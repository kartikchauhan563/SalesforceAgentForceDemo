/**
 * Reads threshold and policy values from Policy_Rule__mdt — never hardcode business thresholds in Apex.
 */
public with sharing class PolicyRuleService {
    private static Map<String, Policy_Rule__mdt> ruleCache;

    /**
     * Returns active policy rules keyed by DeveloperName (e.g. RULE_MIN_AMOUNT).
     */
    public static Map<String, Policy_Rule__mdt> getActiveRulesByDeveloperName() {
        if (ruleCache == null) {
            ruleCache = new Map<String, Policy_Rule__mdt>();
            for (Policy_Rule__mdt rule : [
                SELECT DeveloperName, Threshold_Value__c, Risk_Points__c, Field_API_Name__c,
                       Operator__c, Category__c, Description__c, Is_Active__c
                FROM Policy_Rule__mdt
                WHERE Is_Active__c = TRUE
            ]) {
                ruleCache.put(rule.DeveloperName, rule);
            }
        }
        return ruleCache;
    }

    public static Decimal getDecimalThreshold(String developerName) {
        Policy_Rule__mdt rule = getActiveRulesByDeveloperName().get(developerName);
        if (rule == null || String.isBlank(rule.Threshold_Value__c)) {
            return null;
        }
        return Decimal.valueOf(rule.Threshold_Value__c.trim());
    }

    public static Integer getIntegerThreshold(String developerName) {
        Decimal value = getDecimalThreshold(developerName);
        return value == null ? null : value.intValue();
    }

    /**
     * Maps a numeric risk score to Risk_Level__c picklist using CMDT band thresholds.
     */
    public static String mapRiskScoreToLevel(Decimal riskScore) {
        if (riskScore == null) {
            return null;
        }
        Decimal veryLowMax = getDecimalThreshold('RULE_RISK_VERY_LOW_MAX');
        Decimal lowMax = getDecimalThreshold('RULE_RISK_LOW_MAX');
        Decimal mediumMax = getDecimalThreshold('RULE_RISK_MEDIUM_MAX');
        Decimal highMax = getDecimalThreshold('RULE_RISK_HIGH_MAX');

        if (veryLowMax != null && riskScore <= veryLowMax) {
            return 'Very Low';
        }
        if (lowMax != null && riskScore <= lowMax) {
            return 'Low';
        }
        if (mediumMax != null && riskScore <= mediumMax) {
            return 'Medium';
        }
        if (highMax != null && riskScore <= highMax) {
            return 'High';
        }
        return 'Very High';
    }

    @TestVisible
    static void clearCache() {
        ruleCache = null;
    }
}
