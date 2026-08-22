---
layout: default
title: FinOps multitool
browser: FinOps multitool - Scan your Azure environment for FinOps insights
nav_order: 52
description: 'The FinOps multitool scans an Azure environment for cost optimization, governance, and FinOps insights from an interactive terminal UI, with agent skills so AI assistants can run the same analysis.'
permalink: /multitool
#customer intent: As a FinOps practitioner, I need to learn about the FinOps multitool
---

<span class="fs-9 d-block mb-4">FinOps multitool</span>
Scan your Azure environment for cost optimization, governance, and FinOps insights from an interactive terminal UI, with agent skills so AI assistants can run the same analysis.
{: .fs-6 .fw-300 }

<a class="btn btn-primary fs-5 mb-4 mb-md-0 mr-4" href="#install">Install</a>
<a class="btn fs-5 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/multitool/finops-multitool-commands">Documentation</a>

---

The FinOps multitool scans an Azure environment for cost optimization, governance, and FinOps insights and grounds its findings in your live resource state. It surfaces cost trends, orphaned resources, idle VMs, tag hygiene, reservation and savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly alerts, and policy compliance—from an interactive terminal UI or as tools an AI agent can call.

<div id="whats-new" class="ftk-new">
    <h3>New in the FinOps toolkit<span class="ftk-version">v15</span></h3>
    <p>
        The FinOps multitool is a new addition to the FinOps toolkit. It delivers 30 read-only scan modules through a cross-platform terminal UI, plus agent skills for AI assistants, with a scalable FinOps hub Kusto data path for large environments.
    </p>
    <p><a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/changelog">See all changes</a></p>
</div>

<a name="features"></a>

## Explore the multitool

<div class="ftk-gallery ftk-50">
    <div class="ftk-tile">
        <div>🖥️ Terminal UI</div>
        <div>Run cost, governance, and optimization scans from an interactive, cross-platform terminal experience.</div>
        <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/multitool/start-finopsmultitool">Learn more</a>
    </div>
    <div class="ftk-tile">
        <div>🤖 Agent skills</div>
        <div>Teach AI agents the FinOps investigations, the queries behind them, and how to read the results.</div>
        <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/multitool/finops-multitool-commands">Learn more</a>
    </div>
    <div class="ftk-tile">
        <div>🏦 FinOps hub data paths</div>
        <div>Query the hub's Azure Data Explorer or Fabric database directly and push aggregation into the engine to scale to large environments.</div>
        <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/multitool/finops-multitool-commands">Learn more</a>
    </div>
    <div class="ftk-tile">
        <div>🛡️ Read-only by design</div>
        <div>Every scan reads your environment and reports what it finds. The multitool never creates, changes, or deletes a resource.</div>
        <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/multitool/finops-multitool-commands">Learn more</a>
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
</span><span class="n">Install-Module</span><span class="w"> </span><span class="nt">-Name</span><span class="w"> </span><span class="nx">Az.ResourceGraph</span><span class="w">
</span><span class="n">Install-Module</span><span class="w"> </span><span class="nt">-Name</span><span class="w"> </span><span class="nx">Az.Storage</span><span class="w">
</span><span class="n">Install-Module</span><span class="w"> </span><span class="nt">-Name</span><span class="w"> </span><span class="nx">FinOpsToolkit</span><span class="w">
</span><span class="n">Connect-AzAccount</span><span class="w">
</span></code></pre>
            </div>
            <button type="button" aria-label="Copy code to clipboard"><svg viewBox="0 0 24 24" class="copy-icon"><use xlink:href="#svg-copy"></use></svg></button>
        </div>
    </div>
    <div class="ftk-step">
        <button class="ftk-accordion">3️⃣&nbsp; Launch the multitool</button>
        <div>You're now ready to scan. Run the command, then choose the subscriptions and modules to scan.</div>
        <div class="language-powershell highlighter-rouge">
            <div class="highlight">
                <pre class="highlight"><code><span class="n">Start-FinOpsMultitool</span><span class="w">
</span></code></pre>
            </div>
            <button type="button" aria-label="Copy code to clipboard"><svg viewBox="0 0 24 24" class="copy-icon"><use xlink:href="#svg-copy"></use></svg></button>
        </div>
    </div>
</div>
<a name="docs"></a>

<a class="btn mt-2 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/powershell/multitool/finops-multitool-commands">About the commands</a>
<a class="btn mt-2 mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20PowerShell%3F/cvaQuestion/How%20valuable%20are%20FinOps%20toolkit%20PowerShell%3F/surveyId/FTK{% include ftkver.txt %}/bladeName/PowerShell/featureName/Marketing.Docs">💜 Give feedback</a>

<br>
