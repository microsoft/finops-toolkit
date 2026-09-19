# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Private helper; the returned shape varies by scan and is not a declared contract.')]
param()

###########################################################################
# GET-COSTQUERYRESPONSEPAGE.PS1
# COST MANAGEMENT QUERY PAGINATION
###########################################################################
# Purpose: Follow the Cost Management query API's nextLink and return every
#          page, so a caller that sums rows sees the whole result set.
# Date: Created for FinOps Multitool
#
# Description:
# The Cost Management query API returns one page at a time. A subscription
# with a large resource footprint therefore reports only its first page
# unless nextLink is followed, and the shortfall looks like lower cost
# rather than like an error.
#
# Returns the raw response objects rather than parsed rows, because callers
# read the payload differently (column-index lookups, row parsers).
# Throws without returning pages if the response chain is incomplete.
#
# ── Parameters ──────────────────────────────────────────────
# FirstResponse   The already-issued first-page response
# Context         Label used in errors so a failed query is attributable
# Payload         Original POST body for cost query and forecast continuations
# MaxPages        Bounds a pathological nextLink chain
#
# Prerequisites:
# - Invoke-AzRestMethodWithRetry.ps1
###########################################################################

function Resolve-NextLinkPath {
    # nextLink comes from the service, so it is not trusted input. A relative or
    # malformed value silently yields an empty PathAndQuery rather than throwing,
    # and an absolute URL on another host would be rewritten onto the ARM host.
    # Accept a rooted relative path, or an absolute https URL on the ARM endpoint
    # for the cloud the caller is signed in to.
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$NextLink
    )

    if ([string]::IsNullOrWhiteSpace($NextLink)) { return $null }
    $trimmed = $NextLink.Trim()
    if ($trimmed.StartsWith('//') -or $trimmed.Contains('\')) { return $null }
    if ($trimmed.StartsWith('/')) { return $trimmed }

    $uri = $null
    if (-not [System.Uri]::TryCreate($trimmed, [System.UriKind]::Absolute, [ref]$uri)) { return $null }
    if ($uri.Scheme -ne 'https') { return $null }

    $armHost = $null
    try { $armHost = ([System.Uri](Get-FinOpsArmEndpoint)).Host } catch { $armHost = 'management.azure.com' }
    if ($uri.Host -ne $armHost) { return $null }

    return $uri.PathAndQuery
}

function Get-CostQueryResponsePage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$FirstResponse,

        [Parameter()]
        [string]$Context = 'cost query',

        [Parameter()]
        [string]$Payload,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$MaxPages = 50,

        # The Cost Management query API nests nextLink under properties, while
        # the Consumption and benefit list APIs return it at the root.
        [Parameter()]
        [switch]$RootNextLink
    )

    $pages = [System.Collections.Generic.List[object]]::new()
    $resp = $FirstResponse
    $pageCount = 0
    $firstColumns = $null
    $visitedLinks = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    while ($true) {
        $pageCount++
        if (-not $resp -or $resp.StatusCode -ne 200) {
            $code = if ($resp) { [string]$resp.StatusCode } else { 'no response' }
            throw "$Context : page $pageCount failed ($code); results are incomplete."
        }
        if ([string]::IsNullOrWhiteSpace($resp.Content)) {
            throw "$Context : page $pageCount has no content; results are incomplete."
        }

        try {
            $parsed = $resp.Content | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "$Context : page $pageCount contains invalid JSON; results are incomplete."
        }
        if ($RootNextLink) {
            if ($parsed.value -isnot [array]) {
                throw "$Context : page $pageCount is missing its value array; results are incomplete."
            }
            $next = $parsed.nextLink
        }
        else {
            if ($parsed.properties.rows -isnot [array] -or $parsed.properties.columns -isnot [array]) {
                throw "$Context : page $pageCount is missing query rows or columns; results are incomplete."
            }
            $pageColumns = ConvertTo-Json -InputObject @($parsed.properties.columns | Select-Object name, type) -Depth 4 -Compress
            if ($null -ne $firstColumns -and $pageColumns -ne $firstColumns) {
                throw "$Context : columns changed on page $pageCount; results are incomplete."
            }
            $firstColumns = $pageColumns
            $costIndexes = @(
                for ($columnIndex = 0; $columnIndex -lt $parsed.properties.columns.Count; $columnIndex++) {
                    if ($parsed.properties.columns[$columnIndex].name -in @('Cost', 'PreTaxCost', 'CostUSD', 'TotalCost')) { $columnIndex }
                }
            )
            if ($parsed.properties.rows.Count -gt 0 -and $costIndexes.Count -eq 0) {
                throw "$Context : page $pageCount is missing a cost column; results are incomplete."
            }
            foreach ($row in $parsed.properties.rows) {
                if ($row -isnot [array] -or $row.Count -ne $parsed.properties.columns.Count) {
                    throw "$Context : page $pageCount contains an invalid row; results are incomplete."
                }
                foreach ($costIndex in $costIndexes) {
                    $amount = 0.0
                    if (-not [double]::TryParse([string]$row[$costIndex], [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$amount) -or
                        [double]::IsNaN($amount) -or [double]::IsInfinity($amount)) {
                        throw "$Context : page $pageCount contains an invalid cost; results are incomplete."
                    }
                }
            }
            $next = $parsed.properties.nextLink
        }

        [void]$pages.Add($resp)
        if ([string]::IsNullOrWhiteSpace($next)) { break }

        $nextPath = Resolve-NextLinkPath -NextLink $next
        if (-not $nextPath) {
            throw "$Context : page $pageCount contains an unexpected nextLink; results are incomplete."
        }
        if (-not $visitedLinks.Add($nextPath)) {
            throw "$Context : a continuation link repeated; results are incomplete."
        }

        if ($pageCount -ge $MaxPages) {
            throw "$Context : stopped after $MaxPages pages; results are incomplete."
        }

        if (-not $RootNextLink -and [string]::IsNullOrWhiteSpace($Payload)) {
            throw "$Context : the original POST payload is required for pagination; results are incomplete."
        }
        try {
            $resp = if ($RootNextLink) {
                Invoke-AzRestMethodWithRetry -Path $nextPath -Method GET
            }
            else {
                Invoke-AzRestMethodWithRetry -Path $nextPath -Method POST -Payload $Payload
            }
        }
        catch {
            throw "$Context : continuation request failed; results are incomplete. $($_.Exception.Message)"
        }
    }

    return $pages
}

function Get-CostQueryResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$FirstResponse,

        [Parameter(Mandatory)]
        [string]$Payload,

        [Parameter()]
        [string]$Context = 'cost query'
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    $columns = @()
    foreach ($page in (Get-CostQueryResponsePage -FirstResponse $FirstResponse -Payload $Payload -Context $Context)) {
        $result = $page.Content | ConvertFrom-Json -ErrorAction Stop
        $columns = $result.properties.columns
        foreach ($row in $result.properties.rows) { [void]$rows.Add($row) }
    }

    return [PSCustomObject]@{
        properties = [PSCustomObject]@{
            columns = $columns
            rows = $rows.ToArray()
            nextLink = $null
        }
    }
}
