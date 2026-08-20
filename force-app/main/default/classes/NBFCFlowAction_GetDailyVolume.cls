public with sharing class NBFCFlowAction_GetDailyVolume {
    @InvocableMethod(label='Get Daily Volume' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.GetDailyVolumeResponse> run(
        List<NBFCAgentFlowService.GetDailyVolumeRequest> requests
    ) {
        return NBFCAgentFlowService.getDailyVolume(requests);
    }
}