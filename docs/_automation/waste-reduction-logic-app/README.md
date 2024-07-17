
# Automated detection

The **Waste Reduction Logic App** is an automated detection mechanism provided by [Azure Logic App](https://docs.microsoft.com/en-us/azure/logic-apps/logic-apps-overview). The logic app will run on a configurable schedule to monitor selected subscriptions for a set of idle resources and send notifications once it finds any of those resources to alert admins to investigate and take action.

Use the following steps to deploy the Logic App

1. Create a new **Custom Deployment** by navigating to **Deploy a custom template** and clicking on **Build your own template in the editor**

* You will see a blank template.

* You can either load the Bicep file "**Waste Reduction Logic App**" or replace the blank template with the code
* Select  **Save**.
* Then select  **Review + create**
* After the portal validates the template, select  **Create**.

> [!IMPORTANT]
> The logic app needs to be in the same region as its resource group

1. Authorize Connection

> [!NOTE]
> After the deployment has been completed, the API connection will have an error. This is expected and will be fixed after authorizing the connection.  

* Click on the **API connection** resource, then click on **Edit API Connection** in the General tab to authorize the connection.

* Click on **Authorize**

> [!IMPORTANT]
> Be aware that the account authorizing the connection will be used to by the Logic App to send the Alerts.

* **Save** your change after the authorization is successful

* Go back to the **Overview** blade and verify that the **Status: Connected**

1. Create a system-assigned identity to allow the Logic App to "read" the resources in the subscription.

* Navigate to the **WasteReductionApp**
* Click on **Identity** under the Settings tab and toggle the Status to **On**

* **Save** your changes and select **yes** to enable the system assigned managed identity

* Go to **Azure role assignments** within the *system assigned* blade

* Click on **Add role Assignment** and assign the following permissions then click on **Save** ([Figure WR-12](../logicapp/media/waste-app-11.png)):  

```text

Scope: Subscription

Subscription: Subscription to be analyzed by this Logic App

Role: Reader

```

1. Configure the Logic App

* Navigate to the **WasteReductionApp** and select **Logic App Designer** under the Development Tools tab ([Figure WR-13](../logicapp/media/waste-app-13.png))

* Configure the reoccurrence
* Configure the alert recipient
* Set subscriptions in scope

* **Set subscriptions** in scope ([Figure WR-14](../logicapp/media/waste-app-14.png))

> [!NOTE]
> If the customer has multiple subscriptions, you can add them to the array, by using the following format: ["subscription1", "subscription2", "subscription3"]

1. Test Logic App

* Click on **Run** to test the Logic App
