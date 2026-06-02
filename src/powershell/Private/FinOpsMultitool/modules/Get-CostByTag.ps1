###########################################################################
# GET-COSTBYTAG.PS1
# AZURE FINOPS MULTITOOL - Cost Breakdown by Tag
###########################################################################
# Purpose: For each CAF allocation tag (CostCenter, BusinessUnit,
#          etc.), query Cost Management to show how spend distributes
#          across tag values. If no meaningful tags exist, fall back
#          to cost-by-subscription so the user still sees a breakdown.
#
# This is the "Understand" pillar - cost allocation and showback.
###########################################################################

function Get-CostByTag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [Parameter()]
        [hashtable]$ExistingTags,

        [Parameter()]
        [object[]]$Subscriptions
    )

    # Tags we want to break cost down by (in priority order — matches CAF allocation tags)
    $targetTags = @('CostCenter', 'BusinessUnit', 'ApplicationName', 'WorkloadName', 'OpsTeam', 'Criticality', 'DataClassification')

    # Also check variations
    $variations = @{
        'CostCenter'         = @('cost-center', 'costcenter', 'cost_center', 'cc')
        'BusinessUnit'       = @('bu', 'businessunit', 'business-unit', 'department', 'dept')
        'ApplicationName'    = @('applicationname', 'application', 'app', 'appname', 'app-name')
        'WorkloadName'       = @('workloadname', 'workload', 'workload-name', 'workload_name')
        'OpsTeam'            = @('opsteam', 'ops-team', 'ops_team', 'owner', 'technicalowner')
        'Criticality'        = @('criticality', 'sla', 'tier', 'importance')
        'DataClassification' = @('dataclassification', 'data-classification', 'data_classification', 'classification')
    }

    $existingKeys = if ($ExistingTags) { $ExistingTags.Keys | ForEach-Object { $_.ToLower() } } else { @() }
    $tagsToQuery = @()

    foreach ($tag in $targetTags) {
        # Check exact match first
        $match = $existingKeys | Where-Object { $_ -eq $tag.ToLower() } | Select-Object -First 1
        if ($match) {
            # Find the properly-cased version from existing tags
            $properCase = $ExistingTags.Keys | Where-Object { $_.ToLower() -eq $match } | Select-Object -First 1
            $tagsToQuery += $properCase
            continue
        }

        # Check variations
        if ($variations.ContainsKey($tag)) {
            $varMatch = $existingKeys | Where-Object { $_ -in $variations[$tag] } | Select-Object -First 1
            if ($varMatch) {
                $properCase = $ExistingTags.Keys | Where-Object { $_.ToLower() -eq $varMatch } | Select-Object -First 1
                $tagsToQuery += $properCase
            }
        }
    }

    # Also include any additional existing tags not already in the list
    # Sorted by resource coverage (descending) so the most-used tags survive any cap
    if ($ExistingTags) {
        $alreadyLower = $tagsToQuery | ForEach-Object { $_.ToLower() }
        $systemPrefixes = @('hidden-', 'ms-resource-', 'aks-managed-', 'kubernetes.io', 'displayname')
        # Exact-match system/auto-generated tags (Azure Policy, Monitor, Automanage, etc.)
        $systemExact = @(
            'action', 'automanage', 'alertrulecreatedwithalertsrecommendations',
            'createdby', 'createddate', 'createdtime', 'createdon',
            'environment-type', 'intune-deployed', 'policyassignmentname',
            'statuschangedate', 'vmsize', 'offer', 'publisher', 'sku'
        )
        $extras = @()
        foreach ($key in $ExistingTags.Keys) {
            if ($key.ToLower() -in $alreadyLower) { continue }
            $skip = $false
            if ($key.ToLower() -in $systemExact) { $skip = $true }
            if (-not $skip) {
                foreach ($prefix in $systemPrefixes) {
                    if ($key.ToLower().StartsWith($prefix)) { $skip = $true; break }
                }
            }
            if (-not $skip) {
                $coverage = if ($ExistingTags[$key].TotalResources) { $ExistingTags[$key].TotalResources } else { 0 }
                $extras += [PSCustomObject]@{ Name = $key; Coverage = $coverage }
            }
        }
        $extras = $extras | Sort-Object Coverage -Descending
        foreach ($e in $extras) { $tagsToQuery += $e.Name }
    }

    # Skip tags with very low resource coverage (< 3 resources tagged)
    # These produce mostly "(untagged)" results and waste API calls
    if ($ExistingTags -and $tagsToQuery.Count -gt 8) {
        $cafTags = $tagsToQuery | Select-Object -First ([math]::Min($tagsToQuery.Count, 7))
        $extraTags = $tagsToQuery | Select-Object -Skip 7
        $filteredExtras = @()
        foreach ($t in $extraTags) {
            $tagInfo = if ($ExistingTags.ContainsKey($t)) { $ExistingTags[$t] } else { $null }
            $count = if ($tagInfo -and $tagInfo.TotalResources) { $tagInfo.TotalResources } else { 0 }
            if ($count -ge 3) { $filteredExtras += $t }
        }
        $skipped = $tagsToQuery.Count - $cafTags.Count - $filteredExtras.Count
        $tagsToQuery = $cafTags + $filteredExtras
        if ($skipped -gt 0) {
            Write-Host "  Skipped $skipped low-coverage tags (< 3 resources) to reduce API calls" -ForegroundColor Yellow
        }
    }

    $results = @{}
    $mgScopeId  = Resolve-CostMgId -TenantId $TenantId
    $useMgScope = [bool]$mgScopeId
    $mgPath = "/providers/Microsoft.Management/managementGroups/$mgScopeId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"

    # Track subs that don't support Tag grouping (HTTP 400 "Invalid dataset grouping")
    $skipSubs = [System.Collections.Generic.HashSet[string]]::new()

    # Helper: parse Cost Management query response using column headers
    function Parse-CostRows {
        param($ResponseContent)
        $parsed = [System.Collections.Generic.List[PSCustomObject]]::new()
        $result = ($ResponseContent | ConvertFrom-Json)
        if (-not $result.properties -or -not $result.properties.rows -or $result.properties.rows.Count -eq 0) {
            return $parsed
        }
        # Build column index map from response
        $cols = $result.properties.columns
        $costIdx = -1; $tagIdx = -1; $currIdx = -1
        for ($i = 0; $i -lt $cols.Count; $i++) {
            $n = $cols[$i].name.ToLower()
            if ($n -eq 'cost' -or $n -eq 'totalcost' -or $n -match 'precost|pretaxcost') { $costIdx = $i }
            elseif ($n -match 'currency|billingcurrency') { $currIdx = $i }
            elseif ($n -eq 'tagvalue') { $tagIdx = $i }
        }
        # Fallback: if TagValue column not found, pick first String column that isn't TagKey or Currency
        if ($tagIdx -eq -1) {
            for ($i = 0; $i -lt $cols.Count; $i++) {
                if ($cols[$i].type -eq 'String' -and $i -ne $currIdx -and $cols[$i].name.ToLower() -ne 'tagkey') { $tagIdx = $i; break }
            }
        }
        # Final positional fallback
        if ($costIdx -eq -1) { $costIdx = 0 }
        if ($tagIdx -eq -1) { $tagIdx = if ($cols.Count -ge 4) { 2 } else { 1 } }
        if ($currIdx -eq -1) { $currIdx = if ($cols.Count -ge 4) { 3 } else { 2 } }

        foreach ($row in $result.properties.rows) {
            $cost = [math]::Round([double]$row[$costIdx], 2)
            $value = if ($row[$tagIdx]) { $row[$tagIdx] } else { '(untagged)' }
            $currency = if ($currIdx -lt $row.Count) { $row[$currIdx] } else { 'USD' }
            [void]$parsed.Add([PSCustomObject]@{ TagValue = $value; Cost = $cost; Currency = $currency })
        }
        return $parsed
    }

    # Helper: parse batched TagKey+TagValue response into per-tag results
    function Parse-BatchedCostRows {
        param($ResponseContent)
        $perTag = @{}
        $result = ($ResponseContent | ConvertFrom-Json)
        if (-not $result.properties -or -not $result.properties.rows -or $result.properties.rows.Count -eq 0) {
            return $perTag
        }
        $cols = $result.properties.columns
        $costIdx = -1; $keyIdx = -1; $valIdx = -1; $currIdx = -1
        for ($i = 0; $i -lt $cols.Count; $i++) {
            $n = $cols[$i].name.ToLower()
            if ($n -eq 'cost' -or $n -eq 'totalcost' -or $n -match 'precost|pretaxcost') { $costIdx = $i }
            elseif ($n -eq 'tagkey') { $keyIdx = $i }
            elseif ($n -eq 'tagvalue') { $valIdx = $i }
            elseif ($n -match 'currency|billingcurrency') { $currIdx = $i }
        }
        if ($costIdx -eq -1) { $costIdx = 0 }
        if ($keyIdx -eq -1) { $keyIdx = 1 }
        if ($valIdx -eq -1) { $valIdx = 2 }
        if ($currIdx -eq -1) { $currIdx = 3 }

        foreach ($row in $result.properties.rows) {
            $tagKey = if ($row[$keyIdx]) { $row[$keyIdx] } else { '' }
            $tagVal = if ($row[$valIdx]) { $row[$valIdx] } else { '(untagged)' }
            $cost = [math]::Round([double]$row[$costIdx], 2)
            $currency = if ($currIdx -lt $row.Count) { $row[$currIdx] } else { 'USD' }
            if (-not $perTag.ContainsKey($tagKey)) {
                $perTag[$tagKey] = [System.Collections.Generic.List[PSCustomObject]]::new()
            }
            [void]$perTag[$tagKey].Add([PSCustomObject]@{ TagValue = $tagVal; Cost = $cost; Currency = $currency })
        }
        return $perTag
    }

    # Helper: Fire multiple REST calls in parallel using the shared runspace pool.
    # Each call handles its own 429 retry internally, so pool slots may block
    # briefly on throttle but other slots continue processing.
    function Invoke-ParallelRestCalls {
        param(
            [array]$Calls,            # Array of @{ Path; Body; SubId; SubName }
            [int]$TimeoutSeconds = 90
        )
        $pendingJobs = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($call in $Calls) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $script:RunspacePool
            [void]$ps.AddScript({
                    param($path, $payload)
                    for ($attempt = 0; $attempt -le 3; $attempt++) {
                        $params = @{ Path = $path; Method = 'POST'; ErrorAction = 'Stop' }
                        if ($payload) { $params['Payload'] = $payload }
                        try {
                            $r = Invoke-AzRestMethod @params
                            if ($r.StatusCode -ne 429) {
                                $hdrs = @{}
                                if ($r.Headers) { foreach ($k in $r.Headers.Keys) { $hdrs[$k] = $r.Headers[$k] } }
                                return [PSCustomObject]@{ StatusCode = $r.StatusCode; Content = $r.Content; Headers = $hdrs }
                            }
                            # 429 — parse Retry-After or exponential backoff
                            $retryAfter = 10
                            if ($r.Headers -and $r.Headers['Retry-After']) {
                                $parsed = 0
                                if ([int]::TryParse($r.Headers['Retry-After'], [ref]$parsed)) { $retryAfter = [math]::Max($parsed, 5) }
                            }
                            else { $retryAfter = [math]::Min(10 * [math]::Pow(2, $attempt), 60) }
                            Start-Sleep -Seconds $retryAfter
                        }
                        catch {
                            return [PSCustomObject]@{ StatusCode = 0; Content = "{`"error`":{`"message`":`"$($_.Exception.Message)`"}}"; Headers = @{} }
                        }
                    }
                    return [PSCustomObject]@{ StatusCode = 429; Content = '{"error":{"message":"Rate limited after retries"}}'; Headers = @{} }
                }).AddArgument($call.Path).AddArgument($call.Body)
            $async = $ps.BeginInvoke()
            [void]$pendingJobs.Add(@{ PS = $ps; Async = $async; Call = $call; Result = $null })
        }

        # Poll until all complete or timeout, keeping WPF UI responsive
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        while ((Get-Date) -lt $deadline) {
            $allDone = $true
            foreach ($job in $pendingJobs) {
                if ($null -ne $job.Result) { continue }
                if ($job.Async.IsCompleted) {
                    try {
                        $raw = $job.PS.EndInvoke($job.Async)
                        $resp = if ($raw -and $raw.Count -gt 0) { $raw[0] } else { $null }
                        if (-not $resp) { $resp = [PSCustomObject]@{ StatusCode = 0; Content = '{}'; Headers = @{} } }
                        if ($null -eq $resp.Content) { $resp = [PSCustomObject]@{ StatusCode = $resp.StatusCode; Content = '{}'; Headers = @{} } }
                        $job.Result = $resp
                    }
                    catch {
                        $job.Result = [PSCustomObject]@{ StatusCode = 0; Content = '{}'; Headers = @{} }
                    }
                    $job.PS.Dispose()
                }
                else { $allDone = $false }
            }
            if ($allDone) { break }
            Wait-WithDispatcher -Milliseconds 50
        }

        # Cleanup any timed-out jobs
        foreach ($job in $pendingJobs) {
            if ($null -eq $job.Result) {
                try { $job.PS.Stop() } catch { }
                $job.PS.Dispose()
                $job.Result = [PSCustomObject]@{ StatusCode = 408; Content = '{"error":{"message":"Timeout"}}'; Headers = @{} }
            }
        }
        return $pendingJobs
    }

    # -- Strategy 1: Batched query using TagKey + TagValue grouping -----
    # This uses a single API call to get cost data for ALL tags at once,
    # instead of one call per tag. Dramatically reduces API calls and 429s.
    $batchedResults = $null
    $batchSuccess = $false
    $usedTimeframe = 'MonthToDate'

    $timeframes = @('MonthToDate', 'Custom')
    foreach ($tf in $timeframes) {
        if ($batchSuccess) { break }
        Write-Host "  Querying cost by all tags (batched, $tf)..." -ForegroundColor Cyan

        $bodyObj = @{
            type    = 'ActualCost'
            dataset = @{
                granularity = 'None'
                aggregation = @{
                    totalCost = @{ name = 'Cost'; function = 'Sum' }
                }
                grouping    = @(
                    @{ type = 'Dimension'; name = 'TagKey' }
                    @{ type = 'Dimension'; name = 'TagValue' }
                )
            }
        }
        if ($tf -eq 'Custom') {
            $lastMonthStart = (Get-Date).AddMonths(-1).ToString('yyyy-MM-01')
            $lastMonthEnd = (Get-Date -Day 1).AddDays(-1).ToString('yyyy-MM-dd')
            $bodyObj['timeframe'] = 'Custom'
            $bodyObj['timePeriod'] = @{ from = $lastMonthStart; to = $lastMonthEnd }
        }
        else {
            $bodyObj['timeframe'] = $tf
        }
        $body = $bodyObj | ConvertTo-Json -Depth 10

        if ($useMgScope) {
            $response = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $body
            if ($response.StatusCode -eq 200) {
                $batchedResults = Parse-BatchedCostRows -ResponseContent $response.Content
                if ($batchedResults.Count -gt 0) {
                    $batchSuccess = $true
                    $usedTimeframe = $tf
                    Write-Host "    Batched query returned $($batchedResults.Count) tag keys via MG scope ($tf)" -ForegroundColor Green
                }
            }
            elseif ($response.StatusCode -in @(401, 403)) {
                Set-MgCostScopeFailed
                $useMgScope = $false
            }
        }

        # Per-sub fallback for batched query (parallel)
        if (-not $batchSuccess -and $Subscriptions) {
            $allBatched = @{}
            $calls = @()
            foreach ($sub in $Subscriptions) {
                if ($skipSubs.Contains($sub.Id)) { continue }
                $calls += @{
                    Path    = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                    Body    = $body
                    SubId   = $sub.Id
                    SubName = $sub.Name
                }
            }
            if ($calls.Count -gt 0) {
                Write-Host "    Querying $($calls.Count) subs in parallel (batched $tf)..." -ForegroundColor Cyan
                $parallelJobs = Invoke-ParallelRestCalls -Calls $calls
                foreach ($pj in $parallelJobs) {
                    $subResp = $pj.Result
                    $subName = $pj.Call.SubName
                    $subId = $pj.Call.SubId
                    if ($subResp.StatusCode -eq 200) {
                        $subBatch = Parse-BatchedCostRows -ResponseContent $subResp.Content
                        foreach ($key in $subBatch.Keys) {
                            if (-not $allBatched.ContainsKey($key)) {
                                $allBatched[$key] = [System.Collections.Generic.List[PSCustomObject]]::new()
                            }
                            foreach ($r in $subBatch[$key]) { [void]$allBatched[$key].Add($r) }
                        }
                    }
                    elseif ($subResp.StatusCode -eq 400) {
                        $errBody = try { ($subResp.Content | ConvertFrom-Json).error.message } catch { '' }
                        Write-Host "    Batched query failed for '$subName' (HTTP 400): $($errBody.Substring(0, [math]::Min(120, $errBody.Length)))" -ForegroundColor Yellow
                        [void]$skipSubs.Add($subId)
                        if ($errBody -match 'AO View Charges') { $script:costAccessIssue = 'EA' }
                    }
                    elseif ($subResp.StatusCode -eq 403) {
                        Write-Host "    Batched query forbidden for '$subName' (HTTP 403)" -ForegroundColor Yellow
                        $script:costAccessIssue = 'MCA'
                    }
                    else {
                        Write-Host "    Batched query: '$subName' HTTP $($subResp.StatusCode)" -ForegroundColor Yellow
                    }
                }
            }
            if ($allBatched.Count -gt 0) {
                $batchedResults = $allBatched
                $batchSuccess = $true
                $usedTimeframe = $tf
                Write-Host "    Batched per-sub query returned $($allBatched.Count) tag keys ($tf)" -ForegroundColor Green
            }
        }
    }

    # Map batched results to per-tag results, matching against tagsToQuery
    if ($batchSuccess -and $batchedResults) {
        $tagsToQueryLower = @{}
        foreach ($t in $tagsToQuery) { $tagsToQueryLower[$t.ToLower()] = $t }

        foreach ($batchKey in $batchedResults.Keys) {
            # Match batch key to requested tag (case-insensitive)
            $matchedTag = $null
            if ($tagsToQueryLower.ContainsKey($batchKey.ToLower())) {
                $matchedTag = $tagsToQueryLower[$batchKey.ToLower()]
            }
            if (-not $matchedTag) { continue }

            $tagCosts = $batchedResults[$batchKey]
            # Merge duplicate values
            $merged = $tagCosts | Group-Object TagValue -CaseSensitive | ForEach-Object {
                [PSCustomObject]@{
                    TagValue = $_.Name
                    Cost     = [math]::Round(($_.Group | Measure-Object -Property Cost -Sum).Sum, 2)
                    Currency = $_.Group[0].Currency
                }
            }
            $results[$matchedTag] = @($merged | Sort-Object Cost -Descending)
        }

        # Check if any requested tags weren't in batched results
        $missingTags = @($tagsToQuery | Where-Object { -not $results.ContainsKey($_) })
        if ($missingTags.Count -gt 0) {
            Write-Host "  $($missingTags.Count) requested tags had no cost data in batched results" -ForegroundColor Yellow
        }
    }

    # -- Strategy 2: Per-tag fallback (only if batched query failed) ----
    # This is the original approach - one API call per tag. Only used when
    # the TagKey+TagValue grouping is not supported by the subscription type.
    # Optimized: per-sub queries run in parallel; tag count capped at 5.
    if (-not $batchSuccess) {
        # Clear skipSubs from batched query — Dimension/TagKey != Tag grouping
        $skipSubs.Clear()

        Write-Host "  Batched tag query not available, falling back to per-tag queries ($($tagsToQuery.Count) tags)..." -ForegroundColor Yellow

        $tagQueryCount = 0
        foreach ($tagName in $tagsToQuery) {
            $tagQueryCount++
            if ($tagQueryCount -gt 1) {
                Start-Sleep -Milliseconds 500
            }

            try {
                $tagCosts = [System.Collections.Generic.List[PSCustomObject]]::new()
                $gotData = $false
                $usedTimeframe = 'MonthToDate'

                foreach ($tf in $timeframes) {
                    if ($gotData) { break }

                    Write-Host "  Querying cost by tag: $tagName ($tf)..." -ForegroundColor Cyan
                    $bodyObj = @{
                        type    = 'ActualCost'
                        dataset = @{
                            granularity = 'None'
                            aggregation = @{
                                totalCost = @{ name = 'Cost'; function = 'Sum' }
                            }
                            grouping    = @(
                                @{ type = 'TagKey'; name = $tagName }
                            )
                        }
                    }
                    if ($tf -eq 'Custom') {
                        $lastMonthStart = (Get-Date).AddMonths(-1).ToString('yyyy-MM-01')
                        $lastMonthEnd = (Get-Date -Day 1).AddDays(-1).ToString('yyyy-MM-dd')
                        $bodyObj['timeframe'] = 'Custom'
                        $bodyObj['timePeriod'] = @{ from = $lastMonthStart; to = $lastMonthEnd }
                    }
                    else {
                        $bodyObj['timeframe'] = $tf
                    }
                    $body = $bodyObj | ConvertTo-Json -Depth 10

                    $tagCosts = [System.Collections.Generic.List[PSCustomObject]]::new()

                    if ($useMgScope) {
                        $response = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $body
                        if ($response.StatusCode -in @(401, 403)) {
                            Set-MgCostScopeFailed
                            $useMgScope = $false
                        }
                        elseif ($response.StatusCode -eq 200) {
                            $tagCosts = Parse-CostRows -ResponseContent $response.Content
                            if ($tagCosts.Count -gt 0) {
                                $gotData = $true
                                $usedTimeframe = $tf
                                Write-Host "    Found $($tagCosts.Count) tag values via MG scope ($tf)" -ForegroundColor Green
                            }
                        }
                        else {
                            $useMgScope = $false
                        }
                    }

                    # Per-subscription fallback — parallel (also runs if MG scope returned no rows)
                    if ((-not $useMgScope -or -not $gotData) -and $Subscriptions) {
                        $tagCosts = [System.Collections.Generic.List[PSCustomObject]]::new()
                        $calls = @()
                        foreach ($sub in $Subscriptions) {
                            if ($skipSubs.Contains($sub.Id)) { continue }
                            $calls += @{
                                Path    = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                                Body    = $body
                                SubId   = $sub.Id
                                SubName = $sub.Name
                            }
                        }
                        if ($calls.Count -gt 0) {
                            Write-Host "    Querying $($calls.Count) subs in parallel for $tagName ($tf)..." -ForegroundColor Cyan
                            $parallelJobs = Invoke-ParallelRestCalls -Calls $calls
                            foreach ($pj in $parallelJobs) {
                                $subResp = $pj.Result
                                if ($subResp.StatusCode -eq 200) {
                                    $subRows = Parse-CostRows -ResponseContent $subResp.Content
                                    foreach ($r in $subRows) { [void]$tagCosts.Add($r) }
                                }
                                elseif ($subResp.StatusCode -eq 400) {
                                    $errBody = try { ($subResp.Content | ConvertFrom-Json).error.message } catch { '' }
                                    if ($errBody -match 'Invalid dataset grouping') {
                                        [void]$skipSubs.Add($pj.Call.SubId)
                                    }
                                    elseif ($errBody -match 'AO View Charges') {
                                        $script:costAccessIssue = 'EA'
                                    }
                                }
                                elseif ($subResp.StatusCode -eq 403) {
                                    $script:costAccessIssue = 'MCA'
                                }
                            }
                        }

                        # Merge duplicate tag values across subs
                        if ($tagCosts.Count -gt 0) {
                            $merged = $tagCosts | Group-Object TagValue -CaseSensitive | ForEach-Object {
                                [PSCustomObject]@{
                                    TagValue = $_.Name
                                    Cost     = [math]::Round(($_.Group | Measure-Object -Property Cost -Sum).Sum, 2)
                                    Currency = $_.Group[0].Currency
                                }
                            }
                            $tagCosts = @($merged)
                            $gotData = $true
                            $usedTimeframe = $tf
                            Write-Host "    Found $($tagCosts.Count) tag values via per-sub parallel ($tf)" -ForegroundColor Green
                        }
                    }
                }

                $results[$tagName] = $tagCosts | Sort-Object Cost -Descending
            }
            catch {
                Write-Warning "Cost-by-tag query for '$tagName' failed: $($_.Exception.Message)"
            }
        }
    } # end per-tag fallback

    # Determine which timeframe was used (for display hint)
    $usedLastMonth = $false
    foreach ($tagName in $tagsToQuery) {
        if ($results.ContainsKey($tagName) -and $results[$tagName].Count -gt 0) { break }
    }

    return [PSCustomObject]@{
        TagsQueried   = $tagsToQuery
        CostByTag     = $results
        NoTagsFound   = ($tagsToQuery.Count -eq 0)
        UsedTimeframe = $usedTimeframe
    }
}
