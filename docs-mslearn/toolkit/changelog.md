---
title: FinOps toolkit changelog
description: Review the latest features and enhancements in the FinOps toolkit, including updates to FinOps hubs, Power BI reports, and more.
author: bandersmsft
ms.author: banders
ms.date: 02/18/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what changes were made in the latest FinOps toolkit releases.
---

<!-- cSpell:ignore nextstepaction -->
<!-- markdownlint-disable MD036 -->
<!-- markdownlint-disable-next-line MD025 -->
# FinOps toolkit changelog

This article summarizes the features and enhancements in each release of the FinOps toolkit.

<br>

## Unreleased

The following section lists features and enhancements that are currently in development.

### Bicep Registry module pending updates

- Cost Management export modules for subscriptions and resource groups.

### Optimization engine

- **Fixed**
  - Fixed issue with breaking storage account recommendations when resource tags are duplicated after tag inheritance  ([#1430](https://github.com/microsoft/finops-toolkit/issues/1430)).

<br><a name="latest"></a>

## v0.9

_Released March 2025_

### [Power BI reports](power-bi/reports.md) v0.9

**General**

- **Added**
  - Added support for promoted tags with spaces in the tag key.
- **Changed**
  - Updated the savings columns to exclude rows where costs are missing or incorrect.
  - Disabled the **Deprecated: Perform Extra Query Optimizations** parameter by default ([#1380](https://github.com/microsoft/finops-toolkit/issues/1380)).
    - This parameter will be removed on or after July 1, 2025.
    - If you rely on this setting, please [create an issue in GitHub](https://aka.ms/ftk/ideas) and let us know what you need.
- **Fixed**
  - Fixed the "The import Storage URL matches no exports" error ([#1344](https://github.com/microsoft/finops-toolkit/issues/1344)).
  - Added resource-specific tags to the stop all triggers deployment script ([#1330](https://github.com/microsoft/finops-toolkit/issues/1330))

**[Rate optimization](power-bi/rate-optimization.md)**

- **Added**
  - Added support for MCA reservation recommendation exports.
- **Fixed**
  - Fixed core count double-counting on the Hybrid Benefit page.
  - Fixed savings to include negotiated discounts on the Total savings page.

### [FinOps hubs](hubs/finops-hubs-overview.md) v0.9

- **Added**
  - Added support for MCA reservation recommendation exports.
  - Added support for multiple reservation recommendation exports to support shared and single recommendations for all services and lookback periods.
  - Managed exports now create price, reservation detail, reservation transaction, and VM reservation recommendation exports.
  - Documented the roles that will be assigned as part of the deployment in the [template details](./hubs/template.md).
- **Changed**
  - Changed the deployment template to only deploy Key Vault when configured as a remote hub.
    - This will not remove existing Key Vault instances. Please delete them manually if not using this instance as a remote (secondary) hub.
  - Added a new Data ingestion > Data quality section into the Data Explorer dashboard with a summary of missing and incorrect costs.
- **Fixed**
  - Added resource-specific tags to the stop all triggers deployment script ([#1330](https://github.com/microsoft/finops-toolkit/issues/1330))
  - Updated the deployment script to set the settings.json scopes property to an array ([#1237](https://github.com/microsoft/finops-toolkit/issues/1237)).
  - Fixed an issue where the Data Explorer cluster could not update when re-deployed ([#1350](https://github.com/microsoft/finops-toolkit/issues/1350)).
  - Removed spaces from the MCA reservation recommendations export column names ([#1317](https://github.com/microsoft/finops-toolkit/issues/1317)).
  - Fixed an issue where reservation recommendations were being duplicated for the Canada Central region.
  - Fixed an issue where Recommendations.x_IngestionTime is not being populated in Data Explorer.
- **Removed**
  - Removed the Managed Identity Contributor permission assigned to managed identities used during the deployment ([#1248](https://github.com/microsoft/finops-toolkit/issues/1248)).
    - The deployment cannot remove role assignments. You can safely remove role assignments from the managed identities to limit access.
    - Please do not delete the managed identities. Deleting managed identities can result in errors during upgrades.
  - Removed the trusted external tenants setting due to an error causing redeployments to fail. Please enable this after deploying FinOps hubs the first time.

### [FinOps alerts](finops-alerts-overview.md) v0.9

- **Added**
  - Overview documentation on how the FinOps alert tool works in the [FinOps alerts overview](./alerts/finops-alerts-overview.md).
  - Configuration steps in the [Configure FinOps alerts](./alerts/configure-finops-alerts.md).
  - FinOps alerts deployment template.

### [Open data](open-data.md) v0.9

**[Dataset examples](open-data.md#dataset-examples)**

- **Added**
  - Added sample data for MCA reservation exports.
- **Fixed**
  - Changed a **Central Canada** reference to **Canada Central**.
    - This may have caused issues or duplication when joined with other datasets.
    - Please check your data for duplicate references to **Central Canada** and **Canada Central**.

> [!div class="nextstepaction"]
> [Download](https://github.com/microsoft/finops-toolkit/releases/tag/v0.9)
> [!div class="nextstepaction"]
> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.8...v0.9)

<br>

## v0.8 Update 1

_Released February 16, 2025_

This release is a minor patch to fix Power BI reports. These files were updated in the existing 0.8 release. We are documenting this as a new patch release for transparency. If you downloaded **PowerBI-KQL.zip** or **PowerBI-storage.zip** between February 12-15, 2025, please update to the latest version.

### [Power BI reports](power-bi/reports.md) v0.8 Update 1

- **Fixed**
  - Fixed all storage reports that were failing with an "Error converting value (null) to type System.Boolean" error ([#1314](https://github.com/microsoft/finops-toolkit/issues/1314)).
  - Fixed the Reservation recommendations page on the KQL Rate optimization report.
  - Fixed the Unattached disk page on the KQL Workload optimization report.

<br>

## v0.8

_Released February 12, 2025_

### [Implementing FinOps guide](../implementing-finops-guide.md) v0.8

- **Added**
  - Added the Learning FOCUS blog series to the [FOCUS overview doc](../focus/what-is-focus.md).

### [Power BI reports](power-bi/reports.md) v0.8

- **Added**
  - Added experimental feature to populate missing prices/costs.
    - This feature requires Cost Management price sheet exports be created and configured in the same FinOps hub instance or storage path.
    - This feature performs a large join between cost and price datasets and will slow down data refresh times.
    - If you run into any issues with data at scale, please disable the parameter.
    - If you notice prices or costs that are not correct, please [submit an issue in GitHub](https://aka.ms/ftk/ideas). Do not file a support request.
  - Added the Pricing units open dataset to support price sheet data cleanup.
  - Added `PricingUnit` and `x_PricingBlockSize` columns to the **Prices** table.
  - Added Total savings page to the Rate optimization report.
  - Added Effective Savings Rate (ESR) to Cost summary and Rate optimization reports.
- **Changed**
  - Updated the visual design of all storage and KQL reports.
  - Updated the KQL reports to use Direct Query to support larger datasets.
  - Updated storage reports to match the updated visuals from the KQL reports.
  - Expanded the columns in the commitment discount purchases page and updated to show recurring purchases separately.
- **Fixed**
  - Fixed date handling bug that resulted in a "We cannot apply operator >= to types List and Number" error ([#1180](https://github.com/microsoft/finops-toolkit/issues/1180)).
    - Date parsing now uses the report locale. If you run into issues, set the report locale explicitly to the desired format.
- **Deprecated**
  - Cosmetic and informational transforms will be disabled by default in 0.9 and removed on or after July 1, 2025 to improve Power BI performance. If you rely on any of these changes, please let us know by [creating an issue in GitHub](https://aka.ms/ftk/ideas) to request an exemption. This includes:
    - Support for FOCUS 1.0 preview. Please create new FOCUS 1.0 exports and backfill historical data.
    - Fixing `x_SkuTerm` for MCA so it's the number of months rather than a display string.
    - Tracking changes in the `x_SourceChanges` column.
    - Explaining why rows have no cost in the `x_FreeReason` column.
    - Creating `*Unique` name columns for resources, resource groups, subscriptions, and commitment discounts.

### [FinOps hubs](hubs/finops-hubs-overview.md) v0.8

<!-- cSpell:ignore daterange, datestring, monthsago, monthstring, numberstring, resourceid, startofmonth, virtualmachines -->
- **Added**
  - Added Data Explorer dashboard template.
  - Added new KQL functions in Data Explorer:
    - `monthstring(datetime, [length])` returns the name of the month at a given string length (for example, default = "January", 3 = "Jan", 1 = "J").
    - `datestring(datetime, [datetime])` returns a formatted date or date range abbreviated based on the current date (for example, "Jan 1", "Jan-Feb 2025", "Dec 15, 2024-Jan 14, 2025"). This function replaces `daterange()` and improves the return values to fix issues and covers more scenarios.
  - Add `resource_type()` KQL function to map internal resource type IDs to display names.
  - Clean up `ResourceType` values that have internal resource type IDs (for example, microsoft.compute/virtualmachines).
- **Changed**
  - Changed the **enablePublicAccess** parameter to exclude network components.
    - When disabled, a VNet will be created along with the required private endpoints and DNS zones to function in a fully private manner.
  - Updated the default setting for Data Explorer trusted external tenants from "All tenants" to "My tenant only".
    - This change may cause breaking issues for Data Explorer clusters accessed by users from external tenants.
  - Change the Data Explorer `numberstring()` function to support decimal numbers.
  - Updated `CommitmentDiscountUsage_transform_v1_0()` to use `parse_resourceid()`.
  - Update [required permissions](hubs/finops-hubs-overview.md#required-permissions) documentation.
  - Expand details about supported datasets in documentation.
  - Clean up bicep warnings in the FinOps hub deployment template.
- **Deprecated**
  - Deprecated the `daterange()` KQL function. Please use `datestring(datetime, [datetime])` instead.
  - Deprecated the `monthsago()` KQL function. Please use `startofmonth(datetime, [offset])` instead.
- **Fixed**
  - Improved performance and memory consumption in the `parse_resourceid()` function to address out of memory errors during cost data ingestion ([#1188](https://github.com/microsoft/finops-toolkit/issues/1188)).
  - Fixed timezones for Data Factory triggers to resolve issue where triggers would not start due to unrecognized timezone.
  - Fixed an issue where `x_ResourceType` is using the wrong value.
    - This fix resolves the issue for all newly ingested data.
    - To fix historical data, reingest data using the `ingestion_ExecuteETL` Data Factory pipeline.
  - Added missing request body to fix the false positive `config_RunExportJobs` pipeline validation errors in Data Factory ([#1250](https://github.com/microsoft/finops-toolkit/issues/1250)).

### [FinOps workbooks](workbooks/finops-workbooks-overview.md) v0.8

#### [Optimization workbook](workbooks/optimization.md) v0.8

- **Added**
  - Azure Arc Windows license management under the **Commitment Discounts** tab.  
- **Fixed**
  - Enabled "Export to CSV" option on the **Idle backups** query.
  - Corrected VM processor details on the **Compute** tab query.  

### [Optimization engine](optimization-engine/overview.md) v0.8

- **Added**
  - Improved multi-tenancy support with Azure Lighthouse guidance ([#1036](https://github.com/microsoft/finops-toolkit/issues/1036)).

### [PowerShell module](powershell/powershell-commands.md) v0.8

- **Added**
  - Added explicit `-CommitmentDiscountScope`, `-CommitmentDiscountResourceType`, and `-CommitmentDiscountLookback` parameters to the [New-FinOpsCostExport command](powershell/cost/New-FinOpsCostExport.md) for reservation recommendations.
  - Added explicit `-SystemAssignedIdentity` switch parameter to the [New-FinOpsCostExport command](powershell/cost/New-FinOpsCostExport.md) to enable system-assigned identity.
  - Updated the [Remove-FinOpsHub command](powershell/hubs/Remove-FinOpsHub.md) to show a list of resources before confirming delete.
    - The name of each deleted resource is printed for better visibility during the deletion process.
    - Added ability to confirm all deletions using a `-Force` parameter or "Yes to All" option ([#1187](https://github.com/microsoft/finops-toolkit/issues/1187)).
- **Changed**
  - Updated the following `RunHistory` array item properties in [Get-FinOpsCostExport command](powershell/cost/Get-FinOpsCostExport.md) outputs:
    - Renamed `Id` to `ResourceId`
    - Renamed `StartTime` to `RunStartTime`
    - Renamed `EndTime` to `RunEndTime`
    - Added `RunId` with the GUID export run ID
    - Added `QueryStartDate` with the first day of the exported data
    - Added `QueryEndDate` with the last day of the exported data
    - Added `ErrorCode` with the error code of the run, if applicable
    - Added `ErrorMessage` with the error message of the run, if applicable
  - Fixed the following [Get-FinOpsCostExport command](powershell/cost/Get-FinOpsCostExport.md) outputs:
    - `DatasetVersion` string
    - `DatasetFilters` object
    - `OverwriteData` flag
    - `PartitionData` flag
    - `CompressionMode` flag
    - `RunHistory` array item properties:
      - `FileName` string
      - `SubmittedBy` string
      - `SubmittedTime` date/time
      - `Status` string
      - `StartTime` date/time (renamed to `RunStartTime`)
      - `EndTime` date/time (renamed to `RunEndTime`)
- **Fixed**
  - Fixed the [New-FinOpsCostExport command](powershell/cost/New-FinOpsCostExport.md) to work for prices, reservation recommendations, and reservation transactions ([#1193](https://github.com/microsoft/finops-toolkit/issues/1193)).

### [Open data](open-data.md) v0.8

#### [Pricing units](open-data.md#pricing-units) v0.8

- **Added**
  - Added the "1000 TB" unit of measure ([#1181](https://github.com/microsoft/finops-toolkit/issues/1181)).

#### [Regions](open-data.md#regions) v0.8

- **Added**
  - Added the following new region values: <!-- cSpell:disable -->
    - ase
    - aue
    - southeastus
    - taiwannorthwest <!-- cSpell:enable -->

#### [Resource types](open-data.md#resource-types) v0.8

- **Added**
  - Added 8 new Microsoft.AzureCIS resource types.
  - Added 5 new Commvault.ContentStore resource types. <!-- cSpell:disable-line -->
  - Added 6 new Microsoft.ChangeSafety resource types.
  - Added 2 new Microsoft.DeviceOnboarding resource types.
  - Added 3 new Microsoft.DurableTask resource types.
  - Added 2 new Microsoft.Network DNS resolver resource types.
  - Added 2 new Microsoft.Relationships resource types.
  - Added 3 new Microsoft.Workloads resource types.
  - Added 14 new resource types: <!-- cSpell:disable -->
    - microsoft.baremetal/peeringsettings
    - microsoft.cdn/edgeactions
    - microsoft.compute/computefleetscalesets
    - microsoft.compute/virtualmachinescalesetscomputehub
    - microsoft.liftrpilot/organizations
    - microsoft.managednetworkfabric/networkmonitors
    - microsoft.mission/approvals
    - microsoft.mysqldiscovery/mysqlsitesagents
    - microsoft.portalservices/settings
    - microsoft.proposal/proposals
    - microsoft.zerotrustsegmentation/segmentationmanagers
    - mongodb.atlas/organizations <!-- cSpell:enable -->
- **Changed**
  - Updated 9 Microsoft.AzureStackHCI and Microsoft.All resource type to rebrand Azure Stack to Azure Local.
  - Updated 8 Microsoft.AzureCIS resource types.
  - Updated 3 Microsoft.DeviceRegistry resource types.
  - Updated 7 Microsoft.MobilePacketCore resource types.
  - Updated 5 Microsoft.StandByPool resource types.
  - Updated 3 Microsoft.Workloads resource types.
  - Updated 17 resource types: <!-- cSpell:disable -->
    - arizeai.observabilityeval/organizations
    - microsoft.azurebusinesscontinuity/deletedunifiedprotecteditems
    - microsoft.azurelargeinstance/azurelargestorageinstances
    - microsoft.community/communitytrainings
    - microsoft.compute/images
    - microsoft.compute/imagescomputehub
    - microsoft.deviceonboarding/onboardingservices/policies
    - microsoft.devopsinfrastructure/pools
    - microsoft.hybridnetwork/publishers/networkfunctiondefinitiongroups
    - microsoft.kubernetes/connectedclusters
    - microsoft.machinelearningservices/aistudio
    - microsoft.manufacturingplatform/manufacturingdataservices
    - microsoft.messagingconnectors/connectors
    - microsoft.network/dnszones
    - microsoft.network/trafficmanagerprofiles
    - microsoft.network/virtualnetworktaps
    - microsoft.servicebus/namespaces <!-- cSpell:enable -->

#### [Services](open-data.md#services) v0.8

- **Added**
  - Added 4 resource types to new services: <!-- cSpell:disable -->
    - microsoft.azurefleet/fleets
    - microsoft.hybridnetwork/sitenetworkservices
    - microsoft.iotoperations/instances
    - microsoft.networkcloud/baremetalmachines <!-- cSpell:enable -->

> [!div class="nextstepaction"]
> [Download](https://github.com/microsoft/finops-toolkit/releases/tag/v0.8)
> [!div class="nextstepaction"]
> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.7...v0.8)

<br>

## v0.7 Update 1

_Released December 9, 2024_

This release is a minor patch to update documentation and fix Power BI storage reports that are reporting all usage as $0. These files were updated in the existing 0.7 release. We are documenting this as a new patch release for transparency. If you downloaded the **PowerBI-storage.zip** file between December 1-9, 2024, please update to the latest version.

### [Power BI reports](power-bi/reports.md) v0.7 Update 1

- **Fixed**
  - Corrected the EffectiveCost for usage records.
  - Updated the download links in Power BI docs to the new files:
    - PowerBI-demo.zip for demo-only reports (not intended for connecting to customer data)
    - PowerBI-storage.zip for reports that connect to raw Cost Management exports or FinOps hubs storage.
    - PowerBI-kql.zip for reports that connect to FinOps hubs with Data Explorer.

> [!NOTE]
> Some have reported a 404 or "file not found" error in storage reports. The issue seems to be transient and can be resolved within a few hours. We have not been able to reproduce the issue and cannot pinpoint the source. If you are experiencing the error, please [submit an issue](https://aka.ms/ftk/ideas).

<br>

## v0.7

_Released December 1, 2024_

### [Implementing FinOps guide](../implementing-finops-guide.md) v0.7

- **Changed**
  - Added Enterprise App Patterns links resources to the [Architecting for cloud capability](../framework/optimize/architecting.md).
  - Update cost and unit of measure handling in the [FOCUS conversion instructions](../focus/convert.md).

### [Power BI reports](power-bi/reports.md) v0.7

- **Added**
  - Added partial support for OneLake URLs.
    - Support for OneLake URLs was added based on feedback and wasn't fully tested. More changes may be needed to fully support Microsoft Fabric.
  - Added KQL-based version of the [Cost summary](power-bi/cost-summary.md), [Data ingestion](power-bi/data-ingestion.md), and [Rate optimization](power-bi/rate-optimization.md) reports that connect to FinOps hubs with Azure Data Explorer.
- **Changed**
  - Consolidated the **Hub Storage URL** and **Export Storage URL** parameters into a single **Storage URL**.
    - All datasets must be either raw exports outside of FinOps hubs or be processed through hubs. This release no longer supports some data from hubs and some from raw exports.
    - If you have existing exports that aren't running through hubs data pipelines, change the exports to point to the hub **msexports** container.
    - This change was made to simplify the setup process and avoid errors in Power BI service configuration (for example, incremental refresh).
  - Renamed the following columns:
    - The **x_DatasetChanges** column is now **x_SourceChanges**.
    - The **x_DatasetType** column is now **x_SourceType**.
    - The **x_DatasetVersion** column is now **x_SourceVersion**.
    - The **x_AccountType** column is now **x_BillingAccountAgreement**.
  - Updated supported spend estimates in the Power BI documentation.
- **Fixed**
  - Fixed EffectiveCost for savings plan purchases to work around a bug in exported data.
  
### [FinOps hubs](hubs/finops-hubs-overview.md) v0.7

_**Breaking change**_

- **Added**
  - Option to ingest data into an Azure Data Explorer cluster.
  - Set missing reservation list and contracted prices/cost columns for EA and MCA accounts (Data Explorer only).
    - Requires the price sheet export to be configured.
  - Support for FOCUS 1.0r2 exports.
    - The 1.0r2 dataset only differs in date formatting. There are no functional differences compared to 1.0.
    - For example, dates in 1.0 are formatted as `2024-01-01T00:00Z` while dates in 1.0r2 are formatted as `2024-01-01T00:00:00Z`. Note the last `:00` for seconds.
    - The 1.0r2 dataset is only needed if you experience date parsing errors with the 1.0 dataset.
  - Support for private endpoints via an optional template parameter.
    - Added private endpoints for storage account, Azure Data Explorer & Keyvault.
    - Added managed virtual network & storage endpoint for Azure Data Factory Runtime.
    - All data processing now happens within a virtual network.
    - Added param to disable external access to Azure Data Lake and Azure Data Explorer.
    - Added param to specify subnet range of virtual network - minimum size = /26
  - Support for storage account infrastructure encryption.
  - Published a [schema file](https://aka.ms/finops/hubs/settings-schema) for the hub settings.json file.
- **Changed**
  - Changed dataset names in the ingestion container to facilitate Azure Data Explorer ingestion.
    > [!IMPORTANT]
    > This change requires removing previously ingested data for the current month to avoid data duplication. You do not need to re-export historical data for storage-based Power BI reports; however, historical data DOES need to be re-exported to ingest into Azure Data Explorer.
    - For FOCUS cost data, use `Costs`.
    - For price sheet data, use `Prices`.
    - For reservation details, use `CommitmentDiscountUsage`.
    - For reservation recommendations, use `Recommendations`.
    - For reservation transactions, use `Transactions`.
  - Renamed the `msexports_FileAdded` trigger to `msexports_ManifestAdded`.
- **Fixed**
  - Fix EffectiveCost for savings plan purchases to work around a bug in exported data (Data Explorer only).

### [FinOps workbooks](workbooks/finops-workbooks-overview.md) v0.7

#### [Optimization workbook](workbooks/optimization.md) v0.7

- **Added**
  - On the Storage tab, included the **RSVaultBackup** tag in the list of nonidle disks.
- **Fixed**
  - On the Azure reservations tab, fixed a configuration issue which was limiting results to 100 rows.
  - On the Compute tab, fixed incorrect virtual machine processor in processors query.
- **Removed**
  - On the Database tab, removed the idle SQL database query.
    - This query will be reevaluated and added again in a future release.

### [Optimization engine](optimization-engine/overview.md) v0.7

- **Fixed**
  - Exports ingestion issues in cases where exports come with empty lines ([#998](https://github.com/microsoft/finops-toolkit/issues/998)).
  - Missing columns in EA savings plans exports ([#1026](https://github.com/microsoft/finops-toolkit/issues/1026)).

### [Open data](open-data.md) v0.7

#### [Resource types](open-data.md#resource-types) v0.7

- **Added**
  - Added 50 new **Microsoft.AWSConnector** resource types.
  - Added eight new **Microsoft.Compute** resource types.
  - Added three new **Microsoft.ContainerInstance** resource types.
  - Added three new **Microsoft.DatabaseFleetManager** resource types.
  - Added four new **Microsoft.Fabric** resource types.
  - Added five new **Microsoft.OpenLogisticsPlatform** resource types.
  - Added three new **Microsoft.Sovereign** resource types.
  - Added 10 other new Microsoft resource types: <!-- cSpell:disable -->
    - microsoft.azurestackhci/edgedevices/jobs
    - microsoft.clouddeviceplatform/delegatedidentities
    - microsoft.compute/capacityreservationgroupscomputehub
    - microsoft.compute/galleries/imagescomputehub
    - microsoft.compute/hostgroupscomputehub
    - microsoft.hybridcompute/machinessoftwareassurance
    - microsoft.machinelearning/workspaces
    - microsoft.resources/deletedresources
    - microsoft.security/defenderforstoragesettings/malwarescans
    - microsoft.weightsandbiases/instances <!-- cSpell:enable -->
  - Added four other new third-party resource types: <!-- cSpell:disable -->
    - arizeai.observabilityeval/organizations
    - lambdatest.hyperexecute/organizations
    - neon.postgres/organizations
    - pinecone.vectordb/organizations <!-- cSpell:enable -->
- **Changed**
  - Updated 17 new **Microsoft.ComputeHub** resource types.
  - Updated nine other resource type: <!-- cSpell:disable -->
    - microsoft.appsecurity/policies
    - microsoft.compute/virtualmachines/providers/guestconfigurationassignments
    - microsoft.dbforpostgresql/flexibleservers
    - microsoft.deviceregistry/billingcontainers
    - microsoft.durabletask/namespaces
    - microsoft.durabletask/namespaces/taskhubs
    - microsoft.edge/configurations
    - microsoft.hybridcompute/machines/providers/guestconfigurationassignments
    - microsoft.securitycopilot/capacities <!-- cSpell:enable -->

#### [Services](open-data.md#services) v0.7

- **Added**
  - Added three resource types to existing services: <!-- cSpell:disable -->
    - microsoft.hardwaresecuritymodules/cloudhsmclusters
    - microsoft.healthdataaiservices/deidservices
    - microsoft.insights/datacollectionrules <!-- cSpell:enable -->

> [!div class="nextstepaction"]
> [Download](https://github.com/microsoft/finops-toolkit/releases/tag/v0.7)
> [!div class="nextstepaction"]
> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.6...v0.7)

<br>

## v0.6 Update 1

_Released October 5, 2024_

This release is a minor patch to update documentation and fix Rate optimization and Data ingestion Power BI files. These files were updated in the existing 0.6 release. We're documenting this release as a new patch release for transparency. If you downloaded these files between October 2-4, 2024, update to the latest version.

### [Power BI reports](power-bi/reports.md) v0.6 update 1

- **Added**
  - Documented the need to configure both **Hub Storage URL** and **Export Storage URL** when publishing reports to the Power BI service ([#1033](https://github.com/microsoft/finops-toolkit/issues/1033)).
- **Fixed**
  - Updated the Data ingestion report to account for storage path changes ([#1043](https://github.com/microsoft/finops-toolkit/issues/1043)).
  - Updated the Rate optimization report to remove the sensitivity level ([#1041](https://github.com/microsoft/finops-toolkit/issues/1041)).

### [FinOps hubs](hubs/finops-hubs-overview.md) v0.6 update 1

- **Added**
  - Added [compatibility guide](hubs/compatibility.md) to identify when changes are compatible with older Power BI reports.
- **Changed**
  - Updated the [upgrade guide](hubs/upgrade.md) to account for changes in 0.5 and 0.6.
- **Fixed**
  - Fixed the reservation details mapping file.

<br>

## v0.6

_Released October 2, 2024_

### [Implementing FinOps guide](../implementing-finops-guide.md) v0.6

- **Added**
  - Started a FinOps best practices library using Azure Resource Graph (ARG) queries from the Cost optimization workbook.

### [Power BI reports](power-bi/reports.md) v0.6

#### General Power BI updates v0.6

- **Added**
  - Add sample tags to promote to separate `tag_*` columns
  - Documented [how to connect to Power BI reports using storage account SAS tokens](power-bi/setup.md).
  - Documented [how to preview reports with sample data using Power BI Desktop](hubs/finops-hubs-overview.md).
- **Changed**
  - Renamed Prices `ChargePeriodStart`/`*End` to `x_EffectivePeriodStart`/`*End`.
  - Removed autocreated date tables.
- **Fixed**
  - Improved import performance by using parquet metadata to filter files by date (if configured).
  - Improved performance of column updates in CostDetails and Prices queries.
  - In the Prices query, fixed bug where `SkuID` wasn't merged into `x_SkuId`.

#### [Governance report v0.6](power-bi/governance.md)

- **Added**
  - Added Policy compliance.
  - Added Virtual machines and managed disks.
  - Added SQL databases.
  - Added Network security groups.

#### [Workload optimization report v0.6](power-bi/workload-optimization.md)

- **Added**
  - Added Azure Advisor cost recommendations.
  - Added Unattached disks.

### [FinOps hubs](hubs/finops-hubs-overview.md) v0.6

- **Added**
  - Support for Cost Management parquet and Gzip CSV exports.
  - Support for ingesting price, reservation recommendation, reservation detail, and reservation transaction datasets via Cost Management exports.
  - Compatibility guide to explain what versions of hubs and Power BI reports work together.
  - New UnsupportedExportFileType error when the exported file type isn't supported.
- **Changed**
  - Renamed the following pipelines to be clearer about their intent:
    - `config_BackfillData` to `config_StartBackfillProcess`.
    - `config_ExportData` to `config_StartExportProcess`.
    - `config_RunBackfill` to `config_RunBackfillJob`.
    - `config_RunExports` to `config_RunExportJobs`.
  - Changed the storage ingestion path from "{scope}/{yyyyMM}/{dataset}" to "{dataset}/{yyyy}/{MM}/{dataset}"
- **Fixed**
  - Updated the `config_RunBackfillJob` and `config_StartExportProcess` pipelines to handle when there's a single scope defined in config instead of an array.
  - Corrected the reservation details version in the schema file name in storage.
- **Removed**
  - Removed the temporary Event Grid resource from the template.

### [FinOps workbooks](workbooks/finops-workbooks-overview.md) v0.6

- **Added**
  - Created an option to deploy all [general-purpose FinOps toolkit workbooks](workbooks/finops-workbooks-overview.md) together.
    - Doesn't include workbooks specific to Optimization Engine.

### [Optimization engine](optimization-engine/overview.md) v0.6

- **Added**
  - [Troubleshooting documentation page](optimization-engine/troubleshooting.md) with the most common deployment and runtime issues and respective solutions or troubleshooting steps.
- **Changed**
  - Replaced storage account key-based authentication with Microsoft Entra ID authentication for improved security.
- **Fixed**
  - Added expiring savings plans and reservations to usage workbooks ([#1014](https://github.com/microsoft/finops-toolkit/issues/1014)).
- Deprecated
  - With the deprecation of the legacy Log Analytics agent in August 31, the `Setup-LogAnalyticsWorkspaces` script is no longer being maintained and will be removed in a future update.
    - The script was used to set up performance counters collection for machines connected to Log Analytics workspaces with the legacy agent.
    - We recommend migrating to the [Azure Monitor Agent](/azure/azure-monitor/agents/azure-monitor-agent-migration) and use the `Setup-DataCollectionRules` script to [setup performance counters collection with Data Collection Rules](optimization-engine/configure-workspaces.md).

### [PowerShell module](powershell/powershell-commands.md) v0.6

- **Changed**
  - Added a -ServiceSubcategory filter option to the [Get-FinOpsService command](powershell/data/get-finopsservice.md).

### [Open data](open-data.md) v0.6

#### [Resource types v0.6](open-data.md#resource-types)

- **Added**
  - Added 13 new **Microsoft.Billing** resource types.
  - Added 17 new **Microsoft.ComputeHub** resource types.
  - Added two new **Microsoft.DeviceOnboarding** resource types.
  - Added eight new **Microsoft.Edge** resource types.
  - Added eight other new resource types: <!-- cSpell:disable -->
    - microsoft.agricultureplatform/agriservices
    - microsoft.azurefleet/fleetscomputehub
    - microsoft.cloudtest/buildcaches
    - microsoft.contoso/employees/desks
    - microsoft.databasefleetmanager/fleets
    - microsoft.resources/databoundaries
    - microsoft.subscription/changetenantrequest
    - microsoft.sustainabilityservices/calculations <!-- cSpell:enable -->
- **Changed**
  - Updated two Microsoft.DurableTask resource types.
  - Updated four Microsoft.SignalRService resource types.
  - Updated four Microsoft.TimeSeriesInsights resource types.
  - Updated four other resource types: <!-- cSpell:disable -->
    - microsoft.network/dnsresolvers
    - microsoft.search/searchservices
    - microsoft.storagepool/diskpools/iscsitargets
    - oracle.database/oraclesubscriptions <!-- cSpell:enable -->

#### [Services v0.6](open-data.md#services)

- **Added**
  - Added a new ServiceSubcategory column to support FOCUS 1.1 ServiceSubcategory mapping.
  - Added the following resource types to existing services: <!-- cSpell:disable -->
    - microsoft.apimanagement/gateways
    - microsoft.sql/longtermretentionmanagedinstances
    - microsoft.sql/longtermretentionservers
    - microsoft.verifiedid/authorities <!-- cSpell:enable -->

> [!div class="nextstepaction"]
> [Download v0.6](https://github.com/microsoft/finops-toolkit/releases/tag/v0.6)
> [!div class="nextstepaction"]
> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.5...v0.6)

<br>

## v0.5 Update 1

_Released September 7, 2024_

This release is a minor patch to Power BI files. These files were updated in the existing 0.5 release. We're documenting the release as a new patch release for transparency.

### [Power BI reports](power-bi/reports.md) v0.5 update 1

- **Fixed**
  - Corrected a bug where Azure Data Lake Storage (ADLS) data sources couldn't be refreshed from the Power BI service ([#964](https://github.com/microsoft/finops-toolkit/issues/964)).
    > _This updated all PBIX/PBIT files downloaded between September 1-6, 2024. If you are using one of these files and plan to publish it to the Power BI service, please update to the latest version of the PBIX or PBIT files._

<br>

## v0.5

_Released September 1, 2024_

### [Implementing FinOps guide](../implementing-finops-guide.md) v0.5

- **Added**
  - Documented [how to compare FOCUS and actual/amortized data](../focus/validate.md) to learn and validate FOCUS data.

### [Power BI reports](power-bi/reports.md) v0.5

#### General Power BI updates v0.5

- **Changed**
  - Updated `ListCost`, `ListUnitPrice`, `ContractedCost`, and `ContractedUnitPrice` when not provided in Cost Management exports.
    - Contracted cost/price are set to effective cost/price when not available.
    - List cost/price are set to contracted cost/price when not available.
    - This means savings can be calculated, but aren't complete.
    - Refer to the Data quality page for details about missing or updated data.
  - Added support for pointing Power BI reports directly to Cost Management exports (without FinOps hubs).
  - Added new tables for Prices, ReservationDetails, ReservationRecommendations, and ReservationTransactions (works with exports only; doesn't work with hubs).
- **Fixed**
  - Fixed a bug in Cost Management exports where committed usage is showing as "Standard" pricing category.

#### [Cost summary report v0.5](power-bi/cost-summary.md)

- **Changed**
  - Added a table to the [Data quality page](power-bi/cost-summary.md#data-quality) to identify rows for which a unique ID can't be identified.
  - Added a table to the [Data quality page](power-bi/cost-summary.md#data-quality) to identify rows where billing currency and pricing currency are different.

#### [Rate optimization report v0.5](power-bi/rate-optimization.md)

- **Changed**
  - Commitment savings no longer filters out rows with missing list/contracted cost.
    - Since `ListCost` and `ContractedCost` are set to a fallback value when not included in Cost Management data, we can now calculate partial savings.
    - The calculated savings function is still incomplete since we don't have accurate list/contracted cost values.
  - Merged shared and single reservation recommendations into a single [Reservation recommendations](power-bi/rate-optimization.md#reservation-recommendations) page.

### [FinOps hubs](hubs/finops-hubs-overview.md) v0.5

- **Added**
  - Added an optional `skipEventGridRegistration` template parameter to support skipping Event Grid resource provider registration.
  - Added an Event Grid section to the hubs create form.
- **Changed**
  - Changed the Event Grid location selection logic to only identify fallback regions rather than supported regions.
  - Expanded cost estimate documentation to call out Power BI pricing and include a link to the Pricing Calculator.
- **Fixed**
  - Updated the config_ConfigureExports pipeline to handle when scopes in the settings.json file aren't an object.
  - Fixed a bug where scopes added via the Add-FinOpsHubScope command aren't added correctly due to missing brackets.

### [FinOps workbooks](workbooks/finops-workbooks-overview.md) v0.5

#### [Optimization workbook v0.5](workbooks/optimization.md)

- **Added**
  - New compute query to identify VMs per processor architecture type
  - New database query to identify SQL Pool instances with zero databases
  - New storage query to identify Powered Off VMs with Premium Disks
- **Changed**
  - Redesign of the Rate Optimization tab for easier identification of the break-even point for reservations
  - Fixed the Hybrid Benefit Virtual Machine Scale Set query to count the total cores consumed per the entire scale set
  - Improved storage idle disks query to ignore disks used by Azure Kubernetes Service pods
  - Updated Storage not v2 query to exclude blockBlobStorage accounts from the list
  - Added export option for the list of idle backups to streamline data extraction

#### [Governance workbook v0.5](workbooks/governance.md)

- **Changed**
  - Removed the management group filter to simplify filtering by subscription.

### [Optimization engine](optimization-engine/overview.md) v0.5

- **Added**
  - `Register-MultitenantAutomationSchedules` PowerShell script helper to [add a different Azure tenant to the scope of AOE](optimization-engine/customize.md).
  - Zone-redundant storage (ZRS) disks included in the scope of the `Premium SSD disk has been underutilized` recommendation (besides locally redundant storage (LRS)).
  - Option to scope consumption exports to MCA Billing Profile.
- **Changed**
  - Improved SQL Database security, replacing SQL authentication by Microsoft Entra ID authentication-only.
- **Fixed**
  - `Premium SSD disk has been underutilized` recommendation wasn't showing results due to a meter name change in Cost Management ([#831](https://github.com/microsoft/finops-toolkit/issues/831)).
  - Consumption exports for pay-as-you-go MCA subscriptions were missing cost data ([#828](https://github.com/microsoft/finops-toolkit/issues/828)).

### [PowerShell module](powershell/powershell-commands.md) v0.5

- **Added**
  - Added support for FOCUS, price sheet, and reservation dataset filters in [Get-FinOpsCostExport](powershell/cost/Get-FinOpsCostExport.md).
  - Added a `-DatasetVersion` filter in [Get-FinOpsCostExport](powershell/cost/Get-FinOpsCostExport.md).
- **Changed**
  - Update Get-AzAccessToken calls to use -AsSecureString ([#946](https://github.com/microsoft/finops-toolkit/issues/946)).
- **Fixed**
  - Fixed [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md) to address breaking change in Cost Management when storage paths start with `/`.
  - Fixed a bug where scopes added via the Add-FinOpsHubScope command aren't added correctly due to missing brackets.

### [Open data](open-data.md) v0.5

#### [Pricing units v0.5](open-data.md#pricing-units)

- **Added**
  - Added handling for the following new UnitOfMeasure values: **1 /Minute**, **10 PiB/Hour**, **100000 /Month**, **Text**.
- **Changed**
  - Changed DistinctUnits for the **10000s** UnitOfMeasure from **Units** to **Transactions**.

#### [Regions v0.5](open-data.md#regions)

- **Added**
  - Added the following new region values: <!-- cSpell:disable -->
    - `asiapacific`
    - `australia`
    - `azure stack`
    - `eastsu2`
    - `gbs`
    - `germany west central`
    - `japan`
    - `sweden central`
    - `unitedstates`
    - `us do`
    - `central`
    - `us dod east`
    - `us gov iowa`
    - `us gov virginia`
    - `us2`
    - `usa`
    - `usv` <!-- cSpell:enable -->

#### [Resource types v0.5](open-data.md#resource-types)

- **Added**
  - Added the following new resource types: <!-- cSpell:disable enable -->
    - microsoft.app/logicapps
    - microsoft.app/logicapps/workflows
    - microsoft.azurebusinesscontinuity/deletedunifiedprotecteditems
    - microsoft.azurebusinesscontinuity/unifiedprotecteditems
    - microsoft.azurecis/publishconfigvalues
    - microsoft.compositesolutions/compositesolutiondefinitions
    - microsoft.compositesolutions/compositesolutions
    - microsoft.compute/capacityreservationgroups/capacityreservations
    - microsoft.compute/virtualmachinescalesets/virtualmachines
    - microsoft.datareplication/replicationvaults/alertsettings
    - microsoft.datareplication/replicationvaults/events
    - microsoft.datareplication/replicationvaults/jobs
    - microsoft.datareplication/replicationvaults/jobs/operations
    - microsoft.datareplication/replicationvaults/operations
    - microsoft.datareplication/replicationvaults/protecteditems
    - microsoft.datareplication/replicationvaults/protecteditems/operations
    - microsoft.datareplication/replicationvaults/protecteditems/recoverypoints
    - microsoft.datareplication/replicationvaults/replicationextensions
    - microsoft.datareplication/replicationvaults/replicationextensions/operations
    - microsoft.datareplication/replicationvaults/replicationpolicies
    - microsoft.datareplication/replicationvaults/replicationpolicies/operations
    - microsoft.deviceregistry/billingcontainers
    - microsoft.deviceregistry/discoveredassetendpointprofiles
    - microsoft.deviceregistry/discoveredassets
    - microsoft.deviceregistry/schemaregistries
    - microsoft.deviceregistry/schemaregistries/schemas
    - microsoft.deviceregistry/schemaregistries/schemas/schemaversions
    - microsoft.eventgrid/systemtopics/eventsubscriptions
    - microsoft.hardware/orders
    - microsoft.hybridcompute/machines/microsoft.awsconnector/ec2instances
    - microsoft.hybridonboarding/extensionmanagers
    - microsoft.iotoperations/instances
    - microsoft.iotoperations/instances/brokers
    - microsoft.iotoperations/instances/brokers/authentications
    - microsoft.iotoperations/instances/brokers/authorizations
    - microsoft.iotoperations/instances/brokers/listeners
    - microsoft.iotoperations/instances/dataflowendpoints
    - microsoft.iotoperations/instances/dataflowprofiles
    - microsoft.iotoperations/instances/dataflowprofiles/dataflows
    - microsoft.messagingconnectors/connectors
    - microsoft.mobilepacketcore/networkfunctions
    - microsoft.saashub/cloudservices/hidden
    - microsoft.secretsynccontroller/azurekeyvaultsecretproviderclasses
    - microsoft.secretsynccontroller/secretsyncs
    - microsoft.storagepool/diskpools/iscsitargets
    - microsoft.usagebilling/accounts/dataexports
    - microsoft.usagebilling/accounts/metricexports
    - microsoft.windowsesu/multipleactivationkeys <!-- cSpell:enable -->
- **Changed**
  - Updated the following resource types: <!-- cSpell:disable -->
    - microsoft.apimanagement/gateways
    - microsoft.azurearcdata/sqlserveresulicenses
    - microsoft.azurestackhci/edgenodepools
    - microsoft.azurestackhci/galleryimages
    - microsoft.azurestackhci/logicalnetworks
    - microsoft.azurestackhci/marketplacegalleryimages
    - microsoft.azurestackhci/networkinterfaces
    - microsoft.azurestackhci/storagecontainers
    - microsoft.cache/redisenterprise
    - microsoft.cache/redisenterprise/databases
    - microsoft.databricks/accessconnectors
    - microsoft.datareplication/replicationvaults
    - microsoft.devhub/iacprofiles
    - microsoft.edge/sites
    - microsoft.eventhub/namespaces
    - microsoft.hybridcompute/gateways
    - microsoft.impact/connectors
    - microsoft.iotoperationsorchestrator/instances
    - microsoft.iotoperationsorchestrator/solutions
    - microsoft.iotoperationsorchestrator/targets
    - microsoft.kubernetesruntime/loadbalancers
    - microsoft.manufacturingplatform/manufacturingdataservices
    - microsoft.network/dnsforwardingrulesets
    - microsoft.network/dnsresolvers
    - microsoft.network/dnszones
    - microsoft.powerbidedicated/capacities
    - microsoft.programmableconnectivity/gateways
    - microsoft.programmableconnectivity/operatorapiconnections
    - microsoft.programmableconnectivity/operatorapiplans
    - microsoft.resources/subscriptions/resourcegroups
    - microsoft.security/pricings
    - microsoft.sovereign/transparencylogs
    - microsoft.storagepool/diskpools <!-- cSpell:enable -->
  - Updated multiple resource types for the following resource providers: **microsoft.awsconnector**. <!-- cSpell:disable-line -->
  - Changed the following resource providers to be GA: **microsoft.modsimworkbench**. <!-- cSpell:disable-line -->
- **Removed**
  - Removed internal "microsoft.cognitiveservices/browse*" resource types. <!-- cSpell:disable-line -->

#### [Services v0.5](open-data.md#services)

- **Added**
  - Added the following consumed services:
    - API Center
    - API Management
    - Bastion Scale Units
    - Microsoft.Community
    - Microsoft.DataReplication.Admin
    - Microsoft.DevOpsInfrastructure
    - Microsoft.Dynamics365FraudProtection
    - Microsoft.HybridContainerService
    - Microsoft.NetworkFunction
    - Microsoft.RecommendationsService
    - Microsoft.ServiceNetworking
    - Virtual Network
  - Added the following resource types to existing services: <!-- cSpell:disable -->
    - Microsoft.AgFoodPlatform/farmBeats
    - Microsoft.App/sessionPools
    - Microsoft.AzureActiveDirectory/ciamDirectories
    - Microsoft.AzureArcData/sqlServerEsuLicenses
    - Microsoft.Graph/accounts
    - Microsoft.MachineLearningServices/registries
    - Microsoft.Orbital/groundStations
    - PlayFabBillingService/partyVoice <!-- cSpell:enable -->
- **Changed**
  - Moved Microsoft Genomics from the **AI and Machine Learning** service category to **Analytics**.
  - Changed Microsoft Genomics from the **SaaS** service model to **PaaS**.
  - Replace **Azure Active Directory** service name references with **Microsoft Entra**.
  - Move Azure Cache for Redis from the **Storage** service category to **Databases**.
  - Move Event Hubs from the **Integration** service category to **Analytics**.
  - Rename the Microsoft.HybridCompute consumed service name from **Azure Resource Manager** to **Azure Arc**.
  - Move Microsoft Defender for Endpoint from the **Multicloud** service category to **Security**.
  - Move StorSimple from the **Multicloud** service category to **Storage**.

> [!div class="nextstepaction"]
> [Download v0.5](https://github.com/microsoft/finops-toolkit/releases/tag/v0.5)
> [!div class="nextstepaction"]
> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.4...v0.5)

<br>

## v0.4

_Released July 12, 2024_

### [Implementing FinOps guide](../implementing-finops-guide.md) v0.4

- **Added**
  - Documented the [FOCUS export dataset](../focus/metadata.md) to align to the FOCUS metadata specification.
- **Changed**
  - Updated [FinOps Framework guidance](../framework/finops-framework.md) to account for the 2024 updates.
  - Updated [FOCUS guidance](../focus/what-is-focus.md) to FOCUS 1.0.

### [FinOps hubs](hubs/finops-hubs-overview.md) v0.4

- **Added**
  - Ingest FOCUS 1.0 data in FinOps hubs.
  - Grant access to FinOps hubs to [create and manage exports](hubs/configure-scopes.md#configure-managed-exports) for you.
  - Connect to a hub instance in another Microsoft Entra ID tenant.
  - Step-by-step troubleshooting guide and expanded set of common errors for validating FinOps hubs and Power BI setup.
- **Fixed**
  - Fixed an issue where some dates are showing as off by 1 based on local time zone.
    - If you see dates that are off, upgrade to 0.4 and re-export those months. The fix is in ingestion.
    - You can re-export data in FOCUS 1.0 or FOCUS 1.0 preview. We recommend FOCUS 1.0 for slightly faster refresh times in Power BI.

### [Power BI reports](power-bi/reports.md) v0.4

#### General Power BI updates v0.4

- **Added**
  - **x_IncrementalRefreshDate** column to facilitate configuring incremental refresh in Power BI.
  - Step-by-step troubleshooting guide and expanded set of common errors for validating Power BI setup.
- **Changed**
  - Changed the **Tags** column to default to `{}` when empty to facilitate tag expansion ([#691](https://github.com/microsoft/finops-toolkit/issues/691#issuecomment-2134072033)).
  - Simplified formatting for the `BillingPeriod` and `ChargePeriod` measures in Power BI.
  - Improved error handling for derived savings columns in the CostDetails query.
  - Simplified queries and improved error handling in the START HERE query for report setup steps.
  - Changed internal storage for reports to use [Tabular Model Definition Language (TMDL)](/power-bi/developer/projects/projects-dataset#tmdl-format). <!-- cSpell:ignore TMDL -->
    - This change makes it easier to review changes to the data model in Power BI.
    - Reports continue to get released as Power BI report (.pbix) files, so this change shouldn't affect end users.
    - Visualizations aren't being switched to [Power BI Enhanced Report (PBIR)](/power-bi/developer/projects/projects-report#pbir-format) format yet due to functional limitations that would affect end users (as of June 2024). <!-- cSpell:ignore: PBIR -->
- **Fixed**
  - Improved parsing for the `x_ResourceParentName` and `x_ResourceParentType` columns ([#691](https://github.com/microsoft/finops-toolkit/issues/691#issuecomment-2134072033)).

#### [Cost summary report v0.4](power-bi/cost-summary.md)

- **Added**
  - Resource count and cost per resource in the [Inventory page](power-bi/cost-summary.md#inventory).
- **Changed**
  - Changed the [Cost summary Purchases page](power-bi/cost-summary.md#purchases) and [Rate optimization Purchases page](power-bi/rate-optimization.md#purchases) to use PricingQuantity instead of Usage/ConsumedQuantity and added the PricingUnit column.
  - Updated the [Data quality page](power-bi/cost-summary.md#data-quality) to identify empty ChargeDescription rows.
  - Updated the [Data quality page](power-bi/cost-summary.md#data-quality) to identify potentially missing rounding adjustments.

#### [Data ingestion report v0.4](power-bi/data-ingestion.md)

- **Added**
  - [Ingestion errors page](power-bi/data-ingestion.md#ingestion-errors) to help identify FinOps hub data ingestion issues.
- **Changed**
  - Optimized queries to reduce memory footprint and load faster.
- **Fixed**
  - Fixed error in queries.

#### [Rate optimization report v0.4](power-bi/rate-optimization.md)

- **Changed**
  - Renamed the "Commitment discounts" report to "Rate optimization" to align to the FinOps Framework 2024 updates.
- **Fixed**
  - Added error handling for missing `normalizedSize` and `recommendedQuantityNormalized` columns in the [Rate optimization (Commitment discounts) report](power-bi/rate-optimization.md) ([#702](https://github.com/microsoft/finops-toolkit/issues/702)).

### [FinOps workbooks](workbooks/finops-workbooks-overview.md) v0.4

#### [Optimization workbook v0.4](workbooks/optimization.md)

- **Added**
  - Added reservation recommendations with the break-even point to identify when savings would be achieved.
  - Identify idle ExpressRoute circuits to streamline costs.
  - Gain insights into the routing preferences for public IP addresses to optimize network performance.
  - Explore commitment discount savings to get a clear overview of rate optimization opportunities.
  - Quickly view public IP addresses with DDoS protection enabled and compare if it would be cheaper to enable DDoS to the virtual network instead.
  - Identify Azure Hybrid Benefit usage for SQL Database elastic pools to maximize cost efficiency.
- **Changed**
  - Redesigned the Sustainability tab to clarify recommendations.
  - Provide more accurate results by ignoring dynamic IPs in the public IP addresses list.
  - Ignore free tier web apps to provide a clearer picture of your top services.

#### [Governance workbook v0.4](workbooks/governance.md)

- **Added**
  - Added managed disk usage monitoring.
- **Changed**
  - Overview was revised to align with the latest governance principles of the cloud adoption framework.

### [Optimization engine](optimization-engine/overview.md) v0.4

- **Added**
  - Added Azure Optimization Engine (AOE), an extensible solution for custom optimization recommendations.

### [PowerShell module](powershell/powershell-commands.md) v0.4

- **Added**
  - Added progress tracking to [Start-FinOpsCostExport](powershell/cost/Start-FinOpsCostExport.md) for multi-month exports.
  - Added a 60-second delay when Cost Management returns throttling (429) errors in [Start-FinOpsCostExport](powershell/cost/Start-FinOpsCostExport.md).
- **Changed**
  - Updated [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md) to default to FOCUS 1.0.
- **Removed**
  - Removed support for Windows PowerShell.
    > _We discovered errors with Windows PowerShell due to incompatibilities in Windows PowerShell and PowerShell 7. Due to our limited capacity, we decided to only support [PowerShell 7](/powershell/scripting/install/installing-powershell) going forward._
  - Removed `ConvertTo-FinOpsSchema` and `Invoke-FinOpsSchemaTransform` commands which were deprecated in [0.2 (January 2024)](#v02).

### [Open data](open-data.md) v0.4

- **Added**
  - Added a new FOCUS 1.0 [dataset example](open-data.md#dataset-examples).
  - Added [dataset metadata](open-data.md#dataset-metadata) for FOCUS 1.0 and FOCUS 1.0-preview.
- **Changed**
  - Updated all [open data files](open-data.md) to include the latest data.
  - Changed the primary columns in the [Regions](open-data.md#regions) and [Services](open-data.md#services) open data files to be lowercase.
  - Updated all [sample exports](open-data.md#dataset-examples) to use the same date range as the FOCUS 1.0 dataset.

> [!div class="nextstepaction"]
> [Download v0.4](https://github.com/microsoft/finops-toolkit/releases/tag/v0.4)
> [!div class="nextstepaction"]
> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.3...v0.4)

<br>

## v0.3

_Released March 28, 2024_

### [Implementing FinOps guide](../implementing-finops-guide.md) v0.3

- **Added**
  - Moved Azure FinOps documentation about how to implement and adopt FinOps into the toolkit repository.
- **Changed**
  - Rearranged documentation site to better organize content.

### [FinOps hubs](hubs/finops-hubs-overview.md) v0.3

- **Added**
  - Started archiving template versions so they can be referenced easily via URL microsoft.github.io/finops-toolkit/deploy/finops-hub-{version}.json.
- **Fixed**
  - Fixed "missing period" error Data Factory Studio.
  - Fixed bug where `msexports_FileAdded` trigger wasn't getting started.
  - Fixed deploy to Azure buttons to point to the latest release.
- **Changed**
  - Return a single boolean value from the Remove-FinOpsHub command.

### [Power BI reports](power-bi/reports.md) v0.3

#### General Power BI updates v0.3

- **Added**
  - Added `ResourceParentId`, `ResourceParentName`, and `ResourceParentType` columns to support the usage of the user-defined `cm-resource-parent` tag.
  - Added `ToolkitVersion` and `ToolkitTool` columns to help quantify the cost of FinOps toolkit solutions.
  - Added a Data quality page to the [Commitment discounts report](power-bi/rate-optimization.md#data-quality) for data quality validations. This page can be useful in identifying data gaps in Cost Management.
  - Added `x_NegotiatedUnitPriceSavings` column to show the price reduction from negotiated discounts compared to the public, list price.
  - Added `x_IsFree` column to indicate when a row represents a free charge (based on Cost Management data). It gets used in data quality checks.
  - Added `Tags` and `TagsAsJson` columns to both the **Usage details** and **Usage details amortized** tables in the [CostManagementTemplateApp report](power-bi/template-app.md) ([#625](https://github.com/microsoft/finops-toolkit/issues/625)).
- **Changed**
  - Changed "Other" ChargeSubcategory for usage to "On-Demand" to be consistent with Cost Management exports
  - Renamed savings columns for consistency:
    - `x_OnDemandUnitPriceSavings` is now `x_CommitmentUnitPriceSavings`. It shows the commitment discount price reduction compared to the negotiated prices for the account.
    - `x_ListUnitPriceSavings` is now `x_DiscountUnitPriceSavings`. It shows the price reduction from all discounts compared to the public, list price.
    - `x_NegotiatedSavings` is now `x_NegotiatedCostSavings`. It shows the cost savings from negotiated discounts only (excluding commitment discounts).
    - `x_CommitmentSavings` is now `x_CommitmentCostSavings`. It shows the cost savings from commitment discounts compared to on-demand prices for the account (including negotiated discounts).
    - `x_DiscountSavings` is now `x_DiscountCostSavings`. It shows the cost savings from all negotiated and commitment discounts.
  - Changed the `PricingQuantity` and `UsageQuantity` columns to use three decimal places.
  - Changed all cost columns to use two decimal places.
  - Changed all unit price columns to not summarize by default and use three decimal places.
  - Changed the `x_PricingBlockSize` column to a whole number and not summarize by default.
- **Fixed**
  - Fixed data issue where Cost Management uses `1Year`, `3Years`, and `5Years` for the `x_SkuTerm`. Values should be 12, 36, and 60 ([#594](https://github.com/microsoft/finops-toolkit/issues/594)).
  - Changed the data type for the `x_Month` column to be a date.
  - Changed `x_SkuTerm` to be a whole number and to not summarize by default.
  - Changed `x_BillingExchangeRate` to not summarize by default.
  - Corrected the datatype for the `x_Month` column.

#### [Commitment discounts report v0.3](power-bi/rate-optimization.md)

- **Changed**
  - Renamed the **Coverage** pages to **Recommendations**.
- **Fixed**
  - Fixed incorrect filter ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).

#### [Cost Management connector report v0.3](power-bi/connector.md)

- **Fixed**
  - Fixed numerous errors causing the report to not load for MCA accounts.
  - Corrected references to `x_InvoiceIssuerId` and `InvoiceIssuerName` columns ([#639](https://github.com/microsoft/finops-toolkit/issues/649)).

### [PowerShell module](powershell/powershell-commands.md) v0.3

- **Added**
  - [Get-FinOpsService](powershell/data/Get-FinOpsService.md) includes new `-Environment` and `-ServiceModel` filters and properties in the response ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).
- **Changed**
  - [Start-FinOpsCostExport](powershell/cost/Start-FinOpsCostExport.md) includes a new `-Backfill` option to backfill multiple months.
  - [Start-FinOpsCostExport](powershell/cost/Start-FinOpsCostExport.md) includes a new `-StartDate` and `-EndDate` options to run the export for a given date range. It can include multiple months.
- **Fixed**
  - Fixed ParameterBindingException error in [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md).
  - Updated the FOCUS dataset version that was changed in Cost Management exports in [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md).
  - Changed the default `-EndDate` in [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md) to be the end of the month due to a breaking change in Cost Management exports.
  - Fixed internal command used in [Deploy-FinOpsHub](powershell/hubs/Deploy-FinOpsHub.md) that might cause failure for some versions of the Az PowerShell module.

### [Open data](open-data.md) v0.3

- **Added**
  - Added ServiceModel and Environment columns to the [services](open-data.md#services) data ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).
  - New and updated [resource types](open-data.md#resource-types) and icons.

> [!div class="nextstepaction"]
> [Download v0.3](https://github.com/microsoft/finops-toolkit/releases/tag/v0.3)
> [!div class="nextstepaction"]
> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.2...v0.3)

<br>

## v0.2

_Released January 22, 2024_

### [FinOps hubs](hubs/finops-hubs-overview.md) v0.2

_**Breaking change**_

- **Fixed**
  - Fixed error in some China regions where deployment scripts weren't supported ([#259](https://github.com/microsoft/finops-toolkit/issues/259)).
- **Changed**
  - Switch from amortized cost exports to FOCUS cost exports.
    > [!NOTE]
    > This change requires re-ingesting historical data and isn't backwards compatible. The unified schema used in this release is aligned with the future plans for Microsoft Cost Management exports. A later release updates the schema to align to the FinOps Open Cost and Usage Specification (FOCUS).
  - Updated ingestion container month folders from `yyyyMMdd-yyyyMMdd` to `yyyyMM`.
  - Renamed **msexports_extract** pipeline to **msexports_ExecuteETL**.
  - Renamed **msexports_transform** pipeline to **msexports_ETL_ingestion**.

### [Power BI reports](power-bi/reports.md) v0.2

#### General Power BI updates v0.2

- **Changed**
  - Updated reports to [FOCUS 1.0 preview](../focus/what-is-focus.md).
  - Updated reports to only use [FinOps hubs](hubs/finops-hubs-overview.md).
  - Removed unused custom visualizations.
  - Organized setup instructions in Cost summary to match other reports.
  - Updated troubleshooting documentation.
- **Fixed**
  - Removed sensitivity labels.
  - Fixed dynamic data source error when the Power BI service refreshes data.
    - Error message: `You can't schedule refresh for this semantic model because the following data sources currently don't support refresh...`
  - Fixed error in ChargeId column when ResourceId is empty.
  - Removed the ChargeId column due to it bloating the data size.
    - The field is commented out. If interested, you can enable uncomment in the ftk_NormalizeSchema function. It can duplicate many columns to ensure uniqueness which bloats the data size significantly.
  - Fixed null error when Billing Account ID is empty ([#473](https://github.com/microsoft/finops-toolkit/issues/473)).
  - Added missing commitment discount refunds to the actual cost data ([#447](https://github.com/microsoft/finops-toolkit/issues/447)).

#### [Cost Management connector report v0.2](power-bi/connector.md)

- **Added**
  - Added new report to support the Cost Management connector.

### [FinOps workbooks](workbooks/finops-workbooks-overview.md) v0.2

#### [Optimization workbook v0.2](workbooks/optimization.md)

- **Added**
  - Storage: Identify Idle Backups: Review protected items' backup activity to spot items not backed up in the last 90 days.
  - Storage: Review Replication Settings: Evaluate and improve your backup strategy by identifying resources with default geo-redundant storage (GRS) replication.
  - Networking: Azure Firewall Premium Features: Identify Azure Firewalls with Premium SKU and ensure associated policies use premium-only features.
  - Networking: Firewall Optimization: Streamline Azure Firewall usage by centralizing instances in the hub virtual network or Virtual WAN secure hub.
- **Changed**
  - Top 10 services: Improved Monitoring tabs: Enhance your monitoring experience with updated Azure Advisor recommendations for Log Analytics.
- **Fixed**
  - Azure Hybrid Benefit: Fixed support for Windows 10/Windows 11.

### [PowerShell module](powershell/powershell-commands.md) v0.2

- **Added**
  - [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md) to create and update Cost Management exports.
  - [Start-FinOpsCostExport](powershell/cost/Start-FinOpsCostExport.md) to run a Cost Management export immediately.
  - [Get-FinOpsCostExport](powershell/cost/Get-FinOpsCostExport.md) now has a `-RunHistory` option to include the run history of each export.
- **Changed**
  - Updated the default API version for export commands to `2023-07-01-preview` to use new datasets and features.
    - Specify `2023-08-01` explicitly for the previous API version.
- **Fixed**
  - Fixed typo in [Deploy-FinOpsHub](powershell/hubs/Deploy-FinOpsHub.md) causing it to fail.
- Deprecated
  - `ConvertTo-FinOpsSchema` and `Invoke-FinOpsSchemaTransform` are no longer being maintained and will be removed in a future update.
    - With native support for FOCUS 1.0 preview in Cost Management, we're deprecating both commands, which only support FOCUS 0.5.
    - If you would like to see the PowerShell commands updated to 1.0 preview, let us know in discussions or via a GitHub issue.

### [Open data](open-data.md) v0.2

- **Added**
  - [Resource types](open-data.md#resource-types) to map Azure resource types to friendly display names.
  - [Get-FinOpsResourceType](powershell/data/Get-FinOpsResourceType.md) PowerShell command to support resource type to display name mapping.
  - [Sample exports](open-data.md) for each of the datasets that can be exported from Cost Management.

### [Implementing FinOps guide](../implementing-finops-guide.md) v0.2

- **Added**
  - [FinOps Open Cost and Usage Specification (FOCUS) details](../focus/what-is-focus.md).

> [!div class="nextstepaction"]
> [Download v0.2](https://github.com/microsoft/finops-toolkit/releases/tag/v0.2)
> [!div class="nextstepaction"]
> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.1.1...v0.2)

<br>

## v0.1.1

_Released October 26, 2023_

### [PowerShell module](powershell/powershell-commands.md) v0.1.1

- **Added**
  - New PowerShell commands to convert data to FOCUS 0.5:
    - ConvertTo-FinOpsSchema
    - Invoke-FinOpsSchemaTransform
  - New PowerShell commands to get and delete Cost Management exports:
    - [Get-FinOpsCostExport](powershell/cost/Get-FinOpsCostExport.md)
    - [Remove-FinOpsCostExport](powershell/cost/Remove-FinOpsCostExport.md)

### [Open data](open-data.md) v0.1.1

- **Added**
  - New PowerShell commands to integrate open data to support data cleansing:
    - [Get-FinOpsPricingUnit](powershell/data/Get-FinOpsPricingUnit.md)
    - [Get-FinOpsRegion](powershell/data/Get-FinOpsRegion.md)
    - [Get-FinOpsService](powershell/data/Get-FinOpsService.md)

### [FinOps hubs](hubs/finops-hubs-overview.md) v0.1.1

- **Added**
  - New PowerShell commands to manage FinOps hubs 0.1:
    - [Get-FinOpsHub](powershell/hubs/Get-FinOpsHub.md)
    - [Initialize-FinOpsHubDeployment](powershell/hubs/Initialize-FinOpsHubDeployment.md)
    - [Register-FinOpsHubProviders](powershell/hubs/Register-FinOpsHubProviders.md)
    - [Remove-FinOpsHub](powershell/hubs/Remove-FinOpsHub.md)

> [!div class="nextstepaction"]
> [Download v0.1.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1)
> [!div class="nextstepaction"]
> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.1...v0.1.1)

<br>

## v0.1

_Released October 22, 2023_

### [PowerShell module](powershell/powershell-commands.md) v0.1

- **Added**
  - [FinOpsToolkit module](powershell/toolkit/finops-toolkit-commands.md) released in the PowerShell Gallery.
  - [Get-FinOpsToolkitVersion](powershell/toolkit/get-finopstoolkitversion.md) to get toolkit versions.

### [FinOps hubs](hubs/finops-hubs-overview.md) v0.1

- **Added**
  - [Deploy-FinOpsHub](powershell/hubs/Deploy-FinOpsHub.md) to deploy or update a hub instance.
  - [Get-FinOpsHub](powershell/hubs/Get-FinOpsHub.md) to get details about a hub instance.
  - Support for Microsoft Customer Agreement (MCA) accounts and Cloud Solution Provider (CSP) subscriptions in Power BI reports.
- **Fixed**
  - Storage redundancy dropdown default not set correctly in the creation form.
  - Tags specified in the creation form were causing the deployment to fail ([#331](https://github.com/microsoft/finops-toolkit/issues/331)).

### [Power BI reports](power-bi/reports.md) v0.1

- **Added**
  - Commitments, Savings, Chargeback, Purchases, and Prices pages in the [Commitment discounts report](power-bi/rate-optimization.md).
  - Prices page in the [Cost summary report](power-bi/cost-summary.md).
  - [FOCUS sample report](power-bi/reports.md) – See your data in the FinOps Open Cost and Usage Specification (FOCUS) schema.
  - [Cost Management template app](power-bi/template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.
- **Changed**
  - Expanded the FinOps hubs Cost summary and Commitment discounts [Power BI reports](power-bi/reports.md) to support the Cost Management connector.

### [FinOps workbooks](workbooks/finops-workbooks-overview.md) v0.1

- **Added**
  - [Governance workbook](workbooks/governance.md) to centralize governance.
- **Changed**
  - [Optimization workbook](workbooks/optimization.md) updated to cover more scenarios.

### [Open data](open-data.md) v0.1

- **Added**
  - [Pricing units](open-data.md#pricing-units) to map all pricing units (UnitOfMeasure values) to distinct units with a scaling factor.
  - [Regions](open-data.md#regions) to map historical resource location values in Microsoft Cost Management to standard Azure regions.
  - [Services](open-data.md#services) to map all resource types to FOCUS service names and categories.

> [!div class="nextstepaction"]
> [Download v0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1)
> [!div class="nextstepaction"]
> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.0.1...v0.1)

<br>

## v0.0.1

_Released May 27, 2023_

### [FinOps hubs](hubs/finops-hubs-overview.md) v0.0.1

- **Added**
  - [FinOps hub template](hubs/finops-hubs-overview.md) to deploy a storage account and Data Factory instance.
  - [Cost summary report](power-bi/cost-summary.md) for various out-of-the-box cost breakdowns.
  - [Commitment discounts report](power-bi/rate-optimization.md) for commitment-based discount reports.

### [Bicep Registry modules](bicep-registry/modules.md) v0.0.1

- **Added**
  - [Scheduled action modules](bicep-registry/scheduled-actions.md) submitted to the Bicep Registry.

### [FinOps workbooks](workbooks/finops-workbooks-overview.md) v0.0.1

- **Added**
  - [Cost optimization workbook](workbooks/optimization.md) to centralize cost optimization.

> [!div class="nextstepaction"]
> [Download v0.0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.0.1)
> [!div class="nextstepaction"]
> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/878e4864ca785db4fc13bdd2ec3a6a00058688c3...v0.0.1)

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.8/bladeName/Toolkit/featureName/Changelog)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>
