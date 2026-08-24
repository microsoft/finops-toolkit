// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

targetScope = 'resourceGroup'

param uniqueName string = 'ftk-hub-localtest1'
param location string = 'westus2'

// Test 1 - Creates a FinOps hub instance with recommendations and quota disabled.
module hub '../main.bicep' = {
  name: 'finops-hub'
  params: {
    hubName: uniqueName
    location: location
  }
}

// Test 2 - Creates a FinOps hub instance with recommendations enabled.
module hubRecommendations '../main.bicep' = {
  name: 'finops-hub-recommendations'
  params: {
    hubName: '${uniqueName}-recommendations'
    location: location
    enableRecommendations: true
  }
}

// Test 3 - Creates a FinOps hub instance with quota enabled.
module hubQuota '../main.bicep' = {
  name: 'finops-hub-quota'
  params: {
    hubName: '${uniqueName}-quota'
    location: location
    enableQuota: true
  }
}

// Test 4 - Creates a FinOps hub instance with recommendations and quota enabled.
module hubRecommendationsAndQuota '../main.bicep' = {
  name: 'finops-hub-recommendations-quota'
  params: {
    hubName: '${uniqueName}-recommendations-quota'
    location: location
    enableRecommendations: true
    enableQuota: true
  }
}

output hubName string = hub.outputs.name
