// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

// See https://learn.microsoft.com/rest/api/cost-management/exports/create-or-update

targetScope = 'subscription'

//==============================================================================
// Parameters
//==============================================================================

//     Creates a new Cost Management export.
//     The New-FinOpsCostExport command creates a new Cost Management export for the specified scope.

//     This command has been tested with the following API versions:
//     - 2023-07-01-preview (default) – Enables FocusCost and other datasets.
//     - 2023-08-01

@sys.description('Required. Name of the export.')
param name string

@sys.description('Optional. Additional text to save about the export for context.')
param description string = ''

@sys.description('Optional. Dataset to export. Allowed values = "ActualCost", "AmortizedCost", "FocusCost". Note there are other datasets available at other scopes. Default = "FocusCost".')
@allowed([
  'ActualCost'
  'AmortizedCost'
  'FocusCost'
  // TODO: Add billing account (tenant) support -- 'PriceSheet'
  // TODO: Add billing account (tenant) support -- 'ReservationDetails'
  // TODO: Add billing account (tenant) support -- 'ReservationTransactions'
  // TODO: Add billing account (tenant) support -- 'ReservationRecommendations'
])
param dataset string = 'FocusCost'
    
@sys.description('Optional. Schema version of the dataset to export. Default = "1.0" (applies to FocusCost only).')
param datasetVersion string = ''

// TODO: Add billing account (tenant) support -- @sys.description('Optional. Dictionary of key/value pairs to filter the dataset with. Only applies to ReservationRecommendations dataset in 2023-07-01-preview. Valid filters are reservationScope (Shared or Single), resourceType (for example, VirtualMachines), lookBackPeriod (Last7Days, Last30Days, Last60Days).')
// TODO: Add billing account (tenant) support -- param datasetFilters object = {}

@sys.description('Optional. Indicates that the export should be executed monthly (instead of daily). Default = false.')
param monthly bool = false

@sys.description('Optional. Indicates that the export should only be executed once. When set, the start/end dates are the dates to query data for. Cannot be used in conjunction with the -Monthly option.')
param oneTime bool = false

@sys.description('Optional. Day to start running exports. Must be in the format yyyy-MM-ddTHH:miZ. Default = First day of the previous month if oneTime is set; otherwise, tomorrow.')
param startDate string = ''

@sys.description('Optional. Last day to run the export. Must be in the format yyyy-MM-ddTHH:miZ. Default = Last day of the month identified in startDate if oneTime is set; otherwise, 5 years from startDate.')
param endDate string = ''

@sys.description('Required. Resource ID of the storage account to export data to.')
param storageAccountId string

@sys.description('Optional. Name of the container to export data to. Container is created if it doesn\'t exist. Default = "cost-management".')
param storageContainer string = 'cost-management'

@sys.description('Optional. Path to export data to within the storage container. Default = (scope ID).')
param storagePath string = ''

@sys.description('Optional. Indicates whether to partition the exported data into multiple files. Partitioning is recommended for reliability so this option is to disable partitioning. Default = false.')
param doNotPartition bool = false

@sys.description('Optional. Indicates whether to overwrite previously exported data for the current month. Overwriting is recommended to keep storage size and costs down so this option is to disable overwriting. If creating an export for FinOps hubs, we recommend you specify the doNotOverwrite option to improve troubleshooting. Default = false.')
param doNotOverwrite bool = false

@sys.description('Optional. Indicates the Azure location to use for the managed identity used to push data to the storage account. Managed identity is required in order to work with storage accounts behind a firewall but require access to grant permissions (for example, Owner). If specified, managed identity will be used; otherwise, managed identity will not be used and your export will not be able to push data to a storage account behind a firewall. Default = (empty).')
param location string = ''

@sys.description('Ignore. Used to capture UTC time for smart defaults. Only used when startDate is not set.')
param __doNotUse_utcNow string = utcNow('yyyy-MM-ddTHH:mm:ssZ')

//==============================================================================
// Variables
//==============================================================================

// @subscription
var scope = subscription().id
// @resourceGroup
//   var scope = resourceGroup().id

var lastMonth = dateTimeAdd('${substring(__doNotUse_utcNow, 0, 7)}-01-01T00:00:00Z', 'P-1M')
var minStart = dateTimeAdd('${substring(__doNotUse_utcNow, 0, 10)}T00:00:00Z', 'P1D')
var start = startDate ?? (oneTime ? lastMonth : minStart)
// Default to last month for one-time exports
// Default to now for daily/monthly exports

var eom = dateTimeAdd(dateTimeAdd(start, 'P1M'), 'P-1MS')
var maxExpiry = dateTimeAdd(start, 'P-5Y')
var end = endDate ?? (oneTime ? eom : maxExpiry)

var timePeriod = {
    from: start
    to: end
}

// Always default to the latest dataset version
var defaultDatasetVersion = ({
  ActualCost: '2021-10-01'
  AmortizedCost: '2021-10-01'
  FocusCost: '1.0'
  PriceSheet: '2023-05-01'
  ReservationDetails: '2023-03-01'
  ReservationRecommendations: '2023-05-01'
  ReservationTransactions: '2023-05-01'
})[?dataset] ?? null

//==============================================================================
// Resources
//==============================================================================

resource export 'Microsoft.CostManagement/exports@2023-04-01-preview' = {
  name: name
  scope: subscription() // @subscription
  // scope: resourceGroup() // @resourceGroup
  location: length(location) > 0 ? location : null
  identity: length(location) > 0 ? { type: 'SystemAssigned' } : null
  properties: {
    exportDescription: description
    definition: union({
      type: dataset
      dataSet: {
        configuration: {
          dataVersion: length(datasetVersion) > 0 ? datasetVersion : defaultDatasetVersion
          filters: datasetFilters
        }
        granularity: 'Daily'
      }
    }, oneTime ? { timeframe: 'Custom', timePeriod: timePeriod } : { timeframe: monthly ? 'TheLastMonth' : (dataset == 'PriceSheet' ? 'TheCurrentMonth' : 'MonthToDate') })
    schedule: oneTime ? { status: 'Inactive' } : {
      status: 'Active'
      recurrence: monthly ? 'Monthly' : (dataset == 'PriceSheet' ? 'Daily' : 'Daily')
      recurrencePeriod: timePeriod
    }
    format: 'Csv'
    deliveryInfo: {
      destination: {
        type: 'AzureBlob'
        resourceId: storageAccountId
        container: toLower(storageContainer)
        rootFolderPath: replace(replace(length(storagePath ?? '') > 0 ? storagePath : scope, '^/+', ''), '/+$', '')
        // TODO: Add storageAccount + sasToken
      }
    }
    partitionData: !doNotPartition
    dataOverwriteBehavior: doNotOverwrite ? 'CreateNewReport' : 'OverwritePreviousReport'
    compressionMode: 'None'
  }
}

//==============================================================================
// Outputs
//==============================================================================

@sys.description('Resource ID of the export.')
output exportId string = export.id
