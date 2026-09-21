# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Private helper; the returned shape varies by scan and is not a declared contract.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Accepted for signature parity; the dispatcher passes -TenantId to every scan module.')]
param()

###########################################################################
# GET-POLICYINVENTORY.PS1
# AZURE FINOPS MULTITOOL - Policy Inventory Across the Tenant
###########################################################################
# Purpose: Scan all policy assignments across the tenant's subscriptions
#          and return a summary of assigned policies, their effects,
#          scopes, and compliance state.
#
# Strategy: Resource Graph for assignments (1 paginated call) +
#           MG-scope Policy Insights for compliance (1 call).
#           Falls back to per-sub only for small tenants if above fail.
###########################################################################

function Format-PolicyEffectName {
    # Azure stores effect names inconsistently across definitions: some authored as
    # "modify", others as "AuditIfNotExists". Capitalizing the first character keeps
    # one column from mixing both conventions.
    param([string]$Effect)
    if ([string]::IsNullOrWhiteSpace($Effect)) { return $Effect }
    $trimmed = $Effect.Trim()
    return $trimmed.Substring(0, 1).ToUpperInvariant() + $trimmed.Substring(1)
}

function Resolve-PolicyEffect {
    # An assignment only carries an effect when it overrides the parameter, which
    # is the exception rather than the rule. Everything else has to come from the
    # definition, or the report understates what is actually enforced.
    #
    # Precedence: assignment override, definition literal, definition parameter default.
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$AssignmentEffect,

        [Parameter()]
        [object]$Definition,

        # An initiative bundles policies with differing effects, so there is no
        # single value to report. That is not the same as an unknown effect.
        [Parameter()]
        [switch]$IsInitiative
    )

    if (-not [string]::IsNullOrWhiteSpace($AssignmentEffect) -and $AssignmentEffect -ne '-') {
        return (Format-PolicyEffectName $AssignmentEffect)
    }
    if ($IsInitiative) { return 'varies (Initiative)' }
    if (-not $Definition) { return '-' }

    # "[parameters('effect')]" defers to the parameter default; a bare word is the effect.
    $literal = [string]$Definition.policyRule.then.effect
    if (-not [string]::IsNullOrWhiteSpace($literal) -and $literal -notmatch '^\s*\[') {
        return (Format-PolicyEffectName $literal)
    }

    $default = [string]$Definition.parameters.effect.defaultValue
    if (-not [string]::IsNullOrWhiteSpace($default)) { return (Format-PolicyEffectName $default) }

    return '-'
}

function Get-PolicyDefinitionMap {
    # Fetched by resource ID rather than queried. Resource Graph's policyresources
    # only returns definitions scoped to the subscriptions being queried, which
    # excludes tenant-level built-ins and management-group definitions - and those
    # are exactly where inherited assignments point. A GET against the definition
    # ID works for all three scopes.
    #
    # Callers pass only the IDs they could not resolve, deduplicated, so this stays
    # proportional to distinct definitions rather than to assignment count.
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$DefinitionIds
    )

    $map = @{}
    foreach ($id in @($DefinitionIds | Where-Object { $_ } | Select-Object -Unique)) {
        # The ID is concatenated ahead of a query string, so anything carrying '?',
        # '#' or '&' could rewrite the request. Accept only well-formed definition IDs.
        # The scope prefix is optional: built-ins start at /providers directly.
        if ($id -notmatch '^(/[A-Za-z0-9._\-()/]+)?/providers/Microsoft\.Authorization/policyDefinitions/[A-Za-z0-9._\-()]+$') {
            continue
        }
        try {
            $resp = Invoke-AzRestMethodWithRetry -Path "$($id)?api-version=2023-04-01" -Method GET
            if ($resp.StatusCode -eq 200) {
                $def = $resp.Content | ConvertFrom-Json
                if ($def.properties) { $map[[string]$id] = $def.properties }
            }
        }
        catch {
            # An unreadable definition just leaves the effect unresolved.
            continue
        }
    }
    return $map
}

