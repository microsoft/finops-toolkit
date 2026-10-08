# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Private helper; the returned shape varies by scan and is not a declared contract.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Private helper named for the collection it processes.')]
param()

###########################################################################
# GET-RESOURCECOSTS.PS1
# AZURE FINOPS MULTITOOL - Per-Resource Cost Breakdown
###########################################################################
# Purpose: Query Cost Management per subscription to retrieve actual and
#          forecasted spend grouped by individual resource.
###########################################################################

function Get-ResourceCosts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions,

        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        $CostData,      # Per-sub cost data for forecast ratio distribution

        [Parameter()]
        [switch]$RestrictToSelected
    )

    # Guard: extract hashtable if pipeline pollution wrapped it in an array
    if ($CostData -and $CostData -isnot [hashtable]) {
        $CostData = @($CostData | Where-Object { $_ -is [hashtable] })[-1]
    }
    if (-not $CostData) { $CostData = @{} }

    $allRows = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Linear month-to-date projection factor for per-resource forecasts. The
    # per-resource Cost Management query only returns ActualCost (MTD), so a
    # native forecast is not available. Project to month-end (Actual / dayOfMonth
    # * daysInMonth) so Forecast is a real projection instead of equal to Actual.
    # ForecastSource records whether a row uses this projection or a Cost Management forecast.
    $now = (Get-Date).ToUniversalTime()
    $costPeriodEnd = $now.AddTicks(-($now.Ticks % [TimeSpan]::TicksPerSecond))
    $costPeriodStart = $costPeriodEnd.Date.AddDays(1 - $costPeriodEnd.Day)
    $queryPeriod = @{
        from = $costPeriodStart.ToString('yyyy-MM-ddTHH:mm:ssZ')
        to = $costPeriodEnd.ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
    $actualPeriod = '{0:yyyy-MM-dd HH:mm} to {1:yyyy-MM-dd HH:mm} UTC (query window)' -f $costPeriodStart, $costPeriodEnd
    $daysInMonth = [DateTime]::DaysInMonth($now.Year, $now.Month)
    $dayOfMonth = [math]::Max(1, $now.Day)
    $forecastMult = $daysInMonth / $dayOfMonth

    # Friendly resource type map
    $typeMap = @{
        'microsoft.compute/virtualmachines'          = 'Virtual Machine'
        'microsoft.compute/disks'                    = 'Managed Disk'
        'microsoft.network/loadbalancers'            = 'Load Balancer'
        'microsoft.network/applicationgateways'      = 'App Gateway'
        'microsoft.network/azurefirewalls'           = 'Azure Firewall'
        'microsoft.network/publicipaddresses'        = 'Public IP'
        'microsoft.network/virtualnetworkgateways'   = 'VNet Gateway'
        'microsoft.network/virtualnetworks'          = 'Virtual Network'
        'microsoft.network/privatednszones'          = 'Private DNS Zone'
        'microsoft.network/networkinterfaces'        = 'NIC'
        'microsoft.network/networksecuritygroups'    = 'NSG'
        'microsoft.network/bastionhosts'             = 'Bastion'
        'microsoft.containerservice/managedclusters' = 'AKS Cluster'
        'microsoft.sql/servers'                      = 'SQL Server'
        'microsoft.sql/servers/databases'            = 'SQL Database'
        'microsoft.storage/storageaccounts'          = 'Storage Account'
        'microsoft.web/sites'                        = 'App Service'
        'microsoft.web/serverfarms'                  = 'App Service Plan'
        'microsoft.keyvault/vaults'                  = 'Key Vault'
        'microsoft.operationalinsights/workspaces'   = 'Log Analytics'
        'microsoft.insights/components'              = 'App Insights'
        'microsoft.recoveryservices/vaults'          = 'Recovery Vault'
        'microsoft.automation/automationaccounts'    = 'Automation Account'
        'microsoft.dbformysql/flexibleservers'       = 'MySQL Flexible'
        'microsoft.dbforpostgresql/flexibleservers'  = 'PostgreSQL Flexible'
        'microsoft.cosmosdb/databaseaccounts'        = 'Cosmos DB'
        'microsoft.cache/redis'                      = 'Redis Cache'
        'microsoft.cdn/profiles'                     = 'CDN / Front Door'
        'microsoft.containerregistry/registries'     = 'Container Registry'
        'microsoft.apimanagement/service'            = 'API Management'
        'microsoft.eventgrid/topics'                 = 'Event Grid Topic'
        'microsoft.servicebus/namespaces'            = 'Service Bus'
        'microsoft.logic/workflows'                  = 'Logic App'
        'microsoft.security/pricings'                = 'Defender Plan'
        'microsoft.hybridcompute/machines'           = 'Arc Server'
    }

    $subNameMap = @{}
    foreach ($subscription in $Subscriptions) { $subNameMap[[string]$subscription.Id] = [string]$subscription.Name }

    function Get-ResourceCostIdentity {
        param([string]$ResourceId, [object]$QuerySubscription)

        $subscriptionId = if ($QuerySubscription) { [string]$QuerySubscription.Id } else { '' }
        if ($ResourceId -match '^/subscriptions/([^/]+)(?:/|$)') { $subscriptionId = $Matches[1] }
        $subscriptionName = if ($subscriptionId -and $subNameMap.ContainsKey($subscriptionId) -and $subNameMap[$subscriptionId]) { $subNameMap[$subscriptionId] }
        elseif ($subscriptionId) { $subscriptionId }
        else { 'Not attributed' }
        $resourceName = 'No resource ID recorded'
        $resourceType = 'Unattributed charge'
        if (-not [string]::IsNullOrWhiteSpace($ResourceId)) {
            $resourceType = 'Unknown'
            $segments = @($ResourceId.TrimEnd('/').Split('/', [StringSplitOptions]::RemoveEmptyEntries))
            $resourceName = $segments[-1]
            $providerIndex = -1
            for ($segmentIndex = 0; $segmentIndex -lt $segments.Count; $segmentIndex++) {
                if ($segments[$segmentIndex] -eq 'providers') { $providerIndex = $segmentIndex }
            }
            if ($providerIndex -ge 0 -and $segments.Count -gt ($providerIndex + 2)) {
                $typeSegments = @(for ($segmentIndex = $providerIndex + 2; $segmentIndex -lt $segments.Count; $segmentIndex += 2) { $segments[$segmentIndex] })
                $providerType = ($segments[$providerIndex + 1] + '/' + ($typeSegments -join '/')).ToLowerInvariant()
                $resourceType = if ($typeMap.ContainsKey($providerType)) { $typeMap[$providerType] } else { $providerType -replace '^microsoft\.', '' }
            }
            if ($ResourceId -match '(?i)^/providers/Microsoft\.Capacity/reservationOrders/([^/]+)/reservations(?:/([^/]+))?/?$') {
                $resourceType = 'Reservation charge'
                $resourceName = if ($Matches[2]) { $Matches[2] } else { "Reservation charge (order $($Matches[1]))" }
            }
        }
        [pscustomobject]@{ Subscription = $subscriptionName; SubscriptionId = $subscriptionId; ResourceName = $resourceName; ResourceType = $resourceType }
    }

    $gotMgData = $false

    # -- Strategy 1: MG-scope query (1-10 API calls instead of 300+) ----
    # When the user picked a subset of subscriptions we KEEP the fast MG-scope
    # query but add a server-side SubscriptionId filter so only the selected
    # subs' resources are returned - avoids the slow per-subscription fan-out
    # that triggers 429 throttling.
    $mgScopeId = if ($TenantId) { Resolve-CostMgId -TenantId $TenantId } else { $null }
    if ($mgScopeId -and -not (Test-CostMgCoverage -ManagementGroupId $mgScopeId -TenantId $TenantId -Subscriptions $Subscriptions)) { $mgScopeId = $null }
    $subFilter = if ($RestrictToSelected) { Get-CostSubscriptionFilter -Subscriptions $Subscriptions } else { $null }
    if ($mgScopeId) {
        try {
            Write-Host "  Querying resource costs (MG scope)..." -ForegroundColor Cyan
            $rcDataset = @{
                granularity = 'None'
                aggregation = @{
                    totalCost = @{ name = 'Cost'; function = 'Sum' }
                }
                grouping    = @(
                    @{ type = 'Dimension'; name = 'ResourceId' }
                    @{ type = 'Dimension'; name = 'ResourceGroupName' }
                )
            }
            if ($subFilter) { $rcDataset['filter'] = $subFilter }
            $body = @{
                type      = 'ActualCost'
                timeframe = 'Custom'
                timePeriod = $queryPeriod
                dataset   = $rcDataset
            } | ConvertTo-Json -Depth 10

            $mgPath = "/providers/Microsoft.Management/managementGroups/$mgScopeId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
            $resp = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $body

            if ($resp.StatusCode -eq 200) {
                $result = ($resp.Content | ConvertFrom-Json)
                $cols = @{}
                for ($colIdx = 0; $colIdx -lt $result.properties.columns.Count; $colIdx++) {
                    $cols[$result.properties.columns[$colIdx].name] = $colIdx
                }

                $pageNum = 0
                foreach ($responsePage in (Get-CostQueryResponsePage -FirstResponse $resp -Payload $body -Context 'management-group resource costs')) {
                    $page = $responsePage.Content | ConvertFrom-Json
                    $pageNum++
                    if ($page.properties.rows) {
                        if ($pageNum -eq 1 -or $pageNum % 3 -eq 0) {
                            Write-Host "    Page $pageNum ($($page.properties.rows.Count) rows)..." -ForegroundColor Gray
                        }
                        foreach ($row in $page.properties.rows) {
                            $cost = [math]::Round($row[$cols['Cost']], 2)
                            $currency = $row[$cols['Currency']]
                                $resourceId = [string]$row[$cols['ResourceId']]
                            $rg = $row[$cols['ResourceGroupName']]

                                $identity = Get-ResourceCostIdentity -ResourceId $resourceId

                            [void]$allRows.Add([PSCustomObject]@{
                                    Subscription  = $identity.Subscription
                                    SubscriptionId = $identity.SubscriptionId
                                    ResourceGroup = $rg
                                    ResourceType  = $identity.ResourceType
                                    ResourceName  = $identity.ResourceName
                                    ResourcePath  = $resourceId
                                    Actual        = $cost
                                    ActualPeriod = $actualPeriod
                                    ActualPeriodStart = $costPeriodStart
                                    ActualPeriodEnd = $costPeriodEnd
                                    ActualPeriodSource = 'Query window'
                                    Forecast      = [math]::Round($cost * $forecastMult, 2)
                                    ForecastSource = 'Linear projection'
                                    Currency      = $currency
                                })
                        }
                    }
                }

                if ($allRows.Count -gt 0) {
                    $gotMgData = $true
                    Write-Host "  MG scope: $($allRows.Count) resources across $pageNum page(s)" -ForegroundColor Green

                    # Apply forecast ratios from CostData (actual + forecast per sub)
                    if ($CostData) {
                        $ratios = @{}
                        foreach ($entry in $CostData.GetEnumerator()) {
                            $a = $entry.Value.Actual
                            $f = $entry.Value.Forecast
                            $isForecast = if ($null -ne $entry.Value.ForecastSource) { $entry.Value.ForecastSource -eq 'Forecast' } else { $f -gt $a }
                            if ($a -gt 0 -and $null -ne $f -and $isForecast) { $ratios[$entry.Key.ToLower()] = @{ Ratio = $f / $a; Currency = ([string]$entry.Value.Currency).Trim().ToUpperInvariant() } }
                            # Forecast spend with no actual cost to apportion by can't be split across resources.
                            elseif ($null -ne $f -and $isForecast -and $f -ne 0) { $ratios[$entry.Key.ToLower()] = @{ Ratio = $null; Currency = '' } }
                        }
                        foreach ($r in $allRows) {
                            if ($r.ResourcePath -match '/subscriptions/([^/]+)/') {
                                $sid = $Matches[1].ToLower()
                                if ($ratios.ContainsKey($sid)) {
                                    $splittable = $null -ne $ratios[$sid].Ratio -and $ratios[$sid].Currency -and $ratios[$sid].Currency -eq ([string]$r.Currency).Trim().ToUpperInvariant()
                                    $r.Forecast = if ($splittable) { [math]::Round($r.Actual * $ratios[$sid].Ratio, 2) } else { $null }
                                    $r.ForecastSource = if ($splittable) { 'Forecast' } else { 'Unavailable' }
                                }
                            }
                        }
                    }
                }
            }
            else {
                if ($resp.StatusCode -in @(401, 403)) { Set-MgCostScopeFailed }
                Write-Warning "  MG-scope resource cost query returned HTTP $($resp.StatusCode)"
            }
        }
        catch {
            $allRows.Clear()
            $gotMgData = $false
            Write-Warning "  MG-scope resource cost query failed: $($_.Exception.Message)"
        }
    }

    # -- Strategy 2: Per-subscription fallback (only if MG scope failed) -
    if (-not $gotMgData) {
        $subCount = $Subscriptions.Count
        $skipForecast = ($subCount -gt 50)   # For large tenants, skip per-sub forecast to halve API calls
        if ($skipForecast) {
            Write-Host "  Large tenant ($subCount subs): skipping per-resource forecast to reduce API calls" -ForegroundColor Yellow
        }

        $i = 0
        foreach ($sub in $Subscriptions) {
            $i++
            if ($i -eq 1 -or $i -eq $subCount -or ($subCount -gt 5 -and $i % [math]::Max(1, [int]($subCount / 10)) -eq 0)) {
                if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
                    Update-ScanStatus "Querying resource costs ($i/$subCount subs)..."
                }
            }
            $basePath = "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement"

            # -- Actual cost grouped by resource ----------------------------
            # A list, not a map: unattributed rows share an empty ID, and IDs can differ only by case.
            $actualRows = [System.Collections.Generic.List[PSCustomObject]]::new()
            try {
                Write-Host "  Querying resource costs for $($sub.Name)..." -ForegroundColor Cyan
                $body = @{
                    type      = 'ActualCost'
                    timeframe = 'Custom'
                    timePeriod = $queryPeriod
                    dataset   = @{
                        granularity = 'None'
                        aggregation = @{
                            totalCost = @{ name = 'Cost'; function = 'Sum' }
                        }
                        grouping    = @(
                            @{ type = 'Dimension'; name = 'ResourceId' }
                            @{ type = 'Dimension'; name = 'ResourceGroupName' }
                        )
                    }
                } | ConvertTo-Json -Depth 10

                $resp = Invoke-AzRestMethodWithRetry -Path "$basePath/query?api-version=2023-11-01" -Method POST -Payload $body

                if ($resp.StatusCode -eq 200) {
                    $result = ($resp.Content | ConvertFrom-Json)

                    # Build column index from response metadata (same for all pages)
                    # Distinct loop variable: $i is the outer per-subscription counter.
                    $cols = @{}
                    for ($colIdx = 0; $colIdx -lt $result.properties.columns.Count; $colIdx++) {
                        $cols[$result.properties.columns[$colIdx].name] = $colIdx
                    }

                    # Process all pages (Cost Management API paginates at ~5000 rows)
                    foreach ($responsePage in (Get-CostQueryResponsePage -FirstResponse $resp -Payload $body -Context "resource costs for $($sub.Name)")) {
                        $page = $responsePage.Content | ConvertFrom-Json
                        if ($page.properties.rows) {
                            foreach ($row in $page.properties.rows) {
                                $cost = [math]::Round($row[$cols['Cost']], 2)
                                $currency = $row[$cols['Currency']]
                                $resourceId = [string]$row[$cols['ResourceId']]
                                $rg = $row[$cols['ResourceGroupName']]

                                $identity = Get-ResourceCostIdentity -ResourceId $resourceId -QuerySubscription $sub

                                [void]$actualRows.Add([PSCustomObject]@{
                                    Subscription  = $identity.Subscription
                                    SubscriptionId = $identity.SubscriptionId
                                    ResourceGroup = $rg
                                    ResourceType  = $identity.ResourceType
                                    ResourceName  = $identity.ResourceName
                                    ResourcePath  = $resourceId
                                    Actual        = $cost
                                    ActualPeriod = $actualPeriod
                                    ActualPeriodStart = $costPeriodStart
                                    ActualPeriodEnd = $costPeriodEnd
                                    ActualPeriodSource = 'Query window'
                                    Forecast      = [math]::Round($cost * $forecastMult, 2)
                                    ForecastSource = 'Linear projection'
                                    Currency      = $currency
                                })
                            }
                        }
                    }
                }
                else {
                    throw "Resource cost query returned HTTP $($resp.StatusCode); results are incomplete."
                }
            }
            catch {
                throw "Resource cost query failed for $($sub.Name): $($_.Exception.Message)"
            }

            # -- Forecast: use subscription-level forecast ratio -------------
            # The forecast API does not reliably support ResourceId grouping,
            # so we get the sub-level forecast and distribute proportionally.
            # For large tenants (50+ subs), skip per-sub forecast API calls
            # and use CostData ratios if available.
            $subTotalActual = 0
            foreach ($entry in $actualRows) { $subTotalActual += $entry.Actual }

            $subForecast = $subTotalActual  # default: same as actual
            $hasForecast = $false
            $forecastIssue = $null
            $forecastCurrencyMismatch = $false
            $forecastUnapportionable = $false
            $actualCurrencies = @($actualRows | ForEach-Object { ([string]$_.Currency).Trim().ToUpperInvariant() } | Select-Object -Unique)

            # Use a verified Cost Data forecast when there is one (avoids an extra API call).
            # Entries without one fall through to the forecast API.
            $cd = if ($CostData -and $CostData.ContainsKey($sub.Id)) { $CostData[$sub.Id] } else { $null }
            $cdIsForecast = $null -ne $cd -and $null -ne $cd.Forecast -and $(if ($null -ne $cd.ForecastSource) { $cd.ForecastSource -eq 'Forecast' } else { $cd.Forecast -gt $cd.Actual })
            if ($cdIsForecast -and $cd.Actual -gt 0) {
                $cdCurrency = ([string]$cd.Currency).Trim().ToUpperInvariant()
                if ($cdCurrency -and $actualCurrencies.Count -eq 1 -and $cdCurrency -eq [string]$actualCurrencies[0]) {
                    $subForecast = $subTotalActual * ($cd.Forecast / $cd.Actual)
                    $hasForecast = $true
                }
                else { $forecastCurrencyMismatch = $true }
            }
            elseif ($cdIsForecast -and $cd.Forecast -ne 0 -and $subTotalActual -le 0) {
                # Forecast spend with no actual cost to apportion by can't be split across resources.
                $forecastUnapportionable = $true
            }
            elseif (-not $skipForecast) {
                # Only call the forecast API for small tenants without a usable Cost Data forecast
                try {
                    $now = (Get-Date).ToUniversalTime()
                    $monthEnd = (Get-Date -Year $now.Year -Month $now.Month -Day 1).AddMonths(1).AddDays(-1)

                    $fBody = @{
                        type                    = 'Usage'
                        timeframe               = 'Custom'
                        timePeriod              = @{
                            from = $now.AddDays(1 - $now.Day).ToString('yyyy-MM-dd')
                            to   = $monthEnd.ToString('yyyy-MM-dd')
                        }
                        dataset                 = @{
                            granularity = 'None'
                            aggregation = @{
                                totalCost = @{ name = 'Cost'; function = 'Sum' }
                            }
                        }
                        includeActualCost       = $true
                        includeFreshPartialCost = $false
                    } | ConvertTo-Json -Depth 10

                    $fResp = Invoke-AzRestMethodWithRetry -Path "$basePath/forecast?api-version=2023-11-01" -Method POST -Payload $fBody

                    if (-not $fResp -or $fResp.StatusCode -ne 200) {
                        throw "Resource forecast returned HTTP $($fResp.StatusCode); results are incomplete."
                    }
                    if ($fResp.StatusCode -eq 200) {
                        $forecastTotal = 0.0
                        $rowCount = 0
                        $forecastCurrencies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                        foreach ($responsePage in (Get-CostQueryResponsePage -FirstResponse $fResp -Payload $fBody -Context "resource forecast for $($sub.Name)")) {
                            $fResult = $responsePage.Content | ConvertFrom-Json
                            if ($fResult.properties.rows.Count -eq 0) { continue }
                            $costIndex = Get-CostColumnIndex -Columns $fResult.properties.columns -Names @('cost', 'pretaxcost', 'costusd')
                            $currencyIndex = Get-CostColumnIndex -Columns $fResult.properties.columns -Names @('currency')
                            if ($costIndex -lt 0 -or $currencyIndex -lt 0) { throw 'Forecast response did not expose the expected Cost and Currency columns.' }
                            foreach ($row in $fResult.properties.rows) {
                                $forecastTotal += [double]$row[$costIndex]
                                [void]$forecastCurrencies.Add(([string]$row[$currencyIndex]).Trim().ToUpperInvariant())
                                $rowCount++
                            }
                        }
                        if ($rowCount -gt 0) {
                            $subForecast = [math]::Round($forecastTotal, 2)
                            $hasForecast = $true
                            # Costs aren't converted, so a forecast in another currency can't scale these resources.
                            $forecastCurrencyMismatch = $forecastCurrencies.Count -ne 1 -or $actualCurrencies.Count -ne 1 -or -not $forecastCurrencies.Contains([string]$actualCurrencies[0])
                        }
                        else {
                            throw 'Resource forecast returned no rows; results are incomplete.'
                        }
                    }
                }
                catch {
                    $forecastIssue = "Resource forecasts for $($sub.Name) are unavailable; actual costs are kept. $($_.Exception.Message)"
                    Write-Warning $forecastIssue
                }
            }

            # Apply forecast ratio proportionally to each resource
            if ($forecastIssue -or $forecastCurrencyMismatch -or $forecastUnapportionable -or ($hasForecast -and $subTotalActual -le 0 -and $subForecast -ne 0)) {
                # A failed forecast, one in another currency, or one without actual cost to apportion by can't be split across resources.
                foreach ($entry in $actualRows) {
                    $entry.Forecast = $null
                    $entry.ForecastSource = 'Unavailable'
                    # Reports show CostIssue as limited data, so a failed request stays visible.
                    if ($forecastIssue) { $entry | Add-Member -NotePropertyName CostIssue -NotePropertyValue $forecastIssue }
                }
            }
            elseif ($subTotalActual -gt 0 -and $hasForecast) {
                $ratio = $subForecast / $subTotalActual
                foreach ($entry in $actualRows) {
                    $entry.Forecast = [math]::Round($entry.Actual * $ratio, 2)
                    $entry.ForecastSource = 'Forecast'
                }
            }

            # Collect rows from this sub
            foreach ($entry in $actualRows) {
                [void]$allRows.Add($entry)
            }
        }
    } # end per-sub fallback

    return $allRows
}
