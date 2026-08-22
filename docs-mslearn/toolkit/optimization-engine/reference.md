---
title: Azure optimization engine reference
description: Reference to the optimization engine tables, runbooks, schedules, and variables.
author: flanakin
ms.author: micflan
ms.date: 08/22/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: hepint
#customer intent: As a FinOps user, I want to understand the Azure optimization engine reference tables, runbooks, schedules, and variables.
---

# Azure optimization engine reference

# Runbooks

Azure Optimization Engine runbooks form a data pipeline. Export runbooks collect Azure data as CSV files in Azure Storage. Ingestion runbooks load the exported data into Log Analytics or Azure SQL Database. Recommendation runbooks query Log Analytics and export recommendations as JSON files, which are then ingested into Log Analytics and Azure SQL Database. Maintenance and optional remediation runbooks operate on the recommendations stored in Azure SQL Database.

## Data collection runbooks

| Runbook | Description | Upstream dependencies | Downstream dependencies |
| --- | --- | --- | --- |
| `Export-AADObjectsToBlobStorage` | Exports Microsoft Entra ID objects as CSV to Azure Storage. | `AzureOptimization_ExportAADObjectsDaily` schedule and `Global Reader` role in the Microsoft Entra ID tenant | `Identities and Roles` workbook and `Recommend-AADExpiringCredentialsToBlobStorage` runbook |
| `Export-AdvisorRecommendationsToBlobStorage` | Exports Azure Advisor recommendations as CSV to Azure Storage. | `AzureOptimization_ExportAdvisorWeekly` schedule and `Reader` role in the subscriptions | `Recommend-AdvisorAsIsToBlobStorage` and `Recommend-AdvisorCostAugmentedToBlobStorage` runbooks |
| `Export-ARGAppGatewayPropertiesToBlobStorage` | Exports Application Gateway properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-UnusedAppGWsToBlobStorage` runbook and `Resources Inventory` workbook |
| `Export-ARGAppServicePlanPropertiesToBlobStorage` | Exports App Service plan properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-AppServiceOptimizationsToBlobStorage` runbook and `Resources Inventory` workbook |
| `Export-ARGAvailabilitySetPropertiesToBlobStorage` | Exports availability set properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-VMsHighAvailabilityToBlobStorage` runbook |
| `Export-ARGLoadBalancerPropertiesToBlobStorage` | Exports load balancer properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-UnusedLoadBalancersToBlobStorage` runbook and `Resources Inventory` workbook |
| `Export-ARGManagedDisksPropertiesToBlobStorage` | Exports managed disk properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-DiskOptimizationsToBlobStorage`, `Recommend-UnattachedDisksToBlobStorage`, and `Recommend-VMOptimizationsToBlobStorage` runbooks and `Resources Inventory` workbook |
| `Export-ARGNICPropertiesToBlobStorage` | Exports network interface properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-VNetOptimizationsToBlobStorage` runbook and `Resources Inventory` workbook |
| `Export-ARGNSGPropertiesToBlobStorage` | Exports network security group properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-VNetOptimizationsToBlobStorage` runbook and `Resources Inventory` workbook |
| `Export-ARGPublicIpPropertiesToBlobStorage` | Exports public IP address properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-VNetOptimizationsToBlobStorage` runbook and `Resources Inventory` workbook |
| `Export-ARGResourceContainersPropertiesToBlobStorage` | Exports subscription and resource group properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | All runbooks and workbooks except `Export-AADObjectsToBlobStorage` and the `Identities and Roles` workbook |
| `Export-ARGSqlDatabasePropertiesToBlobStorage` | Exports Azure SQL Database properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-SqlDbOptimizationsToBlobStorage` runbook and `Resources Inventory` workbook |
| `Export-ARGUnmanagedDisksPropertiesToBlobStorage` | Exports unmanaged disk properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-VMsHighAvailabilityToBlobStorage` runbook and `Resources Inventory` workbook |
| `Export-ARGVirtualMachinesPropertiesToBlobStorage` | Exports virtual machine properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-AdvisorCostAugmentedToBlobStorage`, `Recommend-VMOptimizationsToBlobStorage`, and `Recommend-VMsHighAvailabilityToBlobStorage` runbooks and `Resources Inventory` workbook |
| `Export-ARGVMSSPropertiesToBlobStorage` | Exports Virtual Machine Scale Set properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-VMsHighAvailabilityToBlobStorage` and `Recommend-VMSSOptimizationsToBlobStorage` runbooks and `Resources Inventory` workbook |
| `Export-ARGVNetPropertiesToBlobStorage` | Exports virtual network properties from Azure Resource Graph as CSV to Azure Storage. | `AzureOptimization_ExportARGDaily` schedule and `Reader` role in the subscriptions | `Recommend-VNetOptimizationsToBlobStorage` runbook and `Resources Inventory` workbook |
| `Export-AzMonitorMetricsToBlobStorage` | Exports Azure Monitor metrics for supported resource types as CSV to Azure Storage. Different schedules invoke the runbook with resource type, metric, aggregation, and time-grain parameters. | `AzureOptimization_ExportMonitor*` schedules and `Reader` role in the subscriptions | `Recommend-AppServiceOptimizationsToBlobStorage`, `Recommend-DiskOptimizationsToBlobStorage`, `Recommend-SqlDbOptimizationsToBlobStorage`, and `Recommend-VMSSOptimizationsToBlobStorage` runbooks |
| `Export-ConsumptionToBlobStorage` | Exports Azure billing event details as CSV to Azure Storage. | `AzureOptimization_ConsumptionOffsetDays` variable, `AzureOptimization_ExportConsumptionDaily` schedule, and `Reader` role in the subscriptions or EA/MCA billing account or profile | Cost recommendation runbooks and billing-related workbooks |
| `Export-PolicyComplianceToBlobStorage` | Exports Azure Policy compliance state details as CSV to Azure Storage. | `AzureOptimization_ExportPolicyStateDaily` schedule and `Reader` role in the subscriptions | `Policy Compliance` workbook |
| `Export-PriceSheetToBlobStorage` | Exports EA or MCA price sheet details as CSV to Azure Storage. | Price sheet and billing account variables, `AzureOptimization_ExportPricesWeekly` schedule, and `Reader` role in the EA or MCA billing account or profile. This runbook isn't compatible with non-EA/MCA deployments. | `Benefits Simulation`, `Benefits Usage`, `Reservations Potential`, `Reservations Usage`, and `Savings Plans Usage` workbooks |
| `Export-RBACAssignmentsToBlobStorage` | Exports Azure RBAC and Microsoft Entra role assignments as CSV to Azure Storage. | `AzureOptimization_ExportRBACDaily` schedule, `Reader` role in the subscriptions, and `Global Reader` role in the Microsoft Entra ID tenant | `Identities and Roles` and `Resources Inventory` workbooks and `Recommend-ARMOptimizationsToBlobStorage` runbook |
| `Export-ReservationsPriceToBlobStorage` | Exports Azure Reservations prices from the Azure Retail Prices API as CSV to Azure Storage. | `AzureOptimization_RetailPricesCurrencyCode` variable and `AzureOptimization_ExportPricesWeekly` schedule | `Benefits Simulation`, `Benefits Usage`, `Reservations Potential`, and `Reservations Usage` workbooks |
| `Export-ReservationsUsageToBlobStorage` | Exports Azure Reservations usage details as CSV to Azure Storage. | Billing account variables, `AzureOptimization_ExportReservationsDaily` schedule, and `Reader` role in the EA or MCA billing account or profile. This runbook isn't compatible with non-EA/MCA deployments. | `Reservations Usage` workbook |
| `Export-SavingsPlansUsageToBlobStorage` | Exports Azure savings plan usage details as CSV to Azure Storage. | Billing account variables, `AzureOptimization_ExportSavingsPlansDaily` schedule, and `Reader` role in the EA or MCA billing account or profile. This runbook isn't compatible with non-EA/MCA deployments. | `Savings Plans Usage` workbook |

