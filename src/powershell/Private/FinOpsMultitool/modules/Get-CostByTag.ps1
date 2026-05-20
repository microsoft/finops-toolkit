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
        'CostCenter'          = @('cost-center', 'costcenter', 'cost_center', 'cc')
        'BusinessUnit'        = @('bu', 'businessunit', 'business-unit', 'department', 'dept')
        'ApplicationName'     = @('applicationname', 'application', 'app', 'appname', 'app-name')
        'WorkloadName'        = @('workloadname', 'workload', 'workload-name', 'workload_name')
        'OpsTeam'             = @('opsteam', 'ops-team', 'ops_team', 'owner', 'technicalowner')
        'Criticality'         = @('criticality', 'sla', 'tier', 'importance')
        'DataClassification'  = @('dataclassification', 'data-classification', 'data_classification', 'classification')
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
    if ($ExistingTags) {
        $alreadyLower = $tagsToQuery | ForEach-Object { $_.ToLower() }
        $systemPrefixes = @('hidden-', 'ms-resource-', 'aks-managed-', 'kubernetes.io', 'displayname')
        foreach ($key in ($ExistingTags.Keys | Sort-Object)) {
            if ($key.ToLower() -in $alreadyLower) { continue }
            $skip = $false
            foreach ($prefix in $systemPrefixes) {
                if ($key.ToLower().StartsWith($prefix)) { $skip = $true; break }
            }
            if (-not $skip) { $tagsToQuery += $key }
        }
    }

    $results = @{}
    $useMgScope = Test-MgCostScope
    $mgPath = "/providers/Microsoft.Management/managementGroups/$TenantId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"

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
            elseif ($n -eq 'tagvalue')  { $tagIdx = $i }
        }
        # Fallback: if TagValue column not found, pick first String column that isn't TagKey or Currency
        if ($tagIdx -eq -1) {
            for ($i = 0; $i -lt $cols.Count; $i++) {
                if ($cols[$i].type -eq 'String' -and $i -ne $currIdx -and $cols[$i].name.ToLower() -ne 'tagkey') { $tagIdx = $i; break }
            }
        }
        # Final positional fallback
        if ($costIdx -eq -1) { $costIdx = 0 }
        if ($tagIdx -eq -1)  { $tagIdx  = if ($cols.Count -ge 4) { 2 } else { 1 } }
        if ($currIdx -eq -1) { $currIdx = if ($cols.Count -ge 4) { 3 } else { 2 } }

        foreach ($row in $result.properties.rows) {
            $cost     = [math]::Round([double]$row[$costIdx], 2)
            $value    = if ($row[$tagIdx]) { $row[$tagIdx] } else { '(untagged)' }
            $currency = if ($currIdx -lt $row.Count) { $row[$currIdx] } else { 'USD' }
            [void]$parsed.Add([PSCustomObject]@{ TagValue = $value; Cost = $cost; Currency = $currency })
        }
        return $parsed
    }

    # Build both timeframe bodies: MonthToDate first, then last month as fallback
    $timeframes = @('MonthToDate', 'Custom')

    foreach ($tagName in $tagsToQuery) {

        try {
            $tagCosts = [System.Collections.Generic.List[PSCustomObject]]::new()
            $gotData  = $false
            $usedTimeframe = 'MonthToDate'

            foreach ($tf in $timeframes) {
                if ($gotData) { break }

                Write-Host "  Querying cost by tag: $tagName ($tf)..." -ForegroundColor Cyan
                $bodyObj = @{
                    type      = 'ActualCost'
                    dataset   = @{
                        granularity = 'None'
                        aggregation = @{
                            totalCost = @{ name = 'Cost'; function = 'Sum' }
                        }
                        grouping = @(
                            @{ type = 'Tag'; name = $tagName }
                        )
                    }
                }
                if ($tf -eq 'Custom') {
                    $lastMonthStart = (Get-Date).AddMonths(-1).ToString('yyyy-MM-01')
                    $lastMonthEnd   = (Get-Date -Day 1).AddDays(-1).ToString('yyyy-MM-dd')
                    $bodyObj['timeframe'] = 'Custom'
                    $bodyObj['timePeriod'] = @{ from = $lastMonthStart; to = $lastMonthEnd }
                } else {
                    $bodyObj['timeframe'] = $tf
                }
                $body = $bodyObj | ConvertTo-Json -Depth 10

                $tagCosts = [System.Collections.Generic.List[PSCustomObject]]::new()

                if ($useMgScope) {
                    $response = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $body
                    Write-Host "    MG-scope response: HTTP $($response.StatusCode)" -ForegroundColor Gray
                    if ($response.StatusCode -in @(401, 403)) {
                        Set-MgCostScopeFailed
                        Write-Warning "  MG-scope cost-by-tag returned HTTP $($response.StatusCode) - falling back to per-subscription"
                        $useMgScope = $false
                    }
                    elseif ($response.StatusCode -ne 200) {
                        Write-Warning "  MG-scope cost-by-tag returned HTTP $($response.StatusCode) - falling back to per-subscription"
                        if ($response.Content) {
                            $errBody = try { ($response.Content | ConvertFrom-Json).error.message } catch { $response.Content.Substring(0, [math]::Min(200, $response.Content.Length)) }
                            Write-Warning "    Response: $errBody"
                        }
                        $useMgScope = $false
                    }
                    else {
                        $tagCosts = Parse-CostRows -ResponseContent $response.Content
                        if ($tagCosts.Count -gt 0) {
                            $gotData = $true
                            $usedTimeframe = $tf
                            Write-Host "    Found $($tagCosts.Count) tag values via MG scope ($tf)" -ForegroundColor Green
                        } else {
                            Write-Host "    MG scope returned 0 rows for $tf" -ForegroundColor Yellow
                        }
                    }
                }

                # Per-subscription fallback (also runs if MG scope returned no rows)
                if ((-not $useMgScope -or -not $gotData) -and $Subscriptions) {
                    $tagCosts = [System.Collections.Generic.List[PSCustomObject]]::new()

                    # Sample first 3 subs - if all return 0, skip the remaining subs
                    $sampleSize = [math]::Min(3, $Subscriptions.Count)
                    $sampleHits = 0
                    for ($i = 0; $i -lt $sampleSize; $i++) {
                        $sub = $Subscriptions[$i]
                        if ($skipSubs.Contains($sub.Id)) { continue }
                        $subPath = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                        Write-Host "    Per-sub query: $($sub.Name) ($tf)..." -ForegroundColor Gray
                        $subResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload $body
                        Write-Host "    Per-sub response: HTTP $($subResp.StatusCode)" -ForegroundColor Gray
                        if ($subResp.StatusCode -eq 200) {
                            # Log raw response for diagnostics
                            $rawParsed = try { ($subResp.Content | ConvertFrom-Json) } catch { $null }
                            $rowCount = if ($rawParsed -and $rawParsed.properties -and $rawParsed.properties.rows) { $rawParsed.properties.rows.Count } else { 0 }
                            $colNames = if ($rawParsed -and $rawParsed.properties -and $rawParsed.properties.columns) { ($rawParsed.properties.columns | ForEach-Object { "$($_.name)($($_.type))" }) -join ', ' } else { 'N/A' }
                            Write-Host "    Columns: $colNames | Rows: $rowCount" -ForegroundColor Gray
                            if ($rowCount -gt 0 -and $rowCount -le 5) {
                                foreach ($row in $rawParsed.properties.rows) {
                                    Write-Host "      Row: $($row -join ' | ')" -ForegroundColor DarkGray
                                }
                            }
                            $subRows = Parse-CostRows -ResponseContent $subResp.Content
                            foreach ($r in $subRows) { [void]$tagCosts.Add($r) }
                            if ($subRows.Count -gt 0) { $sampleHits++ }
                        } elseif ($subResp.Content) {
                            $errBody = try { ($subResp.Content | ConvertFrom-Json).error.message } catch { $subResp.Content.Substring(0, [math]::Min(300, $subResp.Content.Length)) }
                            if ($errBody -match 'Invalid dataset grouping') {
                                [void]$skipSubs.Add($sub.Id)
                                Write-Host "    Skipping '$($sub.Name)' - subscription type does not support Tag grouping" -ForegroundColor Yellow
                            } else {
                                Write-Warning "    Per-sub error: $errBody"
                            }
                        }
                    }

                    # Only iterate remaining subs if sample found data
                    if ($sampleHits -gt 0 -and $Subscriptions.Count -gt $sampleSize) {
                        Write-Host "    Sample found data, querying remaining $($Subscriptions.Count - $sampleSize) subs..." -ForegroundColor Cyan
                        for ($i = $sampleSize; $i -lt $Subscriptions.Count; $i++) {
                            $sub = $Subscriptions[$i]
                            if ($skipSubs.Contains($sub.Id)) { continue }
                            $subPath = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                            $subResp = Invoke-AzRestMethodWithRetry -Path $subPath -Method POST -Payload $body
                            if ($subResp.StatusCode -eq 200) {
                                $subRows = Parse-CostRows -ResponseContent $subResp.Content
                                foreach ($r in $subRows) { [void]$tagCosts.Add($r) }
                            } elseif ($subResp.StatusCode -eq 400 -and $subResp.Content -match 'Invalid dataset grouping') {
                                [void]$skipSubs.Add($sub.Id)
                            }
                        }
                    } elseif ($sampleHits -eq 0 -and $Subscriptions.Count -gt $sampleSize) {
                        Write-Host "    Sample of $sampleSize subs returned 0 rows - skipping remaining subs for $tf" -ForegroundColor Yellow
                    }

                    # Merge duplicate tag values across subs (case-sensitive to surface casing inconsistencies)
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
                        Write-Host "    Found $($tagCosts.Count) tag values via per-sub fallback ($tf)" -ForegroundColor Green
                    } else {
                        Write-Host "    Per-sub fallback returned 0 rows for $tf" -ForegroundColor Yellow
                    }
                }
            }

            $results[$tagName] = $tagCosts | Sort-Object Cost -Descending
        } catch {
            Write-Warning "Cost-by-tag query for '$tagName' failed: $($_.Exception.Message)"
        }
    }

    # Determine which timeframe was used (for display hint)
    $usedLastMonth = $false
    foreach ($tagName in $tagsToQuery) {
        if ($results.ContainsKey($tagName) -and $results[$tagName].Count -gt 0) { break }
    }

    return [PSCustomObject]@{
        TagsQueried    = $tagsToQuery
        CostByTag      = $results
        NoTagsFound    = ($tagsToQuery.Count -eq 0)
        UsedTimeframe  = $usedTimeframe
    }
}
