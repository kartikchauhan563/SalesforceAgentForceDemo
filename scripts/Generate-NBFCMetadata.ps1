# Generates NBFC Loan Application Salesforce metadata
$base = "c:\Users\kchauhan030\Kartik Projects\SFDC AI UsedCase\SFDCAIUSECASE\force-app\main\default"
$manifest = "c:\Users\kchauhan030\Kartik Projects\SFDC AI UsedCase\SFDCAIUSECASE\manifest\package.xml"

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

function Write-MetaFile($path, $content) {
    Ensure-Dir (Split-Path $path -Parent)
    [System.IO.File]::WriteAllText($path, $content.TrimStart(), [System.Text.UTF8Encoding]::new($false))
}

function Picklist-Field($name, $label, $values, [switch]$Required) {
    $req = if ($Required.IsPresent) { "`n    <required>true</required>" } else { "" }
    $valueXml = ($values | ForEach-Object { "        <value>`n            <fullName>$_</fullName>`n            <default>false</default>`n            <label>$_</label>`n        </value>" }) -join "`n"
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <type>Picklist</type>$req
    <valueSet>
        <restricted>true</restricted>
        <valueSetDefinition>
            <sorted>false</sorted>
$valueXml
        </valueSetDefinition>
    </valueSet>
</CustomField>
"@
}

function MultiPicklist-Field($name, $label, $values) {
    $valueXml = ($values | ForEach-Object { "        <value>`n            <fullName>$_</fullName>`n            <default>false</default>`n            <label>$_</label>`n        </value>" }) -join "`n"
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <type>MultiselectPicklist</type>
    <visibleLines>4</visibleLines>
    <valueSet>
        <restricted>true</restricted>
        <valueSetDefinition>
            <sorted>false</sorted>
$valueXml
        </valueSetDefinition>
    </valueSet>
</CustomField>
"@
}

function Text-Field($name, $label, $length, [switch]$Required, [switch]$Unique, [switch]$ExternalId) {
    $req = if ($Required.IsPresent) { "`n    <required>true</required>" } else { "" }
    $uniq = if ($Unique) { "`n    <unique>true</unique>" } else { "" }
    $ext = if ($ExternalId) { "`n    <externalId>true</externalId>" } else { "" }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <length>$length</length>
    <type>Text</type>$req$uniq$ext
</CustomField>
"@
}

function Number-Field($name, $label, $precision, $scale, [switch]$Required) {
    $req = if ($Required.IsPresent) { "`n    <required>true</required>" } else { "" }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <precision>$precision</precision>
    <scale>$scale</scale>
    <type>Number</type>$req
</CustomField>
"@
}

function Currency-Field($name, $label, [switch]$Required) {
    $req = if ($Required.IsPresent) { "`n    <required>true</required>" } else { "" }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <precision>16</precision>
    <scale>2</scale>
    <type>Currency</type>$req
</CustomField>
"@
}

function Percent-Field($name, $label, [switch]$Required) {
    $req = if ($Required.IsPresent) { "`n    <required>true</required>" } else { "" }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <precision>5</precision>
    <scale>2</scale>
    <type>Percent</type>$req
</CustomField>
"@
}

function Checkbox-Field($name, $label, [switch]$DefaultTrue) {
    $def = if ($DefaultTrue) { "`n    <defaultValue>true</defaultValue>" } else { "`n    <defaultValue>false</defaultValue>" }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <type>Checkbox</type>$def
</CustomField>
"@
}

function Date-Field($name, $label, [switch]$Required) {
    $req = if ($Required.IsPresent) { "`n    <required>true</required>" } else { "" }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <type>Date</type>$req
</CustomField>
"@
}

function DateTime-Field($name, $label, [switch]$Required) {
    $req = if ($Required.IsPresent) { "`n    <required>true</required>" } else { "" }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <type>DateTime</type>$req
</CustomField>
"@
}

function LongText-Field($name, $label, $length) {
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <length>$length</length>
    <type>LongTextArea</type>
    <visibleLines>5</visibleLines>
</CustomField>
"@
}

function Lookup-Field($name, $label, $refTo, $relLabel, $relName, [switch]$Required) {
    $req = if ($Required.IsPresent) { "`n    <required>true</required>" } else { "" }
    $deleteConstraint = if ($Required.IsPresent) { "Restrict" } else { "SetNull" }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <referenceTo>$refTo</referenceTo>
    <relationshipLabel>$relLabel</relationshipLabel>
    <relationshipName>$relName</relationshipName>
    <deleteConstraint>$deleteConstraint</deleteConstraint>
    <type>Lookup</type>$req
</CustomField>
"@
}

function MasterDetail-Field($name, $label, $refTo, $relLabel, $relName, $order) {
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <referenceTo>$refTo</referenceTo>
    <relationshipLabel>$relLabel</relationshipLabel>
    <relationshipName>$relName</relationshipName>
    <relationshipOrder>$order</relationshipOrder>
    <reparentableMasterDetail>false</reparentableMasterDetail>
    <type>MasterDetail</type>
    <writeRequiresMasterRead>false</writeRequiresMasterRead>
</CustomField>
"@
}

function Formula-Field($name, $label, $returnType, $formula, $precision, $scale) {
    $precScale = if ($returnType -in @("Number","Currency","Percent")) {
        "`n    <precision>$precision</precision>`n    <scale>$scale</scale>"
    } else { "" }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <formula>$formula</formula>
    <formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs>$precScale
    <type>$returnType</type>
</CustomField>
"@
}

function Rollup-Field($name, $label, $foreignKey, $operation, $summarizedField, $filters) {
    $filterXml = ""
    if ($filters) {
        $filterXml = ($filters | ForEach-Object {
            "    <summaryFilterItems>`n        <field>$($_.Field)</field>`n        <operation>$($_.Operation)</operation>`n        <value>$($_.Value)</value>`n    </summaryFilterItems>"
        }) -join "`n"
    }
    $summField = if ($summarizedField) { "`n    <summarizedField>$summarizedField</summarizedField>" } else { "" }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$name</fullName>
    <label>$label</label>
    <summaryForeignKey>$foreignKey</summaryForeignKey>
    <summaryOperation>$operation</summaryOperation>$summField
$filterXml
    <type>Summary</type>
</CustomField>
"@
}

function CustomObject-Meta($apiName, $label, $plural, $nameFieldType, $nameFieldLabel, $displayFormat, $sharingModel, $enableActivities, $enableHistory, $enableReports, $enableSearch, $comment) {
    $nameField = if ($nameFieldType -eq "AutoNumber") {
        @"
    <nameField>
        <displayFormat>$displayFormat</displayFormat>
        <label>$nameFieldLabel</label>
        <type>AutoNumber</type>
    </nameField>
"@
    } else {
        @"
    <nameField>
        <label>$nameFieldLabel</label>
        <type>Text</type>
    </nameField>
"@
    }
    $activities = if ($enableActivities) { "true" } else { "false" }
    $history = if ($enableHistory) { "true" } else { "false" }
    $reports = if ($enableReports) { "true" } else { "false" }
    $search = if ($enableSearch) { "true" } else { "false" }
    $commentBlock = if ($comment) { "`n    <!-- $comment -->" } else { "" }
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">$commentBlock
    <deploymentStatus>Deployed</deploymentStatus>
    <enableActivities>$activities</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableHistory>$history</enableHistory>
    <enableReports>$reports</enableReports>
    <enableSearch>$search</enableSearch>
    <label>$label</label>
$nameField
    <pluralLabel>$plural</pluralLabel>
    <sharingModel>$sharingModel</sharingModel>
</CustomObject>
"@
}

function CustomMetadataObject($apiName, $label, $plural) {
    @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>$label</label>
    <pluralLabel>$plural</pluralLabel>
    <visibility>Public</visibility>
</CustomObject>
"@
}

