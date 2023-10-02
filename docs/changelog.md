---
layout: default
title: Changelog
nav_order: zzz
description: 'Latest and greatest features and enhancements from the FinOps toolkit.'
permalink: /changelog
---

<span class="fs-9 d-block mb-4">FinOps toolkit changelog</span>
Explore the latest and greatest features and enhancements from the FinOps toolkit.
{: .fs-6 .fw-300 }

[Download the latest release](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🔄️ Unreleased](#️-unreleased)
- [🚀 v0.0.1](#-v001)

</details>

---

## 🔄️ Unreleased

Added:

1. PowerShell
   1. [Get-FinOpsToolkitVersion](./powershell/toolkit/Get-FinOpsToolkitVersion) to get toolkit versions.
   2. [Deploy-FinOpsHub](./powershell/hubs/Deploy-FinOpsHub) to deploy or update a hub instance.
   3. [Get-FinOpsHub](./powershell/hubs/Get-FinOpsHub) to get details about a hub instance.
2. Open data
   1. [PricingUnits](./open-data/README.md#-pricing-units) to map all pricing units (UnitOfMeasure values) to distinct units with a scaling factor.
   2. [Regions](./open-data/README.md#-regions) to map historical resource location values in Microsoft Cost Management to standard Azure regions.
   3. [Services](./open-data/README.md#-services) to map all resource types to FOCUS service names and categories.

<br>

## 🚀 v0.0.1

Added:

1. FinOps hubs
   1. [FinOps hub template](./finops-hub/README.md) to deploy a storage account and Data Factory instance.
   2. [Cost summary report](./finops-hub/reports/cost-summary.md) for various out-of-the-box cost breakdowns.
   3. [Commitment discounts report](./finops-hub/reports/commitment-discounts.md) for commitment-based discount reports.
2. Bicep modules
   1. [Scheduled action modules](./bicep-registry/README.md#scheduled-actions) submitted to the Bicep Registry.
3. Azure Monitor workbooks
   1. [Cost optimization workbook](./optimization-workbook/README.md) to centralize cost optimization.

[Download v0.0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
