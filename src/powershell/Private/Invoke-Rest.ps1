# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Executes an HTTP REST API and provides output with error handling.

    .PARAMETER Method
    Required. HTTP Method to invoke. Accepted values: GET, POST, PUT, PATCH, DELETE

    .PARAMETER Uri
    Required. URI of target resource or operation. Do not include the Azure Resource Manager domain.

    .PARAMETER Body
    Optional. HTTP request body.

    .PARAMETER CommandName
    Required. Name of the PowerShell command being run. This is included in backend telemetry.

    .PARAMETER ParameterSetName
    Optional. Name of the PowerShell parameter set being used. This is included in backend telemetry.

    .EXAMPLE
    Invoke-Rest -Method GET -Uri "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/providers/Microsoft.CostManagement/exports/August2023OneTime?api-version=2023-08-01"

    Invoke GET method against a target resource URI.
#>
function Invoke-Rest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")]
        [System.ComponentModel.DefaultValueAttribute("GET")]
        [string]
        $Method = "GET",
        
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet("Azure", "Fabric")]
        [System.ComponentModel.DefaultValueAttribute("Azure")]
        [string]
        $Service = "Azure",
        
        [Parameter(Mandatory = $true, Position = 2)]
        [string]
        $Uri,
        
        [Parameter()]
        [PSCustomObject]
        $Body,
        
        [Parameter(Mandatory = $true)]
        [string]
        $CommandName,

        [Parameter()]
        [string]
        $ParameterSetName
    )

    $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    $ErrorActionPreference = $PSCmdlet.GetVariableValue('ErrorActionPreference')

    $ver = 'unknown'
    try { $ver = Get-VersionNumber } catch {}

    # Build API parameters
    $env = (Get-AzContext).Environment
    if ($Service -eq 'Fabric')
    {
        $fabricUrls = @{
            default = @{
                resource = 'https://api.fabric.microsoft.com'
                endpoint = 'https://api.fabric.microsoft.com/v1'
            }
        }
        # TODO: Map Azure to Fabric environment
        # $token = (Get-PowerBIAccessToken).Token.Value.Trim('Bearer ')
        $resourceUri = $fabricUrls.default.resource
        $token = (Get-AzAccessToken -ResourceUrl $resourceUri).Token
        $domain = $fabricUrls.default.endpoint
    }
    else
    {
        $token = (Get-AzAccessToken).Token
        $domain = $env.ResourceManagerUrl
    }
    $params = @{
        Method      = $Method
        Uri         = $domain.Trim('/') + '/' + $Uri.Trim('/')
        Headers     = @{
            Authorization             = "Bearer $token"
            ClientType                = "FinOpsToolkit.PowerShell.$CommandName@$ver"
            'Content-Type'            = 'application/json'
            'x-ms-command-name'       = "FinOpsToolkit.PowerShell.$CommandName@$ver"
            'x-ms-parameter-set-name' = $ParameterSetName
        }
        ErrorAction = 'Stop'
    }
    if ($Body)
    {
        $params.Body = $Body | ConvertTo-Json -Depth 100
    }
    
    try
    {
        Write-Verbose "Invoking $Method $($params.Uri) with request body $($params.Body)`n"
        $response = Invoke-WebRequest @params
        $content = $response.Content | ConvertFrom-Json -Depth 100
    }
    catch
    {
        Write-Verbose "Error invoking $Method $($params.Uri) with request body $($params.Body)"
        $response = $_.Exception.Response
        $content = $_.ErrorDetails.Message | ConvertFrom-Json -Depth 10
        # DEBUG: Write-Verbose "Exception.Response = $($response | ConvertTo-Json -Depth 10)"
        # DEBUG: Write-Verbose "ErrorDetails.Message = $($content | ConvertTo-Json -Depth 10)"
        if ($content.error)
        {
            $errorCode = $content.error.code
            $errorMessage = $content.error.message
            Write-Error -Message ($script:localizedData.Common_ErrorResponse -f $errorMessage, $errorCode)
        }
        elseif ($content.moreDetails.Count -gt 0)
        {
            $content.moreDetails | ForEach-Object {
                $errorCode = $_.errorCode
                $errorMessage = $_.message
                Write-Host -Message ($script:localizedData.Common_ErrorResponse -f $errorMessage, $errorCode)
                Write-Error -Message ($script:localizedData.Common_ErrorResponse -f $errorMessage, $errorCode)
            }
        }
        elseif ($content.errorCode)
        {
            $errorCode = $content.errorCode
            $errorMessage = $content.message
            Write-Error -Message ($script:localizedData.Common_ErrorResponse -f $errorMessage, $errorCode)
        }
        else
        {
            throw $_.Exception.Message
        }
    }
    return @{
        Headers    = $response.Headers
        StatusCode = $response.StatusCode
        Success    = $response.StatusCode -ge 200 -and $response.StatusCode -lt 300
        Failure    = $response.StatusCode -ge 300
        NotFound   = $response.StatusCode -eq 404 -or $response.StatusCode -eq 'NotFound'
        Content    = $content
    }
}


