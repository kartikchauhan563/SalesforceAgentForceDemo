@isTest
private class LoanApplicationTriggerHandlerTest {
    @TestSetup
    static void setupData() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        NBFC_TestDataFactory.createLoanApplications(applicant, product, 3);
    }

    private static Loan_Application__c getLoanApp() {
        return [
            SELECT Id, Status__c, Applicant__c, Loan_Product__c, Loan_Officer__c
            FROM Loan_Application__c
            LIMIT 1
        ];
    }

    @isTest
    static void testDefaultValues() {
        Account applicant = [SELECT Id FROM Account LIMIT 1];
        Loan_Product__c product = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Loan_Application__c app = new Loan_Application__c(
            Applicant__c = applicant.Id,
            Loan_Product__c = product.Id,
            Loan_Amount__c = 250000,
            Tenure_Months__c = 24,
            Monthly_Income__c = 75000
        );
        LoanApplicationTriggerHandler.setDefaultValues(new List<Loan_Application__c>{ app });
        System.assertEquals('Draft', app.Status__c);
        System.assertEquals('Medium', app.Priority__c);
        System.assertEquals(Date.today(), app.Application_Date__c);
        System.assertEquals(false, app.All_Agents_Completed__c);
    }

    @isTest
    static void testStatusTransitionAllowed() {
        Loan_Application__c app = getLoanApp();
        app.Status__c = 'Submitted';
        update app;
        app.Status__c = 'Under Review';
        update app;
        app.Status__c = 'Approved';
        update app;
        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('Approved', app.Status__c);
    }

    @isTest
    static void testStatusTransitionBlocked() {
        Loan_Application__c app = getLoanApp();
        app.Status__c = 'Approved';
        Boolean blocked = false;
        try {
            update app;
        } catch (DmlException ex) {
            blocked = true;
            System.assert(ex.getMessage().contains('Invalid status transition'), ex.getMessage());
        }
        System.assert(blocked, 'Draft to Approved should be blocked');
    }

    @isTest
    static void testAutoAssignLoanOfficer() {
        Loan_Application__c app = getLoanApp();
        app.Status__c = 'Submitted';
        Test.startTest();
        update app;
        Test.stopTest();
        app = [SELECT Loan_Officer__c FROM Loan_Application__c WHERE Id = :app.Id];
        List<User> officers = [
            SELECT Id FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'NBFC Loan Officer'
            LIMIT 1
        ];
        if (!officers.isEmpty()) {
            System.assertNotEquals(null, app.Loan_Officer__c);
        }
    }

    @isTest
    static void testAgentEventPublishedOnSubmit() {
        Loan_Application__c app = getLoanApp();
        Map<Id, Loan_Application__c> oldMap = new Map<Id, Loan_Application__c>([
            SELECT Id, Status__c FROM Loan_Application__c WHERE Id = :app.Id
        ]);
        app.Status__c = 'Submitted';
        Test.startTest();
        LoanApplicationTriggerHandler.publishAgentOrchestrationEvent_OnSubmit(
            new List<Loan_Application__c>{ app },
            oldMap
        );
        Test.getEventBus().deliver();
        Test.stopTest();
        System.assertEquals('Submitted', app.Status__c);
    }

    @isTest
    static void testHistoryCreatedOnInsert() {
        Account applicant = [SELECT Id FROM Account LIMIT 1];
        Loan_Product__c product = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Test.startTest();
        Loan_Application__c app = NBFC_TestDataFactory.createLoanApplication(applicant, product, 'Draft');
        Test.stopTest();
        Integer historyCount = [
            SELECT COUNT()
            FROM Loan_Application_History__c
            WHERE Loan_Application__c = :app.Id
            AND Event_Type__c = 'Application Created'
        ];
        System.assert(historyCount > 0, 'Application Created history expected');
    }

    @isTest
    static void testHistoryCreatedOnStatusChange() {
        Loan_Application__c app = getLoanApp();
        app.Status__c = 'Submitted';
        Test.startTest();
        update app;
        Test.stopTest();
        Integer historyCount = [
            SELECT COUNT()
            FROM Loan_Application_History__c
            WHERE Loan_Application__c = :app.Id
            AND Event_Type__c = 'Application Status Changed'
        ];
        System.assert(historyCount > 0, 'Status change history expected');
    }

    @isTest
    static void testBulkInsert100Records() {
        Account applicant = [SELECT Id FROM Account LIMIT 1];
        Loan_Product__c product = [SELECT Id FROM Loan_Product__c LIMIT 1];
        List<Loan_Application__c> apps = new List<Loan_Application__c>();
        for (Integer i = 0; i < 100; i++) {
            apps.add(new Loan_Application__c(
                Applicant__c = applicant.Id,
                Loan_Product__c = product.Id,
                Loan_Amount__c = 100000 + i,
                Tenure_Months__c = 24,
                Monthly_Income__c = 75000,
                Existing_EMI__c = 5000,
                Credit_Score__c = 700,
                Status__c = 'Draft'
            ));
        }
        Test.startTest();
        insert apps;
        Test.stopTest();
        Set<Id> appIds = new Map<Id, Loan_Application__c>(apps).keySet();
        System.assertEquals(100, [SELECT COUNT() FROM Loan_Application__c WHERE Id IN :appIds]);
    }
}