## Data ingestion runbooks

| Runbook | Description | Upstream dependencies | Downstream dependencies |
| --- | --- | --- | --- |
| `Ingest-OptimizationCSVExportsToLogAnalytics` | Ingests CSV files from the Azure Storage container specified by the `StorageSinkContainer` schedule parameter into the corresponding Log Analytics table. It uses the table, stream, and data collection rule (DCR) mappings in the `LogAnalyticsIngestControl` table. | `AzureOptimization_Ingest*` schedules, Azure SQL Database, `AzureOptimization_DCEIngestionEndpoint`, and the deployed data collection endpoint (DCE) and DCRs | Recommendation runbooks and workbooks |
| `Ingest-RecommendationsToLogAnalytics` | Ingests recommendation JSON files from Azure Storage into the recommendations table in Log Analytics by using the Logs Ingestion API. | `AzureOptimization_IngestRecommendationsWeekly` schedule, Azure SQL Database, `AzureOptimization_DCEIngestionEndpoint`, and the recommendations DCR | Recommendations workbook |
| `Ingest-RecommendationsToSQLServer` | Ingests recommendation JSON files from Azure Storage into the `Recommendations` table in Azure SQL Database. | `AzureOptimization_IngestRecommendationsWeekly` schedule and recommendation JSON files generated by the `Recommend-*` runbooks | Recommendation cleanup, suppression, and remediation runbooks and Power BI reports |
| `Ingest-SuppressionsToLogAnalytics` | Ingests user-created recommendation suppressions from the `Filters` table in Azure SQL Database into Log Analytics by using the Logs Ingestion API. | `AzureOptimization_IngestSuppressionsWeekly` schedule, Azure SQL Database, `AzureOptimization_DCEIngestionEndpoint`, and the suppressions DCR | Recommendations workbook |

## Recommendation runbooks

Recommendation runbooks run on the `AzureOptimization_RecommendationsWeekly` schedule. They query data in Log Analytics, export recommendation JSON files to Azure Storage, and depend on `Ingest-RecommendationsToLogAnalytics` and `Ingest-RecommendationsToSQLServer` to make the results available to downstream experiences.

| Runbook | Recommendations generated | Primary source data |
| --- | --- | --- |
| `Recommend-AADExpiringCredentialsToBlobStorage` | Microsoft Entra application and service principal credentials that are expired, expiring, or have long validity periods | Microsoft Entra ID objects |
| `Recommend-AdvisorAsIsToBlobStorage` | Azure Advisor recommendations without additional augmentation | Azure Advisor recommendations |
| `Recommend-AdvisorCostAugmentedToBlobStorage` | Azure Advisor cost recommendations augmented with resource, usage, and cost context | Azure Advisor recommendations, resource inventory, consumption, and performance data |
| `Recommend-AppServiceOptimizationsToBlobStorage` | App Service plan performance and right-sizing opportunities | App Service plan properties, Azure Monitor metrics, and consumption data |
| `Recommend-ARMOptimizationsToBlobStorage` | Subscription, resource group, and role assignment governance opportunities | Resource containers and role assignments |
| `Recommend-DiskOptimizationsToBlobStorage` | Managed disk performance and right-sizing opportunities | Managed disk properties, Azure Monitor metrics, and consumption data |
| `Recommend-SqlDbOptimizationsToBlobStorage` | Azure SQL Database performance and right-sizing opportunities | Azure SQL Database properties, Azure Monitor metrics, and consumption data |
| `Recommend-StorageAccountOptimizationsToBlobStorage` | Storage account cost-growth opportunities | Consumption data |
| `Recommend-UnattachedDisksToBlobStorage` | Unattached managed disks | Managed disk properties and consumption data |
| `Recommend-UnusedAppGWsToBlobStorage` | Unused Application Gateways | Application Gateway properties and consumption data |
| `Recommend-UnusedLoadBalancersToBlobStorage` | Unused load balancers | Load balancer properties and consumption data |
| `Recommend-VMOptimizationsToBlobStorage` | Virtual machine optimization opportunities, including long-deallocated virtual machines | Virtual machine properties, managed disk properties, and consumption data |
| `Recommend-VMsHighAvailabilityToBlobStorage` | Virtual machine and Virtual Machine Scale Set high-availability opportunities | Virtual machines, scale sets, availability sets, and unmanaged disks |
| `Recommend-VMSSOptimizationsToBlobStorage` | Virtual Machine Scale Set performance and right-sizing opportunities | Scale set properties, Azure Monitor metrics, and consumption data |
| `Recommend-VNetOptimizationsToBlobStorage` | Virtual network, subnet, network interface, network security group, and public IP address optimization opportunities | Virtual network and related networking resource properties |

