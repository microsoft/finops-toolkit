---
title: Deploy FinOps workbooks
description: FinOps workbooks are Azure Monitor workbooks that help you implement FinOps capabilities, including optimization and governance, to achieve your FinOps goals.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: arclares
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

1. To deploy and use the workbook, confirm you have the following least-privileged roles:

   - **Workbook Contributor** allows you to deploy the workbook.
   - **Reader** view all of the workbook tabs.

   > [!NOTE]
   > If you only have read access, you can still import your workbook directly into Azure Monitor. You will not be able to save it, but you can view all tabs.

2. Deploy the **finops-workbooks** template.

   <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy To Azure" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true" /></a>
   &nbsp;
   <a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy To Azure Gov" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true" /></a>
   <!--
   &nbsp;
   <a href="https://portal.azure.cn/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy To Azure China" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazurechina.svg?sanitize=true" /></a>
   -->

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20workbooks%3F/cvaQuestion/How%20valuable%20are%20FinOps%20workbooks%3F/surveyId/FTK0.10/bladeName/Workbooks/featureName/Overview)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20Workbooks%22%20sort%3A"reactions-%2B1-desc")

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

- [Optimization engine](../optimization-engine/overview.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
