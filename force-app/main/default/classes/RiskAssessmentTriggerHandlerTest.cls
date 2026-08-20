@isTest
private class RiskAssessmentTriggerHandlerTest {
    @TestSetup
    static void setupData() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        NBFC_TestDataFactory.createLoanApplications(applicant, product, 3);
    }

    private static Id getLoanAppId() {
        return [SELECT Id FROM Loan_Application__c LIMIT 1].Id;
    }

    @isTest
    static void testBureauScoreSyncsToParent() {
        Id loanAppId = getLoanAppId();
        Risk_Assessment__c assessment = new Risk_Assessment__c(
            Loan_Application__c = loanAppId,
            Bureau_Score__c = 780,
            Risk_Category__c = 'Low',
            Final_Risk_Score__c = 15
        );
        Test.startTest();
        insert assessment;
        Test.stopTest();
        Loan_Application__c app = [
            SELECT Credit_Score__c, Risk_Level__c
            FROM Loan_Application__c WHERE Id = :loanAppId
        ];
        System.assertEquals(780, app.Credit_Score__c);
        System.assertEquals('Low', app.Risk_Level__c);
    }

    @isTest
    static void testHighRiskCreatesComplianceRecord() {
        Id loanAppId = getLoanAppId();
        Risk_Assessment__c assessment = new Risk_Assessment__c(
            Loan_Application__c = loanAppId,
            Bureau_Score__c = 520,
            Risk_Category__c = 'Very High',
            Final_Risk_Score__c = 95
        );
        Test.startTest();
        insert assessment;
        Test.stopTest();
        Integer checkCount = [
            SELECT COUNT()
            FROM Compliance_Check__c
            WHERE Loan_Application__c = :loanAppId
            AND Rule_Name__c = 'HIGH_RISK_AUTO_FLAG'
        ];
        System.assertEquals(1, checkCount);
    }

    @isTest
    static void testHistoryCreatedOnRiskUpdate() {
        Id loanAppId = getLoanAppId();
        Risk_Assessment__c assessment = new Risk_Assessment__c(
            Loan_Application__c = loanAppId,
            Bureau_Score__c = 700,
            Risk_Category__c = 'Medium',
            Final_Risk_Score__c = 40
        );
        insert assessment;
        assessment.Final_Risk_Score__c = 55;
        assessment.Risk_Category__c = 'High';
        Test.startTest();
        update assessment;
        Test.stopTest();
        Integer historyCount = [
            SELECT COUNT()
            FROM Loan_Application_History__c
            WHERE Loan_Application__c = :loanAppId
            AND Event_Type__c = 'Risk Score Updated'
        ];
        System.assert(historyCount > 0, 'Risk update history expected');
    }
}
