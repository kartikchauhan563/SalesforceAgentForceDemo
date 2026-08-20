/**
 * Queueable that runs credit risk scoring via RiskScoringEngine for the Credit Risk Agent.
 */
public with sharing class RiskAgentQueueable implements Queueable {
    private Id loanAppId;

    public RiskAgentQueueable(Id loanAppId) {
        this.loanAppId = loanAppId;
    }

    public void execute(QueueableContext ctx) {
        if (loanAppId == null) {
            return;
        }
        RiskScoringEngine.calculateRisk(new List<Id>{ loanAppId });
        System.enqueueJob(new ComplianceAgentQueueable(loanAppId));
    }
}
