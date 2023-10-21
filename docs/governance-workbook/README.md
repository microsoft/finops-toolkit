---
layout: default
title: Governance workbook
nav_order: 31
description: 'Azure Monitor workbook focused on governance.'
permalink: /governance-workbook
---

<span class="fs-9 d-block mb-4">Governance workbook</span>
Monitor the governance posture of your Azure environment. Leverage recommendations to address compliance issues.
{: .fs-6 .fw-300 }

[Deploy](./README.md#-create-a-new-hub){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Learn more](./details.md){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

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

2. [Deploy the **governance-workbook** template](../resources/deploy.md).

   [![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.costmanagement%2Fgovernance-workbook%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.costmanagement%2Fgovernance-workbook%2FcreateUiDefinition.json) &nbsp; [![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.costmanagement%2Fgovernance-workbook%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.costmanagement%2Fgovernance-workbook%2FcreateUiDefinition.json)

<br>

{% include tools.md root="../" finops-hub=1 optimization-workbook="1" %}
