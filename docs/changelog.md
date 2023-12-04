---
layout: default
title: Changelog
nav_order: zzz
description: 'Latest and greatest features and enhancements from the FinOps toolkit.'
permalink: /changelog
---

<span class="fs-9 d-block mb-4">FinOps toolkit changelog</span>
Explore the latest and greatest features and enhancements from the FinOps toolkit.
{: .fs-6 .fw-300 }

[Download the latest release](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[See changes](#-v01){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🔄️ Unreleased](#️-unreleased)
- [🛠️ v0.1.1](#️-v011)
- [🚚 v0.1](#-v01)
- [🌱 v0.0.1](#-v001)

</details>

---

<!-- markdownlint-disable MD036 -->

<!--
Legend:
🔄️ Unreleased
🚀🎉 Major
🚚💎 Minor
🛠️✨ Patch
🪛⬆️ Update
🌱 Pre-release
-->

## 🔄️ Unreleased

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Managed exports – Let FinOps hubs manage exports for you.
> 2. MCA support – Added support for Microsoft Customer Agreement accounts.
> 3. Actual cost data – Ingest both actual and amortized costs.
> 4. Auto-backfill – Backfill historical data from Microsoft Cost Management.
> 5. Remote hubs – Ingest cost data from other tenants.
> 6. Retention – Configure how long you want to keep Cost Management exports and normalized data in storage.
> 7. Analytics engine – Ingest cost data into an Azure Data Explorer cluster.
>
> ✏️ Changed:
>
> 1. Unified schema – Normalize EA and MCA data to a single, "unified" schema.
>    <blockquote class="important" markdown="1">
>       _This change requires re-ingesting historical data and is not backwards compatible. The unified schema used in this release is aligned with the future plans for Microsoft Cost Management exports. Note the next release will update the schema to align to the FinOps Open Cost and Usage Specification (FOCUS)._
>    </blockquote>

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ✏️ Changed:
>
> 1. Removed unused custom visualizations.
> 2. Organized setup instructions in Cost summary to match other reports.
>
> 🛠️ Fixed:
>
> 1. Removed sensitivity labels.
> 2. Fixed error in ChargeId column when ResourceId is empty.
> 3. Fixed null error when Billing Account ID is empty ([#473](https://github.com/microsoft/finops-toolkit/issues/473)).

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. New-FinOpsCostExport
> 2. Remove-FinOpsHubScope

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Resource types](./open-data/README.md#-resource-types) to map Azure resource types to friendly display names.
> 2. [Get-FinOpsResourceType](./powershell/data/Get-FinOpsResourceType.md) PowerShell command to support resource type to display name mapping.

<br>

## 🛠️ v0.1.1

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. New PowerShell commands to convert data to FOCUS 0.5:
>    1. [ConvertTo-FinOpsSchema](./powershell/focus/ConvertTo-FinOpsSchema.md)
>    2. [Invoke-FinOpsSchemaTransform](./powershell/focus/Invoke-FinOpsSchemaTransform.md)
> 2. New PowerShell commands to get and delete Cost Management exports:
>    1. Get-FinOpsCostExport
>    2. Remove-FinOpsCostExport

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. New PowerShell commands to integrate open data to support data cleansing:
>    1. [Get-FinOpsPricingUnit](./powershell/data/Get-FinOpsPricingUnit.md)
>    2. [Get-FinOpsRegion](./powershell/data/Get-FinOpsRegion.md)
>    3. [Get-FinOpsService](./powershell/data/Get-FinOpsService.md)

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. New PowerShell commands to manage FinOps hubs 0.1:
>    1. Get-FinOpsHub
>    2. Initialize-FinOpsHubDeployment
>    3. Register-FinOpsHubProviders
>    4. Remove-FinOpsHub

[Download v0.1.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.1...v0.1.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🚚 v0.1

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [FinOpsToolkit module](https://aka.ms/finops/toolkit/powershell) released in the PowerShell Gallery.
> 2. [Get-FinOpsToolkitVersion](./powershell/toolkit/Get-FinOpsToolkitVersion) to get toolkit versions.

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Deploy-FinOpsHub](./powershell/hubs/Deploy-FinOpsHub) to deploy or update a hub instance.
> 2. [Get-FinOpsHub](./powershell/hubs/Get-FinOpsHub) to get details about a hub instance.
> 3. Support for Microsoft Customer Agreement (MCA) in Power BI reports.
>
> 🛠️ Fixed:
>
> 1. Storage redundancy dropdown default not set correctly in the create form.
> 2. Tags specified in the create form were causing the deployment to fail. See #331.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Commitments, Savings, Chargeback, Purchases, and Prices pages in the [Commitment discounts report](./power-bi/commitment-discounts.md).
> 2. Prices page in the [Cost summary report](./power-bi/cost-summary.md).
> 3. [FOCUS sample report](./power-bi/focus.md) – See your data in the FinOps Open Cost and Usage Specification (FOCUS) schema.
> 4. [Cost Management template app](./power-bi/template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.
>
> ✏️ Changed:
>
> 1. Expanded the FinOps hubs Cost summary and Commitment discounts [Power BI reports](./power-bi/README.md) to support the Cost Management connector.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Governance workbook](./governance-workbook/README.md) to centralize governance.
>
> ✏️ Changed:
>
> 1. [Optimization workbook](./optimization-workbook/README.md) updated to cover more scenarios.

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Pricing units](./open-data/README.md#-pricing-units) to map all pricing units (UnitOfMeasure values) to distinct units with a scaling factor.
> 2. [Regions](./open-data/README.md#-regions) to map historical resource location values in Microsoft Cost Management to standard Azure regions.
> 3. [Services](./open-data/README.md#-services) to map all resource types to FOCUS service names and categories.

[Download v0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1){: .btn .btn-primary .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.0.1...v0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🌱 v0.0.1

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [FinOps hub template](./finops-hub/README.md) to deploy a storage account and Data Factory instance.
> 2. [Cost summary report](./power-bi/cost-summary.md) for various out-of-the-box cost breakdowns.
> 3. [Commitment discounts report](./power-bi/commitment-discounts.md) for commitment-based discount reports.

🦾 Bicep modules
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Scheduled action modules](./bicep-registry/README.md#scheduled-actions) submitted to the Bicep Registry.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Cost optimization workbook](./optimization-workbook/README.md) to centralize cost optimization.

[Download v0.0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/878e4864ca785db4fc13bdd2ec3a6a00058688c3...v0.0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
