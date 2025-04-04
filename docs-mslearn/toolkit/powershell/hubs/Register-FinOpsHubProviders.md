---
title: Register-FinOpsHubProviders command
description: Register Azure resource providers required for FinOps hub using the Register-FinOpsHubProviders command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Register-FinOpsHubProviders command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Register-FinOpsHubProviders command

The **Register-FinOpsHubProviders** command registers the Azure resource providers required to deploy and operate a FinOps hub instance.

To register a resource provider, you must have Contributor access (or the /register permission for each resource provider) for the entire subscription. Subscription readers can check the status of the resource providers but can't register them. If you don't have access to register resource providers, contact a subscription contributor or owner to run the Register-FinOpsHubProviders command.

<br>

## Syntax

```powershell
Register-FinOpsHubProviders `
    [-WhatIf <string>] `
```

<br>

## Parameters

| Name      | Description                                                                        |
| --------- | ---------------------------------------------------------------------------------- |
| `‑WhatIf` | Optional. Shows what would happen if the command runs without actually running it. |

<br>

## Examples

The following example demonstrates how to use the Register-FinOpsHubProviders command to register the Azure resource providers required for a FinOps hub.

### Test register FinOps hub providers

```powershell
Register-FinOpsHubProviders `
    -WhatIf
```

Shows what would happen if the command runs without actually running it.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK0.9/bladeName/PowerShell/featureName/Hubs.RegisterProviders)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)


<br>
