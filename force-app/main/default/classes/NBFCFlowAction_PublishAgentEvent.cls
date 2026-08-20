public with sharing class NBFCFlowAction_PublishAgentEvent {
    @InvocableMethod(label='Publish Agent Platform Event' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.PublishAgentPlatformEventResponse> run(
        List<NBFCAgentFlowService.PublishAgentPlatformEventRequest> requests
    ) {
        return NBFCAgentFlowService.publishAgentPlatformEvent(requests);
    }
}