trigger AgentCheckResultTrigger on Agent_Check_Result__c (
    before insert, after insert, after update
) {
    AgentCheckResultTriggerHandler.dispatch(
        Trigger.operationType,
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap
    );
}
