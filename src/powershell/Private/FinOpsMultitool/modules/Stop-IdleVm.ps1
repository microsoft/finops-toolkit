###########################################################################
# STOP-IDLEVM.PS1
# AZURE FINOPS MULTITOOL - Deallocate an Idle VM
###########################################################################
# Purpose: Deallocate (stop) a single idle VM found by scan_idle_vms so
#          it stops billing for compute. Deallocate is REVERSIBLE - the
#          VM can be started again and keeps its disks and config.
#
# Description:
# 1. Validates the resource id (Microsoft.Compute/virtualMachines only).
# 2. Reads the VM power state; no-ops if it is already deallocated.
# 3. Routes through the configurable write-safety gate (dry-run by
#    default; token required only in Enforced mode).
# Note: deallocate releases the dynamic public IP and ephemeral state;
# it does NOT delete the VM or its disks.
#
# ── Parameters ──────────────────────────────────────────────────────
# ResourceId         Full ARM resource ID of the VM
# Apply              Omitted = dry-run preview. Present = deallocate.
# ConfirmationToken  Required only in Enforced mode (from the preview)
#
# Usage: Stop-IdleVm -ResourceId <id> [-Apply]
###########################################################################

function Stop-IdleVm {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Writes are gated by the explicit -Apply switch and routed through Resolve-WriteDecision (dry-run by default, mode/guardrail/confirmation-token enforcement, and audit logging).')]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceId,

        [Parameter()]
        [switch]$Apply,

        [Parameter()]
        [string]$ConfirmationToken
    )

    $apiVersion = '2024-07-01'

    if ($ResourceId -notmatch '/providers/Microsoft\.Compute/virtualMachines/(?<name>[^/]+)$') {
        return [PSCustomObject]@{
            HasData = $false
            Error   = 'This tool only deallocates Microsoft.Compute/virtualMachines. Pass a VM resource ID.'
        }
    }
    $vmName = $Matches.name

    # ---- Read power state (instanceView) ----
    $ivPath = "$ResourceId/instanceView`?api-version=$apiVersion"
    $ivResp = Invoke-AzRestMethodWithRetry -Path $ivPath -Method 'GET'
    $ivStatus = if ($ivResp) { [int]$ivResp.StatusCode } else { 0 }
    if ($ivStatus -eq 404) {
        return [PSCustomObject]@{ HasData = $true; Applied = $false; ResourceId = $ResourceId; Note = 'VM not found.' }
    }
    if ($ivStatus -lt 200 -or $ivStatus -ge 300) {
        $gErr = $null
        if ($ivResp -and $ivResp.Content) { try { $gErr = ($ivResp.Content | ConvertFrom-Json).error.message } catch { $gErr = $ivResp.Content } }
        return [PSCustomObject]@{ HasData = $false; Error = "Could not read VM power state (HTTP $ivStatus). $gErr"; ResourceId = $ResourceId }
    }

    $iv = $null
    try { $iv = $ivResp.Content | ConvertFrom-Json -ErrorAction Stop } catch {}
    $powerState = 'unknown'
    if ($iv -and $iv.statuses) {
        $ps = $iv.statuses | Where-Object { $_.code -like 'PowerState/*' } | Select-Object -First 1
        if ($ps) { $powerState = ($ps.code -replace '^PowerState/', '') }
    }

    # ---- Already stopped? No-op. ----
    if ($powerState -in @('deallocated', 'deallocating', 'stopped')) {
        return [PSCustomObject]@{
            HasData      = $true
            Mode         = 'NoOp'
            Applied      = $false
            Note         = "VM '$vmName' is already '$powerState'. Nothing to do."
            ResourceId   = $ResourceId
            ResourceName = $vmName
            PowerState   = $powerState
        }
    }

    $subId = if ($ResourceId -match '/subscriptions/([^/]+)/') { $Matches[1] } else { $null }
    $rg = if ($ResourceId -match '/resourceGroups/([^/]+)/') { $Matches[1] } else { $null }
    # Tags require a separate GET; deallocate is reversible so a light touch
    # is fine - read tags from the VM resource for guardrail checks.
    $tagHash = @{}
    $vmResp = Invoke-AzRestMethodWithRetry -Path "$ResourceId`?api-version=$apiVersion" -Method 'GET'
    if ($vmResp -and [int]$vmResp.StatusCode -ge 200 -and [int]$vmResp.StatusCode -lt 300) {
        try { $vmObj = $vmResp.Content | ConvertFrom-Json; if ($vmObj.tags) { foreach ($t in $vmObj.tags.PSObject.Properties) { $tagHash[$t.Name] = $t.Value } } } catch {}
    }

    # ---- Write-safety gate (reversible -> impact 0) ----
    $decision = Resolve-WriteDecision -ToolName 'remediate_deallocate_vm' -Operation 'Deallocate' `
        -ResourceId $ResourceId -SubscriptionId $subId -ResourceGroup $rg -Tags $tagHash `
        -EstimatedMonthlyImpact 0 -Reversible $true -Apply:$Apply -ConfirmationToken $ConfirmationToken

    if ($decision.Decision -eq 'Blocked') {
        return [PSCustomObject]@{
            HasData = $false; Mode = 'Blocked'; Applied = $false; Error = $decision.Reason
            GuardrailViolations = @($decision.GuardrailViolations); WriteMode = $decision.Mode
            ResourceId = $ResourceId; ResourceName = $vmName
        }
    }

    $deallocPath = "$ResourceId/deallocate`?api-version=$apiVersion"

    if ($decision.Decision -eq 'Preview') {
        return [PSCustomObject]@{
            HasData           = $true
            Mode              = 'DryRun'
            Applied           = $false
            WriteMode         = $decision.Mode
            Warning           = "PREVIEW ONLY - the VM was not stopped. Deallocate is REVERSIBLE (you can start the VM again; disks are kept). $($decision.Reason)"
            Method            = 'POST'
            Uri               = "https://management.azure.com$deallocPath"
            ResourceId        = $ResourceId
            ResourceName      = $vmName
            CurrentPowerState = $powerState
            ConfirmationToken = $decision.ConfirmationToken
            RequiresToken     = $decision.RequiresToken
            NextStep          = if ($decision.RequiresToken) {
                'Enforced mode: re-run with apply=true AND confirmationToken=<the ConfirmationToken above>, after user confirmation.'
            }
            else { 'Re-run remediate_deallocate_vm with apply=true (after user confirmation) to deallocate this VM.' }
        }
    }

    # ---- Proceed: POST deallocate ----
    Write-Host "  Deallocating idle VM '$vmName'..." -ForegroundColor Yellow
    $resp = Invoke-AzRestMethodWithRetry -Path $deallocPath -Method 'POST'
    $status = if ($resp) { [int]$resp.StatusCode } else { 0 }
    $ok = $status -in @(200, 202)
    $errMsg = $null
    if (-not $ok) {
        $errMsg = "POST deallocate returned $status."
        if ($resp -and $resp.Content) { try { $eb = ($resp.Content | ConvertFrom-Json); if ($eb.error.message) { $errMsg += " $($eb.error.message)" } } catch {} }
    }

    return [PSCustomObject]@{
        HasData      = $true
        Mode         = 'Apply'
        Applied      = $ok
        WriteMode    = $decision.Mode
        StatusCode   = $status
        Warning      = if ($ok) { "Deallocate started (async). Reversible - start the VM to bring it back." } else { $null }
        Error        = $errMsg
        Method       = 'POST'
        Uri          = "https://management.azure.com$deallocPath"
        ResourceId   = $ResourceId
        ResourceName = $vmName
        Async        = ($status -eq 202)
    }
}
