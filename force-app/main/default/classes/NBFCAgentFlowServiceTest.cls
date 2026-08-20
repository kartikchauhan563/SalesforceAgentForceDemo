/**
 * Tests for NBFCAgentFlowService invocable methods used by Agentforce flows.
 */
@isTest
private class NBFCAgentFlowServiceTest {
    @TestSetup
    static void setup() {
        Account applicant = NBFC_TestDataFactory.createPersonAccount();
        Loan_Product__c product = NBFC_TestDataFactory.createLoanProduct();
        Loan_Application__c app = NBFC_TestDataFactory.createLoanApplication(applicant, product, 'Under Review');
        NBFC_TestDataFactory.createDocument(app.Id, 'PAN Card', true);
        NBFC_TestDataFactory.createAgentResult(app.Id, 'Document Verification Agent', 'Completed', 5);
        NBFC_TestDataFactory.createAgentResult(app.Id, 'Financial Health Agent', 'Completed', 3);
        insert new Risk_Assessment__c(
            Loan_Application__c = app.Id,
            Bureau_Score__c = 720,
            Fraud_Score__c = 10,
            Final_Risk_Score__c = 25
        );
    }

    private static Id loanAppId() {
        return [SELECT Id FROM Loan_Application__c LIMIT 1].Id;
    }

