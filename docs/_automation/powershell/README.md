---
title: FinOps toolkit PowerShell module
description: Automate and scale your FinOps efforts.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what PowerShell commands are available in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps toolkit PowerShell module

The FinOps toolkit PowerShell module is a collection of commands to automate and manage FinOps solutions. We're just getting started so let us know what you'd like to see next. For details about the FinOps toolkit PowerShell module, refer to the [PowerShell Gallery](https://www.powershellgallery.com/packages/FinOpsToolkit).

<br>

## Install the module

The FinOps toolkit module requires PowerShell 7, which is built into [Azure Cloud Shell](https://portal.azure.com/#cloudshell) and supported on all major operating systems. 

Azure Cloud Shell comes with PowerShell 7 and Azure PowerShell pre-installed. If you are not using Azure Cloud Shell, you will need to [Install PowerShell](/powershell/scripting/install/installing-powershell) first and then run the following commands to install Azure PowerShell:

```powershell
Install-Module -Name Az.Accounts
Install-Module -Name Az.Resources
```

To install the FinOps toolkit module, run the following in either Azure Cloud Shell or a PowerShell client:

```powershell
Install-Module -Name FinOpsToolkit
```

If this is the first time using Azure PowerShell, you will also need to sign into your account and select a default subscription:

```powershell
Connect-AzAccount
```

This will show a popup window to sign in to your account. If you do not see the window, it may be on a different screen.

<br>

## Commands

### General toolkit commands

- [Get-FinOpsToolkitVersion](toolkit/Get-FinOpsToolkitVersion.md) – Get details about available FinOps toolkit releases.

### Cost Management commands

- [Get-FinOpsCostExport](cost/Get-FinOpsCostExport.md) – Get details about Cost Management exports.
- [New-FinOpsCostExport](cost/New-FinOpsCostExport.md) – Create a new Cost Management export.
- [Remove-FinOpsCostExport](cost/Remove-FinOpsCostExport.md) – Delete a Cost Management export and optionally data associated with the export.
- [Start-FinOpsCostExport](cost/Start-FinOpsCostExport.md) – Initiates a Cost Management export run for the most recent period.

### FinOps hubs commands

- [Deploy-FinOpsHub](hubs/Deploy-FinOpsHub.md) – Deploy your first hub or update to the latest version.
- [Get-FinOpsHub](hubs/Get-FinOpsHub.md) – Get details about your FinOps hub instance.
- [Initialize-FinOpsHubDeployment](hubs/Initialize-FinOpsHubDeployment.md) – Initializes the deployment for FinOps hubs.
- [Register-FinOpsHubProviders](hubs/Register-FinOpsHubProviders.md) – Registers resource providers for FinOps hubs.
- [Remove-FinOpsHub](hubs/Remove-FinOpsHub.md) – Deletes a FinOps hub instance.

### Open data commands

- [Get-FinOpsPricingUnit](data/Get-FinOpsPricingUnit.md) – Gets an Azure region ID and name.
- [Get-FinOpsRegion](data/Get-FinOpsRegion.md) – Gets an Azure region ID and name.
- [Get-FinOpsResourceType](data/Get-FinOpsResourceType.md) – Gets details about an Azure resource type.
- [Get-FinOpsService](data/Get-FinOpsService.md) – Gets the name and category for a service, publisher, and cloud provider.

<br>

## Looking for more?

We'd love to hear about any commands or scripts you're looking for. Vote up (👍) existing ideas or create a new issue to suggest a new idea in the [FinOps toolkit issues list](https://aka.ms/ftk/ideas). We'll focus on ideas with the most votes.

<br>

## Related content

Related products:

- [Azure PowerShell](/powershell/azure/)
- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [Optimization engine](../optimization-engine/optimization-engine-overview.md)
- [Bicep Registry modules](../bicep-registry/modules.md)
- [FinOps toolkit open data](../open-data.md)

<br>
