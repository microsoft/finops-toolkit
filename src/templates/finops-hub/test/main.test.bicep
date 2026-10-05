// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

targetScope = 'resourceGroup'

param uniqueName string = 'ftk-hub-localtest1'
param location string = 'westus2'

// Test 1 - Creates a FinOps hub instance with default settings.
module hub '../main.bicep' = {
  name: 'finops-hub'
  params: {
    hubName: uniqueName
    location: location
  }
}

// Test 2 - Creates a FinOps hub with Azure Data Explorer encryption enabled.
module hubWithAdxEncryption '../main.bicep' = {
  name: 'finops-hub-adx-encryption'
  params: {
    hubName: '${uniqueName}-adx'
    location: location
    dataExplorerName: '${uniqueName}-adx'
    enableAdxDiskEncryption: true
    enableAdxDoubleEncryption: true
  }
}

output hubName string = hub.outputs.name
