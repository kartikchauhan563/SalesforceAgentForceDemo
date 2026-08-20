/**
 * Shared test data factory for NBFC loan origination platform tests.
 */
@isTest
public class NBFC_TestDataFactory {
    public static Account createPersonAccount() {
        Account applicant;
        if (AccountFieldHelper.hasPersonAccounts()) {
            Schema.RecordTypeInfo personRt = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount');
            applicant = new Account();
            applicant.put('FirstName', 'Test');
            applicant.put('LastName', 'Applicant');
            applicant.put('PersonEmail', 'test.applicant@example.com');
            applicant.put('PersonBirthdate', Date.today().addYears(-30));
            if (personRt != null) {
                applicant.put('RecordTypeId', personRt.getRecordTypeId());
            }
        } else {
            applicant = new Account(Name = 'Test Applicant');
        }
        insert applicant;
        return applicant;
    }

    public static Loan_Product__c createLoanProduct() {
        Loan_Product__c product = new Loan_Product__c(
            Name = 'Personal Loan Test',
            Product_Code__c = 'PL-TEST-' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            Product_Type__c = 'Personal',
            Min_Loan_Amount__c = 10000,
            Max_Loan_Amount__c = 5000000,
            Min_Tenure__c = 3,
            Max_Tenure__c = 84,
            Required_Documents__c = 'PAN Card, Aadhaar Card',
            Is_Active__c = true
        );
        insert product;
        return product;
    }

    public static Loan_Application__c createLoanApplication(
        Account applicant,
        Loan_Product__c product,
        String status
    ) {
        Loan_Application__c app = new Loan_Application__c(
            Applicant__c = applicant.Id,
            Loan_Product__c = product.Id,
            Loan_Amount__c = 250000,
            Tenure_Months__c = 24,
            Monthly_Income__c = 75000,
            Existing_EMI__c = 10000,
            Credit_Score__c = 720,
            Status__c = status
        );
        insert app;
        return app;
    }

    public static List<Loan_Application__c> createLoanApplications(
        Account applicant,
        Loan_Product__c product,
        Integer count
    ) {
        List<Loan_Application__c> apps = new List<Loan_Application__c>();
        for (Integer i = 0; i < count; i++) {
            apps.add(new Loan_Application__c(
                Applicant__c = applicant.Id,
                Loan_Product__c = product.Id,
                Loan_Amount__c = 250000 + (i * 1000),
                Tenure_Months__c = 24,
                Monthly_Income__c = 75000,
                Existing_EMI__c = 10000,
                Credit_Score__c = 720,
                Status__c = 'Draft'
            ));
        }
        insert apps;
        return apps;
    }

    public static Applicant_Document__c createDocument(Id loanAppId, String docType, Boolean uploaded) {
        Applicant_Document__c doc = new Applicant_Document__c(
            Loan_Application__c = loanAppId,
            Document_Type__c = docType,
            Is_Mandatory__c = true,
            Uploaded__c = uploaded,
            Verified__c = false
        );
        insert doc;
        return doc;
    }

    public static Agent_Check_Result__c createAgentResult(
        Id loanAppId,
        String agentName,
        String status,
        Decimal scoreImpact
    ) {
        Agent_Check_Result__c result = new Agent_Check_Result__c(
            Loan_Application__c = loanAppId,
            Agent_Name__c = agentName,
            Status__c = status,
            Score_Impact__c = scoreImpact,
            Run_Started_At__c = DateTime.now().addMinutes(-1)
        );
        insert result;
        return result;
    }
}
