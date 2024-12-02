# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Get list of Cost Management exports.

    .DESCRIPTION
    The Get-FinOpsCostExport command gets a list of Cost Management exports for a given scope.

    This command has been tested with the following API versions:
    - 2023-07-01-preview (default) – Enables FocusCost and other datasets.
    - 2023-08-01

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
    Optional. API version to use when calling the Cost Management exports API. Default = 2023-07-01-preview.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"

    Gets all exports for a subscription. Does not include exports in nested resource groups.

    .EXAMPLE
    Get-FinOpsCostExport -Name mtd* -Scope "providers/Microsoft.Billing/billingAccounts/00000000"

    Gets export with name matching wildcard mtd* within the specified billing account scope. Does not include exports in nested resource groups.

    .EXAMPLE
    Get-FinOpsCostExport -Dataset "AmortizedCost"

    Gets all exports within the current context subscription scope and filtered by dataset AmortizedCost.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageAccountId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/MyResourceGroup/providers/Microsoft.Storage/storageAccounts/MyStorageAccount"

    Gets all exports within the subscription scope filtered by a specific storage account.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageContainer "MyContainer*"

    Gets all exports within the subscription scope for a specific container. Supports wildcard.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageContainer "mtd*" -ApiVersion "2023-07-01-preview"

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
        [ValidateSet("ActualCost", "AmortizedCost", "FocusCost", "PriceSheet", "ReservationDetails", "ReservationTransactions", "ReservationRecommendations")]
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
        $ApiVersion = '2023-07-01-preview'
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
            $item = [PSCustomObject]@{
                Name                = $_.name
                Id                  = $_.id
                Type                = $_.type
                eTag                = $_.eTag
                Description         = $_.properties.exportDescription
                Dataset             = $_.properties.definition.type
                DatasetVersion      = $_.properties.definition.configuration.dataVersion
                DatasetFilters      = $_.properties.definition.configuration.filter
                DatasetTimeFrame    = $_.properties.definition.timeframe
                DatasetStartDate    = $_.properties.definition.timePeriod.from
                DatasetEndDate      = $_.properties.definition.timePeriod.to
                DatasetGranularity  = $_.properties.definition.dataset.granularity
                ScheduleStatus      = $_.properties.schedule.status
                ScheduleRecurrence  = $_.properties.schedule.recurrence
                ScheduleStartDate   = $_.properties.schedule.recurrencePeriod.from
                ScheduleEndDate     = $_.properties.schedule.recurrencePeriod.to
                NextRuntimeEstimate = $_.properties.nextRunTimeEstimate
                Format              = $_.properties.format
                StorageAccountId    = $_.properties.deliveryInfo.destination.resourceId
                StorageContainer    = $_.properties.deliveryInfo.destination.container
                StoragePath         = $_.properties.deliveryInfo.destination.rootfolderpath
                OverwriteData       = $_.properties.deliveryInfo.dataOverwriteBehavior -eq "OverwritePreviousReport"
                PartitionData       = $_.properties.deliveryInfo.partitionData
                CompressionMode     = $_.properties.deliveryInfo.compressionMode
                RunHistory          = $_.properties.runHistory.value | Where-Object { $_ -ne $null } | ForEach-Object {
                    [PSCustomObject]@{
                        Id            = $_.id
                        ExecutionType = $_.properties.executionType
                        FileName      = $_.fileName
                        StartTime     = $_.processingStartTime
                        EndTime       = $_.processingEndTime
                        Status        = $_.status
                        SubmittedBy   = $_.submittedBy
                        SubmittedTime = $_.submittedTime
                    }
                }
            }
            $exportdetails += $item
        }
        return $exportdetails
    }
}