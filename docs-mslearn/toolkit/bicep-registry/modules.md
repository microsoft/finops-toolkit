---
title: Bicep Registry modules for FinOps
description: This article summarizes the Bicep modules available from the FinOps toolkit and provides guidance on how to reference them in your templates.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what Bicep registry modules are available from the FinOps toolkit.
---

# Bicep Registry modules

Bicep modules developed within the toolkit are published to the [official Bicep Registry](https://azure.github.io/bicep-registry-modules). These modules aren't included directly in the toolkit release. To use a module, reference the desired module from your bicep code.

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

For details about the parameters for each module, refer to the module details.

<br>

## Modules

The FinOps toolkit maintains the following Bicep Registry modules:

<!--
- [Exports](exports.md) – Publish Cost Management datasets to a storage account ad-hoc or on a recurring schedule.
-->

- [Scheduled actions](scheduled-actions.md) – Send an email on a schedule or when an anomaly is detected.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20deploy%20Cost%20Management%20scheduled%20actions%20with%20the%20FinOps%20toolkit%20bicep%20modules%3F/cvaQuestion/How%20valuable%20are%20the%20Cost%20Management%20scheduled%20actions%20bicep%20modules%3F/surveyId/FTK/bladeName/BicepRegistry/featureName/Overview)
<!-- prettier-ignore-end -->

If you're looking for a specific module or template, vote for an existing or create a new idea. Share your ideas with others. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+label%3A%22Tool%3A+Bicep+Registry%22+sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

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
