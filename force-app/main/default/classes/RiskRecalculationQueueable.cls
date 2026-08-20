/**
 * Queueable that re-runs risk scoring when financial fields change mid-review.
 */
public with sharing class RiskRecalculationQueueable implements Queueable {
    private List<Id> loanAppIds;

    public RiskRecalculationQueueable(List<Id> loanAppIds) {
        this.loanAppIds = loanAppIds != null ? loanAppIds : new List<Id>();
    }

    public void execute(QueueableContext ctx) {
        if (loanAppIds.isEmpty()) {
            return;
        }
        RiskScoringEngine.calculateRisk(loanAppIds);
    }
}
