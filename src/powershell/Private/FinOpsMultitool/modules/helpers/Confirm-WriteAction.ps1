# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# CONFIRM-WRITEACTION.PS1
# AZURE FINOPS MULTITOOL - Configurable Write-Safety Core
###########################################################################
# Purpose: One choke point that every MUTATING tool routes through, so
#          writeback is safe whether a human is driving an AI chat or an
#          autonomous agent is acting unattended.
#
# Description:
# Safety is OPTIONAL and configurable via FINOPS_WRITE_MODE. Writes are
# OPT-IN: the server is read-only out of the box and a mutating tool only
# acts after an operator deliberately enables a write mode.
#   ReadOnly (default)    - all writes blocked. Set FINOPS_WRITE_MODE to
#       Interactive or Enforced to enable remediation.
#   Interactive           - platform-agnostic AI chat. apply=true is
#       honored directly (the human/AI client showed the preview). A
#       confirmation token is still issued, but NOT required. Low friction.
#   Enforced              - autonomous-safe. apply=true is REJECTED unless
#       it carries the exact confirmation token returned by the matching
#       dry-run. An agent cannot skip the preview or apply a different /
#       larger change than was previewed.
#
# Guardrails (apply in BOTH Interactive and Enforced, all configurable):
#   - Protected tag keys/values (e.g. do-not-delete) - never mutate
#   - Protected resource groups / subscriptions (deny-list patterns)
#   - Estimated monthly $ impact cap
#   - Blast-radius cap (max writes per rolling window)
# Every preview and apply is written to an append-only audit log.
#
# ── Configuration (env) ─────────────────────────────────────────────
# FINOPS_WRITE_MODE          Interactive | Enforced | ReadOnly
# FINOPS_WRITE_MAX_IMPACT    Max estimated monthly USD impact (0 = no cap)
# FINOPS_WRITE_MAX_PER_WINDOW Max writes per window (0 = no cap)
# FINOPS_WRITE_WINDOW_MIN    Rolling window minutes for blast radius
# FINOPS_PROTECTED_TAGS      Comma list of tag keys that block a write
# FINOPS_PROTECTED_RGS       Comma list of resource-group name patterns
# FINOPS_PROTECTED_SUBS      Comma list of subscription IDs to deny
# FINOPS_AUDIT_LOG           Audit log path
#
# Usage: $d = Resolve-WriteDecision -ToolName x -Operation Delete ...
###########################################################################

# -- Per-process state -----------------------------------------------------
$script:FinOpsPendingConfirmations = @{}
$script:FinOpsWriteHistory = New-Object System.Collections.ArrayList

function Get-FinOpsDefaultAuditLogPath {
    # Durable, per-user audit location that survives reboots - unlike %TEMP%,
    # which the user (or OS cleanup) can clear, weakening an append-only trail.
    # Falls back to the temp dir only if the profile path cannot be resolved or
    # created. Override entirely with FINOPS_AUDIT_LOG.
    $base = [Environment]::GetFolderPath('LocalApplicationData')
    if ([string]::IsNullOrWhiteSpace($base)) { $base = [System.IO.Path]::GetTempPath() }
    $dir = Join-Path $base 'FinOpsMultitool'
    try {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
        }
    }
    catch {
        $dir = [System.IO.Path]::GetTempPath()
    }
    return (Join-Path $dir 'finops-multitool-audit.log')
}

function Initialize-FinOpsWritePolicy {
    $envList = {
        param($v)
        if ([string]::IsNullOrWhiteSpace($v)) { @() }
        else { @($v -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    }

    $mode = $env:FINOPS_WRITE_MODE
    if ($mode -notin @('Interactive', 'Enforced', 'ReadOnly')) { $mode = 'ReadOnly' }

    $script:FinOpsWritePolicy = [ordered]@{
        Mode                    = $mode
        MaxEstimatedImpact      = [double]($env:FINOPS_WRITE_MAX_IMPACT    | ForEach-Object { if ($_) { $_ } else { 0 } })
        MaxWritesPerWindow      = [int](   $env:FINOPS_WRITE_MAX_PER_WINDOW | ForEach-Object { if ($_) { $_ } else { 0 } })
        WindowMinutes           = [int](   $env:FINOPS_WRITE_WINDOW_MIN     | ForEach-Object { if ($_) { $_ } else { 60 } })
        ProtectedTagKeys        = & $envList ($env:FINOPS_PROTECTED_TAGS)
        ProtectedResourceGroups = & $envList ($env:FINOPS_PROTECTED_RGS)
        ProtectedSubscriptions  = & $envList ($env:FINOPS_PROTECTED_SUBS)
        TokenTtlSeconds         = 300
        AuditLogPath            = if ($env:FINOPS_AUDIT_LOG) { $env:FINOPS_AUDIT_LOG } else { Get-FinOpsDefaultAuditLogPath }
    }
    # Built-in safety defaults so a fresh deploy is never wide open on the
    # most dangerous classes even before an operator tunes the env vars.
    if ($script:FinOpsWritePolicy.ProtectedTagKeys.Count -eq 0) {
        $script:FinOpsWritePolicy.ProtectedTagKeys = @('do-not-delete', 'DoNotDelete', 'lock', 'protected')
    }
    return $script:FinOpsWritePolicy
}

function Get-FinOpsWritePolicy {
    if (-not $script:FinOpsWritePolicy) { Initialize-FinOpsWritePolicy | Out-Null }
    return $script:FinOpsWritePolicy
}

function Set-FinOpsWritePolicy {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates only the in-process write-policy hashtable; it does not change system or Azure state.')]
    param([hashtable]$Settings)
    if (-not $script:FinOpsWritePolicy) { Initialize-FinOpsWritePolicy | Out-Null }
    foreach ($k in $Settings.Keys) {
        if ($script:FinOpsWritePolicy.Contains($k)) { $script:FinOpsWritePolicy[$k] = $Settings[$k] }
    }
    return $script:FinOpsWritePolicy
}

# -- Stable fingerprint of the exact intended change ----------------------
function Get-WriteFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)][string]$ResourceId,
        [hashtable]$Extra
    )
    $parts = @($ToolName.ToLower(), $Operation.ToLower(), $ResourceId.ToLower())
    if ($Extra) {
        foreach ($k in ($Extra.Keys | Sort-Object)) { $parts += "$k=$($Extra[$k])".ToLower() }
    }
    $canonical = ($parts -join '|')
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($canonical))
    $sha.Dispose()
    return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}

