---
title: Get-FinOpsInstanceSizeFlexibility command
description: Get the instance size flexibility group and ratio for an ARM SKU using the Get-FinOpsInstanceSizeFlexibility command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 09/02/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Get-FinOpsInstanceSizeFlexibility command in the FinOpsToolkit module.
---

# Get-FinOpsInstanceSizeFlexibility command

The **Get-FinOpsInstanceSizeFlexibility** command returns instance size flexibility (ISF) ratios, sourced from the Azure Reservations Catalogs API. ISF lets a reservation apply across multiple SKUs in the same flexibility group, weighted by a ratio.

<br>

## Syntax

```powershell
Get-FinOpsInstanceSizeFlexibility `
    [[-ArmSkuName] <string>] `
    [[-InstanceSizeFlexibilityGroup] <string>]
```

<br>

## Parameters

| Name                         | Description                                                                                |
| ---------------------------- | ------------------------------------------------------------------------------------------- |
| ArmSkuName                   | Optional. The ARM SKU name to look up. Accepts wildcards. Default = \* (all).               |
| InstanceSizeFlexibilityGroup | Optional. The instance size flexibility group to find SKUs for. Accepts wildcards. Default = \* (all). |

<br>

## Examples

The following examples demonstrate how to use the Get-FinOpsInstanceSizeFlexibility command to retrieve instance size flexibility data based on different criteria.

### Get based on ARM SKU name

```powershell
Get-FinOpsInstanceSizeFlexibility -ArmSkuName "Standard_D4s_v5"
```

Returns the flexibility group and ratio for the Standard_D4s_v5 SKU.

### Get based on flexibility group

```powershell
Get-FinOpsInstanceSizeFlexibility -InstanceSizeFlexibilityGroup "Dsv5 Series"
```

Returns all SKUs in the Dsv5 Series flexibility group.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/OpenData.GetInstanceSizeFlexibility)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")
<!-- prettier-ignore-end -->

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Instance size flexibility for reservations](/azure/cost-management-billing/reservations/instance-size-flexibility)

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)
- [FinOps toolkit open data](../../open-data.md)

<br>
