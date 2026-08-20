public with sharing class NBFCFlowAction_AcceptAiRecommendation {
    @InvocableMethod(label='Accept AI Recommendation' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.AcceptAiRecommendationResponse> run(
        List<NBFCAgentFlowService.AcceptAiRecommendationRequest> requests
    ) {
        return NBFCAgentFlowService.acceptAiRecommendation(requests);
    }
}