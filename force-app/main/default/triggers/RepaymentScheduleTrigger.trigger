trigger RepaymentScheduleTrigger on Repayment_Schedule__c (
    before insert, before update, after update
) {
    RepaymentScheduleTriggerHandler.dispatch(
        Trigger.operationType,
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap
    );
}
