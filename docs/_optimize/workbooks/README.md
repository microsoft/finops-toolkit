---
layout: default
title: FinOps workbooks
nav_order: 1
description: 'Azure Monitor workbooks that help you implement FinOps capabilities.'
permalink: /workbooks
---

<span class="fs-9 d-block mb-4">FinOps workbooks</span>
A customizable home for engineers to maximize cloud ROI through FinOps. Leverage Azure Monitor workbooks to manage and optimize cost, usage, and carbon efficiency for your Azure resources and services.
{: .fs-6 .fw-300 }

[Deploy](#-deploy-the-workbooks){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
<!--
[Try now](<https://portal.azure.com/#blade/AppInsightsExtension/UsageNotebookBlade/ComponentId/Azure%20Advisor/ConfigurationId/community-Workbooks%2FAzure%20Advisor%2FCost%20Optimization/Type/workbook/WorkbookTemplateName/Cost%20Optimization%20(Preview)>){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
-->

---

FinOps workbooks are Azure Monitor workbooks that provide a series of tools to help engineers perform targeted FinOps capabilities, modeled after the Well-Architected Framework guidance.

This template includes the following workbooks:

- [Optimization](./optimization/README.md)
- [Governance](./governance/README.md)

<br>

## ➕ Deploy the workbooks

1. Confirm you have the following least-privileged roles to deploy and use the workbook:

   - **Workbook Contributor** allows you to deploy the workbook.
   - **Reader** view all of the workbook tabs.

   <blockquote class="tip" markdown="1">
     _If you only have read access, you can still import your workbook directly into Azure Monitor. You will not be able to save it, but you can view all tabs._
   </blockquote>

2. Deploy the **finops-workbooks** template. [Learn more](../../_resources/deploy.md).

   {% include deploy.html template="finops-workbooks" public="1" gov="1" china="0" %}

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any workbooks you need or general questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new workbooks.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md aoe="1" bicep="0" gov="0" hubs="1" opt="0" pbi="0" ps="0" %}

<br>