# ==================== LOAN PRODUCT ====================
$lp = "$base\objects\Loan_Product__c"
Write-MetaFile "$lp\Loan_Product__c.object-meta.xml" (CustomObject-Meta "Loan_Product__c" "Loan Product" "Loan Products" "Text" "Product Name" "" "ReadWrite" $false $false $true $true "")
Write-MetaFile "$lp\fields\Product_Code__c.field-meta.xml" (Text-Field "Product_Code__c" "Product Code" 20 -Required -Unique -ExternalId)
Write-MetaFile "$lp\fields\Product_Type__c.field-meta.xml" (Picklist-Field "Product_Type__c" "Product Type" @("Personal","Business","Vehicle","Home","Gold","Education") -Required)
Write-MetaFile "$lp\fields\Description__c.field-meta.xml" (LongText-Field "Description__c" "Description" 2000)
Write-MetaFile "$lp\fields\Min_Loan_Amount__c.field-meta.xml" (Currency-Field "Min_Loan_Amount__c" "Min Loan Amount")
Write-MetaFile "$lp\fields\Max_Loan_Amount__c.field-meta.xml" (Currency-Field "Max_Loan_Amount__c" "Max Loan Amount")
Write-MetaFile "$lp\fields\Min_Tenure__c.field-meta.xml" (Number-Field "Min_Tenure__c" "Min Tenure" 3 0)
Write-MetaFile "$lp\fields\Max_Tenure__c.field-meta.xml" (Number-Field "Max_Tenure__c" "Max Tenure" 3 0)
Write-MetaFile "$lp\fields\Min_Interest_Rate__c.field-meta.xml" (Percent-Field "Min_Interest_Rate__c" "Min Interest Rate")
Write-MetaFile "$lp\fields\Max_Interest_Rate__c.field-meta.xml" (Percent-Field "Max_Interest_Rate__c" "Max Interest Rate")
Write-MetaFile "$lp\fields\Min_Credit_Score__c.field-meta.xml" (Number-Field "Min_Credit_Score__c" "Min Credit Score" 4 0)
Write-MetaFile "$lp\fields\Min_Income_Required__c.field-meta.xml" (Currency-Field "Min_Income_Required__c" "Min Income Required")
Write-MetaFile "$lp\fields\Min_Age__c.field-meta.xml" (Number-Field "Min_Age__c" "Min Age" 3 0)
Write-MetaFile "$lp\fields\Max_Age__c.field-meta.xml" (Number-Field "Max_Age__c" "Max Age" 3 0)
Write-MetaFile "$lp\fields\Max_FOIR__c.field-meta.xml" (Percent-Field "Max_FOIR__c" "Max FOIR")
Write-MetaFile "$lp\fields\Processing_Fee_Pct__c.field-meta.xml" (Percent-Field "Processing_Fee_Pct__c" "Processing Fee Pct")
Write-MetaFile "$lp\fields\Prepayment_Charges__c.field-meta.xml" (Percent-Field "Prepayment_Charges__c" "Prepayment Charges")
Write-MetaFile "$lp\fields\Required_Documents__c.field-meta.xml" (LongText-Field "Required_Documents__c" "Required Documents" 5000)
Write-MetaFile "$lp\fields\Target_Segment__c.field-meta.xml" (MultiPicklist-Field "Target_Segment__c" "Target Segment" @("Salaried","Self-Employed","Business","Student"))
Write-MetaFile "$lp\fields\Is_Active__c.field-meta.xml" (Checkbox-Field "Is_Active__c" "Is Active" -DefaultTrue)
Write-MetaFile "$lp\fields\Launch_Date__c.field-meta.xml" (Date-Field "Launch_Date__c" "Launch Date")
Write-MetaFile "$lp\fields\Sunset_Date__c.field-meta.xml" (Date-Field "Sunset_Date__c" "Sunset Date")

# ==================== LOAN APPLICATION ====================
$la = "$base\objects\Loan_Application__c"
Write-MetaFile "$la\Loan_Application__c.object-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- Core loan application object. History tracking enabled on Status__c and Final_Recommendation__c fields. -->
    <!-- Roll-up summaries on Loan_Application_History__c cannot use native Summary fields because History uses Lookup (not Master-Detail) per RBI 7-year retention requirement. Use DLRS or Apex for: Total_History_Events__c, Agent_Events_Count__c, Compliance_Violations_Count__c, Officer_Overrides_Count__c. -->
    <deploymentStatus>Deployed</deploymentStatus>
    <enableActivities>true</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableHistory>true</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <label>Loan Application</label>
    <nameField>
        <displayFormat>LA-{0000000}</displayFormat>
        <label>Application Number</label>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>Loan Applications</pluralLabel>
    <sharingModel>ReadWrite</sharingModel>
</CustomObject>
"@

Write-MetaFile "$la\fields\Applicant__c.field-meta.xml" (Lookup-Field "Applicant__c" "Applicant" "Account" "Loan Applications" "Loan_Applications" -Required)
Write-MetaFile "$la\fields\Loan_Product__c.field-meta.xml" (Lookup-Field "Loan_Product__c" "Loan Product" "Loan_Product__c" "Loan Applications" "Loan_Applications" -Required)
Write-MetaFile "$la\fields\Loan_Amount__c.field-meta.xml" (Currency-Field "Loan_Amount__c" "Loan Amount" -Required)
Write-MetaFile "$la\fields\Loan_Amount_Approved__c.field-meta.xml" (Currency-Field "Loan_Amount_Approved__c" "Loan Amount Approved")
Write-MetaFile "$la\fields\Tenure_Months__c.field-meta.xml" (Number-Field "Tenure_Months__c" "Tenure Months" 3 0 -Required)
Write-MetaFile "$la\fields\Interest_Rate__c.field-meta.xml" (Percent-Field "Interest_Rate__c" "Interest Rate")
Write-MetaFile "$la\fields\Loan_Purpose__c.field-meta.xml" (Picklist-Field "Loan_Purpose__c" "Loan Purpose" @("Personal Use","Wedding","Medical Emergency","Home Renovation","Education","Travel","Debt Consolidation","Vehicle Purchase","Business Expansion","Working Capital","Equipment Purchase"))
Write-MetaFile "$la\fields\Application_Channel__c.field-meta.xml" (Picklist-Field "Application_Channel__c" "Application Channel" @("Web","Mobile","Branch","DSA","Partner"))
Write-MetaFile "$la\fields\Application_Date__c.field-meta.xml" (Date-Field "Application_Date__c" "Application Date")
Write-MetaFile "$la\fields\Status__c.field-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Status__c</fullName>
    <label>Status</label>
    <trackHistory>true</trackHistory>
    <type>Picklist</type>
    <valueSet>
        <restricted>true</restricted>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value><fullName>Draft</fullName><default>true</default><label>Draft</label></value>
            <value><fullName>Submitted</fullName><default>false</default><label>Submitted</label></value>
            <value><fullName>Under Review</fullName><default>false</default><label>Under Review</label></value>
            <value><fullName>Documents Pending</fullName><default>false</default><label>Documents Pending</label></value>
            <value><fullName>KYC In Progress</fullName><default>false</default><label>KYC In Progress</label></value>
            <value><fullName>Underwriting</fullName><default>false</default><label>Underwriting</label></value>
            <value><fullName>On Hold</fullName><default>false</default><label>On Hold</label></value>
            <value><fullName>Approved</fullName><default>false</default><label>Approved</label></value>
            <value><fullName>Rejected</fullName><default>false</default><label>Rejected</label></value>
            <value><fullName>Disbursed</fullName><default>false</default><label>Disbursed</label></value>
            <value><fullName>Closed</fullName><default>false</default><label>Closed</label></value>
            <value><fullName>Withdrawn</fullName><default>false</default><label>Withdrawn</label></value>
        </valueSetDefinition>
    </valueSet>
