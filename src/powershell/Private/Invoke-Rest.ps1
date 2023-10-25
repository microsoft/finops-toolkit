# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Runs Invoke-AzRestMethod and provides output with error handling.

    .PARAMETER Path
    Path of target resource URL. Hostname of Resource Manager should not be added.

    .PARAMETER Method
    Http Method to invoke. Accepted values: GET, POST, PUT, PATCH, DELETE
    
    .PARAMETER Payload
    JSON format payload to pass with the request.

    .EXAMPLE
    Invoke-Rest -Path "subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/providers/Microsoft.CostManagement/exports/August2023OneTime?api-version=2023-08-01" -Method GET
    Invoke GET method against a target resource url.
#>
function Invoke-Rest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")]
        [string]
        $Method,
        
        [Parameter(Mandatory = $false)]
        [string]
        $Payload
    )
    
    $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    $ErrorActionPreference = $PSCmdlet.GetVariableValue('ErrorActionPreference') 
    Write-Verbose "Invoking $path, Method $Method Payload $Payload`n"

    try
    {
        if ($Payload) 
        {
            $httpResponse = Invoke-AzRestMethod -Path $Path -Method $Method -Payload $Payload -ErrorAction stop
        }
        else
        {
            $httpResponse = Invoke-AzRestMethod -Path $Path -Method $Method -ErrorAction stop
        }
    
        if ($httpResponse -and $($httpResponse.Content | ConvertFrom-Json).error)
        {
            $errorobject = $($httpResponse.Content | ConvertFrom-Json).error
            $errorcode = $errorobject.code
            $errorcodemessage = $errorobject.message
            Write-Error -Message $($script:localizedData.ErrorResponse -f $errorcodemessage, $errorcode)
        }
    return $httpResponse
    }
    catch 
        { 
            throw $_.Exception.Message
        }
}


