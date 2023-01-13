# FinOps toolkit deployment options

![Status: Not started](https://img.shields.io/badge/status-in%20progress-blue)

On this page:

- [Summary](#Summary)
- [Using custom deployment in the Azure portal](#Using-custom-deployment-in-the-Azure-portal)
- [Deploy from Microsoft Learn](#Deploy-from-Microsoft-Learn)
- [Deploy from Azure Quickstart Templates](#Deploy-from-Azure-Quickstart-Templates)

**⚠️⚠️⚠️ Open issues ⚠️⚠️⚠️**

- Add details about deploying from Cost Management
- Add note about how to use the resource visualizer (with screenshot)
- Add screenshots for each deployment option

---

## Summary

FinOps toolkit supports the following deployment options:

- **FinOps hub instance** – Creates an export, backing storage account, and data factory pipeline to clean up old export files.

> 🚩 **Important**<br>_The FinOps toolkit will change over time. We highly recommend saving a parameter file or creating an overarching bicep file to ensure you can re-deploy the template with the same parameters as new versions become available._

<br>

<!--
## Deploy from Cost Management
![Status: Not started](https://img.shields.io/badge/status-not%20started-critical)

<br>
-->

## Using custom deployment in the Azure portal

The Azure portal includes a **Custom deployment** option that supports all templates available in the Azure Quickstart Templates repository. To deploy a quickstart template:

1. Open [Custom deployment](https://portal.azure.com/#create/Microsoft.Template)
2. In the **Quickstart template** dropdown, select `quickstarts/microsoft.costmanagement/finops-hub`.
3. Select the **Select template** button.
4. <a name="edit-params"></a>Are you updating an existing deployment?
   1. If so, use a parameters file:
      1. Select the **Edit parameters** link at the top of the form.
      2. Select the **Load file** command at the top of the page to upload your existing parameters file or copy and paste the file contents directly.
      3. Select the **Save** button at the bottom of the page.
   2. If this is a new deployment, specify the desired values:
      Parameter | Type | Description
      ----------|------|------------
      **hubName** | String | Name of the resource group and name prefix for all resources. Default: `finops-hub`.
      **location** | String | Azure location where all resources should be created.
      **exportScopes** | Array | Optional. List of scope IDs to create exports for.
5. Select the **Edit parameters** link at the top of the form.
6. Select the **Download** command at the top of the page to save your parameters file. Keep this for your next deployment.
7. Select the **Save** button at the bottom of the page.
8. Select the **Review + create** button.
9. Select the **Create** button.

If you received any validation errors, fix those and attempt to create the resources again.

<br>

## Deploy from Microsoft Learn code samples

Microsoft Learn hosts all templates available from the Azure Quickstart Templates repository. To deploy from Microsoft Learn:

1. Open the [FinOps hub code sample](https://learn.microsoft.com/en-us/samples/azure/azure-quickstart-templates/finops-hub).
2. Select the **Deploy to Azure** button towards the top of the page.
3. Complete [steps 5 and beyond](#edit-params) from the custom deployment steps above.

<br>

## Deploy from Azure Quickstart Templates

Azure Quickstart Templates is a Microsoft-managed community of open source deployment templates. Many teams at Microsoft and across the community publish templates to share with the customers and partners. All FinOps toolkit releases will be available in the [Cost Management folder](https://github.com/Azure/azure-quickstart-templates/quickstarts/microsoft.costmanagement).

To deploy a quickstart template:

1. Open the [FinOps hub template folder](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.costmanagement/finops-hub).
2. Select the **Deploy to Azure** button towards the top of the page.
3. Complete [steps 5 and beyond](#edit-params) from the custom deployment steps above.

<br>