</CustomField>
"@
Write-MetaFile "$la\fields\Sub_Status__c.field-meta.xml" (Picklist-Field "Sub_Status__c" "Sub Status" @("KYC Pending","Docs Pending","Under Underwriting","Approval Pending"))
Write-MetaFile "$la\fields\Loan_Officer__c.field-meta.xml" (Lookup-Field "Loan_Officer__c" "Loan Officer" "User" "Loan Applications (Officer)" "Loan_Applications_Officer")
Write-MetaFile "$la\fields\Underwriter__c.field-meta.xml" (Lookup-Field "Underwriter__c" "Underwriter" "User" "Loan Applications (Underwriter)" "Loan_Applications_Underwriter")
Write-MetaFile "$la\fields\Branch__c.field-meta.xml" (Text-Field "Branch__c" "Branch" 50)
Write-MetaFile "$la\fields\Priority__c.field-meta.xml" (Picklist-Field "Priority__c" "Priority" @("Low","Medium","High","Urgent"))
Write-MetaFile "$la\fields\Monthly_Income__c.field-meta.xml" (Currency-Field "Monthly_Income__c" "Monthly Income" -Required)
Write-MetaFile "$la\fields\Existing_EMI__c.field-meta.xml" (Currency-Field "Existing_EMI__c" "Existing EMI" -Required)
Write-MetaFile "$la\fields\EMI_Burden__c.field-meta.xml" (Formula-Field "EMI_Burden__c" "EMI Burden" "Percent" "IF(Monthly_Income__c &gt; 0, Existing_EMI__c / Monthly_Income__c, 0)" 5 2)
Write-MetaFile "$la\fields\Calculated_EMI__c.field-meta.xml" (Formula-Field "Calculated_EMI__c" "Calculated EMI" "Currency" "IF(AND(Tenure_Months__c &gt; 0, Loan_Amount__c &gt; 0), IF(Interest_Rate__c &gt; 0, Loan_Amount__c * (Interest_Rate__c / 1200) * (1 + Interest_Rate__c / 1200) ^ Tenure_Months__c / ((1 + Interest_Rate__c / 1200) ^ Tenure_Months__c - 1), Loan_Amount__c / Tenure_Months__c), 0)" 16 2)
Write-MetaFile "$la\fields\FOIR_After_Loan__c.field-meta.xml" (Formula-Field "FOIR_After_Loan__c" "FOIR After Loan" "Percent" "IF(Monthly_Income__c &gt; 0, (Existing_EMI__c + Calculated_EMI__c) / Monthly_Income__c, 0)" 5 2)
Write-MetaFile "$la\fields\LTI__c.field-meta.xml" (Formula-Field "LTI__c" "LTI" "Number" "IF(Monthly_Income__c &gt; 0, Loan_Amount__c / (Monthly_Income__c * 12), 0)" 16 2)
Write-MetaFile "$la\fields\Credit_Score__c.field-meta.xml" (Number-Field "Credit_Score__c" "Credit Score" 4 0 -Required)
Write-MetaFile "$la\fields\Risk_Score__c.field-meta.xml" (Number-Field "Risk_Score__c" "Risk Score" 3 0)
Write-MetaFile "$la\fields\Risk_Level__c.field-meta.xml" (Picklist-Field "Risk_Level__c" "Risk Level" @("Very Low","Low","Medium","High","Very High"))
Write-MetaFile "$la\fields\Final_Recommendation__c.field-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Final_Recommendation__c</fullName>
    <label>Final Recommendation</label>
    <trackHistory>true</trackHistory>
    <type>Picklist</type>
    <valueSet>
        <restricted>true</restricted>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value><fullName>Approve</fullName><default>false</default><label>Approve</label></value>
            <value><fullName>Hold</fullName><default>false</default><label>Hold</label></value>
            <value><fullName>Reject</fullName><default>false</default><label>Reject</label></value>
        </valueSetDefinition>
    </valueSet>
</CustomField>
"@
Write-MetaFile "$la\fields\Decision_Reasons__c.field-meta.xml" (LongText-Field "Decision_Reasons__c" "Decision Reasons" 32768)
Write-MetaFile "$la\fields\Missing_Documents__c.field-meta.xml" (LongText-Field "Missing_Documents__c" "Missing Documents" 5000)
Write-MetaFile "$la\fields\Next_Best_Action__c.field-meta.xml" (LongText-Field "Next_Best_Action__c" "Next Best Action" 2000)
Write-MetaFile "$la\fields\AI_Confidence__c.field-meta.xml" (Percent-Field "AI_Confidence__c" "AI Confidence")
Write-MetaFile "$la\fields\All_Agents_Completed__c.field-meta.xml" (Checkbox-Field "All_Agents_Completed__c" "All Agents Completed")

# Validation Rules
Write-MetaFile "$la\validationRules\Loan_Amount_Range.validationRule-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Loan_Amount_Range</fullName>
    <active>true</active>
    <description>Loan amount must be between 10,000 and 5,000,000</description>
    <errorConditionFormula>OR(Loan_Amount__c &lt; 10000, Loan_Amount__c &gt; 5000000)</errorConditionFormula>
    <errorDisplayField>Loan_Amount__c</errorDisplayField>
    <errorMessage>Loan amount must be between 10,000 and 5,000,000.</errorMessage>
</ValidationRule>
"@
Write-MetaFile "$la\validationRules\Tenure_Range.validationRule-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Tenure_Range</fullName>
    <active>true</active>
    <description>Tenure must be between 3 and 84 months</description>
    <errorConditionFormula>OR(Tenure_Months__c &lt; 3, Tenure_Months__c &gt; 84)</errorConditionFormula>
    <errorDisplayField>Tenure_Months__c</errorDisplayField>
    <errorMessage>Tenure must be between 3 and 84 months.</errorMessage>
</ValidationRule>
"@
Write-MetaFile "$la\validationRules\Monthly_Income_Required.validationRule-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Monthly_Income_Required</fullName>
    <active>true</active>
    <description>Monthly income cannot be blank or zero</description>
    <errorConditionFormula>OR(ISBLANK(Monthly_Income__c), Monthly_Income__c &lt;= 0)</errorConditionFormula>
    <errorDisplayField>Monthly_Income__c</errorDisplayField>
    <errorMessage>Monthly income is required and must be greater than zero.</errorMessage>
</ValidationRule>
"@

# ==================== APPLICANT DOCUMENT ====================
$ad = "$base\objects\Applicant_Document__c"
Write-MetaFile "$ad\Applicant_Document__c.object-meta.xml" (CustomObject-Meta "Applicant_Document__c" "Applicant Document" "Applicant Documents" "AutoNumber" "Document Number" "DOC-{00000}" "ControlledByParent" $false $false $true $true "Master-Detail to Loan_Application__c ensures document records cascade with the application lifecycle.")
Write-MetaFile "$ad\fields\Loan_Application__c.field-meta.xml" (MasterDetail-Field "Loan_Application__c" "Loan Application" "Loan_Application__c" "Applicant Documents" "Applicant_Documents" 0)
Write-MetaFile "$ad\fields\Document_Type__c.field-meta.xml" (Picklist-Field "Document_Type__c" "Document Type" @("PAN Card","Aadhaar Card","Passport","Driving License","Voter ID","Bank Statement 3 months","Bank Statement 6 months","Salary Slip","Form 16","ITR Acknowledgment","GST Returns","Business Registration","Address Proof","Photograph","Property Documents","Vehicle Documents") -Required)
Write-MetaFile "$ad\fields\Document_Category__c.field-meta.xml" (Picklist-Field "Document_Category__c" "Document Category" @("KYC","Income","Address","Collateral"))
Write-MetaFile "$ad\fields\Is_Mandatory__c.field-meta.xml" (Checkbox-Field "Is_Mandatory__c" "Is Mandatory")
Write-MetaFile "$ad\fields\Uploaded__c.field-meta.xml" (Checkbox-Field "Uploaded__c" "Uploaded")
Write-MetaFile "$ad\fields\Upload_Date__c.field-meta.xml" (DateTime-Field "Upload_Date__c" "Upload Date")
Write-MetaFile "$ad\fields\Verified__c.field-meta.xml" (Checkbox-Field "Verified__c" "Verified")
Write-MetaFile "$ad\fields\Verification_Status__c.field-meta.xml" (Picklist-Field "Verification_Status__c" "Verification Status" @("Pending","Verified","Failed","Manual Review"))
Write-MetaFile "$ad\fields\Issue_Found__c.field-meta.xml" (Picklist-Field "Issue_Found__c" "Issue Found" @("None","Missing","Name Mismatch","Expired","Blurred","Suspicious","Forged"))
Write-MetaFile "$ad\fields\OCR_Confidence__c.field-meta.xml" (Percent-Field "OCR_Confidence__c" "OCR Confidence")
Write-MetaFile "$ad\fields\Document_Number__c.field-meta.xml" (Text-Field "Document_Number__c" "Document Number" 50)
Write-MetaFile "$ad\fields\Expiry_Date__c.field-meta.xml" (Date-Field "Expiry_Date__c" "Expiry Date")
Write-MetaFile "$ad\fields\Agent_Comment__c.field-meta.xml" (LongText-Field "Agent_Comment__c" "Agent Comment" 2000)

