/**
 * Contract for object-specific trigger handlers routed by TriggerDispatcher.
 */
public interface ITriggerHandler {
    void beforeInsert(List<SObject> newRecords);
    void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap);
    void beforeDelete(List<SObject> oldRecords);
    void afterInsert(List<SObject> newRecords);
    void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap);
    void afterDelete(List<SObject> oldRecords);
    void afterUndelete(List<SObject> newRecords);
}
