---
title: Troubleshoot common FinOps toolkit errors
description: This article describes common FinOps toolkit errors and provides solutions to help you resolve issues you might encounter.
author: flanakin
ms.author: micflan
ms.date: 05/02/2025
ms.topic: troubleshooting
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand and resolve common errors I might experience with the FinOps toolkit.
---

<!-- markdownlint-disable-next-line MD025 -->
# Troubleshoot common FinOps toolkit errors

This article describes common FinOps toolkit errors and provides information about solutions. If you get an error when using FinOps toolkit solutions that you don't understand or can't resolve, find the following corresponding error code with mitigation steps to resolve the problem.

Here's a list of common error codes with mitigation information.

If the information provided doesn't resolve the issue, try the [Troubleshooting guide](troubleshooting.md).

<!--
If the information provided doesn't help you, [Create a support request](/azure/cost-management-billing/costs/cost-management-error-codes#create-a-support-request).
-->

<br>

## Access to the resource is forbidden

<sup>Severity: Critical</sup>

This error generally means the account you are connected with does not have access to the resource you're attempting to use.

**Mitigation**: Confirm you are using the correct account in the correct Microsoft Entra ID tenant.

<br>

## AccountPropertyCannotBeUpdated

<sup>Severity: Critical</sup>

This error typically occurs when updating a FinOps hub deployment with a different storage account configuration than was originally used during creation. While most properties can be changed, there are a few properties that can only be set once when the storage account is created and cannot change. The one known case of this for FinOps hubs is the "requireInfrastructureEncryption" property. If this property was enabled or disabled during the first FinOps hub deployment, then it cannot be changed. You will see the following error when this happens:

> The property 'requireInfrastructureEncryption' was specified in the input, but it cannot be updated as it is read-only.

**Mitigation**: If you did not mean to change this setting, confirm whether your storage account is configured to use infrastructure encryption and re-deploy the FinOps hub template with the same value (either on or off). If you want to change the setting, we recommend deploying a new FinOps hub instance, as this will require reingesting all data.

You can try to delete the existing storage account and redeploy the template with infrastructure encryption changed; however, we have not thoroughly tested this. While we do not anticipate issues, we cannot confirm if it will cause problems.

<br>

## BadHubVersion

<sup>Severity: Critical</sup>

FinOps hubs 0.2 isn't operational. Upgrade to version 0.3 or later.

**Mitigation**: Upgrade to the latest version of [FinOps hubs](../hubs/finops-hubs-overview.md).

<br>

## Column 'id' in Table 'Resources' contains a duplicate value

<sup>Severity: Critical</sup>

If you experience the following error, it means that Azure Resource Graph is returning rows with the same logical value for the **id** column. This can happen when the resource ID values have inconsistent casing or when another column is expanded across rows.

> _Column 'id' in Table 'Resources' contains a duplicate value '{resource-id}' and this is not allowed for columns on the one side of a many-to-one relationship or for columns that are used as the primary key of a table._

