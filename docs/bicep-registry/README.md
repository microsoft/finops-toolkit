---
layout: default
title: Bicep Registry
nav_order: 4
description: 'Include bicep modules in your templates.'
permalink: /bicep
---

<span class="fs-9 d-block mb-4">Bicep Registry modules</span>
Leverage reusable bicep modules in your templates to accelerate your FinOps efforts.
{: .fs-6 .fw-300 }

[See the modules](https://azure.github.io/bicep-registry-modules/#cost){: .btn .btn-primary .fs-5 .mt-4 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="block">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Scheduled actions](#scheduled-actions)
- [Tag inheritance](#tag-inheritance)

</details>

---

Bicep modules developed within the toolkit are published to the [official Bicep Registry](https://azure.github.io/bicep-registry-modules). These modules are not included directly in the toolkit release.

<br>

## Scheduled actions

Version: **1.0.1**
{: .label .label-green .fs-2 .mr-4 }
Scopes: **Resource group, Subscription**
{: .label .fs-2 .mr-4 }

![Version 1.0.1](https://img.shields.io/badge/version-1.0.1-darkgreen)
&nbsp;
![Scopes: Resource group, Subscription](https://img.shields.io/badge/scopes-resourceGroup,_subscription-blue)

Creates a [scheduled action](https://learn.microsoft.com/rest/api/cost-management/scheduled-actions) to notify recipients about the latest costs or when an anomaly is detected.

- [About scheduled actions for resource groups](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/resourcegroup-scheduled-action/README.md)
- [About scheduled actions for subscriptions](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/subscription-scheduled-action/README.md)

<br>

## Tag inheritance

Version: **Unreleased**
{: .label .label-green .fs-2 .mr-4 }
Scopes: **Subscription**
{: .label .fs-2 .mr-4 }
<sup>→</sup>
{: .mr-4 }
[Issue: #184](https://github.com/finops-toolkit/issues/184)
{: .label .label-yellow .fs-2 .mr-4 }

![Unreleased](https://img.shields.io/badge/version-unreleased-inactive)
&nbsp;
![Scopes: Subscription](https://img.shields.io/badge/scopes-subscription-blue)
&nbsp;<sup>→</sup>&nbsp;
[![Issue details](https://img.shields.io/github/issues/detail/title/microsoft/finops-toolkit/184)](https://github.com/finops-toolkit/issues/184)

<!--
[![Go to PR](https://img.shields.io/github/pulls/detail/state/Azure/bicep-registry-modules/300?label=resourceGroup%20PR)](https://github.com/bicep-registry-modules/pulls/300)
-->

Enables tag inheritance within Cost Management. This module is pending review and inclusion in the next Bicep Registry release.

<br>
