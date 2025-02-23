---
layout: default
title: Bicep Registry
browser: FinOps toolkit bicep - Reusable modules for deployments
nav_order: 7
description: 'Leverage reusable bicep modules in your Azure deployment templates to accelerate your FinOps efforts.'
permalink: /bicep
#customer intent: As a Finops practitioner, I need to learn about FinOps hubs
---

<span class="fs-9 d-block mb-4">FinOps toolkit PowerShell</span>
Accelerate your FinOps efforts with reusable bicep modules for your Azure deployment templates.
{: .fs-6 .fw-300 }

[Browse](#deploy){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Documentation](https://learn.microsoft.com/cloud-computing/finops/toolkit/bicep-registry/modules){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

---

<a name="overview"></a>

## Reusable bicep modules

The FinOps toolkit PowerShell module helps you automate and scale common Cost Management and FinOps toolkit management operations and work with FinOps toolkit open data.

<br>

<!--
<a name="whats-new"></a>

## What's new in February 2025 (v0.8)

TODO

[See all changes](https://aka.ms/ftk/changes#bicep-registry-modules-v08){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>
-->

<a name="features"></a>

## Explore the commands

<div id="tile-gallery">
    <div class="tile" markdown="1">
        <div>📨 Cost Management scheduled actions</div>
        <div>Create anomaly alerts for subscriptions or scheduled alerts for resource groups or subscriptions.</div>
        [Learn more](https://learn.microsoft.com/cloud-computing/finops/toolkit/bicep-registry/scheduled-actions){: .btn .mb-4 .mb-md-0 .mr-4 }
    </div>
</table>

<br>

<a name="deploy"></a>
<a name="download"></a>
<a name="install"></a>
<a name="docs"></a>

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

[Learn more](https://learn.microsoft.com/cloud-computing/finops/toolkit/bicep-registry/modules){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[💜 Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20bicep%20modules%3F/cvaQuestion/How%20valuable%20are%20FinOps%20toolkit%20bicep%20modules%3F/surveyId/FTK0.8/bladeName/Bicep/featureName/Marketing.Docs){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>
