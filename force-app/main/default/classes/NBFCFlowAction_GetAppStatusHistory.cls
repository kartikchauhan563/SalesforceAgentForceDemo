public with sharing class NBFCFlowAction_GetAppStatusHistory {
    @InvocableMethod(label='Get Application Status History' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetApplicationStatusHistoryResponse> run(
        List<NBFCAgentFlowService.GetApplicationStatusHistoryRequest> requests
    ) {
        return NBFCAgentFlowService.getApplicationStatusHistory(requests);
    }
}