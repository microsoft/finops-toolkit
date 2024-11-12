---
title: Initialize-FinOpsHubDeployment command
description: Initialize a FinOps hub deployment using the Initialize-FinOpsHubDeployment command in the FinOpsToolkit module.
author: bandersmsft
ms.author: banders
ms.date: 11/01/2024
ms.topic: reference
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Initialize-FinOpsHubDeployment command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
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

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)


<br>
