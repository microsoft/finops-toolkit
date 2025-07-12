---
title: FinOps best practices for Web
description: This article outlines a collection of proven FinOps practices for web services, focusing on cost optimization, efficiency improvements, and resource insights.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
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

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.11/bladeName/Guide.BestPractices/featureName/Web)

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
