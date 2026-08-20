public with sharing class NBFCFlowAction_GetLoanDecision {
    @InvocableMethod(label='Get Loan Decision' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetLoanDecisionResponse> run(
        List<NBFCAgentFlowService.GetLoanDecisionRequest> requests
    ) {
        return NBFCAgentFlowService.getLoanDecision(requests);
    }
}