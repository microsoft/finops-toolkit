---
title: Get-FinOpsRecommendationType command
description: Get metadata for Azure Advisor recommendation types using the Get-FinOpsRecommendationType command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 10/10/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Get-FinOpsRecommendationType command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Get-FinOpsRecommendationType command

The **Get-FinOpsRecommendationType** command returns metadata about Azure Advisor recommendation types based on the specified filters. This data helps organize and provide additional context for Azure Advisor recommendations in FinOps reports and dashboards.

The recommendation type metadata includes:

- RecommendationTypeId - Unique GUID identifier
- Category - Cost, HighAvailability, OperationalExcellence, Performance, or Security
- Impact - High, Medium, or Low
- ServiceName - Name of the Azure service
- ResourceType - Azure resource type (lowercase)
- DisplayName - Human-readable description
- LearnMoreLink - URL to documentation

<br>

## Syntax

```powershell
Get-FinOpsRecommendationType `
    [[-RecommendationTypeId] <string>] `
    [[-Category] <string>] `
    [[-Impact] <string>] `
    [-ServiceName <string>] `
    [-ResourceType <string>]
```

<br>

## Parameters

| Name                     | Description                                                                                                                                                                                 |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑RecommendationTypeId`  | Optional. The recommendation type ID (GUID) to filter by. Accepts wildcards. Default = \* (all).                                                                                            |
| `‑Category`              | Optional. The recommendation category to filter by. Accepts wildcards. Default = \* (all). Expected values: Cost, HighAvailability, OperationalExcellence, Performance, Security.          |
| `‑Impact`                | Optional. The impact level to filter by. Accepts wildcards. Default = \* (all). Expected values: High, Medium, Low.                                                                         |
| `‑ServiceName`           | Optional. The service name to filter by. Accepts wildcards. Default = \* (all).                                                                                                             |
| `‑ResourceType`          | Optional. The resource type to filter by. Accepts wildcards. Default = \* (all).                                                                                                            |

<br>

## Examples

The following examples demonstrate how to use the Get-FinOpsRecommendationType command to retrieve recommendation type metadata.

### Get all recommendation types

```powershell
Get-FinOpsRecommendationType
```

Returns all recommendation types.

### Get cost recommendations

```powershell
Get-FinOpsRecommendationType -Category Cost
```

Returns all cost-related recommendation types.

### Get high-impact cost recommendations

```powershell
Get-FinOpsRecommendationType -Impact High -Category Cost
```

Returns all high-impact cost recommendation types.

### Get virtual machine recommendations

```powershell
Get-FinOpsRecommendationType -ResourceType "microsoft.compute/virtualmachines"
```

Returns all recommendation types that apply to virtual machines.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/OpenData.GetRecommendationType)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related products:

- [Azure Advisor](/azure/advisor/advisor-overview)

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps toolkit open data](../../open-data.md)

<br>
