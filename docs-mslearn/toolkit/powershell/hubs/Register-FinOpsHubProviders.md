---
title: Register-FinOpsHubProviders command
description: Register Azure resource providers required for FinOps hub using the Register-FinOpsHubProviders command in the FinOpsToolkit module.
author: bandersmsft
ms.author: banders
ms.date: 11/01/2024
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

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)


<br>
