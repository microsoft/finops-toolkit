//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the FinOps hub instance. Used to ensure unique resource names.')
param hubName string

@description('Required. Suffix to add to the storage account name to ensure uniqueness.')
@minLength(6) // Min length requirement is to avoid a false positive warning
param uniqueSuffix string

@description('Required. Name to use for the Azure Data Explorer cluster. This name must be unique within the region.')
param clusterName string

@description('Optional. Name of the Azure Data Explorer SKU. Default: "Standard_E2ads_v5".')
param clusterSkuName string = 'Standard_E2ads_v5'

@description('Optional. SKU tier for the Azure Data Explorer cluster. Allowed values: Basic, Standard. Default: "Standard".')
@allowed(['Basic', 'Standard'])
param clusterSkuTier string = 'Standard'

@description('Optional. Number of nodes to use in the cluster. Allowed values: 2-1000. Default: 2.')
@minValue(2)
@maxValue(1000)
param clusterSkuCapacity int = 2

// TODO: Is this needed?
@description('Optional. Forces the table to be updated if different from the last time it was deployed.')
param forceUpdateTag string = utcNow()

@description('Optional. If true, ingestion will continue even if some rows fail to ingest. Default: false.')
param continueOnErrors bool = false

@description('Optional. Azure location to use for the managed identity and deployment script to auto-start triggers. Default: (resource group location).')
param location string = resourceGroup().location

@description('Optional. Azure location to use for Event Grid topics used for Azure Data Explorer ingestion if the primary location is not supported. Default: "" (same as location).')
param eventGridLocation string = resourceGroup().location

@description('Optional. Tags to apply to all resources.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Required. Name of the storage account to use for data ingestion.')
param storageAccountName string

@description('Required. Name of storage container to monitor for data ingestion.')
param storageContainerName string

@description('Optional. SKU to use for the Event Hubs instance used to trigger data ingestion in Azure Data Explorer. Allowed values: Standard, Premium. Default: Standard.')
@allowed(['Standard', 'Premium'])
param eventHubSku string = 'Standard'

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

// Generate event grid topic name: 3-50 chars; letters/numbers/hyphens only -- https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsofteventgrid
var eventGridTopicName = replace('${take('${replace(hubName, '_', '-')}-storage-events', 49 - length(uniqueSuffix))}-${uniqueSuffix}', '--', '-')

// Generate event hub namespace name: 6-50 chars; letters/numbers/hyphens only -- https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsofteventhub
var eventHubNamespaceName = '${take('${replace(hubName, '_', '')}-adx-ingestion', 49 - length(uniqueSuffix))}-${uniqueSuffix}'

//==============================================================================
// Resources
//==============================================================================

//------------------------------------------------------------------------------
// Dependencies
//------------------------------------------------------------------------------

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
  resource blobServices 'blobServices' = {
    name: 'default'
    resource ingestionContainer 'containers' = {
      name: storageContainerName
    }
  }
}

//------------------------------------------------------------------------------
// Event Hub for ingestion
//------------------------------------------------------------------------------

// Event hub receiving event grid notifications
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: eventHubNamespaceName
  location: location
  tags: union(tags, contains(tagsByResource, 'Microsoft.EventHub/namespaces') ? tagsByResource['Microsoft.EventHub/namespaces'] : {})
  sku: {
    capacity: 1
    name: eventHubSku
    tier: eventHubSku
  }
  properties: {}

  resource storageIngestionEventHub 'eventhubs' = {
    name: 'StorageIngestion'
    properties: {
      messageRetentionInDays: 2
      partitionCount: 2
    }

    resource costConsumerGroup 'consumergroups' = {
      name: 'FocusCost'
      properties: {}
    }
    resource pricesConsumerGroup 'consumergroups' = {
      name: 'PriceSheet'
      properties: {}
    }
    resource recommendationsConsumerGroup 'consumergroups' = {
      name: 'Recommendations'
      properties: {}
    }
    resource resvDetailsConsumerGroup 'consumergroups' = {
      name: 'ReservationDetails'
      properties: {}
    }
    resource resvRecommendationsConsumerGroup 'consumergroups' = {
      name: 'ReservationRecommendations'
      properties: {}
    }
    resource resvTransactionsConsumerGroup 'consumergroups' = {
      name: 'ReservationTransactions'
      properties: {}
    }
  }
}

