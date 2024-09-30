---
layout: default
parent: FinOps workbooks
title: Optimization workbook
has_children: true
nav_order: 1
description: 'Azure Monitor workbook focused on cost optimization.'
permalink: /workbooks/optimization
---

<span class="fs-9 d-block mb-4">Cost optimization workbook</span>
Give your engineers a single pane of glass for cost optimization with this handy Azure Monitor workbook.
{: .fs-6 .fw-300 }

[Deploy](#-deploy-the-workbook){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Try now](<https://portal.azure.com/#blade/AppInsightsExtension/UsageNotebookBlade/ComponentId/Azure%20Advisor/ConfigurationId/community-Workbooks%2FAzure%20Advisor%2FCost%20Optimization/Type/workbook/WorkbookTemplateName/Cost%20Optimization%20(Preview)>){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

---

The cost optimization workbook is an Azure Monitor workbook that provides a single pane of glass for cost optimization, modeled after the Well-Architected Framework guidance.

![Screenshot of the Cost optimization workbook overview](https://github.com/microsoft/finops-toolkit/assets/399533/70b71cb4-d42e-40fc-8870-b4262ecc3633)

<br>

## ➕ Deploy the workbook

1. Confirm you have the following least-privileged roles to deploy and use the workbook:

   - **Workbook Contributor** allows you to deploy the workbook.
   - **Reader** view all of the workbook tabs.

   <blockquote class="tip" markdown="1">
     _If you only have read access, you can still import your workbook directly into Azure Monitor. You will not be able to save it, but you can view all tabs._
   </blockquote>

2. Deploy the **optimization-workbook** template. [Learn more](../../../_resources/deploy.md).

   {% include deploy.html template="optimization-workbook" public="1" gov="1" china="0" %}

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" gov="1" aoe="1" %}

<br>
