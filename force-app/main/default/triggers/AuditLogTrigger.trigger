trigger AuditLogTrigger on Audit_Log__c (
    before insert
) {
    AuditLogTriggerHandler.dispatch(
        Trigger.operationType,
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap
    );
}
