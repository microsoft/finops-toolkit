<#
.SYNOPSIS
This script sets up the necessary dependencies for the Azure Optimization Engine to collect the data required for the several Azure benefits workbooks.

.DESCRIPTION
This script sets up the necessary dependencies for the Azure Optimization Engine to collect the data required for the several Azure benefits workbooks.
It will ask for the customer type (EA or MCA), the billing account ID, the billing profile ID (if MCA), and the consumption currency code. It will then grant
the necessary roles to the Azure Optimization Engine managed identity and set up the required variables in the Automation Account.

.PARAMETER AzureEnvironment
The Azure environment to use. Possible values are AzureCloud, AzureChinaCloud, AzureUSGovernment.

.PARAMETER AutomationAccountName
The name of the Automation Account where the Azure Optimization Engine is deployed.

.PARAMETER ResourceGroupName
The name of the Resource Group where the Automation Account is located.

.EXAMPLE
.\Setup-BenefitsUsageDependencies.ps1 -AutomationAccountName "MyAutomationAccount" -ResourceGroupName "MyResourceGroup"

.LINK
https://aka.ms/AzureOptimizationEngine/commitmentssetup
#>
param(
    [Parameter(Mandatory = $false)]
    [String] $AzureEnvironment = "AzureCloud",

    [Parameter(Mandatory = $true)]
    [String] $AutomationAccountName,

    [Parameter(Mandatory = $true)]
    [String] $ResourceGroupName
)

$ErrorActionPreference = "Stop"

$ctx = Get-AzContext
if (-not($ctx)) {
    Connect-AzAccount -Environment $AzureEnvironment
    $ctx = Get-AzContext
}
else {
    if ($ctx.Environment.Name -ne $AzureEnvironment) {
        Disconnect-AzAccount -ContextName $ctx.Name
        Connect-AzAccount -Environment $AzureEnvironment
        $ctx = Get-AzContext
    }
}

try {
    $scheduledRunbooks = Get-AzAutomationScheduledRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName
}
catch {
    throw "$AutomationAccountName Automation Account not found in Resource Group $ResourceGroupName in Subscription $($ctx.Subscription.Name). If we are not in the right subscription, use Set-AzContext to switch to the correct one."
}

if (-not($scheduledRunbooks)) {
    throw "The $AutomationAccountName Automation Account does not contain any scheduled runbook. It might not be associated to the Azure Optimization Engine."
}

$automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName
$principalId = $automationAccount.Identity.PrincipalId
$tenantId = $automationAccount.Identity.TenantId

if (-not($principalId))
{
    throw "The $AutomationAccountName Automation Account does not have a managed identity and probably is not associated to the latest version of Azure Optimization Engine. Please, upgrade it before setting up benefits usage dependencies (more details: https://github.com/helderpinto/AzureOptimizationEngine#upgrade)."
}

$pricesheetSchedule = Get-AzAutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name "AzureOptimization_ExportPricesWeekly" -ErrorAction SilentlyContinue
if (-not($pricesheetSchedule)) {
    throw "The Azure Optimization Engine is in an older version. Please, upgrade it before setting up benefits usage dependencies (more details: https://github.com/helderpinto/AzureOptimizationEngine#upgrade)."
}

$mcaBillingAccountIdRegex = "([A-Za-z0-9]+(-[A-Za-z0-9]+)+):([A-Za-z0-9]+(-[A-Za-z0-9]+)+)_[0-9]{4}-[0-9]{2}-[0-9]{2}"
$mcaBillingProfileIdRegex = "([A-Za-z0-9]+(-[A-Za-z0-9]+)+)"

$customerType = Read-Host "Are you an Enterprise Agreement (EA), Microsoft Customer Agreement (MCA), or other type (Other) of customer? Please, type EA, MCA, or Other"

