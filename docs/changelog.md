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
- [🌱 v0.0.1](#-v001)

</details>

---

<!--
Legend:
🔄️ Unreleased
🚀🎉 Major
🚚💎 Minor
🛠️✨ Patch
🪛⬆️ Update
🌱 Pre-release
-->

## 🔄️ Unreleased

Added:

1. FinOps hubs
   1. Support for actual (billed) cost data.
   2. Backfill historical cost data to streamline first-time setup.
   3. Managed exports to simplify the setup and backfill process.
   4. Normalize Enterprise Agreement and Microsoft Customer Agreement cost data to a consistent schema.
   5. Support for Microsoft Customer Agreement in Power BI reports.
   6. Remote exports to monitor cost across Azure Active Directory tenants.

<br>

## 🌱 v0.0.1

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
