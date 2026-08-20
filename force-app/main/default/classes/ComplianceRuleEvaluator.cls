/**
 * Evaluates Compliance_Rule__mdt Validation_Logic__c expressions against loan applications.
 */
public with sharing class ComplianceRuleEvaluator {
    public static Boolean evaluate(Loan_Application__c app, Compliance_Rule__mdt rule) {
        if (app == null || rule == null || String.isBlank(rule.Validation_Logic__c)) {
            return true;
        }
        String logic = rule.Validation_Logic__c.trim();
        if (logic.contains('Credit_Score__c')) {
            Decimal minScore = PolicyRuleService.getDecimalThreshold('RULE_MIN_CREDIT_SCORE');
            if (minScore != null && app.Credit_Score__c != null && app.Credit_Score__c < minScore) {
                return false;
            }
        }
        if (logic.contains('Monthly_Income__c')) {
            Decimal minIncome = PolicyRuleService.getDecimalThreshold('RULE_MIN_INCOME');
            if (minIncome != null && app.Monthly_Income__c != null && app.Monthly_Income__c < minIncome) {
                return false;
            }
        }
        if (logic.contains('Loan_Amount__c')) {
            Decimal maxAmount = PolicyRuleService.getDecimalThreshold('RULE_MAX_AMOUNT');
            if (maxAmount != null && app.Loan_Amount__c != null && app.Loan_Amount__c > maxAmount) {
                return false;
            }
        }
        return true;
    }
}
