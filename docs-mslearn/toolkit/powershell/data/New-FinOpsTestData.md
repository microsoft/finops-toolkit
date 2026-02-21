---
title: New-FinOpsTestData command
description: Generate synthetic, multi-cloud FOCUS-compliant cost data for FinOps Hub validation using the New-FinOpsTestData command in the FinOpsToolkit module.
author: fallenhoot
ms.author: josholan
ms.date: 02/21/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps practitioner, I want to generate synthetic test data to validate my FinOps hub deployment.
---

<!-- markdownlint-disable-next-line MD025 -->

# New-FinOpsTestData command

The **New-FinOpsTestData** command generates synthetic, multi-cloud FOCUS-compliant cost data for Azure, AWS, GCP, and on-premises providers. Use it to populate a FinOps hub with realistic test data for validation, demos, and development. Generated data is compatible with both Azure Data Explorer and Microsoft Fabric Real-Time Intelligence ingestion paths.

The generated data includes:

- **Cost and usage data** for all four providers following the FOCUS specification (versions 1.0–1.3)
- **Price sheet data** (Azure EA/MCA price sheet simulation)
- **Commitment discount usage** (reservation details)
- **Recommendations** (reservation recommendations)
- **Transactions** (reservation transactions)

Features include version-specific column sets, commitment discount simulation, Azure Hybrid Benefit rows, tag variation (~20% untagged), data quality anomaly rows, negotiated discount rows, persistent resources across days, inline budget scaling, and reproducible output via the `-Seed` parameter.

<br>

## Syntax

```powershell
New-FinOpsTestData `
    [-OutputPath <string>] `
    [-ServiceProvider <string>] `
    [-MonthsOfData <int>] `
    [-StartDate <datetime>] `
    [-EndDate <datetime>] `
    [-RowCount <int>] `
    [-TotalCost <decimal>] `
    [-FocusVersion <string>] `
    [-OutputFormat <string>] `
    [-StorageAccountName <string>] `
    [-ResourceGroupName <string>] `
    [-AdfName <string>] `
    [-StartTriggers] `
    [-Seed <int>]
```

<br>

## Parameters

| Name                  | Description                                                                                                                                                                         |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑OutputPath`         | Optional. Directory to save generated files. Default = `./test-data`.                                                                                                               |
| `‑ServiceProvider`    | Optional. Which cloud provider data to generate. Allowed values: `Azure`, `AWS`, `GCP`, `DataCenter`, `All`. Default = `All`.                                                       |
| `‑MonthsOfData`       | Optional. Number of months of historical data to generate, ending at today. Default = `6`.                                                                                          |
| `‑StartDate`          | Optional. Start date for generated data. Overrides MonthsOfData if specified.                                                                                                       |
| `‑EndDate`            | Optional. End date for generated data. Default = today.                                                                                                                             |
| `‑RowCount`           | Optional. Target total rows across all providers and days. Rows are distributed approximately 60% Azure, 20% AWS, 15% GCP, 5% DataCenter. Default = `500000`.                       |
| `‑TotalCost`          | Optional. Target total cost in USD. Costs are scaled proportionally during generation. Default = `500000`.                                                                          |
| `‑FocusVersion`       | Optional. FOCUS specification version. Allowed values: `1.0`, `1.1`, `1.2`, `1.3`. The output column set varies per version. Default = `1.3`.                                       |
| `‑OutputFormat`       | Optional. Output file format. Allowed values: `CSV`, `Parquet`. Parquet requires the [PSParquet](https://www.powershellgallery.com/packages/PSParquet) module. Default = `Parquet`. |
| `‑StorageAccountName` | Optional. Azure Storage account name. When specified, generated files are uploaded to Azure Storage using Microsoft Entra ID authentication after generation completes.             |
| `‑ResourceGroupName`  | Optional. Resource group containing the storage account and Azure Data Factory instance. Required when using `-StartTriggers`.                                                      |
| `‑AdfName`            | Optional. Azure Data Factory name. Required when using `-StartTriggers` to start or verify ADF triggers before uploading data.                                                      |
| `‑StartTriggers`      | Optional. Start ADF triggers before upload so Event Grid blob-created events are captured. Triggers must be running for Event Grid to fire ADF pipelines.                           |
| `‑Seed`               | Optional. Random seed for reproducible test data generation. The same seed with the same parameters produces identical output.                                                      |

<br>

## Prerequisites

- PowerShell 7.0 or later
- [PSParquet](https://www.powershellgallery.com/packages/PSParquet) module (required for Parquet output, install with `Install-Module PSParquet`)
- [Az.Storage](https://www.powershellgallery.com/packages/Az.Storage) module (required for storage upload)
- [Az.DataFactory](https://www.powershellgallery.com/packages/Az.DataFactory) module (required for `-StartTriggers`)

<br>

## Examples

### Generate default test data

```powershell
New-FinOpsTestData
```

Generates 6 months of FOCUS 1.3 data for all providers with 500K rows and $500K total cost.

### Generate a small dataset

```powershell
New-FinOpsTestData -MonthsOfData 3 -RowCount 100000 -TotalCost 50000
```

Generates 3 months of data with 100K rows and $50K total cost.

### Generate Azure-only FOCUS 1.0 data

```powershell
New-FinOpsTestData -FocusVersion 1.0 -ServiceProvider Azure -RowCount 50000
```

Generates FOCUS 1.0 Azure-only data with the 1.0 column set.

### Generate and upload to a FinOps hub

```powershell
New-FinOpsTestData `
    -StorageAccountName "stfinopshub" `
    -ResourceGroupName "rg-finopshub" `
    -AdfName "adf-finopshub" `
    -StartTriggers
```

Generates data, ensures ADF triggers are running, then uploads to Azure Storage for hub ingestion.

> [!TIP]
> Use a separate FinOps hub instance for test data. If test data is uploaded to a hub that also contains production data, storage cleanup can target only test-data folders, but Azure Data Explorer `.clear table` removes **all** rows. See [Remove-FinOpsTestData](Remove-FinOpsTestData.md) for details.

### Generate reproducible test data

```powershell
New-FinOpsTestData -Seed 42 -RowCount 1000
```

Generates reproducible test data. Running with the same seed and parameters produces identical output.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/TestData.NewFinOpsTestData)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related commands:

- [Remove-FinOpsTestData](Remove-FinOpsTestData.md) – Remove test data from a FinOps hub environment.

Related solutions:

- [FinOps hubs](../../hubs/finops-hubs-overview.md)
- [FinOps toolkit Power BI reports](../../power-bi/reports.md)

<br>
