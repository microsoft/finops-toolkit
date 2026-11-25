---
name: FinOps Hubs Deployment
description: How to deploy and configure Microsoft FinOps Hubs for cloud cost management and analytics. Covers prerequisites, deployment methods, scope configuration, data backfill, dashboard setup, and troubleshooting.
disable-model-invocation: true
---

# FinOps Hubs Deployment

## Overview

FinOps hubs provide a scalable platform for cost analytics, insights, and optimization. This skill covers deployment, configuration, and troubleshooting of the FinOps hub infrastructure.

**Architecture:**
- Storage Account (Data Lake Gen2) - staging area for data ingestion
- Azure Data Factory - data ingestion and cleanup pipelines
- Azure Data Explorer (optional) - scalable datastore for analytics
- Microsoft Fabric RTI (optional) - alternative to Data Explorer
- Key Vault - stores managed identity credentials

**Estimated Cost:** ~$120/mo + $10/mo per $1M in monitored spend

---

## Prerequisites

### Required Permissions

| Task | Required Role |
|------|---------------|
| Deploy template | Contributor + Role Based Access Control Administrator (or Owner) |
| Configure subscription/RG exports | Cost Management Contributor |
| Configure EA billing exports | Enterprise Reader, Department Reader, or Account Owner |
| Configure MCA billing exports | Contributor on billing account/profile/invoice section |
| Configure MPA billing exports | Contributor on billing account/profile/customer |
| Savings plan recommendations (optional) | Data Factory identity: EnrollmentReader (EA billing account), billing profile reader (MCA billing profile), or Cost Management Reader (subscription/resource group) |

### Resource Providers

Enable these resource providers before deployment:

**Azure Portal:**
1. Open subscription → Settings → Resource providers
2. Register `Microsoft.EventGrid`
3. Register `Microsoft.CostManagementExports`

**PowerShell:**
```powershell
Initialize-FinOpsHubDeployment
```

---

## Deployment Methods

### Azure Portal

Deploy using one of these links:
- **Azure Commercial:** https://aka.ms/finops/hubs/deploy
- **Azure Government:** https://aka.ms/finops/hubs/deploy/gov
- **Azure China (MCA only):** https://aka.ms/finops/hubs/deploy/china

**Key Parameters:**

| Parameter | Description | Recommendation |
|-----------|-------------|----------------|
| Hub Name | Used for resource naming and Cost Management grouping | Short, descriptive name |
| Data Explorer Name | Cluster name or Fabric eventhouse Query URI | Required for >$100K spend |
| Storage SKU | `Premium_LRS` or `Premium_ZRS` | Default (LRS) for initial deploy |
| Data Explorer SKU | Cluster size | `Dev(No SLA)_Standard_E2a_v4` to start |

**Data Explorer SKU availability:** Not all SKUs are available in every region. To check availability, use `Get-AzKustoSku -Location "{region}"` or query `GET https://management.azure.com/subscriptions/{subscriptionId}/providers/Microsoft.Kusto/locations/{region}/skus?api-version=2025-02-14`. If the selected SKU isn't available, deployment fails with `"The sku {SkuName} is not supported in {region}"`.

### PowerShell

```powershell
# Install the module
Install-Module -Name FinOpsToolkit

# Deploy to Azure Data Explorer
Deploy-FinOpsHub `
    -Name MyHub `
    -ResourceGroupName MyNewResourceGroup `
    -Location westus `
    -DataExplorerName MyFinOpsHubCluster

# Deploy to Microsoft Fabric
Deploy-FinOpsHub `
    -Name MyHub `
    -ResourceGroupName MyNewResourceGroup `
    -Location westus `
    -DataExplorerName https://abcxyz123789.x0.kusto.fabric.microsoft.com
```

### Bicep Module

```bicep
module finopsHub 'br/public:avm/ptn/finops-toolkit/finops-hub:<version>' = {
  params: {
    hubName: 'finops-hub'
    location: 'westus'
    dataExplorerName: 'myhubcluster'
  }
}
```

---

## Configure Scopes (Cost Management Exports)

### Manual Export Creation

Create exports for each scope you want to monitor:

**Required Settings:**
- **Type of data:** `Cost and usage details (FOCUS)`
- **Dataset version:** `1.0` or `1.0r2`
- **Frequency:** `Daily export of month-to-date costs`
- **Container:** `msexports`
- **Format:** `Parquet` with `Snappy` compression
- **File partitioning:** On
- **Overwrite data:** Off (recommended)

