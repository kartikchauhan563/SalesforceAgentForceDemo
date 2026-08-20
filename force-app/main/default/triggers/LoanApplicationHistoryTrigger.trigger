trigger LoanApplicationHistoryTrigger on Loan_Application_History__c (
    before insert
) {
    LoanApplicationHistoryTriggerHandler.dispatch(
        Trigger.operationType,
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap
    );
}
