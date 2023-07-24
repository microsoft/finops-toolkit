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
   - [using the FinOps Toolkit PowerShell module](#️-add-export-scopes-via-the-finops-toolkit-powershell-module)
   - [manually via the Azure Portal](#️-add-export-scopes-via-the-azure-portal)
3. Initialize the dataset.
  
  > ℹ️ _**Important**<br>Ensure not to add duplicate or overlapping export scopes as this will lead to duplication of data._

<br>

### 🛠️ Add export scopes via the FinOps Toolkit PowerShell module

1. Load the FinOps Toolkit PowerShell module
2. Add the export scope(s)

    ````powershell
    Add-FinOpsHubScope -ResourceGroupName ftk-FinOps-Hub -Scope "/providers/Microsoft.Billing/billingAccounts/1234567"
    ````

<br>

### 🛠️ Add export scopes via the Azure Portal

- Export scope examples:

  - Subscription

  ````json
   "exportScopes": [
      {
         "scope": "/subscriptions/{subscriptionId}"
      }
    ]
  ````

  - EA Enrollment

  ````json
   "exportScopes": [
      {
         "/providers/Microsoft.Billing/billingAccounts/{enrollmentNumber}"
      }
    ]
  ````

  - MCA Billing Account

  ````json
   "exportScopes": [
      {
         "scope": "/providers/Microsoft.Billing/billingAccounts/{billingAccountId}"
      }
    ]
  ````

  - MCA Billing Profile

  ````json
   "exportScopes": [
      {
         "scope": "/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}"
      }
    ]
  ````
  