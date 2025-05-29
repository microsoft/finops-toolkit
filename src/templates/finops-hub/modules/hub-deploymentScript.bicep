// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { getPublisherTags } from 'hub-types.bicep'

type EnvironmentVariable = {
  name: string
  value: string
}


//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the managed identity to create.')
param identityName string

@description('Optional. Name of the deployment script to create. Default = (same as deployment).')
param scriptName string = deployment().name

@description('Required. Name of the deployment script to create.')
param scriptContent string

@description('Optional. Additional arguments to pass into the deployment script.')
param arguments string = ''

@description('Optional. Environment variables to use for the deployment script.')
param environmentVariables EnvironmentVariable[] = []

//------------------------------------------------------------------------------
// Hub context
//------------------------------------------------------------------------------

@description('Optional. Azure location where all resources should be created. See https://aka.ms/azureregions. Default: (resource group location).')
param location string = resourceGroup().location

@description('Optional. Tags to apply to all resources.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Required. Indicates whether public access should be enabled.')
param enablePublicAccess bool

@description('Optional. The name of the storage account used for deployment scripts. Required when using private endpoints and uploading files or creating an identity.')
param scriptStorageAccountName string = ''

@description('Optional. Resource ID of the virtual network for running deployment scripts. Required when using private endpoints and uploading files.')
param scriptSubnetId string = ''


//==============================================================================
// Variables
//==============================================================================

// See https://learn.microsoft.com/azure/azure-resource-manager/templates/deployment-script-template#use-existing-storage-account
var privateEndpointDeploymentRoles = enablePublicAccess ? [] : [
  '69566ab7-960f-475b-8e7c-b3118f30c6bd' // Storage File Data Privileged Contributor - https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/storage#storage-file-data-privileged-contributor
]
var privateEndpointDeploymentProperties = enablePublicAccess ? {} : {
  storageAccountSettings: {
    storageAccountName: scriptStorageAccountName
  }
  containerSettings: {
    containerGroupName: '${scriptStorageAccountName}cg'
    subnetIds: [
      {
        id: scriptSubnetId
      }
    ]
  }
}


//==============================================================================
// Resources
//==============================================================================

//------------------------------------------------------------------------------
// Create identity to run deployment scripts
//------------------------------------------------------------------------------

// Create managed identity to run deployment scripts
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  tags: union(tags, tagsByResource[?'Microsoft.ManagedIdentity/userAssignedIdentities'] ?? {})
  location: location
}

// Get script storage account for private endpoint deployment scripts
resource scriptStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing =  if (!enablePublicAccess) {
  name: scriptStorageAccountName
}

// Assign the identity access to the script storage account
resource identityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in privateEndpointDeploymentRoles: if (!enablePublicAccess) {
  name: guid(role, identity.id)
  scope: scriptStorageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]


//------------------------------------------------------------------------------
// Upload schema file to storage
//------------------------------------------------------------------------------

// TODO: Move to hub-deploymentScript.bicep
resource script 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: scriptName
  dependsOn: [
    identityRoleAssignments
  ]
  kind: 'AzurePowerShell'
  // chinaeast2 is the only region in China that supports deployment scripts
  location: startsWith(location, 'china') ? 'chinaeast2' : location  // cSpell:ignore chinaeast
  tags: union(tags, tagsByResource[?'Microsoft.Resources/deploymentScripts'] ?? {})
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    ...privateEndpointDeploymentProperties
    azPowerShellVersion: '9.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    scriptContent: scriptContent
    arguments: arguments
    environmentVariables: environmentVariables
  }
}


//==============================================================================
// Outputs
//==============================================================================

// None
