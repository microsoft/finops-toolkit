###########################################################################
# TEST-MCPSERVER.PS1
# FINOPS MULTITOOL MCP SERVER TEST HARNESS
###########################################################################
# Purpose: End-to-end smoke + integration test for Start-McpServer.ps1.
#          Spawns the server as a child process, drives the JSON-RPC
#          lifecycle over stdio, and asserts on protocol, tools,
#          resources, a live Azure tool call, and error/edge paths.
# Author:  Zac Larsen
# Date:    Created for FinOps Toolkit MCP integration testing
#
# Description:
# 1. Starts Start-McpServer.ps1 with redirected stdin/stdout/stderr
# 2. Sends initialize / tools/list / resources/* requests and asserts
# 3. Runs a live tools/call against Azure (requires Connect-AzAccount)
# 4. Verifies error handling (unknown tool, bad resource, malformed JSON)
# 5. Prints a pass/fail summary and exits non-zero on any failure
#
# ── Parameters ──────────────────────────────────────────────────
# ServerPath         Path to Start-McpServer.ps1 (default: sibling file)
# LiveTool           Tool name to call live (default: scan_orphaned_resources)
# SubscriptionId     Optional subscription to scope the live call
# SkipLive           Skip the live Azure tool call (protocol-only run)
# TimeoutSeconds     Per-request response timeout (default: 120)
#
# Prerequisites:
# - PowerShell 7+ (pwsh)
# - Active Azure session (Connect-AzAccount) unless -SkipLive
#
# Usage: .\Test-McpServer.ps1
#        .\Test-McpServer.ps1 -SkipLive
#        .\Test-McpServer.ps1 -LiveTool scan_tag_inventory -SubscriptionId <guid>
###########################################################################

[CmdletBinding()]
param(
    [string]$ServerPath = (Join-Path $PSScriptRoot 'Start-McpServer.ps1'),
    [string]$LiveTool = 'scan_orphaned_resources',
    [string]$SubscriptionId,
    [switch]$SkipLive,
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'

$script:Pass = 0
$script:Fail = 0
$script:Failures = @()

function Write-TestResult {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) {
        $script:Pass++
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    }
    else {
        $script:Fail++
        $script:Failures += $Name
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor DarkYellow }
    }
}

function Invoke-Rpc {
    param(
        [System.Diagnostics.Process]$Proc,
        [string]$Json,
        [int]$Timeout = $TimeoutSeconds,
        [switch]$NoResponse
    )
    $Proc.StandardInput.WriteLine($Json)
    $Proc.StandardInput.Flush()
    if ($NoResponse) { return $null }

    $task = $Proc.StandardOutput.ReadLineAsync()
    if (-not $task.Wait([TimeSpan]::FromSeconds($Timeout))) {
        throw "Timed out waiting for response after ${Timeout}s"
    }
    $line = $task.Result
    if ($null -eq $line) { throw 'Server closed stdout unexpectedly' }
    return ($line | ConvertFrom-Json)
}

# =====================================================================
#  PRE-FLIGHT
# =====================================================================
Write-Host "FinOps Multitool MCP Server — Test Harness" -ForegroundColor Cyan
Write-Host ("=" * 60)

if (-not (Test-Path $ServerPath)) {
    Write-Host "Server script not found: $ServerPath" -ForegroundColor Red
    exit 2
}

if (-not $SkipLive) {
    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $ctx) {
        Write-Host "No active Azure context — live tool call will be skipped. Run Connect-AzAccount or pass -SkipLive." -ForegroundColor Yellow
        $SkipLive = $true
    }
    else {
        Write-Host "Azure context: $($ctx.Account.Id) | $($ctx.Subscription.Name)" -ForegroundColor DarkGray
    }
}

# =====================================================================
#  START SERVER PROCESS
# =====================================================================
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = 'pwsh'
$psi.ArgumentList.Add('-NoProfile')
$psi.ArgumentList.Add('-File')
$psi.ArgumentList.Add($ServerPath)
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false

$proc = [System.Diagnostics.Process]::Start($psi)
Start-Sleep -Milliseconds 500

