public with sharing class NBFCFlowAction_FlagForFraudReview {
    @InvocableMethod(label='Flag For Fraud Review' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.FlagForFraudReviewResponse> run(
        List<NBFCAgentFlowService.FlagForFraudReviewRequest> requests
    ) {
        return NBFCAgentFlowService.flagForFraudReview(requests);
    }
}