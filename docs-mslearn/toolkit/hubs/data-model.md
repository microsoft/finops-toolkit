---
title: FinOps hubs data model
description: Learn about the tables and functions available in FinOps hubs to build your own queries, reports, and dashboards.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps hub user, I want to learn about the data model so that I can build custom queries, reports, and dashboards.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps hub data model

FinOps hubs are a platform for cost analytics, insights, and optimization. While the core of FinOps hubs is a data pipeline that ingests, cleans, and normalizes data, the power of FinOps hubs comes from the standardized data model built on the FinOps Open Cost and Usage Specification (FOCUS).

This article explains the FinOps hubs data model &ndash; from storage folders, Azure Data Explorer tables and functions, and Power BI tables and functions &ndash; to prepare you for building your own custom queries, reports, and dashboards. For the most flexible and scalable support, we recommend deploying FinOps hubs with Data Explorer.

<br>

## Prerequisites

Before you begin, you must have:

- [Deployed a FinOps hub instance](finops-hubs-overview.md#create-a-new-hub) (ideally with Data Explorer).
- [Configured scopes](configure-scopes.md) and ingested data successfully.
- Have database viewer access to the Data Explorer **Hub** and **Ingestion** databases.

This walkthrough does not incur any cost; however, storage reads incur a nominal charge and maintaining an active Data Explorer cluster does incur cost.

<br>

## Summarizing the data model

FinOps hubs spans storage, Data Factory, Data Explorer, and Power BI. Depending on your setup, you may interact with one or more of these.

When data is ingested into FinOps hubs, it ultimately lands in the **ingestion** storage container. Each folder in this container maps to a managed dataset in FinOps hubs. When Data Explorer is deployed, these folder names map to the tables in the **Ingestion** container. For details about these folders and the overarching data ingestion process, see [How data is processed in FinOps hubs](data-processing.md). We will not cover these folders and pipelines here.

If you configured a Data Explorer cluster name as part of your FinOps hub deployment, you will find a number of tables and functions in the **Hub** and **Ingestion** databases. Queries in Power BI and Data Explorer dashboards extend these tables and functions. If you use Power BI to connect to data in your storage account, you'll find a different set of functions and tables in Power BI.

The following sections will outline:

- Managed datasets
- Data Explorer functions
- Power BI functions
- Power BI tables

<br>

## Managed datasets in FinOps hubs

A **managed dataset** is a logical dataset that is backed by a storage folder, Data Explorer table, multiple Data Explorer functions, and a Power BI table. Managed datasets also provide versioned functions in Data Explorer that enable backwards compatibility over time. The exact resources behind a managed dataset depend on whether your FinOps hub instance uses storage or Data Explorer.

Managed datasets include the following assets for FinOps hubs with storage:

- A folder in the **ingestion** storage container (for example, **ingestion/Costs**).
- A table in Power BI storage reports that maps to the corresponding storage folder.

Managed datasets also include the following assets for FinOps hubs with Data Explorer:

- A "raw" table in the Data Explorer **Ingestion** database (for example, **Costs_raw**).
- A versioned "transform" function in the Data Explorer **Ingestion** database, used to transform raw data (for example, **Costs_transform_v1_0()**).
- A versioned "final" table in the Data Explorer **Ingestion** database (for example, **Costs_final_v1_0**).
- A versioned function in the Data Explorer **Hub** database (for example, **Costs_v1_0()**).
- An unversioned function in the Data Explorer **Hub** database (for example, **Costs()**).
- A table in Power BI KQL reports that wraps the corresponding versioned function.

When querying data in FinOps hubs, always use the **Hub** database and avoid working with the tables and functions in the **Ingestion** database. To learn more about the data ingestion process, see [How data is processed in FinOps hubs](data-processing.md). Use unversioned functions for ad-hoc analysis or reports that do not require long-term backwards compatibility. Use the versioned functions for reports or systems that do require backwards compatibility and you do not want to be impacted by FinOps hub updates, which may introduce new FOCUS versions.

The unversioned functions call the latest versioned function, which in turn queries data from all versioned final tables in the **Ingestion** database. For instance, **Costs()** calls **Costs_v1_0()**, which queries **Costs_final_v1_0** table. When FinOps hubs adds support for a new FOCUS version, like FOCUS 1.1, all new data will be ingested into the **Costs_final_v1_1** table and the **Costs()** function calls **Costs_v1_1()**, which queries both **Costs_final_v1_0** and **Costs_final_v1_1** tables, transforming the FOCUS 1.0 data to look like FOCUS 1.1. Similarly, the **Costs_v1_0()** function queries both tables, transforming FOCUS 1.1 data to FOCUS 1.0 to support systems that can't work with newer columns.

This same approach is used for dataset updates that change columns within the same FOCUS version. These tables and functions will use an **r#** version, like **Costs_final_v1_2r3**, signifying the third release (r3) of the FOCUS 1.2 specification. This approach helps avoid changes that may impact custom queries and reports.

This applies to all managed datasets discussed in the following sections.

<br>

## Power BI functions

Power BI storage and KQL reports include a subset of the following functions. Each of these functions is intended to be internal and we do not guarantee backward compatibility across versions.

- **ftk_DatetimeToJulianDate(Date inputDate)**<br>
  Date/time conversion helper.
- **ftk_DemoFilter()**<br>
  Filter used to minimize data included in the demo reports. Can be customized to filter Resource Graph subscriptions, but not designed for scale. If filtering is needed, [create a feature request](https://aka.ms/ftk/ideas).
- **ftk_ImpalaToJulianDate(object data)**<br>
  Date/time conversion helper.
- **ftk_Metadata(object fileContents, text dateColumn)**<br>
  Parquet file parsing helper to support incremental refresh in Power BI storage reports.
- **ftk_ParseResourceId(text resourceId, bool getName)**<br>
  Azure resource ID parsing helper. Can parse out the hierarchical resource name or resource type.
- **ftk_ParseResourceName(text resourceId)**<br>
  Parses the hierarchical resource name from an Azure resource ID by calling the **ftk_ParseResourceId** function.
- **ftk_ParseResourceType(text resourceId)**<br>
  Parses the hierarchical resource type from an Azure resource ID by calling the **ftk_ParseResourceId** function.
- **ftk_Storage([datasetType])**<br>
  Reads data from Azure DataLake Storage. The **datasetType** parameter can be either a Cost Management export dataset or a FinOps hubs managed dataset. This function handles the differences between Cost Management export types and Finops hubs versions, which can use different folder hierarchies.

<br>

## AdvisorRecommendations table

The **AdvisorRecommendations** table in Power BI reports that queries Azure Advisor recommendations from Azure Resource Graph.

<br>

## arraystring() KQL function

The **arraystring(arr: dynamic)** function in Data Explorer returns a comma-delimited string for array elements.

Examples:

- `arraystring(dynamic(['x']))` = "x"
- `arraystring(dynamic([1, 2, 3]))` = "1, 2, 3"
- `arraystring(dynamic(['a', 'b', 'c']))` = "a, b, c"

<br>

## CommitmentDiscountUsage managed dataset

The **CommitmentDiscountUsage** managed dataset includes:

- **ingestion/CommitmentDiscountUsage** storage folder.
- **CommitmentDiscountUsage_raw** table in the **Ingestion** database.
- **CommitmentDiscountUsage_transform_v1_0()** function in the **Ingestion** database.
- **CommitmentDiscountUsage_final_v1_0** table in the **Ingestion** database.
- **CommitmentDiscountUsage_v1_0()** function in the **Hub** database.
- **CommitmentDiscountUsage()** function in the **Hub** database.
- **CommitmentDiscountUsage** table in Power BI reports.

The **CommitmentDiscountUsage_raw** table supports Microsoft Cost Management reservation details export schemas for EA and MCA accounts. Data is transformed into a FOCUS-aligned dataset when ingested into the final table. This dataset does not explicitly support other clouds.

<br>

## Compliance calculation table

The **Compliance calculation** virtual table in Power BI reports that joins the [PolicyAssignments](#policyassignments-table) and [PolicyStates](#policystates-table) tables to summarize policy compliance.

<br>

## Costs managed dataset

The **Costs** managed dataset includes:

- **ingestion/Costs** storage folder.
- **Costs_raw** table in the **Ingestion** database.
- **Costs_transform_v1_0()** function in the **Ingestion** database.
- **Costs_final_v1_0** table in the **Ingestion** database.
- **Costs_v1_0()** function in the **Hub** database.
- **Costs()** function in the **Hub** database.
- **Costs** table in Power BI reports.

The **Costs_raw** table supports FOCUS 1.0 data ingestion from Microsoft, Amazon Web Services (AWS), Google Cloud Platform (GCP), and Oracle Cloud Infrastructure (OCI). FinOps hubs does not support directly pulling data from other clouds, but if data is added to the **ingestion** storage container, it will be ingested with all custom columns.

<br>

## datestring() KQL function

The **datestring(start: datetime, [end: datetime])** function in Data Explorer returns a formatted date or date range (for example, Jan 1-Feb 3). Formatted dates are the shortest possible value based on the current date.

Examples:

- `datestring(datetime(2025-01-01))` = "Jan 1"
- `datestring(datetime(2024-01-01))` = "Jan 1, 2024"
- `datestring(datetime(2025-01-01), datetime(2025-01-01))` = "Jan 1"
- `datestring(datetime(2025-01-01), datetime(2025-01-15))` = "Jan 1-15"
- `datestring(datetime(2025-01-01), datetime(2025-01-31))` = "Jan 2025"
- `datestring(datetime(2025-01-01), datetime(2025-03-31))` = "Jan-Mar"
- `datestring(datetime(2024-01-01), datetime(2024-03-31))` = "Jan-Mar 2024"
- `datestring(datetime(2025-01-01), datetime(2025-02-15))` = "Jan 1-Feb 15"
- `datestring(datetime(2024-07-01), datetime(2025-06-31))` = "Jul 2024-Jun 2025"
- `datestring(datetime(2024-12-16), datetime(2025-01-15))` = "Dec 16, 2024-Jan 15, 2025"
- `datestring(datetime(2025-01-01), datetime(2025-12-31))` = "2025"
- `datestring(datetime(2024-01-01), datetime(2025-12-31))` = "2024-2025"

<br>

## delta() KQL function

The **delta(oldValue: double, newValue: double)** function in Data Explorer compares 2 values and returns the percentage change from **oldValue** to **newValue**.

Examples:

- `delta(1, 2.5)` = 1.5
- `delta(2, 1.5)` = -0.5

<br>

## deltastring() KQL function

The **deltastring(oldValue: double, newValue: double, [places: int], [useArrows: bool])** function in Data Explorer returns the percentage difference between two numbers as a string using the specified number of decimal places. The useArrows parameter indicates whether to use arrows for positive and negative changes.

Examples:

- `deltastring(1.2, 3.4)` = "+2.2"
- `deltastring(3.4567, 1.2345, 2)` = "-2.22"
- `deltastring(1.2, 3.4, 1, true)` = "↑2.2"
- `deltastring(3.4567, 1.2345, 2, true)` = "↓2.22"

<br>

## diffstring() KQL function

The **diffstring(oldValue: double, newValue: double, [places: int])** function in Data Explorer returns the difference between two numbers as a string with a plus or minus sign and optionally rounds it to a specified number of places.

Examples:

- `plusminus(1.2, 3.4)` = "+2.2"
- `plusminus(3.4567, 1.2345, 2)` = "-2.22"

<br>

## Disks table

The **Disks** table in Power BI reports that queries Azure virtual machine managed disks from Azure Resource Graph.

<br>

## HubScopes table

In Power BI, the **HubScopes** table summarizes the scopes that were ingested into FinOps hubs. This table is derived from the **config/settings.json** file in storage.

In Data Explorer, the **HubScopes** function summarizes the scopes that were identified in the [HubSettings function](#hubsettings-table).

<br>

## HubSettings table

In Power BI, the **HubSettings** table pulls configuration settings from the **config/settings.json** file in storage for the FinOps hub instance.

In Data Explorer, the **HubSettingsLog** table holds a history of all settings.json file updates. The **HubSettings()** function in Data Explorer returns the latest settings entry from the **HubSettingsLog** table.

<br>

## ifempty() KQL function

The **ifempty(value: dynamic, defaultValue: dynamic)** function in Data Explorer returns the **defaultValue** if the specified **value** is empty.

Examples:

- `ifempty('', '(empty)')` = "(empty)"
- `ifempty(null, '(empty)')` = "(empty)"
- `ifempty(123, '(empty)')` = 123

<br>

## ManagementGroups table

The **ManagementGroups** table in Power BI reports that queries Azure management groups from Azure Resource Graph.

<br>

## monthstring() KQL function

The **monthstring(date: datetime, [length: int])** function in Data Explorer returns the name of the month for the specified date (for example, "Jan" or "January"). The **length** parameter indicates how many characters the month name should be. By default, the full name will be used.

Examples:

- `monthstring(datetime(2025-01-01))` = "January"
- `monthstring(datetime(2025-01-01), 3)` = "Jan"
- `monthstring(datetime(2025-01-01), 1)` = "J"

<br>

## NetworkInterfaces table

The **NetworkInterfaces** table in Power BI reports that queries Azure network interfaces from Azure Resource Graph.

<br>

## NetworkSecurityGroups table

The **NetworkSecurityGroups** table in Power BI reports that queries Azure network security groups from Azure Resource Graph.

<br>

## numberstring() KQL function

The **numberstring(num: double, [abbrev: bool])** function in Data Explorer converts a number to a formatted and optionally abbreviated string.

Examples:

- `numberstring(1234)` = "1.23K"
- `numberstring(12345)` = "12.3K"
- `numberstring(1234567)` = "1.23M"
- `numberstring(12345678)` = "12.3"
- `numberstring(1234567890)` = "1.23B"
- `numberstring(12345678901)` = "12.3B"
- `numberstring(1234567890123)` = "1.23T"
- `numberstring(12345678901234)` = "12.3T"
- `numberstring(1234567, false)` = "1,234,567"

<br>

## parse_resourceid() KQL function

The **parse_resourceid(resourceId: string)** function parses the specified Azure resource ID to extract resource attributes like the name, type, resource group, and subaccount ID.

Example:

```kusto
parse_resourceid('/subscriptions/###/resourceGroups/foo/providers/Microsoft.Compute/virtualMachines/bar')
```

```json
{
    "ResourceId": "/subscriptions/###/resourceGroups/foo/providers/Microsoft.Compute/virtualMachines/bar",
    "ResourceName": "bar",
    "SubAccountId": "###",
    "x_ResourceGroupName": "foo",
    "x_ResourceProvider": "Microsoft.Compute",
    "x_ResourceType": "microsoft.compute/virtualmachines"
}
```

<br>

## percent() KQL function

The **percent(table: (Count: long))** function in Data Explorer calculates the percentage of each record based on a required Count column.

{
    let total = todouble(toscalar(t | summarize sum(Count)));
    percentOfTotal(t, total)
}

<br>

## percentOfTotal() KQL function

The **percentOfTotal(table: (Count: long), total: long)** function in Data Explorer calculates the percentage of each record based on a required **Count** column. This function adds a new **Percent** column that divides the **Count** column by the specified **total** value.

<br>

## percentstring KQL function

The **percentstring(num: double, [total: double], [places: int])** function in Data Explorer returns the specified number as a percentage of the **total** as a string, using the specified number of decimal places. If the **total** parameter is not specified, `1.0` is used as the default total.

Examples:

- `percentstring(0.5)` = "50%"
- `percentstring(0.5, 2)` = "25%"
- `percentstring(0.5, 3, 2)` = "16.67%"

<br>

## plusminus() KQL function

The ****plusminus KQL function in Data Explorer a +/- sign based on the direction of the number.
plusminus(val: string)
{
    let neg = substring(val, 0, 1) == '-';
    iff(neg, val, strcat('+', val))
}

<br>

## PolicyAssignments table

The **PolicyAssignments** table in Power BI reports that queries Azure Policy assignments from Azure Resource Graph.

<br>

## PolicyDefinitions table

The **PolicyDefinitions** table in Power BI reports that queries Azure Policy definitions from Azure Resource Graph.

<br>

## PolicyStates table

The **PolicyStates** table in Power BI reports that queries Azure Policy states from Azure Resource Graph.

<br>

## Prices managed dataset

The **Prices** managed dataset includes:

- **ingestion/Prices** storage folder.
- **Prices_raw** table in the **Ingestion** database.
- **Prices_transform_v1_0()** function in the **Ingestion** database.
- **Prices_final_v1_0** table in the **Ingestion** database.
- **Prices_v1_0()** function in the **Hub** database.
- **Prices()** function in the **Hub** database.
- **Prices** table in Power BI reports.

The **Prices_raw** table supports Microsoft Cost Management export schemas for EA and MCA accounts. Data is transformed into a FOCUS-aligned dataset when ingested into the final table. This dataset does not explicitly support other clouds.

<br>

## PricingUnits table

The **PricingUnits** table in Power BI and Data Explorer is populated from the [Pricing units open data file](../open-data.md#pricing-units). This table is used to normalize [Prices](#prices-managed-dataset).

<br>

## PublicIPAddresses table

The **PublicIPAddresses** table in Power BI reports that queries Azure public IP addresses from Azure Resource Graph.

<br>

## Recommendations managed dataset

The **Recommendations** managed dataset includes:

- **ingestion/Recommendations** storage folder.
- **Recommendations_raw** table in the **Ingestion** database.
- **Recommendations_transform_v1_0()** function in the **Ingestion** database.
- **Recommendations_final_v1_0** table in the **Ingestion** database.
- **Recommendations_v1_0()** function in the **Hub** database.
- **Recommendations()** function in the **Hub** database.
- **Recommendations** table in Power BI reports.

The **Recommendations_raw** table supports Microsoft Cost Management reservation recommendation export schemas for EA and MCA accounts. Data is transformed into a FOCUS-aligned dataset when ingested into the final table. This dataset does not explicitly support other clouds.

<br>

## Regions table

The **Regions** table in Power BI and Data Explorer is populated from the [Regions open data file](../open-data.md#regions). This table is used to facilitate data cleansing.

<br>

## ReservationRecommendations table

The **ReservationRecommendations** table in Power BI pulls data from the [Recommendations managed dataset](#recommendations-managed-dataset), but filtered down to only reservation recommendations.

<br>

## Resources table

The **Resources** table in Power BI reports that queries Azure resources from Azure Resource Graph.

<br>

## resource_type() KQL function

The **resource_type(resourceType: string)** function in Data Explorer returns an object with details about the specified Azure resource type.

Examples:

- `resource_type('Microsoft.Compute/virtualMachines')` = { "SingularDisplayName": "Virtual machine" }
- `resource_type('Microsoft.Billing/billingAccounts')` = { "SingularDisplayName": "Billing account" }

<br>

## ResourceTypes table

The **ResourceTypes** table in Power BI and Data Explorer is populated from the [Resource types open data file](../open-data.md#resource-types). This table is used to facilitate data cleansing.

<br>

## SqlDatabases table

The **SqlDatabases** table in Power BI reports that queries SQL Azure databases from Azure Resource Graph.

<br>

## Services table

The **Services** table in Data Explorer is populated from the [Services open data file](../open-data.md#services). This table is used to facilitate data cleansing.

<br>

## StorageData table

The **StorageData** table in Power BI is populated from all files discovered in the Azure Data Lake Storage account. This table is used to identify data ingestion errors in the Data ingestion report.

<br>

## StorageErrors table

The **StorageErrors** table in Power BI is derived from the [StorageData table](#storagedata-table). This table is used to summarize data ingestion errors in the Data ingestion report.

<br>

## Subscriptions table

The **Subscriptions** table in Power BI reports that queries Azure subscriptions from Azure Resource Graph.

<br>

## Transactions managed dataset

The **Transactions** managed dataset includes:

- **ingestion/Transactions** storage folder.
- **Transactions_raw** table in the **Ingestion** database.
- **Transactions_transform_v1_0()** function in the **Ingestion** database.
- **Transactions_final_v1_0** table in the **Ingestion** database.
- **Transactions_v1_0()** function in the **Hub** database.
- **Transactions()** function in the **Hub** database.
- **Transactions** table in Power BI reports.

The **Transactions_raw** table supports Microsoft Cost Management reservation transactions export schemas for EA and MCA accounts. Data is transformed into a FOCUS-aligned dataset when ingested into the final table. This dataset does not explicitly support other clouds.

<br>

## updown() KQL function

The **updown(value: string)** function in Data Explorer returns an up or down arrow based on whether the specified value is positive or negative.

Examples:

- `updown(1)` = "↑"
- `updown(-1)` = "↓"

<br>

## VirtualMachines table

The **VirtualMachines** table in Power BI reports that queries Azure virtual machines from Azure Resource Graph.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.10/bladeName/Hubs/featureName/ConfigureScopes)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20sort%3Areactions-%2B1-desc)

<br>
