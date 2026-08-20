/**
 * Queueable that evaluates uploaded documents and completes the Document Verification Agent.
 */
public with sharing class DocumentAgentQueueable implements Queueable {
    private Id loanAppId;

    public DocumentAgentQueueable(Id loanAppId) {
        this.loanAppId = loanAppId;
    }

    public void execute(QueueableContext ctx) {
        if (loanAppId == null) {
            return;
        }
        List<Applicant_Document__c> docs = [
            SELECT Id, Document_Type__c, Uploaded__c, Verified__c, Is_Mandatory__c,
                   Expiry_Date__c, Issue_Found__c
            FROM Applicant_Document__c
            WHERE Loan_Application__c = :loanAppId
        ];
        List<String> missing = new List<String>();
        List<String> issues = new List<String>();
        for (Applicant_Document__c doc : docs) {
            if (doc.Is_Mandatory__c == true && doc.Uploaded__c != true) {
                missing.add(doc.Document_Type__c);
            }
            if (doc.Expiry_Date__c != null && doc.Expiry_Date__c < Date.today()) {
                issues.add(doc.Document_Type__c + ' expired');
            }
            if (doc.Issue_Found__c != null && !'None'.equals(doc.Issue_Found__c)) {
                issues.add(doc.Document_Type__c + ': ' + doc.Issue_Found__c);
            }
        }
        String result = missing.isEmpty() && issues.isEmpty() ? 'Pass' : (missing.isEmpty() ? 'Warning' : 'Fail');
        Decimal scoreImpact = 'Pass'.equals(result) ? 0 : ('Warning'.equals(result) ? 5 : 15);
        String reason = missing.isEmpty()
            ? (issues.isEmpty() ? 'All mandatory documents present.' : String.join(issues, '; '))
            : 'Missing: ' + String.join(missing, ', ');

        completeAgentResult('Document Verification Agent', result, scoreImpact, reason);
        System.enqueueJob(new FinancialAgentQueueable(loanAppId));
    }

    private void completeAgentResult(String agentName, String result, Decimal scoreImpact, String reason) {
        List<Agent_Check_Result__c> results = [
            SELECT Id
            FROM Agent_Check_Result__c
            WHERE Loan_Application__c = :loanAppId
            AND Agent_Name__c = :agentName
            LIMIT 1
        ];
        if (results.isEmpty()) {
            return;
        }
        Agent_Check_Result__c agentResult = results[0];
        agentResult.Status__c = 'Completed';
        agentResult.Result__c = result;
        agentResult.Score_Impact__c = scoreImpact;
        agentResult.Reason__c = reason;
        agentResult.Run_Completed_At__c = DateTime.now();
        Database.update(agentResult, false);
    }
}
