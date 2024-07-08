---
layout: default
title: Governance workbook
has_children: true
nav_order: 2
description: 'Azure Monitor workbook focused on governance.'
permalink: /governance-workbook
---

<span class="fs-9 d-block mb-4">Governance workbook</span>
Monitor the governance posture of your Azure environment. Leverage recommendations to address compliance issues.
{: .fs-6 .fw-300 }

[Deploy](#-deploy-the-workbook){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
<!--
[Learn more](./details.md){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
-->

---

The governance workbook is an Azure Monitor workbook that provides a comprehensive overview of the governance posture of your Azure environment. It includes the standard metrics aligned with the Cloud Adoption Framework for all disciplines and has the capability to identify and apply recommendations to address non-compliant resources.

![Screenshot of the Governance workbook](https://github.com/microsoft/finops-toolkit/assets/399533/1710cf38-b0ef-4cdf-a30f-dde03dc7f1bf).

<br>

## ➕ Deploy the workbook

1. Confirm you have the following least-privileged roles to deploy and use the workbook:

   - **Workbook Contributor** allows you to deploy and make changes to the workbook.
   - **Cost Management Reader** allows you to view the costs in the Cost Management tab only.
   - **Reader** allows you to view all tabs.

   <blockquote class="tip" markdown="1">
     _If you only have read access, you can still import your workbook directly into Azure Monitor. You will not be able to save it, but you can view all tabs._
   </blockquote>

2. Deploy the **governance-workbook** template. [Learn more](../../_resources/deploy.md).

   {% include deploy.html template="governance-workbook" public="1" gov="1" china="0" %}

<br>

---

## 🧰 Related tools

{% include tools.md opt="1" aoe="1" %}

<br>
