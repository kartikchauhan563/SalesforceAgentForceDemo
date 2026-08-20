public with sharing class NBFCFlowAction_GetUploadedDocuments {
    @InvocableMethod(label='Get Uploaded Documents' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetUploadedDocumentsResponse> run(
        List<NBFCAgentFlowService.GetUploadedDocumentsRequest> requests
    ) {
        return NBFCAgentFlowService.getUploadedDocuments(requests);
    }
}