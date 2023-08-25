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

[See the modules](https://azure.github.io/bicep-registry-modules/#cost){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Scheduled actions](#scheduled-actions)
- [Exports](#exports)

</details>

---

Bicep modules developed within the toolkit are published to the [official Bicep Registry](https://azure.github.io/bicep-registry-modules). These modules are not included directly in the toolkit release.

<br>

## Scheduled actions

<small>Version: **1.0.1**</small>
{: .label .label-green .pt-0 .pl-3 .pr-3 .m-0 }
<small>Scopes: **Resource group, Subscription**</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

Creates a [scheduled action](https://learn.microsoft.com/rest/api/cost-management/scheduled-actions) to notify recipients about the latest costs or when an anomaly is detected.

- [About scheduled actions for resource groups](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/resourcegroup-scheduled-action/README.md)
- [About scheduled actions for subscriptions](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/subscription-scheduled-action/README.md)

<br>

## Exports

<small>Version: **Unreleased**</small>
{: .label .label-yellow .pt-0 .pl-3 .pr-3 .m-0 }
<small>Scopes: **Resource group, Subscription**</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>[Issue: **#221**](https://github.com/microsoft/finops-toolkit/issues/221)</small>
{: .label .label-yellow .pt-0 .pl-3 .pr-3 .m-0 }

Creates an [export](https://learn.microsoft.com/rest/api/cost-management/exports) to push cost data to a storage account on a daily or monthly schedule.

<br>
