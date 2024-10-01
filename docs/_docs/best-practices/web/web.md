---
layout: default
parent: Best practices
permalink: /best-practices/web
title: Web
author: arclares
ms.date: 08/16/2024
ms.service: finops
description: 'Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.'

---

<span class="fs-9 d-block mb-4">Web best practices</span>
Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure web resources.
{: .fs-6 .fw-300 }

[Share feedback](#️-looking-for-more){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [App Service](#app-service)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---

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

## 🙋‍♀️ Looking for more?

We'd love to hear about any datasets you're looking for. Create a new issue with the details that you'd like to see either included in existing or new best practices.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="0" opt="1" pbi="0" ps="0" %}

<br>
