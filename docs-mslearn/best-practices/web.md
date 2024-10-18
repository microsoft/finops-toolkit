---
title: FinOps best practices for Web
description: This article outlines a collection of proven FinOps practices for web services.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: arclares
#customer intent: As a FinOps user, I want to understand what FinOps best practices I should use with web services.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps best practices for Web

This article outlines a collection of proven FinOps practices for web services.

<br>

## App Service

### Query: Web Application Status

This Azure Resource Graph (ARG) query retrieves the status and basic information of web applications within your Azure environment.

<h4>Category</h4>

Monitoring

<h4>Query</h4>

```kql
resources
| where type =~ 'Microsoft.Web/sites'
| project
    id,
    WebAppName = name,
    Type = kind,
    Status = tostring(properties.state),
    WebAppLocation = location,
    AppServicePlan = tostring(properties.serverFarmId),
    WebAppRG = resourceGroup,
    SubscriptionId = subscriptionId
| order by id asc
```

### Query: App Service plan details

This Azure Resource Graph (ARG) query retrieves detailed information about Azure App Service Plans within your Azure environment.

<h4>Category</h4>

Resource management

<h4>Query</h4>

```kql
resources
| where type == "microsoft.web/serverfarms"  and sku.tier !~ 'Free'
| project
    planId = tolower(tostring(id)),
    name,
    skuname = tostring(sku.name),
    skutier = tostring(sku.tier),
    workers = tostring(properties.numberOfWorkers),
    maxworkers = tostring(properties.maximumNumberOfWorkers),
    webRG = resourceGroup,
    Sites = tostring(properties.numberOfSites),
    SubscriptionId = subscriptionId
| join kind=leftouter (
    resources
    | where type == "microsoft.insights/autoscalesettings"
    | project
        planId = tolower(tostring(properties.targetResourceUri)),
        PredictiveAutoscale = properties.predictiveAutoscalePolicy.scaleMode,
        AutoScaleProfiles = properties.profiles,
        resourceGroup
) on planId
```

<br>

## Looking for more?

Did we miss anything? Would you like to see something added? We'd love to hear about any questions, problems, or solutions you'd like to see covered here. [Create a new issue](https://aka.ms/ftk/ideas) with the details that you'd like to see either included here.

<br>

## Related content

Related resources:

- [FinOps Framework](../framework/finops-framework.md)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](../../docs/_optimize/workbooks/README.md)
- [Optimization engine](../optimization-engine/optimization-engine-overview.md)

<br>
