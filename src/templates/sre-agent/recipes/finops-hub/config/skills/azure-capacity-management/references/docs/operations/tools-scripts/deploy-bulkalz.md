---
title: Deploy-BulkALZ.ps1
parent: Tools & scripts
nav_order: 7
---

# Deploy-BulkALZ.ps1

Enterprise-scale deployment of anomaly alerts to all subscriptions in a management group with intelligent pagination support.

## Overview

This PowerShell script deploys cost anomaly alerts across entire Azure Landing Zone management groups, handling hundreds or thousands of subscriptions efficiently. It uses Azure Resource Graph for subscription discovery and implements intelligent pagination to work within Azure's query limits.

### Key capabilities

- **Management group targeting**: Deploy to entire hierarchy at once
- **Azure Resource Graph integration**: Efficient subscription discovery
- **Intelligent pagination**: Automatically handles Azure's 1,000 result limit
- **Progressive discovery**: Real-time progress reporting
- **Performance optimization**: Quiet mode for faster bulk operations
- **Safety confirmations**: Prevents accidental enterprise-wide changes

### When to use this script

- Enterprise-scale anomaly alert deployment
- Management group-wide rollouts
- Automated governance implementation
- Large estates with 100+ subscriptions
- Azure Landing Zone (ALZ) implementations

## Prerequisites

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Force -AllowClobber

# Install Azure Resource Graph module (required)
Install-Module -Name Az.ResourceGraph -Force -AllowClobber

# Authenticate to Azure
Connect-AzAccount -Tenant "YOUR-TENANT-ID"

# Verify management group access
Get-AzManagementGroup | Select-Object Name, DisplayName

# Verify Resource Graph access
Search-AzGraph -Query "resourcecontainers | where type == 'microsoft.resources/subscriptions' | limit 1"
```

## Parameters

| Parameter | Type | Description | Required |
|-----------|------|-------------|----------|
| **TenantId** | String | Azure tenant ID (GUID) | Yes |
| **ManagementGroup** | String | Target management group name | Yes |
| **EmailRecipients** | String[] | Alert recipient email addresses | Yes |
| **NotificationEmail** | String | Primary notification email | Yes |
| **WhatIf** | Switch | Preview mode without deployment | No |
| **Quiet** | Switch | Suppress Azure warnings | No |

## Usage examples

### Basic deployment to management group

```powershell
.\Deploy-BulkALZ.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ManagementGroup "ALZ" `
    -EmailRecipients @("platform@company.com", "finops@company.com") `
    -NotificationEmail "alerts@company.com"
```

### Preview deployment (what-if)

```powershell
# See what would be deployed without making changes
.\Deploy-BulkALZ.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ManagementGroup "Production" `
    -EmailRecipients @("admin@company.com") `
    -NotificationEmail "alerts@company.com" `
    -WhatIf
```

### Quiet mode for automation

```powershell
# Suppress warnings for cleaner output
.\Deploy-BulkALZ.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ManagementGroup "ALZ" `
    -EmailRecipients @("admin@company.com") `
    -NotificationEmail "alerts@company.com" `
    -Quiet
```

### Deploy to specific environment

```powershell
# Target specific management group like Dev, Test, or Prod
.\Deploy-BulkALZ.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ManagementGroup "Development" `
    -EmailRecipients @("dev-team@company.com") `
    -NotificationEmail "dev-alerts@company.com"
