/**
 * Publishes NBFC_Agent_Trigger__e platform events for async agent orchestration.
 */
public with sharing class AgentEventPublisher {
    public static final String ACTION_START_ALL_AGENTS = 'START_ALL_AGENTS';
    public static final String ACTION_RUN_DOCUMENT_AGENT = 'RUN_DOCUMENT_AGENT';
    public static final String ACTION_RUN_FINANCIAL_AGENT = 'RUN_FINANCIAL_AGENT';
    public static final String ACTION_RUN_RISK_AGENT = 'RUN_RISK_AGENT';
    public static final String ACTION_RUN_COMPLIANCE_AGENT = 'RUN_COMPLIANCE_AGENT';
    public static final String ACTION_RUN_DECISION_AGENT = 'RUN_DECISION_AGENT';

    public static void publishEvents(List<NBFC_Agent_Trigger__e> events) {
        if (events == null || events.isEmpty()) {
            return;
        }
        List<Database.SaveResult> results = EventBus.publish(events);
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'Platform event publish failed: ' + err.getMessage());
                }
            }
        }
    }

    public static void publishForLoanApplication(Id loanAppId, String eventAction) {
        publishForLoanApplication(loanAppId, eventAction, null);
    }

    public static void publishForLoanApplication(Id loanAppId, String eventAction, String additionalContext) {
        if (loanAppId == null || String.isBlank(eventAction)) {
            return;
        }
        NBFC_Agent_Trigger__e evt = new NBFC_Agent_Trigger__e();
        evt.Loan_Application_Id__c = String.valueOf(loanAppId);
        evt.Event_Action__c = eventAction;
        evt.Triggered_At__c = DateTime.now();
        evt.Additional_Context__c = additionalContext;
        publishEvents(new List<NBFC_Agent_Trigger__e>{ evt });
    }
}
