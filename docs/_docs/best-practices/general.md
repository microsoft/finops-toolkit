---
title: FinOps best practices for general resource management
description: This article outlines a collection of proven FinOps practices for Microsoft Cloud services.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: arclares
#customer intent: As a FinOps user, I want to understand what FinOps best practices I should use with Microsoft Cloud services. 
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps best practices for general resource management

This article outlines a collection of general proven FinOps practices that can be applied to many Microsoft Cloud services.

<br>

## Carbon Optimization

### Query: Carbon emissions

This Azure Resource Graph (ARG) query identifies resources within your Azure environment that have recommendations for reducing carbon emissions, based on Azure Advisor recommendations.

<h4>Description</h4>

This query surfaces Azure resources with recommendations from Azure Advisor for optimizing carbon emissions. It highlights potential carbon savings and provides insights into how these recommendations can be implemented to reduce the carbon footprint of your cloud infrastructure.

<h4>Category</h4>

Sustainability

<h4>Query</h4>

```kql
advisorresources
| where tolower(type) == "microsoft.advisor/recommendations"
| extend RecommendationTypeId = tostring(properties.recommendationTypeId)
| where RecommendationTypeId in ("94aea435-ef39-493f-a547-8408092c22a7", "e10b1381-5f0a-47ff-8c7b-37bd13d7c974")
| extend properties = parse_json(properties)
| project
    subscriptionId,
    resourceGroup,
    ResourceId = properties.resourceMetadata.resourceId,
    ResourceType = tostring(properties.impactedField),
    shortDescription = properties.shortDescription.problem,
    recommendationType = properties.extendedProperties.recommendationType,
    recommendationMessage = properties.extendedProperties.recommendationMessage,
    PotentialMonthlyCarbonEmissions = properties.extendedProperties.PotentialMonthlyCarbonEmissions,
    PotentialMonthlyCarbonSavings = toreal(properties.extendedProperties.PotentialMonthlyCarbonSavings),
    properties
```

<br>

## Looking for more?

Did we miss anything? Would you like to see something added? We'd love to hear about any questions, problems, or solutions you'd like to see covered here. [Create a new issue](https://aka.ms/ftk/ideas) with the details that you'd like to see either included here.

<br>

## Related content

Related resources:

- [FinOps Framework](../../../docs-mslearn/framework/finops-framework.md)

Related products:

- [Azure Carbon Optimization](/azure/carbon-optimization/)
- [Azure Advisor](/azure/advisor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [FinOps toolkit Power BI reports](../../../docs-mslearn/power-bi/reports.md)
- [FinOps hubs](../../../docs-mslearn/hubs/finops-hubs-overview.md)
- [FinOps workbooks](../../../docs-mslearn/toolkit/workbooks/finops-workbooks-overview.md)
- [Optimization engine](../../../docs-mslearn/optimization-engine/optimization-engine-overview.md)

<br>
