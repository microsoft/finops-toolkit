---
title: FinOps best practices for general resource management
description: This article outlines proven FinOps practices for Microsoft Cloud services, focusing on cost optimization, efficiency improvements, and resource insights.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: arclares
#customer intent: As a FinOps user, I want to understand what FinOps best practices I should use with Microsoft Cloud services.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps best practices for general resource management

This article outlines a collection of general FinOps best practices that can be applied to various Microsoft Cloud services. It includes strategies for optimizing costs, improving efficiency, and using Azure Resource Graph (ARG) queries to gain insights into your resources. By following these practices, you can ensure that your cloud services are cost-effective and aligned with your organization's financial goals.

<br>

## Carbon Optimization

The following section provides an ARG query for carbon optimization. It helps you gain insights into your Azure resources and identify opportunities to reduce carbon emissions. By analyzing recommendations from Azure Advisor, you can optimize your cloud infrastructure for sustainability and environmental impact.

### Query: Carbon emissions

This ARG query identifies resources within your Azure environment that have recommendations for reducing carbon emissions, based on Azure Advisor recommendations.

**Description**

This query surfaces Azure resources with recommendations from Azure Advisor for optimizing carbon emissions. It highlights potential carbon savings and provides insights into how these recommendations can be implemented to reduce the carbon footprint of your cloud infrastructure.

**Category**

Sustainability

**Query**

```kusto
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

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.10/bladeName/Guide.BestPractices/featureName/General)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related resources:

- [FinOps Framework](../framework/finops-framework.md)

Related products:

- [Azure Carbon Optimization](/azure/carbon-optimization/)
- [Azure Advisor](/azure/advisor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [FinOps toolkit Power BI reports](../toolkit/power-bi/reports.md)
- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md)
- [FinOps workbooks](../toolkit/workbooks/finops-workbooks-overview.md)
- [Optimization engine](../toolkit/optimization-engine/overview.md)

<br>
