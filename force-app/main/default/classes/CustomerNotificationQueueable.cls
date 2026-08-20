/**
 * Queueable that sends customer email notifications and logs audit/history records.
 */
public with sharing class CustomerNotificationQueueable implements Queueable {
    private List<Id> loanAppIds;
    private List<String> notificationTypes;

    public CustomerNotificationQueueable(List<Id> loanAppIds, List<String> notificationTypes) {
        this.loanAppIds = loanAppIds != null ? loanAppIds : new List<Id>();
        this.notificationTypes = notificationTypes != null ? notificationTypes : new List<String>();
    }

    public void execute(QueueableContext ctx) {
        if (loanAppIds.isEmpty()) {
            return;
        }
        Map<Id, Loan_Application__c> appsById = new Map<Id, Loan_Application__c>();
        String appQuery = 'SELECT Id, Name, Status__c, Applicant__c, Final_Recommendation__c';
        if (AccountFieldHelper.hasField('PersonEmail')) {
            appQuery += ', Applicant__r.PersonEmail';
        }
        appQuery += ' FROM Loan_Application__c WHERE Id IN :loanAppIds';
        for (Loan_Application__c app : (List<Loan_Application__c>) Database.query(appQuery)) {
            appsById.put(app.Id, app);
        }
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<LoanApplicationHistoryHandler.HistoryRequest> historyRequests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        List<LoanApplicationHistoryHandler.AuditLogRequest> auditRequests = new List<LoanApplicationHistoryHandler.AuditLogRequest>();

        for (Integer i = 0; i < loanAppIds.size(); i++) {
            Id loanAppId = loanAppIds[i];
            Loan_Application__c app = appsById.get(loanAppId);
            if (app == null) {
                continue;
            }
            String notifyType = i < notificationTypes.size() ? notificationTypes[i] : app.Status__c;
            String subject = buildSubject(notifyType, app.Name);
            String body = buildBody(notifyType, app);

            String email = app.Applicant__r != null
                ? AccountFieldHelper.getEmail(app.Applicant__r)
                : null;
            if (String.isNotBlank(email)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ email });
                mail.setSubject(subject);
                mail.setPlainTextBody(body);
                emails.add(mail);
            }

            LoanApplicationHistoryHandler.HistoryRequest hist = new LoanApplicationHistoryHandler.HistoryRequest();
            hist.loanApplicationId = loanAppId;
            hist.eventType = 'Customer Notification Sent';
            hist.eventDescription = subject;
            hist.triggeredBy = 'System';
            historyRequests.add(hist);

            LoanApplicationHistoryHandler.AuditLogRequest audit = new LoanApplicationHistoryHandler.AuditLogRequest();
            audit.loanApplicationId = loanAppId;
            audit.eventType = 'Integration Call';
            audit.eventSource = 'System';
            audit.eventDescription = 'Customer notification sent: ' + notifyType;
            audit.severity = 'Info';
            auditRequests.add(audit);
        }

        if (!emails.isEmpty() && !Test.isRunningTest()) {
            Messaging.sendEmail(emails);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(historyRequests);
        LoanApplicationHistoryHandler.createAuditRecords(auditRequests);
    }

    private static String buildSubject(String notifyType, String appName) {
        return 'Loan Application ' + appName + ' - ' + notifyType + ' Update';
    }

    private static String buildBody(String notifyType, Loan_Application__c app) {
        return 'Dear Applicant,\n\nYour loan application ' + app.Name
            + ' status has been updated to: ' + notifyType
            + '.\n\nRegards,\nNBFC Loan Team';
    }
}
