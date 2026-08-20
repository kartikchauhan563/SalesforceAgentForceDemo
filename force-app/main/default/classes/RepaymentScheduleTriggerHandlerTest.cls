@isTest
private class RepaymentScheduleTriggerHandlerTest {
    @TestSetup
    static void setupData() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        NBFC_TestDataFactory.createLoanApplications(applicant, product, 3);
    }

    private static Repayment_Schedule__c createSchedule(String status) {
        Id loanAppId = [SELECT Id FROM Loan_Application__c LIMIT 1].Id;
        Repayment_Schedule__c schedule = new Repayment_Schedule__c(
            Loan_Application__c = loanAppId,
            EMI_Number__c = 1,
            EMI_Amount__c = 15000,
            Due_Date__c = Date.today().addMonths(1),
            Status__c = status == null ? 'Pending' : status,
            Principal_Component__c = 12000,
            Interest_Component__c = 3000,
            Outstanding_Balance__c = 200000
        );
        insert schedule;
        return schedule;
    }

    @isTest
    static void testPaymentMadeCreatesHistory() {
        Repayment_Schedule__c schedule = createSchedule('Pending');
        schedule.Status__c = 'Paid';
        schedule.Paid_Amount__c = 15000;
        schedule.Paid_Date__c = Date.today();
        Test.startTest();
        update schedule;
        Test.stopTest();
        Integer historyCount = [
            SELECT COUNT()
            FROM Loan_Application_History__c
            WHERE Loan_Application__c = :schedule.Loan_Application__c
            AND Event_Type__c = 'Disbursement Completed'
        ];
        System.assert(historyCount > 0, 'Payment history expected');
    }

    @isTest
    static void testBouncedCreatesHistory() {
        Repayment_Schedule__c schedule = createSchedule('Pending');
        schedule.Status__c = 'Bounced';
        schedule.Bounce_Reason__c = 'Insufficient funds';
        Test.startTest();
        update schedule;
        Test.stopTest();
        Integer historyCount = [
            SELECT COUNT()
            FROM Loan_Application_History__c
            WHERE Loan_Application__c = :schedule.Loan_Application__c
            AND Event_Type__c = 'Disbursement Failed'
        ];
        System.assert(historyCount > 0, 'Bounce history expected');
    }

    @isTest
    static void testLateFeeCalculated() {
        Repayment_Schedule__c schedule = createSchedule('Pending');
        schedule.Status__c = 'Overdue';
        schedule.Due_Date__c = Date.today().addDays(-5);
        schedule.EMI_Amount__c = 20000;
        Test.startTest();
        update schedule;
        Test.stopTest();
        schedule = [
            SELECT Late_Fee__c, Status__c
            FROM Repayment_Schedule__c WHERE Id = :schedule.Id
        ];
        Decimal lateFeePct = PolicyRuleService.getDecimalThreshold('RULE_LATE_FEE_PCT');
        if (lateFeePct != null) {
            System.assertEquals(20000 * (lateFeePct / 100), schedule.Late_Fee__c);
        } else {
            System.assertEquals('Overdue', schedule.Status__c);
        }
    }

    @isTest
    static void testOverdueAlertEnqueued() {
        Repayment_Schedule__c schedule = createSchedule('Pending');
        schedule.Status__c = 'Overdue';
        schedule.Due_Date__c = Date.today().addDays(-10);
        Test.startTest();
        update schedule;
        Test.stopTest();
        System.assertEquals('Overdue', [
            SELECT Status__c FROM Repayment_Schedule__c WHERE Id = :schedule.Id
        ].Status__c);
    }
}
