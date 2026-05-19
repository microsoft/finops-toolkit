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
        $CostData      # Per-sub cost data for forecast ratio distribution
    )

    # Guard: extract hashtable if pipeline pollution wrapped it in an array
    if ($CostData -and $CostData -isnot [hashtable]) {
        $CostData = @($CostData | Where-Object { $_ -is [hashtable] })[-1]
    }
    if (-not $CostData) { $CostData = @{} }

    $allRows = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Friendly resource type map
    $typeMap = @{
        'microsoft.compute/virtualmachines'             = 'Virtual Machine'
        'microsoft.compute/disks'                       = 'Managed Disk'
        'microsoft.network/loadbalancers'               = 'Load Balancer'
        'microsoft.network/applicationgateways'         = 'App Gateway'
        'microsoft.network/azurefirewalls'              = 'Azure Firewall'
        'microsoft.network/publicipaddresses'           = 'Public IP'
        'microsoft.network/virtualnetworkgateways'      = 'VNet Gateway'
        'microsoft.network/virtualnetworks'             = 'Virtual Network'
        'microsoft.network/privatednszones'             = 'Private DNS Zone'
        'microsoft.network/networkinterfaces'           = 'NIC'
        'microsoft.network/networksecuritygroups'       = 'NSG'
        'microsoft.network/bastionhosts'                = 'Bastion'
        'microsoft.containerservice/managedclusters'    = 'AKS Cluster'
        'microsoft.sql/servers'                         = 'SQL Server'
        'microsoft.sql/servers/databases'               = 'SQL Database'
        'microsoft.storage/storageaccounts'             = 'Storage Account'
        'microsoft.web/sites'                           = 'App Service'
        'microsoft.web/serverfarms'                     = 'App Service Plan'
        'microsoft.keyvault/vaults'                     = 'Key Vault'
        'microsoft.operationalinsights/workspaces'      = 'Log Analytics'
        'microsoft.insights/components'                 = 'App Insights'
        'microsoft.recoveryservices/vaults'             = 'Recovery Vault'
        'microsoft.automation/automationaccounts'       = 'Automation Account'
        'microsoft.dbformysql/flexibleservers'          = 'MySQL Flexible'
        'microsoft.dbforpostgresql/flexibleservers'     = 'PostgreSQL Flexible'
        'microsoft.cosmosdb/databaseaccounts'           = 'Cosmos DB'
        'microsoft.cache/redis'                         = 'Redis Cache'
        'microsoft.cdn/profiles'                        = 'CDN / Front Door'
        'microsoft.containerregistry/registries'        = 'Container Registry'
        'microsoft.apimanagement/service'               = 'API Management'
        'microsoft.eventgrid/topics'                    = 'Event Grid Topic'
        'microsoft.servicebus/namespaces'               = 'Service Bus'
        'microsoft.logic/workflows'                     = 'Logic App'
        'microsoft.security/pricings'                   = 'Defender Plan'
        'microsoft.hybridcompute/machines'              = 'Arc Server'
    }

    $gotMgData = $false

    # -- Strategy 1: MG-scope query (1-10 API calls instead of 300+) ----
    if ($TenantId -and (Test-MgCostScope)) {
        try {
            Write-Host "  Querying resource costs (MG scope)..." -ForegroundColor Cyan
            $body = @{
                type      = 'ActualCost'
                timeframe = 'MonthToDate'
                dataset   = @{
                    granularity = 'None'
                    aggregation = @{
                        totalCost = @{ name = 'Cost'; function = 'Sum' }
                    }
                    grouping = @(
                        @{ type = 'Dimension'; name = 'ResourceId' }
                        @{ type = 'Dimension'; name = 'ResourceGroupName' }
                    )
                }
            } | ConvertTo-Json -Depth 10

            $mgPath = "/providers/Microsoft.Management/managementGroups/$TenantId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
            $resp = Invoke-AzRestMethodWithRetry -Path $mgPath -Method POST -Payload $body

            if ($resp.StatusCode -eq 200) {
                $result = ($resp.Content | ConvertFrom-Json)
                $cols = @{}
                for ($i = 0; $i -lt $result.properties.columns.Count; $i++) {
                    $cols[$result.properties.columns[$i].name] = $i
                }

                $page = $result
                $pageNum = 0
                do {
                    $pageNum++
                    if ($page.properties.rows) {
                        if ($pageNum -eq 1 -or $pageNum % 3 -eq 0) {
                            Write-Host "    Page $pageNum ($($page.properties.rows.Count) rows)..." -ForegroundColor Gray
                        }
                        foreach ($row in $page.properties.rows) {
                            $cost       = [math]::Round($row[$cols['Cost']], 2)
                            $currency   = $row[$cols['Currency']]
                            $resourceId = $row[$cols['ResourceId']]
                            $rg         = $row[$cols['ResourceGroupName']]

                            $resType = 'Unknown'
                            $resName = $resourceId
                            if ($resourceId -match '/providers/(.+)/([^/]+)$') {
                                $providerType = $Matches[1].ToLower()
                                $resName = $Matches[2]
                                $resType = if ($typeMap.ContainsKey($providerType)) { $typeMap[$providerType] } else { $providerType -replace 'microsoft\.', '' }
                            }

                            [void]$allRows.Add([PSCustomObject]@{
                                Subscription  = ''
                                ResourceGroup = $rg
                                ResourceType  = $resType
                                ResourcePath  = $resourceId
                                Actual        = $cost
                                Forecast      = $cost
                                Currency      = $currency
                            })
                        }
                    }
                    if ($page.properties.nextLink) {
                        $nextUri = [System.Uri]$page.properties.nextLink
                        $nResp = Invoke-AzRestMethodWithRetry -Path $nextUri.PathAndQuery -Method GET
                        if ($nResp.StatusCode -eq 200) { $page = ($nResp.Content | ConvertFrom-Json) }
                        else { break }
                    } else { break }
                } while ($true)

                if ($allRows.Count -gt 0) {
                    $gotMgData = $true
                    Write-Host "  MG scope: $($allRows.Count) resources across $pageNum page(s)" -ForegroundColor Green

                    # Populate subscription names from ARM resource ID
                    $subNameMap = @{}
                    foreach ($sub in $Subscriptions) { $subNameMap[$sub.Id.ToLower()] = $sub.Name }
                    foreach ($r in $allRows) {
                        if ($r.ResourcePath -match '/subscriptions/([^/]+)/') {
                            $sid = $Matches[1].ToLower()
                            $r.Subscription = if ($subNameMap.ContainsKey($sid)) { $subNameMap[$sid] } else { $sid }
                        }
                    }

                    # Apply forecast ratios from CostData (actual + forecast per sub)
                    if ($CostData) {
                        $ratios = @{}
                        foreach ($entry in $CostData.GetEnumerator()) {
                            $a = $entry.Value.Actual
                            $f = $entry.Value.Forecast
                            if ($a -gt 0 -and $f -gt $a) { $ratios[$entry.Key.ToLower()] = $f / $a }
                        }
                        foreach ($r in $allRows) {
                            if ($r.ResourcePath -match '/subscriptions/([^/]+)/') {
                                $sid = $Matches[1].ToLower()
                                if ($ratios.ContainsKey($sid)) {
                                    $r.Forecast = [math]::Round($r.Actual * $ratios[$sid], 2)
                                }
                            }
                        }
                    }
                }
            } else {
                if ($resp.StatusCode -in @(401, 403)) { Set-MgCostScopeFailed }
                Write-Warning "  MG-scope resource cost query returned HTTP $($resp.StatusCode)"
            }
        } catch {
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
        $actualMap = @{}
        try {
            Write-Host "  Querying resource costs for $($sub.Name)..." -ForegroundColor Cyan
            $body = @{
                type      = 'ActualCost'
                timeframe = 'MonthToDate'
                dataset   = @{
                    granularity = 'None'
                    aggregation = @{
                        totalCost = @{ name = 'Cost'; function = 'Sum' }
                    }
                    grouping = @(
                        @{ type = 'Dimension'; name = 'ResourceId' }
                        @{ type = 'Dimension'; name = 'ResourceGroupName' }
                    )
                }
            } | ConvertTo-Json -Depth 10

            $resp = Invoke-AzRestMethodWithRetry -Path "$basePath/query?api-version=2023-11-01" -Method POST -Payload $body

            if ($resp.StatusCode -eq 200) {
                $result = ($resp.Content | ConvertFrom-Json)

                # Build column index from response metadata (same for all pages)
                $cols = @{}
                for ($i = 0; $i -lt $result.properties.columns.Count; $i++) {
                    $cols[$result.properties.columns[$i].name] = $i
                }

                # Process all pages (Cost Management API paginates at ~5000 rows)
                $page = $result
                do {
                    if ($page.properties.rows) {
                        foreach ($row in $page.properties.rows) {
                            $cost       = [math]::Round($row[$cols['Cost']], 2)
                            $currency   = $row[$cols['Currency']]
                            $resourceId = $row[$cols['ResourceId']]
                            $rg         = $row[$cols['ResourceGroupName']]

                            # Extract resource type from ARM ID
                            $resType = 'Unknown'
                            $resName = $resourceId
                            if ($resourceId -match '/providers/(.+)/([^/]+)$') {
                                $providerType = $Matches[1].ToLower()
                                $resName = $Matches[2]
                                $resType = if ($typeMap.ContainsKey($providerType)) { $typeMap[$providerType] } else { $providerType -replace 'microsoft\.', '' }
                            }

                            $actualMap[$resourceId] = [PSCustomObject]@{
                                Subscription  = $sub.Name
                                ResourceGroup = $rg
                                ResourceType  = $resType
                                ResourcePath  = $resourceId
                                Actual        = $cost
                                Forecast      = $cost
                                Currency      = $currency
                            }
                        }
                    }
                    # Follow pagination link if present
                    if ($page.properties.nextLink) {
                        $uri = [System.Uri]$page.properties.nextLink
                        $nResp = Invoke-AzRestMethodWithRetry -Path $uri.PathAndQuery -Method GET
                        if ($nResp.StatusCode -eq 200) { $page = ($nResp.Content | ConvertFrom-Json) }
                        else { break }
                    } else { break }
                } while ($true)
            }
        } catch {
            Write-Warning "  Resource cost query failed for $($sub.Name): $($_.Exception.Message)"
        }

        # -- Forecast: use subscription-level forecast ratio -------------
        # The forecast API does not reliably support ResourceId grouping,
        # so we get the sub-level forecast and distribute proportionally.
        # For large tenants (50+ subs), skip per-sub forecast API calls
        # and use CostData ratios if available.
        $subTotalActual = 0
        foreach ($entry in $actualMap.Values) { $subTotalActual += $entry.Actual }

        $subForecast = $subTotalActual  # default: same as actual

        # Use CostData ratio if available (avoids extra API call)
        if ($CostData -and $CostData.ContainsKey($sub.Id)) {
            $cd = $CostData[$sub.Id]
            if ($cd.Forecast -gt $cd.Actual -and $cd.Actual -gt 0) {
                $subForecast = $subTotalActual * ($cd.Forecast / $cd.Actual)
            }
        }
        elseif (-not $skipForecast) {
            # Only call forecast API for small tenants without CostData
            try {
                $now = Get-Date
                $monthEnd = (Get-Date -Year $now.Year -Month $now.Month -Day 1).AddMonths(1).AddDays(-1)

                $fBody = @{
                    type       = 'Usage'
                    timeframe  = 'Custom'
                    timePeriod = @{
                        from = $now.ToString('yyyy-MM-dd')
                        to   = $monthEnd.ToString('yyyy-MM-dd')
                    }
                    dataset    = @{
                        granularity = 'None'
                        aggregation = @{
                            totalCost = @{ name = 'Cost'; function = 'Sum' }
                        }
                    }
                    includeActualCost       = $true
                    includeFreshPartialCost = $false
                } | ConvertTo-Json -Depth 10

                $fResp = Invoke-AzRestMethodWithRetry -Path "$basePath/forecast?api-version=2023-11-01" -Method POST -Payload $fBody

                if ($fResp.StatusCode -eq 200) {
                    $fResult = ($fResp.Content | ConvertFrom-Json)
                    if ($fResult.properties.rows -and $fResult.properties.rows.Count -gt 0) {
                        $forecastTotal = 0
                        foreach ($row in $fResult.properties.rows) {
                            $forecastTotal += [double]$row[0]
                        }
                        $subForecast = [math]::Round($forecastTotal, 2)
                    }
                }
            } catch {
                # Forecast not available for all account types
            }
        }

        # Apply forecast ratio proportionally to each resource
        if ($subTotalActual -gt 0 -and $subForecast -gt $subTotalActual) {
            $ratio = $subForecast / $subTotalActual
            foreach ($entry in $actualMap.Values) {
                $entry.Forecast = [math]::Round($entry.Actual * $ratio, 2)
            }
        }

        # Collect rows from this sub
        foreach ($entry in $actualMap.Values) {
            [void]$allRows.Add($entry)
        }
    }
    } # end per-sub fallback

    return $allRows
}
