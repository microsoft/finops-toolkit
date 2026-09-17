---
title: FOCUS query library
description: Collection of SQL and KQL queries that leverage the FinOps Open Cost and Usage Specification (FOCUS).
author: flanakin
ms.author: micflan
ms.date: 03/11/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to query FOCUS data.
---

<!-- markdownlint-disable-next-line MD025 -->
# FOCUS query library

This article outlines a collection of SQL and KQL queries that can be used with a data store that hosts FinOps Open Cost and Usage Specification (FOCUS) data. Use the queries here to explore your data in [Microsoft Fabric](../fabric/create-fabric-workspace-finops.md) or [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) with Data Explorer.

<br>

## Prerequisites

Before you can execute these queries, you must have:

- A KQL or SQL database, like Azure Data Explorer or a Microsoft Fabric lakehouse or eventhouse.
- Create a table named "Costs" that uses a FOCUS 1.0 schema.
- Ingest cost from Microsoft and optionally other cloud or SaaS providers based on your needs.

If you do not have a database, consider one of the following options:

- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) with Data Explorer
- [Microsoft Fabric lakehouse](../fabric/create-fabric-workspace-finops.md)

<br>

## Account structure

Different providers have different account constructs that FinOps practitioners use for allocation, reporting, and more. Organizations may have one or many accounts within one or more providers and FinOps practitioners may need to review the cost broken down by each account. FOCUS has two types of accounts: a billing account and a sub account.

A billing account is the account where invoices are generated. Each billing account can have one or more sub accounts, which can be used for deploying and managing resources and services. Billing and sub accounts are often used to facilitate allocation strategies and FinOps practitioners must be able to break costs down by billing and sub account to facilitate FinOps scenarios like chargeback and budgeting.

### Example: Cost breakdown by account

**KQL**

```kusto
Costs
| where BillingPeriodStart == startofmonth(now(), -1)
| summarize
    BillingAccountName = take_any(BillingAccountName),
    BillingAccountType = take_any(BillingAccountType),
    SubAccountName     = take_any(SubAccountName),
    SubAccountType     = take_any(SubAccountType),
    BilledCost         = sum(BilledCost)
    by
    BillingAccountId,
    SubAccountId
```

**SQL**

```sql
SELECT
  BillingAccountId,
  BillingAccountName,
  BillingAccountType,
  SubAccountId,
  SubAccountName,
  SubAccountType,
  SUM(BilledCost)
FROM Costs
WHERE BillingPeriodStart = DATEADD(month, -1, DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0))
GROUP BY
  BillingAccountId,
  SubAccountId
```

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20Implementing%20FinOps%20guide%3F/cvaQuestion/How%20valuable%20is%20the%20Implementing%20FinOps%20guide%3F/surveyId/FTK0.8/bladeName/Guide.FOCUS/featureName/Queries)

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
