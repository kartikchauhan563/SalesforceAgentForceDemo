public with sharing class NBFCFlowAction_CheckAgentCompletion {
    @InvocableMethod(label='Check Agent Completion' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.CheckAgentCompletionResponse> run(
        List<NBFCAgentFlowService.CheckAgentCompletionRequest> requests
    ) {
        return NBFCAgentFlowService.checkAgentCompletion(requests);
    }
}