---
title: Get-FinOpsToolkitVersion command
description: Get available versions from published FinOps toolkit releases using the Get-FinOpsToolkitVersion command.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Get-FinOpsToolkitVersion PowerShell command.
---

<!-- markdownlint-disable-next-line MD025 -->
# Get-FinOpsToolkitVersion command

The Get-FinOpsToolkitVersions command calls GitHub to retrieve all toolkit releases, then filters the list based on the specified options.

<br>

## Syntax

```powershell
Get-FinOpsToolkitVersion `
    [-Latest] `
    [-Preview] `
    [<CommonParameters>]
```

<br>

## Parameters

| Name    | Description                                                                                |
| ------- | ------------------------------------------------------------------------------------------ |
| Latest  | Optional. Indicates that only the most recent release should be returned. Default = false. |
| Preview | Optional. Indicates that preview releases should also be included. Default = false.        |

<br>

## Examples

The following examples demonstrate how to use the Get-FinOpsToolkitVersion command to retrieve available versions from published FinOps toolkit releases.

### Get stable release versions

```powershell
Get-FinOpsToolkitVersion
```

Returns all stable (non-preview) release versions.

### Get latest stable release only

```powershell
Get-FinOpsToolkitVersion -Latest
```

Returns only the latest stable (non-preview) release version.

### Get all versions

```powershell
Get-FinOpsToolkitVersion -Preview
```

Returns all release versions, including preview releases.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK0.12/bladeName/PowerShell/featureName/Toolkit.GetVersion)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
