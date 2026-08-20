/**
 * Invocable risk scoring engine driven by Policy_Rule__mdt thresholds.
 */
public with sharing class RiskScoringEngine {
    public class RiskRequest {
        @InvocableVariable(required=true)
        public Id loanAppId;
    }

    @InvocableMethod(label='Calculate Loan Risk Score' description='Evaluates policy rules and updates risk score')
    public static void calculateRisk(List<Id> loanAppIds) {
        if (loanAppIds == null || loanAppIds.isEmpty()) {
            return;
        }
        Map<String, Policy_Rule__mdt> rules = PolicyRuleService.getActiveRulesByDeveloperName();
        Map<Id, Loan_Application__c> appsById = new Map<Id, Loan_Application__c>([
            SELECT Id, Credit_Score__c, Monthly_Income__c, Existing_EMI__c, Loan_Amount__c,
                   FOIR_After_Loan__c, Tenure_Months__c
            FROM Loan_Application__c
            WHERE Id IN :loanAppIds
        ]);

        List<Loan_Application__c> updates = new List<Loan_Application__c>();
        List<Agent_Check_Result__c> agentResults = new List<Agent_Check_Result__c>();

        for (Id loanAppId : loanAppIds) {
            Loan_Application__c app = appsById.get(loanAppId);
            if (app == null) {
                continue;
            }
            Decimal totalScore = 0;
            List<String> reasons = new List<String>();
            for (Policy_Rule__mdt rule : rules.values()) {
                if (String.isBlank(rule.Field_API_Name__c) || rule.Risk_Points__c == null) {
                    continue;
                }
                Object fieldValue = app.get(rule.Field_API_Name__c);
                if (evaluateRule(fieldValue, rule)) {
                    totalScore += rule.Risk_Points__c;
                    reasons.add(rule.Description__c);
                }
            }
            String riskLevel = PolicyRuleService.mapRiskScoreToLevel(totalScore);
            updates.add(new Loan_Application__c(
                Id = loanAppId,
                Risk_Score__c = totalScore,
                Risk_Level__c = riskLevel
            ));

            Decimal rejectThreshold = PolicyRuleService.getDecimalThreshold('RULE_REJECT_RISK_SCORE');
            Decimal holdThreshold = PolicyRuleService.getDecimalThreshold('RULE_HOLD_RISK_SCORE');
            String recommendation = 'Approve';
            if (rejectThreshold != null && totalScore >= rejectThreshold) {
                recommendation = 'Reject';
            } else if (holdThreshold != null && totalScore >= holdThreshold) {
                recommendation = 'Hold';
            }

            List<Agent_Check_Result__c> existing = [
                SELECT Id
                FROM Agent_Check_Result__c
                WHERE Loan_Application__c = :loanAppId
                AND Agent_Name__c = 'Credit Risk Agent'
                LIMIT 1
            ];
            Agent_Check_Result__c agentResult = existing.isEmpty()
                ? new Agent_Check_Result__c(Loan_Application__c = loanAppId, Agent_Name__c = 'Credit Risk Agent')
                : existing[0];
            agentResult.Status__c = 'Completed';
            agentResult.Result__c = 'Reject'.equals(recommendation) ? 'Fail' : ('Hold'.equals(recommendation) ? 'Warning' : 'Pass');
            agentResult.Score_Impact__c = totalScore;
            agentResult.Reason__c = reasons.isEmpty() ? 'No policy violations.' : String.join(reasons, '; ');
            agentResult.Raw_Output_JSON__c = JSON.serialize(new Map<String, Object>{
                'riskScore' => totalScore,
                'riskLevel' => riskLevel,
                'recommendation' => recommendation
            });
            agentResult.Run_Completed_At__c = DateTime.now();
            if (agentResult.Run_Started_At__c == null) {
                agentResult.Run_Started_At__c = DateTime.now();
            }
            agentResults.add(agentResult);
        }

        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
        if (!agentResults.isEmpty()) {
            Database.upsert(agentResults, false);
        }
    }

    private static Boolean evaluateRule(Object fieldValue, Policy_Rule__mdt rule) {
        if (fieldValue == null || String.isBlank(rule.Operator__c) || String.isBlank(rule.Threshold_Value__c)) {
            return false;
        }
        String operator = rule.Operator__c.trim();
        String threshold = rule.Threshold_Value__c.trim();
        if (fieldValue instanceof Decimal || fieldValue instanceof Integer || fieldValue instanceof Double) {
            Decimal val = Decimal.valueOf(String.valueOf(fieldValue));
            Decimal thresh = Decimal.valueOf(threshold);
            if ('>'.equals(operator)) {
                return val > thresh;
            }
            if ('>='.equals(operator)) {
                return val >= thresh;
            }
            if ('<'.equals(operator)) {
                return val < thresh;
            }
            if ('<='.equals(operator)) {
                return val <= thresh;
            }
            if ('='.equals(operator)) {
                return val == thresh;
            }
            if ('!='.equals(operator)) {
                return val != thresh;
            }
        }
        String valStr = String.valueOf(fieldValue);
        if ('Contains'.equals(operator)) {
            return valStr.contains(threshold);
        }
        if ('='.equals(operator)) {
            return valStr.equals(threshold);
        }
        if ('!='.equals(operator)) {
            return !valStr.equals(threshold);
        }
        return false;
    }
}
