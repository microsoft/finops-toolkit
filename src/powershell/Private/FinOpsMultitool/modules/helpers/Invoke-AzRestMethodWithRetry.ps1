# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Changes only in-memory throttle bookkeeping for the current run.')]
param()

# -- Shared Runspace Pool --------------------------------------------------
# Created once at module load. Reused by Invoke-AzRestMethodWithRetry and
# Search-AzGraphSafe to avoid the ~1-2s cold-start per runspace creation.
if (-not $script:RunspacePool -or $script:RunspacePool.RunspacePoolStateInfo.State -ne 'Opened') {
    $script:RunspacePool = [runspacefactory]::CreateRunspacePool(1, 6)
    $script:RunspacePool.Open()
}

# -- Friendly throttle message ---------------------------------------------
# While waiting out a 429 rate limit, show a single friendly status instead
# of a technical "throttled" notice. Shared by all retry paths.
function Get-NextThrottleMessage {
    return 'Fetching numbers......'
}

# -- Cost Management throttle window ----------------------------------------
# Cost Management limits query and forecast requests per tenant. When it asks
# for a wait longer than a call will spend, every later call to the same API
# fails the same way until the window ends, so the window is remembered and
# those calls are skipped instead of repeated.
$script:CostMgmtThrottle = @{}
$script:CostMgmtLongDelaySeconds = 120

function Get-CostMgmtThrottleKey {
    param([string]$Path)

    if ($Path -match '(?i)/providers/Microsoft\.CostManagement/(query|forecast)(?:[?/]|$)') { return $Matches[1].ToLowerInvariant() }
    return $null
}

function Get-CostMgmtThrottleRemaining {
    param([string]$Key)

    if (-not $Key -or -not $script:CostMgmtThrottle.ContainsKey($Key)) { return 0.0 }
    return [math]::Max(0.0, ($script:CostMgmtThrottle[$Key].Until - [datetime]::UtcNow).TotalSeconds)
}

# When an open window ends, or $null when the API isn't throttled.
function Get-CostMgmtThrottleUntil {
    param([string]$Key)

    if ((Get-CostMgmtThrottleRemaining -Key $Key) -le 0) { return $null }
    return $script:CostMgmtThrottle[$Key].Until
}

function Format-CostMgmtThrottleTime {
    param([datetime]$Until)

    $format = if (($Until - [datetime]::UtcNow).TotalHours -gt 12) { 'yyyy-MM-dd HH:mm' } else { 'HH:mm' }
    return "$($Until.ToString($format, [cultureinfo]::InvariantCulture)) UTC"
}

# Longest delay the service asked for, in seconds, or -1 when it gave none.
function Get-ServerRetryDelay {
    param($Headers, [bool]$IsThrottled)

    $delay = -1
    if ($Headers) {
        foreach ($headerName in $Headers.Keys) {
            if ($headerName -ne 'Retry-After' -and -not ($IsThrottled -and $headerName -match '^x-ms-ratelimit-microsoft\.(costmanagement|consumption)(-.*)?-retry-after$')) { continue }
            foreach ($headerValue in @($Headers[$headerName])) {
                $parsed = 0
                if ([int]::TryParse([string]$headerValue, [ref]$parsed) -and $parsed -ge 0) {
                    $delay = [math]::Max($delay, $parsed)
                }
            }
        }
    }
    return $delay
}

function Register-CostMgmtThrottle {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][double]$Seconds
    )

    $until = [datetime]::UtcNow.AddSeconds($Seconds)
    if ((Get-CostMgmtThrottleRemaining -Key $Key) -gt 0) {
        if ($until -gt $script:CostMgmtThrottle[$Key].Until) { $script:CostMgmtThrottle[$Key].Until = $until }
        return
    }
    $skipped = if ($script:CostMgmtThrottle.ContainsKey($Key)) { $script:CostMgmtThrottle[$Key].Skipped } else { 0 }
    $script:CostMgmtThrottle[$Key] = @{ Until = $until; Skipped = $skipped }
    $minutes = [math]::Ceiling($Seconds / 60)
    $unit = if ($minutes -eq 1) { 'minute' } else { 'minutes' }
    Write-Warning "Cost Management is limiting this tenant's $Key requests and asked for a wait of about $minutes $unit (until $(Format-CostMgmtThrottleTime -Until $until)). That's longer than this scan waits, so the remaining $Key requests are skipped and the affected results are marked incomplete. Run the scan again after that time."
}

