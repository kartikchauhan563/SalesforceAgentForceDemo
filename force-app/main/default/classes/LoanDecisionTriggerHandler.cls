/**
 * Handler for Loan_Decision__c — AI decision sync and officer override processing.
 */
public with sharing class LoanDecisionTriggerHandler implements ITriggerHandler {
    public static void dispatch(
        System.TriggerOperation operationType,
        List<Loan_Decision__c> newList,
        List<Loan_Decision__c> oldList,
        Map<Id, Loan_Decision__c> newMap,
        Map<Id, Loan_Decision__c> oldMap
    ) {
        TriggerDispatcher.dispatch(
            operationType,
            new LoanDecisionTriggerHandler(),
            newList,
            oldList,
            newMap,
            oldMap
        );
    }

    public void beforeInsert(List<SObject> newRecords) {}
    public void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {}
    public void beforeDelete(List<SObject> oldRecords) {}

    public void afterInsert(List<SObject> newRecords) {
        List<Loan_Decision__c> decisions = (List<Loan_Decision__c>) newRecords;
        syncDecisionToParent(decisions);
        updateParentStatus(decisions);
        createHistoryRecord_DecisionGenerated(decisions);
        enqueueNotification(decisions);
    }

    public void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        onOfficerOverride((List<Loan_Decision__c>) newRecords, castOldMap(oldMap));
    }

    public void afterDelete(List<SObject> oldRecords) {}
    public void afterUndelete(List<SObject> newRecords) {}

    public static void syncDecisionToParent(List<Loan_Decision__c> newList) {
        if (newList == null) {
            return;
        }
        List<Loan_Application__c> updates = new List<Loan_Application__c>();
        for (Loan_Decision__c decision : newList) {
            updates.add(new Loan_Application__c(
                Id = decision.Loan_Application__c,
                Final_Recommendation__c = decision.Recommendation__c,
                AI_Confidence__c = decision.Confidence_Score__c,
                Decision_Reasons__c = decision.Key_Reasons__c,
                Missing_Documents__c = decision.Missing_Paperwork__c,
                Next_Best_Action__c = decision.Next_Best_Action__c,
                All_Agents_Completed__c = true
            ));
        }
        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
    }

    public static void updateParentStatus(List<Loan_Decision__c> newList) {
        if (newList == null) {
            return;
        }
        List<Loan_Application__c> updates = new List<Loan_Application__c>();
        for (Loan_Decision__c decision : newList) {
            String status = mapRecommendationToStatus(decision.Recommendation__c);
            if (status != null) {
                updates.add(new Loan_Application__c(
                    Id = decision.Loan_Application__c,
                    Status__c = status
                ));
            }
        }
        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
    }

    public static void createHistoryRecord_DecisionGenerated(List<Loan_Decision__c> newList) {
        if (newList == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Loan_Decision__c decision : newList) {
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = decision.Loan_Application__c;
            req.eventType = 'Loan Decision Generated';
            req.aiConfidence = decision.Confidence_Score__c;
            req.decisionMade = decision.Recommendation__c;
            req.decisionReason = decision.Decision_Summary__c;
            req.missingDocumentsSnapshot = decision.Missing_Paperwork__c;
            req.triggeredBy = 'AI Agent';
            req.complianceRelevant = true;
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    public static void enqueueNotification(List<Loan_Decision__c> newList) {
        if (newList == null || newList.isEmpty()) {
            return;
        }
        List<Id> loanAppIds = new List<Id>();
        List<String> notifyTypes = new List<String>();
        for (Loan_Decision__c decision : newList) {
            loanAppIds.add(decision.Loan_Application__c);
            notifyTypes.add(mapRecommendationToStatus(decision.Recommendation__c));
        }
        if (!System.isFuture() && !System.isBatch()) {
            System.enqueueJob(new CustomerNotificationQueueable(loanAppIds, notifyTypes));
        }
    }

    public static void onOfficerOverride(
        List<Loan_Decision__c> newList,
        Map<Id, Loan_Decision__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<Loan_Application__c> parentUpdates = new List<Loan_Application__c>();
        List<Loan_Decision__c> decisionUpdates = new List<Loan_Decision__c>();
        List<LoanApplicationHistoryHandler.HistoryRequest> historyRequests = new List<LoanApplicationHistoryHandler.HistoryRequest>();

        for (Loan_Decision__c decision : newList) {
            Loan_Decision__c oldDecision = oldMap.get(decision.Id);
            if (oldDecision == null || decision.Officer_Decision__c == oldDecision.Officer_Decision__c
                || decision.Officer_Decision__c == null) {
                continue;
            }
            Loan_Application__c parentUpdate = new Loan_Application__c(Id = decision.Loan_Application__c);
            Boolean isOverride = false;

            if ('Override Approve'.equals(decision.Officer_Decision__c)) {
                parentUpdate.Status__c = 'Approved';
                parentUpdate.Final_Recommendation__c = 'Approve';
                isOverride = true;
            } else if ('Override Reject'.equals(decision.Officer_Decision__c)) {
                parentUpdate.Status__c = 'Rejected';
                parentUpdate.Final_Recommendation__c = 'Reject';
                isOverride = true;
            } else if ('Accept AI'.equals(decision.Officer_Decision__c)) {
                decisionUpdates.add(new Loan_Decision__c(
                    Id = decision.Id,
                    Officer_Reviewed__c = true,
                    Officer_Reviewed_At__c = DateTime.now()
                ));
            }
            if (isOverride) {
                parentUpdates.add(parentUpdate);
            }

            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = decision.Loan_Application__c;
            req.eventType = 'Officer Decision Made';
            req.officerOverride = isOverride;
            req.overrideReason = decision.Officer_Comments__c;
            req.complianceRelevant = true;
            req.triggeredBy = 'User';
            historyRequests.add(req);
        }

        if (!parentUpdates.isEmpty()) {
            Database.update(parentUpdates, false);
        }
        if (!decisionUpdates.isEmpty()) {
            Database.update(decisionUpdates, false);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(historyRequests);
    }

    private static String mapRecommendationToStatus(String recommendation) {
        if ('Approve'.equals(recommendation)) {
            return 'Approved';
        }
        if ('Hold'.equals(recommendation)) {
            return 'On Hold';
        }
        if ('Reject'.equals(recommendation)) {
            return 'Rejected';
        }
        return null;
    }

    private static Map<Id, Loan_Decision__c> castOldMap(Map<Id, SObject> oldMap) {
        Map<Id, Loan_Decision__c> typed = new Map<Id, Loan_Decision__c>();
        if (oldMap != null) {
            for (Id key : oldMap.keySet()) {
                typed.put(key, (Loan_Decision__c) oldMap.get(key));
            }
        }
        return typed;
    }
}
