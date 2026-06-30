<#
.SYNOPSIS
Creates or updates the custom Log Analytics tables and Data Collection Rules (DCRs) required
for DCR-based ingestion in the Azure Optimization Engine.

.DESCRIPTION
This script provisions all custom Log Analytics tables with explicit schemas and one DCR per table,
replacing the legacy Log Analytics Data Collector API (SharedKey) ingestion. It must be run once
on both new and existing AOE installations. On existing installations, it also migrates the SQL
control table to store the DCR immutable IDs.

The script:
- Reads the Data Collection Endpoint (DCE) logs ingestion endpoint from the AzureOptimization_DCEIngestionEndpoint automation variable (the DCE and variable are expected to be deployed via the Bicep template).- Creates or updates each custom Log Analytics table schema.
- Creates or updates one DCR per table.
- Assigns the Monitoring Metrics Publisher role on the resource group containing the DCRs to the Automation account managed identity.
- Writes the DCR immutable ID for each table into the SQL LogAnalyticsIngestControl table.
- Creates/updates the AzureOptimization_DCEIngestionEndpoint automation variable.
- Removes the AzureOptimization_LogAnalyticsWorkspaceKey automation variable (no longer needed).

.PARAMETER ResourceGroupName
The resource group where the AOE Automation account and (optionally) Log Analytics workspace reside.

.PARAMETER AutomationAccountName
The name of the AOE Automation account.

.PARAMETER WorkspaceName
The name of the Log Analytics workspace where custom tables will be created.

.PARAMETER WorkspaceResourceGroupName
The resource group of the Log Analytics workspace. Defaults to ResourceGroupName if not specified.

.PARAMETER WorkspaceSubscriptionId
The subscription ID of the Log Analytics workspace. Defaults to the current subscription if not specified.

.PARAMETER SqlServerName
The SQL Server hostname (FQDN or short name). If short name, '.database.windows.net' is appended.

.PARAMETER SqlDatabaseName
The name of the AOE SQL database.

.PARAMETER CloudEnvironment
The Azure cloud environment. Default is AzureCloud. Supported: AzureCloud, AzureChinaCloud, AzureUSGovernment.

.EXAMPLE
.\Setup-LogAnalyticsTablesAndDCRs.ps1 `
    -ResourceGroupName "rg-aoe" `
    -AutomationAccountName "aa-aoe" `
    -WorkspaceName "la-aoe" `
    -SqlServerName "sql-aoe" `
    -SqlDatabaseName "db-aoe"

.LINK
https://aka.ms/AzureOptimizationEngine/deployment
#>
param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string] $AutomationAccountName,

    [Parameter(Mandatory = $true)]
    [string] $WorkspaceName,

    [Parameter(Mandatory = $false)]
    [string] $WorkspaceResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string] $WorkspaceSubscriptionId,

    [Parameter(Mandatory = $true)]
    [string] $SqlServerName,

    [Parameter(Mandatory = $true)]
    [string] $SqlDatabaseName,

    [Parameter(Mandatory = $false)]
    [string] $CloudEnvironment = "AzureCloud"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($WorkspaceResourceGroupName))
{
    $WorkspaceResourceGroupName = $ResourceGroupName
}

#region Resolve Monitor audience URL per cloud
switch ($CloudEnvironment)
{
    "AzureChinaCloud" { $armEndpoint = "https://management.chinacloudapi.cn" }
    "AzureUSGovernment" { $armEndpoint = "https://management.usgovcloudapi.net" }
    default { $armEndpoint = "https://management.azure.com" }
}
#endregion

#region Resolve SQL connection string
if (-not ($SqlServerName -like "*.*"))
{
    switch ($CloudEnvironment)
    {
        "AzureChinaCloud" { $SqlServerName = "$SqlServerName.database.chinacloudapi.cn" }
        "AzureUSGovernment" { $SqlServerName = "$SqlServerName.database.usgovcloudapis.net" }
        default { $SqlServerName = "$SqlServerName.database.windows.net" }
    }
}
#endregion

Write-Host "Setting up Log Analytics custom tables and DCRs for the Azure Optimization Engine..." -ForegroundColor Green

#region Resolve workspace and current subscription context
$context = Get-AzContext
if ([string]::IsNullOrEmpty($WorkspaceSubscriptionId))
{
    $WorkspaceSubscriptionId = $context.Subscription.Id
}
$currentSubscriptionId = $context.Subscription.Id

$workspaceResourceId = "/subscriptions/$WorkspaceSubscriptionId/resourceGroups/$WorkspaceResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName"
$workspaceLocation = (Get-AzOperationalInsightsWorkspace -ResourceGroupName $WorkspaceResourceGroupName -Name $WorkspaceName).Location
#endregion

#region Get DCE endpoint and resource ID from automation variable
$dceVar = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName `
    -Name "AzureOptimization_DCEIngestionEndpoint" -ErrorAction SilentlyContinue
if ($null -eq $dceVar -or [string]::IsNullOrEmpty($dceVar.Value))
{
    throw "AzureOptimization_DCEIngestionEndpoint automation variable not found. Ensure the Bicep template has been deployed first."
}
$dceLogsIngestionEndpoint = $dceVar.Value
Write-Host "DCE Logs Ingestion endpoint: $dceLogsIngestionEndpoint" -ForegroundColor Cyan

# Discover the DCE resource ID by searching for DCEs in the resource group whose logsIngestion endpoint matches

$dceListResponse = Get-AzDataCollectionEndpoint -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
$matchedDce = $dceListResponse | Where-Object { $_.LogIngestionEndpoint -eq $dceLogsIngestionEndpoint }
if ($null -eq $matchedDce)
{
    throw "Could not find a Data Collection Endpoint in resource group $ResourceGroupName with logsIngestion endpoint '$dceLogsIngestionEndpoint'."
}
$dceResourceId = $matchedDce.Id
Write-Host "DCE resource ID: $dceResourceId" -ForegroundColor Cyan
#endregion

