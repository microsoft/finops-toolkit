###########################################################################
# SET-COSTALLOCATIONRULE.PS1
# WRITE-BACK: NATIVE AZURE COST ALLOCATION RULE (CHARGEBACK)
###########################################################################
# Purpose: Push transfer-weighted percentages into a native Azure Cost
#          Management cost allocation rule so chargeback reflects the split.
# Author: Zac Larsen
# Date: Created for FinOps Multitool shared-cost allocation
#
# Description:
# Creates or updates a Cost Management cost allocation rule via the ARM REST
# API (api-version 2025-03-01). The rule reallocates the cost of a shared
# source (a hub resource group or subscription) to spoke subscriptions by
# fixed percentage. Intended to be fed from scan_allocate_shared_cost output.
#
# SAFETY: This MUTATES chargeback. It is DRY-RUN by default. Nothing is
# written to Azure unless -Apply is passed. The dry-run returns the exact
# PUT URI and request body so a human can review before it is applied. The
# agent must present the preview and obtain explicit confirmation first.
#
# ── Parameters ──────────────────────────────────────────────────
# BillingAccountId       EA enrollment id or MCA billing account id (rule scope)
# RuleName               Rule name ([A-Za-z0-9_-]+, max 260 chars)
# SourceResourceGroup    Shared-cost source resource group name(s) (Dimension)
# SourceSubscriptionId   Shared-cost source subscription id(s) (alt to RG)
# Targets                Spoke targets: array of {subscriptionId, percentage}
#                        or {spoke, allocatedShared} (percent derived)
# TargetDimension        SubscriptionId (default) or ResourceGroupName
# Status                 Active (default) or NotActive
# Description            Free-text rule description
# Apply                  Switch. Without it, returns a preview and writes nothing
#
# Prerequisites:
# - Cost Management Contributor on the billing account / enrollment
# - EA, MCA-E, or MCA-online billing account (cost allocation supported)
#
# Usage: Set-CostAllocationRule -BillingAccountId 100 -RuleName hub-split `
#          -SourceResourceGroup rg-hub -Targets $alloc -Apply
###########################################################################

function Get-AllocTargetProp {
    param(
        [object]$Item,
        [string[]]$Names
    )
    foreach ($n in $Names) {
        if ($Item -is [hashtable]) {
            if ($Item.ContainsKey($n) -and $null -ne $Item[$n] -and "$($Item[$n])".Trim().Length -gt 0) {
                return $Item[$n]
            }
        }
        elseif ($null -ne $Item) {
            $p = $Item.PSObject.Properties[$n]
            if ($p -and $null -ne $p.Value -and "$($p.Value)".Trim().Length -gt 0) {
                return $p.Value
            }
        }
    }
    return $null
}

function ConvertTo-AllocationPercentages {
    # Normalizes a target list to whole percentages that sum to EXACTLY 100.00.
    param(
        [object[]]$Targets,
        [string]$TargetDimension
    )

    $raw = @()
    $anyPct = $false
    foreach ($t in $Targets) {
        $name = Get-AllocTargetProp -Item $t -Names @('subscriptionId', 'SubscriptionId', 'spoke', 'Spoke', 'name', 'Name')
        if (-not $name) { continue }
        $pct = Get-AllocTargetProp -Item $t -Names @('percentage', 'Percentage', 'pct', 'Pct')
        $share = Get-AllocTargetProp -Item $t -Names @('allocatedShared', 'AllocatedShared', 'weight', 'Weight', 'value', 'Value')
        if ($null -ne $pct) { $anyPct = $true; $val = [double]$pct }
        elseif ($null -ne $share) { $val = [double]$share }
        else { $val = 0.0 }
        $raw += [PSCustomObject]@{ Name = [string]$name; Value = $val }
    }

    if ($raw.Count -eq 0) {
        return @{ Ok = $false; Error = 'No usable targets. Each target needs subscriptionId/spoke plus percentage or allocatedShared.'; Values = @() }
    }

    $sum = ($raw | Measure-Object -Property Value -Sum).Sum
    if ($sum -le 0) {
        return @{ Ok = $false; Error = ('Target weights/percentages sum to {0}; cannot build a rule.' -f $sum); Values = @() }
    }

    $scaled = foreach ($r in $raw) {
        [PSCustomObject]@{ Name = $r.Name; Percentage = [math]::Round(($r.Value / $sum) * 100, 2) }
    }
    $scaled = @($scaled)

    # Fix rounding residual so the rule sums to exactly 100.00.
    $pSum = ($scaled | Measure-Object -Property Percentage -Sum).Sum
    $residual = [math]::Round(100 - $pSum, 2)
    if ($residual -ne 0) {
        $top = $scaled | Sort-Object -Property Percentage -Descending | Select-Object -First 1
        $top.Percentage = [math]::Round($top.Percentage + $residual, 2)
    }

    return @{
        Ok     = $true
        Error  = $null
        Values = @($scaled | ForEach-Object { @{ name = $_.Name; percentage = $_.Percentage } })
    }
}

