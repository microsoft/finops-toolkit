# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Creates a new Cost Management export.

    .DESCRIPTION
    The New-FinOpsCostExport command creates a new Cost Management export for the specified scope.

    This command has been tested with the following API versions:
    - 2023-07-01-preview (default) – Enables FocusCost and other datasets.
    - 2023-08-01

    .PARAMETER Name
    Required. Name of the export.

    .PARAMETER Scope
    Required. Resource ID of the scope to export data for.

    .PARAMETER Dataset
    Optional. Dataset to export. Allowed values = "ActualCost", "AmortizedCost", "FocusCost", "PriceSheet", "ReservationDetails", "ReservationTransactions", "ReservationRecommendations". Default = "FocusCost".
    
    .PARAMETER DatasetVersion
    Optional. Schema version of the dataset to export. Default = "1.0-preview (v1)" (applies to FocusCost only).

    .PARAMETER DatasetFilters
    Optional. Dictionary of key/value pairs to filter the dataset with. Only applies to ReservationRecommendations dataset in 2023-07-01-preview. Valid filters are reservationScope (Shared or Single), resourceType (e.g., VirtualMachines), lookBackPeriod (Last7Days, Last30Days, Last60Days).

    .PARAMETER Monthly
    Optional. Indicates that the export should be executed monthly (instead of daily). Default = false.

    .PARAMETER OneTime
    Optional. Indicates that the export should only be executed once. When set, the start/end dates are the dates to query data for. Cannot be used in conjunction with the -Monthly option.

    .PARAMETER StartDate
    Optional. Day to start running exports. Default = First day of the previous month if -OneTime is set; otherwise, tomorrow (DateTime.Now.AddDays(1)).

    .PARAMETER EndDate
    Optional. Last day to run the export. Default = Last day of the previous month if -OneTime is set; otherwise, 5 years from -StartDate.

    .PARAMETER StorageAccountId
    Required. Resource ID of the storage account to export data to.

    .PARAMETER StorageContainer
    Optional. Name of the container to export data to. Container is created if it doesn't exist. Default = "cost-management".

    .PARAMETER StoragePath
    Optional. Path to export data to within the storage container. Default = (scope ID).

    .PARAMETER DoNotPartition
    Optional. Indicates whether to partition the exported data into multiple files. Partitioning is recommended for reliability so this option is to disable partitioning. Default = false.

    .PARAMETER DoNotOverwrite
    Optional. Indicates whether to overwrite previously exported data for the current month. Overwriting is recommended to keep storage size and costs down so this option is to disable overwriting. Default = false.

    .PARAMETER Location
    Optional. Indicates the Azure location to use for the managed identity used to push data to the storage account. Managed identity is required in order to work with storage accounts behind a firewall but require access to grant permissions (e.g., Owner). If specified, managed identity will be used; otherwise, managed identity will not be used and your export will not be able to push data to a storage account behind a firewall. Default = (empty).

    .PARAMETER Execute
    Optional. Indicates that the export should be run immediately after created.

    .PARAMETER Backfill
    Optional. Number of months to export the data for. This is only run once at create time. Failed exports are not re-attempted. Not supported when -OneTime is set. Default = 0.

    .PARAMETER ApiVersion
    Optional. API version to use when calling the Cost Management Exports API. Default = 2023-03-01.

    .EXAMPLE
    New-FinopsCostExport -Name 'July2023OneTime' `
        -Scope "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
        -StorageAccountId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
        -DataSet ActualCost `
        -OneTime `
        -StartDate "2023-07-01" `
        -EndDate "2023-07-31"

    Creates a new one time export called 'July2023OneTime from 2023-07-01 to 2023-07-31 with Dataset = Actual and execute it once.

    .EXAMPLE
    New-FinopsCostExport -Name 'DailyMTD' `
        -Scope "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
        -StorageAccountId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
        -DataSet AmortizedCost `
        -EndDate "2024-12-31" `
        -Execute

    Creates a new scheduled export called Daily-MTD with StartDate = DateTime.Now and EndDate = 2024-12-31. Export is run immediately after creation.

    .EXAMPLE
    New-FinopsCostExport -Name 'Monthly-Report' `
        -Scope "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
        -StorageAccountId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
        -DataSet AmortizedCost `
        -StartDate $(Get-Date -AsUTC).AddDays(5) `
        -EndDate "2024-08-15" `
        -Monthly `
        -Execute

    Creates a new monthly export called Monthly-Report with StartDate = 1 day from DateTime.Now and EndDate 2024-08-15. Export is run immediately after creation.

    .EXAMPLE
    New-FinopsCostExport -Name 'Daily--MTD' `
        -Scope "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
        -StorageAccountId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
        -DataSet ActualCost `
        -StorageContainer "costreports" `
        -Backfill 4 `
        -Execute

    Creates a new daily export called Daily-MTD with StartDate = DateTime.Now and EndDate 5 years from StartDate. Additiionally, export cost data for the previous 4 months and save all results in costreports container of the specified storage account.

    .LINK
    https://aka.ms/ftk/New-FinOpsCostExport