#region Get automation account managed identity principal ID
$automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName
$automationPrincipalId = $automationAccount.Identity.PrincipalId
if ([string]::IsNullOrEmpty($automationPrincipalId))
{
    Write-Host "Could not retrieve the managed identity principal ID for the Automation account $AutomationAccountName." -ForegroundColor Yellow
    Write-Host "Grant the Metrics Publisher role to the AOE's managed identity on the resource group containing the DCRs after this script completes." -ForegroundColor Yellow
}
else
{
    Write-Host "Retrieved managed identity principal ID for Automation account: $automationPrincipalId" -ForegroundColor Cyan
}
#endregion

#region Monitoring Metrics Publisher role definition ID
# Role definition: Monitoring Metrics Publisher (3913510d-42f4-4e42-8a64-420c390055eb)
$monitoringMetricsPublisherRoleId = "3913510d-42f4-4e42-8a64-420c390055eb"
#endregion

#region Table schema definitions
# Each entry defines the columns that the ingest runbooks write.
# Column type mapping from the legacy _suffix convention:
#   _s  -> string
#   _g  -> string (GUIDs stored as plain strings in the typed column name)
#   _t  -> datetime
#   _d  -> real
#   _b  -> boolean
# TimeGenerated is mandatory for all custom tables.