# ==================== AGENT CHECK RESULT ====================
$acr = "$base\objects\Agent_Check_Result__c"
Write-MetaFile "$acr\Agent_Check_Result__c.object-meta.xml" (CustomObject-Meta "Agent_Check_Result__c" "Agent Check Result" "Agent Check Results" "AutoNumber" "Check Result Number" "ACR-{00000}" "ControlledByParent" $false $false $true $true "Master-Detail to Loan_Application__c for roll-up of agent scores and failed agent counts.")
Write-MetaFile "$acr\fields\Loan_Application__c.field-meta.xml" (MasterDetail-Field "Loan_Application__c" "Loan Application" "Loan_Application__c" "Agent Check Results" "Agent_Check_Results" 0)
Write-MetaFile "$acr\fields\Agent_Name__c.field-meta.xml" (Picklist-Field "Agent_Name__c" "Agent Name" @("Document Verification Agent","Financial Health Agent","Credit Risk Agent","Compliance Agent","Decision Agent") -Required)
Write-MetaFile "$acr\fields\Agent_Run_Order__c.field-meta.xml" (Number-Field "Agent_Run_Order__c" "Agent Run Order" 2 0)
Write-MetaFile "$acr\fields\Status__c.field-meta.xml" (Picklist-Field "Status__c" "Status" @("Pending","Running","Completed","Failed"))
Write-MetaFile "$acr\fields\Result__c.field-meta.xml" (Picklist-Field "Result__c" "Result" @("Pass","Warning","Fail"))
Write-MetaFile "$acr\fields\Score_Impact__c.field-meta.xml" (Number-Field "Score_Impact__c" "Score Impact" 3 0)
Write-MetaFile "$acr\fields\Confidence__c.field-meta.xml" (Percent-Field "Confidence__c" "Confidence")
Write-MetaFile "$acr\fields\Reason__c.field-meta.xml" (LongText-Field "Reason__c" "Reason" 5000)
Write-MetaFile "$acr\fields\Recommendations__c.field-meta.xml" (LongText-Field "Recommendations__c" "Recommendations" 2000)
Write-MetaFile "$acr\fields\Run_Started_At__c.field-meta.xml" (DateTime-Field "Run_Started_At__c" "Run Started At")
Write-MetaFile "$acr\fields\Run_Completed_At__c.field-meta.xml" (DateTime-Field "Run_Completed_At__c" "Run Completed At")
Write-MetaFile "$acr\fields\Execution_Time_Ms__c.field-meta.xml" (Number-Field "Execution_Time_Ms__c" "Execution Time Ms" 7 0)
Write-MetaFile "$acr\fields\Agent_Version__c.field-meta.xml" (Text-Field "Agent_Version__c" "Agent Version" 20)
Write-MetaFile "$acr\fields\Raw_Output_JSON__c.field-meta.xml" (LongText-Field "Raw_Output_JSON__c" "Raw Output JSON" 32768)

# ==================== RISK ASSESSMENT ====================
$ra = "$base\objects\Risk_Assessment__c"
Write-MetaFile "$ra\Risk_Assessment__c.object-meta.xml" (CustomObject-Meta "Risk_Assessment__c" "Risk Assessment" "Risk Assessments" "AutoNumber" "Risk Assessment Number" "RSK-{00000}" "ControlledByParent" $false $false $true $true "")
Write-MetaFile "$ra\fields\Loan_Application__c.field-meta.xml" (MasterDetail-Field "Loan_Application__c" "Loan Application" "Loan_Application__c" "Risk Assessments" "Risk_Assessments" 0)
Write-MetaFile "$ra\fields\Bureau_Score__c.field-meta.xml" (Number-Field "Bureau_Score__c" "Bureau Score" 4 0)
Write-MetaFile "$ra\fields\Bureau_Source__c.field-meta.xml" (Picklist-Field "Bureau_Source__c" "Bureau Source" @("CIBIL","Experian","Equifax","CRIF"))
Write-MetaFile "$ra\fields\Past_Defaults__c.field-meta.xml" (Number-Field "Past_Defaults__c" "Past Defaults" 2 0)
Write-MetaFile "$ra\fields\Past_Bounces_12M__c.field-meta.xml" (Number-Field "Past_Bounces_12M__c" "Past Bounces 12M" 2 0)
Write-MetaFile "$ra\fields\Active_Loans__c.field-meta.xml" (Number-Field "Active_Loans__c" "Active Loans" 2 0)
Write-MetaFile "$ra\fields\Credit_Inquiries_6M__c.field-meta.xml" (Number-Field "Credit_Inquiries_6M__c" "Credit Inquiries 6M" 2 0)
Write-MetaFile "$ra\fields\Fraud_Score__c.field-meta.xml" (Number-Field "Fraud_Score__c" "Fraud Score" 3 0)
Write-MetaFile "$ra\fields\Identity_Verified__c.field-meta.xml" (Checkbox-Field "Identity_Verified__c" "Identity Verified")
Write-MetaFile "$ra\fields\Address_Risk__c.field-meta.xml" (Picklist-Field "Address_Risk__c" "Address Risk" @("Low","Medium","High"))
Write-MetaFile "$ra\fields\Sector_Risk__c.field-meta.xml" (Picklist-Field "Sector_Risk__c" "Sector Risk" @("Low","Medium","High","Very High"))
Write-MetaFile "$ra\fields\Final_Risk_Score__c.field-meta.xml" (Number-Field "Final_Risk_Score__c" "Final Risk Score" 3 0)
Write-MetaFile "$ra\fields\Risk_Category__c.field-meta.xml" (Picklist-Field "Risk_Category__c" "Risk Category" @("Low","Medium","High","Very High"))
Write-MetaFile "$ra\fields\Risk_Reasons__c.field-meta.xml" (LongText-Field "Risk_Reasons__c" "Risk Reasons" 5000)

# ==================== COMPLIANCE CHECK ====================
$cc = "$base\objects\Compliance_Check__c"
Write-MetaFile "$cc\Compliance_Check__c.object-meta.xml" (CustomObject-Meta "Compliance_Check__c" "Compliance Check" "Compliance Checks" "AutoNumber" "Compliance Check Number" "CMP-{00000}" "ControlledByParent" $false $false $true $true "")
Write-MetaFile "$cc\fields\Loan_Application__c.field-meta.xml" (MasterDetail-Field "Loan_Application__c" "Loan Application" "Loan_Application__c" "Compliance Checks" "Compliance_Checks" 0)
Write-MetaFile "$cc\fields\Rule_Name__c.field-meta.xml" (Text-Field "Rule_Name__c" "Rule Name" 100)
Write-MetaFile "$cc\fields\Rule_Category__c.field-meta.xml" (Picklist-Field "Rule_Category__c" "Rule Category" @("KYC","RBI Digital Lending","AML","Internal Policy"))
Write-MetaFile "$cc\fields\Status__c.field-meta.xml" (Picklist-Field "Status__c" "Status" @("Compliant","Non-Compliant","Warning","N/A"))
Write-MetaFile "$cc\fields\Severity__c.field-meta.xml" (Picklist-Field "Severity__c" "Severity" @("Low","Medium","High","Critical"))
Write-MetaFile "$cc\fields\Description__c.field-meta.xml" (LongText-Field "Description__c" "Description" 5000)
Write-MetaFile "$cc\fields\Action_Required__c.field-meta.xml" (LongText-Field "Action_Required__c" "Action Required" 2000)
Write-MetaFile "$cc\fields\Checked_At__c.field-meta.xml" (DateTime-Field "Checked_At__c" "Checked At")
Write-MetaFile "$cc\fields\Resolved__c.field-meta.xml" (Checkbox-Field "Resolved__c" "Resolved")
Write-MetaFile "$cc\fields\Resolved_By__c.field-meta.xml" (Lookup-Field "Resolved_By__c" "Resolved By" "User" "Compliance Checks Resolved" "Compliance_Checks_Resolved")
Write-MetaFile "$cc\fields\Resolved_At__c.field-meta.xml" (DateTime-Field "Resolved_At__c" "Resolved At")
Write-MetaFile "$cc\fields\Regulation_Reference__c.field-meta.xml" (Text-Field "Regulation_Reference__c" "Regulation Reference" 100)

