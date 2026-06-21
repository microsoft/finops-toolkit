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
#>
function Invoke-FinOpsHubLocalCommand
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]
        $ClusterUri,

        [Parameter(Mandatory)]
        [string]
        $Database,

        [Parameter(Mandatory)]
        [string]
        $Command,

        [Parameter()]
        [ValidateSet('mgmt', 'query')]
        [string]
        $Endpoint = 'mgmt'
    )

    $uri = '{0}/v1/rest/{1}' -f $ClusterUri.TrimEnd('/'), $Endpoint
    $body = @{ db = $Database; csl = $Command } | ConvertTo-Json -Compress
    return Invoke-RestMethod -Uri $uri -Method 'Post' -ContentType 'application/json' -Body $body
}
