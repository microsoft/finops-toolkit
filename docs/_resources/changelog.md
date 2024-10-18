---
title: FinOps toolkit changelog
description: Review the latest features and enhancements in the FinOps toolkit.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what changes were made in the latest FinOps toolkit releases.
---

<!-- markdownlint-disable MD036 -->
<!-- markdownlint-disable-next-line MD025 -->
# FinOps toolkit changelog

This article summarizes the features and enhancements in each release of the FinOps toolkit.

<br>

## Unreleased

### FinOps guide

- **Added**
  - Added Enterprise App Patterns links resources to the architecting for the cloud section.

### FinOps hubs

- **Added**
  - Analytics engine – Ingest cost data into an Azure Data Explorer cluster.
  - Auto-backfill – Backfill historical data from Microsoft Cost Management.
  - Retention – Configure how long you want to keep Cost Management exports and normalized data in storage.
  - ETL pipeline – Add support for parquet files created by Cost Management exports.

### Power BI reports

#### General Power BI updates

- **Added**
  - Populate missing prices.

### Bicep Registry modules

- **Added**
  - Cost Management export modules for subscriptions and resource groups.

### Optimization engine

- **Fixed**
  - Exports ingestion issues in cases where exports come with empty lines ([#998](https://github.com/microsoft/finops-toolkit/issues/998))
  - Missing columns in EA savings plans exports ([#1026](https://github.com/microsoft/finops-toolkit/issues/1026))

<br><a name="latest"></a>

## v0.6 Update 1

<sup>Released October 5, 2024</sup>

This release is a minor patch to update documentation and fix Rate optimization and Data ingestion Power BI files. These files were updated in the existing 0.6 release. We are documenting this as a new patch release for transparency. If you downloaded these files between October 2-4, 2024, please update to the latest version.

### Power BI reports v0.6 update 1

- **Added**
  - Documented the need to configure both **Hub Storage URL** and **Export Storage URL** when publishing reports to the Power BI service ([#1033](https://github.com/microsoft/finops-toolkit/issues/1033)).
- **Fixed**
  - Updated the Data ingestion report to account for storage path changes ([#1043](https://github.com/microsoft/finops-toolkit/issues/1043)).
  - Updated the Rate optimization report to remove the sensitivity level ([#1041](https://github.com/microsoft/finops-toolkit/issues/1041)).

### FinOps hubs v0.6 update 1

- **Added**
  - Added [compatibility guide](hubs/compatibility.md) to identify when changes are compatible with older Power BI reports.
- **Changed**
  - Updated the [upgrade guide](hubs/upgrade.md) to account for changes in 0.5 and 0.6.
- **Fixed**
  - Fixed the reservation details mapping file.

<br>

## v0.6

<sup>Released October 2, 2024</sup>

### FinOps guide v0.6

- **Added**
  - Started a FinOps best practices library using Azure Resource Graph (ARG) queries from the Cost optimization workbook.

### Power BI reports v0.6

#### General Power BI updates v0.6

- **Added**
  - Add sample tags to promote to separate `tag_*` columns
  - Documented [how to connect to Power BI reports using storage account SAS tokens](power-bi/setup.md).
  - Documented [how to preview reports with sample data using Power BI Desktop](hubs/finops-hubs-overview.md).
- **Changed**
  - Renamed Prices `ChargePeriodStart`/`*End` to `x_EffectivePeriodStart`/`*End`.
  - Removed auto-created date tables.
- **Fixed**
  - Improved import performance by using parquet metadata to filter files by date (if configured).
  - Improved performance of column updates in CostDetails and Prices queries.
  - In the Prices query, fixed bug where `SkuID` was not merged into `x_SkuId`.

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

### FinOps hubs v0.6

- **Added**
  - Support for Cost Management parquet and GZip CSV exports.
  - Support for ingesting price, reservation recommendation, reservation detail, and reservation transaction datasets via Cost Management exports.
  - Compatibility guide to explain what versions of hubs and Power BI reports work together.
  - New UnsupportedExportFileType error when the exported file type is not supported.
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

### FinOps workbooks v0.6

- **Added**
  - Created an option to deploy all [general-purpose FinOps toolkit workbooks](workbooks/finops-workbooks-overview.md) together.
    - Does not include workbooks specific to Optimization Engine.

### Optimization engine v0.6

- **Added**
  - [Troubleshooting documentation page](optimization-engine/troubleshooting.md) with the most common deployment and runtime issues and respective solutions or troubleshooting steps.
- **Changed**
  - Replaced storage account key-based authentication with Entra ID authentication for improved security.
- **Fixed**
  - Added expiring savings plans and reservations to usage workbooks ([#1014](https://github.com/microsoft/finops-toolkit/issues/1014)).
- Deprecated
  - With the deprecation of the legacy Log Analytics agent in August 31, the `Setup-LogAnalyticsWorkspaces` script is no longer being maintained and will be removed in a future update.
    - The script was used to setup performance counters collection for machines connected to Log Analytics workspaces with the legacy agent. 
    - We recommend migrating to the [Azure Monitor Agent](/azure/azure-monitor/agents/azure-monitor-agent-migration) and use the `Setup-DataCollectionRules` script to [setup performance counters collection with Data Collection Rules](optimization-engine/configure-workspaces.md).

### PowerShell module v0.6

- **Changed**
  - Added a -ServiceSubcategory filter option to the [Get-FinOpsService command](../powershell/data/Get-FinOpsService.md).

### Open data v0.6

#### [Resource types v0.6](open-data.md#resource-types)

- **Added**
  - Added 13 new Microsoft.Billing resource types.
  - Added 17 new Microsoft.ComputeHub resource types.
  - Added 2 new Microsoft.DeviceOnboarding resource types.
  - Added 8 new Microsoft.Edge resource types.
  - Added 8 other new resource types: "microsoft.agricultureplatform/agriservices", "microsoft.azurefleet/fleetscomputehub", "microsoft.cloudtest/buildcaches", "microsoft.contoso/employees/desks", "microsoft.databasefleetmanager/fleets", "microsoft.resources/databoundaries", "microsoft.subscription/changetenantrequest", "microsoft.sustainabilityservices/calculations".
- **Changed**
  - Updated 2 Microsoft.DurableTask resource types.
  - Updated 4 Microsoft.SignalRService resource types.
  - Updated 4 Microsoft.TimeSeriesInsights resource types.
  - Updated 4 other resource type: "microsoft.network/dnsresolvers", "microsoft.search/searchservices", "microsoft.storagepool/diskpools/iscsitargets", "oracle.database/oraclesubscriptions".

#### [Services v0.6](open-data.md#services)

- **Added**
  - Added a new ServiceSubcategory column to support FOCUS 1.1 ServiceSubcategory mapping.
  - Added the following resource types to existing services:  "microsoft.apimanagement/gateways", "microsoft.sql/longtermretentionmanagedinstances", "microsoft.sql/longtermretentionservers", "microsoft.verifiedid/authorities".

[Download v0.6](https://github.com/microsoft/finops-toolkit/releases/tag/v0.6) &nbsp; [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.5...v0.6)

<br>

## v0.5 Update 1

<sup>Released September 7, 2024</sup>

This release is a minor patch to Power BI files. These files were updated in the existing 0.5 release. We are documenting this as a new patch release for transparency.

### Power BI reports v0.5 update 1

- **Fixed**
  - Corrected a bug where ADLS data sources could not be refreshed from the Power BI service ([#964](https://github.com/microsoft/finops-toolkit/issues/964)).
    > _This updated all PBIX/PBIT files downloaded between September 1-6, 2024. If you are using one of these files and plan to publish it to the Power BI service, please update to the latest version of the PBIX or PBIT files._

<br>

## v0.5

<sup>Released September 1, 2024</sup>

### FinOps guide v0.5

- **Added**
  - Documented [how to compare FOCUS and actual/amortized data](../focus/validate.md) to learn and validate FOCUS data.

### Power BI reports v0.5

#### General Power BI updates v0.5

- **Changed**
  - Updated `ListCost`, `ListUnitPrice`, `ContractedCost`, and `ContractedUnitPrice` when not provided in Cost Management exports.
    - Contracted cost/price are set to effective cost/price when not available.
    - List cost/price are set to contracted cost/price when not available.
    - This means savings can be calculated, but will not be complete.
    - Refer to the Data quality page for details about missing or updated data.
  - Added support for pointing Power BI reports to directly to Cost Management exports (without FinOps hubs).
  - Added new tables for Prices, ReservationDetails, ReservationRecommendations, and ReservationTransactions (works with exports only; does not work with hubs).
- **Fixed**
  - Fixed a bug in Cost Management exports where committed usage is showing as "Standard" pricing category.

#### [Cost summary report v0.5](power-bi/cost-summary.md)

- **Changed**
  - Added a table to the [Data quality page](power-bi/cost-summary.md#data-quality) to identify rows for which a unique ID cannot be identified.
  - Added a table to the [Data quality page](power-bi/cost-summary.md#data-quality) to identify rows where billing currency and pricing currency are different.

#### [Rate optimization report v0.5](power-bi/rate-optimization.md)

- **Changed**
  - Commitment savings no longer filters out rows with missing list/contracted cost.
    - Since `ListCost` and `ContractedCost` are set to a fallback value when not included in Cost Management data, we can now calculate partial savings.
    - Calculated savings is still incomplete since we do not have accurate list/contracted cost values.
  - Merged shared and single reservation recommendations into a single [Reservation recommendations](power-bi/rate-optimization.md#reservation-recommendations) page.

### FinOps hubs v0.5

- **Added**
  - Added an optional `skipEventGridRegistration` template parameter to support skipping Event Grid RP registration.
  - Added an Event Grid section to the hubs create form.
- **Changed**
  - Changed the Event Grid location selection logic to only identify fallback regions rather than supported regions.
  - Expanded cost estimate documentation to call out Power BI pricing and include a link to the Pricing Calculator.
- **Fixed**
  - Updated the config_ConfigureExports pipeline to handle when scopes in settings.json is not an object.
  - Fixed a bug where scopes added via the Add-FinOpsHubScope command are not added correctly due to missing brackets.

### FinOps workbooks v0.5

#### [Optimization workbook v0.5](workbooks/optimization.md)

- **Added**
  - New compute query to identify VMs per processor architecture type
  - New database query to identify SQL Pool instances with 0 databases
  - New storage query to identify Powered Off VMs with Premium Disks
- **Changed**
  - Redesign of the Rate Optimization tab for easier identification of the break-even point for reservations
  - Fixed the AHB VMSS query to count the total cores consumed per the entire scale set
  - Improved storage idle disks query to ignore disks used by AKS pods
  - Updated Storage not v2 query to exclude blockBlobStorage accounts from the list
  - Added export option for the list of idle backups to streamline data extraction

#### [Governance workbook v0.5](workbooks/governance.md)

- **Changed**
  - Removed the management group filter to simplify filtering by subscription.

### Optimization engine v0.5

- **Added**
  - `Register-MultitenantAutomationSchedules` PowerShell script helper to [add a different Azure tenant to the scope of AOE](optimization-engine/customize.md).
  - ZRS disks included in the scope of the `Premium SSD disk has been underutilized` recommendation (besides LRS).
  - Option to scope consumption exports to MCA Billing Profile.
- **Changed**
  - Improved SQL Database security, replacing SQL authentication by Entra ID authentication-only.
- **Fixed**
  - `Premium SSD disk has been underutilized` recommendation was not showing results due to a meter name change in Cost Management ([#831](https://github.com/microsoft/finops-toolkit/issues/831)).
  - Consumption exports for Pay-As-You-Go MCA subscriptions were missing cost data ([#828](https://github.com/microsoft/finops-toolkit/issues/828))

### PowerShell module v0.5

- **Added**
  - Added support for FOCUS, pricesheet, and reservation dataset filters in [Get-FinOpsCostExport](powershell/cost/Get-FinOpsCostExport.md).
  - Added a `-DatasetVersion` filter in [Get-FinOpsCostExport](powershell/cost/Get-FinOpsCostExport.md).
- **Changed**
  - Update Get-AzAccessToken calls to use -AsSecureString ([#946](https://github.com/microsoft/finops-toolkit/issues/946)).
- **Fixed**
  - Fixed [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md) to address breaking change in Cost Management when storage paths start with "/".
  - Fixed a bug where scopes added via the Add-FinOpsHubScope command are not added correctly due to missing brackets.

### Open data v0.5

#### [Pricing units v0.5](open-data.md#pricing-units)

- **Added**
  - Added handling for the following new UnitOfMeasure values: "1 /Minute", "10 PiB/Hour", "100000 /Month", "Text".
- **Changed**
  - Changed DistinctUnits for the "10000s" UnitOfMeasure from "Units" to "Transactions".

#### [Regions v0.5](open-data.md#️regions)

- **Added**
  - Added the following new region values: "asiapacific", "australia", azure "stack", "eastsu2", "gbs", germany west "central", "japan", sweden "central", "unitedstates", us dod "central", us dod "east", us gov "iowa", us gov "virginia", "us2", "usa", "usv".

#### [Resource types v0.5](open-data.md#️resource-types)

- **Added**
  - Added the following new resource types: "microsoft.app/logicapps", "microsoft.app/logicapps/workflows", "microsoft.azurebusinesscontinuity/deletedunifiedprotecteditems", "microsoft.azurebusinesscontinuity/unifiedprotecteditems", "microsoft.azurecis/publishconfigvalues", "microsoft.compositesolutions/compositesolutiondefinitions", "microsoft.compositesolutions/compositesolutions", "microsoft.compute/capacityreservationgroups/capacityreservations", "microsoft.compute/virtualmachinescalesets/virtualmachines", "microsoft.datareplication/replicationvaults/alertsettings", "microsoft.datareplication/replicationvaults/events", "microsoft.datareplication/replicationvaults/jobs", "microsoft.datareplication/replicationvaults/jobs/operations", "microsoft.datareplication/replicationvaults/operations", "microsoft.datareplication/replicationvaults/protecteditems", "microsoft.datareplication/replicationvaults/protecteditems/operations", "microsoft.datareplication/replicationvaults/protecteditems/recoverypoints", "microsoft.datareplication/replicationvaults/replicationextensions", "microsoft.datareplication/replicationvaults/replicationextensions/operations", "microsoft.datareplication/replicationvaults/replicationpolicies", "microsoft.datareplication/replicationvaults/replicationpolicies/operations", "microsoft.deviceregistry/billingcontainers", "microsoft.deviceregistry/discoveredassetendpointprofiles", "microsoft.deviceregistry/discoveredassets", "microsoft.deviceregistry/schemaregistries", "microsoft.deviceregistry/schemaregistries/schemas", "microsoft.deviceregistry/schemaregistries/schemas/schemaversions", "microsoft.eventgrid/systemtopics/eventsubscriptions", "microsoft.hardware/orders", "microsoft.hybridcompute/machines/microsoft.awsconnector/ec2instances", "microsoft.hybridonboarding/extensionmanagers", "microsoft.iotoperations/instances", "microsoft.iotoperations/instances/brokers", "microsoft.iotoperations/instances/brokers/authentications", "microsoft.iotoperations/instances/brokers/authorizations", "microsoft.iotoperations/instances/brokers/listeners", "microsoft.iotoperations/instances/dataflowendpoints", "microsoft.iotoperations/instances/dataflowprofiles", "microsoft.iotoperations/instances/dataflowprofiles/dataflows", "microsoft.messagingconnectors/connectors", "microsoft.mobilepacketcore/networkfunctions", "microsoft.saashub/cloudservices/hidden", "microsoft.secretsynccontroller/azurekeyvaultsecretproviderclasses", "microsoft.secretsynccontroller/secretsyncs", "microsoft.storagepool/diskpools/iscsitargets", "microsoft.usagebilling/accounts/dataexports", "microsoft.usagebilling/accounts/metricexports", "microsoft.windowsesu/multipleactivationkeys".
- **Changed**
  - Updated the following resource types: "microsoft.apimanagement/gateways", "microsoft.azurearcdata/sqlserveresulicenses", "microsoft.azurestackhci/edgenodepools", "microsoft.azurestackhci/galleryimages", "microsoft.azurestackhci/logicalnetworks", "microsoft.azurestackhci/marketplacegalleryimages", "microsoft.azurestackhci/networkinterfaces", "microsoft.azurestackhci/storagecontainers", "microsoft.cache/redisenterprise", "microsoft.cache/redisenterprise/databases", "microsoft.databricks/accessconnectors", "microsoft.datareplication/replicationvaults", "microsoft.devhub/iacprofiles", "microsoft.edge/sites", "microsoft.eventhub/namespaces", "microsoft.hybridcompute/gateways", "microsoft.impact/connectors", "microsoft.iotoperationsorchestrator/instances", "microsoft.iotoperationsorchestrator/solutions", "microsoft.iotoperationsorchestrator/targets", "microsoft.kubernetesruntime/loadbalancers", "microsoft.manufacturingplatform/manufacturingdataservices", "microsoft.network/dnsforwardingrulesets", "microsoft.network/dnsresolvers", "microsoft.network/dnszones", "microsoft.powerbidedicated/capacities", "microsoft.programmableconnectivity/gateways", "microsoft.programmableconnectivity/operatorapiconnections", "microsoft.programmableconnectivity/operatorapiplans", "microsoft.resources/subscriptions/resourcegroups", "microsoft.security/pricings", "microsoft.sovereign/transparencylogs", "microsoft.storagepool/diskpools".
  - Updated multiple resource types for the following resource providers: "microsoft.awsconnector".
  - Changed the following resource providers to be GA: "microsoft.modsimworkbench".
- **Removed**
  - Removed internal "microsoft.cognitiveservices/browse*" resource types.

#### [Services v0.5](open-data.md#️services)

- **Added**
  - Added the following consumed services:  "API Center", "API Management", "Bastion Scale Units", "Microsoft.Community", "Microsoft.DataReplication.Admin", "Microsoft.DevOpsInfrastructure", "Microsoft.Dynamics365FraudProtection", "Microsoft.HybridContainerService", "Microsoft.NetworkFunction", "Microsoft.RecommendationsService", "Microsoft.ServiceNetworking", "Virtual Network".
  - Added the following resource types to existing services:  "Microsoft.AgFoodPlatform/farmBeats", "Microsoft.App/sessionPools", "Microsoft.AzureActiveDirectory/ciamDirectories", "Microsoft.AzureArcData/sqlServerEsuLicenses", "Microsoft.Graph/accounts", "Microsoft.MachineLearningServices/registries", "Microsoft.Orbital/groundStations", "PlayFabBillingService/partyVoice".
- **Changed**
  - Moved Microsoft Genomics from the "AI and Machine Learning" service category to "Analytics".
  - Changed Microsoft Genomics from the "SaaS" service model to "PaaS".
  - Replace "Azure Active Directory" service name references with "Microsoft Entra".
  - Move Azure Cache for Redis from the "Storage" service category to "Databases".
  - Move Event Hubs from the "Integration" service category to "Analytics".
  - Rename the Microsoft.HybridCompute consumed service service name from "Azure Resource Manager" to "Azure Arc".
  - Move Microsoft Defender for Endpoint from the "Multicloud" service category to "Security".
  - Move StorSimple from the "Multicloud" service category to "Storage".

[Download v0.5](https://github.com/microsoft/finops-toolkit/releases/tag/v0.5) &nbsp; [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.4...v0.5)

<br>

## v0.4

<sup>Released July 12, 2024</sup>

### FinOps guide v0.4

- **Added**
  - Documented the [FOCUS export dataset](../focus/metadata.md) to align to the FOCUS metadata specification.
- **Changed**
  - Updated [FinOps Framework guidance](../framework/finops-framework.md) to account for the 2024 updates.
  - Updated [FOCUS guidance](../focus/what-is-focus.md) to FOCUS 1.0.

### FinOps hubs v0.4

- **Added**
  - Ingest FOCUS 1.0 data in FinOps hubs.
  - Grant access to FinOps hubs to [create and manage exports](hubs/configure-scopes.md#-configure-managed-exports) for you.
  - Connect to a hub instance in another Entra ID tenant.
  - Step-by-step troubleshooting guide and expanded set of common errors for validating FinOps hubs and Power BI setup.
- **Fixed**
  - Fixed an issue where some dates are showing as off by 1 based on local time zone.
    - If you see dates that are off, upgrade to 0.4 and re-export those months. The fix is in ingestion.
    - You can re-export data in FOCUS 1.0 or FOCUS 1.0 preview. We recommend FOCUS 1.0 for slightly faster refresh times in Power BI.

### Power BI reports v0.4

#### General Power BI updates v0.4

- **Added**
  - **x_IncrementalRefreshDate** column to facilitate configuring incremental refresh in Power BI.
  - Step-by-step troubleshooting guide and expanded set of common errors for validating Power BI setup.
- **Changed**
  - Changed the **Tags** column to default to `{}` when empty to facilitate tag expansion ([#691](https://github.com/microsoft/finops-toolkit/issues/691#issuecomment-2134072033)).
  - Simplified formatting for the `BillingPeriod` and `ChargePeriod` measures in Power BI.
  - Improved error handling for derived savings columns in the CostDetails query.
  - Simplified queries and improved error handling in the START HERE query for report setup steps.
  - Changed internal storage for reports to use [Tabular Model Definition Language (TMDL)](/power-bi/developer/projects/projects-dataset#tmdl-format).
    - This change makes it easier to review changes to the data model in Power BI.
    - Reports will still be released as PBIX files so this change should not impact end users.
    - Visualizations are not being switched to [Power BI Enhanced Report (PBIR)](/power-bi/developer/projects/projects-report#pbir-format) format yet due to functional limitations that would impact end users (as of June 2024).
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

### FinOps workbooks v0.4

#### [Optimization workbook v0.4](workbooks/optimization.md)

- **Added**
  - Added reservation recommendations with the break-even point to identify when savings would be achieved.
  - Identify idle ExpressRoute circuits to streamline costs.
  - Gain insights into the routing preferences for public IP addresses to optimize network performance.
  - Explore commitment discount savings to get a clear overview of rate optimization opportunities.
  - Quickly view public IP addresses with DDoS protection enabled and compare if it would be cheaper to enable DDoS to the vNet instead.
  - Identify Azure Hybrid Benefit usage for SQL Database elastic pools to maximize cost efficiency.
- **Changed**
  - Redesigned the Sustainability tab to clarify recommendations.
  - Ignore dynamic IPs in the public IP addresses list to ensure more accurate results.
  - Ignore free tier web apps to provide a clearer picture of your top services.

#### [Governance workbook v0.4](workbooks/governance.md)

- **Added**
  - Added managed disk usage monitoring.
- **Changed**
  - Overview has been revised to align with the latest governance principles of the cloud adoption framework.

### Optimization engine v0.4

- **Added**
  - Added Azure Optimization Engine (AOE), an extensible solution for custom optimization recommendations.

### PowerShell module v0.4

- **Added**
  - Added progress tracking to [Start-FinOpsCostExport](powershell/cost/Start-FinOpsCostExport.md) for multi-month exports.
  - Added a 60-second delay when Cost Management returns throttling (429) errors in [Start-FinOpsCostExport](powershell/cost/Start-FinOpsCostExport.md).
- **Changed**
  - Updated [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md) to default to FOCUS 1.0.
- **Removed**
  - Removed support for Windows PowerShell.
    > _We discovered errors with Windows PowerShell due to incompatibilities in Windows PowerShell and PowerShell 7. Due to our limited capacity, we decided to only support [PowerShell 7](/powershell/scripting/install/installing-powershell) going forward._
  - Removed `ConvertTo-FinOpsSchema` and `Invoke-FinOpsSchemaTransform` commands which were deprecated in [0.2 (January 2024)](#v02).

### Open data v0.4

- **Added**
  - Added a new FOCUS 1.0 [dataset example](open-data.md#️dataset-examples).
  - Added [dataset metadata](open-data.md#️dataset-metadata) for FOCUS 1.0 and FOCUS 1.0-preview.
- **Changed**
  - Updated all [open data files](open-data.md) to include the latest data.
  - Changed the primary columns in the [Regions](open-data.md#️regions) and [Services](open-data.md#️services) open data files to be lowercase.
  - Updated all [sample exports](open-data.md#️dataset-examples) to use the same date range as the FOCUS 1.0 dataset.

[Download v0.4](https://github.com/microsoft/finops-toolkit/releases/tag/v0.4) &nbsp; [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.3...v0.4)

<br>

## v0.3

<sup>Released March 28, 2024</sup>

### FinOps guide v0.3

- **Added**
  - Moved Azure FinOps documentation about how to implement and adopt FinOps into the toolkit repository.
- **Changed**
  - Rearranged documentation site to better organize content.

### FinOps hubs v0.3

- **Added**
  - Started archiving template versions so they can be referenced easily via URL microsoft.github.io/finops-toolkit/deploy/finops-hub-{version}.json.
- **Fixed**
  - Fixed "missing period" error Data Factory Studio.
  - Fixed bug where `msexports_FileAdded` trigger was not getting started.
  - Fixed deploy to Azure buttons to point to the latest release.
- **Changed**
  - Return a single boolean value from the Remove-FinOpsHub command.

### Power BI reports v0.3

#### General Power BI updates v0.3

- **Added**
  - Added `ResourceParentId`, `ResourceParentName`, and `ResourceParentType` columns to support the usage of the user-defined `cm-resource-parent` tag.
  - Added `ToolkitVersion` and `ToolkitTool` columns to help quantify the cost of FinOps toolkit solutions.
  - Added a Data quality page to the [Commitment discounts report](power-bi/rate-optimization.md#data-quality) for data quality validations. This page can be useful in identifying data gaps in Cost Management.
  - Added `x_NegotiatedUnitPriceSavings` column to show the price reduction from negotiated discounts compared to the public, list price.
  - Added `x_IsFree` column to indicate when a row represents a free charge (based on Cost Management data). This is used in data quality checks.
  - Added `Tags` and `TagsAsJson` columns to both the **Usage details** and **Usage details amortized** tables in the [CostManagementTemplateApp report](power-bi/template-app.md) ([#625](https://github.com/microsoft/finops-toolkit/issues/625)).
- **Changed**
  - Changed "Other" ChargeSubcategory for usage to "On-Demand" to be consistent with Cost Management exports
  - Renamed savings columns for consistency:
    - `x_OnDemandUnitPriceSavings` is now `x_CommitmentUnitPriceSavings`. This shows the commitment discount price reduction compared to the negotiated prices for the account.
    - `x_ListUnitPriceSavings` is now `x_DiscountUnitPriceSavings`. This shows the price reduction from all discounts compared to the public, list price.
    - `x_NegotiatedSavings` is now `x_NegotiatedCostSavings`. This shows the cost savings from negotiated discounts only (excluding commitment discounts).
    - `x_CommitmentSavings` is now `x_CommitmentCostSavings`. This shows the cost savings from commitment discounts compared to on-demand prices for the account (including negotiated discounts).
    - `x_DiscountSavings` is now `x_DiscountCostSavings`. This shows the cost savings from all negotiated and commitment discounts.
  - Changed the `PricingQuantity` and `UsageQuantity` columns to use 3 decimal places.
  - Changed all cost columns to use 2 decimal places.
  - Changed all unit price columns to not summarize by default and use 3 decimal places.
  - Changed the `x_PricingBlockSize` column to a whole number and not summarize by default.
- **Fixed**
  - Fixed data issue where Cost Management uses "1Year", "3Years", and "5Years" for the x_SkuTerm. Values should be 12, 36, and 60 ([#594](https://github.com/microsoft/finops-toolkit/issues/594)).
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

### PowerShell module v0.3

- **Added**
  - [Get-FinOpsService](powershell/data/Get-FinOpsService.md) includes new `-Environment` and `-ServiceModel` filters and properties in the response ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).
- **Changed**
  - [Start-FinOpsCostExport](powershell/cost/Start-FinOpsCostExport.md) includes a new `-Backfill` option to backfill multiple months.
  - [Start-FinOpsCostExport](powershell/cost/Start-FinOpsCostExport.md) includes a new `-StartDate` and `-EndDate` options to run the export for a given date range. This can include multiple months.
- **Fixed**
  - Fixed ParameterBindingException error in [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md).
  - Updated the FOCUS dataset version that was changed in Cost Management exports in [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md).
  - Changed the default `-EndDate` in [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md) to be the end of the month due to a breaking change in Cost Management exports.
  - Fixed internal command used in [Deploy-FinOpsHub](powershell/hubs/Deploy-FinOpsHub.md) that may have caused it to fail for some versions of the Az PowerShell module.

### Open data v0.3

- **Added**
  - Added ServiceModel and Environment columns to the [services](open-data.md#services) data ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).
  - New and updated [resource types](open-data.md#resource-types) and icons.

[Download v0.3](https://github.com/microsoft/finops-toolkit/releases/tag/v0.3) &nbsp; [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.2...v0.3)

<br>

## v0.2

<sup>Released January 22, 2024</sup>

### FinOps hubs v0.2

<small>**Breaking change**</small>

- **Fixed**
  - Fixed error in some China regions where deployment scripts were not supported ([#259](https://github.com/microsoft/finops-toolkit/issues/259)).
- **Changed**
  - Switch from amortized cost exports to FOCUS cost exports.
    > [!NOTE]
    > This change requires re-ingesting historical data and is not backwards compatible. The unified schema used in this release is aligned with the future plans for Microsoft Cost Management exports. Note the next release will update the schema to align to the FinOps Open Cost and Usage Specification (FOCUS).
  - Updated ingestion container month folders from `yyyyMMdd-yyyyMMdd` to `yyyyMM`.
  - Renamed **msexports_extract** pipeline to **msexports_ExecuteETL**.
  - Renamed **msexports_transform** pipeline to **msexports_ETL_ingestion**.

### Power BI reports v0.2

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
    - Error message: "You can't schedule refresh for this semantic model because the following data sources currently don't support refresh..."
  - Fixed error in ChargeId column when ResourceId is empty.
  - Removed the ChargeId column due to it bloating the data size.
    - The field is commented out. If interested, you can enable uncomment it in the ftk_NormalizeSchema function. Just be aware that it duplicates a lot of columns to ensure uniqueness which bloats the data size significantly.
  - Fixed null error when Billing Account ID is empty ([#473](https://github.com/microsoft/finops-toolkit/issues/473)).
  - Added missing commitment discount refunds to the actual cost data ([#447](https://github.com/microsoft/finops-toolkit/issues/447)).

#### [Cost Management connector report v0.2](power-bi/connector.md)

- **Added**
  - Added new report to support the Cost Management connector.

### FinOps workbooks v0.2

#### [Optimization workbook v0.2](workbooks/optimization.md)

- **Added**
  - Storage: Identify Idle Backups: Review protected items' backup activity to spot items not backed up in the last 90 days.
  - Storage: Review Replication Settings: Evaluate and improve your backup strategy by identifying resources with default geo-redundant storage (GRS) replication.
  - Networking: Azure Firewall Premium Features: Identify Azure Firewalls with Premium SKU and ensure associated policies leverage premium-only features.
  - Networking: Firewall Optimization: Streamline Azure Firewall usage by centralizing instances in the hub virtual network or Virtual WAN secure hub.
- **Changed**
  - Top 10 services: Improved Monitoring tabs: Enhance your monitoring experience with updated Azure Advisor recommendations for Log Analytics.
- **Fixed**
  - AHB: Fixed AHB to support Windows 10/Windows 11

### PowerShell module v0.2

- **Added**
  - [New-FinOpsCostExport](powershell/cost/New-FinOpsCostExport.md) to create and update Cost Management exports.
  - [Start-FinOpsCostExport](powershell/cost/Start-FinOpsCostExport.md) to run a Cost Management export immediately.
  - [Get-FinOpsCostExport](powershell/cost/Get-FinOpsCostExport.md) now has a `-RunHistory` option to include the run history of each export.
- **Changed**
  - Updated the default API version for export commands to `2023-07-01-preview` to leverage new datasets and features.
    - Specify `2023-08-01` explicitly for the previous API version.
- **Fixed**
  - Fixed typo in [Deploy-FinOpsHub](powershell/hubs/Deploy-FinOpsHub.md) causing it to fail.
- Deprecated
  - `ConvertTo-FinOpsSchema` and `Invoke-FinOpsSchemaTransform` are no longer being maintained and will be removed in a future update.
    - With native support for FOCUS 1.0 preview in Cost Management, we are deprecating both commands, which only support FOCUS 0.5.
    - If you would like to see the PowerShell commands updated to 1.0 preview, please let us know in discussions or via a GitHub issue.

### Open data v0.2

- **Added**
  - [Resource types](open-data.md#resource-types) to map Azure resource types to friendly display names.
  - [Get-FinOpsResourceType](powershell/data/Get-FinOpsResourceType.md) PowerShell command to support resource type to display name mapping.
  - [Sample exports](open-data.md#sample-data) for each of the datasets that can be exported from Cost Management.

### FinOps guide v0.2

- **Added**
  - [FinOps Open Cost and Usage Specification (FOCUS) details](../focus/what-is-focus.md).

[Download v0.2](https://github.com/microsoft/finops-toolkit/releases/tag/v0.2) &nbsp; [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.1.1...v0.2)

<br>

## v0.1.1

<sup>Released October 26, 2023</sup>

### PowerShell module v0.1.1

- **Added**
  - New PowerShell commands to convert data to FOCUS 0.5:
    - ConvertTo-FinOpsSchema
    - Invoke-FinOpsSchemaTransform
  - New PowerShell commands to get and delete Cost Management exports:
    - [Get-FinOpsCostExport](powershell/cost/Get-FinOpsCostExport.md)
    - [Remove-FinOpsCostExport](powershell/cost/Remove-FinOpsCostExport.md)

### Open data v0.1.1

- **Added**
  - New PowerShell commands to integrate open data to support data cleansing:
    - [Get-FinOpsPricingUnit](powershell/data/Get-FinOpsPricingUnit.md)
    - [Get-FinOpsRegion](powershell/data/Get-FinOpsRegion.md)
    - [Get-FinOpsService](powershell/data/Get-FinOpsService.md)

### FinOps hubs v0.1.1

- **Added**
  - New PowerShell commands to manage FinOps hubs 0.1:
    - [Get-FinOpsHub](powershell/hubs/Get-FinOpsHub.md)
    - [Initialize-FinOpsHubDeployment](powershell/hubs/Initialize-FinOpsHubDeployment.md)
    - [Register-FinOpsHubProviders](powershell/hubs/Register-FinOpsHubProviders.md)
    - [Remove-FinOpsHub](powershell/hubs/Remove-FinOpsHub.md)

[Download v0.1.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1) &nbsp; [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.1...v0.1.1)

<br>

## v0.1

<sup>Released October 22, 2023</sup>

### PowerShell module v0.1

- **Added**
  - [FinOpsToolkit module](powershell/finops-toolkit-module.md) released in the PowerShell Gallery.
  - [Get-FinOpsToolkitVersion](powershell/toolkit/Get-FinOpsToolkitVersion.md) to get toolkit versions.

### FinOps hubs v0.1

- **Added**
  - [Deploy-FinOpsHub](powershell/hubs/Deploy-FinOpsHub.md) to deploy or update a hub instance.
  - [Get-FinOpsHub](powershell/hubs/Get-FinOpsHub.md) to get details about a hub instance.
  - Support for Microsoft Customer Agreement (MCA) accounts and Cloud Solution Provider (CSP) subscriptions in Power BI reports.
- **Fixed**
  - Storage redundancy dropdown default not set correctly in the create form.
  - Tags specified in the create form were causing the deployment to fail ([#331](https://github.com/microsoft/finops-toolkit/issues/331)).

### Power BI reports v0.1

- **Added**
  - Commitments, Savings, Chargeback, Purchases, and Prices pages in the [Commitment discounts report](power-bi/rate-optimization.md).
  - Prices page in the [Cost summary report](power-bi/cost-summary.md).
  - [FOCUS sample report](power-bi/focus.md) – See your data in the FinOps Open Cost and Usage Specification (FOCUS) schema.
  - [Cost Management template app](power-bi/template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.
- **Changed**
  - Expanded the FinOps hubs Cost summary and Commitment discounts [Power BI reports](power-bi/reports.md) to support the Cost Management connector.

### FinOps workbooks v0.1

- **Added**
  - [Governance workbook](workbooks/governance.md) to centralize governance.
- **Changed**
  - [Optimization workbook](workbooks/optimization.md) updated to cover more scenarios.

### Open data v0.1

- **Added**
  - [Pricing units](open-data.md#pricing-units) to map all pricing units (UnitOfMeasure values) to distinct units with a scaling factor.
  - [Regions](open-data.md#regions) to map historical resource location values in Microsoft Cost Management to standard Azure regions.
  - [Services](open-data.md#services) to map all resource types to FOCUS service names and categories.

[Download v0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1) &nbsp; [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.0.1...v0.1)

<br>

## v0.0.1

<sup>Released May 27, 2023</sup>

### FinOps hubs v0.0.1

- **Added**
  - [FinOps hub template](hubs/finops-hubs-overview.md) to deploy a storage account and Data Factory instance.
  - [Cost summary report](power-bi/cost-summary.md) for various out-of-the-box cost breakdowns.
  - [Commitment discounts report](power-bi/rate-optimization.md) for commitment-based discount reports.

### Bicep Registry modules v0.0.1

- **Added**
  - [Scheduled action modules](bicep-registry/scheduled-actions.md) submitted to the Bicep Registry.

### FinOps workbooks v0.0.1

- **Added**
  - [Cost optimization workbook](workbooks/optimization.md) to centralize cost optimization.

[Download v0.0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.0.1) &nbsp; [Full changelog](https://github.com/microsoft/finops-toolkit/compare/878e4864ca785db4fc13bdd2ec3a6a00058688c3...v0.0.1)

<br>
