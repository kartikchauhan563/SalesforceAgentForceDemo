public with sharing class AgentCheckResultCreator {
    public class Request {
        @InvocableVariable(label='Loan Application Id' required=true)
        public String loanApplicationId;
        @InvocableVariable(label='Agent Name' required=true)
        public String agentName;
        @InvocableVariable(label='Status' required=true)
        public String status;
        @InvocableVariable(label='Result' required=true)
        public String result;
        @InvocableVariable(label='Score Impact' required=true)
        public Decimal scoreImpact;
        @InvocableVariable(label='Confidence')
        public Decimal confidence;
        @InvocableVariable(label='Reason')
        public String reason;
        @InvocableVariable(label='Recommendations')
        public String recommendations;
        @InvocableVariable(label='Execution Time Ms')
        public Decimal executionTimeMs;
    }

    public class Response {
        @InvocableVariable public String agentCheckResultId;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(
        label='Create Agent Check Result'
        description='Creates an Agent_Check_Result__c record for an agent run'
    )
    public static List<Response> create(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            results.add(res);
            if (req == null || String.isBlank(req.loanApplicationId) || String.isBlank(req.agentName)) {
                res.success = false;
                res.errorMessage = 'Loan application ID and agent name are required.';
                continue;
            }
            try {
                DateTime startedAt = DateTime.now().addSeconds(-1);
                Agent_Check_Result__c record = new Agent_Check_Result__c(
                    Loan_Application__c = req.loanApplicationId,
                    Agent_Name__c = req.agentName,
                    Status__c = String.isBlank(req.status) ? 'Completed' : req.status,
                    Result__c = req.result,
                    Score_Impact__c = req.scoreImpact,
                    Confidence__c = req.confidence,
                    Reason__c = req.reason,
                    Recommendations__c = req.recommendations,
                    Run_Started_At__c = startedAt,
                    Run_Completed_At__c = DateTime.now(),
                    Execution_Time_Ms__c = req.executionTimeMs
                );
                Database.SaveResult sr = Database.insert(record, false);
                if (sr.isSuccess()) {
                    res.agentCheckResultId = sr.getId();
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
