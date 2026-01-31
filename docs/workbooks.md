---
layout: default
title: FinOps workbooks
browser: FinOps workbooks - Engineering hub to maximize cloud ROI
nav_order: 30
description: ''
permalink: /workbooks
#customer intent: As a Finops practitioner, I need to learn about FinOps workbooks
---

<span class="fs-9 d-block mb-4">FinOps workbooks</span>
Engineering hub to maximize cloud ROI through FinOps.
{: .fs-6 .fw-300 }

<a class="btn btn-primary fs-5 mb-4 mb-md-0 mr-4" href="#deploy">Deploy</a>
<a class="btn fs-5 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/workbooks/finops-workbooks-overview">Documentation</a>

---

FinOps workbooks are Azure workbooks that provide a series of tools to help engineers perform targeted FinOps tasks, modeled after the Well-Architected Framework guidance.

<div id="whats-new" class="ftk-new">
    <h3>What's new in January 2026<span class="ftk-version">v13</span></h3>
    <p>
        In January, the optimization workbook fixed SQL Managed Instance vCores displaying incorrect values.
    </p>
    <p><a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/changelog">See all changes</a></p>
</div>

<a name="features"></a>

## A central hub for efficiency and control

<div class="ftk-gallery">
    <div class="ftk-tile">
        <div>🦉 Holistic view</div>
        <div>Review Azure Advisor cost, security, and reliability recommendations from a central engineering hub.</div>
    </div>
    <div class="ftk-tile">
        <div>💤 Identify idle resources</div>
        <div>Identify idle and unused resources to reduce waste.<br>&nbsp;</div>
    </div>
    <div class="ftk-tile">
        <div>📈 Maximize commitments</div>
        <div>Monitor reservation and savings plan usage across subscriptions.<br>&nbsp;</div>
    </div>
    <div class="ftk-tile">
        <div>☁️ Expand Hybrid Benefit</div>
        <div>Identify opportunities to use Azure Hybrid Benefit for Windows, Linux, and SQL Server.</div>
    </div>
    <div class="ftk-tile">
        <div>🧮 Review resource inventory</div>
        <div>Summarize and review resource inventory across multiple areas.<br>&nbsp;</div>
    </div>
    <div class="ftk-tile">
        <div>🪦 Review retired services</div>
        <div>Review retired services and impacted resources.<br>&nbsp;</div>
    </div>
    <div class="ftk-tile">
        <div>⚖️ Monitor policy compliance</div>
        <div>Review Azure Policy assignments and compliance status per subscription.</div>
    </div>
</div>
<a name="deploy"></a>

## Deploy FinOps workbooks

FinOps workbooks require the <strong>Contributor</strong> role or a role with both <strong>Microsoft.Resources/deployments/validate/action</strong> and <strong>Microsoft.Resources/deployments/write</strong> permissions for ARM template deployments, <strong>Workbook Contributor</strong> role to save changes, and <strong>Reader</strong> on all subscriptions you want to monitor.

> If you only have Reader access, you can download the workbook JSON files from the finops-workbooks.zip package available in the [latest release](https://aka.ms/ftk/latest), and then import them directly into Azure Monitor Workbooks.

<br>
<a class="btn btn-primary mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json">Deploy to Azure</a>
<a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json">Deploy to Azure Gov</a>

<div id="pricing" class="ftk-pricing">
    <h3>Estimated cost for FinOps workbooks</h3>
    <p>
        FinOps workbooks do not incur any cost.
    </p>
</div>
<a name="docs"></a>

## Learn more from documentation

<div class="ftk-gallery">
    <div class="ftk-tile">
        <div>💹 <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/workbooks/optimization">Cost optimization</a></div>
        <div>Monitor resource utilization and maximize cost efficiency across your Azure environment.</div>
    </div>
    <div class="ftk-tile">
        <div>⚖️ <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/workbooks/governance">Governance</a></div>
        <div>Monitor resources, service alerts, and policy compliance across your Azure environment.</div>
    </div>
    <div class="ftk-tile">
        <div>⚙️ <a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/workbooks/customize-workbooks">How to customize</a></div>
        <div>Learn how to install and edit FinOps workbooks to tune them to meet your unique needs.</div>
    </div>
</div>

<a class="btn mt-2 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/workbooks/finops-workbooks-overview">About the workbooks</a>
<a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20workbooks%3F/cvaQuestion/How%20valuable%20are%20FinOps%20workbooks%3F/surveyId/FTK{% include ftkver.txt %}/bladeName/Workbooks/featureName/Marketing.Docs">💜 Give feedback</a>

<br>
