# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

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
#
# ── Parameters ──────────────────────────────────────────────
# FirstResponse   The already-issued first-page response
# Context         Label used in warnings so a partial total is attributable
# MaxPages        Bounds a pathological nextLink chain
#
# Prerequisites:
# - Invoke-AzRestMethodWithRetry.ps1
###########################################################################

function Get-CostQueryResponsePage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$FirstResponse,

        [Parameter()]
        [string]$Context = 'cost query',

        [Parameter()]
        [int]$MaxPages = 50
    )

    $pages = [System.Collections.Generic.List[object]]::new()
    $resp = $FirstResponse
    $pageCount = 0

    while ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
        [void]$pages.Add($resp)
        $pageCount++

        $next = $null
        try { $next = ($resp.Content | ConvertFrom-Json).properties.nextLink }
        catch { $next = $null }
        if ([string]::IsNullOrWhiteSpace($next)) { break }

        if ($pageCount -ge $MaxPages) {
            Write-Warning "  $Context : stopped after $MaxPages pages; totals are incomplete."
            break
        }

        $resp = Invoke-AzRestMethodWithRetry -Path ([System.Uri]$next).PathAndQuery -Method GET
        # A failed continuation must be reported: silence here reads as lower cost.
        if (-not $resp -or $resp.StatusCode -ne 200) {
            $code = if ($resp) { [string]$resp.StatusCode } else { 'no response' }
            Write-Warning "  $Context : continuation page failed ($code); totals are incomplete."
            break
        }
    }

    return $pages
}
