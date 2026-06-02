# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# -- Shared Runspace Pool --------------------------------------------------
# Created once at module load. Reused by Invoke-AzRestMethodWithRetry and
# Search-AzGraphSafe to avoid the ~1-2s cold-start per runspace creation.
if (-not $script:RunspacePool -or $script:RunspacePool.RunspacePoolStateInfo.State -ne 'Opened') {
    $script:RunspacePool = [runspacefactory]::CreateRunspacePool(1, 6)
    $script:RunspacePool.Open()
}

# -- Friendly throttle messages --------------------------------------------
# While waiting out a 429 rate limit, show a rotating, friendly status
# instead of a technical "throttled" notice. Shared by all retry paths.
if ($null -eq $script:ThrottleMsgIndex) { $script:ThrottleMsgIndex = 0 }
function Get-NextThrottleMessage {
    $msgs = @('Crunching numbers......', 'Fetching numbers......', 'Organizing costs......')
    $msg = $msgs[$script:ThrottleMsgIndex % $msgs.Count]
    $script:ThrottleMsgIndex++
    return $msg
}

# -- WPF Detection ---------------------------------------------------------
# When running standalone (no GUI), skip DispatcherFrame pumping and use
# simple Start-Sleep instead. This lets the same code work in both contexts.
function Test-WpfLoaded {
    try {
        $dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
        return ($null -ne $dispatcher -and
            -not $dispatcher.HasShutdownStarted -and
            [System.Windows.Application]::Current -ne $null)
    }
    catch { return $false }
}

function Wait-WithDispatcher {
    param([int]$Milliseconds)
    if (Test-WpfLoaded) {
        $waitEnd = (Get-Date).AddMilliseconds($Milliseconds)
        while ((Get-Date) -lt $waitEnd) {
            $frame = [System.Windows.Threading.DispatcherFrame]::new()
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action] { $frame.Continue = $false }
            )
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
            Start-Sleep -Milliseconds 100
        }
    }
    else {
        Start-Sleep -Milliseconds $Milliseconds
    }
}

function Wait-ForRunspace {
    param(
        [System.IAsyncResult]$AsyncResult,
        [int]$TimeoutSeconds = 60
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    if (Test-WpfLoaded) {
        while (-not $AsyncResult.IsCompleted -and (Get-Date) -lt $deadline) {
            $frame = [System.Windows.Threading.DispatcherFrame]::new()
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action] { $frame.Continue = $false }
            )
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
            Start-Sleep -Milliseconds 100
        }
    }
    else {
        while (-not $AsyncResult.IsCompleted -and (Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 200
        }
    }
}

function Invoke-AzRestMethodWithRetry {
    param(
        [string]$Path,
        [string]$Method = 'POST',
        [string]$Payload,
        [int]$MaxRetries = 3,
        [int]$TimeoutSeconds = 60
    )
    for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $script:RunspacePool
        [void]$ps.AddScript({
                param($p, $m, $pl)
                $params = @{ Path = $p; Method = $m; ErrorAction = 'Stop' }
                if ($pl) { $params['Payload'] = $pl }
                try {
                    $r = Invoke-AzRestMethod @params
                    $hdrs = @{}
                    if ($r.Headers) {
                        foreach ($k in $r.Headers.Keys) { $hdrs[$k] = $r.Headers[$k] }
                    }
                    [PSCustomObject]@{
                        StatusCode = $r.StatusCode
                        Content    = $r.Content
                        Headers    = $hdrs
                    }
                }
                catch {
                    # A transport-level failure ("An error occurred while sending
                    # the request", TLS/socket drop, token-acquisition error) has
                    # no HTTP status and would otherwise re-throw out of EndInvoke
                    # as a raw ErrorActionPreference=Stop exception. Surface it as
                    # a synthetic 503 so the caller degrades gracefully.
                    $msg = "$($_.Exception.Message)" -replace '[\\"]', "'"
                    [PSCustomObject]@{
                        StatusCode = 503
                        Content    = ('{"error":{"message":"' + $msg + '"}}')
                        Headers    = @{}
                    }
                }
            }).AddArgument($Path).AddArgument($Method).AddArgument($Payload)

        $asyncResult = $ps.BeginInvoke()
        Wait-ForRunspace -AsyncResult $asyncResult -TimeoutSeconds $TimeoutSeconds

        $resp = $null
        if ($asyncResult.IsCompleted) {
            try {
                $raw = $ps.EndInvoke($asyncResult)
                $resp = if ($raw -and $raw.Count -gt 0) { $raw[0] } else { $null }
            }
            catch {
                # Should be rare now that the runspace script catches internally,
                # but never let an EndInvoke failure bubble up as a raw
                # terminating error - degrade to a synthetic 503 instead.
                $ps.Dispose()
                Write-Warning "  REST call failed in runspace: $($_.Exception.Message)"
                return [PSCustomObject]@{
                    StatusCode = 503
                    Content    = '{"error":{"message":"Request failed (transport error)."}}'
                    Headers    = @{}
                }
            }
        }
        else {
            $ps.Stop()
            Write-Warning "  REST call timed out after $($TimeoutSeconds)s: $Method $Path"
            $ps.Dispose()
            return [PSCustomObject]@{ StatusCode = 408; Content = '{"error":{"message":"Request timed out"}}'; Headers = @{} }
        }

        $ps.Dispose()

        if (-not $resp) {
            $resp = [PSCustomObject]@{ StatusCode = 0; Content = $null; Headers = @{} }
        }
        if ($null -eq $resp.Content) {
            $resp = [PSCustomObject]@{ StatusCode = $resp.StatusCode; Content = '{}'; Headers = if ($resp.Headers) { $resp.Headers } else { @{} } }
        }

        if ($resp.StatusCode -ne 429) { return $resp }

        # Parse Retry-After header or default to exponential backoff
        $retryAfter = 10
        if ($resp.Headers -and $resp.Headers['Retry-After']) {
            $parsed = 0
            if ([int]::TryParse($resp.Headers['Retry-After'], [ref]$parsed)) {
                $retryAfter = [math]::Max($parsed, 5)
            }
        }
        else {
            $retryAfter = [math]::Min(10 * [math]::Pow(2, $attempt), 60)
        }
        $friendly = Get-NextThrottleMessage
        Write-Host "  $friendly" -ForegroundColor Yellow

        if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
            Update-ScanStatus $friendly
        }

        Wait-WithDispatcher -Milliseconds ($retryAfter * 1000)
    }
    return $resp
}