**Directory Path by Scope:**

| Scope | Directory Path |
|-------|----------------|
| EA Billing Account | `billingAccounts/{enrollment-number}` |
| MCA Billing Profile | `billingProfiles/{billing-profile-id}` |
| Subscription | `subscriptions/{subscription-id}` |
| Resource Group | `subscriptions/{subscription-id}/resourceGroups/{rg-name}` |

**Supported Datasets:**
- Cost and usage details (FOCUS) - `1.0`, `1.0r2`
- Price sheet - `2023-05-01` (required for missing prices)
- Reservation details - `2023-03-01`
- Reservation recommendations - `2023-05-01` (required for Rate optimization report)
- Reservation transactions - `2023-05-01`

### Managed Exports

Allow FinOps hubs to create and maintain exports automatically:

1. Get Data Factory identity from deployment outputs (`managedIdentityId`)
2. Grant access to each scope:
   - EA: Assign enrollment/department reader role
   - Subscriptions: Assign Cost Management Contributor
3. Update `settings.json` in storage account `config` container:

```json
{
  "scopes": [
    { "scope": "/providers/Microsoft.Billing/billingAccounts/1234567" },
    { "scope": "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e" }
  ]
}
```

### PowerShell Export Commands

```powershell
# Create FOCUS cost export with 12-month backfill
New-FinOpsCostExport -Name 'ftk-FinOpsHub-costs' `
    -Scope "{scope-id}" `
    -Dataset FocusCost `
    -StorageAccountId "{storage-resource-id}" `
    -StorageContainer msexports `
    -StoragePath 'billingAccounts/###' `
    -Backfill 12 `
    -Execute

# Create price sheet export
New-FinOpsCostExport -Name 'finops-hub-prices' `
    -Scope '/providers/Microsoft.Billing/billingAccounts/###/billingProfiles/###' `
    -Dataset PriceSheet `
    -StorageAccountId $StorageAccountId `
    -StorageContainer msexports `
    -StoragePath 'billingProfiles/###' `
    -Backfill 13

# Create reservation recommendations export
New-FinOpsCostExport -Name 'finops-hub-resrecs' `
    -Scope '/providers/Microsoft.Billing/billingAccounts/###/billingProfiles/###' `
    -Dataset ReservationRecommendations `
    -CommitmentDiscountResourceType VirtualMachines `
    -CommitmentDiscountScope Shared `
    -CommitmentDiscountLookback 30 `
    -StorageAccountId $StorageAccountId `
    -StorageContainer msexports `
    -StoragePath 'billingProfiles/###'
```

---

## Savings Plan Recommendations (Optional)

Cost Management exports don't include savings plan recommendations. To ingest them from the Benefit Recommendations API (`2025-03-01`) into `Recommendations()`:

1. Deploy or redeploy the hub with `enableSavingsPlanRecommendations = true` and `savingsPlanRecommendationScopes` (for example, `['/providers/Microsoft.Billing/billingAccounts/1234567']`). Requires Data Explorer or Fabric. These scopes are separate from `scopesToMonitor` (managed exports); there's no fallback, so without them no recommendations are ingested. Stored in `config/settings.json` at `recommendations.savingsPlans.scopes` and kept on redeploy unless specified.
2. Optionally limit `savingsPlanRecommendationLookbackPeriods` (`Last7Days`, `Last30Days`, `Last60Days`) and `savingsPlanRecommendationTerms` (`P1Y`, `P3Y`). Default: all, which is six API calls per scope. Like retention, the values are kept in `config/settings.json` unless specified on redeploy.
3. Grant the Data Factory identity (`managedIdentityId` output) read access to each savings plan scope. The template doesn't assign these roles:
   - EA billing account: EnrollmentReader
   - MCA billing profile: billing profile reader
   - Subscription or resource group: Cost Management Reader
4. The `savingsPlanRecommendations_DailySchedule` trigger runs once per day. To run it now, trigger the `savingsPlanRecommendations_ExecuteETL` pipeline.

Other scopes (EA departments and enrollment accounts, MCA billing accounts and invoice sections, management groups) are skipped. Results replace the previous run per scope, term, and lookback period. An empty API response keeps the last ingested recommendation.

For details, see [Configure savings plan recommendations](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/configure-recommendations#savings-plan-recommendations).

---

## Backfill Historical Data

### Azure Portal
1. Open Cost Management → Exports
2. Select the export
3. Select **Export selected dates**
4. Specify month (one at a time, up to 12 months)

### PowerShell
```powershell
# Backfill 13 months
Start-FinOpsCostExport `
    -Scope '/providers/Microsoft.Billing/billingAccounts/###/billingProfiles/###' `
    -Name '{export-name}' `
    -Backfill 13

# Or specific date range
Start-FinOpsCostExport `
    -Scope '/providers/Microsoft.Billing/billingAccounts/###' `
    -Name '{export-name}' `
    -StartDate '2024-01-01' -EndDate '2024-12-31'
