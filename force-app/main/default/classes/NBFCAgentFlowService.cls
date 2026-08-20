/**
 * Invocable Apex service backing NBFC Agentforce Auto-Launched flows.
 */
public with sharing class NBFCAgentFlowService {
    private static final String AGENT_DOCUMENT = 'Document Verification Agent';
    private static final String AGENT_FINANCIAL = 'Financial Health Agent';
    private static final String AGENT_RISK = 'Credit Risk Agent';
    private static final String AGENT_COMPLIANCE = 'Compliance Agent';
    private static final String AGENT_DECISION = 'Decision Agent';
    private static final String PRODUCT_CODE_ALL = 'ALL';
    private static final Set<String> CLOSED_STATUSES = new Set<String>{
        'Approved', 'Rejected', 'Disbursed', 'Withdrawn'
    };

    // --- Helpers ---

    private static Id resolveLoanAppId(String input) {
        if (String.isBlank(input)) {
            return null;
        }
        String trimmed = input.trim();
        if (isSalesforceId(trimmed)) {
            return (Id) trimmed;
        }
        if (trimmed.startsWithIgnoreCase('LA-')) {
            List<Loan_Application__c> apps = [
                SELECT Id FROM Loan_Application__c WHERE Name = :trimmed LIMIT 1
            ];
            return apps.isEmpty() ? null : apps[0].Id;
        }
        try {
            return (Id) trimmed;
        } catch (Exception e) {
            return null;
        }
    }

    private static Boolean isSalesforceId(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        String v = value.trim();
        return (v.length() == 15 || v.length() == 18) && Pattern.matches('^[a-zA-Z0-9]{15,18}$', v);
    }

    private static String maskPan(String pan) {
        if (String.isBlank(pan) || pan.length() < 4) {
            return null;
        }
        return 'XXXXXX' + pan.right(4);
    }

    private static String maskAadhaar(String aadhaar) {
        if (String.isBlank(aadhaar)) {
            return null;
        }
        String digits = aadhaar.replaceAll('[^0-9]', '');
        if (digits.length() < 4) {
            return null;
        }
        return 'XXXX-XXXX-' + digits.right(4);
    }

    private static Policy_Rule__mdt queryPolicyRule(String developerName, String productCode) {
        String code = String.isBlank(productCode) ? PRODUCT_CODE_ALL : productCode.trim();
        List<Policy_Rule__mdt> rules = [
            SELECT DeveloperName, MasterLabel, Threshold_Value__c, Severity__c, Description__c, Product_Code__c
            FROM Policy_Rule__mdt
            WHERE DeveloperName = :developerName
            AND Is_Active__c = TRUE
            AND Product_Code__c = :code
            LIMIT 1
        ];
        if (!rules.isEmpty()) {
            return rules[0];
        }
        if (!PRODUCT_CODE_ALL.equals(code)) {
            return queryPolicyRule(developerName, PRODUCT_CODE_ALL);
        }
        return null;
    }

    private static String formatCurrency(Decimal amount) {
        if (amount == null) {
            return '';
        }
        return 'INR ' + amount.setScale(2).format();
    }

    private static String mapRecommendationToStatus(String recommendation) {
        if ('Approve'.equalsIgnoreCase(recommendation)) {
            return 'Approved';
        }
        if ('Hold'.equalsIgnoreCase(recommendation)) {
            return 'On Hold';
        }
        if ('Reject'.equalsIgnoreCase(recommendation)) {
            return 'Rejected';
        }
        return null;
    }

    private static Integer severityRank(String severity) {
        if ('Critical'.equals(severity)) {
            return 0;
        }
        if ('High'.equals(severity)) {
            return 1;
        }
        if ('Medium'.equals(severity)) {
            return 2;
        }
        if ('Low'.equals(severity)) {
            return 3;
        }
        return 99;
    }

    private static String applicantDisplayName(Loan_Application__c app) {
        if (app.Applicant__r == null) {
            return null;
        }
        return app.Applicant__r.Name;
    }

    private static String documentStatusSymbol(Applicant_Document__c doc) {
        if (doc.Uploaded__c != true) {
            return 'MISSING';
        }
        if (doc.Verified__c == true && String.isBlank(doc.Issue_Found__c)) {
            return 'VERIFIED';
        }
        return 'WARNING';
    }

    private static String buildHistoryLine(Loan_Application_History__c h) {
        List<String> parts = new List<String>();
        parts.add(String.valueOf(h.Event_Timestamp__c));
        parts.add(h.Event_Type__c);
        parts.add(h.Triggered_By__c);
        if (String.isNotBlank(h.Agent_Name__c)) {
            parts.add(h.Agent_Name__c);
        }
        if (String.isNotBlank(h.Previous_Status__c) || String.isNotBlank(h.New_Status__c)) {
            parts.add((h.Previous_Status__c != null ? h.Previous_Status__c : '') + ' -> '
                + (h.New_Status__c != null ? h.New_Status__c : ''));
        }
        if (String.isNotBlank(h.Decision_Made__c)) {
            parts.add(h.Decision_Made__c);
        }
        return String.join(parts, ' | ');
    }

    private static String buildAuditLine(Loan_Application_History__c h) {
        return String.join(new List<String>{
            String.valueOf(h.Event_Timestamp__c),
            h.Event_Type__c,
            h.Triggered_By__c,
            h.Agent_Name__c,
            h.Previous_Status__c,
            h.New_Status__c,
            h.Decision_Made__c,
            h.Severity__c,
            String.valueOf(h.Compliance_Relevant__c)
        }, ' | ');
    }

    private static User resolveUnderwriter(String nameOrId) {
        if (String.isBlank(nameOrId)) {
            return null;
        }
        String input = nameOrId.trim();
        if (isSalesforceId(input)) {
            List<User> users = [
                SELECT Id, Name, Email FROM User WHERE Id = :input AND IsActive = TRUE LIMIT 1
            ];
            return users.isEmpty() ? null : users[0];
        }
        String likeName = '%' + input + '%';
        List<User> users = [
            SELECT Id, Name, Email
            FROM User
            WHERE Name LIKE :likeName
            AND IsActive = TRUE
            AND (Profile.Name LIKE '%Underwriter%' OR Profile.Name LIKE '%Loan Officer%')
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0];
    }

    private static Integer countTokens(String csv) {
        if (String.isBlank(csv)) {
            return 0;
        }
        return csv.split(',').size();
    }

    private static String nullSafe(String value) {
        return value == null ? '' : value;
    }

    // --- 1. Search Applications By Name ---

    public class SearchApplicationsByNameRequest {
        @InvocableVariable(label='Applicant Name Search' required=true)
        public String applicantNameSearch;
    }
    public class SearchApplicationsByNameResponse {
        @InvocableVariable public String matchingApplications;
        @InvocableVariable public Integer matchCount;
        @InvocableVariable public Boolean recordFound;
        @InvocableVariable public String errorMessage;
    }

    public static List<SearchApplicationsByNameResponse> searchApplicationsByName(
        List<SearchApplicationsByNameRequest> requests
    ) {
        List<SearchApplicationsByNameResponse> results = new List<SearchApplicationsByNameResponse>();
        for (SearchApplicationsByNameRequest req : requests) {
            SearchApplicationsByNameResponse res = new SearchApplicationsByNameResponse();
            results.add(res);
            if (req == null || String.isBlank(req.applicantNameSearch)) {
                res.recordFound = false;
                res.errorMessage = 'Applicant name search is required.';
                continue;
            }
            String likeName = '%' + req.applicantNameSearch.trim() + '%';
            List<Loan_Application__c> apps = [
                SELECT Name, Applicant__r.Name, Loan_Product__r.Name, Loan_Amount__c, Status__c
                FROM Loan_Application__c
                WHERE Applicant__r.Name LIKE :likeName
                ORDER BY Application_Date__c DESC
                LIMIT 10
            ];
            if (apps.isEmpty()) {
                res.recordFound = false;
                res.errorMessage = 'No loan applications found for applicants matching the name provided. Please check the name and try again.';
                res.matchCount = 0;
                continue;
            }
            List<String> lines = new List<String>();
            for (Loan_Application__c app : apps) {
                lines.add(
                    nullSafe(app.Name) + ' | ' + nullSafe(applicantDisplayName(app)) + ' | '
                    + nullSafe(app.Loan_Product__r != null ? app.Loan_Product__r.Name : null) + ' | '
                    + formatCurrency(app.Loan_Amount__c) + ' | ' + nullSafe(app.Status__c)
                );
            }
            res.matchingApplications = String.join(lines, '\n');
            res.matchCount = apps.size();
            res.recordFound = true;
        }
        return results;
    }

    // --- 2. Get Application Status History ---

    public class GetApplicationStatusHistoryRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
        @InvocableVariable(label='Compliance Relevant Only') public Boolean complianceRelevantOnly;
        @InvocableVariable(label='Limit Records') public Integer limitRecords;
    }
    public class GetApplicationStatusHistoryResponse {
        @InvocableVariable public String historyEventsText;
        @InvocableVariable public Integer totalEventsFound;
        @InvocableVariable public Boolean recordFound;
    }

    public static List<GetApplicationStatusHistoryResponse> getApplicationStatusHistory(
        List<GetApplicationStatusHistoryRequest> requests
    ) {
        List<GetApplicationStatusHistoryResponse> results = new List<GetApplicationStatusHistoryResponse>();
        for (GetApplicationStatusHistoryRequest req : requests) {
            GetApplicationStatusHistoryResponse res = new GetApplicationStatusHistoryResponse();
            results.add(res);
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.recordFound = false;
                continue;
            }
            Integer lim = (req != null && req.limitRecords != null && req.limitRecords > 0) ? req.limitRecords : 10;
            Boolean complianceOnly = req != null && req.complianceRelevantOnly == true;
            String soql = 'SELECT Event_Type__c, Event_Sub_Type__c, Event_Timestamp__c, Triggered_By__c, '
                + 'Agent_Name__c, Previous_Status__c, New_Status__c, Decision_Made__c, Officer_Override__c, '
                + 'Severity__c, Compliance_Relevant__c, Event_Description__c '
                + 'FROM Loan_Application_History__c WHERE Loan_Application__c = :loanAppId';
            if (complianceOnly) {
                soql += ' AND Compliance_Relevant__c = true';
            }
            soql += ' ORDER BY Event_Timestamp__c DESC LIMIT :lim';
            List<Loan_Application_History__c> events = Database.query(soql);
            if (events.isEmpty()) {
                res.recordFound = false;
                res.totalEventsFound = 0;
                continue;
            }
            List<String> lines = new List<String>();
            for (Loan_Application_History__c h : events) {
                lines.add(buildHistoryLine(h));
            }
            res.historyEventsText = String.join(lines, '\n');
            res.totalEventsFound = events.size();
            res.recordFound = true;
        }
        return results;
    }

    // --- 3. Get Uploaded Documents ---

    public class GetUploadedDocumentsRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
    }
    public class GetUploadedDocumentsResponse {
        @InvocableVariable public String documentsSummaryText;
        @InvocableVariable public Integer totalDocuments;
        @InvocableVariable public Integer uploadedCount;
        @InvocableVariable public Integer verifiedCount;
        @InvocableVariable public Integer failedCount;
        @InvocableVariable public Integer missingCount;
        @InvocableVariable public String issuesFoundText;
        @InvocableVariable public String missingDocumentsText;
        @InvocableVariable public Boolean recordFound;
    }

    public static List<GetUploadedDocumentsResponse> getUploadedDocuments(
        List<GetUploadedDocumentsRequest> requests
    ) {
        List<GetUploadedDocumentsResponse> results = new List<GetUploadedDocumentsResponse>();
        for (GetUploadedDocumentsRequest req : requests) {
            GetUploadedDocumentsResponse res = new GetUploadedDocumentsResponse();
            results.add(res);
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.recordFound = false;
                continue;
            }
            List<Applicant_Document__c> docs = [
                SELECT Document_Type__c, Document_Category__c, Is_Mandatory__c, Uploaded__c,
                       Upload_Date__c, Verified__c, Verification_Status__c, Issue_Found__c,
                       OCR_Confidence__c, Document_Number__c, Expiry_Date__c, Agent_Comment__c
                FROM Applicant_Document__c
                WHERE Loan_Application__c = :loanAppId
            ];
            if (docs.isEmpty()) {
                res.recordFound = false;
                continue;
            }
            List<String> summary = new List<String>();
            List<String> issues = new List<String>();
            List<String> missing = new List<String>();
            Integer uploaded = 0, verified = 0, failed = 0, miss = 0;
            for (Applicant_Document__c doc : docs) {
                String symbol = documentStatusSymbol(doc);
                summary.add(doc.Document_Type__c + ' [' + symbol + '] ' + nullSafe(doc.Verification_Status__c));
                if (doc.Uploaded__c == true) {
                    uploaded++;
                }
                if (doc.Verified__c == true) {
                    verified++;
                }
                if (String.isNotBlank(doc.Issue_Found__c)) {
                    failed++;
                    issues.add(doc.Document_Type__c + ': ' + doc.Issue_Found__c);
                }
                if (doc.Uploaded__c != true && doc.Is_Mandatory__c == true) {
                    miss++;
                    missing.add(doc.Document_Type__c);
                }
            }
            res.documentsSummaryText = String.join(summary, '\n');
            res.issuesFoundText = String.join(issues, '\n');
            res.missingDocumentsText = String.join(missing, ', ');
            res.totalDocuments = docs.size();
            res.uploadedCount = uploaded;
            res.verifiedCount = verified;
            res.failedCount = failed;
            res.missingCount = miss;
            res.recordFound = true;
        }
        return results;
    }

    // --- 4. Get All Compliance Rules ---

    public class GetAllComplianceRulesRequest {
        @InvocableVariable(required=false) public String placeholder;
    }
    public class GetAllComplianceRulesResponse {
        @InvocableVariable public String complianceRulesText;
        @InvocableVariable public Integer totalRulesCount;
        @InvocableVariable public Integer criticalRulesCount;
        @InvocableVariable public Integer highRulesCount;
    }

    public static List<GetAllComplianceRulesResponse> getAllComplianceRules(
        List<GetAllComplianceRulesRequest> requests
    ) {
        GetAllComplianceRulesRequest req = (requests != null && !requests.isEmpty()) ? requests[0] : new GetAllComplianceRulesRequest();
        List<Compliance_Rule__mdt> rules = [
            SELECT MasterLabel, DeveloperName, Regulator__c, Regulation_Reference__c, Category__c,
                   Description__c, Mandatory__c, Severity__c, Validation_Logic__c, Effective_Date__c
            FROM Compliance_Rule__mdt
            WHERE Active__c = TRUE
        ];
        rules.sort(new ComplianceRuleSeverityComparator());
        List<String> lines = new List<String>();
        Integer critical = 0, high = 0;
        for (Compliance_Rule__mdt rule : rules) {
            lines.add(
                rule.MasterLabel + ' | ' + rule.Category__c + ' | ' + rule.Regulator__c + ' | '
                + rule.Severity__c + ' | ' + rule.Mandatory__c + ' | ' + rule.Regulation_Reference__c
            );
            if ('Critical'.equals(rule.Severity__c)) {
                critical++;
            } else if ('High'.equals(rule.Severity__c)) {
                high++;
            }
        }
        GetAllComplianceRulesResponse res = new GetAllComplianceRulesResponse();
        res.complianceRulesText = String.join(lines, '\n');
        res.totalRulesCount = rules.size();
        res.criticalRulesCount = critical;
        res.highRulesCount = high;
        return new List<GetAllComplianceRulesResponse>{ res };
    }

    private class ComplianceRuleSeverityComparator implements System.Comparator<Compliance_Rule__mdt> {
        public Integer compare(Compliance_Rule__mdt a, Compliance_Rule__mdt b) {
            return severityRank(a.Severity__c) - severityRank(b.Severity__c);
        }
    }

    // --- 5. Get Existing Compliance Checks ---

    public class GetExistingComplianceChecksRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
    }
    public class GetExistingComplianceChecksResponse {
        @InvocableVariable public String existingRuleNamesText;
        @InvocableVariable public Integer existingCount;
        @InvocableVariable public Boolean hasCriticalViolations;
        @InvocableVariable public Boolean hasHighViolations;
        @InvocableVariable public Boolean recordFound;
    }

    public static List<GetExistingComplianceChecksResponse> getExistingComplianceChecks(
        List<GetExistingComplianceChecksRequest> requests
    ) {
        List<GetExistingComplianceChecksResponse> results = new List<GetExistingComplianceChecksResponse>();
        for (GetExistingComplianceChecksRequest req : requests) {
            GetExistingComplianceChecksResponse res = new GetExistingComplianceChecksResponse();
            results.add(res);
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.recordFound = false;
                res.existingCount = 0;
                res.hasCriticalViolations = false;
                res.hasHighViolations = false;
                continue;
            }
            List<Compliance_Check__c> checks = [
                SELECT Rule_Name__c, Status__c, Severity__c, Resolved__c
                FROM Compliance_Check__c
                WHERE Loan_Application__c = :loanAppId
            ];
            if (checks.isEmpty()) {
                res.recordFound = false;
                res.existingCount = 0;
                res.hasCriticalViolations = false;
                res.hasHighViolations = false;
                continue;
            }
            List<String> names = new List<String>();
            Boolean critical = false, high = false;
            for (Compliance_Check__c c : checks) {
                names.add(c.Rule_Name__c);
                if ('Non-Compliant'.equals(c.Status__c) && c.Resolved__c != true) {
                    if ('Critical'.equals(c.Severity__c)) {
                        critical = true;
                    }
                    if ('High'.equals(c.Severity__c)) {
                        high = true;
                    }
                }
            }
            res.existingRuleNamesText = String.join(names, ', ');
            res.existingCount = checks.size();
            res.hasCriticalViolations = critical;
            res.hasHighViolations = high;
            res.recordFound = true;
        }
        return results;
    }

    // --- 6. Check Agent Completion ---

    public class CheckAgentCompletionRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
    }
    public class CheckAgentCompletionResponse {
        @InvocableVariable public String documentAgentStatus;
        @InvocableVariable public String financialAgentStatus;
        @InvocableVariable public String riskAgentStatus;
        @InvocableVariable public String complianceAgentStatus;
        @InvocableVariable public String decisionAgentStatus;
        @InvocableVariable public Boolean allPrerequisitesComplete;
        @InvocableVariable public Integer agentsCompletedCount;
        @InvocableVariable public Integer agentsFailedCount;
        @InvocableVariable public Integer agentsPendingCount;
        @InvocableVariable public String completionSummaryText;
        @InvocableVariable public Boolean recordFound;
    }

    public static List<CheckAgentCompletionResponse> checkAgentCompletion(
        List<CheckAgentCompletionRequest> requests
    ) {
        List<CheckAgentCompletionResponse> results = new List<CheckAgentCompletionResponse>();
        for (CheckAgentCompletionRequest req : requests) {
            CheckAgentCompletionResponse res = new CheckAgentCompletionResponse();
            results.add(res);
            res.documentAgentStatus = 'Not Started';
            res.financialAgentStatus = 'Not Started';
            res.riskAgentStatus = 'Not Started';
            res.complianceAgentStatus = 'Not Started';
            res.decisionAgentStatus = 'Not Started';
            res.allPrerequisitesComplete = false;
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.recordFound = false;
                continue;
            }
            List<Agent_Check_Result__c> agentResults = [
                SELECT Agent_Name__c, Status__c, Result__c, Score_Impact__c, Run_Completed_At__c
                FROM Agent_Check_Result__c
                WHERE Loan_Application__c = :loanAppId
            ];
            if (agentResults.isEmpty()) {
                res.recordFound = false;
                continue;
            }
            Integer completed = 0, failed = 0, pending = 0;
            for (Agent_Check_Result__c ar : agentResults) {
                if (AGENT_DOCUMENT.equals(ar.Agent_Name__c)) {
                    res.documentAgentStatus = ar.Status__c;
                } else if (AGENT_FINANCIAL.equals(ar.Agent_Name__c)) {
                    res.financialAgentStatus = ar.Status__c;
                } else if (AGENT_RISK.equals(ar.Agent_Name__c)) {
                    res.riskAgentStatus = ar.Status__c;
                } else if (AGENT_COMPLIANCE.equals(ar.Agent_Name__c)) {
                    res.complianceAgentStatus = ar.Status__c;
                } else if (AGENT_DECISION.equals(ar.Agent_Name__c)) {
                    res.decisionAgentStatus = ar.Status__c;
                }
                if ('Completed'.equals(ar.Status__c)) {
                    completed++;
                } else if ('Failed'.equals(ar.Status__c)) {
                    failed++;
                } else if ('Pending'.equals(ar.Status__c) || 'Running'.equals(ar.Status__c)) {
                    pending++;
                }
            }
            res.agentsCompletedCount = completed;
            res.agentsFailedCount = failed;
            res.agentsPendingCount = pending;
            res.allPrerequisitesComplete = 'Completed'.equals(res.documentAgentStatus)
                && 'Completed'.equals(res.financialAgentStatus)
                && 'Completed'.equals(res.riskAgentStatus)
                && 'Completed'.equals(res.complianceAgentStatus);
            res.completionSummaryText = AGENT_DOCUMENT + ': ' + res.documentAgentStatus + '\n'
                + AGENT_FINANCIAL + ': ' + res.financialAgentStatus + '\n'
                + AGENT_RISK + ': ' + res.riskAgentStatus + '\n'
                + AGENT_COMPLIANCE + ': ' + res.complianceAgentStatus + '\n'
                + AGENT_DECISION + ': ' + res.decisionAgentStatus;
            res.recordFound = true;
        }
        return results;
    }

    // --- 7. Get All Agent Results ---

    public class GetAllAgentResultsRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
    }
    public class GetAllAgentResultsResponse {
        @InvocableVariable public String allAgentResultsText;
        @InvocableVariable public Decimal totalRiskScore;
        @InvocableVariable public String documentAgentResult;
        @InvocableVariable public Decimal documentAgentScore;
        @InvocableVariable public String documentAgentReason;
        @InvocableVariable public String financialAgentResult;
        @InvocableVariable public Decimal financialAgentScore;
        @InvocableVariable public String financialAgentReason;
        @InvocableVariable public String riskAgentResult;
        @InvocableVariable public Decimal riskAgentScore;
        @InvocableVariable public String riskAgentReason;
        @InvocableVariable public String complianceAgentResult;
        @InvocableVariable public Decimal complianceAgentScore;
        @InvocableVariable public String complianceAgentReason;
        @InvocableVariable public String decisionAgentResult;
        @InvocableVariable public Integer agentsRetrievedCount;
        @InvocableVariable public Boolean recordFound;
    }

    public static List<GetAllAgentResultsResponse> getAllAgentResults(
        List<GetAllAgentResultsRequest> requests
    ) {
        List<GetAllAgentResultsResponse> results = new List<GetAllAgentResultsResponse>();
        for (GetAllAgentResultsRequest req : requests) {
            GetAllAgentResultsResponse res = new GetAllAgentResultsResponse();
            results.add(res);
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.recordFound = false;
                continue;
            }
            List<Agent_Check_Result__c> agentResults = [
                SELECT Agent_Name__c, Status__c, Result__c, Score_Impact__c, Confidence__c,
                       Reason__c, Recommendations__c, Run_Completed_At__c, Execution_Time_Ms__c
                FROM Agent_Check_Result__c
                WHERE Loan_Application__c = :loanAppId
            ];
            if (agentResults.isEmpty()) {
                res.recordFound = false;
                continue;
            }
            Decimal total = 0;
            List<String> lines = new List<String>();
            for (Agent_Check_Result__c ar : agentResults) {
                if (ar.Score_Impact__c != null) {
                    total += ar.Score_Impact__c;
                }
                lines.add(ar.Agent_Name__c + ' | ' + ar.Result__c + ' | ' + ar.Score_Impact__c + ' | ' + ar.Reason__c);
                if (AGENT_DOCUMENT.equals(ar.Agent_Name__c)) {
                    res.documentAgentResult = ar.Result__c;
                    res.documentAgentScore = ar.Score_Impact__c;
                    res.documentAgentReason = ar.Reason__c;
                } else if (AGENT_FINANCIAL.equals(ar.Agent_Name__c)) {
                    res.financialAgentResult = ar.Result__c;
                    res.financialAgentScore = ar.Score_Impact__c;
                    res.financialAgentReason = ar.Reason__c;
                } else if (AGENT_RISK.equals(ar.Agent_Name__c)) {
                    res.riskAgentResult = ar.Result__c;
                    res.riskAgentScore = ar.Score_Impact__c;
                    res.riskAgentReason = ar.Reason__c;
                } else if (AGENT_COMPLIANCE.equals(ar.Agent_Name__c)) {
                    res.complianceAgentResult = ar.Result__c;
                    res.complianceAgentScore = ar.Score_Impact__c;
                    res.complianceAgentReason = ar.Reason__c;
                } else if (AGENT_DECISION.equals(ar.Agent_Name__c)) {
                    res.decisionAgentResult = ar.Result__c;
                }
            }
            res.allAgentResultsText = String.join(lines, '\n');
            res.totalRiskScore = total;
            res.agentsRetrievedCount = agentResults.size();
            res.recordFound = true;
        }
        return results;
    }

    // --- 8. Escalate To Underwriter ---

    public class EscalateToUnderwriterRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
        @InvocableVariable(label='Underwriter Name Or Id' required=true) public String underwriterNameOrId;
    }
    public class EscalateToUnderwriterResponse {
        @InvocableVariable public String underwriterId;
        @InvocableVariable public String underwriterFullName;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    public static List<EscalateToUnderwriterResponse> escalateToUnderwriter(
        List<EscalateToUnderwriterRequest> requests
    ) {
        List<EscalateToUnderwriterResponse> results = new List<EscalateToUnderwriterResponse>();
        for (EscalateToUnderwriterRequest req : requests) {
            EscalateToUnderwriterResponse res = new EscalateToUnderwriterResponse();
            results.add(res);
            res.success = false;
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            User uw = resolveUnderwriter(req != null ? req.underwriterNameOrId : null);
            if (uw == null) {
                res.errorMessage = 'No user found with the name provided. Please check the name or provide the exact Salesforce user ID.';
                continue;
            }
            if (loanAppId == null) {
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            Database.SaveResult sr = Database.update(new Loan_Application__c(
                Id = loanAppId,
                Underwriter__c = uw.Id,
                Sub_Status__c = 'Approval Pending'
            ), false);
            if (!sr.isSuccess()) {
                res.errorMessage = sr.getErrors()[0].getMessage();
                continue;
            }
            res.underwriterId = uw.Id;
            res.underwriterFullName = uw.Name;
            res.success = true;
        }
        return results;
    }

    // --- 9. Send Escalation Notification ---

    public class SendEscalationNotificationRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
        @InvocableVariable(label='Underwriter Id' required=true) public String underwriterId;
        @InvocableVariable(label='Escalation Note') public String escalationNote;
        @InvocableVariable(label='Application Number' required=true) public String applicationNumber;
        @InvocableVariable(label='Applicant Name' required=true) public String applicantName;
        @InvocableVariable(label='Loan Amount' required=true) public Decimal loanAmount;
        @InvocableVariable(label='Risk Score' required=true) public Decimal riskScore;
        @InvocableVariable(label='Final AI Recommendation' required=true) public String finalAiRecommendation;
    }
    public class SendEscalationNotificationResponse {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    public static List<SendEscalationNotificationResponse> sendEscalationNotification(
        List<SendEscalationNotificationRequest> requests
    ) {
        List<SendEscalationNotificationResponse> results = new List<SendEscalationNotificationResponse>();
        for (SendEscalationNotificationRequest req : requests) {
            SendEscalationNotificationResponse res = new SendEscalationNotificationResponse();
            results.add(res);
            if (req == null || String.isBlank(req.underwriterId)) {
                res.success = false;
                res.errorMessage = 'Underwriter Id is required.';
                continue;
            }
            List<User> users = [
                SELECT Id, Name, Email FROM User WHERE Id = :req.underwriterId AND IsActive = TRUE LIMIT 1
            ];
            if (users.isEmpty()) {
                res.success = false;
                res.errorMessage = 'Underwriter user not found.';
                continue;
            }
            User uw = users[0];
            String body = 'Loan Application Escalated for Senior Review\n\n'
                + 'Application Number: ' + nullSafe(req.applicationNumber) + '\n'
                + 'Applicant Name: ' + nullSafe(req.applicantName) + '\n'
                + 'Loan Amount: ' + formatCurrency(req.loanAmount) + '\n'
                + 'Risk Score: ' + String.valueOf(req.riskScore) + '\n'
                + 'AI Recommendation: ' + nullSafe(req.finalAiRecommendation) + '\n';
            if (String.isNotBlank(req.escalationNote)) {
                body += 'Escalation Note: ' + req.escalationNote + '\n';
            }
            body += '\nPlease review this application at your earliest convenience.';
            String subject = 'Loan Application ' + req.applicationNumber + ' Escalated for Senior Review';
            if (Test.isRunningTest()) {
                res.success = true;
                res.errorMessage = 'Email not sent in test context.';
                continue;
            }
            if (String.isBlank(uw.Email)) {
                res.success = true;
                res.errorMessage = 'Underwriter has no email address; notification logged only.';
                continue;
            }
            try {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ uw.Email });
                mail.setSubject(subject);
                mail.setPlainTextBody(body);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
                res.success = true;
            } catch (Exception e) {
                res.success = true;
                res.errorMessage = 'Email send failed: ' + e.getMessage();
            }
        }
        return results;
    }

    // --- 10. Update Risk Score ---

    public class UpdateRiskScoreRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
        @InvocableVariable(label='Score To Add' required=true) public Decimal scoreToAdd;
    }
    public class UpdateRiskScoreResponse {
        @InvocableVariable public Decimal newTotalScore;
        @InvocableVariable public String newRiskLevel;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    public static List<UpdateRiskScoreResponse> updateRiskScore(List<UpdateRiskScoreRequest> requests) {
        List<UpdateRiskScoreResponse> results = new List<UpdateRiskScoreResponse>();
        for (UpdateRiskScoreRequest req : requests) {
            UpdateRiskScoreResponse res = new UpdateRiskScoreResponse();
            results.add(res);
            res.success = false;
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            List<Loan_Application__c> apps = [
                SELECT Id, Risk_Score__c FROM Loan_Application__c WHERE Id = :loanAppId LIMIT 1
            ];
            if (apps.isEmpty()) {
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            Decimal current = apps[0].Risk_Score__c != null ? apps[0].Risk_Score__c : 0;
            Decimal newTotal = current + (req.scoreToAdd != null ? req.scoreToAdd : 0);
            String level = PolicyRuleService.mapRiskScoreToLevel(newTotal);
            Database.SaveResult sr = Database.update(new Loan_Application__c(
                Id = loanAppId,
                Risk_Score__c = newTotal,
                Risk_Level__c = level
            ), false);
            if (!sr.isSuccess()) {
                res.errorMessage = sr.getErrors()[0].getMessage();
                continue;
            }
            res.newTotalScore = newTotal;
            res.newRiskLevel = level;
            res.success = true;
        }
        return results;
    }

    // --- 11. Get Portfolio Summary ---

    public class GetPortfolioSummaryRequest {
        @InvocableVariable(label='Date From') public Date dateFrom;
        @InvocableVariable(label='Date To') public Date dateTo;
    }
    public class GetPortfolioSummaryResponse {
        @InvocableVariable public Integer totalApplications;
        @InvocableVariable public Integer totalApproved;
        @InvocableVariable public Integer totalRejected;
        @InvocableVariable public Integer totalOnHold;
        @InvocableVariable public Integer totalUnderReview;
        @InvocableVariable public Integer totalSubmitted;
        @InvocableVariable public Integer totalDisbursed;
        @InvocableVariable public Decimal totalLoanAmountApproved;
        @InvocableVariable public Decimal averageRiskScore;
        @InvocableVariable public Integer applicationsWithMissingDocs;
        @InvocableVariable public Integer highRiskApplications;
        @InvocableVariable public String portfolioSummaryText;
    }

    public static List<GetPortfolioSummaryResponse> getPortfolioSummary(
        List<GetPortfolioSummaryRequest> requests
    ) {
        GetPortfolioSummaryRequest req = (requests != null && !requests.isEmpty())
            ? requests[0] : new GetPortfolioSummaryRequest();
        List<Loan_Application__c> apps;
        if (req.dateFrom != null && req.dateTo != null) {
            apps = [
                SELECT Status__c, Final_Recommendation__c, Loan_Amount_Approved__c,
                       Risk_Score__c, Risk_Level__c, Missing_Documents__c
                FROM Loan_Application__c
                WHERE Application_Date__c >= :req.dateFrom AND Application_Date__c <= :req.dateTo
            ];
        } else {
            apps = [
                SELECT Status__c, Final_Recommendation__c, Loan_Amount_Approved__c,
                       Risk_Score__c, Risk_Level__c, Missing_Documents__c
                FROM Loan_Application__c
            ];
        }
        GetPortfolioSummaryResponse res = new GetPortfolioSummaryResponse();
        Integer approved = 0, rejected = 0, onHold = 0, underReview = 0, submitted = 0, disbursed = 0;
        Decimal amountSum = 0, riskSum = 0;
        Integer missingDocs = 0, highRisk = 0;
        for (Loan_Application__c app : apps) {
            if ('Approved'.equals(app.Status__c)) {
                approved++;
            } else if ('Rejected'.equals(app.Status__c)) {
                rejected++;
            } else if ('On Hold'.equals(app.Status__c)) {
                onHold++;
            } else if ('Under Review'.equals(app.Status__c) || 'Underwriting'.equals(app.Status__c)) {
                underReview++;
            } else if ('Submitted'.equals(app.Status__c)) {
                submitted++;
            } else if ('Disbursed'.equals(app.Status__c)) {
                disbursed++;
            }
            if (('Approved'.equals(app.Status__c) || 'Disbursed'.equals(app.Status__c))
                && app.Loan_Amount_Approved__c != null) {
                amountSum += app.Loan_Amount_Approved__c;
            }
            if (app.Risk_Score__c != null) {
                riskSum += app.Risk_Score__c;
            }
            if (String.isNotBlank(app.Missing_Documents__c)) {
                missingDocs++;
            }
            if ('High'.equals(app.Risk_Level__c) || 'Very High'.equals(app.Risk_Level__c)) {
                highRisk++;
            }
        }
        res.totalApplications = apps.size();
        res.totalApproved = approved;
        res.totalRejected = rejected;
        res.totalOnHold = onHold;
        res.totalUnderReview = underReview;
        res.totalSubmitted = submitted;
        res.totalDisbursed = disbursed;
        res.totalLoanAmountApproved = amountSum;
        res.averageRiskScore = apps.isEmpty() ? 0 : riskSum / apps.size();
        res.applicationsWithMissingDocs = missingDocs;
        res.highRiskApplications = highRisk;
        res.portfolioSummaryText = 'Total: ' + res.totalApplications
            + ' | Approved: ' + approved + ' | Rejected: ' + rejected
            + ' | On Hold: ' + onHold + ' | Under Review: ' + underReview
            + ' | Submitted: ' + submitted + ' | Disbursed: ' + disbursed
            + ' | Avg Risk: ' + res.averageRiskScore
            + ' | Missing Docs: ' + missingDocs + ' | High Risk: ' + highRisk;
        return new List<GetPortfolioSummaryResponse>{ res };
    }

    // --- 12. Get Risk Distribution ---

    public class GetRiskDistributionRequest {
        @InvocableVariable(required=false) public String placeholder;
    }
    public class GetRiskDistributionResponse {
        @InvocableVariable public Integer veryLowCount;
        @InvocableVariable public Integer lowCount;
        @InvocableVariable public Integer mediumCount;
        @InvocableVariable public Integer highCount;
        @InvocableVariable public Integer veryHighCount;
        @InvocableVariable public Integer totalCount;
        @InvocableVariable public String riskDistributionText;
    }

    public static List<GetRiskDistributionResponse> getRiskDistribution(
        List<GetRiskDistributionRequest> requests
    ) {
        GetRiskDistributionResponse res = new GetRiskDistributionResponse();
        for (AggregateResult ar : [
            SELECT Risk_Level__c level, COUNT(Id) cnt
            FROM Loan_Application__c
            GROUP BY Risk_Level__c
        ]) {
            String level = (String) ar.get('level');
            Integer cnt = (Integer) ar.get('cnt');
            if ('Very Low'.equals(level)) {
                res.veryLowCount = cnt;
            } else if ('Low'.equals(level)) {
                res.lowCount = cnt;
            } else if ('Medium'.equals(level)) {
                res.mediumCount = cnt;
            } else if ('High'.equals(level)) {
                res.highCount = cnt;
            } else if ('Very High'.equals(level)) {
                res.veryHighCount = cnt;
            }
        }
        res.veryLowCount = res.veryLowCount != null ? res.veryLowCount : 0;
        res.lowCount = res.lowCount != null ? res.lowCount : 0;
        res.mediumCount = res.mediumCount != null ? res.mediumCount : 0;
        res.highCount = res.highCount != null ? res.highCount : 0;
        res.veryHighCount = res.veryHighCount != null ? res.veryHighCount : 0;
        res.totalCount = res.veryLowCount + res.lowCount + res.mediumCount + res.highCount + res.veryHighCount;
        Decimal total = res.totalCount > 0 ? res.totalCount : 1;
        res.riskDistributionText = 'Very Low: ' + res.veryLowCount + ' (' + Integer.valueOf(res.veryLowCount * 100 / total) + '%)\n'
            + 'Low: ' + res.lowCount + ' (' + Integer.valueOf(res.lowCount * 100 / total) + '%)\n'
            + 'Medium: ' + res.mediumCount + ' (' + Integer.valueOf(res.mediumCount * 100 / total) + '%)\n'
            + 'High: ' + res.highCount + ' (' + Integer.valueOf(res.highCount * 100 / total) + '%)\n'
            + 'Very High: ' + res.veryHighCount + ' (' + Integer.valueOf(res.veryHighCount * 100 / total) + '%)';
        return new List<GetRiskDistributionResponse>{ res };
    }

    // --- 13. Get Agent Performance ---

    public class GetAgentPerformanceRequest {
        @InvocableVariable(required=false) public String placeholder;
    }
    public class GetAgentPerformanceResponse {
        @InvocableVariable public String performanceSummaryText;
        @InvocableVariable public Integer totalAgentRuns;
    }

    public static List<GetAgentPerformanceResponse> getAgentPerformance(
        List<GetAgentPerformanceRequest> requests
    ) {
        List<Agent_Check_Result__c> runs = [
            SELECT Agent_Name__c, Result__c, Execution_Time_Ms__c
            FROM Agent_Check_Result__c
            WHERE Status__c = 'Completed'
        ];
        Map<String, AgentPerfStats> statsByAgent = new Map<String, AgentPerfStats>();
        for (Agent_Check_Result__c ar : runs) {
            if (!statsByAgent.containsKey(ar.Agent_Name__c)) {
                statsByAgent.put(ar.Agent_Name__c, new AgentPerfStats());
            }
            AgentPerfStats s = statsByAgent.get(ar.Agent_Name__c);
            s.total++;
            if ('Pass'.equals(ar.Result__c)) {
                s.passCount++;
            } else if ('Warning'.equals(ar.Result__c)) {
                s.warnCount++;
            } else if ('Fail'.equals(ar.Result__c)) {
                s.failCount++;
            }
            if (ar.Execution_Time_Ms__c != null) {
                s.totalMs += ar.Execution_Time_Ms__c.longValue();
            }
        }
        List<String> lines = new List<String>();
        for (String agent : statsByAgent.keySet()) {
            AgentPerfStats s = statsByAgent.get(agent);
            Decimal avgSec = s.total > 0 ? (s.totalMs / 1000.0) / s.total : 0;
            lines.add(agent + ' | Pass: ' + s.passCount + ' | Warning: ' + s.warnCount
                + ' | Fail: ' + s.failCount + ' | Avg Sec: ' + avgSec.setScale(2));
        }
        GetAgentPerformanceResponse res = new GetAgentPerformanceResponse();
        res.performanceSummaryText = String.join(lines, '\n');
        res.totalAgentRuns = runs.size();
        return new List<GetAgentPerformanceResponse>{ res };
    }

    private class AgentPerfStats {
        Integer total = 0;
        Integer passCount = 0;
        Integer warnCount = 0;
        Integer failCount = 0;
        Long totalMs = 0;
    }

    // --- 14. Get Missing Documents Report ---

    public class GetMissingDocumentsReportRequest {
        @InvocableVariable(required=false) public String placeholder;
    }
    public class GetMissingDocumentsReportResponse {
        @InvocableVariable public String missingDocsReportText;
        @InvocableVariable public Integer applicationsCount;
        @InvocableVariable public Boolean recordFound;
    }

    public static List<GetMissingDocumentsReportResponse> getMissingDocumentsReport(
        List<GetMissingDocumentsReportRequest> requests
    ) {
        GetMissingDocumentsReportResponse res = new GetMissingDocumentsReportResponse();
        List<Loan_Application__c> apps = [
            SELECT Name, Applicant__r.Name, Loan_Product__r.Name, Status__c,
                   Missing_Documents__c, Risk_Level__c, Application_Date__c
            FROM Loan_Application__c
            WHERE Status__c NOT IN :CLOSED_STATUSES
            ORDER BY Risk_Level__c DESC
            LIMIT 500
        ];
        if (apps.isEmpty()) {
            res.recordFound = false;
            res.applicationsCount = 0;
            return new List<GetMissingDocumentsReportResponse>{ res };
        }
        List<String> lines = new List<String>();
        for (Loan_Application__c app : apps) {
            if (String.isBlank(app.Missing_Documents__c)) {
                continue;
            }
            lines.add(app.Name + ' | ' + applicantDisplayName(app) + ' | '
                + (app.Loan_Product__r != null ? app.Loan_Product__r.Name : '') + ' | '
                + app.Status__c + ' | ' + app.Risk_Level__c + ' | ' + app.Missing_Documents__c);
        }
        res.missingDocsReportText = String.join(lines, '\n');
        res.applicationsCount = lines.size();
        res.recordFound = !lines.isEmpty();
        return new List<GetMissingDocumentsReportResponse>{ res };
    }

    // --- 15. Get Officer Override Report ---

    public class GetOfficerOverrideReportRequest {
        @InvocableVariable(required=false) public String placeholder;
    }
    public class GetOfficerOverrideReportResponse {
        @InvocableVariable public String overrideReportText;
        @InvocableVariable public Integer overrideCount;
        @InvocableVariable public Boolean recordFound;
    }

    public static List<GetOfficerOverrideReportResponse> getOfficerOverrideReport(
        List<GetOfficerOverrideReportRequest> requests
    ) {
        GetOfficerOverrideReportResponse res = new GetOfficerOverrideReportResponse();
        List<Loan_Application_History__c> events = [
            SELECT Loan_Application__r.Name, Loan_Application__r.Applicant__r.Name,
                   Performed_By__r.Name, Decision_Made__c, Override_Reason__c, Event_Timestamp__c
            FROM Loan_Application_History__c
            WHERE Officer_Override__c = TRUE
            ORDER BY Event_Timestamp__c DESC
            LIMIT 200
        ];
        if (events.isEmpty()) {
            res.recordFound = false;
            res.overrideCount = 0;
            return new List<GetOfficerOverrideReportResponse>{ res };
        }
        List<String> lines = new List<String>();
        for (Loan_Application_History__c h : events) {
            lines.add(h.Loan_Application__r.Name + ' | '
                + h.Loan_Application__r.Applicant__r.Name + ' | '
                + (h.Performed_By__r != null ? h.Performed_By__r.Name : '') + ' | '
                + h.Decision_Made__c + ' | ' + h.Override_Reason__c + ' | ' + h.Event_Timestamp__c);
        }
        res.overrideReportText = String.join(lines, '\n');
        res.overrideCount = events.size();
        res.recordFound = true;
        return new List<GetOfficerOverrideReportResponse>{ res };
    }

    // --- 16. Get Audit Trail ---

    public class GetAuditTrailRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
        @InvocableVariable(label='Compliance Relevant Only') public Boolean complianceRelevantOnly;
        @InvocableVariable(label='Limit Records') public Integer limitRecords;
    }
    public class GetAuditTrailResponse {
        @InvocableVariable public String auditTrailText;
        @InvocableVariable public Integer totalEvents;
        @InvocableVariable public Boolean hasCriticalEvents;
        @InvocableVariable public Boolean recordFound;
    }

    public static List<GetAuditTrailResponse> getAuditTrail(List<GetAuditTrailRequest> requests) {
        List<GetAuditTrailResponse> results = new List<GetAuditTrailResponse>();
        for (GetAuditTrailRequest req : requests) {
            GetAuditTrailResponse res = new GetAuditTrailResponse();
            results.add(res);
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.recordFound = false;
                continue;
            }
            Integer lim = (req != null && req.limitRecords != null && req.limitRecords > 0) ? req.limitRecords : 20;
            Boolean complianceOnly = req != null && req.complianceRelevantOnly == true;
            String soql = 'SELECT Event_Type__c, Event_Sub_Type__c, Event_Timestamp__c, Triggered_By__c, '
                + 'Agent_Name__c, Previous_Status__c, New_Status__c, Decision_Made__c, Severity__c, '
                + 'Compliance_Relevant__c, Event_Description__c, Officer_Override__c '
                + 'FROM Loan_Application_History__c WHERE Loan_Application__c = :loanAppId';
            if (complianceOnly) {
                soql += ' AND Compliance_Relevant__c = true';
            }
            soql += ' ORDER BY Event_Timestamp__c ASC LIMIT :lim';
            List<Loan_Application_History__c> events = Database.query(soql);
            if (events.isEmpty()) {
                res.recordFound = false;
                continue;
            }
            List<String> lines = new List<String>();
            Boolean critical = false;
            for (Loan_Application_History__c h : events) {
                lines.add(buildAuditLine(h));
                if ('Critical'.equals(h.Severity__c)) {
                    critical = true;
                }
            }
            res.auditTrailText = String.join(lines, '\n');
            res.totalEvents = events.size();
            res.hasCriticalEvents = critical;
            res.recordFound = true;
        }
        return results;
    }

    // --- 17. Get Compliance Summary ---

    public class GetComplianceSummaryRequest {
        @InvocableVariable(label='Loan Application Id') public String loanApplicationId;
    }
    public class GetComplianceSummaryResponse {
        @InvocableVariable public Integer totalChecks;
        @InvocableVariable public Integer compliantCount;
        @InvocableVariable public Integer nonCompliantCount;
        @InvocableVariable public Integer warningCount;
        @InvocableVariable public Integer criticalViolationsCount;
        @InvocableVariable public Integer highViolationsCount;
        @InvocableVariable public Integer unresolvedCount;
        @InvocableVariable public String complianceSummaryText;
        @InvocableVariable public Boolean recordFound;
    }

    public static List<GetComplianceSummaryResponse> getComplianceSummary(
        List<GetComplianceSummaryRequest> requests
    ) {
        GetComplianceSummaryRequest req = (requests != null && !requests.isEmpty())
            ? requests[0] : new GetComplianceSummaryRequest();
        Id loanAppId = resolveLoanAppId(req.loanApplicationId);
        List<Compliance_Check__c> checks;
        if (loanAppId != null) {
            checks = [
                SELECT Status__c, Severity__c, Resolved__c, Rule_Name__c, Rule_Category__c,
                       Loan_Application__r.Name
                FROM Compliance_Check__c
                WHERE Loan_Application__c = :loanAppId
            ];
        } else {
            checks = [
                SELECT Status__c, Severity__c, Resolved__c, Rule_Name__c, Rule_Category__c,
                       Loan_Application__r.Name
                FROM Compliance_Check__c
                LIMIT 500
            ];
        }
        GetComplianceSummaryResponse res = new GetComplianceSummaryResponse();
        Integer compliant = 0, nonCompliant = 0, warning = 0, critical = 0, high = 0, unresolved = 0;
        for (Compliance_Check__c c : checks) {
            if ('Compliant'.equals(c.Status__c)) {
                compliant++;
            } else if ('Non-Compliant'.equals(c.Status__c)) {
                nonCompliant++;
                if (c.Resolved__c != true) {
                    unresolved++;
                }
            } else if ('Warning'.equals(c.Status__c)) {
                warning++;
            }
            if ('Critical'.equals(c.Severity__c)) {
                critical++;
            } else if ('High'.equals(c.Severity__c)) {
                high++;
            }
        }
        res.totalChecks = checks.size();
        res.compliantCount = compliant;
        res.nonCompliantCount = nonCompliant;
        res.warningCount = warning;
        res.criticalViolationsCount = critical;
        res.highViolationsCount = high;
        res.unresolvedCount = unresolved;
        res.complianceSummaryText = 'Total: ' + res.totalChecks + ' | Compliant: ' + compliant
            + ' | Non-Compliant: ' + nonCompliant + ' | Warning: ' + warning
            + ' | Critical: ' + critical + ' | High: ' + high + ' | Unresolved: ' + unresolved;
        res.recordFound = !checks.isEmpty();
        return new List<GetComplianceSummaryResponse>{ res };
    }

    // --- 18. Get Daily Volume ---

    public class GetDailyVolumeRequest {
        @InvocableVariable(required=false) public String placeholder;
    }
    public class GetDailyVolumeResponse {
        @InvocableVariable public String dailyVolumeText;
        @InvocableVariable public Integer totalThisMonth;
        @InvocableVariable public Boolean recordFound;
    }

    public static List<GetDailyVolumeResponse> getDailyVolume(List<GetDailyVolumeRequest> requests) {
        Date monthStart = Date.today().toStartOfMonth();
        DateTime startDt = DateTime.newInstance(monthStart, Time.newInstance(0, 0, 0, 0));
        DateTime endDt = DateTime.now();
        List<Loan_Application__c> apps = [
            SELECT CreatedDate FROM Loan_Application__c
            WHERE CreatedDate >= :startDt AND CreatedDate <= :endDt
        ];
        Map<String, Integer> countByDay = new Map<String, Integer>();
        for (Loan_Application__c app : apps) {
            String dayKey = app.CreatedDate.date().format();
            countByDay.put(dayKey, countByDay.containsKey(dayKey) ? countByDay.get(dayKey) + 1 : 1);
        }
        List<String> sortedDays = new List<String>(countByDay.keySet());
        sortedDays.sort();
        Integer cumulative = 0;
        List<String> lines = new List<String>();
        for (String day : sortedDays) {
            Integer cnt = countByDay.get(day);
            cumulative += cnt;
            lines.add(day + ' | ' + cnt + ' | ' + cumulative);
        }
        GetDailyVolumeResponse res = new GetDailyVolumeResponse();
        res.dailyVolumeText = String.join(lines, '\n');
        res.totalThisMonth = apps.size();
        res.recordFound = !apps.isEmpty();
        return new List<GetDailyVolumeResponse>{ res };
    }

    // --- 19. Get Loan Application Details ---

    public class GetLoanApplicationDetailsRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
    }
    public class GetLoanApplicationDetailsResponse {
        @InvocableVariable public String applicationNumber;
        @InvocableVariable public String applicantName;
        @InvocableVariable public Decimal loanAmount;
        @InvocableVariable public Decimal loanAmountApproved;
        @InvocableVariable public String productName;
        @InvocableVariable public String productCode;
        @InvocableVariable public Decimal tenureMonths;
        @InvocableVariable public Decimal interestRate;
        @InvocableVariable public Decimal monthlyIncome;
        @InvocableVariable public Decimal existingEmi;
        @InvocableVariable public Decimal emiBurdenPct;
        @InvocableVariable public Decimal calculatedEmi;
        @InvocableVariable public Decimal foirAfterLoan;
        @InvocableVariable public Decimal lti;
        @InvocableVariable public Decimal creditScore;
        @InvocableVariable public String status;
        @InvocableVariable public String subStatus;
        @InvocableVariable public String priority;
        @InvocableVariable public String branch;
        @InvocableVariable public Decimal riskScore;
        @InvocableVariable public String riskLevel;
        @InvocableVariable public String finalRecommendation;
        @InvocableVariable public Decimal aiConfidence;
        @InvocableVariable public String decisionReasons;
        @InvocableVariable public String missingDocuments;
        @InvocableVariable public String nextBestAction;
        @InvocableVariable public Boolean allAgentsCompleted;
        @InvocableVariable public String loanOfficerName;
        @InvocableVariable public String underwriterName;
        @InvocableVariable public Date applicationDate;
        @InvocableVariable public String loanPurpose;
        @InvocableVariable public String applicationChannel;
        @InvocableVariable public Boolean recordFound;
        @InvocableVariable public String errorMessage;
    }

    public static List<GetLoanApplicationDetailsResponse> getLoanApplicationDetails(
        List<GetLoanApplicationDetailsRequest> requests
    ) {
        List<GetLoanApplicationDetailsResponse> results = new List<GetLoanApplicationDetailsResponse>();
        for (GetLoanApplicationDetailsRequest req : requests) {
            GetLoanApplicationDetailsResponse res = new GetLoanApplicationDetailsResponse();
            results.add(res);
            res.recordFound = false;
            if (req == null || String.isBlank(req.loanApplicationId)) {
                res.errorMessage = 'Loan Application Id is required.';
                continue;
            }
            Loan_Application__c app = fetchLoanApplication(req.loanApplicationId);
            if (app == null) {
                res.errorMessage = 'No loan application found with the provided ID or number. Please verify and try again.';
                continue;
            }
            mapLoanAppToDetailsResponse(app, res);
            res.recordFound = true;
            res.errorMessage = '';
        }
        return results;
    }

    private static Loan_Application__c fetchLoanApplication(String input) {
        Id loanAppId = resolveLoanAppId(input);
        if (loanAppId != null) {
            List<Loan_Application__c> apps = [
                SELECT Name, Applicant__r.Name, Loan_Product__r.Name, Loan_Product__r.Product_Code__c,
                       Loan_Amount__c, Loan_Amount_Approved__c, Tenure_Months__c, Interest_Rate__c,
                       Monthly_Income__c, Existing_EMI__c, EMI_Burden__c, Calculated_EMI__c,
                       FOIR_After_Loan__c, LTI__c, Credit_Score__c, Status__c, Sub_Status__c,
                       Priority__c, Branch__c, Risk_Score__c, Risk_Level__c, Final_Recommendation__c,
                       AI_Confidence__c, Decision_Reasons__c, Missing_Documents__c, Next_Best_Action__c,
                       All_Agents_Completed__c, Loan_Officer__r.Name, Underwriter__r.Name,
                       Application_Date__c, Loan_Purpose__c, Application_Channel__c
                FROM Loan_Application__c
                WHERE Id = :loanAppId
                LIMIT 1
            ];
            return apps.isEmpty() ? null : apps[0];
        }
        String name = input.trim();
        List<Loan_Application__c> apps = [
            SELECT Name, Applicant__r.Name, Loan_Product__r.Name, Loan_Product__r.Product_Code__c,
                   Loan_Amount__c, Loan_Amount_Approved__c, Tenure_Months__c, Interest_Rate__c,
                   Monthly_Income__c, Existing_EMI__c, EMI_Burden__c, Calculated_EMI__c,
                   FOIR_After_Loan__c, LTI__c, Credit_Score__c, Status__c, Sub_Status__c,
                   Priority__c, Branch__c, Risk_Score__c, Risk_Level__c, Final_Recommendation__c,
                   AI_Confidence__c, Decision_Reasons__c, Missing_Documents__c, Next_Best_Action__c,
                   All_Agents_Completed__c, Loan_Officer__r.Name, Underwriter__r.Name,
                   Application_Date__c, Loan_Purpose__c, Application_Channel__c
            FROM Loan_Application__c
            WHERE Name = :name
            LIMIT 1
        ];
        return apps.isEmpty() ? null : apps[0];
    }

    private static void mapLoanAppToDetailsResponse(
        Loan_Application__c app,
        GetLoanApplicationDetailsResponse res
    ) {
        res.applicationNumber = app.Name;
        res.applicantName = applicantDisplayName(app);
        res.loanAmount = app.Loan_Amount__c;
        res.loanAmountApproved = app.Loan_Amount_Approved__c;
        res.productName = app.Loan_Product__r != null ? app.Loan_Product__r.Name : null;
        res.productCode = app.Loan_Product__r != null ? app.Loan_Product__r.Product_Code__c : null;
        res.tenureMonths = app.Tenure_Months__c;
        res.interestRate = app.Interest_Rate__c;
        res.monthlyIncome = app.Monthly_Income__c;
        res.existingEmi = app.Existing_EMI__c;
        res.emiBurdenPct = app.EMI_Burden__c;
        res.calculatedEmi = app.Calculated_EMI__c;
        res.foirAfterLoan = app.FOIR_After_Loan__c;
        res.lti = app.LTI__c;
        res.creditScore = app.Credit_Score__c;
        res.status = app.Status__c;
        res.subStatus = app.Sub_Status__c;
        res.priority = app.Priority__c;
        res.branch = app.Branch__c;
        res.riskScore = app.Risk_Score__c;
        res.riskLevel = app.Risk_Level__c;
        res.finalRecommendation = app.Final_Recommendation__c;
        res.aiConfidence = app.AI_Confidence__c;
        res.decisionReasons = app.Decision_Reasons__c;
        res.missingDocuments = app.Missing_Documents__c;
        res.nextBestAction = app.Next_Best_Action__c;
        res.allAgentsCompleted = app.All_Agents_Completed__c;
        res.loanOfficerName = app.Loan_Officer__r != null ? app.Loan_Officer__r.Name : null;
        res.underwriterName = app.Underwriter__r != null ? app.Underwriter__r.Name : null;
        res.applicationDate = app.Application_Date__c;
        res.loanPurpose = app.Loan_Purpose__c;
        res.applicationChannel = app.Application_Channel__c;
    }

    // --- 20. Get Required Documents ---

    public class GetRequiredDocumentsRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
    }
    public class GetRequiredDocumentsResponse {
        @InvocableVariable public String requiredDocumentsList;
        @InvocableVariable public Integer requiredDocumentsCount;
        @InvocableVariable public String productName;
        @InvocableVariable public String productCode;
        @InvocableVariable public Boolean recordFound;
        @InvocableVariable public String errorMessage;
    }

    public static List<GetRequiredDocumentsResponse> getRequiredDocuments(
        List<GetRequiredDocumentsRequest> requests
    ) {
        List<GetRequiredDocumentsResponse> results = new List<GetRequiredDocumentsResponse>();
        for (GetRequiredDocumentsRequest req : requests) {
            GetRequiredDocumentsResponse res = new GetRequiredDocumentsResponse();
            results.add(res);
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.recordFound = false;
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            List<Loan_Application__c> apps = [
                SELECT Loan_Product__r.Required_Documents__c, Loan_Product__r.Name,
                       Loan_Product__r.Product_Code__c
                FROM Loan_Application__c
                WHERE Id = :loanAppId
                LIMIT 1
            ];
            if (apps.isEmpty() || apps[0].Loan_Product__r == null) {
                res.recordFound = false;
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            res.requiredDocumentsList = apps[0].Loan_Product__r.Required_Documents__c;
            res.requiredDocumentsCount = countTokens(res.requiredDocumentsList);
            res.productName = apps[0].Loan_Product__r.Name;
            res.productCode = apps[0].Loan_Product__r.Product_Code__c;
            res.recordFound = true;
        }
        return results;
    }

    // --- 21. Get Financial Data ---

    public class GetFinancialDataRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
    }
    public class GetFinancialDataResponse {
        @InvocableVariable public Decimal monthlyIncome;
        @InvocableVariable public Decimal existingEmi;
        @InvocableVariable public Decimal loanAmount;
        @InvocableVariable public Decimal tenureMonths;
        @InvocableVariable public Decimal interestRate;
        @InvocableVariable public Decimal emiBurdenPct;
        @InvocableVariable public Decimal calculatedEmi;
        @InvocableVariable public Decimal foirAfterLoan;
        @InvocableVariable public Decimal lti;
        @InvocableVariable public Decimal creditScore;
        @InvocableVariable public String applicantName;
        @InvocableVariable public String productCode;
        @InvocableVariable public String productName;
        @InvocableVariable public Boolean recordFound;
        @InvocableVariable public String errorMessage;
    }

    public static List<GetFinancialDataResponse> getFinancialData(List<GetFinancialDataRequest> requests) {
        List<GetFinancialDataResponse> results = new List<GetFinancialDataResponse>();
        for (GetFinancialDataRequest req : requests) {
            GetFinancialDataResponse res = new GetFinancialDataResponse();
            results.add(res);
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.recordFound = false;
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            List<Loan_Application__c> apps = [
                SELECT Monthly_Income__c, Existing_EMI__c, Loan_Amount__c, Tenure_Months__c,
                       Interest_Rate__c, EMI_Burden__c, Calculated_EMI__c, FOIR_After_Loan__c,
                       LTI__c, Credit_Score__c, Applicant__r.Name,
                       Loan_Product__r.Product_Code__c, Loan_Product__r.Name
                FROM Loan_Application__c
                WHERE Id = :loanAppId
                LIMIT 1
            ];
            if (apps.isEmpty()) {
                res.recordFound = false;
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            Loan_Application__c app = apps[0];
            res.monthlyIncome = app.Monthly_Income__c;
            res.existingEmi = app.Existing_EMI__c;
            res.loanAmount = app.Loan_Amount__c;
            res.tenureMonths = app.Tenure_Months__c;
            res.interestRate = app.Interest_Rate__c;
            res.emiBurdenPct = app.EMI_Burden__c;
            res.calculatedEmi = app.Calculated_EMI__c;
            res.foirAfterLoan = app.FOIR_After_Loan__c;
            res.lti = app.LTI__c;
            res.creditScore = app.Credit_Score__c;
            res.applicantName = applicantDisplayName(app);
            res.productCode = app.Loan_Product__r != null ? app.Loan_Product__r.Product_Code__c : null;
            res.productName = app.Loan_Product__r != null ? app.Loan_Product__r.Name : null;
            res.recordFound = true;
        }
        return results;
    }

    // --- 22. Get FOIR Policy ---

    public class GetFoirPolicyRequest {
        @InvocableVariable(label='Product Code' required=true) public String productCode;
    }
    public class GetFoirPolicyResponse {
        @InvocableVariable public Decimal maxFoirThreshold;
        @InvocableVariable public String maxFoirDisplay;
        @InvocableVariable public String ruleName;
        @InvocableVariable public String severity;
        @InvocableVariable public Boolean recordFound;
        @InvocableVariable public String errorMessage;
    }

    public static List<GetFoirPolicyResponse> getFoirPolicy(List<GetFoirPolicyRequest> requests) {
        List<GetFoirPolicyResponse> results = new List<GetFoirPolicyResponse>();
        for (GetFoirPolicyRequest req : requests) {
            GetFoirPolicyResponse res = new GetFoirPolicyResponse();
            results.add(res);
            Policy_Rule__mdt rule = queryPolicyRule('RULE_MAX_FOIR', req != null ? req.productCode : null);
            if (rule == null || String.isBlank(rule.Threshold_Value__c)) {
                res.maxFoirThreshold = 0.60;
                res.maxFoirDisplay = '60 percent';
                res.recordFound = false;
                res.errorMessage = 'Policy rule not found. Using default 60 percent threshold.';
                continue;
            }
            res.maxFoirThreshold = Decimal.valueOf(rule.Threshold_Value__c.trim());
            res.maxFoirDisplay = String.valueOf((res.maxFoirThreshold * 100).intValue()) + ' percent';
            res.ruleName = rule.MasterLabel;
            res.severity = rule.Severity__c;
            res.recordFound = true;
        }
        return results;
    }

    // --- 23. Get Risk Assessment ---

    public class GetRiskAssessmentRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
    }
    public class GetRiskAssessmentResponse {
        @InvocableVariable public Decimal bureauScore;
        @InvocableVariable public String bureauSource;
        @InvocableVariable public Decimal pastDefaults;
        @InvocableVariable public Decimal pastBounces12M;
        @InvocableVariable public Decimal activeLoans;
        @InvocableVariable public Decimal creditInquiries6M;
        @InvocableVariable public Decimal fraudScore;
        @InvocableVariable public Boolean identityVerified;
        @InvocableVariable public String addressRisk;
        @InvocableVariable public String sectorRisk;
        @InvocableVariable public Decimal finalRiskScore;
        @InvocableVariable public String riskCategory;
        @InvocableVariable public String riskReasons;
        @InvocableVariable public String riskAssessmentId;
        @InvocableVariable public Boolean recordFound;
        @InvocableVariable public String errorMessage;
    }

    public static List<GetRiskAssessmentResponse> getRiskAssessment(
        List<GetRiskAssessmentRequest> requests
    ) {
        List<GetRiskAssessmentResponse> results = new List<GetRiskAssessmentResponse>();
        for (GetRiskAssessmentRequest req : requests) {
            GetRiskAssessmentResponse res = new GetRiskAssessmentResponse();
            results.add(res);
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.recordFound = false;
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            List<Risk_Assessment__c> assessments = [
                SELECT Id, Bureau_Score__c, Bureau_Source__c, Past_Defaults__c, Past_Bounces_12M__c,
                       Active_Loans__c, Credit_Inquiries_6M__c, Fraud_Score__c, Identity_Verified__c,
                       Address_Risk__c, Sector_Risk__c, Final_Risk_Score__c, Risk_Category__c, Risk_Reasons__c
                FROM Risk_Assessment__c
                WHERE Loan_Application__c = :loanAppId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!assessments.isEmpty()) {
                Risk_Assessment__c ra = assessments[0];
                res.bureauScore = ra.Bureau_Score__c;
                res.bureauSource = ra.Bureau_Source__c;
                res.pastDefaults = ra.Past_Defaults__c;
                res.pastBounces12M = ra.Past_Bounces_12M__c;
                res.activeLoans = ra.Active_Loans__c;
                res.creditInquiries6M = ra.Credit_Inquiries_6M__c;
                res.fraudScore = ra.Fraud_Score__c;
                res.identityVerified = ra.Identity_Verified__c;
                res.addressRisk = ra.Address_Risk__c;
                res.sectorRisk = ra.Sector_Risk__c;
                res.finalRiskScore = ra.Final_Risk_Score__c;
                res.riskCategory = ra.Risk_Category__c;
                res.riskReasons = ra.Risk_Reasons__c;
                res.riskAssessmentId = ra.Id;
                res.recordFound = true;
                continue;
            }
            List<Loan_Application__c> apps = [
                SELECT Credit_Score__c FROM Loan_Application__c WHERE Id = :loanAppId LIMIT 1
            ];
            res.bureauScore = apps.isEmpty() ? null : apps[0].Credit_Score__c;
            res.recordFound = false;
            res.errorMessage = 'No bureau assessment record found. Using credit score from application as fallback. Results may be incomplete.';
        }
        return results;
    }

    // --- 24. Get Credit Score Policy ---

    public class GetCreditScorePolicyRequest {
        @InvocableVariable(label='Product Code' required=true) public String productCode;
    }
    public class GetCreditScorePolicyResponse {
        @InvocableVariable public Decimal minCreditScore;
        @InvocableVariable public String ruleName;
        @InvocableVariable public String severity;
        @InvocableVariable public Boolean recordFound;
        @InvocableVariable public String errorMessage;
    }

    public static List<GetCreditScorePolicyResponse> getCreditScorePolicy(
        List<GetCreditScorePolicyRequest> requests
    ) {
        List<GetCreditScorePolicyResponse> results = new List<GetCreditScorePolicyResponse>();
        for (GetCreditScorePolicyRequest req : requests) {
            GetCreditScorePolicyResponse res = new GetCreditScorePolicyResponse();
            results.add(res);
            Policy_Rule__mdt rule = queryPolicyRule('RULE_MIN_CREDIT_SCORE', req != null ? req.productCode : null);
            if (rule == null || String.isBlank(rule.Threshold_Value__c)) {
                res.minCreditScore = 650;
                res.recordFound = false;
                res.errorMessage = 'Policy rule not found. Using default minimum score of 650.';
                continue;
            }
            res.minCreditScore = Decimal.valueOf(rule.Threshold_Value__c.trim());
            res.ruleName = rule.MasterLabel;
            res.severity = rule.Severity__c;
            res.recordFound = true;
        }
        return results;
    }

    // --- 25. Get KYC Status ---

    public class GetKycStatusRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
    }
    public class GetKycStatusResponse {
        @InvocableVariable public String kycStatus;
        @InvocableVariable public String panNumberMasked;
        @InvocableVariable public String aadhaarNumberMasked;
        @InvocableVariable public String applicantName;
        @InvocableVariable public String customerSegment;
        @InvocableVariable public String employmentStatus;
        @InvocableVariable public Decimal bureauScore;
        @InvocableVariable public String riskCategory;
        @InvocableVariable public Boolean recordFound;
        @InvocableVariable public String errorMessage;
    }

    public static List<GetKycStatusResponse> getKycStatus(List<GetKycStatusRequest> requests) {
        List<GetKycStatusResponse> results = new List<GetKycStatusResponse>();
        for (GetKycStatusRequest req : requests) {
            GetKycStatusResponse res = new GetKycStatusResponse();
            results.add(res);
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.recordFound = false;
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            List<Loan_Application__c> apps = [
                SELECT Applicant__r.KYC_Status__c, Applicant__r.PAN_Number__c,
                       Applicant__r.Aadhaar_Number__c, Applicant__r.Name,
                       Applicant__r.Customer_Segment__c, Applicant__r.Employment_Status__c,
                       Applicant__r.Bureau_Score__c, Applicant__r.Risk_Category__c
                FROM Loan_Application__c
                WHERE Id = :loanAppId
                LIMIT 1
            ];
            if (apps.isEmpty() || apps[0].Applicant__r == null) {
                res.recordFound = false;
                res.errorMessage = 'Applicant not found.';
                continue;
            }
            Account acc = apps[0].Applicant__r;
            res.kycStatus = acc.KYC_Status__c;
            res.panNumberMasked = maskPan(acc.PAN_Number__c);
            res.aadhaarNumberMasked = maskAadhaar(acc.Aadhaar_Number__c);
            res.applicantName = acc.Name;
            res.customerSegment = acc.Customer_Segment__c;
            res.employmentStatus = acc.Employment_Status__c;
            res.bureauScore = acc.Bureau_Score__c;
            res.riskCategory = acc.Risk_Category__c;
            res.recordFound = true;
        }
        return results;
    }

    // --- 26. Get Loan Decision ---

    public class GetLoanDecisionRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
    }
    public class GetLoanDecisionResponse {
        @InvocableVariable public String loanDecisionId;
        @InvocableVariable public String recommendation;
        @InvocableVariable public Decimal confidenceScore;
        @InvocableVariable public Decimal approvedAmount;
        @InvocableVariable public String decisionSummary;
        @InvocableVariable public String keyReasons;
        @InvocableVariable public String missingPaperwork;
        @InvocableVariable public String nextBestAction;
        @InvocableVariable public String conditions;
        @InvocableVariable public String generatedBy;
        @InvocableVariable public String aiModel;
        @InvocableVariable public DateTime generatedAt;
        @InvocableVariable public Boolean officerReviewed;
        @InvocableVariable public String officerDecision;
        @InvocableVariable public String officerComments;
        @InvocableVariable public DateTime officerReviewedAt;
        @InvocableVariable public Boolean recordFound;
        @InvocableVariable public String errorMessage;
    }

    public static List<GetLoanDecisionResponse> getLoanDecision(List<GetLoanDecisionRequest> requests) {
        List<GetLoanDecisionResponse> results = new List<GetLoanDecisionResponse>();
        for (GetLoanDecisionRequest req : requests) {
            GetLoanDecisionResponse res = new GetLoanDecisionResponse();
            results.add(res);
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.recordFound = false;
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            List<Loan_Decision__c> decisions = [
                SELECT Id, Recommendation__c, Confidence_Score__c, Approved_Amount__c,
                       Decision_Summary__c, Key_Reasons__c, Missing_Paperwork__c, Next_Best_Action__c,
                       Conditions__c, Generated_By__c, AI_Model__c, Generated_At__c,
                       Officer_Reviewed__c, Officer_Decision__c, Officer_Comments__c, Officer_Reviewed_At__c
                FROM Loan_Decision__c
                WHERE Loan_Application__c = :loanAppId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (decisions.isEmpty()) {
                res.recordFound = false;
                res.errorMessage = 'No loan decision has been generated for this application yet. Please run the Decision Agent first.';
                continue;
            }
            Loan_Decision__c d = decisions[0];
            res.loanDecisionId = d.Id;
            res.recommendation = d.Recommendation__c;
            res.confidenceScore = d.Confidence_Score__c;
            res.approvedAmount = d.Approved_Amount__c;
            res.decisionSummary = d.Decision_Summary__c;
            res.keyReasons = d.Key_Reasons__c;
            res.missingPaperwork = d.Missing_Paperwork__c;
            res.nextBestAction = d.Next_Best_Action__c;
            res.conditions = d.Conditions__c;
            res.generatedBy = d.Generated_By__c;
            res.aiModel = d.AI_Model__c;
            res.generatedAt = d.Generated_At__c;
            res.officerReviewed = d.Officer_Reviewed__c;
            res.officerDecision = d.Officer_Decision__c;
            res.officerComments = d.Officer_Comments__c;
            res.officerReviewedAt = d.Officer_Reviewed_At__c;
            res.recordFound = true;
        }
        return results;
    }

    // --- 27. Update Missing Documents ---

    public class UpdateMissingDocumentsRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
        @InvocableVariable(label='Missing Documents List' required=true) public String missingDocumentsList;
    }
    public class UpdateMissingDocumentsResponse {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    public static List<UpdateMissingDocumentsResponse> updateMissingDocuments(
        List<UpdateMissingDocumentsRequest> requests
    ) {
        List<UpdateMissingDocumentsResponse> results = new List<UpdateMissingDocumentsResponse>();
        for (UpdateMissingDocumentsRequest req : requests) {
            UpdateMissingDocumentsResponse res = new UpdateMissingDocumentsResponse();
            results.add(res);
            res.success = false;
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            Database.SaveResult sr = Database.update(new Loan_Application__c(
                Id = loanAppId,
                Missing_Documents__c = req.missingDocumentsList
            ), false);
            if (!sr.isSuccess()) {
                res.errorMessage = sr.getErrors()[0].getMessage();
                continue;
            }
            res.success = true;
        }
        return results;
    }

    // --- 28. Flag For Fraud Review ---

    public class FlagForFraudReviewRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
        @InvocableVariable(label='Fraud Score' required=true) public Decimal fraudScore;
        @InvocableVariable(label='Fraud Threshold' required=true) public Decimal fraudThreshold;
    }
    public class FlagForFraudReviewResponse {
        @InvocableVariable public String complianceCheckId;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    public static List<FlagForFraudReviewResponse> flagForFraudReview(
        List<FlagForFraudReviewRequest> requests
    ) {
        List<FlagForFraudReviewResponse> results = new List<FlagForFraudReviewResponse>();
        for (FlagForFraudReviewRequest req : requests) {
            FlagForFraudReviewResponse res = new FlagForFraudReviewResponse();
            results.add(res);
            res.success = false;
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            Compliance_Check__c check = new Compliance_Check__c(
                Loan_Application__c = loanAppId,
                Rule_Name__c = 'FRAUD_FLAG_REVIEW',
                Rule_Category__c = 'AML',
                Status__c = 'Non-Compliant',
                Severity__c = 'Critical',
                Description__c = 'Fraud score of ' + req.fraudScore + ' exceeds acceptable threshold of '
                    + req.fraudThreshold + '. Application flagged for manual fraud investigation before any approval.',
                Action_Required__c = 'Senior underwriter and fraud team must review this application before any approval decision. Do not disburse.',
                Regulation_Reference__c = 'RBI KYC Master Direction 2016 Section 37 AML',
                Checked_At__c = DateTime.now(),
                Resolved__c = false
            );
            Database.SaveResult sr = Database.insert(check, false);
            if (!sr.isSuccess()) {
                res.errorMessage = sr.getErrors()[0].getMessage();
                continue;
            }
            res.complianceCheckId = check.Id;
            res.success = true;
        }
        return results;
    }

    // --- 29. Update Application AI Output ---

    public class UpdateApplicationAiOutputRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
        @InvocableVariable(label='Final Recommendation' required=true) public String finalRecommendation;
        @InvocableVariable(label='AI Confidence' required=true) public Decimal aiConfidence;
        @InvocableVariable(label='Decision Reasons' required=true) public String decisionReasons;
        @InvocableVariable(label='Missing Documents') public String missingDocuments;
        @InvocableVariable(label='Next Best Action') public String nextBestAction;
        @InvocableVariable(label='All Agents Completed' required=true) public Boolean allAgentsCompleted;
        @InvocableVariable(label='Risk Score' required=true) public Decimal riskScore;
    }
    public class UpdateApplicationAiOutputResponse {
        @InvocableVariable public String newStatus;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    public static List<UpdateApplicationAiOutputResponse> updateApplicationAiOutput(
        List<UpdateApplicationAiOutputRequest> requests
    ) {
        List<UpdateApplicationAiOutputResponse> results = new List<UpdateApplicationAiOutputResponse>();
        for (UpdateApplicationAiOutputRequest req : requests) {
            UpdateApplicationAiOutputResponse res = new UpdateApplicationAiOutputResponse();
            results.add(res);
            res.success = false;
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null) {
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            String newStatus = mapRecommendationToStatus(req.finalRecommendation);
            Database.SaveResult sr = Database.update(new Loan_Application__c(
                Id = loanAppId,
                Final_Recommendation__c = req.finalRecommendation,
                AI_Confidence__c = req.aiConfidence,
                Decision_Reasons__c = req.decisionReasons,
                Missing_Documents__c = req.missingDocuments,
                Next_Best_Action__c = req.nextBestAction,
                All_Agents_Completed__c = req.allAgentsCompleted,
                Risk_Score__c = req.riskScore,
                Status__c = newStatus
            ), false);
            if (!sr.isSuccess()) {
                res.errorMessage = sr.getErrors()[0].getMessage();
                continue;
            }
            res.newStatus = newStatus;
            res.success = true;
        }
        return results;
    }

    // --- 30. Accept AI Recommendation ---

    public class AcceptAiRecommendationRequest {
        @InvocableVariable(label='Loan Decision Id' required=true) public String loanDecisionId;
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
        @InvocableVariable(label='AI Recommendation' required=true) public String aiRecommendation;
    }
    public class AcceptAiRecommendationResponse {
        @InvocableVariable public String newApplicationStatus;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    public static List<AcceptAiRecommendationResponse> acceptAiRecommendation(
        List<AcceptAiRecommendationRequest> requests
    ) {
        List<AcceptAiRecommendationResponse> results = new List<AcceptAiRecommendationResponse>();
        for (AcceptAiRecommendationRequest req : requests) {
            AcceptAiRecommendationResponse res = new AcceptAiRecommendationResponse();
            results.add(res);
            res.success = false;
            String newStatus = mapRecommendationToStatus(req != null ? req.aiRecommendation : null);
            if (newStatus == null) {
                res.errorMessage = 'Invalid AI recommendation.';
                continue;
            }
            Database.SaveResult dr = Database.update(new Loan_Decision__c(
                Id = req.loanDecisionId,
                Officer_Decision__c = 'Accept AI',
                Officer_Reviewed__c = true,
                Officer_Reviewed_At__c = DateTime.now()
            ), false);
            if (!dr.isSuccess()) {
                res.errorMessage = dr.getErrors()[0].getMessage();
                continue;
            }
            Id loanAppId = resolveLoanAppId(req.loanApplicationId);
            if (loanAppId == null) {
                res.errorMessage = 'Loan application not found.';
                continue;
            }
            Database.SaveResult ar = Database.update(new Loan_Application__c(
                Id = loanAppId,
                Status__c = newStatus
            ), false);
            if (!ar.isSuccess()) {
                res.errorMessage = ar.getErrors()[0].getMessage();
                continue;
            }
            res.newApplicationStatus = newStatus;
            res.success = true;
        }
        return results;
    }

    // --- 31. Publish Agent Platform Event ---

    public class PublishAgentPlatformEventRequest {
        @InvocableVariable(label='Loan Application Id' required=true) public String loanApplicationId;
        @InvocableVariable(label='Event Action' required=true) public String eventAction;
        @InvocableVariable(label='Additional Context') public String additionalContext;
    }
    public class PublishAgentPlatformEventResponse {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    public static List<PublishAgentPlatformEventResponse> publishAgentPlatformEvent(
        List<PublishAgentPlatformEventRequest> requests
    ) {
        List<PublishAgentPlatformEventResponse> results = new List<PublishAgentPlatformEventResponse>();
        for (PublishAgentPlatformEventRequest req : requests) {
            PublishAgentPlatformEventResponse res = new PublishAgentPlatformEventResponse();
            results.add(res);
            res.success = false;
            Id loanAppId = resolveLoanAppId(req != null ? req.loanApplicationId : null);
            if (loanAppId == null || req == null || String.isBlank(req.eventAction)) {
                res.errorMessage = 'Loan Application Id and Event Action are required.';
                continue;
            }
            NBFC_Agent_Trigger__e evt = new NBFC_Agent_Trigger__e();
            evt.Loan_Application_Id__c = String.valueOf(loanAppId);
            evt.Event_Action__c = req.eventAction;
            evt.Triggered_At__c = DateTime.now();
            evt.Additional_Context__c = req.additionalContext;
            List<Database.SaveResult> publishResults = EventBus.publish(new List<NBFC_Agent_Trigger__e>{ evt });
            if (publishResults.isEmpty() || !publishResults[0].isSuccess()) {
                String msg = publishResults.isEmpty() ? 'Publish returned no result.'
                    : publishResults[0].getErrors()[0].getMessage();
                res.errorMessage = msg;
                continue;
            }
            res.success = true;
        }
        return results;
    }
}





