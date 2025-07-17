---
title: Get-FinOpsService command
description: Get the name and category for a service, publisher, and cloud provider using the Get-FinOpsService command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Get-FinOpsService command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Get-FinOpsService command

The **Get-FinOpsService** command returns service details based on the specified filters. This command is designed to help map Cost Management cost data to the FinOps Open Cost and Usage Specification (FOCUS) schema but can also be useful for general data cleansing.

<br>

## Syntax

```powershell
Get-FinOpsService `
    [[-ConsumedService] <string>] `
    [[-ResourceId] <string>] `
    [[-ResourceType] <string>] `
    [-ServiceName <string>] `
    [-ServiceCategory <string>] `
    [-ServiceModel <string>] `
    [-Environment <string>] `
    [-PublisherName <string>] `
    [-PublisherCategory <string>]
```

<br>

## Parameters

| Name                 | Description                                                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `‑ConsumedService`   | Optional. ConsumedService value from a Cost Management cost/usage details dataset. Accepts wildcards. Default = \* (all). |
| `‑ResourceId`        | Optional. The Azure resource ID for resource you want to look up. Accepts wildcards. Default = \* (all).                  |
| `‑ResourceType`      | Optional. The Azure resource type for the resource you want to find the service for. Default = null (all).                |
| `‑ServiceName`       | Optional. The service name to find. Default = null (all).                                                                 |
| `‑ServiceCategory`   | Optional. The service category to find services for. Default = null (all).                                                |
| `‑Servicemodel`      | Optional. The service model the service aligns to. Expected values: IaaS, PaaS, SaaS. Default = null (all).               |
| `‑Environment`       | Optional. The environment the service runs in. Expected values: Cloud, Hybrid. Default = null (all).                      |
| `‑PublisherName`     | Optional. The publisher name to find services for. Default = null (all).                                                  |
| `‑PublisherCategory` | Optional. The publisher category to find services for. Default = null (all).                                              |

<br>

## Examples

The following example demonstrates how to use the Get-FinOpsService command to retrieve service details.

### Get a specific region

```powershell
Get-FinOpsService `
    -ConsumedService "Microsoft.C*" `
    -ResourceType "Microsoft.Compute/virtualMachines"
```

Returns all services with a resource provider that starts with `Microsoft.C`.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/OpenData.GetService)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)
- [FinOps toolkit open data](../../open-data.md)

<br>
