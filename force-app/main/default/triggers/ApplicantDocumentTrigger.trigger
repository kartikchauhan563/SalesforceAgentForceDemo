trigger ApplicantDocumentTrigger on Applicant_Document__c (
    before insert, before update, after insert, after update
) {
    ApplicantDocumentTriggerHandler.dispatch(
        Trigger.operationType,
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap
    );
}
