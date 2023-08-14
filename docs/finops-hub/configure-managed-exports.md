# 🛠️ Configure managed exports

> ℹ️ _**Important**<br>Microsoft Cost Management does not support managed exports for Microsoft Customer Agreement billing accounts, billing profiles, invoice sections, and customers. Please [configure Cost Management exports manually](./configure-scopes.md#️-configure-cost-management-exports-manually)._

On this page:

- [✅ Managed export requirements](#-managed-export-requirements)
- [🛠️ Managed export configuration](#️-managed-export-configuration)

---

## ✅ Managed export requirements

- Managed exports require granting permissions against the export scope to the managed identity used by Data Factory.  If this is not desireable/feasable use Cost Management exports instead
- Managed exports support EA Enrollment, EA Department and Subscription level imports.
- **MCA Billing Accounts and Billing Profiles are not supported by managed exports.  Rather use [Cost Management exports](./configure-scopes.md#️-configure-cost-management-exports-manually).**
- Minimum required permissions for the export scope:
  - _**EA Enrollment:** EA Reader_
  - _**EA Department:** Department Reader_
  - _**Subscription:** Cost Management Contributor_
  
## 🛠️ Managed export configuration

1. [Grant permissions to Data Factory](./Configure-permissions.md).
2. Add the export scope(s).
   - [using the FinOps Toolkit PowerShell module](#🛠️-add-export-scopes-via-the-finops-toolkit-powershell-module) (EA enrollments and departments, subscriptions and resource groups)
   - [manually via the Azure Portal](#🛠️-add-export-scopes-via-the-azure-portal) (MCA billing accounts and billing profiles)
3. [Initialize the dataset](#🛠️-initialize-the-dataset)
  
  > ℹ️ _**Important**<br>Ensure not to add duplicate or overlapping export scopes as this will lead to duplication of data._

<br>

### 🛠️ Add export scopes via the FinOps Toolkit PowerShell module

1. Load the FinOps Toolkit PowerShell module
2. Add the export scope(s)

   ````powershell
   # EA billing account
   Add-FinOpsHubScope -ResourceGroupName "ftk-FinOps-Hub" `
                      -Scope "/providers/Microsoft.Billing/billingAccounts/1234567"

   # EA department
   Add-FinOpsHubScope -ResourceGroupName "ftk-FinOps-Hub" `
                      -Scope "/providers/Microsoft.Billing/billingAccounts/1234567/departments/56789"
   
   # Subscription
   Add-FinOpsHubScope -ResourceGroupName "ftk-FinOps-Hub" `
                      -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"

   # Resource group
   Add-FinOpsHubScope -ResourceGroupName "ftk-FinOps-Hub" `
                      -Scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ftk-finops-hub"
   ````

<br>

### 🛠️ Add export scopes via the Azure Portal

1. Open the Azure portal and navigate to the FinOps hub resource group.
2. Select the FinOps hub storage account and navigate to the config container.
3. Select the settings.json file and add the required scopes via the edit tab.
4. Save the file to commit the export scopes.
  
  > ℹ️ _**Important**<br>Ensure not to add duplicate or overlapping export scopes as this will lead to duplication of data._

- Export scope examples:

  - EA billing account

  ````json
   "exportScopes": [
      {
         "scope": "/providers/Microsoft.Billing/billingAccounts/1234567"
      }
    ]
  ````

  - EA department

  ````json
   "exportScopes": [
      {
         "scope": "/providers/Microsoft.Billing/billingAccounts/1234567/departments/56789"
      }
    ]
  ````

  - Subscription

  ````json
   "exportScopes": [
      {
         "scope": "/subscriptions/00000000-0000-0000-0000-000000000000"
      }
    ]
  ````

  - Resource group

  ````json
   "exportScopes": [
      {
         "scope": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ftk-finops-hub"
      }
    ]
  ````

<br>

### 🛠️ Initialize the dataset

Trigger the "msexports_backfill" datafactory pipeline to initialize the dataset.  This can be done through the Azure Portal or using PowerShell.

````powershell

$ResourceGroup = "ftk-finops-hub"
$df = (Get-AzDataFactoryV2 -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue)
Invoke-AzDataFactoryV2Pipeline -DataFactoryName $df.DataFactoryName -PipelineName 'msexports_backfill' -ResourceGroupName $ResourceGroup
````