## Maintenance runbooks

| Runbook | Description | Upstream dependencies | Downstream dependencies |
| --- | --- | --- | --- |
| `CleanUp-OlderRecommendationsFromSqlServer` | Deletes recommendations older than the configured retention period from Azure SQL Database. The default retention period is 365 days. | `AzureOptimization_RecommendationsMaxAgeInDays` variable and `AzureOptimization_CleanUpRecommendationsWeekly` schedule | Azure SQL Database storage and recommendation history |

## Remediation runbooks

Remediation runbooks aren't scheduled by default. They query the `Recommendations` table in Azure SQL Database for recommendations that meet the configured fit-score and recurrence thresholds. Depending on the configured action, a runbook can simulate or perform remediation. Each runbook exports its results as CSV to Azure Storage for ingestion into the remediation log table in Log Analytics.

| Runbook | Remediation | Key configuration |
| --- | --- | --- |
| `Remediate-AdvisorRightSizeFiltered` | Applies or simulates selected Azure Advisor virtual machine right-sizing recommendations. | Minimum fit score and number of consecutive weeks |
| `Remediate-LongDeallocatedVMsFiltered` | Applies or simulates remediation of virtual machines that have remained deallocated. | Minimum fit score and number of consecutive weeks |
| `Remediate-UnattachedDisksFiltered` | Applies or simulates remediation of unattached managed disks. | Minimum fit score, number of consecutive weeks, and remediation action |

Runbooks authenticate with a system-assigned managed identity by default. Set `AzureOptimization_AuthenticationOption` to `UserAssignedManagedIdentity` and configure `AzureOptimization_UAMIClientID` to use a user-assigned managed identity. `AzureOptimization_CloudEnvironment` selects the Azure cloud and defaults to `AzureCloud`.

The runbooks use different deployment-specific variables based on their function:

- Export and recommendation runbooks use `AzureOptimization_StorageSink` and the applicable container variables.
- Recommendation runbooks use the applicable `AzureOptimization_LogAnalyticsWorkspace*` variables to query Log Analytics.
- Runbooks that access Azure SQL Database use `AzureOptimization_SQLServerHostname`; `AzureOptimization_SQLServerDatabase` defaults to `azureoptimization`.
- Runbooks that ingest data into Log Analytics use `AzureOptimization_DCEIngestionEndpoint` and the DCR mappings stored in Azure SQL Database.

