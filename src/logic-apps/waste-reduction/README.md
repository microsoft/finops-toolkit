# Logic App template

![Azure Public Test Date](https://azurequickstartsservice.blob.core.windows.net/badges/path-to-sample/PublicLastTestDate.svg)
![Azure Public Test Result](https://azurequickstartsservice.blob.core.windows.net/badges/path-to-sample/PublicDeployment.svg)

![Azure US Gov Last Test Date](https://azurequickstartsservice.blob.core.windows.net/badges/path-to-sample/FairfaxLastTestDate.svg)
![Azure US Gov Last Test Result](https://azurequickstartsservice.blob.core.windows.net/badges/path-to-sample/FairfaxDeployment.svg)

![Best Practice Check](https://azurequickstartsservice.blob.core.windows.net/badges/path-to-sample/BestPracticeResult.svg)
![Cred Scan Check](https://azurequickstartsservice.blob.core.windows.net/badges/path-to-sample/CredScanResult.svg)

![Bicep Version](https://azurequickstartsservice.blob.core.windows.net/badges/path-to-sample/BicepVersion.svg)

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fpath-to-sample%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fpath-to-sample%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fpath-to-sample%2Fazuredeploy.json)

```

To add a createUiDefinition.json file to the deploy button, append the url to the createUiDefinition.json file to the href for the button, e.g.

https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fpath-to-sample%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fpath-to-sample%2FcreateUiDefinition.json

Note the url is case sensitive.

```

This template deploys a **Waste Reduction Logic App**. The **Waste Reduction Logic App** is an automated detection tool that runs on a configurable schedule to monitor a set of idle resources and send notifications once it finds any of those resources to alert users to investigate and take action.

The Waste Reduction Logic App includes:

- Logic App to run queries
- API connection to connect to Office 365

<br>

## Prerequisites

Description of the prerequisites for the deployment

1. You must have permission to create the deployed resources mentioned above.

<br>

## 📗 How to use this template

1. Deploy the template
   > [![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)] &nbsp; [![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)]
2. Authorize API connection
     > After the deployment has been completed, the API connection will have an error. This is expected and will be fixed after authorizing the connection.  
   - Click on the **API connection** resource, then click on **Edit API connection** in the General tab to authorize the connection.
   - Click on **Authorize**  
      > Be aware that the account authorizing the connection will be used to by the Logic App to send the Alerts.
   - **Save** your change after the authorization is successful
   - Go back to the **Overview** blade and verify that the **Status: Connected**
3. Create a system-assigned identity to allow the Logic App to "read" the resources in the subscription.
   - Navigate to the **WasteReductionApp**
   - Click on **Identity** under the Settings tab and toggle the Status to **On**
   - **Save** your changes and select **yes** to enable the system assigned managed identity
   - Go to **Azure role assignments** within the *system assigned* blade
   - Click on **Add role assignment** and assign the following permissions then click on **Save**
4. Configure the Logic App
   - Navigate to the **WasteReductionApp** and select **Logic App Designer** under the Development Tools tab
   - Configure the reoccurrence
   - Configure the alert recipient
   - Set subscriptions in scope
      > If the customer has multiple subscriptions, you can add them to the array, by using the following format: ["subscription1", "subscription2", "subscription3"]
   - Click on **Run** to test the Logic App

## 🖥️ About the Waste Reduction Logic App

Waste Reduction Logic App is part of the  [FinOps toolkit](https://aka.ms/finops/toolkit), an open-source collection of FinOps solutions that help you manage and optimize your cloud costs.

To contribute to the FinOps toolkit, [join us on GitHub](https://aka.ms/ftk).

`Tags: Tag1, Tag2, Tag3`
