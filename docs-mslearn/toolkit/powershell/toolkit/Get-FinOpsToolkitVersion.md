---
title: Get-FinOpsToolkitVersion command
description: Get available versions from published FinOps toolkit releases using the Get-FinOpsToolkitVersion command.
author: bandersmsft
ms.author: banders
ms.date: 11/01/2024
ms.topic: reference
ms.service: finops
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

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>