/**
 * Queueable that generates the final AI loan decision after prerequisite agents complete.
 */
public with sharing class DecisionAgentQueueable implements Queueable {
    private Id loanAppId;

    public DecisionAgentQueueable(Id loanAppId) {
        this.loanAppId = loanAppId;
    }

    public void execute(QueueableContext ctx) {
        if (loanAppId == null) {
            return;
        }
        Loan_Application__c app = [
            SELECT Id, Risk_Score__c, Risk_Level__c, Missing_Documents__c, Final_Recommendation__c
            FROM Loan_Application__c
            WHERE Id = :loanAppId
            LIMIT 1
        ];
        Decimal rejectThreshold = PolicyRuleService.getDecimalThreshold('RULE_REJECT_RISK_SCORE');
        Decimal holdThreshold = PolicyRuleService.getDecimalThreshold('RULE_HOLD_RISK_SCORE');
        String recommendation = 'Approve';
        Decimal confidence = 85;
        if (String.isNotBlank(app.Missing_Documents__c)) {
            recommendation = 'Hold';
            confidence = 60;
        } else if (rejectThreshold != null && app.Risk_Score__c != null && app.Risk_Score__c >= rejectThreshold) {
            recommendation = 'Reject';
            confidence = 90;
        } else if (holdThreshold != null && app.Risk_Score__c != null && app.Risk_Score__c >= holdThreshold) {
            recommendation = 'Hold';
            confidence = 75;
        }

        Loan_Decision__c decision = new Loan_Decision__c(
            Loan_Application__c = loanAppId,
            Recommendation__c = recommendation,
            Confidence_Score__c = confidence,
            Decision_Summary__c = 'AI decision based on aggregated agent results.',
            Key_Reasons__c = 'Risk score: ' + app.Risk_Score__c + ', Level: ' + app.Risk_Level__c,
            Missing_Paperwork__c = app.Missing_Documents__c,
            Generated_By__c = 'AI Agent',
            Generated_At__c = DateTime.now()
        );
        Database.insert(decision, false);

        completeAgentResult('Decision Agent', 'Pass', 0, 'Decision generated: ' + recommendation);
    }

    private void completeAgentResult(String agentName, String result, Decimal scoreImpact, String reason) {
        List<Agent_Check_Result__c> results = [
            SELECT Id
            FROM Agent_Check_Result__c
            WHERE Loan_Application__c = :loanAppId
            AND Agent_Name__c = :agentName
            LIMIT 1
        ];
        if (results.isEmpty()) {
            return;
        }
        Agent_Check_Result__c agentResult = results[0];
        agentResult.Status__c = 'Completed';
        agentResult.Result__c = result;
        agentResult.Score_Impact__c = scoreImpact;
        agentResult.Reason__c = reason;
        agentResult.Run_Completed_At__c = DateTime.now();
        Database.update(agentResult, false);
    }
}
