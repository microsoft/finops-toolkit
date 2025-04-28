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
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")]
        [string]
        $Method,
        
        [Parameter(Mandatory = $true, Position = 1)]
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

    Write-Verbose -Message "Get access token for the $Method $Uri request"
    
    if ($Uri -like '/*')
    {
        $accessToken = (Get-AzAccessToken -AsSecureString).Token | ConvertFrom-SecureString -AsPlainText
        $arm = (Get-AzContext).Environment.ResourceManagerUrl
        $fullUri = $arm.Trim('/') + '/' + $Uri.Trim('/')
    }
    elseif ($Uri -like 'https://api.powerbi.com/*')
    {
        $accessToken = (Get-AzAccessToken -AsSecureString -ResourceUrl 'https://graph.microsoft.com').Token | ConvertFrom-SecureString -AsPlainText
        $fullUri = $Uri
    }
    else
    {
        $accessToken = (Get-AzAccessToken -AsSecureString -ResourceUrl "https://$($Uri.Split('/')[2])").Token | ConvertFrom-SecureString -AsPlainText
        $fullUri = $Uri
    }

    $params = @{
        Method      = $Method
        Uri         = $fullUri
        Headers     = @{
            Authorization             = "Bearer $accessToken"
            ClientType                = "FinOpsToolkit.PowerShell.$CommandName@$ver"
            "Content-Type"            = 'application/json'
            "x-ms-command-name"       = "FinOpsToolkit.PowerShell.$CommandName@$ver"
            "x-ms-parameter-set-name" = $ParameterSetName
        }
        ErrorAction = "Stop"
    }
    if ($Body)
    {
        $params.Body = $Body | ConvertTo-Json -Depth 100
    }
    
    Write-Verbose "Invoking $Method $fullUri with request body $Body`n"

    try
    {
        $response = Invoke-WebRequest @params
        $content = $response.Content | ConvertFrom-Json -Depth 100
    }
    catch
    {
        $response = $_.Exception.Response
        try
        {
            $content = $_.ErrorDetails.Message | ConvertFrom-Json -Depth 10
        }
        catch {}

        if ($content.error)
        {
            $errorCode = $content.error.code
            $errorMessage = $content.error.message
            Write-Error -Message $($script:localizedData.Common_ErrorResponse -f $errorMessage, $errorCode)
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
        Throttled  = $response.StatusCode -eq 429 -or $response.StatusCode -eq 'ResourceRequestsThrottled'
        Content    = $content
    }
}


