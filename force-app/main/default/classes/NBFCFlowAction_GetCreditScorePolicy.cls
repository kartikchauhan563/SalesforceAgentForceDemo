public with sharing class NBFCFlowAction_GetCreditScorePolicy {
    @InvocableMethod(label='Get Credit Score Policy' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetCreditScorePolicyResponse> run(
        List<NBFCAgentFlowService.GetCreditScorePolicyRequest> requests
    ) {
        return NBFCAgentFlowService.getCreditScorePolicy(requests);
    }
}