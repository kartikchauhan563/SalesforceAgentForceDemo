# Generates 31 NBFC Agentforce Auto-Launched Flow metadata files (.flow-meta.xml)
# Hybrid: simple flows use recordLookups in Flow XML; complex flows call NBFCAgentFlowService Apex.
param(
    [string]$ProjectRoot = "c:\Users\kchauhan030\Kartik Projects\SFDC AI UsedCase\SFDCAIUSECASE"
)

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

$FlowsDir = Join-Path $ProjectRoot "force-app\main\default\flows"
$DataLoadDir = Join-Path $ProjectRoot "data-load"
Ensure-Dir $FlowsDir
Ensure-Dir $DataLoadDir

function Write-FlowFile($apiName, $content) {
    $path = Join-Path $FlowsDir "$apiName.flow-meta.xml"
    [System.IO.File]::WriteAllText($path, $content.TrimStart(), [System.Text.UTF8Encoding]::new($false))
    return $path
}

function Get-FlowHeader($label, $description) {
    $desc = [System.Security.SecurityElement]::Escape($description)
    @"
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <description>$desc</description>
    <environments>Default</environments>
    <interviewLabel>$label {!`$Flow.CurrentDateTime}</interviewLabel>
    <label>$label</label>
    <processMetadataValues>
        <name>BuilderType</name>
        <value><stringValue>LightningFlowBuilder</stringValue></value>
    </processMetadataValues>
    <processMetadataValues>
        <name>CanvasMode</name>
        <value><stringValue>AUTO_LAYOUT_CANVAS</stringValue></value>
    </processMetadataValues>
    <processMetadataValues>
        <name>OriginBuilderType</name>
        <value><stringValue>LightningFlowBuilder</stringValue></value>
    </processMetadataValues>
    <processType>AutoLaunchedFlow</processType>

"@
}

function Get-FlowWrapperClass($apiName) {
    $map = @{
        'Search_Applications_By_Name_Flow' = 'NBFCFlowAction_SearchAppsByName'
        'Get_Application_Status_History_Flow' = 'NBFCFlowAction_GetAppStatusHistory'
        'Get_Uploaded_Documents_Flow' = 'NBFCFlowAction_GetUploadedDocuments'
        'Get_All_Compliance_Rules_Flow' = 'NBFCFlowAction_GetAllComplianceRules'
        'Get_Existing_Compliance_Checks_Flow' = 'NBFCFlowAction_GetExistingCompliance'
        'Check_Agent_Completion_Flow' = 'NBFCFlowAction_CheckAgentCompletion'
        'Get_All_Agent_Results_Flow' = 'NBFCFlowAction_GetAllAgentResults'
        'Escalate_To_Underwriter_Flow' = 'NBFCFlowAction_EscalateToUnderwriter'
        'Send_Escalation_Notification_Flow' = 'NBFCFlowAction_SendEscNotif'
        'Update_Risk_Score_Flow' = 'NBFCFlowAction_UpdateRiskScore'
        'Get_Portfolio_Summary_Flow' = 'NBFCFlowAction_GetPortfolioSummary'
        'Get_Risk_Distribution_Flow' = 'NBFCFlowAction_GetRiskDistribution'
        'Get_Agent_Performance_Flow' = 'NBFCFlowAction_GetAgentPerformance'
        'Get_Missing_Documents_Report_Flow' = 'NBFCFlowAction_GetMissingDocsReport'
        'Get_Officer_Override_Report_Flow' = 'NBFCFlowAction_GetOfficerOverride'
        'Get_Audit_Trail_Flow' = 'NBFCFlowAction_GetAuditTrail'
        'Get_Compliance_Summary_Flow' = 'NBFCFlowAction_GetComplianceSummary'
        'Get_Daily_Volume_Flow' = 'NBFCFlowAction_GetDailyVolume'
        'Get_Loan_Application_Details_Flow' = 'NBFCFlowAction_GetLoanAppDetails'
        'Get_Required_Documents_Flow' = 'NBFCFlowAction_GetRequiredDocuments'
        'Get_Financial_Data_Flow' = 'NBFCFlowAction_GetFinancialData'
        'Get_FOIR_Policy_Flow' = 'NBFCFlowAction_GetFoirPolicy'
        'Get_Risk_Assessment_Flow' = 'NBFCFlowAction_GetRiskAssessment'
        'Get_Credit_Score_Policy_Flow' = 'NBFCFlowAction_GetCreditScorePolicy'
        'Get_KYC_Status_Flow' = 'NBFCFlowAction_GetKycStatus'
        'Get_Loan_Decision_Flow' = 'NBFCFlowAction_GetLoanDecision'
        'Update_Missing_Documents_Flow' = 'NBFCFlowAction_UpdateMissingDocuments'
        'Flag_For_Fraud_Review_Flow' = 'NBFCFlowAction_FlagForFraudReview'
        'Update_Application_AI_Output_Flow' = 'NBFCFlowAction_UpdateAppAiOutput'
        'Accept_AI_Recommendation_Flow' = 'NBFCFlowAction_AcceptAiRecommendation'
        'Publish_Agent_Platform_Event_Flow' = 'NBFCFlowAction_PublishAgentEvent'
    }
    if ($map.ContainsKey($apiName)) { return $map[$apiName] }
    throw "No wrapper mapping for flow: $apiName"
}

function Get-FlowFooter($startTarget) {
    @"
    <start>
        <locationX>50</locationX>
        <locationY>0</locationY>
        <connector><targetReference>$startTarget</targetReference></connector>
    </start>
    <status>Active</status>
</Flow>
"@
}

function New-TextVariable($name, $isInput, $isOutput) {
    $inVal = if ($isInput) { 'true' } else { 'false' }
    $outVal = if ($isOutput) { 'true' } else { 'false' }
    @"
    <variables>
        <name>$name</name>
        <dataType>String</dataType>
        <isCollection>false</isCollection>
        <isInput>$inVal</isInput>
        <isOutput>$outVal</isOutput>
    </variables>
"@
}

function New-NumberVariable($name, $isInput, $isOutput, [int]$Scale = 2) {
    $inVal = if ($isInput) { 'true' } else { 'false' }
    $outVal = if ($isOutput) { 'true' } else { 'false' }
    @"
    <variables>
        <name>$name</name>
        <dataType>Number</dataType>
        <isCollection>false</isCollection>
        <isInput>$inVal</isInput>
        <isOutput>$outVal</isOutput>
        <scale>$Scale</scale>
    </variables>
"@
}

function New-BooleanVariable($name, $isInput, $isOutput) {
    $inVal = if ($isInput) { 'true' } else { 'false' }
    $outVal = if ($isOutput) { 'true' } else { 'false' }
    @"
    <variables>
        <name>$name</name>
        <dataType>Boolean</dataType>
        <isCollection>false</isCollection>
        <isInput>$inVal</isInput>
        <isOutput>$outVal</isOutput>
    </variables>
"@
}

function New-CurrencyVariable($name, $isInput, $isOutput) {
    $inVal = if ($isInput) { 'true' } else { 'false' }
    $outVal = if ($isOutput) { 'true' } else { 'false' }
    @"
    <variables>
        <name>$name</name>
        <dataType>Currency</dataType>
        <isCollection>false</isCollection>
        <isInput>$inVal</isInput>
        <isOutput>$outVal</isOutput>
        <scale>2</scale>
    </variables>
"@
}

function New-DateVariable($name, $isInput, $isOutput) {
    $inVal = if ($isInput) { 'true' } else { 'false' }
    $outVal = if ($isOutput) { 'true' } else { 'false' }
    @"
    <variables>
        <name>$name</name>
        <dataType>Date</dataType>
        <isCollection>false</isCollection>
        <isInput>$inVal</isInput>
        <isOutput>$outVal</isOutput>
    </variables>
"@
}

function New-ApexWrapperFlow {
    param(
        [string]$ApiName,
        [string]$Label,
        [string]$Description,
        [string]$InvocableLabel,
        [array]$InputVars,
        [array]$OutputVars,
        [hashtable]$ApexInputMap,
        [hashtable]$ApexOutputMap,
        [switch]$HasFaultOutputs
    )
    $varsXml = ""
    foreach ($v in $InputVars) { $varsXml += "`n" + $v }
    foreach ($v in $OutputVars) { $varsXml += "`n" + $v }
    if ($HasFaultOutputs) {
        if (-not ($OutputVars -match 'Success')) {
            $varsXml += (New-BooleanVariable 'Success' $false $true)
            $varsXml += (New-TextVariable 'Error_Message' $false $true)
        }
    }

    $inParams = ""
    foreach ($key in $ApexInputMap.Keys) {
        $flowVar = $ApexInputMap[$key]
        $inParams += @"
        <inputParameters>
            <name>$key</name>
            <value>
                <elementReference>$flowVar</elementReference>
            </value>
        </inputParameters>
"@
    }

    $outParams = ""
    foreach ($key in $ApexOutputMap.Keys) {
        $flowVar = $ApexOutputMap[$key]
        $outParams += @"

        <outputParameters>
            <assignToReference>$flowVar</assignToReference>
            <name>$key</name>
        </outputParameters>
"@
    }

    $faultConnector = ""
    $faultAssign = ""
    if ($HasFaultOutputs) {
        $faultConnector = "<faultConnector><targetReference>Set_Fault_Outputs</targetReference></faultConnector>"
        $faultAssign = @"
    <assignments>
        <name>Set_Fault_Outputs</name>
        <label>Set Fault Outputs</label>
        <locationX>440</locationX>
        <locationY>350</locationY>
        <assignmentItems>
            <assignToReference>Success</assignToReference>
            <operator>Assign</operator>
            <value><booleanValue>false</booleanValue></value>
        </assignmentItems>
        <assignmentItems>
            <assignToReference>Error_Message</assignToReference>
            <operator>Assign</operator>
            <value><elementReference>`$Flow.FaultMessage</elementReference></value>
        </assignmentItems>
    </assignments>
"@
    }

    $wrapperClass = Get-FlowWrapperClass $ApiName
    $content = Get-FlowHeader $Label $Description
    $content += @"
    <actionCalls>
        <name>Call_NBFC_Apex</name>
        <label>Call NBFC Apex Service</label>
        <locationX>176</locationX>
        <locationY>158</locationY>
        <actionName>$wrapperClass</actionName>
        <actionType>apex</actionType>
        <flowTransactionModel>CurrentTransaction</flowTransactionModel>
$inParams
$outParams
        $faultConnector
    </actionCalls>
$faultAssign
    <start>
        <locationX>50</locationX>
        <locationY>0</locationY>
        <connector>
            <targetReference>Call_NBFC_Apex</targetReference>
        </connector>
    </start>
    <status>Active</status>
$varsXml
</Flow>
"@
    Write-FlowFile $ApiName $content
}

function New-SimpleGetLoanAppFlow {
    # Flow 1 uses Apex wrapper for reliable cross-object field mapping (Id or LA-* lookup).
    New-ApexWrapperFlow -ApiName 'Get_Loan_Application_Details_Flow' -Label 'Get Loan Application Details' `
        -Description 'Retrieves complete Loan_Application__c by Id or application number (LA-*). Called by Loan Application Lookup and Decision Agent sub-agents.' `
        -InvocableLabel 'Get Loan Application Details' `
        -InputVars @((New-TextVariable 'Loan_Application_Id' $true $false)) `
        -OutputVars @(
            (New-TextVariable 'Application_Number' $false $true),
            (New-TextVariable 'Applicant_Name' $false $true),
            (New-CurrencyVariable 'Loan_Amount' $false $true),
            (New-CurrencyVariable 'Loan_Amount_Approved' $false $true),
            (New-TextVariable 'Product_Name' $false $true),
            (New-TextVariable 'Product_Code' $false $true),
            (New-NumberVariable 'Tenure_Months' $false $true),
            (New-NumberVariable 'Interest_Rate' $false $true),
            (New-CurrencyVariable 'Monthly_Income' $false $true),
            (New-CurrencyVariable 'Existing_EMI' $false $true),
            (New-NumberVariable 'EMI_Burden_Pct' $false $true),
            (New-CurrencyVariable 'Calculated_EMI' $false $true),
            (New-NumberVariable 'FOIR_After_Loan' $false $true),
            (New-NumberVariable 'LTI' $false $true),
            (New-NumberVariable 'Credit_Score' $false $true),
            (New-TextVariable 'Status' $false $true),
            (New-TextVariable 'Sub_Status' $false $true),
            (New-TextVariable 'Priority' $false $true),
            (New-TextVariable 'Branch' $false $true),
            (New-NumberVariable 'Risk_Score' $false $true),
            (New-TextVariable 'Risk_Level' $false $true),
            (New-TextVariable 'Final_Recommendation' $false $true),
            (New-NumberVariable 'AI_Confidence' $false $true),
            (New-TextVariable 'Decision_Reasons' $false $true),
            (New-TextVariable 'Missing_Documents' $false $true),
            (New-TextVariable 'Next_Best_Action' $false $true),
            (New-BooleanVariable 'All_Agents_Completed' $false $true),
            (New-TextVariable 'Loan_Officer_Name' $false $true),
            (New-TextVariable 'Underwriter_Name' $false $true),
            (New-DateVariable 'Application_Date' $false $true),
            (New-TextVariable 'Loan_Purpose' $false $true),
            (New-TextVariable 'Application_Channel' $false $true),
            (New-BooleanVariable 'Record_Found' $false $true),
            (New-TextVariable 'Error_Message' $false $true)
        ) `
        -ApexInputMap @{ loanApplicationId='Loan_Application_Id' } `
        -ApexOutputMap @{
            applicationNumber='Application_Number'; applicantName='Applicant_Name'; loanAmount='Loan_Amount'
            loanAmountApproved='Loan_Amount_Approved'; productName='Product_Name'; productCode='Product_Code'
            tenureMonths='Tenure_Months'; interestRate='Interest_Rate'; monthlyIncome='Monthly_Income'
            existingEmi='Existing_EMI'; emiBurdenPct='EMI_Burden_Pct'; calculatedEmi='Calculated_EMI'
            foirAfterLoan='FOIR_After_Loan'; lti='LTI'; creditScore='Credit_Score'; status='Status'
            subStatus='Sub_Status'; priority='Priority'; branch='Branch'; riskScore='Risk_Score'
            riskLevel='Risk_Level'; finalRecommendation='Final_Recommendation'; aiConfidence='AI_Confidence'
            decisionReasons='Decision_Reasons'; missingDocuments='Missing_Documents'; nextBestAction='Next_Best_Action'
            allAgentsCompleted='All_Agents_Completed'; loanOfficerName='Loan_Officer_Name'; underwriterName='Underwriter_Name'
            applicationDate='Application_Date'; loanPurpose='Loan_Purpose'; applicationChannel='Application_Channel'
            recordFound='Record_Found'; errorMessage='Error_Message'
        }
}

function New-SimpleRecordLookupFlow {
    param(
        [string]$ApiName,
        [string]$Label,
        [string]$Description,
        [string]$InvocableLabel,
        [array]$InputVars,
        [array]$OutputVars,
        [hashtable]$ApexInputMap,
        [hashtable]$ApexOutputMap
    )
    # Simple get/map flows still use Apex for reliable cross-object mapping; recordLookups remain in dedicated flows above.
    New-ApexWrapperFlow -ApiName $ApiName -Label $Label -Description $Description `
        -InvocableLabel $InvocableLabel -InputVars $InputVars -OutputVars $OutputVars `
        -ApexInputMap $ApexInputMap -ApexOutputMap $ApexOutputMap
}

$created = @()

# --- Simple / hybrid flows with Get Records in Flow XML where specified ---
$created += (New-SimpleGetLoanAppFlow)

# Financial / documents / KYC / policies / decisions - thin wrappers calling Apex (logic in service)
$flowDefs = @(
    @{
        Api='Get_Required_Documents_Flow'; Label='Get Required Documents'
        Desc='Returns mandatory documents for loan product. Document Verification Agent.'
        Inv='Get Required Documents'
        In=@((New-TextVariable 'Loan_Application_Id' $true $false))
        Out=@((New-TextVariable 'Required_Documents_List' $false $true),(New-NumberVariable 'Required_Documents_Count' $false $true),(New-TextVariable 'Product_Name' $false $true),(New-TextVariable 'Product_Code' $false $true),(New-BooleanVariable 'Record_Found' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ loanApplicationId='Loan_Application_Id' }
        OutMap=@{ requiredDocumentsList='Required_Documents_List'; requiredDocumentsCount='Required_Documents_Count'; productName='Product_Name'; productCode='Product_Code'; recordFound='Record_Found'; errorMessage='Error_Message' }
    },
    @{
        Api='Get_Financial_Data_Flow'; Label='Get Financial Data'
        Desc='Financial fields for Financial Health Agent sub-agent.'
        Inv='Get Financial Data'
        In=@((New-TextVariable 'Loan_Application_Id' $true $false))
        Out=@((New-CurrencyVariable 'Monthly_Income' $false $true),(New-CurrencyVariable 'Existing_EMI' $false $true),(New-CurrencyVariable 'Loan_Amount' $false $true),(New-NumberVariable 'Tenure_Months' $false $true),(New-NumberVariable 'Interest_Rate' $false $true),(New-NumberVariable 'EMI_Burden_Pct' $false $true),(New-CurrencyVariable 'Calculated_EMI' $false $true),(New-NumberVariable 'FOIR_After_Loan' $false $true),(New-NumberVariable 'LTI' $false $true),(New-NumberVariable 'Credit_Score' $false $true),(New-TextVariable 'Applicant_Name' $false $true),(New-TextVariable 'Product_Code' $false $true),(New-TextVariable 'Product_Name' $false $true),(New-BooleanVariable 'Record_Found' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ loanApplicationId='Loan_Application_Id' }
        OutMap=@{ monthlyIncome='Monthly_Income'; existingEmi='Existing_EMI'; loanAmount='Loan_Amount'; tenureMonths='Tenure_Months'; interestRate='Interest_Rate'; emiBurdenPct='EMI_Burden_Pct'; calculatedEmi='Calculated_EMI'; foirAfterLoan='FOIR_After_Loan'; lti='LTI'; creditScore='Credit_Score'; applicantName='Applicant_Name'; productCode='Product_Code'; productName='Product_Name'; recordFound='Record_Found'; errorMessage='Error_Message' }
    },
    @{
        Api='Get_FOIR_Policy_Flow'; Label='Get FOIR Policy'
        Desc='Max FOIR from Policy_Rule__mdt. Financial Health Agent.'
        Inv='Get FOIR Policy'
        In=@((New-TextVariable 'Product_Code' $true $false))
        Out=@((New-NumberVariable 'Max_FOIR_Threshold' $false $true),(New-TextVariable 'Max_FOIR_Display' $false $true),(New-TextVariable 'Rule_Name' $false $true),(New-TextVariable 'Severity' $false $true),(New-BooleanVariable 'Record_Found' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ productCode='Product_Code' }
        OutMap=@{ maxFoirThreshold='Max_FOIR_Threshold'; maxFoirDisplay='Max_FOIR_Display'; ruleName='Rule_Name'; severity='Severity'; recordFound='Record_Found'; errorMessage='Error_Message' }
    },
    @{
        Api='Get_Risk_Assessment_Flow'; Label='Get Risk Assessment'
        Desc='Bureau and fraud data. Credit Risk Agent.'
        Inv='Get Risk Assessment'
        In=@((New-TextVariable 'Loan_Application_Id' $true $false))
        Out=@((New-NumberVariable 'Bureau_Score' $false $true),(New-TextVariable 'Bureau_Source' $false $true),(New-NumberVariable 'Past_Defaults' $false $true),(New-NumberVariable 'Past_Bounces_12M' $false $true),(New-NumberVariable 'Active_Loans' $false $true),(New-NumberVariable 'Credit_Inquiries_6M' $false $true),(New-NumberVariable 'Fraud_Score' $false $true),(New-BooleanVariable 'Identity_Verified' $false $true),(New-TextVariable 'Address_Risk' $false $true),(New-TextVariable 'Sector_Risk' $false $true),(New-NumberVariable 'Final_Risk_Score' $false $true),(New-TextVariable 'Risk_Category' $false $true),(New-TextVariable 'Risk_Reasons' $false $true),(New-TextVariable 'Risk_Assessment_Id' $false $true),(New-BooleanVariable 'Record_Found' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ loanApplicationId='Loan_Application_Id' }
        OutMap=@{ bureauScore='Bureau_Score'; bureauSource='Bureau_Source'; pastDefaults='Past_Defaults'; pastBounces12M='Past_Bounces_12M'; activeLoans='Active_Loans'; creditInquiries6M='Credit_Inquiries_6M'; fraudScore='Fraud_Score'; identityVerified='Identity_Verified'; addressRisk='Address_Risk'; sectorRisk='Sector_Risk'; finalRiskScore='Final_Risk_Score'; riskCategory='Risk_Category'; riskReasons='Risk_Reasons'; riskAssessmentId='Risk_Assessment_Id'; recordFound='Record_Found'; errorMessage='Error_Message' }
    },
    @{
        Api='Get_Credit_Score_Policy_Flow'; Label='Get Credit Score Policy'
        Desc='Min credit score from Policy_Rule__mdt. Credit Risk Agent.'
        Inv='Get Credit Score Policy'
        In=@((New-TextVariable 'Product_Code' $true $false))
        Out=@((New-NumberVariable 'Min_Credit_Score' $false $true),(New-TextVariable 'Rule_Name' $false $true),(New-TextVariable 'Severity' $false $true),(New-BooleanVariable 'Record_Found' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ productCode='Product_Code' }
        OutMap=@{ minCreditScore='Min_Credit_Score'; ruleName='Rule_Name'; severity='Severity'; recordFound='Record_Found'; errorMessage='Error_Message' }
    },
    @{
        Api='Get_KYC_Status_Flow'; Label='Get KYC Status'
        Desc='KYC and masked identity from applicant Account. Compliance Verification Agent.'
        Inv='Get KYC Status'
        In=@((New-TextVariable 'Loan_Application_Id' $true $false))
        Out=@((New-TextVariable 'KYC_Status' $false $true),(New-TextVariable 'PAN_Number_Masked' $false $true),(New-TextVariable 'Aadhaar_Number_Masked' $false $true),(New-TextVariable 'Applicant_Name' $false $true),(New-TextVariable 'Customer_Segment' $false $true),(New-TextVariable 'Employment_Status' $false $true),(New-NumberVariable 'Bureau_Score' $false $true),(New-TextVariable 'Risk_Category' $false $true),(New-BooleanVariable 'Record_Found' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ loanApplicationId='Loan_Application_Id' }
        OutMap=@{ kycStatus='KYC_Status'; panNumberMasked='PAN_Number_Masked'; aadhaarNumberMasked='Aadhaar_Number_Masked'; applicantName='Applicant_Name'; customerSegment='Customer_Segment'; employmentStatus='Employment_Status'; bureauScore='Bureau_Score'; riskCategory='Risk_Category'; recordFound='Record_Found'; errorMessage='Error_Message' }
    },
    @{
        Api='Get_Loan_Decision_Flow'; Label='Get Loan Decision'
        Desc='Loan decision for Officer Review sub-agent.'
        Inv='Get Loan Decision'
        In=@((New-TextVariable 'Loan_Application_Id' $true $false))
        Out=@((New-TextVariable 'Loan_Decision_Id' $false $true),(New-TextVariable 'Recommendation' $false $true),(New-NumberVariable 'Confidence_Score' $false $true),(New-CurrencyVariable 'Approved_Amount' $false $true),(New-TextVariable 'Decision_Summary' $false $true),(New-TextVariable 'Key_Reasons' $false $true),(New-TextVariable 'Missing_Paperwork' $false $true),(New-TextVariable 'Next_Best_Action' $false $true),(New-TextVariable 'Conditions' $false $true),(New-TextVariable 'Generated_By' $false $true),(New-TextVariable 'AI_Model' $false $true),(New-BooleanVariable 'Record_Found' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ loanApplicationId='Loan_Application_Id' }
        OutMap=@{ loanDecisionId='Loan_Decision_Id'; recommendation='Recommendation'; confidenceScore='Confidence_Score'; approvedAmount='Approved_Amount'; decisionSummary='Decision_Summary'; keyReasons='Key_Reasons'; missingPaperwork='Missing_Paperwork'; nextBestAction='Next_Best_Action'; conditions='Conditions'; generatedBy='Generated_By'; aiModel='AI_Model'; recordFound='Record_Found'; errorMessage='Error_Message' }
    }
)

foreach ($d in $flowDefs) {
    $created += (New-ApexWrapperFlow -ApiName $d.Api -Label $d.Label -Description $d.Desc -InvocableLabel $d.Inv `
        -InputVars $d.In -OutputVars $d.Out -ApexInputMap $d.InMap -ApexOutputMap $d.OutMap)
}

# Update / create flows with fault paths
$mutatingFlows = @(
    @{
        Api='Update_Missing_Documents_Flow'; Label='Update Missing Documents'; Inv='Update Missing Documents'; HasFault=$true
        Desc='Updates Missing_Documents__c. Document Verification Agent.'
        In=@((New-TextVariable 'Loan_Application_Id' $true $false),(New-TextVariable 'Missing_Documents_List' $true $false))
        Out=@((New-BooleanVariable 'Success' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ loanApplicationId='Loan_Application_Id'; missingDocumentsList='Missing_Documents_List' }
        OutMap=@{ success='Success'; errorMessage='Error_Message' }
    },
    @{
        Api='Flag_For_Fraud_Review_Flow'; Label='Flag For Fraud Review'; Inv='Flag For Fraud Review'; HasFault=$true
        Desc='Creates Compliance_Check__c fraud flag. Credit Risk Agent.'
        In=@((New-TextVariable 'Loan_Application_Id' $true $false),(New-NumberVariable 'Fraud_Score' $true $false),(New-NumberVariable 'Fraud_Threshold' $true $false))
        Out=@((New-TextVariable 'Compliance_Check_Id' $false $true),(New-BooleanVariable 'Success' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ loanApplicationId='Loan_Application_Id'; fraudScore='Fraud_Score'; fraudThreshold='Fraud_Threshold' }
        OutMap=@{ complianceCheckId='Compliance_Check_Id'; success='Success'; errorMessage='Error_Message' }
    },
    @{
        Api='Update_Application_AI_Output_Flow'; Label='Update Application AI Output'; Inv='Update Application AI Output'; HasFault=$true
        Desc='Updates AI recommendation fields. Decision Agent.'
        In=@((New-TextVariable 'Loan_Application_Id' $true $false),(New-TextVariable 'Final_Recommendation' $true $false),(New-NumberVariable 'AI_Confidence' $true $false),(New-TextVariable 'Decision_Reasons' $true $false),(New-TextVariable 'Missing_Documents' $true $false),(New-TextVariable 'Next_Best_Action' $true $false),(New-BooleanVariable 'All_Agents_Completed' $true $false),(New-NumberVariable 'Risk_Score' $true $false))
        Out=@((New-TextVariable 'New_Status' $false $true),(New-BooleanVariable 'Success' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ loanApplicationId='Loan_Application_Id'; finalRecommendation='Final_Recommendation'; aiConfidence='AI_Confidence'; decisionReasons='Decision_Reasons'; missingDocuments='Missing_Documents'; nextBestAction='Next_Best_Action'; allAgentsCompleted='All_Agents_Completed'; riskScore='Risk_Score' }
        OutMap=@{ newStatus='New_Status'; success='Success'; errorMessage='Error_Message' }
    },
    @{
        Api='Accept_AI_Recommendation_Flow'; Label='Accept AI Recommendation'; Inv='Accept AI Recommendation'; HasFault=$true
        Desc='Officer accepts AI recommendation. Officer Review sub-agent.'
        In=@((New-TextVariable 'Loan_Decision_Id' $true $false),(New-TextVariable 'Loan_Application_Id' $true $false),(New-TextVariable 'AI_Recommendation' $true $false))
        Out=@((New-TextVariable 'New_Application_Status' $false $true),(New-BooleanVariable 'Success' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ loanDecisionId='Loan_Decision_Id'; loanApplicationId='Loan_Application_Id'; aiRecommendation='AI_Recommendation' }
        OutMap=@{ newApplicationStatus='New_Application_Status'; success='Success'; errorMessage='Error_Message' }
    },
    @{
        Api='Publish_Agent_Platform_Event_Flow'; Label='Publish Agent Platform Event'; Inv='Publish Agent Platform Event'; HasFault=$true
        Desc='Publishes NBFC_Agent_Trigger__e. Decision Agent.'
        In=@((New-TextVariable 'Loan_Application_Id' $true $false),(New-TextVariable 'Event_Action' $true $false),(New-TextVariable 'Additional_Context' $true $false))
        Out=@((New-BooleanVariable 'Success' $false $true),(New-TextVariable 'Error_Message' $false $true))
        InMap=@{ loanApplicationId='Loan_Application_Id'; eventAction='Event_Action'; additionalContext='Additional_Context' }
        OutMap=@{ success='Success'; errorMessage='Error_Message' }
    }
)
foreach ($d in $mutatingFlows) {
    $created += (New-ApexWrapperFlow -ApiName $d.Api -Label $d.Label -Description $d.Desc -InvocableLabel $d.Inv `
        -InputVars $d.In -OutputVars $d.Out -ApexInputMap $d.InMap -ApexOutputMap $d.OutMap -HasFaultOutputs:$d.HasFault)
}

# Complex flows (loops, text building, aggregates)
$complexFlows = @(
    @{ Api='Search_Applications_By_Name_Flow'; Label='Search Applications By Name'; Inv='Search Applications By Name'
       Desc='Search by applicant name. Loan Application Lookup sub-agent.'
       In=@((New-TextVariable 'Applicant_Name_Search' $true $false))
       Out=@((New-TextVariable 'Matching_Applications' $false $true),(New-NumberVariable 'Match_Count' $false $true),(New-BooleanVariable 'Record_Found' $false $true),(New-TextVariable 'Error_Message' $false $true))
       InMap=@{ applicantNameSearch='Applicant_Name_Search' }
       OutMap=@{ matchingApplications='Matching_Applications'; matchCount='Match_Count'; recordFound='Record_Found'; errorMessage='Error_Message' } },
    @{ Api='Get_Application_Status_History_Flow'; Label='Get Application Status History'; Inv='Get Application Status History'
       Desc='Last N history events. Loan Application Lookup sub-agent.'
       In=@((New-TextVariable 'Loan_Application_Id' $true $false),(New-BooleanVariable 'Compliance_Relevant_Only' $true $false),(New-NumberVariable 'Limit_Records' $true $false))
       Out=@((New-TextVariable 'History_Events_Text' $false $true),(New-NumberVariable 'Total_Events_Found' $false $true),(New-BooleanVariable 'Record_Found' $false $true))
       InMap=@{ loanApplicationId='Loan_Application_Id'; complianceRelevantOnly='Compliance_Relevant_Only'; limitRecords='Limit_Records' }
       OutMap=@{ historyEventsText='History_Events_Text'; totalEventsFound='Total_Events_Found'; recordFound='Record_Found' } },
    @{ Api='Get_Uploaded_Documents_Flow'; Label='Get Uploaded Documents'; Inv='Get Uploaded Documents'
       Desc='Document verification summary. Document Verification Agent.'
       In=@((New-TextVariable 'Loan_Application_Id' $true $false))
       Out=@((New-TextVariable 'Documents_Summary_Text' $false $true),(New-NumberVariable 'Total_Documents' $false $true),(New-NumberVariable 'Uploaded_Count' $false $true),(New-NumberVariable 'Verified_Count' $false $true),(New-NumberVariable 'Failed_Count' $false $true),(New-NumberVariable 'Missing_Count' $false $true),(New-TextVariable 'Issues_Found_Text' $false $true),(New-TextVariable 'Missing_Documents_Text' $false $true),(New-BooleanVariable 'Record_Found' $false $true))
       InMap=@{ loanApplicationId='Loan_Application_Id' }
       OutMap=@{ documentsSummaryText='Documents_Summary_Text'; totalDocuments='Total_Documents'; uploadedCount='Uploaded_Count'; verifiedCount='Verified_Count'; failedCount='Failed_Count'; missingCount='Missing_Count'; issuesFoundText='Issues_Found_Text'; missingDocumentsText='Missing_Documents_Text'; recordFound='Record_Found' } },
    @{ Api='Get_All_Compliance_Rules_Flow'; Label='Get All Compliance Rules'; Inv='Get All Compliance Rules'
       Desc='Active Compliance_Rule__mdt. Compliance Verification Agent.'
       In=@(); Out=@((New-TextVariable 'Compliance_Rules_Text' $false $true),(New-NumberVariable 'Total_Rules_Count' $false $true),(New-NumberVariable 'Critical_Rules_Count' $false $true),(New-NumberVariable 'High_Rules_Count' $false $true))
       InMap=@{}; OutMap=@{ complianceRulesText='Compliance_Rules_Text'; totalRulesCount='Total_Rules_Count'; criticalRulesCount='Critical_Rules_Count'; highRulesCount='High_Rules_Count' } },
    @{ Api='Get_Existing_Compliance_Checks_Flow'; Label='Get Existing Compliance Checks'; Inv='Get Existing Compliance Checks'
       Desc='Existing compliance checks. Compliance Verification Agent.'
       In=@((New-TextVariable 'Loan_Application_Id' $true $false))
       Out=@((New-TextVariable 'Existing_Rule_Names_Text' $false $true),(New-NumberVariable 'Existing_Count' $false $true),(New-BooleanVariable 'Has_Critical_Violations' $false $true),(New-BooleanVariable 'Has_High_Violations' $false $true),(New-BooleanVariable 'Record_Found' $false $true))
       InMap=@{ loanApplicationId='Loan_Application_Id' }
       OutMap=@{ existingRuleNamesText='Existing_Rule_Names_Text'; existingCount='Existing_Count'; hasCriticalViolations='Has_Critical_Violations'; hasHighViolations='Has_High_Violations'; recordFound='Record_Found' } },
    @{ Api='Check_Agent_Completion_Flow'; Label='Check Agent Completion'; Inv='Check Agent Completion'
       Desc='Agent run status summary. Decision Agent.'
       In=@((New-TextVariable 'Loan_Application_Id' $true $false))
       Out=@((New-TextVariable 'Document_Agent_Status' $false $true),(New-TextVariable 'Financial_Agent_Status' $false $true),(New-TextVariable 'Risk_Agent_Status' $false $true),(New-TextVariable 'Compliance_Agent_Status' $false $true),(New-TextVariable 'Decision_Agent_Status' $false $true),(New-BooleanVariable 'All_Prerequisites_Complete' $false $true),(New-NumberVariable 'Agents_Completed_Count' $false $true),(New-NumberVariable 'Agents_Failed_Count' $false $true),(New-NumberVariable 'Agents_Pending_Count' $false $true),(New-TextVariable 'Completion_Summary_Text' $false $true),(New-BooleanVariable 'Record_Found' $false $true))
       InMap=@{ loanApplicationId='Loan_Application_Id' }
       OutMap=@{ documentAgentStatus='Document_Agent_Status'; financialAgentStatus='Financial_Agent_Status'; riskAgentStatus='Risk_Agent_Status'; complianceAgentStatus='Compliance_Agent_Status'; decisionAgentStatus='Decision_Agent_Status'; allPrerequisitesComplete='All_Prerequisites_Complete'; agentsCompletedCount='Agents_Completed_Count'; agentsFailedCount='Agents_Failed_Count'; agentsPendingCount='Agents_Pending_Count'; completionSummaryText='Completion_Summary_Text'; recordFound='Record_Found' } },
    @{ Api='Get_All_Agent_Results_Flow'; Label='Get All Agent Results'; Inv='Get All Agent Results'
       Desc='All agent findings for Decision Agent.'
       In=@((New-TextVariable 'Loan_Application_Id' $true $false))
       Out=@((New-TextVariable 'All_Agent_Results_Text' $false $true),(New-NumberVariable 'Total_Risk_Score' $false $true),(New-NumberVariable 'Agents_Retrieved_Count' $false $true),(New-BooleanVariable 'Record_Found' $false $true))
       InMap=@{ loanApplicationId='Loan_Application_Id' }
       OutMap=@{ allAgentResultsText='All_Agent_Results_Text'; totalRiskScore='Total_Risk_Score'; agentsRetrievedCount='Agents_Retrieved_Count'; recordFound='Record_Found' } },
    @{ Api='Escalate_To_Underwriter_Flow'; Label='Escalate To Underwriter'; Inv='Escalate To Underwriter'; HasFault=$true
       Desc='Assign underwriter. Officer Review sub-agent.'
       In=@((New-TextVariable 'Loan_Application_Id' $true $false),(New-TextVariable 'Underwriter_Name_Or_Id' $true $false))
       Out=@((New-TextVariable 'Underwriter_Id' $false $true),(New-TextVariable 'Underwriter_Full_Name' $false $true),(New-BooleanVariable 'Success' $false $true),(New-TextVariable 'Error_Message' $false $true))
       InMap=@{ loanApplicationId='Loan_Application_Id'; underwriterNameOrId='Underwriter_Name_Or_Id' }
       OutMap=@{ underwriterId='Underwriter_Id'; underwriterFullName='Underwriter_Full_Name'; success='Success'; errorMessage='Error_Message' } },
    @{ Api='Send_Escalation_Notification_Flow'; Label='Send Escalation Notification'; Inv='Send Escalation Notification'; HasFault=$true
       Desc='Email underwriter on escalation. Officer Review sub-agent.'
       In=@((New-TextVariable 'Loan_Application_Id' $true $false),(New-TextVariable 'Underwriter_Id' $true $false),(New-TextVariable 'Escalation_Note' $true $false),(New-TextVariable 'Application_Number' $true $false),(New-TextVariable 'Applicant_Name' $true $false),(New-CurrencyVariable 'Loan_Amount' $true $false),(New-NumberVariable 'Risk_Score' $true $false),(New-TextVariable 'Final_AI_Recommendation' $true $false))
       Out=@((New-BooleanVariable 'Success' $false $true),(New-TextVariable 'Error_Message' $false $true))
       InMap=@{ loanApplicationId='Loan_Application_Id'; underwriterId='Underwriter_Id'; escalationNote='Escalation_Note'; applicationNumber='Application_Number'; applicantName='Applicant_Name'; loanAmount='Loan_Amount'; riskScore='Risk_Score'; finalAiRecommendation='Final_AI_Recommendation' }
       OutMap=@{ success='Success'; errorMessage='Error_Message' } },
    @{ Api='Update_Risk_Score_Flow'; Label='Update Risk Score'; Inv='Update Risk Score'; HasFault=$true
       Desc='Adds score impact and recalculates risk level. All agent sub-agents.'
       In=@((New-TextVariable 'Loan_Application_Id' $true $false),(New-NumberVariable 'Score_To_Add' $true $false))
       Out=@((New-NumberVariable 'New_Total_Score' $false $true),(New-TextVariable 'New_Risk_Level' $false $true),(New-BooleanVariable 'Success' $false $true),(New-TextVariable 'Error_Message' $false $true))
       InMap=@{ loanApplicationId='Loan_Application_Id'; scoreToAdd='Score_To_Add' }
       OutMap=@{ newTotalScore='New_Total_Score'; newRiskLevel='New_Risk_Level'; success='Success'; errorMessage='Error_Message' } },
    @{ Api='Get_Portfolio_Summary_Flow'; Label='Get Portfolio Summary'; Inv='Get Portfolio Summary'
       Desc='Portfolio aggregates. Portfolio and Audit Reporting sub-agent.'
       In=@((New-DateVariable 'Date_From' $true $false),(New-DateVariable 'Date_To' $true $false))
       Out=@((New-NumberVariable 'Total_Applications' $false $true),(New-TextVariable 'Portfolio_Summary_Text' $false $true))
       InMap=@{ dateFrom='Date_From'; dateTo='Date_To' }
       OutMap=@{ totalApplications='Total_Applications'; portfolioSummaryText='Portfolio_Summary_Text' } },
    @{ Api='Get_Risk_Distribution_Flow'; Label='Get Risk Distribution'; Inv='Get Risk Distribution'
       Desc='Risk level distribution. Portfolio and Audit Reporting sub-agent.'
       In=@(); Out=@((New-NumberVariable 'Total_Count' $false $true),(New-TextVariable 'Risk_Distribution_Text' $false $true))
       InMap=@{}; OutMap=@{ totalCount='Total_Count'; riskDistributionText='Risk_Distribution_Text' } },
    @{ Api='Get_Agent_Performance_Flow'; Label='Get Agent Performance'; Inv='Get Agent Performance'
       Desc='Agent performance metrics. Portfolio and Audit Reporting sub-agent.'
       In=@(); Out=@((New-TextVariable 'Performance_Summary_Text' $false $true),(New-NumberVariable 'Total_Agent_Runs' $false $true))
       InMap=@{}; OutMap=@{ performanceSummaryText='Performance_Summary_Text'; totalAgentRuns='Total_Agent_Runs' } },
    @{ Api='Get_Missing_Documents_Report_Flow'; Label='Get Missing Documents Report'; Inv='Get Missing Documents Report'
       Desc='Applications with missing docs. Portfolio and Audit Reporting sub-agent.'
       In=@(); Out=@((New-TextVariable 'Missing_Docs_Report_Text' $false $true),(New-NumberVariable 'Applications_Count' $false $true),(New-BooleanVariable 'Record_Found' $false $true))
       InMap=@{}; OutMap=@{ missingDocsReportText='Missing_Docs_Report_Text'; applicationsCount='Applications_Count'; recordFound='Record_Found' } },
    @{ Api='Get_Officer_Override_Report_Flow'; Label='Get Officer Override Report'; Inv='Get Officer Override Report'
       Desc='Officer override history. Portfolio and Audit Reporting sub-agent.'
       In=@(); Out=@((New-TextVariable 'Override_Report_Text' $false $true),(New-NumberVariable 'Override_Count' $false $true),(New-BooleanVariable 'Record_Found' $false $true))
       InMap=@{}; OutMap=@{ overrideReportText='Override_Report_Text'; overrideCount='Override_Count'; recordFound='Record_Found' } },
    @{ Api='Get_Audit_Trail_Flow'; Label='Get Audit Trail'; Inv='Get Audit Trail'
       Desc='Chronological audit trail. Portfolio and Audit Reporting sub-agent.'
       In=@((New-TextVariable 'Loan_Application_Id' $true $false),(New-BooleanVariable 'Compliance_Relevant_Only' $true $false),(New-NumberVariable 'Limit_Records' $true $false))
       Out=@((New-TextVariable 'Audit_Trail_Text' $false $true),(New-NumberVariable 'Total_Events' $false $true),(New-BooleanVariable 'Has_Critical_Events' $false $true),(New-BooleanVariable 'Record_Found' $false $true))
       InMap=@{ loanApplicationId='Loan_Application_Id'; complianceRelevantOnly='Compliance_Relevant_Only'; limitRecords='Limit_Records' }
       OutMap=@{ auditTrailText='Audit_Trail_Text'; totalEvents='Total_Events'; hasCriticalEvents='Has_Critical_Events'; recordFound='Record_Found' } },
    @{ Api='Get_Compliance_Summary_Flow'; Label='Get Compliance Summary'; Inv='Get Compliance Summary'
       Desc='Compliance check summary. Portfolio and Audit Reporting sub-agent.'
       In=@((New-TextVariable 'Loan_Application_Id' $true $false))
       Out=@((New-NumberVariable 'Total_Checks' $false $true),(New-TextVariable 'Compliance_Summary_Text' $false $true),(New-BooleanVariable 'Record_Found' $false $true))
       InMap=@{ loanApplicationId='Loan_Application_Id' }
       OutMap=@{ totalChecks='Total_Checks'; complianceSummaryText='Compliance_Summary_Text'; recordFound='Record_Found' } },
    @{ Api='Get_Daily_Volume_Flow'; Label='Get Daily Volume'; Inv='Get Daily Volume'
       Desc='Daily application volume this month. Portfolio and Audit Reporting sub-agent.'
       In=@(); Out=@((New-TextVariable 'Daily_Volume_Text' $false $true),(New-NumberVariable 'Total_This_Month' $false $true),(New-BooleanVariable 'Record_Found' $false $true))
       InMap=@{}; OutMap=@{ dailyVolumeText='Daily_Volume_Text'; totalThisMonth='Total_This_Month'; recordFound='Record_Found' } }
)

foreach ($d in $complexFlows) {
    if ($d.HasFault) {
        $created += (New-ApexWrapperFlow -ApiName $d.Api -Label $d.Label -Description $d.Desc -InvocableLabel $d.Inv `
            -InputVars $d.In -OutputVars $d.Out -ApexInputMap $d.InMap -ApexOutputMap $d.OutMap -HasFaultOutputs)
    } else {
        $created += (New-ApexWrapperFlow -ApiName $d.Api -Label $d.Label -Description $d.Desc -InvocableLabel $d.Inv `
            -InputVars $d.In -OutputVars $d.Out -ApexInputMap $d.InMap -ApexOutputMap $d.OutMap)
    }
}

Write-Host "Generated $($created.Count) flow files in $FlowsDir"
$created | ForEach-Object { Write-Host "  $_" }
