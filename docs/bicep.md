---
layout: default
title: Bicep Registry
browser: FinOps toolkit bicep - Reusable modules for deployments
nav_order: 55
description: 'Leverage reusable bicep modules in your Azure deployment templates to accelerate your FinOps efforts.'
permalink: /bicep
#customer intent: As a Finops practitioner, I need to learn about FinOps hubs
---

<span class="fs-9 d-block mb-4">FinOps toolkit bicep modules</span>
Accelerate your FinOps efforts with reusable bicep modules for your Azure deployment templates.
{: .fs-6 .fw-300 }

<a class="btn btn-primary fs-5 mb-4 mb-md-0 mr-4" href="#deploy">Browse</a>
<a class="btn fs-5 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/bicep-registry/modules">Documentation</a>

---

The FinOps toolkit bicep modules help you deploy resources to manage, monitor, and optimize cost and usage.

<!--
<div id="whats-new" class="ftk-new">
    <h3>What's new in February 2025<span class="ftk-version">v0.8</span></h3>
    <p>
        February introduced...
    </p>
    <p><a target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/changelog">See all changes</a></p>
</div>
-->

<a name="features"></a>
<a name="docs"></a>

## Explore the commands

<div class="ftk-gallery">
    <div class="ftk-tile">
        <div>📨 Scheduled actions</div>
        <div>Create Cost Management anomaly alerts and scheduled alerts.</div>
        <a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/bicep-registry/scheduled-actions">Learn more</a>
    </div>
</div>
<a name="deploy"></a>
<a name="download"></a>
<a name="install"></a>

## Referencing bicep modules

Referencing a module in your bicep template is as simple as adding the following in your bicep file:

```bicep
module <name> 'br/public:cost/<scope>-<type>:<version>' {
   name: '<name>'
   params: {
      parameterName: '<parameter-value>'
   }
}
```

For details about the parameters for each module, refer to the documentation.

<a class="btn mt-2 mb-4 mb-md-0 mr-4" target="_blank" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/bicep-registry/modules">About the modules</a>
<a class="btn mb-4 mb-md-0 mr-4" target="_blank" href="https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20bicep%20modules%3F/cvaQuestion/How%20valuable%20are%20FinOps%20toolkit%20bicep%20modules%3F/surveyId/FTK{% include ftkver.txt %}/bladeName/Bicep/featureName/Marketing.Docs">💜 Give feedback</a>

<br>
