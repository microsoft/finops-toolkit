---
title: Open data for FinOps
description: Use open data to normalize and enhance your FinOps reporting, ensuring accurate and consistent data for better insights and decision-making.
ms.topic: concept-article
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
ms.custom: references_regions
# customer intent: As a FinOps practitioner, I want to understand FinOps reporting so that I can clean or normalize my data.
---

# Open data for FinOps

Reporting is the life-blood of any FinOps initiative. And your reports are only as good as your data. It's why [data ingestion](../framework/understand/ingestion.md) is such an important part of FinOps (and any big data effort). The following datasets can be used to clean and normalize your data as part of data ingestion, reporting, or other solutions.

<br>

## Pricing units

Microsoft Cost Management uses the `UnitOfMeasure` column to indicate how each charge is measured. It can be in singular or distinct units or can be grouped into chunks based on applicable block pricing rules. As a string, the `UnitOfMeasure` column can be challenging to parse and handle all the different permutations and inconsistencies. The Pricing units file provides a list of values you might find within common cost-related datasets, for example, Cost Management exports and price sheets. It also has their related distinct unit and block size or scaling factor to compare pricing to usage units.

Sample data:

| UnitOfMeasure    | AccountTypes | PricingBlockSize | DistinctUnits |
| ---------------- | ------------ | ---------------: | ------------- |
| 1 Hour           | MCA, EA      |                1 | Hours         |
| 10000 GB         | EA           |            10000 | GB            |
| 150 Hours        | EA           |              150 | Hours         |
| 200 /Hour        | EA           |              200 | Units/Hour    |
| 5 GB             | MCA, EA      |                5 | GB            |
| 5000000 Requests | EA           |          5000000 | Requests      |
| 744 Connections  | EA           |              744 | Connections   |

A few important notes about the data:

- Meter names aren't included to keep the file size down.
- The default unit type is `Units`.
- Some default units might include a more specific unit in the meter name, which isn't accounted here since meter names aren't included.
- Marketplace meters aren't included due to inconsistencies that would affect data size.

In the Cost Management FOCUS dataset, `UnitOfMeasure` is renamed to `x_PricingUnitDescription`. Both `PricingUnit` and `ConsumedUnit` in FOCUS are set to the `DistinctUnits` column.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/PricingUnits.csv)
> [!div class="nextstepaction"]
> [See PowerShell](powershell/data/get-finopspricingunit.md)
<!-- prettier-ignore-end -->

<br>

## Regions

Microsoft Cost Management provides various values for resource locations that are occasionally inconsistent due to different underlying systems providing the data. The Regions file provides a list of values you might find within common cost-related datasets (for example, Cost Management exports and price sheets) along with their related Azure region IDs and names.

Sample data:

<!-- cSpell:disable -->

| OriginalValue | RegionId      | RegionName     |
| ------------- | ------------- | -------------- |
| ap east       | eastasia      | East Asia      |
| ca central    | canadacentral | Canada Central |
| de north      | germanynorth  | Germany North  |
| no west       | norwaywest    | Norway West    |
| tw north      | taiwannorth   | Taiwan North   |

<!-- cSpell:enable -->

[Download Regions.csv](https://github.com/microsoft/finops-toolkit/releases/latest/download/Regions.csv) &nbsp; [See PowerShell](powershell/data/get-finopsregion.md)

Convert region values to lowercase before mapping. This helps reduce duplication and speed up the mapping process.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/Regions.csv)
> [!div class="nextstepaction"]
> [See PowerShell](powershell/data/get-finopsregion.md)
<!-- prettier-ignore-end -->

<br>

## Resource types

Azure resource types are a semi-readable code that represents what kind of resource it is. Currently, there's no mapping of the resource type to a user-friendly string, description, or its icon. The ResourceTypes file provides a list of resource type values you see in the Azure portal along with their display names, description, and a link to the icon, when available.

Sample data:

<!-- cSpell:disable -->

| ResourceType                      | Singular Display Name   | Plural Display Name      | Lower Singular Display Name | Lower Plural Display Name |
| --------------------------------- | ----------------------- | ------------------------ | --------------------------- | ------------------------- |
| microsoft.compute/virtualmachines | Virtual machine         | Virtual machines         | virtual machine             | virtual machines          |
| microsoft.insights/workbooks      | Azure Workbook          | Azure Workbooks          | Azure workbook              | Azure workbooks           |
| microsoft.logic/workflows         | Logic app               | Logic apps               | logic app                   | logic apps                |
| microsoft.network/virtualnetworks | Virtual network         | Virtual networks         | virtual network             | virtual networks          |
| microsoft.recoveryservices/vaults | Recovery Services vault | Recovery Services vaults | recovery services vault     | recovery services         |
| microsoft.search/searchservices   | Search service          | Search services          | search service              | search services           |
| microsoft.sql/servers             | SQL server              | SQL servers              | SQL server                  | SQL servers               |
| microsoft.sql/servers/databases   | SQL database            | SQL databases            | SQL database                | SQL databases             |
| microsoft.web/sites               | App Service web app     | App Service web apps     | app service                 | app services              |

<!-- cSpell:enable -->