$tableSchemas = @{

    "VMsV1"                = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "Zones_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "VMName_s"; type = "string" }
        @{ name = "DeploymentModel_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "VMSize_s"; type = "string" }
        @{ name = "CoresCount_s"; type = "string" }
        @{ name = "MemoryMB_s"; type = "string" }
        @{ name = "OSType_s"; type = "string" }
        @{ name = "LicenseType_s"; type = "string" }
        @{ name = "DataDiskCount_s"; type = "string" }
        @{ name = "NicCount_s"; type = "string" }
        @{ name = "UsesManagedDisks_s"; type = "string" }
        @{ name = "AvailabilitySetId_s"; type = "string" }
        @{ name = "BootDiagnosticsEnabled_s"; type = "string" }
        @{ name = "BootDiagnosticsStorageAccount_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
        @{ name = "PowerState_s"; type = "string" }
        @{ name = "ImagePublisher_s"; type = "string" }
        @{ name = "ImageOffer_s"; type = "string" }
        @{ name = "ImageSku_s"; type = "string" }
        @{ name = "ImageVersion_s"; type = "string" }
        @{ name = "ImageExactVersion_s"; type = "string" }
        @{ name = "OSName_s"; type = "string" }
        @{ name = "OSVersion_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
    )

    "DisksV1"              = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "DiskName_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "OwnerVMId_s"; type = "string" }
        @{ name = "DeploymentModel_s"; type = "string" }
        @{ name = "DiskType_s"; type = "string" }
        @{ name = "TimeCreated_s"; type = "string" }
        @{ name = "DiskIOPS_s"; type = "string" }
        @{ name = "DiskThroughput_s"; type = "string" }
        @{ name = "DiskTier_s"; type = "string" }
        @{ name = "DiskState_s"; type = "string" }
        @{ name = "EncryptionType_s"; type = "string" }
        @{ name = "Zones_s"; type = "string" }
        @{ name = "Caching_s"; type = "string" }
        @{ name = "DiskSizeGB_s"; type = "string" }
        @{ name = "SKU_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
    )

    "VhdDisksV1"           = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "DiskName_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "OwnerVMId_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "DeploymentModel_s"; type = "string" }
        @{ name = "DiskType_s"; type = "string" }
        @{ name = "Caching_s"; type = "string" }
        @{ name = "DiskSizeGB_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
    )

    "AvailSetsV1"          = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "InstanceName_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "SkuName_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "FaultDomains_s"; type = "string" }
        @{ name = "UpdateDomains_s"; type = "string" }
        @{ name = "VmCount_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "Zones_s"; type = "string" }
    )

    "AdvisorV1"            = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "Category"; type = "string" }
        @{ name = "Impact_s"; type = "string" }
        @{ name = "ImpactedArea_s"; type = "string" }
        @{ name = "Description_s"; type = "string" }
        @{ name = "RecommendationText_s"; type = "string" }
        @{ name = "RecommendationTypeId_g"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "InstanceName_g"; type = "string" }
        @{ name = "InstanceName_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "AdditionalInfo_s"; type = "string" }
        @{ name = "ResourceGroup"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
    )

    "RemediationV1"        = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "ResourceId_s"; type = "string" }
        @{ name = "RemediationId_g"; type = "string" }
        @{ name = "RemediationName_s"; type = "string" }
        @{ name = "PolicyAssignmentId_s"; type = "string" }
        @{ name = "PolicyDefinitionId_s"; type = "string" }
        @{ name = "ProvisioningState_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
    )

    "ConsumptionV1"        = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "AdditionalInfo_s"; type = "string" }
        @{ name = "benefitId_s"; type = "string" }
        @{ name = "benefitName_s"; type = "string" }
        @{ name = "BillingAccountId_s"; type = "string" }
        @{ name = "BillingAccountName_s"; type = "string" }
        @{ name = "BillingCurrencyCode_s"; type = "string" }
        @{ name = "BillingPeriodEndDate_s"; type = "string" }
        @{ name = "BillingPeriodStartDate_s"; type = "string" }
        @{ name = "BillingProfileId_s"; type = "string" }
        @{ name = "BillingProfileName_s"; type = "string" }
        @{ name = "ChargeType_s"; type = "string" }
        @{ name = "ConsumedService_s"; type = "string" }
        @{ name = "CostAllocationRuleName_s"; type = "string" }
        @{ name = "CostCenter_s"; type = "string" }
        @{ name = "CostInBillingCurrency_s"; type = "string" }
        @{ name = "Date_s"; type = "string" }
        @{ name = "EffectivePrice_s"; type = "string" }
        @{ name = "Frequency_s"; type = "string" }
        @{ name = "InvoiceSectionId_s"; type = "string" }
        @{ name = "InvoiceSectionName_s"; type = "string" }
        @{ name = "IsAzureCreditEligible_s"; type = "string" }
        @{ name = "MeterCategory_s"; type = "string" }
        @{ name = "MeterId_g"; type = "string" }
        @{ name = "MeterName_s"; type = "string" }
        @{ name = "MeterRegion_s"; type = "string" }
        @{ name = "MeterSubCategory_s"; type = "string" }
        @{ name = "OfferId_s"; type = "string" }
        @{ name = "PricingModel_s"; type = "string" }
        @{ name = "ProductOrderId_s"; type = "string" }
        @{ name = "ProductOrderName_s"; type = "string" }
        @{ name = "PublisherName_s"; type = "string" }
        @{ name = "PublisherType_s"; type = "string" }
        @{ name = "Quantity_s"; type = "string" }
        @{ name = "ReservationId_s"; type = "string" }
        @{ name = "ReservationName_s"; type = "string" }
        @{ name = "ResourceGroup"; type = "string" }
        @{ name = "ResourceId"; type = "string" }
        @{ name = "ResourceLocation_s"; type = "string" }
        @{ name = "ServiceFamily_s"; type = "string" }
        @{ name = "ServiceInfo1_s"; type = "string" }
        @{ name = "ServiceInfo2_s"; type = "string" }
        @{ name = "SubscriptionId"; type = "string" }
        @{ name = "SubscriptionName_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "Term_s"; type = "string" }
        @{ name = "UnitOfMeasure_s"; type = "string" }
        @{ name = "UnitPrice_s"; type = "string" }
    )

    "AADObjectsV1"         = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "ObjectId_g"; type = "string" }
        @{ name = "ObjectType_s"; type = "string" }
        @{ name = "ObjectSubType_s"; type = "string" }
        @{ name = "DisplayName_s"; type = "string" }
        @{ name = "SecurityEnabled_s"; type = "string" }
        @{ name = "ApplicationId_g"; type = "string" }
        @{ name = "Keys_s"; type = "string" }
        @{ name = "PrincipalNames_s"; type = "string" }
        @{ name = "Owners_s"; type = "string" }
        @{ name = "CreatedDate_t"; type = "datetime" }
        @{ name = "DeletedDate_s"; type = "string" }
    )

    "LoadBalancersV1"      = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "InstanceName_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "SkuName_s"; type = "string" }
        @{ name = "SkuTier_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "LbType_s"; type = "string" }
        @{ name = "LbRulesCount_s"; type = "string" }
        @{ name = "InboundNatRulesCount_s"; type = "string" }
        @{ name = "OutboundRulesCount_s"; type = "string" }
        @{ name = "FrontendIPsCount_s"; type = "string" }
        @{ name = "BackendIPCount_s"; type = "string" }
        @{ name = "BackendAddressesCount_s"; type = "string" }
        @{ name = "InboundNatPoolsCount_s"; type = "string" }
        @{ name = "BackendPoolsCount_s"; type = "string" }
        @{ name = "ProbesCount_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
    )

    "AppGatewaysV1"        = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "InstanceName_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "SkuName_s"; type = "string" }
        @{ name = "SkuTier_s"; type = "string" }
        @{ name = "SkuCapacity_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "Zones_s"; type = "string" }
        @{ name = "EnableHttp2_s"; type = "string" }
        @{ name = "GatewayIPsCount_s"; type = "string" }
        @{ name = "FrontendIPsCount_s"; type = "string" }
        @{ name = "FrontendPortsCount_s"; type = "string" }
        @{ name = "BackendIPCount_s"; type = "string" }
        @{ name = "BackendAddressesCount_s"; type = "string" }
        @{ name = "HttpSettingsCount_s"; type = "string" }
        @{ name = "HttpListenersCount_s"; type = "string" }
        @{ name = "BackendPoolsCount_s"; type = "string" }
        @{ name = "ProbesCount_s"; type = "string" }
        @{ name = "UrlPathMapsCount_s"; type = "string" }
        @{ name = "RequestRoutingRulesCount_s"; type = "string" }
        @{ name = "RewriteRulesCount_s"; type = "string" }
        @{ name = "RedirectConfsCount_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
    )

    "ResourceContainersV1" = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "ContainerType_s"; type = "string" }
        @{ name = "ContainerName_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "ResourceCount_s"; type = "string" }
        @{ name = "ManagedBy_s"; type = "string" }
        @{ name = "ContainerProperties_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
    )

    "RBACAssignmentsV1"    = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "Model_s"; type = "string" }
        @{ name = "PrincipalId_g"; type = "string" }
        @{ name = "PrincipalId_s"; type = "string" }
        @{ name = "Scope_s"; type = "string" }
        @{ name = "RoleDefinition_s"; type = "string" }
    )

    "VNetsV1"              = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "VNetName_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "Model_s"; type = "string" }
        @{ name = "VNetPrefixes_s"; type = "string" }
        @{ name = "DNSServers_s"; type = "string" }
        @{ name = "PeeringsCount_s"; type = "string" }
        @{ name = "EnableDdosProtection_s"; type = "string" }
        @{ name = "SubnetName_s"; type = "string" }
        @{ name = "SubnetPrefix_s"; type = "string" }
        @{ name = "SubnetDelegationsCount_s"; type = "string" }
        @{ name = "SubnetTotalPrefixIPs_s"; type = "string" }
        @{ name = "SubnetUsedIPs_s"; type = "string" }
        @{ name = "SubnetNSGId_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
    )

    "NICsV1"               = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "Name_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "IsPrimary_s"; type = "string" }
        @{ name = "EnableAcceleratedNetworking_s"; type = "string" }
        @{ name = "EnableIPForwarding_s"; type = "string" }
        @{ name = "TapConfigurationsCount_s"; type = "string" }
        @{ name = "HostedWorkloadsCount_s"; type = "string" }
        @{ name = "InternalDomainNameSuffix_s"; type = "string" }
        @{ name = "AppliedDnsServers_s"; type = "string" }
        @{ name = "DnsServers_s"; type = "string" }
        @{ name = "OwnerVMId_s"; type = "string" }
        @{ name = "OwnerPEId_s"; type = "string" }
        @{ name = "MacAddress_s"; type = "string" }
        @{ name = "NicType_s"; type = "string" }
        @{ name = "NicNSGId_s"; type = "string" }
        @{ name = "PrivateIPAddressVersion_s"; type = "string" }
        @{ name = "PrivateIPAllocationMethod_s"; type = "string" }
        @{ name = "IsIPConfigPrimary_s"; type = "string" }
        @{ name = "PrivateIPAddress_s"; type = "string" }
        @{ name = "PublicIPId_s"; type = "string" }
        @{ name = "IPConfigName_s"; type = "string" }
        @{ name = "SubnetId_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
    )

    "NSGsV1"               = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "NSGName_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "NicCount_s"; type = "string" }
        @{ name = "SubnetCount_s"; type = "string" }
        @{ name = "RuleName_s"; type = "string" }
        @{ name = "RuleProtocol_s"; type = "string" }
        @{ name = "RuleDirection_s"; type = "string" }
        @{ name = "RulePriority_s"; type = "string" }
        @{ name = "RuleAccess_s"; type = "string" }
        @{ name = "RuleDestinationAddresses_s"; type = "string" }
        @{ name = "RuleSourceAddresses_s"; type = "string" }
        @{ name = "RuleDestinationPorts_s"; type = "string" }
        @{ name = "RuleSourcePorts_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
    )

    "PublicIPsV1"          = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "Name_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "Model_s"; type = "string" }
        @{ name = "SkuName_s"; type = "string" }
        @{ name = "SkuTier_s"; type = "string" }
        @{ name = "AllocationMethod_s"; type = "string" }
        @{ name = "AddressVersion_s"; type = "string" }
        @{ name = "AssociatedResourceId_s"; type = "string" }
        @{ name = "PublicIpPrefixId_s"; type = "string" }
        @{ name = "IPAddress"; type = "string" }
        @{ name = "FQDN_s"; type = "string" }
        @{ name = "Zones_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
    )

    "VMSSV1"               = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "Zones_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "VMSSName_s"; type = "string" }
        @{ name = "ComputerNamePrefix_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "VMSSSize_s"; type = "string" }
        @{ name = "CoresCount_s"; type = "string" }
        @{ name = "MemoryMB_s"; type = "string" }
        @{ name = "OSType_s"; type = "string" }
        @{ name = "DataDiskCount_s"; type = "string" }
        @{ name = "NicCount_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "Capacity_s"; type = "string" }
        @{ name = "Priority_s"; type = "string" }
        @{ name = "OSDiskSize_s"; type = "string" }
        @{ name = "OSDiskCaching_s"; type = "string" }
        @{ name = "OSDiskSKU_s"; type = "string" }
        @{ name = "SinglePlacementGroup_s"; type = "string" }
        @{ name = "UpgradePolicy_s"; type = "string" }
        @{ name = "OverProvision_s"; type = "string" }
        @{ name = "PlatformFaultDomainCount_s"; type = "string" }
        @{ name = "ZoneBalance_s"; type = "string" }
        @{ name = "UsesManagedDisks_s"; type = "string" }
        @{ name = "ImagePublisher_s"; type = "string" }
        @{ name = "ImageOffer_s"; type = "string" }
        @{ name = "ImageSku_s"; type = "string" }
        @{ name = "ImageVersion_s"; type = "string" }
        @{ name = "ImageExactVersion_s"; type = "string" }
    )

    "SqlDbV1"              = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "ZoneRedundant_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "DBName_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "SkuName_s"; type = "string" }
        @{ name = "SkuTier_s"; type = "string" }
        @{ name = "SkuCapacity_s"; type = "string" }
        @{ name = "ServiceObjectiveName_s"; type = "string" }
        @{ name = "StorageAccountType_s"; type = "string" }
        @{ name = "LicenseType_s"; type = "string" }
        @{ name = "MaxSizeBytes_s"; type = "string" }
        @{ name = "MaxLogSizeBytes_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
    )

    "MonitorMetricsV1"     = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "ResourceName_s"; type = "string" }
        @{ name = "ResourceId"; type = "string" }
        @{ name = "MetricNames_s"; type = "string" }
        @{ name = "AggregationType_s"; type = "string" }
        @{ name = "AggregationOfType_s"; type = "string" }
        @{ name = "MetricValue_s"; type = "string" }
        @{ name = "TimeGrain_s"; type = "string" }
        @{ name = "TimeSpan_s"; type = "string" }
    )

    "PolicyStatesV1"       = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "ResourceId"; type = "string" }
        @{ name = "ResourceType_s"; type = "string" }
        @{ name = "ComplianceState_s"; type = "string" }
        @{ name = "ComplianceReason_s"; type = "string" }
        @{ name = "Effect_s"; type = "string" }
        @{ name = "AssignmentId_s"; type = "string" }
        @{ name = "AssignmentName_s"; type = "string" }
        @{ name = "InitiativeId_s"; type = "string" }
        @{ name = "InitiativeName_s"; type = "string" }
        @{ name = "DefinitionId_s"; type = "string" }
        @{ name = "DefinitionName_s"; type = "string" }
        @{ name = "DefinitionReferenceId_s"; type = "string" }
        @{ name = "EvaluatedOn_s"; type = "string" }
        @{ name = "StatesCount_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
    )

    "RecommendationsV1"    = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "Category"; type = "string" }
        @{ name = "ImpactedArea_s"; type = "string" }
        @{ name = "Impact_s"; type = "string" }
        @{ name = "RecommendationType_s"; type = "string" }
        @{ name = "RecommendationSubType_s"; type = "string" }
        @{ name = "RecommendationSubTypeId_g"; type = "string" }
        @{ name = "RecommendationDescription_s"; type = "string" }
        @{ name = "RecommendationAction_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "InstanceName_s"; type = "string" }
        @{ name = "AdditionalInfo_s"; type = "string" }
        @{ name = "ResourceGroup"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "SubscriptionName_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "FitScore_d"; type = "real" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "DetailsURL_s"; type = "string" }
        @{ name = "GeneratedDate_s"; type = "string" }
    )

    "ReservationsUsageV1"  = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "ReservationResourceId_s"; type = "string" }
        @{ name = "ReservationOrderId_s"; type = "string" }
        @{ name = "ReservationId_g"; type = "string" }
        @{ name = "DisplayName_s"; type = "string" }
        @{ name = "SKUName_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "ResourceType"; type = "string" }
        @{ name = "AppliedScopeType_s"; type = "string" }
        @{ name = "Term_s"; type = "string" }
        @{ name = "ProvisioningState_s"; type = "string" }
        @{ name = "RenewState_s"; type = "string" }
        @{ name = "PurchaseDate_s"; type = "string" }
        @{ name = "ExpiryDate_s"; type = "string" }
        @{ name = "Archived_s"; type = "string" }
        @{ name = "ReservedHours_s"; type = "string" }
        @{ name = "UsedHours_s"; type = "string" }
        @{ name = "UsageDate_s"; type = "string" }
        @{ name = "MinUtilPercentage_s"; type = "string" }
        @{ name = "AvgUtilPercentage_s"; type = "string" }
        @{ name = "MaxUtilPercentage_s"; type = "string" }
        @{ name = "PurchasedQuantity_s"; type = "string" }
        @{ name = "RemainingQuantity_s"; type = "string" }
        @{ name = "TotalReservedQuantity_s"; type = "string" }
        @{ name = "UsedQuantity_s"; type = "string" }
        @{ name = "UtilizedPercentage_s"; type = "string" }
        @{ name = "UtilTrend_s"; type = "string" }
        @{ name = "Util1Days_s"; type = "string" }
        @{ name = "Util7Days_s"; type = "string" }
        @{ name = "Util30Days_s"; type = "string" }
        @{ name = "Scope_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "CollectedDate_s"; type = "string" }
    )

    "AppServicePlansV1"    = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "SubscriptionGuid_g"; type = "string" }
        @{ name = "ResourceGroupName_s"; type = "string" }
        @{ name = "ZoneRedundant_s"; type = "string" }
        @{ name = "Location_s"; type = "string" }
        @{ name = "AppServicePlanName_s"; type = "string" }
        @{ name = "InstanceId_s"; type = "string" }
        @{ name = "Kind_s"; type = "string" }
        @{ name = "SkuName_s"; type = "string" }
        @{ name = "SkuTier_s"; type = "string" }
        @{ name = "SkuCapacity_s"; type = "string" }
        @{ name = "SkuFamily_s"; type = "string" }
        @{ name = "SkuSize_s"; type = "string" }
        @{ name = "ComputeMode_s"; type = "string" }
        @{ name = "NumberOfWorkers_s"; type = "string" }
        @{ name = "CurrentNumberOfWorkers_s"; type = "string" }
        @{ name = "MaximumNumberOfWorkers_s"; type = "string" }
        @{ name = "NumberOfSites_s"; type = "string" }
        @{ name = "PlanName_s"; type = "string" }
        @{ name = "Tags_s"; type = "string" }
        @{ name = "StatusDate_s"; type = "string" }
    )

    "PricesheetV1"         = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "MeterID_g"; type = "string" }
        @{ name = "MeterName_s"; type = "string" }
        @{ name = "MeterCategory_s"; type = "string" }
        @{ name = "MeterSubCategory_s"; type = "string" }
        @{ name = "MeterRegion_s"; type = "string" }
        @{ name = "UnitOfMeasure_s"; type = "string" }
        @{ name = "PartNumber_s"; type = "string" }
        @{ name = "UnitPrice_s"; type = "string" }
        @{ name = "CurrencyCode_s"; type = "string" }
        @{ name = "IncludedQuantity_s"; type = "string" }
        @{ name = "OfferId_s"; type = "string" }
        @{ name = "Term_s"; type = "string" }
        @{ name = "PriceType_s"; type = "string" }
    )

    "ReservationsPriceV1"  = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "productName_s"; type = "string" }
        @{ name = "serviceName_s"; type = "string" }
        @{ name = "skuName_s"; type = "string" }
        @{ name = "skuId_s"; type = "string" }
        @{ name = "armRegionName_s"; type = "string" }
        @{ name = "location_s"; type = "string" }
        @{ name = "effectiveStartDate_s"; type = "string" }
        @{ name = "effectiveEndDate_s"; type = "string" }
        @{ name = "unitPrice_s"; type = "string" }
        @{ name = "currencyCode_s"; type = "string" }
        @{ name = "unitOfMeasure_s"; type = "string" }
        @{ name = "armSkuName_s"; type = "string" }
        @{ name = "productId_s"; type = "string" }
        @{ name = "reservationTerm_s"; type = "string" }
        @{ name = "meterName_s"; type = "string" }
    )

    "SavingsPlansUsageV1"  = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "SavingsPlanResourceId_s"; type = "string" }
        @{ name = "SavingsPlanOrderId_s"; type = "string" }
        @{ name = "SavingsPlanId_g"; type = "string" }
        @{ name = "DisplayName_s"; type = "string" }
        @{ name = "SKUName_s"; type = "string" }
        @{ name = "Term_s"; type = "string" }
        @{ name = "ProvisioningState_s"; type = "string" }
        @{ name = "AppliedScopeType_s"; type = "string" }
        @{ name = "RenewState_s"; type = "string" }
        @{ name = "PurchaseDate_s"; type = "string" }
        @{ name = "BenefitStart_s"; type = "string" }
        @{ name = "ExpiryDate_s"; type = "string" }
        @{ name = "EffectiveDate_s"; type = "string" }
        @{ name = "BillingScopeId_s"; type = "string" }
        @{ name = "BillingAccountId_s"; type = "string" }
        @{ name = "BillingProfileId_s"; type = "string" }
        @{ name = "BillingPlan_s"; type = "string" }
        @{ name = "CommitmentGrain_s"; type = "string" }
        @{ name = "CommitmentCurrencyCode_s"; type = "string" }
        @{ name = "CommitmentAmount_s"; type = "string" }
        @{ name = "UtilTrend_s"; type = "string" }
        @{ name = "Util1Days_s"; type = "string" }
        @{ name = "Util7Days_s"; type = "string" }
        @{ name = "Util30Days_s"; type = "string" }
        @{ name = "Scope_s"; type = "string" }
        @{ name = "TenantGuid_g"; type = "string" }
        @{ name = "Cloud_s"; type = "string" }
        @{ name = "CollectedDate_s"; type = "string" }
    )

    "SuppressionsV1"       = @(
        @{ name = "TimeGenerated"; type = "datetime" }
        @{ name = "FilterId_g"; type = "string" }
        @{ name = "RecommendationSubTypeId_g"; type = "string" }
        @{ name = "FilterType_s"; type = "string" }
        @{ name = "InstanceId_g"; type = "string" }
        @{ name = "InstanceName_s"; type = "string" }
        @{ name = "FilterStartDate_t"; type = "datetime" }
        @{ name = "FilterEndDate_t"; type = "datetime" }
        @{ name = "Author_s"; type = "string" }
        @{ name = "Notes_s"; type = "string" }
    )
}

