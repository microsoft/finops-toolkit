---
title: FinOps toolkit PowerShell module
description: Automate and scale your FinOps efforts using the FinOps toolkit PowerShell module, which includes commands to manage FinOps solutions.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what PowerShell commands are available in the FinOpsToolkit module.
---

# FinOps toolkit PowerShell module

The FinOps toolkit PowerShell module is a collection of commands to automate and manage FinOps solutions. We're just getting started so let us know what you'd like to see next. For details about the FinOps toolkit PowerShell module, refer to the [PowerShell Gallery](https://www.powershellgallery.com/packages/FinOpsToolkit).

<br>

## Install the module

The FinOps toolkit module requires PowerShell 7, which is built into [Azure Cloud Shell](https://portal.azure.com/#cloudshell) and supported on all major operating systems. 

Azure Cloud Shell comes with PowerShell 7 and Azure PowerShell preinstalled. If you aren't using Azure Cloud Shell, you need to [Install PowerShell](/powershell/scripting/install/installing-powershell) first and then run the following commands to install Azure PowerShell:

```powershell
Install-Module -Name Az.Accounts
Install-Module -Name Az.Resources
```

To install the FinOps toolkit module, run the following command in either Azure Cloud Shell or a PowerShell client:

```powershell
Install-Module -Name FinOpsToolkit
```

If it's the first time using Azure PowerShell, you also need to sign into your account and select a default subscription:

```powershell
Connect-AzAccount
```

It shows a popup window to sign in to your account. If you don't see the window, it might be on a different screen.

<br>

## Commands

The FinOps toolkit PowerShell module includes commands to manage FinOps solutions. Here are the available commands:

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

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/Overview)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")
<!-- prettier-ignore-end -->

<br>

## Related content

Related products:

- [Azure PowerShell](/powershell/azure/)
- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [Optimization engine](../optimization-engine/overview.md)
- [Bicep Registry modules](../bicep-registry/modules.md)
- [FinOps toolkit open data](../open-data.md)

<br>
