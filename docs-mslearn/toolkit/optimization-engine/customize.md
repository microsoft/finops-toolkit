---
title: Customize Azure optimization engine
description: This article describes how to customize the Azure optimization engine settings according to your organization requirements.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: hepint
#customer intent: As a FinOps user, I want to understand how to customize Azure optimization engine.
---

<!-- cSpell:ignore hepint -->
# Customize Azure optimization engine

The Azure optimization engine (AOE) is a set of Azure Automation runbooks that collect, ingest, and analyze Azure consumption and performance data to provide cost optimization recommendations. The engine is designed to be flexible and customizable, allowing you to adjust its behavior to better fit your organization's needs. This article provides guidance on how to customize the engine's settings. It includes adjusting thresholds, changing schedules, and expanding the engine's scope.

<br>

## Widen the engine scope

By default, the Azure Automation Managed Identity is assigned the Reader role only over the respective subscription. However, you can widen the scope of its recommendations just by granting the same Reader role to other subscriptions or, even simpler, to a top-level Management Group.

In the context of augmented virtual machine (VM) right-size recommendations, you might have your VMs reporting to multiple workspaces. If you need to include other workspaces - besides the main one AOE is using - in the recommendations scope, you just have to add their workspace IDs to the `AzureOptimization_RightSizeAdditionalPerfWorkspaces` variable (see more details in [Configuring workspaces](configure-workspaces.md)).

If you have multiple Entra ID directories (also known as tenants), you can extend the reach of AOE to a tenant other than the one where it was deployed. To achieve this, you have two options, each with its pros and cons:

| Service principal in secondary tenant                                                                                                      | Azure Lighthouse deployment                                                                                                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Provides the widest feature coverage (see limitations below)                                                                               | Provides an almost complete feature coverage (see limitations below)                                                                                                                                                                                                                                             |
| Uses a less secure and unmanaged authentication option, based on secrets                                                                   | Provides robust authentication, reusing the engine's managed identity                                                                                                                                                                                                                                            |
| Does not support reusing Perf metrics from Log Analytics workspaces in the secondary tenant, when augmenting VM right-size recommendations | Does not include support for Microsoft Entra objects, impacting the completeness of the Identities and Roles workbook and Microsoft Entra ID-related recommendations. The Policy Compliance workbook overview tab does not bring data from the secondary tenant; only the detailed policy analysis is supported. |
| Implementation is based on the execution of a helper PowerShell script                                                                     | Implementation is based on the deployment of an Azure Resource Manager template                                                                                                                                                                                                                                  |
| More scalable coverage of secondary tenant, just by granting permissions to the service principal on a higher-level scope                  | Deployment is done per subscription in secondary tenant; needs Azure Policy to scale                                                                                                                                                                                                                             |
| Less cost-effective, as job schedules are duplicated for the secondary tenant                                                              | More cost-effective, as existing job schedules will automatically cover the secondary tenant                                                                                                                                                                                                                     |

### Multitenant with service principal in secondary tenant

To widen the engine scope using the service principal-based approach, you must ensure the following pre-requisites:

