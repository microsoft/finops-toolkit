---
layout: default
title: Open data
nav_order: 60
description: 'Leverage open data to normalize and enhance your FinOps reporting.'
permalink: /data
---

<span class="fs-9 d-block mb-4">Open data</span>
Leverage open data to normalize and enhance your FinOps reporting.
{: .fs-6 .fw-300 }

[Download](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Share feedback](#️-looking-for-more){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [📏 Pricing units](#-pricing-units)
- [🗺️ Regions](#️-regions)
- [📚 Resource types](#-resource-types)
- [🎛️ Services](#️-services)
- [⬇️ Dataset examples](#️-dataset-examples)
- [📃 Dataset metadata](#-dataset-metadata)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---

Reporting is the life-blood of any FinOps initiative. And your reports are only as good as your data. This is why [data ingestion and normalization](../../_docs/framework/capabilities/understand/ingestion.md) is such an important part of FinOps (and any big data effort). The following datasets can be used to clean and normalize your data as part of data ingestion, reporting, or other solutions.

<br>

## 📏 Pricing units

Microsoft Cost Management uses the `UnitOfMeasure` column to indicate how each charge is measured. This can be in singular or distinct units or can be grouped into chunks based on applicable block pricing rules. As a string, the `UnitOfMeasure` column can be challenging to parse and handle all the different permutations and inconsistencies. The Pricing units file provides a list of values you may find within common cost-related datasets (e.g., Cost Management exports and price sheets) along with their related distinct unit and block size or scaling factor to compare pricing to usage units.

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

1. Meter names are not included to keep the file size down.
2. The default unit type is "Units".
3. Some default units may include a more specific unit in the meter name, which is not accounted here since meter names aren't included.
4. Marketplace meters are not included due to inconsistencies that would impact data size.

<blockquote class="note" markdown="1">
   _In the Cost Management FOCUS dataset, `UnitOfMeasure` is renamed to `x_PricingUnitDescription`. Both `PricingUnit` and `UsageUnit` in FOCUS are set to the `DistictUnits` column._
</blockquote>

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/PricingUnits.csv){: .btn .mb-4 .mb-md-0 .mr-4 }
[See PowerShell](../../_automation/powershell/data/Get-FinOpsPricingUnit.md){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

## 🗺️ Regions

Microsoft Cost Management provides various values for resource locations that are occasionally inconsistent due to different underlying systems providing the data. The Regions file provides a list of values you may find within common cost-related datasets (e.g., Cost Management exports and price sheets) along with their related Azure region IDs and names.

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

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/Regions.csv){: .btn .mb-4 .mb-md-0 .mr-4 }
[See PowerShell](../../_automation/powershell/data/Get-FinOpsRegion.md){: .btn .mb-4 .mb-md-0 .mr-4 }

<blockquote class="important" markdown="1">
  _Convert region values to lowercase before mapping. This helps reduce duplication and speed up the mapping process._
</blockquote>

<br>

## 📚 Resource types

Azure resource types are a semi-readable code that represents what kind of resource it is. Currently, there's no mapping of the resource type to a user-friendly string, description, or its icon. The ResourceTypes file provides a list of resource type values you'll find in the Azure portal along with their display names, description, and a link to the icon, when available.

Sample data:

<!-- cSpell:disable -->

| ResourceType                      | Singular Display Name   | Plural Display Name      | Lower Singular Display Name | Lower Plural Display Name |
| --------------------------------- | ----------------------- | ------------------------ | --------------------------- | ------------------------- |
| microsoft.compute/virtualmachines | Virtual machine         | Virtual machines         | virtual machine             | virtual machines          |
| microsoft.insights/workbooks      | Azure Workbook          | Azure Workbooks          | azure workbook              | azure workbooks           |
| microsoft.logic/workflows         | Logic app               | Logic apps               | logic app                   | logic apps                |
| microsoft.network/virtualnetworks | Virtual network         | Virtual networks         | virtual network             | virtual networks          |
| microsoft.recoveryservices/vaults | Recovery Services vault | Recovery Services vaults | recovery services vault     | recovery services         |
| microsoft.search/searchservices   | Search service          | Search services          | search service              | search services           |
| microsoft.sql/servers             | SQL server              | SQL servers              | SQL server                  | SQL servers               |
| microsoft.sql/servers/databases   | SQL database            | SQL databases            | SQL database                | SQL databases             |
| microsoft.web/sites               | App Service web app     | App Service web apps     | app service                 | app services              |

<!-- cSpell:enable -->

<blockquote class="important" markdown="1">
  _Convert resource type values to lowercase before mapping. This helps reduce duplication and speed up the mapping process._
</blockquote>

[Download CSV](https://github.com/microsoft/finops-toolkit/releases/latest/download/ResourceTypes.csv){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Download JSON](https://github.com/microsoft/finops-toolkit/releases/latest/download/ResourceTypes.json){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
[See PowerShell](../../_automation/powershell/data/Get-FinOpsResourceType.md){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🎛️ Services

In Microsoft Cost Management, `ConsumedService` represents the primary service or resource provider of the resource you used. This is roughly the same as `ServiceName` in [FOCUS](../../_docs/focus/README.md). In some cases, multiple services share the same resource provider, so we're using the `ConsumedService` and `ResourceType` columns to map to `ServiceName` and `ServiceCategory` values for use within FOCUS.

Sample data:

<!-- cSpell:disable -->

| ConsumedService      | ResourceType                          | ServiceName         | ServiceCategory | PublisherName | PublisherType  |
| -------------------- | ------------------------------------- | ------------------- | --------------- | ------------- | -------------- |
| microsoft.compute    | microsoft.compute/virtualmachines     | Virtual Machines    | Compute         | Microsoft     | Cloud Provider |
| microsoft.documentdb | microsoft.documentdb/databaseaccounts | Cosmos DB           | Databases       | Microsoft     | Cloud Provider |
| microsoft.kusto      | microsoft.kusto/clusters              | Azure Data Explorer | Analytics       | Microsoft     | Cloud Provider |
| microsoft.network    | microsoft.network/virtualnetworks     | Virtual Network     | Networking      | Microsoft     | Cloud Provider |
| microsoft.storage    | microsoft.storage/storageaccounts     | Storage Accounts    | Storage         | Microsoft     | Cloud Provider |

<!-- cSpell:enable -->

A few important notes about the data:

1. `ConsumedService` and `ResourceType` values are all lowercased to avoid case sensitivity issues.
2. `ServiceName` values should match the product marketing name for the closest possible service. Some services reuse resource types and cannot be distinguished from the resource type alone (e.g., Azure functions will show as App Service).
3. `ServiceCategory` values are aligned with the allowed values in FOCUS.

<blockquote class="note" markdown="1">
  _Most mappings can rely on resource type alone. In a future update, we will merge this list with [Resource types](#-resource-types) to provide only a single dataset. Currently, the only known case where resource type is shared that ConsumedService can help identify is for Microsoft Defender for Cloud. To simplify your mapping, you can only map those 5 rows and rely on a resource type mapping for everything else._
</blockquote>

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/Services.csv){: .btn .mb-4 .mb-md-0 .mr-4 }
[See PowerShell](../../_automation/powershell/data/Get-FinOpsService.md){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

## ⬇️ Dataset examples

The following files are examples of what you will find when you export data from Microsoft Cost Management. These files are provided to help you understand the data structure and format. They are from an Enterprise Agreement (EA) demo account and are not intended to be used for ingestion or reporting.

- Cost and usage
  - Actual (billed) (`2021-10-01`)
  - Amortized (`2021-10-01`)
  - FOCUS (`1.0-preview(v1)`)
- Prices (`2023-05-01`)
- Reservation details (`2023-03-01`)
- Reservation transactions (`2023-05-01`)
- Reservation recommendations (`2023-05-01`)

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/dataset-examples.zip){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

## 📃 Dataset metadata

Given each dataset uses different columns and data types, FOCUS has defined metadata schema to describe the dataset. Dataset metadata includes general information about the data like the data generator, schema version, and columns included in the dataset.

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
  - FOCUS 1.0 – [Learn more](../../_docs/focus/metadata.md#focuscost-10)
  - FOCUS 1.0-preview(v1) – [Learn more](../../_docs/focus/metadata.md#focuscost-10-previewv1)

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/dataset-metadata.zip){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any datasets you're looking for. Create a new issue with the details that you'd like to see either included in existing or new datasets.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md pbi="1" ps="1" %}

<br>
