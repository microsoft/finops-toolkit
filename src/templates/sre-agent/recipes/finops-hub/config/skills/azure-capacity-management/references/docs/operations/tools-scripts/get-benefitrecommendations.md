---
title: Get-BenefitRecommendations.ps1
parent: Tools & scripts
nav_order: 5
---

# Get-BenefitRecommendations.ps1

Queries the Azure Cost Management API to retrieve detailed benefit recommendations that aren't fully exposed in the Azure portal.

## Overview

This PowerShell script extracts comprehensive savings plan and reserved instance recommendations directly from the Azure Cost Management API. The API returns additional details and granular data that the portal interface doesn't display, providing deeper insights for cost optimization decisions.

### Key capabilities

- **API-level detail extraction**: Accesses recommendation data not visible in portal
- **Flexible lookback periods**: Analyze 7, 30, or 60 days of historical usage
- **Multiple commitment terms**: Compare 1-year vs 3-year savings plans
- **Billing scope flexibility**: Works at subscription or billing account level

### When to use this script

- Extracting detailed recommendation data for FinOps reporting
- Comparing savings opportunities across different commitment terms
- Analyzing recommendations based on different usage windows
- Accessing API data fields not shown in portal views
- Building automated cost optimization workflows

## Prerequisites

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Repository PSGallery -Force

# Authenticate to Azure
Connect-AzAccount

# Verify Cost Management Reader permissions
Get-AzRoleAssignment | Where-Object {$_.RoleDefinitionName -like "*Cost Management*"}

# Find your billing account (for MCA)
Get-AzBillingAccount | Select-Object Name, Id

# List available subscriptions
Get-AzSubscription | Select-Object Name, Id
```

## Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| **BillingScope** | String | Billing scope path (required) | None |
| **LookBackPeriod** | String | Historical period to analyze | Last7Days |
| **Term** | String | Commitment term: P1Y or P3Y | P3Y |

### BillingScope format

For subscriptions:
```
subscriptions/12345678-1234-1234-1234-123456789012
```

For billing accounts:
```
providers/Microsoft.Billing/billingAccounts/12345678
```

### LookBackPeriod values

- `Last7Days` - Analyze last 7 days of usage
- `Last30Days` - Analyze last 30 days of usage
- `Last60Days` - Analyze last 60 days of usage

### Term values

- `P1Y` - 1-year commitment term
- `P3Y` - 3-year commitment term

## Usage examples

### Basic subscription analysis

```powershell
# Get 3-year recommendations based on last 7 days
.\Get-BenefitRecommendations.ps1 `
    -BillingScope "subscriptions/12345678-1234-1234-1234-123456789012"
```

### Extended analysis period

```powershell
# Analyze 30 days of usage for 1-year commitments
.\Get-BenefitRecommendations.ps1 `
    -BillingScope "subscriptions/12345678-1234-1234-1234-123456789012" `
    -LookBackPeriod "Last30Days" `
    -Term "P1Y"
```

### Billing account level

```powershell
# Get billing account ID
$billingAccount = Get-AzBillingAccount | Select-Object -First 1

# Analyze entire billing account
.\Get-BenefitRecommendations.ps1 `
    -BillingScope "providers/Microsoft.Billing/billingAccounts/$($billingAccount.Name)" `
    -LookBackPeriod "Last60Days" `
    -Term "P3Y"
```

### Export results for analysis

```powershell
# Run script and capture output
$result = .\Get-BenefitRecommendations.ps1 `
    -BillingScope "subscriptions/12345678-1234-1234-1234-123456789012" `
    -LookBackPeriod "Last30Days"

# The script outputs raw JSON and formatted tables
# Capture and process as needed for your workflows
```

## Output format

The script provides three types of output:

1. **Raw JSON output** - Complete API response for processing
2. **Recommended savings plan** - Primary recommendation in table format
3. **All savings plan recommendations** - Full list of recommendations

## API endpoint

The script calls the Cost Management API:
```
https://management.azure.com/{BillingScope}/providers/Microsoft.CostManagement/benefitRecommendations
```

With parameters:
- `$filter`: Filters by lookback period and term
- `$expand`: Includes usage and recommendation details
- `api-version`: 2024-08-01

## Troubleshooting

### No recommendations returned

```powershell
# Verify you have usage data in the period
Get-AzConsumptionUsageDetail `
    -StartDate (Get-Date).AddDays(-7) `
    -EndDate (Get-Date) |
    Measure-Object

# Check permissions
Get-AzRoleAssignment -Scope "/subscriptions/YOUR-SUB-ID" |
    Where-Object {$_.RoleDefinitionName -like "*Cost Management*"}
```

### Authentication errors

```powershell
# Clear cached credentials
Clear-AzContext -Force

# Re-authenticate
Connect-AzAccount

# Set specific subscription context
Set-AzContext -SubscriptionId "YOUR-SUB-ID"
```

### API access issues

```powershell
# Test direct API access
$scope = "subscriptions/YOUR-SUB-ID"
$uri = "https://management.azure.com/$scope/providers/Microsoft.CostManagement/query?api-version=2024-08-01"
Invoke-AzRestMethod -Uri $uri -Method POST
```

## Integration patterns

### Scheduled analysis

```powershell
# Weekly analysis across all subscriptions
$subscriptions = Get-AzSubscription | Where-Object State -eq "Enabled"

foreach ($sub in $subscriptions) {
    Write-Host "Analyzing subscription: $($sub.Name)"
    .\Get-BenefitRecommendations.ps1 `
        -BillingScope "subscriptions/$($sub.Id)" `
        -LookBackPeriod "Last30Days"
}
```

### CI/CD integration

```yaml
# Azure DevOps pipeline
- task: AzurePowerShell@5
  inputs:
    azureSubscription: 'ServiceConnection'
    ScriptType: 'FilePath'
    ScriptPath: '$(System.DefaultWorkingDirectory)/Get-BenefitRecommendations.ps1'
    ScriptArguments: >
      -BillingScope "subscriptions/$(SubscriptionId)"
      -LookBackPeriod "Last30Days"
      -Term "P3Y"
    azurePowerShellVersion: 'LatestVersion'
```

## Script source

[View full script source →](https://github.com/MSBrett/azcapman/blob/main/scripts/rate/Get-BenefitRecommendations.ps1)

## Related documentation

- [Azure Cost Management API](https://learn.microsoft.com/en-us/rest/api/cost-management/)
- [Savings plan purchase recommendations](https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/purchase-recommendations)
- [Understanding reservation recommendations](https://learn.microsoft.com/en-us/azure/cost-management-billing/reservations/reserved-instance-purchase-recommendations)