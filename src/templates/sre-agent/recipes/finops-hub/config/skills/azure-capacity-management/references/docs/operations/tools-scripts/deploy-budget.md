---
title: Deploy-Budget.ps1
parent: Tools & scripts
nav_order: 8
---

# Deploy-Budget.ps1

Deploy a cost budget to a single Azure subscription with tag-based amount configuration and configurable notification thresholds.

## Overview

This PowerShell script deploys a `Microsoft.Consumption/budgets` resource to an Azure subscription. Budget amounts can be set via explicit parameter or read from a `BudgetAmount` subscription tag, letting different subscriptions carry different spending limits without modifying the script.

### Key capabilities

- **Tag-based amounts**: Reads `BudgetAmount` tag from the subscription to set per-subscription limits
- **Interactive selection**: Prompts for subscription when no ID is provided
- **Threshold configuration**: Configures actual and forecasted notification thresholds
- **What-if mode**: Preview deployment without making changes
- **Force mode**: Skip confirmation for automation scenarios

### When to use this script

- Deploying a budget to a single subscription
- Testing budget configuration before bulk deployment
- Onboarding a new subscription to cost governance
- CI/CD pipeline integration for subscription-level budgets

### Budget amount priority

The script resolves the budget amount in this order:

1. **`-Amount` parameter** — explicit value takes precedence
2. **`BudgetAmount` subscription tag** — tag-based per-subscription configuration
3. **Default** — falls back to $10/month

## Prerequisites

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Repository PSGallery -Force

# Authenticate to Azure
Connect-AzAccount

# Verify subscription access
Get-AzSubscription | Select-Object Name, Id, State
```

## Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| **SubscriptionId** | String | Target subscription GUID | Interactive selection |
| **ContactEmails** | String[] | Email addresses for notifications | Required |
| **Amount** | Decimal | Budget amount (overrides tag) | Tag or $10 |
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

### Interactive subscription selection

```powershell
.\Deploy-Budget.ps1 -ContactEmails "admin@company.com"
```

### Specific subscription

```powershell
.\Deploy-Budget.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789012" `
    -ContactEmails "admin@company.com"
```

### Override budget amount

```powershell
.\Deploy-Budget.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789012" `
    -ContactEmails "finops@company.com" `
    -Amount 5000
```

### What-if preview

```powershell
.\Deploy-Budget.ps1 `
    -ContactEmails "admin@company.com" `
    -WhatIf
```

### Automated deployment (no prompts)

```powershell
.\Deploy-Budget.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789012" `
    -ContactEmails "admin@company.com" `
    -Force -Quiet
```

## Setting the BudgetAmount tag

Set the `BudgetAmount` tag on a subscription to control its per-subscription limit without changing script parameters:

```powershell
# PowerShell
Update-AzTag -ResourceId "/subscriptions/<subscription-id>" `
    -Tag @{BudgetAmount = "500"} `
    -Operation Merge
```

```bash
# Azure CLI
az tag update \
  --resource-id "/subscriptions/<subscription-id>" \
  --operation merge \
  --tags BudgetAmount=500
```

## Notification thresholds

By default, notifications are sent at these percentages of the configured budget amount:

| Threshold | Type | Default |
|-----------|------|---------|
| First | Actual | 50% |
| Second | Actual | 75% |
| Third | Actual | 90% |
| Forecasted | Forecasted | 100% |

All four thresholds are configurable via parameters. Actual thresholds trigger when actual spend crosses the percentage; the forecasted threshold triggers when projected spend is expected to cross it.

## Troubleshooting

### Subscription not found

```powershell
# List accessible subscriptions
Get-AzSubscription | Where-Object State -eq 'Enabled' | Select-Object Name, Id
```

### Budget already exists

The script uses `New-AzConsumptionBudget` with upsert behavior. Re-running against the same subscription updates the existing budget rather than creating a duplicate.

### Authentication errors

```powershell
# Re-authenticate
Clear-AzContext -Force
Connect-AzAccount -Tenant 'your-tenant-id'
```

## Script source

[View full script source →](https://github.com/MSBrett/azcapman/blob/main/scripts/budgets/Deploy-Budget.ps1)

## Related scripts

- [Deploy-BulkBudgets.ps1](deploy-bulkbudgets.md) - Bulk budget deployment across a management group
- [Deploy-AnomalyAlert.ps1](deploy-anomalyalert.md) - Deploy anomaly alerts to individual subscriptions

## Related documentation

- [Azure budgets overview](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
- [Microsoft.Consumption/budgets API](https://learn.microsoft.com/en-us/azure/templates/microsoft.consumption/budgets)
