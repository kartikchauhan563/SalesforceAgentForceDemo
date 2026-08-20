public with sharing class NBFCFlowAction_EscalateToUnderwriter {
    @InvocableMethod(label='Escalate To Underwriter' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.EscalateToUnderwriterResponse> run(
        List<NBFCAgentFlowService.EscalateToUnderwriterRequest> requests
    ) {
        return NBFCAgentFlowService.escalateToUnderwriter(requests);
    }
}