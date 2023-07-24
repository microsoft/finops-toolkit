// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

// See https://learn.microsoft.com/rest/api/cost-management/settings/create-or-update-by-scope

targetScope = 'subscription'

//==============================================================================
// Parameters
//==============================================================================

@description('Optional. Indicates whether tag inheritance should be enabled. Default = true.')
param enabled bool = true

@description('Optional. Indicates whether resource tag values should be overridden by the subscription or resource group tag value, if one is specified. Default = false.')
param preferContainerTags bool = false

//==============================================================================
// Resources
//==============================================================================

resource tagInheritance 'Microsoft.CostManagement/settings@2022-10-01-preview' = {
  name: 'taginheritance'
  kind: 'taginheritance'
  properties: enabled ? {
    preferContainerTags: preferContainerTags
  } : {}
}

//===| Outputs |===============================================================

@description('Indicates whether tag inheritance was enabled.')
output enabled bool = enabled

@description('Indicates whether resource tag values should be overridden by the subscription or resource group tag value, if one is specified.')
output preferContainerTags bool = tagInheritance.properties.preferContainerTags
