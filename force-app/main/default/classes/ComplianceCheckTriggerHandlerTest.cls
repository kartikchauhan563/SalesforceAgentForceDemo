@isTest
private class ComplianceCheckTriggerHandlerTest {
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
    static void testViolationFoundCreatesHistory() {
        Id loanAppId = getLoanAppId();
        Compliance_Check__c check = new Compliance_Check__c(
            Loan_Application__c = loanAppId,
            Rule_Name__c = 'KYC_INCOMPLETE',
            Status__c = 'Non-Compliant',
            Severity__c = 'High',
            Checked_At__c = DateTime.now()
        );
        Test.startTest();
        insert check;
        Test.stopTest();
        Integer historyCount = [
            SELECT COUNT()
            FROM Loan_Application_History__c
            WHERE Loan_Application__c = :loanAppId
            AND Event_Type__c = 'Compliance Violation Found'
        ];
        System.assert(historyCount > 0, 'Violation history expected');
    }

    @isTest
    static void testViolationResolvedCreatesHistory() {
        Id loanAppId = getLoanAppId();
        Compliance_Check__c check = new Compliance_Check__c(
            Loan_Application__c = loanAppId,
            Rule_Name__c = 'AML_SCREEN',
            Status__c = 'Non-Compliant',
            Severity__c = 'Medium',
            Resolved__c = false,
            Checked_At__c = DateTime.now()
        );
        insert check;
        check.Resolved__c = true;
        Test.startTest();
        update check;
        Test.stopTest();
        Integer historyCount = [
            SELECT COUNT()
            FROM Loan_Application_History__c
            WHERE Loan_Application__c = :loanAppId
            AND Event_Type__c = 'Compliance Violation Resolved'
        ];
        System.assert(historyCount > 0, 'Resolved violation history expected');
    }

    @isTest
    static void testCriticalViolationUpdatesParentStatus() {
        Id loanAppId = getLoanAppId();
        Compliance_Check__c check = new Compliance_Check__c(
            Loan_Application__c = loanAppId,
            Rule_Name__c = 'CRITICAL_KYC_FAIL',
            Status__c = 'Non-Compliant',
            Severity__c = 'Critical',
            Checked_At__c = DateTime.now()
        );
        Test.startTest();
        insert check;
        Test.stopTest();
        Loan_Application__c app = [
            SELECT Sub_Status__c FROM Loan_Application__c WHERE Id = :loanAppId
        ];
        System.assertEquals('KYC Pending', app.Sub_Status__c);
    }
}
