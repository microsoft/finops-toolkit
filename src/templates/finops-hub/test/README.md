# FinOps Hub Test Data

This directory contains test data generation utilities for validating FinOps Hub deployments.

## New-FinOpsTestData

Generates synthetic multi-cloud cost data in [FOCUS format](https://focus.finops.org/) for Azure, AWS, GCP, and on-premises data center scenarios. Generated data is compatible with both Azure Data Explorer and Microsoft Fabric Real-Time Intelligence ingestion paths.

This command is part of the [FinOps toolkit PowerShell module](../../../powershell/). The source is located at [`src/powershell/Public/New-FinOpsTestData.ps1`](../../../powershell/Public/New-FinOpsTestData.ps1).

### Prerequisites

- PowerShell 7.0 or later
- [FinOps toolkit PowerShell module](https://aka.ms/ftk/ps)
- Az PowerShell modules (`Az.Accounts`, `Az.Storage`, `Az.DataFactory`) for upload to storage
- Azure AD credentials with Storage Blob Data Contributor role (for upload)

### Quick Start

```powershell
# Generate 6 months of FOCUS 1.3 data for all providers (500K rows, $500K cost target)
New-FinOpsTestData

# Generate a small reproducible dataset
New-FinOpsTestData -Seed 42 -RowCount 1000

# Generate Azure-only FOCUS 1.0 data
New-FinOpsTestData -FocusVersion 1.0 -ServiceProvider Azure -RowCount 50000

# Generate and upload to Azure Storage with ADF trigger management
New-FinOpsTestData -StorageAccountName "stfinopshub" -ResourceGroupName "rg-finopshub" -AdfName "adf-finopshub" -StartTriggers

# Remove test-data folders from storage (production data is preserved)
Remove-FinOpsTestData -StorageAccountName "stfinopshub"

# Full cleanup including ADX (requires -Force because .clear table removes ALL rows)
Remove-FinOpsTestData -AdxClusterUri "https://mycluster.region.kusto.windows.net" -StorageAccountName "stfinopshub" -AdfName "adf-finopshub" -ResourceGroupName "rg-finopshub" -StopTriggers -Force
```

### Features

| Feature               | Description                                                               |
| --------------------- | ------------------------------------------------------------------------- |
| Multi-cloud           | Azure, AWS, GCP, and Data Center providers                                |
| FOCUS versions        | 1.0, 1.1, 1.2, 1.3 with version-specific column sets                      |
| Budget scaling        | Inline cost scaling to hit target cost (no Python dependency)             |
| Commitment discounts  | Reservations and Savings Plans with Used/Unused status                    |
| Azure Hybrid Benefit  | x_SkuLicenseStatus Enabled/Not Enabled simulation                         |
| CPU architecture      | Intel/AMD/Arm64 patterns in x_SkuMeterName                                |
| Tag variation         | ~80% tagged, ~20% untagged for maturity scorecard testing                 |
| Data quality          | ~2% anomaly rows with ChargeClass=Correction                              |
| Split cost allocation | ~10% of AKS/EKS/GKE rows with Allocated\* columns (v1.3+)                 |
| ContractApplied       | JSON contract reference on committed-discount rows (v1.3+)                |
| Reproducibility       | `-Seed` parameter for deterministic output                                |
| Azure AD auth         | Default Microsoft Entra ID auth for uploads                               |
| ShouldProcess         | Full `-WhatIf` / `-Confirm` support for destructive operations            |
| Output formats        | CSV and Parquet (via PSParquet module)                                    |
| Additional datasets   | Azure-only Prices, CommitmentDiscountUsage, Recommendations, Transactions |

### Parameters

Run `Get-Help New-FinOpsTestData -Detailed` for the full parameter reference.

### FOCUS Specification Compliance

The command generates the **Cost and Usage** dataset. The Contract Commitment dataset (introduced in v1.3) is not included.

Column sets vary by FOCUS version:

| Version | Mandatory | Conditional | Total |
| ------- | --------- | ----------- | ----- |
| 1.0     | 32        | 11          | 43    |
| 1.1     | 32        | 13          | 45    |
| 1.2     | 35        | 13          | 48    |
| 1.3     | 37        | 13          | 50    |

Plus FinOps Hub-specific `x_` prefixed extension columns for dashboard compatibility.

> **Note:** All columns are emitted regardless of version (with empty/null values for non-applicable columns) to maintain a consistent Parquet schema. This is intentional for test data compatibility.

### Remove-FinOpsTestData (Clean Reset)

The `Remove-FinOpsTestData` command performs a targeted cleanup for re-testing:

1. **Stops ADF triggers** (optional, with `-StopTriggers -AdfName -ResourceGroupName`) to prevent re-ingestion during cleanup
2. **Purges all ADX tables** in both Hub and Ingestion databases via REST API (requires `-Force`)
3. **Verifies ADX update policies** are intact after clearing tables
4. **Deletes test-data folders from storage** — scans manifests for `_ftkTestData` marker and removes only marked folders (production data is preserved)
5. **Removes local test-data folder**

All cloud parameters are optional. By default only local files are deleted. Pass `-StorageAccountName` for storage cleanup and `-AdxClusterUri -Force` for ADX cleanup.

> **Important:** Do not ingest test data into an ADX cluster that also contains production data. Storage cleanup is targeted (only test-data folders are removed), but ADX `.clear table` removes **all** rows. If you accidentally mix test and production data in ADX, clear the tables and re-ingest production data from storage. This command does not manage Microsoft Fabric data — clean up Fabric resources separately if applicable.

Uses `ConfirmImpact = 'High'` so PowerShell will prompt for confirmation unless `-Confirm:$false` is passed.

Run `Get-Help Remove-FinOpsTestData -Detailed` for the full parameter reference.