function Set-CostAllocationRule {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Writes are gated by the explicit -Apply switch and routed through Resolve-WriteDecision (dry-run by default, mode/guardrail/confirmation-token enforcement, and audit logging).')]
    param(
        [Parameter(Mandatory)]
        [string]$BillingAccountId,

        [Parameter(Mandatory)]
        [string]$RuleName,

        [Parameter()]
        [string[]]$SourceResourceGroup,

        [Parameter()]
        [string[]]$SourceSubscriptionId,

        [Parameter(Mandatory)]
        [object[]]$Targets,

        [Parameter()]
        [ValidateSet('SubscriptionId', 'ResourceGroupName')]
        [string]$TargetDimension = 'SubscriptionId',

        [Parameter()]
        [ValidateSet('Active', 'NotActive')]
        [string]$Status = 'Active',

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [switch]$Apply,

        [Parameter()]
        [string]$ConfirmationToken
    )

    $apiVersion = '2025-03-01'

    # ---- Validate inputs (fail before building anything) ----
    if ($RuleName -notmatch '^[A-Za-z0-9_\-]+$' -or $RuleName.Length -gt 260) {
        return [PSCustomObject]@{
            HasData = $false
            Error   = "RuleName '$RuleName' is invalid. Use only letters, digits, '_' and '-' (max 260 chars)."
        }
    }

    $srcRg = @($SourceResourceGroup | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    $srcSub = @($SourceSubscriptionId | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    if ($srcRg.Count -gt 0 -and $srcSub.Count -gt 0) {
        return [PSCustomObject]@{
            HasData = $false
            Error   = 'Provide a source as EITHER sourceResourceGroup OR sourceSubscriptionId, not both. A rule has one source resource type.'
        }
    }
    if ($srcRg.Count -eq 0 -and $srcSub.Count -eq 0) {
        return [PSCustomObject]@{
            HasData = $false
            Error   = 'A source is required: pass sourceResourceGroup (hub RG) or sourceSubscriptionId (hub subscription).'
        }
    }

    $source = if ($srcRg.Count -gt 0) {
        @{ name = 'ResourceGroupName'; resourceType = 'Dimension'; values = @($srcRg) }
    }
    else {
        @{ name = 'SubscriptionId'; resourceType = 'Dimension'; values = @($srcSub) }
    }
    if ($source.values.Count -gt 25) {
        return [PSCustomObject]@{ HasData = $false; Error = 'A cost allocation rule source allows at most 25 values.' }
    }

    # ---- Normalize target percentages to sum exactly 100.00 ----
    $norm = ConvertTo-AllocationPercentages -Targets $Targets -TargetDimension $TargetDimension
    if (-not $norm.Ok) {
        return [PSCustomObject]@{ HasData = $false; Error = $norm.Error }
    }
    $targetValues = @($norm.Values)
    if ($targetValues.Count -gt 25) {
        return [PSCustomObject]@{ HasData = $false; Error = 'A cost allocation rule allows at most 25 target values.' }
    }
    $pctTotal = [math]::Round((($targetValues | ForEach-Object { [double]$_.percentage } | Measure-Object -Sum).Sum), 2)

    $target = @{
        name         = $TargetDimension
        policyType   = 'FixedProportion'
        resourceType = 'Dimension'
        values       = $targetValues
    }

    $desc = if ($Description) { $Description } else { "FinOps Multitool shared-cost allocation ($RuleName)" }

    $bodyObj = @{
        properties = @{
            description = $desc
            status      = $Status
            details     = @{
                sourceResources = @($source)
                targetResources = @($target)
            }
        }
    }
    $bodyJson = $bodyObj | ConvertTo-Json -Depth 12

    $path = "/providers/Microsoft.Billing/billingAccounts/$BillingAccountId/providers/Microsoft.CostManagement/costAllocationRules/$RuleName" + "?api-version=$apiVersion"

    $previewTargets = @($targetValues | ForEach-Object {
            [PSCustomObject]@{ Name = $_.name; Percentage = $_.percentage }
        })

    # ---- Route through the configurable write-safety gate ----
    # A cost allocation rule lives at billing-account scope (no sub/RG). The
    # fingerprint binds the EXACT rule body so Enforced mode cannot apply a
    # different source/target split than was previewed. Reallocating cost is
    # reversible (update/deactivate/delete the rule) so impact is left at 0.
    $ruleResourceId = "/providers/Microsoft.Billing/billingAccounts/$BillingAccountId/providers/Microsoft.CostManagement/costAllocationRules/$RuleName"
    $fpExtra = @{
        billingAccountId = $BillingAccountId
        status           = $Status
        source           = ($source.name + ':' + ((@($source.values) | Sort-Object) -join ','))
        targetDimension  = $TargetDimension
        targets          = ((@($targetValues | ForEach-Object { "$($_.name)=$($_.percentage)" }) | Sort-Object) -join ';')
    }
    $decision = Resolve-WriteDecision -ToolName 'set_cost_allocation_rule' -Operation 'CreateUpdateCostAllocationRule' `
        -ResourceId $ruleResourceId -EstimatedMonthlyImpact 0 -Reversible $true `
        -Apply:$Apply -ConfirmationToken $ConfirmationToken -FingerprintExtra $fpExtra

    # ---- BLOCKED by mode/guardrails/enforcement ----
    if ($decision.Decision -eq 'Blocked') {
        return [PSCustomObject]@{
            HasData             = $false
            Mode                = 'Blocked'
            Applied             = $false
            Error               = $decision.Reason
            GuardrailViolations = @($decision.GuardrailViolations)
            WriteMode           = $decision.Mode
            BillingAccountId    = $BillingAccountId
            RuleName            = $RuleName
        }
    }

    # ---- DRY RUN (default): show what WOULD be written, mutate nothing ----
    if ($decision.Decision -eq 'Preview') {
        return [PSCustomObject]@{
            HasData           = $true
            Mode              = 'DryRun'
            Applied           = $false
            WriteMode         = $decision.Mode
            Warning           = "PREVIEW ONLY - nothing was written to Azure. This rule changes chargeback/cost allocation. Show this preview to the user and get explicit approval, then re-run with apply=true to write it. $($decision.Reason)"
            Method            = 'PUT'
            Uri               = "$(Get-FinOpsArmEndpoint)$path"
            BillingAccountId  = $BillingAccountId
            RuleName          = $RuleName
            Status            = $Status
            Source            = [PSCustomObject]@{ Dimension = $source.name; Values = @($source.values) }
            Targets           = $previewTargets
            PercentageTotal   = $pctTotal
            RequestBody       = $bodyObj
            ConfirmationToken = $decision.ConfirmationToken
            RequiresToken     = $decision.RequiresToken
            NextStep          = if ($decision.RequiresToken) {
                'Enforced mode: re-run set_cost_allocation_rule with apply=true AND confirmationToken=<the ConfirmationToken above>, after user confirmation.'
            }
            else {
                'Re-run set_cost_allocation_rule with apply=true (after user confirmation) to create/update this rule.'
            }
        }
    }

    # ---- APPLY (decision = Proceed): actually create/update the rule ----
    Write-Host "  Writing cost allocation rule '$RuleName' on billing account '$BillingAccountId'..." -ForegroundColor Yellow
    $resp = Invoke-AzRestMethodWithRetry -Path $path -Method 'PUT' -Payload $bodyJson

    $status = if ($resp) { [int]$resp.StatusCode } else { 0 }
    $ok = ($status -eq 200 -or $status -eq 201)
    $respObj = $null
    if ($resp -and $resp.Content) {
        try { $respObj = $resp.Content | ConvertFrom-Json -ErrorAction Stop } catch { $respObj = $resp.Content }
    }

    $errMsg = $null
    if (-not $ok) {
        $errMsg = "PUT returned $status."
        if ($respObj -and $respObj.error -and $respObj.error.message) {
            $errMsg += " $($respObj.error.message)"
        }
    }

    return [PSCustomObject]@{
        HasData          = $true
        Mode             = 'Apply'
        Applied          = $ok
        WriteMode        = $decision.Mode
        StatusCode       = $status
        Warning          = if ($ok) { 'Cost allocation rule written. It changes how shared cost is charged back; allow time for Cost Management to reprocess.' } else { $null }
        Error            = $errMsg
        Method           = 'PUT'
        Uri              = "$(Get-FinOpsArmEndpoint)$path"
        BillingAccountId = $BillingAccountId
        RuleName         = $RuleName
        Status           = $Status
        Source           = [PSCustomObject]@{ Dimension = $source.name; Values = @($source.values) }
        Targets          = $previewTargets
        PercentageTotal  = $pctTotal
        Response         = $respObj
    }
}
