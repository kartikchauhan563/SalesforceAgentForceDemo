public with sharing class OfficerDecisionHandler {
    private static final Set<String> TERMINAL_STATUSES = new Set<String>{
        'Approved', 'Rejected', 'Disbursed', 'Withdrawn'
    };

    public class Request {
        @InvocableVariable(label='Loan Decision Id' required=true)
        public String loanDecisionId;
        @InvocableVariable(label='Loan Application Id' required=true)
        public String loanApplicationId;
        @InvocableVariable(label='New Decision' required=true)
        public String newDecision;
        @InvocableVariable(label='Override Reason' required=true)
        public String overrideReason;
    }

    public class Response {
        @InvocableVariable public String newApplicationStatus;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(
        label='Record Officer Override'
        description='Records officer override decision with mandatory reason and updates application status'
    )
    public static List<Response> recordOverride(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            results.add(res);
            if (req == null || String.isBlank(req.loanDecisionId)
                || String.isBlank(req.loanApplicationId)
                || String.isBlank(req.newDecision)
                || String.isBlank(req.overrideReason)) {
                res.success = false;
                res.errorMessage = 'Loan decision ID, application ID, new decision, and override reason are required.';
                continue;
            }
            if (req.overrideReason.trim().length() < 20) {
                res.success = false;
                res.errorMessage = 'Override reason must be at least 20 characters.';
                continue;
            }
            try {
                List<Loan_Application__c> apps = [
                    SELECT Id, Status__c
                    FROM Loan_Application__c
                    WHERE Id = :req.loanApplicationId
                    LIMIT 1
                ];
                if (apps.isEmpty()) {
                    res.success = false;
                    res.errorMessage = 'Loan application not found.';
                    continue;
                }
                if (TERMINAL_STATUSES.contains(apps[0].Status__c)) {
                    res.success = false;
                    res.errorMessage = 'Cannot override an application in terminal status: ' + apps[0].Status__c;
                    continue;
                }
                String officerDecision;
                String newStatus;
                if ('Approve'.equalsIgnoreCase(req.newDecision)) {
                    officerDecision = 'Override Approve';
                    newStatus = 'Approved';
                } else if ('Reject'.equalsIgnoreCase(req.newDecision)) {
                    officerDecision = 'Override Reject';
                    newStatus = 'Rejected';
                } else {
                    res.success = false;
                    res.errorMessage = 'New decision must be Approve or Reject for an override.';
                    continue;
                }
                Loan_Decision__c decision = new Loan_Decision__c(
                    Id = req.loanDecisionId,
                    Officer_Decision__c = officerDecision,
                    Officer_Comments__c = req.overrideReason,
                    Officer_Reviewed__c = true,
                    Officer_Reviewed_At__c = DateTime.now()
                );
                Loan_Application__c app = new Loan_Application__c(
                    Id = req.loanApplicationId,
                    Status__c = newStatus
                );
                Database.SaveResult dr = Database.update(decision, false);
                if (!dr.isSuccess()) {
                    res.success = false;
                    res.errorMessage = dr.getErrors()[0].getMessage();
                    continue;
                }
                Database.SaveResult ar = Database.update(app, false);
                if (!ar.isSuccess()) {
                    res.success = false;
                    res.errorMessage = ar.getErrors()[0].getMessage();
                    continue;
                }
                res.newApplicationStatus = newStatus;
                res.success = true;
            } catch (Exception ex) {
                res.success = false;
                res.errorMessage = ex.getMessage();
            }
        }
        return results;
    }
}
