@isTest
private class LoanApplicationHistoryTriggerHandlerTest {
    @isTest
    static void testBeforeInsertDefaults() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        Loan_Application__c app = NBFC_TestDataFactory.createLoanApplication(applicant, product, 'Draft');

        Loan_Application_History__c hist = new Loan_Application_History__c(
            Loan_Application__c = app.Id,
            Event_Type__c = 'Application Created',
            Triggered_By__c = 'User'
        );
        insert hist;

        hist = [
            SELECT Event_Timestamp__c, Session_ID__c, Compliance_Relevant__c
            FROM Loan_Application_History__c
            WHERE Id = :hist.Id
        ];
        System.assertNotEquals(null, hist.Event_Timestamp__c);
        System.assertEquals(true, hist.Compliance_Relevant__c);
    }

    @isTest
    static void testFutureTimestampBlocked() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        Loan_Application__c app = NBFC_TestDataFactory.createLoanApplication(applicant, product, 'Draft');

        Loan_Application_History__c hist = new Loan_Application_History__c(
            Loan_Application__c = app.Id,
            Event_Type__c = 'Field Modified',
            Triggered_By__c = 'User',
            Event_Timestamp__c = DateTime.now().addDays(1)
        );
        Boolean failed = false;
        try {
            insert hist;
        } catch (DmlException ex) {
            failed = true;
        }
        System.assert(failed, 'Future timestamp should be blocked');
    }
}
