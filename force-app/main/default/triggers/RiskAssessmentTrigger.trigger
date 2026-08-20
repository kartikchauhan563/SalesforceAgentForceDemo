trigger RiskAssessmentTrigger on Risk_Assessment__c (
    after insert, after update
) {
    RiskAssessmentTriggerHandler.dispatch(
        Trigger.operationType,
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap
    );
}
