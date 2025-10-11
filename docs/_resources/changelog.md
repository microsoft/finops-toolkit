---
layout: default
title: Changelog
nav_order: zzz
description: 'Latest and greatest features and enhancements from the FinOps toolkit.'
permalink: /changelog
---

<span class="fs-9 d-block mb-4">FinOps toolkit changelog</span>
Explore the latest and greatest features and enhancements from the FinOps toolkit.
{: .fs-6 .fw-300 }

[Download the latest release](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[See changes](#latest){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🔄️ Unreleased](#️-unreleased)
- [🪛 v0.6 Update 1](#-v06-update-1)
- [🚚 v0.6](#-v06)
- [🪛 v0.5 Update 1](#-v05-update-1)
- [🚚 v0.5](#-v05)
- [🚚 v0.4](#-v04)
- [🚚 v0.3](#-v03)
- [🚚 v0.2](#-v02)
- [🛠️ v0.1.1](#️-v011)
- [🚚 v0.1](#-v01)
- [🌱 v0.0.1](#-v001)

</details>

---

<!-- markdownlint-disable MD036 -->

<!--
Legend:
🔄️ Unreleased
🚀🎉 Major
🚚💎 Minor
🛠️✨ Patch
🪛⬆️ Update
🌱 Pre-release

➕ Added
✏️ Changed
🛠️ Fixed
🚫 Deprecated
🗑️ Removed

📒 Workbook
🏦 FinOps hubs
🖥️ PowerShell
-->

## 🔄️ Unreleased

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Analytics engine – Ingest cost data into an Azure Data Explorer cluster.
> 2. Auto-backfill – Backfill historical data from Microsoft Cost Management.
> 3. Retention – Configure how long you want to keep Cost Management exports and normalized data in storage.
> 4. ETL pipelile – Add support for parquet files created by Cost Management exports.
> 5. Private endpoints support.
>    - Added private endpoints for storage account & Keyvault.
>    - Added managed virtual network & storage endpoint for Azure Data Factory Runtime.
>    - All data processing now happens within a vNet.
>    - Added param to disable external access to data lake
>    - Added param to specify subnet range of vnet - minumum size = /27

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - General
>   1. Populate missing prices.

🦾 Bicep modules
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Cost Management export modules for subscriptions and resource groups.
>

📗 FinOps guide
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ✏️ Changed:
>
> 1. Added Enterprise App Patterns links resources to the architecting for the cloud section.
> 2. Improved Compute best practices documentation: removed Advisor section, standardized KQL formatting in VM disks query, and created separate Virtual machine scale sets section.

🔍 Optimization engine
{: .fs-5 .fw-500 .mt-4 mb-0 }

> 🛠️ Fixed:
>
> 1. Exports ingestion issues in cases where exports come with empty lines ([#998](https://github.com/microsoft/finops-toolkit/issues/998))
> 1. Missing columns in EA savings plans exports ([#1026](https://github.com/microsoft/finops-toolkit/issues/1026))

<br><a name="latest"></a>

## 🚚 v0.7


📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> 🛠️ **Fixed:**
> - Minor bug fixes:
>   - **Commitment discounts**:
>     - Fixed RI ROWS Limited
>   - **Storage**:
>     - Included tag "RSVaultBackup" in the list of non-idle disks
>   - **Compute**:
>     - Fixed incorrect VM processor in "processors" query
>   - **Database**:
>     - Removed Idle SQLDB query to be re-evaluated by engineering


## 🪛 v0.6 Update 1

<sup>Released October 5, 2024</sup>

This release is a minor patch to update documentation and fix Rate optimization and Data ingestion Power BI files. These files were updated in the existing 0.6 release. We are documenting this as a new patch release for transparency. If you downloaded these files between October 2-4, 2024, please update to the latest version.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Documented the need to configure both **Hub Storage URL** and **Export Storage URL** when publishing reports to the Power BI service ([#1033](https://github.com/microsoft/finops-toolkit/issues/1033)).
>
> 🛠️ Fixed:
>
> 1. Updated the Data ingestion report to account for storage path changes ([#1043](https://github.com/microsoft/finops-toolkit/issues/1043)).
> 2. Updated the Rate optimization report to remove the sensitivity level ([#1041](https://github.com/microsoft/finops-toolkit/issues/1041)).

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added [compatibility guide](../_reporting/hubs/compatibility.md) to identify when changes are compatible with older Power BI reports.
>
> ✏️ Changed:
>
> 1. Updated the [upgrade guide](../_reporting/hubs/upgrade.md) to account for changes in 0.5 and 0.6.
>
> 🛠️ Fixed:
>
> 1. Fixed the reservation details mapping file.

<br>

## 🚚 v0.6

<sup>Released October 2, 2024</sup>

📗 FinOps guide
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Started a FinOps best practices library using Azure Resource Graph (ARG) queries from the Cost optimization workbook.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - General
>   1. Add sample tags to promote to separate `tag_*` columns
>   2. Documented [how to connect to Power BI reports using storage account SAS tokens](../_reporting/power-bi/setup.md).
>   3. Documented [how to preview reports with sample data using Power BI Desktop](../_reporting/hubs/README.md).
> - [Governance](../_reporting/power-bi/governance.md)
>   1. Added Policy compliance.
>   2. Added Virtual machines and managed disks.
>   3. Added SQL databases.
>   4. Added Network security groups.
> - [Workload optimization](../_reporting/power-bi/workload-optimization.md)
>   1. Added Azure Advisor cost recommendations.
>   2. Added Unattached disks.
>
> ✏️ Changed:
>
> - General
>   1. Renamed Prices `ChargePeriodStart`/`*End` to `x_EffectivePeriodStart`/`*End`.
>   2. Removed auto-created date tables.
>
> 🛠️ Fixed:
>
> - General
>   1. Improved import performance by using parquet metadata to filter files by date (if configured).
>   2. Improved performance of column updates in CostDetails and Prices queries.
>   3. In the Prices query, fixed bug where `SkuID` was not merged into `x_SkuId`.

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Support for Cost Management parquet and GZip CSV exports.
> 2. Support for ingesting price, reservation recommendation, reservation detail, and reservation transaction datasets via Cost Management exports.
> 3. Compatibility guide to explain what versions of hubs and Power BI reports work together.
> 4. New UnsupportedExportFileType error when the exported file type is not supported.
>
> ✏️ Changed:
>
> 1. Renamed the following pipelines to be clearer about their intent:
>    - `config_BackfillData` to `config_StartBackfillProcess`.
>    - `config_ExportData` to `config_StartExportProcess`.
>    - `config_RunBackfill` to `config_RunBackfillJob`.
>    - `config_RunExports` to `config_RunExportJobs`.
> 2. Changed the storage ingestion path from "{scope}/{yyyyMM}/{dataset}" to "{dataset}/{yyyy}/{MM}/{dataset}"
>
> 🛠️ Fixed:
>
> 1. Updated the `config_RunBackfillJob` and `config_StartExportProcess` pipelines to handle when there's a single scope defined in config instead of an array.
> 2. Corrected the reservation details version in the schema file name in storage.
>
> 🗑️ Removed
>
> 1. Removed the temporary Event Grid resource from the template.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Created an option to deploy all [general-purpose FinOps toolkit workbooks](../_optimize/workbooks/README.md) together.
>    - Does not include workbooks specific to Optimization Engine.

🔍 Optimization engine
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Troubleshooting documentation page](../_optimize/optimization-engine/troubleshooting.md) with the most common deployment and runtime issues and respective solutions or troubleshooting steps.
>
> ✏️ Changed:
>
> 1. Replaced storage account key-based authentication with Entra ID authentication for improved security.
>
> 🛠️ Fixed:
>
> 1. Added expiring savings plans and reservations to usage workbooks ([#1014](https://github.com/microsoft/finops-toolkit/issues/1014)).
>
> 🚫 Deprecated:
>
> 1. With the deprecation of the legacy Log Analytics agent in August 31, the `Setup-LogAnalyticsWorkspaces` script is no longer being maintained and will be removed in a future update.
>    - The script was used to setup performance counters collection for machines connected to Log Analytics workspaces with the legacy agent. 
>    - We recommend migrating to the [Azure Monitor Agent](https://learn.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-migration) and use the `Setup-DataCollectionRules` script to [setup performance counters collection with Data Collection Rules](https://aka.ms/AzureOptimizationEngine/workspaces).

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ✏️ Changed:
>
> 1. Added a -ServiceSubcategory filter option to the Get-FinOpsService command.

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - [Resource types](../_reporting/data/README.md#-resource-types)
>   1. Added 13 new Microsoft.Billing resource types.
>   2. Added 17 new Microsoft.ComputeHub resource types.
>   3. Added 2 new Microsoft.DeviceOnboarding resource types.
>   4. Added 8 new Microsoft.Edge resource types.
>   5. Added 8 other new resource types: "microsoft.agricultureplatform/agriservices", "microsoft.azurefleet/fleetscomputehub", "microsoft.cloudtest/buildcaches", "microsoft.contoso/employees/desks", "microsoft.databasefleetmanager/fleets", "microsoft.resources/databoundaries", "microsoft.subscription/changetenantrequest", "microsoft.sustainabilityservices/calculations".
> - [Services](../_reporting/data/README.md#-services)
>   1. Added a new ServiceSubcategory column to support FOCUS 1.1 ServiceSubcategory mapping.
>   2. Added the following resource types to existing services:  "microsoft.apimanagement/gateways", "microsoft.sql/longtermretentionmanagedinstances", "microsoft.sql/longtermretentionservers", "microsoft.verifiedid/authorities".
>
> ✏️ Changed:
>
> - [Resource types](../_reporting/data/README.md#-resource-types)
>   1. Updated 2 Microsoft.DurableTask resource types.
>   2. Updated 4 Microsoft.SignalRService resource types.
>   3. Updated 4 Microsoft.TimeSeriesInsights resource types.
>   4. Updated 4 other resource type: "microsoft.network/dnsresolvers", "microsoft.search/searchservices", "microsoft.storagepool/diskpools/iscsitargets", "oracle.database/oraclesubscriptions".

[Download v0.6](https://github.com/microsoft/finops-toolkit/releases/tag/v0.6){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.5...v0.6){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🪛 v0.5 Update 1

<sup>Released September 7, 2024</sup>

This release is a minor patch to Power BI files. These files were updated in the existing 0.5 release. We are documenting this as a new patch release for transparency.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> 🛠️ Fixed:
>
> 1. Corrected a bug where ADLS data sources could not be refreshed from the Power BI service ([#964](https://github.com/microsoft/finops-toolkit/issues/964)).
>    > _This updated all PBIX/PBIT files downloaded between September 1-6, 2024. If you are using one of these files and plan to publish it to the Power BI service, please update to the latest version of the PBIX or PBIT files._

<br>

## 🚚 v0.5

<sup>Released September 1, 2024</sup>

📗 FinOps guide
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Documented [how to compare FOCUS and actual/amortized data](../_docs/focus/validate.md) to learn and validate FOCUS data.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ✏️ Changed:
>
> - General
>   1. Updated `ListCost`, `ListUnitPrice`, `ContractedCost`, and `ContractedUnitPrice` when not provided in Cost Management exports.
>      - Contracted cost/price are set to effective cost/price when not available.
>      - List cost/price are set to contracted cost/price when not available.
>      - This means savings can be calculated, but will not be complete.
>      - Refer to the DQ page for details about missing or updated data.
>   2. Added support for pointing Power BI reports to directly to Cost Management exports (without FinOps hubs).
>   3. Added new tables for Prices, ReservationDetails, ReservationRecommendations, and ReservationTransactions (works with exports only; does not work with hubs).
> - [Cost summary](../_reporting/power-bi/cost-summary.md)
>   1. Added a table to the [DQ page](../_reporting/power-bi/cost-summary.md#dq) to identify rows for which a unique ID cannot be identified.
>   2. Added a table to the [DQ page](../_reporting/power-bi/cost-summary.md#dq) to identify rows where billing currency and pricing currency are different.
> - [Rate optimization](../_reporting/power-bi/rate-optimization.md)
>   1. Commitment savings no longer filters out rows with missing list/contracted cost.
>      - Since `ListCost` and `ContractedCost` are set to a fallback value when not included in Cost Management data, we can now calculate partial savings.
>      - Calculated savings is still incomplete since we do not have accurate list/contracted cost values.
>   2. Merged shared and single reservation recommendations into a single [Reservation recommendations](../_reporting/power-bi/rate-optimization.md#reservation-recommendations) page.
>
> 🛠️ Fixed:
>
> - General
>   1. Fixed a bug in Cost Management exports where committed usage is showing as "Standard" pricing category.

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added an optional `skipEventGridRegistration` template parameter to support skipping Event Grid RP registration.
> 2. Added an Event Grid section to the hubs create form.
>
> ✏️ Changed:
>
> 1. Changed the Event Grid location selection logic to only identify fallback regions rather than supported regions.
> 2. Expanded cost estimate documentation to call out Power BI pricing and include a link to the Pricing Calculator.
>
> 🛠️ Fixed:
>
> 1. Updated the config_ConfigureExports pipeline to handle when scopes in settings.json is not an object.
> 2. Fixed a bug where scopes added via the Add-FinOpsHubScope command are not added correctly due to missing brackets.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - [Optimization workbook](../_optimize/workbooks/optimization/README.md):
>   1. New compute query to identify VMs per processor architecture type
>   2. New database query to identify SQL Pool instances with 0 databases
>   3. New storage query to identify Powered Off VMs with Premium Disks
>
> ✏️ Changed:
>
> - [Optimization workbook](../_optimize/workbooks/optimization/README.md):
>   1. Redesign of the Rate Optimization tab for easier identification of the break-even point for reservations
>   2. Fixed the AHB VMSS query to count the total cores consumed per the entire scale set
>   3. Improved storage idle disks query to ignore disks used by AKS pods
>   4. Updated Storage not v2 query to exclude blockBlobStorage accounts from the list
>   5. Added export option for the list of idle backups to streamline data extraction
> - [Governance workbook](../_optimize/workbooks/governance/README.md):
>   1. Removed the management group filter to simplify filtering by subscription.

🔍 Optimization engine
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. `Register-MultitenantAutomationSchedules` PowerShell script helper to [add a different Azure tenant to the scope of AOE](../_optimize/optimization-engine/customize.md).
> 2. ZRS disks included in the scope of the `Premium SSD disk has been underutilized` recommendation (besides LRS).
> 3. Option to scope consumption exports to MCA Billing Profile.
>
> ✏️ Changed:
>
> 1. Improved SQL Database security, replacing SQL authentication by Entra ID authentication-only.
>
> 🛠️ Fixed:
>
> 1. `Premium SSD disk has been underutilized` recommendation was not showing results due to a meter name change in Cost Management ([#831](https://github.com/microsoft/finops-toolkit/issues/831)).
> 2. Consumption exports for Pay-As-You-Go MCA subscriptions were missing cost data ([#828](https://github.com/microsoft/finops-toolkit/issues/828))

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added support for FOCUS, pricesheet, and reservation dataset filters in [Get-FinOpsCostExport](../_automation/powershell/cost/Get-FinOpsCostExport.md).
> 2. Added a `-DatasetVersion` filter in [Get-FinOpsCostExport](../_automation/powershell/cost/Get-FinOpsCostExport.md).
>
> ✏️ Changed:
>
> 1. Update Get-AzAccessToken calls to use -AsSecureString ([#946](https://github.com/microsoft/finops-toolkit/issues/946)).
>
> 🛠️ Fixed:
>
> 1. Fixed [New-FinOpsCostExport](../_automation/powershell/cost/New-FinOpsCostExport.md) to address breaking change in Cost Management when storage paths start with "/".
> 2. Fixed a bug where scopes added via the Add-FinOpsHubScope command are not added correctly due to missing brackets.

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - [Pricing units](../_reporting/data/README.md#-pricing-units)
>   1. Added handling for the following new UnitOfMeasure values: "1 /Minute", "10 PiB/Hour", "100000 /Month", "Text".
> - [Regions](../_reporting/data/README.md#️-regions)
>   1. Added the following new region values: "asiapacific", "australia", azure "stack", "eastsu2", "gbs", germany west "central", "japan", sweden "central", "unitedstates", us dod "central", us dod "east", us gov "iowa", us gov "virginia", "us2", "usa", "usv".
> - [Resource types](../_reporting/data/README.md#️-resource-types)
>   1. Added the following new resource types: "microsoft.app/logicapps", "microsoft.app/logicapps/workflows", "microsoft.azurebusinesscontinuity/deletedunifiedprotecteditems", "microsoft.azurebusinesscontinuity/unifiedprotecteditems", "microsoft.azurecis/publishconfigvalues", "microsoft.compositesolutions/compositesolutiondefinitions", "microsoft.compositesolutions/compositesolutions", "microsoft.compute/capacityreservationgroups/capacityreservations", "microsoft.compute/virtualmachinescalesets/virtualmachines", "microsoft.datareplication/replicationvaults/alertsettings", "microsoft.datareplication/replicationvaults/events", "microsoft.datareplication/replicationvaults/jobs", "microsoft.datareplication/replicationvaults/jobs/operations", "microsoft.datareplication/replicationvaults/operations", "microsoft.datareplication/replicationvaults/protecteditems", "microsoft.datareplication/replicationvaults/protecteditems/operations", "microsoft.datareplication/replicationvaults/protecteditems/recoverypoints", "microsoft.datareplication/replicationvaults/replicationextensions", "microsoft.datareplication/replicationvaults/replicationextensions/operations", "microsoft.datareplication/replicationvaults/replicationpolicies", "microsoft.datareplication/replicationvaults/replicationpolicies/operations", "microsoft.deviceregistry/billingcontainers", "microsoft.deviceregistry/discoveredassetendpointprofiles", "microsoft.deviceregistry/discoveredassets", "microsoft.deviceregistry/schemaregistries", "microsoft.deviceregistry/schemaregistries/schemas", "microsoft.deviceregistry/schemaregistries/schemas/schemaversions", "microsoft.eventgrid/systemtopics/eventsubscriptions", "microsoft.hardware/orders", "microsoft.hybridcompute/machines/microsoft.awsconnector/ec2instances", "microsoft.hybridonboarding/extensionmanagers", "microsoft.iotoperations/instances", "microsoft.iotoperations/instances/brokers", "microsoft.iotoperations/instances/brokers/authentications", "microsoft.iotoperations/instances/brokers/authorizations", "microsoft.iotoperations/instances/brokers/listeners", "microsoft.iotoperations/instances/dataflowendpoints", "microsoft.iotoperations/instances/dataflowprofiles", "microsoft.iotoperations/instances/dataflowprofiles/dataflows", "microsoft.messagingconnectors/connectors", "microsoft.mobilepacketcore/networkfunctions", "microsoft.saashub/cloudservices/hidden", "microsoft.secretsynccontroller/azurekeyvaultsecretproviderclasses", "microsoft.secretsynccontroller/secretsyncs", "microsoft.storagepool/diskpools/iscsitargets", "microsoft.usagebilling/accounts/dataexports", "microsoft.usagebilling/accounts/metricexports", "microsoft.windowsesu/multipleactivationkeys".
> - [Services](../_reporting/data/README.md#️-services)
>   1. Added the following consumed services:  "API Center", "API Management", "Bastion Scale Units", "Microsoft.Community", "Microsoft.DataReplication.Admin", "Microsoft.DevOpsInfrastructure", "Microsoft.Dynamics365FraudProtection", "Microsoft.HybridContainerService", "Microsoft.NetworkFunction", "Microsoft.RecommendationsService", "Microsoft.ServiceNetworking", "Virtual Network".
>   2. Added the following resource types to existing services:  "Microsoft.AgFoodPlatform/farmBeats", "Microsoft.App/sessionPools", "Microsoft.AzureActiveDirectory/ciamDirectories", "Microsoft.AzureArcData/sqlServerEsuLicenses", "Microsoft.Graph/accounts", "Microsoft.MachineLearningServices/registries", "Microsoft.Orbital/groundStations", "PlayFabBillingService/partyVoice".
>
> ✏️ Changed:
>
> - [Pricing units](../_reporting/data/README.md#-pricing-units)
>   1. Changed DistinctUnits for the "10000s" UnitOfMeasure from "Units" to "Transactions".
> - [Resource types](../_reporting/data/README.md#️-resource-types)
>   1. Updated the following resource types: "microsoft.apimanagement/gateways", "microsoft.azurearcdata/sqlserveresulicenses", "microsoft.azurestackhci/edgenodepools", "microsoft.azurestackhci/galleryimages", "microsoft.azurestackhci/logicalnetworks", "microsoft.azurestackhci/marketplacegalleryimages", "microsoft.azurestackhci/networkinterfaces", "microsoft.azurestackhci/storagecontainers", "microsoft.cache/redisenterprise", "microsoft.cache/redisenterprise/databases", "microsoft.databricks/accessconnectors", "microsoft.datareplication/replicationvaults", "microsoft.devhub/iacprofiles", "microsoft.edge/sites", "microsoft.eventhub/namespaces", "microsoft.hybridcompute/gateways", "microsoft.impact/connectors", "microsoft.iotoperationsorchestrator/instances", "microsoft.iotoperationsorchestrator/solutions", "microsoft.iotoperationsorchestrator/targets", "microsoft.kubernetesruntime/loadbalancers", "microsoft.manufacturingplatform/manufacturingdataservices", "microsoft.network/dnsforwardingrulesets", "microsoft.network/dnsresolvers", "microsoft.network/dnszones", "microsoft.powerbidedicated/capacities", "microsoft.programmableconnectivity/gateways", "microsoft.programmableconnectivity/operatorapiconnections", "microsoft.programmableconnectivity/operatorapiplans", "microsoft.resources/subscriptions/resourcegroups", "microsoft.security/pricings", "microsoft.sovereign/transparencylogs", "microsoft.storagepool/diskpools".
>   2. Updated multiple resource types for the following resource providers: "microsoft.awsconnector".
>   3. Changed the following resource providers to be GA: "microsoft.modsimworkbench".
> - [Services](../_reporting/data/README.md#️-services)
>   1. Moved Microsoft Genomics from the "AI and Machine Learning" service category to "Analytics".
>   2. Changed Microsoft Genomics from the "SaaS" service model to "PaaS".
>   3. Replace "Azure Active Directory" service name references with "Microsoft Entra".
>   4. Move Azure Cache for Redis from the "Storage" service category to "Databases".
>   5. Move Event Hubs from the "Integration" service category to "Analytics".
>   6. Rename the Microsoft.HybridCompute consumed service service name from "Azure Resource Manager" to "Azure Arc".
>   7. Move Microsoft Defender for Endpoint from the "Multicloud" service category to "Security".
>   8. Move StorSimple from the "Multicloud" service category to "Storage".
>
> 🗑️ Removed
>
> - [Resource types](../_reporting/data/README.md#️-resource-types)
>   1. Removed internal "microsoft.cognitiveservices/browse*" resource types.

[Download v0.5](https://github.com/microsoft/finops-toolkit/releases/tag/v0.5){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.4...v0.5){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🚚 v0.4

<sup>Released July 12, 2024</sup>

📗 FinOps guide
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Documented the [FOCUS export dataset](../_docs/focus/metadata.md) to align to the FOCUS metadata specification.
>
> ✏️ Changed:
>
> 1. Updated [FinOps Framework guidance](../_docs/framework/README.md) to account for the 2024 updates.
> 2. Updated [FOCUS guidance](../_docs/focus/README.md) to FOCUS 1.0.

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Ingest FOCUS 1.0 data in FinOps hubs.
> 2. Grant access to FinOps hubs to [create and manage exports](../_reporting/hubs/configure-scopes.md#-configure-managed-exports) for you.
> 3. Connect to a hub instance in another Entra ID tenant.
> 4. Step-by-step troubleshooting guide and expanded set of common errors for validating FinOps hubs and Power BI setup.
>
> 🛠️ Fixed:
>
> 1. Fixed an issue where some dates are showing as off by 1 based on local time zone.
>    - If you see dates that are off, upgrade to 0.4 and re-export those months. The fix is in ingestion.
>    - You can re-export data in FOCUS 1.0 or FOCUS 1.0 preview. We recommend FOCUS 1.0 for slightly faster refresh times in Power BI.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - General:
>   1. **x_IncrementalRefreshDate** column to facilitate configuring incremental refresh in Power BI.
>   2. Step-by-step troubleshooting guide and expanded set of common errors for validating Power BI setup.
> - [Cost summary](../_reporting/power-bi/cost-summary.md):
>   1. Resource count and cost per resource in the [Inventory page](../_reporting/power-bi/cost-summary.md#inventory).
> - [Data ingestion](../_reporting/power-bi/data-ingestion.md):
>   1. [Ingestion errors page](../_reporting/power-bi/data-ingestion.md#ingestion-errors) to help identify FinOps hub data ingestion issues.
>
> ✏️ Changed:
>
> - General:
>   1. Changed the **Tags** column to default to `{}` when empty to facilitate tag expansion ([#691](https://github.com/microsoft/finops-toolkit/issues/691#issuecomment-2134072033)).
>   2. Simplified formatting for the `BillingPeriod` and `ChargePeriod` measures in Power BI.
>   3. Improved error handling for derived savings columns in the CostDetails query.
>   4. Simplified queries and improved error handling in the START HERE query for report setup steps.
>   5. Changed internal storage for reports to use [Tabular Model Definition Language (TMDL)](https://learn.microsoft.com/power-bi/developer/projects/projects-dataset#tmdl-format).
>      - This change makes it easier to review changes to the data model in Power BI.
>      - Reports will still be released as PBIX files so this change should not impact end users.
>      - Visualizations are not being switched to [Power BI Enhanced Report (PBIR)](https://learn.microsoft.com/power-bi/developer/projects/projects-report#pbir-format) format yet due to functional limitations that would impact end users (as of June 2024).
> - [Cost summary](../_reporting/power-bi/cost-summary.md):
>   1. Changed the [Cost summary Purchases page](../_reporting/power-bi/cost-summary.md#purchases) and [Rate optimization Purchases page](../_reporting/power-bi/rate-optimization.md#purchases) to use PricingQuantity instead of Usage/ConsumedQuantity and added the PricingUnit column.
>   2. Updated the [DQ page](../_reporting/power-bi/cost-summary.md#dq) to identify empty ChargeDescription rows.
>   3. Updated the [DQ page](../_reporting/power-bi/cost-summary.md#dq) to identify potentially missing rounding adjustments.
> - [Rate optimization](../_reporting/power-bi/rate-optimization.md):
>   1. Renamed the "Commitment discounts" report to "Rate optimization" to align to the FinOps Framework 2024 updates.
> - [Data ingestion](../_reporting/power-bi/data-ingestion.md):
>   1. Optimized [Data ingestion report](../_reporting/power-bi/data-ingestion.md) queries to reduce memory footprint and load faster.
>      <blockquote class="warning" markdown="1">
>         _We are investigating an issue where we are missing rounding adjustments since May 2024. We do not yet know the cause of this issue._
>      </blockquote>
>
> 🛠️ Fixed:
>
> - General:
>   1. Improved parsing for the `x_ResourceParentName` and `x_ResourceParentType` columns ([#691](https://github.com/microsoft/finops-toolkit/issues/691#issuecomment-2134072033)).
> - [Rate optimization](../_reporting/power-bi/rate-optimization.md):
>   1. Added error handling for missing `normalizedSize` and `recommendedQuantityNormalized` columns in the [Rate optimization (Commitment discounts) report](../_reporting/power-bi/rate-optimization.md) ([#702](https://github.com/microsoft/finops-toolkit/issues/702)).
> - [Data ingestion](../_reporting/power-bi/data-ingestion.md):
>   1. Fixed error in [Data ingestion report](../_reporting/power-bi/data-ingestion.md) queries.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - [Optimization workbook](../_optimize/workbooks/optimization/README.md):
>   1. Added reservation recommendations with the break-even point to identify when savings would be achieved.
>   2. Identify idle ExpressRoute circuits to streamline costs.
>   3. Gain insights into the routing preferences for public IP addresses to optimize network performance.
>   4. Explore commitment discount savings to get a clear overview of rate optimization opportunities.
>   5. Quickly view public IP addresses with DDoS protection enabled and compare if it would be cheaper to enable DDoS to the vNet instead.
>   6. Identify Azure Hybrid Benefit usage for SQL Database elastic pools to maximize cost efficiency.
>    
> - [Governance workbook](../_optimize/workbooks/governance/README.md):
>   1. Added managed disk usage monitoring.

> ✏️ Changed:
>
> - [Optimization workbook](../_optimize/workbooks/optimization/README.md):
>   1. Redesigned the Sustainability tab to clarify recommendations.
>   2. Ignore dynamic IPs in the public IP addresses list to ensure more accurate results.
>   3. Ignore free tier web apps to provide a clearer picture of your top services.
>
> - [Governance workbook](../_optimize/workbooks/governance/README.md):
>   1. Overview has been revised to align with the latest governance principles of the cloud adoption framework.

🔍 Optimization engine
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added Azure Optimization Engine (AOE), an extensible solution for custom optimization recommendations.

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added progress tracking to [Start-FinOpsCostExport](../_automation/powershell/cost/Start-FinOpsCostExport.md) for multi-month exports.
> 2. Added a 60-second delay when Cost Management returns throttling (429) errors in [Start-FinOpsCostExport](../_automation/powershell/cost/Start-FinOpsCostExport.md).
>
> ✏️ Changed:
>
> 1. Updated [New-FinOpsCostExport](../_automation/powershell/cost/New-FinOpsCostExport.md) to default to FOCUS 1.0.
>
> 🗑️ Removed:
>
> 1. Removed support for Windows PowerShell.
>    > _We discovered errors with Windows PowerShell due to incompatibilities in Windows PowerShell and PowerShell 7. Due to our limited capacity, we decided to only support [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) going forward._
> 2. Removed `ConvertTo-FinOpsSchema` and `Invoke-FinOpsSchemaTransform` commands which were deprecated in [0.2 (January 2024)](#-v02).

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added a new FOCUS 1.0 [dataset example](../_reporting/data/README.md#️-dataset-examples).
> 2. Added [dataset metadata](../_reporting/data/README.md#️-dataset-metadata) for FOCUS 1.0 and FOCUS 1.0-preview.
>
> ✏️ Changed:
>
> 1. Updated all [open data files](../_reporting/data/README.md) to include the latest data.
> 2. Changed the primary columns in the [Regions](../_reporting/data/README.md#️-regions) and [Services](../_reporting/data/README.md#️-services) open data files to be lowercase.
> 3. Updated all [sample exports](../_reporting/data/README.md#️-dataset-examples) to use the same date range as the FOCUS 1.0 dataset.

[Download v0.4](https://github.com/microsoft/finops-toolkit/releases/tag/v0.4){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.3...v0.4){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🚚 v0.3

<sup>Released March 28, 2024</sup>

📗 FinOps guide
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Moved [Azure FinOps documentation](https://aka.ms/finops/docs) about how to implement and adopt FinOps into the toolkit.
>
> ✏️ Changed:
>
> 1. Rearranged documentation site to better organize content.

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Started archiving template versions so they can be referenced easily via URL microsoft.github.io/finops-toolkit/deploy/finops-hub-{version}.json.
>
> 🛠️ Fixed:
>
> 1. Fixed "missing period" error Data Factory Studio.
> 2. Fixed bug where `msexports_FileAdded` trigger was not getting started.
> 3. Fixed deploy to Azure buttons to point to the latest release.
>
> ✏️ Changed:
>
> 1. Return a single boolean value from the Remove-FinOpsHub command.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added `ResourceParentId`, `ResourceParentName`, and `ResourceParentType` columns to support the usage of the user-defined `cm-resource-parent` tag.
> 2. Added `ToolkitVersion` and `ToolkitTool` columns to help quantify the cost of FinOps toolkit solutions.
> 3. Added a DQ page to the [Commitment discounts report](../_reporting/power-bi/rate-optimization.md#dq) for data quality validations. This page can be useful in identifying data gaps in Cost Management.
> 4. Added `x_NegotiatedUnitPriceSavings` column to show the price reduction from negotiated discounts compared to the public, list price.
> 5. Added `x_IsFree` column to indicate when a row represents a free charge (based on Cost Management data). This is used in data quality checks.
> 6. Added `Tags` and `TagsAsJson` columns to both the **Usage details** and **Usage details amortized** tables in the [CostManagementTemplateApp report](../_reporting/power-bi/template-app.md) ([#625](https://github.com/microsoft/finops-toolkit/issues/625)).
>
> 🛠️ Fixed:
>
> 1. Fixed numerous errors causing the [Cost Management connector report](../_reporting/power-bi/connector.md) to not load for MCA accounts.
> 2. Fixed incorrect filter in the [Commitment discounts report](../_reporting/power-bi/rate-optimization.md) ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).
> 3. Fixed data issue where Cost Management uses "1Year", "3Years", and "5Years" for the x_SkuTerm. Values should be 12, 36, and 60 ([#594](https://github.com/microsoft/finops-toolkit/issues/594)).
> 4. Changed the data type for the `x_Month` column to be a date.
> 5. Changed `x_SkuTerm` to be a whole number and to not summarize by default.
> 6. Changed `x_BillingExchangeRate` to not summarize by default.
> 7. Corrected references to x_InvoiceIssuerId and InvoiceIssuerName columns in the [Cost Management connector report](../_reporting/power-bi/connector.md) ([#639](https://github.com/microsoft/finops-toolkit/issues/649)).
> 8. Corrected the datatype for the `x_Month` column.
>
> ✏️ Changed:
>
> 1. Changed "Other" ChargeSubcategory for usage to "On-Demand" to be consistent with Cost Management exports
> 2. Renamed savings columns for consistency:
>    - `x_OnDemandUnitPriceSavings` is now `x_CommitmentUnitPriceSavings`. This shows the commitment discount price reduction compared to the negotiated prices for the account.
>    - `x_ListUnitPriceSavings` is now `x_DiscountUnitPriceSavings`. This shows the price reduction from all discounts compared to the public, list price.
>    - `x_NegotiatedSavings` is now `x_NegotiatedCostSavings`. This shows the cost savings from negotiated discounts only (excluding commitment discounts).
>    - `x_CommitmentSavings` is now `x_CommitmentCostSavings`. This shows the cost savings from commitment discounts compared to on-demand prices for the account (including negotiated discounts).
>    - `x_DiscountSavings` is now `x_DiscountCostSavings`. This shows the cost savings from all negotiated and commitment discounts.
> 3. Changed the `PricingQuantity` and `UsageQuantity` columns to use 3 decimal places.
> 4. Changed all cost columns to use 2 decimal places.
> 5. Changed all unit price columns to not summarize by default and use 3 decimal places.
> 6. Changed the `x_PricingBlockSize` column to a whole number and not summarize by default.
> 7. Renamed the **Coverage** pages in the [Commitment discounts report](../_reporting/power-bi/rate-optimization.md) to **Recommendations**.

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Get-FinOpsService](../_automation/powershell/data/Get-FinOpsService.md) includes new `-Environment` and `-ServiceModel` filters and properties in the response ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).
>
> ✏️ Changed:
>
> 1. [Start-FinOpsCostExport](../_automation/powershell/cost/Start-FinOpsCostExport.md) includes a new `-Backfill` option to backfill multiple months.
> 2. [Start-FinOpsCostExport](../_automation/powershell/cost/Start-FinOpsCostExport.md) includes a new `-StartDate` and `-EndDate` options to run the export for a given date range. This can include multiple months.
>
> 🛠️ Fixed:
>
> 1. Fixed ParameterBindingException error in [New-FinOpsCostExport](../_automation/powershell/cost/New-FinOpsCostExport.md).
> 2. Updated the FOCUS dataset version that was changed in Cost Management exports in [New-FinOpsCostExport](../_automation/powershell/cost/New-FinOpsCostExport.md).
> 3. Changed the default `-EndDate` in [New-FinOpsCostExport](../_automation/powershell/cost/New-FinOpsCostExport.md) to be the end of the month due to a breaking change in Cost Management exports.
> 4. Fixed internal command used in [Deploy-FinOpsHub](../_automation/powershell/hubs/Deploy-FinOpsHub.md) that may have caused it to fail for some versions of the Az PowerShell module.

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Added ServiceModel and Environment columns to the [services](../_reporting/data/README.md#-services) data ([#585](https://github.com/microsoft/finops-toolkit/issues/585)).
> 2. New and updated [resource types](../_reporting/data/README.md#-resource-types) and icons.

[Download v0.3](https://github.com/microsoft/finops-toolkit/releases/tag/v0.3){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.2...v0.3){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🚚 v0.2

<sup>Released January 22, 2024</sup>

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

<small>**Breaking change**</small>
{: .label .label-red .pt-0 .pl-3 .pr-3 .m-0 }

> 🛠️ Fixed:
>
> 1. Fixed error in some China regions where deployment scripts were not supported ([#259](https://github.com/microsoft/finops-toolkit/issues/259)).
>
> ✏️ Changed:
>
> 1. Switch from amortized cost exports to FOCUS cost exports.
>    <blockquote class="important" markdown="1">
>       _This change requires re-ingesting historical data and is not backwards compatible. The unified schema used in this release is aligned with the future plans for Microsoft Cost Management exports. Note the next release will update the schema to align to the FinOps Open Cost and Usage Specification (FOCUS)._
>    </blockquote>
> 2. Updated ingestion container month folders from `yyyyMMdd-yyyyMMdd` to `yyyyMM`.
> 3. Renamed **msexports_extract** pipeline to **msexports_ExecuteETL**.
> 4. Renamed **msexports_transform** pipeline to **msexports_ETL_ingestion**.

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Cost Management connector report](../_reporting/power-bi/connector.md) to support the Cost Management connector.
>
> ✏️ Changed:
>
> 1. Updated [Cost summary](../_reporting/power-bi/cost-summary.md) and [Commitment discounts](../_reporting/power-bi/rate-optimization.md) reports to [FOCUS 1.0 preview](../_docs/focus/README.md).
> 2. Updated [Cost summary](../_reporting/power-bi/cost-summary.md) and [Commitment discounts](../_reporting/power-bi/rate-optimization.md) reports to only use [FinOps hubs](../_reporting/hubs/README.md).
> 3. Removed unused custom visualizations.
> 4. Organized setup instructions in Cost summary to match other reports.
> 5. Updated troubleshooting documentation.
>
> 🛠️ Fixed:
>
> 1. Removed sensitivity labels.
> 2. Fixed dynamic data source error when the Power BI service refreshes data.
>    - Error message: "You can't schedule refresh for this semantic model because the following data sources currently don't support refresh..."
> 3. Fixed error in ChargeId column when ResourceId is empty.
> 4. Removed the ChargeId column due to it bloating the data size.
>    - The field is commented out. If interested, you can enable uncomment it in the ftk_NormalizeSchema function. Just be aware that it duplicates a lot of columns to ensure uniqueness which bloats the data size significantly.
> 5. Fixed null error when Billing Account ID is empty ([#473](https://github.com/microsoft/finops-toolkit/issues/473)).
> 6. Added missing commitment discount refunds to the actual cost data ([#447](https://github.com/microsoft/finops-toolkit/issues/447)).

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> - [Optimization workbook](../_optimize/workbooks/optimization/README.md):
>   1. Storage: Identify Idle Backups: Review protected items' backup activity to spot items not backed up in the last 90 days.
>   2. Storage: Review Replication Settings: Evaluate and improve your backup strategy by identifying resources with default geo-redundant storage (GRS) replication.
>   3. Networking: Azure Firewall Premium Features: Identify Azure Firewalls with Premium SKU and ensure associated policies leverage premium-only features.
>   4. Networking: Firewall Optimization: Streamline Azure Firewall usage by centralizing instances in the hub virtual network or Virtual WAN secure hub.
>
> ✏️ Changed:
>
> - [Optimization workbook](../_optimize/workbooks/optimization/README.md):
>   1. Top 10 services: Improved Monitoring tabs: Enhance your monitoring experience with updated Azure Advisor recommendations for Log Analytics.
>
> 🛠️ Fixed:
>
> - [Optimization workbook](../_optimize/workbooks/optimization/README.md):
>   1. AHB: Fixed AHB to support Windows 10/Windows 11

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [New-FinOpsCostExport](../_automation/powershell/cost/New-FinOpsCostExport.md) to create and update Cost Management exports.
> 2. [Start-FinOpsCostExport](../_automation/powershell/cost/Start-FinOpsCostExport.md) to run a Cost Management export immediately.
> 3. [Get-FinOpsCostExport](../_automation/powershell/cost/Get-FinOpsCostExport.md) now has a `-RunHistory` option to include the run history of each export.
>
> ✏️ Changed:
>
> 1. Updated the default API version for export commands to `2023-07-01-preview` to leverage new datasets and features.
>    - Specify `2023-08-01` explicitly for the previous API version.
>
> 🛠️ Fixed:
>
> 1. Fixed typo in [Deploy-FinOpsHub](../_automation/powershell/hubs/Deploy-FinOpsHub.md) causing it to fail.
>
> 🚫 Deprecated:
>
> 1. `ConvertTo-FinOpsSchema` and `Invoke-FinOpsSchemaTransform` are no longer being maintained and will be removed in a future update.
>    - With native support for FOCUS 1.0 preview in Cost Management, we are deprecating both commands, which only support FOCUS 0.5.
>    - If you would like to see the PowerShell commands updated to 1.0 preview, please let us know in discussions or via a GitHub issue.

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Resource types](../_reporting/data/README.md#-resource-types) to map Azure resource types to friendly display names.
> 2. [Get-FinOpsResourceType](../_automation/powershell/data/Get-FinOpsResourceType.md) PowerShell command to support resource type to display name mapping.
> 3. [Sample exports](../_reporting/data/README.md#-sample-data) for each of the datasets that can be exported from Cost Management.

📗 FinOps guide
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [FinOps Open Cost and Usage Specification (FOCUS) details](../_docs/focus/README.md).

[Download v0.2](https://github.com/microsoft/finops-toolkit/releases/tag/v0.2){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.1.1...v0.2){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🛠️ v0.1.1

<sup>Released October 26, 2023</sup>

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. New PowerShell commands to convert data to FOCUS 0.5:
>    1. ConvertTo-FinOpsSchema
>    2. Invoke-FinOpsSchemaTransform
> 2. New PowerShell commands to get and delete Cost Management exports:
>    1. [Get-FinOpsCostExport](../_automation/powershell/cost/Get-FinOpsCostExport.md)
>    2. [Remove-FinOpsCostExport](../_automation/powershell/cost/Remove-FinOpsCostExport.md)

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. New PowerShell commands to integrate open data to support data cleansing:
>    1. [Get-FinOpsPricingUnit](../_automation/powershell/data/Get-FinOpsPricingUnit.md)
>    2. [Get-FinOpsRegion](../_automation/powershell/data/Get-FinOpsRegion.md)
>    3. [Get-FinOpsService](../_automation/powershell/data/Get-FinOpsService.md)

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. New PowerShell commands to manage FinOps hubs 0.1:
>    1. [Get-FinOpsHub](../_automation/powershell/hubs/Get-FinOpsHub.md)
>    2. [Initialize-FinOpsHubDeployment](../_automation/powershell/hubs/Initialize-FinOpsHubDeployment.md)
>    3. [Register-FinOpsHubProviders](../_automation/powershell/hubs/Register-FinOpsHubProviders.md)
>    4. [Remove-FinOpsHub](../_automation/powershell/hubs/Remove-FinOpsHub.md)

[Download v0.1.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.1...v0.1.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🚚 v0.1

<sup>Released October 22, 2023</sup>

🖥️ PowerShell
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [FinOpsToolkit module](https://aka.ms/finops/toolkit/powershell) released in the PowerShell Gallery.
> 2. [Get-FinOpsToolkitVersion](../_automation/powershell/toolkit/Get-FinOpsToolkitVersion.md) to get toolkit versions.

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Deploy-FinOpsHub](../_automation/powershell/hubs/Deploy-FinOpsHub.md) to deploy or update a hub instance.
> 2. [Get-FinOpsHub](../_automation/powershell/hubs/Get-FinOpsHub.md) to get details about a hub instance.
> 3. Support for Microsoft Customer Agreement (MCA) accounts and Cloud Solution Provider (CSP) subscriptions in Power BI reports.
>
> 🛠️ Fixed:
>
> 1. Storage redundancy dropdown default not set correctly in the create form.
> 2. Tags specified in the create form were causing the deployment to fail ([#331](https://github.com/microsoft/finops-toolkit/issues/331)).

📊 Power BI reports
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. Commitments, Savings, Chargeback, Purchases, and Prices pages in the [Commitment discounts report](../_reporting/power-bi/rate-optimization.md).
> 2. Prices page in the [Cost summary report](../_reporting/power-bi/cost-summary.md).
> 3. [FOCUS sample report](../_reporting/power-bi/focus.md) – See your data in the FinOps Open Cost and Usage Specification (FOCUS) schema.
> 4. [Cost Management template app](../_reporting/power-bi/template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.
>
> ✏️ Changed:
>
> 1. Expanded the FinOps hubs Cost summary and Commitment discounts [Power BI reports](../_reporting/power-bi/README.md) to support the Cost Management connector.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Governance workbook](../_optimize/workbooks/governance/README.md) to centralize governance.
>
> ✏️ Changed:
>
> 1. [Optimization workbook](../_optimize/workbooks/optimization/README.md) updated to cover more scenarios.

🌐 Open data
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Pricing units](../_reporting/data/README.md#-pricing-units) to map all pricing units (UnitOfMeasure values) to distinct units with a scaling factor.
> 2. [Regions](../_reporting/data/README.md#-regions) to map historical resource location values in Microsoft Cost Management to standard Azure regions.
> 3. [Services](../_reporting/data/README.md#-services) to map all resource types to FOCUS service names and categories.

[Download v0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1){: .btn .btn-primary .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/v0.0.1...v0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🌱 v0.0.1

<sup>Released May 27, 2023</sup>

🏦 FinOps hubs
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [FinOps hub template](../_reporting/hubs/README.md) to deploy a storage account and Data Factory instance.
> 2. [Cost summary report](../_reporting/power-bi/cost-summary.md) for various out-of-the-box cost breakdowns.
> 3. [Commitment discounts report](../_reporting/power-bi/rate-optimization.md) for commitment-based discount reports.

🦾 Bicep modules
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Scheduled action modules](../_automation/bicep-registry/scheduled-actions.md) submitted to the Bicep Registry.

📒 Azure Monitor workbooks
{: .fs-5 .fw-500 .mt-4 mb-0 }

> ➕ Added:
>
> 1. [Cost optimization workbook](../_optimize/workbooks/optimization/README.md) to centralize cost optimization.

[Download v0.0.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Full changelog](https://github.com/microsoft/finops-toolkit/compare/878e4864ca785db4fc13bdd2ec3a6a00058688c3...v0.0.1){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
