/**
 * Routes NBFC_Agent_Trigger__e platform events to the appropriate Queueable agent.
 */
public with sharing class NBFCAgentTriggerEventHandler {
    public static void handleEvents(List<NBFC_Agent_Trigger__e> events) {
        if (events == null || events.isEmpty()) {
            return;
        }
        for (NBFC_Agent_Trigger__e evt : events) {
            Id loanAppId = parseLoanAppId(evt.Loan_Application_Id__c);
            if (loanAppId == null || String.isBlank(evt.Event_Action__c)) {
                continue;
            }
            routeEvent(loanAppId, evt.Event_Action__c);
        }
    }

    private static void routeEvent(Id loanAppId, String eventAction) {
        if (AgentEventPublisher.ACTION_START_ALL_AGENTS.equals(eventAction)) {
            AgentOrchestrator.runAllAgents(new List<Id>{ loanAppId });
            return;
        }
        if (AgentEventPublisher.ACTION_RUN_DOCUMENT_AGENT.equals(eventAction)) {
            System.enqueueJob(new DocumentAgentQueueable(loanAppId));
            return;
        }
        if (AgentEventPublisher.ACTION_RUN_FINANCIAL_AGENT.equals(eventAction)) {
            System.enqueueJob(new FinancialAgentQueueable(loanAppId));
            return;
        }
        if (AgentEventPublisher.ACTION_RUN_RISK_AGENT.equals(eventAction)) {
            System.enqueueJob(new RiskAgentQueueable(loanAppId));
            return;
        }
        if (AgentEventPublisher.ACTION_RUN_COMPLIANCE_AGENT.equals(eventAction)) {
            System.enqueueJob(new ComplianceAgentQueueable(loanAppId));
            return;
        }
        if (AgentEventPublisher.ACTION_RUN_DECISION_AGENT.equals(eventAction)) {
            System.enqueueJob(new DecisionAgentQueueable(loanAppId));
        }
    }

    private static Id parseLoanAppId(String loanAppIdText) {
        if (String.isBlank(loanAppIdText)) {
            return null;
        }
        try {
            return Id.valueOf(loanAppIdText.trim());
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'Invalid loan application Id on platform event: ' + loanAppIdText);
            return null;
        }
    }
}
