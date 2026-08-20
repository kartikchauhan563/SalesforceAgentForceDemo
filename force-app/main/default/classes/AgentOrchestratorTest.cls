@isTest
private class AgentOrchestratorTest {
    private static final Integer EXPECTED_AGENT_COUNT = 5;

    @TestSetup
    static void setupData() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        NBFC_TestDataFactory.createLoanApplications(applicant, product, 3);
    }

    private static List<Id> getLoanAppIds() {
        List<Id> ids = new List<Id>();
        for (Loan_Application__c app : [SELECT Id FROM Loan_Application__c]) {
            ids.add(app.Id);
        }
        return ids;
    }

    @isTest
    static void testAllAgentsEnqueued() {
        Id loanAppId = [SELECT Id FROM Loan_Application__c LIMIT 1].Id;
        Test.startTest();
        AgentOrchestrator.runAllAgents(new List<Id>{ loanAppId });
        Test.stopTest();
        Integer stubCount = [
            SELECT COUNT()
            FROM Agent_Check_Result__c
            WHERE Loan_Application__c = :loanAppId
        ];
        System.assertEquals(EXPECTED_AGENT_COUNT, stubCount);
    }

    @isTest
    static void testQueueableChaining() {
        Id loanAppId = [SELECT Id FROM Loan_Application__c LIMIT 1].Id;
        Test.startTest();
        AgentOrchestrator.runAllAgents(new List<Id>{ loanAppId });
        Test.stopTest();
        List<Agent_Check_Result__c> results = [
            SELECT Agent_Name__c, Status__c
            FROM Agent_Check_Result__c
            WHERE Loan_Application__c = :loanAppId
            ORDER BY Agent_Run_Order__c
        ];
        System.assert(!results.isEmpty(), 'Agent stubs should exist after queueable chain');
    }

    @isTest
    static void testAgentStubRecordsCreated() {
        List<Id> loanAppIds = getLoanAppIds();
        Test.startTest();
        AgentOrchestrator.runAllAgents(loanAppIds);
        Test.stopTest();
        Integer totalStubs = [
            SELECT COUNT() FROM Agent_Check_Result__c
            WHERE Loan_Application__c IN :loanAppIds
        ];
        System.assertEquals(loanAppIds.size() * EXPECTED_AGENT_COUNT, totalStubs);
        List<Agent_Check_Result__c> agentStubs = [
            SELECT Id, Agent_Name__c, Status__c, Agent_Run_Order__c
            FROM Agent_Check_Result__c
            WHERE Loan_Application__c IN :loanAppIds
        ];
        System.assert(agentStubs.size() > 0, 'Agent stub records expected');
    }
}
