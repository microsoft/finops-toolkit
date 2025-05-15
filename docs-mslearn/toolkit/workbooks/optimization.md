---
title: FinOps toolkit Optimization workbook
description: The Azure Monitor workbook focuses on cost optimization, providing insights and recommendations for improving cost efficiency in your Azure environment.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: arclares
#customer intent: As a FinOps user, I want to understand what the FinOps Optimization workbook is and how it can help me implement the Workload optimization and Rate optimization FinOps capabilities.
---

<!-- markdownlint-disable-next-line MD025 -->
# Optimization workbook

The optimization workbook is an Azure Monitor workbook that provides a single location to view cost optimization, modeled after the Well-Architected Framework guidance. It offers a range of insights, including:

- Advisor cost recommendations
- Idle resource identification
- Management of improperly deallocated virtual machines
- Insights into using Azure Hybrid Benefit options for Windows, Linux, and SQL databases

The workbook includes insights for compute, storage, and networking. The workbook also has a quick fix option for some queries. The quick fix option allows you to apply the recommended optimization directly from the workbook page, streamlining the optimization process.

:::image type="content" source="./media/optimization/overview-optimization.png" border="true" alt-text="Screenshot of the Cost optimization workbook overview." lightbox="./media/optimization/overview-optimization.png":::

The workbook has two main sections: Rate optimization and Usage optimization.

<br>

## Rate optimization

This section focuses on strategies to optimize your Azure costs by addressing rate-related factors. It includes insights from Advisor cost recommendations, guidance on the utilization of Azure Hybrid Benefit options for Windows, Linux, and SQL databases, and more. It also includes recommendations for commitment discounts, such as Reservations and Azure Savings Plans. Rate optimization is critical for reducing the hourly or monthly cost of your resources.

Here's an example of the Rate optimization section for Windows virtual machines with Azure Hybrid Benefit.

:::image type="content" source="./media/optimization/rate-optimization-example.png" alt-text="Screenshot showing the Rate optimization section for Windows virtual machines with Azure Hybrid Benefit." lightbox="./media/optimization/rate-optimization-example.png" :::

<br>

## Usage optimization

The purpose of Usage optimization is to ensure that your Azure resources are used efficiently. This section provides guidance to identify idle resources, manage improperly deallocated virtual machines, and implement recommendations to enhance resource efficiency. Focus on usage optimization to maximize your resource utilization and minimize costs.

Here's an example of the Usage optimization section for Azure Kubernetes Service (AKS).

:::image type="content" source="./media/optimization/usage-optimization-example.png" alt-text="Screenshot showing the Usage optimization section for AKS." lightbox="./media/optimization/usage-optimization-example.png" :::

For more information about the Cost optimization workbook, see [Understand and optimize your Azure costs using the Cost optimization workbook](/azure/advisor/advisor-cost-optimization-workbook).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20workbooks%3F/cvaQuestion/How%20valuable%20are%20FinOps%20workbooks%3F/surveyId/FTK0.10/bladeName/Workbooks.Optimization/featureName/Overview)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20Workbooks%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related FinOps capabilities:

- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Advisor](/azure/advisor/)
- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps alerts](../alerts/finops-alerts-overview.md)
- [Optimization engine](../optimization-engine/overview.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
