# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Get list of Cost Management exports.

    .PARAMETER Name
    Optional. Name of the export. Supports wildcards.

    .PARAMETER Scope
    Optional. Resource ID of the scope the export was created for. If empty, defaults to current subscription context.

    .PARAMETER DataSet
    Optional. Dataset to get exports for. Allowed values = "ActualCost", "AmortizedCost", "Usage". Default = null (all exports).

    .PARAMETER StorageAccountId
    Optional. Resource ID of the storage account to get exports for. Default = null (all exports).

    .PARAMETER StorageContainer
    Optional. Name of the container to get exports for. Supports wildcards. Default = null (all exports).

    .PARAMETER ApiVersion
    Optional. API version to use when calling the Cost Management exports API. Default = 2023-03-01.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"

    Gets all exports for a subscription. Does not include exports in nested resource groups.
    
    .EXAMPLE
    Get-FinOpsCostExport -Name mtd* -Scope "providers/Microsoft.Billing/billingAccounts/00000000"

    Gets export with name matching wildcard mtd* within the specified billing account scope. Does not include exports in nested resource groups.

    .EXAMPLE
    Get-FinOpsCostExport -DataSet "AmortizedCost"

    Gets all exports within the current context subscription scope and filtered by dataset AmortizedCost.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageAccountId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/MyResourceGroup/providers/Microsoft.Storage/storageAccounts/MyStorageAccount"

    Gets all exports within the subscription scope filtered by a specific storage account.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageContainer "MyContainer*"

    Gets all exports within the subscription scope for a specific container. Supports wildcard.

    .EXAMPLE
    Get-FinOpsCostExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -StorageContainer "mtd*" -ApiVersion "2023-08-01"

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
        [ValidateSet("ActualCost", "AmortizedCost", "Usage")]
        [string]
        $DataSet,

        [Parameter()]
        [string]
        $StorageAccountId,

        [Parameter()]
        [SupportsWildcards()]
        [string]
        $StorageContainer,

        [Parameter()]
        [string]
        $ApiVersion = '2023-08-01'
    )

    $context = Get-AzContext
    if (-not $context)
    {
        throw $script:localizedData.ContextNotFound
    }
    # if Scope is not passed, use current subscription scope
    if ([System.String]::IsNullOrEmpty($Scope))
    {
        $contextsubscription = $context.Subscription.Id
        $Scope = "subscriptions/$contextsubscription"

        Write-Verbose -Message "Scope parameter was not passed. Setting to subscription scope from current context"
    }

    $scope = $scope.Trim("/")
    $path = "$scope/providers/Microsoft.CostManagement/exports?api-version=$ApiVersion"
    
    # Get operation does not allow wildcards. Fetching all exports using list operation and then filtering in script
    # https://learn.microsoft.com/en-us/rest/api/cost-management/exports/list?tabs=HTTP
    
    Write-Verbose -Message "fetching all exports for scope:$scope"
    $httpResponse = Invoke-AzRestMethod -Path $path

    Write-Verbose -Message "response received with status code $($httpResponse.StatusCode)"

    if ($httpResponse.StatusCode -eq 200)
    {
      
        $content = $(ConvertFrom-Json -InputObject $httpResponse.Content -Depth 20).Value
        Write-Verbose -Message "found $($content.count) export items for the scope $scope"

        # Name parameter received
        if (-not [System.String]::IsNullOrEmpty($Name))
        {
            $content = $content | Where-Object { $_.name -like $Name }
            Write-Verbose -Message "$($content.count) items left after filtering for Name $Name"
        }
        if (-not [System.String]::IsNullOrEmpty($DataSet)) 
        {
            $content = $content | Where-Object { $_.properties.definition.type -like $DataSet }
            Write-Verbose -Message "$($content.count) items left after filtering for DataSet $DataSet"
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
                ScheduleStatus      = $_.properties.schedule.status
                ScheduleRecurrence  = $_.properties.schedule.recurrence
                ScheduleStartDate   = $_.properties.schedule.recurrencePeriod.from
                ScheduleEndDate     = $_.properties.schedule.recurrencePeriod.to
                NextRuntimeEstimate = $_.properties.nextRunTimeEstimate
                Format              = $_.properties.format
                StorageAccountId    = $_.properties.deliveryInfo.destination.resourceId
                StorageContainer    = $_.properties.deliveryInfo.destination.container
                StoragePath         = $_.properties.deliveryInfo.destination.rootfolderpath
                DataSet             = $_.properties.definition.type
                DataSetTimeFrame    = $_.properties.definition.timeframe
                DataSetStartDate    = $_.properties.definition.timePeriod.from
                DataSetEndDate      = $_.properties.definition.timePeriod.to
                DatasetGranularity  = $_.properties.definition.dataset.granularity        
            }
            $exportdetails += $item
           
        }
        return $exportdetails 
    }
    else
    {
        $errorobject = $($httpResponse.Content | ConvertFrom-Json).error
        $errorcode = $errorobject.code
        $errorcodemessage = $errorobject.message
        Write-Error -Message $($script:localizedData.ErrorResponse -f $errorcodemessage, $errorcode)
    }
}