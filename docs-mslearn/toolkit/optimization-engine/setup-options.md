---
title: Setup options
description: This article describes advance scenarios for setting up or upgrading Azure optimization engine (AOE).
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: hepint
#customer intent: As a FinOps user, I want to understand how to setup Azure optimization engine (AOE).
---

# Azure optimization engine setup options

This article describes advance scenarios for setting up or upgrading Azure optimization engine (AOE).

<br>

## Using a local repository

If you choose to deploy all the dependencies from your own local repository, you must publish the solution files into a publicly reachable URL. You must ensure the entire AOE project structure is available at the same base URL. Storage Account SAS Token-based URLs aren't supported.

```powershell
.\Deploy-AzureOptimizationEngine.ps1 -TemplateUri <URL to the Bicep file (for example, https://contoso.com/azuredeploy.bicep)> [-AzureEnvironment <AzureUSGovernment|AzureGermanCloud|AzureCloud>]

# Example - Deploying from a public endpoint
.\Deploy-AzureOptimizationEngine.ps1 -TemplateUri "https://contoso.com/azuredeploy.bicep"

# Example 2 - Deploying from a public endpoint, using resource tags
$tags = @{"CostCenter"="FinOps";"Environment"="Production"}
.\Deploy-AzureOptimizationEngine.ps1 -TemplateUri "https://contoso.com/azuredeploy.bicep" -ResourceTags $tags
```

<br>

## Silent deployment

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

When silently deploying AOE, which typically happens in automated continuous deployment workflows, you might want to use Microsoft Entra authentication for Azure SQL parameters. For example, to grant the SQL administrator role to a Microsoft Entra ID group having the workflow automation service principal as member. Here's an example:

```powershell
.\Deploy-AzureOptimizationEngine.ps1 -SilentDeploymentSettingsPath "<path to deployment settings file>" -SqlAdminPrincipalType Group -SqlAdminPrincipalName "<Group Name>" -SqlAdminPrincipalObjectId "<Group Object GUID>"
```

> [!NOTE]
> When you deploy AOE with non-user identities (service principals), you must ensure you assign a system identity to the AOE SQL Server and grant it the `Directory Readers` role in Microsoft Entra ID. Follow the steps at [Microsoft Entra service principals with Azure SQL](https://aka.ms/sqlaadsetup).

<br>

## Enable Azure commitments workbooks

In order to use the Workbooks that allow you to analyze your Azure commitments usage (`Benefits Usage`, `Reservations Usage`, and `Savings Plans Usage`) or estimate the effect of having other consumption commitments (`Benefits Simulation` and `Reservations Potential`), you need to configure AOE and grant privileges to its Managed Identity at your consumption agreement level (EA or Microsoft Customer Agreement (MCA)). If you couldn't do it during setup/upgrade, you can still execute those extra configuration steps, provided you do it with a user that is **both Contributor in the AOE resource group and have administrative privileges over the consumption agreement** (Enterprise Enrollment Administrator for EA or Billing Profile Owner for MCA). You just have to use the `Setup-BenefitsUsageDependencies.ps1` script using the following syntax and answer the input requests:

```powershell
./Setup-BenefitsUsageDependencies.ps1 -AutomationAccountName <AOE automation account> -ResourceGroupName <AOE resource group> [-AzureEnvironment <AzureUSGovernment|AzureGermanCloud|AzureCloud>]
```

If you run into issues with the Azure Price sheet ingestion (due to the large size of the CVS export), you can create the following Azure Automation variable, to filter in the Price Sheet regions: `AzureOptimization_PriceSheetMeterRegions` set to the comma-separated billing regions of your virtual machines. For example, _EU West, EU, and North_.

The Reservations Usage Workbook has a couple of "Unused Reservations" tiles that require AOE to export Consumption data at the EA/MCA scope (instead of the default Subscription scope). You can switch to EA/MCA scope consumption by creating/updating the `AzureOptimization_ConsumptionScope` Automation variable with `BillingAccount` (EA/MCA, requiring another Billing Account Reader role manually granted to the AOE managed identity) or `BillingProfile` (MCA only) as value. This option can generate a large single consumption export which might lead to errors due to lack of memory (it would in turn require [deploying AOE with a Hybrid Worker](./customize.md#scale-aoe-runbooks-with-hybrid-worker)).

<br>

## Upgrading AOE

If you have a previous version of AOE and want to upgrade, it's as simple as rerunning the deployment script. Use the resource naming options you chose at the initial deployment. It redeploys the ARM template, adding new resources and updating existing ones.

However, if you previously customized components such as Automation variables or schedules, improved job execution performance with Hybrid Workers, or hardened the solution with Private Link, then you should run the deployment script with the `DoPartialUpgrade` switch, for example:

`.\Deploy-AzureOptimizationEngine.ps1 -DoPartialUpgrade`

With the `DoPartialUpgrade` switch, the deployment will only:

- Add new storage containers
- Update/add Automation runbooks
- Update/add Automation modules
- Add new Automation schedules
- Add new Automation variables
- Upgrade the SQL database model
- Update Log Analytics Workbooks

Some customers might also customize the SQL Server deployment, for example, migrating from SQL Database to a SQL Managed Instance. There's no tooling available to help the migration, but once the database migration is done manually, the AOE upgrade script supports future `DoPartialUpgrade` upgrades with the `IgnoreNamingAvailabilityErrors` switch on (skips SQL Server naming/existence validation).

<br>

## Related content

Related FinOps capabilities:

- [Data ingestion](../../framework/understand/ingestion.md)
- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure Advisor](/azure/advisor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)

<br>
