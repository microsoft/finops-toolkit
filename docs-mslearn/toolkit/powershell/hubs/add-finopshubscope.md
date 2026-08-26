---
title: Add-FinOpsHubScope command
description: Add a scope to be monitored by a FinOps hub instance using the Add-FinOpsHubScope command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 08/26/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Add-FinOpsHubScope command in the FinOpsToolkit module.
---

# Add-FinOpsHubScope command

The **Add-FinOpsHubScope** command adds a scope to the settings.json configuration file used by a FinOps hub instance so the scope can be monitored going forward. This command doesn't create the Cost Management export for the scope; use New-FinOpsCostExport to create the export.

<br>

## Syntax

```powershell
Add-FinOpsHubScope `
    [‑HubName] <string> `
    [‑Scope] <string> `
    [<CommonParameters>]
```

<br>

## Parameters

| Name       | Description                                                                |
| ---------- | -------------------------------------------------------------------------- |
| `‑HubName` | Required. Name of the FinOps hub instance.                                 |
| `‑Scope`   | Required. Resource ID of the scope to add to the FinOps hub configuration. |

<br>

## Examples

### Add a billing account scope

```powershell
Add-FinOpsHubScope -HubName ftk-FinOps-Hub -Scope "/providers/Microsoft.Billing/billingAccounts/1234567"
```

Adds the specified billing account scope to the ftk-FinOps-Hub hub configuration.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/Hubs.AddHubScope)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")
<!-- prettier-ignore-end -->

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
