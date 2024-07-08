# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Initiates a Cost Management export run for the most recent period.

    .DESCRIPTION
    The Start-FinOpsCostExport command runs a Cost Management export for the most recent period using the Run API.

    This command has been tested with the following API versions:
    - 2023-07-01-preview (default) – Enables FocusCost and other datasets.
    - 2023-08-01
    - 2023-03-01

    .PARAMETER Name
    Required. Name of the export.

    .PARAMETER Scope
    Optional. Resource ID of the scope to export data for. If empty, defaults to current subscription context.

    .PARAMETER StartDate
    Optional. Day to start pulling the data for. If not set, the export will use the dates defined in the export configuration.
    
    .PARAMETER EndDate
    Optional. Last day to pull data for. If not set and -StartDate is set, -EndDate will use the last day of the month. If not set and -StartDate is not set, the export will use the dates defined in the export configuration.
    
    .PARAMETER Backfill
    Optional. IndicLast day to pull data for. If not set and -StartDate is set, -EndDate will use the last day of the month. If not set and -StartDate is not set, the export will use the dates defined in the export configuration.

    .PARAMETER ApiVersion
    Optional. API version to use when calling the Cost Management Exports API. Default = 2023-07-01-preview.

    .EXAMPLE
    Start-FinopsCostExport -Name 'July2023OneTime'

    Runs an export called 'July2023OneTime'.
    
    .LINK
    https://aka.ms/ftk/Start-FinOpsCostExport
#>
function Start-FinOpsCostExport
{
    [cmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Scope,
        
        [Parameter()]
        [datetime]
        $StartDate,
        
        [Parameter()]
        [datetime]
        $EndDate,
        
        [Parameter()]
        [int]
        $Backfill,

        [Parameter()]
        [string]
        $ApiVersion = '2023-07-01-preview'
    )

    $export = Get-FinOpsCostExport -Name $Name -Scope $Scope
    
    if (-not $export)
    {
        Write-Error "Export $Name not found. Did you specify the correct scope?" -ErrorAction Stop
        return
    }

    $runpath = "$($export.Id)/run?api-version=$ApiVersion"

    # Set start date if using -Backfill
    if ($Backfill -gt 0)
    {
        $StartDate = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0 -AsUTC).AddMonths($Backfill * -1)
        $EndDate = $StartDate.AddMonths($Backfill).AddMilliseconds(-1)
        Write-Verbose "Backfill $Backfill months = $($StartDate.ToUniversalTime().ToString('yyyy-MM-dd"T"HH:mm:ss"Z"')) to $($EndDate.ToUniversalTime().ToString('yyyy-MM-dd"T"HH:mm:ss"Z"'))"
    }
    
    # Remove time + set end date
    if ($StartDate)
    {
        $StartDate = $StartDate.ToUniversalTime().Date
        if ($EndDate)
        {
            $EndDate = $EndDate.ToUniversalTime().Date
        }
        else
        {
            $EndDate = $StartDate.ToUniversalTime().Date.AddMonths(1).AddDays(-1)
        }
        Write-Verbose "Updated dates = $($StartDate.ToUniversalTime().ToString('yyyy-MM-dd"T"HH:mm:ss"Z"')) to $($EndDate.ToUniversalTime().ToString('yyyy-MM-dd"T"HH:mm:ss"Z"'))"
    }

    # Loop thru each month
    $monthToExport = 0
    $success = $true
    $body = $null
    $multipleMonths = $StartDate -and $StartDate.Year -ne $EndDate.Year -or $StartDate.Month -ne $EndDate.Month
    Write-Verbose "Exporting $($StartDate) - $($EndDate)"
    do
    {
        if ($StartDate)
        {
            # If more than one month
            if ($multipleMonths)
            {
                $firstDay = $EndDate.AddDays(-$EndDate.Day + 1).AddMonths($monthToExport * -1)
                $lastDay = $firstDay.AddMonths(1).AddMilliseconds(-1)
            }
            else
            {
                $firstDay = $StartDate
                $lastDay = $EndDate
            }
            $body = @{ timePeriod = @{ from = $firstDay.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"); to = $lastDay.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") } }
            Write-Verbose "Executing $($firstDay.ToString("MMM d yyyy HH:mm:ss")) export $runpath"
        }
        else
        {
            Write-Verbose "Executing export $runpath"
        }

        $response = Invoke-Rest -Method POST -Uri $runpath -Body $body -CommandName "Start-FinOpsCostExport"
        if ($response.Success)
        {
            Write-Verbose "Export executed successfully"
        }
        else
        {
            Write-Verbose "Export failed to execute"
        }
        $success = $success -and $response.Success

        $monthToExport += 1
    } while ($multipleMonths -and $EndDate.AddMonths($monthToExport * -1) -ge $StartDate)

    return $success
}