// Here we setup an event grid topic and a subscription sending events to event hub

// Event grid topic on storage account
resource ingestionTopic 'Microsoft.EventGrid/systemTopics@2023-12-15-preview' = {
  name: eventGridTopicName
  location: eventGridLocation
  tags: union(tags, contains(tagsByResource, 'Microsoft.EventGrid/systemTopics') ? tagsByResource['Microsoft.EventGrid/systemTopics'] : {})
  identity: {
    // We give an identity to the Event Grid so we can give it permission to write into Event Hub
    type: 'SystemAssigned'
  }
  properties: {
    source: storage.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }

  resource ingestFocusCostEvent 'eventSubscriptions' = {
    name: 'IngestFocusCost'
    properties: {
      deliveryWithResourceIdentity: {
        destination: {
          endpointType: 'EventHub'
          properties: {
            resourceId: eventHubNamespace::storageIngestionEventHub.id
          }
        }
        identity: {
          type: 'SystemAssigned'
        }
      }
      eventDeliverySchema: 'EventGridSchema'
      filter: {
        subjectBeginsWith: '/blobServices/default/containers/${storage::blobServices::ingestionContainer.name}/blobs/focuscost/'
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

  resource ingestPriceSheetEvent 'eventSubscriptions' = {
    name: 'IngestPriceSheet'
    properties: {
      deliveryWithResourceIdentity: {
        destination: {
          endpointType: 'EventHub'
          properties: {
            resourceId: eventHubNamespace::storageIngestionEventHub.id
          }
        }
        identity: {
          type: 'SystemAssigned'
        }
      }
      eventDeliverySchema: 'EventGridSchema'
      filter: {
        subjectBeginsWith: '/blobServices/default/containers/${storage::blobServices::ingestionContainer.name}/blobs/pricesheet/'
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

  resource ingestRecommendationsEvent 'eventSubscriptions' = {
    name: 'IngestRecommendations'
    properties: {
      deliveryWithResourceIdentity: {
        destination: {
          endpointType: 'EventHub'
          properties: {
            resourceId: eventHubNamespace::storageIngestionEventHub.id
          }
        }
        identity: {
          type: 'SystemAssigned'
        }
      }
      eventDeliverySchema: 'EventGridSchema'
      filter: {
        subjectBeginsWith: '/blobServices/default/containers/${storage::blobServices::ingestionContainer.name}/blobs/recommendations/'
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

  resource ingestReservationDetailsEvent 'eventSubscriptions' = {
    name: 'IngestReservationDetails'
    properties: {
      deliveryWithResourceIdentity: {
        destination: {
          endpointType: 'EventHub'
          properties: {
            resourceId: eventHubNamespace::storageIngestionEventHub.id
          }
        }
        identity: {
          type: 'SystemAssigned'
        }
      }
      eventDeliverySchema: 'EventGridSchema'
      filter: {
        subjectBeginsWith: '/blobServices/default/containers/${storage::blobServices::ingestionContainer.name}/blobs/reservationdetails/'
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

  resource ingestReservationRecommendationsEvent 'eventSubscriptions' = {
    name: 'IngestReservationRecommendations'
    properties: {
      deliveryWithResourceIdentity: {
        destination: {
          endpointType: 'EventHub'
          properties: {
            resourceId: eventHubNamespace::storageIngestionEventHub.id
          }
        }
        identity: {
          type: 'SystemAssigned'
        }
      }
      eventDeliverySchema: 'EventGridSchema'
      filter: {
        subjectBeginsWith: '/blobServices/default/containers/${storage::blobServices::ingestionContainer.name}/blobs/reservationrecommendations/'
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

  resource ingestReservationTransactionsEvent 'eventSubscriptions' = {
    name: 'IngestReservationTransactions'
    properties: {
      deliveryWithResourceIdentity: {
        destination: {
          endpointType: 'EventHub'
          properties: {
            resourceId: eventHubNamespace::storageIngestionEventHub.id
          }
        }
        identity: {
          type: 'SystemAssigned'
        }
      }
      eventDeliverySchema: 'EventGridSchema'
      filter: {
        subjectBeginsWith: '/blobServices/default/containers/${storage::blobServices::ingestionContainer.name}/blobs/reservationtransactions/'
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

// Authorize topic to send to Event Hub
resource ingestionTopicAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(ingestionTopic.id, eventHubNamespace::storageIngestionEventHub.id, 'rbac')
  scope: eventHubNamespace::storageIngestionEventHub
  properties: {
    description: 'Azure Event Hubs data sender'
    principalId: ingestionTopic.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '2b629674-e913-4c01-ae53-ef4638d8f975') // Event Hubs Data Sender role -- https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#analytics
  }
}

//------------------------------------------------------------------------------
// Cluster + databases
//------------------------------------------------------------------------------

resource cluster 'Microsoft.Kusto/clusters@2023-08-15' = {
  name: clusterName
  location: location
  tags: union(tags, contains(tagsByResource, 'Microsoft.Kusto/clusters') ? tagsByResource['Microsoft.Kusto/clusters'] : {})
  sku: {
    name: clusterSkuName
    tier: clusterSkuTier
    capacity: clusterSkuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enableStreamingIngest: true
  }

  resource ingestionDb 'databases' = {
    name: 'ingestion'
    location: location
    kind: 'ReadWrite'

    resource ingestionSetupScript 'scripts' = {
      name: 'SetupScript'
      properties: {
        scriptContent: loadTextContent('scripts/IngestionSetup.kql')
        continueOnErrors: continueOnErrors
        forceUpdateTag: forceUpdateTag
      }
    }

    resource ingestFocusCostConnection 'dataConnections' = {
      name: 'FocusCostIngestion'
      location: location
      dependsOn: [
        ingestionSetupScript
        clusterEventHubAccess
      ]
      kind: 'EventGrid'
      properties: {
        blobStorageEventType: 'Microsoft.Storage.BlobCreated'
        consumerGroup: eventHubNamespace::storageIngestionEventHub::costConsumerGroup.name
        dataFormat: 'parquet'
        eventGridResourceId: ingestionTopic::ingestFocusCostEvent.id
        eventHubResourceId: eventHubNamespace::storageIngestionEventHub.id
        ignoreFirstRecord: false
        managedIdentityResourceId: cluster.id
        storageAccountResourceId: storage.id
        tableName: 'FocusCost_raw'
      }
    }

    resource ingestPriceSheetConnection 'dataConnections' = {
      name: 'PriceSheetIngestion'
      location: location
      dependsOn: [
        ingestionSetupScript
        clusterEventHubAccess
      ]
      kind: 'EventGrid'
      properties: {
        blobStorageEventType: 'Microsoft.Storage.BlobCreated'
        consumerGroup: eventHubNamespace::storageIngestionEventHub::pricesConsumerGroup.name
        dataFormat: 'parquet'
        eventGridResourceId: ingestionTopic::ingestPriceSheetEvent.id
        eventHubResourceId: eventHubNamespace::storageIngestionEventHub.id
        ignoreFirstRecord: false
        managedIdentityResourceId: cluster.id
        storageAccountResourceId: storage.id
        tableName: 'PriceSheet_raw'
      }
    }

    resource ingestRecommendationsConnection 'dataConnections' = {
      name: 'RecommendationsIngestion'
      location: location
      dependsOn: [
        ingestionSetupScript
        clusterEventHubAccess
      ]
      kind: 'EventGrid'
      properties: {
        blobStorageEventType: 'Microsoft.Storage.BlobCreated'
        consumerGroup: eventHubNamespace::storageIngestionEventHub::recommendationsConsumerGroup.name
        dataFormat: 'json'
        eventGridResourceId: ingestionTopic::ingestRecommendationsEvent.id
        eventHubResourceId: eventHubNamespace::storageIngestionEventHub.id
        ignoreFirstRecord: false
        managedIdentityResourceId: cluster.id
        storageAccountResourceId: storage.id
        tableName: 'Recommendations_raw'
      }
    }

    resource ingestReservationDetailsConnection 'dataConnections' = {
      name: 'ReservationDetailsIngestion'
      location: location
      dependsOn: [
        ingestionSetupScript
        clusterEventHubAccess
      ]
      kind: 'EventGrid'
      properties: {
        blobStorageEventType: 'Microsoft.Storage.BlobCreated'
        consumerGroup: eventHubNamespace::storageIngestionEventHub::resvDetailsConsumerGroup.name
        dataFormat: 'parquet'
        eventGridResourceId: ingestionTopic::ingestReservationDetailsEvent.id
        eventHubResourceId: eventHubNamespace::storageIngestionEventHub.id
        ignoreFirstRecord: false
        managedIdentityResourceId: cluster.id
        storageAccountResourceId: storage.id
        tableName: 'ReservationDetails_raw'
      }
    }

    resource ingestReservationRecommendationsConnection 'dataConnections' = {
      name: 'ReservationRecommendationsIngestion'
      location: location
      dependsOn: [
        ingestionSetupScript
        clusterEventHubAccess
      ]
      kind: 'EventGrid'
      properties: {
        blobStorageEventType: 'Microsoft.Storage.BlobCreated'
        consumerGroup: eventHubNamespace::storageIngestionEventHub::resvRecommendationsConsumerGroup.name
        dataFormat: 'parquet'
        eventGridResourceId: ingestionTopic::ingestReservationRecommendationsEvent.id
        eventHubResourceId: eventHubNamespace::storageIngestionEventHub.id
        ignoreFirstRecord: false
        managedIdentityResourceId: cluster.id
        storageAccountResourceId: storage.id
        tableName: 'ReservationRecommendations_raw'
      }
    }

    resource ingestReservationTransactionsConnection 'dataConnections' = {
      name: 'ReservationTransactionsIngestion'
      location: location
      dependsOn: [
        ingestionSetupScript
        clusterEventHubAccess
      ]
      kind: 'EventGrid'
      properties: {
        blobStorageEventType: 'Microsoft.Storage.BlobCreated'
        consumerGroup: eventHubNamespace::storageIngestionEventHub::resvTransactionsConsumerGroup.name
        dataFormat: 'parquet'
        eventGridResourceId: ingestionTopic::ingestReservationTransactionsEvent.id
        eventHubResourceId: eventHubNamespace::storageIngestionEventHub.id
        ignoreFirstRecord: false
        managedIdentityResourceId: cluster.id
        storageAccountResourceId: storage.id
        tableName: 'ReservationTransactions_raw'
      }
    }
  }

  resource hubDb 'databases' = {
    name: 'hub'
    location: location
    kind: 'ReadWrite'
    dependsOn: [
      ingestionDb
    ]

    resource hubSetupScript 'scripts' = {
      name: 'SetupScript'
      dependsOn: [
        ingestionDb::ingestionSetupScript
      ]
      properties: {
        scriptContent: loadTextContent('scripts/HubSetup.kql')
        continueOnErrors: continueOnErrors
        forceUpdateTag: forceUpdateTag
      }
    }
  }
}

// Authorize Kusto Cluster to receive event from Event Hub
resource clusterEventHubAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cluster.name, eventHubNamespaceName, 'Azure Event Hubs Data Receiver')
  // See https://docs.microsoft.com/azure/azure-resource-manager/bicep/scope-extension-resources for scope for extension
  scope: eventHubNamespace::storageIngestionEventHub
  properties: {
    description: 'Give "Azure Event Hubs Data Receiver" to the cluster'
    principalId: cluster.identity.principalId
    // Required in case principal not ready when deploying the assignment
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'a638d3c7-ab3a-418d-83e6-5f17a39d4fde' // Event Hubs Data Receiver role -- https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#analytics
    )
  }
}

// Authorize Kusto Cluster to read storage
resource clusterStorageAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cluster.name, storageContainerName, 'Storage Blob Data Contributor')
  // See https://docs.microsoft.com/azure/azure-resource-manager/bicep/scope-extension-resources for scope for extension
  scope: storage::blobServices
  properties: {
    description: 'Give "Storage Blob Data Contributor" to the cluster'
    principalId: cluster.identity.principalId
    // Required in case principal not ready when deploying the assignment
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor -- https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage
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

@description('The name of the ingestion database.')
output ingestionDbName string = cluster::ingestionDb.name

@description('The name of the hub database.')
output hubDbName string = cluster::hubDb.name
