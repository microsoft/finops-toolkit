# Azure subscription budget deployment

Deploy cost budgets to Azure subscriptions with automatic tag-based amount configuration.

## Overview

These scripts deploy `Microsoft.Consumption/budgets` resources to Azure subscriptions with configurable notification thresholds. Budget amounts can be set per-subscription using the `BudgetAmount` tag, allowing different spending limits across your environment.

## Budget amount priority

1. **Explicit parameter** - If `-Amount` is provided, that value is used
2. **Subscription tag** - If the subscription has a `BudgetAmount` tag, that value is used
3. **Default** - Falls back to $10/month

## Prerequisites

- Azure PowerShell module (`Az`)
- Azure Resource Graph module (`Az.ResourceGraph`) - for bulk deployments
- Authenticated to Azure (`Connect-AzAccount`)
- Appropriate permissions to create subscription-level resources

## Scripts

### Deploy-Budget.ps1

Deploy a budget to a single subscription.

```powershell
# Interactive - prompts for subscription selection
./Deploy-Budget.ps1 -ContactEmails "admin@company.com"

# Specific subscription
./Deploy-Budget.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ContactEmails "admin@company.com"

# Override the tag/default amount
./Deploy-Budget.ps1 -ContactEmails "admin@company.com" -Amount 5000

# Preview without deploying
./Deploy-Budget.ps1 -ContactEmails "admin@company.com" -WhatIf

# Skip confirmation prompt
./Deploy-Budget.ps1 -ContactEmails "admin@company.com" -Force
```

#### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-SubscriptionId` | No | Interactive | Target subscription GUID |
| `-ContactEmails` | Yes | - | Email addresses for notifications |
| `-Amount` | No | Tag or $10 | Budget amount (overrides tag) |
| `-BudgetName` | No | `SubscriptionBudget` | Name of the budget resource |
| `-TimeGrain` | No | `Monthly` | Reset period: Monthly, Quarterly, Annually |
| `-StartDate` | No | 1st of next month | Budget start date (YYYY-MM-DD) |
| `-EndDate` | No | 1 year from start | Budget end date (YYYY-MM-DD) |
| `-ContactRoles` | No | Owner, Contributor | Azure roles to notify |
| `-FirstThreshold` | No | 50 | First notification threshold % |
| `-SecondThreshold` | No | 75 | Second notification threshold % |
| `-ThirdThreshold` | No | 90 | Third notification threshold % |
| `-ForecastedThreshold` | No | 100 | Forecasted cost threshold % |
| `-Force` | No | - | Skip confirmation prompt |
| `-Quiet` | No | - | Suppress verbose output |
| `-WhatIf` | No | - | Preview without deploying |

### Deploy-BulkBudgets.ps1

Deploy budgets to all subscriptions in a management group.

```powershell
# Deploy to all subscriptions in management group (uses tag/default per subscription)
./Deploy-BulkBudgets.ps1 -ManagementGroup "ALZ" -ContactEmails "admin@company.com"

# Override amount for all subscriptions
./Deploy-BulkBudgets.ps1 -ManagementGroup "ALZ" -ContactEmails "admin@company.com" -Amount 5000

# Preview without deploying
./Deploy-BulkBudgets.ps1 -ManagementGroup "ALZ" -ContactEmails "admin@company.com" -WhatIf

# Automated deployment (no prompts, minimal output)
./Deploy-BulkBudgets.ps1 -ManagementGroup "ALZ" -ContactEmails "admin@company.com" -Force -Quiet
```

#### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-ManagementGroup` | Yes | - | Management group to query for subscriptions |
| `-ContactEmails` | Yes | - | Email addresses for notifications |
| `-Amount` | No | Per-sub tag or $10 | Budget amount (overrides all tags) |
| `-BudgetName` | No | `SubscriptionBudget` | Name of the budget resource |
| `-TimeGrain` | No | `Monthly` | Reset period: Monthly, Quarterly, Annually |
| `-StartDate` | No | 1st of next month | Budget start date (YYYY-MM-DD) |
| `-EndDate` | No | 1 year from start | Budget end date (YYYY-MM-DD) |
| `-ContactRoles` | No | Owner, Contributor | Azure roles to notify |
| `-FirstThreshold` | No | 50 | First notification threshold % |
| `-SecondThreshold` | No | 75 | Second notification threshold % |
| `-ThirdThreshold` | No | 90 | Third notification threshold % |
| `-ForecastedThreshold` | No | 100 | Forecasted cost threshold % |
| `-Force` | No | - | Skip confirmation prompt |
| `-Quiet` | No | - | Suppress verbose output |
| `-WhatIf` | No | - | Preview without deploying |

## Setting the BudgetAmount Tag

Set the `BudgetAmount` tag on subscriptions to control per-subscription budget amounts:

```powershell
# Set tag on a subscription
Update-AzTag -ResourceId "/subscriptions/<subscription-id>" -Tag @{BudgetAmount = "500"} -Operation Merge
```

Or via Azure CLI:

```bash
az tag update --resource-id "/subscriptions/<subscription-id>" --operation merge --tags BudgetAmount=500
```

## Notification Thresholds

By default, notifications are sent when:

| Threshold | Type | Default |
|-----------|------|---------|
| First | Actual | 50% |
| Second | Actual | 75% |
| Third | Actual | 90% |
| Forecasted | Forecasted | 100% |

## Examples

### Enterprise deployment

```powershell
# Connect to Azure
Connect-AzAccount

# Preview deployment to production management group
./Deploy-BulkBudgets.ps1 -ManagementGroup "Production" -ContactEmails "finops@company.com","alerts@company.com" -WhatIf

# Deploy after review
./Deploy-BulkBudgets.ps1 -ManagementGroup "Production" -ContactEmails "finops@company.com","alerts@company.com" -Force
```

### Development environment with low budget

```powershell
# Tag dev subscriptions with low budget
Update-AzTag -ResourceId "/subscriptions/<dev-sub-id>" -Tag @{BudgetAmount = "50"} -Operation Merge

# Deploy - will use $50 from tag
./Deploy-Budget.ps1 -SubscriptionId "<dev-sub-id>" -ContactEmails "dev-team@company.com"
```
