public with sharing class NBFCFlowAction_GetRiskAssessment {
    @InvocableMethod(label='Get Risk Assessment' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetRiskAssessmentResponse> run(
        List<NBFCAgentFlowService.GetRiskAssessmentRequest> requests
    ) {
        return NBFCAgentFlowService.getRiskAssessment(requests);
    }
}