# ==================== LOAN DECISION ====================
$ld = "$base\objects\Loan_Decision__c"
Write-MetaFile "$ld\Loan_Decision__c.object-meta.xml" (CustomObject-Meta "Loan_Decision__c" "Loan Decision" "Loan Decisions" "AutoNumber" "Decision Number" "DEC-{00000}" "ControlledByParent" $false $false $true $true "")
Write-MetaFile "$ld\fields\Loan_Application__c.field-meta.xml" (MasterDetail-Field "Loan_Application__c" "Loan Application" "Loan_Application__c" "Loan Decisions" "Loan_Decisions" 0)
Write-MetaFile "$ld\fields\Recommendation__c.field-meta.xml" (Picklist-Field "Recommendation__c" "Recommendation" @("Approve","Hold","Reject"))
Write-MetaFile "$ld\fields\Confidence_Score__c.field-meta.xml" (Percent-Field "Confidence_Score__c" "Confidence Score")
Write-MetaFile "$ld\fields\Approved_Amount__c.field-meta.xml" (Currency-Field "Approved_Amount__c" "Approved Amount")
Write-MetaFile "$ld\fields\Approved_Tenure__c.field-meta.xml" (Number-Field "Approved_Tenure__c" "Approved Tenure" 3 0)
Write-MetaFile "$ld\fields\Suggested_Interest_Rate__c.field-meta.xml" (Percent-Field "Suggested_Interest_Rate__c" "Suggested Interest Rate")
Write-MetaFile "$ld\fields\Decision_Summary__c.field-meta.xml" (LongText-Field "Decision_Summary__c" "Decision Summary" 32768)
Write-MetaFile "$ld\fields\Key_Reasons__c.field-meta.xml" (LongText-Field "Key_Reasons__c" "Key Reasons" 5000)
Write-MetaFile "$ld\fields\Missing_Paperwork__c.field-meta.xml" (LongText-Field "Missing_Paperwork__c" "Missing Paperwork" 5000)
Write-MetaFile "$ld\fields\Next_Best_Action__c.field-meta.xml" (LongText-Field "Next_Best_Action__c" "Next Best Action" 2000)
Write-MetaFile "$ld\fields\Conditions__c.field-meta.xml" (LongText-Field "Conditions__c" "Conditions" 5000)
Write-MetaFile "$ld\fields\Generated_By__c.field-meta.xml" (Picklist-Field "Generated_By__c" "Generated By" @("AI Agent","Manual","Hybrid"))
Write-MetaFile "$ld\fields\AI_Model__c.field-meta.xml" (Text-Field "AI_Model__c" "AI Model" 50)
Write-MetaFile "$ld\fields\Officer_Reviewed__c.field-meta.xml" (Checkbox-Field "Officer_Reviewed__c" "Officer Reviewed")
Write-MetaFile "$ld\fields\Officer_Decision__c.field-meta.xml" (Picklist-Field "Officer_Decision__c" "Officer Decision" @("Accept AI","Override Approve","Override Reject"))
Write-MetaFile "$ld\fields\Officer_Comments__c.field-meta.xml" (LongText-Field "Officer_Comments__c" "Officer Comments" 5000)
Write-MetaFile "$ld\fields\Generated_At__c.field-meta.xml" (DateTime-Field "Generated_At__c" "Generated At")
Write-MetaFile "$ld\fields\Officer_Reviewed_At__c.field-meta.xml" (DateTime-Field "Officer_Reviewed_At__c" "Officer Reviewed At")

# ==================== REPAYMENT SCHEDULE ====================
$rs = "$base\objects\Repayment_Schedule__c"
Write-MetaFile "$rs\Repayment_Schedule__c.object-meta.xml" (CustomObject-Meta "Repayment_Schedule__c" "Repayment Schedule" "Repayment Schedules" "AutoNumber" "EMI Number" "EMI-{00000}" "ControlledByParent" $false $false $true $true "")
Write-MetaFile "$rs\fields\Loan_Application__c.field-meta.xml" (MasterDetail-Field "Loan_Application__c" "Loan Application" "Loan_Application__c" "Repayment Schedules" "Repayment_Schedules" 0)
Write-MetaFile "$rs\fields\EMI_Number__c.field-meta.xml" (Number-Field "EMI_Number__c" "EMI Number" 3 0)
Write-MetaFile "$rs\fields\Due_Date__c.field-meta.xml" (Date-Field "Due_Date__c" "Due Date")
Write-MetaFile "$rs\fields\EMI_Amount__c.field-meta.xml" (Currency-Field "EMI_Amount__c" "EMI Amount")
Write-MetaFile "$rs\fields\Principal_Component__c.field-meta.xml" (Currency-Field "Principal_Component__c" "Principal Component")
Write-MetaFile "$rs\fields\Interest_Component__c.field-meta.xml" (Currency-Field "Interest_Component__c" "Interest Component")
Write-MetaFile "$rs\fields\Outstanding_Balance__c.field-meta.xml" (Currency-Field "Outstanding_Balance__c" "Outstanding Balance")
Write-MetaFile "$rs\fields\Status__c.field-meta.xml" (Picklist-Field "Status__c" "Status" @("Pending","Paid","Overdue","Bounced","Waived"))
Write-MetaFile "$rs\fields\Paid_Date__c.field-meta.xml" (Date-Field "Paid_Date__c" "Paid Date")
Write-MetaFile "$rs\fields\Paid_Amount__c.field-meta.xml" (Currency-Field "Paid_Amount__c" "Paid Amount")
Write-MetaFile "$rs\fields\Days_Overdue__c.field-meta.xml" (Formula-Field "Days_Overdue__c" "Days Overdue" "Number" "IF(AND(ISPICKVAL(Status__c, &quot;Pending&quot;), Due_Date__c &lt; TODAY()), TODAY() - Due_Date__c, 0)" 18 0)
Write-MetaFile "$rs\fields\Late_Fee__c.field-meta.xml" (Currency-Field "Late_Fee__c" "Late Fee")
Write-MetaFile "$rs\fields\Payment_Mode__c.field-meta.xml" (Picklist-Field "Payment_Mode__c" "Payment Mode" @("NACH","UPI","NEFT","Cheque","Cash"))
Write-MetaFile "$rs\fields\Transaction_Reference__c.field-meta.xml" (Text-Field "Transaction_Reference__c" "Transaction Reference" 50)
Write-MetaFile "$rs\fields\Bounce_Reason__c.field-meta.xml" (Picklist-Field "Bounce_Reason__c" "Bounce Reason" @("Insufficient Funds","Account Closed","Signature Mismatch","Other"))

# ==================== AUDIT LOG (Lookup) ====================
$al = "$base\objects\Audit_Log__c"
Write-MetaFile "$al\Audit_Log__c.object-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- Lookup (not Master-Detail) to Loan_Application__c: audit records must survive parent deletion for regulatory traceability and forensic analysis. -->
    <deploymentStatus>Deployed</deploymentStatus>
    <enableActivities>false</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableHistory>false</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <label>Audit Log</label>
    <nameField>
        <displayFormat>LOG-{0000000}</displayFormat>
        <label>Log Number</label>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>Audit Logs</pluralLabel>
    <sharingModel>ReadWrite</sharingModel>
</CustomObject>
"@
Write-MetaFile "$al\fields\Loan_Application__c.field-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Loan_Application__c</fullName>
    <label>Loan Application</label>
    <referenceTo>Loan_Application__c</referenceTo>
    <relationshipLabel>Audit Logs</relationshipLabel>
    <relationshipName>Audit_Logs</relationshipName>
    <deleteConstraint>SetNull</deleteConstraint>
    <type>Lookup</type>
