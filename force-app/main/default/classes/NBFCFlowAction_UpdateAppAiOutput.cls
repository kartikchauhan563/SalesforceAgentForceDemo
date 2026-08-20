public with sharing class NBFCFlowAction_UpdateAppAiOutput {
    @InvocableMethod(label='Update Application AI Output' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.UpdateApplicationAiOutputResponse> run(
        List<NBFCAgentFlowService.UpdateApplicationAiOutputRequest> requests
    ) {
        return NBFCAgentFlowService.updateApplicationAiOutput(requests);
    }
}