# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Creates a new Cost Management export.

    .DESCRIPTION
    The New-FinOpsCostExport command creates a new Cost Management export for the specified scope.

    .PARAMETER Name
    Required. Name of the export.

    .PARAMETER Scope
    Required. Resource ID of the scope to export data for.

    .PARAMETER Dataset
    Optional. Dataset to export. Allowed values = "ActualCost", "AmortizedCost". Default = "ActualCost".

    .PARAMETER Monthly
    Optional. Indicates that the export should be executed monthly (instead of daily). Default = false.

    .PARAMETER OneTime
    Optional. Indicates that the export should only be executed once. When set, the start/end dates are the dates to query data for. Cannot be used in conjunction with the -Monthly option.

    .PARAMETER StartDate
    Optional. Day to start running exports. If -OneTime is set, this is required (not defaulted) and is used as the first day to query data for. Default = DateTime.Now.

    .PARAMETER EndDate
    Optional. Last day to run the export. If -OneTime is set, this is required (not defaulted) and is used as the last day to query data for. Default = 5 years from -StartDate.

    .PARAMETER StorageAccountId
    Required. Resource ID of the storage account to export data to.

    .PARAMETER StorageContainer
    Optional. Name of the container to export data to. Container is created if it doesn't exist. Default = "cost-management".

    .PARAMETER StoragePath
    Optional. Path to export data to within the storage container. Default = (scope ID).

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
        -StartDate $(Get-Date).AddDays(5) `
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
        [ValidateSet("ActualCost", "AmortizedCost")]
        [string]
        $DataSet = "ActualCost",

        [Parameter(ParameterSetName = "Scheduled")]
        [switch]
        $Monthly,

        [Parameter(ParameterSetName = "OneTime")]
        [switch]
        $OneTime,

        [Parameter(ParameterSetName = "OneTime", Mandatory = $true)]
        [Parameter(ParameterSetName = "Scheduled")]
        [System.DateTime]
        $StartDate = $(Get-Date).AddDays(1),

        [Parameter(ParameterSetName = "OneTime", Mandatory = $true)]
        [Parameter(ParameterSetName = "Scheduled")]
        [System.DateTime]
        $EndDate = $StartDate.AddYears(5),

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
        [switch]
        $Execute,

        [Parameter(ParameterSetName = "Scheduled")]
        [int32]
        $Backfill = 0,

        [Parameter()]
        [string]
        $ApiVersion = '2023-08-01'
    )

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

    $uri = "$scope/providers/Microsoft.CostManagement/exports/$Name`?api-version=$ApiVersion"

    # Storage container must be lowercase
    $StorageContainer = $StorageContainer.ToLower()

    # Default storage path to scope ID
    if ([System.String]::IsNullOrEmpty($StoragePath))
    {
        $StoragePath = $Scope
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

    if ($Monthly) { $recurrence = "Monthly" } else { $recurrence = "Daily" }

    # Use "MonthToDate" unless -OneTime is enabled, then use "Custom"
    if ($OneTime) { $timeframe = "Custom"; $schedulestatus = "Inactive" } else { $timeframe = "MonthToDate"; $schedulestatus = "Active" }

    $StartDatestr = "$($StartDate.ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'"))"
    $EndDatestr = $EndDate.ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")

    $scheduledproperties = @"
{
  "identity": {
    "type": "SystemAssigned"
  },
  "location": "centralus",
  "properties": {
    "schedule": {
      "status": "$schedulestatus",
      "recurrence": "$recurrence",
      "recurrencePeriod": {
        from: "$StartDatestr",
        to: "$EndDatestr",
      }
    },
    "format": "Csv",
    "deliveryInfo": {
      "destination": {
        "resourceId": "$StorageAccountId",
        "container": "$StorageContainer",
        "rootFolderPath": "$StoragePath"
      }
    },
    "definition": {
      "type": "$DataSet",
      "timeframe": "$timeframe",
      "dataSet": {
        "granularity": "Daily"
      }
    }
  }
}
"@ 

    $onetimeproperties = @"
{
  "identity": {
    "type": "SystemAssigned"
  },
  "location": "centralus",
  "properties": {
    "format": "Csv",
    "deliveryInfo": {
      "destination": {
        "resourceId": "$StorageAccountId",
        "container": "$StorageContainer",
        "rootFolderPath": "$StoragePath"
      }
    },
    "definition": {
      "type": "$DataSet",
      "timeframe": "$timeframe",
      "dataSet": {
        "granularity": "Daily"
      },
      "timePeriod": {
        "from": "$StartDatestr",
        "to": "$EndDatestr"
      }
    }
  }
}
"@ 

    if ($onetime) { $properties = $onetimeproperties; $execute = $true } else { $properties = $scheduledproperties }

    $propertiesobj = $properties | ConvertFrom-Json

    #Check if export with same name exists in scope. If it exists, update will be performed using etag.

    Write-Verbose "Checking if export $Name exists with path $uri"
    $export = Get-FinOpsCostExport -Name $Name -Scope $Scope

    if ($export)
    {
        Write-Verbose "Export with name $name already exists in scope $scope. Updating export."
        $etag = $export.etag #needed for update

        $propobj = $propertiesobj 
        Write-Verbose "Adding etag to the request for modify request"
        $propobj | Add-Member -Name eTag -Value $etag -MemberType NoteProperty -Force | ConvertTo-Json -Depth 100
        $properties = $propobj | ConvertTo-Json -Depth 100
    }
    else
    {
        # Create the export using the JSON properties below.
        Write-Verbose "Creating a new export from $startdatestr to $enddatestr : $uri"
    }
    
    $createResponse = Invoke-Rest -Method PUT -Uri $uri -Body $properties @commandDetails
    if ($createResponse.Failure)
    {
        Write-Error "Unable to create export $Name in scope $Scope. Error: $($createResponse.Content.error.message) ($($createResponse.Content.error.code))" -ErrorAction Stop
        return
    }

    if ($Execute -eq $true)
    {
        Start-FinOpsCostExport -Name $Name -Scope $Scope
    }

    # once set, change the export to be a one-time export for the previous month. Keep all other settings as-is. This should auto-trigger a run and repeat for each month
    if ($Backfill -gt 0)
    {
        $propertiesobj = $onetimeproperties | ConvertFrom-Json
        Write-Host "Running backfill for $backfill month$(if ($backfill -gt 1) { 's' })"
        $counter = 1
        $propertiesobj.properties.definition.timeframe = "Custom"  
        do
        {
            $export = $null
            # run get to fetch etag since this is an update operation.
            $export = Get-FinOpsCostExport -Name $Name -Scope $Scope
            $etag = $export.etag #needed for update

            # insert etag in the properies object and convert it to json
            $propertiesobj | Add-Member -Name eTag -Value $etag -MemberType NoteProperty -Force | ConvertTo-Json -Depth 100

            Write-Verbose "Month $counter of $backfill"
            $startofcurrentmonth = [datetime]$(Get-Date -Day 1).ToString("yyyy-MM-dd")

            $startofpreviousmonth = $startofcurrentmonth.AddMonths($counter * -1)
            $endofpreviousmonth = $startofpreviousmonth.AddMonths(1).AddMilliseconds($counter * -1).ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
            $startofpreviousmonth = $startofpreviousmonth.ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
            $propertiesobj.properties.definition.timePeriod.to = $endofpreviousmonth
            $propertiesobj.properties.definition.timePeriod.from = $startofpreviousmonth

            $backfillsettings = $null
            $backfillsettings = $propertiesobj | ConvertTo-Json -Depth 100

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

        $export = Get-FinOpsCostExport -Name $Name -Scope $Scope
        $etag = $export.etag #needed for update

        $propertiesobj = $properties | ConvertFrom-Json
        $propertiesobj | Add-Member -Name eTag -Value $etag -MemberType NoteProperty -Force | ConvertTo-Json -Depth 100
        $properties = $propertiesobj | ConvertTo-Json -Depth 100
        $updateResponse = Invoke-Rest -Method PUT -Uri $uri -Body $properties @commandDetails
        if ($updateResponse.Failure)
        {
            Write-Error "Unable to update export $Name back to the original state after backfill. Please run New-FinOpsCostExport again without the -Backfill option. Error: $($updateResponse.Content.error.message) ($($updateResponse.Content.error.code))" -ErrorAction Stop
        }
    }

    return (Get-FinOpsCostExport -Name $Name -Scope $Scope)
}
