public with sharing class NBFCFlowAction_GetRiskDistribution {
    @InvocableMethod(label='Get Risk Distribution' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetRiskDistributionResponse> run(
        List<NBFCAgentFlowService.GetRiskDistributionRequest> requests
    ) {
        return NBFCAgentFlowService.getRiskDistribution(requests);
    }
}