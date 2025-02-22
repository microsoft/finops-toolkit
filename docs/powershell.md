---
layout: default
title: FinOps toolkit PowerShell - Automate your FinOps efforts
nav_order: 6
description: 'FinOps toolkit PowerShell helps you automate and scale common Cost Management and FinOps toolkit management operations and work with FinOps toolkit open data.'
permalink: /powershell
#customer intent: As a Finops practitioner, I need to learn about FinOps toolkit PowerShell
---

<span class="fs-9 d-block mb-4">FinOps toolkit PowerShell</span>
Automate and scale your FinOps efforts with PowerShell commands that streamline operations and accelerate adoption across projects and teams.
{: .fs-6 .fw-300 }

[Install](#deploy){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Documentation](https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/commands){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

---

<a name="overview"></a>

## Automate your FinOps efforts

The FinOps toolkit PowerShell module helps you automate and scale common Cost Management and FinOps toolkit management operations and work with FinOps toolkit open data.

<br>

<a name="whats-new"></a>

## What's new in February 2025 (v0.8)

February introduced new options in the New-FinOpsCostExport command and fixed support or price and reservation exports, cleaned up the Get-FinOpsCostExport command output, and added a delete confirmation for Remove-FinOpsHub.

[See all changes](https://aka.ms/ftk/changes#powershell-v08){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

<a name="features"></a>

## Explore the commands

<table border="0">
<tr>
    <td>
        <strong>📊 Cost Management</strong><br>
        Manage Cost Management exports using the latest features. (Not available in Az PowerShell.)
        [See commands](https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/cost/cost-management-commands){: .btn .mb-4 .mb-md-0 .mr-4 }
    </td>
    <td>
        <strong>🏦 FinOps hubs</strong><br>
        Deploy and manage FinOps hubs and configured scopes.
        [See commands](https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/hubs/finops-hubs-commands){: .btn .mb-4 .mb-md-0 .mr-4 }
    </td>
    <td>
        <strong>🌐 Open data</strong><br>
        Query FinOps toolkit open data to integrate with your own data.
        [See commands](https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/data/open-data-commands){: .btn .mb-4 .mb-md-0 .mr-4 }
    </td>
    <td>
        <strong>🧰 FinOps toolkit</strong><br>
        Get FinOps toolkit versions or download specific releases.
        [See commands](https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/toolkit/finops-toolkit-commands){: .btn .mb-4 .mb-md-0 .mr-4 }
    </td>
</tr>
</table>

<br>

<a name="deploy"></a>
<a name="download"></a>
<a name="install"></a>

## Install the module

Create a new or update an existing FinOps hub instance.

<table border="0">
<tr>
    <td>
        <strong>1️⃣ Install PowerShell 7+</strong><br>
        FinOps toolkit requires PowerShell 7, which is built into Azure Cloud Shell and supported on all major operating systems.<br>
        [Install PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell){: .btn .mb-4 .mb-md-0 .mr-4 }
        [Launch Azure Cloud Shell](https://portal.azure.com/#cloudshell){: .btn .mb-4 .mb-md-0 .mr-4 }
    </td>
    <td>
        <strong>2️⃣ Install modules and sign in</strong><br>
        ```powershell
        Install-Module -Name Az.Accounts
        Install-Module -Name Az.Resources
        Install-Module -Name FinOpsToolkit
        Connect-AzAccount
        ```
    </td>
    <td>
        <strong>3️⃣ Run your commands</strong><br>
        You're now ready to run FinOps toolkit commands. Browse available commands and examples to build your scripts.
        [Explore commands](https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/commands#commands){: .btn .mb-4 .mb-md-0 .mr-4 }
    </td>
</tr>
</table>

<a name="docs"></a>

[Learn more](https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/commands){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[💜 Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20PowerShell%3F/cvaQuestion/How%20valuable%20are%20FinOps%20toolkit%20PowerShell%3F/surveyId/FTK0.8/bladeName/PowerShell/featureName/Marketing.Docs){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>
