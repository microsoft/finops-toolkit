---
layout: default
parent: FinOps best practices library
permalink: /bestpractices/Sustainability
nav_order: 2
title: Sustainability
author: arclares
ms.date: 08/16/2024
ms.service: finops
description: 'Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.'

---

# 📇 Table of Contents
1. [Carbon Optimization](#carbon-optimization)


## Carbon Optimization

### Query: Carbon Emissions

This Azure Resource Graph (ARG) query identifies resources within your Azure environment that have recommendations for reducing carbon emissions, based on Azure Advisor recommendations.

#### Description

This query surfaces Azure resources with recommendations from Azure Advisor for optimizing carbon emissions. It highlights potential carbon savings and provides insights into how these recommendations can be implemented to reduce the carbon footprint of your cloud infrastructure.

#### Category

Sustainability

#### Potential Benefits

- **Carbon Footprint Reduction:** Identifies opportunities to reduce the carbon emissions associated with your Azure resources, contributing to environmental sustainability.
- **Cost Savings:** Optimizing resources for carbon efficiency can also lead to cost savings, as reducing energy consumption often aligns with reducing costs.
- **Compliance:** Helps in meeting organizational and regulatory requirements for sustainability and carbon reduction.

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> advisorresources
| where tolower(type) == "microsoft.advisor/recommendations"
| extend RecommendationTypeId = tostring(properties.recommendationTypeId)
| where RecommendationTypeId in ("94aea435-ef39-493f-a547-8408092c22a7", "e10b1381-5f0a-47ff-8c7b-37bd13d7c974")
| extend properties = parse_json(properties)
| extend monthlyCarbonSavingsKg = toreal(properties.extendedProperties.PotentialMonthlyCarbonSavings)
| extend shortDescription=properties.shortDescription.problem, recommendationType=properties.extendedProperties.recommendationType, recommendationMessage=properties.extendedProperties.recommendationMessage, PotentialMonthlyCarbonEmissions=properties.extendedProperties.PotentialMonthlyCarbonEmissions, PotentialMonthlyCarbonSavings=properties.extendedProperties.PotentialMonthlyCarbonSavings
| extend ResourceId=properties.resourceMetadata.resourceId, ResourceType=tostring(properties.impactedField)
| project subscriptionId, resourceGroup,ResourceId,ResourceType, shortDescription,recommendationType, recommendationMessage, PotentialMonthlyCarbonEmissions, PotentialMonthlyCarbonSavings, monthlyCarbonSavingsKg, properties
</code></pre>
  </div>
</details>