# Storage container -> LogAnalyticsSuffix mapping used to update SQL control table
$containerSuffixMap = @{
    "argvmexports"             = "VMsV1"
    "argdiskexports"           = "DisksV1"
    "argvhdexports"            = "VhdDisksV1"
    "argavailsetexports"       = "AvailSetsV1"
    "advisorexports"           = "AdvisorV1"
    "remediationlogs"          = "RemediationV1"
    "consumptionexports"       = "ConsumptionV1"
    "aadobjectsexports"        = "AADObjectsV1"
    "arglbexports"             = "LoadBalancersV1"
    "argappgwexports"          = "AppGatewaysV1"
    "argrescontainersexports"  = "ResourceContainersV1"
    "rbacexports"              = "RBACAssignmentsV1"
    "argvnetexports"           = "VNetsV1"
    "argnicexports"            = "NICsV1"
    "argnsgexports"            = "NSGsV1"
    "argpublicipexports"       = "PublicIPsV1"
    "argvmssexports"           = "VMSSV1"
    "argsqldbexports"          = "SqlDbV1"
    "azmonitorexports"         = "MonitorMetricsV1"
    "policystateexports"       = "PolicyStatesV1"
    "recommendationsexports"   = "RecommendationsV1"
    "reservationsexports"      = "ReservationsUsageV1"
    "argappserviceplanexports" = "AppServicePlansV1"
    "pricesheetexports"        = "PricesheetV1"
    "reservationspriceexports" = "ReservationsPriceV1"
    "savingsplansexports"      = "SavingsPlansUsageV1"
}
#endregion