```

### Data Factory Pipeline
Run `config_RunBackfillJob` pipeline after exports complete:

```powershell
Get-AzDataFactoryV2 -ResourceGroupName "{hub-resource-group}" `
| ForEach-Object {
    Invoke-AzDataFactoryV2Pipeline `
        -ResourceGroupName $_.ResourceGroupName `
        -DataFactoryName $_.DataFactoryName `
        -PipelineName 'config_RunBackfillJob'
}
```

---

## Microsoft Fabric Setup

For Fabric as primary data store (instead of Data Explorer):

### Before Deployment

1. Create workspace and eventhouse in Fabric
2. Create **Ingestion** database
3. Run setup script from [finops-hub-fabric-setup-Ingestion.kql](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-fabric-setup-Ingestion.kql)
4. Repeat for **Hub** database using [finops-hub-fabric-setup-Hub.kql](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-fabric-setup-Hub.kql)
5. Copy the **Query URI** for deployment

### After Deployment

Grant Data Factory access to databases:

```kusto
.add database Ingestion admins ('aadapp=<adf-identity-id>')
.add database Hub admins ('aadapp=<adf-identity-id>')
```

---

## Dashboard and Report Setup

### Data Explorer Dashboard

1. Download [finops-hub-dashboard.json](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-dashboard.json)
2. Grant users **Viewer** access to Hub and Ingestion databases
3. Go to [dataexplorer.azure.com/dashboards](https://dataexplorer.azure.com/dashboards)
4. Import dashboard from file
5. Edit data source to point to your cluster

### Power BI Reports

Download reports based on your backend:
- **KQL (Data Explorer/Fabric):** [PowerBI-kql.zip](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip)
- **Storage:** [PowerBI-storage.zip](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip)
- **Demo (sample data):** [PowerBI-demo.zip](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-demo.zip)

**Required Parameters:**
- **Cluster URI:** Data Explorer cluster or Fabric eventhouse query URI
- **Storage URL:** DFS endpoint for the storage account

---

## Template Outputs

After deployment, retrieve these values from **Deployments → hub → Outputs:**

| Output | Description |
|--------|-------------|
| `storageAccountId` | Resource ID of storage account |
| `storageAccountName` | Storage account name for Power BI |
| `storageUrlForPowerBI` | URL for custom Power BI reports |
| `clusterUri` | Data Explorer cluster URI |
| `managedIdentityId` | Data Factory managed identity (for managed exports) |
| `managedIdentityTenantId` | Tenant ID for managed exports |

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| No data after export | Export takes up to 24 hours | Use "Run now" command |
| Missing prices | Price sheet export not configured | Create price sheet export |
| Power BI timeout | >$1M spend without Data Explorer | Redeploy with Data Explorer or Fabric |
| Export not visible | New subscription | Wait 48 hours for Cost Management activation |

### Data Processing

- Files land in `msexports` container
- Data Factory processes into `ingestion` container
- Final data available in Data Explorer **Hub** database

### Verify Connectivity

```kusto
Costs() | summarize count(), max(ChargePeriodStart)
```

---

## References

- [FinOps Hubs Overview](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/finops-hubs-overview)
- [Create and Update FinOps Hubs](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/deploy)
- [Configure Scopes](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/configure-scopes)
- [FinOps Hub Template](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/template)
- [Configure Dashboards](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/configure-dashboards)
- [Troubleshooting Guide](https://learn.microsoft.com/cloud-computing/finops/toolkit/help/troubleshooting)
- [FinOps Toolkit PowerShell](https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/powershell-commands)
