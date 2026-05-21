#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Deploy anomaly alerts to all subscriptions in a management group.

.DESCRIPTION
    Deploy anomaly alerts to all subscriptions in the specified management group with
    intelligent pagination support for large enterprise environments. The script uses
    Azure Resource Graph to discover subscriptions and deploys alerts in batches.

.PARAMETER TenantId
    Azure tenant ID to connect to.

.PARAMETER ManagementGroup
    Management group name to query for subscriptions.

.PARAMETER EmailRecipients
    Array of email addresses that'll receive anomaly notifications.

.PARAMETER NotificationEmail
    Primary notification email address for alerts.

.PARAMETER WhatIf
    Preview changes without deploying.

.PARAMETER Quiet
    Suppress Azure PowerShell warning messages for cleaner output.

.EXAMPLE
    ./Deploy-BulkALZ.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -ManagementGroup "ALZ" -EmailRecipients @("admin@company.com") -NotificationEmail "alerts@company.com"
    
    Deploy anomaly alerts to all subscriptions in the ALZ management group.

.EXAMPLE
    ./Deploy-BulkALZ.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -ManagementGroup "ALZ" -EmailRecipients @("admin@company.com") -NotificationEmail "alerts@company.com" -WhatIf
    
    Preview what would be deployed without making actual changes.

.EXAMPLE
    ./Deploy-BulkALZ.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -ManagementGroup "ALZ" -EmailRecipients @("admin@company.com") -NotificationEmail "alerts@company.com" -Quiet
    
    Deploy with minimal output for automated scenarios.

.NOTES
    - Requires Azure PowerShell and Azure Resource Graph modules
    - Supports intelligent pagination for thousands of subscriptions
    - Automatically handles Azure Resource Graph's 1,000 result limit
    - User must have appropriate permissions across target subscriptions
#>

param(
    [Parameter(Mandatory=$true)]
    [string[]]$EmailRecipients,
    
    [Parameter(Mandatory=$true)]
    [string]$NotificationEmail,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$true)]
    [string]$ManagementGroup,
    
    [switch]$WhatIf,
    
    [switch]$Quiet
)

Write-Host "=== Bulk anomaly alert deployment ===" -ForegroundColor Cyan
Write-Host "Target: $ManagementGroup management group" -ForegroundColor Yellow
Write-Host "Tenant: $TenantId" -ForegroundColor Yellow
Write-Host "Mode: $(if ($WhatIf) { 'What-if (preview)' } else { 'Deploy' })" -ForegroundColor Yellow

# Suppress Azure PowerShell warnings if Quiet mode is enabled
if ($Quiet) {
    $WarningPreference = 'SilentlyContinue'
}

# Connect to target tenant
Write-Host "Connecting to tenant..." -ForegroundColor Yellow
Connect-AzAccount -TenantId $tenantId

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
        $pageResults = Search-AzGraph -Query $query -ManagementGroup $managementGroup -First $pageSize
    } else {
        $pageResults = Search-AzGraph -Query $query -ManagementGroup $managementGroup -First $pageSize -Skip $skip
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
if (!$WhatIf) {
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

foreach ($sub in $subscriptions) {
    Write-Host "Deploying to: $($sub.name)" -ForegroundColor Cyan
    
    try {
        if ($WhatIf) {
            if ($Quiet) {
                ./Deploy-AnomalyAlert.ps1 -SubscriptionId $sub.subscriptionId -EmailRecipients $EmailRecipients -NotificationEmail $NotificationEmail -WhatIf -Force -Quiet -WarningAction SilentlyContinue
            } else {
                ./Deploy-AnomalyAlert.ps1 -SubscriptionId $sub.subscriptionId -EmailRecipients $EmailRecipients -NotificationEmail $NotificationEmail -WhatIf -Force -Quiet
            }
        } else {
            if ($Quiet) {
                ./Deploy-AnomalyAlert.ps1 -SubscriptionId $sub.subscriptionId -EmailRecipients $EmailRecipients -NotificationEmail $NotificationEmail -Force -Quiet -WarningAction SilentlyContinue
            } else {
                ./Deploy-AnomalyAlert.ps1 -SubscriptionId $sub.subscriptionId -EmailRecipients $EmailRecipients -NotificationEmail $NotificationEmail -Force -Quiet
            }
        }
        Write-Host "✅ Success: $($sub.name)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed: $($sub.name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Green
