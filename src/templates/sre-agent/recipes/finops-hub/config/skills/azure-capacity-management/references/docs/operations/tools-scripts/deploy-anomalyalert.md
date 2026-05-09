---
title: Deploy-AnomalyAlert.ps1
parent: Tools & scripts
nav_order: 6
---

# Deploy-AnomalyAlert.ps1

Deploy cost anomaly alert configuration to individual Azure subscriptions with interactive features and validation.

## Overview

This PowerShell script deploys the anomaly alert Bicep template to create a subscription-level scheduled action for cost anomaly monitoring. It provides interactive subscription selection, parameter validation, and deployment options suitable for individual subscription management or CI/CD integration.

### Key capabilities

- **Interactive subscription selection**: Choose target subscription from available list
- **Email validation**: Validates email format before deployment
- **What-if deployment**: Preview changes without actual deployment
- **Color-coded logging**: Timestamped output with visual status indicators
- **Force mode**: Skip confirmations for automation scenarios
- **Quiet mode**: Suppress verbose output for cleaner logs

### When to use this script

- Deploying anomaly alerts to individual subscriptions
- Testing alert configurations before bulk deployment
- CI/CD pipeline integration for specific subscriptions
- Interactive deployment with validation
- Small-scale deployments (1-10 subscriptions)

## Prerequisites

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Force -AllowClobber

# Authenticate to Azure
Connect-AzAccount

# Verify permissions (Contributor or Owner required)
Get-AzRoleAssignment | Where-Object {
    $_.RoleDefinitionName -eq "Contributor" -or
    $_.RoleDefinitionName -eq "Owner"
}

# List available subscriptions
Get-AzSubscription | Select-Object Name, Id, State
```

## Parameters

| Parameter | Type | Description | Required |
|-----------|------|-------------|----------|
| **SubscriptionId** | String | Target subscription ID (GUID format) | No (interactive) |
| **EmailRecipients** | String[] | Array of recipient email addresses | Yes |
| **NotificationEmail** | String | Primary notification email | Yes |
| **DeploymentName** | String | Custom deployment name | No (auto-generated) |
| **Location** | String | Deployment metadata location | No (West US) |
| **Force** | Switch | Skip confirmation prompts | No |
| **Quiet** | Switch | Suppress deployment progress | No |

## Usage examples

### Interactive subscription selection

```powershell
# Select subscription interactively
.\Deploy-AnomalyAlert.ps1 `
    -EmailRecipients @("platform@company.com", "finops@company.com") `
    -NotificationEmail "alerts@company.com"
```

### Specific subscription deployment

```powershell
# Deploy to specific subscription
.\Deploy-AnomalyAlert.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789012" `
    -EmailRecipients @("admin@company.com") `
    -NotificationEmail "alerts@company.com"
```

### What-if preview

```powershell
# Preview deployment without making changes
.\Deploy-AnomalyAlert.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789012" `
    -EmailRecipients @("admin@company.com") `
    -NotificationEmail "alerts@company.com" `
    -WhatIf
```

### Automated deployment

```powershell
# Skip all prompts for automation
.\Deploy-AnomalyAlert.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789012" `
    -EmailRecipients @("admin@company.com") `
    -NotificationEmail "alerts@company.com" `
    -Force `
    -Quiet
```

### Multiple recipients

```powershell
# Send alerts to multiple email addresses
.\Deploy-AnomalyAlert.ps1 `
    -EmailRecipients @(
        "platform-team@company.com",
        "finance@company.com",
        "cloudops@company.com"
    ) `
    -NotificationEmail "azure-alerts@company.com"
```

## Deployment process

1. **Subscription validation**: Verifies subscription exists and is accessible
2. **Email validation**: Checks email format for all recipients
3. **Parameter collection**: Gathers required parameters
4. **Confirmation prompt**: Shows deployment summary (unless -Force)
5. **Template deployment**: Deploys anomaly-alert.bicep template
6. **Status reporting**: Shows success/failure with deployment ID

## What gets deployed

The script deploys:
- **Cost Management scheduled action** named "AnomalyAlert"
- **Anomaly detection** at subscription level
- **Email notifications** to specified recipients

This uses the Azure public Bicep registry module:
```
br/public:cost/subscription-scheduled-action:1.0.2
```

## Error handling

The script includes comprehensive error handling:
- Validates subscription ID format (GUID)
- Validates email address formats
- Checks Azure authentication status
- Verifies subscription access permissions
- Handles deployment failures gracefully

## Troubleshooting

### Authentication issues

```powershell
# Clear and re-authenticate
Clear-AzContext -Force
Connect-AzAccount

# Verify current context
Get-AzContext | Select-Object Account, Subscription, Tenant
```

### Permission errors

```powershell
# Check role assignments
Get-AzRoleAssignment -Scope "/subscriptions/YOUR-SUB-ID" |
    Select-Object DisplayName, RoleDefinitionName

# Minimum required: Contributor or Owner role
```

### Subscription not found

```powershell
# List all accessible subscriptions
Get-AzSubscription | Format-Table Name, Id, State

# Ensure subscription is enabled
Get-AzSubscription -SubscriptionId "YOUR-SUB-ID" |
    Select-Object State
```

### Deployment failures

```powershell
# Check deployment history
Get-AzSubscriptionDeployment -Name "YOUR-DEPLOYMENT-NAME" |
    Select-Object ProvisioningState, Timestamp

# Get detailed error
$deployment = Get-AzSubscriptionDeploymentOperation `
    -DeploymentName "YOUR-DEPLOYMENT-NAME"
$deployment.Properties.StatusMessage
```

## CI/CD integration

### Azure DevOps pipeline

```yaml
- task: AzurePowerShell@5
  displayName: 'Deploy Anomaly Alert'
  inputs:
    azureSubscription: 'ServiceConnection'
    ScriptType: 'FilePath'
    ScriptPath: '$(System.DefaultWorkingDirectory)/Deploy-AnomalyAlert.ps1'
    ScriptArguments: >
      -SubscriptionId $(SubscriptionId)
      -EmailRecipients @("$(EmailRecipients)")
      -NotificationEmail "$(NotificationEmail)"
      -Force
      -Quiet
    azurePowerShellVersion: 'LatestVersion'
```

### GitHub Actions

```yaml
- name: Deploy Anomaly Alert
  uses: azure/powershell@v1
  with:
    inlineScript: |
      .\Deploy-AnomalyAlert.ps1 `
        -SubscriptionId "${{ secrets.AZURE_SUBSCRIPTION_ID }}" `
        -EmailRecipients @("${{ vars.ALERT_RECIPIENTS }}") `
        -NotificationEmail "${{ vars.NOTIFICATION_EMAIL }}" `
        -Force `
        -Quiet
    azPSVersion: "latest"
```

## Script source

[View full script source →](https://github.com/MSBrett/azcapman/blob/main/scripts/anomaly-alerts/Deploy-AnomalyAlert.ps1)

## Related scripts

- [Deploy-BulkALZ.ps1](deploy-bulkalz.md) - Enterprise bulk deployment
- [anomaly-alert.bicep](https://github.com/MSBrett/azcapman/blob/main/scripts/anomaly-alerts/anomaly-alert.bicep) - Bicep template

## Related documentation

- [Cost anomaly detection](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/anomaly-detection)
- [Cost Management scheduled actions](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/save-share-views)