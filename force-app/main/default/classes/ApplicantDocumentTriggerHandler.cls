/**
 * Handler for Applicant_Document__c — document upload, verification, and parent sync.
 */
public with sharing class ApplicantDocumentTriggerHandler implements ITriggerHandler {
    public static void dispatch(
        System.TriggerOperation operationType,
        List<Applicant_Document__c> newList,
        List<Applicant_Document__c> oldList,
        Map<Id, Applicant_Document__c> newMap,
        Map<Id, Applicant_Document__c> oldMap
    ) {
        TriggerDispatcher.dispatch(
            operationType,
            new ApplicantDocumentTriggerHandler(),
            newList,
            oldList,
            newMap,
            oldMap
        );
    }

    public void beforeInsert(List<SObject> newRecords) {
        setVerificationStatusPending((List<Applicant_Document__c>) newRecords);
    }

    public void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<Applicant_Document__c> docs = (List<Applicant_Document__c>) newRecords;
        Map<Id, Applicant_Document__c> typedOldMap = castOldMap(oldMap);
        validateExpiryDate(docs);
        syncVerifiedAndStatus(docs, typedOldMap);
    }

    public void beforeDelete(List<SObject> oldRecords) {}

    public void afterInsert(List<SObject> newRecords) {
        List<Applicant_Document__c> docs = (List<Applicant_Document__c>) newRecords;
        createHistoryRecord_DocUploaded(docs);
        updateParentMissingDocsList(docs);
    }

    public void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<Applicant_Document__c> docs = (List<Applicant_Document__c>) newRecords;
        Map<Id, Applicant_Document__c> typedOldMap = castOldMap(oldMap);
        createHistoryRecord_DocVerified(docs, typedOldMap);
        Set<Id> parentIds = collectParentIds(docs);
        updateParentMissingDocsList(parentIds);
        checkAllDocsVerified(docs, typedOldMap);
        publishDocumentAgentEvent(docs, typedOldMap);
    }

    public void afterDelete(List<SObject> oldRecords) {}

    public void afterUndelete(List<SObject> newRecords) {}

    public static void setVerificationStatusPending(List<Applicant_Document__c> newList) {
        if (newList == null) {
            return;
        }
        for (Applicant_Document__c doc : newList) {
            doc.Verification_Status__c = 'Pending';
            doc.Issue_Found__c = 'None';
        }
    }

    public static void validateExpiryDate(List<Applicant_Document__c> newList) {
        if (newList == null) {
            return;
        }
        for (Applicant_Document__c doc : newList) {
            if (doc.Expiry_Date__c != null && doc.Expiry_Date__c < Date.today()) {
                doc.Issue_Found__c = 'Expired';
                doc.Verified__c = false;
            }
        }
    }

    public static void syncVerifiedAndStatus(
        List<Applicant_Document__c> newList,
        Map<Id, Applicant_Document__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        for (Applicant_Document__c doc : newList) {
            Applicant_Document__c oldDoc = oldMap.get(doc.Id);
            if (oldDoc == null || doc.Verified__c == oldDoc.Verified__c) {
                continue;
            }
            if (doc.Verified__c == true) {
                doc.Verification_Status__c = 'Verified';
            } else if (doc.Issue_Found__c != null && !'None'.equals(doc.Issue_Found__c)) {
                doc.Verification_Status__c = 'Failed';
            }
        }
    }

    public static void createHistoryRecord_DocUploaded(List<Applicant_Document__c> newList) {
        if (newList == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Applicant_Document__c doc : newList) {
            if (doc.Uploaded__c != true) {
                continue;
            }
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = doc.Loan_Application__c;
            req.eventType = 'Document Uploaded';
            req.eventSubType = doc.Document_Type__c;
            req.triggeredBy = 'User';
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    public static void createHistoryRecord_DocVerified(
        List<Applicant_Document__c> newList,
        Map<Id, Applicant_Document__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<LoanApplicationHistoryHandler.HistoryRequest> requests = new List<LoanApplicationHistoryHandler.HistoryRequest>();
        for (Applicant_Document__c doc : newList) {
            Applicant_Document__c oldDoc = oldMap.get(doc.Id);
            if (oldDoc == null || doc.Verification_Status__c == oldDoc.Verification_Status__c) {
                continue;
            }
            LoanApplicationHistoryHandler.HistoryRequest req = new LoanApplicationHistoryHandler.HistoryRequest();
            req.loanApplicationId = doc.Loan_Application__c;
            req.eventSubType = doc.Document_Type__c;
            req.triggeredBy = 'User';
            if ('Verified'.equals(doc.Verification_Status__c)) {
                req.eventType = 'Document Verified';
            } else {
                req.eventType = 'Document Issue Flagged';
                req.eventDescription = doc.Issue_Found__c;
            }
            requests.add(req);
        }
        LoanApplicationHistoryHandler.createHistoryRecords(requests);
    }

    public static void updateParentMissingDocsList(List<Applicant_Document__c> newList) {
        updateParentMissingDocsList(collectParentIds(newList));
    }

    public static void updateParentMissingDocsList(Set<Id> parentIds) {
        if (parentIds == null || parentIds.isEmpty()) {
            return;
        }
        Map<Id, List<String>> missingByParent = new Map<Id, List<String>>();
        for (Id parentId : parentIds) {
            missingByParent.put(parentId, new List<String>());
        }
        for (Applicant_Document__c doc : [
            SELECT Loan_Application__c, Document_Type__c
            FROM Applicant_Document__c
            WHERE Loan_Application__c IN :parentIds
            AND Uploaded__c = FALSE
            AND Is_Mandatory__c = TRUE
        ]) {
            missingByParent.get(doc.Loan_Application__c).add(doc.Document_Type__c);
        }
        List<Loan_Application__c> updates = new List<Loan_Application__c>();
        for (Id parentId : missingByParent.keySet()) {
            List<String> missing = missingByParent.get(parentId);
            updates.add(new Loan_Application__c(
                Id = parentId,
                Missing_Documents__c = missing.isEmpty() ? null : String.join(missing, ', ')
            ));
        }
        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
    }

    public static void checkAllDocsVerified(
        List<Applicant_Document__c> newList,
        Map<Id, Applicant_Document__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        Set<Id> parentIdsToCheck = new Set<Id>();
        for (Applicant_Document__c doc : newList) {
            Applicant_Document__c oldDoc = oldMap.get(doc.Id);
            if (oldDoc != null && doc.Verified__c == true && oldDoc.Verified__c != true) {
                parentIdsToCheck.add(doc.Loan_Application__c);
            }
        }
        if (parentIdsToCheck.isEmpty()) {
            return;
        }
        Map<Id, Integer> unverifiedCount = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Loan_Application__c parentId, COUNT(Id) cnt
            FROM Applicant_Document__c
            WHERE Loan_Application__c IN :parentIdsToCheck
            AND Is_Mandatory__c = TRUE
            AND Verified__c = FALSE
            GROUP BY Loan_Application__c
        ]) {
            unverifiedCount.put((Id) ar.get('parentId'), (Integer) ar.get('cnt'));
        }
        List<Loan_Application__c> updates = new List<Loan_Application__c>();
        for (Id parentId : parentIdsToCheck) {
            if (!unverifiedCount.containsKey(parentId)) {
                updates.add(new Loan_Application__c(
                    Id = parentId,
                    Sub_Status__c = null
                ));
            }
        }
        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
    }

    public static void publishDocumentAgentEvent(
        List<Applicant_Document__c> newList,
        Map<Id, Applicant_Document__c> oldMap
    ) {
        if (newList == null || oldMap == null) {
            return;
        }
        List<NBFC_Agent_Trigger__e> events = new List<NBFC_Agent_Trigger__e>();
        for (Applicant_Document__c doc : newList) {
            Applicant_Document__c oldDoc = oldMap.get(doc.Id);
            if (oldDoc != null && doc.Uploaded__c == true && oldDoc.Uploaded__c != true) {
                NBFC_Agent_Trigger__e evt = new NBFC_Agent_Trigger__e();
                evt.Loan_Application_Id__c = String.valueOf(doc.Loan_Application__c);
                evt.Event_Action__c = AgentEventPublisher.ACTION_RUN_DOCUMENT_AGENT;
                evt.Triggered_At__c = DateTime.now();
                events.add(evt);
            }
        }
        AgentEventPublisher.publishEvents(events);
    }

    private static Set<Id> collectParentIds(List<Applicant_Document__c> docs) {
        Set<Id> parentIds = new Set<Id>();
        if (docs != null) {
            for (Applicant_Document__c doc : docs) {
                if (doc.Loan_Application__c != null) {
                    parentIds.add(doc.Loan_Application__c);
                }
            }
        }
        return parentIds;
    }

    private static Map<Id, Applicant_Document__c> castOldMap(Map<Id, SObject> oldMap) {
        Map<Id, Applicant_Document__c> typed = new Map<Id, Applicant_Document__c>();
        if (oldMap != null) {
            for (Id key : oldMap.keySet()) {
                typed.put(key, (Applicant_Document__c) oldMap.get(key));
            }
        }
        return typed;
    }
}
