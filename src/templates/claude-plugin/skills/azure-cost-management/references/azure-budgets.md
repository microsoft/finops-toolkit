---
name: Azure Budgets
description: Cost budgets track spending against a threshold and send notifications when exceeded. Supports email, role-based, and Action Group notifications for automation.
---

**Key Facts:**
- Up to 5 notifications per budget
- Action Groups only at Subscription/Resource Group scope
- Start date must be 1st of month, on or after June 1, 2017
- BillingMonth/Quarter/Annual time grains for EA/MCA billing scopes

## Supported Scopes

| Scope | Format | Action Groups |
|-------|--------|---------------|
| Subscription | `/subscriptions/{subscriptionId}` | Yes |
| Resource Group | `/subscriptions/{subId}/resourceGroups/{rg}` | Yes |
| Billing Account (EA) | `/providers/Microsoft.Billing/billingAccounts/{enrollmentId}` | No |
| Billing Profile (MCA) | `/providers/Microsoft.Billing/billingAccounts/{accountId}/billingProfiles/{profileId}` | No |
| Invoice Section (MCA) | `...billingProfiles/{profileId}/invoiceSections/{sectionId}` | No |

## Workflow: Create Budget with Notifications

### Step 1: List Existing Budgets

```bash
# List budgets at subscription scope
az consumption budget list \
  --query "[].{Name:name, Amount:amount, Spent:currentSpend.amount, TimeGrain:timeGrain}" \
  -o table
```

### Step 2: Create Budget via REST API

The CLI `az consumption budget create` doesn't support notifications. Use REST API:

```bash
# Create budget with email notifications
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az rest --method PUT \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.Consumption/budgets/MonthlyBudget?api-version=2024-08-01" \
  --body '{
    "properties": {
      "category": "Cost",
      "amount": 1000,
      "timeGrain": "Monthly",
      "timePeriod": {
        "startDate": "2026-02-01",
        "endDate": "2027-01-31"
      },
      "notifications": {
        "Actual_GreaterThan_80_Percent": {
          "enabled": true,
          "operator": "GreaterThan",
          "threshold": 80,
          "thresholdType": "Actual",
          "contactEmails": ["finops@company.com"],
          "contactRoles": ["Owner", "Contributor"]
        },
        "Forecasted_GreaterThan_100_Percent": {
          "enabled": true,
          "operator": "GreaterThan",
          "threshold": 100,
          "thresholdType": "Forecasted",
          "contactEmails": ["finops@company.com"]
        }
      }
    }
  }'
```

### Step 3: Verify Budget Created

```bash
# Show budget details
az consumption budget show --budget-name "MonthlyBudget" -o table
```

## Workflow: Add Action Group for Automation

Action Groups enable automated responses (Logic Apps, Azure Functions, webhooks) when budget thresholds are exceeded.

### Step 1: Create or Identify Action Group

```bash
# List existing action groups
az monitor action-group list \
  --query "[].{Name:name, ResourceGroup:resourceGroup}" \
  -o table

# Create new action group (if needed)
az monitor action-group create \
  --name "BudgetAlerts" \
  --resource-group "monitoring-rg" \
  --short-name "BudgetAG" \
  --action email finops-team finops@company.com
```

### Step 2: Update Budget with Action Group

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
ACTION_GROUP_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/monitoring-rg/providers/microsoft.insights/actionGroups/BudgetAlerts"

az rest --method PUT \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.Consumption/budgets/MonthlyBudget?api-version=2024-08-01" \
  --body "{
    \"properties\": {
      \"category\": \"Cost\",
      \"amount\": 1000,
      \"timeGrain\": \"Monthly\",
      \"timePeriod\": {
        \"startDate\": \"2026-02-01\",
        \"endDate\": \"2027-01-31\"
      },
      \"notifications\": {
        \"Actual_GreaterThan_80_Percent\": {
          \"enabled\": true,
          \"operator\": \"GreaterThan\",
          \"threshold\": 80,
          \"thresholdType\": \"Actual\",
          \"contactEmails\": [\"finops@company.com\"],
          \"contactGroups\": [\"${ACTION_GROUP_ID}\"]
        }
      }
    }
  }"
```

## Notification Configuration

| Field | Required | Description |
|-------|----------|-------------|
| `enabled` | Yes | Enable/disable this notification |
| `operator` | Yes | `GreaterThan`, `GreaterThanOrEqualTo` |
| `threshold` | Yes | Percentage (0-1000) |
| `thresholdType` | Yes | `Actual` or `Forecasted` |
| `contactEmails` | Conditional | Required if no contactGroups at sub/RG scope |
| `contactGroups` | No | Action Group resource IDs (sub/RG scope only) |
| `contactRoles` | No | Azure roles (Owner, Contributor, Reader) |
| `locale` | No | Notification language (en-us, ja-jp, etc.) |

**Threshold types:**
- **Actual** - Triggers when accrued cost exceeds threshold
- **Forecasted** - Triggers when projected end-of-period cost exceeds threshold

## Time Grain Options

| Time Grain | Scope | Description |
|------------|-------|-------------|
| `Monthly` | All | Resets monthly |
| `Quarterly` | All | Resets quarterly |
| `Annually` | All | Resets annually |
| `BillingMonth` | EA/MCA billing | Aligns to billing period |
| `BillingQuarter` | EA/MCA billing | Aligns to billing period |
| `BillingAnnual` | EA/MCA billing | Aligns to billing period |

## Common Operations

### Delete Budget

```bash
az consumption budget delete --budget-name "MonthlyBudget"
```

### List Budgets via REST (Any Scope)

```bash
# EA Billing Account scope
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/{enrollmentId}/providers/Microsoft.Consumption/budgets?api-version=2024-08-01"
```

## Best Practices

1. **Use Forecasted alerts** at 100% to get early warning before overspend
2. **Combine with Action Groups** to trigger automation (scale down, notify Slack, create tickets)
3. **Set multiple thresholds** (50%, 80%, 100%) for progressive visibility
4. **Use filters** to create budgets for specific resource groups, tags, or resources
5. **For enterprise**, deploy budgets at billing scope with BillingMonth grain

## References

- [Tutorial: Create and manage budgets](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
- [Budgets REST API](https://learn.microsoft.com/rest/api/consumption/budgets)
- [Action Groups](https://learn.microsoft.com/azure/azure-monitor/alerts/action-groups)
- [Manage costs with budgets](https://learn.microsoft.com/azure/cost-management-billing/manage/cost-management-budget-scenario)
