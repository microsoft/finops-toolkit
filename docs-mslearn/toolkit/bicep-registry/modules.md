---
title: Bicep registry
description: This article summarizes the Bicep modules available from the FinOps toolkit and provides guidance on how to reference them in your templates.
author: bandersmsft
ms.author: banders
ms.date: 10/30/2024
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what Bicep registry modules are available from the FinOps toolkit.
---

<!-- markdownlint-disable-next-line MD025 -->
# Bicep registry modules

Bicep modules developed within the toolkit are published to the [official Bicep Registry](https://azure.github.io/bicep-registry-modules). These modules aren't included directly in the toolkit release.

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

For details about the parameters for each module, see the following module details.

<br>

## Modules

<!--
- [Exports](exports.md) – Publish Cost Management datasets to a storage account ad-hoc or on a recurring schedule.
-->

- [Scheduled actions](scheduled-actions.md) – Send an email on a schedule or when an anomaly is detected.

<br>

## Looking for more?

We'd love to hear about any modules or templates you're looking for. To suggest a new idea, vote up existing ideas or create a new issue. We focus on ideas with the most votes.

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
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [Optimization engine](../optimization-engine/overview.md)

<br>
