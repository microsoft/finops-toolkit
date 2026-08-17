---
title: Reference
description: Reference to the optimization engine tables, runbooks, schedules and variables.
author: flanakin
ms.author: micflan
ms.date: 08/17/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: hepint
#customer intent: As a FinOps user, I want to understand the Azure optimization engine reference tables, runbooks, schedules and variables.
---

# 🧿 Runbooks

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

See [Variables](#-variables) for more details.

<br>

# ⏰ Schedules

| Schedule                                    | Frequency                        | Linked runbooks                  | Notes                            |
| ------------------------------------------- | -------------------------------- | -------------------------------- | -------------------------------- |
| `AzureOptimization_CleanUpRecommendationsWeekly`      | Weekly                    | `CleanUp-OlderRecommendationsFromSqlServer` | Can be rescheduled and run anytime |

<br>

# 🧿 Variables

| Variable                                    | Description                      | Used in runbooks                 | Notes                            |
| ------------------------------------------- | -------------------------------- | -------------------------------- | -------------------------------- |
| `AzureOptimization_AADObjectsContainer`     | Name of the Storage container where Entra ID objects are exported to                    | `Export-AADObjectsToBlobStorage` | Changing its value requires you to update the respective row in the `LogAnalyticsIngestControl` SQL table |

<br>

# 🧿 Log Analytics tables

All Log Analytics tables depend on the successful execution of the `Ingest-OptimizationCSVExportsToLogAnalytics`

| Table                                       | Data stored         | Origin storage container  | Origin runbooks    | Used in runbooks   | Used in workbooks  |
| ------------------------------------------- | ------------------- | ------------------------- | ------------------ | ------------------ | ------------------ |
| `AzureOptimizationAADObjectsV1_CL`          | Entra ID objects (users, groups, service principals, applications)   | `aadobjectsexports` | `Export-AADObjectsToBlobStorage` |  | Identities and Roles |

<br>

# 🧿 SQL Database tables

| Table                                       | Data stored         | Origin storage container  | Origin runbooks    | Used in runbooks   | Used in Power BI   |
| ------------------------------------------- | ------------------- | ------------------------- | ------------------ | ------------------ | ------------------ |
| `Filters`                   | User-created recommendation suppressions       |  |  |  | yes |