switch ($customerType) {
    "EA" {
        $billingAccountId = Read-Host "Please, enter your Enterprise Agreement Billing Account ID (e.g. 12345678)"
        try
        {
            [int32]::Parse($billingAccountId) | Out-Null
        }
        catch
        {
            throw "The Enterprise Agreement Billing Account ID must be a number (e.g. 12345678)."
        }
        Write-Host "Granting the Enterprise Enrollment Reader role to the AOE Managed Identity..." -ForegroundColor Green
        $uri = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingRoleAssignments?api-version=2019-10-01-preview"
        $roleAssignmentResponse = Invoke-AzRestMethod -Method GET -Uri $uri
        if (-not($roleAssignmentResponse.StatusCode -eq 200))
        {
            throw "The Enterprise Enrollment Reader role could not be verified. Status Code: $($roleAssignmentResponse.StatusCode); Response: $($roleAssignmentResponse.Content)"
        }
        $roleAssignments = ($roleAssignmentResponse.Content | ConvertFrom-Json).value
        if (-not($roleAssignments | Where-Object { $_.properties.principalId -eq $principalId -and $_.properties.roleDefinitionId -eq "/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingRoleDefinitions/24f8edb6-1668-4659-b5e2-40bb5f3a7d7e" }))
        {
            $billingRoleAssignmentName = ([System.Guid]::NewGuid()).Guid
            $uri = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingRoleAssignments/$($billingRoleAssignmentName)?api-version=2019-10-01-preview"
            $body = "{`"properties`": {`"principalId`":`"$principalId`",`"principalTenantId`":`"$tenantId`",`"roleDefinitionId`":`"/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingRoleDefinitions/24f8edb6-1668-4659-b5e2-40bb5f3a7d7e`"}}"
            $roleAssignmentResponse = Invoke-AzRestMethod -Method PUT -Uri $uri -Payload $body
            if (-not($roleAssignmentResponse.StatusCode -in (200,201,202)))
            {
                throw "The Enterprise Enrollment Reader role could not be granted. Status Code: $($roleAssignmentResponse.StatusCode); Response: $($roleAssignmentResponse.Content)"
            }
        }
        else
        {
            Write-Host "Role was already granted before." -ForegroundColor Green
        }
        break
    }
    "MCA" {
        $billingAccountId = Read-Host "Please, enter your Microsoft Customer Agreement Billing Account ID (e.g. <guid>:<guid>_YYYY-MM-DD)"
        if (-not($billingAccountId -match $mcaBillingAccountIdRegex))
        {
            throw "The Microsoft Customer Agreement Billing Account ID must be in the format <guid>:<guid>_YYYY-MM-DD."
        }
        $billingProfileId = Read-Host "Please, enter your Billing Profile ID (e.g. ABCD-DEF-GHI-JKL)"
        if (-not($billingProfileId -match $mcaBillingProfileIdRegex))
        {
            throw "The Microsoft Customer Agreement Billing Profile ID must be in the format ABCD-DEF-GHI-JKL."
        }
        Write-Host "Granting the Billing Profile Reader role to the AOE Managed Identity..." -ForegroundColor Green
        $uri = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingProfiles/$billingProfileId/billingRoleAssignments?api-version=2019-10-01-preview"
        $roleAssignmentResponse = Invoke-AzRestMethod -Method GET -Uri $uri
        if (-not($roleAssignmentResponse.StatusCode -eq 200))
        {
            throw "The Billing Profile Reader role could not be verified. Status Code: $($roleAssignmentResponse.StatusCode); Response: $($roleAssignmentResponse.Content)"
        }
        $roleAssignments = ($roleAssignmentResponse.Content | ConvertFrom-Json).value
        if (-not($roleAssignments | Where-Object { $_.properties.principalId -eq $principalId -and $_.properties.roleDefinitionId -eq "/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingProfiles/$billingProfileId/billingRoleDefinitions/40000000-aaaa-bbbb-cccc-100000000002" }))
        {
            $uri = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingProfiles/$billingProfileId/createBillingRoleAssignment?api-version=2020-12-15-privatepreview"
            $body = "{`"principalId`":`"$principalId`",`"principalTenantId`":`"$tenantId`",`"roleDefinitionId`":`"/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingProfiles/$billingProfileId/billingRoleDefinitions/40000000-aaaa-bbbb-cccc-100000000002`"}"
            $roleAssignmentResponse = Invoke-AzRestMethod -Method POST -Uri $uri -Payload $body
            if (-not($roleAssignmentResponse.StatusCode -in (200,201,202)))
            {
                throw "The Billing Profile Reader role could not be granted. Status Code: $($roleAssignmentResponse.StatusCode); Response: $($roleAssignmentResponse.Content)"
            }
        }
        else
        {
            Write-Host "Role was already granted before." -ForegroundColor Green
        }
        break
    }
    Default {
        throw "Only EA and MCA customers are supported at this time."
    }
}

Write-Output "Setting up the Billing Account ID variable..."
$billingAccountIdVarName = "AzureOptimization_BillingAccountID"
$billingAccountIdVar = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingAccountIdVarName -ErrorAction SilentlyContinue
if (-not($billingAccountIdVar))
{
    New-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingAccountIdVarName -Value $billingAccountId -Encrypted $false | Out-Null
}
else
{
    Set-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingAccountIdVarName -Value $billingAccountId -Encrypted $false | Out-Null
}

if ($billingProfileId)
{
    Write-Output "Setting up the Billing Profile ID variable..."
    $billingProfileIdVarName = "AzureOptimization_BillingProfileID"
    $billingProfileIdVar = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingProfileIdVarName -ErrorAction SilentlyContinue
    if (-not($billingProfileIdVar))
    {
        New-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingProfileIdVarName -Value $billingProfileId -Encrypted $false | Out-Null
    }
    else
    {
        Set-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingProfileIdVarName -Value $billingProfileId -Encrypted $false | Out-Null
    }
}

$currencyCode = Read-Host "Please, enter your consumption currency code (e.g. EUR, USD, etc.)"
Write-Output "Setting up the consumption currency code variable..."
$currencyCodeVarName = "AzureOptimization_RetailPricesCurrencyCode"
$currencyCodeVar = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $currencyCodeVarName -ErrorAction SilentlyContinue
if (-not($currencyCodeVar))
{
    New-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $currencyCodeVarName -Value $currencyCode -Encrypted $false | Out-Null
}
else
{
    Set-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $currencyCodeVarName -Value $currencyCode -Encrypted $false | Out-Null
}

Write-Host "DONE" -ForegroundColor Green