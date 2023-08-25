---
layout: default
title: Deployment options
nav_order: 5
description: 'Azure Monitor workbook focused on cost optimization.'
permalink: /deploy
---

<span class="fs-9 d-block mb-4">FinOps toolkit deployment options</span>
Learn where to find and how to deploy FinOps toolkit solutions.
{: .fs-6 .fw-300 }

<details open markdown="block">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Where can I get FinOps toolkit templates?](#where-can-i-get-finops-toolkit-templates)
- [Deploy a FinOps toolkit template](#deploy-a-finops-toolkit-template)
- [Using custom deployment in the Azure portal](#using-custom-deployment-in-the-azure-portal)

</details>

---

The FinOps toolkit includes multiple ARM templates. Prerequisites, parameters, and post-deployment setup steps differ per template. Please refer to the template details for more information:

- [FinOps hub](../finops-hub/template.md)
- [Optimization workbook](../optimization-workbook/README.md)

Note Bicep Registry modules can be referenced directly from your Bicep code and are not deployed using the steps below.

<br>

## Where can I get FinOps toolkit templates?

- Deploy from [Microsoft Learn code samples](https://learn.microsoft.com/samples/browse/?terms=finops).
- Deploy from [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.costmanagement).
- Download from [FinOps toolkit releases](https://github.com/microsoft/finops-toolkit/releases).
- Include in your bicep modules from the [Bicep Registry](https://azure.github.io/bicep-registry-modules/#cost).

<blockquote class="highlight" markdown="1">
  💡 _Have an idea? Are we missing anything? [Let us know!](https://github.com/microsoft/finops-toolkit/issues/new/choose)_
</blockquote>

<br>

## Deploy a FinOps toolkit template

1. Open the desired template:
   - [FinOps hub](https://learn.microsoft.com/samples/azure/azure-quickstart-templates/finops-hub)
   - [Optimization workbook](https://learn.microsoft.com/samples/azure/azure-quickstart-templates/optimization-workbook)
2. Select the **Deploy to Azure** button towards the top of the page.
3. Specify the desired values for each parameter. See the template details for more information.
   > _Use the **Edit parameters** link to use a saved parameters file or to download a new parameters file for future use._
4. Select the **Review + create** button.
5. Select the **Create** button.

![Screenshot of the FinOps hub create form](https://github.com/microsoft/finops-toolkit/assets/399533/80257886-41d3-402d-8756-c3eaced7a19b)

<br>

## Using custom deployment in the Azure portal

![Screenshot of the custom deployment form](https://github.com/microsoft/finops-toolkit/assets/399533/cab162d6-cbb1-43e4-87ff-2e659285a428)

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
