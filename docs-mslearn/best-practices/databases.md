---
title: FinOps best practices for Databases
description: This article outlines a collection of proven FinOps practices for database services.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: arclares
#customer intent: As a FinOps user, I want to understand what FinOps best practices I should use with database services.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps best practices for Databases

This article outlines a collection of proven FinOps practices for database services. It provides strategies for optimizing costs, improving efficiency, and using Azure Resource Graph (ARG) queries to gain insights into your database resources. By following these practices, you can ensure that your database services are cost-effective and aligned with your organization's financial goals.

<br>

## Cosmos DB

The following sections provide ARG queries for Cosmos DB. These queries help you gain insights into your Cosmos DB accounts and ensure they're configured with the appropriate Request Units (RUs). By analyzing usage patterns and surfacing recommendations from Azure Advisor, you can optimize RUs for cost efficiency.

### Query: Confirm Cosmos DB request units

This ARG query analyzes Cosmos DB accounts within your Azure environment to ensure they're configured with the appropriate RUs.

**Description**

This query identifies Cosmos DB accounts with recommendations for optimizing their RUs based on usage patterns. It surfaces recommendations from Azure Advisor to adjust RUs for cost efficiency.

**Category**

Optimization

**Query**

```kusto
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

This ARG query identifies Cosmos DB collections within your Azure environment that would benefit from switching their throughput mode, based on Azure Advisor recommendations.

**Description**

This query surfaces Cosmos DB collections that have recommendations to switch their throughput mode (for example, from manual to autoscale or vice versa) to optimize performance and cost. It uses Azure Advisor recommendations to highlight potential improvements.

**Category**

Optimization

**Benefits**

- **Cost optimization:** Identifies Cosmos DB collections that can save costs by switching to a more appropriate throughput mode based on usage patterns and recommendations.
- **Performance management:** Ensures that Cosmos DB collections are using the optimal throughput mode, enhancing performance and avoiding over-provisioning or under-provisioning.

**Query**

```kusto
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

This ARG query analyzes Cosmos DB accounts that use the 'Periodic' backup policy and don't have multiple write locations enabled.

**Category**

Optimization

**Query**

```kusto
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

The following sections provide ARG queries for SQL Databases. These queries help you identify SQL databases that might be idle, old, in development, or used for testing purposes. By analyzing these databases, you can optimize costs and improve efficiency by decommissioning or repurposing underutilized resources.

### Query: SQL DB idle

This ARG query identifies SQL databases with names indicating they might be old, in development, or used for testing purposes.

**Category**

Optimization

**Query**

```kusto
resources
| where type == "microsoft.sql/servers/databases"
| where name contains "old" or name contains "Dev"or  name contains "test"
| where resourceGroup in ({ResourceGroup})
| extend SQLDBName = name, Type = sku.name, Tier = sku.tier, Location = location
| order by id asc
| project id, SQLDBName, Type, Tier, resourceGroup, Location, subscriptionId
```

### Query: Unused Elastic Pools analysis

This ARG query identifies potentially idle Elastic Pools in your Azure SQL environment by analyzing the number of databases associated with each Elastic Pool.

**Category**

Optimization

**Query**

```kusto
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

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/Guide.BestPractices/featureName/Databases)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related resources:

- [FinOps Framework](../framework/finops-framework.md)

Related solutions:

- [FinOps toolkit Power BI reports](../toolkit/power-bi/reports.md)
- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md)
- [FinOps workbooks](../toolkit/workbooks/finops-workbooks-overview.md)
- [Optimization engine](../toolkit/optimization-engine/overview.md)

<br>
