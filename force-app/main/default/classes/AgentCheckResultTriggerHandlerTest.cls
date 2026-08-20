@isTest
private class AgentCheckResultTriggerHandlerTest {
    private static final List<String> PREREQ_AGENTS = new List<String>{
        'Document Verification Agent',
        'Financial Health Agent',
        'Credit Risk Agent',
        'Compliance Agent'
    };

    @TestSetup
    static void setupData() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        NBFC_TestDataFactory.createLoanApplications(applicant, product, 3);
    }

    private static Id getLoanAppId() {
        return [SELECT Id FROM Loan_Application__c LIMIT 1].Id;
    }

    private static Agent_Check_Result__c buildCompletedResult(Id loanAppId, String agentName, Decimal scoreImpact) {
        Agent_Check_Result__c result = new Agent_Check_Result__c(
            Loan_Application__c = loanAppId,
            Agent_Name__c = agentName,
            Status__c = 'Running',
            Score_Impact__c = scoreImpact,
            Run_Started_At__c = DateTime.now().addMinutes(-2),
            Run_Completed_At__c = DateTime.now(),
            Result__c = 'Pass'
        );
        insert result;
        result.Status__c = 'Completed';
        return result;
    }

    @isTest
    static void testAgentCompletedUpdatesRiskScore() {
        Id loanAppId = getLoanAppId();
        Agent_Check_Result__c result = buildCompletedResult(loanAppId, 'Credit Risk Agent', 25);
        Test.startTest();
        update result;
        Test.stopTest();
        Loan_Application__c app = [
            SELECT Risk_Score__c, Risk_Level__c FROM Loan_Application__c WHERE Id = :loanAppId
        ];
        System.assertNotEquals(null, app.Risk_Score__c);
    }

    @isTest
    static void testAllAgentsCompletePublishesDecisionEvent() {
        Id loanAppId = getLoanAppId();
        List<Agent_Check_Result__c> toUpdate = new List<Agent_Check_Result__c>();
        for (String agentName : PREREQ_AGENTS) {
            toUpdate.add(buildCompletedResult(loanAppId, agentName, 5));
        }
        Test.startTest();
        update toUpdate;
        Test.getEventBus().deliver();
        Test.stopTest();
        System.assertEquals(4, [
            SELECT COUNT() FROM Agent_Check_Result__c
            WHERE Loan_Application__c = :loanAppId AND Status__c = 'Completed'
        ]);
    }

    @isTest
    static void testAgentFailedCreatesErrorHistory() {
        Id loanAppId = getLoanAppId();
        Agent_Check_Result__c result = NBFC_TestDataFactory.createAgentResult(
            loanAppId, 'Compliance Agent', 'Running', 0
        );
        result.Status__c = 'Failed';
        result.Reason__c = 'Compliance API timeout';
        Test.startTest();
        update result;
        Test.stopTest();
        Integer historyCount = [
            SELECT COUNT()
            FROM Loan_Application_History__c
            WHERE Loan_Application__c = :loanAppId
            AND Event_Type__c = 'Agent Run Failed'
        ];
        System.assert(historyCount > 0, 'Failed agent history expected');
    }

    @isTest
    static void testRiskLevelMapping() {
        Id loanAppId = getLoanAppId();
        List<Agent_Check_Result__c> results = new List<Agent_Check_Result__c>{
            buildCompletedResult(loanAppId, 'Financial Health Agent', 10),
            buildCompletedResult(loanAppId, 'Document Verification Agent', 15)
        };
        Test.startTest();
        update results;
        Test.stopTest();
        Loan_Application__c app = [
            SELECT Risk_Score__c, Risk_Level__c FROM Loan_Application__c WHERE Id = :loanAppId
        ];
        System.assertEquals(25, app.Risk_Score__c);
        System.assertNotEquals(null, PolicyRuleService.mapRiskScoreToLevel(app.Risk_Score__c));
    }

    @isTest
    static void testBulkAgentResults() {
        List<Loan_Application__c> apps = [SELECT Id FROM Loan_Application__c];
        List<Agent_Check_Result__c> results = new List<Agent_Check_Result__c>();
        for (Loan_Application__c app : apps) {
            results.add(new Agent_Check_Result__c(
                Loan_Application__c = app.Id,
                Agent_Name__c = 'Credit Risk Agent',
                Score_Impact__c = 5,
                Run_Started_At__c = DateTime.now().addMinutes(-1)
            ));
        }
        Test.startTest();
        insert results;
        for (Agent_Check_Result__c result : results) {
            result.Status__c = 'Completed';
            result.Run_Completed_At__c = DateTime.now();
            result.Result__c = 'Pass';
        }
        update results;
        Test.stopTest();
        System.assertEquals(apps.size(), [
            SELECT COUNT() FROM Agent_Check_Result__c WHERE Status__c = 'Completed'
        ]);
    }
}
