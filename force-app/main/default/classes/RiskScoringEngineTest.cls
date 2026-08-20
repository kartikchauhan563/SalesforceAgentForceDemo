@isTest
private class RiskScoringEngineTest {
    @TestSetup
    static void setupData() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        NBFC_TestDataFactory.createLoanApplications(applicant, product, 3);
    }

    private static Loan_Application__c getLoanApp() {
        return [
            SELECT Id, Credit_Score__c, Monthly_Income__c, Existing_EMI__c,
                   Loan_Amount__c, FOIR_After_Loan__c, Tenure_Months__c
            FROM Loan_Application__c
            LIMIT 1
        ];
    }

    @isTest
    static void testHighRiskScenario() {
        Loan_Application__c app = getLoanApp();
        app.Credit_Score__c = 550;
        app.Existing_EMI__c = 60000;
        app.Monthly_Income__c = 50000;
        update app;
        Test.startTest();
        RiskScoringEngine.calculateRisk(new List<Id>{ app.Id });
        Test.stopTest();
        app = [SELECT Risk_Score__c, Risk_Level__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertNotEquals(null, app.Risk_Score__c);
    }

    @isTest
    static void testLowRiskScenario() {
        Loan_Application__c app = getLoanApp();
        app.Credit_Score__c = 820;
        app.Existing_EMI__c = 5000;
        app.Monthly_Income__c = 120000;
        update app;
        Test.startTest();
        RiskScoringEngine.calculateRisk(new List<Id>{ app.Id });
        Test.stopTest();
        app = [SELECT Risk_Score__c, Risk_Level__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertNotEquals(null, app.Risk_Level__c);
    }

    @isTest
    static void testMediumRiskScenario() {
        Loan_Application__c app = getLoanApp();
        app.Credit_Score__c = 680;
        app.Existing_EMI__c = 25000;
        app.Monthly_Income__c = 80000;
        update app;
        Test.startTest();
        RiskScoringEngine.calculateRisk(new List<Id>{ app.Id });
        Test.stopTest();
        List<Agent_Check_Result__c> results = [
            SELECT Status__c, Result__c, Score_Impact__c
            FROM Agent_Check_Result__c
            WHERE Loan_Application__c = :app.Id
            AND Agent_Name__c = 'Credit Risk Agent'
        ];
        System.assert(!results.isEmpty(), 'Credit Risk Agent result expected');
    }

    @isTest
    static void testBulkScoring() {
        List<Loan_Application__c> apps = [SELECT Id FROM Loan_Application__c];
        List<Id> appIds = new List<Id>();
        for (Loan_Application__c app : apps) {
            appIds.add(app.Id);
        }
        Test.startTest();
        RiskScoringEngine.calculateRisk(appIds);
        Test.stopTest();
        System.assertEquals(apps.size(), [
            SELECT COUNT() FROM Loan_Application__c WHERE Risk_Score__c != NULL
        ]);
    }

    @isTest
    static void testCustomMetadataRulesApplied() {
        List<Policy_Rule__mdt> rules = [
            SELECT DeveloperName, Field_API_Name__c, Operator__c, Threshold_Value__c, Risk_Points__c
            FROM Policy_Rule__mdt
            WHERE Is_Active__c = TRUE
            AND Field_API_Name__c != NULL
            AND Risk_Points__c != NULL
            LIMIT 50
        ];
        Loan_Application__c app = getLoanApp();
        PolicyRuleService.clearCache();
        Test.startTest();
        RiskScoringEngine.calculateRisk(new List<Id>{ app.Id });
        Test.stopTest();
        app = [SELECT Risk_Score__c, Risk_Level__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertNotEquals(null, app.Risk_Score__c, 'Risk score should be calculated');
        if (!rules.isEmpty()) {
            System.assertNotEquals(null, PolicyRuleService.mapRiskScoreToLevel(app.Risk_Score__c));
        }
    }
}
