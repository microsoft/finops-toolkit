# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

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

        # No -RestrictToSelected here: this scan queries each subscription
        # individually, so it is always scoped to $Subscriptions.
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

    # Helper: normalize an ARG tags bag (PSCustomObject or hashtable) into a
    # plain hashtable of tagKey -> tagValue.
    function ConvertTo-TagHash {
        param($Tags)
        $h = @{}
        if (-not $Tags) { return $h }
        if ($Tags -is [System.Collections.IDictionary]) {
            foreach ($k in $Tags.Keys) { $h[[string]$k] = [string]$Tags[$k] }
        }
        else {
            foreach ($p in $Tags.PSObject.Properties) { $h[[string]$p.Name] = [string]$p.Value }
        }
        return $h
    }

    # === Build resource -> tag maps via Azure Resource Graph =============
    # The reliable, throttle-resistant way to allocate cost by tag is to query
    # cost grouped by ResourceId (one cheap, universally-supported call per
    # subscription) and join it client-side against each resource's tags. ARG
    # supplies that join data without hammering the Cost Management API. We
    # capture resource-level tags plus resource-group-level tags (used as a
    # fallback when a resource carries no tag of its own but its RG does).
    $subIds    = @($Subscriptions | ForEach-Object { $_.Id })
    $resTagMap = @{}   # lowercased resourceId        -> @{ tagKey = tagValue }
    $rgTagMap  = @{}   # lowercased resourceGroup id  -> @{ tagKey = tagValue }
    try {
        Write-Host "  Building resource -> tag map via Resource Graph..." -ForegroundColor Cyan
        $resTagQuery = "resources | where isnotempty(tags) | project id, tags"
        $skip = $null
        do {
            $r = Search-AzGraphSafe -Query $resTagQuery -Subscription $subIds -First 1000 -SkipToken $skip
            if (-not $r -or -not $r.Data) { break }
            foreach ($row in $r.Data) {
                if ($row.id) { $resTagMap[([string]$row.id).ToLower()] = ConvertTo-TagHash $row.tags }
            }
            $skip = $r.SkipToken
        } while ($skip)

        $rgTagQuery = "resourcecontainers | where type =~ 'microsoft.resources/subscriptions/resourcegroups' | where isnotempty(tags) | project id, tags"
        $skip = $null
        do {
            $r = Search-AzGraphSafe -Query $rgTagQuery -Subscription $subIds -First 1000 -SkipToken $skip
            if (-not $r -or -not $r.Data) { break }
            foreach ($row in $r.Data) {
                if ($row.id) { $rgTagMap[([string]$row.id).ToLower()] = ConvertTo-TagHash $row.tags }
            }
            $skip = $r.SkipToken
        } while ($skip)

        Write-Host "    Mapped tags for $($resTagMap.Count) resources, $($rgTagMap.Count) resource groups" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Resource tag map build failed: $($_.Exception.Message). Cost-by-tag will rely on whatever map data was collected."
    }

    # Helper: parse a ResourceId-grouped Cost Management response into rows of
    # @{ ResourceId; Cost; Currency }. Rows with an empty ResourceId represent
    # non-resource charges (reservations, marketplace, refunds/credits).
    function Parse-ResourceIdRows {
        param($ResponseContent)
        $parsed = [System.Collections.Generic.List[PSCustomObject]]::new()
        $result = ($ResponseContent | ConvertFrom-Json)
        if (-not $result.properties -or -not $result.properties.rows -or $result.properties.rows.Count -eq 0) {
            return $parsed
        }
        $cols = $result.properties.columns
        $costIdx = -1; $ridIdx = -1; $currIdx = -1
        for ($i = 0; $i -lt $cols.Count; $i++) {
            $n = $cols[$i].name.ToLower()
            if ($n -eq 'cost' -or $n -eq 'totalcost' -or $n -match 'precost|pretaxcost') { $costIdx = $i }
            elseif ($n -match 'currency|billingcurrency') { $currIdx = $i }
            elseif ($n -eq 'resourceid') { $ridIdx = $i }
        }
        if ($costIdx -eq -1) { $costIdx = 0 }
        if ($ridIdx -eq -1) { $ridIdx = 1 }
        if ($currIdx -eq -1) { $currIdx = if ($cols.Count -ge 3) { 2 } else { -1 } }

        foreach ($row in $result.properties.rows) {
            $cost = [math]::Round([double]$row[$costIdx], 2)
            $rid  = if ($ridIdx -ge 0 -and $ridIdx -lt $row.Count -and $row[$ridIdx]) { [string]$row[$ridIdx] } else { '' }
            $currency = if ($currIdx -ge 0 -and $currIdx -lt $row.Count) { $row[$currIdx] } else { 'USD' }
            [void]$parsed.Add([PSCustomObject]@{ ResourceId = $rid; Cost = $cost; Currency = $currency })
        }
        return $parsed
    }

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

    # === Query cost grouped by ResourceId, one call per subscription ======
    # ResourceId grouping is supported at subscription scope across EA, MCA and
    # pay-as-you-go (unlike TagKey/TagValue, which 400/408s on most sub types).
    # This collapses the old tags x subs x timeframes call matrix down to a
    # single call per subscription, then attributes each resource's cost to its
    # tag values client-side. The scan is built to COMPLETE even when some subs
    # fail: a failed subscription is recorded and skipped, never thrown.
    $usedTimeframe = 'MonthToDate'
    $timeframes    = @('MonthToDate', 'Custom')

    # Per-tag aggregation: tagName -> (tagValue -> accumulated cost)
    $tagAgg = @{}
    foreach ($t in $tagsToQuery) { $tagAgg[$t] = @{} }
    $currencySeen = 'USD'
    $subsQueried  = 0
    $subsFailed   = 0
    $grandTotal   = 0.0

    if (-not $Subscriptions -or $Subscriptions.Count -eq 0) {
        Write-Host "  No subscriptions available for cost-by-tag." -ForegroundColor Yellow
    }
    elseif ($tagsToQuery.Count -eq 0) {
        Write-Host "  No allocation tags found to break cost down by." -ForegroundColor Yellow
    }
    else {
        foreach ($tf in $timeframes) {
            # MonthToDate first; only fall back to last month (Custom) when MTD
            # produced no cost at all (e.g. the first day of a new billing month).
            if ($tf -eq 'Custom' -and $grandTotal -gt 0) { break }
            if ($tf -eq 'Custom') {
                Write-Host "  MonthToDate returned no cost - retrying with last month..." -ForegroundColor Yellow
                foreach ($t in $tagsToQuery) { $tagAgg[$t] = @{} }
                $subsQueried = 0; $subsFailed = 0; $grandTotal = 0.0
            }

            $bodyObj = @{
                type    = 'ActualCost'
                dataset = @{
                    granularity = 'None'
                    aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                    grouping    = @( @{ type = 'Dimension'; name = 'ResourceId' } )
                }
            }
            if ($tf -eq 'Custom') {
                $lastMonthStart = (Get-Date).AddMonths(-1).ToString('yyyy-MM-01')
                $lastMonthEnd   = (Get-Date -Day 1).AddDays(-1).ToString('yyyy-MM-dd')
                $bodyObj['timeframe']  = 'Custom'
                $bodyObj['timePeriod'] = @{ from = $lastMonthStart; to = $lastMonthEnd }
            }
            else {
                $bodyObj['timeframe'] = $tf
            }
            $body = $bodyObj | ConvertTo-Json -Depth 10

            # Fan out across subscriptions in capped batches so a large tenant
            # never floods the Cost Management API. Each call self-retries 429.
            $batchSize = 8
            $subList   = @($Subscriptions)
            for ($offset = 0; $offset -lt $subList.Count; $offset += $batchSize) {
                $upper = [math]::Min($offset + $batchSize - 1, $subList.Count - 1)
                $slice = @($subList[$offset..$upper])
                $calls = @()
                foreach ($sub in $slice) {
                    $calls += @{
                        Path    = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                        Body    = $body
                        SubId   = $sub.Id
                        SubName = $sub.Name
                    }
                }
                $done = [math]::Min($offset + $slice.Count, $subList.Count)
                Write-Host "  Cost-by-tag: subscriptions $($offset + 1)-$done of $($subList.Count) ($tf)..." -ForegroundColor Cyan
                $jobs = Invoke-ParallelRestCalls -Calls $calls -TimeoutSeconds 120
                foreach ($pj in $jobs) {
                    $subResp = $pj.Result
                    if ($subResp.StatusCode -eq 200) {
                        $subsQueried++
                        $rows = Parse-ResourceIdRows -ResponseContent $subResp.Content
                        foreach ($row in $rows) {
                            $cost = $row.Cost
                            $grandTotal += $cost
                            if ($row.Currency) { $currencySeen = $row.Currency }

                            if ([string]::IsNullOrWhiteSpace($row.ResourceId)) {
                                foreach ($t in $tagsToQuery) {
                                    $cur = [double]$tagAgg[$t]['(non-resource charges)']
                                    $tagAgg[$t]['(non-resource charges)'] = $cur + $cost
                                }
                                continue
                            }

                            $ridLower = $row.ResourceId.ToLower()
                            $tags = $resTagMap[$ridLower]
                            if (-not $tags -or $tags.Count -eq 0) {
                                $pIdx = $ridLower.IndexOf('/providers/')
                                if ($pIdx -gt 0) {
                                    $rgId = $ridLower.Substring(0, $pIdx)
                                    $tags = $rgTagMap[$rgId]
                                }
                            }

                            foreach ($t in $tagsToQuery) {
                                $val = $null
                                if ($tags -and $tags.Count -gt 0) {
                                    foreach ($k in $tags.Keys) {
                                        if ($k -ieq $t) { $val = $tags[$k]; break }
                                    }
                                }
                                if ([string]::IsNullOrWhiteSpace($val)) { $val = '(untagged resources)' }
                                $cur = [double]$tagAgg[$t][$val]
                                $tagAgg[$t][$val] = $cur + $cost
                            }
                        }
                    }
                    elseif ($subResp.StatusCode -eq 403) {
                        $subsFailed++
                        $script:costAccessIssue = 'MCA'
                    }
                    elseif ($subResp.StatusCode -eq 400) {
                        $subsFailed++
                        $errBody = try { ($subResp.Content | ConvertFrom-Json).error.message } catch { '' }
                        if ($errBody -match 'AO View Charges') { $script:costAccessIssue = 'EA' }
                    }
                    else {
                        $subsFailed++
                    }
                }
            }

            $usedTimeframe = $tf
        }

        if ($subsFailed -gt 0) {
            Write-Host "  Cost-by-tag completed: $subsQueried subscription(s) returned data, $subsFailed skipped (timeout / throttle / access)." -ForegroundColor Yellow
        }
        else {
            Write-Host "  Cost-by-tag completed: $subsQueried subscription(s) returned data." -ForegroundColor Green
        }
    }

    # === Materialize aggregation into the result contract =================
    # For each tag, emit { TagValue; Cost; Currency } rows sorted by cost desc.
    # The synthetic "(untagged resources)" and "(non-resource charges)" values
    # reconcile the breakdown back to the subscription invoice total.
    foreach ($t in $tagsToQuery) {
        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($val in $tagAgg[$t].Keys) {
            $c = [math]::Round([double]$tagAgg[$t][$val], 2)
            if ($c -eq 0) { continue }
            [void]$rows.Add([PSCustomObject]@{ TagValue = $val; Cost = $c; Currency = $currencySeen })
        }
        $results[$t] = @($rows | Sort-Object Cost -Descending)
    }

    return [PSCustomObject]@{
        TagsQueried   = $tagsToQuery
        CostByTag     = $results
        NoTagsFound   = ($tagsToQuery.Count -eq 0)
        UsedTimeframe = $usedTimeframe
    }
}
