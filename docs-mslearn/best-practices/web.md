---
title: FinOps best practices for Web
description: This article outlines a collection of proven FinOps practices for web services, focusing on cost optimization, efficiency improvements, and resource insights.
author: bandersmsft
ms.author: banders
ms.date: 02/13/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: arclares
#customer intent: As a FinOps user, I want to understand what FinOps best practices I should use with web services.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps best practices for Web

This article outlines a collection of proven FinOps practices for web services. It provides strategies for optimizing costs, improving efficiency, and using Azure Resource Graph (ARG) queries to gain insights into your web resources. By following these practices, you can ensure that your web services are cost-effective and aligned with your organization's financial goals.

<br>

## App Service

The following sections provide ARG queries for App Service. These queries help you gain insights into your App Service resources and ensure they're configured with the appropriate settings. By analyzing App Service plans and surfacing recommendations from Azure Advisor, you can optimize your App Service resources for cost efficiency.

### Query: Web Application Status

This ARG query retrieves the status and basic information of web applications within your Azure environment.

**Category**

Monitoring

**Query**

```kusto
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

This ARG query retrieves detailed information about Azure App Service Plans within your Azure environment.

**Category**

Resource management

**Query**

```kusto
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

- [FinOps toolkit Power BI reports](../toolkit/power-bi/reports.md)
- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md)
- [FinOps workbooks](../toolkit/workbooks/finops-workbooks-overview.md)
- [Optimization engine](../toolkit/optimization-engine/overview.md)

<br>
