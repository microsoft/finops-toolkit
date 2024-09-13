// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

targetScope = 'subscription' // @resourceGroup @subscription
// TODO: Add tenant support (for billing accounts/profiles) add remaining datasets: PriceSheet, ReservationDetails, ReservationTransactions, ReservationRecommendations


param timestamp string = utcNow('yyyy-MM-dd')

module storage 'br/public:avm/res/storage/storage-account:0.13.0' = {
  name: uniqueString()
}


// Test 1 - Creates an export with all the defaults.
module defaultDailyExport '../main.bicep' = {
  name: '__test_defaultDaily'
  params: {
    storageAccountId: storage.id
  }
}

// Test 2 - Creates a monthly export with all the defaults.
module defaultMonthlyExport '../main.bicep' = {
  name: '__test_defaultMonthly'
  params: {
    monthly: true
    storageAccountId: storage.id
  }
}

// Test 3 - Creates a one-time export with all the defaults.
module defaultOneTimeExport '../main.bicep' = {
  name: '__test_defaultOneTime'
  params: {
    oneTime: true
    storageAccountId: storage.id
  }
}

// Test 4 - Creates a one-time reservation transaction export from 2024-07-01 to 2024-07-31.
module actualExport '../main.bicep' = {
  name: '__test_actual'
  params: {
    dataset: 'ActualCost'
    oneTime: true
    startDate: '2024-07-01'
    endDate: '2024-07-31'
    storageAccountId: storage.id
  }
}

// Test 5 - Creates a daily amortized cost export that runs the next 5-10 days.
module amortizedExport '../main.bicep' = {
  name: '__test_amortized'
  params: {
    dataset: 'AmortizedCost'
    startDate: dateTimeAdd(timestamp, 'P5D')
    endDate: dateTimeAdd(timestamp, 'P10D')
    storageAccountId: storage.id
  }
}

// Test 6 - Creates a daily export with all options.
module dailyAllOptionsExport '../main.bicep' = {
  name: '__test_dailyAllOptions'
  params: {
    description: 'Some description about this export'
    location: 'West US2'    
    dataset: 'AmortizedCost'
    datasetVersion: '2021-10-01'
    monthly: false
    oneTime: false
    startDate: dateTimeAdd(timestamp, 'P5D')
    endDate: dateTimeAdd(timestamp, 'P7D')
    storageAccountId: storage.id
    storageContainer: 'cm-exports'
    storagePath: 'path/to/export'
    doNotOverwrite: true
    doNotPartition: true
  }
}

// Test 7 - Creates a monthly export with all options.
module monthlyAllOptionsExport '../main.bicep' = {
  name: '__test_monthlyAllOptions'
  params: {
    description: 'Some description about this export'
    location: 'West US2'    
    dataset: 'FocusCost'
    datasetVersion: '1.0-preview(v1)'
    monthly: true
    oneTime: false
    startDate: dateTimeAdd(timestamp, 'P5D')
    endDate: dateTimeAdd(timestamp, 'P7D')
    storageAccountId: storage.id
    storageContainer: 'cm-exports'
    storagePath: 'path/to/export'
    doNotOverwrite: true
    doNotPartition: true
  }
}

// Test 8 - Creates a one-time export with all options.
module oneTimeAllOptionsExport '../main.bicep' = {
  name: '__test_oneTimeAllOptions'
  params: {
    description: 'Some description about this export'
    location: 'West US2'    
    dataset: 'FocusCost'
    datasetVersion: '1.0'
    monthly: false
    oneTime: true
    startDate: dateTimeAdd(timestamp, 'P-2D')
    endDate: dateTimeAdd(timestamp, 'P-1D')
    storageAccountId: storage.id
    storageContainer: 'cm-exports'
    storagePath: 'path/to/export'
    doNotOverwrite: true
    doNotPartition: true
  }
}


output defaultDailyExportId string = defaultDailyExport.outputs.exportId
output defaultMonthlyExportId string = defaultMonthlyExport.outputs.exportId
output defaultOneTimeExportId string = defaultOneTimeExport.outputs.exportId
output actualExportId string = actualExport.outputs.exportId
output amortizedExportId string = amortizedExport.outputs.exportId
output dailyAllOptionsExportId string = dailyAllOptionsExport.outputs.exportId
output monthlyAllOptionsExportId string = monthlyAllOptionsExport.outputs.exportId
output oneTimeAllOptionsExportId string = oneTimeAllOptionsExport.outputs.exportId
