---
layout: default
title: Open data
nav_order: 5
description: 'Leverage open data to normalize and enhance your FinOps reporting.'
permalink: /hubs
---

<span class="fs-9 d-block mb-4">Mappings</span>
Leverage open data to normalize and enhance your FinOps reporting.
{: .fs-6 .fw-300 }

[Download](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Share feedback](#-looking-for-more){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [📏 Pricing units](#-pricing-units)
- [🗺️ Regions](#️-regions)
- [📇 Looking for more?](#-looking-for-more)

</details>

---

Reporting is the life-blood of any FinOps initiative. And your reports are only as good as your data. This is why [data ingestion and normalization](https://learn.microsoft.com/azure/cost-management-billing/finops/capabilities-ingestion-normalization) is such an important part of FinOps (and any big data effort). The following datasets can be used to clean and normalize your data as part of data ingestion, reporting, or other solutions.

<br>

## 📏 Pricing units

Microsoft Cost Management uses the `UnitOfMeasure` column to indicate how each charge is measured. This can be in singular or distinct units or can be grouped into chunks based on applicable block pricing rules. As a string, the `UnitOfMeasure` column can be challenging to parse and handle all the different permutations and inconsistencies. The Pricing units file provides a list of values you may find within common cost-related datasets (e.g., Cost Management exports and price sheets) along with their related distinct unit and scaling factor to compare pricing to usage units.

Sample data:

| UnitOfMeasure      | MeterCount | UsageToPricingRate | DistinctUnits |
| ------------------ | ---------- | ------------------ | ------------- |
| `1 Hour`           | 116073     | 1                  | Hours         |
| `10000 GB`         | 342        | 10000              | GB            |
| `150 Hours`        | 4          | 150                | Hours         |
| `200 /Hour`        | 4          | 200                | Units/Hour    |
| `5 GB`             | 16         | 5                  | GB            |
| `5000000 Requests` | 1          | 5000000            | Requests      |
| `744 Connections`  | 26         | 744                | Connections   |

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/PricingUnits.csv){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🗺️ Regions

Microsoft Cost Management provides various values for resource locations that are occasionally inconsistent due to different underlying systems providing the data. The Regions file provides a list of values you may find within common cost-related datasets (e.g., Cost Management exports and price sheets) along with their related Azure region IDs and names.

Sample data:

| OriginalValue | RegionId      | RegionName     |
| ------------- | ------------- | -------------- |
| AP East       | eastasia      | East Asia      |
| CA Central    | canadacentral | Canada Central |
| DE North      | germanynorth  | Germany North  |
| NO West       | norwaywest    | Norway West    |
| TW North      | taiwannorth   | Taiwan North   |

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/Regions.csv){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<br>

## 📇 Looking for more?

We'd love to hear about any datasets you're looking for. Create a new issue with the details that you'd like to see either included in existing or new datasets.

[Share feedback](https://github.com/microsoft/finops-toolkit/issues/new/choose){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
