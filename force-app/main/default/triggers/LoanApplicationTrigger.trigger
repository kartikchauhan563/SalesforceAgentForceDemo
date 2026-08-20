trigger LoanApplicationTrigger on Loan_Application__c (
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    LoanApplicationTriggerHandler.dispatch(
        Trigger.operationType,
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap
    );
}
