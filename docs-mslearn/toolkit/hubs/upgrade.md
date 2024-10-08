---
title: Upgrade guide
description: Upgrade an existing FinOps hub instance to the latest version.
author: bandersmsft
ms.author: banders
ms.date: 10/03/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
---

<!-- markdownlint-disable-next-line MD025 -->
# Upgrading FinOps hubs

Upgrade an existing FinOps hub instance to the latest version to leverage new capabilities.

Upgrading a FinOps hub instance is usually the same as the initial setup but depending on what version you're moving from or to, you may have specific steps that are needed. Use the following sections to move from one version to another. If you have any questions, please [start a discussion](https://aka.ms/discuss).

<br>

## Before you begin

Before you upgrade, make sure you know what version you're currently running. You can find the version in the storage account:

1. Open the storage account in the Azure portal
   - You can navigate from the [resource group](https://portal.azure.com/#browse/resourcegroups) or the [list of storage accounts](https://portal.azure.com/#browse/Microsoft.Storage%2FStorageAccounts).
   - If you use the list of storage accounts, add a tag filter for `cm-resource-parent` contains `Microsoft.Cloud/hubs` to see all hub storage accounts.
2. Open **Storage browser** > **Blob containers** > **config**
3. Find the **settings.json** row and select the **⋯** menu on the right, then **View/edit**.
4. Look for the **version** property.

<br>

## Upgrading 0.0.1

FinOps hubs `0.0.1` was the initial release and was intentionally scoped down in capabilities to get something out that we could start to collect feedback on. This release was intended for supporting amortized cost only but it did not make any assumptions about the data, which means you could connect it to any export type or account type. Power BI reports in `0.0.1` only worked with Enterprise Agreement (EA) accounts. Refer to the subsections below if you have another account type.

Please use the following sections to determine the best steps to upgrade your hub instance.

### MOSA and Microsoft internal subscriptions for 0.0.1

Microsoft Online Services Agreement (MOSA, aka PAYG) and Microsoft internal subscriptions are not supported in FinOps hubs `0.2` or later. You can use Power BI reports from the `0.1.1` release or the FinOps toolkit PowerShell module `0.1.1`, but there is no need to upgrade your hub instance. Changes were internal or only apply to initial onboarding. Please contact support about transitioning to a Microsoft Customer Agreement account.

[Download 0.1.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1) &nbsp; [Install PowerShell](https://aka.ms/ftk/ps#install-the-module)

### EA and MCA accounts for 0.0.1

If you have an EA or MCA account, please upgrade to `0.2` which uses the new [FOCUS](../../focus/what-is-focus.md) cost data format and covers both billed (actual) and amortized costs with 30% less data size (and storage costs). This will be the baseline for all future updates.

[See 0.2 upgrade instructions](#ea-and-mca-accounts-for-01x) &nbsp; [View changes](https://aka.ms/ftk/changes#-v01)

<br>

## Upgrading 0.1.x

FinOps hubs received small internal updates in `0.1` and `0.1.1`.

Please use the following sections to determine the best steps to upgrade your hub instance.

### MOSA and Microsoft internal subscriptions for 0.1.x

Microsoft Online Services Agreement (MOSA, aka PAYG) and Microsoft internal subscriptions are not supported in FinOps hubs `0.2` or later. You can use Power BI reports from the `0.1.1` release or the FinOps toolkit PowerShell module `0.1.1`, but there is no need to upgrade your hub instance. Please contact support about transitioning to a Microsoft Customer Agreement account.

[Download 0.1.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1) &nbsp; [Install PowerShell](https://aka.ms/ftk/ps#install-the-module)

### EA and MCA accounts for 0.1.x

FinOps hubs `0.2` and later use the [FOCUS](../../focus/what-is-focus.md) cost data format which covers both billed (actual) and amortized costs. FOCUS allows viewing EA and MCA data together and is 30% smaller than actual + amortized datasets combined, which reduces your (storage costs). See [FOCUS benefits](../../focus/what-is-focus.md#benefits) for additional benefits.

> [!IMPORTANT]
> Cost Management has a limitation with the new exports that limits them to the last 13 months. If you need data older than 13 months, please contact support to request support for historical data. The following details are based on this current limitation (as of January 2024).

Before you upgrade, consider the following:

1. How much data do you have in your hub instance?
   - If you have less than 13 months of data, we recommend you delete the data and re-export it using the FOCUS dataset.
   - If you have more than 13 months of data, you can keep the data in your storage account, but the new Power BI reports will not recognize it. You can continue to use the current Power BI reports.
2. Did you modify the Power BI reports?
   - If you modified the reports, you will need to re-apply your changes to the new reports. Refer to [How to update existing reports to FOCUS](../../focus/what-is-focus.md#how-to-update-existing-reports-to-focus) for details.
   - If you need your customized reports to continue to run while you upgrade, deploy a second instance of FinOps hubs using a different storage account to avoid data processing errors.

Based on the above, use the following steps to upgrade your hub instance from `0.1.x` to `0.3`:

1. Delete any amortized cost exports pointing to your hub instance.
2. If desired, delete the historical amortized cost data to keep storage costs down.
3. Deploy FinOps hubs `0.3` and create new FOCUS exports using the [Create a new hub](./finops-hubs-overview.md#create-a-new-hub) instructions.
   > [!NOTE]
   > You can skip step 1 since resource providers have already been registered.
4. Backfill historical data using the FOCUS export.

[Download 0.3](https://github.com/microsoft/finops-toolkit/releases/tag/v0.3) &nbsp; [View changes](https://aka.ms/ftk/changes#-v02)

<br>

## Upgrading 0.2

Upgrading FinOps hubs 0.2 to 0.3 is as simple as re-deploying the template and optionally update to the 0.3 Power BI reports. There are no breaking changes, so Power BI reports from 0.2 should work with 0.3 and vice-versa.

[Download 0.3](https://github.com/microsoft/finops-toolkit/releases/tag/v0.3) &nbsp; [View changes](https://aka.ms/ftk/changes#-v03)

<br>

## Upgrading 0.3

Upgrading FinOps hubs 0.3 to 0.4 is as simple as re-deploying the template and optionally update to the 0.4 Power BI reports. There are no breaking changes, so Power BI reports from 0.3 should work with 0.4 and vice-versa.

FinOps hubs 0.4 aligns with FOCUS 1.0, so you will notice changes to the following columns:

- ChargeCategory is "Purchase" for refunds instead of "Adjustment".
- ChargeClass (new) is "Correction" for refunds.
- CommitmentDiscountStatus (new) replaces ChargeSubcategory for commitment discount usage.
- Region is replaced by RegionId and RegionName.

Reports work with both FOCUS 1.0 and FOCUS 1.0 preview exports, so there's no need to change exports in order to use the new reports. The reports themselves update the schema to meet FOCUS 1.0 requirements.

[Download 0.4](https://github.com/microsoft/finops-toolkit/releases/tag/v0.4) &nbsp; [View changes](https://aka.ms/ftk/changes#-v04)

<br>

## Upgrading 0.4

Upgrading FinOps hubs 0.4 to 0.5 is as simple as re-deploying the template and optionally update to the 0.5 Power BI reports. There are no breaking changes in FinOps hubs, so Power BI reports from 0.4 should work with 0.5 and vice-versa. There are however changes in Power BI reports that must be accounted for if updating to 0.5 reports.

FinOps toolkit 0.5 reports replaced the Cost Management connector with reservation recommendation exports. When you update to 0.5 reports, you will need to create new reservation recommendation exports in Cost Management and then configure 0.5 reports with both a **Hub Storage URL** pointing to the traditional FinOps hub URL and a separate **Export Storage URL** that points to where reservation recommendations were exported.

If you exported reservation recommendations to the **msexports** container of your hub storage account, use that. If you chose not to export reservation recommendations, set the **Export Storage URL** to the same FinOps hub URL. If you leave one of the URLs empty, the report will not refresh in the Power BI service and you will receive a "dynamic query" error. Placing the same URL in both parameters should work around this limitation.

[Download 0.5](https://github.com/microsoft/finops-toolkit/releases/tag/v0.5) &nbsp; [View changes](https://aka.ms/ftk/changes#-v05)

<br>

## Upgrading 0.5

Upgrading FinOps hubs 0.5 to 0.6 involves re-deploying the template and updating Power BI reports. FinOps hubs 0.6 changed how data is stored in the **ingestion** container, which means older Power BI reports will not work with data exported with FinOps hubs 0.6. Conversely, 0.6 Power BI reports _will_ work with older FinOps hubs versions, so previously exported data will continue to work without re-exporting it.

> [!IMPORTANT]
> If you re-export any historical data in 0.6 that was previously exported in an earlier release, FinOps hubs will not clean up the old data, which will result in duplicated data. The simplest way to resolve this is to delete the older data in the **ingestion** container. FinOps hubs 0.6 moves all content into a folder based on the dataset type: **focuscost**, **pricesheet**, **reservationdetails**, **reservationrecommendations**, or **reservationtransactions**. Any other folders can be safely removed. Once removed, re-run your historical data backfill.

[Download 0.6](https://github.com/microsoft/finops-toolkit/releases/tag/v0.6) &nbsp; [View changes](https://aka.ms/ftk/changes#-v06)

<br>

## Next steps

- [Deploy FinOps hubs](./finops-hubs-overview.md#create-a-new-hub)
- [Download Power BI reports](../power-bi/reports.md#available-reports)

<br>
