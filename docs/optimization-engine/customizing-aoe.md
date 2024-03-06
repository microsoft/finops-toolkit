# Customizing the Azure Optimization Engine

There are many customization options available in AOE, in the form of Azure Automation variables. The list below is a highlight of the most relevant configuration variables. To access them, go to the Automation Account _Shared Resources - Variables_ menu option.

* `AzureOptimization_AdvisorFilter` - If you are not interested in getting recommendations for all the non-Cost Advisor pillars, you can specify a pillar-level filter (comma-separated list with at least one of the following: `HighAvailability,Security,Performance,OperationalExcellence`). Defaults to all pillars.
* `AzureOptimization_AuthenticationOption` - The default authentication method for Automation Runbooks is `RunAsAccount`. But you can change to `ManagedIdentity` if you're using a Hybrid Worker in an Azure VM.
* `AzureOptimization_ConsumptionOffsetDays` - The Azure Consumption data collection runbook queries each day for billing events that occurred 7 days ago (default). You can change to a closer offset, but bear in mind that some subscription types (e.g., MSDN) to not support a lower value.
* `AzureOptimization_PerfPercentileCpu` - The default percentile for CPU metrics aggregations is 99. The lower the percentile, the less conservative will be VM right-size fit score algorithm.
* `AzureOptimization_PerfPercentileDisk` - The default percentile for disk IO/throughput metrics aggregations is 99. The lower the percentile, the less conservative will be VM right-size fit score algorithm.
* `AzureOptimization_PerfPercentileMemory` - The default percentile for memory metrics aggregations is 99. The lower the percentile, the less conservative will be VM right-size fit score algorithm.
* `AzureOptimization_PerfPercentileNetwork` - The default percentile for network metrics aggregations is 99. The lower the percentile, the less conservative will be VM right-size fit score algorithm.
* `AzureOptimization_PerfPercentileSqlDtu` - The default percentile to be used for SQL DB DTU metrics. The lower the percentile, the less conservative will be the SQL Database right-size algorithm.
* `AzureOptimization_PerfThresholdCpuPercentage` - The CPU threshold (in % Processor Time) above which the VM right-size fit score will decrease or below which the VM scale set right-size Cost recommendation will trigger.
* `AzureOptimization_PerfThresholdCpuShutdownPercentage` - The CPU threshold (in % Processor Time) above which the VM right-size fit score will decrease (_shutdown recommendations only_).
* `AzureOptimization_PerfThresholdCpuDegradedMaxPercentage` - The CPU threshold (Maximum observed in % Processor Time) above which the VM scale set right-size Performance recommendation will trigger.
* `AzureOptimization_PerfThresholdCpuDegradedAvgPercentage` - The CPU threshold (Average observed in % Processor Time) above which the VM scale set right-size Performance recommendation will trigger.
* `AzureOptimization_PerfThresholdMemoryPercentage` - The memory threshold (in % Used Memory) above which the VM right-size fit score will decrease or below which the VM scale set right-size Cost recommendation will trigger.
* `AzureOptimization_PerfThresholdMemoryShutdownPercentage` - The memory threshold (in % Used Memory) above which the VM right-size fit score will decrease (_shutdown recommendations only_).
* `AzureOptimization_PerfThresholdMemoryDegradedPercentage` - The memory threshold (in % Used Memory) above which the VM scale set right-size Performance recommendation will trigger.
* `AzureOptimization_PerfThresholdNetworkMbps` - The network threshold (in Total Mbps) above which the VM right-size fit score will decrease.
* `AzureOptimization_PerfThresholdNetworkShutdownMbps` - The network threshold (in Total Mbps) above which the VM right-size fit score will decrease (_shutdown recommendations only_).
* `AzureOptimization_PerfThresholdDtuPercentage` - The DTU usage percentage threshold below which a SQL Database instance is considered underutilized.
* `AzureOptimization_RecommendAdvisorPeriodInDays` - The interval in days to look for Advisor recommendations in the Log Analytics repository - the default is 7, as Advisor recommendations are collected once a week.
* `AzureOptimization_RecommendationAADMaxCredValidityYears` - The maximum number of years for a Service Principal credential/certificate validity - any validity above this interval will generate a Security recommendation. Defaults to 2.
* `AzureOptimization_RecommendationAADMinCredValidityDays` - The minimum number of days for a Service Principal credential/certificate before it expires - any validity below this interval will generate an Operational Excellence recommendation. Defaults to 30.
* `AzureOptimization_RecommendationLongDeallocatedVmsIntervalDays` - The number of consecutive days a VM has been deallocated before being recommended for deletion (_Virtual Machine has been deallocated for long with disks still incurring costs_). Defaults to 30.
* `AzureOptimization_RecommendationVNetSubnetMaxUsedPercentageThreshold` - The maximum percentage tolerated for subnet IP space usage. Defaults to 80.
* `AzureOptimization_RecommendationVNetSubnetMinUsedPercentageThreshold` - The minimum percentage for subnet IP space usage - any usage below this value will flag the respective subnet as using low IP space. Defaults to 5.
* `AzureOptimization_RecommendationVNetSubnetEmptyMinAgeInDays` - The minimum age in days for an empty subnet to be flagged, thus avoiding flagging newly created subnets. Defaults to 30.
* `AzureOptimization_RecommendationVNetSubnetUsedPercentageExclusions` - Comma-separated, single-quote enclosed list of subnet names that must be excluded from subnet usage percentage recommendations, e.g., 'gatewaysubnet','azurebastionsubnet'. Defaults to 'gatewaysubnet'.
* `AzureOptimization_RecommendationRBACAssignmentsPercentageThreshold` - The maximum percentage of RBAC assignments limits usage. Defaults to 80.
* `AzureOptimization_RecommendationResourceGroupsPerSubPercentageThreshold` - The maximum percentage of Resource Groups count per subscription limits usage. Defaults to 80.
* `AzureOptimization_RecommendationRBACSubscriptionsAssignmentsLimit` - The maximum limit for RBAC assignments per subscription. Currently set to 2000 (as [documented](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-rbac-limits)).
* `AzureOptimization_RecommendationRBACMgmtGroupsAssignmentsLimit` - The maximum limit for RBAC assignments per management group. Currently set to 500 (as [documented](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-rbac-limits)).
* `AzureOptimization_RecommendationResourceGroupsPerSubLimit` - The maximum limit for Resource Group count per subscription. Currently set to 980 (as [documented](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#subscription-limits)).
* `AzureOptimization_RecommendationStorageAcountGrowthThresholdPercentage` - The minimum Storage Account growth percentage required to flag Storage as not having a retention policy in place.
* `AzureOptimization_RecommendationStorageAcountGrowthMonthlyCostThreshold` - The minimum monthly cost (in your EA/MCA currency) required to flag Storage as not having a retention policy in place.
* `AzureOptimization_RecommendationStorageAcountGrowthLookbackDays` - The lookback period (in days) for analyzing Storage Account growth.
* `AzureOptimization_ReferenceRegion` - The Azure region used as a reference for getting the list of available SKUs (defaults to `westeurope`).
* `AzureOptimization_RemediateRightSizeMinFitScore` - The minimum fit score a VM right-size recommendation must have for the remediation to occur.
* `AzureOptimization_RemediateRightSizeMinWeeksInARow` - The minimum number of weeks in a row a VM right-size recommendation must have been done for the remediation to occur.
* `AzureOptimization_RemediateRightSizeTagsFilter` - The tag name/value pairs a VM right-size recommendation must have for the remediation to occur. Example: `[ { "tagName": "a", "tagValue": "b" }, { "tagName": "c", "tagValue": "d" } ]`
* `AzureOptimization_RemediateLongDeallocatedVMsMinFitScore` - The minimum fit score a long deallocated VM recommendation must have for the remediation to occur.
* `AzureOptimization_RemediateLongDeallocatedVMsMinWeeksInARow` - The minimum number of weeks in a row a long deallocated VM recommendation must have been done for the remediation to occur.
* `AzureOptimization_RemediateLongDeallocatedVMsTagsFilter` - The tag name/value pairs a long deallocated VM recommendation must have for the remediation to occur. Example: `[ { "tagName": "a", "tagValue": "b" }, { "tagName": "c", "tagValue": "d" } ]`
* `AzureOptimization_RemediateUnattachedDisksMinFitScore` - The minimum fit score an unattached disk recommendation must have for the remediation to occur.
* `AzureOptimization_RemediateUnattachedDisksMinWeeksInARow` - The minimum number of weeks in a row an unattached disk recommendation must have been done for the remediation to occur.
* `AzureOptimization_RemediateUnattachedDisksAction` - The action to apply for an unattached disk recommendation remediation (`Delete` or `Downsize`).
* `AzureOptimization_RemediateUnattachedDisksTagsFilter` - The tag name/value pairs an unattached disk recommendation must have for the remediation to occur. Example: `[ { "tagName": "a", "tagValue": "b" }, { "tagName": "c", "tagValue": "d" } ]`
* `AzureOptimization_RightSizeAdditionalPerfWorkspaces` - A comma-separated list of additional Log Analytics workspace IDs where to look for VM metrics (see [Configuring Log Analytics workspaces](./configuring-workspaces.md)).
* `AzureOptimization_PerfThresholdDiskIOPSPercentage` - The disk IOPS usage percentage threshold below which the underutilized Premium SSD disks recommendation will trigger.
* `AzureOptimization_PerfThresholdDiskMBsPercentage` - The disk throughput usage percentage threshold below which the underutilized Premium SSD disks recommendation will trigger.
* `AzureOptimization_RecommendationsMaxAgeInDays` - The maximum age (in days) for a recommendation to be kept in the SQL database. Default: 365.
* `AzureOptimization_RetailPricesCurrencyCode` - The currency code (e.g., EUR, USD, etc.) used to collect the Reservations retail prices.
* `AzureOptimization_PriceSheetMeterCategories` - The comma-separated meter categories used for Pricesheet filtering, in order to avoid ingesting unnecessary data. Defaults to "Virtual Machines,Storage"
* `AzureOptimization_ConsumptionScope` - The scope of the consumption exports: `Subscription` (default) or `BillingAccount`. See [more details](#enabling-the-reservations-and-benefits-usage-workbooks).
