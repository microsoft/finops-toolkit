---
title: Deployment options
description: Learn how to use various options to deploy FinOps toolkit solutions, including ARM templates, Bicep modules, and quickstart templates.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what options I have to deploy FinOps toolkit tools.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps toolkit deployment options

The FinOps toolkit includes multiple ARM templates. Prerequisites, parameters, and post-deployment setup steps differ per template. For more information, see the following template details:

- [FinOps hub](../hubs/template.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)

Bicep Registry modules can be referenced directly from your Bicep code and aren't deployed using the following steps.

<br>

## Where to find FinOps toolkit templates

- Deploy from this site (with the following links).
- Deploy from [Microsoft Learn code samples](/samples/browse/?terms=finops).
- Deploy from [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.costmanagement).
- Download from [FinOps toolkit releases](https://github.com/microsoft/finops-toolkit/releases).
- Include in your bicep modules from the [Bicep Registry](https://azure.github.io/bicep-registry-modules/#cost).

<br>

## Deploy a FinOps toolkit template

To deploy a FinOps toolkit template, use the following steps:

1. Select **Deploy to Azure** for the desired template using the following table.
2. Specify the desired values for each parameter. For more information, see the template details.
   > [!NOTE]
   > Use the **Edit parameters** link to use a saved parameters file or to download a new parameters file for future use.
3. Select **Review + create**.
4. Select **Create**.

| Template                                                      | Azure Commercial                                                                                                                                                                                                                                                                                                                                                                                                                                               | Azure Gov                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Azure China                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [FinOps hub](../hubs/finops-hubs-overview.md)                 | <a href="https://aka.ms/finops/hubs/deploy"><img alt="Deploy to Azure" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true" /></a>                                                                                                                                                                                                                                      | <a href="https://aka.ms/finops/hubs/deploy/gov"><img alt="Deploy to Azure Gov" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true" /></a>                                                                                                                                                                                                                                 | <a href="https://aka.ms/finops/hubs/deploy/china"><img alt="Deploy to Azure China" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazurechina.svg?sanitize=true" /></a>                                                                                                                                                                                                                               |
| [FinOps workbooks](../workbooks/finops-workbooks-overview.md) | <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy to Azure" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true" /></a> | <a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy to Azure Gov" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true" /></a> | <a href="https://portal.azure.cn/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-workbooks-latest.ui.json"><img alt="Deploy to Azure China" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazurechina.svg?sanitize=true" /></a> |
| [FinOps alerts](../alerts/finops-alerts-overview.md)          | <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.ui.json"><img alt="Deploy to Azure" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true" /></a>       | <a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.ui.json"><img alt="Deploy to Azure Gov" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true" /></a>       | <a href="https://portal.azure.cn/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.ui.json"><img alt="Deploy to Azure China" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazurechina.svg?sanitize=true" /></a>       |

:::image type="content" source="./media/help/deploy-create-form.png" border="true" alt-text="Screenshot of the FinOps hub create form." lightbox="./media/help/deploy-create-form.png" :::

<br>

## Use the custom deployment option in the Azure portal

:::image type="content" source="./media/help/deploy-custom-deployment.png" border="true" alt-text="Screenshot of the custom deployment form." lightbox="./media/help/deploy-custom-deployment.png" :::

The Azure portal includes a **Custom deployment** option that supports all templates available in the Azure Quickstart Templates repository. To deploy a quickstart template:

1. Open [Custom deployment](https://portal.azure.com/#create/Microsoft.Template)
2. In the **Quickstart template** dropdown, select `quickstarts/microsoft.costmanagement/<template>`.
3. Select the **Select template** button.
4. <a name="edit-params"></a>Are you updating an existing deployment?
   1. If so, use a parameters file:
      1. Select the **Edit parameters** link at the top of the form.
      2. Select the **Load file** command at the top of the page to upload your existing parameters file or copy and paste the file contents directly.
      3. Select the **Save** button at the bottom of the page.
   2. If it's a new deployment, specify the desired values for each parameter. For more information, see the template details.
5. Select the **Edit parameters** link at the top of the form.
6. Select the **Download** command at the top of the page to save your parameters file. Keep it for your next deployment.
7. Select the **Save** button at the bottom of the page.
8. Select the **Review + create** button.
9. Select the **Create** button.

If you received any validation errors, fix them and attempt to create the resources again.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.12/bladeName/Toolkit/featureName/Help.Deploy)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%2B1-desc)

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
