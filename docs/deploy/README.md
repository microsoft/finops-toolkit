# FinOps toolkit deployment options

![Status: Not started](https://img.shields.io/badge/status-not%20started-red) &nbsp;<sup>→</sup>&nbsp;
[![#1](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/1)](https://github.com/microsoft/cloud-hubs/issues/1)

The FinOps toolkit includes multiple ARM templates depending on your needs. We recommend using the **FinOps hub with exports** template to streamline your setup process. All the examples below refer to this template. You may select a different template, which will change the available options.

For more details about toolkit options, refer to the [available templates](../templates).

> ### ⚠️ Important
>
> _The FinOps toolkit will change over time. We highly recommend saving a parameter file to ensure you can re-deploy new versions of the template with the same parameters._

On this page:

- [Using custom deployment in the Azure portal](#using-custom-deployment-in-the-azure-portal)
- [Deploy from Microsoft Learn code samples](#deploy-from-microsoft-learn-code-samples)
- [Deploy from Azure Quickstart Templates](#deploy-from-azure-quickstart-templates)
- [Future considerations](#future-considerations)

---

## Using custom deployment in the Azure portal

The Azure portal includes a **Custom deployment** option that supports all templates available in the Azure Quickstart Templates repository. To deploy a quickstart template:

1. Open [Custom deployment](https://portal.azure.com/#create/Microsoft.Template)
2. In the **Quickstart template** dropdown, select `tenant-deployments/finops-hub-with-exports`.
   > ℹ️ _Replace this template as desired. Note parameters below may differ slightly._
3. Select the **Select template** button.
4. <a name="edit-params"></a>Are you updating an existing deployment?
   1. If so, use a parameters file:
      1. Select the **Edit parameters** link at the top of the form.
      2. Select the **Load file** command at the top of the page to upload your existing parameters file or copy and paste the file contents directly.
      3. Select the **Save** button at the bottom of the page.
   2. If this is a new deployment, specify the desired values:
      Parameter | Type | Description
      ----------|------|------------
      **subscription** | String | ID of the subscription to deploy the hub instance to.
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

1. Open the [FinOps hub code sample](https://learn.microsoft.com/en-us/samples/azure/azure-quickstart-templates/finops-hub-with-exports).
2. Select the **Deploy to Azure** button towards the top of the page.
3. Complete [steps 4 and beyond](#edit-params) from the custom deployment steps above.

<br>

## Deploy from Azure Quickstart Templates

Azure Quickstart Templates is a Microsoft-managed community of open source deployment templates. Many teams at Microsoft and across the community publish templates to share with the customers and partners.

Templates are organized based on scope:

- Tenant templates in [tenant-deployments](https://github.com/Azure/azure-quickstart-templates/tree/master/tenant-deployments)
- Resource group templates in [quickstarts/microsoft.costmanagement](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.costmanagement)

We do not currently have any subscription or management group templates.

To deploy a quickstart template:

1. Open the [FinOps hub with exports template](https://github.com/Azure/azure-quickstart-templates/tree/master/template-deployments/finops-hub-with-exports).
2. Select the **Deploy to Azure** button towards the top of the page.
3. Complete [steps 5 and beyond](#edit-params) from the custom deployment steps above.

<br>

---

## Future considerations

- Add note about how to use the resource visualizer (with screenshot)
- Add screenshots for each deployment option
