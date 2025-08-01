---
layout: default
title: PowerShell
browser: FinOps toolkit PowerShell - Automate your FinOps efforts
nav_order: 50
description: 'FinOps toolkit PowerShell helps you automate and scale common Cost Management and FinOps toolkit management operations and work with FinOps toolkit open data.'
permalink: /powershell
#customer intent: As a Finops practitioner, I need to learn about FinOps toolkit PowerShell
---

<span class="fs-9 d-block mb-4">FinOps toolkit PowerShell</span>
Automate and scale your FinOps efforts with PowerShell commands that streamline operations and accelerate adoption across projects and teams.
{: .fs-6 .fw-300 }

<a class="btn btn-primary fs-5 mb-4 mb-md-0 mr-4" href="#deploy">Install</a>
<a class="btn fs-5 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/powershell-commands">Documentation</a>

---

The FinOps toolkit PowerShell module helps you automate and scale common Cost Management and FinOps toolkit management operations and work with FinOps toolkit open data.

<!--
<div id="whats-new" class="ftk-new">
    <h3>What's new in April 2025<span class="ftk-version">v0.10</span></h3>
    <p>
        In April, the FinOps toolkit PowerShell module updated documentation to cover Add-FinOpsServicePrincipal and add examples of Start-FinOpsCostExport with the -Scope parameter.
    </p>
    <p><a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/changelog">See all changes</a></p>
</div>
-->

<a name="features"></a>

## Explore the commands

<div class="ftk-gallery ftk-50">
    <div class="ftk-tile">
        <div>📊 Cost Management</div>
        <div>Manage Cost Management exports using the latest features.</div>
        <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/cost/cost-management-commands">See commands</a>
    </div>
    <div class="ftk-tile">
        <div>🏦 FinOps hubs</div>
        <div>Deploy and manage FinOps hubs and configured scopes.</div>
        <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/hubs/finops-hubs-commands">See commands</a>
    </div>
    <div class="ftk-tile">
        <div>🌐 Open data</div>
        <div>Query FinOps toolkit open data to integrate with your own data.</div>
        <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/data/open-data-commands">See commands</a>
    </div>
    <div class="ftk-tile">
        <div>🧰 FinOps toolkit</div>
        <div>Get FinOps toolkit versions or download specific releases.</div>
        <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/toolkit/finops-toolkit-commands">See commands</a>
    </div>
</div>
<a name="deploy"></a>
<a name="download"></a>
<a name="install"></a>

## Install the module

<div class="ftk-instructions">
    <div class="ftk-step">
        <button class="ftk-accordion">1️⃣&nbsp; Install PowerShell 7+</button>
        <div>FinOps toolkit requires PowerShell 7, which is built into Azure Cloud Shell and supported on all major operating systems.</div>
        <div>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/powershell/scripting/install/installing-powershell">Install PowerShell</a>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#cloudshell">Launch Azure Cloud Shell</a>
            </p>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">2️⃣&nbsp; Install modules and sign in</button>
        <div class="language-powershell highlighter-rouge">
            <div class="highlight">
                <pre class="highlight"><code><span class="n">Install-Module</span><span class="w"> </span><span class="nt">-Name</span><span class="w"> </span><span class="nx">Az.Accounts</span><span class="w">
</span><span class="n">Install-Module</span><span class="w"> </span><span class="nt">-Name</span><span class="w"> </span><span class="nx">Az.Resources</span><span class="w">
</span><span class="n">Install-Module</span><span class="w"> </span><span class="nt">-Name</span><span class="w"> </span><span class="nx">FinOpsToolkit</span><span class="w">
</span><span class="n">Connect-AzAccount</span><span class="w">
</span></code></pre>
            </div>
            <button type="button" aria-label="Copy code to clipboard"><svg viewBox="0 0 24 24" class="copy-icon"><use xlink:href="#svg-copy"></use></svg></button>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">3️⃣&nbsp; Run your commands</button>
        <div>You're now ready to run FinOps toolkit commands. Browse available commands and examples to build your scripts.</div>
        <div>
            <p>
                <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/powershell-commands#commands">Explore commands</a>
            </p>
        </div>
    </div>
</div>
<a name="docs"></a>

<a class="btn mt-2 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/powershell-commands">About the commands</a>
<a class="btn mt-2 mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20PowerShell%3F/cvaQuestion/How%20valuable%20are%20FinOps%20toolkit%20PowerShell%3F/surveyId/FTK{% include ftkver.txt %}/bladeName/PowerShell/featureName/Marketing.Docs">💜 Give feedback</a>

<br>