    @isTest
    static void testGetLoanApplicationDetails() {
        Loan_Application__c app = [SELECT Id, Name FROM Loan_Application__c LIMIT 1];
        NBFCAgentFlowService.GetLoanApplicationDetailsRequest req =
            new NBFCAgentFlowService.GetLoanApplicationDetailsRequest();
        req.loanApplicationId = app.Id;
        List<NBFCAgentFlowService.GetLoanApplicationDetailsResponse> results =
            NBFCAgentFlowService.getLoanApplicationDetails(new List<NBFCAgentFlowService.GetLoanApplicationDetailsRequest>{ req });
        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].recordFound);
        req.loanApplicationId = app.Name;
        results = NBFCAgentFlowService.getLoanApplicationDetails(new List<NBFCAgentFlowService.GetLoanApplicationDetailsRequest>{ req });
        System.assertEquals(true, results[0].recordFound);
    }

    @isTest
    static void testSearchApplicationsByName() {
        NBFCAgentFlowService.SearchApplicationsByNameRequest req =
            new NBFCAgentFlowService.SearchApplicationsByNameRequest();
        req.applicantNameSearch = 'Test';
        List<NBFCAgentFlowService.SearchApplicationsByNameResponse> results =
            NBFCAgentFlowService.searchApplicationsByName(new List<NBFCAgentFlowService.SearchApplicationsByNameRequest>{ req });
        System.assertEquals(1, results.size());
    }

    @isTest
    static void testGetFinancialDataAndPolicies() {
        Id appId = loanAppId();
        NBFCAgentFlowService.GetFinancialDataRequest finReq = new NBFCAgentFlowService.GetFinancialDataRequest();
        finReq.loanApplicationId = appId;
        System.assert(NBFCAgentFlowService.getFinancialData(new List<NBFCAgentFlowService.GetFinancialDataRequest>{ finReq })[0].recordFound);

        Loan_Product__c product = [SELECT Product_Code__c FROM Loan_Product__c LIMIT 1];
        NBFCAgentFlowService.GetFoirPolicyRequest foirReq = new NBFCAgentFlowService.GetFoirPolicyRequest();
        foirReq.productCode = product.Product_Code__c;
        NBFCAgentFlowService.getFoirPolicy(new List<NBFCAgentFlowService.GetFoirPolicyRequest>{ foirReq });

        NBFCAgentFlowService.GetCreditScorePolicyRequest scoreReq = new NBFCAgentFlowService.GetCreditScorePolicyRequest();
        scoreReq.productCode = product.Product_Code__c;
        NBFCAgentFlowService.getCreditScorePolicy(new List<NBFCAgentFlowService.GetCreditScorePolicyRequest>{ scoreReq });
    }

    @isTest
    static void testAgentAndComplianceFlows() {
        Id appId = loanAppId();
        NBFCAgentFlowService.CheckAgentCompletionRequest checkReq = new NBFCAgentFlowService.CheckAgentCompletionRequest();
        checkReq.loanApplicationId = appId;
        NBFCAgentFlowService.checkAgentCompletion(new List<NBFCAgentFlowService.CheckAgentCompletionRequest>{ checkReq });

        NBFCAgentFlowService.GetAllAgentResultsRequest resultsReq = new NBFCAgentFlowService.GetAllAgentResultsRequest();
        resultsReq.loanApplicationId = appId;
        NBFCAgentFlowService.getAllAgentResults(new List<NBFCAgentFlowService.GetAllAgentResultsRequest>{ resultsReq });

        NBFCAgentFlowService.getAllComplianceRules(new List<NBFCAgentFlowService.GetAllComplianceRulesRequest>{
            new NBFCAgentFlowService.GetAllComplianceRulesRequest()
        });

        NBFCAgentFlowService.GetExistingComplianceChecksRequest ccReq =
            new NBFCAgentFlowService.GetExistingComplianceChecksRequest();
        ccReq.loanApplicationId = appId;
        NBFCAgentFlowService.getExistingComplianceChecks(new List<NBFCAgentFlowService.GetExistingComplianceChecksRequest>{ ccReq });
    }

    @isTest
    static void testUpdateAndFlagFlows() {
        Id appId = loanAppId();
        NBFCAgentFlowService.UpdateMissingDocumentsRequest updReq = new NBFCAgentFlowService.UpdateMissingDocumentsRequest();
        updReq.loanApplicationId = appId;
        updReq.missingDocumentsList = 'PAN Card';
        System.assert(NBFCAgentFlowService.updateMissingDocuments(new List<NBFCAgentFlowService.UpdateMissingDocumentsRequest>{ updReq })[0].success);

        NBFCAgentFlowService.FlagForFraudReviewRequest fraudReq = new NBFCAgentFlowService.FlagForFraudReviewRequest();
        fraudReq.loanApplicationId = appId;
        fraudReq.fraudScore = 85;
        fraudReq.fraudThreshold = 50;
        NBFCAgentFlowService.flagForFraudReview(new List<NBFCAgentFlowService.FlagForFraudReviewRequest>{ fraudReq });

        NBFCAgentFlowService.UpdateRiskScoreRequest riskReq = new NBFCAgentFlowService.UpdateRiskScoreRequest();
        riskReq.loanApplicationId = appId;
        riskReq.scoreToAdd = 5;
        NBFCAgentFlowService.updateRiskScore(new List<NBFCAgentFlowService.UpdateRiskScoreRequest>{ riskReq });
    }

    @isTest
    static void testReportingAndPlatformEvent() {
        NBFCAgentFlowService.getPortfolioSummary(new List<NBFCAgentFlowService.GetPortfolioSummaryRequest>{
            new NBFCAgentFlowService.GetPortfolioSummaryRequest()
        });
        NBFCAgentFlowService.getRiskDistribution(new List<NBFCAgentFlowService.GetRiskDistributionRequest>{
            new NBFCAgentFlowService.GetRiskDistributionRequest()
        });
        NBFCAgentFlowService.getAgentPerformance(new List<NBFCAgentFlowService.GetAgentPerformanceRequest>{
            new NBFCAgentFlowService.GetAgentPerformanceRequest()
        });
        NBFCAgentFlowService.getMissingDocumentsReport(new List<NBFCAgentFlowService.GetMissingDocumentsReportRequest>{
            new NBFCAgentFlowService.GetMissingDocumentsReportRequest()
        });
        NBFCAgentFlowService.getDailyVolume(new List<NBFCAgentFlowService.GetDailyVolumeRequest>{
            new NBFCAgentFlowService.GetDailyVolumeRequest()
        });

        NBFCAgentFlowService.PublishAgentPlatformEventRequest peReq = new NBFCAgentFlowService.PublishAgentPlatformEventRequest();
        peReq.loanApplicationId = loanAppId();
        peReq.eventAction = 'START_ALL_AGENTS';
        Test.startTest();
        NBFCAgentFlowService.publishAgentPlatformEvent(new List<NBFCAgentFlowService.PublishAgentPlatformEventRequest>{ peReq });
        Test.stopTest();
    }
}
