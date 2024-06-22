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
- [🚚 v0.4](#-v04)
- [🚚 v0.3](#-v03)
- [🚚 v0.2](#-v02)
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

➕ Added
✏️ Changed
🛠️ Fixed
🗑️ Removed

📒 Workbook
🏦 FinOps hubs
🖥️ PowerShell
-->

## 🔄️ Unreleased

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Managed exports – Let FinOps hubs manage exports for you.
> 2. Auto-backfill – Backfill historical data from Microsoft Cost Management.
> 3. Remote hubs – Ingest cost data from other tenants.
> 4. Retention – Configure how long you want to keep Cost Management exports and normalized data in storage.
> 5. Analytics engine – Ingest cost data into an Azure Data Explorer cluster.

<br>

## 🚚 v0.4

📗 FinOps guide
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Documented the [FOCUS export dataset](../_docs/focus/metadata.md) to align to the FOCUS metadata specification.
>
> ✏️ Changed:
>
> 1. Updated [FinOps Framework guidance](../_docs/framework/README.md) to account for the 2024 updates.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> 🛠️ Fixed:
>
> 1. Improved parsing for the `x_ResourceParentName` and `x_ResourceParentType` columns ([#691](https://github.com/microsoft/finops-toolkit/issues/691#issuecomment-2134072033)).
>
> ✏️ Changed
>
> 1. Changed the **Tags** column to default to `{}` when empty to facilitate tag expansion ([#691](https://github.com/microsoft/finops-toolkit/issues/691#issuecomment-2134072033)).

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ✏️ Changed
>
> 1. Updated all [open data files](../_reporting/data/README.md) to include the latest data.
> 2. Changed the primary columns in the [Regions](../_reporting/data/README.md#️-regions) and [Services](../_reporting/data/README.md#️-services) open data files to be lowercase.

<br>

## 🚚 v0.3

📗 FinOps guide
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Moved [Azure FinOps documentation](https://aka.ms/finops/docs) about how to implement and adopt FinOps into the toolkit.
>
> ✏️ Changed:
>
> 1. Rearranged documentation site to better organize content.

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Started archiving template versions so they can be referenced easily via URL microsoft.github.io/finops-toolkit/deploy/finops-hub-{version}.json.
>
> 🛠️ Fixed:
>
> 1. Fixed "missing period" error Data Factory Studio.
> 2. Fixed bug where `msexports_FileAdded` trigger was not getting started.
> 3. Fixed deploy to Azure buttons to point to the latest release.
>
> ✏️ Changed:
>
> 1. Return a single boolean value from the Remove-FinOpsHub command.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added `ResourceParentId`, `ResourceParentName`, and `ResourceParentType` columns to support the usage of the user-defined `cm-resource-parent` tag.
> 2. Added `ToolkitVersion` and `ToolkitTool` columns to help quantify the cost of FinOps toolkit solutions.
> 1. Added a DQ page to the [Commitment discounts report](../_reporting/power-bi/commitment-discounts.md#dq) for data quality validations. This page can be useful in identifying data gaps in Cost Management.
> 2. Added `x_NegotiatedUnitPriceSavings` column to show the price reduction from negotiated discounts compared to the public, list price.
> 3. Added `x_IsFree` column to indicate when a row represents a free charge (based on Cost Management data). This is used in data quality checks.
> 4. Added `Tags` and `TagsAsJson` columns to both the **Usage details** and **Usage details amortized** tables in the [CostManagementTemplateApp report](../_reporting/power-bi/template-app.md) ([#625](https://github.com/microsoft/finops-toolkit/issues/625)).
>
> 🛠️ Fixed:
>
> 1. Fixed numerous errors causing the [Cost Management connector report](../_reporting/power-bi/connector.md) to not load for MCA accounts.
> 2. Fixed incorrect filter in the [Commitment discounts report](../_reporting/power-bi/commitment-discounts.md) ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).
> 3. Fixed data issue where Cost Management uses "1Year", "3Years", and "5Years" for the x_SkuTerm. Values should be 12, 36, and 60 ([#594](https://github.com/microsoft/finops-toolkit/issues/594)).
> 4. Changed the data type for the `x_Month` column to be a date.
> 5. Changed `x_SkuTerm` to be a whole number and to not summarize by default.
> 6. Changed `x_BillingExchangeRate` to not summarize by default.
> 7. Corrected references to x_InvoiceIssuerId and InvoiceIssuerName columns in the [Cost Management connector report](../_reporting/power-bi/connector.md) ([#639](https://github.com/microsoft/finops-toolkit/issues/649)).
> 8. Corrected the datatype for the `x_Month` column.
>
> ✏️ Changed:
>
> 1. Changed "Other" ChargeSubcategory for usage to "On-Demand" to be consistent with Cost Management exports
> 2. Renamed savings columns for consistency:
>    - `x_OnDemandUnitPriceSavings` is now `x_CommitmentUnitPriceSavings`. This shows the commitment discount price reduction compared to the negotiated prices for the account.
>    - `x_ListUnitPriceSavings` is now `x_DiscountUnitPriceSavings`. This shows the price reduction from all discounts compared to the public, list price.
>    - `x_NegotiatedSavings` is now `x_NegotiatedCostSavings`. This shows the cost savings from negotiated discounts only (excluding commitment discounts).
>    - `x_CommitmentSavings` is now `x_CommitmentCostSavings`. This shows the cost savings from commitment discounts compared to on-demand prices for the account (including negotiated discounts).
>    - `x_DiscountSavings` is now `x_DiscountCostSavings`. This shows the cost savings from all negotiated and commitment discounts.
> 3. Changed the `PricingQuantity` and `UsageQuantity` columns to use 3 decimal places.
> 4. Changed all cost columns to use 2 decimal places.
> 5. Changed all unit price columns to not summarize by default and use 3 decimal places.
> 6. Changed the `x_PricingBlockSize` column to a whole number and not summarize by default.
> 7. Renamed the **Coverage** pages in the [Commitment discounts report](../_reporting/power-bi/commitment-discounts.md) to **Recommendations**.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

**May**:
> 1. 🔹 Reservations Recommendations:<br>
> New Tab: We've added a new tab specifically for Reservations recommendations. <br>This tab includes a handy **Break-Even Point** feature, allowing you to prioritize recommendations that will reach their break-even point sooner.
> > :warning: **Permissions**: Please note, this tab now requires Enterprise Admin or Billing Profile Reader permissions. We have kept the old tab for the time being to ensure a smooth transition.
> 2. 🔹 Sustainability: <br>
> Redesigned Tab: The sustainability tab has been completely redesigned with an improved layout, making it easier to understand the provided recommendations.
> 3. 🔹 Networking Tab: <br>
> Query Improvement: The Public IP Addresses query has been enhanced to ignore dynamic IPs, ensuring more accurate results.
> 4. 🔹 Top 10 Services:<br>
> Web App Query Update: The Web App query now ignores the free tier, providing a clearer picture of your top services.

> **April**:
> ➕ Added:
> 1. 1️⃣🕵️‍♂️ Identify Idle ExpressRoute Circuits: Now, easily pinpoint and optimize inactive ExpressRoute circuits to streamline costs.
> 2. 2️⃣ 📊Routing Preference for Public IP Addresses: Gain insights into the routing preferences for your public IP addresses to optimize network performance.
> 3. 3️⃣ 🥧Commitment Discount Savings Summary: Explore a new pie chart summarizing commitment discount savings, providing a clear overview of cost-saving opportunities.
>4.  4️⃣ 💰DDoS-enabled Public IP Addresses Query: Quickly view public IP addresses with DDoS protection enabled and compare if it would be cheaper to enable DDoS to the vNet instead.
> 5. 5️⃣ 💡Azure Hybrid Benefit for SQL Database Elastic Pools: Leverage new queries to identify Azure Hybrid Benefit usage for SQL Database elastic pools, maximizing cost efficiencies.

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Get-FinOpsService](../_automation/powershell/data/Get-FinOpsService.md) includes new `-Environment` and `-ServiceModel` filters and properties in the response ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).
>
> ✏️ Changed:
>
> 1. [Start-FinOpsCostExport](../_automation/powershell/cost/Start-FinOpsCostExport.md) includes a new `-Backfill` option to backfill multiple months.
> 2. [Start-FinOpsCostExport](../_automation/powershell/cost/Start-FinOpsCostExport.md) includes a new `-StartDate` and `-EndDate` options to run the export for a given date range. This can include multiple months.
>
> 🛠️ Fixed:
>
> 1. Fixed ParameterBindingException error in [New-FinOpsCostExport](../_automation/powershell/cost/New-FinOpsCostExport.md).
> 2. Updated the FOCUS dataset version that was changed in Cost Management exports in [New-FinOpsCostExport](../_automation/powershell/cost/New-FinOpsCostExport.md).
> 3. Changed the default `-EndDate` in [New-FinOpsCostExport](../_automation/powershell/cost/New-FinOpsCostExport.md) to be the end of the month due to a breaking change in Cost Management exports.
> 4. Fixed internal command used in [Deploy-FinOpsHub](../_automation/powershell/hubs/Deploy-FinOpsHub.md) that may have caused it to fail for some versions of the Az PowerShell module.

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added ServiceModel and Environment columns to the [services](../_reporting/data/README.md#-services) data ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).
> 2. New and updated [resource types](../_reporting/data/README.md#-resource-types) and icons.

[Download v0.3](https://github.com/microsoft/finops-toolkit/releases/tag/v0.3){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.2...v0.3){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🚚 v0.2

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

<small>**Breaking change**</small>
{: .label .label-red .pt-0 .pl-3 .pr-3 .m-0 }

> 🛠️ Fixed:
>
> 1. Fixed error in some China regions where deployment scripts were not supported ([#259](https://github.com/microsoft/finops-toolkit/issues/259)).
>
> ✏️ Changed:
>
> 1. Switch from amortized cost exports to FOCUS cost exports.
>    <blockquote class="important" markdown="1">
>       _This change requires re-ingesting historical data and is not backwards compatible. The unified schema used in this release is aligned with the future plans for Microsoft Cost Management exports. Note the next release will update the schema to align to the FinOps Open Cost and Usage Specification (FOCUS)._
>    </blockquote>
> 2. Updated ingestion container month folders from `yyyyMMdd-yyyyMMdd` to `yyyyMM`.
> 3. Renamed **msexports_extract** pipeline to **msexports_ExecuteETL**.
> 4. Renamed **msexports_transform** pipeline to **msexports_ETL_ingestion**.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Cost Management connector report](../_reporting/power-bi/connector.md) to support the Cost Management connector.
>
> ✏️ Changed:
>
> 1. Updated [Cost summary](../_reporting/power-bi/cost-summary.md) and [Commitment discounts](../_reporting/power-bi/commitment-discounts.md) reports to [FOCUS 1.0 preview](../_docs/focus/README.md).
> 2. Updated [Cost summary](../_reporting/power-bi/cost-summary.md) and [Commitment discounts](../_reporting/power-bi/commitment-discounts.md) reports to only use [FinOps hubs](../_reporting/hubs/README.md).
> 3. Removed unused custom visualizations.
> 4. Organized setup instructions in Cost summary to match other reports.
> 5. Updated troubleshooting documentation.
>
> 🛠️ Fixed:
>
> 1. Removed sensitivity labels.
> 2. Fixed dynamic data source error when the Power BI service refreshes data.
>    - Error message: "You can't schedule refresh for this semantic model because the following data sources currently don't support refresh..."
> 3. Fixed error in ChargeId column when ResourceId is empty.
> 4. Removed the ChargeId column due to it bloating the data size.
>    - The field is commented out. If interested, you can enable uncomment it in the ftk_NormalizeSchema function. Just be aware that it duplicates a lot of columns to ensure uniqueness which bloats the data size significantly.
> 5. Fixed null error when Billing Account ID is empty ([#473](https://github.com/microsoft/finops-toolkit/issues/473)).
> 6. Added missing commitment discount refunds to the actual cost data ([#447](https://github.com/microsoft/finops-toolkit/issues/447)).

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - [Optimization workbook](../_workbooks/optimization-workbook/README.md):
>   1. Storage: Identify Idle Backups: Review protected items' backup activity to spot items not backed up in the last 90 days.
>   2. Storage: Review Replication Settings: Evaluate and improve your backup strategy by identifying resources with default geo-redundant storage (GRS) replication.
>   3. Networking: Azure Firewall Premium Features: Identify Azure Firewalls with Premium SKU and ensure associated policies leverage premium-only features.
>   4. Networking: Firewall Optimization: Streamline Azure Firewall usage by centralizing instances in the hub virtual network or Virtual WAN secure hub.
>
> ✏️ Changed:
>
> - [Optimization workbook](../_workbooks/optimization-workbook/README.md):
>   1. Top 10 services: Improved Monitoring tabs: Enhance your monitoring experience with updated Azure Advisor recommendations for Log Analytics.
>
> 🛠️ Fixed:
>
> - [Optimization workbook](../_workbooks/optimization-workbook/README.md):
>   1. AHB: Fixed AHB to support Windows 10/Windows 11

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [New-FinOpsCostExport](../_automation/powershell/cost/New-FinOpsCostExport.md) to create and update Cost Management exports.
> 2. [Start-FinOpsCostExport](../_automation/powershell/cost/Start-FinOpsCostExport.md) to run a Cost Management export immediately.
> 3. [Get-FinOpsCostExport](../_automation/powershell/cost/Get-FinOpsCostExport.md) now has a `-RunHistory` option to include the run history of each export.
>
> ✏️ Changed:
>
> 1. Updated the default API version for export commands to `2023-07-01-preview` to leverage new datasets and features.
>    - Specify `2023-08-01` explicitly for the previous API version.
>
> 🛠️ Fixed:
>
> 1. Fixed typo in [Deploy-FinOpsHub](../_automation/powershell/hubs/Deploy-FinOpsHub.md) causing it to fail.
>
> 🗑️ Removed:
>
> 1. `ConvertTo-FinOpsSchema` and `Invoke-FinOpsSchemaTransform` are no longer being maintained and will be removed in a future update.
>    - With native support for FOCUS 1.0 preview in Cost Management, we are deprecating both commands, which only support FOCUS 0.5.
>    - If you would like to see the PowerShell commands updated to 1.0 preview, please let us know in discussions or via a GitHub issue.

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Resource types](../_reporting/data/README.md#-resource-types) to map Azure resource types to friendly display names.
> 2. [Get-FinOpsResourceType](../_automation/powershell/data/Get-FinOpsResourceType.md) PowerShell command to support resource type to display name mapping.
> 3. [Sample exports](../_reporting/data/README.md#-sample-data) for each of the datasets that can be exported from Cost Management.

📗 FinOps guide
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [FinOps Open Cost and Usage Specification (FOCUS) details](../_docs/focus/README.md).

[Download v0.2](https://github.com/microsoft/finops-toolkit/releases/tag/v0.2){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.1.1...v0.2){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🛠️ v0.1.1

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. New PowerShell commands to convert data to FOCUS 0.5:
>    1. [ConvertTo-FinOpsSchema](../_automation/powershell/focus/ConvertTo-FinOpsSchema.md)
>    2. [Invoke-FinOpsSchemaTransform](../_automation/powershell/focus/Invoke-FinOpsSchemaTransform.md)
> 2. New PowerShell commands to get and delete Cost Management exports:
>    1. [Get-FinOpsCostExport](../_automation/powershell/cost/Get-FinOpsCostExport.md)
>    2. [Remove-FinOpsCostExport](../_automation/powershell/cost/Remove-FinOpsCostExport.md)

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. New PowerShell commands to integrate open data to support data cleansing:
>    1. [Get-FinOpsPricingUnit](../_automation/powershell/data/Get-FinOpsPricingUnit.md)
>    2. [Get-FinOpsRegion](../_automation/powershell/data/Get-FinOpsRegion.md)
>    3. [Get-FinOpsService](../_automation/powershell/data/Get-FinOpsService.md)

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. New PowerShell commands to manage FinOps hubs 0.1:
>    1. [Get-FinOpsHub](../_automation/powershell/hubs/Get-FinOpsHub.md)
>    2. [Initialize-FinOpsHubDeployment](../_automation/powershell/hubs/Initialize-FinOpsHubDeployment.md)
>    3. [Register-FinOpsHubProviders](../_automation/powershell/hubs/Register-FinOpsHubProviders.md)
>    4. [Remove-FinOpsHub](../_automation/powershell/hubs/Remove-FinOpsHub.md)

[Download v0.1.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.1...v0.1.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🚚 v0.1

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [FinOpsToolkit module](https://aka.ms/finops/toolkit/powershell) released in the PowerShell Gallery.
> 2. [Get-FinOpsToolkitVersion](../_automation/powershell/toolkit/Get-FinOpsToolkitVersion.md) to get toolkit versions.

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Deploy-FinOpsHub](../_automation/powershell/hubs/Deploy-FinOpsHub.md) to deploy or update a hub instance.
> 2. [Get-FinOpsHub](../_automation/powershell/hubs/Get-FinOpsHub.md) to get details about a hub instance.
> 3. Support for Microsoft Customer Agreement (MCA) accounts and Cloud Solution Provider (CSP) subscriptions in Power BI reports.
>
> 🛠️ Fixed:
>
> 1. Storage redundancy dropdown default not set correctly in the create form.
> 2. Tags specified in the create form were causing the deployment to fail ([#331](https://github.com/microsoft/finops-toolkit/issues/331)).

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Commitments, Savings, Chargeback, Purchases, and Prices pages in the [Commitment discounts report](../_reporting/power-bi/commitment-discounts.md).
> 2. Prices page in the [Cost summary report](../_reporting/power-bi/cost-summary.md).
> 3. [FOCUS sample report](../_reporting/power-bi/focus.md) – See your data in the FinOps Open Cost and Usage Specification (FOCUS) schema.
> 4. [Cost Management template app](../_reporting/power-bi/template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.
>
> ✏️ Changed:
>
> 1. Expanded the FinOps hubs Cost summary and Commitment discounts [Power BI reports](../_reporting/power-bi/README.md) to support the Cost Management connector.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Governance workbook](../_workbooks/governance-workbook/README.md) to centralize governance.
>
> ✏️ Changed:
>
> 1. [Optimization workbook](../_workbooks/optimization-workbook/README.md) updated to cover more scenarios.

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Pricing units](../_reporting/data/README.md#-pricing-units) to map all pricing units (UnitOfMeasure values) to distinct units with a scaling factor.
> 2. [Regions](../_reporting/data/README.md#-regions) to map historical resource location values in Microsoft Cost Management to standard Azure regions.
> 3. [Services](../_reporting/data/README.md#-services) to map all resource types to FOCUS service names and categories.

[Download v0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1){: .btn .btn-primary .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.0.1...v0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🌱 v0.0.1

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [FinOps hub template](../_reporting/hubs/README.md) to deploy a storage account and Data Factory instance.
> 2. [Cost summary report](../_reporting/power-bi/cost-summary.md) for various out-of-the-box cost breakdowns.
> 3. [Commitment discounts report](../_reporting/power-bi/commitment-discounts.md) for commitment-based discount reports.

🦾 Bicep modules
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Scheduled action modules](../_automation/bicep-registry/README.md#scheduled-actions) submitted to the Bicep Registry.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Cost optimization workbook](../_workbooks/optimization-workbook/README.md) to centralize cost optimization.

[Download v0.0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/878e4864ca785db4fc13bdd2ec3a6a00058688c3...v0.0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
