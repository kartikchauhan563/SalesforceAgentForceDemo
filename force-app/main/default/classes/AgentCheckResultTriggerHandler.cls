/**
 * Handler for Agent_Check_Result__c — agent lifecycle, risk rollup, and orchestration.
 */
public with sharing class AgentCheckResultTriggerHandler implements ITriggerHandler {
    private static final Set<String> PREREQUISITE_AGENTS = new Set<String>{
        'Document Verification Agent',
        'Financial Health Agent',
        'Credit Risk Agent',
        'Compliance Agent'
    };

    public static void dispatch(
        System.TriggerOperation operationType,
        List<Agent_Check_Result__c> newList,
        List<Agent_Check_Result__c> oldList,
        Map<Id, Agent_Check_Result__c> newMap,
        Map<Id, Agent_Check_Result__c> oldMap
    ) {
        TriggerDispatcher.dispatch(
            operationType,
            new AgentCheckResultTriggerHandler(),
            newList,
            oldList,
            newMap,
            oldMap
        );
    }

    public void beforeInsert(List<SObject> newRecords) {
        setRunTimestamp((List<Agent_Check_Result__c>) newRecords);
    }

    public void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {}

    public void beforeDelete(List<SObject> oldRecords) {}

    public void afterInsert(List<SObject> newRecords) {
        createHistoryRecord_AgentStarted((List<Agent_Check_Result__c>) newRecords);
    }

    public void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<Agent_Check_Result__c> results = (List<Agent_Check_Result__c>) newRecords;
        Map<Id, Agent_Check_Result__c> typedOldMap = castOldMap(oldMap);
        onAgentCompleted(results, typedOldMap);
        onAgentFailed(results, typedOldMap);
    }

    public void afterDelete(List<SObject> oldRecords) {}

    public void afterUndelete(List<SObject> newRecords) {}

    public static void setRunTimestamp(List<Agent_Check_Result__c> newList) {
        if (newList == null) {
            return;
        }
        for (Agent_Check_Result__c result : newList) {
            if (result.Run_Started_At__c == null) {
                result.Run_Started_At__c = DateTime.now();
            }
            result.Status__c = 'Running';
        }
    }

    public static void createHistoryRecord_AgentStarted(List<Agent_Check_Result__c> newList) {
        if (newList == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Agent_Check_Result__c result : newList) {
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = result.Loan_Application__c;
            req.eventType = 'Agent Run Started';
            req.agentName = result.Agent_Name__c;
            req.durationSeconds = 0;
            req.triggeredBy = 'System';
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    public static void onAgentCompleted(
        List<Agent_Check_Result__c> newList,
        Map<Id, Agent_Check_Result__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<Agent_Check_Result__c> completed = new List<Agent_Check_Result__c>();
        List<Agent_Check_Result__c> executionUpdates = new List<Agent_Check_Result__c>();
        Set<Id> parentIds = new Set<Id>();
        for (Agent_Check_Result__c result : newList) {
            Agent_Check_Result__c oldResult = oldMap.get(result.Id);
            if (oldResult != null && !'Completed'.equals(oldResult.Status__c) && 'Completed'.equals(result.Status__c)) {
                completed.add(result);
                parentIds.add(result.Loan_Application__c);
                if (result.Run_Completed_At__c != null && result.Run_Started_At__c != null) {
                    Long ms = result.Run_Completed_At__c.getTime() - result.Run_Started_At__c.getTime();
                    executionUpdates.add(new Agent_Check_Result__c(
                        Id = result.Id,
                        Execution_Time_Ms__c = ms
                    ));
                }
            }
        }
        if (completed.isEmpty()) {
            return;
        }
        if (!executionUpdates.isEmpty()) {
            Database.update(executionUpdates, false);
        }

        Map<Id, Decimal> riskByParent = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Loan_Application__c parentId, SUM(Score_Impact__c) totalImpact
            FROM Agent_Check_Result__c
            WHERE Loan_Application__c IN :parentIds
            AND Status__c = 'Completed'
            GROUP BY Loan_Application__c
        ]) {
            riskByParent.put((Id) ar.get('parentId'), (Decimal) ar.get('totalImpact'));
        }
        List<Loan_Application__c> parentUpdates = new List<Loan_Application__c>();
        for (Id parentId : parentIds) {
            Decimal score = riskByParent.containsKey(parentId) ? riskByParent.get(parentId) : 0;
            parentUpdates.add(new Loan_Application__c(
                Id = parentId,
                Risk_Score__c = score,
                Risk_Level__c = PolicyRuleService.mapRiskScoreToLevel(score)
            ));
        }
        if (!parentUpdates.isEmpty()) {
            Database.update(parentUpdates, false);
        }

        List<LoanApplicationHistoryHandler.HistoryRequest> historyRequests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Agent_Check_Result__c result : completed) {
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = result.Loan_Application__c;
            req.eventType = 'Agent Run Completed';
            req.agentName = result.Agent_Name__c;
            req.agentResult = result.Result__c;
            req.agentScoreImpact = result.Score_Impact__c;
            req.durationSeconds = result.Execution_Time_Ms__c != null
                ? result.Execution_Time_Ms__c / 1000
                : null;
            req.triggeredBy = 'AI Agent';
            historyRequests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(historyRequests);

        publishDecisionAgentIfReady(parentIds);
    }

    public static void onAgentFailed(
        List<Agent_Check_Result__c> newList,
        Map<Id, Agent_Check_Result__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> historyRequests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        List<LoanApplicationHistoryHandler.AuditLogRequest> auditRequests = new List<LoanApplicationHistoryHandler.AuditLogRequest>();
        for (Agent_Check_Result__c result : newList) {
            Agent_Check_Result__c oldResult = oldMap.get(result.Id);
            if (oldResult == null || 'Failed'.equals(oldResult.Status__c) || !'Failed'.equals(result.Status__c)) {
                continue;
            }
            LoanApplicationHistoryHandler.HistoryRequest hist = new LoanApplicationHistoryHandler.HistoryRequest();
            hist.loanApplicationId = result.Loan_Application__c;
            hist.eventType = 'Agent Run Failed';
            hist.agentName = result.Agent_Name__c;
            hist.severity = 'Error';
            hist.triggeredBy = 'System';
            historyRequests.add(hist);

            LoanApplicationHistoryHandler.AuditLogRequest audit = new LoanApplicationHistoryHandler.AuditLogRequest();
            audit.loanApplicationId = result.Loan_Application__c;
            audit.eventType = 'Agent Run';
            audit.eventSource = 'AI Agent';
            audit.severity = 'Error';
            audit.agentName = result.Agent_Name__c;
            audit.eventDescription = result.Reason__c;
            auditRequests.add(audit);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(historyRequests);
        LoanApplicationHistoryHandler.createAuditRecords(auditRequests);
    }

    public static void updateParentRiskLevel(List<Agent_Check_Result__c> newList) {
        if (newList == null) {
            return;
        }
        Set<Id> parentIds = new Set<Id>();
        for (Agent_Check_Result__c result : newList) {
            if (result.Loan_Application__c != null) {
                parentIds.add(result.Loan_Application__c);
            }
        }
        if (parentIds.isEmpty()) {
            return;
        }
        Map<Id, Decimal> riskByParent = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Loan_Application__c parentId, SUM(Score_Impact__c) totalImpact
            FROM Agent_Check_Result__c
            WHERE Loan_Application__c IN :parentIds
            AND Status__c = 'Completed'
            GROUP BY Loan_Application__c
        ]) {
            riskByParent.put((Id) ar.get('parentId'), (Decimal) ar.get('totalImpact'));
        }
        List<Loan_Application__c> updates = new List<Loan_Application__c>();
        for (Id parentId : parentIds) {
            Decimal score = riskByParent.containsKey(parentId) ? riskByParent.get(parentId) : 0;
            updates.add(new Loan_Application__c(
                Id = parentId,
                Risk_Score__c = score,
                Risk_Level__c = PolicyRuleService.mapRiskScoreToLevel(score)
            ));
        }
        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
    }

    private static void publishDecisionAgentIfReady(Set<Id> parentIds) {
        Map<Id, Set<String>> completedAgentsByParent = new Map<Id, Set<String>>();
        for (Id parentId : parentIds) {
            completedAgentsByParent.put(parentId, new Set<String>());
        }
        for (Agent_Check_Result__c result : [
            SELECT Loan_Application__c, Agent_Name__c
            FROM Agent_Check_Result__c
            WHERE Loan_Application__c IN :parentIds
            AND Status__c = 'Completed'
            AND Agent_Name__c IN :PREREQUISITE_AGENTS
        ]) {
            completedAgentsByParent.get(result.Loan_Application__c).add(result.Agent_Name__c);
        }
        List<NBFC_Agent_Trigger__e> events = new List<NBFC_Agent_Trigger__e>();
        for (Id parentId : parentIds) {
            Set<String> completed = completedAgentsByParent.get(parentId);
            if (completed != null && completed.containsAll(PREREQUISITE_AGENTS)) {
                NBFC_Agent_Trigger__e evt = new NBFC_Agent_Trigger__e();
                evt.Loan_Application_Id__c = String.valueOf(parentId);
                evt.Event_Action__c = AgentEventPublisher.ACTION_RUN_DECISION_AGENT;
                evt.Triggered_At__c = DateTime.now();
                events.add(evt);
            }
        }
        AgentEventPublisher.publishEvents(events);
    }

    private static Map<Id, Agent_Check_Result__c> castOldMap(Map<Id, SObject> oldMap) {
        Map<Id, Agent_Check_Result__c> typed = new Map<Id, Agent_Check_Result__c>();
        if (oldMap != null) {
            for (Id key : oldMap.keySet()) {
                typed.put(key, (Agent_Check_Result__c) oldMap.get(key));
            }
        }
        return typed;
    }
}
