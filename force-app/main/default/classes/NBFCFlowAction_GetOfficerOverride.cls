public with sharing class NBFCFlowAction_GetOfficerOverride {
    @InvocableMethod(label='Get Officer Override Report' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetOfficerOverrideReportResponse> run(
        List<NBFCAgentFlowService.GetOfficerOverrideReportRequest> requests
    ) {
        return NBFCAgentFlowService.getOfficerOverrideReport(requests);
    }
}