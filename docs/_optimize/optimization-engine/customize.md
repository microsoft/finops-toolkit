---
layout: default
parent: Optimization engine
title: Customizations
nav_order: 20
description: 'Customize the Azure Optimization Engine settings according to your organization requirements.'
permalink: /optimization-engine/customize
---

<span class="fs-9 d-block mb-4">Customizations</span>
Customize the Azure Optimization Engine settings according to your organization requirements.
{: .fs-6 .fw-300 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🧿 Widen the engine scope](#-widen-the-engine-scope)
- [⏰ Adjust schedules](#-adjust-schedules)
- [🦹 Scale AOE runbooks with Hybrid Worker](#-scale-aoe-runbooks-with-hybrid-worker)
- [🚥 Adjust thresholds](#-adjust-thresholds)

</details>

---

## 🧿 Widen the engine scope

By default, the Azure Automation Managed Identity is assigned the Reader role only over the respective subscription. However, you can widen the scope of its recommendations just by granting the same Reader role to other subscriptions or, even simpler, to a top-level Management Group.

In the context of augmented VM right-size recommendations, you may have your VMs reporting to multiple workspaces. If you need to include other workspaces - besides the main one AOE is using - in the recommendations scope, you just have to add their workspace IDs to the `AzureOptimization_RightSizeAdditionalPerfWorkspaces` variable (see more details in [Configuring workspaces](./configuring-workspaces.md)).

If you are a multi-tenant customer, you can extend the reach of AOE to a tenant other than the one where it was deployed. To achieve this, you must ensure the following pre-requisites:

* Create a service principal (App registration) and a secret in the secondary tenant.
* Grant the required permissions to the service principal in the secondary tenant, namely **Reader** in Azure subscriptions/management groups and **Global Reader** in Entra ID.
* Create an [Automation credential](https://learn.microsoft.com/azure/automation/shared-resources/credentials?tabs=azure-powershell#create-a-new-credential-asset) in the AOE's Automation Account, with the service principal's client ID as username and the secret as password.
* Execute the `Register-MultitenantAutomationSchedules.ps1` script (available in the [AOE root folder](https://aka.ms/AzureOptimizationEngine/code)) in the context of the subscription where AOE was deployed. This script will create new job schedules for each of the export runbooks and configure them to query the secondary tenant. You just have to call the script following the syntax below:

```powershell
./Register-MultitenantAutomationSchedules.ps1 -AutomationAccountName <AOE automation account> -ResourceGroupName <AOE resource group> -TargetSchedulesSuffix <suffix to append to every new job schedules, e.g., Tenant2> -TargetTenantId <secondary tenant GUID> -TargetTenantCredentialName <name of the Automation credential created in the previous step> [-TargetSchedulesOffsetMinutes <offset in minutes relative to original schedules, defaults to 0>] [-TargetAzureEnvironment <AzureUSGovernment|AzureGermanCloud|AzureCloud>] [-ExcludedRunbooks <An array of runbook names to exclude from the process>] [-IncludedRunbooks <An array of runbook names to include in the process>]
```

<br>

## ⏰ Adjust schedules

By default, the base time for the AOE Automation schedules is set as the deployment time. Soon after the initial deployment completes, the exports, ingests and recommendations runbooks will run according to the engine's default schedules. For example, if you deploy AOE on a Monday at 11:00 a.m., you will get new recommendations every Monday at 2:30 p.m.. If this schedule, for some reason, does not fit your needs, you can reset it to the time that better suits you, by using the `Reset-AutomationSchedules.ps1` script (available in the [AOE root folder](https://aka.ms/AzureOptimizationEngine/code)). You just have to call the script following the syntax below and answer the input requests:

```powershell
./Reset-AutomationSchedules.ps1 -AutomationAccountName <AOE automation account> -ResourceGroupName <AOE resource group> [-AzureEnvironment <AzureUSGovernment|AzureGermanCloud|AzureCloud>]
```

The base time you choose must be in UTC and must be defined according to the week day and hour you want recommendations to be generated. You must deduce 3h30m from the time you choose, because the base time defines the schedules for all the dependent automation runbooks that must run before the recommendations are generated. For example, let's say you want recommendations to be generated every Monday at 8h30 a.m.; the base time will be the next calendar date falling on a Monday, at 5h00 a.m.. The format of the date you choose must be YYYY-MM-dd HH:mm:ss, e.g., 2022-01-03 05:00:00.

The script will also ask you to enter, **if needed**, the Hybrid Worker Group you want the runbooks to run in (see the next sub-section).

<br>

## 🦹 Scale AOE runbooks with Hybrid Worker

By default, AOE Automation runbooks are executed in the context of the Azure Automation sandbox. If you face performance issues due to the memory limits of the Automation sandbox or decide to implement private endpoints for the Storage Account or SQL Database, to harden AOE's security, you will need to execute runbooks from a Hybrid Worker (an Azure or on-premises Virtual Machine with the Automation Hybrid Worker extension). To change the execution context for the AOE runbooks, you must use the `Reset-AutomationSchedules.ps1` script. See how to use the script in the previous sub-section and, after setting the runbooks execution base time, enter the Hybrid Worker Group name you want the runbooks to run in.

**IMPORTANT**: 
* The Hybrid Worker machine must have the required PowerShell modules installed. See `upgrade-manifest.json` file contains the list of required modules.
* Once you change the runbook execution context to Hybrid Worker, you will have to always use the `DoPartialUpgrade` flag whenever you upgrade AOE, or else you will lose the runbook schedule settings and revert to the default sandbox configuration.
* The Managed Identity used to authenticate against Azure, Microsoft Entra ID and Billing Account scopes is still the Azure Automation's one, even if the Hybrid Worker machine has a Managed Identity assigned ([see details](https://learn.microsoft.com/en-us/azure/automation/automation-hrw-run-runbooks?#runbook-auth-managed-identities)). User-assigned Managed Identities are supported in the context of Hybrid Workers only if 1) the Automation Account does not have any associated Managed Identity, i.e., only the Hybrid Worker machine can have a User-Assigned Managed Identity; 2) all runbooks run in the context of the Hybrid Worker. In this case, you must create an `AzureOptimization_UAMIClientID` Automation Variable with the User-Assigned Managed Identity Client ID as value; and 3) the `AzureOptimization_AuthenticationOption` Automation variable value is updated to `UserAssignedManagedIdentity`.

<br>

## 🚥 Adjust thresholds

For Advisor cost recommendations, the AOE's default configuration produces percentile 99th VM metrics aggregations, but you can adjust those to be less conservative. There are also adjustable metrics thresholds that are used to compute the fit score. The default thresholds values are 30% for CPU (5% for shutdown recommendations), 50% for memory (100% for shutdown) and 750 Mbps for network bandwidth (10 Mbps for shutdown). All the adjustable configurations are available as Azure Automation variables. The list below is a highlight of the most relevant configuration variables. To access them, go to the Automation Account _Shared Resources - Variables_ menu option.

Variable | Description
--- | --- |
`AzureOptimization_AdvisorFilter` | If you are not interested in getting recommendations for all the non-Cost Advisor pillars, you can specify a pillar-level filter (comma-separated list with at least one of the following: `HighAvailability,Security,Performance,OperationalExcellence`). Defaults to all pillars.
`AzureOptimization_AuthenticationOption` | The default authentication method for Automation Runbooks is `RunAsAccount`. But you can change to `ManagedIdentity` if you're using a Hybrid Worker in an Azure VM.
`AzureOptimization_ConsumptionOffsetDays` | The Azure Consumption data collection runbook queries each day for billing events that occurred 7 days ago (default). You can change to a closer offset, but bear in mind that some subscription types (e.g., MSDN) to not support a lower value.
`AzureOptimization_PerfPercentileCpu` | The default percentile for CPU metrics aggregations is 99. The lower the percentile, the less conservative will be VM right-size fit score algorithm.
`AzureOptimization_PerfPercentileDisk` | The default percentile for disk IO/throughput metrics aggregations is 99. The lower the percentile, the less conservative will be VM right-size fit score algorithm.
`AzureOptimization_PerfPercentileMemory` | The default percentile for memory metrics aggregations is 99. The lower the percentile, the less conservative will be VM right-size fit score algorithm.
`AzureOptimization_PerfPercentileNetwork` | The default percentile for network metrics aggregations is 99. The lower the percentile, the less conservative will be VM right-size fit score algorithm.
`AzureOptimization_PerfPercentileSqlDtu` | The default percentile to be used for SQL DB DTU metrics. The lower the percentile, the less conservative will be the SQL Database right-size algorithm.
`AzureOptimization_PerfThresholdCpuPercentage` | The CPU threshold (in % Processor Time) above which the VM right-size fit score will decrease or below which the VM scale set right-size Cost recommendation will trigger.
`AzureOptimization_PerfThresholdCpuShutdownPercentage` | The CPU threshold (in % Processor Time) above which the VM right-size fit score will decrease (_shutdown recommendations only_).
`AzureOptimization_PerfThresholdCpuDegradedMaxPercentage` | The CPU threshold (Maximum observed in % Processor Time) above which the VM scale set right-size Performance recommendation will trigger.
`AzureOptimization_PerfThresholdCpuDegradedAvgPercentage` | The CPU threshold (Average observed in % Processor Time) above which the VM scale set right-size Performance recommendation will trigger.
`AzureOptimization_PerfThresholdMemoryPercentage` | The memory threshold (in % Used Memory) above which the VM right-size fit score will decrease or below which the VM scale set right-size Cost recommendation will trigger.
`AzureOptimization_PerfThresholdMemoryShutdownPercentage` | The memory threshold (in % Used Memory) above which the VM right-size fit score will decrease (_shutdown recommendations only_).
`AzureOptimization_PerfThresholdMemoryDegradedPercentage` | The memory threshold (in % Used Memory) above which the VM scale set right-size Performance recommendation will trigger.
`AzureOptimization_PerfThresholdNetworkMbps` | The network threshold (in Total Mbps) above which the VM right-size fit score will decrease.
`AzureOptimization_PerfThresholdNetworkShutdownMbps` | The network threshold (in Total Mbps) above which the VM right-size fit score will decrease (_shutdown recommendations only_).
`AzureOptimization_PerfThresholdDtuPercentage` | The DTU usage percentage threshold below which a SQL Database instance is considered underutilized.
`AzureOptimization_RecommendAdvisorPeriodInDays` | The interval in days to look for Advisor recommendations in the Log Analytics repository - the default is 7, as Advisor recommendations are collected once a week.
`AzureOptimization_RecommendationAADMaxCredValidityYears` | The maximum number of years for a Service Principal credential/certificate validity - any validity above this interval will generate a Security recommendation. Defaults to 2.
`AzureOptimization_RecommendationAADMinCredValidityDays` | The minimum number of days for a Service Principal credential/certificate before it expires - any validity below this interval will generate an Operational Excellence recommendation. Defaults to 30.
`AzureOptimization_RecommendationLongDeallocatedVmsIntervalDays` | The number of consecutive days a VM has been deallocated before being recommended for deletion (_Virtual Machine has been deallocated for long with disks still incurring costs_). Defaults to 30.
`AzureOptimization_RecommendationVNetSubnetMaxUsedPercentageThreshold` | The maximum percentage tolerated for subnet IP space usage. Defaults to 80.
`AzureOptimization_RecommendationVNetSubnetMinUsedPercentageThreshold` | The minimum percentage for subnet IP space usage - any usage below this value will flag the respective subnet as using low IP space. Defaults to 5.
`AzureOptimization_RecommendationVNetSubnetEmptyMinAgeInDays` | The minimum age in days for an empty subnet to be flagged, thus avoiding flagging newly created subnets. Defaults to 30.
`AzureOptimization_RecommendationVNetSubnetUsedPercentageExclusions` | Comma-separated, single-quote enclosed list of subnet names that must be excluded from subnet usage percentage recommendations, e.g., 'gatewaysubnet','azurebastionsubnet'. Defaults to 'gatewaysubnet'.
`AzureOptimization_RecommendationRBACAssignmentsPercentageThreshold` | The maximum percentage of RBAC assignments limits usage. Defaults to 80.
`AzureOptimization_RecommendationResourceGroupsPerSubPercentageThreshold` | The maximum percentage of Resource Groups count per subscription limits usage. Defaults to 80.
`AzureOptimization_RecommendationRBACSubscriptionsAssignmentsLimit` | The maximum limit for RBAC assignments per subscription. Currently set to 2000 (as [documented](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-rbac-limits)).
`AzureOptimization_RecommendationRBACMgmtGroupsAssignmentsLimit` | The maximum limit for RBAC assignments per management group. Currently set to 500 (as [documented](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-rbac-limits)).
`AzureOptimization_RecommendationResourceGroupsPerSubLimit` | The maximum limit for Resource Group count per subscription. Currently set to 980 (as [documented](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-rbac-limits)).
`AzureOptimization_RecommendationStorageAcountGrowthThresholdPercentage` | The minimum Storage Account growth percentage required to flag Storage as not having a retention policy in place.
`AzureOptimization_RecommendationStorageAcountGrowthMonthlyCostThreshold` | The minimum monthly cost (in your EA/MCA currency) required to flag Storage as not having a retention policy in place.
`AzureOptimization_RecommendationStorageAcountGrowthLookbackDays` | The lookback period (in days) for analyzing Storage Account growth.
`AzureOptimization_ReferenceRegion` | The Azure region used as a reference for getting the list of available SKUs (defaults to `westeurope`).
`AzureOptimization_RemediateRightSizeMinFitScore` | The minimum fit score a VM right-size recommendation must have for the remediation to occur.
`AzureOptimization_RemediateRightSizeMinWeeksInARow` | The minimum number of weeks in a row a VM right-size recommendation must have been done for the remediation to occur.
`AzureOptimization_RemediateRightSizeTagsFilter` | The tag name/value pairs a VM right-size recommendation must have for the remediation to occur. Example: `[ { "tagName": "a", "tagValue": "b" }, { "tagName": "c", "tagValue": "d" } ]`
`AzureOptimization_RemediateLongDeallocatedVMsMinFitScore` | The minimum fit score a long deallocated VM recommendation must have for the remediation to occur.
`AzureOptimization_RemediateLongDeallocatedVMsMinWeeksInARow` | The minimum number of weeks in a row a long deallocated VM recommendation must have been done for the remediation to occur.
`AzureOptimization_RemediateLongDeallocatedVMsTagsFilter` | The tag name/value pairs a long deallocated VM recommendation must have for the remediation to occur. Example: `[ { "tagName": "a", "tagValue": "b" }, { "tagName": "c", "tagValue": "d" } ]`
`AzureOptimization_RemediateUnattachedDisksMinFitScore` | The minimum fit score an unattached disk recommendation must have for the remediation to occur.
`AzureOptimization_RemediateUnattachedDisksMinWeeksInARow` | The minimum number of weeks in a row an unattached disk recommendation must have been done for the remediation to occur.
`AzureOptimization_RemediateUnattachedDisksAction` | The action to apply for an unattached disk recommendation remediation (`Delete` or `Downsize`).
`AzureOptimization_RemediateUnattachedDisksTagsFilter` | The tag name/value pairs an unattached disk recommendation must have for the remediation to occur. Example: `[ { "tagName": "a", "tagValue": "b" }, { "tagName": "c", "tagValue": "d" } ]`
`AzureOptimization_RightSizeAdditionalPerfWorkspaces` | A comma-separated list of additional Log Analytics workspace IDs where to look for VM metrics (see [Configuring workspaces](./configuring-workspaces.md)).
`AzureOptimization_PerfThresholdDiskIOPSPercentage` | The disk IOPS usage percentage threshold below which the underutilized Premium SSD disks recommendation will trigger.
`AzureOptimization_PerfThresholdDiskMBsPercentage` | The disk throughput usage percentage threshold below which the underutilized Premium SSD disks recommendation will trigger.
`AzureOptimization_RecommendationsMaxAgeInDays` | The maximum age (in days) for a recommendation to be kept in the SQL database. Default: 365.
`AzureOptimization_RetailPricesCurrencyCode` | The currency code (e.g., EUR, USD, etc.) used to collect the Reservations retail prices.
`AzureOptimization_PriceSheetMeterCategories` | The comma-separated meter categories used for Pricesheet filtering, in order to avoid ingesting unnecessary data. Defaults to "Virtual Machines,Storage"
`AzureOptimization_ConsumptionScope` | The scope of the consumption exports: `Subscription` (default), `BillingProfile` (MCA only) or `BillingAccount` (for MCA, requires adding the Billing Account Reader role to the AOE managed identity). See [more details](./setup-options.md#-enabling-azure-commitments-workbooks).
