# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Search-AzGraphSafe {
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
                    elseif (-not $result) { throw $ps.Streams.Error[0].Exception }
                }
            }
            catch {
                if ($_.Exception.Message -match '429|throttl|Too Many Requests') { $is429 = $true }
                else { $ps.Dispose(); throw }
            }
        }
        else {
            $ps.Stop()
            Write-Warning "  Resource Graph query timed out after $($TimeoutSeconds)s"
        }

        $ps.Dispose()

        if (-not $is429) { return $result }

        # 429 retry wait
        $retryAfter = [math]::Min(10 * [math]::Pow(2, $attempt), 30)
        $friendly = if (Get-Command Get-NextThrottleMessage -ErrorAction SilentlyContinue) { Get-NextThrottleMessage } else { 'Crunching numbers......' }
        Write-Host "  $friendly" -ForegroundColor Yellow
        if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
            Update-ScanStatus $friendly
        }
        Wait-WithDispatcher -Milliseconds ($retryAfter * 1000)
    }
    return $null
}
