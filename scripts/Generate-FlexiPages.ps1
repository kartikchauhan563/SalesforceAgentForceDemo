# Generates all 13 NBFC Lightning FlexiPage metadata files (API 66)
# Run: .\scripts\Generate-FlexiPages.ps1

$ErrorActionPreference = "Stop"
$out = "c:\Users\kchauhan030\Kartik Projects\SFDC AI UsedCase\SFDCAIUSECASE\force-app\main\default\flexipages"
$script:FacetCounter = 0

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

function Write-FlexiPage($fileName, $content) {
    Ensure-Dir $out
    [System.IO.File]::WriteAllText((Join-Path $out $fileName), $content.TrimStart(), [System.Text.UTF8Encoding]::new($false))
}

function New-FacetId($prefix) {
    $script:FacetCounter++
    return "${prefix}_$($script:FacetCounter)"
}

function Reset-FacetCounter { $script:FacetCounter = 0 }

function Build-FieldInstance($fieldApi, $behavior = "none") {
@"

            <fieldInstance>
                <fieldInstanceProperties>
                    <name>uiBehavior</name>
                    <value>$behavior</value>
                </fieldInstanceProperties>
                <fieldItem>Record.$fieldApi</fieldItem>
                <identifier>Record_${fieldApi}_Field</identifier>
            </fieldInstance>
"@
}

function Build-FieldSectionFacet($label, $fields, $columns = 1) {
    $fieldXml = ($fields | ForEach-Object { Build-FieldInstance $_ }) -join ""
    $sectionFacet = New-FacetId "section"
    if ($columns -eq 1) {
        $colFacet = New-FacetId "col"
        $regions = @"
    <!-- Field section: $label -->
    <flexiPageRegions>
        <itemInstances>$fieldXml
        </itemInstances>
        <name>$colFacet</name>
        <type>Facet</type>
    </flexiPageRegions>
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>columns</name>
                    <value>$colFacet</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>label</name>
                    <value>$label</value>
                </componentInstanceProperties>
                <componentName>flexipage:fieldSection</componentName>
                <identifier>${sectionFacet}_fieldSection</identifier>
            </componentInstance>
        </itemInstances>
        <name>$sectionFacet</name>
        <type>Facet</type>
    </flexiPageRegions>
"@
    } else {
        $mid = [math]::Ceiling($fields.Count / 2)
        $col1Fields = $fields[0..($mid - 1)]
        $col2Fields = if ($mid -lt $fields.Count) { $fields[$mid..($fields.Count - 1)] } else { @() }
        $col1Facet = New-FacetId "col1"
        $col2Facet = New-FacetId "col2"
        $columnsFacet = New-FacetId "columns"
        $col1Xml = ($col1Fields | ForEach-Object { Build-FieldInstance $_ }) -join ""
        $col2Xml = ($col2Fields | ForEach-Object { Build-FieldInstance $_ }) -join ""
        $regions = @"
    <!-- Two-column field section: $label -->
    <flexiPageRegions>
        <itemInstances>$col1Xml
        </itemInstances>
        <name>$col1Facet</name>
        <type>Facet</type>
    </flexiPageRegions>
    <flexiPageRegions>
        <itemInstances>$col2Xml
        </itemInstances>
        <name>$col2Facet</name>
        <type>Facet</type>
    </flexiPageRegions>
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>body</name>
                    <value>$col1Facet</value>
                </componentInstanceProperties>
                <componentName>flexipage:column</componentName>
                <identifier>${col1Facet}_column</identifier>
            </componentInstance>
        </itemInstances>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>body</name>
                    <value>$col2Facet</value>
                </componentInstanceProperties>
                <componentName>flexipage:column</componentName>
                <identifier>${col2Facet}_column</identifier>
            </componentInstance>
        </itemInstances>
        <name>$columnsFacet</name>
        <type>Facet</type>
    </flexiPageRegions>
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>columns</name>
                    <value>$columnsFacet</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>label</name>
                    <value>$label</value>
                </componentInstanceProperties>
                <componentName>flexipage:fieldSection</componentName>
                <identifier>${sectionFacet}_fieldSection</identifier>
            </componentInstance>
        </itemInstances>
        <name>$sectionFacet</name>
        <type>Facet</type>
    </flexiPageRegions>
"@
    }
    return @{ Regions = $regions; FacetName = $sectionFacet }
}

function Build-FieldSectionDirect($label, $fields, $identifier, $columns = 1, $visibilityRule = $null) {
    $fieldXml = ($fields | ForEach-Object { Build-FieldInstance $_ }) -join ""
    $vis = if ($visibilityRule) { "`n                $visibilityRule" } else { "" }
    if ($columns -eq 1) {
        $colFacet = New-FacetId "col"
        $regions = @"
    <!-- Sidebar/main field section column facet: $label -->
    <flexiPageRegions>
        <itemInstances>$fieldXml
        </itemInstances>
        <name>$colFacet</name>
        <type>Facet</type>
    </flexiPageRegions>
"@
        $component = @"
            <componentInstance>
                <componentInstanceProperties>
                    <name>columns</name>
                    <value>$colFacet</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>label</name>
                    <value>$label</value>
                </componentInstanceProperties>
                <componentName>flexipage:fieldSection</componentName>
                <identifier>$identifier</identifier>$vis
            </componentInstance>
"@
    } else {
        $mid = [math]::Ceiling($fields.Count / 2)
        $col1Fields = $fields[0..($mid - 1)]
        $col2Fields = if ($mid -lt $fields.Count) { $fields[$mid..($fields.Count - 1)] } else { @() }
        $col1Facet = New-FacetId "col1"
        $col2Facet = New-FacetId "col2"
        $columnsFacet = New-FacetId "columns"
        $col1Xml = ($col1Fields | ForEach-Object { Build-FieldInstance $_ }) -join ""
        $col2Xml = ($col2Fields | ForEach-Object { Build-FieldInstance $_ }) -join ""
        $regions = @"
    <!-- Two-column direct field section: $label -->
    <flexiPageRegions>
        <itemInstances>$col1Xml
        </itemInstances>
        <name>$col1Facet</name>
        <type>Facet</type>
    </flexiPageRegions>
    <flexiPageRegions>
        <itemInstances>$col2Xml
        </itemInstances>
        <name>$col2Facet</name>
        <type>Facet</type>
    </flexiPageRegions>
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>body</name>
                    <value>$col1Facet</value>
                </componentInstanceProperties>
                <componentName>flexipage:column</componentName>
                <identifier>${col1Facet}_column</identifier>
            </componentInstance>
        </itemInstances>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>body</name>
                    <value>$col2Facet</value>
                </componentInstanceProperties>
                <componentName>flexipage:column</componentName>
                <identifier>${col2Facet}_column</identifier>
            </componentInstance>
        </itemInstances>
        <name>$columnsFacet</name>
        <type>Facet</type>
    </flexiPageRegions>
"@
        $component = @"
            <componentInstance>
                <componentInstanceProperties>
                    <name>columns</name>
                    <value>$columnsFacet</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>label</name>
                    <value>$label</value>
                </componentInstanceProperties>
                <componentName>flexipage:fieldSection</componentName>
                <identifier>$identifier</identifier>$vis
            </componentInstance>
"@
    }
    return @{ Regions = $regions; Component = $component }
}

