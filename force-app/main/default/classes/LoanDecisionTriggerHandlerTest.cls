@isTest
private class LoanDecisionTriggerHandlerTest {
    @TestSetup
    static void setupData() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        NBFC_TestDataFactory.createLoanApplications(applicant, product, 3);
        Loan_Application__c app = [
            SELECT Id FROM Loan_Application__c LIMIT 1
        ];
        app.Status__c = 'Under Review';
        update app;
    }

    private static Id getLoanAppId() {
        return [SELECT Id FROM Loan_Application__c LIMIT 1].Id;
    }

    private static Loan_Decision__c buildDecision(String recommendation) {
        return new Loan_Decision__c(
            Loan_Application__c = getLoanAppId(),
            Recommendation__c = recommendation,
            Confidence_Score__c = 88,
            Key_Reasons__c = 'Test decision reasons',
            Decision_Summary__c = 'Automated test decision',
            Missing_Paperwork__c = 'None',
            Next_Best_Action__c = 'Review terms'
        );
    }

    @isTest
    static void testDecisionSyncsToParent() {
        Loan_Decision__c decision = buildDecision('Approve');
        Test.startTest();
        insert decision;
        Test.stopTest();
        Loan_Application__c app = [
            SELECT Final_Recommendation__c, AI_Confidence__c, All_Agents_Completed__c
            FROM Loan_Application__c WHERE Id = :decision.Loan_Application__c
        ];
        System.assertEquals('Approve', app.Final_Recommendation__c);
        System.assertEquals(88, app.AI_Confidence__c);
        System.assertEquals(true, app.All_Agents_Completed__c);
    }

    @isTest
    static void testApproveUpdatesParentStatus() {
        Id loanAppId = getLoanAppId();
        Loan_Decision__c decision = buildDecision('Approve');
        Test.startTest();
        insert decision;
        Test.stopTest();
        Loan_Application__c app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :loanAppId];
        System.assertEquals('Approved', app.Status__c);
    }

    @isTest
    static void testRejectUpdatesParentStatus() {
        Id loanAppId = getLoanAppId();
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c WHERE Id = :loanAppId];
        app.Status__c = 'Under Review';
        update app;
        Loan_Decision__c decision = buildDecision('Reject');
        Test.startTest();
        insert decision;
        Test.stopTest();
        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :loanAppId];
        System.assertEquals('Rejected', app.Status__c);
    }

    @isTest
    static void testHoldUpdatesParentStatus() {
        Id loanAppId = getLoanAppId();
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c WHERE Id = :loanAppId];
        app.Status__c = 'Under Review';
        update app;
        Loan_Decision__c decision = buildDecision('Hold');
        Test.startTest();
        insert decision;
        Test.stopTest();
        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :loanAppId];
        System.assertEquals('On Hold', app.Status__c);
    }

    @isTest
    static void testOfficerOverrideApprove() {
        Loan_Decision__c decision = buildDecision('Hold');
        insert decision;
        decision.Officer_Decision__c = 'Override Approve';
        decision.Officer_Comments__c = 'Strong repayment capacity';
        Test.startTest();
        update decision;
        Test.stopTest();
        Loan_Application__c app = [
            SELECT Status__c, Final_Recommendation__c
            FROM Loan_Application__c WHERE Id = :decision.Loan_Application__c
        ];
        System.assertEquals('Approved', app.Status__c);
        System.assertEquals('Approve', app.Final_Recommendation__c);
    }

    @isTest
    static void testOfficerOverrideReject() {
        Loan_Decision__c decision = buildDecision('Approve');
        insert decision;
        decision.Officer_Decision__c = 'Override Reject';
        decision.Officer_Comments__c = 'Income verification failed';
        Test.startTest();
        update decision;
        Test.stopTest();
        Loan_Application__c app = [
            SELECT Status__c, Final_Recommendation__c
            FROM Loan_Application__c WHERE Id = :decision.Loan_Application__c
        ];
        System.assertEquals('Rejected', app.Status__c);
        System.assertEquals('Reject', app.Final_Recommendation__c);
    }

    @isTest
    static void testHistoryCreatedOnDecision() {
        Id loanAppId = getLoanAppId();
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c WHERE Id = :loanAppId];
        app.Status__c = 'Under Review';
        update app;
        Loan_Decision__c decision = buildDecision('Approve');
        Test.startTest();
        insert decision;
        Test.stopTest();
        Integer historyCount = [
            SELECT COUNT()
            FROM Loan_Application_History__c
            WHERE Loan_Application__c = :loanAppId
            AND Event_Type__c = 'Loan Decision Generated'
        ];
        System.assert(historyCount > 0, 'Decision history expected');
    }
}
