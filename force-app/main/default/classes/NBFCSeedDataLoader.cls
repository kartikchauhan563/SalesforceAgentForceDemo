/**
 * Seeds NBFC loan origination demo data for sandboxes and UAT orgs.
 * Invoke via: NBFCSeedDataLoader.load(new NBFCSeedDataLoader.LoadRequest());
 */
public with sharing class NBFCSeedDataLoader {
    public class LoadRequest {
        @InvocableVariable(label='Scenario' description='minimal, standard, or demo')
        public String scenario;
        @InvocableVariable(label='Applicant Count')
        public Integer applicantCount;
        @InvocableVariable(label='Applications Per Applicant')
        public Integer applicationsPerApplicant;
    }

    public class LoadResult {
        @InvocableVariable public Integer applicantsCreated;
        @InvocableVariable public Integer productsCreated;
        @InvocableVariable public Integer applicationsCreated;
        @InvocableVariable public Integer childRecordsCreated;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Load NBFC Seed Data' description='Creates sample loan origination data')
    public static List<LoadResult> loadInvocable(List<LoadRequest> requests) {
        List<LoadResult> results = new List<LoadResult>();
        if (requests == null || requests.isEmpty()) {
            results.add(load(buildDefaultRequest('standard')));
            return results;
        }
        for (LoadRequest req : requests) {
            results.add(load(req));
        }
        return results;
    }

    public static LoadResult load(LoadRequest request) {
        LoadRequest cfg = normalizeRequest(request);
        LoadResult result = new LoadResult();
        result.applicantsCreated = 0;
        result.productsCreated = 0;
        result.applicationsCreated = 0;
        result.childRecordsCreated = 0;

        List<Loan_Product__c> products = createProducts(cfg.scenario);
        result.productsCreated = products.size();

        List<Account> applicants = createApplicants(cfg.applicantCount);
        result.applicantsCreated = applicants.size();

        List<Loan_Application__c> applications = createApplications(applicants, products, cfg);
        result.applicationsCreated = applications.size();

        Integer childCount = 0;
        childCount += createDocumentsForApplications(applications, cfg.scenario);
        if (cfg.scenario == 'demo') {
            childCount += createAgentAndDecisionData(applications);
            childCount += createRepaymentSchedules(applications);
        } else if (cfg.scenario == 'standard') {
            childCount += createPartialAgentData(applications);
        }
        result.childRecordsCreated = childCount;
        result.message = 'Seed load complete for scenario: ' + cfg.scenario;
        return result;
    }

    public static LoadResult load(String scenario) {
        LoadRequest req = buildDefaultRequest(scenario);
        return load(req);
    }

    private static LoadRequest normalizeRequest(LoadRequest request) {
        if (request == null) {
            return buildDefaultRequest('standard');
        }
        if (String.isBlank(request.scenario)) {
            request.scenario = 'standard';
        }
        request.scenario = request.scenario.toLowerCase();
        if (request.applicantCount == null || request.applicantCount < 1) {
            request.applicantCount = scenarioApplicantCount(request.scenario);
        }
        if (request.applicationsPerApplicant == null || request.applicationsPerApplicant < 1) {
            request.applicationsPerApplicant = scenarioAppsPerApplicant(request.scenario);
        }
        return request;
    }

    private static LoadRequest buildDefaultRequest(String scenario) {
        LoadRequest req = new LoadRequest();
        req.scenario = String.isBlank(scenario) ? 'standard' : scenario.toLowerCase();
        req.applicantCount = scenarioApplicantCount(req.scenario);
        req.applicationsPerApplicant = scenarioAppsPerApplicant(req.scenario);
        return req;
    }

    private static Integer scenarioApplicantCount(String scenario) {
        if ('minimal'.equals(scenario)) {
            return 3;
        }
        if ('demo'.equals(scenario)) {
            return 8;
        }
        return 5;
    }

    private static Integer scenarioAppsPerApplicant(String scenario) {
        if ('minimal'.equals(scenario)) {
            return 1;
        }
        if ('demo'.equals(scenario)) {
            return 2;
        }
        return 1;
    }

    /** Creates active loan products with external-id product codes for idempotent re-runs. */
    private static List<Loan_Product__c> createProducts(String scenario) {
        List<Loan_Product__c> templates = new List<Loan_Product__c>();
        templates.add(buildProduct(
            'NBFC Personal Loan',
            'NBFC-PL-001',
            'Personal',
            'PAN Card, Aadhaar Card, Salary Slip, Bank Statement 3 months',
            10000, 1500000, 6, 60
        ));
        templates.add(buildProduct(
            'NBFC Business Loan',
            'NBFC-BL-001',
            'Business',
            'PAN Card, Aadhaar Card, GST Returns, Bank Statement 6 months, Business Registration',
            50000, 5000000, 12, 84
        ));
        if ('demo'.equals(scenario)) {
            templates.add(buildProduct(
                'NBFC Vehicle Loan',
                'NBFC-VL-001',
                'Vehicle',
                'PAN Card, Aadhaar Card, Driving License, Vehicle Documents',
                100000, 2500000, 12, 72
            ));
        }

        Map<String, Loan_Product__c> existingByCode = new Map<String, Loan_Product__c>();
        Set<String> codes = new Set<String>();
        for (Loan_Product__c p : templates) {
            codes.add(p.Product_Code__c);
        }
        for (Loan_Product__c existing : [
            SELECT Id, Product_Code__c FROM Loan_Product__c WHERE Product_Code__c IN :codes
        ]) {
            existingByCode.put(existing.Product_Code__c, existing);
        }

        List<Loan_Product__c> toInsert = new List<Loan_Product__c>();
        List<Loan_Product__c> results = new List<Loan_Product__c>();
        for (Loan_Product__c template : templates) {
            if (existingByCode.containsKey(template.Product_Code__c)) {
                results.add(existingByCode.get(template.Product_Code__c));
            } else {
                toInsert.add(template);
            }
        }
        if (!toInsert.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(toInsert, false);
            logFailures('Loan_Product__c', insertResults);
            for (Integer i = 0; i < toInsert.size(); i++) {
                if (insertResults[i].isSuccess()) {
                    results.add(toInsert[i]);
                }
            }
        }
        return results;
    }

    private static Loan_Product__c buildProduct(
        String name,
        String productCode,
        String productType,
        String requiredDocs,
        Decimal minAmount,
        Decimal maxAmount,
        Integer minTenure,
        Integer maxTenure
    ) {
        return new Loan_Product__c(
            Name = name,
            Product_Code__c = productCode,
            Product_Type__c = productType,
            Required_Documents__c = requiredDocs,
            Min_Loan_Amount__c = minAmount,
            Max_Loan_Amount__c = maxAmount,
            Min_Tenure__c = minTenure,
            Max_Tenure__c = maxTenure,
            Min_Credit_Score__c = 650,
            Min_Income_Required__c = 25000,
            Max_FOIR__c = 65,
            Is_Active__c = true,
            Launch_Date__c = Date.today().addYears(-1)
        );
    }

    /** Creates applicant accounts (Person or Business depending on org config). */
    private static List<Account> createApplicants(Integer count) {
        List<Account> applicants = new List<Account>();
        List<String> firstNames = new List<String>{ 'Aarav', 'Priya', 'Rahul', 'Sneha', 'Vikram', 'Ananya', 'Karan', 'Meera' };
        List<String> lastNames = new List<String>{ 'Sharma', 'Patel', 'Singh', 'Iyer', 'Gupta', 'Reddy', 'Khan', 'Das' };
        Boolean usePersonAccounts = AccountFieldHelper.hasPersonAccounts();
        Schema.RecordTypeInfo personRt = usePersonAccounts
            ? Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount')
            : null;

        for (Integer i = 0; i < count; i++) {
            String firstName = firstNames[Math.mod(i, firstNames.size())];
            String lastName = lastNames[Math.mod(i, lastNames.size())];
            String suffix = String.valueOf(1000 + i);
            Account acc;
            if (usePersonAccounts) {
                acc = new Account();
                acc.put('FirstName', firstName);
                acc.put('LastName', lastName + ' ' + suffix);
                acc.put('PersonEmail', (firstName + '.' + lastName + suffix + '@nbfc-demo.example.com').toLowerCase());
                acc.put('PersonBirthdate', Date.today().addYears(-(25 + Math.mod(i, 20))));
                if (personRt != null) {
                    acc.put('RecordTypeId', personRt.getRecordTypeId());
                }
            } else {
                acc = new Account(Name = firstName + ' ' + lastName + ' ' + suffix);
            }
            acc.put('PAN_Number__c', 'ABCDE' + suffix + 'F');
            acc.put('Customer_Segment__c', Math.mod(i, 2) == 0 ? 'Salaried' : 'Self-Employed');
            acc.put('Employment_Status__c', 'Employed');
            acc.put('Employer_Name__c', 'Demo Corp ' + suffix);
            acc.put('Monthly_Income__c', 45000 + (i * 5000));
            acc.put('Annual_Income__c', (45000 + (i * 5000)) * 12);
            acc.put('Bureau_Score__c', 680 + (i * 10));
            acc.put('KYC_Status__c', 'Verified');
            acc.put('Existing_EMI_Total__c', 5000 + (i * 1000));
            applicants.add(acc);
        }
        Database.SaveResult[] results = Database.insert(applicants, false);
        logFailures('Account', results);
        List<Account> inserted = new List<Account>();
        for (Account acc : applicants) {
            if (acc.Id != null) {
                inserted.add(acc);
            }
        }
        return inserted;
    }

    /** Creates loan applications spread across lifecycle statuses. */
    private static List<Loan_Application__c> createApplications(
        List<Account> applicants,
        List<Loan_Product__c> products,
        LoadRequest cfg
    ) {
        if (applicants.isEmpty() || products.isEmpty()) {
            return new List<Loan_Application__c>();
        }
        List<String> statuses = statusSequence(cfg.scenario);
        List<Loan_Application__c> apps = new List<Loan_Application__c>();
        Integer statusIndex = 0;
        for (Integer a = 0; a < applicants.size(); a++) {
            Account applicant = applicants[a];
            for (Integer j = 0; j < cfg.applicationsPerApplicant; j++) {
                Loan_Product__c product = products[Math.mod(a + j, products.size())];
                Decimal income = applicant.Monthly_Income__c != null ? applicant.Monthly_Income__c : 50000;
                Decimal existingEmi = applicant.Existing_EMI_Total__c != null ? applicant.Existing_EMI_Total__c : 8000;
                Integer creditScore = applicant.Bureau_Score__c != null ? applicant.Bureau_Score__c.intValue() : 700;
                apps.add(new Loan_Application__c(
                    Applicant__c = applicant.Id,
                    Loan_Product__c = product.Id,
                    Loan_Amount__c = 150000 + (a * 25000) + (j * 10000),
                    Tenure_Months__c = 24 + Math.mod(a, 3) * 12,
                    Monthly_Income__c = income,
                    Existing_EMI__c = existingEmi,
                    Credit_Score__c = creditScore,
                    Loan_Purpose__c = 'Personal Use',
                    Application_Channel__c = Math.mod(a, 2) == 0 ? 'Web' : 'Mobile',
                    Priority__c = pickPriority(a, j),
                    Status__c = statuses[Math.mod(statusIndex, statuses.size())],
                    Application_Date__c = Date.today().addDays(-(a * 3 + j))
                ));
                statusIndex++;
            }
        }
        Database.SaveResult[] results = Database.insert(apps, false);
        logFailures('Loan_Application__c', results);
        List<Loan_Application__c> inserted = new List<Loan_Application__c>();
        for (Loan_Application__c app : apps) {
            if (app.Id != null) {
                inserted.add(app);
            }
        }
        return inserted;
    }

    private static List<String> statusSequence(String scenario) {
        if ('minimal'.equals(scenario)) {
            return new List<String>{ 'Draft', 'Submitted', 'Under Review' };
        }
        if ('demo'.equals(scenario)) {
            return new List<String>{
                'Draft', 'Submitted', 'Under Review', 'Documents Pending',
                'On Hold', 'Approved', 'Rejected', 'Disbursed'
            };
        }
        return new List<String>{ 'Draft', 'Submitted', 'Under Review', 'Approved', 'On Hold' };
    }

    private static String pickPriority(Integer applicantIndex, Integer appIndex) {
        Integer mod = Math.mod(applicantIndex + appIndex, 4);
        if (mod == 0) {
            return 'Low';
        }
        if (mod == 1) {
            return 'Medium';
        }
        if (mod == 2) {
            return 'High';
        }
        return 'Urgent';
    }

    /** Adds applicant documents; uploaded/verified mix varies by scenario. */
    private static Integer createDocumentsForApplications(List<Loan_Application__c> applications, String scenario) {
        if (applications.isEmpty()) {
            return 0;
        }
        Set<Id> productIds = new Set<Id>();
        for (Loan_Application__c app : applications) {
            productIds.add(app.Loan_Product__c);
        }
        Map<Id, Loan_Product__c> productsById = new Map<Id, Loan_Product__c>([
            SELECT Id, Required_Documents__c FROM Loan_Product__c WHERE Id IN :productIds
        ]);

        List<Applicant_Document__c> docs = new List<Applicant_Document__c>();
        Integer appIndex = 0;
        for (Loan_Application__c app : applications) {
            Loan_Product__c product = productsById.get(app.Loan_Product__c);
            if (product == null || String.isBlank(product.Required_Documents__c)) {
                appIndex++;
                continue;
            }
            List<String> docTypes = product.Required_Documents__c.split(',');
            Integer docIdx = 0;
            for (String rawType : docTypes) {
                String docType = rawType.trim();
                if (String.isBlank(docType)) {
                    continue;
                }
                Boolean uploaded = shouldUploadDocument(scenario, appIndex, docIdx);
                Boolean verified = uploaded && Math.mod(appIndex + docIdx, 3) != 0;
                docs.add(new Applicant_Document__c(
                    Loan_Application__c = app.Id,
                    Document_Type__c = docType,
                    Document_Category__c = mapDocCategory(docType),
                    Is_Mandatory__c = true,
                    Uploaded__c = uploaded,
                    Upload_Date__c = uploaded ? DateTime.now().addDays(-docIdx) : null,
                    Verified__c = verified,
                    Verification_Status__c = verified ? 'Verified' : (uploaded ? 'Pending' : 'Pending'),
                    Issue_Found__c = 'None'
                ));
                docIdx++;
            }
            appIndex++;
        }
        if (docs.isEmpty()) {
            return 0;
        }
        Database.SaveResult[] results = Database.insert(docs, false);
        logFailures('Applicant_Document__c', results);
        return countSuccess(results);
    }

    private static Boolean shouldUploadDocument(String scenario, Integer appIndex, Integer docIndex) {
        if ('minimal'.equals(scenario)) {
            return docIndex < 1;
        }
        if ('demo'.equals(scenario)) {
            return Math.mod(appIndex + docIndex, 4) != 3;
        }
        return Math.mod(appIndex + docIndex, 2) == 0;
    }

    private static String mapDocCategory(String docType) {
        if (docType.contains('PAN') || docType.contains('Aadhaar') || docType.contains('Passport')
            || docType.contains('License') || docType.contains('Voter') || docType.contains('Photograph')) {
            return 'KYC';
        }
        if (docType.contains('Salary') || docType.contains('Bank') || docType.contains('ITR')
            || docType.contains('Form 16') || docType.contains('GST')) {
            return 'Income';
        }
        if (docType.contains('Address')) {
            return 'Address';
        }
        return 'Collateral';
    }

    /** Creates agent check results for a subset of applications (standard scenario). */
    private static Integer createPartialAgentData(List<Loan_Application__c> applications) {
        Integer created = 0;
        List<Agent_Check_Result__c> agents = new List<Agent_Check_Result__c>();
        Integer idx = 0;
        for (Loan_Application__c app : applications) {
            if (Math.mod(idx, 2) != 0) {
                idx++;
                continue;
            }
            agents.add(buildAgentResult(app.Id, 'Document Verification Agent', 1, 'Completed', 'Pass', 5));
            agents.add(buildAgentResult(app.Id, 'Financial Health Agent', 2, 'Completed', 'Pass', 8));
            idx++;
        }
        if (!agents.isEmpty()) {
            Database.SaveResult[] results = Database.insert(agents, false);
            logFailures('Agent_Check_Result__c', results);
            created += countSuccess(results);
        }
        return created;
    }

    /** Creates full agent pipeline, risk, compliance, and decision records (demo scenario). */
    private static Integer createAgentAndDecisionData(List<Loan_Application__c> applications) {
        Integer created = 0;
        List<Agent_Check_Result__c> agents = new List<Agent_Check_Result__c>();
        List<Risk_Assessment__c> riskRows = new List<Risk_Assessment__c>();
        List<Compliance_Check__c> complianceRows = new List<Compliance_Check__c>();
        List<Loan_Decision__c> decisions = new List<Loan_Decision__c>();

        Integer idx = 0;
        for (Loan_Application__c app : applications) {
            if (!isAdvancedStatus(app.Status__c)) {
                idx++;
                continue;
            }
            agents.add(buildAgentResult(app.Id, 'Document Verification Agent', 1, 'Completed', 'Pass', 5));
            agents.add(buildAgentResult(app.Id, 'Financial Health Agent', 2, 'Completed', 'Pass', 10));
            agents.add(buildAgentResult(app.Id, 'Credit Risk Agent', 3, 'Completed', 'Warning', 15));
            agents.add(buildAgentResult(app.Id, 'Compliance Agent', 4, 'Completed', 'Pass', 0));
            agents.add(buildAgentResult(app.Id, 'Decision Agent', 5, 'Completed', 'Pass', 0));

            riskRows.add(new Risk_Assessment__c(
                Loan_Application__c = app.Id,
                Bureau_Score__c = app.Credit_Score__c,
                Bureau_Source__c = 'CIBIL',
                Final_Risk_Score__c = 20 + Math.mod(idx, 40),
                Risk_Category__c = pickRiskCategory(idx),
                Identity_Verified__c = true,
                Past_Defaults__c = 0,
                Past_Bounces_12M__c = Math.mod(idx, 2)
            ));

            complianceRows.add(new Compliance_Check__c(
                Loan_Application__c = app.Id,
                Rule_Name__c = 'RBI_KYC_Mandatory',
                Rule_Category__c = 'KYC',
                Status__c = Math.mod(idx, 5) == 0 ? 'Non-Compliant' : 'Compliant',
                Severity__c = Math.mod(idx, 5) == 0 ? 'Critical' : 'Low',
                Description__c = 'Seed compliance check',
                Checked_At__c = DateTime.now()
            ));

            if ('Approved'.equals(app.Status__c) || 'Rejected'.equals(app.Status__c) || 'On Hold'.equals(app.Status__c)) {
                decisions.add(new Loan_Decision__c(
                    Loan_Application__c = app.Id,
                    Recommendation__c = mapStatusToRecommendation(app.Status__c),
                    Confidence_Score__c = 75 + Math.mod(idx, 20),
                    Decision_Summary__c = 'AI decision generated from seed loader.',
                    Key_Reasons__c = 'Income stable; credit score acceptable.',
                    Generated_By__c = 'AI Agent',
                    Generated_At__c = DateTime.now()
                ));
            }
            idx++;
        }

        if (!agents.isEmpty()) {
            Database.SaveResult[] r = Database.insert(agents, false);
            logFailures('Agent_Check_Result__c', r);
            created += countSuccess(r);
        }
        if (!riskRows.isEmpty()) {
            Database.SaveResult[] r = Database.insert(riskRows, false);
            logFailures('Risk_Assessment__c', r);
            created += countSuccess(r);
        }
        if (!complianceRows.isEmpty()) {
            Database.SaveResult[] r = Database.insert(complianceRows, false);
            logFailures('Compliance_Check__c', r);
            created += countSuccess(r);
        }
        if (!decisions.isEmpty()) {
            Database.SaveResult[] r = Database.insert(decisions, false);
            logFailures('Loan_Decision__c', r);
            created += countSuccess(r);
        }
        return created;
    }

    private static Integer createRepaymentSchedules(List<Loan_Application__c> applications) {
        List<Repayment_Schedule__c> schedules = new List<Repayment_Schedule__c>();
        for (Loan_Application__c app : applications) {
            if (!'Disbursed'.equals(app.Status__c) && !'Approved'.equals(app.Status__c)) {
                continue;
            }
            Decimal emiAmount = app.Loan_Amount__c != null ? (app.Loan_Amount__c / 24).setScale(2) : 10000;
            for (Integer emi = 1; emi <= 6; emi++) {
                schedules.add(new Repayment_Schedule__c(
                    Loan_Application__c = app.Id,
                    EMI_Number__c = emi,
                    Due_Date__c = Date.today().addMonths(emi),
                    EMI_Amount__c = emiAmount,
                    Principal_Component__c = emiAmount * 0.7,
                    Interest_Component__c = emiAmount * 0.3,
                    Outstanding_Balance__c = emiAmount * (24 - emi),
                    Status__c = emi == 1 ? 'Paid' : (emi == 2 ? 'Overdue' : 'Pending'),
                    Paid_Amount__c = emi == 1 ? emiAmount : null,
                    Paid_Date__c = emi == 1 ? Date.today().addMonths(-1) : null,
                    Payment_Mode__c = 'NACH'
                ));
            }
        }
        if (schedules.isEmpty()) {
            return 0;
        }
        Database.SaveResult[] results = Database.insert(schedules, false);
        logFailures('Repayment_Schedule__c', results);
        return countSuccess(results);
    }

    private static Agent_Check_Result__c buildAgentResult(
        Id loanAppId,
        String agentName,
        Integer runOrder,
        String status,
        String result,
        Decimal scoreImpact
    ) {
        return new Agent_Check_Result__c(
            Loan_Application__c = loanAppId,
            Agent_Name__c = agentName,
            Agent_Run_Order__c = runOrder,
            Status__c = status,
            Result__c = result,
            Score_Impact__c = scoreImpact,
            Reason__c = 'Seed data agent result',
            Run_Started_At__c = DateTime.now().addMinutes(-10),
            Run_Completed_At__c = 'Completed'.equals(status) ? DateTime.now().addMinutes(-5) : null,
            Agent_Version__c = '1.0.0'
        );
    }

    private static Boolean isAdvancedStatus(String status) {
        return 'Under Review'.equals(status) || 'Documents Pending'.equals(status)
            || 'On Hold'.equals(status) || 'Approved'.equals(status)
            || 'Rejected'.equals(status) || 'Disbursed'.equals(status);
    }

    private static String pickRiskCategory(Integer index) {
        List<String> categories = new List<String>{ 'Low', 'Medium', 'High', 'Very High' };
        return categories[Math.mod(index, categories.size())];
    }

    private static String mapStatusToRecommendation(String status) {
        if ('Approved'.equals(status) || 'Disbursed'.equals(status)) {
            return 'Approve';
        }
        if ('Rejected'.equals(status)) {
            return 'Reject';
        }
        return 'Hold';
    }

    private static Integer countSuccess(Database.SaveResult[] results) {
        Integer count = 0;
        if (results == null) {
            return 0;
        }
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                count++;
            }
        }
        return count;
    }

    private static void logFailures(String objectLabel, Database.SaveResult[] results) {
        if (results == null) {
            return;
        }
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug(LoggingLevel.WARN, objectLabel + ' seed insert failed: ' + err.getMessage());
                }
            }
        }
    }
}
