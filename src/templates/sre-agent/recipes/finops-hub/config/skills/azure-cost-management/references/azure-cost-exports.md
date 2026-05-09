---
name: Azure Cost Management Exports
description: Cost Management exports automatically export cost and usage data to Azure Storage on a recurring schedule. Exports are the foundation for FinOps data pipelines and are required for FinOps Hubs.
---

## Supported Scopes

| Agreement | Scope | Format | Recommended |
|-----------|-------|--------|-------------|
| **EA** | Billing Account | `/providers/Microsoft.Billing/billingAccounts/{enrollmentId}` | ✅ |
| **EA** | Department | `/providers/Microsoft.Billing/billingAccounts/{enrollmentId}/departments/{deptId}` | |
| **EA** | Enrollment Account | `/providers/Microsoft.Billing/billingAccounts/{enrollmentId}/enrollmentAccounts/{accountId}` | |
| **MCA** | Billing Profile | `/providers/Microsoft.Billing/billingAccounts/{accountId}/billingProfiles/{profileId}` | ✅ |
| **MCA** | Invoice Section | `...billingProfiles/{profileId}/invoiceSections/{sectionId}` | |
| **MPA** | Customer | `/providers/Microsoft.Billing/billingAccounts/{accountId}/customers/{customerId}` | |
| All | Subscription | `/subscriptions/{subscriptionId}` | |
| All | Resource Group | `/subscriptions/{subId}/resourceGroups/{rgName}` | |

**Why billing scope?** Billing account (EA) and billing profile (MCA) include price sheets, reservation recommendations, and complete cost visibility across all subscriptions.

## Workflow: Create Export at Billing Scope

### Step 1: List Existing Exports

```bash
# EA Billing Account scope
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/{enrollmentId}/providers/Microsoft.CostManagement/exports?api-version=2023-08-01" \
  --query "value[].{Name:name, Type:properties.definition.type, Status:properties.schedule.status}" \
  -o table

# MCA Billing Profile scope
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/{accountId}/billingProfiles/{profileId}/providers/Microsoft.CostManagement/exports?api-version=2023-08-01" \
  --query "value[].{Name:name, Type:properties.definition.type, Status:properties.schedule.status}" \
  -o table
```

### Step 2: Create Export via REST API

```bash
# EA Billing Account - FOCUS cost export
SCOPE="/providers/Microsoft.Billing/billingAccounts/{enrollmentId}"

az rest --method PUT \
  --url "https://management.azure.com${SCOPE}/providers/Microsoft.CostManagement/exports/ftk-costs-daily?api-version=2023-08-01" \
  --body '{
    "properties": {
      "format": "Parquet",
      "deliveryInfo": {
        "destination": {
          "resourceId": "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{account}",
          "container": "msexports",
          "rootFolderPath": "billingAccounts/{enrollmentId}"
        }
      },
      "definition": {
        "type": "FocusCost",
        "timeframe": "MonthToDate",
        "dataSet": {
          "granularity": "Daily"
        }
      },
      "schedule": {
        "status": "Active",
        "recurrence": "Daily",
        "recurrencePeriod": {
          "from": "2026-01-01T00:00:00Z",
          "to": "2027-12-31T00:00:00Z"
        }
      }
    }
  }'
```

### Step 3: Run Export Immediately

```bash
# Trigger export run
az rest --method POST \
  --url "https://management.azure.com${SCOPE}/providers/Microsoft.CostManagement/exports/ftk-costs-daily/run?api-version=2023-08-01"
```

### Step 4: Verify Data Landed

```bash
# List blobs in export container
az storage blob list \
  --account-name {storageAccount} \
  --container-name msexports \
  --prefix "billingAccounts/{enrollmentId}" \
  --auth-mode login \
  --query "[].{Name:name, Size:properties.contentLength}" \
  -o table
```

## Workflow: Historical Backfill

### FinOps Toolkit PowerShell (Recommended)

```powershell
# Backfill 12 months at billing scope
New-FinOpsCostExport -Name "ftk-costs" `
  -Scope "/providers/Microsoft.Billing/billingAccounts/{enrollmentId}" `
  -StorageAccountId "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{account}" `
  -Backfill 12 `
  -Execute
```

### REST API (One Month at a Time)

```bash
SCOPE="/providers/Microsoft.Billing/billingAccounts/{enrollmentId}"

az rest --method PUT \
  --url "https://management.azure.com${SCOPE}/providers/Microsoft.CostManagement/exports/backfill-jan2025?api-version=2023-08-01" \
  --body '{
    "properties": {
      "format": "Parquet",
      "deliveryInfo": {
        "destination": {
          "resourceId": "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{account}",
          "container": "msexports",
          "rootFolderPath": "backfill"
        }
      },
      "definition": {
        "type": "FocusCost",
        "timeframe": "Custom",
        "timePeriod": {
          "from": "2025-01-01T00:00:00Z",
          "to": "2025-01-31T23:59:59Z"
        }
      }
    }
  }'

# Run the backfill
az rest --method POST \
  --url "https://management.azure.com${SCOPE}/providers/Microsoft.CostManagement/exports/backfill-jan2025/run?api-version=2023-08-01"
```

## Dataset Types by Scope

| Dataset | EA Billing | MCA Profile | Subscription |
|---------|------------|-------------|--------------|
| **FocusCost** | ✅ | ✅ | ✅ |
| **ActualCost** | ✅ | ✅ | ✅ |
| **AmortizedCost** | ✅ | ✅ | ✅ |
| **PriceSheet** | ✅ | ✅ | ❌ |
| **ReservationRecommendations** | ✅ | ✅ | ❌ |
| **ReservationDetails** | ✅ | ✅ | ❌ |
| **ReservationTransactions** | ✅ | ✅ | ❌ |

## Common Issues

### "Unauthorized" Error
**Fix:** Assign Cost Management Contributor or Owner role at the billing scope

### Export Created But No Data
**Fix:** Trigger immediate run:
```bash
az rest --method POST \
  --url "https://management.azure.com/{scope}/providers/Microsoft.CostManagement/exports/{exportName}/run?api-version=2023-08-01"
```

## Best Practices

1. **Use billing scope** (EA enrollment / MCA profile) for complete data including price sheets
2. **Use FOCUS format** - combines actual/amortized, reduces storage
3. **Use Parquet with Snappy** compression for best performance
4. **Create backfill in one-month chunks** to avoid timeouts

## References

- [Tutorial: Create and manage exports](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-improved-exports)
- [Exports REST API](https://learn.microsoft.com/rest/api/cost-management/exports)
- [Understand and work with scopes](https://learn.microsoft.com/azure/cost-management-billing/costs/understand-work-scopes)
