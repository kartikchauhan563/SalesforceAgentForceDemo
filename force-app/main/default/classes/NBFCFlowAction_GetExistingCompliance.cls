public with sharing class NBFCFlowAction_GetExistingCompliance {
    @InvocableMethod(label='Get Existing Compliance Checks' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetExistingComplianceChecksResponse> run(
        List<NBFCAgentFlowService.GetExistingComplianceChecksRequest> requests
    ) {
        return NBFCAgentFlowService.getExistingComplianceChecks(requests);
    }
}