function Build-RelatedListFacet($facetName, $relatedListApiName, $rows = 10, $override = "ADVGRID", $visibilityRule = $null) {
    $vis = if ($visibilityRule) { "`n                $visibilityRule" } else { "" }
@"

    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>relatedListComponentOverride</name>
                    <value>$override</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>relatedListApiName</name>
                    <value>$relatedListApiName</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>rowsToDisplay</name>
                    <value>$rows</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>showActionBar</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentName>force:relatedListSingleContainer</componentName>
                <identifier>${facetName}_relatedList</identifier>$vis
            </componentInstance>
        </itemInstances>
        <name>$facetName</name>
        <type>Facet</type>
    </flexiPageRegions>
"@
}

function Build-RelatedListDirect($relatedListApiName, $identifier, $rows = 10, $override = "ADVGRID", $visibilityRule = $null) {
    $vis = if ($visibilityRule) { "`n                $visibilityRule" } else { "" }
@"

            <componentInstance>
                <componentInstanceProperties>
                    <name>relatedListComponentOverride</name>
                    <value>$override</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>relatedListApiName</name>
                    <value>$relatedListApiName</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>rowsToDisplay</name>
                    <value>$rows</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>showActionBar</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentName>force:relatedListSingleContainer</componentName>
                <identifier>$identifier</identifier>$vis
            </componentInstance>
"@
}

function Build-DynamicRelatedListFacet($facetName, $relatedFieldApiName, $displayFields, $maxRecords = 10, $visibilityRule = $null) {
    $fieldList = ($displayFields | ForEach-Object {
        "                        <valueListItems>`n                            <value>$_</value>`n                        </valueListItems>"
    }) -join "`n"
    $vis = if ($visibilityRule) { "`n                $visibilityRule" } else { "" }
@"

    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>relatedFieldApiName</name>
                    <value>$relatedFieldApiName</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>maxRecordsToDisplay</name>
                    <value>$maxRecords</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>displayFields</name>
                    <valueList>
$fieldList
                    </valueList>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>showActionBar</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentName>lst:dynamicRelatedList</componentName>
                <identifier>${facetName}_dynamicList</identifier>$vis
            </componentInstance>
        </itemInstances>
        <name>$facetName</name>
        <type>Facet</type>
    </flexiPageRegions>
"@
}

function Build-RichTextFacet($facetName, $html, $visibilityRule = $null) {
    $vis = if ($visibilityRule) { "`n                $visibilityRule" } else { "" }
@"

    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>decorate</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>richTextValue</name>
                    <value>$html</value>
                </componentInstanceProperties>
                <componentName>flexipage:richText</componentName>
                <identifier>${facetName}_richText</identifier>$vis
            </componentInstance>
        </itemInstances>
        <name>$facetName</name>
        <type>Facet</type>
    </flexiPageRegions>
"@
}

function Build-RichTextDirect($html, $identifier, $visibilityRule = $null) {
    $vis = if ($visibilityRule) { "`n                $visibilityRule" } else { "" }
@"

            <componentInstance>
                <componentInstanceProperties>
                    <name>decorate</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>richTextValue</name>
                    <value>$html</value>
                </componentInstanceProperties>
                <componentName>flexipage:richText</componentName>
                <identifier>$identifier</identifier>$vis
            </componentInstance>
"@
}

function Build-VisibilityRule($criteria, $booleanFilter = $null) {
    $critXml = ($criteria | ForEach-Object {
        @"
                    <criteria>
                        <leftValue>$($_.Left)</leftValue>
                        <operator>$($_.Op)</operator>
                        <rightValue>$($_.Right)</rightValue>
                    </criteria>
"@
    }) -join ""
    $bf = if ($booleanFilter) { "`n                    <booleanFilter>$booleanFilter</booleanFilter>" } else { "" }
    @"
                <visibilityRule>$bf
$critXml
                </visibilityRule>
"@
}

function Build-FeedFacet($facetName) {
@"

    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentName>forceChatter:recordFeedContainer</componentName>
                <identifier>${facetName}_feed</identifier>
            </componentInstance>
        </itemInstances>
        <name>$facetName</name>
        <type>Facet</type>
    </flexiPageRegions>
"@
}

function Build-FeedDirect($identifier) {
@"

            <componentInstance>
                <componentName>forceChatter:recordFeedContainer</componentName>
                <identifier>$identifier</identifier>
            </componentInstance>
"@
}

function Build-ActivityDirect($identifier) {
@"

            <componentInstance>
                <componentInstanceProperties>
                    <name>showLegacyActivityComposer</name>
                    <value>false</value>
                </componentInstanceProperties>
                <componentName>runtime_sales_activities:activityPanel</componentName>
                <identifier>$identifier</identifier>
            </componentInstance>
"@
}

function Build-BlankDirect($identifier) {
@"

            <componentInstance>
                <componentName>flexipage:blankSpace</componentName>
                <identifier>$identifier</identifier>
            </componentInstance>
"@
}

