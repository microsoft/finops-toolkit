# 📦 FinOps toolkit deployment options

The FinOps toolkit includes multiple ARM templates. Prerequisites, parameters, and post-deployment setup steps differ per template. Please refer to the template details for more information:

- [FinOps hub](./finops-hub/template.md)
- [Optimization workbook](./optimization-workbook)

Note Bicep Registry modules can be referenced directly from your Bicep code and are not deployed using the steps below.

> ### ⚠️ Important <!-- markdownlint-disable-line -->
>
> _The FinOps toolkit will change over time. We highly recommend saving a parameter file to ensure you can re-deploy new versions with the same parameters._

On this page:

- [Using custom deployment in the Azure portal](#using-custom-deployment-in-the-azure-portal)
- [Deploy from Azure Quickstart Templates](#deploy-from-azure-quickstart-templates)

---

## Using custom deployment in the Azure portal

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

<!--
TODO: Uncomment this when the template is published to the Azure Quickstart Templates repository.

## Deploy from Microsoft Learn code samples

Microsoft Learn hosts all templates available from the Azure Quickstart Templates repository. To deploy from Microsoft Learn:

1. Open the [FinOps hub code sample](https://learn.microsoft.com/en-us/samples/azure/azure-quickstart-templates/finops-hub).
2. Select the **Deploy to Azure** button towards the top of the page.
3. Complete [steps 4+](#edit-params) from the custom deployment steps above.

<br>
-->

## Deploy from Azure Quickstart Templates

Azure Quickstart Templates is a Microsoft-managed community of open source deployment templates. Many teams at Microsoft and across the community publish templates to share with the customers and partners.

<!--
Templates are organized based on scope:

- Tenant templates in [tenant-deployments](https://github.com/Azure/azure-quickstart-templates/tree/master/tenant-deployments)
- Resource group templates in [quickstarts/microsoft.costmanagement](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.costmanagement)

We do not currently have any subscription or management group templates.
-->

To deploy a quickstart template:

1. Open the [FinOps hub template](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/finops-hub).
2. Select the **Deploy to Azure** button towards the top of the page.
3. Complete [steps 4+](#edit-params) from the custom deployment steps above.

<br>
