---
layout: default
parent: {category} <!-- Service category display name from FOCUS -->
title: {service} <!-- Service display name from ACOM -->
nav_order: 0
description: '{one-line-description-from-acom}'
permalink: /services/{kebab-category}/{kebab-service}
---

<span class="fs-9 d-block mb-4">{service}</span>
{one-line-description-from-acom}
{: .fs-6 .fw-300 }

<!--
These CTA buttons are TBD. We could jump down to content or do something else.
[Primary CTA](#){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Secondary CTA](#){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
-->

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Understand cloud usage and cost](#understand-cloud-usage-and-cost)
- [Optimize cloud usage and cost](#optimize-cloud-usage-and-cost)
- [Quantify business value](#quantify-business-value)
- [Manage the FinOps practice](#manage-the-finops-practice)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---

<!-- Consider copying the intro paragraph(s) from the "What is" doc -->
{long-description-if-needed}

<!-- Add links to ACOM, pricing, and docs -->
[About](https://azure.microsoft.com/products/{kebab-service}){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Pricing](https://azure.microsoft.com/pricing/details/{kebab-service}){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Documentation](https://learn.microsoft.com/azure/{kebab-service}){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<br>

<!-- Add content under each H3 capability and comment out any that aren't used -->

## Understand cloud usage and cost

### Data ingestion

### Allocation

### Reporting + analytics

### Anomalies

<br>

## Optimize cloud usage and cost

### Unit economics

### Estimation + forecasting

### Budgeting

### Benchmarking

<br>

## Quantify business value

### Architecting for cloud

### Utilization efficiency

### Workload management

### Licensing + SaaS

### Commitment discounts

### Cloud sustainability

<br>

## Manage the FinOps practice

### FinOps practice operations

### FinOps education + enablement

### FinOps assessment

### Cloud policy + governance

### FinOps tools + services

### Chargeback + invoicing

### Intersecting disciplines

<br>

## 🙋‍♀️ Looking for more?

Did we miss anything? Would you like to see something added? We'd love to hear about any questions, problems, or solutions you'd like to see covered here. Create a new issue with the details that you'd like to see either included here.

[Share feedback](https://github.com/microsoft/finops-toolkit/issues/new/choose){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

<!-- Change any 0s to a "1" if the tool offers some specific support for this service or comment out the entire section including the "---" if none apply -->
{% include tools.md hubs="0" pbi="0" opt="0" gov="0" ps="0" bicep="0" data="0" %}

<br>
