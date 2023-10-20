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

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🔄️ Unreleased](#️-unreleased)
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

🏦 **FinOps hubs**

1. ➕ Added:
   1. New PowerShell commands to manage FinOps hubs 0.1:
      1. Get-FinOpsHub
      2. Initialize-FinOpsHubDeployment
      3. Register-FinOpsHubProviders
      4. Remove-FinOpsHub
   2. Managed exports – Let FinOps hubs manage exports for you.
   3. MCA support – Added support for Microsoft Customer Agreement accounts.
   4. Actual cost data – Ingest both actual and amortized costs.
   5. Auto-backfill – Backfill historical data from Microsoft Cost Management.
   6. Remote hubs – Ingest cost data from other tenants.
   7. Retention – Configure how long you want to keep Cost Management exports and normalized data in storage.
2. ✏️ Changed:
   1. Unified schema – Normalize EA and MCA data to a single, "unified" schema.
      <blockquote class="important" markdown="1">
         _This change requires re-ingesting historical data and is not backwards compatible. The unified schema used in this release is aligned with the future plans for Microsoft Cost Management exports. Note the next release will update the schema to align to the FinOps Open Cost and Usage Specification (FOCUS)._
      </blockquote>

🖥️ **PowerShell for Cost Management**

1. ➕ Added:
   1. Get-FinOpsCostExport command
   2. Remove-FinOpsCostExport command

<br>

## 🚚 v0.1

🖥️ **PowerShell**

1. ➕ Added:
   1. [FinOpsToolkit module](https://aka.ms/finops/toolkit/powershell) released in the PowerShell Gallery.
   2. [Get-FinOpsToolkitVersion](./powershell/toolkit/Get-FinOpsToolkitVersion) to get toolkit versions.

🏦 **FinOps hubs**

1. ➕ Added:
   1. [Deploy-FinOpsHub](./powershell/hubs/Deploy-FinOpsHub) to deploy or update a hub instance.
   2. [Get-FinOpsHub](./powershell/hubs/Get-FinOpsHub) to get details about a hub instance.
2. 🛠️ Fixed:
   1. Storage redundancy dropdown default not set correctly in the create form.
   2. Tags specified in the create form were causing the deployment to fail. See #331.

📊 **Power BI reports**

1. ➕ Added:
   1. Commitments, Savings, Chargeback, Purchases, and Prices pages in the [Commitment discounts report](./power-bi/commitment-discounts.md).
   2. Prices page in the [Cost summary report](./power-bi/cost-summary.md).
   3. [FOCUS sample report](./power-bi/focus.md) – See your data in the FinOps Open Cost and Usage Specification (FOCUS) schema.
   4. [Cost Management template app](./power-bi/template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.
2. ✏️ Changed:
   1. Expanded the FinOps hubs Cost summary and Commitment discounts [Power BI reports](./power-bi/README.md) to support the Cost Management connector.

📒 **Azure Monitor workbooks**

1. ➕ Added:
   1. [Governance workbook](./governance-workbook/README.md) to centralize governance.
1. ✏️ Changed:
   1. [Optimization workbook](./optimization-workbook/README.md) updated to cover more scenarios.

🌐 **Open data**

1. ➕ Added:
   1. [PricingUnits](./open-data/README.md#-pricing-units) to map all pricing units (UnitOfMeasure values) to distinct units with a scaling factor.
   2. [Regions](./open-data/README.md#-regions) to map historical resource location values in Microsoft Cost Management to standard Azure regions.
   3. [Services](./open-data/README.md#-services) to map all resource types to FOCUS service names and categories.

[Download v0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🌱 v0.0.1

🏦 **FinOps hubs**

1. ➕ Added:
   1. [FinOps hub template](./finops-hub/README.md) to deploy a storage account and Data Factory instance.
   2. [Cost summary report](./finops-hub/reports/cost-summary.md) for various out-of-the-box cost breakdowns.
   3. [Commitment discounts report](./finops-hub/reports/commitment-discounts.md) for commitment-based discount reports.

🦾 **Bicep modules**

1. ➕ Added:
   1. [Scheduled action modules](./bicep-registry/README.md#scheduled-actions) submitted to the Bicep Registry.

📒 **Azure Monitor workbooks**

1. ➕ Added:
   1. [Cost optimization workbook](./optimization-workbook/README.md) to centralize cost optimization.

[Download v0.0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