See [Variables](#variables) for more details.

<br>

# Schedules

Schedule start times are calculated from the deployment time by using the offsets defined in the deployment manifest. You can reschedule any runbook after deployment.

| Schedule | Frequency | Linked runbooks | Notes |
| --- | --- | --- | --- |
| `AzureOptimization_ExportAADObjectsDaily` | Daily | `Export-AADObjectsToBlobStorage` | Exports Microsoft Entra ID objects. |
| `AzureOptimization_IngestAADObjectsDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `aadobjectsexports` as the `StorageSinkContainer`. |
| `AzureOptimization_ExportAdvisorWeekly` | Weekly | `Export-AdvisorRecommendationsToBlobStorage` | Exports Azure Advisor recommendations. |
| `AzureOptimization_IngestAdvisorWeekly` | Weekly | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `advisorexports` as the `StorageSinkContainer`. |
| `AzureOptimization_ExportARGDaily` | Daily | All `Export-ARG*` runbooks | Exports Azure Resource Graph datasets. |
| `AzureOptimization_ExportPolicyStateDaily` | Daily | `Export-PolicyComplianceToBlobStorage` | Exports Azure Policy compliance states. |
| `AzureOptimization_IngestARGAppGWsDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argappgwexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGAvailSetsDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argavailsetexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGLoadBalancersDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `arglbexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGDisksDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argdiskexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGPublicIPsDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argpublicipexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGNICsDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argnicexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGNSGsDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argnsgexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGVNetsDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argvnetexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGVHDsDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argvhdexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGVMsDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argvmexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGVMSSDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argvmssexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGSqlDbDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argsqldbexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGAppServicePlanDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argappserviceplanexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestPolicyStateDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `policystateexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestARGResourceContainersDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `argrescontainersexports` as the `StorageSinkContainer`. |
| `AzureOptimization_ExportConsumptionDaily` | Daily | `Export-ConsumptionToBlobStorage` | Billing-account export requires EA or MCA access. |
| `AzureOptimization_IngestConsumptionDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `consumptionexports` as the `StorageSinkContainer`. |
| `AzureOptimization_ExportRBACDaily` | Daily | `Export-RBACAssignmentsToBlobStorage` | Exports Azure RBAC and Microsoft Entra role assignments. |
| `AzureOptimization_IngestRBACDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `rbacexports` as the `StorageSinkContainer`. |
| `AzureOptimization_RecommendationsWeekly` | Weekly | All `Recommend-*` runbooks | Generates recommendation JSON files. |
| `AzureOptimization_IngestRecommendationsWeekly` | Weekly | `Ingest-RecommendationsToLogAnalytics`, `Ingest-RecommendationsToSQLServer` | Ingests generated recommendations into Log Analytics and Azure SQL Database. |
| `AzureOptimization_IngestSuppressionsWeekly` | Weekly | `Ingest-SuppressionsToLogAnalytics` | Synchronizes recommendation suppressions from Azure SQL Database. |
| `AzureOptimization_IngestRemediationLogsDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `remediationlogs` as the `StorageSinkContainer`. |
| `AzureOptimization_ExportMonitorVmssCpuMaxHourly` | Hourly | `Export-AzMonitorMetricsToBlobStorage` | Exports maximum Virtual Machine Scale Set CPU. |
| `AzureOptimization_ExportMonitorVmssCpuAvgHourly` | Hourly | `Export-AzMonitorMetricsToBlobStorage` | Exports average Virtual Machine Scale Set CPU. |
| `AzureOptimization_ExportMonitorVmssMemoryMinHourly` | Hourly | `Export-AzMonitorMetricsToBlobStorage` | Exports minimum available Virtual Machine Scale Set memory. |
| `AzureOptimization_ExportMonitorSqlDbDtuMaxHourly` | Hourly | `Export-AzMonitorMetricsToBlobStorage` | Exports maximum SQL Database DTU consumption. |
| `AzureOptimization_ExportMonitorSqlDbDtuAvgHourly` | Hourly | `Export-AzMonitorMetricsToBlobStorage` | Exports average SQL Database DTU consumption. |
| `AzureOptimization_ExportMonitorAppServiceCpuMaxHourly` | Hourly | `Export-AzMonitorMetricsToBlobStorage` | Exports maximum App Service plan CPU. |
| `AzureOptimization_ExportMonitorAppServiceCpuAvgHourly` | Hourly | `Export-AzMonitorMetricsToBlobStorage` | Exports average App Service plan CPU. |
| `AzureOptimization_ExportMonitorAppServiceMemoryMaxHourly` | Hourly | `Export-AzMonitorMetricsToBlobStorage` | Exports maximum App Service plan memory. |
| `AzureOptimization_ExportMonitorAppServiceMemoryAvgHourly` | Hourly | `Export-AzMonitorMetricsToBlobStorage` | Exports average App Service plan memory. |
| `AzureOptimization_ExportMonitorDiskIOPSHourly` | Hourly | `Export-AzMonitorMetricsToBlobStorage` | Exports IOPS for attached premium managed disks. |
| `AzureOptimization_ExportMonitorDiskMBPsHourly` | Hourly | `Export-AzMonitorMetricsToBlobStorage` | Exports throughput for attached premium managed disks. |
| `AzureOptimization_IngestAzMonitorMetricsHourly` | Hourly | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `azmonitorexports` as the `StorageSinkContainer`. |
| `AzureOptimization_CleanUpRecommendationsWeekly` | Weekly | `CleanUp-OlderRecommendationsFromSqlServer` | Deletes recommendations older than the configured retention period. |
| `AzureOptimization_ExportPricesWeekly` | Weekly | `Export-PriceSheetToBlobStorage`, `Export-ReservationsPriceToBlobStorage` | Price sheet export requires EA or MCA access. |
| `AzureOptimization_IngestPricesheetWeekly` | Weekly | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `pricesheetexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestReservationsPriceWeekly` | Weekly | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `reservationspriceexports` as the `StorageSinkContainer`. |
| `AzureOptimization_ExportReservationsDaily` | Daily | `Export-ReservationsUsageToBlobStorage` | Requires EA or MCA access. |
| `AzureOptimization_ExportSavingsPlansDaily` | Daily | `Export-SavingsPlansUsageToBlobStorage` | Requires EA or MCA access. |
| `AzureOptimization_IngestReservationsUsageDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `reservationsexports` as the `StorageSinkContainer`. |
| `AzureOptimization_IngestSavingsPlansUsageDaily` | Daily | `Ingest-OptimizationCSVExportsToLogAnalytics` | Uses `savingsplansexports` as the `StorageSinkContainer`. |

<br>

# Variables

| Variable | Description | Used in runbooks | Notes |
| --- | --- | --- | --- |
| `AzureOptimization_CloudEnvironment` | Azure cloud environment. | All runbooks | Defaults to `AzureCloud`. |
| `AzureOptimization_AuthenticationOption` | Runbook authentication type. | All runbooks | Defaults to `ManagedIdentity`; also supports `UserAssignedManagedIdentity`. |
| `AzureOptimization_UAMIClientID` | User-assigned managed identity client ID. | All runbooks | Required only with `UserAssignedManagedIdentity`. |
| `AzureOptimization_StorageSink` | Storage account used for exports. | Export, ingestion, recommendation, and remediation runbooks | Set by deployment. |
| `AzureOptimization_SQLServerHostname` | Azure SQL logical server hostname. | SQL-dependent runbooks | Set by deployment. |
| `AzureOptimization_SQLServerDatabase` | Azure SQL Database name. | SQL-dependent runbooks | Defaults to `azureoptimization`. |
| `AzureOptimization_LogAnalyticsWorkspaceId` | Log Analytics workspace ID. | `Recommend-*` runbooks | Set by deployment. |
| `AzureOptimization_LogAnalyticsWorkspaceName` | Log Analytics workspace name. | `Recommend-*` runbooks | Set by deployment. |
| `AzureOptimization_LogAnalyticsWorkspaceRG` | Log Analytics workspace resource group. | `Recommend-*` runbooks | Set by deployment. |
| `AzureOptimization_LogAnalyticsWorkspaceSubId` | Log Analytics workspace subscription ID. | `Recommend-*` runbooks | Set by deployment. |
| `AzureOptimization_LogAnalyticsWorkspaceTenantId` | Log Analytics workspace tenant ID. | `Recommend-*` runbooks | Set by deployment. |
| `AzureOptimization_LogAnalyticsWorkspaceKey` | Encrypted Log Analytics workspace shared key. | None of the current runbooks | Legacy variable (not deployed in current versions). If upgrading from older versions, it is removed; DCR ingestion uses managed identity. |
| `AzureOptimization_DCEIngestionEndpoint` | Logs Ingestion endpoint of the data collection endpoint. | Log Analytics ingestion runbooks | Set by deployment. |
| `AzureOptimization_LogAnalyticsChunkSize` | Rows per Logs Ingestion API request. | Log Analytics ingestion runbooks | Defaults to `150`. |
| `AzureOptimization_LogAnalyticsLogPrefix` | Prefix for custom Log Analytics tables. | Log Analytics ingestion runbooks | Defaults to `AzureOptimization`. |
| `AzureOptimization_StorageBlobsPageSize` | Blobs per storage listing page. | Ingestion runbooks | Defaults to `1000`. |
| `AzureOptimization_SQLServerInsertSize` | Rows per SQL insert batch. | `Ingest-RecommendationsToSQLServer` | Defaults to `900`. |
| `AzureOptimization_BillingAccountID` | EA or MCA billing account ID. | Billing export runbooks | Required for billing-account exports. |
| `AzureOptimization_BillingProfileID` | MCA billing profile ID. | Billing export runbooks | Required for MCA exports. |
| `AzureOptimization_ConsumptionOffsetDays` | Consumption query offset in days. | Consumption export and cost recommendation runbooks | Defaults to `3`. |
| `AzureOptimization_AdvisorFilter` | Advisor categories to export. | `Export-AdvisorRecommendationsToBlobStorage` | Defaults to `HighAvailability,Security,Performance,OperationalExcellence`. |
| `AzureOptimization_AADObjectsFilter` | Microsoft Entra object types to export. | `Export-AADObjectsToBlobStorage` | Defaults to `Application,ServicePrincipal,User,Group`. |
| `AzureOptimization_ReferenceRegion` | Reference region for VM size details. | Resource and recommendation runbooks | Defaults to the deployment region. |
| `AzureOptimization_PriceSheetMeterCategories` | Meter categories included in price sheet exports. | `Export-PriceSheetToBlobStorage` | Defaults to `Virtual Machines,Storage`; remove to include all. |
| `AzureOptimization_RetailPricesCurrencyCode` | Currency for retail price exports. | `Export-ReservationsPriceToBlobStorage` | Defaults to `EUR`. |
| `AzureOptimization_RecommendAdvisorPeriodInDays` | Advisor recommendation lookback period. | Advisor recommendation runbooks | Defaults to `7`. |
| `AzureOptimization_RecommendationLongDeallocatedVmsIntervalDays` | Minimum long-deallocated VM period. | `Recommend-VMOptimizationsToBlobStorage` | Defaults to `30` days. |
| `AzureOptimization_RecommendationAADMinCredValidityDays` | Minimum credential validity. | `Recommend-AADExpiringCredentialsToBlobStorage` | Defaults to `30` days. |
| `AzureOptimization_RecommendationAADMaxCredValidityYears` | Maximum credential validity. | `Recommend-AADExpiringCredentialsToBlobStorage` | Defaults to `2` years. |
| `AzureOptimization_RecommendationAdvisorCostRightSizeId` | Advisor VM right-size recommendation ID. | Advisor recommendation and remediation runbooks | Defaults to `e10b1381-5f0a-47ff-8c7b-37bd13d7c974`. |
| `AzureOptimization_RecommendationLongDeallocatedVMsId` | Long-deallocated VM recommendation ID. | VM recommendation and remediation runbooks | Defaults to `c320b790-2e58-452a-aa63-7b62c383ad8a`. |
| `AzureOptimization_RecommendationUnattachedDisksId` | Unattached disk recommendation ID. | Disk recommendation and remediation runbooks | Defaults to `c84d5e86-e2d6-4d62-be7c-cecfbd73b0db`. |
| `AzureOptimization_RecommendationRBACAssignmentsPercentageThreshold` | RBAC assignment limit threshold. | `Recommend-ARMOptimizationsToBlobStorage` | Defaults to `80` percent. |
| `AzureOptimization_RecommendationResourceGroupsPerSubPercentageThreshold` | Resource group limit threshold. | `Recommend-ARMOptimizationsToBlobStorage` | Defaults to `80` percent. |
| `AzureOptimization_RecommendationVNetSubnetMaxUsedPercentageThreshold` | Maximum subnet usage threshold. | `Recommend-VNetOptimizationsToBlobStorage` | Defaults to `80` percent. |
| `AzureOptimization_RecommendationVNetSubnetMinUsedPercentageThreshold` | Minimum subnet usage threshold. | `Recommend-VNetOptimizationsToBlobStorage` | Defaults to `5` percent. |
| `AzureOptimization_RecommendationVNetSubnetEmptyMinAgeInDays` | Minimum age for empty subnet recommendations. | `Recommend-VNetOptimizationsToBlobStorage` | Defaults to `30` days. |
| `AzureOptimization_RecommendationStorageAcountGrowthThresholdPercentage` | Storage growth threshold. | `Recommend-StorageAccountOptimizationsToBlobStorage` | Defaults to `5` percent. |
| `AzureOptimization_RecommendationStorageAcountGrowthMonthlyCostThreshold` | Storage monthly-cost threshold. | `Recommend-StorageAccountOptimizationsToBlobStorage` | Defaults to `50` in the billing currency. |
| `AzureOptimization_RecommendationStorageAcountGrowthLookbackDays` | Storage growth lookback period. | `Recommend-StorageAccountOptimizationsToBlobStorage` | Defaults to `30` days. |
| `AzureOptimization_RecommendationsMaxAgeInDays` | Recommendation retention period. | `CleanUp-OlderRecommendationsFromSqlServer` | Defaults to `365` days. |
| `AzureOptimization_RecommendationsContainer` | Recommendation export container. | Recommendation generation and ingestion runbooks | Optional; defaults to `recommendationsexports`. |
| `AzureOptimization_RemediationLogsContainer` | Remediation log container. | `Remediate-*` runbooks | Optional; defaults to `remediationlogs`. |
| `AzureOptimization_PerfPercentileCpu` | CPU analysis percentile. | Performance recommendation runbooks | Defaults to `99`. |
| `AzureOptimization_PerfPercentileMemory` | Memory analysis percentile. | Performance recommendation runbooks | Defaults to `99`. |
| `AzureOptimization_PerfPercentileNetwork` | Network analysis percentile. | Performance recommendation runbooks | Defaults to `99`. |
| `AzureOptimization_PerfPercentileDisk` | Disk analysis percentile. | Performance recommendation runbooks | Defaults to `99`. |
| `AzureOptimization_PerfPercentileSqlDtu` | SQL DTU analysis percentile. | `Recommend-SqlDbOptimizationsToBlobStorage` | Defaults to `99`. |
| `AzureOptimization_PerfThresholdCpuPercentage` | CPU underutilization threshold. | Performance recommendation runbooks | Defaults to `30` percent. |
| `AzureOptimization_PerfThresholdMemoryPercentage` | Memory underutilization threshold. | Performance recommendation runbooks | Defaults to `50` percent. |
| `AzureOptimization_PerfThresholdCpuDegradedMaxPercentage` | Maximum CPU degradation threshold. | App Service and VMSS recommendation runbooks | Defaults to `95` percent. |
| `AzureOptimization_PerfThresholdCpuDegradedAvgPercentage` | Average CPU degradation threshold. | App Service and VMSS recommendation runbooks | Defaults to `75` percent. |
| `AzureOptimization_PerfThresholdMemoryDegradedPercentage` | Memory degradation threshold. | App Service and VMSS recommendation runbooks | Defaults to `90` percent. |
| `AzureOptimization_PerfThresholdNetworkMbps` | Network fit-score threshold. | VM recommendation runbooks | Defaults to `750` Mbps. |
| `AzureOptimization_PerfThresholdCpuShutdownPercentage` | CPU threshold for shutdown scenarios. | VM recommendation runbooks | Defaults to `5` percent. |
| `AzureOptimization_PerfThresholdMemoryShutdownPercentage` | Memory threshold for shutdown scenarios. | VM recommendation runbooks | Defaults to `100` percent. |
| `AzureOptimization_PerfThresholdNetworkShutdownMbps` | Network threshold for shutdown scenarios. | VM recommendation runbooks | Defaults to `10` Mbps. |
| `AzureOptimization_PerfThresholdDtuPercentage` | SQL DTU underutilization threshold. | `Recommend-SqlDbOptimizationsToBlobStorage` | Defaults to `40` percent. |
| `AzureOptimization_PerfThresholdDtuDegradedPercentage` | SQL DTU degradation threshold. | `Recommend-SqlDbOptimizationsToBlobStorage` | Defaults to `75` percent. |
| `AzureOptimization_PerfThresholdDiskIOPSPercentage` | Disk IOPS underutilization threshold. | `Recommend-DiskOptimizationsToBlobStorage` | Defaults to `5` percent. |
| `AzureOptimization_PerfThresholdDiskMBsPercentage` | Disk throughput underutilization threshold. | `Recommend-DiskOptimizationsToBlobStorage` | Defaults to `5` percent. |
| `AzureOptimization_RemediateRightSizeMinFitScore` | Minimum fit score for VM right-size remediation. | `Remediate-AdvisorRightSizeFiltered` | Defaults to `5.0`. |
| `AzureOptimization_RemediateRightSizeMinWeeksInARow` | Required consecutive weeks for VM right-size remediation. | `Remediate-AdvisorRightSizeFiltered` | Defaults to `4`. |
| `AzureOptimization_RemediateRightSizeTagsFilter` | Optional tag filter for VM right-size remediation. | `Remediate-AdvisorRightSizeFiltered` | No filter by default. |
| `AzureOptimization_RemediateLongDeallocatedVMsMinFitScore` | Minimum fit score for long-deallocated VM remediation. | `Remediate-LongDeallocatedVMsFiltered` | Defaults to `5.0`. |
| `AzureOptimization_RemediateLongDeallocatedVMsMinWeeksInARow` | Required consecutive weeks for long-deallocated VM remediation. | `Remediate-LongDeallocatedVMsFiltered` | Defaults to `4`. |
| `AzureOptimization_RemediateLongDeallocatedVMsTagsFilter` | Optional tag filter for long-deallocated VM remediation. | `Remediate-LongDeallocatedVMsFiltered` | No filter by default. |
| `AzureOptimization_RemediateUnattachedDisksMinFitScore` | Minimum fit score for unattached disk remediation. | `Remediate-UnattachedDisksFiltered` | Defaults to `5.0`. |
| `AzureOptimization_RemediateUnattachedDisksMinWeeksInARow` | Required consecutive weeks for unattached disk remediation. | `Remediate-UnattachedDisksFiltered` | Defaults to `4`. |
| `AzureOptimization_RemediateUnattachedDisksAction` | Unattached disk remediation action. | `Remediate-UnattachedDisksFiltered` | Defaults to `Delete`; supports `Delete` or `Downsize`. |
| `AzureOptimization_RemediateUnattachedDisksTagsFilter` | Optional tag filter for unattached disk remediation. | `Remediate-UnattachedDisksFiltered` | No filter by default. |
| `AzureOptimization_AdvisorContainer` | Advisor export container. | Advisor export runbook | Defaults to `advisorexports`. |
| `AzureOptimization_ARGVMContainer` | Virtual machine export container. | Virtual machine export runbook | Defaults to `argvmexports`. |
| `AzureOptimization_ARGVMSSContainer` | Virtual Machine Scale Set export container. | Scale set export runbook | Defaults to `argvmssexports`. |
| `AzureOptimization_ARGDiskContainer` | Managed disk export container. | Managed disk export runbook | Defaults to `argdiskexports`. |
| `AzureOptimization_ARGVhdContainer` | Unmanaged disk export container. | Unmanaged disk export runbook | Defaults to `argvhdexports`. |
| `AzureOptimization_ARGAvailabilitySetContainer` | Availability set export container. | Availability set export runbook | Defaults to `argavailsetexports`. |
| `AzureOptimization_ConsumptionContainer` | Consumption export container. | Consumption export runbook | Defaults to `consumptionexports`. |
| `AzureOptimization_AADObjectsContainer` | Microsoft Entra object export container. | Microsoft Entra export runbook | Defaults to `aadobjectsexports`. |
| `AzureOptimization_ARGLoadBalancerContainer` | Load balancer export container. | Load balancer export runbook | Defaults to `arglbexports`. |
| `AzureOptimization_ARGAppGatewayContainer` | Application Gateway export container. | Application Gateway export runbook | Defaults to `argappgwexports`. |
| `AzureOptimization_ARGResourceContainersContainer` | Resource container export container. | Resource container export runbook | Defaults to `argrescontainersexports`. |
| `AzureOptimization_RBACAssignmentsContainer` | Role assignment export container. | RBAC export runbook | Defaults to `rbacexports`. |
| `AzureOptimization_ARGNICContainer` | Network interface export container. | Network interface export runbook | Defaults to `argnicexports`. |
| `AzureOptimization_ARGNSGContainer` | Network security group export container. | Network security group export runbook | Defaults to `argnsgexports`. |
| `AzureOptimization_ARGVNetContainer` | Virtual network export container. | Virtual network export runbook | Defaults to `argvnetexports`. |
| `AzureOptimization_ARGPublicIpContainer` | Public IP export container. | Public IP export runbook | Defaults to `argpublicipexports`. |
| `AzureOptimization_ARGSqlDatabaseContainer` | SQL Database export container. | SQL Database export runbook | Defaults to `argsqldbexports`. |
| `AzureOptimization_PolicyStatesContainer` | Policy state export container. | Policy export runbook | Defaults to `policystateexports`. |
| `AzureOptimization_AzMonitorContainer` | Azure Monitor metric export container. | Azure Monitor export runbook | Defaults to `azmonitorexports`. |
| `AzureOptimization_ARGAppServicePlanContainer` | App Service plan export container. | App Service plan export runbook | Defaults to `argappserviceplanexports`. |
| `AzureOptimization_PriceSheetContainer` | Price sheet export container. | Price sheet export runbook | Defaults to `pricesheetexports`. |
| `AzureOptimization_ReservationsPriceContainer` | Reservation price export container. | Reservation price export runbook | Defaults to `reservationspriceexports`. |
| `AzureOptimization_ReservationsContainer` | Reservation usage export container. | Reservation usage export runbook | Defaults to `reservationsexports`. |
| `AzureOptimization_SavingsPlansContainer` | Savings plan usage export container. | Savings plan usage export runbook | Defaults to `savingsplansexports`. |

Changing a container variable also requires updating the corresponding `StorageContainerName` mapping in the `LogAnalyticsIngestControl` table and the linked ingestion schedule's `StorageSinkContainer` parameter.

<br>

# Log Analytics tables

All tables are DCR-based custom tables. Most tables are populated from CSV files by `Ingest-OptimizationCSVExportsToLogAnalytics`. Recommendations are populated from JSON files by `Ingest-RecommendationsToLogAnalytics`, and suppressions are populated from Azure SQL Database by `Ingest-SuppressionsToLogAnalytics`.

| Table | Data stored | Origin storage container | Origin runbooks | Used in runbooks | Used in workbooks |
| --- | --- | --- | --- | --- | --- |
| `AzureOptimizationAADObjectsV1_CL` | Microsoft Entra ID users, groups, service principals, and applications | `aadobjectsexports` | `Export-AADObjectsToBlobStorage` | `Recommend-AADExpiringCredentialsToBlobStorage` | Identities and Roles |
| `AzureOptimizationAdvisorV1_CL` | Azure Advisor recommendations | `advisorexports` | `Export-AdvisorRecommendationsToBlobStorage` | `Recommend-AdvisorAsIsToBlobStorage`, `Recommend-AdvisorCostAugmentedToBlobStorage` | Recommendations |
| `AzureOptimizationAppGatewaysV1_CL` | Application Gateway properties | `argappgwexports` | `Export-ARGAppGatewayPropertiesToBlobStorage` | `Recommend-UnusedAppGWsToBlobStorage` | Resources Inventory |
| `AzureOptimizationAppServicePlansV1_CL` | App Service plan properties | `argappserviceplanexports` | `Export-ARGAppServicePlanPropertiesToBlobStorage` | `Recommend-AppServiceOptimizationsToBlobStorage` | Resources Inventory |
| `AzureOptimizationAvailSetsV1_CL` | Availability set properties | `argavailsetexports` | `Export-ARGAvailabilitySetPropertiesToBlobStorage` | `Recommend-VMsHighAvailabilityToBlobStorage` | Resources Inventory |
| `AzureOptimizationConsumptionV1_CL` | Azure billing and consumption details | `consumptionexports` | `Export-ConsumptionToBlobStorage` | Cost and performance `Recommend-*` runbooks | Billing and optimization workbooks |
| `AzureOptimizationDisksV1_CL` | Managed disk properties | `argdiskexports` | `Export-ARGManagedDisksPropertiesToBlobStorage` | `Recommend-DiskOptimizationsToBlobStorage`, `Recommend-UnattachedDisksToBlobStorage`, `Recommend-VMOptimizationsToBlobStorage` | Resources Inventory |
| `AzureOptimizationLoadBalancersV1_CL` | Load balancer properties | `arglbexports` | `Export-ARGLoadBalancerPropertiesToBlobStorage` | `Recommend-UnusedLoadBalancersToBlobStorage` | Resources Inventory |
| `AzureOptimizationMonitorMetricsV1_CL` | Azure Monitor performance metrics | `azmonitorexports` | `Export-AzMonitorMetricsToBlobStorage` | App Service, disk, SQL Database, and VMSS recommendation runbooks | Optimization workbooks |
| `AzureOptimizationNICsV1_CL` | Network interface properties | `argnicexports` | `Export-ARGNICPropertiesToBlobStorage` | `Recommend-VNetOptimizationsToBlobStorage` | Resources Inventory |
| `AzureOptimizationNSGsV1_CL` | Network security group properties and rules | `argnsgexports` | `Export-ARGNSGPropertiesToBlobStorage` | `Recommend-VNetOptimizationsToBlobStorage` | Resources Inventory |
| `AzureOptimizationPolicyStatesV1_CL` | Azure Policy compliance states | `policystateexports` | `Export-PolicyComplianceToBlobStorage` |  | Policy Compliance |
| `AzureOptimizationPricesheetV1_CL` | EA or MCA price sheet details | `pricesheetexports` | `Export-PriceSheetToBlobStorage` |  | Benefits Simulation, Benefits Usage, Reservations Potential, Reservations Usage, Savings Plans Usage |
| `AzureOptimizationPublicIPsV1_CL` | Public IP address properties | `argpublicipexports` | `Export-ARGPublicIpPropertiesToBlobStorage` | `Recommend-VNetOptimizationsToBlobStorage` | Resources Inventory |
| `AzureOptimizationRBACAssignmentsV1_CL` | Azure RBAC and Microsoft Entra role assignments | `rbacexports` | `Export-RBACAssignmentsToBlobStorage` | `Recommend-ARMOptimizationsToBlobStorage` | Identities and Roles, Resources Inventory |
| `AzureOptimizationRecommendationsV1_CL` | Generated optimization recommendations | `recommendationsexports` | All `Recommend-*` runbooks |  | Recommendations |
| `AzureOptimizationRemediationV1_CL` | Remediation execution results | `remediationlogs` | All `Remediate-*` runbooks |  | Remediation reporting |
| `AzureOptimizationReservationsPriceV1_CL` | Azure Reservations retail prices | `reservationspriceexports` | `Export-ReservationsPriceToBlobStorage` |  | Benefits Simulation, Benefits Usage, Reservations Potential, Reservations Usage |
| `AzureOptimizationReservationsUsageV1_CL` | Azure Reservations usage details | `reservationsexports` | `Export-ReservationsUsageToBlobStorage` |  | Reservations Usage |
| `AzureOptimizationResourceContainersV1_CL` | Subscription and resource group properties | `argrescontainersexports` | `Export-ARGResourceContainersPropertiesToBlobStorage` | Most `Recommend-*` runbooks | Resources Inventory and optimization workbooks |
| `AzureOptimizationSavingsPlansUsageV1_CL` | Azure savings plan usage details | `savingsplansexports` | `Export-SavingsPlansUsageToBlobStorage` |  | Savings Plans Usage |
| `AzureOptimizationSqlDbV1_CL` | Azure SQL Database properties | `argsqldbexports` | `Export-ARGSqlDatabasePropertiesToBlobStorage` | `Recommend-SqlDbOptimizationsToBlobStorage` | Resources Inventory |
| `AzureOptimizationSuppressionsV1_CL` | User-created recommendation suppressions | Not applicable; sourced from Azure SQL Database | `Ingest-SuppressionsToLogAnalytics` |  | Recommendations |
| `AzureOptimizationVhdDisksV1_CL` | Unmanaged disk properties | `argvhdexports` | `Export-ARGUnmanagedDisksPropertiesToBlobStorage` | `Recommend-VMsHighAvailabilityToBlobStorage` | Resources Inventory |
| `AzureOptimizationVMsV1_CL` | Virtual machine properties | `argvmexports` | `Export-ARGVirtualMachinesPropertiesToBlobStorage` | Advisor cost, VM optimization, and high-availability recommendation runbooks | Resources Inventory |
| `AzureOptimizationVMSSV1_CL` | Virtual Machine Scale Set properties | `argvmssexports` | `Export-ARGVMSSPropertiesToBlobStorage` | `Recommend-VMsHighAvailabilityToBlobStorage`, `Recommend-VMSSOptimizationsToBlobStorage` | Resources Inventory |
| `AzureOptimizationVNetsV1_CL` | Virtual network and subnet properties | `argvnetexports` | `Export-ARGVNetPropertiesToBlobStorage` | `Recommend-VNetOptimizationsToBlobStorage` | Resources Inventory |

<br>

# SQL Database tables

| Table | Data stored | Origin storage container | Origin runbooks | Used in runbooks | Used in Power BI |
| --- | --- | --- | --- | --- | --- |
| `Filters` | User-created recommendation suppressions | Not applicable | Created by the `Suppress-Recommendation` script | `Ingest-SuppressionsToLogAnalytics` and remediation runbooks | Yes |
| `LogAnalyticsIngestControl` | Storage-to-table mappings, DCR identifiers, and CSV ingestion progress | All CSV export containers | Initialized by deployment and updated by `Setup-LogAnalyticsTablesAndDCRs` | `Ingest-OptimizationCSVExportsToLogAnalytics`, `Ingest-RecommendationsToLogAnalytics`, `Ingest-SuppressionsToLogAnalytics` | No |
| `Recommendations` | Generated recommendations and resource context | `recommendationsexports` | All `Recommend-*` runbooks; populated by `Ingest-RecommendationsToSQLServer` | Cleanup and `Remediate-*` runbooks | Yes |
| `SqlServerIngestControl` | Recommendation JSON ingestion progress | `recommendationsexports` | Initialized by deployment | `Ingest-RecommendationsToSQLServer` | No |

<br>

## Related content

- [Get started with the Azure Optimization Engine](overview.md)
- [Customize Azure optimization engine](customize.md)
- [Troubleshoot Azure Optimization Engine issues](troubleshooting.md)