public with sharing class NBFCFlowAction_GetAgentPerformance {
    @InvocableMethod(label='Get Agent Performance' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetAgentPerformanceResponse> run(
        List<NBFCAgentFlowService.GetAgentPerformanceRequest> requests
    ) {
        return NBFCAgentFlowService.getAgentPerformance(requests);
    }
}