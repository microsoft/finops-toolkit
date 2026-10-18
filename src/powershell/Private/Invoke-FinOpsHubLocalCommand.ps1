# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Sends a single command or query to a local FinOps hub (Kusto emulator) HTTP endpoint.

    .DESCRIPTION
    Posts a management command or query to a running Kusto emulator over its REST API. Used by Initialize-FinOpsHubLocal to set up a local FinOps hub. This command does not manage the container; the emulator must already be running.

    .PARAMETER ClusterUri
    Required. Base URI of the running Kusto emulator (for example, http://localhost:8082).

    .PARAMETER Database
    Required. Name of the database to run the command against.

    .PARAMETER Command
    Required. The management command (starting with '.') or query to run.

    .PARAMETER Endpoint
    Optional. The REST endpoint to use: 'mgmt' for management commands (default) or 'query' for queries.

    .PARAMETER TimeoutSec
    Optional. Maximum number of seconds to wait for a response. Default = 0 (wait indefinitely).
#>
function Invoke-FinOpsHubLocalCommand
{
    [Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingEmptyCatchBlock", "", Justification="Not all failures have a JSON error body (for example, a connection failure); ignore parse errors and fall through to rethrow the original exception.")]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ClusterUri,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Database,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Command,

        [Parameter()]
        [ValidateSet('mgmt', 'query')]
        [string]
        $Endpoint = 'mgmt',

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $TimeoutSec = 0
    )

    $uri = '{0}/v1/rest/{1}' -f $ClusterUri.TrimEnd('/'), $Endpoint
    $body = @{ db = $Database; csl = $Command } | ConvertTo-Json -Compress

    try
    {
        return Invoke-RestMethod -Uri $uri -Method 'Post' -ContentType 'application/json' -Body $body -TimeoutSec $TimeoutSec -ErrorAction 'Stop'
    }
    catch
    {
        # Kusto returns a structured JSON error body. Surface its message/code when present;
        # otherwise rethrow the original exception (for example, a connection failure) as-is.
        $content = $null
        if ($null -ne $_.ErrorDetails -and -not [string]::IsNullOrWhiteSpace($_.ErrorDetails.Message))
        {
            try
            {
                $content = $_.ErrorDetails.Message | ConvertFrom-Json -Depth 10
            }
            catch {}
        }

        if ($null -ne $content -and $content.PSObject.Properties['error'])
        {
            $errorBody = $content.error
            throw ($script:LocalizedData.Common_ErrorResponse -f $errorBody.message, $errorBody.code)
        }

        throw
    }
}
