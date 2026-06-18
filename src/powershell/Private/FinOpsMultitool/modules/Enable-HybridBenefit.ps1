###########################################################################
# ENABLE-HYBRIDBENEFIT.PS1
# AZURE FINOPS MULTITOOL - Enable Azure Hybrid Benefit on a VM
###########################################################################
# Purpose: Turn on Azure Hybrid Benefit (AHB) for a single VM found by
#          scan_ahb_opportunities. AHB applies existing Windows Server /
#          SQL licenses to cut compute licensing cost up to ~85%.
#
# Description:
# REVERSIBLE, savings-only write (you can set the license back to None).
# 1. Validates the resource id (Microsoft.Compute/virtualMachines only).
# 2. Reads the VM, detects OS, and picks the right licenseType
#    (Windows -> Windows_Server) unless one is passed explicitly.
# 3. No-ops if AHB is already enabled.
# 4. Routes through the configurable write-safety gate (dry-run by
#    default; token required only in Enforced mode).
#
# ── Parameters ──────────────────────────────────────────────────────
# ResourceId         Full ARM resource ID of the VM
# LicenseType        Override: Windows_Server | Windows_Client |
#                    RHEL_BYOS | SLES_BYOS (auto-detected if omitted)
# Apply              Omitted = dry-run preview. Present = PATCH the VM.
# ConfirmationToken  Required only in Enforced mode (from the preview)
#
# Usage: Enable-HybridBenefit -ResourceId <id> [-Apply]
###########################################################################

