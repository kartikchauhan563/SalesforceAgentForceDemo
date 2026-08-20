public with sharing class NBFCFlowAction_GetFoirPolicy {
    @InvocableMethod(label='Get FOIR Policy' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetFoirPolicyResponse> run(
        List<NBFCAgentFlowService.GetFoirPolicyRequest> requests
    ) {
        return NBFCAgentFlowService.getFoirPolicy(requests);
    }
}