function New-WriteConfirmation {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Issues an in-process, short-lived confirmation token; it does not change system or Azure state.')]
    param([Parameter(Mandatory)][string]$Fingerprint)
    $policy = Get-FinOpsWritePolicy
    $token = [guid]::NewGuid().ToString('N')
    $script:FinOpsPendingConfirmations[$token] = @{
        Fingerprint = $Fingerprint
        Expires     = (Get-Date).AddSeconds($policy.TokenTtlSeconds)
    }
    # Opportunistic cleanup of expired tokens.
    $now = Get-Date
    @($script:FinOpsPendingConfirmations.Keys) | ForEach-Object {
        if ($script:FinOpsPendingConfirmations[$_].Expires -lt $now) { $script:FinOpsPendingConfirmations.Remove($_) }
    }
    return $token
}

function Test-WriteConfirmation {
    [CmdletBinding()]
    param(
        [string]$Token,
        [Parameter(Mandatory)][string]$Fingerprint
    )
    if ([string]::IsNullOrWhiteSpace($Token)) { return @{ Valid = $false; Reason = 'No confirmationToken supplied.' } }
    $entry = $script:FinOpsPendingConfirmations[$Token]
    if (-not $entry) { return @{ Valid = $false; Reason = 'confirmationToken is unknown, already used, or expired. Re-run the dry-run preview to get a fresh token.' } }
    # Single use, regardless of outcome.
    $script:FinOpsPendingConfirmations.Remove($Token)
    if ($entry.Expires -lt (Get-Date)) { return @{ Valid = $false; Reason = 'confirmationToken has expired. Re-run the dry-run preview.' } }
    if ($entry.Fingerprint -ne $Fingerprint) { return @{ Valid = $false; Reason = 'confirmationToken does not match this exact change. The intended action differs from what was previewed; re-run the dry-run preview.' } }
    return @{ Valid = $true; Reason = $null }
}

# -- Guardrails (protected resources, caps) -------------------------------
function Test-WriteGuardrails {
    [CmdletBinding()]
    param(
        [string]$ResourceId,
        [string]$SubscriptionId,
        [string]$ResourceGroup,
        [hashtable]$Tags,
        [double]$EstimatedMonthlyImpact = 0
    )
    $policy = Get-FinOpsWritePolicy
    $violations = @()

    if ($SubscriptionId -and ($policy.ProtectedSubscriptions -contains $SubscriptionId)) {
        $violations += "Subscription '$SubscriptionId' is on the protected (deny) list."
    }
    if ($ResourceGroup) {
        foreach ($pat in $policy.ProtectedResourceGroups) {
            if ($ResourceGroup -like $pat -or $ResourceGroup -eq $pat) {
                $violations += "Resource group '$ResourceGroup' matches a protected pattern ('$pat')."
                break
            }
        }
    }
    if ($Tags) {
        foreach ($pk in $policy.ProtectedTagKeys) {
            $hit = $Tags.Keys | Where-Object { $_ -ieq $pk }
            if ($hit) { $violations += "Resource carries a protected tag ('$hit') - refusing to mutate it." }
        }
    }
    if ($policy.MaxEstimatedImpact -gt 0 -and $EstimatedMonthlyImpact -gt $policy.MaxEstimatedImpact) {
        $violations += ("Estimated monthly impact `$$([math]::Round($EstimatedMonthlyImpact,2)) exceeds the configured cap `$$($policy.MaxEstimatedImpact).")
    }
    if ($policy.MaxWritesPerWindow -gt 0) {
        $cutoff = (Get-Date).AddMinutes(-1 * $policy.WindowMinutes)
        $recent = @($script:FinOpsWriteHistory | Where-Object { $_ -gt $cutoff })
        if ($recent.Count -ge $policy.MaxWritesPerWindow) {
            $violations += "Blast-radius cap reached: $($recent.Count) writes in the last $($policy.WindowMinutes) min (max $($policy.MaxWritesPerWindow)). Wait or raise FINOPS_WRITE_MAX_PER_WINDOW."
        }
    }
    return @{ Allowed = ($violations.Count -eq 0); Violations = $violations }
}