function Enable-HybridBenefit {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Writes are gated by the explicit -Apply switch and routed through Resolve-WriteDecision (dry-run by default, mode/guardrail/confirmation-token enforcement, and audit logging).')]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceId,

        [Parameter()]
        [ValidateSet('Windows_Server', 'Windows_Client', 'RHEL_BYOS', 'SLES_BYOS')]
        [string]$LicenseType,

        [Parameter()]
        [switch]$Apply,

        [Parameter()]
        [string]$ConfirmationToken
    )

    $apiVersion = '2024-07-01'

    if ($ResourceId -notmatch '/providers/Microsoft\.Compute/virtualMachines/(?<name>[^/]+)$') {
        return [PSCustomObject]@{
            HasData = $false
            Error   = 'This tool only enables AHB on Microsoft.Compute/virtualMachines. Pass a VM resource ID.'
        }
    }
    $vmName = $Matches.name
    $path = "$ResourceId`?api-version=$apiVersion"

    # ---- Read the VM ----
    $getResp = Invoke-AzRestMethodWithRetry -Path $path -Method 'GET'
    $getStatus = if ($getResp) { [int]$getResp.StatusCode } else { 0 }
    if ($getStatus -eq 404) {
        return [PSCustomObject]@{ HasData = $true; Applied = $false; ResourceId = $ResourceId; Note = 'VM not found.' }
    }
    if ($getStatus -lt 200 -or $getStatus -ge 300) {
        $gErr = $null
        if ($getResp -and $getResp.Content) { try { $gErr = ($getResp.Content | ConvertFrom-Json).error.message } catch { $gErr = $getResp.Content } }
        return [PSCustomObject]@{ HasData = $false; Error = "Could not read the VM (HTTP $getStatus). $gErr"; ResourceId = $ResourceId }
    }

    $vm = $null
    try { $vm = $getResp.Content | ConvertFrom-Json -ErrorAction Stop } catch {}
    $props = if ($vm) { $vm.properties } else { $null }
    $osType = if ($props -and $props.storageProfile -and $props.storageProfile.osDisk) { [string]$props.storageProfile.osDisk.osType } else { '' }
    $currentLicense = if ($props -and $props.licenseType) { [string]$props.licenseType } else { 'None' }
    $location = if ($vm) { $vm.location } else { $null }

    # ---- Decide the target license type ----
    if (-not $LicenseType) {
        if ($osType -ieq 'Windows') { $LicenseType = 'Windows_Server' }
        elseif ($osType -ieq 'Linux') {
            return [PSCustomObject]@{
                HasData      = $false
                Error        = "VM '$vmName' is Linux. AHB for Linux requires the exact distro license (RHEL_BYOS or SLES_BYOS). Re-run with an explicit licenseType only if this VM is RHEL/SLES BYOS-eligible."
                ResourceId   = $ResourceId
                CurrentLicense = $currentLicense
            }
        }
        else {
            return [PSCustomObject]@{ HasData = $false; Error = "Could not determine OS type for '$vmName'. Pass licenseType explicitly."; ResourceId = $ResourceId }
        }
    }

    # ---- Already enabled? No-op. ----
    if ($currentLicense -ieq $LicenseType) {
        return [PSCustomObject]@{
            HasData      = $true
            Mode         = 'NoOp'
            Applied      = $false
            Note         = "AHB already enabled on '$vmName' (licenseType=$currentLicense). Nothing to do."
            ResourceId   = $ResourceId
            ResourceName = $vmName
        }
    }

    $subId = if ($ResourceId -match '/subscriptions/([^/]+)/') { $Matches[1] } else { $null }
    $rg = if ($ResourceId -match '/resourceGroups/([^/]+)/') { $Matches[1] } else { $null }
    $tagHash = @{}
    if ($vm -and $vm.tags) { foreach ($t in $vm.tags.PSObject.Properties) { $tagHash[$t.Name] = $t.Value } }

    # ---- Write-safety gate (reversible, savings-only -> impact 0) ----
    $decision = Resolve-WriteDecision -ToolName 'remediate_enable_hybrid_benefit' -Operation 'EnableAHB' `
        -ResourceId $ResourceId -SubscriptionId $subId -ResourceGroup $rg -Tags $tagHash `
        -EstimatedMonthlyImpact 0 -Reversible $true -Apply:$Apply -ConfirmationToken $ConfirmationToken `
        -FingerprintExtra @{ licenseType = $LicenseType }

    if ($decision.Decision -eq 'Blocked') {
        return [PSCustomObject]@{
            HasData = $false; Mode = 'Blocked'; Applied = $false; Error = $decision.Reason
            GuardrailViolations = @($decision.GuardrailViolations); WriteMode = $decision.Mode
            ResourceId = $ResourceId; ResourceName = $vmName
        }
    }

    $bodyJson = @{ properties = @{ licenseType = $LicenseType } } | ConvertTo-Json -Depth 5

    if ($decision.Decision -eq 'Preview') {
        return [PSCustomObject]@{
            HasData           = $true
            Mode              = 'DryRun'
            Applied           = $false
            WriteMode         = $decision.Mode
            Warning           = "PREVIEW ONLY - the VM was not changed. This is REVERSIBLE and reduces licensing cost. $($decision.Reason)"
            Method            = 'PATCH'
            Uri               = "https://management.azure.com$path"
            ResourceId        = $ResourceId
            ResourceName      = $vmName
            Location          = $location
            OsType            = $osType
            CurrentLicense    = $currentLicense
            NewLicense        = $LicenseType
            RequestBody       = ($bodyJson | ConvertFrom-Json)
            ConfirmationToken = $decision.ConfirmationToken
            RequiresToken     = $decision.RequiresToken
            NextStep          = if ($decision.RequiresToken) {
                'Enforced mode: re-run with apply=true AND confirmationToken=<the ConfirmationToken above>.'
            }
            else { 'Re-run remediate_enable_hybrid_benefit with apply=true to enable AHB.' }
        }
    }

    # ---- Proceed: PATCH the VM ----
    Write-Host "  Enabling Azure Hybrid Benefit ($LicenseType) on '$vmName'..." -ForegroundColor Yellow
    $resp = Invoke-AzRestMethodWithRetry -Path $path -Method 'PATCH' -Payload $bodyJson
    $status = if ($resp) { [int]$resp.StatusCode } else { 0 }
    $ok = $status -in @(200, 201, 202)
    $errMsg = $null
    if (-not $ok) {
        $errMsg = "PATCH returned $status."
        if ($resp -and $resp.Content) { try { $eb = ($resp.Content | ConvertFrom-Json); if ($eb.error.message) { $errMsg += " $($eb.error.message)" } } catch {} }
    }

    return [PSCustomObject]@{
        HasData      = $true
        Mode         = 'Apply'
        Applied      = $ok
        WriteMode    = $decision.Mode
        StatusCode   = $status
        Warning      = if ($ok) { "AHB enabled ($LicenseType). Reversible - set licenseType back to None to undo." } else { $null }
        Error        = $errMsg
        Method       = 'PATCH'
        Uri          = "https://management.azure.com$path"
        ResourceId   = $ResourceId
        ResourceName = $vmName
        CurrentLicense = $currentLicense
        NewLicense   = $LicenseType
    }
}
