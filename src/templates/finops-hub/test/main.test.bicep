// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

targetScope = 'resourceGroup'

param uniqueName string = 'ftk-hub-localtest1'
param location string = 'westus2'

// Test 1 - Creates a FinOps hub instance with default settings (auto-generated names).
module hubDefault '../main.bicep' = {
  name: 'finops-hub-default'
  params: {
    hubName: uniqueName
    location: location
  }
}

// Test 2 - Creates a FinOps hub instance with custom resource names.
module hubCustomNames '../main.bicep' = {
  name: 'finops-hub-custom-names'
  params: {
    hubName: '${uniqueName}-custom'
    location: location
    storageAccountName: 'ftkstgcustom${uniqueString(resourceGroup().id)}'
    dataFactoryName: 'ftk-df-custom-${uniqueString(resourceGroup().id)}'
    keyVaultName: 'ftk-kv-${uniqueString(resourceGroup().id)}'
    virtualNetworkName: 'ftk-vnet-custom'
    managedIdentityName: 'ftk-id-custom'
    dataExplorerClusterName: 'ftkadxcustom${uniqueString(resourceGroup().id)}'
    privateEndpointNamePrefix: 'ftk-pe-custom'
  }
}

// Test 3 - Creates a FinOps hub instance with existing DNS Zones (Hub & Spoke scenario).
// Note: This test assumes DNS Zones already exist. In a real scenario, you would provide actual resource IDs.
module hubExistingDns '../main.bicep' = {
  name: 'finops-hub-existing-dns'
  params: {
    hubName: '${uniqueName}-hubspoke'
    location: location
    // Uncomment and provide actual DNS Zone resource IDs when testing in a Hub & Spoke environment
    // existingBlobDnsZoneId: '/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
    // existingDfsDnsZoneId: '/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/privateDnsZones/privatelink.dfs.core.windows.net'
    // existingQueueDnsZoneId: '/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net'
    // existingTableDnsZoneId: '/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net'
    // existingVaultDnsZoneId: '/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
    // existingDataExplorerDnsZoneId: '/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/privateDnsZones/privatelink.{region}.kusto.windows.net'
  }
}

// Test 4 - Creates a FinOps hub instance combining custom names and existing DNS Zones.
module hubFullCustom '../main.bicep' = {
  name: 'finops-hub-full-custom'
  params: {
    hubName: '${uniqueName}-full'
    location: location
    storageAccountName: 'ftkstgfull${uniqueString(resourceGroup().id)}'
    dataFactoryName: 'ftk-df-full-${uniqueString(resourceGroup().id)}'
    keyVaultName: 'ftk-kv-full-${uniqueString(resourceGroup().id)}'
    virtualNetworkName: 'ftk-vnet-full'
    managedIdentityName: 'ftk-id-full'
    privateEndpointNamePrefix: 'ftk-pe-full'
    // Note: DNS Zone IDs would be provided in real Hub & Spoke scenarios
  }
}

output defaultHubName string = hubDefault.outputs.name
output customNamesHubName string = hubCustomNames.outputs.name
output existingDnsHubName string = hubExistingDns.outputs.name
output fullCustomHubName string = hubFullCustom.outputs.name
