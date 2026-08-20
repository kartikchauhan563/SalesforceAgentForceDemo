public with sharing class EMICalculator {
    public class Request {
        @InvocableVariable(label='Principal' required=true)
        public Decimal principal;
        @InvocableVariable(label='Annual Interest Rate' required=true)
        public Decimal annualInterestRate;
        @InvocableVariable(label='Tenure Months' required=true)
        public Decimal tenureMonths;
    }

    public class Response {
        @InvocableVariable public Decimal calculatedEmi;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(
        label='Calculate EMI'
        description='Calculates monthly EMI using standard reducing-balance formula'
    )
    public static List<Response> calculate(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            results.add(res);
            if (req == null || req.principal == null || req.tenureMonths == null
                || req.principal <= 0 || req.tenureMonths <= 0) {
                res.success = false;
                res.errorMessage = 'Principal and tenure must be greater than zero.';
                continue;
            }
            Decimal rate = req.annualInterestRate == null ? 0 : req.annualInterestRate;
            Decimal monthlyRate = rate / 12 / 100;
            Decimal n = req.tenureMonths;
            if (monthlyRate == 0) {
                res.calculatedEmi = (req.principal / n).setScale(2);
            } else {
                Double factor = Math.pow(1 + monthlyRate.doubleValue(), n.doubleValue());
                Decimal emi = req.principal * monthlyRate * (factor / (factor - 1));
                res.calculatedEmi = emi.setScale(2);
            }
            res.success = true;
        }
        return results;
    }
}
