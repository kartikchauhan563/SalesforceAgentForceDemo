#Requires -Version 5.1
<#
.SYNOPSIS
    Loads NBFC loan origination seed data into a Salesforce org.

.DESCRIPTION
    Deploys NBFCSeedDataLoader (if needed) and executes Apex seed logic.
    Scenarios:
      minimal  - 3 applicants, 1 app each, basic documents
      standard - 5 applicants, 1 app each, partial agent data (default)
      demo     - 8 applicants, 2 apps each, full agent/decision/repayment data

.PARAMETER Scenario
    Seed scenario: minimal, standard, or demo.

.PARAMETER ApplicantCount
    Override number of applicant accounts to create.

.PARAMETER ApplicationsPerApplicant
    Override loan applications per applicant.

.PARAMETER TargetOrg
    Salesforce org alias or username (sf --target-org).

.PARAMETER SkipDeploy
    Skip deploying NBFCSeedDataLoader before running.

.PARAMETER DryRun
    Deploy validation only; do not execute seed Apex.

.EXAMPLE
    .\Load-NBFCSeedData.ps1 -Scenario demo

.EXAMPLE
    .\Load-NBFCSeedData.ps1 -Scenario standard -ApplicantCount 10 -TargetOrg mySandbox
#>
[CmdletBinding()]
param(
    [ValidateSet('minimal', 'standard', 'demo')]
    [string]$Scenario = 'standard',

    [int]$ApplicantCount = 0,

    [int]$ApplicationsPerApplicant = 0,

    [string]$TargetOrg = '',

    [switch]$SkipDeploy,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$classesDir = Join-Path $projectRoot 'force-app\main\default\classes'
$apexFile = Join-Path $scriptRoot 'apex\RunNBFCSeedData.apex'

function Write-Step([string]$Message) {
    Write-Host "[NBFC Seed] $Message" -ForegroundColor Cyan
}

function Get-SfBaseArgs() {
    if ([string]::IsNullOrWhiteSpace($TargetOrg)) {
        return @()
    }
    return @('--target-org', $TargetOrg)
}

function Assert-SfCli {
    $sf = Get-Command sf -ErrorAction SilentlyContinue
    if (-not $sf) {
        throw 'Salesforce CLI (sf) not found. Install from https://developer.salesforce.com/tools/salesforcecli'
    }
}

function Deploy-SeedLoader {
    Write-Step 'Deploying NBFCSeedDataLoader and dependencies...'
    $deployArgs = @(
        'project', 'deploy', 'start',
        '--source-dir', $classesDir,
        '--metadata', 'ApexClass:NBFCSeedDataLoader',
        '--metadata', 'ApexClass:NBFCSeedDataLoaderTest',
        '--metadata', 'ApexClass:AccountFieldHelper'
    ) + (Get-SfBaseArgs)
    if ($DryRun) {
        $deployArgs += '--dry-run'
    }
    & sf @deployArgs
    if ($LASTEXITCODE -ne 0) {
        throw 'Deploy failed. Ensure NBFC metadata and Apex handlers are deployed first.'
    }
}

function Build-ApexScript {
    $countLine = if ($ApplicantCount -gt 0) { "req.applicantCount = $ApplicantCount;" } else { '' }
    $appsLine = if ($ApplicationsPerApplicant -gt 0) { "req.applicationsPerApplicant = $ApplicationsPerApplicant;" } else { '' }
    return @"
NBFCSeedDataLoader.LoadRequest req = new NBFCSeedDataLoader.LoadRequest();
req.scenario = '$Scenario';
$countLine
$appsLine
NBFCSeedDataLoader.LoadResult result = NBFCSeedDataLoader.load(req);
System.debug('=== NBFC SEED LOAD COMPLETE ===');
System.debug('Scenario: $Scenario');
System.debug('Message: ' + result.message);
System.debug('Applicants created: ' + result.applicantsCreated);
System.debug('Products created/ reused: ' + result.productsCreated);
System.debug('Applications created: ' + result.applicationsCreated);
System.debug('Child records created: ' + result.childRecordsCreated);
"@
}

function Invoke-SeedApex {
    $tempApex = Join-Path $env:TEMP ("RunNBFCSeedData_{0}.apex" -f ([Guid]::NewGuid().ToString('N')))
    try {
        [System.IO.File]::WriteAllText($tempApex, (Build-ApexScript), (New-Object System.Text.UTF8Encoding $false))
        Write-Step "Running seed load (scenario: $Scenario)..."
        $runArgs = @('apex', 'run', '--file', $tempApex) + (Get-SfBaseArgs)
        & sf @runArgs
        if ($LASTEXITCODE -ne 0) {
            throw 'Apex seed execution failed. Check debug logs in the org.'
        }
    }
    finally {
        if (Test-Path $tempApex) {
            Remove-Item $tempApex -Force
        }
    }
}

# --- Main ---
Assert-SfCli
Write-Step "Project root: $projectRoot"

if (-not $SkipDeploy) {
    Deploy-SeedLoader
}

if ($DryRun) {
    Write-Step 'Dry run complete (deploy validated, seed not executed).'
    exit 0
}

Invoke-SeedApex
Write-Step 'Done. Open Loan Application records in the org to verify seed data.'
