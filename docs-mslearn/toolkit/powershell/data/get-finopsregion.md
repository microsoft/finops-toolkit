---
title: Get-FinOpsRegion command
description: Get an Azure region ID and name based on the specified resource location using the Get-FinOpsRegion command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Get-FinOpsRegion command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Get-FinOpsRegion command

The **Get-FinOpsRegion** command returns an Azure region ID and name based on the specified resource location.

<br>

## Syntax

```powershell
Get-FinOpsRegion `
    [[-ResourceLocation] <string>] `
    [-RegionId <string>] `
    [-RegionName <string>]
```

<br>

## Parameters

| Name             | Description                                                                                                                      | Notes                                                                                                |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| ResourceLocation | Optional. Resource location value from a Cost Management cost/usage details dataset. Accepts wildcards. Default = \* (all).      |
| RegionId         | Optional. Azure region ID (lowercase English name without spaces). Accepts wildcards. Default = \* (all).                        |
| RegionName       | Optional. Azure region name (title case English name with spaces). Accepts wildcards. Default = \* (all).IncludeResourceLocation | Optional. Indicates whether to include the ResourceLocation property in the output. Default = false. |

<br>

## Examples

The following examples demonstrate how to use the Get-FinOpsRegion command to retrieve Azure region IDs and names based on different criteria.

### Get a specific region

```powershell
Get-FinOpsRegion -ResourceLocation "US East"
```

Returns the region ID and name for the East US region.

### Get many regions with the original Cost Management value

```powershell
Get-FinOpsRegion -RegionId "*asia*" -IncludeResourceLocation
```

Returns all Asia regions with the original Cost Management ResourceLocation value.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK0.12/bladeName/PowerShell/featureName/OpenData.GetRegion)

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