</CustomField>
"@
Write-MetaFile "$al\fields\Event_Type__c.field-meta.xml" (Picklist-Field "Event_Type__c" "Event Type" @("Application Created","Doc Uploaded","Agent Run","Decision Made","Status Changed","Officer Action","Disbursement","Integration Call"))
Write-MetaFile "$al\fields\Event_Source__c.field-meta.xml" (Picklist-Field "Event_Source__c" "Event Source" @("System","User","AI Agent","Integration","Customer"))
Write-MetaFile "$al\fields\Performed_By__c.field-meta.xml" (Lookup-Field "Performed_By__c" "Performed By" "User" "Audit Logs Performed" "Audit_Logs_Performed")
Write-MetaFile "$al\fields\Agent_Name__c.field-meta.xml" (Picklist-Field "Agent_Name__c" "Agent Name" @("Document Verification Agent","Financial Health Agent","Credit Risk Agent","Compliance Agent","Decision Agent"))
Write-MetaFile "$al\fields\Event_Description__c.field-meta.xml" (LongText-Field "Event_Description__c" "Event Description" 5000)
Write-MetaFile "$al\fields\Old_Value__c.field-meta.xml" (LongText-Field "Old_Value__c" "Old Value" 2000)
Write-MetaFile "$al\fields\New_Value__c.field-meta.xml" (LongText-Field "New_Value__c" "New Value" 2000)
Write-MetaFile "$al\fields\Field_Changed__c.field-meta.xml" (Text-Field "Field_Changed__c" "Field Changed" 100)
Write-MetaFile "$al\fields\Event_Timestamp__c.field-meta.xml" (DateTime-Field "Event_Timestamp__c" "Event Timestamp")
Write-MetaFile "$al\fields\IP_Address__c.field-meta.xml" (Text-Field "IP_Address__c" "IP Address" 50)
Write-MetaFile "$al\fields\User_Agent__c.field-meta.xml" (Text-Field "User_Agent__c" "User Agent" 255)
Write-MetaFile "$al\fields\Session_ID__c.field-meta.xml" (Text-Field "Session_ID__c" "Session ID" 100)
Write-MetaFile "$al\fields\Severity__c.field-meta.xml" (Picklist-Field "Severity__c" "Severity" @("Info","Warning","Error","Critical"))
Write-MetaFile "$al\fields\Compliance_Relevant__c.field-meta.xml" (Checkbox-Field "Compliance_Relevant__c" "Compliance Relevant")

# ==================== LOAN APPLICATION HISTORY (Lookup) ====================
$lah = "$base\objects\Loan_Application_History__c"
Write-MetaFile "$lah\Loan_Application_History__c.object-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- Lookup (not Master-Detail) to Loan_Application__c: RBI mandates 7-year retention of lending event history independent of parent record lifecycle. -->
    <deploymentStatus>Deployed</deploymentStatus>
    <enableActivities>false</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableHistory>false</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <label>Loan Application History</label>
    <nameField>
        <displayFormat>LAH-{0000000}</displayFormat>
        <label>History Number</label>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>Loan Application Histories</pluralLabel>
    <sharingModel>ReadWrite</sharingModel>
</CustomObject>
"@
Write-MetaFile "$lah\fields\Loan_Application__c.field-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Loan_Application__c</fullName>
    <label>Loan Application</label>
    <referenceTo>Loan_Application__c</referenceTo>
    <relationshipLabel>Application History</relationshipLabel>
    <relationshipName>Application_History</relationshipName>
    <deleteConstraint>SetNull</deleteConstraint>
    <type>Lookup</type>
</CustomField>
"@
Write-MetaFile "$lah\fields\Applicant_Name__c.field-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Applicant_Name__c</fullName>
    <label>Applicant Name</label>
    <formula>Loan_Application__r.Applicant__r.Name</formula>
    <formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs>
    <type>Text</type>
</CustomField>
"@
$lahEvents = @("Application Created","Application Submitted","Document Uploaded","Document Verified","Document Issue Flagged","Agent Run Started","Agent Run Completed","Agent Run Failed","Risk Score Updated","Compliance Check Run","Compliance Violation Found","Compliance Violation Resolved","Loan Decision Generated","Officer Review Started","Officer Decision Made","Application Status Changed","Application On Hold","Application Approved","Application Rejected","Approval Letter Generated","Disbursement Initiated","Disbursement Completed","Disbursement Failed","EMI Schedule Generated","KYC Event","Customer Notification Sent","Application Withdrawn","Application Reopened","Field Modified","Reassigned","Escalated","Integration Event","Exception Raised")
Write-MetaFile "$lah\fields\Event_Type__c.field-meta.xml" (Picklist-Field "Event_Type__c" "Event Type" $lahEvents -Required)
Write-MetaFile "$lah\fields\Event_Sub_Type__c.field-meta.xml" (Text-Field "Event_Sub_Type__c" "Event Sub Type" 100)
Write-MetaFile "$lah\fields\Event_Description__c.field-meta.xml" (LongText-Field "Event_Description__c" "Event Description" 5000)
Write-MetaFile "$lah\fields\Event_Timestamp__c.field-meta.xml" (DateTime-Field "Event_Timestamp__c" "Event Timestamp" -Required)
Write-MetaFile "$lah\fields\Triggered_By__c.field-meta.xml" (Picklist-Field "Triggered_By__c" "Triggered By" @("System","AI Agent","User","Integration","Customer","Scheduled Job") -Required)
Write-MetaFile "$lah\fields\Performed_By__c.field-meta.xml" (Lookup-Field "Performed_By__c" "Performed By" "User" "Application History Performed" "Application_History_Performed")
Write-MetaFile "$lah\fields\Agent_Name__c.field-meta.xml" (Picklist-Field "Agent_Name__c" "Agent Name" @("Document Verification Agent","Financial Health Agent","Credit Risk Agent","Compliance Agent","Decision Agent"))
Write-MetaFile "$lah\fields\Previous_Status__c.field-meta.xml" (Text-Field "Previous_Status__c" "Previous Status" 50)
Write-MetaFile "$lah\fields\New_Status__c.field-meta.xml" (Text-Field "New_Status__c" "New Status" 50)
Write-MetaFile "$lah\fields\Previous_Value__c.field-meta.xml" (LongText-Field "Previous_Value__c" "Previous Value" 2000)
Write-MetaFile "$lah\fields\New_Value__c.field-meta.xml" (LongText-Field "New_Value__c" "New Value" 2000)
Write-MetaFile "$lah\fields\Field_Changed__c.field-meta.xml" (Text-Field "Field_Changed__c" "Field Changed" 200)
Write-MetaFile "$lah\fields\Risk_Score_Before__c.field-meta.xml" (Number-Field "Risk_Score_Before__c" "Risk Score Before" 3 0)
Write-MetaFile "$lah\fields\Risk_Score_After__c.field-meta.xml" (Number-Field "Risk_Score_After__c" "Risk Score After" 3 0)
Write-MetaFile "$lah\fields\Agent_Result__c.field-meta.xml" (Picklist-Field "Agent_Result__c" "Agent Result" @("Pass","Warning","Fail"))
Write-MetaFile "$lah\fields\Agent_Score_Impact__c.field-meta.xml" (Number-Field "Agent_Score_Impact__c" "Agent Score Impact" 3 0)
Write-MetaFile "$lah\fields\AI_Confidence__c.field-meta.xml" (Percent-Field "AI_Confidence__c" "AI Confidence")
Write-MetaFile "$lah\fields\Decision_Made__c.field-meta.xml" (Picklist-Field "Decision_Made__c" "Decision Made" @("Approve","Hold","Reject"))
Write-MetaFile "$lah\fields\Decision_Reason__c.field-meta.xml" (LongText-Field "Decision_Reason__c" "Decision Reason" 5000)
Write-MetaFile "$lah\fields\Missing_Documents_Snapshot__c.field-meta.xml" (LongText-Field "Missing_Documents_Snapshot__c" "Missing Documents Snapshot" 2000)
Write-MetaFile "$lah\fields\Officer_Override__c.field-meta.xml" (Checkbox-Field "Officer_Override__c" "Officer Override")
Write-MetaFile "$lah\fields\Override_Reason__c.field-meta.xml" (LongText-Field "Override_Reason__c" "Override Reason" 2000)
Write-MetaFile "$lah\fields\Duration_Seconds__c.field-meta.xml" (Number-Field "Duration_Seconds__c" "Duration Seconds" 7 0)
Write-MetaFile "$lah\fields\IP_Address__c.field-meta.xml" (Text-Field "IP_Address__c" "IP Address" 50)
Write-MetaFile "$lah\fields\Session_ID__c.field-meta.xml" (Text-Field "Session_ID__c" "Session ID" 100)
Write-MetaFile "$lah\fields\Integration_Reference__c.field-meta.xml" (Text-Field "Integration_Reference__c" "Integration Reference" 100)
Write-MetaFile "$lah\fields\Compliance_Relevant__c.field-meta.xml" (Checkbox-Field "Compliance_Relevant__c" "Compliance Relevant")
Write-MetaFile "$lah\fields\Severity__c.field-meta.xml" (Picklist-Field "Severity__c" "Severity" @("Info","Warning","Error","Critical"))
Write-MetaFile "$lah\fields\Is_Archived__c.field-meta.xml" (Checkbox-Field "Is_Archived__c" "Is Archived")

