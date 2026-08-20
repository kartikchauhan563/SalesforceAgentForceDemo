public with sharing class NBFCFlowAction_GetComplianceSummary {
    @InvocableMethod(label='Get Compliance Summary' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetComplianceSummaryResponse> run(
        List<NBFCAgentFlowService.GetComplianceSummaryRequest> requests
    ) {
        return NBFCAgentFlowService.getComplianceSummary(requests);
    }
}