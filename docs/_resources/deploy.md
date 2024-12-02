---
layout: default
title: Deployment options
nav_order: 10
description: 'Deploy FinOps toolkit solutions.'
permalink: /help/deploy
---

<span class="fs-9 d-block mb-4">FinOps toolkit deployment options</span>
Explore the different options to deploy FinOps toolkit solutions. Deploy from the portal, make small tweaks, or download for a fully customized deployment.
{: .fs-6 .fw-300 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🗺️ Where to find FinOps toolkit templates](#️-where-to-find-finops-toolkit-templates)
- [🚀 Deploy a FinOps toolkit template](#-deploy-a-finops-toolkit-template)
- [🎛️ Using custom deployment in the Azure portal](#️-using-custom-deployment-in-the-azure-portal)

</details>

---

The FinOps toolkit includes multiple ARM templates. Prerequisites, parameters, and post-deployment setup steps differ per template. Please refer to the template details for more information:

- [FinOps hub](../_reporting/hubs/template.md)
- [Optimization workbook](../_optimize/workbooks/optimization/README.md)
- [Governance workbook](../_optimize/workbooks/governance/README.md)

Note Bicep Registry modules can be referenced directly from your Bicep code and are not deployed using the steps below.

<br>

## 🗺️ Where to find FinOps toolkit templates

- Deploy from this site (links below).
- Deploy from [Microsoft Learn code samples](https://learn.microsoft.com/samples/browse/?terms=finops).
- Deploy from [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.costmanagement).
- Download from [FinOps toolkit releases](https://github.com/microsoft/finops-toolkit/releases).
- Include in your bicep modules from the [Bicep Registry](https://azure.github.io/bicep-registry-modules/#cost).

<blockquote class="highlight" markdown="1">
  💡 _Are we missing anywhere? [Let us know!](https://aka.ms/ftk/idea)_
</blockquote>

<br>

## 🚀 Deploy a FinOps toolkit template

1. Select the **Deploy to Azure** button for the desired template:

   | Template                                                               | Azure Commercial                                                      | Azure Gov                                                          | Azure China                                                          |
   | ---------------------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------- |
   | [FinOps hub](../_reporting/hubs/README.md)                             | {% include deploy.html template="finops-hub" public="1" %}            | {% include deploy.html template="finops-hub" gov="1" %}            | {% include deploy.html template="finops-hub" china="1" %}            |
   | [FinOps workbooks](../_reporting/hubs/README.md)                       | {% include deploy.html template="finops-workbooks" public="1" %}      | {% include deploy.html template="finops-workbooks" gov="1" %}      | {% include deploy.html template="finops-workbooks" china="1" %}      |
   | [Optimization workbook](../_optimize/workbooks/optimization/README.md) | {% include deploy.html template="optimization-workbook" public="1" %} | {% include deploy.html template="optimization-workbook" gov="1" %} | {% include deploy.html template="optimization-workbook" china="1" %} |
   | [Governance workbook](../_optimize/workbooks/governance/README.md)     | {% include deploy.html template="governance-workbook" public="1" %}   | {% include deploy.html template="governance-workbook" gov="1" %}   | {% include deploy.html template="governance-workbook" china="1" %}   |

2. Specify the desired values for each parameter. See the template details for more information.
   <blockquote class="tip" markdown="1">
     _Use the **Edit parameters** link to use a saved parameters file or to download a new parameters file for future use._
   </blockquote>
3. Select the **Review + create** button.
4. Select the **Create** button.

![Screenshot of the FinOps hub create form](https://github.com/microsoft/finops-toolkit/assets/399533/80257886-41d3-402d-8756-c3eaced7a19b)

<br>

## 🎛️ Using custom deployment in the Azure portal

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