# Stands in for a call that isn't sent because its throttle window is still open.
function New-CostMgmtSkippedResponse {
    param([Parameter(Mandatory)][string]$Key)

    $window = $script:CostMgmtThrottle[$Key]
    $window.Skipped++
    $message = "Cost Management is limiting this tenant's $Key requests until about $(Format-CostMgmtThrottleTime -Until $window.Until). The request wasn't sent."
    return [PSCustomObject]@{
        StatusCode = 429
        Content    = (@{ error = @{ code = 'TooManyRequests'; message = $message } } | ConvertTo-Json -Compress)
        Headers    = @{ 'Retry-After' = @([string][math]::Ceiling((Get-CostMgmtThrottleRemaining -Key $Key))) }
    }
}

function Reset-CostMgmtThrottle {
    $script:CostMgmtThrottle = @{}
}

# Windows that skipped at least one request in this run, for report notes.
function Get-CostMgmtThrottleSummary {
    return @($script:CostMgmtThrottle.GetEnumerator() | Where-Object { $_.Value.Skipped -gt 0 } | Sort-Object Key | ForEach-Object {
            [PSCustomObject]@{ Api = $_.Key; UntilUtc = $_.Value.Until; SkippedRequests = $_.Value.Skipped }
        })
}

# -- WPF Detection ---------------------------------------------------------
# When running standalone (no GUI), skip DispatcherFrame pumping and use
# simple Start-Sleep instead. This lets the same code work in both contexts.
function Test-WpfLoaded {
    try {
        $dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
        return ($null -ne $dispatcher -and
            -not $dispatcher.HasShutdownStarted -and
            $null -ne [System.Windows.Application]::Current)
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
        [int]$TimeoutSeconds = 60,
        [ValidateRange(0, 3600)]
        [int]$MaxRetryWaitSeconds = 120
    )
    # An earlier call learned that Cost Management won't answer inside this call's wait budget.
    $throttleKey = Get-CostMgmtThrottleKey -Path $Path
    if ($throttleKey -and (Get-CostMgmtThrottleRemaining -Key $throttleKey) -gt $MaxRetryWaitSeconds) {
        return New-CostMgmtSkippedResponse -Key $throttleKey
    }
    $retryWaitSeconds = 0.0
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
                        foreach ($header in $r.Headers.GetEnumerator()) { $hdrs[$header.Key] = @($header.Value) }
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

        # 429 and transient 5xx are both retryable. 5xx also covers the synthetic
        # 503 this function raises for transport failures, which are the most
        # likely thing to succeed on a second attempt.
        $isThrottled = ($resp.StatusCode -eq 429)
        $isServerErr = ($resp.StatusCode -ge 500 -and $resp.StatusCode -le 599)
        if (-not ($isThrottled -or $isServerErr)) { return $resp }

        # Cost Management can return several throttle budgets; honor the longest server delay.
        $serverDelay = Get-ServerRetryDelay -Headers $resp.Headers -IsThrottled $isThrottled

        # A delay longer than any call here waits means later calls to this API fail the same way.
        if ($isThrottled -and $throttleKey -and $serverDelay -gt [math]::Max($MaxRetryWaitSeconds, $script:CostMgmtLongDelaySeconds)) {
            Register-CostMgmtThrottle -Key $throttleKey -Seconds $serverDelay
            return $resp
        }
        if ($attempt -eq $MaxRetries) { return $resp }
        if ($serverDelay -ge 0) {
            $retryAfter = Get-JitteredDelay -RetryAfterSeconds ([math]::Max($serverDelay, 5))
        }
        elseif ($isServerErr) {
            $retryAfter = Get-JitteredDelay -BaseSeconds ([math]::Min(2 * [math]::Pow(2, $attempt), 30))
        }
        else {
            $retryAfter = Get-JitteredDelay -BaseSeconds ([math]::Min(10 * [math]::Pow(2, $attempt), 60))
        }
        if ($retryAfter -gt ($MaxRetryWaitSeconds - $retryWaitSeconds)) {
            Write-Warning "Azure returned HTTP $($resp.StatusCode); retry requires $([math]::Ceiling($retryAfter)) seconds, exceeding the remaining retry wait budget. No early retry was sent."
            return $resp
        }
        $friendly = if ($isThrottled) { Get-NextThrottleMessage } else { "Azure returned $($resp.StatusCode) - retrying..." }
        Write-Host "  $friendly" -ForegroundColor Yellow

        if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
            Update-ScanStatus $friendly
        }

        Wait-WithDispatcher -Milliseconds ($retryAfter * 1000)
        $retryWaitSeconds += $retryAfter
    }
    return $resp
}
