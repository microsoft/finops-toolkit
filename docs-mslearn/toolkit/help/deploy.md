---
title: Deployment options
description: 'Deploy FinOps toolkit solutions.'
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what options I have to deploy FinOps toolkit tools.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps toolkit deployment options

The FinOps toolkit includes multiple ARM templates. Prerequisites, parameters, and post-deployment setup steps differ per template. Please refer to the template details for more information:

- [FinOps hub](../hubs/template.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)

Note Bicep Registry modules can be referenced directly from your Bicep code and are not deployed using the steps below.

<br>

## Where to find FinOps toolkit templates

- Deploy from this site (links below).
- Deploy from [Microsoft Learn code samples](/samples/browse/?terms=finops).
- Deploy from [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.costmanagement).
- Download from [FinOps toolkit releases](https://github.com/microsoft/finops-toolkit/releases).
- Include in your bicep modules from the [Bicep Registry](https://azure.github.io/bicep-registry-modules/#cost).

<br>

## Deploy a FinOps toolkit template

1. Select the **Deploy to Azure** button for the desired template:

   <table>
     <tr><th>Template</th><th>Azure Commercial</th><th>Azure Gov</th><th>Azure China</th></tr>
     <tr>
      <td>
        [FinOps hub](../hubs/finops-hubs-overview.md)
      </td>
      <td>
        <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-latest.ui.json"><img alt="Deploy To Azure" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true" /></a>
      </td>
      <td>
        <a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-0.1.1.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-0.1.1.ui.json"><img alt="Deploy To Azure Gov" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true" /></a>
      </td>
      <td>
        <a href="https://portal.azure.cn/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-0.1.1.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-0.1.1.ui.json"><img alt="Deploy To Azure China" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazurechina.svg?sanitize=true" /></a>
      </td>
     </tr>
     <tr>
      <td>
        [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
      </td>
      <td>
        <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy To Azure" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true" /></a>
      </td>
      <td>
        <a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy To Azure Gov" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true" /></a>
      </td>
      <td>
        <!--
        <a href="https://portal.azure.cn/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy To Azure China" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazurechina.svg?sanitize=true" /></a>
        -->
      </td>
     </tr>
   </table>

2. Specify the desired values for each parameter. See the template details for more information.
   > [!NOTE]
   > Use the **Edit parameters** link to use a saved parameters file or to download a new parameters file for future use.
3. Select the **Review + create** button.
4. Select the **Create** button.

:::image type="content" source="../../media/help/deploy-create-form.png" border="true" alt-text="Screenshot of the FinOps hub create form" lightbox="../../media/help/deploy-create-form.png" :::

<br>

## Using custom deployment in the Azure portal

:::image type="content" source="../../media/help/deploy-custom-deployment.png" border="true" alt-text="Screenshot of the custom deployment form." lightbox="../../media/help/deploy-custom-deployment.png" :::

The Azure portal includes a **Custom deployment** option that supports all templates available in the Azure Quickstart Templates repository. To deploy a quickstart template:

1. Open [Custom deployment](https://portal.azure.com/#create/Microsoft.Template)
2. In the **Quickstart template** dropdown, select `quickstarts/microsoft.costmanagement/<template>`.
3. Select the **Select template** button.
4. <a name="edit-params"></a>Are you updating an existing deployment?
   1. If so, use a parameters file:
      1. Select the **Edit parameters** link at the top of the form.
      2. Select the **Load file** command at the top of the page to upload your existing parameters file or copy and paste the file contents directly.
      3. Select the **Save** button at the bottom of the page.
   2. If this is a new deployment, specify the desired values for each parameter. See the template details for more information.
5. Select the **Edit parameters** link at the top of the form.
6. Select the **Download** command at the top of the page to save your parameters file. Keep this for your next deployment.
7. Select the **Save** button at the bottom of the page.
8. Select the **Review + create** button.
9. Select the **Create** button.

If you received any validation errors, fix those and attempt to create the resources again.

<br>