#>

function New-FinOpsCostExport
{
    [cmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Scope,

        [Parameter()]
        [ValidateSet("ActualCost", "AmortizedCost", "FocusCost", "PriceSheet", "ReservationDetails", "ReservationTransactions", "ReservationRecommendations")]
        [string]
        $Dataset = "FocusCost",

        [Parameter()]
        [string]
        $DatasetVersion,

        [Parameter()]
        [hashtable]
        $DatasetFilters,

        [Parameter(ParameterSetName = "Scheduled")]
        [switch]
        $Monthly,

        [Parameter(ParameterSetName = "OneTime")]
        [switch]
        $OneTime,

        [Parameter(ParameterSetName = "OneTime")]
        [Parameter(ParameterSetName = "Scheduled")]
        [System.DateTime]
        $StartDate,

        [Parameter(ParameterSetName = "OneTime")]
        [Parameter(ParameterSetName = "Scheduled")]
        [System.DateTime]
        $EndDate,

        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountId,

        [Parameter()]
        [string]
        $StorageContainer = "cost-management",

        [Parameter()]
        [string]
        $StoragePath,

        [Parameter()]
        [string]
        $Location,

        [Parameter()]
        [switch]
        $DoNotPartition,

        [Parameter()]
        [switch]
        $DoNotOverwrite,

        [Parameter()]
        [switch]
        $Execute,

        [Parameter(ParameterSetName = "Scheduled")]
        [int32]
        $Backfill = 0,

        [Parameter()]
        [string]
        $ApiVersion = '2023-07-01-preview'
    )

    function getProperties()
    {
        # Set default dates based on schedule type
        $start = $StartDate
        $end = $EndDate
        if (-not $start)
        {
            if ($OneTime)
            {
                $start = $(Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0 -AsUTC).AddMonths(-1) 
            }
            else
            {
                $start = $(Get-Date -AsUTC).AddDays(1) 
            }
        }
        if (-not $end)
        {
            if ($OneTime)
            {
                $end = $start.AddMonths(1).AddMilliseconds(-1)
            }
            else
            {
                $end = $start.AddYears(5)
            }
        }

        $timePeriod = @{
            from = $start.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
            to   = $end.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
        }

        # Default storage path to scope ID
        if ([System.String]::IsNullOrEmpty($StoragePath))
        {
            $StoragePath = $Scope
        }

        $props = @{
            properties = @{
                definition    = @{
                    type      = $Dataset
                    timeframe = "Custom"
                    dataSet   = @{
                        configuration = @{}
                        granularity   = "Daily"
                    }
                }
                schedule      = @{ status = "Inactive" }
                format        = "Csv"
                deliveryInfo  = @{
                    destination = @{
                        resourceId     = $StorageAccountId
                        container      = $StorageContainer.ToLower()
                        rootFolderPath = $StoragePath
                        # TODO: Add sasToken
                        # TODO: Add storageAccount
                    }
                }
                partitionData = (-not $DoNotPartition)
            }
        }

        # Enable managed identity
        if ($Location)
        {
            $props | Add-Member -Name identity -Value @{ type = "SystemAssigned" } -MemberType NoteProperty -Force
            $props | Add-Member -Name location -Value $Location -MemberType NoteProperty -Force
        }

        # Add scheduling-specific settings
        if ($OneTime)
        {
            $props.properties.definition = $props.properties.definition | Add-Member -Name timePeriod -Value $timePeriod -MemberType NoteProperty -Force -PassThru
        }
        else
        {
            $props.properties.definition.timeframe = "$(if ($Monthly) { 'TheLastMonth' } elseif ($Dataset -eq "PriceSheet") { 'TheCurrentMonth' } else { 'MonthToDate' })"
            $props.properties.schedule = @{
                status           = "Active"
                recurrence       = "$(if ($Monthly) { 'Monthly' } elseif ($Dataset -eq "PriceSheet") { 'Daily' } else { 'Daily' })"
                recurrencePeriod = $timePeriod
            }
        }
        
        # Add version-specific settings
        if ($ApiVersion -eq '2023-07-01-preview' -or $ApiVersion.Substring(0, 4) -ge 2024)
        {
            # Default dataset versions
            if (-not $DatasetVersion)
            {
                if ($Dataset -eq "FocusCost")
                {
                    $DatasetVersion = "1.0-preview (v1)"
                }
                elseif ($Dataset -eq "ActualCost" -or $Dataset -eq "AmortizedCost")
                {
                    $DatasetVersion = "2021-10-01"
                }
                elseif ($Dataset -eq "PriceSheet")
                {
                    $DatasetVersion = "2023-05-01"
                }
                elseif ($Dataset -eq "ReservationDetails")
                {
                    $DatasetVersion = "2023-03-01"
                }
                elseif ($Dataset -eq "ReservationTransactions")
                {
                    $DatasetVersion = "2023-05-01"
                }
                elseif ($Dataset -eq "ReservationRecommendations")
                {
                    $DatasetVersion = "2023-05-01"
                }
            }
            
            # Add 2023-07-01-preview settings
            $props | Add-Member -Name name -Value $Name -MemberType NoteProperty -Force
            $props.properties = $props.properties | Add-Member -Name exportDescription -Value $Description -MemberType NoteProperty -Force -PassThru
            $props.properties = $props.properties | Add-Member -Name dataOverwriteBehavior -Value "$(if ($DoNotOverwrite) { "CreateNewReport" } else { "OverwritePreviousReport" })" -MemberType NoteProperty -Force -PassThru
            $props.properties = $props.properties | Add-Member -Name compressionMode -Value "None" -MemberType NoteProperty -Force -PassThru
            $props.properties.definition.dataSet.configuration = $props.properties.definition.dataSet.configuration | Add-Member -Name dataVersion -Value $DatasetVersion -MemberType NoteProperty -Force -PassThru
            $props.properties.deliveryInfo.destination.type = "AzureBlob"
            
            # Add dataset filters
            if ($DatasetFilters.Count -gt 0)
            {
                $props.properties.definition.dataSet.configuration = $props.properties.definition.dataSet.configuration | Add-Member -Name filters -Value $DatasetFilters -MemberType NoteProperty -Force -PassThru
            }
        }
        elseif ($Dataset -ne 'ActualCost' -and $Dataset -ne 'AmortizedCost')
        {
            $props.properties.definition.type = 'ActualCost'
        }

        return $props
    }

    # Command details for Invoke-Rest calls
    $commandDetails = @{
        CommandName      = "New-FinOpsCostExport" 
        ParameterSetName = $PsCmdlet.ParameterSetName
    }

    $context = Get-AzContext
    if (-not $context)
    {
        throw $script:localizedData.ContextNotFound
    }

    
    # Register the Microsoft.CostManagementExports RP
    if ((Get-AzResourceProvider -ProviderNamespace Microsoft.CostManagementExports).RegistrationState -ne 'Registered')
    {
        Write-Verbose "Microsoft.CostManagementExports provider is not registered. Registering provider."
        Register-AzResourceProvider -ProviderNamespace 'Microsoft.CostManagementExports'
    }
    else
    {
        Write-Verbose "Provider Microsoft.CostManagementExports is registered"
    }

    $properties = getProperties
    
    # Check if exists and get etag
    $uri = "$Scope/providers/Microsoft.CostManagement/exports/$Name`?api-version=$ApiVersion"
    Write-Verbose "Checking if export $Name exists with path $uri"
    $export = Get-FinOpsCostExport -Name $Name -Scope $Scope -ApiVersion $ApiVersion
    if ($export)
    {
        Write-Verbose "Export with name $name already exists in scope $scope. Updating export."
        $etag = $export.etag
        Write-Verbose "Adding etag to the request for modify request"
        $properties = $properties | Add-Member -Name eTag -Value $etag -MemberType NoteProperty -Force -PassThru
    }
    else
    {
        # Create the export using the JSON properties below.
        Write-Verbose "Creating a new export from $startdateString to $enddateString : $uri"
    }

    # Create/update export
    $createResponse = Invoke-Rest -Method PUT -Uri $uri -Body $properties @commandDetails
    if ($createResponse.Failure)
    {
        Write-Error "Unable to create export $Name in scope $Scope. Error: $($createResponse.Content.error.message) ($($createResponse.Content.error.code))" -ErrorAction Stop
        return
    }

    # Run now if requested
    if ($Execute -eq $true -or $OneTime -eq $true)
    {
        Start-FinOpsCostExport -Name $Name -Scope $Scope
    }

    # once set, change the export to be a one-time export for the previous month. Keep all other settings as-is. This should auto-trigger a run and repeat for each month
    if ($Backfill -gt 0)
    {
        $properties = getProperties
        Write-Host "Running backfill for $backfill month$(if ($backfill -gt 1) { 's' })"
        $counter = 1
        $properties.properties.schedule = @{ status = "Inactive" }
        $properties.properties.definition.timeframe = "Custom"
        do
        {
            # run get to fetch etag since this is an update operation
            $etag = (Get-FinOpsCostExport -Name $Name -Scope $Scope -ApiVersion $ApiVersion).etag

            # insert etag in the properies object and convert it to json
            $properties = $properties | Add-Member -Name eTag -Value $etag -MemberType NoteProperty -Force -PassThru

            Write-Verbose "Month $counter of $backfill"
            $startofcurrentmonth = [datetime]$(Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0 -AsUTC).ToString("yyyy-MM-dd")

            $startofpreviousmonth = $startofcurrentmonth.AddMonths($counter * -1)
            $endofpreviousmonth = $startofpreviousmonth.AddMonths(1).AddMilliseconds($counter * -1).ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
            $startofpreviousmonth = $startofpreviousmonth.ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
            $properties.properties.definition = $properties.properties.definition | Add-Member -Name timePeriod -Value @{ to = $endofpreviousmonth; from = $startofpreviousmonth } -MemberType NoteProperty -Force -PassThru

            $backfillsettings = $null
            $backfillsettings = $properties

            Write-Verbose "Running backfill export from $startofpreviousmonth to $endofpreviousmonth"
            Write-Verbose $backfillsettings 
            $backfillResponse = Invoke-Rest -Method PUT -Uri $uri -Body $backfillsettings @commandDetails
            if ($backfillResponse.Success)
            {
                Write-Verbose "Updated export for onetime export of previous month. Executing export"
                $runResponse = Start-FinOpsCostExport -Name $Name -Scope $Scope
                if ($runResponse.Failure)
                {
                    Write-Error "Unable to run export for $startofpreviousmonth. Error: $($runResponse.Content.error.message) ($($runResponse.Content.error.code))." -ErrorAction Continue
                }
            }
            else
            {
                Write-Error "Unable to run export for $startofpreviousmonth. Error: $($backfillResponse.Content.error.message) ($($backfillResponse.Content.error.code))." -ErrorAction Continue
            }

            $counter += 1
            Start-Sleep 2
        } while ($counter -le $Backfill)

        Write-Verbose "Backfill complete. Updating export settings back to original scheduled settings"
        $etag = (Get-FinOpsCostExport -Name $Name -Scope $Scope -ApiVersion $ApiVersion).etag
        $properties = getProperties
        $properties = $properties | Add-Member -Name eTag -Value $etag -MemberType NoteProperty -Force -PassThru
        $updateResponse = Invoke-Rest -Method PUT -Uri $uri -Body $properties @commandDetails
        if ($updateResponse.Failure)
        {
            Write-Error "Unable to update export $Name back to the original state after backfill. Please run New-FinOpsCostExport again without the -Backfill option. Error: $($updateResponse.Content.error.message) ($($updateResponse.Content.error.code))" -ErrorAction Stop
        }
    }

    return (Get-FinOpsCostExport -Name $Name -Scope $Scope -ApiVersion $ApiVersion)
}
