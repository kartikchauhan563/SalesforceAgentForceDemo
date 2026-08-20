/**
 * Handler for Loan_Application__c trigger — all business logic for loan application lifecycle.
 */
public with sharing class LoanApplicationTriggerHandler implements ITriggerHandler {
    private static final Map<String, Set<String>> ALLOWED_STATUS_TRANSITIONS = buildTransitionMatrix();
    private static final List<String> TRACKED_FIELDS = new List<String>{
        'Status__c', 'Final_Recommendation__c', 'Risk_Score__c', 'Loan_Officer__c',
        'Underwriter__c', 'Priority__c', 'Loan_Amount_Approved__c', 'Interest_Rate__c', 'AI_Confidence__c'
    };

    public static void dispatch(
        System.TriggerOperation operationType,
        List<Loan_Application__c> newList,
        List<Loan_Application__c> oldList,
        Map<Id, Loan_Application__c> newMap,
        Map<Id, Loan_Application__c> oldMap
    ) {
        LoanApplicationTriggerHandler handler = new LoanApplicationTriggerHandler();
        TriggerDispatcher.dispatch(
            operationType,
            handler,
            newList,
            oldList,
            newMap,
            oldMap
        );
    }

    public void beforeInsert(List<SObject> newRecords) {
        List<Loan_Application__c> apps = (List<Loan_Application__c>) newRecords;
        setDefaultValues(apps);
        validateLoanAmount(apps);
        validateTenure(apps);
        validateApplicantAge(apps);
    }

    public void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<Loan_Application__c> apps = (List<Loan_Application__c>) newRecords;
        Map<Id, Loan_Application__c> typedOldMap = castOldMap(oldMap);
        preventIllegalStatusTransitions(apps, typedOldMap);
        setApprovalTimestamp(apps, typedOldMap);
        clearAIOutputOnResubmit(apps, typedOldMap);
    }

    public void beforeDelete(List<SObject> oldRecords) {
        // No before-delete logic required.
    }

    public void afterInsert(List<SObject> newRecords) {
        List<Loan_Application__c> apps = (List<Loan_Application__c>) newRecords;
        createHistoryRecord_Created(apps);
        createInitialDocumentChecklist(apps);
        publishAgentOrchestrationEvent(apps);
    }

    public void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<Loan_Application__c> apps = (List<Loan_Application__c>) newRecords;
        Map<Id, Loan_Application__c> typedOldMap = castOldMap(oldMap);
        createHistoryRecord_StatusChange(apps, typedOldMap);
        createHistoryRecord_DecisionChange(apps, typedOldMap);
        createHistoryRecord_FieldChange(apps, typedOldMap);
        triggerRiskRecalculation(apps, typedOldMap);
        sendStatusNotification(apps, typedOldMap);
        autoAssignLoanOfficer(apps, typedOldMap);
        publishAgentOrchestrationEvent_OnSubmit(apps, typedOldMap);
    }

    public void afterDelete(List<SObject> oldRecords) {
        createHistoryRecord_Deleted((List<Loan_Application__c>) oldRecords);
    }

    public void afterUndelete(List<SObject> newRecords) {
        // No after-undelete logic required.
    }

    /** Sets baseline field values on new loan applications. */
    public static void setDefaultValues(List<Loan_Application__c> newList) {
        if (newList == null) {
            return;
        }
        for (Loan_Application__c app : newList) {
            if (app.Application_Date__c == null) {
                app.Application_Date__c = Date.today();
            }
            if (String.isBlank(app.Status__c)) {
                app.Status__c = 'Draft';
            }
            if (String.isBlank(app.Priority__c)) {
                app.Priority__c = 'Medium';
            }
            if (app.All_Agents_Completed__c == null) {
                app.All_Agents_Completed__c = false;
            }
        }
    }

    /** Validates loan amount against Policy_Rule__mdt min/max thresholds. */
    public static void validateLoanAmount(List<Loan_Application__c> newList) {
        if (newList == null) {
            return;
        }
        Decimal minAmount = PolicyRuleService.getDecimalThreshold('RULE_MIN_AMOUNT');
        Decimal maxAmount = PolicyRuleService.getDecimalThreshold('RULE_MAX_AMOUNT');
        for (Loan_Application__c app : newList) {
            if (app.Loan_Amount__c == null) {
                continue;
            }
            if (minAmount != null && app.Loan_Amount__c < minAmount) {
                app.Loan_Amount__c.addError('Loan amount must be at least ' + minAmount.format());
            }
            if (maxAmount != null && app.Loan_Amount__c > maxAmount) {
                app.Loan_Amount__c.addError('Loan amount cannot exceed ' + maxAmount.format());
            }
        }
    }

    /** Validates tenure against the linked loan product min/max tenure. */
    public static void validateTenure(List<Loan_Application__c> newList) {
        if (newList == null || newList.isEmpty()) {
            return;
        }
        Set<Id> productIds = new Set<Id>();
        for (Loan_Application__c app : newList) {
            if (app.Loan_Product__c != null) {
                productIds.add(app.Loan_Product__c);
            }
        }
        if (productIds.isEmpty()) {
            return;
        }
        Map<Id, Loan_Product__c> productsById = new Map<Id, Loan_Product__c>([
            SELECT Id, Min_Tenure__c, Max_Tenure__c
            FROM Loan_Product__c
            WHERE Id IN :productIds
        ]);
        for (Loan_Application__c app : newList) {
            if (app.Tenure_Months__c == null || app.Loan_Product__c == null) {
                continue;
            }
            Loan_Product__c product = productsById.get(app.Loan_Product__c);
            if (product == null) {
                continue;
            }
            if (product.Min_Tenure__c != null && app.Tenure_Months__c < product.Min_Tenure__c) {
                app.Tenure_Months__c.addError('Tenure is below product minimum of ' + product.Min_Tenure__c.intValue());
            }
            if (product.Max_Tenure__c != null && app.Tenure_Months__c > product.Max_Tenure__c) {
                app.Tenure_Months__c.addError('Tenure exceeds product maximum of ' + product.Max_Tenure__c.intValue());
            }
        }
    }

    /** Validates applicant age from Person Account birthdate against policy rules. */
    public static void validateApplicantAge(List<Loan_Application__c> newList) {
        if (newList == null || newList.isEmpty()) {
            return;
        }
        Set<Id> accountIds = new Set<Id>();
        for (Loan_Application__c app : newList) {
            if (app.Applicant__c != null) {
                accountIds.add(app.Applicant__c);
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }
        Map<Id, Account> accountsById = new Map<Id, Account>();
        if (AccountFieldHelper.hasField('PersonBirthdate')) {
            String accountQuery = 'SELECT Id, PersonBirthdate FROM Account WHERE Id IN :accountIds';
            accountsById = new Map<Id, Account>((List<Account>) Database.query(accountQuery));
        } else {
            accountsById = new Map<Id, Account>([
                SELECT Id
                FROM Account
                WHERE Id IN :accountIds
            ]);
        }
        Integer minAge = PolicyRuleService.getIntegerThreshold('RULE_MIN_AGE');
        Integer maxAge = PolicyRuleService.getIntegerThreshold('RULE_MAX_AGE');
        for (Loan_Application__c app : newList) {
            Account applicant = accountsById.get(app.Applicant__c);
            Date birthDate = AccountFieldHelper.getBirthdate(applicant);
            if (birthDate == null) {
                continue;
            }
            Integer age = calculateAge(birthDate);
            if (minAge != null && age < minAge) {
                app.Applicant__c.addError('Applicant age ' + age + ' is below minimum allowed age of ' + minAge);
            }
            if (maxAge != null && age > maxAge) {
                app.Applicant__c.addError('Applicant age ' + age + ' exceeds maximum allowed age of ' + maxAge);
            }
        }
    }

    /** Enforces the allowed loan application status transition matrix. */
    public static void preventIllegalStatusTransitions(
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (oldApp == null || app.Status__c == oldApp.Status__c) {
                continue;
            }
            Set<String> allowed = ALLOWED_STATUS_TRANSITIONS.get(oldApp.Status__c);
            if (allowed == null || !allowed.contains(app.Status__c)) {
                app.Status__c.addError(
                    'Invalid status transition from ' + oldApp.Status__c + ' to ' + app.Status__c
                );
            }
        }
    }

    /** Copies loan amount to approved amount when status moves to Approved. */
    public static void setApprovalTimestamp(
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (oldApp == null || app.Status__c == oldApp.Status__c) {
                continue;
            }
            if ('Approved'.equals(app.Status__c) && app.Loan_Amount_Approved__c == null) {
                app.Loan_Amount_Approved__c = app.Loan_Amount__c;
            }
        }
    }

    /** Clears AI outputs when application is resubmitted from On Hold. */
    public static void clearAIOutputOnResubmit(
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (oldApp == null) {
                continue;
            }
            if ('On Hold'.equals(oldApp.Status__c) && 'Submitted'.equals(app.Status__c)) {
                app.Risk_Score__c = null;
                app.Final_Recommendation__c = null;
                app.AI_Confidence__c = null;
                app.All_Agents_Completed__c = false;
                app.Missing_Documents__c = null;
                app.Decision_Reasons__c = null;
            }
        }
    }

    /** Logs Application Created history events. */
    public static void createHistoryRecord_Created(List<Loan_Application__c> newList) {
        if (newList == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Loan_Application__c app : newList) {
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = app.Id;
            req.eventType = 'Application Created';
            req.triggeredBy = 'User';
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    /** Creates mandatory applicant document checklist from loan product requirements. */
    public static void createInitialDocumentChecklist(List<Loan_Application__c> newList) {
        if (newList == null || newList.isEmpty()) {
            return;
        }
        Set<Id> productIds = new Set<Id>();
        for (Loan_Application__c app : newList) {
            if (app.Loan_Product__c != null) {
                productIds.add(app.Loan_Product__c);
            }
        }
        Map<Id, Loan_Product__c> productsById = productIds.isEmpty()
            ? new Map<Id, Loan_Product__c>()
            : new Map<Id, Loan_Product__c>([
                SELECT Id, Required_Documents__c
                FROM Loan_Product__c
                WHERE Id IN :productIds
            ]);
        List<Applicant_Document__c> docsToInsert = new List<Applicant_Document__c>();
        for (Loan_Application__c app : newList) {
            Loan_Product__c product = productsById.get(app.Loan_Product__c);
            if (product == null || String.isBlank(product.Required_Documents__c)) {
                continue;
            }
            for (String docType : product.Required_Documents__c.split(',')) {
                String trimmed = docType.trim();
                if (String.isBlank(trimmed)) {
                    continue;
                }
                docsToInsert.add(new Applicant_Document__c(
                    Loan_Application__c = app.Id,
                    Document_Type__c = trimmed,
                    Uploaded__c = false,
                    Verified__c = false,
                    Is_Mandatory__c = true
                ));
            }
        }
        if (!docsToInsert.isEmpty()) {
            Database.insert(docsToInsert, false);
        }
    }

    /** Publishes agent orchestration event for applications submitted on insert. */
    public static void publishAgentOrchestrationEvent(List<Loan_Application__c> newList) {
        if (newList == null) {
            return;
        }
        List<NBFC_Agent_Trigger__e> events = new List<NBFC_Agent_Trigger__e>();
        for (Loan_Application__c app : newList) {
            if ('Submitted'.equals(app.Status__c)) {
                events.add(buildAgentEvent(app.Id, AgentEventPublisher.ACTION_START_ALL_AGENTS));
            }
        }
        AgentEventPublisher.publishEvents(events);
    }

    /** Logs status change history when Status__c is updated. */
    public static void createHistoryRecord_StatusChange(
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (oldApp == null || app.Status__c == oldApp.Status__c) {
                continue;
            }
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = app.Id;
            req.eventType = 'Application Status Changed';
            req.triggeredBy = 'User';
            req.previousStatus = oldApp.Status__c;
            req.newStatus = app.Status__c;
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    /** Logs AI decision history when Final_Recommendation__c changes. */
    public static void createHistoryRecord_DecisionChange(
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (oldApp == null || app.Final_Recommendation__c == oldApp.Final_Recommendation__c
                || app.Final_Recommendation__c == null) {
                continue;
            }
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = app.Id;
            req.eventType = 'Loan Decision Generated';
            req.triggeredBy = 'AI Agent';
            req.decisionMade = app.Final_Recommendation__c;
            req.aiConfidence = app.AI_Confidence__c;
            req.riskScoreAfter = app.Risk_Score__c;
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    /** Creates consolidated field change history per application. */
    public static void createHistoryRecord_FieldChange(
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (oldApp == null) {
                continue;
            }
            List<String> changedFields = new List<String>();
            List<String> oldValues = new List<String>();
            List<String> newValues = new List<String>();
            for (String fieldName : TRACKED_FIELDS) {
                Object oldVal = oldApp.get(fieldName);
                Object newVal = app.get(fieldName);
                if (oldVal != newVal && (oldVal != null || newVal != null)) {
                    changedFields.add(fieldName);
                    oldValues.add(String.valueOf(oldVal));
                    newValues.add(String.valueOf(newVal));
                }
            }
            if (changedFields.isEmpty()) {
                continue;
            }
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = app.Id;
            req.eventType = 'Field Modified';
            req.triggeredBy = 'User';
            req.fieldChanged = String.join(changedFields, ', ');
            req.previousValue = String.join(oldValues, '; ');
            req.newValue = String.join(newValues, '; ');
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    /** Enqueues risk recalculation when key financial fields change. */
    public static void triggerRiskRecalculation(
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        Set<Id> loanAppIds = new Set<Id>();
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (oldApp == null) {
                continue;
            }
            if (app.Credit_Score__c != oldApp.Credit_Score__c
                || app.Monthly_Income__c != oldApp.Monthly_Income__c
                || app.Existing_EMI__c != oldApp.Existing_EMI__c) {
                loanAppIds.add(app.Id);
            }
        }
        if (!loanAppIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
            System.enqueueJob(new RiskRecalculationQueueable(new List<Id>(loanAppIds)));
        }
    }

    /** Sends customer notifications for terminal or hold statuses. */
    public static void sendStatusNotification(
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<Id> notifyIds = new List<Id>();
        List<String> notifyTypes = new List<String>();
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (oldApp == null || app.Status__c == oldApp.Status__c) {
                continue;
            }
            if ('Approved'.equals(app.Status__c) || 'Rejected'.equals(app.Status__c) || 'On Hold'.equals(app.Status__c)) {
                notifyIds.add(app.Id);
                notifyTypes.add(app.Status__c);
            }
        }
        if (!notifyIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
            System.enqueueJob(new CustomerNotificationQueueable(notifyIds, notifyTypes));
        }
    }

    /** Assigns loan officer with fewest open applications when submitted. */
    public static void autoAssignLoanOfficer(
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<Loan_Application__c> toAssign = new List<Loan_Application__c>();
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (oldApp != null && 'Draft'.equals(oldApp.Status__c) && 'Submitted'.equals(app.Status__c)
                && app.Loan_Officer__c == null) {
                toAssign.add(app);
            }
        }
        if (toAssign.isEmpty()) {
            return;
        }
        List<User> officers = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
            AND Profile.Name = 'NBFC Loan Officer'
        ];
        if (officers.isEmpty()) {
            return;
        }
        Set<Id> officerIds = new Map<Id, User>(officers).keySet();
        Map<Id, Integer> openCountByOfficer = new Map<Id, Integer>();
        for (Id officerId : officerIds) {
            openCountByOfficer.put(officerId, 0);
        }
        for (AggregateResult ar : [
            SELECT Loan_Officer__c officerId, COUNT(Id) cnt
            FROM Loan_Application__c
            WHERE Loan_Officer__c IN :officerIds
            AND Status__c NOT IN ('Approved', 'Rejected', 'Disbursed', 'Closed', 'Withdrawn')
            GROUP BY Loan_Officer__c
        ]) {
            openCountByOfficer.put((Id) ar.get('officerId'), (Integer) ar.get('cnt'));
        }
        Id selectedOfficerId;
        Integer minCount;
        for (Id officerId : openCountByOfficer.keySet()) {
            Integer count = openCountByOfficer.get(officerId);
            if (selectedOfficerId == null || count < minCount) {
                selectedOfficerId = officerId;
                minCount = count;
            }
        }
        List<Loan_Application__c> updates = new List<Loan_Application__c>();
        for (Loan_Application__c app : toAssign) {
            updates.add(new Loan_Application__c(Id = app.Id, Loan_Officer__c = selectedOfficerId));
        }
        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
    }

    /** Publishes START_ALL_AGENTS when application moves from Draft to Submitted. */
    public static void publishAgentOrchestrationEvent_OnSubmit(
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<NBFC_Agent_Trigger__e> events = new List<NBFC_Agent_Trigger__e>();
        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (oldApp != null && 'Draft'.equals(oldApp.Status__c) && 'Submitted'.equals(app.Status__c)) {
                events.add(buildAgentEvent(app.Id, AgentEventPublisher.ACTION_START_ALL_AGENTS));
            }
        }
        AgentEventPublisher.publishEvents(events);
    }

    /** Logs application deletion to audit trail. */
    public static void createHistoryRecord_Deleted(List<Loan_Application__c> oldList) {
        if (oldList == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.AuditLogRequest> requests = new List<LoanApplicationHistoryHandler.AuditLogRequest>();
        for (Loan_Application__c app : oldList) {
            LoanApplicationHistoryHandler.AuditLogRequest req = new LoanApplicationHistoryHandler.AuditLogRequest();
            req.loanApplicationId = app.Id;
            req.eventType = 'Application Created';
            req.eventSource = 'User';
            req.eventDescription = 'Loan application deleted: ' + app.Id;
            req.severity = 'Warning';
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createAuditRecords(requests);
    }

    private static NBFC_Agent_Trigger__e buildAgentEvent(Id loanAppId, String action) {
        NBFC_Agent_Trigger__e evt = new NBFC_Agent_Trigger__e();
        evt.Loan_Application_Id__c = String.valueOf(loanAppId);
        evt.Event_Action__c = action;
        evt.Triggered_At__c = DateTime.now();
        return evt;
    }

    private static Map<String, Set<String>> buildTransitionMatrix() {
        Map<String, Set<String>> matrix = new Map<String, Set<String>>();
        matrix.put('Draft', new Set<String>{ 'Submitted' });
        matrix.put('Submitted', new Set<String>{ 'Under Review', 'Withdrawn' });
        matrix.put('Under Review', new Set<String>{ 'On Hold', 'Documents Pending', 'Approved', 'Rejected' });
        matrix.put('On Hold', new Set<String>{ 'Under Review', 'Withdrawn', 'Submitted' });
        matrix.put('Approved', new Set<String>{ 'Disbursed' });
        matrix.put('Rejected', new Set<String>());
        matrix.put('Disbursed', new Set<String>());
        matrix.put('Withdrawn', new Set<String>());
        return matrix;
    }

    private static Integer calculateAge(Date birthDate) {
        Integer age = Date.today().year() - birthDate.year();
        if (Date.today().month() < birthDate.month()
            || (Date.today().month() == birthDate.month() && Date.today().day() < birthDate.day())) {
            age--;
        }
        return age;
    }

    private static Map<Id, Loan_Application__c> castOldMap(Map<Id, SObject> oldMap) {
        Map<Id, Loan_Application__c> typed = new Map<Id, Loan_Application__c>();
        if (oldMap != null) {
            for (Id key : oldMap.keySet()) {
                typed.put(key, (Loan_Application__c) oldMap.get(key));
            }
        }
        return typed;
    }

}