Write-MetaFile "$lah\validationRules\Event_Timestamp_Not_Future.validationRule-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Event_Timestamp_Not_Future</fullName>
    <active>true</active>
    <description>Event timestamp cannot be in the future</description>
    <errorConditionFormula>Event_Timestamp__c &gt; NOW()</errorConditionFormula>
    <errorDisplayField>Event_Timestamp__c</errorDisplayField>
    <errorMessage>Event timestamp cannot be in the future.</errorMessage>
</ValidationRule>
"@
Write-MetaFile "$lah\validationRules\Override_Reason_Required.validationRule-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Override_Reason_Required</fullName>
    <active>true</active>
    <description>Override reason required when officer override is checked</description>
    <errorConditionFormula>AND(Officer_Override__c, ISBLANK(Override_Reason__c))</errorConditionFormula>
    <errorDisplayField>Override_Reason__c</errorDisplayField>
    <errorMessage>Override reason is required when Officer Override is checked.</errorMessage>
</ValidationRule>
"@
Write-MetaFile "$lah\validationRules\Agent_Name_Required_For_AI.validationRule-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Agent_Name_Required_For_AI</fullName>
    <active>true</active>
    <description>Agent name required when triggered by AI Agent</description>
    <errorConditionFormula>AND(ISPICKVAL(Triggered_By__c, &quot;AI Agent&quot;), ISPICKVAL(Agent_Name__c, &quot;&quot;))</errorConditionFormula>
    <errorDisplayField>Agent_Name__c</errorDisplayField>
    <errorMessage>Agent Name is required when Triggered By is AI Agent.</errorMessage>
</ValidationRule>
"@
Write-MetaFile "$lah\validationRules\Decision_Made_Required.validationRule-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Decision_Made_Required</fullName>
    <active>true</active>
    <description>Decision Made required when event type is Loan Decision Generated</description>
    <errorConditionFormula>AND(ISPICKVAL(Event_Type__c, &quot;Loan Decision Generated&quot;), ISPICKVAL(Decision_Made__c, &quot;&quot;))</errorConditionFormula>
    <errorDisplayField>Decision_Made__c</errorDisplayField>
    <errorMessage>Decision Made is required when Event Type is Loan Decision Generated.</errorMessage>
</ValidationRule>
"@

# ==================== ACCOUNT FIELDS (Person Account) ====================
$acc = "$base\objects\Account\fields"
Write-MetaFile "$acc\PAN_Number__c.field-meta.xml" (Text-Field "PAN_Number__c" "PAN Number" 10 -Unique)
Write-MetaFile "$acc\Aadhaar_Number__c.field-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Aadhaar_Number__c</fullName>
    <label>Aadhaar Number</label>
    <length>12</length>
    <maskChar>asterisk</maskChar>
    <maskType>lastFour</maskType>
    <type>EncryptedText</type>
</CustomField>
"@
Write-MetaFile "$acc\Customer_Segment__c.field-meta.xml" (Picklist-Field "Customer_Segment__c" "Customer Segment" @("Salaried","Self-Employed","Business","Student"))
Write-MetaFile "$acc\Annual_Income__c.field-meta.xml" (Currency-Field "Annual_Income__c" "Annual Income")
Write-MetaFile "$acc\Monthly_Income__c.field-meta.xml" (Currency-Field "Monthly_Income__c" "Monthly Income")
Write-MetaFile "$acc\KYC_Status__c.field-meta.xml" (Picklist-Field "KYC_Status__c" "KYC Status" @("Not Started","In Progress","Verified","Failed"))
Write-MetaFile "$acc\Bureau_Score__c.field-meta.xml" (Number-Field "Bureau_Score__c" "Bureau Score" 4 0)
Write-MetaFile "$acc\Risk_Category__c.field-meta.xml" (Picklist-Field "Risk_Category__c" "Risk Category" @("Low","Medium","High"))
Write-MetaFile "$acc\Employment_Status__c.field-meta.xml" (Picklist-Field "Employment_Status__c" "Employment Status" @("Employed","Self-Employed","Unemployed"))
Write-MetaFile "$acc\Employer_Name__c.field-meta.xml" (Text-Field "Employer_Name__c" "Employer Name" 100)
Write-MetaFile "$acc\Years_At_Current_Job__c.field-meta.xml" (Number-Field "Years_At_Current_Job__c" "Years At Current Job" 3 1)
Write-MetaFile "$acc\Existing_EMI_Total__c.field-meta.xml" (Currency-Field "Existing_EMI_Total__c" "Existing EMI Total")
Write-MetaFile "$acc\FOIR__c.field-meta.xml" (Formula-Field "FOIR__c" "FOIR" "Percent" "IF(Monthly_Income__c &gt; 0, Existing_EMI_Total__c / Monthly_Income__c, 0)" 5 2)

# ==================== CUSTOM METADATA TYPES ====================
$pr = "$base\objects\Policy_Rule__mdt"
Write-MetaFile "$pr\Policy_Rule__mdt.object-meta.xml" (CustomMetadataObject "Policy_Rule__mdt" "Policy Rule" "Policy Rules")
Write-MetaFile "$pr\fields\Category__c.field-meta.xml" (Picklist-Field "Category__c" "Category" @("Eligibility","Income","Risk","Document"))
Write-MetaFile "$pr\fields\Product_Code__c.field-meta.xml" (Text-Field "Product_Code__c" "Product Code" 20)
Write-MetaFile "$pr\fields\Description__c.field-meta.xml" (LongText-Field "Description__c" "Description" 32768)
Write-MetaFile "$pr\fields\Field_API_Name__c.field-meta.xml" (Text-Field "Field_API_Name__c" "Field API Name" 80)
Write-MetaFile "$pr\fields\Operator__c.field-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Operator__c</fullName>
    <label>Operator</label>
    <type>Picklist</type>
    <valueSet>
        <restricted>true</restricted>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value><fullName>=</fullName><default>false</default><label>=</label></value>
            <value><fullName>!=</fullName><default>false</default><label>!=</label></value>
            <value><fullName>&gt;</fullName><default>false</default><label>&gt;</label></value>
            <value><fullName>&lt;</fullName><default>false</default><label>&lt;</label></value>
            <value><fullName>&gt;=</fullName><default>false</default><label>&gt;=</label></value>
            <value><fullName>&lt;=</fullName><default>false</default><label>&lt;=</label></value>
            <value><fullName>Contains</fullName><default>false</default><label>Contains</label></value>
        </valueSetDefinition>
    </valueSet>
</CustomField>
"@
Write-MetaFile "$pr\fields\Threshold_Value__c.field-meta.xml" (Text-Field "Threshold_Value__c" "Threshold Value" 50)
Write-MetaFile "$pr\fields\Risk_Points__c.field-meta.xml" (Number-Field "Risk_Points__c" "Risk Points" 3 0)
Write-MetaFile "$pr\fields\Severity__c.field-meta.xml" (Picklist-Field "Severity__c" "Severity" @("Low","Medium","High","Critical"))
Write-MetaFile "$pr\fields\Is_Active__c.field-meta.xml" (Checkbox-Field "Is_Active__c" "Is Active")
Write-MetaFile "$pr\fields\Effective_Date__c.field-meta.xml" (Date-Field "Effective_Date__c" "Effective Date")

$cr = "$base\objects\Compliance_Rule__mdt"
Write-MetaFile "$cr\Compliance_Rule__mdt.object-meta.xml" (CustomMetadataObject "Compliance_Rule__mdt" "Compliance Rule" "Compliance Rules")
Write-MetaFile "$cr\fields\Regulator__c.field-meta.xml" (Picklist-Field "Regulator__c" "Regulator" @("RBI","SEBI","Internal"))
Write-MetaFile "$cr\fields\Regulation_Reference__c.field-meta.xml" (Text-Field "Regulation_Reference__c" "Regulation Reference" 100)
Write-MetaFile "$cr\fields\Category__c.field-meta.xml" (Picklist-Field "Category__c" "Category" @("KYC","AML","Digital Lending","Fair Practice"))
Write-MetaFile "$cr\fields\Description__c.field-meta.xml" (LongText-Field "Description__c" "Description" 32768)
Write-MetaFile "$cr\fields\Mandatory__c.field-meta.xml" (Checkbox-Field "Mandatory__c" "Mandatory")
Write-MetaFile "$cr\fields\Severity__c.field-meta.xml" (Picklist-Field "Severity__c" "Severity" @("Low","Medium","High","Critical"))
Write-MetaFile "$cr\fields\Validation_Logic__c.field-meta.xml" (LongText-Field "Validation_Logic__c" "Validation Logic" 32768)
Write-MetaFile "$cr\fields\Effective_Date__c.field-meta.xml" (Date-Field "Effective_Date__c" "Effective Date")
Write-MetaFile "$cr\fields\Active__c.field-meta.xml" (Checkbox-Field "Active__c" "Active")