$lognamePrefix = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName `
    -Name "AzureOptimization_LogAnalyticsLogPrefix" -ErrorAction SilentlyContinue
if (($null -eq $lognamePrefix -or [string]::IsNullOrEmpty($lognamePrefix.Value)))
{
    $lognamePrefix = "AzureOptimization"
}
else
{
    $lognamePrefix = $lognamePrefix.Value
}

$dcrApiVersion = "2022-06-01"
$tableSchemaApiVersion = "2023-01-01-preview"   # Tables API (GET/PUT schema)
$tableMigrateApiVersion = "2021-12-01-preview"  # Tables migrate endpoint

#region Get Log Analytics workspace resource ID in the target subscription context
if ($WorkspaceSubscriptionId -ne $currentSubscriptionId)
{
    Write-Host "Switching to workspace subscription $WorkspaceSubscriptionId..." -ForegroundColor Cyan
    Set-AzContext -SubscriptionId $WorkspaceSubscriptionId | Out-Null
}
#endregion

#region Create/update custom Log Analytics tables and DCRs
Write-Host "Processing $($tableSchemas.Keys.Count) custom Log Analytics tables and DCRs..." -ForegroundColor Green

$existingTables = Get-AzOperationalInsightsTable -ResourceGroupName $WorkspaceResourceGroupName -WorkspaceName $WorkspaceName

$dcrSuffixToImmutableId = @{}

#region Assign Monitoring Metrics Publisher role at resource group scope
Write-Host "Granting Monitoring Metrics Publisher on resource group to Automation MI..." -ForegroundColor Green

if ($automationPrincipalId)
{
    # Role assignment must be created in the DCR subscription/resource group context
    if ($WorkspaceSubscriptionId -ne $currentSubscriptionId)
    {
        Set-AzContext -SubscriptionId $currentSubscriptionId | Out-Null
    }

    $dcrResourceGroupScope = "/subscriptions/$currentSubscriptionId/resourceGroups/$ResourceGroupName"
    $existingAssignment = Get-AzRoleAssignment -ObjectId $automationPrincipalId `
        -RoleDefinitionId $monitoringMetricsPublisherRoleId `
        -Scope $dcrResourceGroupScope -ErrorAction SilentlyContinue
    if ($null -eq $existingAssignment)
    {
        New-AzRoleAssignment -ObjectId $automationPrincipalId `
            -RoleDefinitionId $monitoringMetricsPublisherRoleId `
            -Scope $dcrResourceGroupScope | Out-Null
        Write-Host "  Role assigned on resource group scope." -ForegroundColor Gray
    }
    else
    {
        Write-Host "  Role already assigned on resource group scope." -ForegroundColor Gray
    }
}
else
{
    Write-Host "  Automation MI not found; skipping role assignment." -ForegroundColor Yellow
}

# Restore workspace subscription context for table operations
if ($WorkspaceSubscriptionId -ne $currentSubscriptionId)
{
    Set-AzContext -SubscriptionId $WorkspaceSubscriptionId | Out-Null
}
#endregion

foreach ($suffix in $tableSchemas.Keys)
{
    $tableName = "$lognamePrefix$suffix" + "_CL"
    $streamName = "Custom-$lognamePrefix$suffix"
    $dcrName = "AOE-DCR-$suffix"

    Write-Host "  [$suffix] Setting up table $tableName..." -ForegroundColor Cyan

    #region Build table columns payload
    $columns = @()
    foreach ($col in $tableSchemas[$suffix])
    {
        $columns += @{ name = $col.name; type = $col.type }
    }

    # Build source stream columns from table schema columns by removing the legacy type suffix
    # (_s, _g, _t, _d, _b). This keeps table column names backward-compatible while accepting
    # CSV/source payload fields without suffixes.
    $sourceColumnsByName = [ordered]@{}
    $destinationToSource = @{}
    foreach ($col in $tableSchemas[$suffix])
    {
        $sourceName = $col.name
        if ($sourceName -match '^(.*)_[sgtdb]$')
        {
            $sourceName = $Matches[1]
        }

        if (-not $sourceColumnsByName.Contains($sourceName))
        {
            $sourceColumnsByName[$sourceName] = @{ name = $sourceName; type = $col.type }
        }

        $destinationToSource[$col.name] = $sourceName
    }

    $sourceColumns = @($sourceColumnsByName.Values)

    $tablePayload = @{
        properties = @{
            schema = @{
                name    = $tableName
                columns = $columns
            }
        }
    } | ConvertTo-Json -Depth 10

    $existingTable = $null
    try
    {
        Write-Host "    Checking if table $tableName exists and its type..." -ForegroundColor Yellow
        $existingTable = $existingTables | Where-Object { $_.Name -eq $tableName }
    }
    catch
    {
        # Table does not yet exist; the PUT below will create it as a DCR-based table.
    }

    if ($null -ne $existingTable -and $existingTable.Schema.TableSubType -eq "Classic")
    {
        # Migrate the classic table to DCR-based before updating the schema.
        # This call is idempotent; it has no effect if the table has already been converted.
        Write-Host "    Table $tableName is a classic (Data Collector API) table. Migrating to DCR-based..." -ForegroundColor Yellow
        $migrateUri = "$armEndpoint$workspaceResourceId/tables/$tableName/migrate?api-version=$tableMigrateApiVersion"
        Invoke-AzRestMethod -Method POST -Uri $migrateUri -Payload "{}" | Out-Null
        Write-Host "    Migration completed for $tableName." -ForegroundColor Gray
    }

    # Build the DCR transform KQL.
    # Stream declarations use unsuffixed source fields, while output maps to suffixed table columns.
    # For existing tables whose _g columns are already typed as Guid (created by the legacy Data
    # Collector API), cast those specific outputs with toguid() so the transformed output matches
    # the existing table schema.
    $guidColumnNames = @()
    if ($null -ne $existingTable)
    {
        $guidColumns = @($existingTable.Schema.Columns | Where-Object { $_.Type -eq "Guid" -and $_.Name -in $columns.name })
        if ($guidColumns.Count -gt 0)
        {
            $guidColumnNames = @($guidColumns | ForEach-Object { $_.Name })
            Write-Host "    Existing guid columns detected ($($guidColumns.Count)). Using toguid() transform." -ForegroundColor Gray
        }
    }

    $projectExpressions = @()
    foreach ($col in $columns)
    {
        $destinationName = $col.name
        $sourceName = $destinationToSource[$destinationName]
        if ($destinationName -in $guidColumnNames)
        {
            $projectExpressions += "$destinationName = toguid($sourceName)"
        }
        else
        {
            $projectExpressions += "$destinationName = $sourceName"
        }
    }
    $transformKql = "source | project " + ($projectExpressions -join ", ")

    # Only create/update the table schema for new (non-existing) tables.
    # Existing tables preserve their schema to avoid column type conflicts
    # (e.g. Guid columns cannot be changed to string).
    $tablePath = "/subscriptions/$WorkspaceSubscriptionId/resourceGroups/$WorkspaceResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/$tableName`?api-version=$tableSchemaApiVersion"
    if ($null -eq $existingTable)
    {
        $tableResponse = Invoke-AzRestMethod -Method PUT -Path $tablePath -Payload $tablePayload
        Write-Host "    Table $tableName created with status code $($tableResponse.StatusCode)." -ForegroundColor Gray
        if ($tableResponse.StatusCode -ne 200 -and $tableResponse.StatusCode -ne 201)
        {
            $errorMessage = $tableResponse.Content | ConvertFrom-Json | Select-Object -ExpandProperty error | Select-Object -ExpandProperty message
            throw "    Failed to create table ${tableName}: ${errorMessage}"
        }
    }
    else
    {
        Write-Host "    Table $tableName already exists, skipping schema update." -ForegroundColor Gray
    }
    #endregion

    #region Create DCR for this table
    Write-Host "  [$suffix] Creating DCR $dcrName..." -ForegroundColor Cyan

    $dcrPayload = @{
        location   = $workspaceLocation
        properties = @{
            dataCollectionEndpointId = $dceResourceId
            streamDeclarations       = @{
                $streamName = @{
                    columns = $sourceColumns
                }
            }
            destinations             = @{
                logAnalytics = @(
                    @{
                        workspaceResourceId = $workspaceResourceId
                        name                = "laDest"
                    }
                )
            }
            dataFlows                = @(
                @{
                    streams      = @($streamName)
                    destinations = @("laDest")
                    transformKql = $transformKql
                    outputStream = "Custom-$tableName"
                }
            )
        }
    } | ConvertTo-Json -Depth 10

    # Switch context back to automation account subscription for DCR creation
    if ($WorkspaceSubscriptionId -ne $currentSubscriptionId)
    {
        Set-AzContext -SubscriptionId $currentSubscriptionId | Out-Null
    }

    $dcrUri = "$armEndpoint/subscriptions/$currentSubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/dataCollectionRules/$dcrName`?api-version=$dcrApiVersion"
    $dcrResponse = Invoke-AzRestMethod -Method PUT -Uri $dcrUri -Payload $dcrPayload
    Write-Host "    DCR $dcrName creation request completed with status code $($dcrResponse.StatusCode)." -ForegroundColor Gray
    if ($dcrResponse.StatusCode -ne 200 -and $dcrResponse.StatusCode -ne 201)
    {
        $errorMessage = $dcrResponse.Content | ConvertFrom-Json | Select-Object -ExpandProperty error | Select-Object -ExpandProperty message
        throw "    Failed to create DCR ${dcrName}: ${errorMessage}"
    }
    else
    {
        $dcrResponseContent = $dcrResponse.Content | ConvertFrom-Json
    }
    Write-Host "    DCR $dcrName created." -ForegroundColor Gray
    $dcrImmutableId = $dcrResponseContent.properties.immutableId
    $dcrSuffixToImmutableId[$suffix] = $dcrImmutableId
    Write-Host "    DCR immutable ID: $dcrImmutableId" -ForegroundColor Gray

    # Switch back to workspace subscription if needed for subsequent table operations
    if ($WorkspaceSubscriptionId -ne $currentSubscriptionId)
    {
        Set-AzContext -SubscriptionId $WorkspaceSubscriptionId | Out-Null
    }
    #endregion

}
#endregion

