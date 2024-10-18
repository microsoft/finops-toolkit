---
title: Bicep Registry
description: This article summarizes the bicep modules available from the FinOps toolkit.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what Bicep Registry modules are available from the FinOps toolkit.
---

<!-- markdownlint-disable-next-line MD025 -->
# Bicep Registry modules

Bicep modules developed within the toolkit are published to the [official Bicep Registry](https://azure.github.io/bicep-registry-modules). These modules are not included directly in the toolkit release.

<br>

## Referencing bicep modules

Referencing a module in your bicep template is as simple as adding the following to the top of your file:

```bicep
module <name> 'br/public:cost/<scope>-<type>:<version>' {
   name: '<name>'
   params: {
      parameterName: '<parameter-value>'
   }
}
```

For details about the parameters for each module, see the module details below.

<br>

## Modules

<!--
- [Exports](exports.md) – Publish Cost Management datasets to a storage account ad-hoc or on a recurring schedule.
-->

- [Scheduled actions](scheduled-actions.md) – Send an email on a schedule or when an anomaly is detected.

<br>

## Looking for more?

We'd love to hear about any modules or templates you're looking for. Vote up (👍) existing ideas or create a new issue to suggest a new idea. We'll focus on ideas with the most votes.

[Vote on ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+label%3A%22Solution%3A+Bicep+Registry%22+sort%3Areactions-%2B1-desc) &nbsp; [Suggest an idea](https://aka.ms/ftk/ideas)

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Anomaly management](../../framework/understand/anomalies.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](https://aka.ms/finops/workbooks)
- [Optimization engine](../optimization-engine/optimization-engine-overview.md)

<br>
