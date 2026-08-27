# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# INVOKE-FOHUBKUSTOQUERY.PS1
# FINOPS HUB - KUSTO (ADX / FABRIC / FTKLOCAL) QUERY TRANSPORT
###########################################################################
# Purpose: Execute a KQL query against a FinOps Hub database and return
#          only the (already-summarized) result rows. This is the scalable
#          hub path: aggregation is pushed into the engine so PowerShell
#          never materializes tens of GB / hundreds of millions of rows.
# Date: Created for FinOps Multitool scalable hub data path
#
# Description:
# Thin REST transport over the Kusto query endpoint (POST {cluster}/v1/rest/query):
# 1. Works against a deployed Azure Data Explorer / Fabric cluster (with a
#    bearer token) AND a local ftklocal Kusto emulator (anonymous, no token).
# 2. Sends { db, csl } and parses the v1 response, mapping the primary
#    result table's columns + rows into PSCustomObjects keyed by column name.
# 3. Returns a small wrapper ({ Ok; Rows; RowCount; Error }) so callers can
#    branch without try/catch. No Az.Kusto module / SDK dependency.
#
# ── Parameters ──────────────────────────────────────────────────
# ClusterUri    Cluster query URI (e.g. https://<name>.<region>.kusto.windows.net
#               or http://localhost:8082 for the ftklocal emulator)
# Query         KQL query text (csl). Should already aggregate/summarize.
# Database      Hub database name (default 'Hub' - the FinOps Hub cost db)
# AccessToken   Optional bearer token. Omit for an anonymous local emulator.
# TimeoutSec    Per-request timeout (default 120)
#
# Prerequisites:
# - Network reachability to the cluster query endpoint
# - For a deployed cluster: a token from Get-PlainAccessToken -ResourceUrl <clusterUri>
#
# Usage:
#   $r = Invoke-FOHubKustoQuery -ClusterUri $uri -Database 'Hub' `
#          -Query 'Costs_v1_2() | summarize Cost=sum(EffectiveCost)'
#   if ($r.Ok) { $r.Rows | ForEach-Object { $_.Cost } }
###########################################################################

function Invoke-FOHubKustoQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ClusterUri,

        [Parameter(Mandatory)]
        [string]$Query,

        [Parameter()]
        [string]$Database = 'Hub',

        [Parameter()]
        [string]$AccessToken,

        [Parameter()]
        [int]$TimeoutSec = 120
    )

    if ([string]::IsNullOrWhiteSpace($ClusterUri)) {
        return @{ Ok = $false; Rows = @(); RowCount = 0; Error = 'ClusterUri is required.' }
    }

    $base = $ClusterUri.TrimEnd('/')
    $uri = "$base/v1/rest/query"

    $headers = @{
        'Content-Type' = 'application/json'
        'Accept'       = 'application/json'
    }
    if (-not [string]::IsNullOrWhiteSpace($AccessToken)) {
        $headers['Authorization'] = "Bearer $AccessToken"
    }

    $body = @{ db = $Database; csl = $Query } | ConvertTo-Json -Depth 3

    try {
        $resp = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body `
            -TimeoutSec $TimeoutSec -ErrorAction Stop

        # v1 response: { Tables: [ { TableName, Columns:[{ColumnName,...}], Rows:[[...]] } ] }
        # The primary result set is the first table.
        $table = $null
        if ($resp.Tables -and @($resp.Tables).Count -gt 0) {
            $table = @($resp.Tables)[0]
        }
        if (-not $table) {
            return @{ Ok = $true; Rows = @(); RowCount = 0; Error = $null }
        }

        $colNames = @($table.Columns | ForEach-Object { $_.ColumnName })
        $rows = foreach ($r in @($table.Rows)) {
            $obj = [ordered]@{}
            for ($i = 0; $i -lt $colNames.Count; $i++) {
                $obj[$colNames[$i]] = $r[$i]
            }
            [PSCustomObject]$obj
        }
        $rows = @($rows)

        return @{ Ok = $true; Rows = $rows; RowCount = $rows.Count; Error = $null }
    }
    catch {
        $msg = $_.Exception.Message
        # Surface the Kusto error body when present (one-api error envelope).
        $detail = $null
        try {
            $respStream = $_.Exception.Response.GetResponseStream()
            if ($respStream) {
                $reader = New-Object System.IO.StreamReader($respStream)
                $detail = $reader.ReadToEnd()
                $reader.Dispose()
            }
        }
        catch { }
        if ($detail) {
            try {
                $err = $detail | ConvertFrom-Json -ErrorAction Stop
                if ($err.error -and $err.error.'@message') { $msg = $err.error.'@message' }
                elseif ($err.error -and $err.error.message) { $msg = $err.error.message }
            }
            catch { }
        }
        return @{ Ok = $false; Rows = @(); RowCount = 0; Error = "Kusto query failed: $msg" }
    }
}
