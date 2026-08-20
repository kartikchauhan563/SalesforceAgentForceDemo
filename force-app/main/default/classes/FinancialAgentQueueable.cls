/**
 * Queueable that evaluates FOIR, EMI burden, and LTI against Policy_Rule__mdt thresholds.
 */
public with sharing class FinancialAgentQueueable implements Queueable {
    private Id loanAppId;

    public FinancialAgentQueueable(Id loanAppId) {
        this.loanAppId = loanAppId;
    }

    public void execute(QueueableContext ctx) {
        if (loanAppId == null) {
            return;
        }
        Loan_Application__c app = [
            SELECT Id, Monthly_Income__c, Existing_EMI__c, Loan_Amount__c,
                   FOIR_After_Loan__c, EMI_Burden__c, LTI__c
            FROM Loan_Application__c
            WHERE Id = :loanAppId
            LIMIT 1
        ];
        Decimal maxFoir = PolicyRuleService.getDecimalThreshold('RULE_MAX_FOIR');
        Decimal maxLti = PolicyRuleService.getDecimalThreshold('RULE_MAX_LTI');
        List<String> reasons = new List<String>();
        String result = 'Pass';
        Decimal scoreImpact = 0;

        if (maxFoir != null && app.FOIR_After_Loan__c != null && app.FOIR_After_Loan__c > maxFoir) {
            result = 'Fail';
            scoreImpact += 20;
            reasons.add('FOIR ' + app.FOIR_After_Loan__c + '% exceeds max ' + maxFoir + '%');
        }
        if (maxLti != null && app.LTI__c != null && app.LTI__c > maxLti) {
            result = 'Fail';
            scoreImpact += 15;
            reasons.add('LTI ' + app.LTI__c + ' exceeds max ' + maxLti);
        }
        if (app.Monthly_Income__c != null && app.Monthly_Income__c <= 0) {
            result = 'Fail';
            scoreImpact += 25;
            reasons.add('Invalid monthly income');
        }
        if (reasons.isEmpty()) {
            reasons.add('Financial ratios within policy limits.');
        }

        completeAgentResult('Financial Health Agent', result, scoreImpact, String.join(reasons, '; '));
        System.enqueueJob(new RiskAgentQueueable(loanAppId));
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
