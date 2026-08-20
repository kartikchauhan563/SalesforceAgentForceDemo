# Generates one invocable Apex wrapper class per NBFC Agentforce flow action.
# Class names must be <= 40 characters (Salesforce Apex identifier limit).
param(
    [string]$ProjectRoot = "c:\Users\kchauhan030\Kartik Projects\SFDC AI UsedCase\SFDCAIUSECASE"
)

$ClassesDir = Join-Path $ProjectRoot "force-app\main\default\classes"
$wrappers = @(
    @{ Wrapper = 'NBFCFlowAction_SearchAppsByName'; Method = 'searchApplicationsByName'; Label = 'Search Applications By Name'; Request = 'SearchApplicationsByNameRequest'; Response = 'SearchApplicationsByNameResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetAppStatusHistory'; Method = 'getApplicationStatusHistory'; Label = 'Get Application Status History'; Request = 'GetApplicationStatusHistoryRequest'; Response = 'GetApplicationStatusHistoryResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetUploadedDocuments'; Method = 'getUploadedDocuments'; Label = 'Get Uploaded Documents'; Request = 'GetUploadedDocumentsRequest'; Response = 'GetUploadedDocumentsResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetAllComplianceRules'; Method = 'getAllComplianceRules'; Label = 'Get All Compliance Rules'; Request = 'GetAllComplianceRulesRequest'; Response = 'GetAllComplianceRulesResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetExistingCompliance'; Method = 'getExistingComplianceChecks'; Label = 'Get Existing Compliance Checks'; Request = 'GetExistingComplianceChecksRequest'; Response = 'GetExistingComplianceChecksResponse' },
    @{ Wrapper = 'NBFCFlowAction_CheckAgentCompletion'; Method = 'checkAgentCompletion'; Label = 'Check Agent Completion'; Request = 'CheckAgentCompletionRequest'; Response = 'CheckAgentCompletionResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetAllAgentResults'; Method = 'getAllAgentResults'; Label = 'Get All Agent Results'; Request = 'GetAllAgentResultsRequest'; Response = 'GetAllAgentResultsResponse' },
    @{ Wrapper = 'NBFCFlowAction_EscalateToUnderwriter'; Method = 'escalateToUnderwriter'; Label = 'Escalate To Underwriter'; Request = 'EscalateToUnderwriterRequest'; Response = 'EscalateToUnderwriterResponse' },
    @{ Wrapper = 'NBFCFlowAction_SendEscNotif'; Method = 'sendEscalationNotification'; Label = 'Send Escalation Notification'; Request = 'SendEscalationNotificationRequest'; Response = 'SendEscalationNotificationResponse' },
    @{ Wrapper = 'NBFCFlowAction_UpdateRiskScore'; Method = 'updateRiskScore'; Label = 'Update Risk Score'; Request = 'UpdateRiskScoreRequest'; Response = 'UpdateRiskScoreResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetPortfolioSummary'; Method = 'getPortfolioSummary'; Label = 'Get Portfolio Summary'; Request = 'GetPortfolioSummaryRequest'; Response = 'GetPortfolioSummaryResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetRiskDistribution'; Method = 'getRiskDistribution'; Label = 'Get Risk Distribution'; Request = 'GetRiskDistributionRequest'; Response = 'GetRiskDistributionResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetAgentPerformance'; Method = 'getAgentPerformance'; Label = 'Get Agent Performance'; Request = 'GetAgentPerformanceRequest'; Response = 'GetAgentPerformanceResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetMissingDocsReport'; Method = 'getMissingDocumentsReport'; Label = 'Get Missing Documents Report'; Request = 'GetMissingDocumentsReportRequest'; Response = 'GetMissingDocumentsReportResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetOfficerOverride'; Method = 'getOfficerOverrideReport'; Label = 'Get Officer Override Report'; Request = 'GetOfficerOverrideReportRequest'; Response = 'GetOfficerOverrideReportResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetAuditTrail'; Method = 'getAuditTrail'; Label = 'Get Audit Trail'; Request = 'GetAuditTrailRequest'; Response = 'GetAuditTrailResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetComplianceSummary'; Method = 'getComplianceSummary'; Label = 'Get Compliance Summary'; Request = 'GetComplianceSummaryRequest'; Response = 'GetComplianceSummaryResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetDailyVolume'; Method = 'getDailyVolume'; Label = 'Get Daily Volume'; Request = 'GetDailyVolumeRequest'; Response = 'GetDailyVolumeResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetLoanAppDetails'; Method = 'getLoanApplicationDetails'; Label = 'Get Loan Application Details'; Request = 'GetLoanApplicationDetailsRequest'; Response = 'GetLoanApplicationDetailsResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetRequiredDocuments'; Method = 'getRequiredDocuments'; Label = 'Get Required Documents'; Request = 'GetRequiredDocumentsRequest'; Response = 'GetRequiredDocumentsResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetFinancialData'; Method = 'getFinancialData'; Label = 'Get Financial Data'; Request = 'GetFinancialDataRequest'; Response = 'GetFinancialDataResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetFoirPolicy'; Method = 'getFoirPolicy'; Label = 'Get FOIR Policy'; Request = 'GetFoirPolicyRequest'; Response = 'GetFoirPolicyResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetRiskAssessment'; Method = 'getRiskAssessment'; Label = 'Get Risk Assessment'; Request = 'GetRiskAssessmentRequest'; Response = 'GetRiskAssessmentResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetCreditScorePolicy'; Method = 'getCreditScorePolicy'; Label = 'Get Credit Score Policy'; Request = 'GetCreditScorePolicyRequest'; Response = 'GetCreditScorePolicyResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetKycStatus'; Method = 'getKycStatus'; Label = 'Get KYC Status'; Request = 'GetKycStatusRequest'; Response = 'GetKycStatusResponse' },
    @{ Wrapper = 'NBFCFlowAction_GetLoanDecision'; Method = 'getLoanDecision'; Label = 'Get Loan Decision'; Request = 'GetLoanDecisionRequest'; Response = 'GetLoanDecisionResponse' },
    @{ Wrapper = 'NBFCFlowAction_UpdateMissingDocuments'; Method = 'updateMissingDocuments'; Label = 'Update Missing Documents'; Request = 'UpdateMissingDocumentsRequest'; Response = 'UpdateMissingDocumentsResponse' },
    @{ Wrapper = 'NBFCFlowAction_FlagForFraudReview'; Method = 'flagForFraudReview'; Label = 'Flag For Fraud Review'; Request = 'FlagForFraudReviewRequest'; Response = 'FlagForFraudReviewResponse' },
    @{ Wrapper = 'NBFCFlowAction_UpdateAppAiOutput'; Method = 'updateApplicationAiOutput'; Label = 'Update Application AI Output'; Request = 'UpdateApplicationAiOutputRequest'; Response = 'UpdateApplicationAiOutputResponse' },
    @{ Wrapper = 'NBFCFlowAction_AcceptAiRecommendation'; Method = 'acceptAiRecommendation'; Label = 'Accept AI Recommendation'; Request = 'AcceptAiRecommendationRequest'; Response = 'AcceptAiRecommendationResponse' },
    @{ Wrapper = 'NBFCFlowAction_PublishAgentEvent'; Method = 'publishAgentPlatformEvent'; Label = 'Publish Agent Platform Event'; Request = 'PublishAgentPlatformEventRequest'; Response = 'PublishAgentPlatformEventResponse' }
)

