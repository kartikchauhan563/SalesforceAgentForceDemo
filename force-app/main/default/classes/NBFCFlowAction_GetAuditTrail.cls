public with sharing class NBFCFlowAction_GetAuditTrail {
    @InvocableMethod(label='Get Audit Trail' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetAuditTrailResponse> run(
        List<NBFCAgentFlowService.GetAuditTrailRequest> requests
    ) {
        return NBFCAgentFlowService.getAuditTrail(requests);
    }
}