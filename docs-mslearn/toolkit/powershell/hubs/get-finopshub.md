---
title: Get-FinOpsHub command
description: Get details about a FinOps hub instance using the Get-FinOpsHub command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Get-FinOpsHub command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Get-FinOpsHub command

The Get-FinOpsHubs command calls GitHub to retrieve all toolkit releases, then filters the list based on the specified options.

<br>

## Syntax

```powershell
Get-FinOpsHub `
    [[-Name] <string>] `
    [-ResourceGroupName <string>] `
    [<CommonParameters>]
```

<br>

## Parameters

| Name                 | Description                                                                              |
| -------------------- | ---------------------------------------------------------------------------------------- |
| '‑Name'              | Optional. Name of the FinOps hub instance. Supports wildcards.                           |
| '‑ResourceGroupName' | Optional. Name of the resource group the FinOps hub was deployed to. Supports wildcards. |

<br>

## Examples

The following examples demonstrate how to use the Get-FinOpsHub command to retrieve details about FinOps hub instances.

### Get all hubs

```powershell
Get-FinOpsHub
```

Returns all FinOps hubs for the selected subscription.

### Get named hubs

```powershell
Get-FinOpsHub -Name foo*
```

Returns all FinOps hubs that start with `foo`.

### Get hubs in a resource group

```powershell
Get-FinOpsHub -ResourceGroupName foo
```

Returns all hubs in the `foo` resource group.

### Get named hubs in a resource group

```powershell
Get-FinOpsHub -Name foo -ResourceGroupName bar
```

Returns all FinOps hubs named `foo` in the `bar` resource group.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK0.11/bladeName/PowerShell/featureName/Hubs.GetHub)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)


<br>
