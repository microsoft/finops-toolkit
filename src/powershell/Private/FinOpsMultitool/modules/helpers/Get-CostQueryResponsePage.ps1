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

        $nextPath = Resolve-NextLinkPath -NextLink $next
        if (-not $nextPath) {
            Write-Warning "  $Context : ignoring an unexpected nextLink; totals may be incomplete."
            break
        }

        if ($pageCount -ge $MaxPages) {
            Write-Warning "  $Context : stopped after $MaxPages pages; totals are incomplete."
            break
        }

        $resp = Invoke-AzRestMethodWithRetry -Path $nextPath -Method GET
        # A failed continuation must be reported: silence here reads as lower cost.
        if (-not $resp -or $resp.StatusCode -ne 200) {
            $code = if ($resp) { [string]$resp.StatusCode } else { 'no response' }
            Write-Warning "  $Context : continuation page failed ($code); totals are incomplete."
            break
        }
    }

    return $pages
}
