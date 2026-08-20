public with sharing class NBFCFlowAction_GetRequiredDocuments {
    @InvocableMethod(label='Get Required Documents' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetRequiredDocumentsResponse> run(
        List<NBFCAgentFlowService.GetRequiredDocumentsRequest> requests
    ) {
        return NBFCAgentFlowService.getRequiredDocuments(requests);
    }
}