```

## Pagination system

The script implements intelligent pagination to handle Azure Resource Graph's 1,000 result limit:

1. **Automatic page detection**: Determines if pagination is needed
2. **Progressive queries**: Fetches subscriptions in 1,000-item batches
3. **Skip token handling**: Uses Azure's continuation tokens
4. **Real-time progress**: Reports each page as it's processed

### How pagination works

```powershell
# Internal process (handled automatically):
# Page 1: Subscriptions 1-1000
# Page 2: Subscriptions 1001-2000
# Page 3: Subscriptions 2001-3000
# Continues until all subscriptions are discovered
```

## Deployment process

1. **Tenant connection**: Authenticates to specified tenant
2. **Subscription discovery**: Queries Resource Graph for all subscriptions in management group
3. **Pagination handling**: Processes results in batches if needed
4. **Confirmation prompt**: Shows total count and asks for confirmation
5. **Sequential deployment**: Deploys to each subscription with progress tracking
6. **Summary report**: Shows success/failure counts

## Performance considerations

- **Query optimization**: Uses Resource Graph for fast discovery
- **Batch size**: Fixed at 1,000 subscriptions per query (Azure limit)
- **Sequential deployment**: Deploys one subscription at a time to avoid throttling
- **Warning suppression**: Use `-Quiet` to reduce output overhead

### Estimated deployment times

| Subscriptions | Estimated Time |
|---------------|----------------|
| 10 | ~1 minute |
| 100 | ~10 minutes |
| 1,000 | ~100 minutes |
| 5,000 | ~8 hours |

## Error handling

The script includes explicit error handling:
- Validates tenant ID format
- Verifies management group exists
- Handles pagination failures
- Reports deployment failures per subscription
- Continues deployment despite individual failures

## Troubleshooting

### Management group not found

```powershell
# List available management groups
Get-AzManagementGroup | Format-Table Name, DisplayName

# Verify exact name (case-sensitive)
Get-AzManagementGroup -GroupName "YOUR-MG-NAME"
```

### Resource Graph errors

```powershell
# Test Resource Graph access
Search-AzGraph -Query "resourcecontainers | where type == 'microsoft.resources/subscriptions' | limit 1"

# Check module installation
Get-Module -ListAvailable Az.ResourceGraph
```

### Authentication issues

```powershell
# Clear all contexts
Clear-AzContext -Force

# Connect to specific tenant
Connect-AzAccount -Tenant "YOUR-TENANT-ID"

# Verify tenant context
Get-AzContext | Select-Object Tenant
```

### No subscriptions found

```powershell
# Test query directly
$query = "resourcecontainers | where type == 'microsoft.resources/subscriptions'"
$mgScope = "/providers/Microsoft.Management/managementGroups/YOUR-MG"
Search-AzGraph -Query $query -ManagementGroup "YOUR-MG"
```

## Security considerations

- **Tenant isolation**: Explicitly connects to specified tenant
- **Confirmation prompts**: Requires confirmation before bulk changes
- **What-if mode**: Always test with `-WhatIf` first
- **Audit trail**: Each deployment creates audit log entries

## Integration patterns

### Scheduled deployment

```powershell
# PowerShell scheduled task
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 2am
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument @"
    -File C:\Scripts\Deploy-BulkALZ.ps1 `
    -TenantId 'TENANT-ID' `
    -ManagementGroup 'ALZ' `
    -EmailRecipients @('admin@company.com') `
    -NotificationEmail 'alerts@company.com' `
    -Quiet
"@
Register-ScheduledTask -TaskName "WeeklyAnomalyAlerts" -Trigger $trigger -Action $action
```

### Azure Automation script

```powershell
# Runbook script
param(
    [Parameter(Mandatory=$true)]
    [string]$ManagementGroup
)

# Use managed identity for authentication
Connect-AzAccount -Identity

# Deploy alerts
.\Deploy-BulkALZ.ps1 `
    -TenantId $env:AZURE_TENANT_ID `
    -ManagementGroup $ManagementGroup `
    -EmailRecipients @($env:ALERT_RECIPIENTS -split ',') `
    -NotificationEmail $env:NOTIFICATION_EMAIL `
    -Quiet
```

## Script source

[View full script source →](https://github.com/MSBrett/azcapman/blob/main/scripts/anomaly-alerts/Deploy-BulkALZ.ps1)

## Related scripts

- [Deploy-AnomalyAlert.ps1](deploy-anomalyalert.md) - Individual subscription deployment
- [anomaly-alert.bicep](https://github.com/MSBrett/azcapman/blob/main/scripts/anomaly-alerts/anomaly-alert.bicep) - Bicep template

## Related documentation

- [Azure Resource Graph overview](https://learn.microsoft.com/en-us/azure/governance/resource-graph/overview)
- [Management groups](https://learn.microsoft.com/en-us/azure/governance/management-groups/overview)
- [Cost anomaly detection](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/anomaly-detection)
