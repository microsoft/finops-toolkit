# Automated detection

The **Waste Reduction Logic App** is an automated detection mechanism provided by [Azure Logic App](https://docs.microsoft.com/en-us/azure/logic-apps/logic-apps-overview). The logic app will run on a configurable schedule to monitor selected subscriptions for a set of idle resources and send notifications once it finds any of those resources to alert admins to investigate and take action.

>[!NOTE]
>For customers using US Government Cloud, use the **Waste Reduction Logic App - Gov** version of the Logic App.

## Deploy Logic App

* Create a new **Custom Deployment** ([Figure WR-2](/media\waste-app-1.png))
  
<figure>
  <img src="../logicapp/media/waste-app-1.png" alt="Showing where to create a Custom Deployment using Azure Portal.">
  <figcaption>
    <center><strong>Figure WR-2</strong>. Custom deployment.</center>
  </figcaption>
</figure>

* Click on **Build your own template in the editor**
* Load file **Waste Reduction Logic App** or copy and paste the content into the *Edit template* section ([Figure WR-3](../logicapp/media/waste-app-2.png))

<figure>
  <img src="../logicapp/media/waste-app-2.png" alt="Showing the Edit template blade during the customer deployment process.">
  <figcaption>
    <center><strong>Figure WR-3</strong>. Edit template.</center>
  </figcaption>
</figure>

> [!IMPORTANT]
> The logic app needs to be in the same region as its resource group

### Authorize Connection

After the deployment has been completed, the API connection will be in Error. This is expected and should be fixed after deploying the template.

* Navigate to the Waste App's API Connection ([Figure WR-4](../logicapp/media/waste-app-3.png))

<figure>
  <img src="../logicapp/media/waste-app-3.png" alt="Highlight the API Connection in the Waste App's Resource Group.">
  <figcaption>
    <center><strong>Figure WR-4</strong>. Waste App's API Connection.</center>
  </figcaption>
</figure>

* Inspect the connection error ([Figure WR-5](../logicapp/media/waste-app-4.png))

<figure>
  <img src="../logicapp/media/waste-app-4.png" alt="Highlight the connection error in the WasteReductionConnection.">
  <figcaption>
    <center><strong>Figure WR-5</strong>. WasteReductionConnection.</center>
  </figcaption>
</figure>

* To fix the connection error, go the API connection resource and authorize the connection.
  * Click on **Edit API Connection** in the General tab ([Figure WR-6](../logicapp/media/waste-app-5.png))
  <figure>
    <img src="../logicapp/media/waste-app-5.png" alt="Showing the Edit API Connection button in the WasteReductionConnection.">
    <figcaption>
      <center><strong>Figure WR-6</strong>. Edit API Connection.</center>
    </figcaption>
  </figure>

  * Click on **Authorize**
    > [!IMPORTANT]
    > Be aware that the account authorizing the connection will be used to by the Logic App to send the Alerts.
  * **Save** your changes after the authorization was successful

  * Go back to the **Overview** blade and verify the **Status: Connected** ([Figure WR-7](../logicapp/media/waste-app-6.png))
  <figure>
    <img src="../logicapp/media/waste-app-6.png" alt="Showing the connected status for the WasteReductionConnection.">
    <figcaption>
      <center><strong>Figure WR-7</strong>. WasteReductionConnection.</center>
    </figcaption>
  </figure>

### Configure Logic App

After making sure the API Connection is connected, now you will need to create a system-assigned identity to allow the Logic App to "read" resources in the subscription.

* Navigate to the **WasteReductionApp** ([Figure WR-8](../logicapp/media/waste-app-7.png))

<figure>
  <img src="../logicapp/media/waste-app-7.png" alt="Highlight the WasteReductionApp in the waste-app resource group.">
  <figcaption>
    <center><strong>Figure WR-8</strong>. WasteReductionApp.</center>
  </figcaption>
</figure>

* Go to Settings > **Identity** and change Status to **On** ([Figure WR-9](../logicapp/media/waste-app-8.png))

<figure>
  <img src="../logicapp/media/waste-app-8.png" alt="Highlight the radio button inside the status field for the system assigned managed identity.">
  <figcaption>
    <center><strong>Figure WR-9</strong>. System assigned managed identity.</center>
  </figcaption>
</figure>

* **Save** your changes and enable system assigned managed identity ([Figure WR-10](../logicapp/media/waste-app-9.png))

<figure>
  <img src="../logicapp/media/waste-app-9.png" alt="Highlight the yes option for registering the WasteReductionApp with AAD.">
  <figcaption>
    <center><strong>Figure WR-10</strong>. Register with AAD.</center>
  </figcaption>
</figure>

* Go to *Azure role assignments* within the *system assigned* blade ([Figure WR-11](../logicapp/media/waste-app-10.png))

<figure>
  <img src="../logicapp/media/waste-app-10.png" alt="Highlight the Azure role assignments button on the system assigned blade.">
  <figcaption>
    <center><strong>Figure WR-11</strong>. Azure role assignments.</center>
  </figcaption>
</figure>

* Click on **Add role Assignment** and assign the follow permissions ([Figure WR-12](../logicapp/media/waste-app-11.png)):

  ```text
  Scope: Subscription
  Subscription: Subscription to be analyzed by this Logic App
  Role: Reader
  ```

<figure>
  <img src="../logicapp/media/waste-app-11.png" alt="Show the add role assignment blade.">
  <figcaption>
    <center><strong>Figure WR-12</strong>. Add role assignment.</center>
  </figcaption>
</figure>

* Click on **Save**
* Go to the Logic App Designer **configure the alert recipient** ([Figure WR-13](../logicapp/media/waste-app-13.png))

<figure>
  <img src="../logicapp/media/waste-app-13.png" alt="Highlight Logic App Designer blade and the 'set alert recipient' field">
  <figcaption>
    <center><strong>Figure WR-13</strong>. Set Alert Recipient.</center>
  </figcaption>
</figure>

* **Set subscriptions** in scope ([Figure WR-14](../logicapp/media/waste-app-14.png))

<figure>
  <img src="../logicapp/media/waste-app-14.png" alt="Highlight the subscriptions array input field in the WasteReductionApp">
  <figcaption>
    <center><strong>Figure WR-14</strong>. Set Subscriptions.</center>
  </figcaption>
</figure>

> [!NOTE]
> If the customer has multiple subscriptions, you can add them to the array, by using the following format: ["subscription1", "subscription2", "subscription3"]

### Test Logic App

After successfully configuring the logic app, it's time to test if everything works as expected. Ensure you have entered valid values for the alert recipient and subscriptions in scope.

* Click on **Run Trigger** to test the Logic App ([Figure WR-15](../logicapp/media/waste-app-15.png))

<figure>
  <img src="../logicapp/media/waste-app-15.png" alt="Highlight the Run Trigger button in the Logic App designer tool">
  <figcaption>
    <center><strong>Figure WR-15</strong>. Run Trigger.</center>
  </figcaption>
</figure>

<div style="text-align: right"> <h3>Next Up: <a href="../logicapp/acoi-reporting.md">Reporting</a></h2></div>
