# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Private helper; the returned shape varies by query and is not a declared contract.')]
param()

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

    try {
        $endpoint = Resolve-FinOpsRequestUri -Uri $ClusterUri -AllowAnonymousLoopback:([string]::IsNullOrWhiteSpace($AccessToken))
        if ($endpoint.Query) { throw 'The cluster URL cannot contain a query string.' }
    }
    catch { return @{ Ok = $false; Rows = @(); RowCount = 0; Error = $_.Exception.Message } }
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
            -TimeoutSec $TimeoutSec -MaximumRedirection 0 -ErrorAction Stop

        if (($resp -isnot [System.Collections.IDictionary] -and $resp -isnot [PSCustomObject]) -or
            $resp.Tables -isnot [System.Collections.IList]) {
            throw 'The Kusto response does not contain a valid Tables array.'
        }

        # Validate every table, including query status, before returning the primary rows.
        $tables = [System.Collections.Generic.List[object]]::new()
        $statusIndexes = [System.Collections.Generic.HashSet[int]]::new()
        for ($tableIndex = 0; $tableIndex -lt $resp.Tables.Count; $tableIndex++) {
            $table = $resp.Tables[$tableIndex]
            if (($table -isnot [System.Collections.IDictionary] -and $table -isnot [PSCustomObject]) -or
                $table.Columns -isnot [System.Collections.IList] -or $table.Rows -isnot [System.Collections.IList]) {
                throw 'The Kusto response contains an invalid table.'
            }
            if ($null -ne $table.TableName -and $table.TableName -isnot [string]) {
                throw 'The Kusto response contains an invalid table name.'
            }
            $columnNames = [System.Collections.Generic.List[string]]::new()
            $seenNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($column in $table.Columns) {
                if ($column -isnot [System.Collections.IDictionary] -and $column -isnot [PSCustomObject]) {
                    throw 'The Kusto response contains an invalid column descriptor.'
                }
                $columnName = $column.ColumnName
                if ($columnName -isnot [string] -or [string]::IsNullOrWhiteSpace($columnName) -or -not $seenNames.Add($columnName)) {
                    throw 'The Kusto response contains a missing or duplicate column name.'
                }
                $columnNames.Add($columnName)
            }
            $mappedRows = [System.Collections.Generic.List[object]]::new()
            foreach ($row in $table.Rows) {
                if ($row -isnot [System.Collections.IList] -or $row.Count -ne $table.Columns.Count) {
                    throw 'The Kusto response contains a row that does not match its columns.'
                }
                $values = [ordered]@{}
                for ($columnIndex = 0; $columnIndex -lt $columnNames.Count; $columnIndex++) {
                    $values[$columnNames[$columnIndex]] = $row[$columnIndex]
                }
                $mappedRows.Add([PSCustomObject]$values)
            }
            $tables.Add([PSCustomObject]@{ Columns = $columnNames.ToArray(); Rows = $mappedRows.ToArray() })
            if ($table.TableName -eq 'QueryStatus' -or
                ($tableIndex -gt 0 -and $seenNames.Contains('Severity') -and $seenNames.Contains('StatusDescription'))) {
                $null = $statusIndexes.Add($tableIndex)
            }
        }
        if ($tables.Count -gt 1) {
            $contents = $tables[$tables.Count - 1]
            if ($contents.Columns -contains 'Ordinal' -or $contents.Columns -contains 'Kind' -or
                $resp.Tables[$tables.Count - 1].TableName -eq 'TableOfContents') {
                if ($contents.Columns -notcontains 'Ordinal' -or $contents.Columns -notcontains 'Kind' -or $contents.Columns -notcontains 'Name') {
                    throw 'The Kusto response contains an incomplete table-of-contents schema.'
                }
                foreach ($entry in $contents.Rows) {
                    if ($entry.Kind -isnot [string] -or $entry.Name -isnot [string]) {
                        throw 'The Kusto response contains an invalid table-of-contents entry.'
                    }
                    if ($entry.Kind -ne 'QueryStatus') { continue }
                    if (($entry.Ordinal -isnot [int] -and $entry.Ordinal -isnot [long]) -or
                        $entry.Ordinal -lt 0 -or $entry.Ordinal -ge ($tables.Count - 1)) {
                        throw 'The Kusto response contains an invalid query-status table reference.'
                    }
                    $null = $statusIndexes.Add([int]$entry.Ordinal)
                }
            }
        }
        foreach ($statusIndex in $statusIndexes) {
            $statusTable = $tables[$statusIndex]
            if ($statusTable.Columns -notcontains 'Severity' -or $statusTable.Rows.Count -eq 0) {
                throw 'The Kusto response contains an invalid query status.'
            }
            foreach ($status in $statusTable.Rows) {
                if ($status.Severity -isnot [int] -and $status.Severity -isnot [long]) {
                    throw 'The Kusto response contains an invalid query severity.'
                }
                if ($status.Severity -le 2) { throw "The Kusto response reports a partial query failure: $($status.StatusDescription)" }
            }
        }
        $rows = @()
        if ($tables.Count) { $rows = @($tables[0].Rows) }

        return @{ Ok = $true; Rows = $rows; RowCount = $rows.Count; Error = $null }
    }
    catch {
        $msg = $_.Exception.Message
        # Surface the Kusto error body when present (one-api error envelope).
        $detail = $_.ErrorDetails.Message
        if (-not $detail) {
            try {
                $respStream = $_.Exception.Response.GetResponseStream()
                if ($respStream) {
                    $reader = New-Object System.IO.StreamReader($respStream)
                    $detail = $reader.ReadToEnd()
                    $reader.Dispose()
                }
            }
            catch {
                Write-Verbose "Non-fatal: $($_.Exception.Message)"
            }
        }
        if ($detail) {
            try {
                $err = $detail | ConvertFrom-Json -ErrorAction Stop
                if ($err.error -and $err.error.'@message') { $msg = $err.error.'@message' }
                elseif ($err.error -and $err.error.message) { $msg = $err.error.message }
            }
            catch {
                Write-Verbose "Non-fatal: $($_.Exception.Message)"
            }
        }
        return @{ Ok = $false; Rows = @(); RowCount = 0; Error = "Kusto query failed: $msg" }
    }
}
