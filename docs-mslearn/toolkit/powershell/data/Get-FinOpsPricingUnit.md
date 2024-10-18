---
title: Get-FinOpsPricingUnit command
description: Gets a pricing unit, distinct unit, and block size
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Get-FinOpsPricingUnit command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Get-FinOpsPricingUnit command

The **Get-FinOpsPricingUnit** command returns a pricing unit (aka unit of measure) with the singular, distinct unit based on applicable block pricing rules, and the pricing block size.

<blockquote class="note" markdown="1">
  _Block pricing is when a service is measured in groups of units (e.g., 100 hours)._
</blockquote>

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

| Name          | Description                                                                                                                                                 |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| UnitOfMeasure | Optional. Unit of measure (aka pricing unit) value from a Cost Management cost/usage details or price sheet dataset. Accepts wildcards. Default = \* (all). |
| DistinctUnits | Optional. The distinct unit for the pricing unit without block pricing. Accepts wildcards. Default = \* (all).                                              |
| BlockSize     | Optional. The number of units for block pricing (e.g., 100 for "100 Hours"). Default = null (all).                                                          |

<br>

## Examples

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

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