#region Restore context to current subscription
if ($WorkspaceSubscriptionId -ne $currentSubscriptionId)
{
    Set-AzContext -SubscriptionId $currentSubscriptionId | Out-Null
}
#endregion

#region Update LogAnalyticsIngestControl SQL table with DCR immutable IDs
Write-Host "Updating SQL LogAnalyticsIngestControl with DCR immutable IDs..." -ForegroundColor Green

$cloudDetails = Get-AzEnvironment -Name $CloudEnvironment
$azureSqlDomain = $cloudDetails.SqlDatabaseDnsSuffix.Substring(1)
$sqlToken = (Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/" -AsSecureString).Token | ConvertFrom-SecureString -AsPlainText

$sqlConnectionString = "Server=tcp:$SqlServerName,1433;Database=$SqlDatabaseName;Encrypt=True;Connection Timeout=120;"

try
{
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = $sqlConnectionString
    $sqlConnection.AccessToken = $sqlToken
    $sqlConnection.Open()

    foreach ($container in $containerSuffixMap.Keys)
    {
        $suffix = $containerSuffixMap[$container]
        if ($dcrSuffixToImmutableId.ContainsKey($suffix))
        {
            $immutableId = $dcrSuffixToImmutableId[$suffix]
            $sqlCommand = $sqlConnection.CreateCommand()
            $sqlCommand.CommandText = "UPDATE [dbo].[LogAnalyticsIngestControl] SET DCRImmutableId = @id WHERE StorageContainerName = @container"
            $sqlCommand.Parameters.AddWithValue("@id", $immutableId) | Out-Null
            $sqlCommand.Parameters.AddWithValue("@container", $container) | Out-Null
            $sqlCommand.ExecuteNonQuery() | Out-Null
        }
    }

    # Update the SuppressionsV1 DCR immutable ID (not in container map, keyed directly)
    if ($dcrSuffixToImmutableId.ContainsKey("SuppressionsV1"))
    {
        # Suppressions are not blob-based; store the immutable ID under a placeholder container name
        $suppImmutableId = $dcrSuffixToImmutableId["SuppressionsV1"]
        $sqlCommand = $sqlConnection.CreateCommand()
        $sqlCommand.CommandText = @"
IF NOT EXISTS (select 1 FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'suppressions')
BEGIN
INSERT INTO [dbo].[LogAnalyticsIngestControl] (StorageContainerName, LastProcessedDateTime, LastProcessedLine, LogAnalyticsSuffix, CollectedType, DCRImmutableId)
VALUES ('suppressions', '1901-01-01T00:00:00Z', -1, 'SuppressionsV1', 'Suppressions', @id)
END
ELSE
BEGIN
UPDATE [dbo].[LogAnalyticsIngestControl] SET DCRImmutableId = @id WHERE StorageContainerName = 'suppressions'
END
"@
        $sqlCommand.Parameters.AddWithValue("@id", $suppImmutableId) | Out-Null
        $sqlCommand.ExecuteNonQuery() | Out-Null
    }

    $sqlConnection.Close()
    Write-Host "SQL update completed." -ForegroundColor Green
}
catch
{
    Write-Host "Could not update SQL control table: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "You may need to update the DCRImmutableId column manually or ensure the managed identity has db_datareader/db_datawriter access." -ForegroundColor Yellow
}
#endregion

#region Remove the legacy workspace shared key automation variable
Write-Host "Removing legacy AzureOptimization_LogAnalyticsWorkspaceKey automation variable..." -ForegroundColor Green
$keyVar = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName `
    -Name "AzureOptimization_LogAnalyticsWorkspaceKey" -ErrorAction SilentlyContinue
if ($null -ne $keyVar)
{
    Remove-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName `
        -Name "AzureOptimization_LogAnalyticsWorkspaceKey"
    Write-Host "Legacy workspace key variable removed." -ForegroundColor Green
}
else
{
    Write-Host "Variable already absent." -ForegroundColor Gray
}
#endregion

Write-Host "Setup-LogAnalyticsTablesAndDCRs completed successfully." -ForegroundColor Green
Write-Host "  Tables created: $($tableSchemas.Keys.Count)" -ForegroundColor Green
Write-Host "  DCRs created/updated: $($dcrSuffixToImmutableId.Keys.Count)" -ForegroundColor Green
