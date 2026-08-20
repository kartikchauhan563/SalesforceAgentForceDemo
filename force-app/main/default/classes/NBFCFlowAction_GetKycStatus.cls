public with sharing class NBFCFlowAction_GetKycStatus {
    @InvocableMethod(label='Get KYC Status' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetKycStatusResponse> run(
        List<NBFCAgentFlowService.GetKycStatusRequest> requests
    ) {
        return NBFCAgentFlowService.getKycStatus(requests);
    }
}