- Create a service principal (App registration) and a secret in the secondary tenant.
- Grant the required permissions to the service principal in the secondary tenant, namely **Reader** in Azure subscriptions/management groups and **Global Reader** in Microsoft Entra ID.
- Create an [Automation credential](/azure/automation/shared-resources/credentials?tabs=azure-powershell#create-a-new-credential-asset) in the AOE's Automation Account. Set the service principal's client ID as username and the secret as password.
- Execute the `Register-MultitenantAutomationSchedules.ps1` script (available in the [AOE root folder](https://aka.ms/AzureOptimizationEngine/code)) in the context of the subscription where AOE was deployed. This script  creates new job schedules for each of the export runbooks and configures them to query the secondary tenant. You just have to call the script using the following syntax:

```powershell
./Register-MultitenantAutomationSchedules.ps1 -AutomationAccountName <AOE automation account> -ResourceGroupName <AOE resource group> -TargetSchedulesSuffix <suffix to append to every new job schedules, e.g., Tenant2> -TargetTenantId <secondary tenant GUID> -TargetTenantCredentialName <name of the Automation credential created in the previous step> [-TargetSchedulesOffsetMinutes <offset in minutes relative to original schedules, defaults to 0>] [-TargetAzureEnvironment <AzureUSGovernment|AzureGermanCloud|AzureCloud>] [-ExcludedRunbooks <An array of runbook names to exclude from the process>] [-IncludedRunbooks <An array of runbook names to include in the process>]
```

### Multitenant with Azure Lighthouse

To widen the engine scope using the Azure Lighthouse-based approach, you must ensure the following pre-requisites:

- Prepare the Azure Resource Manager template to be deployed in the secondary tenant. You can reuse as-is the reference template in our repository (`lighthouse-template.json` file available in the [AOE root folder](https://aka.ms/AzureOptimizationEngine/code)).
- If you're deploying the template for a single subscription, you just have to follow the steps described [here](/azure/lighthouse/how-to/onboard-customer#deploy-the-azure-resource-manager-template), by using the reference template above and specifying the template parameters values (as a separate parameters file or directly in the Azure portal interface).
- If you need to deploy at scale to multiple subscriptions, you can leverage Azure Policy, by following the instructions available [here](/azure/lighthouse/how-to/onboard-management-group) and adjusting the policy definition code to follow the reference template above.
- No matter the deployment approach, the template parameters you must provide are the following:
  - `managedByTenantId` - Microsoft Entra tenant ID of the tenant where AOE was deployed in.
  - `principalId` - Microsoft Entra object ID of the AOE automation account system managed identity.
  - `principalIdDisplayName` - AOE automation account name.

<br>

## Adjust schedules

By default, the base time for the AOE Automation schedules is set as the deployment time. Soon after the initial deployment completes, the exports, ingests, and recommendations runbooks run according to the engine's default schedules. For example, if you deploy AOE on a Monday at 11:00 a.m., you get new recommendations every Monday at 2:30 p.m.. If this schedule, for some reason, doesn't fit your needs, you can reset it to the time that better suits you, by using the `Reset-AutomationSchedules.ps1` script (available in the [AOE root folder](https://aka.ms/AzureOptimizationEngine/code)). You just have to call the following script. Follow the syntax and answer the input requests:

```powershell
./Reset-AutomationSchedules.ps1 -AutomationAccountName <AOE automation account> -ResourceGroupName <AOE resource group> [-AzureEnvironment <AzureUSGovernment|AzureGermanCloud|AzureCloud>]
```

The base time you choose must be in UTC and must be defined according to the day of the week and hour you want recommendations to be generated. You must deduce 3h30m from the time you choose. It's because the base time defines the schedules for all the dependent automation runbooks that must run before the recommendations are generated. For example, let's say you want recommendations to be generated every Monday at 8h30 a.m.; the base time is the next calendar date falling on a Monday, at 5h00 AM. The format of the date you choose must be YYYY-MM-dd HH:mm:ss, for example, `2022-01-03 05:00:00`.

The script also asks you to enter, **if needed**, the Hybrid Worker Group you want the runbooks to run in (see the next subsection).

<br>

## Scale AOE runbooks with Hybrid Worker

By default, AOE Automation runbooks are executed in the context of the Azure Automation sandbox. You might face performance issues due to the memory limits of the Automation sandbox. Or, you might decide to implement private endpoints for the Storage Account or SQL Database to harden AOE's security. In either case, you need to execute runbooks from a Hybrid Worker. It’s an Azure or on-premises Virtual Machine with the Automation Hybrid Worker extension. To change the execution context for the AOE runbooks, you must use the `Reset-AutomationSchedules.ps1` script. See how to use the script in the previous subsection. After setting the runbooks execution base time, enter the Hybrid Worker Group name you want the runbooks to run in.

<!-- cSpell:ignore UAMI, Mbps -->
<!-- prettier-ignore-start -->
> [!IMPORTANT]
> - The Hybrid Worker machine must have the required PowerShell modules installed. The `upgrade-manifest.json` file contains the list of required modules.
> - Once you change the runbook execution context to Hybrid Worker, you must always use the `DoPartialUpgrade` flag whenever you upgrade AOE, or else you lose the runbook schedule settings and revert to the default sandbox configuration.
> - The Managed Identity used to authenticate against Azure, Microsoft Entra ID, and Billing Account scopes is still the one Azure Automation uses. It gets used even if the Hybrid Worker machine has a Managed Identity assigned ([see details](/azure/automation/automation-hrw-run-runbooks?#runbook-auth-managed-identities)). User-assigned Managed Identities are supported in the context of Hybrid Workers only if:
>   - The Automation Account doesn't have any associated Managed Identity, that is, only the Hybrid Worker machine can have a User-Assigned Managed Identity.
>   - All runbooks run in the context of the Hybrid Worker. In this case, you must create an `AzureOptimization_UAMIClientID` Automation Variable with the User-Assigned Managed Identity Client ID as value.
>   - The `AzureOptimization_AuthenticationOption` Automation variable value is updated to `UserAssignedManagedIdentity`.
<!-- prettier-ignore-end -->

<br>

## Adjust thresholds

For Advisor cost recommendations, the AOE's default configuration produces percentile 99th VM metrics aggregations, but you can adjust them to be less conservative. There are also adjustable metrics thresholds that are used to compute the fit score. The default thresholds values are 30% for CPU (5% for shutdown recommendations), 50% for memory (100% for shutdown) and 750 Mbps for network bandwidth (10 Mbps for shutdown). All the adjustable configurations are available as Azure Automation variables. The information in the next table highlights the most relevant configuration variables. To access them, go to the Automation Account _Shared Resources - Variables_ menu option.

| Variable                                                                  | Description                                                                                                                                                                                                                                                                               |
| ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AzureOptimization_AdvisorFilter`                                         | If you aren't interested in getting recommendations for all the non-Cost Advisor pillars, you can specify a pillar-level filter (comma-separated list with at least one of the following values: `HighAvailability,Security,Performance,OperationalExcellence`). Defaults to all pillars. |
| `AzureOptimization_AuthenticationOption`                                  | The default authentication method for Automation Runbooks is `RunAsAccount`. But you can change to `ManagedIdentity` if you're using a Hybrid Worker in an Azure VM.                                                                                                                      |
| `AzureOptimization_ConsumptionOffsetDays`                                 | The Azure Consumption data collection runbook queries each day for billing events that occurred seven days ago (default). You can change to a closer offset, but bear in mind that some subscription types (for example, MSDN) to not support a lower value.                              |
| `AzureOptimization_PerfPercentileCpu`                                     | The default percentile for CPU metrics aggregations is 99. As the percentile lowers, the VM right-size fit score algorithm adjusts less conservatively.                                                                                                                                   |
| `AzureOptimization_PerfPercentileDisk`                                    | The default percentile for disk IO/throughput metrics aggregations is 99. As the percentile lowers, the VM right-size fit score algorithm adjusts less conservatively.                                                                                                                    |
| `AzureOptimization_PerfPercentileMemory`                                  | The default percentile for memory metrics aggregations is 99. As the percentile lowers, the VM right-size fit score algorithm adjusts less conservatively.                                                                                                                                |
| `AzureOptimization_PerfPercentileNetwork`                                 | The default percentile for network metrics aggregations is 99. As the percentile lowers, the VM right-size fit score algorithm adjusts less conservatively.                                                                                                                               |
| `AzureOptimization_PerfPercentileSqlDtu`                                  | The default percentile to be used for SQL DB DTU metrics. As the percentile lowers, the SQL Database right-size algorithm adjusts less conservatively.                                                                                                                                    |
| `AzureOptimization_PerfThresholdCpuPercentage`                            | The CPU threshold (in % Processor Time). Above it, the VM right-size fit score decreases. Below it, the Azure Virtual Machine Scale Set (scale set) right-size Cost recommendation triggers.                                                                                              |
| `AzureOptimization_PerfThresholdCpuShutdownPercentage`                    | The CPU threshold (in % Processor Time). Above it, the VM right-size fit score decreases (_shutdown recommendations only_).                                                                                                                                                               |
| `AzureOptimization_PerfThresholdCpuDegradedMaxPercentage`                 | The CPU threshold (Maximum observed in % Processor Time). Above it, the scale set right-size Performance recommendation triggers.                                                                                                                                                         |
| `AzureOptimization_PerfThresholdCpuDegradedAvgPercentage`                 | The CPU threshold (Average observed in % Processor Time). Above it, the scale set right-size Performance recommendation triggers.                                                                                                                                                         |
| `AzureOptimization_PerfThresholdMemoryPercentage`                         | The memory threshold (in % Used Memory). Above it, the VM right-size fit score decreases. Below it, the scale set right-size Cost recommendation triggers.                                                                                                                                |
| `AzureOptimization_PerfThresholdMemoryShutdownPercentage`                 | The memory threshold (in % Used Memory). Above it, the VM right-size fit score decreases (_shutdown recommendations only_).                                                                                                                                                               |
| `AzureOptimization_PerfThresholdMemoryDegradedPercentage`                 | The memory threshold (in % Used Memory). Above it, the scale set right-size Performance recommendation triggers.                                                                                                                                                                          |
| `AzureOptimization_PerfThresholdNetworkMbps`                              | The network threshold (in Total Mbps). Above it, the VM right-size fit score decreases.                                                                                                                                                                                                   |
| `AzureOptimization_PerfThresholdNetworkShutdownMbps`                      | The network threshold (in Total Mbps). Above it, the VM right-size fit score decreases (_shutdown recommendations only_).                                                                                                                                                                 |
| `AzureOptimization_PerfThresholdDtuPercentage`                            | The DTU usage percentage threshold. Below it, a SQL Database instance is considered underutilized.                                                                                                                                                                                        |
| `AzureOptimization_RecommendAdvisorPeriodInDays`                          | The interval in days to look for Advisor recommendations in the Log Analytics repository - the default is 7, as Advisor recommendations are collected once a week.                                                                                                                        |
| `AzureOptimization_RecommendationAADMaxCredValidityYears`                 | The maximum number of years for a Service Principal credential/certificate validity - any validity above this interval generates a Security recommendation. Defaults to 2.                                                                                                                |
| `AzureOptimization_RecommendationAADMinCredValidityDays`                  | The minimum number of days for a Service Principal credential/certificate before it expires - any validity below this interval generates an Operational Excellence recommendation. Defaults to 30.                                                                                        |
| `AzureOptimization_RecommendationLongDeallocatedVmsIntervalDays`          | The number of consecutive days a VM was deallocated before being recommended for deletion (_Virtual Machine has been deallocated for long with disks still incurring costs_). Defaults to 30.                                                                                             |
| `AzureOptimization_RecommendationVNetSubnetMaxUsedPercentageThreshold`    | The maximum percentage tolerated for subnet IP space usage. Defaults to 80.                                                                                                                                                                                                               |
| `AzureOptimization_RecommendationVNetSubnetMinUsedPercentageThreshold`    | The minimum percentage for subnet IP space usage - any usage below this value flags the respective subnet as using low IP space. Defaults to 5.                                                                                                                                           |
| `AzureOptimization_RecommendationVNetSubnetEmptyMinAgeInDays`             | The minimum age in days for an empty subnet to be flagged, thus avoiding flagging newly created subnets. Defaults to 30.                                                                                                                                                                  |
| `AzureOptimization_RecommendationVNetSubnetUsedPercentageExclusions`      | Comma-separated, single-quote enclosed list of subnet names that must be excluded from subnet usage percentage recommendations, for example, `'gatewaysubnet'`,`'azurebastionsubnet'`. Defaults to `'gatewaysubnet'`.                                                                     |
| `AzureOptimization_RecommendationRBACAssignmentsPercentageThreshold`      | The maximum percentage of RBAC assignments limits usage. Defaults to 80.                                                                                                                                                                                                                  |
| `AzureOptimization_RecommendationResourceGroupsPerSubPercentageThreshold` | The maximum percentage of Resource Groups count per subscription limits usage. Defaults to 80.                                                                                                                                                                                            |
| `AzureOptimization_RecommendationRBACSubscriptionsAssignmentsLimit`       | The maximum limit for RBAC assignments per subscription. Currently set to 2000 (as [documented](/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-rbac-limits)).                                                                                           |
| `AzureOptimization_RecommendationRBACMgmtGroupsAssignmentsLimit`          | The maximum limit for RBAC assignments per management group. Currently set to 500 (as [documented](/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-rbac-limits)).                                                                                        |
| `AzureOptimization_RecommendationResourceGroupsPerSubLimit`               | The maximum limit for Resource Group count per subscription. Currently set to 980 (as [documented](/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-rbac-limits)).                                                                                        |
| `AzureOptimization_RecommendationStorageAcountGrowthThresholdPercentage`  | The minimum Storage Account growth percentage required to flag Storage as not having a retention policy in place.                                                                                                                                                                         |
| `AzureOptimization_RecommendationStorageAcountGrowthMonthlyCostThreshold` | The minimum monthly cost (in your EA/MCA currency) required to flag Storage as not having a retention policy in place.                                                                                                                                                                    |
| `AzureOptimization_RecommendationStorageAcountGrowthLookbackDays`         | The lookback period (in days) for analyzing Storage Account growth.                                                                                                                                                                                                                       |
| `AzureOptimization_ReferenceRegion`                                       | The Azure region used as a reference for getting the list of available SKUs (defaults to `westeurope`).                                                                                                                                                                                   |
| `AzureOptimization_RemediateRightSizeMinFitScore`                         | The minimum fit score a VM right-size recommendation must have for the remediation to occur.                                                                                                                                                                                              |
| `AzureOptimization_RemediateRightSizeMinWeeksInARow`                      | The minimum number of weeks in a row a VM right-size recommendation must be complete for the remediation to occur.                                                                                                                                                                        |
| `AzureOptimization_RemediateRightSizeTagsFilter`                          | The tag name/value pairs a VM right-size recommendation must have for the remediation to occur. Example: `[ { "tagName": "a", "tagValue": "b" }, { "tagName": "c", "tagValue": "d" } ]`                                                                                                   |
| `AzureOptimization_RemediateLongDeallocatedVMsMinFitScore`                | The minimum fit score a long deallocated VM recommendation must have for the remediation to occur.                                                                                                                                                                                        |
| `AzureOptimization_RemediateLongDeallocatedVMsMinWeeksInARow`             | The minimum number of weeks in a row a long deallocated VM recommendation must be complete for the remediation to occur.                                                                                                                                                                  |
| `AzureOptimization_RemediateLongDeallocatedVMsTagsFilter`                 | The tag name/value pairs a long deallocated VM recommendation must have for the remediation to occur. Example: `[ { "tagName": "a", "tagValue": "b" }, { "tagName": "c", "tagValue": "d" } ]`                                                                                             |
| `AzureOptimization_RemediateUnattachedDisksMinFitScore`                   | The minimum fit score an unattached disk recommendation must have for the remediation to occur.                                                                                                                                                                                           |
| `AzureOptimization_RemediateUnattachedDisksMinWeeksInARow`                | The minimum number of weeks in a row an unattached disk recommendation must be complete for the remediation to occur.                                                                                                                                                                     |
| `AzureOptimization_RemediateUnattachedDisksAction`                        | The action to apply for an unattached disk recommendation remediation (`Delete` or `Downsize`).                                                                                                                                                                                           |
| `AzureOptimization_RemediateUnattachedDisksTagsFilter`                    | The tag name/value pairs an unattached disk recommendation must have for the remediation to occur. Example: `[ { "tagName": "a", "tagValue": "b" }, { "tagName": "c", "tagValue": "d" } ]`                                                                                                |
| `AzureOptimization_RightSizeAdditionalPerfWorkspaces`                     | A comma-separated list of other Log Analytics workspace IDs where to look for VM metrics (see [Configuring workspaces](configure-workspaces.md)).                                                                                                                                         |
| `AzureOptimization_PerfThresholdDiskIOPSPercentage`                       | The disk IOPS usage percentage threshold. Below it, the underutilized Premium SSD disks recommendation triggers.                                                                                                                                                                          |
| `AzureOptimization_PerfThresholdDiskMBsPercentage`                        | The disk throughput usage percentage threshold. Below it, the underutilized Premium SSD disks recommendation triggers.                                                                                                                                                                    |
| `AzureOptimization_RecommendationsMaxAgeInDays`                           | The maximum age (in days) for a recommendation to be kept in the SQL database. Default: 365.                                                                                                                                                                                              |
| `AzureOptimization_RetailPricesCurrencyCode`                              | The currency code (for example, EUR, USD, and so on) used to collect the Reservations retail prices.                                                                                                                                                                                      |
| `AzureOptimization_PriceSheetMeterCategories`                             | The comma-separated meter categories used for Price sheet filtering, in order to avoid ingesting unnecessary data. Defaults to `"Virtual Machines,Storage"`.                                                                                                                              |
| `AzureOptimization_ConsumptionScope`                                      | The scope of the consumption exports: `Subscription` (default), `BillingProfile` (MCA only), or `BillingAccount` (for MCA, requires adding the Billing Account Reader role to the AOE managed identity). See [more details](setup-options.md#enable-azure-commitments-workbooks).         |

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
