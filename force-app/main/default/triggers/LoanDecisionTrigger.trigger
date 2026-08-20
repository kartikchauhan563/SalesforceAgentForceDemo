trigger LoanDecisionTrigger on Loan_Decision__c (
    after insert, after update
) {
    LoanDecisionTriggerHandler.dispatch(
        Trigger.operationType,
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap
    );
}
