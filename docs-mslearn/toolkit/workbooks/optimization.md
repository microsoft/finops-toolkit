---
title: Optimization workbook
description: The Azure Monitor workbook focuses on cost optimization, providing insights and recommendations for improving cost efficiency in your Azure environment.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
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

## Related content

Related FinOps capabilities:

- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Advisor](/azure/advisor/)
- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [Optimization engine](../optimization-engine/overview.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
