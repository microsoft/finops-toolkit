// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

targetScope = 'subscription'

// Test 1 - Enables tag inheritance.
module enable '../main.bicep' = {
  name: 'enable'
  params: {
    enabled: true
  }
}

// Test 2 - Enables tag inheritance where subscription and resource group tags override resource tags.
module preferSubOrRGTags '../main.bicep' = {
  name: 'preferSubOrRGTags'
  params: {
    enabled: true
    preferContainerTags: true
  }
}

// Test 3 - Disables tag inheritance.
module disable '../main.bicep' = {
  name: 'disable'
  params: {
    enabled: false
  }
}

output enabled bool = enable.outputs.enabled
output preferSubOrRGTags bool = preferSubOrRGTags.outputs.preferContainerTags
output disabled bool = disable.outputs.enabled