# ==================== PROFILES ====================
$profileNames = @(
    "NBFC_System_Admin",
    "NBFC_Loan_Officer",
    "NBFC_Underwriter",
    "NBFC_Compliance_Officer",
    "NBFC_Branch_Manager",
    "NBFC_Customer_Service"
)
$customObjects = @(
    "Loan_Application__c","Applicant_Document__c","Agent_Check_Result__c","Risk_Assessment__c",
    "Compliance_Check__c","Loan_Decision__c","Loan_Product__c","Repayment_Schedule__c",
    "Audit_Log__c","Loan_Application_History__c"
)
foreach ($prof in $profileNames) {
    $objPerms = ($customObjects | ForEach-Object {
        $allowEdit = if ($prof -eq "NBFC_Customer_Service" -and $_ -ne "Loan_Application__c") { "false" } else { "true" }
        $allowCreate = if ($prof -eq "NBFC_Customer_Service") { "false" } else { "true" }
        $allowDelete = if ($prof -in @("NBFC_System_Admin","NBFC_Compliance_Officer")) { "true" } else { "false" }
        @"
    <objectPermissions>
        <allowCreate>$allowCreate</allowCreate>
        <allowDelete>$allowDelete</allowDelete>
        <allowEdit>$allowEdit</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>$(if ($prof -eq "NBFC_System_Admin") { "true" } else { "false" })</modifyAllRecords>
        <object>$_</object>
        <viewAllRecords>$(if ($prof -in @("NBFC_System_Admin","NBFC_Compliance_Officer","NBFC_Branch_Manager")) { "true" } else { "false" })</viewAllRecords>
    </objectPermissions>
"@
    }) -join "`n"
    $label = ($prof -replace "_"," ")
    Write-MetaFile "$base\profiles\$prof.profile-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<Profile xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- Scaffold profile for $label role in NBFC loan origination platform -->
    <custom>true</custom>
    <description>NBFC role-based profile scaffold for $label</description>
    <userLicense>Salesforce</userLicense>
$objPerms
</Profile>
"@
}

# ==================== PERMISSION SETS ====================
$permSets = @{
    "NBFC_Agentforce_User" = "Grants access to AI agent integration objects and fields for Agentforce automation"
    "NBFC_Loan_Approver" = "Loan approval permissions for standard approver workflow"
    "NBFC_Senior_Approver" = "Elevated approval permissions including override capabilities"
    "NBFC_Reports_Access" = "Read access to reporting objects and report builder"
    "NBFC_Disbursement_Officer" = "Disbursement workflow permissions including repayment schedule management"
}
foreach ($ps in $permSets.Keys) {
    $objPerms = ($customObjects | ForEach-Object {
        @"
    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>true</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>$_</object>
        <viewAllRecords>true</viewAllRecords>
    </objectPermissions>
"@
    }) -join "`n"
    Write-MetaFile "$base\permissionsets\$ps.permissionset-meta.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- $($permSets[$ps]) -->
    <description>$($permSets[$ps])</description>
    <hasActivationRequired>false</hasActivationRequired>
    <label>$($ps -replace '_',' ')</label>
    <license>Salesforce</license>
$objPerms
</PermissionSet>
"@
}

# ==================== PACKAGE.XML MANIFEST ====================
$customObjectMembers = ($customObjects + @("Policy_Rule__mdt","Compliance_Rule__mdt") | ForEach-Object { "        <members>$_</members>" }) -join "`n"
$accountFields = @("PAN_Number__c","Aadhaar_Number__c","Customer_Segment__c","Annual_Income__c","Monthly_Income__c","KYC_Status__c","Bureau_Score__c","Risk_Category__c","Employment_Status__c","Employer_Name__c","Years_At_Current_Job__c","Existing_EMI_Total__c","FOIR__c")
$accountFieldMembers = ($accountFields | ForEach-Object { "        <members>Account.$_</members>" }) -join "`n"
$profileMembers = ($profileNames | ForEach-Object { "        <members>$_</members>" }) -join "`n"
$permSetMembers = ($permSets.Keys | ForEach-Object { "        <members>$_</members>" }) -join "`n"

Write-MetaFile $manifest @"
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- NBFC Loan Origination Platform - Full Metadata Manifest -->
    <!-- Audit_Log__c and Loan_Application_History__c use Lookup (not Master-Detail) to preserve records when parent Loan Application is deleted -->
    <!-- History roll-up fields on Loan_Application__c require DLRS or Apex due to Lookup relationship constraint -->
    <types>
$customObjectMembers
        <name>CustomObject</name>
    </types>
    <types>
$accountFieldMembers
        <name>CustomField</name>
    </types>
    <types>
$profileMembers
        <name>Profile</name>
    </types>
    <types>
$permSetMembers
        <name>PermissionSet</name>
    </types>
    <version>66.0</version>
</Package>
"@

# Generate roll-up summary fields into samples/rollups for phase-2 deployment
$rollupBase = "c:\Users\kchauhan030\Kartik Projects\SFDC AI UsedCase\SFDCAIUSECASE\samples\rollups\objects\Loan_Application__c\fields"
Write-MetaFile "$rollupBase\Total_Documents_Count__c.field-meta.xml" (Rollup-Field "Total_Documents_Count__c" "Total Documents Count" "Applicant_Document__c.Loan_Application__c" "count" $null $null)
Write-MetaFile "$rollupBase\Verified_Documents_Count__c.field-meta.xml" (Rollup-Field "Verified_Documents_Count__c" "Verified Documents Count" "Applicant_Document__c.Loan_Application__c" "count" $null @(@{Field="Verified__c"; Operation="equals"; Value="true"}))
Write-MetaFile "$rollupBase\Missing_Documents_Count__c.field-meta.xml" (Rollup-Field "Missing_Documents_Count__c" "Missing Documents Count" "Applicant_Document__c.Loan_Application__c" "count" $null @(@{Field="Uploaded__c"; Operation="equals"; Value="false"}))
Write-MetaFile "$rollupBase\Total_Agent_Score__c.field-meta.xml" (Rollup-Field "Total_Agent_Score__c" "Total Agent Score" "Agent_Check_Result__c.Loan_Application__c" "sum" "Agent_Check_Result__c.Score_Impact__c" $null)
Write-MetaFile "$rollupBase\Failed_Agents_Count__c.field-meta.xml" (Rollup-Field "Failed_Agents_Count__c" "Failed Agents Count" "Agent_Check_Result__c.Loan_Application__c" "count" $null @(@{Field="Result__c"; Operation="equals"; Value="Fail"}))
Write-MetaFile "$rollupBase\Compliance_Issues_Count__c.field-meta.xml" (Rollup-Field "Compliance_Issues_Count__c" "Compliance Issues Count" "Compliance_Check__c.Loan_Application__c" "count" $null @(@{Field="Status__c"; Operation="equals"; Value="Non-Compliant"}))

Write-MetaFile "c:\Users\kchauhan030\Kartik Projects\SFDC AI UsedCase\SFDCAIUSECASE\manifest\package-rollups.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- Phase 2: Deploy roll-up summary fields AFTER main package.xml succeeds -->
    <types>
        <members>Loan_Application__c.Total_Documents_Count__c</members>
        <members>Loan_Application__c.Verified_Documents_Count__c</members>
        <members>Loan_Application__c.Missing_Documents_Count__c</members>
        <members>Loan_Application__c.Total_Agent_Score__c</members>
        <members>Loan_Application__c.Failed_Agents_Count__c</members>
        <members>Loan_Application__c.Compliance_Issues_Count__c</members>
        <name>CustomField</name>
    </types>
    <version>66.0</version>
</Package>
"@

Write-Host "Metadata generation complete. Files written to $base"
