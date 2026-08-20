public with sharing class NBFCFlowAction_GetLoanAppDetails {
    @InvocableMethod(label='Get Loan Application Details' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetLoanApplicationDetailsResponse> run(
        List<NBFCAgentFlowService.GetLoanApplicationDetailsRequest> requests
    ) {
        return NBFCAgentFlowService.getLoanApplicationDetails(requests);
    }
}