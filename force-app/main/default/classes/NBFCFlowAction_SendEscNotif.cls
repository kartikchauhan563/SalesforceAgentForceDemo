public with sharing class NBFCFlowAction_SendEscNotif {
    @InvocableMethod(label='Send Escalation Notification' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.SendEscalationNotificationResponse> run(
        List<NBFCAgentFlowService.SendEscalationNotificationRequest> requests
    ) {
        return NBFCAgentFlowService.sendEscalationNotification(requests);
    }
}