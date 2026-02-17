---
title: Get-FinOpsResourceType command
description: Get an Azure resource type with readable display names, preview status, description, icon, and support links using the Get-FinOpsResourceType command.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Get-FinOpsResourceType command in the FinOpsToolkit module.
---

# Get-FinOpsResourceType command

The **Get-FinOpsResourceType** command returns an Azure resource type with readable display names, a flag to indicate if the resource provider identified it as a preview resource type, a description, an icon, and help and support links.

<br>

## Syntax

```powershell
Get-FinOpsResourceType `
    [[-ResourceType] <string>] `
    [-IsPreview <bool>]
```

<br>

## Parameters

| Name            | Description                                                                                                                                                                                                              |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `‑ResourceType` | Optional. Azure resource type value. Accepts wildcards. Default = \* (all).                                                                                                                                              |
| `‑IsPreview`    | Optional. Indicates whether to include or exclude resource types that are in preview. Not all resource types self-identify as being in preview, so this information might not be accurate. Default = null (include all). |

<br>

## Examples

The following examples demonstrate how to use the Get-FinOpsResourceType command to retrieve Azure resource type details based on different criteria.

### Get resource type details

```powershell
Get-FinOpsResourceType -ResourceType "microsoft.compute/virtualmachines"
```

Returns the resource type details for virtual machines.

### Get non-preview resource types

```powershell
Get-FinOpsResourceType -Preview $false
```

Returns all resource types that aren't in preview.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/OpenData.GetResourceType)
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

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)
- [FinOps toolkit open data](../../open-data.md)

<br>