function Build-TabFacet($tabsFacetName, $tabs) {
    $tabItems = ($tabs | ForEach-Object {
        $active = if ($_.Active) { @"
                <componentInstanceProperties>
                    <name>active</name>
                    <value>true</value>
                </componentInstanceProperties>
"@ } else { "" }
@"

            <componentInstance>$active
                <componentInstanceProperties>
                    <name>body</name>
                    <value>$($_.Body)</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>title</name>
                    <value>$($_.Title)</value>
                </componentInstanceProperties>
                <componentName>flexipage:tab</componentName>
                <identifier>$($_.Id)_tab</identifier>
            </componentInstance>
"@
    }) -join ""
@"

    <flexiPageRegions>
        <itemInstances>$tabItems
        </itemInstances>
        <name>$tabsFacetName</name>
        <type>Facet</type>
    </flexiPageRegions>
"@
}

function Build-TabsetMain($tabsFacet, $label, $identifier = "flexipage_main_tabset") {
@"

            <componentInstance>
                <componentInstanceProperties>
                    <name>label</name>
                    <value>$label</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>tabs</name>
                    <value>$tabsFacet</value>
                </componentInstanceProperties>
                <componentName>flexipage:tabset</componentName>
                <identifier>$identifier</identifier>
            </componentInstance>
"@
}

function Build-RecordPage($label, $fileName, $sobjectType, $parentFlexiPage, $template, $headerRegions, $facetRegions, $mainRegionContent, $sidebarRegionContent, $sidebarRegionName = "sidebar") {
    $xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<FlexiPage xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- ${label}: NBFC AI Loan Underwriting Lightning Record Page -->
$headerRegions
$facetRegions
    <flexiPageRegions>
        <itemInstances>
$mainRegionContent
        </itemInstances>
        <mode>Replace</mode>
        <name>main</name>
        <type>Region</type>
    </flexiPageRegions>
    <flexiPageRegions>
        <itemInstances>
$sidebarRegionContent
        </itemInstances>
        <mode>Replace</mode>
        <name>$sidebarRegionName</name>
        <type>Region</type>
    </flexiPageRegions>
    <masterLabel>$label</masterLabel>
    <parentFlexiPage>$parentFlexiPage</parentFlexiPage>
    <sobjectType>$sobjectType</sobjectType>
    <template>
        <name>$template</name>
    </template>
    <type>RecordPage</type>
</FlexiPage>
"@
    Write-FlexiPage $fileName $xml
}

function Build-AppPage($label, $fileName, $template, $regions) {
    $xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<FlexiPage xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- ${label}: NBFC Lightning App Page -->
$regions
    <masterLabel>$label</masterLabel>
    <template>
        <name>$template</name>
    </template>
    <type>AppPage</type>
</FlexiPage>
"@
    Write-FlexiPage $fileName $xml
}

function Build-HighlightsHeader {
@"

    <!-- Highlights panel: loan officer command center header -->
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>collapsed</name>
                    <value>false</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>enableActionsConfiguration</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>enableActionsInNative</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>hideChatterActions</name>
                    <value>false</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>numVisibleActions</name>
                    <value>5</value>
                </componentInstanceProperties>
                <componentName>force:highlightsPanel</componentName>
                <identifier>force_highlightsPanel</identifier>
            </componentInstance>
        </itemInstances>
        <mode>Replace</mode>
        <name>header</name>
        <type>Region</type>
    </flexiPageRegions>
"@
}

function Build-PathSubheader($fieldApi = "Status__c") {
@"

    <!-- Path assistant on application status lifecycle -->
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>hideUpdateButton</name>
                    <value>false</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>variant</name>
                    <value>linear</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>fieldApiName</name>
                    <value>$fieldApi</value>
                </componentInstanceProperties>
                <componentName>runtime_sales_pathassistant:pathAssistant</componentName>
                <identifier>runtime_pathAssistant</identifier>
            </componentInstance>
        </itemInstances>
        <mode>Replace</mode>
        <name>subheader</name>
        <type>Region</type>
    </flexiPageRegions>
"@
}

function Build-ReportChartRegion($regionName, $reportName) {
@"

    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>reportName</name>
                    <value>$reportName</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>hideOnError</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>openLinksInNewWindow</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentName>flexipage:reportChart</componentName>
                <identifier>${regionName}_report_$($reportName -replace '[^a-zA-Z0-9_]','_')</identifier>
            </componentInstance>
        </itemInstances>
        <mode>Replace</mode>
        <name>$regionName</name>
        <type>Region</type>
    </flexiPageRegions>
"@
}

function Build-FilterListRegion($regionName, $entityName, $filterName) {
@"

    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>entityName</name>
                    <value>$entityName</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>filterName</name>
                    <value>$filterName</value>
                </componentInstanceProperties>
                <componentName>flexipage:filterListCard</componentName>
                <identifier>${regionName}_filterList</identifier>
            </componentInstance>
        </itemInstances>
        <mode>Replace</mode>
        <name>$regionName</name>
        <type>Region</type>
    </flexiPageRegions>
"@
}

# ==================== PAGE 1: LOAN APPLICATION ====================
Reset-FacetCounter
$allRegions = ""
$tabFacets = @()

$s1 = Build-FieldSectionFacet "Application Details" @("Applicant__c","Loan_Product__c","Loan_Amount__c","Loan_Amount_Approved__c","Tenure_Months__c","Interest_Rate__c","Loan_Purpose__c","Application_Channel__c","Application_Date__c","Priority__c","Branch__c")
$allRegions += $s1.Regions
$tabFacets += @{ Title = "Application Details"; Body = $s1.FacetName; Id = "tab_app_details"; Active = $true }

$s2 = Build-FieldSectionFacet "Financial Analysis" @("Monthly_Income__c","Existing_EMI__c","EMI_Burden__c","Calculated_EMI__c","FOIR_After_Loan__c","LTI__c","Credit_Score__c") 2
$allRegions += $s2.Regions
$tabFacets += @{ Title = "Financial Analysis"; Body = $s2.FacetName; Id = "tab_financial"; Active = $false }

$agentVis = Build-VisibilityRule @(@{ Left = "{!Record.All_Agents_Completed__c}"; Op = "EQUAL"; Right = "true" })
$agentFacet = New-FacetId "agentResults"
$allRegions += Build-DynamicRelatedListFacet $agentFacet "Agent_Check_Results__r" @("Agent_Name__c","Status__c","Result__c","Score_Impact__c","Confidence__c","Run_Completed_At__c","Reason__c") 25 $agentVis
$tabFacets += @{ Title = "AI Agent Results"; Body = $agentFacet; Id = "tab_agents"; Active = $false }

$docFacet = New-FacetId "documents"
$allRegions += Build-DynamicRelatedListFacet $docFacet "Applicant_Documents__r" @("Document_Type__c","Uploaded__c","Verified__c","Verification_Status__c","Issue_Found__c","OCR_Confidence__c","Upload_Date__c") 25
$tabFacets += @{ Title = "Documents"; Body = $docFacet; Id = "tab_documents"; Active = $false }

$compFacet = New-FacetId "compliance"
$allRegions += Build-DynamicRelatedListFacet $compFacet "Compliance_Checks__r" @("Rule_Name__c","Rule_Category__c","Status__c","Severity__c","Action_Required__c","Resolved__c") 25
$tabFacets += @{ Title = "Compliance"; Body = $compFacet; Id = "tab_compliance"; Active = $false }

$histFacet = New-FacetId "history"
$allRegions += Build-DynamicRelatedListFacet $histFacet "Application_History__r" @("Event_Type__c","Event_Timestamp__c","Triggered_By__c","Agent_Name__c","Previous_Status__c","New_Status__c","Decision_Made__c","Severity__c") 25
$tabFacets += @{ Title = "History"; Body = $histFacet; Id = "tab_history"; Active = $false }

$feedFacet = New-FacetId "activityFeed"
$allRegions += Build-FeedFacet $feedFacet
$tabFacets += @{ Title = "Standard.Tab.collaborate"; Body = $feedFacet; Id = "tab_activity"; Active = $false }

$tabsFacet = New-FacetId "mainTabs"
$allRegions += Build-TabFacet $tabsFacet $tabFacets

$sb1 = Build-FieldSectionDirect "Assignment" @("Status__c","Sub_Status__c","Loan_Officer__c","Underwriter__c") "sidebar_assignment"
$allRegions += $sb1.Regions
$sb2 = Build-FieldSectionDirect "AI Output" @("Risk_Score__c","Risk_Level__c","Final_Recommendation__c","AI_Confidence__c","All_Agents_Completed__c") "sidebar_ai_output"
$allRegions += $sb2.Regions
$sb3 = Build-FieldSectionDirect "Actions" @("Missing_Documents__c","Next_Best_Action__c") "sidebar_actions"
$allRegions += $sb3.Regions

$approveVis = Build-VisibilityRule @(@{ Left = "{!Record.Final_Recommendation__c}"; Op = "EQUAL"; Right = "Approve" })
$holdVis = Build-VisibilityRule @(@{ Left = "{!Record.Final_Recommendation__c}"; Op = "EQUAL"; Right = "Hold" })
$rejectVis = Build-VisibilityRule @(@{ Left = "{!Record.Final_Recommendation__c}"; Op = "EQUAL"; Right = "Reject" })

$mainContent = Build-TabsetMain $tabsFacet "Loan Application"
$sidebarContent = $sb1.Component + (Build-BlankDirect "sidebar_blank1") + $sb2.Component +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#027e46;font-size:14px;font-weight:bold;background-color:#d4edda;padding:8px;">APPROVE — Proceed with disbursement preparation</span></p>' "sidebar_banner_approve" $approveVis) +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#856404;font-size:14px;font-weight:bold;background-color:#fff3cd;padding:8px;">HOLD — Additional review required</span></p>' "sidebar_banner_hold" $holdVis) +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#721c24;font-size:14px;font-weight:bold;background-color:#f8d7da;padding:8px;">REJECT — See decision reasons</span></p>' "sidebar_banner_reject" $rejectVis) +
    (Build-BlankDirect "sidebar_blank2") + $sb3.Component + (Build-BlankDirect "sidebar_blank3") +
    (Build-RelatedListDirect "Loan_Decisions__r" "sidebar_loan_decisions" 5) +
    (Build-RelatedListDirect "Audit_Logs__r" "sidebar_audit_logs" 5)

Build-RecordPage "Loan Application Record Page" "Loan_Application_Record_Page.flexipage-meta.xml" "Loan_Application__c" "flexipage:default__Loan_Application__c" "flexipage:recordHomeThreeColTemplateDesktop" ((Build-HighlightsHeader) + (Build-PathSubheader)) $allRegions $mainContent $sidebarContent "rightsidebar"

# ==================== PAGE 2: APPLICANT DOCUMENT ====================
Reset-FacetCounter
$allRegions = ""

$mainFields = Build-FieldSectionDirect "Document Details" @("Document_Type__c","Document_Category__c","Is_Mandatory__c","Loan_Application__c","Uploaded__c","Upload_Date__c","Verified__c","Verification_Status__c","Issue_Found__c","OCR_Confidence__c","Document_Number__c","Expiry_Date__c","Agent_Comment__c") "main_document_details" 2
$allRegions += $mainFields.Regions

$sbStatus = Build-FieldSectionDirect "Verification Summary" @("Verification_Status__c","Issue_Found__c","OCR_Confidence__c") "sidebar_verification"
$allRegions += $sbStatus.Regions
$sbComment = Build-FieldSectionDirect "Agent Notes" @("Agent_Comment__c") "sidebar_agent_comment"
$allRegions += $sbComment.Regions

$issueVis = Build-VisibilityRule @(@{ Left = "{!Record.Issue_Found__c}"; Op = "NE"; Right = "None" })

$mainContent = $mainFields.Component + (Build-RelatedListDirect "AttachedContentDocuments" "main_files" 10 "GRID")
$sidebarContent = $sbStatus.Component +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#721c24;font-size:14px;font-weight:bold;background-color:#f8d7da;padding:8px;">DOCUMENT ISSUE DETECTED — Review required</span></p>' "sidebar_issue_banner" $issueVis) +
    $sbComment.Component + (Build-FeedDirect "sidebar_feed")

Build-RecordPage "Applicant Document Record Page" "Applicant_Document_Record_Page.flexipage-meta.xml" "Applicant_Document__c" "flexipage:default__Applicant_Document__c" "flexipage:recordHomeTemplateDesktop" (Build-HighlightsHeader) $allRegions $mainContent $sidebarContent

# ==================== PAGE 3: AGENT CHECK RESULT ====================
Reset-FacetCounter
$allRegions = ""

$mainAgent = Build-FieldSectionDirect "Agent Run Details" @("Loan_Application__c","Agent_Name__c","Agent_Run_Order__c","Status__c","Result__c","Score_Impact__c","Confidence__c","Agent_Version__c") "main_agent_details" 2
$allRegions += $mainAgent.Regions
$timing = Build-FieldSectionDirect "Timing" @("Run_Started_At__c","Run_Completed_At__c","Execution_Time_Ms__c") "main_timing"
$allRegions += $timing.Regions
$output = Build-FieldSectionDirect "Agent Reason and Output" @("Reason__c","Recommendations__c") "main_output"
$allRegions += $output.Regions

$sbJson = Build-FieldSectionDirect "Raw Agent Output" @("Raw_Output_JSON__c") "sidebar_raw_json"
$allRegions += $sbJson.Regions

$mainContent = $mainAgent.Component + $timing.Component + (Build-RichTextDirect '<p><strong>Agent Reason &amp; Output</strong></p>' "main_header_rich") + $output.Component
$sidebarContent = $sbJson.Component + (Build-FeedDirect "sidebar_feed")

Build-RecordPage "Agent Check Result Record Page" "Agent_Check_Result_Record_Page.flexipage-meta.xml" "Agent_Check_Result__c" "flexipage:default__Agent_Check_Result__c" "flexipage:recordHomeTemplateDesktop" (Build-HighlightsHeader) $allRegions $mainContent $sidebarContent

# ==================== PAGE 4: RISK ASSESSMENT ====================
Reset-FacetCounter
$allRegions = ""
$tabFacets = @()

$t1 = Build-FieldSectionFacet "Bureau and Credit" @("Bureau_Score__c","Bureau_Source__c","Past_Defaults__c","Past_Bounces_12M__c","Active_Loans__c","Credit_Inquiries_6M__c") 2
$allRegions += $t1.Regions
$tabFacets += @{ Title = "Bureau & Credit"; Body = $t1.FacetName; Id = "tab_bureau"; Active = $true }

$t2 = Build-FieldSectionFacet "Risk Scoring" @("Fraud_Score__c","Identity_Verified__c","Address_Risk__c","Sector_Risk__c","Final_Risk_Score__c","Risk_Category__c") 2
$allRegions += $t2.Regions
$tabFacets += @{ Title = "Risk Scoring"; Body = $t2.FacetName; Id = "tab_scoring"; Active = $false }

$t3 = Build-FieldSectionFacet "Reasons" @("Risk_Reasons__c") 1
$allRegions += $t3.Regions
$tabFacets += @{ Title = "Reasons"; Body = $t3.FacetName; Id = "tab_reasons"; Active = $false }

$tabsFacet = New-FacetId "riskTabs"
$allRegions += Build-TabFacet $tabsFacet $tabFacets

$sbRisk = Build-FieldSectionDirect "Risk Summary" @("Loan_Application__c","Final_Risk_Score__c","Risk_Category__c") "sidebar_risk_summary"
$allRegions += $sbRisk.Regions
$riskVis = Build-VisibilityRule @(
    @{ Left = "{!Record.Risk_Category__c}"; Op = "EQUAL"; Right = "High" },
    @{ Left = "{!Record.Risk_Category__c}"; Op = "EQUAL"; Right = "Very High" }
) "1 OR 2"

$mainContent = Build-TabsetMain $tabsFacet "Risk Assessment"
$sidebarContent = $sbRisk.Component +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#721c24;font-size:14px;font-weight:bold;background-color:#f8d7da;padding:8px;">HIGH RISK — Enhanced due diligence required</span></p>' "sidebar_high_risk" $riskVis) +
    (Build-FeedDirect "sidebar_feed")

Build-RecordPage "Risk Assessment Record Page" "Risk_Assessment_Record_Page.flexipage-meta.xml" "Risk_Assessment__c" "flexipage:default__Risk_Assessment__c" "flexipage:recordHomeTemplateDesktop" (Build-HighlightsHeader) $allRegions $mainContent $sidebarContent

# ==================== PAGE 5: COMPLIANCE CHECK ====================
Reset-FacetCounter
$allRegions = ""

$mainComp = Build-FieldSectionDirect "Compliance Rule Details" @("Loan_Application__c","Rule_Name__c","Regulation_Reference__c","Rule_Category__c","Status__c","Severity__c","Description__c","Action_Required__c") "main_compliance" 2
$allRegions += $mainComp.Regions
$resolution = Build-FieldSectionDirect "Resolution" @("Resolved__c","Resolved_By__c","Resolved_At__c") "main_resolution"
$allRegions += $resolution.Regions

$sbComp = Build-FieldSectionDirect "Check Status" @("Status__c","Severity__c","Checked_At__c") "sidebar_check_status"
$allRegions += $sbComp.Regions
$critVis = Build-VisibilityRule @(
    @{ Left = "{!Record.Status__c}"; Op = "EQUAL"; Right = "Non-Compliant" },
    @{ Left = "{!Record.Severity__c}"; Op = "EQUAL"; Right = "Critical" }
) "1 AND 2"

$mainContent = $mainComp.Component + $resolution.Component
$sidebarContent = $sbComp.Component +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#721c24;font-size:14px;font-weight:bold;background-color:#f8d7da;padding:8px;">CRITICAL NON-COMPLIANCE — Immediate action required</span></p>' "sidebar_critical" $critVis) +
    (Build-FeedDirect "sidebar_feed")

Build-RecordPage "Compliance Check Record Page" "Compliance_Check_Record_Page.flexipage-meta.xml" "Compliance_Check__c" "flexipage:default__Compliance_Check__c" "flexipage:recordHomeTemplateDesktop" (Build-HighlightsHeader) $allRegions $mainContent $sidebarContent

# ==================== PAGE 6: LOAN DECISION ====================
Reset-FacetCounter
$allRegions = ""
$tabFacets = @()

$d1 = Build-FieldSectionFacet "AI Decision" @("Recommendation__c","Confidence_Score__c","Generated_By__c","AI_Model__c","Generated_At__c","Decision_Summary__c","Key_Reasons__c") 2
$allRegions += $d1.Regions
$tabFacets += @{ Title = "AI Decision"; Body = $d1.FacetName; Id = "tab_ai_decision"; Active = $true }

$d2 = Build-FieldSectionFacet "Missing and Next Actions" @("Missing_Paperwork__c","Next_Best_Action__c","Conditions__c") 1
$allRegions += $d2.Regions
$tabFacets += @{ Title = "Missing & Next Actions"; Body = $d2.FacetName; Id = "tab_actions"; Active = $false }

$d3 = Build-FieldSectionFacet "Loan Terms" @("Approved_Amount__c","Approved_Tenure__c","Suggested_Interest_Rate__c") 2
$allRegions += $d3.Regions
$tabFacets += @{ Title = "Loan Terms"; Body = $d3.FacetName; Id = "tab_terms"; Active = $false }

$d4 = Build-FieldSectionFacet "Officer Review" @("Officer_Reviewed__c","Officer_Decision__c","Officer_Comments__c","Officer_Reviewed_At__c") 2
$allRegions += $d4.Regions
$tabFacets += @{ Title = "Officer Review"; Body = $d4.FacetName; Id = "tab_officer"; Active = $false }

$tabsFacet = New-FacetId "decisionTabs"
$allRegions += Build-TabFacet $tabsFacet $tabFacets

$sbDec = Build-FieldSectionDirect "Decision Summary" @("Loan_Application__c","Recommendation__c","Confidence_Score__c") "sidebar_decision"
$allRegions += $sbDec.Regions
$approveDecVis = Build-VisibilityRule @(
    @{ Left = "{!Record.Recommendation__c}"; Op = "EQUAL"; Right = "Approve" },
    @{ Left = "{!Record.Officer_Decision__c}"; Op = "EQUAL"; Right = "Accept AI" }
) "1 AND 2"
$holdDecVis = Build-VisibilityRule @(@{ Left = "{!Record.Recommendation__c}"; Op = "EQUAL"; Right = "Hold" })
$rejectDecVis = Build-VisibilityRule @(@{ Left = "{!Record.Recommendation__c}"; Op = "EQUAL"; Right = "Reject" })

$mainContent = Build-TabsetMain $tabsFacet "Loan Decision"
$sidebarContent = $sbDec.Component +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#027e46;font-size:14px;font-weight:bold;background-color:#d4edda;padding:8px;">APPROVED — Proceed to Disbursement</span></p>' "sidebar_approved" $approveDecVis) +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#856404;font-size:14px;font-weight:bold;background-color:#fff3cd;padding:8px;">ON HOLD — Pending Additional Review</span></p>' "sidebar_on_hold" $holdDecVis) +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#721c24;font-size:14px;font-weight:bold;background-color:#f8d7da;padding:8px;">REJECTED — See Key Reasons</span></p>' "sidebar_rejected" $rejectDecVis) +
    (Build-FeedDirect "sidebar_feed")

Build-RecordPage "Loan Decision Record Page" "Loan_Decision_Record_Page.flexipage-meta.xml" "Loan_Decision__c" "flexipage:default__Loan_Decision__c" "flexipage:recordHomeTemplateDesktop" (Build-HighlightsHeader) $allRegions $mainContent $sidebarContent

# ==================== PAGE 7: LOAN PRODUCT ====================
Reset-FacetCounter
$allRegions = ""
$tabFacets = @()

$p1 = Build-FieldSectionFacet "Product Details" @("Product_Code__c","Product_Type__c","Description__c","Is_Active__c","Target_Segment__c","Launch_Date__c","Sunset_Date__c") 2
$allRegions += $p1.Regions
$tabFacets += @{ Title = "Product Details"; Body = $p1.FacetName; Id = "tab_product"; Active = $true }

$p2 = Build-FieldSectionFacet "Limits and Rates" @("Min_Loan_Amount__c","Max_Loan_Amount__c","Min_Tenure__c","Max_Tenure__c","Min_Interest_Rate__c","Max_Interest_Rate__c") 2
$allRegions += $p2.Regions
$tabFacets += @{ Title = "Limits & Rates"; Body = $p2.FacetName; Id = "tab_limits"; Active = $false }

$p3 = Build-FieldSectionFacet "Eligibility Rules" @("Min_Credit_Score__c","Min_Income_Required__c","Min_Age__c","Max_Age__c","Max_FOIR__c") 2
$allRegions += $p3.Regions
$tabFacets += @{ Title = "Eligibility Rules"; Body = $p3.FacetName; Id = "tab_eligibility"; Active = $false }

$p4 = Build-FieldSectionFacet "Fees" @("Processing_Fee_Pct__c","Prepayment_Charges__c") 2
$allRegions += $p4.Regions
$tabFacets += @{ Title = "Fees"; Body = $p4.FacetName; Id = "tab_fees"; Active = $false }

$p5 = Build-FieldSectionFacet "Required Documents" @("Required_Documents__c") 1
$allRegions += $p5.Regions
$tabFacets += @{ Title = "Required Documents"; Body = $p5.FacetName; Id = "tab_docs"; Active = $false }

$tabsFacet = New-FacetId "productTabs"
$allRegions += Build-TabFacet $tabsFacet $tabFacets

$sbProd = Build-FieldSectionDirect "Product Status" @("Is_Active__c","Product_Type__c","Product_Code__c") "sidebar_product_status"
$allRegions += $sbProd.Regions

$mainContent = Build-TabsetMain $tabsFacet "Loan Product"
$sidebarContent = $sbProd.Component + (Build-RelatedListDirect "Loan_Applications__r" "sidebar_loan_apps" 10)

Build-RecordPage "Loan Product Record Page" "Loan_Product_Record_Page.flexipage-meta.xml" "Loan_Product__c" "flexipage:default__Loan_Product__c" "flexipage:recordHomeTemplateDesktop" (Build-HighlightsHeader) $allRegions $mainContent $sidebarContent

# ==================== PAGE 8: REPAYMENT SCHEDULE ====================
Reset-FacetCounter
$allRegions = ""

$mainEmi = Build-FieldSectionDirect "EMI Schedule" @("Loan_Application__c","EMI_Number__c","Due_Date__c","EMI_Amount__c","Principal_Component__c","Interest_Component__c","Outstanding_Balance__c") "main_emi" 2
$allRegions += $mainEmi.Regions
$payment = Build-FieldSectionDirect "Payment Details" @("Status__c","Paid_Date__c","Paid_Amount__c","Payment_Mode__c","Transaction_Reference__c","Days_Overdue__c","Late_Fee__c") "main_payment" 2
$allRegions += $payment.Regions

$sbEmi = Build-FieldSectionDirect "Payment Status" @("Status__c","Due_Date__c","Days_Overdue__c") "sidebar_payment_status"
$allRegions += $sbEmi.Regions
$overdueVis = Build-VisibilityRule @(
    @{ Left = "{!Record.Status__c}"; Op = "EQUAL"; Right = "Overdue" },
    @{ Left = "{!Record.Status__c}"; Op = "EQUAL"; Right = "Bounced" }
) "1 OR 2"
$bounceVis = Build-VisibilityRule @(@{ Left = "{!Record.Status__c}"; Op = "EQUAL"; Right = "Bounced" })
$sbBounce = Build-FieldSectionDirect "Bounce Details" @("Bounce_Reason__c") "sidebar_bounce" 1 $bounceVis
$allRegions += $sbBounce.Regions

$mainContent = $mainEmi.Component + $payment.Component
$sidebarContent = $sbEmi.Component +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#721c24;font-size:14px;font-weight:bold;background-color:#f8d7da;padding:8px;">OVERDUE — Collection Action Required</span></p>' "sidebar_overdue" $overdueVis) +
    $sbBounce.Component +
    (Build-FeedDirect "sidebar_feed")

Build-RecordPage "Repayment Schedule Record Page" "Repayment_Schedule_Record_Page.flexipage-meta.xml" "Repayment_Schedule__c" "flexipage:default__Repayment_Schedule__c" "flexipage:recordHomeTemplateDesktop" (Build-HighlightsHeader) $allRegions $mainContent $sidebarContent

# ==================== PAGE 9: AUDIT LOG ====================
Reset-FacetCounter
$allRegions = ""

$mainAudit = Build-FieldSectionDirect "Audit Event" @("Loan_Application__c","Event_Type__c","Event_Source__c","Event_Timestamp__c","Severity__c","Compliance_Relevant__c") "main_audit" 2
$allRegions += $mainAudit.Regions
$change = Build-FieldSectionDirect "Change Details" @("Field_Changed__c","Old_Value__c","New_Value__c","Event_Description__c") "main_change"
$allRegions += $change.Regions
$tech = Build-FieldSectionDirect "Technical Details" @("IP_Address__c","Session_ID__c","User_Agent__c") "main_technical"
$allRegions += $tech.Regions

$sbAudit = Build-FieldSectionDirect "Actor Details" @("Performed_By__c","Agent_Name__c","Severity__c") "sidebar_actor"
$allRegions += $sbAudit.Regions
$critAuditVis = Build-VisibilityRule @(@{ Left = "{!Record.Severity__c}"; Op = "EQUAL"; Right = "Critical" })

$mainContent = $mainAudit.Component + $change.Component + $tech.Component
$sidebarContent = $sbAudit.Component +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#721c24;font-size:14px;font-weight:bold;background-color:#f8d7da;padding:8px;">CRITICAL AUDIT EVENT</span></p>' "sidebar_critical_audit" $critAuditVis) +
    (Build-FeedDirect "sidebar_feed")

Build-RecordPage "Audit Log Record Page" "Audit_Log_Record_Page.flexipage-meta.xml" "Audit_Log__c" "flexipage:default__Audit_Log__c" "flexipage:recordHomeTemplateDesktop" (Build-HighlightsHeader) $allRegions $mainContent $sidebarContent

# ==================== PAGE 10: LOAN APPLICATION HISTORY ====================
Reset-FacetCounter
$allRegions = ""
$tabFacets = @()

$h1 = Build-FieldSectionFacet "Event Details" @("Loan_Application__c","Applicant_Name__c","Event_Type__c","Event_Sub_Type__c","Event_Timestamp__c","Triggered_By__c","Performed_By__c","Agent_Name__c","Event_Description__c","Severity__c","Compliance_Relevant__c") 2
$allRegions += $h1.Regions
$tabFacets += @{ Title = "Event Details"; Body = $h1.FacetName; Id = "tab_event"; Active = $true }

$h2 = Build-FieldSectionFacet "Status Change" @("Previous_Status__c","New_Status__c","Field_Changed__c","Previous_Value__c","New_Value__c") 2
$allRegions += $h2.Regions
$tabFacets += @{ Title = "Status Change"; Body = $h2.FacetName; Id = "tab_status"; Active = $false }

$h3 = Build-FieldSectionFacet "AI and Decision Data" @("Agent_Result__c","Agent_Score_Impact__c","Risk_Score_Before__c","Risk_Score_After__c","AI_Confidence__c","Decision_Made__c","Decision_Reason__c","Missing_Documents_Snapshot__c") 2
$allRegions += $h3.Regions
$tabFacets += @{ Title = "AI & Decision Data"; Body = $h3.FacetName; Id = "tab_ai"; Active = $false }

$h4 = Build-FieldSectionFacet "Officer Action" @("Officer_Override__c","Override_Reason__c","Duration_Seconds__c") 2
$allRegions += $h4.Regions
$tabFacets += @{ Title = "Officer Action"; Body = $h4.FacetName; Id = "tab_officer"; Active = $false }

$h5 = Build-FieldSectionFacet "Technical" @("IP_Address__c","Session_ID__c","Integration_Reference__c","Is_Archived__c") 2
$allRegions += $h5.Regions
$tabFacets += @{ Title = "Technical"; Body = $h5.FacetName; Id = "tab_technical"; Active = $false }

$tabsFacet = New-FacetId "historyTabs"
$allRegions += Build-TabFacet $tabsFacet $tabFacets

$sbHist = Build-FieldSectionDirect "Event Summary" @("Event_Type__c","Triggered_By__c","Event_Timestamp__c","Severity__c") "sidebar_event_summary"
$allRegions += $sbHist.Regions
$overrideVis = Build-VisibilityRule @(@{ Left = "{!Record.Officer_Override__c}"; Op = "EQUAL"; Right = "true" })
$complianceVis = Build-VisibilityRule @(@{ Left = "{!Record.Compliance_Relevant__c}"; Op = "EQUAL"; Right = "true" })
$critHistVis = Build-VisibilityRule @(@{ Left = "{!Record.Severity__c}"; Op = "EQUAL"; Right = "Critical" })

$mainContent = Build-TabsetMain $tabsFacet "Application History"
$sidebarContent = $sbHist.Component +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#856404;font-size:14px;font-weight:bold;background-color:#fff3cd;padding:8px;">Officer Override Recorded</span></p>' "sidebar_override" $overrideVis) +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#004085;font-size:14px;font-weight:bold;background-color:#cce5ff;padding:8px;">Compliance Relevant — Included in RBI Audit Report</span></p>' "sidebar_compliance" $complianceVis) +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#721c24;font-size:14px;font-weight:bold;background-color:#f8d7da;padding:8px;">CRITICAL EVENT</span></p>' "sidebar_critical_hist" $critHistVis) +
    (Build-FeedDirect "sidebar_feed")

Build-RecordPage "Loan Application History Record Page" "Loan_Application_History_Record_Page.flexipage-meta.xml" "Loan_Application_History__c" "flexipage:default__Loan_Application_History__c" "flexipage:recordHomeTemplateDesktop" (Build-HighlightsHeader) $allRegions $mainContent $sidebarContent

# ==================== PAGE 11: ACCOUNT PERSON ====================
Reset-FacetCounter
$allRegions = ""
$tabFacets = @()

$a1 = Build-FieldSectionFacet "Personal Details" @("FirstName","LastName","PersonEmail","PersonMobilePhone","PersonBirthdate","PersonMailingAddress","PAN_Number__c","Aadhaar_Number__c","Customer_Segment__c","Employment_Status__c","Employer_Name__c","Years_At_Current_Job__c") 2
$allRegions += $a1.Regions
$tabFacets += @{ Title = "Personal Details"; Body = $a1.FacetName; Id = "tab_personal"; Active = $true }

$a2 = Build-FieldSectionFacet "Financial Profile" @("Monthly_Income__c","Annual_Income__c","Existing_EMI_Total__c","FOIR__c","Bureau_Score__c","Risk_Category__c") 2
$allRegions += $a2.Regions
$tabFacets += @{ Title = "Financial Profile"; Body = $a2.FacetName; Id = "tab_financial"; Active = $false }

$kycFields = Build-FieldSectionDirect "KYC Status" @("KYC_Status__c") "kyc_status_fields"
$allRegions += $kycFields.Regions
$kycFacet = New-FacetId "kycTab"
$allRegions += @"
    <!-- KYC tab: status field plus related loan applications for document traceability -->
    <flexiPageRegions>
        <itemInstances>
$($kycFields.Component)
        </itemInstances>
        <itemInstances>
$(Build-RelatedListDirect "Loan_Applications__r" "kyc_loan_apps" 10)
        </itemInstances>
        <name>$kycFacet</name>
        <type>Facet</type>
    </flexiPageRegions>
"@
$tabFacets += @{ Title = "KYC Status"; Body = $kycFacet; Id = "tab_kyc"; Active = $false }

$loanAppsFacet = New-FacetId "loanApps"
$allRegions += Build-DynamicRelatedListFacet $loanAppsFacet "Loan_Applications__r" @("Name","Loan_Amount__c","Loan_Product__c","Status__c","Final_Recommendation__c","Application_Date__c") 25
$tabFacets += @{ Title = "Loan Applications"; Body = $loanAppsFacet; Id = "tab_loans"; Active = $false }

$feedFacet = New-FacetId "accountFeed"
$allRegions += Build-FeedFacet $feedFacet
$tabFacets += @{ Title = "Standard.Tab.collaborate"; Body = $feedFacet; Id = "tab_activity"; Active = $false }

$tabsFacet = New-FacetId "accountTabs"
$allRegions += Build-TabFacet $tabsFacet $tabFacets

$sbAcc = Build-FieldSectionDirect "Applicant Risk Profile" @("KYC_Status__c","Bureau_Score__c","Risk_Category__c") "sidebar_applicant_risk"
$allRegions += $sbAcc.Regions
$sbFin = Build-FieldSectionDirect "Income Summary" @("Monthly_Income__c","FOIR__c") "sidebar_income"
$allRegions += $sbFin.Regions
$highRiskVis = Build-VisibilityRule @(@{ Left = "{!Record.Risk_Category__c}"; Op = "EQUAL"; Right = "High" })

$mainContent = Build-TabsetMain $tabsFacet "Applicant Account"
$sidebarContent = $sbAcc.Component +
    (Build-RichTextDirect '<p style="text-align:center;"><span style="color:#721c24;font-size:14px;font-weight:bold;background-color:#f8d7da;padding:8px;">HIGH RISK APPLICANT</span></p>' "sidebar_high_risk_acc" $highRiskVis) +
    $sbFin.Component + (Build-ActivityDirect "sidebar_activity")

Build-RecordPage "Account Person Record Page" "Account_Person_Record_Page.flexipage-meta.xml" "Account" "flexipage:default__Account" "flexipage:recordHomeThreeColTemplateDesktop" (Build-HighlightsHeader) $allRegions $mainContent $sidebarContent "rightsidebar"

# ==================== PAGE 12: NBFC LOAN DASHBOARD APP PAGE ====================
$dashboardRegions = @"
    <!-- Column 1: portfolio status charts for loan officers -->
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>reportName</name>
                    <value>NBFC_Pending_Applications_by_Status</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>hideOnError</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>openLinksInNewWindow</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentName>flexipage:reportChart</componentName>
                <identifier>region1_report_pending_status</identifier>
            </componentInstance>
        </itemInstances>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>reportName</name>
                    <value>NBFC_Risk_Score_Distribution</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>hideOnError</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>openLinksInNewWindow</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentName>flexipage:reportChart</componentName>
                <identifier>region1_report_risk_score</identifier>
            </componentInstance>
        </itemInstances>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>reportName</name>
                    <value>NBFC_Applications_by_Loan_Product</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>hideOnError</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>openLinksInNewWindow</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentName>flexipage:reportChart</componentName>
                <identifier>region1_report_by_product</identifier>
            </componentInstance>
        </itemInstances>
        <mode>Replace</mode>
        <name>region1</name>
        <type>Region</type>
    </flexiPageRegions>
    <!-- Column 2: volume and document trend charts -->
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>reportName</name>
                    <value>NBFC_Daily_Applications_Volume</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>hideOnError</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>openLinksInNewWindow</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentName>flexipage:reportChart</componentName>
                <identifier>region2_report_daily_volume</identifier>
            </componentInstance>
        </itemInstances>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>reportName</name>
                    <value>NBFC_Missing_Documents_Frequency</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>hideOnError</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>openLinksInNewWindow</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentName>flexipage:reportChart</componentName>
                <identifier>region2_report_missing_docs</identifier>
            </componentInstance>
        </itemInstances>
        <mode>Replace</mode>
        <name>region2</name>
        <type>Region</type>
    </flexiPageRegions>
    <!-- Column 3: loan officer work queue -->
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>entityName</name>
                    <value>Loan_Application__c</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>filterName</name>
                    <value>NBFC_Under_Review_Queue</value>
                </componentInstanceProperties>
                <componentName>flexipage:filterListCard</componentName>
                <identifier>region3_work_queue</identifier>
            </componentInstance>
        </itemInstances>
        <mode>Replace</mode>
        <name>region3</name>
        <type>Region</type>
    </flexiPageRegions>
"@

Build-AppPage "NBFC Loan Dashboard" "NBFC_Loan_Dashboard_App_Page.flexipage-meta.xml" "flexipage:appHomeTemplateDesktopThreeColumns" $dashboardRegions

# ==================== PAGE 13: NBFC AGENT MONITOR APP PAGE ====================
$monitorRegions = @"
    <!-- Left column: recent agent check results across all applications -->
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>entityName</name>
                    <value>Agent_Check_Result__c</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>filterName</name>
                    <value>NBFC_Recent_Agent_Runs</value>
                </componentInstanceProperties>
                <componentName>flexipage:filterListCard</componentName>
                <identifier>region1_agent_runs</identifier>
            </componentInstance>
        </itemInstances>
        <mode>Replace</mode>
        <name>region1</name>
        <type>Region</type>
    </flexiPageRegions>
    <!-- Right column: agent performance analytics -->
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>reportName</name>
                    <value>NBFC_Agent_Pass_Fail_Rates</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>hideOnError</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>openLinksInNewWindow</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentName>flexipage:reportChart</componentName>
                <identifier>region2_report_pass_fail</identifier>
            </componentInstance>
        </itemInstances>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>reportName</name>
                    <value>NBFC_Avg_Agent_Execution_Time</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>hideOnError</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentInstanceProperties>
                    <name>openLinksInNewWindow</name>
                    <value>true</value>
                </componentInstanceProperties>
                <componentName>flexipage:reportChart</componentName>
                <identifier>region2_report_exec_time</identifier>
            </componentInstance>
        </itemInstances>
        <mode>Replace</mode>
        <name>region2</name>
        <type>Region</type>
    </flexiPageRegions>
"@

Build-AppPage "NBFC Agent Monitor" "NBFC_Agent_Monitor_App_Page.flexipage-meta.xml" "flexipage:appHomeTemplateDesktopTwoColumns" $monitorRegions

# ==================== SUMMARY ====================
$created = Get-ChildItem $out -Filter "*.flexipage-meta.xml" | Sort-Object Name
Write-Host "`nGenerated $($created.Count) FlexiPage files in:`n  $out`n"
$created | ForEach-Object { Write-Host "  - $($_.Name)" }
