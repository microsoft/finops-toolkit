#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Deploy budgets to all subscriptions in a management group.

.DESCRIPTION
    Deploy budgets to all subscriptions in the specified management group with
    intelligent pagination support for large enterprise environments. The script uses
    Azure Resource Graph to discover subscriptions and deploys budgets in batches.
    Assumes user is already authenticated via Connect-AzAccount.

.PARAMETER ManagementGroup
    Management group name to query for subscriptions.

.PARAMETER ContactEmails
    Array of email addresses that'll receive budget notifications.

.PARAMETER BudgetName
    Name of the budget. Defaults to 'SubscriptionBudget'.

.PARAMETER Amount
    The total budget amount in the billing currency. Defaults to 1000.

.PARAMETER TimeGrain
    Budget reset period: Monthly, Quarterly, or Annually. Defaults to Monthly.

.PARAMETER StartDate
    Budget start date in YYYY-MM-DD format. Must be first of month.
    Defaults to first of next month.

.PARAMETER EndDate
    Budget end date in YYYY-MM-DD format. Defaults to one year from start date.

.PARAMETER WhatIf
    Preview changes without deploying.

.PARAMETER Quiet
    Suppress Azure PowerShell warning messages for cleaner output.

.EXAMPLE
    ./Deploy-BulkBudgets.ps1 -ManagementGroup "ALZ" -ContactEmails @("admin@company.com") -Amount 5000

    Deploy $5000 monthly budgets to all subscriptions in the ALZ management group.

.EXAMPLE
    ./Deploy-BulkBudgets.ps1 -ManagementGroup "ALZ" -ContactEmails @("admin@company.com") -Amount 10000 -TimeGrain Quarterly -WhatIf

    Preview quarterly budget deployment without making actual changes.

.EXAMPLE
    ./Deploy-BulkBudgets.ps1 -ManagementGroup "ALZ" -ContactEmails @("admin@company.com") -Quiet

    Deploy with minimal output for automated scenarios (uses BudgetAmount tag or $10 default).

.NOTES
    - Requires Azure PowerShell and Azure Resource Graph modules
    - Supports intelligent pagination for thousands of subscriptions
    - Automatically handles Azure Resource Graph's 1,000 result limit
    - User must have appropriate permissions across target subscriptions
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ManagementGroup,

    [Parameter(Mandatory=$true)]
    [string[]]$ContactEmails,

    [Parameter(Mandatory=$false)]
    [string]$BudgetName = 'SubscriptionBudget',

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Amount,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Monthly', 'Quarterly', 'Annually')]
    [string]$TimeGrain = 'Monthly',

    [Parameter(Mandatory=$false)]
    [string]$StartDate,

    [Parameter(Mandatory=$false)]
    [string]$EndDate,

    [Parameter(Mandatory=$false)]
    [string[]]$ContactRoles = @('Owner', 'Contributor'),

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 1000)]
    [int]$FirstThreshold = 50,

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 1000)]
    [int]$SecondThreshold = 75,

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 1000)]
    [int]$ThirdThreshold = 90,

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 1000)]
    [int]$ForecastedThreshold = 100,

    [switch]$WhatIf,

    [switch]$Quiet,

    [switch]$Force
)

# Set default dates if not provided
if (-not $StartDate) {
    $today = Get-Date
    $nextMonth = $today.AddMonths(1)
    $firstOfMonth = Get-Date -Year $nextMonth.Year -Month $nextMonth.Month -Day 1
    $StartDate = $firstOfMonth.ToString('yyyy-MM-dd')
}

if (-not $EndDate) {
    $start = [DateTime]::Parse($StartDate)
    $EndDate = $start.AddYears(1).ToString('yyyy-MM-dd')
}

Write-Host "=== Bulk budget deployment ===" -ForegroundColor Cyan
Write-Host "Target: $ManagementGroup management group" -ForegroundColor Yellow
if ($PSBoundParameters.ContainsKey('Amount')) {
    Write-Host "Budget: $Amount ($TimeGrain) - explicit override" -ForegroundColor Yellow
} else {
    Write-Host "Budget: Per-subscription BudgetAmount tag, default `$10 ($TimeGrain)" -ForegroundColor Yellow
}
Write-Host "Period: $StartDate to $EndDate" -ForegroundColor Yellow
Write-Host "Mode: $(if ($WhatIf) { 'What-if (preview)' } else { 'Deploy' })" -ForegroundColor Yellow

