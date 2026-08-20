@isTest
private class LoanApplicationHistoryHandlerTest {
    @isTest
    static void testCreateHistoryRecordsBulk() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        Loan_Application__c app = NBFC_TestDataFactory.createLoanApplication(applicant, product, 'Draft');

        LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
        req.loanApplicationId = app.Id;
        req.eventType = 'Application Created';
        req.triggeredBy = 'User';
        Test.startTest();
        LoanApplicationHistoryHandler.createHistoryRecords(new List<LoanApplicationHistoryHandler.HistoryRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Loan_Application_History__c WHERE Loan_Application__c = :app.Id]);
    }

    @isTest
    static void testCreateSingleHistoryAndAudit() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        Loan_Application__c app = NBFC_TestDataFactory.createLoanApplication(applicant, product, 'Draft');

        Test.startTest();
        LoanApplicationHistoryHandler.createSingleHistory(
            app.Id,
            'Application Status Changed',
            'User',
            new Map<String, Object>{ 'New_Status__c' => 'Submitted' }
        );
        LoanApplicationHistoryHandler.createSingleAuditLog(
            app.Id,
            'Status Changed',
            'System',
            new Map<String, Object>{ 'Event_Description__c' => 'Status updated' }
        );
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Loan_Application_History__c WHERE Loan_Application__c = :app.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Audit_Log__c WHERE Loan_Application__c = :app.Id]);
    }
}
