public with sharing class NBFCFlowAction_UpdateMissingDocuments {
    @InvocableMethod(label='Update Missing Documents' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.UpdateMissingDocumentsResponse> run(
        List<NBFCAgentFlowService.UpdateMissingDocumentsRequest> requests
    ) {
        return NBFCAgentFlowService.updateMissingDocuments(requests);
    }
}