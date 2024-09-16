// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

targetScope = 'resourceGroup'

@description('Optional. Name of the hub. Used to ensure unique resource names. Default: "finops-hub".')
param hubName string

@description('Optional. Azure location where all resources should be created. See https://aka.ms/azureregions. Default: Same as deployment.')
param location string = resourceGroup().location

@description('Optional. Azure location to use for a temporary Event Grid namespace to register the Microsoft.EventGrid resource provider if the primary location is not supported. The namespace will be deleted and is not used for hub operation. Default: "" (same as location).')
param eventGridLocation string = ''

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
@description('Optional. Storage SKU to use. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Allowed: Premium_LRS, Premium_ZRS. Default: Premium_LRS.')
param storageSku string = 'Premium_LRS'

@description('Optional. Name of the Azure Data Explorer cluster to use for advanced analytics. If empty, Azure Data Explorer will not be deployed. Required to use with Power BI if you have more than $2-5M/mo in costs being monitored. Default: "" (do not use).')
param dataExplorerName string = ''

@description('Optional. Name of the Azure Data Explorer SKU. Default: "Standard_E2ads_v5".')
param dataExplorerSkuName string = 'Standard_E2ads_v5'

@description('Optional. SKU tier for the Azure Data Explorer cluster. Allowed values: Basic, Standard. Default: "Standard".')
@allowed(['Basic', 'Standard'])
param dataExplorerSkuTier string = 'Standard'

@description('Optional. Number of nodes to use in the cluster. Allowed values: 2-1000. Default: 2.')
@minValue(2)
@maxValue(1000)
param dataExplorerSkuCapacity int = 2

@description('Optional. Tags to apply to all resources. We will also add the cm-resource-parent tag for improved cost roll-ups in Cost Management.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Optional. List of scope IDs to monitor and ingest cost for.')
param scopesToMonitor array = []

@description('Optional. Number of days of cost data to retain in the ms-cm-exports container. Default: 0.')
param exportRetentionInDays int = 0

@description('Optional. Number of months of cost data to retain in the ingestion container. Default: 13.')
param ingestionRetentionInMonths int = 13

@description('Optional. Storage account to push data to for ingestion into a remote hub.')
param remoteHubStorageUri string = ''

@description('Optional. Storage account key to use when pushing data to a remote hub.')
@secure()
param remoteHubStorageKey string = ''

//==============================================================================
// Resources
//==============================================================================

module hub 'modules/hub.bicep' = {
  name: 'hub'
  params: {
    hubName: hubName
    location: location
    eventGridLocation: eventGridLocation
    storageSku: storageSku
    dataExplorerName: dataExplorerName
    dataExplorerSkuName: dataExplorerSkuName
    dataExplorerSkuTier: dataExplorerSkuTier
    dataExplorerSkuCapacity: dataExplorerSkuCapacity
    tags: tags
    tagsByResource: tagsByResource
    scopesToMonitor: scopesToMonitor
    exportRetentionInDays: exportRetentionInDays
    ingestionRetentionInMonths: ingestionRetentionInMonths
    remoteHubStorageUri: remoteHubStorageUri
    remoteHubStorageKey: remoteHubStorageKey
  }
}

//==============================================================================
// Outputs
//==============================================================================

@description('The name of the resource group.')
output name string = hubName

@description('The location the resources wer deployed to.')
output location string = location

@description('Name of the Data Factory.')
output dataFactorytName string = hub.outputs.dataFactorytName

@description('The resource ID of the deployed storage account.')
output storageAccountId string = hub.outputs.storageAccountId

@description('Name of the storage account created for the hub instance. This must be used when connecting FinOps toolkit Power BI reports to your data.')
output storageAccountName string = hub.outputs.storageAccountName

@description('URL to use when connecting custom Power BI reports to your data.')
output storageUrlForPowerBI string = hub.outputs.storageUrlForPowerBI

@description('The resource ID of the Data Explorer cluster.')
output clusterId string = hub.outputs.clusterId

@description('The URI of the Data Explorer cluster.')
output clusterUri string = hub.outputs.clusterUri

@description('The name of the Data Explorer ingestion database.')
output ingestionDbName string = hub.outputs.ingestionDbName

@description('The name of the Data Explorer hub database.')
output hubDbName string = hub.outputs.hubDbName

@description('Object ID of the Data Factory managed identity. This will be needed when configuring managed exports.')
output managedIdentityId string = hub.outputs.managedIdentityId

@description('Azure AD tenant ID. This will be needed when configuring managed exports.')
output managedIdentityTenantId string = hub.outputs.managedIdentityTenantId
