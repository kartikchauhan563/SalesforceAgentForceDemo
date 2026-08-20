/**
 * Centralized service for Loan_Application_History__c and Audit_Log__c DML.
 * No other class should insert these objects directly.
 */
public with sharing class LoanApplicationHistoryHandler {
    public class HistoryRequest {
        public Id loanApplicationId;
        public String eventType;
        public String triggeredBy;
        public String eventSubType;
        public String eventDescription;
        public String previousStatus;
        public String newStatus;
        public String previousValue;
        public String newValue;
        public String fieldChanged;
        public Decimal riskScoreBefore;
        public Decimal riskScoreAfter;
        public String agentName;
        public String agentResult;
        public Decimal agentScoreImpact;
        public Decimal aiConfidence;
        public String decisionMade;
        public String decisionReason;
        public String missingDocumentsSnapshot;
        public Boolean officerOverride;
        public String overrideReason;
        public Decimal durationSeconds;
        public String severity;
        public Boolean complianceRelevant;
        public Id performedById;
    }

    public class AuditLogRequest {
        public Id loanApplicationId;
        public String eventType;
        public String eventSource;
        public String eventDescription;
        public String severity;
        public Boolean complianceRelevant;
        public String agentName;
        public String fieldChanged;
        public String oldValue;
        public String newValue;
        public Id performedById;
    }

    /**
     * Bulk insert history records with partial success handling.
     */
    public static void createHistoryRecords(List<HistoryRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }
        List<Loan_Application_History__c> records = new List<Loan_Application_History__c>();
        for (HistoryRequest req : requests) {
            if (req == null || req.loanApplicationId == null || String.isBlank(req.eventType)) {
                continue;
            }
            records.add(buildHistoryRecord(req));
        }
        if (records.isEmpty()) {
            return;
        }
        Database.SaveResult[] results = Database.insert(records, false);
        logDmlFailures('Loan_Application_History__c', results);
    }

    /**
     * Convenience wrapper for a single history row.
     */
    public static void createSingleHistory(
        Id loanAppId,
        String eventType,
        String triggeredBy,
        Map<String, Object> additionalFields
    ) {
        HistoryRequest req = new HistoryRequest();
        req.loanApplicationId = loanAppId;
        req.eventType = eventType;
        req.triggeredBy = triggeredBy;
        if (additionalFields != null) {
            applyAdditionalHistoryFields(req, additionalFields);
        }
        createHistoryRecords(new List<HistoryRequest>{ req });
    }

    /**
     * Bulk insert audit log records with partial success handling.
     */
    public static void createAuditRecords(List<AuditLogRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }
        List<Audit_Log__c> records = new List<Audit_Log__c>();
        for (AuditLogRequest req : requests) {
            if (req == null) {
                continue;
            }
            Audit_Log__c log = new Audit_Log__c();
            log.Loan_Application__c = req.loanApplicationId;
            log.Event_Type__c = req.eventType;
            log.Event_Source__c = String.isBlank(req.eventSource) ? 'System' : req.eventSource;
            log.Event_Description__c = req.eventDescription;
            log.Event_Timestamp__c = DateTime.now();
            log.Severity__c = String.isBlank(req.severity) ? 'Info' : req.severity;
            log.Compliance_Relevant__c = req.complianceRelevant == true;
            log.Agent_Name__c = req.agentName;
            log.Field_Changed__c = req.fieldChanged;
            log.Old_Value__c = req.oldValue;
            log.New_Value__c = req.newValue;
            log.Performed_By__c = req.performedById != null ? req.performedById : UserInfo.getUserId();
            records.add(log);
        }
        if (records.isEmpty()) {
            return;
        }
        Database.SaveResult[] results = Database.insert(records, false);
        logDmlFailures('Audit_Log__c', results);
    }

    public static void createSingleAuditLog(
        Id loanAppId,
        String eventType,
        String eventSource,
        Map<String, Object> additionalFields
    ) {
        AuditLogRequest req = new AuditLogRequest();
        req.loanApplicationId = loanAppId;
        req.eventType = eventType;
        req.eventSource = eventSource;
        if (additionalFields != null) {
            if (additionalFields.containsKey('Event_Description__c')) {
                req.eventDescription = (String) additionalFields.get('Event_Description__c');
            }
            if (additionalFields.containsKey('Severity__c')) {
                req.severity = (String) additionalFields.get('Severity__c');
            }
            if (additionalFields.containsKey('Compliance_Relevant__c')) {
                req.complianceRelevant = (Boolean) additionalFields.get('Compliance_Relevant__c');
            }
            if (additionalFields.containsKey('Agent_Name__c')) {
                req.agentName = (String) additionalFields.get('Agent_Name__c');
            }
        }
        createAuditRecords(new List<AuditLogRequest>{ req });
    }

    private static Loan_Application_History__c buildHistoryRecord(HistoryRequest req) {
        Loan_Application_History__c hist = new Loan_Application_History__c();
        hist.Loan_Application__c = req.loanApplicationId;
        hist.Event_Type__c = req.eventType;
        hist.Triggered_By__c = String.isBlank(req.triggeredBy) ? 'System' : req.triggeredBy;
        hist.Event_Sub_Type__c = req.eventSubType;
        hist.Event_Description__c = req.eventDescription;
        hist.Previous_Status__c = req.previousStatus;
        hist.New_Status__c = req.newStatus;
        hist.Previous_Value__c = req.previousValue;
        hist.New_Value__c = req.newValue;
        hist.Field_Changed__c = req.fieldChanged;
        hist.Risk_Score_Before__c = req.riskScoreBefore;
        hist.Risk_Score_After__c = req.riskScoreAfter;
        hist.Agent_Name__c = req.agentName;
        hist.Agent_Result__c = req.agentResult;
        hist.Agent_Score_Impact__c = req.agentScoreImpact;
        hist.AI_Confidence__c = req.aiConfidence;
        hist.Decision_Made__c = req.decisionMade;
        hist.Decision_Reason__c = req.decisionReason;
        hist.Missing_Documents_Snapshot__c = req.missingDocumentsSnapshot;
        hist.Officer_Override__c = req.officerOverride == true;
        hist.Override_Reason__c = req.overrideReason;
        hist.Duration_Seconds__c = req.durationSeconds;
        hist.Severity__c = req.severity;
        hist.Compliance_Relevant__c = req.complianceRelevant == true;
        hist.Performed_By__c = req.performedById != null ? req.performedById : UserInfo.getUserId();
        return hist;
    }

    private static void applyAdditionalHistoryFields(HistoryRequest req, Map<String, Object> fields) {
        if (fields.containsKey('Event_Sub_Type__c')) {
            req.eventSubType = (String) fields.get('Event_Sub_Type__c');
        }
        if (fields.containsKey('Event_Description__c')) {
            req.eventDescription = (String) fields.get('Event_Description__c');
        }
        if (fields.containsKey('Previous_Status__c')) {
            req.previousStatus = (String) fields.get('Previous_Status__c');
        }
        if (fields.containsKey('New_Status__c')) {
            req.newStatus = (String) fields.get('New_Status__c');
        }
        if (fields.containsKey('Previous_Value__c')) {
            req.previousValue = (String) fields.get('Previous_Value__c');
        }
        if (fields.containsKey('New_Value__c')) {
            req.newValue = (String) fields.get('New_Value__c');
        }
        if (fields.containsKey('Field_Changed__c')) {
            req.fieldChanged = (String) fields.get('Field_Changed__c');
        }
        if (fields.containsKey('Risk_Score_Before__c')) {
            req.riskScoreBefore = (Decimal) fields.get('Risk_Score_Before__c');
        }
        if (fields.containsKey('Risk_Score_After__c')) {
            req.riskScoreAfter = (Decimal) fields.get('Risk_Score_After__c');
        }
        if (fields.containsKey('Agent_Name__c')) {
            req.agentName = (String) fields.get('Agent_Name__c');
        }
        if (fields.containsKey('Agent_Result__c')) {
            req.agentResult = (String) fields.get('Agent_Result__c');
        }
        if (fields.containsKey('Agent_Score_Impact__c')) {
            req.agentScoreImpact = (Decimal) fields.get('Agent_Score_Impact__c');
        }
        if (fields.containsKey('AI_Confidence__c')) {
            req.aiConfidence = (Decimal) fields.get('AI_Confidence__c');
        }
        if (fields.containsKey('Decision_Made__c')) {
            req.decisionMade = (String) fields.get('Decision_Made__c');
        }
        if (fields.containsKey('Decision_Reason__c')) {
            req.decisionReason = (String) fields.get('Decision_Reason__c');
        }
        if (fields.containsKey('Missing_Documents_Snapshot__c')) {
            req.missingDocumentsSnapshot = (String) fields.get('Missing_Documents_Snapshot__c');
        }
        if (fields.containsKey('Officer_Override__c')) {
            req.officerOverride = (Boolean) fields.get('Officer_Override__c');
        }
        if (fields.containsKey('Override_Reason__c')) {
            req.overrideReason = (String) fields.get('Override_Reason__c');
        }
        if (fields.containsKey('Duration_Seconds__c')) {
            req.durationSeconds = (Decimal) fields.get('Duration_Seconds__c');
        }
        if (fields.containsKey('Severity__c')) {
            req.severity = (String) fields.get('Severity__c');
        }
        if (fields.containsKey('Compliance_Relevant__c')) {
            req.complianceRelevant = (Boolean) fields.get('Compliance_Relevant__c');
        }
    }

    private static void logDmlFailures(String objectLabel, Database.SaveResult[] results) {
        if (results == null) {
            return;
        }
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug(LoggingLevel.ERROR, objectLabel + ' insert failed: ' + err.getMessage());
                }
            }
        }
    }

    public class InvocableRequest {
        @InvocableVariable(label='Loan Application Id' required=true)
        public String loanApplicationId;
        @InvocableVariable(label='Event Type' required=true)
        public String eventType;
        @InvocableVariable(label='Triggered By' required=true)
        public String triggeredBy;
        @InvocableVariable(label='Event Sub Type')
        public String eventSubType;
        @InvocableVariable(label='Event Description')
        public String eventDescription;
        @InvocableVariable(label='Previous Status')
        public String previousStatus;
        @InvocableVariable(label='New Status')
        public String newStatus;
        @InvocableVariable(label='Agent Name')
        public String agentName;
        @InvocableVariable(label='Agent Result')
        public String agentResult;
        @InvocableVariable(label='Agent Score Impact')
        public Decimal agentScoreImpact;
        @InvocableVariable(label='AI Confidence')
        public Decimal aiConfidence;
        @InvocableVariable(label='Decision Made')
        public String decisionMade;
        @InvocableVariable(label='Decision Reason')
        public String decisionReason;
        @InvocableVariable(label='Officer Override')
        public Boolean officerOverride;
        @InvocableVariable(label='Override Reason')
        public String overrideReason;
        @InvocableVariable(label='Severity')
        public String severity;
        @InvocableVariable(label='Compliance Relevant')
        public Boolean complianceRelevant;
    }

    public class InvocableResponse {
        @InvocableVariable public String historyRecordId;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(
        label='Create History Record'
        description='Creates a Loan_Application_History__c record for agent or officer events'
    )
    public static List<InvocableResponse> createHistoryFromAgent(List<InvocableRequest> requests) {
        List<InvocableResponse> results = new List<InvocableResponse>();
        for (InvocableRequest req : requests) {
            InvocableResponse res = new InvocableResponse();
            results.add(res);
            if (req == null || String.isBlank(req.loanApplicationId) || String.isBlank(req.eventType)) {
                res.success = false;
                res.errorMessage = 'Loan application ID and event type are required.';
                continue;
            }
            try {
                HistoryRequest histReq = new HistoryRequest();
                histReq.loanApplicationId = req.loanApplicationId;
                histReq.eventType = req.eventType;
                histReq.triggeredBy = String.isBlank(req.triggeredBy) ? 'System' : req.triggeredBy;
                histReq.eventSubType = req.eventSubType;
                histReq.eventDescription = req.eventDescription;
                histReq.previousStatus = req.previousStatus;
                histReq.newStatus = req.newStatus;
                histReq.agentName = req.agentName;
                histReq.agentResult = req.agentResult;
                histReq.agentScoreImpact = req.agentScoreImpact;
                histReq.aiConfidence = req.aiConfidence;
                histReq.decisionMade = req.decisionMade;
                histReq.decisionReason = req.decisionReason;
                histReq.officerOverride = req.officerOverride;
                histReq.overrideReason = req.overrideReason;
                histReq.severity = req.severity;
                histReq.complianceRelevant = req.complianceRelevant;
                if ('AI Agent'.equals(histReq.triggeredBy) && String.isBlank(histReq.agentName)) {
                    histReq.agentName = 'Decision Agent';
                }
                Loan_Application_History__c hist = buildHistoryRecord(histReq);
                hist.Event_Timestamp__c = DateTime.now();
                Database.SaveResult sr = Database.insert(hist, false);
                if (sr.isSuccess()) {
                    res.historyRecordId = sr.getId();
                    res.success = true;
                } else {
                    res.success = false;
                    res.errorMessage = sr.getErrors()[0].getMessage();
                }
            } catch (Exception ex) {
                res.success = false;
                res.errorMessage = ex.getMessage();
            }
        }
        return results;
    }
}
