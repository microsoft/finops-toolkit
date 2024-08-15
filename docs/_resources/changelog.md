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
[See changes](#latest){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🔄️ Unreleased](#️-unreleased)
- [🚚 v0.5](#-v05)
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
🚫 Deprecated
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
> 1. Analytics engine – Ingest cost data into an Azure Data Explorer cluster.
> 2. Auto-backfill – Backfill historical data from Microsoft Cost Management.
> 3. Retention – Configure how long you want to keep Cost Management exports and normalized data in storage.

<br><a name="latest"></a>

## 🚚 v0.5

<sup>Released August 2024</sup>

📗 FinOps guide
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Documented [how to compare FOCUS and actual/amortized data](../_docs/focus/validate.md) to learn and validate FOCUS data.

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added an optional `skipEventGridRegistration` template parameter to support skipping Event Grid RP registration.
> 2. Added an Event Grid section to the hubs create form.
>
> ✏️ Changed:
>
> 1. Changed the Event Grid location selection logic to only identify fallback regions rather than supported regions.
> 2. Expanded cost estimate documentation to call out Power BI pricing and include a link to the Pricing Calculator.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - [Optimization workbook](../_optimize/optimization-workbook/README.md):
>   1. New compute query to identify VMs per processor architecture type
>   2. New database query to identify SQL Pool instances with 0 databases
>   3. New storage query to identify Powered Off VMs with Premium Disks
>
> ✏️ Changed:
>
> - [Optimization workbook](../_optimize/optimization-workbook/README.md):
>   1. Redesign of the Rate Optimization tab for easier identification of the break-even point for reservations
>   2. Fixed the AHB VMSS query to count the total cores consumed per the entire scale set
>   3. Improved storage idle disks query to ignore disks used by AKS pods
>   4. Updated Storage not v2 query to exclude blockBlobStorage accounts from the list
>   5. Added export option for the list of idle backups to streamline data extraction
> - [Governance workbook](../_optimize/governance-workbook/README.md):
>   1. Removed the management group filter to simplify filtering by subscription.

🔍 Optimization engine
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. `Register-MultitenantAutomationSchedules` PowerShell script helper to [add a different Azure tenant to the scope of AOE](../_optimize/optimization-engine/customize.md).
> 2. ZRS disks included in the scope of the `Premium SSD disk has been underutilized` recommendation (besides LRS).
> 3. Option to scope consumption exports to MCA Billing Profile.
>
> ✏️ Changed:
>
> 1. Improved SQL Database security, replacing SQL authentication by Entra ID authentication-only.
>
> 🛠️ Fixed:
>
> 1. `Premium SSD disk has been underutilized` recommendation was not showing results due to a meter name change in Cost Management ([#831](https://github.com/microsoft/finops-toolkit/issues/831)).
> 2. Consumption exports for Pay-As-You-Go MCA subscriptions were missing cost data ([#828](https://github.com/microsoft/finops-toolkit/issues/828))

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added support for FOCUS, pricesheet, and reservation dataset filters in [Get-FinOpsCostExport](../_automation/powershell/cost/Get-FinOpsCostExport.md).
> 2. Added a `-DatasetVersion` filter in [Get-FinOpsCostExport](../_automation/powershell/cost/Get-FinOpsCostExport.md).

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ✏️ Changed
>
> - [Services](../_reporting/data/README.md#️-services)
>   1. Moved Microsoft Genomics from the "AI and Machine Learning" service category to "Analytics".
>   2. Changed Microsoft Genomics from the "SaaS" service model to "PaaS".
>   3. Replace "Azure Active Directory" service name references with "Microsoft Entra".
>   4. Move Azure Cache for Redis from the "Storage" service category to "Databases".
>   5. Move Event Hubs from the "Integration" service category to "Analytics".
>   6. Rename the Microsoft.HybridCompute consumed service service name from "Azure Resource Manager" to "Azure Arc".
>   7. Move Microsoft Defender for Endpoint from the "Multicloud" service category to "Security".
>   8. Move StorSimple from the "Multicloud" service category to "Storage".

[Download v0.5](https://github.com/microsoft/finops-toolkit/releases/tag/v0.5){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.4...v0.5){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🚚 v0.4

<sup>Released July 12, 2024</sup>

📗 FinOps guide
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Documented the [FOCUS export dataset](../_docs/focus/metadata.md) to align to the FOCUS metadata specification.
>
> ✏️ Changed:
>
> 1. Updated [FinOps Framework guidance](../_docs/framework/README.md) to account for the 2024 updates.
> 2. Updated [FOCUS guidance](../_docs/focus/README.md) to FOCUS 1.0.

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Ingest FOCUS 1.0 data in FinOps hubs.
> 2. Grant access to FinOps hubs to [create and manage exports](../_reporting/hubs/configure-scopes.md#-configure-managed-exports) for you.
> 3. Connect to a hub instance in another Entra ID tenant.
> 4. Step-by-step troubleshooting guide and expanded set of common errors for validating FinOps hubs and Power BI setup.
>
> 🛠️ Fixed:
>
> 1. Fixed an issue where some dates are showing as off by 1 based on local time zone.
>    - If you see dates that are off, upgrade to 0.4 and re-export those months. The fix is in ingestion.
>    - You can re-export data in FOCUS 1.0 or FOCUS 1.0 preview. We recommend FOCUS 1.0 for slightly faster refresh times in Power BI.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - General:
>   1. **x_IncrementalRefreshDate** column to facilitate configuring incremental refresh in Power BI.
>   2. Step-by-step troubleshooting guide and expanded set of common errors for validating Power BI setup.
> - [Cost summary](../_reporting/power-bi/cost-summary.md):
>   1. Resource count and cost per resource in the [Inventory page](../_reporting/power-bi/cost-summary.md#inventory).
> - [Data ingestion](../_reporting/power-bi/data-ingestion.md):
>   1. [Ingestion errors page](../_reporting/power-bi/data-ingestion.md#ingestion-errors) to help identify FinOps hub data ingestion issues.
>
> ✏️ Changed
>
> - General:
>   1. Changed the **Tags** column to default to `{}` when empty to facilitate tag expansion ([#691](https://github.com/microsoft/finops-toolkit/issues/691#issuecomment-2134072033)).
>   2. Simplified formatting for the `BillingPeriod` and `ChargePeriod` measures in Power BI.
>   3. Improved error handling for derived savings columns in the CostDetails query.
>   4. Simplified queries and improved error handling in the START HERE query for report setup steps.
>   5. Changed internal storage for reports to use [Tabular Model Definition Language (TMDL)](https://learn.microsoft.com/power-bi/developer/projects/projects-dataset#tmdl-format).
>      - This change makes it easier to review changes to the data model in Power BI.
>      - Reports will still be released as PBIX files so this change should not impact end users.
>      - Visualizations are not being switched to [Power BI Enhanced Report (PBIR)](https://learn.microsoft.com/power-bi/developer/projects/projects-report#pbir-format) format yet due to functional limitations that would impact end users (as of June 2024).
> - [Cost summary](../_reporting/power-bi/cost-summary.md):
>   1. Changed the [Cost summary Purchases page](../_reporting/power-bi/cost-summary.md#purchases) and [Rate optimization Purchases page](../_reporting/power-bi/rate-optimization.md#purchases) to use PricingQuantity instead of Usage/ConsumedQuantity and added the PricingUnit column.
>   2. Updated the [DQ page](../_reporting/power-bi/cost-summary.md#dq) to identify empty ChargeDescription rows.
>   3. Updated the [DQ page](../_reporting/power-bi/cost-summary.md#dq) to identify potentially missing rounding adjustments.
> - [Rate optimization](../_reporting/power-bi/rate-optimization.md):
>   1. Renamed the "Commitment discounts" report to "Rate optimization" to align to the FinOps Framework 2024 updates.
> - [Data ingestion](../_reporting/power-bi/data-ingestion.md):
>   1. Optimized [Data ingestion report](../_reporting/power-bi/data-ingestion.md) queries to reduce memory footprint and load faster.
>      <blockquote class="warning" markdown="1">
>         _We are investigating an issue where we are missing rounding adjustments since May 2024. We do not yet know the cause of this issue._
>      </blockquote>
>
> 🛠️ Fixed:
>
> - General:
>   1. Improved parsing for the `x_ResourceParentName` and `x_ResourceParentType` columns ([#691](https://github.com/microsoft/finops-toolkit/issues/691#issuecomment-2134072033)).
> - [Rate optimization](../_reporting/power-bi/rate-optimization.md):
>   1. Added error handling for missing `normalizedSize` and `recommendedQuantityNormalized` columns in the [Rate optimization (Commitment discounts) report](../_reporting/power-bi/rate-optimization.md) ([#702](https://github.com/microsoft/finops-toolkit/issues/702)).
> - [Data ingestion](../_reporting/power-bi/data-ingestion.md):
>   1. Fixed error in [Data ingestion report](../_reporting/power-bi/data-ingestion.md) queries.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - [Optimization workbook](../_optimize/optimization-workbook/README.md):
>   1. Added reservation recommendations with the break-even point to identify when savings would be achieved.
>   2. Identify idle ExpressRoute circuits to streamline costs.
>   3. Gain insights into the routing preferences for public IP addresses to optimize network performance.
>   4. Explore commitment discount savings to get a clear overview of rate optimization opportunities.
>   5. Quickly view public IP addresses with DDoS protection enabled and compare if it would be cheaper to enable DDoS to the vNet instead.
>   6. Identify Azure Hybrid Benefit usage for SQL Database elastic pools to maximize cost efficiency.
>    
> - [Governance workbook](../_optimize/governance-workbook/README.md):
>   1. Added managed disk usage monitoring.

> ✏️ Changed:
>
> - [Optimization workbook](../_optimize/optimization-workbook/README.md):
>   1. Redesigned the Sustainability tab to clarify recommendations.
>   2. Ignore dynamic IPs in the public IP addresses list to ensure more accurate results.
>   3. Ignore free tier web apps to provide a clearer picture of your top services.
>
> - [Governance workbook](../_optimize/governance-workbook/README.md):
>   1. Overview has been revised to align with the latest governance principles of the cloud adoption framework.

🔍 Optimization engine
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added Azure Optimization Engine (AOE), an extensible solution for custom optimization recommendations.

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added progress tracking to [Start-FinOpsCostExport](../_automation/powershell/cost/Start-FinOpsCostExport.md) for multi-month exports.
> 2. Added a 60-second delay when Cost Management returns throttling (429) errors in [Start-FinOpsCostExport](../_automation/powershell/cost/Start-FinOpsCostExport.md).
>
> ✏️ Changed:
>
> 1. Updated [New-FinOpsCostExport](../_automation/powershell/cost/New-FinOpsCostExport.md) to default to FOCUS 1.0.
>
> 🗑️ Removed:
>
> 1. Removed support for Windows PowerShell.
>    > _We discovered errors with Windows PowerShell due to incompatibilities in Windows PowerShell and PowerShell 7. Due to our limited capacity, we decided to only support [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) going forward._
> 2. Removed `ConvertTo-FinOpsSchema` and `Invoke-FinOpsSchemaTransform` commands which were deprecated in [0.2 (January 2024)](#-v02).

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added a new FOCUS 1.0 [dataset example](../_reporting/data/README.md#️-dataset-examples).
> 2. Added [dataset metadata](../_reporting/data/README.md#️-dataset-metadata) for FOCUS 1.0 and FOCUS 1.0-preview.
>
> ✏️ Changed
>
> 1. Updated all [open data files](../_reporting/data/README.md) to include the latest data.
> 2. Changed the primary columns in the [Regions](../_reporting/data/README.md#️-regions) and [Services](../_reporting/data/README.md#️-services) open data files to be lowercase.
> 3. Updated all [sample exports](../_reporting/data/README.md#️-dataset-examples) to use the same date range as the FOCUS 1.0 dataset.

[Download v0.4](https://github.com/microsoft/finops-toolkit/releases/tag/v0.4){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.3...v0.4){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🚚 v0.3

<sup>Released March 28, 2024</sup>

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
> 3. Added a DQ page to the [Commitment discounts report](../_reporting/power-bi/rate-optimization.md#dq) for data quality validations. This page can be useful in identifying data gaps in Cost Management.
> 4. Added `x_NegotiatedUnitPriceSavings` column to show the price reduction from negotiated discounts compared to the public, list price.
> 5. Added `x_IsFree` column to indicate when a row represents a free charge (based on Cost Management data). This is used in data quality checks.
> 6. Added `Tags` and `TagsAsJson` columns to both the **Usage details** and **Usage details amortized** tables in the [CostManagementTemplateApp report](../_reporting/power-bi/template-app.md) ([#625](https://github.com/microsoft/finops-toolkit/issues/625)).
>
> 🛠️ Fixed:
>
> 1. Fixed numerous errors causing the [Cost Management connector report](../_reporting/power-bi/connector.md) to not load for MCA accounts.
> 2. Fixed incorrect filter in the [Commitment discounts report](../_reporting/power-bi/rate-optimization.md) ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).
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
> 7. Renamed the **Coverage** pages in the [Commitment discounts report](../_reporting/power-bi/rate-optimization.md) to **Recommendations**.

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

<sup>Released January 22, 2024</sup>

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
> 1. Updated [Cost summary](../_reporting/power-bi/cost-summary.md) and [Commitment discounts](../_reporting/power-bi/rate-optimization.md) reports to [FOCUS 1.0 preview](../_docs/focus/README.md).
> 2. Updated [Cost summary](../_reporting/power-bi/cost-summary.md) and [Commitment discounts](../_reporting/power-bi/rate-optimization.md) reports to only use [FinOps hubs](../_reporting/hubs/README.md).
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
> - [Optimization workbook](../_optimize/optimization-workbook/README.md):
>   1. Storage: Identify Idle Backups: Review protected items' backup activity to spot items not backed up in the last 90 days.
>   2. Storage: Review Replication Settings: Evaluate and improve your backup strategy by identifying resources with default geo-redundant storage (GRS) replication.
>   3. Networking: Azure Firewall Premium Features: Identify Azure Firewalls with Premium SKU and ensure associated policies leverage premium-only features.
>   4. Networking: Firewall Optimization: Streamline Azure Firewall usage by centralizing instances in the hub virtual network or Virtual WAN secure hub.
>
> ✏️ Changed:
>
> - [Optimization workbook](../_optimize/optimization-workbook/README.md):
>   1. Top 10 services: Improved Monitoring tabs: Enhance your monitoring experience with updated Azure Advisor recommendations for Log Analytics.
>
> 🛠️ Fixed:
>
> - [Optimization workbook](../_optimize/optimization-workbook/README.md):
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
> 🚫 Deprecated:
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

<sup>Released October 26, 2023</sup>

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

<sup>Released October 22, 2023</sup>

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
> 1. Commitments, Savings, Chargeback, Purchases, and Prices pages in the [Commitment discounts report](../_reporting/power-bi/rate-optimization.md).
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
> 1. [Governance workbook](../_optimize/governance-workbook/README.md) to centralize governance.
>
> ✏️ Changed:
>
> 1. [Optimization workbook](../_optimize/optimization-workbook/README.md) updated to cover more scenarios.

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

<sup>Released May 27, 2023</sup>

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [FinOps hub template](../_reporting/hubs/README.md) to deploy a storage account and Data Factory instance.
> 2. [Cost summary report](../_reporting/power-bi/cost-summary.md) for various out-of-the-box cost breakdowns.
> 3. [Commitment discounts report](../_reporting/power-bi/rate-optimization.md) for commitment-based discount reports.

🦾 Bicep modules
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Scheduled action modules](../_automation/bicep-registry/README.md#scheduled-actions) submitted to the Bicep Registry.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Cost optimization workbook](../_optimize/optimization-workbook/README.md) to centralize cost optimization.

[Download v0.0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/878e4864ca785db4fc13bdd2ec3a6a00058688c3...v0.0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
