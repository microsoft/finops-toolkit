---
title: Get-FinOpsResourceType command
description: Gets an Azure resource type and readable display names
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Get-FinOpsResourceType command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Get-FinOpsResourceType command

The **Get-FinOpsResourceType** command returns an Azure resource type with readable display names, a flag to indicate if the resource provider identified this as a preview resource type, a description, an icon, and help and support links.

<br>

## Syntax

```powershell
Get-FinOpsResourceType `
    [[-ResourceType] <string>] `
    [-IsPreview <bool>]
```

<br>

## Parameters

| Name            | Description                                                                                                                                                                                                                 |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑ResourceType` | Optional. Azure resource type value. Accepts wildcards. Default = \* (all).                                                                                                                                                 |
| `‑IsPreview`    | Optional. Indicates whether to include or exclude resource types that are in preview. Note: Not all resource types self-identify as being in preview, so this may not be completely accurate. Default = null (include all). |

<br>

## Examples

### Get resource type details

```powershell
Get-FinOpsResourceType -ResourceType "microsoft.compute/virtualmachines"
```

Returns the resource type details for virtual machines.

### Get non-preview resource types

```powershell
Get-FinOpsResourceType -Preview $false
```

Returns all resource types that are not in preview.

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
