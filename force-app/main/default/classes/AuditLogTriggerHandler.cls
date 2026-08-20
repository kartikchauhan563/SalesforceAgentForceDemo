/**
 * Handler for Audit_Log__c — timestamp, session, severity, and compliance defaults.
 */
public with sharing class AuditLogTriggerHandler implements ITriggerHandler {
    private static final Set<String> COMPLIANCE_EVENT_TYPES = new Set<String>{
        'Decision Made', 'Officer Action', 'Disbursement'
    };

    public static void dispatch(
        System.TriggerOperation operationType,
        List<Audit_Log__c> newList,
        List<Audit_Log__c> oldList,
        Map<Id, Audit_Log__c> newMap,
        Map<Id, Audit_Log__c> oldMap
    ) {
        TriggerDispatcher.dispatch(
            operationType,
            new AuditLogTriggerHandler(),
            newList,
            oldList,
            newMap,
            oldMap
        );
    }

    public void beforeInsert(List<SObject> newRecords) {
        List<Audit_Log__c> logs = (List<Audit_Log__c>) newRecords;
        setTimestamp(logs);
        setSessionAndIP(logs);
        setSeverityDefault(logs);
        setComplianceFlag(logs);
    }

    public void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {}
    public void beforeDelete(List<SObject> oldRecords) {}
    public void afterInsert(List<SObject> newRecords) {}
    public void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {}
    public void afterDelete(List<SObject> oldRecords) {}
    public void afterUndelete(List<SObject> newRecords) {}

    public static void setTimestamp(List<Audit_Log__c> newList) {
        if (newList == null) {
            return;
        }
        for (Audit_Log__c log : newList) {
            if (log.Event_Timestamp__c == null) {
                log.Event_Timestamp__c = DateTime.now();
            }
        }
    }

    public static void setSessionAndIP(List<Audit_Log__c> newList) {
        if (newList == null) {
            return;
        }
        String sessionId = UserInfo.getSessionId();
        for (Audit_Log__c log : newList) {
            if (String.isBlank(log.Session_ID__c)) {
                log.Session_ID__c = sessionId;
            }
        }
    }

    public static void setSeverityDefault(List<Audit_Log__c> newList) {
        if (newList == null) {
            return;
        }
        for (Audit_Log__c log : newList) {
            if (String.isBlank(log.Severity__c)) {
                log.Severity__c = 'Info';
            }
        }
    }

    public static void setComplianceFlag(List<Audit_Log__c> newList) {
        if (newList == null) {
            return;
        }
        for (Audit_Log__c log : newList) {
            if (COMPLIANCE_EVENT_TYPES.contains(log.Event_Type__c)) {
                log.Compliance_Relevant__c = true;
            }
        }
    }
}
