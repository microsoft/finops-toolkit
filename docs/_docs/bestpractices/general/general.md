---
layout: default
parent: Best practices
permalink: /best-practices/General
nav_order: 2
title: General
author: arclares
ms.date: 08/16/2024
ms.service: finops
description: 'Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.'

---

<span class="fs-9 d-block mb-4">General</span>
Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.
{: .fs-6 .fw-300 }

[Share feedback](#️-looking-for-more){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🍃 Carbon Optimization](#carbon-optimization)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---


## Carbon Optimization

### Query: Carbon emissions

This Azure Resource Graph (ARG) query identifies resources within your Azure environment that have recommendations for reducing carbon emissions, based on Azure Advisor recommendations.

#### Description

This query surfaces Azure resources with recommendations from Azure Advisor for optimizing carbon emissions. It highlights potential carbon savings and provides insights into how these recommendations can be implemented to reduce the carbon footprint of your cloud infrastructure.

#### Category

Sustainability

#### Query

<details>
  <summary>Click to view the code</summary>
  ```kql
  advisorresources
  | where tolower(type) == "microsoft.advisor/recommendations"
  | extend RecommendationTypeId = tostring(properties.recommendationTypeId)
  | where RecommendationTypeId in ("94aea435-ef39-493f-a547-8408092c22a7", "e10b1381-5f0a-47ff-8c7b-37bd13d7c974")
  | extend properties = parse_json(properties)
  | extend monthlyCarbonSavingsKg = toreal(properties.extendedProperties.PotentialMonthlyCarbonSavings)
  | extend shortDescription=properties.shortDescription.problem
  | extend recommendationType=properties.extendedProperties.recommendationType
  | extend recommendationMessage=properties.extendedProperties.recommendationMessage
  | extend PotentialMonthlyCarbonEmissions=properties.extendedProperties.PotentialMonthlyCarbonEmissions
  | extend PotentialMonthlyCarbonSavings=properties.extendedProperties.PotentialMonthlyCarbonSavings
  | extend ResourceId=properties.resourceMetadata.resourceId, ResourceType=tostring(properties.impactedField)
  | project subscriptionId, resourceGroup, ResourceId, ResourceType, shortDescription, recommendationType, recommendationMessage, PotentialMonthlyCarbonEmissions, PotentialMonthlyCarbonSavings, monthlyCarbonSavingsKg, properties
  ```
</details>

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any datasets you're looking for. Create a new issue with the details that you'd like to see either included in existing or new best practices.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="0" opt="1" pbi="0" ps="0" %}

<br>
