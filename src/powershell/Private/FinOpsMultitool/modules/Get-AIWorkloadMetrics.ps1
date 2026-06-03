###########################################################################
# GET-AIWORKLOADMETRICS.PS1
# AZURE FINOPS MULTITOOL - AI/LLM Workload KPIs (token economics)
###########################################################################
# Purpose: Detect AI workloads up front with one cheap ARG query, and -
#          only when AI is present - pull historical token usage from
#          Azure Monitor metrics and join it to Cost Management spend to
#          compute AI/LLM unit-economics KPIs (cost per 1K tokens, cost
#          per request, token volume by model).
###########################################################################
# Notes:
# - Gate-first: if no AI footprint exists, the module returns after a
#   single ARG call (~50ms) so non-AI tenants pay almost nothing.
# - Token metrics: ProcessedPromptTokens (input), GeneratedTokens
#   (output), TokenTransaction (total inference), AzureOpenAIRequests
#   (call count), split by ModelDeploymentName. Window is month-to-date
#   so it aligns 1:1 with the MonthToDate amortized cost query.
# - RBAC: Reader (ARG + Azure Monitor metrics) + Cost Management Reader
#   (billing/MG scope) to map tokens to spend.
# - KPIs covered: Token Consumption, Cost per API Call, Cost per 1K
#   tokens (effective rate). Cost per Inference is a request-count proxy.
# - Export path: when -HubData (FOCUS rows from a FinOps Hub export) is
#   supplied, AI spend and billed token volume are read from the export
#   instead of the Monitor + Cost Management APIs - zero live cost calls.
#   Request counts are not billed line items, so cost-per-request is only
#   available on the live API path.
###########################################################################

