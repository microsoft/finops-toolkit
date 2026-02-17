---
title: Initialize-FinOpsHubDeployment command
description: Initialize a FinOps hub deployment using the Initialize-FinOpsHubDeployment command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Initialize-FinOpsHubDeployment command in the FinOpsToolkit module.
---

# Initialize-FinOpsHubDeployment command

The **Initialize-FinOpsHubDeployment** command performs any initialization tasks required for a resource group contributor to be able to deploy a FinOps hub instance in Azure, like registering resource providers. To view the full list of tasks performed, run the command with the `-WhatIf` option.

<br>

## Syntax

```powershell
Initialize-FinOpsHubDeployment `
    [-WhatIf <string>]
```

<br>

## Parameters

| Name      | Description                                                                        |
| --------- | ---------------------------------------------------------------------------------- |
| '‑WhatIf' | Optional. Shows what would happen if the command runs without actually running it. |

<br>

## Examples

The following example demonstrates how to use the Initialize-FinOpsHubDeployment command to initialize a FinOps hub deployment.

### Test FinOps hub deployment initialization

```powershell
Initialize-FinOpsHubDeployment `
    -WhatIf
```

Shows what would happen if the command runs without actually running it.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/Hubs.InitDeployment)
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
