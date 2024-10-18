---
title: FinOps workbooks
description: 'Azure Monitor workbooks that help you implement FinOps capabilities.'
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what FinOps workbooks are and how they can help me accomplish my goals.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps workbooks

FinOps workbooks are Azure Monitor workbooks that provide a series of tools to help engineers perform targeted FinOps capabilities, modeled after the Well-Architected Framework guidance.

This template includes the following workbooks:

- [Optimization](optimization.md)
- [Governance](governance.md)

<br>

## Deploy the workbooks

1. Confirm you have the following least-privileged roles to deploy and use the workbook:

   - **Workbook Contributor** allows you to deploy the workbook.
   - **Reader** view all of the workbook tabs.

   > [!NOTE]
   > If you only have read access, you can still import your workbook directly into Azure Monitor. You will not be able to save it, but you can view all tabs.

2. Deploy the **finops-workbooks** template. [Learn more](../help/deploy.md).

   <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy To Azure" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true" /></a>
   &nbsp;
   <a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy To Azure Gov" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true" /></a>
   <!--
   &nbsp;
   <a href="https://portal.azure.cn/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy To Azure China" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazurechina.svg?sanitize=true" /></a>
   -->

<br>

## Looking for more?

We'd love to hear about any workbooks you need or general questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new workbooks.

[Share feedback](https://aka.ms/ftk/ideas)

<br>

## Related content

Related FinOps capabilities:

- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)
- [Cloud policy and governance](../../framework/manage/governance.md)

Related products:

- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Advisor](/azure/advisor/)

Related solutions:

- [Optimization engine](../optimization-engine/optimization-engine-overview.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
