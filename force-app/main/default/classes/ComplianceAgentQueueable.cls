/**
 * Queueable that evaluates Compliance_Rule__mdt records and creates Compliance_Check__c rows.
 */
public with sharing class ComplianceAgentQueueable implements Queueable {
    private Id loanAppId;

    public ComplianceAgentQueueable(Id loanAppId) {
        this.loanAppId = loanAppId;
    }

    public void execute(QueueableContext ctx) {
        if (loanAppId == null) {
            return;
        }
        Loan_Application__c app = [
            SELECT Id, Credit_Score__c, Monthly_Income__c, Loan_Amount__c, Applicant__c
            FROM Loan_Application__c
            WHERE Id = :loanAppId
            LIMIT 1
        ];
        List<Compliance_Rule__mdt> rules = [
            SELECT DeveloperName, Validation_Logic__c, Severity__c, Description__c, Mandatory__c
            FROM Compliance_Rule__mdt
            WHERE Active__c = TRUE
        ];
        List<Compliance_Check__c> checks = new List<Compliance_Check__c>();
        List<String> failures = new List<String>();
        for (Compliance_Rule__mdt rule : rules) {
            Boolean compliant = ComplianceRuleEvaluator.evaluate(app, rule);
            Compliance_Check__c check = new Compliance_Check__c(
                Loan_Application__c = loanAppId,
                Rule_Name__c = rule.DeveloperName,
                Description__c = rule.Description__c,
                Severity__c = rule.Severity__c,
                Status__c = compliant ? 'Compliant' : 'Non-Compliant',
                Checked_At__c = DateTime.now()
            );
            checks.add(check);
            if (!compliant) {
                failures.add(rule.DeveloperName);
            }
        }
        if (!checks.isEmpty()) {
            Database.insert(checks, false);
        }

        String result = failures.isEmpty() ? 'Pass' : 'Fail';
        Decimal scoreImpact = failures.isEmpty() ? 0 : 20;
        String reason = failures.isEmpty()
            ? 'All compliance rules passed.'
            : 'Failed rules: ' + String.join(failures, ', ');
        completeAgentResult('Compliance Agent', result, scoreImpact, reason);
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