foreach ($w in $wrappers) {
    if ($w.Wrapper.Length -gt 40) {
        throw "Wrapper class name too long ($($w.Wrapper.Length) chars): $($w.Wrapper)"
    }
    $cls = @"
public with sharing class $($w.Wrapper) {
    @InvocableMethod(label='$($w.Label)' description='NBFC Agentforce flow action wrapper')
    public static List<NBFCAgentFlowService.$($w.Response)> run(
        List<NBFCAgentFlowService.$($w.Request)> requests
    ) {
        return NBFCAgentFlowService.$($w.Method)(requests);
    }
}
"@
    $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <status>Active</status>
</ApexClass>
"@
    [System.IO.File]::WriteAllText((Join-Path $ClassesDir "$($w.Wrapper).cls"), $cls, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $ClassesDir "$($w.Wrapper).cls-meta.xml"), $meta, [System.Text.UTF8Encoding]::new($false))
}

# Remove obsolete wrapper classes with names that exceeded the 40-char limit
$obsolete = @(
    'NBFCFlowAction_SearchApplicationsByName',
    'NBFCFlowAction_GetApplicationStatusHistory',
    'NBFCFlowAction_GetExistingComplianceChecks',
    'NBFCFlowAction_SendEscalationNotification',
    'NBFCFlowAction_GetMissingDocumentsReport',
    'NBFCFlowAction_GetOfficerOverrideReport',
    'NBFCFlowAction_GetLoanApplicationDetails',
    'NBFCFlowAction_PublishAgentPlatformEvent',
    'NBFCFlowAction_UpdateApplicationAiOutput'
)
foreach ($name in $obsolete) {
    $clsPath = Join-Path $ClassesDir "$name.cls"
    $metaPath = Join-Path $ClassesDir "$name.cls-meta.xml"
    if (Test-Path $clsPath) { Remove-Item $clsPath -Force }
    if (Test-Path $metaPath) { Remove-Item $metaPath -Force }
}

Write-Host "Generated $($wrappers.Count) flow wrapper classes."
