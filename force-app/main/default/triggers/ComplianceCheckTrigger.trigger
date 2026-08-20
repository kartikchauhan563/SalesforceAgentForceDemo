trigger ComplianceCheckTrigger on Compliance_Check__c (
    after insert, after update
) {
    ComplianceCheckTriggerHandler.dispatch(
        Trigger.operationType,
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap
    );
}