function Get-PolicyInventory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    $subCount = $Subscriptions.Count
    Write-Host "  Scanning policy assignments across $subCount subscriptions..." -ForegroundColor Cyan

    $allAssignments = [System.Collections.Generic.List[PSCustomObject]]::new()
    $complianceMap = @{}
    $gotAssignments = $false
    $gotCompliance = $false
    $subFailures = [System.Collections.Generic.List[string]]::new()

    # -- Strategy 1: ARM REST API for ALL effective assignments ----------
    # Resource Graph policyresources at subscription scope only returns
    # assignments AT that scope.  The ARM Policy API returns ALL effective
    # assignments including those inherited from management groups and
    # the tenant root group.
    try {
        Write-Host "  Querying policy assignments via ARM REST API..." -ForegroundColor Cyan
        $seenIds = @{}
        foreach ($sub in $Subscriptions) {
            # Scoped per subscription: a transient failure on one must not abandon
            # the rest of the tenant and leave a partial result looking complete.
            try {
                $subName = $sub.Name
                $nextLink = "/subscriptions/$($sub.Id)/providers/Microsoft.Authorization/policyAssignments?api-version=2022-06-01"
                while ($nextLink) {
                    $resp = Invoke-AzRestMethodWithRetry -Path $nextLink -Method GET
                    if ($resp.StatusCode -ne 200) {
                        [void]$subFailures.Add("$($sub.Name): HTTP $($resp.StatusCode)")
                        break
                    }
                    $body = $resp.Content | ConvertFrom-Json
                    if ($null -eq $body -or $body.value -isnot [array]) {
                        throw 'The policy assignment response has no valid value collection.'
                    }
                    foreach ($a in $body.value) {
                        if ([string]::IsNullOrWhiteSpace([string]$a.id) -or [string]::IsNullOrWhiteSpace([string]$a.properties.policyDefinitionId)) {
                            throw 'A policy assignment has no resource ID or policy definition ID.'
                        }
                        # De-duplicate (same MG assignment appears under each sub)
                        if ($seenIds.ContainsKey($a.id)) { continue }
                        $seenIds[$a.id] = $true

                        $props = $a.properties
                        $defId = $props.policyDefinitionId
                        $origin = if ($defId -match '/policySetDefinitions/') { 'Initiative' }
                        elseif ($defId -match '/providers/Microsoft\.Authorization/policyDefinitions/') { 'BuiltIn' }
                        else { 'Custom' }
                        $scope = if ($a.id -match '^(.*)/providers/Microsoft\.Authorization/policyAssignments/') {
                            $Matches[1]
                        }
                        else { '' }

                        [void]$allAssignments.Add([PSCustomObject]@{
                                AssignmentName  = if ($props.displayName) { $props.displayName } else { $a.name }
                                AssignmentId    = $a.id
                                PolicyDefId     = $defId
                                Scope           = $scope
                                Effect          = if ($props.parameters -and $props.parameters.effect) { $props.parameters.effect.value } else { '-' }
                                EnforcementMode = if ($props.enforcementMode) { $props.enforcementMode } else { 'Default' }
                                Origin          = $origin
                                Subscription    = $subName
                                Description     = if ($props.description) { $props.description } else { '' }
                            })
                    }
                    # Handle pagination via nextLink
                    $nextLink = if ($body.nextLink) {
                        $body.nextLink -replace '^https://management\.azure\.com', ''
                    }
                    else { $null }
                }
            }
            catch {
                [void]$subFailures.Add("$($sub.Name): $($_.Exception.Message)")
            }
        }

        if ($subFailures.Count -gt 0) {
            Write-Warning "  Policy assignments could not be read for $($subFailures.Count) of $subCount subscription(s); the inventory below is partial."
            foreach ($f in ($subFailures | Select-Object -First 3)) { Write-Verbose "    $f" }
        }

        if ($subFailures.Count -eq 0 -or $allAssignments.Count -gt 0) {
            $gotAssignments = $true
            Write-Host "  ARM REST API: $($allAssignments.Count) unique policy assignments (including inherited)" -ForegroundColor Green
        }
    }
    catch {
        [void]$subFailures.Add("ARM REST policy query: $($_.Exception.Message)")
        Write-Warning "  ARM REST policy query failed: $($_.Exception.Message)"
    }

    # Fallback: Resource Graph if ARM REST didn't find any
    if (-not $gotAssignments) {
        try {
            Write-Host "  Falling back to Resource Graph for policy assignments..." -ForegroundColor Yellow
            $argQuery = @"
policyresources
| where type =~ 'microsoft.authorization/policyassignments'
| project id, name, properties, subscriptionId, type
"@
            $subIds = $Subscriptions | ForEach-Object { $_.Id }
            $skipToken = $null
            $pageNum = 0
            do {
                $pageNum++
                $result = Search-AzGraphSafe -Query $argQuery -Subscription $subIds -First 1000 -SkipToken $skipToken
                if ($result -and $result.Data) {
                    foreach ($r in $result.Data) {
                        $props = $r.properties
                        $defId = $props.policyDefinitionId
                        $origin = if ($defId -match '/policySetDefinitions/') { 'Initiative' }
                        elseif ($defId -match '/providers/Microsoft\.Authorization/policyDefinitions/') { 'BuiltIn' }
                        else { 'Custom' }
                        $subName = $r.subscriptionId
                        $matchSub = $Subscriptions | Where-Object { $_.Id -eq $r.subscriptionId } | Select-Object -First 1
                        if ($matchSub) { $subName = $matchSub.Name }
                        [void]$allAssignments.Add([PSCustomObject]@{
                                AssignmentName  = if ($props.displayName) { $props.displayName } else { $r.name }
                                AssignmentId    = $r.id
                                PolicyDefId     = $defId
                                Scope           = if ($props.scope) { $props.scope } else { ($r.id -replace '/providers/Microsoft\.Authorization/policyAssignments/.*', '') }
                                Effect          = if ($props.parameters -and $props.parameters.effect) { $props.parameters.effect.value } else { '-' }
                                EnforcementMode = if ($props.enforcementMode) { $props.enforcementMode } else { 'Default' }
                                Origin          = $origin
                                Subscription    = $subName
                                Description     = if ($props.description) { $props.description } else { '' }
                            })
                    }
                    $skipToken = $result.SkipToken
                }
                else { $skipToken = $null }
            } while ($skipToken)
            if ($allAssignments.Count -gt 0) {
                $gotAssignments = $true
                Write-Host "  Resource Graph fallback: $($allAssignments.Count) assignments" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "  Resource Graph policy query failed: $($_.Exception.Message)"
        }
    }

    $complianceErrors = [System.Collections.Generic.List[string]]::new()
    # -- Strategy 2: Resource Graph for compliance (tenant-wide, fast) ---
    # The MG-scope PolicyInsights summarize REST API hangs indefinitely,
    # and per-sub REST loops are slow on large tenants.
    # Resource Graph policyresources table gives us compliance across ALL
    # subscriptions in a single paginated call - fast and complete.
    try {
        Write-Host "  Querying policy compliance via Resource Graph..." -ForegroundColor Cyan
        $compQuery = @"
policyresources
| where type =~ 'microsoft.policyinsights/policystates'
| extend complianceState = tostring(properties.complianceState)
| summarize
    Compliant    = countif(complianceState =~ 'Compliant'),
    NonCompliant = countif(complianceState =~ 'NonCompliant'),
    Total        = count()
    by subscriptionId
"@
        $subIds = $Subscriptions | ForEach-Object { $_.Id }
        $compResult = Search-AzGraphSafe -Query $compQuery -Subscription $subIds -First 1000 -All

        if ($compResult -and $compResult.Data -and $compResult.Data.Count -gt 0) {
            foreach ($row in $compResult.Data) {
                $subName = $row.subscriptionId
                $matchSub = $Subscriptions | Where-Object { $_.Id -eq $row.subscriptionId } | Select-Object -First 1
                if (-not $matchSub) { continue }
                $subName = $matchSub.Name
                foreach ($column in @('Total', 'NonCompliant', 'Compliant')) {
                    if ((Get-HubCostValue -Row $row -Column $column) -lt 0) { throw 'Policy compliance contains an invalid count.' }
                }

                $complianceMap[$row.subscriptionId] = [PSCustomObject]@{
                    Subscription   = $subName
                    SubscriptionId = $row.subscriptionId
                    TotalResources = $row.Total
                    NonCompliant   = $row.NonCompliant
                    Compliant      = $row.Compliant
                    # Not derivable from the compliance query; the REST fallback
                    # computes it. $null distinguishes "unknown" from a real zero.
                    PolicyCount    = $null
                }
            }
            $gotCompliance = @($Subscriptions | Where-Object { $complianceMap.ContainsKey([string]$_.Id) }).Count -eq $subCount
            Write-Host "  Resource Graph compliance: $($complianceMap.Count) subscriptions" -ForegroundColor Green
        }
    }
    catch {
        $complianceMap.Clear()
        Write-Warning "  Resource Graph compliance query failed: $($_.Exception.Message)"
    }

    # -- Compliance fallback: per-sub REST (only if ARG compliance failed) --
    if (-not $gotCompliance) {
        Write-Host "  Falling back to per-sub compliance queries..." -ForegroundColor Yellow
        $complianceMap.Clear()
        $i = 0
        foreach ($sub in $Subscriptions) {
            $i++
            if ($subCount -gt 20 -and ($i % 10 -eq 0)) {
                if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                    Update-ScanStatus "Scanning policy compliance ($i/$subCount)..."
                }
            }
            try {
                $compPath = "/subscriptions/$($sub.Id)/providers/Microsoft.PolicyInsights/policyStates/latest/summarize?api-version=2019-10-01"
                $compResp = Invoke-AzRestMethodWithRetry -Path $compPath -Method POST
                if (-not $compResp -or $compResp.StatusCode -ne 200) { throw "Policy compliance returned HTTP $($compResp.StatusCode)." }
                $summary = ($compResp.Content | ConvertFrom-Json -ErrorAction Stop).value
                if ($summary -isnot [array] -or $summary.Count -gt 1) { throw 'Policy compliance returned an invalid summary.' }
                $total = 0.0
                $compliant = 0.0
                $nonCompliant = 0.0
                $policyCount = $null
                if ($summary.Count -eq 1) {
                    $summaryResult = $summary[0].results
                    if ($summaryResult.resourceDetails -isnot [array]) { throw 'Policy compliance has no resource counts.' }
                    foreach ($detail in $summaryResult.resourceDetails) {
                        $count = Get-HubCostValue -Row $detail -Column 'count'
                        if ($count -lt 0) { throw 'Policy compliance contains a negative count.' }
                        $total += $count
                        if ($detail.complianceState -eq 'compliant') { $compliant += $count }
                        elseif ($detail.complianceState -eq 'noncompliant') { $nonCompliant += $count }
                    }
                    $policyCount = ($summaryResult.policyDetails | ForEach-Object { $_.count } | Measure-Object -Sum).Sum
                }
                $complianceMap[$sub.Id] = [PSCustomObject]@{
                    Subscription = $sub.Name; SubscriptionId = $sub.Id; TotalResources = $total
                    NonCompliant = $nonCompliant; Compliant = $compliant; PolicyCount = $policyCount
                }
            }
            catch {
                [void]$complianceErrors.Add("$($sub.Name): $($_.Exception.Message)")
                Write-Warning "  Policy compliance failed for $($sub.Name): $($_.Exception.Message)"
            }
        }
    }

    # -- Strategy 3: Per-sub fallback (only if Resource Graph failed) ---
    if (-not $gotAssignments) {
        Write-Host "  Falling back to per-subscription policy scan..." -ForegroundColor Yellow
        $i = 0
        foreach ($sub in $Subscriptions) {
            $i++
            if ($i -eq 1 -or $i -eq $subCount -or ($subCount -gt 5 -and $i % [math]::Max(1, [int]($subCount / 10)) -eq 0)) {
                if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                    Update-ScanStatus "Scanning policies ($i/$subCount subs)..."
                }
            }
            try {
                $assignPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Authorization/policyAssignments?api-version=2022-06-01"
                $resp = Invoke-AzRestMethodWithRetry -Path $assignPath -Method GET
                if ($resp.StatusCode -eq 200) {
                    $assignments = ($resp.Content | ConvertFrom-Json).value
                    foreach ($a in $assignments) {
                        $props = $a.properties
                        $defId = $props.policyDefinitionId
                        $origin = if ($defId -match '/providers/Microsoft\.Authorization/policyDefinitions/') { 'BuiltIn' } else { 'Custom' }
                        if ($defId -match '/policySetDefinitions/') { $origin = 'Initiative' }

                        [void]$allAssignments.Add([PSCustomObject]@{
                                AssignmentName  = $props.displayName
                                AssignmentId    = $a.id
                                PolicyDefId     = $defId
                                Scope           = $props.scope
                                Effect          = if ($props.parameters -and $props.parameters.effect) { $props.parameters.effect.value } else { '-' }
                                EnforcementMode = if ($props.enforcementMode) { $props.enforcementMode } else { 'Default' }
                                Origin          = $origin
                                Subscription    = $sub.Name
                                Description     = if ($props.description) { $props.description } else { '' }
                            })
                    }
                }
            }
            catch {
                Write-Warning "  Policy assignments failed for $($sub.Name): $($_.Exception.Message)"
            }
        }
    }

    # -- Deduplicate assignments by resource ID -----------------------
    $seen = @{}
    $unique = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($a in $allAssignments) {
        $key = [string]$a.AssignmentId
        if ([string]::IsNullOrWhiteSpace($key)) {
            [void]$subFailures.Add('An assignment has no resource ID; assignment coverage is incomplete.')
            [void]$unique.Add($a)
            continue
        }
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            [void]$unique.Add($a)
        }
    }

    # -- Resolve effects the assignment did not override ---------------
    if ($unique.Count -gt 0) {
        # Only single policies need a definition lookup; initiatives resolve to 'varies'.
        $needsLookup = @($unique |
            Where-Object { $_.Origin -ne 'Initiative' -and (-not $_.Effect -or $_.Effect -eq '-') } |
            ForEach-Object { $_.PolicyDefId })
        $defMap = if ($needsLookup.Count -gt 0) { Get-PolicyDefinitionMap -DefinitionIds $needsLookup } else { @{} }

        foreach ($a in $unique) {
            $override = if ($a.Effect -and $a.Effect -ne '-') { $a.Effect } else { '' }
            $a.Effect = Resolve-PolicyEffect -AssignmentEffect $override -Definition $defMap[[string]$a.PolicyDefId] -IsInitiative:($a.Origin -eq 'Initiative')
        }
        $resolved = @($unique | Where-Object { $_.Effect -ne '-' }).Count
        Write-Host "  Effects resolved for $resolved of $($unique.Count) assignments." -ForegroundColor Green
    }

    # -- Compliance totals ---------------------------------------------
    $totalCompliant = 0
    $totalNonCompliant = 0
    foreach ($c in $complianceMap.Values) {
        $totalCompliant += $c.Compliant
        $totalNonCompliant += $c.NonCompliant
    }
    $totalEvaluated = $totalCompliant + $totalNonCompliant
    $complianceIncomplete = $complianceErrors.Count -gt 0 -or @($Subscriptions | Where-Object { -not $complianceMap.ContainsKey([string]$_.Id) }).Count -gt 0
    $compliancePct = if (-not $complianceIncomplete -and $totalEvaluated -gt 0) { [math]::Round(($totalCompliant / $totalEvaluated) * 100, 1) } else { $null }

    return [PSCustomObject]@{
        Assignments        = $unique
        AssignmentCount    = $unique.Count
        CoverageIncomplete = ($subFailures.Count -gt 0)
        AssignmentErrors   = $subFailures.ToArray()
        Note               = (@(
            if ($subFailures.Count -gt 0) { 'Some effective policy assignments could not be read. Missing assignments cannot be determined from this inventory.' }
            if ($complianceIncomplete) { 'Policy compliance coverage is incomplete. Partial results do not establish a percentage for the selected scope.' }
        ) -join ' ')
        ComplianceCoverageIncomplete = $complianceIncomplete
        ComplianceErrors   = $complianceErrors.ToArray()
        ComplianceBySubMap = $complianceMap
        CompliancePct      = $compliancePct
        TotalCompliant     = $totalCompliant
        TotalNonCompliant  = $totalNonCompliant
        TotalEvaluated     = $totalEvaluated
        HasComplianceData  = (-not $complianceIncomplete -and $totalEvaluated -gt 0)
    }
}