function Write-FinOpsAudit {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Entry)
    try {
        $policy = Get-FinOpsWritePolicy
        $Entry['timestamp'] = (Get-Date -Format 'o')
        $line = ($Entry | ConvertTo-Json -Depth 6 -Compress)
        Add-Content -Path $policy.AuditLogPath -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    }
    catch { Write-Warning "Audit log write failed: $($_.Exception.Message)" }
}

# -- The single decision the mutating tools call --------------------------
function Resolve-WriteDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)][string]$ResourceId,
        [string]$SubscriptionId,
        [string]$ResourceGroup,
        [hashtable]$Tags,
        [double]$EstimatedMonthlyImpact = 0,
        [bool]$Reversible = $true,
        [switch]$Apply,
        [string]$ConfirmationToken,
        [hashtable]$FingerprintExtra
    )
    $policy = Get-FinOpsWritePolicy
    $fp = Get-WriteFingerprint -ToolName $ToolName -Operation $Operation -ResourceId $ResourceId -Extra $FingerprintExtra

    $result = [ordered]@{
        Mode                = $policy.Mode
        Decision            = $null      # Preview | Proceed | Blocked
        Reason              = $null
        ConfirmationToken   = $null
        RequiresToken       = ($policy.Mode -eq 'Enforced')
        GuardrailViolations = @()
        Reversible          = $Reversible
        Fingerprint         = $fp
    }

    # Read-only server: nothing writes, ever.
    if ($policy.Mode -eq 'ReadOnly') {
        $result.Decision = 'Blocked'
        $result.Reason = 'Server is in ReadOnly write mode (FINOPS_WRITE_MODE=ReadOnly, the default). No mutations are permitted. To enable remediation, set FINOPS_WRITE_MODE=Interactive (human-in-the-loop) or =Enforced (autonomous-safe; apply=true also requires the confirmation token from a dry-run).'
        Write-FinOpsAudit -Entry @{ event = 'blocked'; tool = $ToolName; operation = $Operation; resourceId = $ResourceId; reason = $result.Reason }
        return [PSCustomObject]$result
    }

    # Guardrails apply in every mode (these are the "costly mistake" guard).
    $g = Test-WriteGuardrails -ResourceId $ResourceId -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroup -Tags $Tags -EstimatedMonthlyImpact $EstimatedMonthlyImpact
    if (-not $g.Allowed) {
        $result.Decision = 'Blocked'
        $result.GuardrailViolations = @($g.Violations)
        $result.Reason = 'Blocked by write guardrails: ' + ($g.Violations -join ' ')
        Write-FinOpsAudit -Entry @{ event = 'blocked'; tool = $ToolName; operation = $Operation; resourceId = $ResourceId; reason = $result.Reason; violations = @($g.Violations) }
        return [PSCustomObject]$result
    }

    # Dry-run preview: issue a token (usable later in any mode).
    if (-not $Apply) {
        $result.Decision = 'Preview'
        $result.ConfirmationToken = New-WriteConfirmation -Fingerprint $fp
        $result.Reason = if ($policy.Mode -eq 'Enforced') {
            'Preview only. Server is in Enforced mode: re-run with apply=true AND confirmationToken=<this token> to execute.'
        }
        else {
            'Preview only. Show this to the user; re-run with apply=true to execute (Interactive mode does not require the token).'
        }
        Write-FinOpsAudit -Entry @{ event = 'preview'; tool = $ToolName; operation = $Operation; resourceId = $ResourceId; mode = $policy.Mode; reversible = $Reversible }
        return [PSCustomObject]$result
    }

    # Apply path.
    if ($policy.Mode -eq 'Enforced') {
        $chk = Test-WriteConfirmation -Token $ConfirmationToken -Fingerprint $fp
        if (-not $chk.Valid) {
            $result.Decision = 'Blocked'
            $result.Reason = "Enforced mode: $($chk.Reason)"
            Write-FinOpsAudit -Entry @{ event = 'blocked'; tool = $ToolName; operation = $Operation; resourceId = $ResourceId; reason = $result.Reason }
            return [PSCustomObject]$result
        }
    }

    $result.Decision = 'Proceed'
    [void]$script:FinOpsWriteHistory.Add((Get-Date))
    Write-FinOpsAudit -Entry @{ event = 'apply'; tool = $ToolName; operation = $Operation; resourceId = $ResourceId; mode = $policy.Mode; reversible = $Reversible; estimatedMonthlyImpact = $EstimatedMonthlyImpact }
    return [PSCustomObject]$result
}
