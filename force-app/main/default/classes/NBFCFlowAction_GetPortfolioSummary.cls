public with sharing class NBFCFlowAction_GetPortfolioSummary {
    @InvocableMethod(label='Get Portfolio Summary' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetPortfolioSummaryResponse> run(
        List<NBFCAgentFlowService.GetPortfolioSummaryRequest> requests
    ) {
        return NBFCAgentFlowService.getPortfolioSummary(requests);
    }
}