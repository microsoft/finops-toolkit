---
layout: default
parent: Best practices
permalink: /best-practices/databases
title: Databases
author: arclares
ms.date: 08/16/2024
ms.service: finops
description: 'Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.'

---

<span class="fs-9 d-block mb-4">Databases best practices</span>
Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure database resources.
{: .fs-6 .fw-300 }

[Share feedback](#️-looking-for-more){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Cosmos DB](#cosmos-db)
- [SQL Databases](#sql-databases)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---

## Cosmos DB

### Query: Confirm Cosmos DB request units

This Azure Resource Graph (ARG) query analyzes Cosmos DB accounts within your Azure environment to ensure they are configured with the appropriate Request Units (RUs).

<h4>Description</h4>

This query identifies Cosmos DB accounts with recommendations for optimizing their Request Units (RUs) based on usage patterns. It surfaces recommendations from Azure Advisor to adjust RUs for cost efficiency.

<h4>Category</h4>

Optimization

<h4>Query</h4>

```kql
advisorresources
| where type =~ 'microsoft.advisor/recommendations'
| where properties.impactedField == 'microsoft.documentdb/databaseaccounts'
    and properties.recommendationTypeId == '8b993855-1b3f-4392-8860-6ed4f5afd8a7'
| order by id asc
| project 
    id, subscriptionId, resourceGroup,
    CosmosDBAccountName = properties.extendedProperties.GlobalDatabaseAccountName,
    DatabaseName = properties.extendedProperties.DatabaseName,
    CollectionName = properties.extendedProperties.CollectionName,
    EstimatedAnnualSavings = bin(toreal(properties.extendedProperties.annualSavingsAmount), 1),
    SavingsCurrency = properties.extendedProperties.savingsCurrency
```

### Query: Cosmos DB collections that would benefit from switching to another throughput mode

This Azure Resource Graph (ARG) query identifies Cosmos DB collections within your Azure environment that would benefit from switching their throughput mode, based on Azure Advisor recommendations.

<h4>Description</h4>

This query surfaces Cosmos DB collections that have recommendations to switch their throughput mode (e.g., from manual to autoscale or vice versa) to optimize performance and cost. It leverages Azure Advisor recommendations to highlight potential improvements.

<h4>Category</h4>

Optimization

<h4>Benefits</h4>

- **Cost optimization:** Identifies Cosmos DB collections that can save costs by switching to a more appropriate throughput mode based on usage patterns and recommendations.
- **Performance management:** Ensures that Cosmos DB collections are using the optimal throughput mode, enhancing performance and avoiding over-provisioning or under-provisioning.

<h4>Query</h4>

```kql
advisorresources
| where type =~ 'microsoft.advisor/recommendations'
| where properties.impactedField == 'microsoft.documentdb/databaseaccounts'
    and properties.recommendationTypeId in (
        ' cdf51428-a41b-4735-ba23-39f3b7cde20c',
        ' 6aa7a0df-192f-4dfa-bd61-f43db4843e7d'
    )
| order by id asc
| project 
    id, subscriptionId, resourceGroup,
    CosmosDBAccountName = properties.extendedProperties.GlobalDatabaseAccountName,
    DatabaseName = properties.extendedProperties.DatabaseName,
    CollectionName = properties.extendedProperties.CollectionName,
    EstimatedAnnualSavings = bin(toreal(properties.extendedProperties.annualSavingsAmount), 1),
    SavingsCurrency = properties.extendedProperties.savingsCurrency
```

### Query: Cosmos DB backup mode details

This Azure Resource Graph (ARG) query analyzes Cosmos DB accounts that use the 'Periodic' backup policy and do not have multiple write locations enabled.

<h4>Category</h4>

Optimization

<h4>Query</h4>

```kql
resources
| where type == "microsoft.documentdb/databaseaccounts"
| where resourceGroup in ({ResourceGroup})
| where properties.backupPolicy.type == 'Periodic'
    and tobool(properties.enableMultipleWriteLocations) == false
| extend BackupCopies = toreal(properties.backupPolicy.periodicModeProperties.backupRetentionIntervalInHours)
    / (toreal(properties.backupPolicy.periodicModeProperties.backupIntervalInMinutes) / real(60))
| where BackupCopies >= 10
    or (BackupCopies > 2
        and toint(properties.backupPolicy.periodicModeProperties.backupRetentionIntervalInHours) <= 168)
| order by id asc
| project id, CosmosDBAccountName=name, resourceGroup, subscriptionId, BackupCopies
```

<br>

## SQL Databases

### Query: SQL DB idle

This Azure Resource Graph (ARG) query identifies SQL databases with names indicating they might be old, in development, or used for testing purposes.

<h4>Category</h4>

Optimization

<h4>Query</h4>

```kql
resources
| where type == "microsoft.sql/servers/databases"
| where name contains "old" or name contains "Dev"or  name contains "test"
| where resourceGroup in ({ResourceGroup})
| extend SQLDBName = name, Type = sku.name, Tier = sku.tier, Location = location
| order by id asc
| project id, SQLDBName, Type, Tier, resourceGroup, Location, subscriptionId
```

### Query: Unused Elastic Pools analysis

This Azure Resource Graph (ARG) query identifies potentially idle Elastic Pools in your Azure SQL environment by analyzing the number of databases associated with each Elastic Pool.

<h4>Category</h4>

Optimization

<h4>Query</h4>

```kql
resources
| where type == "microsoft.sql/servers/elasticpools"
| extend elasticPoolId = tolower(tostring(id))
| extend elasticPoolName = name
| extend elasticPoolRG = resourceGroup
| extend skuName = tostring(sku.name)
| extend skuTier = tostring(sku.tier)
| extend skuCapacity = tostring(sku.capacity)
| join kind=leftouter (
    resources
    | where type == "microsoft.sql/servers/databases"
    | extend elasticPoolId = tolower(tostring(properties.elasticPoolId))
) on elasticPoolId
| summarize databaseCount = countif(isnotempty(elasticPoolId1)) by 
    elasticPoolId,
    elasticPoolName,
    serverResourceGroup = resourceGroup,
    name,
    skuName,
    skuTier,
    skuCapacity,
    elasticPoolRG
| where databaseCount == 0
| project elasticPoolId,
    elasticPoolName,
    databaseCount,
    elasticPoolRG,
    skuName,
    skuTier,
    skuCapacity
```

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any datasets you're looking for. Create a new issue with the details that you'd like to see either included in existing or new best practices.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="0" opt="1" pbi="0" ps="0" %}

<br>
