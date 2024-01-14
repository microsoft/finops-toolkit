# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Initiates a Cost Management export run for the most recent period.

    .DESCRIPTION
    The Start-FinOpsCostExport command runs a Cost Management export for the most recent period using the Run API.

    .PARAMETER Name
    Required. Name of the export.

    .PARAMETER Scope
    Optional. Resource ID of the scope to export data for. If empty, defaults to current subscription context.

    .PARAMETER ApiVersion
    Optional. API version to use when calling the Cost Management Exports API. Default = 2023-03-01.

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
        [string]
        $ApiVersion = '2023-08-01'
    )

    $export = Get-FinOpsCostExport -Name $Name -Scope $Scope
    
    if (-not $export)
    {
        Write-Output "Export $Name not found. Did you specify the correct scope?"
    }
    else
    {
        $runpath = "$(export.Id)/run?api-version=$ApiVersion"
        Write-Verbose "Executing export $runpath"
        $executeresponse = Invoke-Rest -Path $runpath -Method POST
        if ($executeresponse.StatusCode -eq 200) 
        {
            Write-Verbose "Export executed successfully"
        }
    }
}
