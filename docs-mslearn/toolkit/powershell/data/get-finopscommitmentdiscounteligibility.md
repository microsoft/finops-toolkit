---
title: Get-FinOpsCommitmentDiscountEligibility command
description: Get commitment discount eligibility for a meter using the Get-FinOpsCommitmentDiscountEligibility command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 09/02/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Get-FinOpsCommitmentDiscountEligibility command in the FinOpsToolkit module.
---

# Get-FinOpsCommitmentDiscountEligibility command

The **Get-FinOpsCommitmentDiscountEligibility** command returns a pre-computed lookup of which meters are eligible for commitment-based discounts (reservations and savings plans), sourced from the Azure Retail Prices API.

<br>

## Syntax

```powershell
Get-FinOpsCommitmentDiscountEligibility `
    [[-MeterId] <string>] `
    [-SpendEligibility <string>] `
    [-UsageEligibility <string>]
```

<br>

## Parameters

| Name             | Description                                                                                                                     |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| MeterId           | Optional. The meter ID to look up. Accepts wildcards. Default = \* (all).                                                        |
| SpendEligibility  | Optional. Filters to meters with the specified reservation (spend-based commitment) eligibility. Expected values: Eligible, Not Eligible. Default = null (all). |
| UsageEligibility  | Optional. Filters to meters with the specified savings plan (usage-based commitment) eligibility. Expected values: Eligible, Not Eligible. Default = null (all). |

<br>

## Examples

The following examples demonstrate how to use the Get-FinOpsCommitmentDiscountEligibility command to retrieve commitment discount eligibility based on different criteria.

### Get based on meter ID

```powershell
Get-FinOpsCommitmentDiscountEligibility -MeterId "00003b45-e996-5b04-b673-a2db710f9237"
```

Returns commitment discount eligibility for the specified meter.

### Get meters eligible for reservations

```powershell
Get-FinOpsCommitmentDiscountEligibility -SpendEligibility "Eligible"
```

Returns all meters eligible for reservations.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/OpenData.GetCommitmentDiscountEligibility)
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
- [Azure Retail Prices API](/rest/api/cost-management/retail-prices/azure-retail-prices)

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)
- [FinOps toolkit open data](../../open-data.md)

<br>
