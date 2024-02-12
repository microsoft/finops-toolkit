# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# TODO: Add -Backfill parameter that can backfill many months with a single number
# TODO: When start/end dates are spread over multiple months, create separate calls for each month

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
    }
    else
    {
        $runpath = "$($export.Id)/run?api-version=$ApiVersion"

        # Set start date if using -Backfill
        if (-not $StartDate -and $Backfill -gt 0)
        {
            $StartDate = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0 -AsUTC).AddMonths($Bacfill * -1)
            $EndDate = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0 -AsUTC).AddMilliseconds(-1)
        }

        # once set, change the export to be a one-time export for the previous month. Keep all other settings as-is. This should auto-trigger a run and repeat for each month
        if ($Backfill -gt 0)
        {
            Write-Host "Running backfill for $backfill month$(if ($backfill -gt 1) { 's' })"
            $counter = 1
            do
            {
                Write-Verbose "Month $counter of $backfill"
                $startofcurrentmonth = [datetime]$(Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0 -AsUTC).ToString("yyyy-MM-dd")
                $startofpreviousmonth = $startofcurrentmonth.AddMonths($counter * -1)
                $endofpreviousmonth = $startofpreviousmonth.AddMonths(1).AddMilliseconds($counter * -1).ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
                $startofpreviousmonth = $startofpreviousmonth.ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'")
            
                Write-Verbose "Running backfill export from $startofpreviousmonth to $endofpreviousmonth"
                $backfillSuccess = Start-FinOpsCostExport -Name $Name -Scope $Scope -StartDate $startofpreviousmonth -EndDate $endofpreviousmonth
                if (-not $backfillSuccess)
                {
                    # TODO: Add detailed error -- Error: $($backfillResponse.Content.error.message) ($($backfillResponse.Content.error.code)).
                    Write-Error "Unable to run export for $startofpreviousmonth." -ErrorAction Continue
                }

                $counter += 1
                Start-Sleep 2
            } while ($counter -le $Backfill)
            Write-Verbose "Backfill complete"
        }
        # Loop thru $EndDate to $StartDate and export one month at a time

        if ($StartDate)
        {
            if ($EndDate)
            {
                $end = $EndDate
            }
            else
            {
                $end = $StartDate.AddDays([datetime]::DaysInMonth($StartDate.Year, $StartDate.Month) - $StartDate.Day)
            }
            $body = @{ timePeriod = @{ from = $StartDate.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"); to = $end.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") } }
        }
        Write-Verbose "Executing export $runpath"
        $response = Invoke-Rest -Method POST -Uri $runpath -Body $body -CommandName "Start-FinOpsCostExport"
        if ($response.Success)
        {
            Write-Verbose "Export executed successfully"
        }
        else
        {
            Write-Verbose "Export failed to execute"
        }
        return $response.Success
    }
}
