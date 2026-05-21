---
title: Deploy-BulkBudgets.ps1
parent: Tools & scripts
nav_order: 9
---

# Deploy-BulkBudgets.ps1

Deploy cost budgets to all subscriptions in a management group with per-subscription tag-based amount configuration.

## Overview

This PowerShell script uses Azure Resource Graph to discover all subscriptions in a management group, then deploys a `Microsoft.Consumption/budgets` resource to each. Each subscription can carry a different budget amount via its `BudgetAmount` tag, so a single bulk run respects per-subscription spending limits without manual intervention.

### Key capabilities

- **Management group targeting**: Discover and deploy to all subscriptions in a hierarchy
- **Tag-based amounts**: Reads `BudgetAmount` tag from each subscription for per-subscription limits
- **What-if mode**: Preview deployment scope without making changes
- **Force mode**: Skip confirmation for automation and CI/CD pipelines
- **Quiet mode**: Suppress output for cleaner pipeline logs

### When to use this script

- Applying cost governance across a management group at once
- Onboarding a new management group to budget monitoring
- Refreshing budgets after fiscal year changes
- Environments with 10+ subscriptions requiring consistent budget coverage

## Prerequisites

```powershell
# Install Azure PowerShell modules
Install-Module -Name Az -Force -AllowClobber
Install-Module -Name Az.ResourceGraph -Force -AllowClobber

# Authenticate to Azure
Connect-AzAccount

# Verify management group access
Get-AzManagementGroup | Select-Object Name, DisplayName
```

## Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| **ManagementGroup** | String | Management group to query for subscriptions | Required |
| **ContactEmails** | String[] | Email addresses for notifications | Required |
| **Amount** | Decimal | Budget amount (overrides all subscription tags) | Per-sub tag or $10 |
| **BudgetName** | String | Name of the budget resource | `SubscriptionBudget` |
| **TimeGrain** | String | Reset period: Monthly, Quarterly, or Annually | Monthly |
| **StartDate** | String | Budget start date (YYYY-MM-DD) | 1st of next month |
| **EndDate** | String | Budget end date (YYYY-MM-DD) | 1 year from start |
| **ContactRoles** | String[] | Azure roles to notify | Owner, Contributor |
| **FirstThreshold** | Int | First notification threshold % | 50 |
| **SecondThreshold** | Int | Second notification threshold % | 75 |
| **ThirdThreshold** | Int | Third notification threshold % | 90 |
| **ForecastedThreshold** | Int | Forecasted cost threshold % | 100 |
| **Force** | Switch | Skip confirmation prompt | False |
| **Quiet** | Switch | Suppress verbose output | False |
| **WhatIf** | Switch | Preview without deploying | False |

## Usage examples

### Deploy to all subscriptions in a management group

```powershell
.\Deploy-BulkBudgets.ps1 `
    -ManagementGroup "ALZ" `
    -ContactEmails "admin@company.com"
```

### Override amount for all subscriptions

```powershell
.\Deploy-BulkBudgets.ps1 `
    -ManagementGroup "ALZ" `
    -ContactEmails "admin@company.com" `
    -Amount 5000
```

### What-if preview

```powershell
.\Deploy-BulkBudgets.ps1 `
    -ManagementGroup "Production" `
    -ContactEmails "finops@company.com" `
    -WhatIf
```

### Automated deployment

```powershell
.\Deploy-BulkBudgets.ps1 `
    -ManagementGroup "ALZ" `
    -ContactEmails "finops@company.com","alerts@company.com" `
    -Force -Quiet
```

### Production management group with custom thresholds

```powershell
.\Deploy-BulkBudgets.ps1 `
    -ManagementGroup "Production" `
    -ContactEmails "finops@company.com","alerts@company.com" `
    -FirstThreshold 70 `
    -SecondThreshold 85 `
    -ThirdThreshold 95 `
    -ForecastedThreshold 100
```

## Tag-based amount configuration

Set the `BudgetAmount` tag on individual subscriptions before running bulk deployment to control per-subscription limits:

```powershell
# Tag a dev subscription with a low budget
Update-AzTag `
    -ResourceId "/subscriptions/<dev-sub-id>" `
    -Tag @{BudgetAmount = "50"} `
    -Operation Merge

# Tag a production subscription with a higher budget
Update-AzTag `
    -ResourceId "/subscriptions/<prod-sub-id>" `
    -Tag @{BudgetAmount = "10000"} `
    -Operation Merge
```

When `-Amount` is provided at the command line, it overrides all subscription tags.

## Deployment process

1. **Management group query**: Uses Resource Graph to discover all enabled subscriptions
2. **Confirmation prompt**: Shows subscription count and asks for confirmation (unless `-Force`)
3. **Sequential deployment**: Deploys to each subscription with progress output
4. **Summary report**: Shows success and failure counts at completion

## Troubleshooting

### Management group not found

```powershell
# List available management groups
Get-AzManagementGroup | Format-Table Name, DisplayName

# Verify exact name (case-sensitive)
Get-AzManagementGroup -GroupName "YOUR-MG-NAME"
```

### Resource Graph module missing

```powershell
Install-Module -Name Az.ResourceGraph -Force -AllowClobber
```

### No subscriptions found

```powershell
# Test the Resource Graph query directly
Search-AzGraph `
    -Query "resourcecontainers | where type == 'microsoft.resources/subscriptions'" `
    -ManagementGroup "YOUR-MG"
```

### Authentication errors

```powershell
Clear-AzContext -Force
Connect-AzAccount -Tenant 'your-tenant-id'
```

## Script source

[View full script source →](https://github.com/MSBrett/azcapman/blob/main/scripts/budgets/Deploy-BulkBudgets.ps1)

## Related scripts

- [Deploy-Budget.ps1](deploy-budget.md) - Single subscription budget deployment
- [Deploy-BulkALZ.ps1](deploy-bulkalz.md) - Bulk anomaly alert deployment pattern

## Related documentation

- [Azure budgets overview](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
- [Azure Resource Graph overview](https://learn.microsoft.com/en-us/azure/governance/resource-graph/overview)
- [Microsoft.Consumption/budgets API](https://learn.microsoft.com/en-us/azure/templates/microsoft.consumption/budgets)
