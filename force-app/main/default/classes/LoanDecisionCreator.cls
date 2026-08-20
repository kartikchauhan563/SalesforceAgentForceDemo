public with sharing class LoanDecisionCreator {
    public class Request {
        @InvocableVariable(label='Loan Application Id' required=true)
        public String loanApplicationId;
        @InvocableVariable(label='Recommendation' required=true)
        public String recommendation;
        @InvocableVariable(label='Confidence Score' required=true)
        public Decimal confidenceScore;
        @InvocableVariable(label='Approved Amount')
        public Decimal approvedAmount;
        @InvocableVariable(label='Decision Summary')
        public String decisionSummary;
        @InvocableVariable(label='Key Reasons')
        public String keyReasons;
        @InvocableVariable(label='Missing Paperwork')
        public String missingPaperwork;
        @InvocableVariable(label='Next Best Action')
        public String nextBestAction;
        @InvocableVariable(label='Conditions')
        public String conditions;
        @InvocableVariable(label='Risk Score')
        public Decimal riskScore;
    }

    public class Response {
        @InvocableVariable public String loanDecisionId;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(
        label='Create Loan Decision'
        description='Creates a Loan_Decision__c record with AI recommendation output'
    )
    public static List<Response> create(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            results.add(res);
            if (req == null || String.isBlank(req.loanApplicationId)
                || String.isBlank(req.recommendation)) {
                res.success = false;
                res.errorMessage = 'Loan application ID and recommendation are required.';
                continue;
            }
            try {
                Loan_Decision__c decision = new Loan_Decision__c(
                    Loan_Application__c = req.loanApplicationId,
                    Recommendation__c = req.recommendation,
                    Confidence_Score__c = req.confidenceScore,
                    Approved_Amount__c = req.approvedAmount,
                    Decision_Summary__c = req.decisionSummary,
                    Key_Reasons__c = req.keyReasons,
                    Missing_Paperwork__c = req.missingPaperwork,
                    Next_Best_Action__c = req.nextBestAction,
                    Conditions__c = req.conditions,
                    Generated_By__c = 'AI Agent',
                    AI_Model__c = 'Agentforce Decision Agent',
                    Generated_At__c = DateTime.now(),
                    Officer_Reviewed__c = false
                );
                Database.SaveResult sr = Database.insert(decision, false);
                if (sr.isSuccess()) {
                    res.loanDecisionId = sr.getId();
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
