/**
 * Handler for Loan_Application_History__c — timestamp, session, and compliance defaults.
 */
public with sharing class LoanApplicationHistoryTriggerHandler implements ITriggerHandler {
    private static final Set<String> COMPLIANCE_EVENT_TYPES = new Set<String>{
        'Application Created', 'Application Submitted', 'Document Verified', 'Document Issue Flagged',
        'Loan Decision Generated', 'Compliance Violation Found', 'Compliance Violation Resolved',
        'Officer Decision Made', 'Application Approved', 'Application Rejected',
        'Disbursement Initiated', 'Disbursement Completed', 'KYC Event'
    };

    public static void dispatch(
        System.TriggerOperation operationType,
        List<Loan_Application_History__c> newList,
        List<Loan_Application_History__c> oldList,
        Map<Id, Loan_Application_History__c> newMap,
        Map<Id, Loan_Application_History__c> oldMap
    ) {
        TriggerDispatcher.dispatch(
            operationType,
            new LoanApplicationHistoryTriggerHandler(),
            newList,
            oldList,
            newMap,
            oldMap
        );
    }

    public void beforeInsert(List<SObject> newRecords) {
        List<Loan_Application_History__c> histories = (List<Loan_Application_History__c>) newRecords;
        setEventTimestamp(histories);
        setSessionInfo(histories);
        validateEventTimestamp(histories);
        setComplianceFlag(histories);
    }

    public void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {}
    public void beforeDelete(List<SObject> oldRecords) {}
    public void afterInsert(List<SObject> newRecords) {}
    public void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {}
    public void afterDelete(List<SObject> oldRecords) {}
    public void afterUndelete(List<SObject> newRecords) {}

    public static void setEventTimestamp(List<Loan_Application_History__c> newList) {
        if (newList == null) {
            return;
        }
        for (Loan_Application_History__c hist : newList) {
            if (hist.Event_Timestamp__c == null) {
                hist.Event_Timestamp__c = DateTime.now();
            }
        }
    }

    public static void setSessionInfo(List<Loan_Application_History__c> newList) {
        if (newList == null) {
            return;
        }
        String maskedSession = maskSessionId(UserInfo.getSessionId());
        for (Loan_Application_History__c hist : newList) {
            if (String.isBlank(hist.Session_ID__c)) {
                hist.Session_ID__c = maskedSession;
            }
        }
    }

    public static void validateEventTimestamp(List<Loan_Application_History__c> newList) {
        if (newList == null) {
            return;
        }
        for (Loan_Application_History__c hist : newList) {
            if (hist.Event_Timestamp__c != null && hist.Event_Timestamp__c > DateTime.now()) {
                hist.Event_Timestamp__c.addError('Event timestamp cannot be in the future.');
            }
        }
    }

    public static void setComplianceFlag(List<Loan_Application_History__c> newList) {
        if (newList == null) {
            return;
        }
        for (Loan_Application_History__c hist : newList) {
            if (COMPLIANCE_EVENT_TYPES.contains(hist.Event_Type__c)) {
                hist.Compliance_Relevant__c = true;
            }
        }
    }

    private static String maskSessionId(String sessionId) {
        if (String.isBlank(sessionId)) {
            return null;
        }
        if (sessionId.length() <= 4) {
            return '****';
        }
        return '****' + sessionId.substring(sessionId.length() - 4);
    }
}
