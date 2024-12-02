---
layout: default
parent: Optimization engine
title: Setup options
nav_order: 50
description: 'Advanced scenarios for setting up or upgrading AOE.'
permalink: /optimization-engine/setup-options
---

<span class="fs-9 d-block mb-4">Setup options</span>
Advanced scenarios for setting up or upgrading AOE.
{: .fs-6 .fw-300 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🎛️ Using a local repository](#-using-a-local-repository)
- [👂 Silent deployment](#-silent-deployment)
- [🤝 Enabling Azure commitments workbooks](#-enabling-azure-commitments-workbooks)
- [🔼 Upgrading AOE](#-upgrading-aoe)

</details>

---

## 🎛️ Using a local repository

If you choose to deploy all the dependencies from your own local repository, you must publish the solution files into a publicly reachable URL. You must ensure the entire AOE project structure is available at the same base URL. Storage Account SAS Token-based URLs are not supported.

```powershell
.\Deploy-AzureOptimizationEngine.ps1 -TemplateUri <URL to the Bicep file (e.g., https://contoso.com/azuredeploy.bicep)> [-AzureEnvironment <AzureUSGovernment|AzureGermanCloud|AzureCloud>]

# Example - Deploying from a public endpoint
.\Deploy-AzureOptimizationEngine.ps1 -TemplateUri "https://contoso.com/azuredeploy.bicep"

# Example 2 - Deploying from a public endpoint, using resource tags
$tags = @{"CostCenter"="FinOps";"Environment"="Production"}
.\Deploy-AzureOptimizationEngine.ps1 -TemplateUri "https://contoso.com/azuredeploy.bicep" -ResourceTags $tags
```

## 👂 Silent deployment

Optionally, you can also use the `SilentDeploymentSettingsPath` input parameter to deploy AOE in a more automated way.  
The file referencing should be a JSON file with the needed attributes defined (**all mandatory** unless specified).  
An example of the content of such silent deployment file is:

```json
{
    "SubscriptionId": "<<SubscriptionId>>",
    "NamePrefix": "<<CustomNamePrefix>>", // prefix for all resources. Fill in 'EmptyNamePrefix' to specify the resource names
    "WorkspaceReuse": "n", // y = reuse existing workspace, n = create new workspace
    "ResourceGroupName": "<<CustomName>>-rg", // mandatory if NamePrefix is set to 'EmptyNamePrefix'
    "StorageAccountName": "<<CustomName>>sa", // mandatory if NamePrefix is set to 'EmptyNamePrefix'
    "AutomationAccountName": "<<CustomName>>-auto", // mandatory if NamePrefix is set to 'EmptyNamePrefix'
    "SqlServerName": "<<CustomName>>-sql", // mandatory if NamePrefix is set to 'EmptyNamePrefix'
    "SqlDatabaseName": "<<CustomName>>-db", // mandatory if NamePrefix is set to 'EmptyNamePrefix'
    "WorkspaceName": "<<ExistingName>>", // mandatory if WorkspaceReuse is set to 'n'
    "WorkspaceResourceGroupName": "<<ExistingName>>", // mandatory if workspaceReuse is set to 'n'
    "DeployWorkbooks": "y", // y = deploy the workbooks, n = don't deploy the workbooks
    "TargetLocation": "westeurope",
    "DeployBenefitsUsageDependencies": "y", // deploy the dependencies for the Azure commitments workbooks (EA/MCA customers only + agreement administrator role required)
    "CustomerType": "MCA", // mandatory if DeployBenefitsUsageDependencies is set to 'y', MCA/EA
    "BillingAccountId": "<guid>:<guid>_YYYY-MM-DD", // mandatory if DeployBenefitsUsageDependencies is set to 'y', MCA or EA Billing Account ID
    "BillingProfileId": "ABCD-DEF-GHI-JKL", // mandatory if CustomerType is set to 'MCA"
    "CurrencyCode": "EUR" // mandatory if DeployBenefitsUsageDependencies is set to 'y'
  } 
```

When silently deploying AOE, which typically happens in automated continuous deployment workflows, you might want to leverage SQL Entra ID authentication
parameters, for example to grant the SQL administrator role to an Entra ID group having the workflow automation service principal as member. For example:

```powershell
.\Deploy-AzureOptimizationEngine.ps1 -SilentDeploymentSettingsPath "<path to deployment settings file>" -SqlAdminPrincipalType Group -SqlAdminPrincipalName "<Group Name>" -SqlAdminPrincipalObjectId "<Group Object GUID>"
```

<blockquote class="note" markdown="1">
  When deploying AOE with non-user identities (service principals), you must ensure you assign a system identity to the AOE SQL Server and grant it the `Directory Readers` role in Entra ID. Please follow the steps described [here](https://aka.ms/sqlaadsetup).
</blockquote>

## 🤝 Enabling Azure commitments workbooks

In order to leverage the Workbooks that allow you to analyze your Azure commitments usage (`Benefits Usage`, `Reservations Usage` and `Savings Plans Usage`) or estimate the impact of doing additional consumption commitments (`Benefits Simulation` and `Reservations Potential`), you need to configure AOE and grant privileges to its Managed Identity at your consumption agreement level (EA or MCA). If you could not do it during setup/upgrade, you can still execute those extra configuration steps, provided you do it with a user that is **both Contributor in the AOE resource group and have administrative privileges over the consumption agreement** (Enterprise Enrollment Administrator for EA or Billing Profile Owner for MCA). You just have to use the `Setup-BenefitsUsageDependencies.ps1` script following the syntax below and answer the input requests:

```powershell
./Setup-BenefitsUsageDependencies.ps1 -AutomationAccountName <AOE automation account> -ResourceGroupName <AOE resource group> [-AzureEnvironment <AzureUSGovernment|AzureGermanCloud|AzureCloud>]
```

If you run into issues with the Azure Pricesheet ingestion (due to the large size of the CVS export), you can create the following Azure Automation variable, to filter in the Price Sheet regions: `AzureOptimization_PriceSheetMeterRegions` set to the comma-separated billing regions of your virtual machines (e.g. *EU West,EU North*).

The Reservations Usage Workbook has a couple of "Unused Reservations" tiles that require AOE to export Consumption data at the EA/MCA scope (instead of the default Subscription scope). You can switch to EA/MCA scope consumption by creating/updating the `AzureOptimization_ConsumptionScope` Automation variable with `BillingAccount` (EA/MCA, requiring additional Billing Account Reader role manually granted to the AOE managed identity) or `BillingProfile` (MCA only) as value. Be aware that this option may generate a very large single consumption export which may lead to errors due to lack of memory (this would in turn require [deploying AOE with a Hybrid Worker](./customize.md#-scale-aoe-runbooks-with-hybrid-worker)).

## 🔼 Upgrading AOE

If you have a previous version of AOE and wish to upgrade, it's as simple as re-running the deployment script with the resource naming options you chose at the initial deployment. It will re-deploy the ARM template, adding new resources and updating existing ones.

However, if you previously customized components such as Automation variables or schedules, improved job execution performance with Hybrid Workers, or hardened the solution with Private Link, then you should run the deployment script with the `DoPartialUpgrade` switch, e.g.:

`.\Deploy-AzureOptimizationEngine.ps1 -DoPartialUpgrade`

With the `DoPartialUpgrade` switch, the deployment will only:

* Add new storage containers
* Update/add Automation runbooks
* Update/add Automation modules
* Add new Automation schedules
* Add new Automation variables
* Upgrade the SQL database model
* Update Log Analytics Workbooks

Some customers may also customize the SQL Server deployment, for example, migrating from SQL Database to a SQL Managed Instance. There is no tooling available to assist in the migration, but once the database migration is done manually, the AOE upgrade script supports future `DoPartialUpgrade` upgrades with the `IgnoreNamingAvailabilityErrors` switch on (skips SQL Server naming/existence validation).
