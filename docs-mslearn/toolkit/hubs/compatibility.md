---
title: Compatibility guide
description: Learn which Power BI report versions are compatible with each FinOps hubs version to ensure seamless upgrades and data integrity.
author: flanakin
ms.author: micflan
ms.date: 05/06/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps toolkit user, I want to learn about which versions of Power BI reports work with each version of FinOps hubs so that I can use them.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps hubs compatibility guide

FinOps hubs support in-place upgrades by redeploying the template. But what happens with the data? Might it break Power BI reports? What about my customized reports? This guide helps you identify what dependencies need to change when moving from one version of FinOps hubs to another. If you have any questions, [start a discussion](https://aka.ms/ftk/discuss).

<br>

## Versioning in the FinOps toolkit

All FinOps toolkit tools and resources maintain the same version number to make it easier to know which tools work together. As of today, it's mostly about FinOps hubs, but will expand as more tools are added in the future. If you can, we recommend updating all resources at the same time. However, we know it isn't always feasible. The intent of this guide is to help you understand what you can expect when you upgrade some but not all tools.

<br>

## Compatibility chart

The following table conveys different scenarios with specific types of Cost Management exports and FinOps hubs releases. Based on the combination you have (or plan to have), make note of the storage path and the Power BI version.

The storage path is important for any client that's utilizing the same datasets. It might be toolkit Power BI reports (covered by the Power BI version), Microsoft Fabric shortcuts, or other tools.

The Power BI version refers to the Power BI reports made available within that specific version of the FinOps toolkit. If you customized an older version of the reports, make note of the version you started with, as that is what is useful here.

| Cost Management exports                   | FinOps hubs | Storage path                       | Power BI      | Notes                                                                                                                                         |
| ----------------------------------------- | ----------- | ---------------------------------- | ------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| FOCUS costs, prices, reservation datasets | 0.10        | {dataset}/{yyyy}/{MM}/{scope}      | 0.7+²         | Fabric Real-Time Intelligence support and data quality improvements                                                                           |
| FOCUS costs, prices, reservation datasets | 0.9         | {dataset}/{yyyy}/{MM}/{scope}      | 0.7+²         | Managed exports for all datasets, MCA reservation recommendations, multiple reservation recommendation exports, and data quality improvements |
| FOCUS costs, prices, reservation datasets | 0.8         | {dataset}/{yyyy}/{MM}/{scope}      | 0.7+²         | ADX ingestion and KQL report optimizations                                                                                                    |
| FOCUS costs, prices, reservation datasets | 0.7         | {dataset}/{yyyy}/{MM}/{scope}¹     | 0.7+²         | Storage path updated to new dataset names that support joining multiple related datasets together                                             |
| FOCUS costs, prices, reservation datasets | 0.6         | {export-type}/{yyyy}/{MM}/{scope}  | 0.6+          | Reservation recommendations pulled from hub storage                                                                                           |
| FOCUS 1.0-preview(v1) or 1.0 costs        | 0.6         | {export-type}/{yyyy}/{MM}/{scope}¹ | 0.6+²         | Storage path updated; Reservation recommendations pulled from a separate, non-hub storage URL (or excluded from report)                       |
| FOCUS 1.0-preview(v1) or 1.0 costs        | 0.5         | {scope}/{yyyyMM}/{export-type}     | 0.4+²         | Reservation recommendations pulled from a separate, non-hub storage URL (or excluded from report)                                             |
| FOCUS 1.0-preview(v1) or 1.0 costs        | 0.4         | {scope}/{yyyyMM}/{export-type}     | 0.4+²         | Supports a mix of FOCUS 1.0 and 1.0-preview(v1) data; Reservation recommendations pulled from the Cost Management connector for Power BI      |
| FOCUS 1.0-preview(v1) only                | 0.4         | {scope}/{yyyyMM}/{export-type}¹    | 0.2+          | Storage path updated                                                                                                                          |
| FOCUS 1.0-preview(v1) only                | 0.2 - 0.3   | {path}/{yyyyMM}/{export-type}      | 0.2+²         | Switched to FOCUS data only                                                                                                                   |
| Actual or Amortized costs (not both)      | 0.1 - 0.1.1 | {path}/{yyyyMM}/{export-type}      | 0.0.1 - 0.1.1 | EA and MCA                                                                                                                                    |
| Actual or Amortized costs (not both)      | 0.0.1       | {path}/{yyyyMM}/{export-type}      | 0.0.1 - 0.1.1 | EA only                                                                                                                                       |

¹ When storage paths update, there's a risk that re-exported data lands in a new place and might cause duplicate data. To resolve, remove the old folders in the **ingestion** container.<br>

² Older Power BI reports don't work with this combination of FinOps hubs version and exported datasets.<br>

<br>

## Looking for more?

Did this guide give you the answers you needed? If not, ask a question in the discussion forums. We're here to help!

> [!div class="nextstepaction"]
> [Ask a question](https://aka.ms/ftk/discuss)

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.10/bladeName/Hubs/featureName/Compatibility)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3Areactions-%2B1-desc%20)

<br>

## Related content

- [Review the upgrade guide](upgrade.md)
- [Deploy the latest release](finops-hubs-overview.md#create-a-new-hub)

<br>
