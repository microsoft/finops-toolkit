---
title: Get-FinOpsRegion command
description: Gets an Azure region ID and name
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
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

| Name            | Description                                                                                                                      |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| ResouceLocation | Optional. Resource location value from a Cost Management cost/usage details dataset. Accepts wildcards. Default = \* (all).      |
| RegionId        | Optional. Azure region ID (lowercase English name without spaces). Accepts wildcards. Default = \* (all).                        |
| RegionName      | Optional. Azure region name (title case English name with spaces). Accepts wildcards. Default = \* (all).IncludeResourceLocation | Optional. Indicates whether to include the ResourceLocation property in the output. Default = false. |

<br>

## Examples

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

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
