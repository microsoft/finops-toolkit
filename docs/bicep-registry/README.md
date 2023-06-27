# 🦾 Bicep Registry modules

[![Go to issue](https://img.shields.io/github/issues/detail/title/microsoft/cloud-hubs/104?label=roadmap)](https://github.com/microsoft/cloud-hubs/issues/104)

Bicep modules developed within the toolkit are published to the [official Bicep Registry](https://azure.github.io/bicep-registry-modules). These modules are not included directly in the toolkit release.

Bicep modules:

- [Scheduled actions](#scheduled-actions)
- [Tag inheritance](#tag-inheritance)

---

## Scheduled actions

![Version 1.0.1](https://img.shields.io/badge/version-1.0.1-darkgreen)
&nbsp;
![Scopes: Resource group, Subscription](https://img.shields.io/badge/scopes-resourceGroup,_subscription-blue)

Creates a [scheduled action](https://learn.microsoft.com/rest/api/cost-management/scheduled-actions) to notify recipients about the latest costs or when an anomaly is detected.

- [About scheduled actions for resource groups](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/resourcegroup-scheduled-action/README.md)
- [About scheduled actions for subscriptions](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/subscription-scheduled-action/README.md)

<br>

## Tag inheritance

![Unreleased](https://img.shields.io/badge/version-unreleased-inactive)
&nbsp;
![Scopes: Resource group, Subscription](https://img.shields.io/badge/scopes-subscription-blue)
&nbsp;<sup>→</sup>&nbsp;
[![Issue details](https://img.shields.io/github/issues/detail/title/microsoft/finops-toolkit/184)](https://github.com/finops-toolkit/issues/184)

<!--
[![Go to PR](https://img.shields.io/github/pulls/detail/state/Azure/bicep-registry-modules/300?label=resourceGroup%20PR)](https://github.com/bicep-registry-modules/pulls/300)
-->

Enables tag inheritance within Cost Management. This module is pending review and inclusion in the next Bicep Registry release.

<br>
