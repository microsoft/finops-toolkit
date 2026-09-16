# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
param()

# Escapes a caller-supplied value for safe use inside a single-quoted KQL
# string literal. KQL uses backslash escapes, so \ and ' must both be escaped
# or a crafted value could terminate the literal and alter query semantics.
function ConvertTo-KqlLiteral {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return $Value.Replace('\', '\\').Replace("'", "\'")
}

function Search-AzGraphSafe {
    param(
        [Parameter(Mandatory)][string]$Query,
        [string[]]$Subscription,
        [int]$First = 1000,
        [string]$SkipToken,
        [int]$TimeoutSeconds = 60,
        [int]$MaxRetries = 2,
        [switch]$All,
        [int]$MaxPages = 100
    )

    if (-not $All) {
        return Invoke-AzGraphQueryPage -Query $Query -Subscription $Subscription -First $First `
            -SkipToken $SkipToken -TimeoutSeconds $TimeoutSeconds -MaxRetries $MaxRetries
    }

    # Resource Graph caps a response at $First rows and hands back a continuation
    # token. A caller that totals rows without following that token reports a
    # truncated set as a complete one, which reads as "fewer resources" rather
    # than as an error. -All follows the token and returns every row.
    $rows = [System.Collections.Generic.List[object]]::new()
    $token = $SkipToken
    $pageCount = 0

    do {
        $usedToken = $token
        $page = Invoke-AzGraphQueryPage -Query $Query -Subscription $Subscription -First $First `
            -SkipToken $usedToken -TimeoutSeconds $TimeoutSeconds -MaxRetries $MaxRetries

        if (-not $page) {
            # A first-page failure keeps the existing contract: callers treat
            # $null as "the query failed". Losing a later page is different -
            # we have partial data, so say so rather than total it silently.
            if ($pageCount -eq 0) { return $null }
            Write-Warning "  Resource Graph continuation failed after $pageCount page(s); results are incomplete."
            break
        }

        if ($page.Data) { $rows.AddRange(@($page.Data)) }
        $token = $page.SkipToken
        $pageCount++

        # A token that does not advance would re-request the page we just added.
        if ($token -and $usedToken -and $token -eq $usedToken) {
            Write-Warning "  Resource Graph returned the same continuation token twice; stopping rather than repeating a page. Results are incomplete."
            break
        }

        if ($token -and $pageCount -ge $MaxPages) {
            Write-Warning "  Resource Graph query stopped after $MaxPages pages ($($rows.Count) rows); results are incomplete."
            break
        }
    } while ($token)

    return [PSCustomObject]@{
        Data      = @($rows)
        SkipToken = $null
        Count     = $rows.Count
    }
}

# A single Resource Graph request with retry and backoff. Kept separate from the
# paging loop so that loop can be exercised without issuing live queries.
function Invoke-AzGraphQueryPage {
    param(
        [Parameter(Mandatory)][string]$Query,
        [string[]]$Subscription,
        [int]$First = 1000,
        [string]$SkipToken,
        [int]$TimeoutSeconds = 60,
        [int]$MaxRetries = 2
    )

    for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $script:RunspacePool
        [void]$ps.AddScript({
                param($q, $s, $f, $st)
                $p = @{ Query = $q; Subscription = $s; First = $f; ErrorAction = 'Stop' }
                if ($st) { $p['SkipToken'] = $st }
                $r = Search-AzGraph @p
                $json = if ($r.Data -and $r.Data.Count -gt 0) {
                    $r.Data | ConvertTo-Json -Depth 20 -Compress
                }
                else { '[]' }
                [PSCustomObject]@{
                    JsonData  = $json
                    SkipToken = $r.SkipToken
                    Count     = if ($r.Data) { $r.Data.Count } else { 0 }
                }
            }).AddArgument($Query).AddArgument($Subscription).AddArgument($First).AddArgument($SkipToken)

        $asyncResult = $ps.BeginInvoke()
        Wait-ForRunspace -AsyncResult $asyncResult -TimeoutSeconds $TimeoutSeconds

        $result = $null
        $is429 = $false
        $isTransient = $false
        if ($asyncResult.IsCompleted) {
            try {
                $raw = $ps.EndInvoke($asyncResult)
                $wrapper = if ($raw -and $raw.Count -gt 0) { $raw[0] } else { $null }
                if ($wrapper) {
                    $data = if ($wrapper.JsonData -and $wrapper.JsonData -ne '[]') {
                        $parsed = $wrapper.JsonData | ConvertFrom-Json
                        if ($parsed -is [array]) { $parsed } else { @($parsed) }
                    }
                    else { @() }
                    $result = [PSCustomObject]@{
                        Data      = $data
                        SkipToken = $wrapper.SkipToken
                        Count     = $wrapper.Count
                    }
                }
                if ($ps.Streams.Error.Count -gt 0) {
                    $errMsg = $ps.Streams.Error[0].Exception.Message
                    if ($errMsg -match '429|throttl|Too Many Requests') { $is429 = $true; $result = $null }
                    elseif ($errMsg -match '\b50[0234]\b|ServiceUnavailable|InternalServerError|BadGateway|Gateway Timeout|temporarily unavailable') { $isTransient = $true; $result = $null }
                    elseif (-not $result) { throw $ps.Streams.Error[0].Exception }
                }
            }
            catch {
                if ($_.Exception.Message -match '429|throttl|Too Many Requests') { $is429 = $true }
                elseif ($_.Exception.Message -match '\b50[0234]\b|ServiceUnavailable|InternalServerError|BadGateway|Gateway Timeout|temporarily unavailable') { $isTransient = $true }
                else { $ps.Dispose(); throw }
            }
        }
        else {
            $ps.Stop()
            Write-Warning "  Resource Graph query timed out after $($TimeoutSeconds)s"
        }

        $ps.Dispose()

        if (-not ($is429 -or $isTransient)) { return $result }
        if ($attempt -eq $MaxRetries) { return $result }

        # Throttling backs off harder than a transient server error. Both are
        # jittered so parallel scans do not retry in lockstep.
        $retryAfter = if ($is429) {
            Get-JitteredDelay -BaseSeconds ([math]::Min(10 * [math]::Pow(2, $attempt), 30))
        }
        else {
            Get-JitteredDelay -BaseSeconds ([math]::Min(2 * [math]::Pow(2, $attempt), 15))
        }
        $friendly = if ($is429) {
            if (Get-Command Get-NextThrottleMessage -ErrorAction SilentlyContinue) { Get-NextThrottleMessage } else { 'Fetching numbers......' }
        }
        else {
            'Resource Graph is unavailable - retrying...'
        }
        Write-Host "  $friendly" -ForegroundColor Yellow
        if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
            Update-ScanStatus $friendly
        }
        Wait-WithDispatcher -Milliseconds ($retryAfter * 1000)
    }
    return $null
}