**Mitigation**: Make sure you are on the [latest version](https://aka.ms/ftk/latest) of the report. Identify the cause of the duplicate values and update the query to work around the duplicate values. Please also [report this issue in GitHub](https://aka.ms/ftk/ideas) so it can be fixed in a future release. This may require additional detail or a meeting to troubleshoot the cause of the error.

<br>

## ConflictError

<sup>Severity: Critical</sup>

There may be multiple instances of this error. The one known instance is when Key Vault returns the following error:

> _A vault with the same name already exists in deleted state. You need to either recover or purge existing key vault. Follow this link https://go.microsoft.com/fwlink/?linkid=2149745 for more information on soft delete._

This generally means you're deploying on top of an old deployment that was deleted, but Key Vault kept the old vault instance in a recoverable delete state.

**Mitigation**: To fix this, purge the deleted Key Vault in the Azure portal.

1. Open the [list of Key Vault instances](https://portal.azure.com/#browse/Microsoft.KeyVault%2Fvaults) in the Azure portal.
2. Select the **Manage deleted vaults** command at the top of the page.
3. Select the subscription in the dropdown.
4. Check the vaults to be removed.
5. Select **Purge** at the bottom of the flyout.
6. Select **Delete** in the confirmation dialog.

You can now retry the deployment.

<br>

## ContractedCostLessThanEffectiveCost

<sup>Severity: Warning</sup>

`ContractedCost` (based on negotiated discounts) is less than `EffectiveCost` (after commitment discounts) in the data from Cost Management. This should never happen unless the commitment discount provides less of a discount than your existing negotiated discounts. This will cause your savings calculations to not add up precisely.

**Mitigation**: Confirm the `ContractedUnitPrice` in the cost data matches what's in the price data. If the contracted price is correct, file a support request with the Cost Management team to confirm the `x_EffectiveUnitPrice` and `EffectiveCost` are correct. If they are correct, consider returning the commitment discount.

<br>

## Cross-tenant access policy does not allow this user

<sup>Severity: Major</sup>

If you experience the following error, it means Microsoft Entra ID is configured to not allow users from other tenants to sign in to the current tenant.

> _Message: AADSTS500213: The resource tenant's cross-tenant access policy does not allow this user to access this tenant._

This error message is not related to the FinOps toolkit.

**Mitigation**: Verify you are signed in to the correct account and that you signed in through the target directory. Contact the directory admin if you need further assistance.

<br>

## DataExplorerIngestionFailed

<sup>Severity: Critical</sup>

Data Explorer ingestion failed. The new data will not be available for reporting.

**Mitigation**: Review the Data Explorer error message and resolve the issue. Rerun data ingestion for the specified folder using the ingestion_ExecuteETL pipeline in Azure Data Factory. Report unresolved issues at https://aka.ms/ftk/ideas.

<br>

## DataExplorerIngestionMappingFailed

<sup>Severity: Critical</sup>

Data Explorer ingestion mapping could not be created for the specified table.

**Mitigation**: Please fix the error and rerun ingestion for the specified folder path. If you continue to see this error, please report an issue at https://aka.ms/ftk/ideas.

<br>

## DataExplorerIngestionTimeout

<sup>Severity: Critical</sup>

Data Explorer ingestion timed out after 2 hours while waiting for available capacity.

**Mitigation**: Please re-run this pipeline to re-attempt ingestion. If you continue to see this error, please report an issue at https://aka.ms/ftk/ideas.

<br>

## DataExplorerPostIngestionDropFailed

<sup>Severity: Critical</sup>

Data Explorer post-ingestion cleanup (drop extents from the final table) failed. Data from a previous ingestion may be present in reporting, which could result in duplicated and inaccurate costs.

**Mitigation**: Review the Data Explorer error message and resolve the issue. Rerun data ingestion for the specified folder using the `ingestion_ExecuteETL` pipeline in Azure Data Factory. Report unresolved issues at https://aka.ms/ftk/ideas.

<br>

## DataExplorerPreIngestionDropFailed

<sup>Severity: Critical</sup>

Data Explorer pre-ingestion cleanup (drop extents from the raw table) failed. Ingestion was not completed.

**Mitigation**: Review the Data Explorer error message and resolve the issue. Rerun data ingestion for the specified folder using the `ingestion_ExecuteETL` pipeline in Azure Data Factory. Report unresolved issues at https://aka.ms/ftk/ideas.

<br>

## DeploymentOutputEvaluationFailed

<sup>Severity: Major</sup>

FinOps hubs 0.8 sets the Azure Data Explorer "trustedExternaltenants" security setting to lock the cluster down so it can only be access from specific, trusted tenants. This setting can be set for the first deployment, but cannot be set again in a second deployment. You may see the following error if you try to redeploy FinOps hubs 0.8 on top of an existing 0.8 deployment:

> _The template output 'clusterUri' is not valid: The language expression property 'uri' doesn't exist, available properties are 'trustedExternalTenants, enableStreamingIngest, publicNetworkAccess, enableAutoStop, provisioningState'._

We are following up with the Azure Data Explorer team to identify the correct resolution.

**Mitigation**: Deploy FinOps hubs 0.9. This setting has been removed from the template.

<br>

## ExportDataNotFound

<sup>Severity: Critical</sup>

Exports weren't found in the specified storage path.

**Mitigation**: Confirm that a [Cost Management export](https://aka.ms/exportsv2) was created and configured with the correct storage account, container, and storage path. After created, select 'Run now' to start the export process. Exports can take 15-30 minutes to complete depending on the size of the account. If you intended to use FinOps hubs, correct the storage URL to point to the 'ingestion' container. Refer to the `storageUrlForPowerBI` output from the FinOps hub deployment for the full URL.

<br>

## ExportTypeNotDefined

<sup>Severity: Critical</sup>

This billing scope type is not supported by managed exports.

**Mitigation**: Remove the unsupported billing scope from settings.json, confirm the billing scope is supported by FinOps hubs and manually create new Cost management exports for the billing scope.

<br>

## ExportTypeUnsupported

<sup>Severity: Critical</sup>

Microsoft Customer Agreements are not supported for managed exports.

**Mitigation**: Remove the MCA billing scope from settings.json and manually create new Cost Management exports for each MCA billing profile for FOCUS cost, pricesheet, reservation details, reservation transactions and reservation recommendations.

<br>

## HubDataNotFound

<sup>Severity: Critical</sup>

FinOps hub data was not found in the specified storage account.

**Mitigation**: This error assumes you are connecting to a FinOps hub deployment. If using raw exports, please correct the storage path to not reference the `ingestion` container. Confirm the following:

1. The storage URL should match the `StorageUrlForPowerBI` output on the FinOps hub deployment.
2. Cost Management exports should be configured to point to the same storage account using the `msexports` container.
3. Cost Management exports should show a successful export in the run history.
4. FinOps hub data factory triggers should all be started.
5. FinOps hub data factory pipelines should be successful.

For more details and debugging steps, see [Validate your FinOps hub deployment](../help/troubleshooting.md#validate-your-finops-hub-deployment).

<br>

## IngestionFilesNotFound

<sup>Severity: Critical</sup>

Unable to locate parquet files to ingest from the specified folder path.

**Mitigation**: Confirm the folder path is the full path, including the **ingestion** container and not starting with or ending with a slash (**/**). Copy the path from the last successful **ingestion_ExecuteETL** pipeline run.

<br>

## InternalServiceError

Microsoft Fabric Real-Time Intelligence may return an "InternalServiceError (520-UnknownError)" error code when ingesting data. The detailed error message may say:

> _Kusto client failed to send a request to the service: 'Unable to read data from the transport connection: An existing connection was forcibly closed by the remote host.'`_

The exact reason for this error is unknown. If you experience it, please file a support request with Microsoft Fabric to investigate further.

<!-- cSpell:ignore eventhouse -->
**Mitigation**: As a workaround, change the minimum consumption for the Fabric eventhouse to **Medium (18 CUs)**, wait 30 minutes, and rerun the **ingestion_ExecuteETL** pipeline for that dataset and month. To learn more minimum consumption, see [Minimum consumption](/fabric/real-time-intelligence/manage-monitor-eventhouse#enable-minimum-consumption) in the eventhouse overview.

<br>

## InvalidEffectiveCost

<sup>Severity: Major</sup>

As of November 2024, Cost Management has a known bug where savings plan purchases are internally tracked as both actual and amortized costs. Because of this, FOCUS includes savings plan purchases in the calculation for `EffectiveCost`, which leads to inaccurate numbers in FinOps toolkit reports.

**Mitigation**: File a support request with the Microsoft Cost Management team with details about the issue to fix the underlying data. As of November 2024, the team is aware of the issue, but the fix has not yet been prioritized. In the interim, update to FinOps toolkit 0.7, which includes a workaround for FinOps hubs and storage-based Power BI reports.

<br>

## InvalidExportContainer

<sup>Severity: Critical</sup>

This file looks like it might be exported from Cost Management but it isn't in the correct container.

**Mitigation**: Update your Cost Management export to point to the 'msexports' storage container. The 'ingestion' container is only used for querying ingested cost data.

<br>

## InvalidExportVersion

<sup>Severity: Critical</sup>

FinOps hubs require FOCUS cost exports but this file looks like a legacy Cost Management export.

**Mitigation**: Create a new Cost Management export for FOCUS cost and either stop the current export or change it to export to a different storage container.

<br>

## InvalidHubVersion

<sup>Severity: Critical</sup>

FinOps hubs 0.1.1 and earlier don't work with the [Data ingestion Power BI report](../power-bi/data-ingestion.md).

**Mitigation**: Upgrade to the latest version of [FinOps hubs](../hubs/finops-hubs-overview.md) or download Power BI reports from [release 0.1.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1).

<br>

## InvalidScopeId

<sup>Severity: Informational</sup>

The export path isn't a valid scope ID. FinOps hubs expect the export path to be an Azure resource ID for the scope the export was created to simplify management. It shouldn't cause failures, but might result in confusing results for scope-related reports.

**Mitigation**: Update the storage path for the Cost Management export to use the full Azure resource ID for the scope.

<br>

## LegacyFocusVersion

<sup>Severity: Informational</sup>

This error code is shown when the ingested data uses an older version of FOCUS. When found in the `x_SourceChanges` column, the code is informational only. When shown in Power BI storage reports when the Costs query fails to load, this means the **Deprecated: Perform Extra Query Optimizations** parameter is disabled.

FinOps hubs converts data to the latest FOCUS version so this should not cause an issue; however, the modernization transform cannot account for all scenarios and may result in unexpected results in some cases. Refer to documentation for known issues.

**Mitigation**: There are several ways to mitigate this message, depending on which tool you're using.

If using FinOps hubs with Data Explorer and seeing this in the `x_SourceChanges` column of the Costs table or related functions, update Cost Management cost exports to use the latest FOCUS version. No additional changes need to be made &nbsp; all data will be merged during Data Explorer ingestion.

If using storage reports and seeing this in the `x_SourceChanges` column of the Costs query, this message is a warning that this FOCUS version will be removed in a future update. While you can safely ignore this message, it will require an update in a future release. To avoid the message, update Cost Management exports to the latest FOCUS version, delete or move any older data using an older FOCUS version, and reexport historical data. If using FinOps hubs, delete or move data outside of the **ingestion** container. If hosting your own exports in storage, change the **Storage URL** parameter to a different folder path that does not include older FOCUS versions.

As of FinOps toolkit 0.7, support for older FOCUS versions has been deprecated to improve performance and scalability. We recommend updating to the latest FOCUS version and reexporting data to improve your experience. Set the **Deprecated: Perform Extra Query Optimizations** parameter to `TRUE` to ensure older FOCUS versions are supported and set it to `FALSE` to speed up performance and support larger datasets covering more cost or time. As of 0.7, this parameter is enabled by default for backwards compatibility. In FinOps toolkit 0.8, it will be disabled by default, but still available for backwards compatibility until on or after June 2025. If you cannot move off of old FOCUS versions or for the best performance and support for larger accounts or longer periods of time, we recommend using FinOps hubs with Data Explorer.

<br>

## ListCostLessThanContractedCost

<sup>Severity: Warning</sup>

`ListCost` (based on public, retail prices) is less than `ContractedCost` (based on negotiated discounts) in the data from Cost Management. This should never happen. This will cause your savings calculations to not add up precisely.

**Mitigation**: Confirm the `ListUnitPrice` in the cost data matches what's in the price data. If the list price is correct, file a support request with the Cost Management team to confirm both the `ListUnitPrice` and `ContractedUnitPrice` are correct and explain why the price after negotiated discounts would be higher than public, retail rates.

<br>

## ManifestReadFailed

<sup>Severity: Critical</sup>

FinOps hub **msexports_ExecuteETL** pipeline failed to read the Cost Management manifest file.

**Mitigation**:

1. If the error occurred on a working hub instance when no changes were made to the hub or export, then Cost Management possibly changed the manifest schema for an existing API version.
2. If the error occurred after you create a new or change an existing export, then the export API version might use a new unsupported manifest schema.
3. If the error occurred after a hub deployment (initial install or upgrade), then the deployment possibly failed or there could be a bug in the pipeline.

To confirm the manifest schema (\#1) or API version (\#2):

1. Open the hub storage account in the Azure portal or storage explorer.
2. If in the Azure portal, go to **Storage browser** in the menu.
3. Select the **msexports** container.
4. Navigate down the file hierarchy for the export with the issue (see the manifest location in the error message).
5. Find the **manifest.json** file and select the menu (**⋯**), then select **View/edit**.
6. Identify the following properties:
   ```json
   {
     "exportConfig": {
       "resourceId": "<scope-id>/providers/Microsoft.CostManagement/exports/<export-name>",
       "dataVersion": "<dataset-version>",
       "apiVersion": "2023-07-01-preview",
       "type": "<dataset-type>",
       ...
     },
     ...
   }
   ```
7. Confirm they're set to the following supported values:
   - **resourceId** can be any scope ID and any export name, but it must exist with the "Microsoft.CostManagement/exports" resource type. It's case-insensitive.
   - **type** must exist, but shouldn't fail with this error for any non-null value.
   - **dataVersion** must exist, but shouldn't fail with this error for any non-null value.
   - **apiVersion** isn't used explicitly but can signify changes to the manifest schema. See [supported API versions](../hubs/data-processing.md#datasets) for details.
8. If you're using a newer API version:
   1. To track adding support for the new API version, [create a change request issue in GitHub](https://aka.ms/ftk/ideas).
   2. Delete the export in Cost Management.
   3. Create an export using the [New-FinOpsCostExport PowerShell command](../powershell/cost/New-FinOpsCostExport.md) using a supported API version.
       >[!TIP]
       >If you consider yourself a power user, you may want to try updating the pipeline yourself for the quickest resolution. To do that, open Data Factory, navigate to Author > Pipelines > msexports_ExecuteETL, and select the applicable "Set" activities and update the **Settings** > **Value** property as needed. If you do this, you do not need to re-create the export with an older version. Please still report the issue and consider sharing the new JSON from the `{}` icon at the top-right of the pipeline designer._
9. If you notice the properties changed for a supported API version:
   1. To track the breaking change, [create a change request issue in GitHub](https://aka.ms/ftk/ideas). Include the **type**, **dataVersion**, and **apiVersion** from your manifest.json file.
   2. File a support request with Cost Management to request their change be reverted as it breaks everyone using FinOps hubs or other custom solutions. Include the following details to help the Cost Management support team identify the issue within their system. Cost Management doesn't have context about FinOps hubs, so you should keep the details focused on Cost Management functionality. Here's an example:
      > I am using Cost Management exports to pull my cost data into ADLS. I have an ADF pipeline that is processing the data when manifest files are written. My pipeline was built on API version `<your-supported-api-version>` which expects `exportConfig.resourceId`, `exportConfig.type`, and `exportConfig.dataVersion` properties to be delivered consistently. I noticed these files are not being included in the manifest file for this API version for my export that ran on `<your-export-date>`. My expectation is that the manifest file should never change for an existing API version. Can you please revert these changes?
      >
      > To help you troubleshoot, here is my manifest file: {your-manifest-json}

If the manifest properties look good and it was a new or upgraded FinOps hub instance, confirm the deployment:

1. Open the hub resource group in the Azure portal.
2. Select **Settings** > **Deployments** in the menu on the left.
3. Confirm all deployments are successful. Specifically, look for the following deployment names:
   - main
   - hub
   - dataFactoryResources
   - storage
   - keyVault
4. If any deployments failed, review the error message to determine if it's something you can resolve yourself (for example, name conflict, fixable policy violation).
5. If the error seems transient, try deploying again.
6. If the error persists, create a [discussion](https://aka.ms/ftk/discuss) to see if anyone else if facing an issue or knows of a possible workaround (especially for policy issues).
7. If the error is clearly a bug or feature gap, [create a bug or feature request issue in GitHub](https://aka.ms/ftk/ideas).

We try to respond to issues and discussions within two business days.

<!--
TODO: Consider the following ways to streamline this in the future:
1. Opt-in telemetry/email to the FTK team when errors happen in the pipeline
2. Detect these errors from the Data ingestion report.
3. Create a hub configuration workbook to detect configuration issues.
4. Consider renaming the main deployment file so it doesn't risk conflicting with other deployments.
-->

<br>

## MissingContractedCost

<sup>Severity: Informational</sup>

This error code is shown in the `x_SourceChanges` column when `ContractedCost` is either null or 0 and `EffectiveCost` is greater than 0. The error indicates Microsoft Cost Management didn't include `ContractedCost` for the specified rows, which means savings can't be calculated.

**Mitigation**: As a workaround to the missing data, FinOps toolkit reports copy the `EffectiveCost` into the `ContractedCost` column for rows flagged with this error code. Savings aren't available for these records.

To calculate complete savings, you can join cost and usage data with prices. For more information, see [issue #873](https://github.com/microsoft/finops-toolkit/issues/873).

<br>

## MissingContractedUnitPrice

<sup>Severity: Informational</sup>

This error code is shown in the `x_SourceChanges` column when `ContractedUnitPrice` is either null or 0 and `EffectiveUnitPrice` is greater than 0. The error indicates Microsoft Cost Management didn't include `ContractedUnitPrice` for the specified rows, which means savings can't be calculated.

**Mitigation**: As a workaround to the missing data, FinOps toolkit reports copy the `EffectiveUnitPrice` into the `ContractedUnitPrice` column for rows flagged with this error code. Savings aren't available for these records.

To calculate complete savings, you can join cost and usage data with prices. For more information, see [issue #873](https://github.com/microsoft/finops-toolkit/issues/873).

<br>

## MissingListCost

<sup>Severity: Informational</sup>

This error code is shown in the `x_SourceChanges` column when `ListCost` is either null or 0 and `ContractedCost` is greater than 0. The error indicates Microsoft Cost Management didn't include `ListCost` for the specified rows, which means savings can't be calculated.

**Mitigation**: As a workaround to the missing data, FinOps toolkit reports copy the `ContractedCost` into the `ListCost` column for rows flagged with this error code. Savings aren't available for these records.

To calculate complete savings, you can join cost and usage data with prices. For more information, see [issue #873](https://github.com/microsoft/finops-toolkit/issues/873).

<br>

## MissingListUnitPrice

<sup>Severity: Informational</sup>

This error code is shown in the `x_SourceChanges` column when `ListUnitPrice` is either null or 0 and `ContractedUnitPrice` is greater than 0. The error indicates Microsoft Cost Management didn't include `ListUnitPrice` for the specified rows, which means savings can't be calculated.

**Mitigation**: As a workaround to the missing data, FinOps toolkit reports copy the `ContractedUnitPrice` into the `ListUnitPrice` column for rows flagged with this error code. Savings aren't available for these records.

To calculate complete savings, you can join cost and usage data with prices. For more information, see [issue #873](https://github.com/microsoft/finops-toolkit/issues/873).

<br>

## MissingProviderName

<sup>Severity: Informational</sup>

This error code is shown in the `x_SourceChanges` column when `ProviderName` is null. The error indicates the provider of the dataset (for example, Microsoft Cost Management) did not include a `ProviderName` value for the specified rows.

**Mitigation**: As a workaround to the missing data, FinOps toolkit reports attempt to identify the provider based on the available columns.

<br>

## Query '...' references other queries or steps

<sup>Severity: Minor</sup>

The source of this error is unknown. This error may be surfaced randomly when refreshing Power BI data.

**Mitigation**: If you receive this error, select **Apply change** again.

This error has only been reported in storage reports. If you have long data refresh times or experience this error often, consider switching to [FinOps hubs](../hubs/finops-hubs-overview.md) with Data Explorer. Data Explorer uses KQL reports which do not require scheduling or incremental refresh. Data is pulled when the report is opened, so reports always show the latest data.

<br>

## ResourceAccessForbiddenException

<sup>Severity: Major</sup>

Power BI: An exception of the 'Microsoft.Mashup.Engine.Interface.ResourceAccessForbiddenException' type was thrown

Indicates that the account loading data in Power BI doesn't have the [Storage Blob Data Reader role](/azure/role-based-access-control/built-in-roles#storage-blob-data-reader). Grant this role to the account loading data in Power BI.

<br>

## Response payload size is... and has exceeded the limit

<sup>Severity: Major</sup>

Azure Resource Graph queries in the Governance and Workload optimization Power BI reports may return an error similar to:

> _OLE DB or ODBC error: [Expression.Error] Please provide below info when asking for support: timestamp = {timestamp}, correlationId = {guid}. Details: Response payload size is {number}, and has exceeded the limit of 16777216. Please consider querying less data at a time and make paginated call if needed._

This error means that you have more resources than are supported in an unfiltered Resource Graph query. This happens because FinOps toolkit reports are designed to show resource-level details and are not aggregated. They are designed for small- and medium-sized environments and not designed to support organizations with millions of resources.

**Mitigation**: If you experience this error, there are several options:

- Remove columns that are not necessary for your needs.
- Filter the query to return fewer resources based on what's most important for you (e.g., subscriptions, tags).
- Disable the query so it doesn't block other queries from running.

<br>

## RoleAssignmentUpdateNotPermitted

<sup>Severity: Minor</sup>

If you deleted FinOps Hubs and are attempting to redeploy it with the same values, including the Managed Identity name, you might encounter the following known issue:

```json
"code": "RoleAssignmentUpdateNotPermitted",
"message": "Tenant ID, application ID, principal ID, and scope are not allowed to be updated."
```

**Mitigation**: To fix that issue you have to remove the stale identity:

- Navigate to the storage account and select **Access control (IAM)** in the menu.
- Select the **Role assignments** tab.
- Find any role assignments with an "unknown" identity and delete them.

<br>

## RoleAssignmentExists

<sup>Severity: Minor</sup>

When upgrading FinOps hubs from one version to another, you might encounter the following error if role assignments created in a previous deployment still exist:

```json
"code": "RoleAssignmentExists",
"message": "The role assignment already exists."
```

This is likely because a managed identity was explicitly deleted without first removing all of its role assignments.

**Mitigation**: To fix this issue, delete the orphaned role assignments in the Azure portal:

- Navigate to the resource group or affected resource (such as Data Explorer cluster).
- Select **Access control (IAM)** in the menu.
- Select the **Role assignments** tab.
- Find any role assignments with an unknown identity and delete them.

<br>

## SchemaLoadFailed

<sup>Severity: Critical</sup>

FinOps hub **msexports_ETL_ingestion** pipeline failed to load the schema file.

**Mitigation**: Review the error message to note the dataset type and version, which are formatted with an underscore (for example, `<type>_<version>` or `FocusCost_1.0`). Confirm that the dataset and type are both supported by the deployed version of FinOps hubs. See [supported datasets](../hubs/data-processing.md#datasets) for details.

<br>

## SchemaNotFound

<sup>Severity: Critical</sup>

FinOps hub **msexports_ExecuteETL** pipeline wasn't able to find the schema mapping file for the exported dataset.

**Mitigation**: Confirm the dataset type and version are supported. See [supported datasets](../hubs/data-processing.md#datasets) for details. If the dataset is supported, confirm the hub version with the [Data ingestion report](../power-bi/data-ingestion.md).

To add support for another dataset, create a custom mapping file and save it to `config/schemas/<dataset-type>_<dataset-version>.json`. The `<dataset-type>` `<dataset-version>` values much match what Cost Management uses. To identify the datatype for each column, use an existing schema file as a template. Some datasets have different schemas for EA and Microsoft Customer Agreement (MCA). They can't be identified via these attributes and might cause an issue if you have both account types. We're working on adding datasets and account for the EA and MCA differences by aligning to FOCUS.

<br>

## The import Storage URL matches no exports

<sup>Severity: Major</sup>

If you are experiencing this in FinOps toolkit 0.8 reports, the error is because of a reference to a parameter that does not exist.

**Mitigation**: This was fixed in FinOps toolkit 0.9. Update to the latest release to apply the fix. If you need to apply the fix directly to the 0.8 reports, edit the **ftk_DemoFilter** function in the advanced editor and change the contents to: `() => ""`. Save, then close and apply all changes.

<br>

## UnknownExportFile

<sup>Severity: Informational</sup>

The file in hub storage doesn't look like it was exported from Cost Management. File is ignored.

**Mitigation**: The **msexports** container is intended for Cost Management exports only. Move other files in another storage container.

<br>

## UnknownFocusVersion

<sup>Severity: Informational</sup>

This error code is shown in the `x_SourceChanges` column when a FOCUS version could not be identified.

**Mitigation**: Validate that the FOCUS dataset is using a supported FOCUS version. Report this issue with an anonymized sample of the data at https://aka.ms/ftk/ideas to investigate further.

<br>

## UnknownHubVersion

<sup>Severity: Critical</sup>

Unable to identify the version of FinOps hubs from the settings file. Verify settings are correct. FinOps hubs 0.1.1 and earlier doesn't work with this Power BI report.

**Mitigation**: Upgrade to the latest version of [FinOps hubs](../hubs/finops-hubs-overview.md) or download Power BI reports from the [FinOps toolkit v0.1.1 release](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1).

<br>

## UnsupportedExportFileType

<sup>Severity: Critical</sup>

Unable to ingest the specified export file because the file type isn't supported.

**Mitigation**: Either convert the file to a supported file format before adding to the msexports container or add support for converting the new file type to the **msexports_ETL_ingestion** pipeline.

<br>

## UnsupportedExportType

<sup>Severity: Warning</sup>

The export manifest in hub storage indicates the export was for an unsupported dataset. Exported data is reported as ingestion errors.

**Mitigation**: Create a new Cost Management export for FOCUS cost and either stop the current export or change it to export to a different storage container.

<br>

## The {name} resource provider isn't registered in subscription {guid}

<sup>Severity: Minor</sup>

Open the subscription in the Azure portal, then select **Settings** > **Resource providers**, select the resource provider row (for example, Microsoft.EventGrid), then select the **Register** command at the top of the page. Registration might take a few minutes.

<br>

## x_PricingSubcategory shows the commitment discount ID

Cost Management exports before February 28, 2024 had a bug where `x_PricingSubcategory` was being set incorrectly for committed usage. You should expect to see values like `Committed Spend` and `Committed Usage`. Instead, you might see values like:

- `Committed /providers/Microsoft.BillingBenefits/savingsPlanOrders/###/savingsPlans/###`
- `Committed /providers/Microsoft.Capacity/reservationOrders/###/reservations/###`

If you see these values, re-export the cost data for that month. If you need to export data for an older month that isn't available, contact support to request the data be exported for you to resolve the data quality issue from the previous export runs.

<br>

## Power BI: Reports are missing data for specific dates

If your report is missing all data for one or more months, check the **Number of Months**, **RangeStart**, and **RangeEnd** parameters to ensure the data isn't being filtered out. 

To check parameters, select **Transform data** > **Edit parameters** in the ribbon or select the individual parameters in the **🛠️ Setup** folder from the query editor window. 

- If you want to always show a specific number of recent months, set **Number of Months** to the number of closed (completed) months. The current month is an extra month in addition to the closed number of months.
- If you want a fixed date range that doesn't change over time (for example, fiscal year reporting), set **RangeStart** and **RangeEnd**.
- If you want to report on all data available, confirm that all three date parameters are empty.

For more information, see [Set up your first report](../power-bi/setup.md).

<br>

## Power BI: Reports are empty (no data)

If you don't see any data in your Power BI or other reports or tools, try the following based on your data source:

1. If using the Cost Management connector in Power BI, check the `Billing Account ID` and `Number of Months` parameters to ensure they're set correctly. Keep in mind old billing accounts might not have data in recent months.
2. If using FinOps hubs, check the storage account to ensure data is populated in the **ingestion** container. You should see either a **providers** or **subscriptions** folder. Use the following sections to troubleshoot further.

### FinOps hubs: Ingestion container is empty

If the **ingestion** container is empty, open the Data Factory instance in Data Factory Studio and select **Manage** > **Author** > **Triggers** and verify the **msexports_FileAdded** trigger is started. If not, start it.

If the trigger fails to start with a "resource provider isn't registered" error, open the subscription in the Azure portal, then select **Settings** > **Resource providers**, select the **Microsoft.EventGrid** row, then select the **Register** command at the top of the page. Registration might take a few minutes.

After registration completes, start the **msexports_FileAdded** trigger again.

After the trigger is started, rerun all connected Cost Management exports. Data should be fully ingested within 10-20 minutes, depending on the size of the account.

If the issue persists, check if Cost Management exports are configured with file partitioning enabled. If you find it disabled, turn it on and rerun the exports.

Confirm the **ingestion** container is populated and refresh your reports or other connected tools.

### FinOps hubs: Files available in the ingestion container

If the **ingestion** container isn't empty, confirm whether you have **parquet** or **csv.gz** files by drilling into the folders.

Once you know, verify the **FileType** parameter is set to `.parquet` or `.gz` in the Power BI report. See [Connect to your data](../power-bi/reports.md#connect-to-your-data) for details.

If you're using another tool, ensure it supports the file type you're using.

<br>

## Power BI: The remote name couldn't be resolved: '\<storage-account>.dfs.core.windows.net'

Indicates that the storage account name is incorrect. If using FinOps hubs, verify the **StorageUrl** parameter from the deployment. See [Connect to your data](../power-bi/reports.md#connect-to-your-data) for details.

<br>

## Power BI: We can't convert the value null to type Logical

Indicates that the **Billing Account ID** parameter is empty. If using FinOps hubs, set the value to the desired billing account ID. If you don't have access to the billing account or don't want to include commitment purchases and refunds, set the value to `0` and open the **CostDetails** query in the advanced editor and change the `2` to a `1`. It informs the report to not load actual/billed cost data from the Cost Management connector. See [Connect to your data](../power-bi/reports.md#connect-to-your-data) for details.

Applicable versions: **0.1 - 0.1.1** (fixed in **0.2**)

<br>

## FinOps hubs: We can't convert the value null to type Table

This error typically indicates that data wasn't ingested into the **ingestion** container.

If you just upgraded to FinOps hubs 0.2, the problem could result from the Power BI report being old (from 0.1.x) or because you aren't using FOCUS exports. See the [Upgrade guide](../hubs/upgrade.md) for details.

See [Reports are empty (no data)](#power-bi-reports-are-empty-no-data) for more troubleshooting steps.

<br>

<!--
## Create a support request

If you're facing an error not listed above or need more help, file a [support request](/azure/azure-portal/supportability/how-to-create-azure-support-request) and specify the issue type as Billing.

<br>
-->

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.10/bladeName/Toolkit/featureName/Help.DataDictionary)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%2B1-desc)

<br>

## Related content

If you don't see the error you're experiencing, walk through the [troubleshooting guide](troubleshooting.md). If you have any questions, [start a discussion](https://aka.ms/ftk/discuss) or [create an issue](https://aka.ms/ftk/ideas) in GitHub.

<br>
