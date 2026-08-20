public with sharing class NBFCFlowAction_GetAllComplianceRules {
    @InvocableMethod(label='Get All Compliance Rules' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetAllComplianceRulesResponse> run(
        List<NBFCAgentFlowService.GetAllComplianceRulesRequest> requests
    ) {
        return NBFCAgentFlowService.getAllComplianceRules(requests);
    }
}