Convert resource type values to lowercase before mapping. This helps reduce duplication and speed up the mapping process.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Download CSV](https://github.com/microsoft/finops-toolkit/releases/latest/download/ResourceTypes.csv)
> [!div class="nextstepaction"]
> [Download JSON](https://github.com/microsoft/finops-toolkit/releases/latest/download/ResourceTypes.json)
> [!div class="nextstepaction"]
> [See PowerShell](powershell/data/get-finopsresourcetype.md)
<!-- prettier-ignore-end -->

<br>

## Services

In Microsoft Cost Management, `ConsumedService` represents the primary service or resource provider of the resource you used. It's roughly the same as `ServiceName` in [FOCUS](../focus/what-is-focus.md). In some cases, multiple services share the same resource provider, so we're using the `ConsumedService` and `ResourceType` columns to map to `ServiceName` and `ServiceCategory` values for use within FOCUS.

Sample data:

<!-- cSpell:disable -->

| ConsumedService      | ResourceType                          | ServiceName         | ServiceCategory | ServiceSubcategory        | PublisherName | PublisherType  | Environment | ServiceModel |
| -------------------- | ------------------------------------- | ------------------- | --------------- | ------------------------- | ------------- | -------------- | ----------- | ------------ |
| microsoft.compute    | microsoft.compute/virtualmachines     | Virtual Machines    | Compute         | Virtual Machines          | Microsoft     | Cloud Provider | Cloud       | IaaS         |
| microsoft.documentdb | microsoft.documentdb/databaseaccounts | Cosmos DB           | Databases       | NoSQL Databases           | Microsoft     | Cloud Provider | Cloud       | PaaS         |
| microsoft.kusto      | microsoft.kusto/clusters              | Azure Data Explorer | Analytics       | Analytics Platforms       | Microsoft     | Cloud Provider | Cloud       | PaaS         |
| microsoft.network    | microsoft.network/virtualnetworks     | Virtual Network     | Networking      | Networking Infrastructure | Microsoft     | Cloud Provider | Cloud       | IaaS         |
| microsoft.storage    | microsoft.storage/storageaccounts     | Storage Accounts    | Storage         | Storage Platforms         | Microsoft     | Cloud Provider | Cloud       | IaaS         |

<!-- cSpell:enable -->

A few important notes about the data:

- `ConsumedService` and `ResourceType` values are all lowercased to avoid case sensitivity issues.
- `ServiceName` values should match the product marketing name for the closest possible service. Some services reuse resource types and can't be distinguished from the resource type alone (for example, Azure functions show as App Service).
- `ServiceCategory` values are aligned with the allowed values in FOCUS.

Most mappings can rely on resource type alone. In a future update, we will merge this list with [Resource types](#resource-types) to provide only a single dataset. Currently, the only known case where resource type is shared that ConsumedService can help identify is for Microsoft Defender for Cloud. To simplify your mapping, you can only map those 5 rows and rely on a resource type mapping for everything else.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/Services.csv)
> [!div class="nextstepaction"]
> [See PowerShell](powershell/data/get-finopsservice.md)
<!-- prettier-ignore-end -->

<br>

## Dataset examples

The following files are examples of what you see when you export data from Microsoft Cost Management. These files are provided to help you understand the data structure and format. They are from an Enterprise Agreement (EA) demo account and aren't intended to be used for ingestion or reporting.

- Cost and usage
  - Actual (billed) (`2021-10-01`)
  - Amortized (`2021-10-01`)
  - FOCUS (`1.0`)
  - FOCUS (`1.0-preview(v1)`)
- Prices (`2023-05-01`)
- Reservation details (`2023-03-01`)
- Reservation transactions (`2023-05-01`)
- Reservation recommendations (`2023-05-01`)

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Download all examples](https://github.com/microsoft/finops-toolkit/releases/latest/download/dataset-examples.zip)
<!-- prettier-ignore-end -->

<br>

## Dataset metadata

Given each dataset uses different columns and data types, FOCUS defines the metadata schema to describe the dataset. Dataset metadata includes general information about the data like the data generator, schema version, and columns included in the dataset.

Sample data:

| ColumnName           | DataType | Description                                                                                                                                                            |
| -------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BilledCost`         | Decimal  | A charge serving as the basis for invoicing, inclusive of all reduced rates and discounts while excluding the amortization of upfront charges (one-time or recurring). |
| `BillingAccountId`   | String   | Unique identifier assigned to a billing account by the provider.                                                                                                       |
| `BillingAccountName` | String   | Display name assigned to a billing account.                                                                                                                            |
| `BillingCurrency`    | String   | Currency that a charge was billed in.                                                                                                                                  |
| `BillingPeriodEnd`   | DateTime | End date and time of the billing period.                                                                                                                               |
| `BillingPeriodStart` | DateTime | Beginning date and time of the billing period.                                                                                                                         |

Metadata is available for the following datasets:

- Cost and usage
  - [FOCUS 1.0](../focus/metadata.md#focuscost-10)
  - [FOCUS 1.0-preview(v1)](../focus/metadata.md#focuscost-10-previewv1)

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Download all metadata](https://github.com/microsoft/finops-toolkit/releases/latest/download/dataset-metadata.zip)
<!-- prettier-ignore-end -->

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/OpenData/featureName/Overview)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related resources:

- [FOCUS metadata](../focus/metadata.md)

Related FinOps capabilities:

- [Data ingestion](../framework/understand/ingestion.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](hubs/finops-hubs-overview.md)
- [FinOps toolkit Power BI reports](power-bi/reports.md)
- [FinOps toolkit PowerShell module](powershell/powershell-commands.md)

<br>
