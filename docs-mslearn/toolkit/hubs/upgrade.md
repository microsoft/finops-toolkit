---
title: Upgrade your FinOps hubs
description: Learn how to upgrade your existing FinOps hub instance to the latest version, including necessary steps and considerations.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to upgrade my existing FinOps hub.
---

<!-- markdownlint-disable-next-line MD025 -->
# Upgrade a FinOps hubs instance

This tutorial helps you upgrade an existing FinOps hub instance to the latest version to use new capabilities.

Upgrading a FinOps hub instance is usually the same as the initial setup where you deploy the FinOps hub template and then update Power BI reports and Data Explorer dashboards. However, depending on what version you're moving from or to, extra steps may be needed. Use the following steps to upgrade your FinOps hub instance. If you have any questions, [start a discussion](https://aka.ms/discuss).

<br>

## Before you begin

Before you upgrade, make sure you know what version you're currently running. You can find the version in the storage account:

1. Open the storage account in the Azure portal.
   - You can navigate from the [resource group](https://portal.azure.com/#browse/resourcegroups) or the [list of storage accounts](https://portal.azure.com/#browse/Microsoft.Storage%2FStorageAccounts).
   - If you use the list of storage accounts, add a tag filter for `cm-resource-parent` contains `Microsoft.Cloud/hubs` to see all hub storage accounts.
2. Open **Storage browser** > **Blob containers** > **config**
3. Find the **settings.json** row and select the **⋯** menu on the right side of the page, then **View/edit**.
4. Look for the **version** property.

If you're using FinOps hubs older than 0.2, it's simplest to deploy a new instance. The steps in this tutorial don't account for differences leading up to 0.2. To deploy a new instance, see [Create a FinOps hub instance](deploy.md).

For a list of changes since your release, refer to the [changelog](../changelog.md).

<br>

## Step 1: Delete unused resources (0.7)

This step only applies when upgrading from FinOps hubs 0.7 and targeting a deployment with public network access. Skip this step if any of the following apply:

- Upgrading from FinOps hubs 0.6 or earlier.
- Upgrading from FinOps hubs 0.7 and using private network routing.
- Upgrading from FinOps hubs 0.8 or later.

FinOps hubs 0.8 introduced architectural changes to how networking resources were deployed. Networking resources must be deleted before upgrading from 0.7 to 0.8 or later. If you're moving from 0.6 or earlier to 0.8 or later, you can skip this step. The instructions assume your FinOps hub instance is the only thing in the resource group and there are no other networking resources. Don't delete resources that aren't related to FinOps hubs.

To delete FinOps hubs 0.7 networking resources:

1. Open the FinOps hub resource group in the Azure portal.
2. Delete all private endpoints within the resource group.
3. Delete all private Domain Name System (DNS) zones within the resource group.
4. Delete the virtual network. If errors are encountered:
   - Confirm no private endpoints or DNS zones remain.
   - Check the connected devices tab and remove any lingering resources to ensure the virtual network isn't in use.

<br>

## Step 2: Update Fabric eventhouse

This step only applies if you are using Microsoft Fabric as a primary data store. Skip this step if any of the following apply:

- You are using Azure Storage as your data store.
- You are using Azure Data Explorer as your data store.

The Microsoft Fabric eventhouse database schema must be manually updated with each release. For details, see [Set up Microsoft Fabric](deploy.md#optional-set-up-microsoft-fabric).

<br>

## Step 3: Deploy the FinOps hub template

Upgrading a FinOps hub instance requires redeploying the latest version of the template. Deploying the template creates new resources and updates existing resources as needed. To ensure the existing instance is updated, make sure to specify the same hub name and Data Explorer cluster name or Fabric eventhouse query URI.

> [!div class="nextstepaction"]
> [Deploy](deploy.md#deploy-the-finops-hub-template)

<br>

## Step 4: Update Cost Management exports (0.2-4)

This step only applies if upgrading from FinOps hubs 0.4 or earlier and using manual exports. Skip this step if upgrading from FinOps hubs 0.5 or later or using managed exports.

FinOps toolkit 0.5 reports replaced the Cost Management connector with reservation recommendation exports. When you update to 0.5 reports, you need to create new reservation recommendation exports in Cost Management.

<br>

## Step 5: Remove duplicate data (0.2-6)

This step only applies if upgrading from FinOps hubs 0.6 or earlier. Skip this step if upgrading from FinOps hubs 0.7 or later.

FinOps hubs 0.6 and 0.7 changed the folder path for data stored in the **ingestion** container, which means older Power BI reports don't work with FinOps hubs 0.7 and later. New Power BI reports are backwards compatible and support old folder paths. You don't need to re-export data for storage reports. However, since FinOps hubs 0.6 and 0.7 use new folder paths, you may see duplicate data for the current month. To avoid the duplication, delete the current month's data from the old path in the **ingestion** container to avoid it being double-counted.

If you enable Azure Data Explorer or Microsoft Fabric, you need to reingest historical data to add it to Data Explorer. This ingestion requirement also applies to data brought in from other systems or clouds.

> [!IMPORTANT]
> If you re-export historical data in 0.7 or later that was previously exported in an earlier release, older data isn't removed. Delete the older data in the **ingestion** container to avoid inaccurate numbers due to duplicated data. FinOps hubs 0.7 moves all content into a folder based on the dataset type: **CommitmentDiscountUsage**, **Costs**, **Prices**, **Recommendations**, or **Transactions**. Any other folders can be safely removed. Once removed, run historical data backfill as needed.

<br>

## Step 6: Update Power BI reports

While Power BI reports are designed to work with the corresponding FinOps hub instance, most releases don't require an update to Power BI reports. If updating from FinOps hubs 0.6 or earlier, you must also update Power BI reports. Power BI reports from v12 and later require FinOps hubs v12 or later. For more information, see the [compatibility guide](compatibility.md).

To update Power BI reports:

1. Download the latest templates:
   - [Kusto Query Language (KQL) reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip) for Data Explorer or Microsoft Fabric.
   - [Storage reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip) for storage only deployments.
2. Extract and open the desired report template in Power BI Desktop.
3. Specify report parameters as needed and load each report.
   - 0.9 deprecated FOCUS 1.0 preview support. To use existing FOCUS 1.0 preview data, enable the **Deprecated: Perform Extra Query Optimizations** parameter.
4. Reapply any customizations to the new report noting the following changes:
   - 0.4 changed the following columns to align with FOCUS 1.0:
     - ChargeCategory is `Purchase` for refunds instead of `Adjustment`.
     - ChargeClass (new) is `Correction` for refunds.
     - CommitmentDiscountStatus (new) replaces ChargeSubcategory for commitment discount usage.
     - RegionId and RegionName replaced Region.
   - To avoid manually applying customizations in future updates, consider contributing customizations into the FinOps toolkit.
5. Publish reports to a Fabric workspace.
6. Repeat 2-5 for each report.

For more information, see [Set up Power BI reports](../power-bi/setup.md).

<br>

## Step 7: Update the Data Explorer dashboard

The Data Explorer dashboard was introduced with Data Explorer support in 0.7 and also works with Microsoft Fabric since 0.10. Generally, the dashboard does not need to be updated once deployed unless you want to take advantage of new features. To upgrade the dashboard, replace the existing dashboard with the latest dashboard template.

Each version of the dashboard is configured to work with a specific FinOps hub schema version (v1_0 or v1_2). Schema versions ensure backwards compatibility across FOCUS dataset versions from different providers. Older dashboard versions will continue to work after upgrading to the latest version of FinOps hubs, but newer dashboard versions may not work with older FinOps hub versions. The following table outlines the supported combinations.

| Dashboard version | FinOps hubs schema | FinOps hubs version |
|-------------------|--------------------|---------------------|
| 12+               | v1_2               | 12+                 |
| 0.7-0.11          | v1_0               | 0.7+                |

> [!div class="nextstepaction"]
> [Download dashboard](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-dashboard.json)

For more information, see [Configure Data Explorer dashboards](configure-dashboards.md).

<br>

## Step 8: Update custom KQL queries

Replace the use of deprecated columns and functions:

| Introduced | Retired | Deprecated                                  | Replacement                                         |
| ---------- | ------- | ------------------------------------------- | --------------------------------------------------- |
| 0.7        | 12      | `Costs().x_InvoiceId`                       | `Costs().InvoiceId`                                 |
| 0.7        | 12      | `Costs().x_PricingCurrency`                 | `Costs().PricingCurrency`                           |
| 0.7        | 12      | `Costs().x_SkuMeterName`                    | `Costs().SkuMeter`                                  |
| 0.7        | 12      | `Prices().x_PricingCurrency`                | `Prices().PricingCurrency`                          |
| 0.7        | 12      | `Prices().x_SkuMeterName`                   | `Prices().SkuMeter`                                 |
| 0.7        | 12      | `Transactions().x_InvoiceId`                | `Transactions().InvoiceId`                          |
| 0.7        | 0.8     | `parse_resourceid(ResourceId).ResourceType` | `resource_type(x_ResourceType).SingularDisplayName` |
| 0.7        | N/A     | `daterange()`                               | `datestring(datetime, [datetime])`                  |
| 0.7        | N/A     | `monthsago()`                               | `startofmonth(datetime, [offset])`                  |

If using unversioned functions or updating from the `v1_0` schema version, review your code for any explicit use of the `decimal` data type and replace it with `real`. As of FinOps hubs v12 (schema version `v1_2`), all `decimal` data types changed to `real` to improve performance. To learn more about schema versions, see [About schema versions](data-model.md#schema-version).

If updating queries to use a newer schema version, use the following table to understand the changes introduced in each schema version for each managed dataset.

| Dataset                 | Schema | Column                                | Notes                                           |
| ----------------------- | ------ | ------------------------------------- | ----------------------------------------------- |
| (All)                   | v1_2   | All `decimal` columns                 | Changed to `real`                               |
| CommitmentDiscountUsage | v1_2   | `CommitmentDiscountQuantity`          | New custom column                               |
| CommitmentDiscountUsage | v1_2   | `CommitmentDiscountUnit`              | New custom column                               |
| CommitmentDiscountUsage | v1_2   | `ServiceSubcategory`                  | New custom column                               |
| Costs                   | v1_2   | `CapacityReservationId`               | New with FOCUS 1.2                              |
| Costs                   | v1_2   | `CapacityReservationStatus`           | New with FOCUS 1.2                              |
| Costs                   | v1_2   | `CommitmentDiscountQuantity`          | New with FOCUS 1.2                              |
| Costs                   | v1_2   | `CommitmentDiscountUnit`              | New with FOCUS 1.2                              |
| Cost                    | v1_2   | `ServiceSubcategory`                  | New with FOCUS 1.2                              |
| Cost                    | v1_2   | `SkuPriceDetails`                     | New with FOCUS 1.2; derived from `x_SkuDetails` |
| Costs                   | v1_2   | `x_AmortizationClass`                 | New with Cost Management FOCUS 1.2-preview      |
| Costs                   | v1_2   | `x_CommitmentDiscountNormalizedRatio` | New with Cost Management FOCUS 1.2-preview      |
| Costs                   | v1_2   | `x_InvoiceId`                         | Renamed to `InvoiceId`                          |
| Costs                   | v1_2   | `x_PricingCurrency`                   | Renamed to `PricingCurrency`                    |
| Costs                   | v1_2   | `x_ServiceModel`                      | New custom column                               |
| Costs                   | v1_2   | `x_SkuMeterName`                      | Renamed to `SkuMeter`                           |
| Prices                  | v1_2   | `CommitmentDiscountUnit`              | New custom column                               |
| Prices                  | v1_2   | `x_PricingCurrency`                   | Renamed to `PricingCurrency`                    |
| Prices                  | v1_2   | `x_SkuMeterName`                      | Renamed to `SkuMeter`                           |
| Recommendations         | v1_2   | `ResourceId`                          | New custom column                               |
| Recommendations         | v1_2   | `ResourceName`                        | New custom column                               |
| Recommendations         | v1_2   | `ResourceType`                        | New custom column                               |
| Recommendations         | v1_2   | `SubAccountName`                      | New custom column                               |
| Recommendations         | v1_2   | `x_RecommendationDetails`             | New custom column                               |
| Recommendations         | v1_2   | `x_ResourceGroupName`                 | New custom column                               |
| Transactions            | v1_2   | `x_InvoiceId`                         | Renamed to `InvoiceId`                          |

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK/bladeName/Hubs/featureName/Upgrade)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

- [Deploy FinOps hubs](./finops-hubs-overview.md#create-a-new-hub)
- [Download Power BI reports](../power-bi/reports.md#available-reports)

<br>
