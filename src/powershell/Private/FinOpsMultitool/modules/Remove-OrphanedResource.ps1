###########################################################################
# REMOVE-ORPHANEDRESOURCE.PS1
# AZURE FINOPS MULTITOOL - Safe Deletion of Orphaned Resources
###########################################################################
# Purpose: Delete a single orphaned Azure resource (unattached managed
#          disk, dangling public IP, unattached NIC, or stale snapshot)
#          discovered by scan_orphaned_resources.
#
# Description:
# Safe-by-default remediation, matching the Set-CostAllocationRule pattern:
# 1. Validates the resource id and refuses any type not on the allow-list
#    (only orphan-eligible types can EVER be deleted by this tool).
# 2. Re-reads the resource and re-verifies it is genuinely orphaned at
#    execution time (defense in depth - never delete on a stale scan).
# 3. DRY-RUN by default: returns the exact DELETE call + orphan evidence
#    and mutates nothing. Only deletes when -Apply is explicitly passed.
#
# ── Parameters ──────────────────────────────────────────────────────
# ResourceId         Full ARM resource ID of the orphan to delete
# Apply              Safety gate. Omitted = dry-run preview (no write).
#                    Present = perform the DELETE after user approval.
#
# Prerequisites:
# - Contributor (or a delete-capable role) on the target resource scope
#
# Usage: Remove-OrphanedResource -ResourceId <id> [-Apply]
###########################################################################

