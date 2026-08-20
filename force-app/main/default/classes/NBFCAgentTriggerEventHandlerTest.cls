@isTest
private class NBFCAgentTriggerEventHandlerTest {
    @isTest
    static void testStartAllAgentsEvent() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        Loan_Application__c app = NBFC_TestDataFactory.createLoanApplication(applicant, product, 'Submitted');

        NBFC_Agent_Trigger__e evt = new NBFC_Agent_Trigger__e(
            Loan_Application_Id__c = String.valueOf(app.Id),
            Event_Action__c = AgentEventPublisher.ACTION_START_ALL_AGENTS,
            Triggered_At__c = DateTime.now()
        );

        Test.startTest();
        NBFCAgentTriggerEventHandler.handleEvents(new List<NBFC_Agent_Trigger__e>{ evt });
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Agent_Check_Result__c WHERE Loan_Application__c = :app.Id] >= 5,
            'Agent stub records should be created'
        );
    }
}
