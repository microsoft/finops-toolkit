---
title: Get-FinOpsHub command
description: Gets details about a FinOps hub instance.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
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

### Get all hubs

```powershell
Get-FinOpsHub
```

Returns all FinOps hubs for the selected subscription.

### Get named hubs

```powershell
Get-FinOpsHub -Name foo*
```

Returns all FinOps hubs that start with 'foo'.

### Get hubs in a resource group

```powershell
Get-FinOpsHub -ResourceGroupName foo
```

Returns all hubs in the 'foo' resource group.

### Get named hubs in a resource group

```powershell
Get-FinOpsHub -Name foo -ResourceGroupName bar
```

Returns all FinOps hubs named 'foo' in the 'bar' resource group.

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
