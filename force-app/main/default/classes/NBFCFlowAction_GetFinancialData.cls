public with sharing class NBFCFlowAction_GetFinancialData {
    @InvocableMethod(label='Get Financial Data' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetFinancialDataResponse> run(
        List<NBFCAgentFlowService.GetFinancialDataRequest> requests
    ) {
        return NBFCAgentFlowService.getFinancialData(requests);
    }
}