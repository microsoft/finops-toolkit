---
title: Get-FinOpsPricingUnit command
description: Get a pricing unit, distinct unit, and block size using the Get-FinOpsPricingUnit command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Get-FinOpsPricingUnit command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Get-FinOpsPricingUnit command

The **Get-FinOpsPricingUnit** command returns a pricing unit (also known as unit of measure) with the singular, distinct unit based on applicable block pricing rules, and the pricing block size.

> [!NOTE]
> Block pricing is when a service is measured in groups of units. For example, 100 hours.

<br>

## Syntax

```powershell
Get-FinOpsPricingUnit `
    [[-UnitOfMeasure] <string>] `
    [-DistinctUnits <string>] `
    [-BlockSize <string>]
```

<br>

## Parameters

| Name          | Description                                                                                                                                                           |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| UnitOfMeasure | Optional. Unit of measure (also known as pricing unit) value from a Cost Management cost/usage details or price sheet dataset. Accepts wildcards. Default = \* (all). |
| DistinctUnits | Optional. The distinct unit for the pricing unit without block pricing. Accepts wildcards. Default = \* (all).                                                        |
| BlockSize     | Optional. The number of units for block pricing (for example, 100 for "100 Hours"). Default = null (all).                                                             |

<br>

## Examples

The following examples demonstrate how to use the Get-FinOpsPricingUnit command to retrieve pricing units based on different criteria.

### Get based on unit of measure

```powershell
Get-FinOpsPricingUnit -UnitOfMeasure "*hours*"
```

Returns all pricing units with "hours" in the name.

### Get based on distinct units

```powershell
Get-FinOpsPricingUnit -DistinctUnits "GB"
```

Returns all pricing units measured in gigabytes.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK0.11/bladeName/PowerShell/featureName/OpenData.GetPricingUnit)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)
- [FinOps toolkit open data](../../open-data.md)

<br>
