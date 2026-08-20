/**
 * Central dispatcher that routes trigger context to the appropriate handler method.
 */
public with sharing class TriggerDispatcher {
    public static void run(ITriggerHandler handler) {
        if (handler == null) {
            return;
        }
        if (Trigger.isBefore) {
            if (Trigger.isInsert) {
                handler.beforeInsert(Trigger.new);
            } else if (Trigger.isUpdate) {
                handler.beforeUpdate(Trigger.new, Trigger.oldMap);
            } else if (Trigger.isDelete) {
                handler.beforeDelete(Trigger.old);
            }
        } else if (Trigger.isAfter) {
            if (Trigger.isInsert) {
                handler.afterInsert(Trigger.new);
            } else if (Trigger.isUpdate) {
                handler.afterUpdate(Trigger.new, Trigger.oldMap);
            } else if (Trigger.isDelete) {
                handler.afterDelete(Trigger.old);
            } else if (Trigger.isUndelete) {
                handler.afterUndelete(Trigger.new);
            }
        }
    }

    /**
     * Routes explicit operation type when trigger context is unavailable (e.g., tests).
     */
    public static void dispatch(
        System.TriggerOperation operationType,
        ITriggerHandler handler,
        List<SObject> newRecords,
        List<SObject> oldRecords,
        Map<Id, SObject> newMap,
        Map<Id, SObject> oldMap
    ) {
        if (handler == null) {
            return;
        }
        switch on operationType {
            when BEFORE_INSERT {
                handler.beforeInsert(newRecords);
            }
            when BEFORE_UPDATE {
                handler.beforeUpdate(newRecords, oldMap);
            }
            when BEFORE_DELETE {
                handler.beforeDelete(oldRecords);
            }
            when AFTER_INSERT {
                handler.afterInsert(newRecords);
            }
            when AFTER_UPDATE {
                handler.afterUpdate(newRecords, oldMap);
            }
            when AFTER_DELETE {
                handler.afterDelete(oldRecords);
            }
            when AFTER_UNDELETE {
                handler.afterUndelete(newRecords);
            }
        }
    }
}
