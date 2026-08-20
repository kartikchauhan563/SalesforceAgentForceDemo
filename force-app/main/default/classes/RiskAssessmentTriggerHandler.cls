/**
 * Handler for Risk_Assessment__c — bureau score sync and high-risk compliance flagging.
 */
public with sharing class RiskAssessmentTriggerHandler implements ITriggerHandler {
    public static void dispatch(
        System.TriggerOperation operationType,
        List<Risk_Assessment__c> newList,
        List<Risk_Assessment__c> oldList,
        Map<Id, Risk_Assessment__c> newMap,
        Map<Id, Risk_Assessment__c> oldMap
    ) {
        TriggerDispatcher.dispatch(
            operationType,
            new RiskAssessmentTriggerHandler(),
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
        List<Risk_Assessment__c> assessments = (List<Risk_Assessment__c>) newRecords;
        syncBureauScoreToParent(assessments, new Map<Id, Risk_Assessment__c>());
        createHistoryRecord_RiskUpdated(assessments, new Map<Id, Risk_Assessment__c>());
        flagHighRiskToCompliance(assessments);
    }

    public void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<Risk_Assessment__c> assessments = (List<Risk_Assessment__c>) newRecords;
        Map<Id, Risk_Assessment__c> typedOldMap = castOldMap(oldMap);
        syncBureauScoreToParent(assessments, typedOldMap);
        createHistoryRecord_RiskUpdated(assessments, typedOldMap);
        flagHighRiskToCompliance(assessments);
    }

    public void afterDelete(List<SObject> oldRecords) {}
    public void afterUndelete(List<SObject> newRecords) {}

    public static void syncBureauScoreToParent(
        List<Risk_Assessment__c> newList,
        Map<Id, Risk_Assessment__c> oldMap
    ) {
        if (newList == null) {
            return;
        }
        List<Loan_Application__c> updates = new List<Loan_Application__c>();
        for (Risk_Assessment__c assessment : newList) {
            Risk_Assessment__c oldAssessment = oldMap != null ? oldMap.get(assessment.Id) : null;
            Boolean bureauChanged = oldAssessment == null
                || assessment.Bureau_Score__c != oldAssessment.Bureau_Score__c;
            Boolean categoryChanged = oldAssessment == null
                || assessment.Risk_Category__c != oldAssessment.Risk_Category__c;
            if (bureauChanged || categoryChanged) {
                updates.add(new Loan_Application__c(
                    Id = assessment.Loan_Application__c,
                    Credit_Score__c = assessment.Bureau_Score__c,
                    Risk_Level__c = assessment.Risk_Category__c
                ));
            }
        }
        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
    }

    public static void createHistoryRecord_RiskUpdated(
        List<Risk_Assessment__c> newList,
        Map<Id, Risk_Assessment__c> oldMap
    ) {
        if (newList == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Risk_Assessment__c assessment : newList) {
            Risk_Assessment__c oldAssessment = oldMap != null ? oldMap.get(assessment.Id) : null;
            Boolean scoreChanged = oldAssessment == null
                || assessment.Final_Risk_Score__c != oldAssessment.Final_Risk_Score__c;
            Boolean categoryChanged = oldAssessment == null
                || assessment.Risk_Category__c != oldAssessment.Risk_Category__c;
            if (!scoreChanged && !categoryChanged) {
                continue;
            }
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = assessment.Loan_Application__c;
            req.eventType = 'Risk Score Updated';
            req.riskScoreBefore = oldAssessment != null ? oldAssessment.Final_Risk_Score__c : null;
            req.riskScoreAfter = assessment.Final_Risk_Score__c;
            req.triggeredBy = 'AI Agent';
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    public static void flagHighRiskToCompliance(List<Risk_Assessment__c> newList) {
        if (newList == null) {
            return;
        }
        List<Compliance_Check__c> checks = new List<Compliance_Check__c>();
        for (Risk_Assessment__c assessment : newList) {
            if ('Very High'.equals(assessment.Risk_Category__c)) {
                checks.add(new Compliance_Check__c(
                    Loan_Application__c = assessment.Loan_Application__c,
                    Rule_Name__c = 'HIGH_RISK_AUTO_FLAG',
                    Status__c = 'Non-Compliant',
                    Severity__c = 'Critical',
                    Action_Required__c = 'Manual senior underwriter review required for very high risk application',
                    Checked_At__c = DateTime.now()
                ));
            }
        }
        if (!checks.isEmpty()) {
            Database.insert(checks, false);
        }
    }

    private static Map<Id, Risk_Assessment__c> castOldMap(Map<Id, SObject> oldMap) {
        Map<Id, Risk_Assessment__c> typed = new Map<Id, Risk_Assessment__c>();
        if (oldMap != null) {
            for (Id key : oldMap.keySet()) {
                typed.put(key, (Risk_Assessment__c) oldMap.get(key));
            }
        }
        return typed;
    }
}
