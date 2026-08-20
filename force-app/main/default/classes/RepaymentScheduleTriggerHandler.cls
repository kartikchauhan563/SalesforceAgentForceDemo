/**
 * Handler for Repayment_Schedule__c — payment validation, late fees, and alerts.
 */
public with sharing class RepaymentScheduleTriggerHandler implements ITriggerHandler {
    public static void dispatch(
        System.TriggerOperation operationType,
        List<Repayment_Schedule__c> newList,
        List<Repayment_Schedule__c> oldList,
        Map<Id, Repayment_Schedule__c> newMap,
        Map<Id, Repayment_Schedule__c> oldMap
    ) {
        TriggerDispatcher.dispatch(
            operationType,
            new RepaymentScheduleTriggerHandler(),
            newList,
            oldList,
            newMap,
            oldMap
        );
    }

    public void beforeInsert(List<SObject> newRecords) {
        setInitialStatus((List<Repayment_Schedule__c>) newRecords);
    }

    public void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<Repayment_Schedule__c> schedules = (List<Repayment_Schedule__c>) newRecords;
        Map<Id, Repayment_Schedule__c> typedOldMap = castOldMap(oldMap);
        validatePaymentAmount(schedules, typedOldMap);
        setLateFee(schedules, typedOldMap);
    }

    public void beforeDelete(List<SObject> oldRecords) {}

    public void afterInsert(List<SObject> newRecords) {}

    public void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<Repayment_Schedule__c> schedules = (List<Repayment_Schedule__c>) newRecords;
        Map<Id, Repayment_Schedule__c> typedOldMap = castOldMap(oldMap);
        createHistoryRecord_PaymentMade(schedules, typedOldMap);
        createHistoryRecord_Bounced(schedules, typedOldMap);
        alertOnOverdue(schedules, typedOldMap);
    }

    public void afterDelete(List<SObject> oldRecords) {}
    public void afterUndelete(List<SObject> newRecords) {}

    public static void setInitialStatus(List<Repayment_Schedule__c> newList) {
        if (newList == null) {
            return;
        }
        for (Repayment_Schedule__c schedule : newList) {
            if (String.isBlank(schedule.Status__c)) {
                schedule.Status__c = 'Pending';
            }
        }
    }

    public static void validatePaymentAmount(
        List<Repayment_Schedule__c> newList,
        Map<Id, Repayment_Schedule__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        for (Repayment_Schedule__c schedule : newList) {
            Repayment_Schedule__c oldSchedule = oldMap.get(schedule.Id);
            if (oldSchedule == null || schedule.Status__c == oldSchedule.Status__c) {
                continue;
            }
            if ('Paid'.equals(schedule.Status__c)
                && (schedule.Paid_Amount__c == null || schedule.Paid_Amount__c <= 0)) {
                schedule.Paid_Amount__c.addError('Paid amount must be greater than zero when marking EMI as Paid.');
            }
        }
    }

    public static void setLateFee(
        List<Repayment_Schedule__c> newList,
        Map<Id, Repayment_Schedule__c> oldMap
    ) {
        if (newList == null) {
            return;
        }
        Decimal lateFeePct = PolicyRuleService.getDecimalThreshold('RULE_LATE_FEE_PCT');
        if (lateFeePct == null) {
            return;
        }
        for (Repayment_Schedule__c schedule : newList) {
            if ('Overdue'.equals(schedule.Status__c)
                && schedule.Due_Date__c != null
                && schedule.Due_Date__c < Date.today()
                && schedule.EMI_Amount__c != null) {
                schedule.Late_Fee__c = schedule.EMI_Amount__c * (lateFeePct / 100);
            }
        }
    }

    public static void createHistoryRecord_PaymentMade(
        List<Repayment_Schedule__c> newList,
        Map<Id, Repayment_Schedule__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Repayment_Schedule__c schedule : newList) {
            Repayment_Schedule__c oldSchedule = oldMap.get(schedule.Id);
            if (oldSchedule == null || !'Paid'.equals(schedule.Status__c) || 'Paid'.equals(oldSchedule.Status__c)) {
                continue;
            }
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = schedule.Loan_Application__c;
            req.eventType = 'Disbursement Completed';
            req.eventDescription = 'EMI #' + schedule.EMI_Number__c + ' paid. Amount: '
                + schedule.Paid_Amount__c + ', Date: ' + schedule.Paid_Date__c;
            req.triggeredBy = 'System';
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    public static void createHistoryRecord_Bounced(
        List<Repayment_Schedule__c> newList,
        Map<Id, Repayment_Schedule__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Repayment_Schedule__c schedule : newList) {
            Repayment_Schedule__c oldSchedule = oldMap.get(schedule.Id);
            if (oldSchedule == null || !'Bounced'.equals(schedule.Status__c) || 'Bounced'.equals(oldSchedule.Status__c)) {
                continue;
            }
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = schedule.Loan_Application__c;
            req.eventType = 'Disbursement Failed';
            req.severity = 'Warning';
            req.eventDescription = 'EMI payment bounced. Reason: ' + schedule.Bounce_Reason__c;
            req.triggeredBy = 'System';
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    public static void alertOnOverdue(
        List<Repayment_Schedule__c> newList,
        Map<Id, Repayment_Schedule__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<Id> loanAppIds = new List<Id>();
        List<String> notifyTypes = new List<String>();
        for (Repayment_Schedule__c schedule : newList) {
            Repayment_Schedule__c oldSchedule = oldMap.get(schedule.Id);
            if (oldSchedule != null && !'Overdue'.equals(oldSchedule.Status__c) && 'Overdue'.equals(schedule.Status__c)) {
                loanAppIds.add(schedule.Loan_Application__c);
                notifyTypes.add('Overdue');
            }
        }
        if (!loanAppIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
            System.enqueueJob(new CustomerNotificationQueueable(loanAppIds, notifyTypes));
        }
    }

    private static Map<Id, Repayment_Schedule__c> castOldMap(Map<Id, SObject> oldMap) {
        Map<Id, Repayment_Schedule__c> typed = new Map<Id, Repayment_Schedule__c>();
        if (oldMap != null) {
            for (Id key : oldMap.keySet()) {
                typed.put(key, (Repayment_Schedule__c) oldMap.get(key));
            }
        }
        return typed;
    }
}
