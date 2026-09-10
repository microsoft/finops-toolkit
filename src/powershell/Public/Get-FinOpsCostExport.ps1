# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Get a list of Cost Management exports for a given scope.

    .DESCRIPTION
    The Get-FinOpsCostExport command gets a list of Cost Management exports for a given scope.

    This command has been tested with the following API versions:
    - 2025-03-01 (default) – GA version for FocusCost and other datasets.
    - 2023-07-01-preview
    - 2023-08-01
    - 2023-03-01

    .PARAMETER Name
    Optional. Name of the export. Supports wildcards.

    .PARAMETER Scope
    Optional. Resource ID of the scope the export was created for. If empty, defaults to current subscription context.

    .PARAMETER DataSet
    Optional. Dataset to export. Allowed values = "ActualCost", "AmortizedCost", "FocusCost", "PriceSheet", "ReservationDetails", "ReservationTransactions", "ReservationRecommendations". Default = null (all exports).

    .PARAMETER DataSetVersion
    Optional. Schema version of the dataset to export. Default = null (all exports).

    .PARAMETER StorageAccountId
    Optional. Resource ID of the storage account to get exports for. Default = null (all exports).

    .PARAMETER StorageContainer
    Optional. Name of the container to get exports for. Supports wildcards. Default = null (all exports).

    .PARAMETER RunHistory
    Optional. Indicates whether the run history should be expanded. Default = false.

    .PARAMETER ApiVersion
    Optional. API version to use when calling the Cost Management exports API. Default = 2025-03-01.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"

    ### Get all cost exports for a subscription
    Gets all exports for a subscription. Does not include exports in nested resource groups.

    .EXAMPLE
    Get-FinOpsCostExport -Name mtd* -Scope "providers/Microsoft.Billing/billingAccounts/00000000"

    ### Get exports matching a wildcard name
    Gets export with name matching wildcard mtd* within the specified billing account scope. Does not include exports in nested resource groups.

    .EXAMPLE
    Get-FinOpsCostExport -Dataset "AmortizedCost"

    ### Get all amortized cost exports
    Gets all exports within the current context subscription scope and filtered by dataset AmortizedCost.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageAccountId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/MyResourceGroup/providers/Microsoft.Storage/storageAccounts/MyStorageAccount"

    ### Get exports using a specific storage account
    Gets all exports within the subscription scope filtered by a specific storage account.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageContainer "MyContainer*"

    ### Get exports using a specific container
    Gets all exports within the subscription scope for a specific container. Supports wildcard.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageContainer "mtd*" -ApiVersion "2025-03-01"

    ### Get exports using a specific API version
    Gets all exports within the subscription scope for a container matching wildcard pattern and using a specific API version.

    .LINK
    https://aka.ms/ftk/Get-FinOpsCostExport
