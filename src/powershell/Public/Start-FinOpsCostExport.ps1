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
    Optional. Number of months to export the data for. Make note of throttling (429) errors. This is only run once. Failed exports are not re-attempted. Default = 0.

    .PARAMETER ApiVersion
    Optional. API version to use when calling the Cost Management Exports API. Default = 2023-07-01-preview.

    .EXAMPLE
    Start-FinopsCostExport -Name 'CostExport'

    Runs an export called 'CostExport' for the configured period on the subscription configured in Get-AzContext.

    .EXAMPLE
    Start-FinopsCostExport -Scope '/providers/Microsoft.Billing/billingAccounts/1234' -Name 'CostExport' -StartDate '2023-01-01' -EndDate '2023-12-31'

    Runs an export called 'CostExport' for a specific date range on the 1234 billing account.

    .EXAMPLE
    Start-FinopsCostExport -Scope '/providers/Microsoft.Billing/billingAccounts/1234/billingProfiles/5678' -Name 'CostExport' -Backfill 12

    Runs an export called 'CostExport' for the previous 12 months on the 5678 billing profile.

    .LINK
    https://aka.ms/ftk/Start-FinOpsCostExport
#>
function Start-FinOpsCostExport
{
    [OutputType([bool])]
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
        # TODO: Consider updating this to account for one-time exports where we should copy the start date from

        # If -StartDate is not set, assume the current month
        if (-not $StartDate)
        {
            $StartDate = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0 -AsUTC)
        }

        # If -EndDate is not set, assume 1 month
        if (-not $EndDate)
        {
            $EndDate = $StartDate.AddMonths(1).AddMilliseconds(-1)
        }

        # Move start date to account for the backfill period
        $StartDate = $StartDate.AddMonths($Backfill * -1)
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

    # Start measuring progress
    $progressActivity = "Running exports"
    $months = (($EndDate.Year - $StartDate.Year) * 12) + $EndDate.Month - $StartDate.Month + 1
    if ($months -lt 1) { $months = 1 } # Assume at least 1 month to avoid errors
    $estimatedSecPerMonth = 6 # Estimated time to trigger a single month export accounting for throttling (10 per minute)

    # Loop thru each month
    $monthToExport = 0
    $success = $true
    $body = $null
    if ($StartDate)
    {
        Write-Verbose "Exporting dates configured on the export definition"
    }
    else
    {
        Write-Verbose "Exporting $($StartDate) - $($EndDate)"
    }
    do
    {
        # Report progress
        if ($months -gt 1)
        {
            $percent = [Math]::Round((1.0 * $monthToExport / $months) * 100, 0)
            $remaining = $estimatedSecPerMonth * ($months - $monthToExport)
            Write-Progress `
                -Activity $progressActivity `
                -Status "$percent% complete - $monthToExport of $months months" `
                -PercentComplete $percent `
                -SecondsRemaining $remaining
        }

        if ($StartDate)
        {
            # If more than one month
            if ($months -gt 1)
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
            Write-Verbose "Executing $($firstDay.ToString("MMM d yyyy")) export $runpath"
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

        # If export throttled, wait 60 seconds and try again
        if ($response.Throttled)
        {
            Write-Verbose "Export request throttled. Waiting 60 seconds and retrying."

            # Report progress
            if ($months -gt 1)
            {
                Write-Progress `
                    -Activity $progressActivity `
                    -Status "$percent% complete - Throttled by Cost Management. Waiting 60 seconds." `

            }
            else
            {
                Write-Information "Requests are being throttled by Cost Management. Waiting 60 seconds and retrying..."
            }
            Start-Sleep -Seconds 60
        }
        else
        {
            # If not retrying, then track the success
            $success = $success -and $response.Success
        }

        $monthToExport += 1
    } while ($months -gt 1 -and $EndDate.AddMonths($monthToExport * -1) -ge $StartDate)

    if ($months -gt 1)
    {
        Write-Progress -Activity $progressActivity -Completed
    }
    return $success
}
