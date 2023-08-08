# 🛠️ Configure permissions

On this page:

- [✅ Requirements](#-requirements)
- [🛠️ MCA billing accounts and billing profiles](#️-mca-billing-accounts-and-billing-profiles)
- [🛠️ Enterprise agreement billing accounts and departments](#️-enterprise-agreement-billing-accounts-and-departments)
- [🛠️ Subscriptions and resource groups](#️-subscriptions-and-resource-groups)

---

## ✅ Requirements

1. [Find your Azure Active Directory tenant id](https://learn.microsoft.com/en-us/azure/azure-portal/get-subscription-tenant-id#find-your-azure-ad-tenant).
3. Find the Identity for the data factory.
    1. Open the Azure Portal and browse to the resource group where you deployed the FinOps toolkit.
    2. Select the Azure Data Factory resource.
    3. Select the **Managed identities** tab.
    4. Make a note of the **Object (principal) ID** value. <img src=../images/managed-identity.jpeg alt="Image showing the managed identity for the azure data factory" title="Data factory managed identity" width="768"/>

## 🛠️ MCA billing accounts and billing profiles

No special configuration is required at this time for MCA export scopes because they use cost management exports rather than managed exports.

<br>

## 🛠️ Enterprise agreement billing accounts and departments

1.  [Find your enrollment (and department) Id](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/view-all-accounts#switch-billing-scope-in-the-azure-portal).
2. Load the FinOps Toolkit PowerShell module.
3. Grant reader permissions to the data factory

   ````powershell
   # Grants enrollment reader permissions to the specified service principal or managed identity
   Add-FinOpsServicePrincipal -ObjectId 00000000-0000-0000-0000-000000000000 ` # Object Id of data factory managed identity
                              -TenantId 00000000-0000-0000-0000-000000000000 ` # Azure Active Directory tenant Id
                              -BillingAccountId 12345                          # Enrollment ID
   
   # Grants department reader permissions to the specified service principal or managed identity
   Add-FinOpsServicePrincipal -ObjectId 00000000-0000-0000-0000-000000000000 ` # Object Id of data factory managed identity
                              -TenantId 00000000-0000-0000-0000-000000000000 ` # Azure Active Directory tenant Id
                              -BillingAccountId 12345 `                        # Enrollment Id
                              -DepartmentId 67890                              # Department Id

   ````

<br>

## 🛠️ Subscriptions and resource groups

Grant the "Cost management contributor" role to the managed identity for the data factory via the portal.

<img src=../images/cm-contributor.jpg alt="Image showing cost management contributor role assigned to the managed identity of the data factory" title="Cost Management Contributor" width="768"/>