#>
function Get-FinOpsCostExport
{
    param
    (
        [Parameter()]
        [SupportsWildcards()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Scope,

        [Parameter()]
        [ValidateSet("ActualCost", "AmortizedCost", "FocusCost", "PriceSheet", "ReservationDetails", "ReservationRecommendations", "ReservationTransactions")]
        [string]
        $Dataset,

        [Parameter()]
        [string]
        $DatasetVersion,

        [Parameter()]
        [string]
        $StorageAccountId,

        [Parameter()]
        [SupportsWildcards()]
        [string]
        $StorageContainer,

        [Parameter()]
        [switch]
        $RunHistory,

        [Parameter()]
        [string]
        $ApiVersion = '2025-03-01'
    )

    $context = Get-AzContext
    if (-not $context)
    {
        throw $script:LocalizedData.Common_ContextNotFound
    }
    # if Scope is not passed, use current subscription scope
    if ([System.String]::IsNullOrEmpty($Scope))
    {
        $contextsubscription = $context.Subscription.Id
        $Scope = "subscriptions/$contextsubscription"

        Write-Verbose -Message "Scope parameter was not passed. Setting to subscription scope from current context"
    }

    $scope = $scope.Trim("/")
    $path = "$scope/providers/Microsoft.CostManagement/exports?api-version=$ApiVersion$(if ($RunHistory) { '&$expand=runHistory' })"

    # Get operation does not allow wildcards. Fetching all exports using list operation and then filtering in script
    # https://learn.microsoft.com/rest/api/cost-management/exports/list?tabs=HTTP

    Write-Verbose -Message "fetching all exports for scope:$scope"
    $response = Invoke-Rest -Method GET -Uri $path -CommandName "Get-FinOpsCostExport"

    Write-Verbose -Message "response received with status code $($response.StatusCode)"

    if ($response.Success)
    {
        $content = $response.Content.Value
        Write-Verbose -Message "found $($content.count) export items for the scope $scope"

        # Name parameter received
        if (-not [System.String]::IsNullOrEmpty($Name))
        {
            $content = $content | Where-Object { $_.name -like $Name }
            Write-Verbose -Message "$($content.count) items left after filtering for Name $Name"
        }
        if (-not [System.String]::IsNullOrEmpty($Dataset))
        {
            $content = $content | Where-Object { $_.properties.definition.type -like $Dataset }
            Write-Verbose -Message "$($content.count) items left after filtering for Dataset $Dataset"
        }
        if (-not [System.String]::IsNullOrEmpty($DatasetVersion))
        {
            $content = $content | Where-Object { $_.properties.definition.type -like $DatasetVersion }
            Write-Verbose -Message "$($content.count) items left after filtering for DatasetVersion $DatasetVersion"
        }
        if (-not [System.String]::IsNullOrEmpty($StorageAccountId))
        {
            $content = $content | Where-Object { $_.properties.deliveryInfo.destination.resourceId.tostring() -eq $StorageAccountId }
            Write-Verbose -Message "found $($content.count) items after filtering for storageaccountid $StorageAccountId"
        }
        if (-not [System.String]::IsNullOrEmpty($StorageContainer))
        {
            $content = $content | Where-Object { $_.properties.deliveryInfo.destination.container.tostring() -like $StorageContainer }
            Write-Verbose -Message "found $($content.count) items after filtering for StorageContainer $StorageContainer"
        }
        $exportdetails = @()
        $content | ForEach-Object {
            $export = $_

            # The list endpoint truncates runHistory per export, so when -RunHistory is
            # requested we re-fetch each export individually to get the full run history.
            # https://github.com/microsoft/finops-toolkit/issues/2063
            $runHistoryValue = $export.properties.runHistory.value
            if ($RunHistory)
            {
                Write-Verbose -Message "fetching full run history for export $($export.name)"
                $exportPath = "$($export.id.Trim('/'))?api-version=$ApiVersion&`$expand=runHistory"

                # Re-fetch each export individually, with two guards:
                #   1. Invoke-Rest throws (rather than returning Success=$false) when an
                #      error response has no structured error body -- network failures,
                #      non-JSON 5xx, token errors. An uncaught throw on a single export
                #      would abort the whole cmdlet and defeat the fallback below, so the
                #      call is wrapped in try/catch.
                #   2. This N+1 fan-out can hit Cost Management throttling on busy
                #      accounts, so honor 429s with a bounded wait-and-retry (mirroring
                #      Start-FinOpsCostExport) rather than silently falling back to the
                #      truncated list history -- which would reintroduce #2063.
                $maxThrottleRetries = 3
                $throttleRetries = 0
                $runResponse = $null
                while ($true)
                {
                    try
                    {
                        $runResponse = Invoke-Rest -Method GET -Uri $exportPath -CommandName "Get-FinOpsCostExport"
                    }
                    catch
                    {
                        $runResponse = $null
                        Write-Verbose -Message "individual GET threw for export $($export.name): $($_.Exception.Message)"
                        break
                    }

                    if (-not $runResponse.Throttled)
                    {
                        break
                    }
                    if ($throttleRetries -ge $maxThrottleRetries)
                    {
                        Write-Verbose -Message "still throttled fetching run history for export $($export.name) after $maxThrottleRetries retries; falling back to list run history"
                        break
                    }
                    $throttleRetries++
                    Write-Verbose -Message "throttled fetching run history for export $($export.name); waiting 60s and retrying ($throttleRetries/$maxThrottleRetries)"
                    Start-Sleep -Seconds 60
                }

                if ($runResponse.Success)
                {
                    $runHistoryValue = $runResponse.Content.properties.runHistory.value
                    Write-Verbose -Message "found $($runHistoryValue.count) runs for export $($export.name)"
                }
                else
                {
                    Write-Verbose -Message "individual GET failed for export $($export.name); falling back to run history from list response"
                }
            }

            # Extract run history before PSCustomObject creation to avoid nested
            # ForEach-Object $_ collision within the hashtable expression
            $runs = @()
            foreach ($run in $runHistoryValue)
            {
                if ($null -eq $run) { continue }
                $runs += [PSCustomObject]@{
                    # .OUTPUTS FinOpsCostExportRunHistory
                    # | Property         | Type     | JSON path                                                  |
                    # | ---------------- | -------- | ----------------------------------------------------------- |
                    # | `ResourceId`     | String   | `properties.runHistory.value[].id`                           |
                    # | `RunId`          | String   | `properties.runHistory.value[].name`                         |
                    # | `ExecutionType`  | String   | `properties.runHistory.value[].properties.executionType`     |
                    # | `Status`         | String   | `properties.runHistory.value[].properties.status`            |
                    # | `SubmittedBy`    | String   | `properties.runHistory.value[].properties.submittedBy`       |
                    # | `SubmittedTime`  | DateTime | `properties.runHistory.value[].properties.submittedTime`     |
                    # | `RunStartTime`   | DateTime | `properties.runHistory.value[].properties.processingStartTime` |
                    # | `RunEndTime`     | DateTime | `properties.runHistory.value[].properties.processingEndTime` |
                    # | `FileName`       | String   | `properties.runHistory.value[].properties.fileName`          |
                    # | `QueryStartDate` | DateTime | `properties.runHistory.value[].properties.startDate`         |
                    # | `QueryEndDate`   | DateTime | `properties.runHistory.value[].properties.endDate`           |
                    # | `ErrorCode`      | String   | `properties.runHistory.value[].properties.error.code`        |
                    # | `ErrorMessage`   | String   | `properties.runHistory.value[].properties.error.message`     |
                    ResourceId     = $run.id
                    RunId          = $run.name
                    ExecutionType  = $run.properties.executionType
                    Status         = $run.properties.status
                    SubmittedBy    = $run.properties.submittedBy
                    SubmittedTime  = $run.properties.submittedTime
                    RunStartTime   = $run.properties.processingStartTime
                    RunEndTime     = $run.properties.processingEndTime
                    FileName       = $run.properties.fileName
                    QueryStartDate = $run.properties.startDate
                    QueryEndDate   = $run.properties.endDate
                    ErrorCode      = $run.properties.error.code
                    ErrorMessage   = $run.properties.error.message
                }
            }
            $item = [PSCustomObject]@{
                # .OUTPUTS FinOpsCostExport
                # | Property              | Type                         | JSON path                                                                    |
                # | --------------------- | ---------------------------- | ---------------------------------------------------------------------------- |
                # | `Name`                | String                       | `name`                                                                       |
                # | `Id`                  | String                       | `id`                                                                         |
                # | `Type`                | String                       | `type`                                                                       |
                # | `eTag`                | String                       | `eTag`                                                                       |
                # | `Description`         | String                       | `properties.exportDescription`                                               |
                # | `Dataset`             | String                       | `properties.definition.type`                                                 |
                # | `DatasetVersion`      | String                       | `properties.definition.configuration.dataVersion`                            |
                # | `DatasetFilters`      | String                       | `properties.definition.configuration.filter`                                 |
                # | `DatasetTimeFrame`    | String                       | `properties.definition.timeframe`                                            |
                # | `DatasetStartDate`    | DateTime                     | `properties.definition.timePeriod.from`                                      |
                # | `DatasetEndDate`      | DateTime                     | `properties.definition.timePeriod.to`                                        |
                # | `DatasetGranularity`  | String                       | `properties.definition.dataset.granularity`                                  |
                # | `ScheduleStatus`      | String                       | `properties.schedule.status`                                                 |
                # | `ScheduleRecurrence`  | String                       | `properties.schedule.recurrence`                                             |
                # | `ScheduleStartDate`   | DateTime                     | `properties.schedule.recurrencePeriod.from`                                  |
                # | `ScheduleEndDate`     | DateTime                     | `properties.schedule.recurrencePeriod.to`                                    |
                # | `NextRuntimeEstimate` | DateTime                     | `properties.nextRunTimeEstimate`                                             |
                # | `Format`              | String                       | `properties.format`                                                          |
                # | `StorageAccountId`    | String                       | `properties.deliveryInfo.destination.resourceId`                             |
                # | `StorageContainer`    | String                       | `properties.deliveryInfo.destination.container`                              |
                # | `StoragePath`         | String                       | `properties.deliveryInfo.destination.rootfolderpath`                         |
                # | `OverwriteData`       | Boolean                      | `properties.deliveryInfo.dataOverwriteBehavior` == "OverwritePreviousReport" |
                # | `PartitionData`       | Boolean                      | `properties.deliveryInfo.partitionData`                                      |
                # | `CompressionMode`     | String                       | `properties.deliveryInfo.compressionMode`                                    |
                # | `RunHistory`          | FinOpsCostExportRunHistory[] | `properties.runHistory.value`                                                |
                Name                = $export.name
                Id                  = $export.id
                Type                = $export.type
                eTag                = $export.eTag
                Description         = $export.properties.exportDescription
                Dataset             = $export.properties.definition.type
                DatasetVersion      = $export.properties.definition.dataSet.configuration.dataVersion
                DatasetFilters      = $export.properties.definition.dataSet.configuration.filter
                DatasetTimeFrame    = $export.properties.definition.timeframe
                DatasetStartDate    = $export.properties.definition.timePeriod.from
                DatasetEndDate      = $export.properties.definition.timePeriod.to
                DatasetGranularity  = $export.properties.definition.dataSet.granularity
                ScheduleStatus      = $export.properties.schedule.status
                ScheduleRecurrence  = $export.properties.schedule.recurrence
                ScheduleStartDate   = $export.properties.schedule.recurrencePeriod.from
                ScheduleEndDate     = $export.properties.schedule.recurrencePeriod.to
                NextRuntimeEstimate = $export.properties.nextRunTimeEstimate
                Format              = $export.properties.format
                StorageAccountId    = $export.properties.deliveryInfo.destination.resourceId
                StorageContainer    = $export.properties.deliveryInfo.destination.container
                StoragePath         = $export.properties.deliveryInfo.destination.rootFolderPath
                OverwriteData       = $export.properties.dataOverwriteBehavior -eq "OverwritePreviousReport"
                PartitionData       = $export.properties.partitionData
                CompressionMode     = $export.properties.compressionMode
                RunHistory          = $runs
            }
            $exportdetails += $item
        }
        return $exportdetails
    }
}