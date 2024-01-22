---
layout: default
title: PowerShell
has_children: true
nav_order: 40
description: 'Automate and scale your FinOps efforts.'
permalink: /powershell
---

<span class="fs-9 d-block mb-4">PowerShell module</span>
Automate and scale your FinOps efforts with PowerShell commands that streamline operations and accelerate adoption across projects and teams.
{: .fs-6 .fw-300 }

[Install](#-install-the-module){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Commands](#-commands){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [📥 Install the module](#-install-the-module)
- [⚡ Commands](#-commands)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---

The FinOps toolkit PowerShell module is a collection of commands to automate and manage FinOps solutions. We're just getting started so let us know what you'd like to see next.

[PowerShell Gallery](https://www.powershellgallery.com/packages/FinOpsToolkit){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

## 📥 Install the module

```powershell
Import-Module -Name FinOpsToolkit
```

<br>

## ⚡ Commands

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

### FinOps Open Cost and Usage Specification (FOCUS) commands (deprecated)

<blockquote class="warning" markdown="1">
    _FOCUS commands were implemented before Microsoft Cost Management supported a native FOCUS export. Going forward, we recommend using the native export. These commands will remain available but will not be updated to support FOCUS 1.0-preview. If you have a scenario where you need a PowerShell converter, please leave feedback at [aka.ms/ftk](https://aka.ms/ftk)._
</blockquote>

- [ConvertTo-FinOpsSchema](ConvertTo-FinOpsSchema.md) – Converts Cost Management cost data to the FOCUS schema.
- [Invoke-FinOpsSchema](Invoke-FinOpsSchemaTransform.md) – Loads Cost Management data from a CSV file, converts it to FOCUS schema, and saves it to a new CSV file.

### Open data commands

- [Get-FinOpsPricingUnit](Get-FinOpsPricingUnit.md) – Gets an Azure region ID and name.
- [Get-FinOpsRegion](Get-FinOpsRegion.md) – Gets an Azure region ID and name.
- [Get-FinOpsResourceType](Get-FinOpsResourceType.md) – Gets details about an Azure resource type.
- [Get-FinOpsService](Get-FinOpsService.md) – Gets the name and category for a service, publisher, and cloud provider.

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any commands or scripts you're looking for. Vote up (👍) existing ideas or create a new issue to suggest a new idea. We'll focus on ideas with the most votes.

[Vote on ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+label%3A%22Area%3A+PowerShell%22+sort%3Areactions-%2B1-desc){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Suggest an idea](https://github.com/microsoft/finops-toolkit/issues/new/choose){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" bicep="1" %}

<br>