function Get-AIWorkloadMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [Parameter()]
        [object[]]$Subscriptions,

        [Parameter()]
        [object[]]$HubData
    )

    Write-Host "  Detecting AI workloads..." -ForegroundColor Cyan

    $subIds = @($Subscriptions | ForEach-Object { $_.Id })

    # -- 0: Cheap presence gate (one ARG call) ----------------------------
    # Count AI resources by type/kind. If nothing is found we bail out
    # immediately so non-AI tenants never run the expensive metrics + cost
    # loop below.
    $openAiAccounts = [System.Collections.Generic.List[PSCustomObject]]::new()
    $aiServiceCount = 0
    $mlWorkspaceCount = 0
    $searchCount = 0
    $gpuVmCount = 0

    try {
        $gateQuery = @"
resources
| extend lkind = tolower(tostring(kind))
| where type =~ 'microsoft.cognitiveservices/accounts'
    or type =~ 'microsoft.machinelearningservices/workspaces'
    or type =~ 'microsoft.search/searchservices'
    or (type =~ 'microsoft.compute/virtualmachines'
        and tostring(properties.hardwareProfile.vmSize) matches regex @'(?i)^Standard_N')
| project id, name, type, lkind, subscriptionId, location
"@
        $result = Search-AzGraphSafe -Query $gateQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }

        foreach ($r in $rows) {
            switch -Wildcard ([string]$r.type) {
                'microsoft.cognitiveservices/accounts' {
                    # OpenAI + AIServices accounts expose token metrics.
                    if ($r.lkind -match 'openai' -or $r.lkind -match 'aiservices') {
                        [void]$openAiAccounts.Add([PSCustomObject]@{
                                Id             = [string]$r.id
                                Name           = [string]$r.name
                                SubscriptionId = [string]$r.subscriptionId
                                Location       = [string]$r.location
                            })
                    }
                    else { $aiServiceCount++ }
                }
                'microsoft.machinelearningservices/workspaces' { $mlWorkspaceCount++ }
                'microsoft.search/searchservices' { $searchCount++ }
                'microsoft.compute/virtualmachines' { $gpuVmCount++ }
            }
        }
    }
    catch {
        Write-Warning "  AI detection query failed: $($_.Exception.Message)"
    }

    $footprint = [PSCustomObject]@{
        OpenAIAccounts = $openAiAccounts.Count
        AIServices     = $aiServiceCount
        MLWorkspaces   = $mlWorkspaceCount
        SearchServices = $searchCount
        GpuVmCount     = $gpuVmCount
    }

    $anyAI = ($openAiAccounts.Count + $aiServiceCount + $mlWorkspaceCount + $searchCount + $gpuVmCount) -gt 0
    if (-not $anyAI) {
        Write-Host "    No AI workloads detected - skipping AI KPIs." -ForegroundColor Gray
        return [PSCustomObject]@{
            HasData     = $false
            AIFootprint = $footprint
            ScannedSubs = $Subscriptions.Count
            Note        = 'No AI workloads detected in the scanned subscriptions.'
        }
    }

    Write-Host ("    AI footprint - OpenAI/AIServices: {0}  ML: {1}  Search: {2}  GPU VMs: {3}" -f `
        ($openAiAccounts.Count + $aiServiceCount), $mlWorkspaceCount, $searchCount, $gpuVmCount) -ForegroundColor Gray

    # -- 1: Historical token usage (Azure Monitor metrics) ----------------
    # Month-to-date so it lines up with the MonthToDate cost query. Daily
    # interval keeps the payload to ~30 datapoints per account.
    $now = (Get-Date).ToUniversalTime()
    $monthStart = (Get-Date -Year $now.Year -Month $now.Month -Day 1 -Hour 0 -Minute 0 -Second 0).ToUniversalTime()
    $fromStr = $monthStart.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $toStr = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')

    $modelTokens = @{}   # deployment -> @{ Prompt; Generated; Total }
    $acctTokens = @{}   # resourceId(lower) -> @{ Tokens; Requests }
    $totalPrompt = 0.0
    $totalGen = 0.0
    $totalTokens = 0.0
    $totalReq = 0.0
    $metricsOk = $false

    $aiCost = 0.0
    $currency = 'USD'
    $costByAcct = @{}   # resourceId(lower) -> cost
    $costOk = $false

    # -- Export path: derive tokens + cost from a FinOps Hub export -------
    # When FOCUS rows are supplied we read AI spend and billed token volume
    # straight from the export - no Azure Monitor and no Cost Management API
    # calls. Request counts are not billed line items, so cost-per-request
    # is left unavailable on this path.
    $fromHub = $false
    $hubApprox = $false
    if ($HubData -and @($HubData).Count -gt 0) {
        $agg = ConvertTo-AIHubAggregates -HubData $HubData
        if ($agg -and ($agg.HasCost -or $agg.HasTokens)) {
            $fromHub = $true
            $hubApprox = $agg.Approximate
            $modelTokens = $agg.ModelTokens
            $acctTokens = $agg.AcctTokens
            $costByAcct = $agg.CostByAcct
            $totalPrompt = $agg.TotalPrompt
            $totalGen = $agg.TotalGen
            $totalTokens = $agg.TotalTokens
            $aiCost = $agg.AICost
            $currency = $agg.Currency
            $metricsOk = $agg.HasTokens
            $costOk = $agg.HasCost
            Write-Host ("    Derived from FinOps Hub export: {0} token rows, {1} {2} AI spend" -f `
                    $agg.RowCount, [math]::Round($agg.AICost, 2), $agg.Currency) -ForegroundColor Gray
        }
    }

    if (-not $fromHub -and $openAiAccounts.Count -gt 0) {
        $token = $null
        try { $token = (Get-AzAccessToken -ResourceUrl 'https://management.azure.com').Token } catch { }

        if ($token) {
            $headers = @{ 'Authorization' = "Bearer $token"; 'Content-Type' = 'application/json' }
            $metricNames = 'ProcessedPromptTokens,GeneratedTokens,TokenTransaction,AzureOpenAIRequests'
            $idx = 0
            $acctCount = $openAiAccounts.Count

            foreach ($acct in $openAiAccounts) {
                $idx++
                if ($acctCount -gt 5 -and ($idx -eq 1 -or $idx % [math]::Max(1, [int]($acctCount / 5)) -eq 0)) {
                    if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                        Update-ScanStatus "Reading AI token metrics ($idx/$acctCount accounts)..."
                    }
                }

                $acctKey = $acct.Id.ToLowerInvariant()
                if (-not $acctTokens.ContainsKey($acctKey)) {
                    $acctTokens[$acctKey] = @{ Name = $acct.Name; Tokens = 0.0; Requests = 0.0 }
                }

                # Split by deployment so per-model KPIs are available. The
                # filter literal needs a single-quoted segment to keep the
                # '$filter' token and the '*' from being touched by PowerShell.
                $filterSeg = '&$filter=' + [uri]::EscapeDataString("ModelDeploymentName eq '*'")
                $metricUri = "https://management.azure.com$($acct.Id)/providers/Microsoft.Insights/metrics?api-version=2023-10-01&metricnames=$metricNames&timespan=$fromStr/$toStr&aggregation=Total&interval=P1D$filterSeg"

                try {
                    $resp = Invoke-WebRequest -Uri $metricUri -Headers $headers -Method Get -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
                    $data = $resp.Content | ConvertFrom-Json
                    $metricsOk = $true

                    foreach ($metric in $data.value) {
                        $mName = $metric.name.value
                        foreach ($ts in $metric.timeseries) {
                            # Deployment name comes from the splitting dimension.
                            $deployment = 'unknown'
                            if ($ts.metadatavalues) {
                                foreach ($mv in $ts.metadatavalues) {
                                    if ($mv.name.value -match '(?i)ModelDeploymentName') { $deployment = [string]$mv.value }
                                }
                            }
                            $sum = 0.0
                            foreach ($dp in $ts.data) { if ($null -ne $dp.total) { $sum += [double]$dp.total } }

                            if (-not $modelTokens.ContainsKey($deployment)) {
                                $modelTokens[$deployment] = @{ Prompt = 0.0; Generated = 0.0; Total = 0.0 }
                            }
                            switch ($mName) {
                                'ProcessedPromptTokens' { $modelTokens[$deployment].Prompt += $sum; $totalPrompt += $sum; $acctTokens[$acctKey].Tokens += $sum }
                                'GeneratedTokens' { $modelTokens[$deployment].Generated += $sum; $totalGen += $sum; $acctTokens[$acctKey].Tokens += $sum }
                                'TokenTransaction' { $modelTokens[$deployment].Total += $sum; $totalTokens += $sum }
                                'AzureOpenAIRequests' { $totalReq += $sum; $acctTokens[$acctKey].Requests += $sum }
                            }
                        }
                    }
                }
                catch {
                    # Metrics unavailable for this account (no usage yet, or
                    # not an OpenAI-capable kind) - skip it.
                }
            }
        }
    }

    # When TokenTransaction is sparse, fall back to prompt + generated.
    if ($totalTokens -le 0) { $totalTokens = $totalPrompt + $totalGen }

    # -- 2: Map tokens to AI spend (Cost Management) ----------------------
    # Skipped entirely on the export path - spend already came from the Hub.
    if (-not $fromHub) {
        try {
            $mgScopeId = Resolve-CostMgId -TenantId $TenantId
            if ($mgScopeId) {
                $rtFilter = @{ dimensions = @{ name = 'ResourceType'; operator = 'In'; values = @('microsoft.cognitiveservices/accounts') } }
                $subFilter = Get-CostSubscriptionFilter -Subscriptions $Subscriptions
                $filterNode = if ($subFilter) { @{ and = @($subFilter, $rtFilter) } } else { $rtFilter }

                $body = @{
                    type      = 'AmortizedCost'
                    timeframe = 'MonthToDate'
                    dataset   = @{
                        granularity = 'None'
                        aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                        grouping    = @(@{ type = 'Dimension'; name = 'ResourceId' })
                        filter      = $filterNode
                    }
                } | ConvertTo-Json -Depth 12

                $path = "/providers/Microsoft.Management/managementGroups/$mgScopeId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
                $resp = Invoke-AzRestMethodWithRetry -Path $path -Method POST -Payload $body

                if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                    $cdata = $resp.Content | ConvertFrom-Json
                    if ($cdata.properties.rows) {
                        $costOk = $true
                        # Column order follows properties.columns; resolve indices.
                        $cols = @($cdata.properties.columns.name)
                        $iCost = [array]::IndexOf($cols, 'Cost')
                        $iRes = [array]::IndexOf($cols, 'ResourceId')
                        $iCur = [array]::IndexOf($cols, 'Currency')
                        foreach ($row in $cdata.properties.rows) {
                            $amount = if ($iCost -ge 0) { [double]$row[$iCost] } else { [double]$row[0] }
                            $rid = if ($iRes -ge 0) { [string]$row[$iRes] } else { '' }
                            if ($iCur -ge 0 -and $row[$iCur]) { $currency = [string]$row[$iCur] }
                            $aiCost += $amount
                            if ($rid) { $costByAcct[$rid.ToLowerInvariant()] = $amount }
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "  AI cost query failed: $($_.Exception.Message)"
        }
    }

    # -- 3: KPIs ----------------------------------------------------------
    $costPer1kTokens = if ($totalTokens -gt 0) { [math]::Round(($aiCost / $totalTokens) * 1000, 4) } else { 0 }
    $costPerRequest = if ($totalReq -gt 0) { [math]::Round($aiCost / $totalReq, 4) } else { 0 }

    $byModel = @(
        $modelTokens.GetEnumerator() | ForEach-Object {
            $mt = if ($_.Value.Total -gt 0) { $_.Value.Total } else { $_.Value.Prompt + $_.Value.Generated }
            [PSCustomObject]@{
                Deployment      = $_.Key
                PromptTokens    = [long]$_.Value.Prompt
                GeneratedTokens = [long]$_.Value.Generated
                TotalTokens     = [long]$mt
                PctOfTokens     = if ($totalTokens -gt 0) { [math]::Round(($mt / $totalTokens) * 100, 1) } else { 0 }
            }
        } | Sort-Object TotalTokens -Descending
    )

    $byAccount = @(
        $acctTokens.GetEnumerator() | ForEach-Object {
            $c = if ($costByAcct.ContainsKey($_.Key)) { $costByAcct[$_.Key] } else { 0.0 }
            $tk = $_.Value.Tokens
            [PSCustomObject]@{
                Name            = $_.Value.Name
                ResourceId      = $_.Key
                Tokens          = [long]$tk
                Requests        = [long]$_.Value.Requests
                Cost            = [math]::Round($c, 2)
                CostPer1KTokens = if ($tk -gt 0) { [math]::Round(($c / $tk) * 1000, 4) } else { 0 }
            }
        } | Sort-Object Cost -Descending
    )

    $hasData = $anyAI

    if ($fromHub) {
        $approxNote = if ($hubApprox) { ' Token volume is approximate where the billing unit could not be parsed.' } else { '' }
        if ($metricsOk -and $costOk) {
            $note = "AI spend and billed token volume read from the FinOps Hub export (no live API calls). Cost per request is unavailable on the export path - request counts are not billed line items.$approxNote"
        }
        elseif ($costOk) {
            $note = "AI spend read from the FinOps Hub export, but the export had no token-metered Azure OpenAI usage to price.$approxNote"
        }
        else {
            $note = "AI footprint detected; the FinOps Hub export had no Cognitive Services spend in the period.$approxNote"
        }
    }
    elseif ($metricsOk -and $costOk) {
        $note = 'Token volume is month-to-date from Azure Monitor; cost is month-to-date amortized.'
    }
    elseif ($metricsOk) {
        $note = 'Token volume available, but AI cost could not be read (Cost Management Reader needed to compute cost per token).'
    }
    elseif ($openAiAccounts.Count -gt 0) {
        $note = 'AI accounts detected but no token usage in the current month (or metrics access unavailable).'
    }
    else {
        $note = 'AI footprint detected (ML/Search/GPU); no token-metered Azure OpenAI usage to price.'
    }

    return [PSCustomObject]@{
        HasData              = $hasData
        AIFootprint          = $footprint
        TotalPromptTokens    = [long]$totalPrompt
        TotalGeneratedTokens = [long]$totalGen
        TotalTokens          = [long]$totalTokens
        TotalRequests        = [long]$totalReq
        TotalAICost          = [math]::Round($aiCost, 2)
        Currency             = $currency
        CostPer1KTokens      = $costPer1kTokens
        CostPerRequest       = $costPerRequest
        ByModel              = $byModel
        ByAccount            = $byAccount
        Period               = 'MonthToDate'
        Source               = if ($fromHub) { 'FinOpsHub' } else { 'API' }
        ScannedSubs          = $Subscriptions.Count
        Note                 = $note
    }
}