try {
    # -----------------------------------------------------------------
    # 1. initialize
    # -----------------------------------------------------------------
    Write-Host "`nProtocol lifecycle" -ForegroundColor Cyan
    $r = Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}}}'
    Write-TestResult 'initialize returns serverInfo.name = finops-multitool' ($r.result.serverInfo.name -eq 'finops-multitool') "got: $($r.result.serverInfo.name)"
    Write-TestResult 'initialize returns protocolVersion 2024-11-05' ($r.result.protocolVersion -eq '2024-11-05') "got: $($r.result.protocolVersion)"

    # initialized notification (no response expected)
    Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","method":"notifications/initialized"}' -NoResponse | Out-Null

    # -----------------------------------------------------------------
    # 2. tools/list
    # -----------------------------------------------------------------
    $r = Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
    $toolCount = @($r.result.tools).Count
    Write-TestResult "tools/list returns 40 tools" ($toolCount -eq 40) "got: $toolCount"
    $hasSchema = @($r.result.tools | Where-Object { $_.inputSchema.type -eq 'object' }).Count -eq $toolCount
    Write-TestResult 'every tool has an object inputSchema' $hasSchema

    # -----------------------------------------------------------------
    # 3. resources/list + resources/read
    # -----------------------------------------------------------------
    Write-Host "`nResources" -ForegroundColor Cyan
    $r = Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","id":3,"method":"resources/list"}'
    Write-TestResult 'resources/list returns 2 resources' (@($r.result.resources).Count -eq 2) "got: $(@($r.result.resources).Count)"

    $r = Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","id":4,"method":"resources/read","params":{"uri":"finops://permissions"}}'
    $permOk = $false
    try { $null = $r.result.contents[0].text | ConvertFrom-Json; $permOk = $true } catch {}
    Write-TestResult 'resources/read finops://permissions returns valid JSON' $permOk

    $r = Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","id":5,"method":"resources/read","params":{"uri":"finops://modules"}}'
    $modOk = $false
    try { $null = $r.result.contents[0].text | ConvertFrom-Json; $modOk = $true } catch {}
    Write-TestResult 'resources/read finops://modules returns valid JSON' $modOk

    # -----------------------------------------------------------------
    # 4. error / edge paths
    # -----------------------------------------------------------------
    Write-Host "`nError handling" -ForegroundColor Cyan
    $r = Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","id":6,"method":"resources/read","params":{"uri":"finops://does-not-exist"}}'
    Write-TestResult 'unknown resource URI returns JSON-RPC error -32602' ($r.error.code -eq -32602) "got: $($r.error.code)"

    $r = Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","id":7,"method":"no/such/method"}'
    Write-TestResult 'unknown method returns JSON-RPC error -32601' ($r.error.code -eq -32601) "got: $($r.error.code)"

    $r = Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"definitely_not_a_tool","arguments":{}}}'
    Write-TestResult 'unknown tool call returns isError result' ($r.result.isError -eq $true)

    # malformed JSON should be skipped; server must survive and answer the next ping
    Invoke-Rpc -Proc $proc -Json '{ this is not valid json' -NoResponse | Out-Null
    $r = Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","id":9,"method":"ping"}'
    Write-TestResult 'server survives malformed JSON and answers ping' ($null -ne $r.result)

    # spec-legal STRING id must be echoed back verbatim (not coerced to int) and
    # must not crash the read loop. Regression guard for the [int]$Id id bug.
    $r = Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","id":"abc-123","method":"ping"}'
    Write-TestResult 'string JSON-RPC id is echoed back verbatim' ($r.id -eq 'abc-123') "got: $($r.id)"
    $r = Invoke-Rpc -Proc $proc -Json '{"jsonrpc":"2.0","id":11,"method":"ping"}'
    Write-TestResult 'server survives a string-id request and answers the next ping' ($null -ne $r.result)

    # -----------------------------------------------------------------
    # 5. live tool call (requires Azure)
    # -----------------------------------------------------------------
    Write-Host "`nLive Azure tool call" -ForegroundColor Cyan
    if ($SkipLive) {
        Write-Host "  [SKIP] live tool call ($LiveTool) — no Azure context or -SkipLive set" -ForegroundColor Yellow
    }
    else {
        $argJson = if ($SubscriptionId) { "{`"subscriptionId`":`"$SubscriptionId`"}" } else { '{}' }
        $callJson = "{`"jsonrpc`":`"2.0`",`"id`":10,`"method`":`"tools/call`",`"params`":{`"name`":`"$LiveTool`",`"arguments`":$argJson}}"
        Write-Host "  calling $LiveTool ..." -ForegroundColor DarkGray
        $r = Invoke-Rpc -Proc $proc -Json $callJson
        $isError = $r.result.isError -eq $true
        if ($isError) {
            Write-TestResult "live $LiveTool executed without error" $false $r.result.content[0].text
        }
        else {
            $payload = $null
            try { $payload = $r.result.content[0].text | ConvertFrom-Json } catch {}
            Write-TestResult "live $LiveTool returns parseable content" ($null -ne $payload)
            Write-TestResult "live $LiveTool result echoes tool name" ($payload.tool -eq $LiveTool) "got: $($payload.tool)"
        }
    }
}
finally {
    # Close stdin so the server's read loop exits cleanly
    try { $proc.StandardInput.Close() } catch {}
    if (-not $proc.WaitForExit(5000)) { try { $proc.Kill() } catch {} }
    $proc.Dispose()
}

# =====================================================================
#  SUMMARY
# =====================================================================
Write-Host "`n$('=' * 60)"
Write-Host "Results: $script:Pass passed, $script:Fail failed" -ForegroundColor ($(if ($script:Fail -eq 0) { 'Green' } else { 'Red' }))
if ($script:Fail -gt 0) {
    Write-Host "Failed tests:" -ForegroundColor Red
    $script:Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
exit 0
