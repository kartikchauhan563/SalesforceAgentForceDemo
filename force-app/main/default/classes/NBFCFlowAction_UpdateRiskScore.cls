public with sharing class NBFCFlowAction_UpdateRiskScore {
    @InvocableMethod(label='Update Risk Score' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.UpdateRiskScoreResponse> run(
        List<NBFCAgentFlowService.UpdateRiskScoreRequest> requests
    ) {
        return NBFCAgentFlowService.updateRiskScore(requests);
    }
}