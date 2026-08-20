public with sharing class Create_Compliance_Checks_Apex {
    public class Request {
        @InvocableVariable(label='Loan Application Id' required=true)
        public String loanApplicationId;
        @InvocableVariable(label='Checks Payload' required=true)
        public String checksPayload;
    }

    public class Response {
        @InvocableVariable public Integer recordsCreated;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(
        label='Create Compliance Checks'
        description='Bulk creates Compliance_Check__c records from a JSON array payload'
    )
    public static List<Response> createChecks(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            results.add(res);
            if (req == null || String.isBlank(req.loanApplicationId)
                || String.isBlank(req.checksPayload)) {
                res.success = false;
                res.errorMessage = 'Loan application ID and checks payload are required.';
                continue;
            }
            try {
                List<Object> rawChecks = (List<Object>) JSON.deserializeUntyped(req.checksPayload);
                List<Compliance_Check__c> records = new List<Compliance_Check__c>();
                for (Object item : rawChecks) {
                    Map<String, Object> check = (Map<String, Object>) item;
                    Compliance_Check__c row = new Compliance_Check__c(
                        Loan_Application__c = req.loanApplicationId,
                        Rule_Name__c = (String) check.get('ruleName'),
                        Rule_Category__c = (String) check.get('ruleCategory'),
                        Status__c = (String) check.get('status'),
                        Severity__c = (String) check.get('severity'),
                        Description__c = (String) check.get('description'),
                        Action_Required__c = (String) check.get('actionRequired'),
                        Regulation_Reference__c = (String) check.get('regulationReference'),
                        Checked_At__c = DateTime.now(),
                        Resolved__c = false
                    );
                    records.add(row);
                }
                if (records.isEmpty()) {
                    res.success = false;
                    res.errorMessage = 'No valid compliance checks found in payload.';
                    continue;
                }
                Database.SaveResult[] saveResults = Database.insert(records, false);
                Integer created = 0;
                List<String> errors = new List<String>();
                for (Database.SaveResult sr : saveResults) {
                    if (sr.isSuccess()) {
                        created++;
                    } else {
                        errors.add(sr.getErrors()[0].getMessage());
                    }
                }
                res.recordsCreated = created;
                res.success = created > 0;
                res.errorMessage = errors.isEmpty() ? null : String.join(errors, '; ');
            } catch (Exception ex) {
                res.success = false;
                res.errorMessage = 'Invalid checks payload. Expected JSON array. ' + ex.getMessage();
            }
        }
        return results;
    }
}
