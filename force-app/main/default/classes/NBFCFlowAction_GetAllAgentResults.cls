public with sharing class NBFCFlowAction_GetAllAgentResults {
    @InvocableMethod(label='Get All Agent Results' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetAllAgentResultsResponse> run(
        List<NBFCAgentFlowService.GetAllAgentResultsRequest> requests
    ) {
        return NBFCAgentFlowService.getAllAgentResults(requests);
    }
}