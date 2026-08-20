@isTest
private class AuditLogTriggerHandlerTest {
    @isTest
    static void testBeforeInsertDefaults() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        Loan_Application__c app = NBFC_TestDataFactory.createLoanApplication(applicant, product, 'Draft');

        LoanApplicationHistoryHandler.AuditLogRequest req = new LoanApplicationHistoryHandler.AuditLogRequest();
        req.loanApplicationId = app.Id;
        req.eventType = 'Decision Made';
        req.eventSource = 'User';
        req.eventDescription = 'Officer approved loan';
        LoanApplicationHistoryHandler.createAuditRecords(new List<LoanApplicationHistoryHandler.AuditLogRequest>{ req });

        Audit_Log__c log = [
            SELECT Event_Timestamp__c, Severity__c, Compliance_Relevant__c
            FROM Audit_Log__c
            WHERE Loan_Application__c = :app.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, log.Event_Timestamp__c);
        System.assertEquals('Info', log.Severity__c);
        System.assertEquals(true, log.Compliance_Relevant__c);
    }
}