# Suppress Azure PowerShell warnings if Quiet mode is enabled
if ($Quiet) {
    $WarningPreference = 'SilentlyContinue'
}

# Verify Azure connection (assume already logged in)
$context = Get-AzContext
if (-not $context) {
    Write-Host "Not connected to Azure. Please run 'Connect-AzAccount' first." -ForegroundColor Red
    exit 1
}

# Get subscriptions
Write-Host "Finding subscriptions in $ManagementGroup management group..." -ForegroundColor Yellow

# Handle pagination for large result sets
$allSubscriptions = @()
$skip = 0
$pageSize = 1000

do {
    Write-Host "Querying subscriptions (page $([math]::Floor($skip / $pageSize) + 1))..." -ForegroundColor Gray

    $query = "ResourceContainers | where type =~ 'microsoft.resources/subscriptions' | where properties.state == 'Enabled' | project subscriptionId, name"

    if ($skip -eq 0) {
        $pageResults = Search-AzGraph -Query $query -ManagementGroup $ManagementGroup -First $pageSize
    } else {
        $pageResults = Search-AzGraph -Query $query -ManagementGroup $ManagementGroup -First $pageSize -Skip $skip
    }

    if ($pageResults) {
        $allSubscriptions += $pageResults
        $skip += $pageResults.Count
        Write-Host "Found $($pageResults.Count) subscriptions in this page (total: $($allSubscriptions.Count))" -ForegroundColor Gray
    }

    # Continue if we got a full page (indicating there might be more)
} while ($pageResults -and $pageResults.Count -eq $pageSize)

$subscriptions = $allSubscriptions
Write-Host "Total subscriptions found: $($subscriptions.Count)" -ForegroundColor Green

if (!$subscriptions -or $subscriptions.Count -eq 0) {
    Write-Host "No subscriptions found!" -ForegroundColor Red
    exit 1
}

Write-Host "Subscriptions to deploy to:" -ForegroundColor Green
foreach ($sub in $subscriptions | Select-Object -First 10) {
    Write-Host "  - $($sub.name)" -ForegroundColor White
}

if ($subscriptions.Count -gt 10) {
    Write-Host "  ... and $($subscriptions.Count - 10) more" -ForegroundColor Gray
}

# Confirm deployment
if (!$WhatIf -and !$Force) {
    Write-Host ""
    $confirm = Read-Host "Deploy to all subscriptions? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Deploy to each subscription
Write-Host ""
Write-Host "Starting deployment..." -ForegroundColor Green

$successCount = 0
$failCount = 0

foreach ($sub in $subscriptions) {
    Write-Host "Deploying to: $($sub.name)" -ForegroundColor Cyan

    try {
        $deployParams = @{
            SubscriptionId = $sub.subscriptionId
            BudgetName = $BudgetName
            TimeGrain = $TimeGrain
            StartDate = $StartDate
            EndDate = $EndDate
            ContactEmails = $ContactEmails
            ContactRoles = $ContactRoles
            FirstThreshold = $FirstThreshold
            SecondThreshold = $SecondThreshold
            ThirdThreshold = $ThirdThreshold
            ForecastedThreshold = $ForecastedThreshold
            Force = $true
            Quiet = $true
        }

        # Only pass Amount if explicitly provided; otherwise let Deploy-Budget.ps1 use tag/default
        if ($PSBoundParameters.ContainsKey('Amount')) {
            $deployParams.Add('Amount', $Amount)
        }

        if ($WhatIf) {
            $deployParams.Add('WhatIf', $true)
        }

        if ($Quiet) {
            & "$PSScriptRoot/Deploy-Budget.ps1" @deployParams -WarningAction SilentlyContinue
        } else {
            & "$PSScriptRoot/Deploy-Budget.ps1" @deployParams
        }

        Write-Host "✅ Success: $($sub.name)" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "❌ Failed: $($sub.name) - $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "  Succeeded: $successCount" -ForegroundColor Green
Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Green' })
