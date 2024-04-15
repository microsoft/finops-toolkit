//==============================================================================
// Parameters
//==============================================================================

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Resource tags.')
param tags object = {}

@description('Optional. Forces the table to be updated if different from the last time it was deployed.')
param forceUpdateTag string = utcNow()

@description('Optional. If true, ingestion will continue even if some rows fail to ingest.')
param continueOnErrors bool = false

@description('Required. Name of the storage account to use for the cluster data ingestion.')
param storageAccountName string

@description('Name of the cluster')
param clusterName string = 'kusto${uniqueString(resourceGroup().id)}'

@description('Optional. Name of the SKU. Default = "Standard_E2ads_v5".')
param skuName string = 'Standard_E2ads_v5'

@description('Optional. Number of nodes to use in the cluster. Default = 2.')
@minValue(2)
@maxValue(1000)
param skuCapacity int = 2

@description('Optional. Name of the database. Default = "finopsdb".')
param databaseName string = 'finopsdb'

@description('Optional. Name of storage account. Default = "ingestion".')
param storageContainerName string = 'ingestion'

// TODO: Revisit name
@description('Optional. Name of the Event Grid topic used to monitor for ingestion changes. Default = "adxingest-topic".')
param eventGridTopicName string = 'adxingest-topic'

@description('Name of Event Hub\'s namespace')
param eventHubNamespaceName string = 'eventHub${uniqueString(resourceGroup().id)}'

// TODO: Align name to the hub
@description('Optional. Name of the Event Hub instance. Default = "storageHub".')
param eventHubName string = 'storageHub'

// TODO: Revisit name
@description('Optional. Name of the Event Grid subscription. Default = "toEventHub".')
param eventGridSubscriptionName string = 'toEventHub'

//==============================================================================
// Resources
//==============================================================================

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName

  resource blobServices 'blobServices' = {
    name: 'default'

    resource landingContainer 'containers' = {
      name: storageContainerName
    }
  }
}

//  Event hub receiving event grid notifications
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: eventHubNamespaceName
  location: location
  tags: tags
  sku: {
    capacity: 1
    // TODO: Move to a parameter
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {}

  resource eventHub 'eventhubs' = {
    name: eventHubName
    properties: {
      messageRetentionInDays: 2
      partitionCount: 2
    }

    resource kustoConsumerGroup 'consumergroups' = {
      // TODO: Revisit name
      name: 'kustoConsumerGroup'
      properties: {}
    }
  }
}

//  Here we setup an event grid topic and a subscription sending events to event hub

//  Event grid topic on storage account
resource blobTopic 'Microsoft.EventGrid/systemTopics@2023-12-15-preview' = {
  name: eventGridTopicName
  location: location
  tags: tags
  identity: {
    //  We give an identity to the Event Grid so we can give it permission to write into Event Hub
    type: 'SystemAssigned'
  }
  properties: {
    source: storage.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }

  //  Event Grid subscription, pushing events to event hub
  resource newBlobSubscription 'eventSubscriptions' = {
    name: eventGridSubscriptionName
    properties: {
      deliveryWithResourceIdentity: {
        destination: {
          endpointType: 'EventHub'
          properties: {
            resourceId: eventHubNamespace::eventHub.id
          }
        }
        identity: {
          type: 'SystemAssigned'
        }
      }
      eventDeliverySchema: 'EventGridSchema'
      filter: {
        subjectBeginsWith: '/blobServices/default/containers/${storage::blobServices::landingContainer.name}'
        includedEventTypes: [
          'Microsoft.Storage.BlobCreated'
        ]
        enableAdvancedFilteringOnArrays: true
      }
      retryPolicy: {
        maxDeliveryAttempts: 30
        eventTimeToLiveInMinutes: 1440
      }
    }
  }
}

//  Authorize topic to send to Event Hub
resource topicEventHubRbacAuthorization 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(blobTopic.id, eventHubNamespace::eventHub.id, 'rbac')
  scope: eventHubNamespace::eventHub

  properties: {
    description: 'Azure Event Hubs Data Sender'
    principalId: blobTopic.identity.principalId
    principalType: 'ServicePrincipal'
    //  See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#analytics for built-in roles
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '2b629674-e913-4c01-ae53-ef4638d8f975')
  }
}

//  Kusto cluster
resource cluster 'Microsoft.Kusto/clusters@2023-08-15' = {
  name: clusterName
  location: location
  // TODO: Do we need to merge tagsByResource or is that handled before this bicep file?
  tags: tags
  sku: {
    name: skuName
    tier: 'Standard'
    capacity: skuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enableStreamingIngest: true
  }

  resource kustoDb 'databases' = {
    name: databaseName
    location: location
    kind: 'ReadWrite'

    resource kustoScript 'scripts' = {
      name: 'db-script'
      properties: {
        scriptContent: loadTextContent('adxTableSchema.kql')
        continueOnErrors: continueOnErrors
        forceUpdateTag: forceUpdateTag
      }
    }

    resource eventConnection 'dataConnections' = {
      name: 'eventConnection'
      location: location
      dependsOn: [
        kustoScript
        clusterEventHubAuthorization
      ]
      kind: 'EventGrid'
      properties: {
        blobStorageEventType: 'Microsoft.Storage.BlobCreated'
        consumerGroup: eventHubNamespace::eventHub::kustoConsumerGroup.name
        dataFormat: 'parquet'
        eventGridResourceId: blobTopic::newBlobSubscription.id
        eventHubResourceId: eventHubNamespace::eventHub.id
        ignoreFirstRecord: false
        managedIdentityResourceId: cluster.id
        storageAccountResourceId: storage.id
        tableName: 'Focus'
      }
    }
  }
}

//  Authorize Kusto Cluster to receive event from Event Hub
resource clusterEventHubAuthorization 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cluster.name, eventHubName, 'Azure Event Hubs Data Receiver')
  //  See https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/scope-extension-resources
  //  for scope for extension
  scope: eventHubNamespace::eventHub
  properties: {
    description: 'Give "Azure Event Hubs Data Receiver" to the cluster'
    principalId: cluster.identity.principalId
    //  Required in case principal not ready when deploying the assignment
    principalType: 'ServicePrincipal'
    //  See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#analytics for built-in roles
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'
    )
  }
}

//  Authorize Kusto Cluster to read storage
resource clusterStorageAuthorization 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cluster.name, storageContainerName, 'Storage Blob Data Contributor')
  //  See https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/scope-extension-resources
  //  for scope for extension
  scope: storage::blobServices
  properties: {
    description: 'Give "Storage Blob Data Contributor" to the cluster'
    principalId: cluster.identity.principalId
    //  Required in case principal not ready when deploying the assignment
    principalType: 'ServicePrincipal'
    //  See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage for built-in roles
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    )
  }
}

//==============================================================================
// Outputs
//==============================================================================

@description('The resource ID of the cluster.')
output clusterId string = cluster.id

@description('The name of the cluster.')
output clusterName string = cluster.name

@description('The URI of the cluster.')
output clusterUri string = cluster.properties.uri

@description('The name of the cluster database.')
output clusterDbName string = databaseName
