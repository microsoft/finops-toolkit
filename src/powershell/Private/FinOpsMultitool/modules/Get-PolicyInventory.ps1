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
    $complianceMap  = @{}
    $gotAssignments = $false
    $gotCompliance  = $false

    # -- Strategy 1: ARM REST API for ALL effective assignments ----------
    # Resource Graph policyresources at subscription scope only returns
    # assignments AT that scope.  The ARM Policy API returns ALL effective
    # assignments including those inherited from management groups and
    # the tenant root group.
    try {
        Write-Host "  Querying policy assignments via ARM REST API..." -ForegroundColor Cyan
        $seenIds = @{}
        foreach ($sub in $Subscriptions) {
            $subName = $sub.Name
            $nextLink = "/subscriptions/$($sub.Id)/providers/Microsoft.Authorization/policyAssignments?api-version=2022-06-01"
            while ($nextLink) {
                $resp = Invoke-AzRestMethodWithRetry -Path $nextLink -Method GET
                if ($resp.StatusCode -ne 200) { break }
                $body = $resp.Content | ConvertFrom-Json
                foreach ($a in $body.value) {
                    # De-duplicate (same MG assignment appears under each sub)
                    if ($seenIds.ContainsKey($a.id)) { continue }
                    $seenIds[$a.id] = $true

                    $props  = $a.properties
                    $defId  = $props.policyDefinitionId
                    $origin = if ($defId -match '/policySetDefinitions/') { 'Initiative' }
                              elseif ($defId -match '/providers/Microsoft\.Authorization/policyDefinitions/') { 'BuiltIn' }
                              else { 'Custom' }
                    $scope  = if ($a.id -match '^(.*)/providers/Microsoft\.Authorization/policyAssignments/') {
                                  $Matches[1]
                              } else { '' }

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
                } else { $null }
            }
        }

        if ($allAssignments.Count -gt 0) {
            $gotAssignments = $true
            Write-Host "  ARM REST API: $($allAssignments.Count) unique policy assignments (including inherited)" -ForegroundColor Green
        }
    } catch {
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
                } else { $skipToken = $null }
            } while ($skipToken)
            if ($allAssignments.Count -gt 0) {
                $gotAssignments = $true
                Write-Host "  Resource Graph fallback: $($allAssignments.Count) assignments" -ForegroundColor Green
            }
        } catch {
            Write-Warning "  Resource Graph policy query failed: $($_.Exception.Message)"
        }
    }

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
        $compResult = Search-AzGraphSafe -Query $compQuery -Subscription $subIds -First 1000

        if ($compResult -and $compResult.Data -and $compResult.Data.Count -gt 0) {
            foreach ($row in $compResult.Data) {
                $subName = $row.subscriptionId
                $matchSub = $Subscriptions | Where-Object { $_.Id -eq $row.subscriptionId } | Select-Object -First 1
                if ($matchSub) { $subName = $matchSub.Name }

                $complianceMap[$row.subscriptionId] = [PSCustomObject]@{
                    Subscription   = $subName
                    SubscriptionId = $row.subscriptionId
                    TotalResources = $row.Total
                    NonCompliant   = $row.NonCompliant
                    Compliant      = $row.Compliant
                    PolicyCount    = 0
                }
            }
            $gotCompliance = $true
            Write-Host "  Resource Graph compliance: $($complianceMap.Count) subscriptions" -ForegroundColor Green
        }
    } catch {
        Write-Warning "  Resource Graph compliance query failed: $($_.Exception.Message)"
    }

    # -- Compliance fallback: per-sub REST (only if ARG compliance failed) --
    if (-not $gotCompliance) {
        Write-Host "  Falling back to per-sub compliance queries..." -ForegroundColor Yellow
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
                if ($compResp.StatusCode -eq 200) {
                    $summary = ($compResp.Content | ConvertFrom-Json).value
                    if ($summary -and $summary.Count -gt 0) {
                        $s = $summary[0].results
                        $complianceMap[$sub.Id] = [PSCustomObject]@{
                            Subscription     = $sub.Name
                            SubscriptionId   = $sub.Id
                            TotalResources   = $s.resourceDetails | ForEach-Object { $_.count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                            NonCompliant     = ($s.resourceDetails | Where-Object { $_.complianceState -eq 'noncompliant' }).count
                            Compliant        = ($s.resourceDetails | Where-Object { $_.complianceState -eq 'compliant' }).count
                            PolicyCount      = $s.policyDetails | ForEach-Object { $_.count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                        }
                    }
                }
            } catch {
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
            } catch {
                Write-Warning "  Policy assignments failed for $($sub.Name): $($_.Exception.Message)"
            }
        }
    }

    # -- Deduplicate assignments by name + scope -----------------------
    $seen = @{}
    $unique = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($a in $allAssignments) {
        $key = "$($a.AssignmentName)|$($a.Scope)"
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            [void]$unique.Add($a)
        }
    }

    # -- Compliance totals ---------------------------------------------
    $totalCompliant    = 0
    $totalNonCompliant = 0
    foreach ($c in $complianceMap.Values) {
        $totalCompliant    += $c.Compliant
        $totalNonCompliant += $c.NonCompliant
    }
    $totalEvaluated = $totalCompliant + $totalNonCompliant
    $compliancePct  = if ($totalEvaluated -gt 0) { [math]::Round(($totalCompliant / $totalEvaluated) * 100, 1) } else { 0 }

    return [PSCustomObject]@{
        Assignments      = $unique
        AssignmentCount  = $unique.Count
        ComplianceBySubMap = $complianceMap
        CompliancePct    = $compliancePct
        TotalCompliant   = $totalCompliant
        TotalNonCompliant = $totalNonCompliant
    }
}
