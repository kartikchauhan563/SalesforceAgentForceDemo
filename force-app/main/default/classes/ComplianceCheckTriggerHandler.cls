/**
 * Handler for Compliance_Check__c — violation tracking and parent sub-status updates.
 */
public with sharing class ComplianceCheckTriggerHandler implements ITriggerHandler {
    public static void dispatch(
        System.TriggerOperation operationType,
        List<Compliance_Check__c> newList,
        List<Compliance_Check__c> oldList,
        Map<Id, Compliance_Check__c> newMap,
        Map<Id, Compliance_Check__c> oldMap
    ) {
        TriggerDispatcher.dispatch(
            operationType,
            new ComplianceCheckTriggerHandler(),
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
        List<Compliance_Check__c> checks = (List<Compliance_Check__c>) newRecords;
        createHistoryRecord_ViolationFound(checks);
        createHistoryRecord_CheckRun(checks);
        updateParentStatusOnCriticalViolation(checks, new Map<Id, Compliance_Check__c>());
    }

    public void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<Compliance_Check__c> checks = (List<Compliance_Check__c>) newRecords;
        Map<Id, Compliance_Check__c> typedOldMap = castOldMap(oldMap);
        createHistoryRecord_ViolationResolved(checks, typedOldMap);
    }

    public void afterDelete(List<SObject> oldRecords) {}
    public void afterUndelete(List<SObject> newRecords) {}

    public static void createHistoryRecord_ViolationFound(List<Compliance_Check__c> newList) {
        if (newList == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Compliance_Check__c check : newList) {
            if (!'Non-Compliant'.equals(check.Status__c)) {
                continue;
            }
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = check.Loan_Application__c;
            req.eventType = 'Compliance Violation Found';
            req.eventSubType = check.Rule_Name__c;
            req.severity = check.Severity__c;
            req.complianceRelevant = true;
            req.triggeredBy = 'System';
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    public static void createHistoryRecord_CheckRun(List<Compliance_Check__c> newList) {
        if (newList == null) {
            return;
        }
        Map<Id, LoanApplicationHistoryHandler.HistoryRequest> byParent = new Map<Id, LoanApplicationHistoryHandler.HistoryRequest>();
        for (Compliance_Check__c check : newList) {
            if (!byParent.containsKey(check.Loan_Application__c)) {
                LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
                req.loanApplicationId = check.Loan_Application__c;
                req.eventType = 'Compliance Check Run';
                req.triggeredBy = 'System';
                req.complianceRelevant = true;
                byParent.put(check.Loan_Application__c, req);
            }
        }
        LoanApplicationHistoryHandler.createHistoryRecords(byParent.values());
    }

    public static void createHistoryRecord_ViolationResolved(
        List<Compliance_Check__c> newList,
        Map<Id, Compliance_Check__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Compliance_Check__c check : newList) {
            Compliance_Check__c oldCheck = oldMap.get(check.Id);
            if (oldCheck == null || check.Resolved__c != true || oldCheck.Resolved__c == true) {
                continue;
            }
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = check.Loan_Application__c;
            req.eventType = 'Compliance Violation Resolved';
            req.eventSubType = check.Rule_Name__c;
            req.complianceRelevant = true;
            req.triggeredBy = 'User';
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    public static void updateParentStatusOnCriticalViolation(
        List<Compliance_Check__c> newList,
        Map<Id, Compliance_Check__c> oldMap
    ) {
        if (newList == null) {
            return;
        }
        List<Loan_Application__c> updates = new List<Loan_Application__c>();
        for (Compliance_Check__c check : newList) {
            Compliance_Check__c oldCheck = oldMap != null ? oldMap.get(check.Id) : null;
            Boolean isNewCritical = oldCheck == null
                && 'Non-Compliant'.equals(check.Status__c)
                && 'Critical'.equals(check.Severity__c);
            if (isNewCritical) {
                updates.add(new Loan_Application__c(
                    Id = check.Loan_Application__c,
                    Sub_Status__c = 'KYC Pending'
                ));
            }
        }
        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
    }

    private static Map<Id, Compliance_Check__c> castOldMap(Map<Id, SObject> oldMap) {
        Map<Id, Compliance_Check__c> typed = new Map<Id, Compliance_Check__c>();
        if (oldMap != null) {
            for (Id key : oldMap.keySet()) {
                typed.put(key, (Compliance_Check__c) oldMap.get(key));
            }
        }
        return typed;
    }
}