function Remove-OrphanedResource {
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

    # -----------------------------------------------------------------
    # Allow-list: ONLY these types may ever be deleted by this tool.
    # inUseProps = the resource 'properties' fields that, when populated,
    # mean the resource is STILL IN USE (so we must refuse to delete).
    # -----------------------------------------------------------------
    $allowList = @{
        'Microsoft.Compute/disks'             = @{ api = '2023-04-02'; label = 'Managed disk'; inUseProps = @('managedBy', 'diskState'); kind = 'attachment' }
        'Microsoft.Network/publicIPAddresses' = @{ api = '2023-09-01'; label = 'Public IP address'; inUseProps = @('ipConfiguration', 'natGateway'); kind = 'attachment' }
        'Microsoft.Network/networkInterfaces' = @{ api = '2023-09-01'; label = 'Network interface'; inUseProps = @('virtualMachine', 'privateEndpoint'); kind = 'attachment' }
        'Microsoft.Compute/snapshots'         = @{ api = '2023-04-02'; label = 'Disk snapshot'; inUseProps = @(); kind = 'backup' }
    }

    # ---- Validate the resource id ----
    if ($ResourceId -notmatch '^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/') {
        return [PSCustomObject]@{
            HasData = $false
            Error   = "Invalid resourceId. Expected a full ARM resource ID like /subscriptions/{guid}/resourceGroups/{rg}/providers/{ns}/{type}/{name}."
        }
    }

    if ($ResourceId -notmatch '/providers/(?<ns>Microsoft\.[^/]+)/(?<type>[^/]+)/(?<name>[^/]+)$') {
        return [PSCustomObject]@{
            HasData = $false
            Error   = "Could not parse a top-level resource type from resourceId. This tool only deletes top-level orphaned resources (disks, public IPs, NICs, snapshots)."
        }
    }
    $fullType = "$($Matches.ns)/$($Matches.type)"
    $resName = $Matches.name

    if (-not $allowList.ContainsKey($fullType)) {
        return [PSCustomObject]@{
            HasData      = $false
            Error        = "Refusing to delete '$fullType'. This tool only deletes orphan-eligible types: $($allowList.Keys -join ', '). Use the appropriate scan/remediation path for other resources."
            ResourceId   = $ResourceId
            ResourceType = $fullType
        }
    }

    $cfg = $allowList[$fullType]
    $apiVersion = $cfg.api
    $path = "$ResourceId`?api-version=$apiVersion"

    # ---- Re-read the resource (confirm it exists + is still orphaned) ----
    $getResp = Invoke-AzRestMethodWithRetry -Path $path -Method 'GET'
    $getStatus = if ($getResp) { [int]$getResp.StatusCode } else { 0 }

    if ($getStatus -eq 404) {
        return [PSCustomObject]@{
            HasData      = $true
            Mode         = if ($Apply) { 'Apply' } else { 'DryRun' }
            Applied      = $false
            ResourceId   = $ResourceId
            ResourceType = $fullType
            Note         = 'Resource not found (already deleted or never existed). Nothing to do.'
        }
    }
    if ($getStatus -lt 200 -or $getStatus -ge 300) {
        $gErr = $null
        if ($getResp -and $getResp.Content) {
            try { $gErr = ($getResp.Content | ConvertFrom-Json -ErrorAction Stop).error.message } catch { $gErr = $getResp.Content }
        }
        return [PSCustomObject]@{
            HasData      = $false
            Error        = "Could not read the resource before deleting (HTTP $getStatus). $gErr"
            ResourceId   = $ResourceId
            ResourceType = $fullType
        }
    }

    $resObj = $null
    try { $resObj = $getResp.Content | ConvertFrom-Json -ErrorAction Stop } catch {}
    $props = if ($resObj) { $resObj.properties } else { $null }
    $location = if ($resObj) { $resObj.location } else { $null }

    # ---- Defense in depth: verify the resource is genuinely orphaned ----
    $inUseBy = @()
    foreach ($p in $cfg.inUseProps) {
        if ($p -eq 'diskState') {
            # A disk is in use unless its diskState is Unattached/Reserved.
            if ($props -and $props.diskState -and $props.diskState -notin @('Unattached', 'Reserved')) {
                $inUseBy += "diskState=$($props.diskState)"
            }
            continue
        }
        $val = if ($props) { $props.$p } else { $null }
        $populated = $false
        if ($null -ne $val) {
            if ($val -is [string]) { $populated = -not [string]::IsNullOrWhiteSpace($val) }
            elseif ($val.PSObject -and $val.PSObject.Properties.Name -contains 'id') { $populated = [bool]$val.id }
            else { $populated = $true }
        }
        if ($populated) { $inUseBy += $p }
    }

    if ($inUseBy.Count -gt 0) {
        return [PSCustomObject]@{
            HasData      = $false
            Mode         = 'Blocked'
            Applied      = $false
            Error        = "Refusing to delete: '$resName' appears to be IN USE ($($inUseBy -join ', ')). It is not orphaned. Re-run scan_orphaned_resources to refresh, or detach it first."
            ResourceId   = $ResourceId
            ResourceType = $fullType
            Location     = $location
            InUseBy      = $inUseBy
        }
    }

    # ---- Build human-readable evidence for the preview ----
    $evidence = [ordered]@{}
    switch ($fullType) {
        'Microsoft.Compute/disks' {
            $evidence['diskState'] = $props.diskState
            $evidence['sizeGB'] = $props.diskSizeGB
            $evidence['sku'] = if ($resObj.sku) { $resObj.sku.name } else { $null }
        }
        'Microsoft.Network/publicIPAddresses' {
            $evidence['ipAddress'] = $props.ipAddress
            $evidence['allocationMethod'] = $props.publicIPAllocationMethod
            $evidence['sku'] = if ($resObj.sku) { $resObj.sku.name } else { $null }
        }
        'Microsoft.Network/networkInterfaces' {
            $evidence['attachedVM'] = 'none'
        }
        'Microsoft.Compute/snapshots' {
            $evidence['sizeGB'] = $props.diskSizeGB
            $evidence['timeCreated'] = $props.timeCreated
        }
    }

    $irreversible = if ($cfg.kind -eq 'backup') {
        'This is a point-in-time backup. Deletion is IRREVERSIBLE and you lose the restore point.'
    }
    else {
        'Deletion is IRREVERSIBLE. The orphaned resource and any data on it are permanently removed.'
    }

    # ---- Route through the configurable write-safety gate ----
    $subId = if ($ResourceId -match '/subscriptions/([^/]+)/') { $Matches[1] } else { $null }
    $rg = if ($ResourceId -match '/resourceGroups/([^/]+)/') { $Matches[1] } else { $null }
    $tagHash = @{}
    if ($resObj -and $resObj.tags) {
        foreach ($t in $resObj.tags.PSObject.Properties) { $tagHash[$t.Name] = $t.Value }
    }
    $estImpact = 0
    if ($evidence['estMonthlySavings']) { $estImpact = [double]$evidence['estMonthlySavings'] }

    $decision = Resolve-WriteDecision -ToolName 'remediate_delete_orphaned_resource' -Operation 'Delete' `
        -ResourceId $ResourceId -SubscriptionId $subId -ResourceGroup $rg -Tags $tagHash `
        -EstimatedMonthlyImpact $estImpact -Reversible $false -Apply:$Apply -ConfirmationToken $ConfirmationToken

    # ---- BLOCKED by mode/guardrails/enforcement ----
    if ($decision.Decision -eq 'Blocked') {
        return [PSCustomObject]@{
            HasData             = $false
            Mode                = 'Blocked'
            Applied             = $false
            Error               = $decision.Reason
            GuardrailViolations = @($decision.GuardrailViolations)
            WriteMode           = $decision.Mode
            ResourceId          = $ResourceId
            ResourceName        = $resName
            ResourceType        = $fullType
        }
    }

    # ---- DRY RUN (default): preview the DELETE, mutate nothing ----
    if ($decision.Decision -eq 'Preview') {
        return [PSCustomObject]@{
            HasData           = $true
            Mode              = 'DryRun'
            Applied           = $false
            WriteMode         = $decision.Mode
            Warning           = "PREVIEW ONLY - nothing was deleted. $irreversible $($decision.Reason)"
            Method            = 'DELETE'
            Uri               = "$(Get-FinOpsArmEndpoint)$path"
            ResourceId        = $ResourceId
            ResourceName      = $resName
            ResourceType      = $fullType
            TypeLabel         = $cfg.label
            Location          = $location
            OrphanEvidence    = [PSCustomObject]$evidence
            ConfirmationToken = $decision.ConfirmationToken
            RequiresToken     = $decision.RequiresToken
            NextStep          = if ($decision.RequiresToken) {
                'Enforced mode: re-run remediate_delete_orphaned_resource with apply=true AND confirmationToken=<the ConfirmationToken above>, after user confirmation.'
            }
            else {
                'Re-run remediate_delete_orphaned_resource with apply=true (after user confirmation) to delete this resource.'
            }
        }
    }

    # ---- APPLY (decision = Proceed): perform the DELETE ----
    Write-Host "  Deleting orphaned $($cfg.label) '$resName'..." -ForegroundColor Yellow
    $delResp = Invoke-AzRestMethodWithRetry -Path $path -Method 'DELETE'
    $delStatus = if ($delResp) { [int]$delResp.StatusCode } else { 0 }
    # 200 OK, 202 Accepted (async), 204 No Content all indicate success.
    $ok = $delStatus -in @(200, 202, 204)

    $errMsg = $null
    if (-not $ok) {
        $errMsg = "DELETE returned $delStatus."
        if ($delResp -and $delResp.Content) {
            try {
                $eb = ($delResp.Content | ConvertFrom-Json -ErrorAction Stop)
                if ($eb.error -and $eb.error.message) { $errMsg += " $($eb.error.message)" }
            }
            catch {}
        }
    }

    return [PSCustomObject]@{
        HasData      = $true
        Mode         = 'Apply'
        Applied      = $ok
        WriteMode    = $decision.Mode
        StatusCode   = $delStatus
        Warning      = if ($ok) { 'Resource deleted. This is irreversible.' } else { $null }
        Error        = $errMsg
        Method       = 'DELETE'
        Uri          = "$(Get-FinOpsArmEndpoint)$path"
        ResourceId   = $ResourceId
        ResourceName = $resName
        ResourceType = $fullType
        TypeLabel    = $cfg.label
        Location     = $location
        Async        = ($delStatus -eq 202)
    }
}
