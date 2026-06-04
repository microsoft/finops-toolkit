# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# INVOKE-FINOPSMULTITOOL.PS1
# INTERACTIVE TERMINAL LAUNCHER FOR FINOPS MULTITOOL
###########################################################################
# Purpose: Provides an arrow-key driven TUI for selecting and running
#          FinOps Multitool scan modules without a GUI dependency.
#
# Usage:   Invoke-FinOpsMultitool
#          Invoke-FinOpsMultitool -SubscriptionId '2693c348-...'
#          Invoke-FinOpsMultitool -OutputPath './results'
#
# Requirements:
#   - PowerShell 5.1+ (Windows) or 7+ (cross-platform)
#   - Az PowerShell modules: Az.Accounts, Az.Resources, Az.ResourceGraph
#   - Azure RBAC: Reader + Cost Management Reader on target scope
###########################################################################

function Invoke-FinOpsMultitool {
    [CmdletBinding()]
    param(
        [string]$SubscriptionId,
        [string]$OutputPath
    )

    # -- Load modules (always force-reimport to pick up latest changes) ----
    $multitoolRoot = $PSScriptRoot
    $psm1Path = Join-Path $multitoolRoot 'FinOpsMultitool.psm1'
    if (Test-Path $psm1Path) {
        Import-Module $psm1Path -Force
    }
    else {
        Write-Error "FinOpsMultitool.psm1 not found at $psm1Path"
        return
    }

    # -- Pre-flight: verify required Az modules ----------------------------
    $requiredModules = @(
        @{ Name = 'Az.Accounts'; Reason = 'Azure authentication' }
        @{ Name = 'Az.ResourceGraph'; Reason = 'Resource Graph queries (optimization, governance scans)' }
        @{ Name = 'Az.Storage'; Reason = 'FinOps Hub data access (reading cost exports)' }
    )
    $missing = @()
    foreach ($req in $requiredModules) {
        if (-not (Get-Module $req.Name -ErrorAction SilentlyContinue) -and
            -not (Get-Module $req.Name -ListAvailable -ErrorAction SilentlyContinue)) {
            $missing += $req
        }
    }
    if ($missing.Count -gt 0) {
        Write-Host ""
        Write-Host "  MISSING REQUIRED MODULES" -ForegroundColor Red
        Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
        foreach ($m in $missing) {
            Write-Host "    $($m.Name)" -ForegroundColor Red -NoNewline
            Write-Host "  — $($m.Reason)" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "  Install with:" -ForegroundColor White
        $names = ($missing.Name | ForEach-Object { "'$_'" }) -join ', '
        Write-Host "    Install-Module $names -Scope CurrentUser" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    # -- Scan Module Registry ----------------------------------------------
    $scanModules = @(
        # -- Optimization (Resource Graph) --
        @{ Name = 'Orphaned Resources'; Fn = 'Get-OrphanedResources'; Selected = $true; Category = 'Optimization' }
        @{ Name = 'Idle VMs'; Fn = 'Get-IdleVMs'; Selected = $true; Category = 'Optimization' }
        @{ Name = 'Storage Tier Advice'; Fn = 'Get-StorageTierAdvice'; Selected = $true; Category = 'Optimization' }
        @{ Name = 'Legacy Resources'; Fn = 'Get-LegacyResources'; Selected = $true; Category = 'Optimization' }
        @{ Name = 'AHB Opportunities'; Fn = 'Get-AHBOpportunities'; Selected = $true; Category = 'Optimization' }
        # -- Governance (run early — other modules depend on these) --
        @{ Name = 'Tag Inventory'; Fn = 'Get-TagInventory'; Selected = $true; Category = 'Governance' }
        @{ Name = 'Tag Recommendations'; Fn = 'Get-TagRecommendations'; Selected = $true; Category = 'Governance' }
        @{ Name = 'Policy Inventory'; Fn = 'Get-PolicyInventory'; Selected = $true; Category = 'Governance' }
        @{ Name = 'Policy Recommendations'; Fn = 'Get-PolicyRecommendations'; Selected = $true; Category = 'Governance' }
        # -- Cost Analysis (depends on Tag Inventory for Cost by Tag) --
        @{ Name = 'Cost Data'; Fn = 'Get-CostData'; Selected = $true; Category = 'Cost Analysis' }
        @{ Name = 'Resource Costs'; Fn = 'Get-ResourceCosts'; Selected = $true; Category = 'Cost Analysis' }
        @{ Name = 'Cost by Tag'; Fn = 'Get-CostByTag'; Selected = $true; Category = 'Cost Analysis' }
        @{ Name = 'Cost Trend'; Fn = 'Get-CostTrend'; Selected = $true; Category = 'Cost Analysis' }
        @{ Name = 'Unit Economics'; Fn = 'Get-UnitEconomics'; Selected = $true; Category = 'Cost Analysis' }
        # -- AI & ML (self-gating — only runs the deep scan when AI is present) --
        @{ Name = 'AI Workload Metrics'; Fn = 'Get-AIWorkloadMetrics'; Selected = $true; Category = 'AI & ML' }
        # -- Commitments --
        @{ Name = 'Reservation Advice'; Fn = 'Get-ReservationAdvice'; Selected = $true; Category = 'Commitments' }
        @{ Name = 'Commitment Utilization'; Fn = 'Get-CommitmentUtilization'; Selected = $true; Category = 'Commitments' }
        @{ Name = 'Savings Realized'; Fn = 'Get-SavingsRealized'; Selected = $true; Category = 'Commitments' }
        # -- Monitoring --
        @{ Name = 'Budget Status'; Fn = 'Get-BudgetStatus'; Selected = $true; Category = 'Monitoring' }
        @{ Name = 'Budget History'; Fn = 'Get-BudgetHistory'; Selected = $true; Category = 'Monitoring' }
        @{ Name = 'Anomaly Alerts'; Fn = 'Get-AnomalyAlerts'; Selected = $true; Category = 'Monitoring' }
        # -- Advisor --
        @{ Name = 'Optimization Advice'; Fn = 'Get-OptimizationAdvice'; Selected = $true; Category = 'Advisor' }
        # -- Sustainability --
        @{ Name = 'Carbon Emissions'; Fn = 'Get-CarbonMetrics'; Selected = $true; Category = 'Sustainability' }
        # -- Account --
        @{ Name = 'Billing Structure'; Fn = 'Get-BillingStructure'; Selected = $false; Category = 'Account' }
        @{ Name = 'Contract Info'; Fn = 'Get-ContractInfo'; Selected = $true; Category = 'Account' }
        @{ Name = 'MACC Commitment'; Fn = 'Get-MaccCommitment'; Selected = $true; Category = 'Account' }
    )

    # -- Permission Requirements per Module --------------------------------
    # Maps each function to the Azure RBAC role(s) needed and a human-readable reason
    $permissionInfo = @{
        'Get-OrphanedResources'     = @{ Role = 'Reader'; Scope = 'Subscription'; API = 'Azure Resource Graph'; Reason = 'Requires read access to query resource metadata via Azure Resource Graph.' }
        'Get-IdleVMs'               = @{ Role = 'Reader'; Scope = 'Subscription'; API = 'Azure Resource Graph + Monitor Metrics'; Reason = 'Requires Reader to query VM metadata and Monitor metrics for CPU/network utilization.' }
        'Get-StorageTierAdvice'     = @{ Role = 'Reader'; Scope = 'Subscription'; API = 'Azure Resource Graph'; Reason = 'Requires read access to query storage account configurations.' }
        'Get-LegacyResources'       = @{ Role = 'Reader'; Scope = 'Subscription'; API = 'Azure Resource Graph'; Reason = 'Requires Reader to query VM/disk/network SKUs for legacy and retiring resources.' }
        'Get-AHBOpportunities'      = @{ Role = 'Reader'; Scope = 'Subscription'; API = 'Azure Resource Graph'; Reason = 'Requires read access to query VM license types.' }
        'Get-TagInventory'          = @{ Role = 'Reader'; Scope = 'Subscription'; API = 'Azure Resource Graph'; Reason = 'Requires read access to inventory resource tags via Resource Graph.' }
        'Get-TagRecommendations'    = @{ Role = 'Reader'; Scope = 'Subscription'; API = 'Azure Resource Graph'; Reason = 'Requires read access to analyze existing tags and suggest improvements.' }
        'Get-PolicyInventory'       = @{ Role = 'Reader'; Scope = 'Subscription'; API = 'Azure Resource Manager'; Reason = 'Requires read access to list policy assignments and definitions.' }
        'Get-PolicyRecommendations' = @{ Role = 'Reader'; Scope = 'Subscription'; API = 'Azure Resource Manager'; Reason = 'Requires read access to evaluate policy coverage gaps.' }
        'Get-CostData'              = @{ Role = 'Cost Management Reader'; Scope = 'Subscription or Management Group'; API = 'Cost Management Query API'; Reason = 'Requires Microsoft.CostManagement/query/action. Assign Cost Management Reader or Reader at the subscription or MG scope.' }
        'Get-ResourceCosts'         = @{ Role = 'Cost Management Reader'; Scope = 'Subscription or Management Group'; API = 'Cost Management Query API'; Reason = 'Requires Microsoft.CostManagement/query/action. Assign Cost Management Reader or Reader at the subscription or MG scope.' }
        'Get-CostByTag'             = @{ Role = 'Cost Management Reader'; Scope = 'Subscription or Management Group'; API = 'Cost Management Query API'; Reason = 'Requires Microsoft.CostManagement/query/action to query cost grouped by tag dimensions.' }
        'Get-CostTrend'             = @{ Role = 'Cost Management Reader'; Scope = 'Subscription or Management Group'; API = 'Cost Management Query API'; Reason = 'Requires Microsoft.CostManagement/query/action to retrieve historical monthly cost data.' }
        'Get-UnitEconomics'         = @{ Role = 'Cost Management Reader + Reader'; Scope = 'Management Group'; API = 'Cost Management Query API + Azure Resource Graph'; Reason = 'Requires amortized cost (Cost Management) and capacity counts (Resource Graph) to compute $/vCPU and $/GB.' }
        'Get-AIWorkloadMetrics'     = @{ Role = 'Cost Management Reader + Reader'; Scope = 'Management Group'; API = 'Azure Resource Graph + Monitor Metrics + Cost Management Query API'; Reason = 'Requires Reader to detect AI resources and read Azure OpenAI token metrics, plus Cost Management Reader to map token usage to spend. Skips the deep scan when no AI workloads are present.' }
        'Get-ReservationAdvice'     = @{ Role = 'Cost Management Reader'; Scope = 'Subscription'; API = 'Consumption Reservation Recommendations API'; Reason = 'Requires Microsoft.Consumption/reservationRecommendations/read to retrieve reservation purchase advice.' }
        'Get-CommitmentUtilization' = @{ Role = 'Cost Management Reader or Reservation Reader'; Scope = 'Reservation Order or Subscription'; API = 'Consumption Reservation Summaries API'; Reason = 'Requires Microsoft.Consumption/reservationSummaries/read. If no reservations exist, this will be empty.' }
        'Get-SavingsRealized'       = @{ Role = 'Cost Management Reader'; Scope = 'Subscription'; API = 'Cost Management Benefit Utilization API'; Reason = 'Requires Microsoft.CostManagement/benefitUtilizationSummaries/read. Returns empty if no active reservations or savings plans.' }
        'Get-BudgetStatus'          = @{ Role = 'Cost Management Reader'; Scope = 'Subscription'; API = 'Consumption Budgets API'; Reason = 'Requires Microsoft.Consumption/budgets/read. Returns empty if no budgets are configured for scanned subscriptions.' }
        'Get-BudgetHistory'         = @{ Role = 'Cost Management Reader'; Scope = 'Subscription'; API = 'Cost Management Query API'; Reason = 'Requires Microsoft.CostManagement/query/action to retrieve monthly actuals per budget. Runs only when Budget Status returns budgets.' }
        'Get-AnomalyAlerts'         = @{ Role = 'Cost Management Reader'; Scope = 'Subscription'; API = 'Cost Management Alerts API'; Reason = 'Requires Microsoft.CostManagement/alerts/read. Returns empty if no cost anomalies were detected.' }
        'Get-OptimizationAdvice'    = @{ Role = 'Reader'; Scope = 'Subscription'; API = 'Azure Advisor API'; Reason = 'Requires Microsoft.Advisor/recommendations/read to retrieve cost optimization recommendations.' }
        'Get-CarbonMetrics'         = @{ Role = 'Reader or Carbon Optimization Reader'; Scope = 'Subscription'; API = 'Carbon Optimization API'; Reason = 'Requires Microsoft.Carbon read access to query emissions. Emissions publish ~2 months in arrears; returns empty if no published months.' }
        'Get-BillingStructure'      = @{ Role = 'Billing Reader or EA Reader'; Scope = 'Billing Account'; API = 'Billing API'; Reason = 'Requires Microsoft.Billing/*/read. This is a billing-scope role, not a subscription role. Contact your billing admin.' }
        'Get-ContractInfo'          = @{ Role = 'Billing Reader'; Scope = 'Billing Account'; API = 'Billing API'; Reason = 'Requires Microsoft.Billing/billingProperty/read. May require billing account access beyond subscription Reader.' }
        'Get-MaccCommitment'        = @{ Role = 'Billing Reader or EA Reader'; Scope = 'Billing Account'; API = 'Consumption Lots API'; Reason = 'Requires a billing role on an EA/MCA billing account to read consumption commitment (MACC) lots. Not applicable to PAYGO/CSP/MSDN.' }
    }

    # =====================================================================
    #  BANNER
    # =====================================================================
    function Show-Banner {
        Clear-Host
        $banner = @"

  ╔════════════════════════════════════════════════════════════════════════╗
  ║                                                                        ║
  ║   ███████╗██╗███╗   ██╗ ██████╗ ██████╗ ███████╗                       ║
  ║   ██╔════╝██║████╗  ██║██╔═══██╗██╔══██╗██╔════╝                       ║
  ║   █████╗  ██║██╔██╗ ██║██║   ██║██████╔╝███████╗                       ║
  ║   ██╔══╝  ██║██║╚██╗██║██║   ██║██╔═══╝ ╚════██║                       ║
  ║   ██║     ██║██║ ╚████║╚██████╔╝██║     ███████║                       ║
  ║   ╚═╝     ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚══════╝                       ║
  ║                                                                        ║
  ║   ███╗   ███╗██╗   ██╗██╗  ████████╗██╗████████╗ ██████╗  ██████╗ ██╗  ║
  ║   ████╗ ████║██║   ██║██║  ╚══██╔══╝██║╚══██╔══╝██╔═══██╗██╔═══██╗██║  ║
  ║   ██╔████╔██║██║   ██║██║     ██║   ██║   ██║   ██║   ██║██║   ██║██║  ║
  ║   ██║╚██╔╝██║██║   ██║██║     ██║   ██║   ██║   ██║   ██║██║   ██║██║  ║
  ║   ██║ ╚═╝ ██║╚██████╔╝███████╗██║   ██║   ██║   ╚██████╔╝╚██████╔╝███████╗
  ║   ╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝   ╚═╝   ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝
  ║                                                                        ║
  ║   Azure FinOps Scanner & Optimizer                          v2.3.0     ║
  ║   ────────────────────────────────────────────────────────────         ║
  ║   Part of the FinOps Toolkit                                           ║
  ║                                                                        ║
  ╚════════════════════════════════════════════════════════════════════════╝

"@
        Write-Host $banner -ForegroundColor Cyan
    }

    # =====================================================================
    #  DATA SOURCE PICKER
    # =====================================================================
    function Select-DataSource {
        param(
            [string]$TenantId,
            [array]$Subscriptions
        )

        Write-Host ""
        Write-Host "  DATA SOURCE" -ForegroundColor Cyan
        Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""

        # Try to detect a FinOps Hub in the selected subscriptions
        $hubStorage = $null
        Write-Host "  Checking for FinOps Hub deployment..." -ForegroundColor DarkGray
        foreach ($sub in $Subscriptions) {
            try {
                $query = "resources | where type == 'microsoft.storage/storageaccounts' and tags['cm-resource-parent'] contains 'Microsoft.Cloud/hubs' | project name, resourceGroup, subscriptionId, location"
                $result = Search-AzGraph -Query $query -Subscription $sub.Id -ErrorAction SilentlyContinue
                if ($result -and @($result).Count -gt 0) {
                    $hubStorage = $result[0]
                    break
                }
            }
            catch { }
        }

        if ($hubStorage) {
            Write-Host "  FinOps Hub detected: " -ForegroundColor Green -NoNewline
            Write-Host "$($hubStorage.name)" -ForegroundColor White -NoNewline
            Write-Host " ($($hubStorage.resourceGroup))" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  [1] FinOps Hub" -ForegroundColor Green -NoNewline
            Write-Host "  - Pre-processed data from your Hub's ingestion pipeline" -ForegroundColor DarkGray
            Write-Host "       Faster, consistent, includes normalized/amortized costs" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  [2] Cost Management API" -ForegroundColor Yellow -NoNewline
            Write-Host "  - Query Azure Cost Management REST APIs directly" -ForegroundColor DarkGray
            Write-Host "       Real-time, no Hub required, subject to API throttling" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  [3] Resource Graph only" -ForegroundColor DarkGray -NoNewline
            Write-Host "  - Skip cost modules, run governance/optimization scans only" -ForegroundColor DarkGray
            Write-Host ""

            while ($true) {
                Write-Host "  Select [1/2/3]: " -ForegroundColor White -NoNewline
                $choice = Read-Host
                switch ($choice.Trim()) {
                    '1' { return @{ Source = 'Hub'; HubStorage = $hubStorage } }
                    '2' { return @{ Source = 'API'; HubStorage = $hubStorage } }
                    '3' { return @{ Source = 'GraphOnly'; HubStorage = $hubStorage } }
                    default { Write-Host "  Invalid choice." -ForegroundColor Red }
                }
            }
        }
        else {
            Write-Host "  No FinOps Hub found in selected subscriptions." -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  [1] Cost Management API" -ForegroundColor Yellow -NoNewline
            Write-Host "  - Query Azure Cost Management REST APIs directly" -ForegroundColor DarkGray
            Write-Host "       Real-time, subject to API throttling on large tenants" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  [2] Resource Graph only" -ForegroundColor DarkGray -NoNewline
            Write-Host "  - Skip cost modules, run governance/optimization scans only" -ForegroundColor DarkGray
            Write-Host ""

            while ($true) {
                Write-Host "  Select [1/2]: " -ForegroundColor White -NoNewline
                $choice = Read-Host
                switch ($choice.Trim()) {
                    '1' { return @{ Source = 'API'; HubStorage = $null } }
                    '2' { return @{ Source = 'GraphOnly'; HubStorage = $null } }
                    default { Write-Host "  Invalid choice." -ForegroundColor Red }
                }
            }
        }
    }

    # =====================================================================
    #  SUBSCRIPTION PICKER
    # =====================================================================
    function Select-Subscription {
        param([string]$PreselectedId)

        Write-Host "  Checking Azure connection..." -ForegroundColor DarkGray
        $ctx = Get-AzContext -ErrorAction SilentlyContinue
        if (-not $ctx) {
            Write-Host "  Not connected. Launching browser login..." -ForegroundColor Yellow
            Connect-AzAccount | Out-Null
            $ctx = Get-AzContext
        }
        Write-Host "  Signed in as: $($ctx.Account.Id)" -ForegroundColor Green
        Write-Host ""

        # -- Tenant picker ------------------------------------------------
        $tenants = @(Get-AzTenant -ErrorAction SilentlyContinue)
        if ($tenants.Count -gt 1) {
            Write-Host "  $($tenants.Count) tenants available:" -ForegroundColor White
            Write-Host ""

            $tCursor = 0
            $currentTenantId = $ctx.Tenant.Id
            # Pre-select current tenant
            for ($t = 0; $t -lt $tenants.Count; $t++) {
                if ($tenants[$t].TenantId -eq $currentTenantId) { $tCursor = $t; break }
            }

            while ($true) {
                [Console]::SetCursorPosition(0, [Console]::CursorTop)
                for ($t = 0; $t -lt $tenants.Count; $t++) {
                    $tPrefix = if ($t -eq $tCursor) { '  > ' } else { '    ' }
                    $tColor = if ($t -eq $tCursor) { 'Green' } else { 'Gray' }
                    $tLabel = if ($tenants[$t].Name -and $tenants[$t].Name -ne $tenants[$t].TenantId) {
                        "$($tenants[$t].Name)  ($($tenants[$t].TenantId))"
                    }
                    else { $tenants[$t].TenantId }
                    $current = if ($tenants[$t].TenantId -eq $currentTenantId) { ' (current)' } else { '' }
                    $tLine = "$tPrefix$tLabel$current"
                    if ($tLine.Length -gt 80) { $tLine = $tLine.Substring(0, 77) + '...' }
                    Write-Host $tLine.PadRight(85) -ForegroundColor $tColor
                }
                Write-Host ""
                Write-Host "  ↑↓ Navigate  │  Enter = Select tenant  │  Q = Stay in current" -ForegroundColor DarkGray

                $tKey = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                switch ($tKey.VirtualKeyCode) {
                    38 { if ($tCursor -gt 0) { $tCursor-- } }
                    40 { if ($tCursor -lt $tenants.Count - 1) { $tCursor++ } }
                    13 {
                        $selectedTenant = $tenants[$tCursor]
                        if ($selectedTenant.TenantId -ne $currentTenantId) {
                            Write-Host ""
                            Write-Host "  Switching to tenant: $($selectedTenant.Name)..." -ForegroundColor Yellow
                            Connect-AzAccount -TenantId $selectedTenant.TenantId | Out-Null
                            $ctx = Get-AzContext
                            Write-Host "  Connected to: $($ctx.Tenant.Id)" -ForegroundColor Green
                        }
                        else {
                            Write-Host ""
                            Write-Host "  Staying in current tenant." -ForegroundColor Green
                        }
                        break
                    }
                    81 {
                        Write-Host ""
                        Write-Host "  Staying in current tenant." -ForegroundColor Green
                        break
                    }
                }
                if ($tKey.VirtualKeyCode -eq 13 -or $tKey.VirtualKeyCode -eq 81) { break }

                # Move cursor back up to re-render
                $tLinesToClear = $tenants.Count + 2
                [Console]::SetCursorPosition(0, [Console]::CursorTop - $tLinesToClear)
            }
            Write-Host ""
        }
        elseif ($tenants.Count -eq 1) {
            $tLabel = if ($tenants[0].Name -and $tenants[0].Name -ne $tenants[0].TenantId) { $tenants[0].Name } else { $tenants[0].TenantId }
            Write-Host "  Tenant: $tLabel" -ForegroundColor Green
            Write-Host ""
        }

        if ($PreselectedId) {
            $sub = Get-AzSubscription -SubscriptionId $PreselectedId -ErrorAction SilentlyContinue
            if ($sub) {
                Write-Host "  Using subscription: $($sub.Name)" -ForegroundColor Green
                return @($sub)
            }
            Write-Host "  Subscription $PreselectedId not found, showing picker..." -ForegroundColor Yellow
        }

        # Scope subscription enumeration to the SELECTED tenant only.
        # Get-AzSubscription with no -TenantId returns subscriptions across every
        # tenant the signed-in account can access, which incorrectly mixes tenants
        # together when the user picks one tenant and chooses "All subscriptions".
        $effectiveTenantId = (Get-AzContext -ErrorAction SilentlyContinue).Tenant.Id
        $allSubs = @(Get-AzSubscription -TenantId $effectiveTenantId -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Enabled' })
        if ($allSubs.Count -eq 0) {
            Write-Error "No enabled subscriptions found in tenant $effectiveTenantId."
            return $null
        }
        if ($allSubs.Count -eq 1) {
            Write-Host "  Using only subscription: $($allSubs[0].Name)" -ForegroundColor Green
            return $allSubs
        }

        # Multi-sub picker
        Write-Host "  Found $($allSubs.Count) subscriptions. Select scope:" -ForegroundColor White
        Write-Host ""
        Write-Host "    [A] All subscriptions" -ForegroundColor White
        Write-Host "    [S] Single subscription (pick from list)" -ForegroundColor White
        Write-Host ""
        $choice = Read-Host "  Choice (A/S)"

        if ($choice -eq 'A' -or $choice -eq 'a') {
            Write-Host "  Scanning all $($allSubs.Count) subscriptions" -ForegroundColor Green
            return $allSubs
        }

        # Arrow-key single subscription picker
        $cursor = 0
        $pageSize = 15
        $offset = 0

        while ($true) {
            # Render list
            $renderStart = $offset
            $renderEnd = [math]::Min($offset + $pageSize, $allSubs.Count) - 1
            [Console]::SetCursorPosition(0, [Console]::CursorTop)

            for ($i = $renderStart; $i -le $renderEnd; $i++) {
                $prefix = if ($i -eq $cursor) { '  > ' } else { '    ' }
                $color = if ($i -eq $cursor) { 'Green' } else { 'Gray' }
                $line = "$prefix$($allSubs[$i].Name)"
                if ($line.Length -gt 70) { $line = $line.Substring(0, 67) + '...' }
                Write-Host $line.PadRight(75) -ForegroundColor $color
            }
            Write-Host ""
            Write-Host "  ↑↓ Navigate  │  Enter = Select  │  Q = Cancel" -ForegroundColor DarkGray

            $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            switch ($key.VirtualKeyCode) {
                38 {
                    # Up
                    if ($cursor -gt 0) { $cursor-- }
                    if ($cursor -lt $offset) { $offset = $cursor }
                }
                40 {
                    # Down
                    if ($cursor -lt $allSubs.Count - 1) { $cursor++ }
                    if ($cursor -ge $offset + $pageSize) { $offset = $cursor - $pageSize + 1 }
                }
                13 {
                    # Enter
                    Write-Host ""
                    Write-Host "  Selected: $($allSubs[$cursor].Name)" -ForegroundColor Green
                    return @($allSubs[$cursor])
                }
                81 { return $null } # Q
            }

            # Move cursor back up to re-render
            $linesToClear = ($renderEnd - $renderStart + 1) + 2
            [Console]::SetCursorPosition(0, [Console]::CursorTop - $linesToClear)
        }
    }

    # =====================================================================
    #  SCAN MODULE PICKER (checkbox menu)
    # =====================================================================
    function Select-ScanModules {
        param([array]$Modules)

        $cursor = 0
        $categories = $Modules | ForEach-Object { $_.Category } | Select-Object -Unique

        while ($true) {
            # Build display lines grouped by category
            $lines = @()
            $lineToIndex = @{}  # map display line -> module index
            $moduleIdx = 0

            foreach ($cat in $categories) {
                $lines += "  ── $cat ──"
                $lineToIndex[$lines.Count - 1] = -1  # category header, not selectable

                $catModules = $Modules | Where-Object { $_.Category -eq $cat }
                foreach ($mod in $catModules) {
                    $idx = [array]::IndexOf($Modules, $mod)
                    $check = if ($mod.Selected) { '[x]' } else { '[ ]' }
                    $lines += "     $check $($mod.Name)"
                    $lineToIndex[$lines.Count - 1] = $idx
                }
                $lines += ''
                $lineToIndex[$lines.Count - 1] = -1
            }

            # Find selectable line indices
            $selectableLines = @()
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lineToIndex[$i] -ge 0) { $selectableLines += $i }
            }

            if ($cursor -ge $selectableLines.Count) { $cursor = $selectableLines.Count - 1 }
            $activeLine = $selectableLines[$cursor]

            # Render
            Clear-Host
            Write-Host ""
            Write-Host "  SELECT SCANS" -ForegroundColor White
            Write-Host "  ↑↓ Move  │  Space = Toggle  │  A = All  │  N = None  │  Enter = Run  │  Q = Quit" -ForegroundColor DarkGray
            Write-Host ""

            $selectedCount = ($Modules | Where-Object { $_.Selected }).Count

            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lineToIndex[$i] -eq -1) {
                    # Category header or blank
                    if ($lines[$i] -match '──') {
                        Write-Host $lines[$i] -ForegroundColor Yellow
                    }
                    else {
                        Write-Host $lines[$i]
                    }
                }
                else {
                    $isActive = ($i -eq $activeLine)
                    $mod = $Modules[$lineToIndex[$i]]
                    $check = if ($mod.Selected) { '[x]' } else { '[ ]' }
                    $pointer = if ($isActive) { ' >' } else { '  ' }
                    $color = if ($isActive -and $mod.Selected) { 'Green' }
                    elseif ($isActive) { 'White' }
                    elseif ($mod.Selected) { 'DarkGreen' }
                    else { 'Gray' }
                    Write-Host "  $pointer $check $($mod.Name)" -ForegroundColor $color
                }
            }

            Write-Host ""
            Write-Host "  $selectedCount of $($Modules.Count) scans selected" -ForegroundColor DarkGray
            Write-Host ""

            # Read key
            $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            switch ($key.VirtualKeyCode) {
                38 { if ($cursor -gt 0) { $cursor-- } }                          # Up
                40 { if ($cursor -lt $selectableLines.Count - 1) { $cursor++ } }  # Down
                32 {
                    # Space = toggle
                    $modIdx = $lineToIndex[$selectableLines[$cursor]]
                    $Modules[$modIdx].Selected = -not $Modules[$modIdx].Selected
                }
                65 {
                    # A = select all
                    foreach ($m in $Modules) { $m.Selected = $true }
                }
                78 {
                    # N = select none
                    foreach ($m in $Modules) { $m.Selected = $false }
                }
                13 {
                    # Enter = run
                    $selected = $Modules | Where-Object { $_.Selected }
                    if ($selected.Count -eq 0) {
                        Write-Host "  No scans selected. Press any key..." -ForegroundColor Red
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    }
                    else { return $Modules }
                }
                81 { return $null }  # Q = quit
            }
        }
    }

    # =====================================================================
    #  RUN SELECTED SCANS
    # =====================================================================
    function Invoke-SelectedScans {
        param(
            [array]$Modules,
            [array]$Subscriptions,
            [string]$TenantId,
            [hashtable]$DataSource
        )

        $selected = $Modules | Where-Object { $_.Selected }
        $results = @{}
        $total = $selected.Count
        $current = 0

        # Pre-load Hub data if Hub source selected
        $hubCostData = $null
        $hubResourceCosts = $null
        $hubRaw = $null
        $hubTagInventory = $null
        if ($DataSource.HubStorage) {
            # Always load Hub data when available — used for instant tag/cost-by-tag
            $hub = $DataSource.HubStorage
            if ($DataSource.Source -eq 'Hub') {
                Write-Host ""
                Write-Host "  Loading cost data from FinOps Hub..." -ForegroundColor Green
            }
            else {
                Write-Host "  Loading Hub tag data for fast tag scans..." -ForegroundColor DarkGray
            }
            try {
                $hubRaw = Read-FinOpsHubData -StorageAccountName $hub.name -ResourceGroupName $hub.resourceGroup -Months 1
            }
            catch {
                Write-Host "  Hub data load failed: $($_.Exception.Message)" -ForegroundColor Yellow
                $hubRaw = $null
            }
            if ($hubRaw -and @($hubRaw).Count -gt 0) {
                $hubTagInventory = ConvertTo-TagInventoryFromHub -HubData $hubRaw

                # Hub tag coverage only reflects resources with cost data — query ARG for true counts
                try {
                    $subIds = $Subscriptions | ForEach-Object { $_.Id }
                    $totalBody = @{
                        subscriptions = @($subIds)
                        query         = "resources | summarize TotalCount = count()"
                        options       = @{ resultFormat = 'objectArray' }
                    } | ConvertTo-Json -Depth 5
                    $totalResp = Invoke-AzRestMethodWithRetry -Path "/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" -Method POST -Payload $totalBody
                    if ($totalResp.StatusCode -eq 200) {
                        $totalRows = @(($totalResp.Content | ConvertFrom-Json).data)
                        if ($totalRows.Count -gt 0) {
                            $argTotal = [int]$totalRows[0].TotalCount

                            $untaggedBody = @{
                                subscriptions = @($subIds)
                                query         = "resources | where isnull(tags) or tags == '{}' | summarize UntaggedCount = count()"
                                options       = @{ resultFormat = 'objectArray' }
                            } | ConvertTo-Json -Depth 5
                            $untaggedResp = Invoke-AzRestMethodWithRetry -Path "/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" -Method POST -Payload $untaggedBody
                            if ($untaggedResp.StatusCode -eq 200) {
                                $untaggedRows = @(($untaggedResp.Content | ConvertFrom-Json).data)
                                $argUntagged = if ($untaggedRows.Count -gt 0) { [int]$untaggedRows[0].UntaggedCount } else { 0 }

                                $argTagged = [math]::Max(0, $argTotal - $argUntagged)
                                $argCoverage = if ($argTotal -gt 0) { [math]::Round(($argTagged / $argTotal) * 100, 1) } else { 0 }

                                # Override Hub coverage with ARG-based coverage
                                $hubTagInventory = $hubTagInventory | ForEach-Object {
                                    $_.TotalResources = $argTotal
                                    $_.TaggedCount = $argTagged
                                    $_.UntaggedCount = $argUntagged
                                    $_.TagCoverage = $argCoverage
                                    $_
                                }
                                Write-Host "  Tag coverage corrected via Resource Graph: $argCoverage% ($argTagged/$argTotal)" -ForegroundColor DarkGray
                            }
                        }
                    }
                }
                catch {
                    Write-Host "  Could not verify tag coverage via ARG: $($_.Exception.Message)" -ForegroundColor DarkGray
                }

                if ($DataSource.Source -eq 'Hub') {
                    $hubCostData = ConvertTo-CostDataFromHub -HubData $hubRaw
                    $hubResourceCosts = ConvertTo-ResourceCostsFromHub -HubData $hubRaw

                    # Hub exports are historical actuals — enrich with live forecast from Cost Management API
                    try {
                        Write-Host "  Fetching forecast data from Cost Management API..." -ForegroundColor DarkGray
                        $now = Get-Date
                        $monthEnd = (Get-Date -Year $now.Year -Month $now.Month -Day 1).AddMonths(1).AddDays(-1)
                        $forecastFilled = $false

                        # Try MG-scope forecast first
                        $fctTenantId = (Get-AzContext).Tenant.Id
                        if ($fctTenantId) {
                            $fctBody = @{
                                type                    = 'Usage'
                                timeframe               = 'Custom'
                                timePeriod              = @{
                                    from = $now.ToString('yyyy-MM-dd')
                                    to   = $monthEnd.ToString('yyyy-MM-dd')
                                }
                                dataset                 = @{
                                    granularity = 'None'
                                    aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                                    grouping    = @(@{ type = 'Dimension'; name = 'SubscriptionId' })
                                }
                                includeActualCost       = $false
                                includeFreshPartialCost = $false
                            } | ConvertTo-Json -Depth 10

                            $fctPath = "/providers/Microsoft.Management/managementGroups/$fctTenantId/providers/Microsoft.CostManagement/forecast?api-version=2023-11-01"
                            $fctResp = Invoke-AzRestMethodWithRetry -Path $fctPath -Method POST -Payload $fctBody
                            if ($fctResp.StatusCode -eq 200) {
                                $fctResult = ($fctResp.Content | ConvertFrom-Json)
                                if ($fctResult.properties.rows -and $fctResult.properties.rows.Count -gt 0) {
                                    $fctSums = @{}
                                    foreach ($row in $fctResult.properties.rows) {
                                        $subId = $row[1]
                                        if (-not $fctSums.ContainsKey($subId)) { $fctSums[$subId] = 0 }
                                        $fctSums[$subId] += [double]$row[0]
                                    }
                                    foreach ($subId in $fctSums.Keys) {
                                        if ($hubCostData.ContainsKey($subId)) {
                                            # Full-month projection = actual MTD + remaining forecast
                                            $actual = $hubCostData[$subId].Actual
                                            $hubCostData[$subId].Forecast = [math]::Round($actual + $fctSums[$subId], 2)
                                        }
                                    }
                                    $forecastFilled = $true
                                    Write-Host "  Forecast data loaded for $($fctSums.Count) subscription(s)" -ForegroundColor Green
                                }
                            }
                        }

                        # Per-subscription fallback if MG-scope failed
                        if (-not $forecastFilled -and $Subscriptions) {
                            $fctHits = 0
                            foreach ($sub in $Subscriptions) {
                                try {
                                    $fBody = @{
                                        type                    = 'Usage'
                                        timeframe               = 'Custom'
                                        timePeriod              = @{
                                            from = $now.ToString('yyyy-MM-dd')
                                            to   = $monthEnd.ToString('yyyy-MM-dd')
                                        }
                                        dataset                 = @{
                                            granularity = 'None'
                                            aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                                        }
                                        includeActualCost       = $false
                                        includeFreshPartialCost = $false
                                    } | ConvertTo-Json -Depth 10
                                    $fResp = Invoke-AzRestMethodWithRetry -Path "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/forecast?api-version=2023-11-01" -Method POST -Payload $fBody
                                    if ($fResp.StatusCode -eq 200) {
                                        $fRes = ($fResp.Content | ConvertFrom-Json)
                                        if ($fRes.properties.rows -and $fRes.properties.rows.Count -gt 0) {
                                            $fctTotal = 0
                                            foreach ($row in $fRes.properties.rows) { $fctTotal += [double]$row[0] }
                                            if ($hubCostData.ContainsKey($sub.Id)) {
                                                # Full-month projection = actual MTD + remaining forecast
                                                $actual = $hubCostData[$sub.Id].Actual
                                                $hubCostData[$sub.Id].Forecast = [math]::Round($actual + $fctTotal, 2)
                                                $fctHits++
                                            }
                                        }
                                    }
                                }
                                catch { }
                            }
                            if ($fctHits -gt 0) { Write-Host "  Forecast data loaded for $fctHits subscription(s)" -ForegroundColor Green }
                        }
                    }
                    catch {
                        Write-Host "  Forecast data unavailable: $($_.Exception.Message)" -ForegroundColor DarkGray
                    }

                    Write-Host "  Hub data loaded: $(@($hubRaw).Count) cost records, $($hubTagInventory.TagCount) tags, $($hubTagInventory.TagCoverage)% coverage" -ForegroundColor Green
                }
                else {
                    Write-Host "  Hub tag data ready: $($hubTagInventory.TagCount) tags, $($hubTagInventory.TagCoverage)% coverage" -ForegroundColor DarkGray
                }
            }
            else {
                $hubRaw = $null
                if ($DataSource.Source -eq 'Hub') {
                    Write-Host "  No Hub data found — falling back to Cost Management API" -ForegroundColor Yellow
                    $DataSource.Source = 'API'
                }
            }
            if ($DataSource.Source -eq 'Hub') { Write-Host "" }
        }

        $srcLabel = switch ($DataSource.Source) {
            'Hub' { "FinOps Hub ($($DataSource.HubStorage.name))" }
            'API' { "Cost Management API (real-time)" }
            'GraphOnly' { "Resource Graph only" }
        }
        Write-SectionHeader "RUNNING $total SCANS"
        $srcColor = switch ($DataSource.Source) { 'Hub' { 'Green' } 'API' { 'Yellow' } 'GraphOnly' { 'DarkGray' } }
        Write-Host "  $srcLabel" -ForegroundColor $srcColor
        Write-Host ""

        foreach ($mod in $selected) {
            $current++
            $pct = [math]::Round(($current / $total) * 100)
            $bar = ('█' * [math]::Floor($pct / 5)).PadRight(20, '░')

            Write-Host "  [$bar] $pct%  ($current/$total) $($mod.Name)" -ForegroundColor White -NoNewline

            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $fn = $mod.Fn
                $output = $null

                # Route parameters based on what each function expects
                # Hub shortcut: return pre-loaded Hub data for cost/tag modules
                switch ($fn) {
                    { $_ -eq 'Get-CostData' -and $hubCostData } {
                        $output = $hubCostData; break
                    }
                    { $_ -eq 'Get-ResourceCosts' -and $hubResourceCosts } {
                        $output = $hubResourceCosts; break
                    }
                    { $_ -eq 'Get-TagInventory' -and $hubTagInventory } {
                        $output = $hubTagInventory; break
                    }
                    { $_ -eq 'Get-CostByTag' -and $hubRaw } {
                        # Build cost-by-tag from Hub data — zero API calls
                        $existingTags = if ($results.ContainsKey('Get-TagInventory') -and $results['Get-TagInventory'].TagNames) {
                            $results['Get-TagInventory'].TagNames
                        }
                        elseif ($hubTagInventory) { $hubTagInventory.TagNames }
                        else { @{} }
                        $output = ConvertTo-CostByTagFromHub -HubData $hubRaw -ExistingTags $existingTags; break
                    }
                    'Get-TagRecommendations' {
                        $tags = if ($results.ContainsKey('Get-TagInventory') -and $results['Get-TagInventory'].TagNames) {
                            $results['Get-TagInventory'].TagNames
                        }
                        elseif ($hubTagInventory) { $hubTagInventory.TagNames }
                        else { @{} }
                        $output = & $fn -ExistingTags $tags; break
                    }
                    'Get-PolicyRecommendations' {
                        $assignments = if ($results.ContainsKey('Get-PolicyInventory') -and $results['Get-PolicyInventory'].Assignments) {
                            $results['Get-PolicyInventory'].Assignments
                        }
                        else { @() }
                        $output = & $fn -ExistingAssignments $assignments; break
                    }
                    'Get-BudgetStatus' {
                        $costData = if ($results.ContainsKey('Get-CostData') -and $results['Get-CostData'] -is [hashtable]) {
                            $results['Get-CostData']
                        }
                        elseif ($hubCostData -is [hashtable]) { $hubCostData }
                        else { @{} }
                        $output = & $fn -Subscriptions $Subscriptions -CostData $costData; break
                    }
                    'Get-BudgetHistory' {
                        # Depends on Budget Status — reuse the budgets it already found
                        $budgetResult = if ($results.ContainsKey('Get-BudgetStatus')) { $results['Get-BudgetStatus'] } else { $null }
                        $budgetRows = if ($budgetResult -and $budgetResult.Budgets) { @($budgetResult.Budgets) } else { @() }
                        if ($budgetRows.Count -gt 0) {
                            # Reuse Cost Trend's already-fetched monthly spend so we don't
                            # re-hit the throttle-prone Cost Management Query API.
                            $trendResult = if ($results.ContainsKey('Get-CostTrend')) { $results['Get-CostTrend'] } else { $null }
                            $output = & $fn -Budgets $budgetRows -MonthsBack 6 -CostTrend $trendResult
                        }
                        else {
                            $output = @()
                        }
                        break
                    }
                    'Get-MaccCommitment' {
                        # Pass the detected agreement type from Contract Info when available
                        $agreementType = ''
                        if ($results.ContainsKey('Get-ContractInfo') -and $results['Get-ContractInfo']) {
                            $agreementType = @($results['Get-ContractInfo'])[0].AgreementType
                        }
                        $output = & $fn -Subscriptions $Subscriptions -AgreementType $agreementType; break
                    }
                    { $_ -eq 'Get-CostByTag' -and -not $hubRaw } {
                        # No Hub data — fall back to API
                        $existingTags = if ($results.ContainsKey('Get-TagInventory') -and $results['Get-TagInventory'].TagNames) {
                            $results['Get-TagInventory'].TagNames
                        }
                        else { @{} }
                        $output = & $fn -TenantId $TenantId -ExistingTags $existingTags -Subscriptions $Subscriptions; break
                    }
                    'Get-AIWorkloadMetrics' {
                        # AI scan runs its own cheap ARG footprint gate; when the
                        # Hub source is selected, hand it the pre-loaded export so
                        # spend + token volume come from the export, not the
                        # Monitor + Cost Management APIs.
                        $aiParams = @{ TenantId = $TenantId; Subscriptions = $Subscriptions }
                        if ($DataSource.Source -eq 'Hub' -and $hubRaw -and @($hubRaw).Count -gt 0) {
                            $aiParams['HubData'] = $hubRaw
                        }
                        $output = & $fn @aiParams; break
                    }
                    default {
                        # Build params — include TenantId if the function accepts it
                        $params = @{ Subscriptions = $Subscriptions }
                        $cmdInfo = Get-Command $fn -ErrorAction SilentlyContinue
                        if ($cmdInfo -and $cmdInfo.Parameters.ContainsKey('TenantId') -and $TenantId) {
                            $params['TenantId'] = $TenantId
                        }
                        $output = & $fn @params
                    }
                }

                $sw.Stop()
                $count = if ($output) { @($output).Count } else { 0 }
                $results[$fn] = $output

                Write-Host "`r  [$bar] $pct%  ($current/$total) $($mod.Name) " -ForegroundColor Green -NoNewline
                Write-Host "  $count results ($([math]::Round($sw.Elapsed.TotalSeconds, 1))s)" -ForegroundColor DarkGray
            }
            catch {
                $sw.Stop()
                Write-Host "`r  [$bar] $pct%  ($current/$total) $($mod.Name) " -ForegroundColor Red -NoNewline
                Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
                $results[$mod.Fn] = @()
                $results["_error_$($mod.Fn)"] = $_.Exception.Message
            }
        }

        return $results
    }

    # =====================================================================
    #  RESULTS SUMMARY
    # =====================================================================
    function Write-SectionHeader {
        param([string]$Title, [string]$Color = 'Cyan')
        $line = '═' * 55
        Write-Host ""
        Write-Host "  $line" -ForegroundColor $Color
        Write-Host "  $Title" -ForegroundColor $Color
        Write-Host "  $line" -ForegroundColor $Color
    }

    # Write a line with dollar amounts ($1,234) highlighted in green
    function Write-ColorizedLine {
        param(
            [string]$Text,
            [string]$DefaultColor = 'White',
            [string]$MoneyColor = 'Green'
        )
        # Split on dollar-amount patterns, render them in green
        $parts = [regex]::Split($Text, '(\$[\d,]+\.?\d*(?:/\w+)?)')
        foreach ($part in $parts) {
            if ($part -match '^\$[\d,]+\.?\d*') {
                Write-Host $part -ForegroundColor $MoneyColor -NoNewline
            }
            else {
                Write-Host $part -ForegroundColor $DefaultColor -NoNewline
            }
        }
        Write-Host ""
    }
    function Show-PermissionReadout {
        param(
            [string]$Fn,
            [hashtable]$PermissionInfo,
            [string]$Activity
        )
        $pInfo = if ($PermissionInfo -and $PermissionInfo.ContainsKey($Fn)) { $PermissionInfo[$Fn] } else { $null }
        $what = if ($Activity) { " reading $Activity" } else { '' }
        Write-Host "    [!] ACCESS DENIED$what (the API returned access denied, not empty results)." -ForegroundColor Red
        if ($pInfo) {
            Write-Host "    Required role:  $($pInfo.Role)" -ForegroundColor Yellow
            Write-Host "    Scope:          $($pInfo.Scope)" -ForegroundColor Yellow
            Write-Host "    API:            $($pInfo.API)" -ForegroundColor DarkGray
            Write-Host "    $($pInfo.Reason)" -ForegroundColor DarkGray
            Write-Host "    Ask a billing or subscription admin to assign the matching role, then re-scan." -ForegroundColor DarkGray
        }
    }

    function Show-ResultsSummary {
        param(
            [hashtable]$Results,
            [array]$Modules,
            [string]$ExportPath,
            [array]$Subscriptions
        )

        # Build sub ID → name lookup for display functions
        $subNameLookup = @{}
        if ($Subscriptions) { foreach ($s in $Subscriptions) { if ($s.Id -and $s.Name) { $subNameLookup[$s.Id] = $s.Name } } }

        Write-SectionHeader 'SCAN COMPLETE'
        Write-Host ""

        $totalFindings = 0
        foreach ($mod in ($Modules | Where-Object { $_.Selected })) {
            $data = $Results[$mod.Fn]
            $errorKey = "_error_$($mod.Fn)"
            $hasError = $Results.ContainsKey($errorKey)
            $count = if ($data) { @($data).Count } else { 0 }
            $totalFindings += $count
            if ($hasError) {
                $icon = '!'
                $color = 'Red'
                $suffix = 'error (see details below)'
            }
            elseif ($count -gt 0) {
                $icon = '*'
                $color = 'Yellow'
                $suffix = "$count findings"
            }
            else {
                $icon = '-'
                $color = 'DarkGray'
                $suffix = '0 findings'
            }
            Write-Host "  $icon $($mod.Name.PadRight(30)) $suffix" -ForegroundColor $color
        }

        Write-Host ""
        Write-Host "  Total findings: $totalFindings" -ForegroundColor White
        Write-Host ""

        # -- Display results per module ------------------------------------
        foreach ($mod in ($Modules | Where-Object { $_.Selected })) {
            $data = $Results[$mod.Fn]
            if (-not $data -or @($data).Count -eq 0) {
                # Show why data is missing — error or permissions
                $errorKey = "_error_$($mod.Fn)"
                $errorMsg = if ($Results.ContainsKey($errorKey)) { $Results[$errorKey] } else { $null }
                $pInfo = if ($permissionInfo.ContainsKey($mod.Fn)) { $permissionInfo[$mod.Fn] } else { $null }

                Write-SectionHeader $mod.Name
                if ($errorMsg) {
                    # Detect permission-related errors
                    $isPermError = $errorMsg -match '(?i)403|401|Forbidden|Unauthorized|AuthorizationFailed|does not have authorization|InsufficientPermissions|BillingAccountNotFound'
                    if ($isPermError -and $pInfo) {
                        Write-Host "    [!] ACCESS DENIED" -ForegroundColor Red
                        Write-Host "    $errorMsg" -ForegroundColor DarkGray
                        Write-Host ""
                        Write-Host "    Required role:  $($pInfo.Role)" -ForegroundColor Yellow
                        Write-Host "    Scope:          $($pInfo.Scope)" -ForegroundColor Yellow
                        Write-Host "    API:            $($pInfo.API)" -ForegroundColor DarkGray
                        Write-Host "    $($pInfo.Reason)" -ForegroundColor DarkGray
                    }
                    else {
                        Write-Host "    [!] ERROR: $errorMsg" -ForegroundColor Red
                        if ($pInfo) {
                            Write-Host "    If this is a permissions issue:" -ForegroundColor DarkGray
                            Write-Host "    Required role: $($pInfo.Role) at $($pInfo.Scope) scope" -ForegroundColor DarkGray
                        }
                    }
                }
                else {
                    # No error but no data — could be legitimately empty
                    Write-Host "    No data returned." -ForegroundColor DarkGray
                    if ($pInfo) {
                        Write-Host "    Possible reasons:" -ForegroundColor DarkGray
                        Write-Host "    - $($pInfo.Reason)" -ForegroundColor DarkGray
                        Write-Host "    - Required role: $($pInfo.Role) at $($pInfo.Scope) scope" -ForegroundColor DarkGray
                    }
                }
                Write-Host ""
                continue
            }

            Write-SectionHeader $mod.Name

            # Extract the displayable rows and columns per module
            $rows = $null
            $cols = $null

            switch ($mod.Fn) {
                'Get-OrphanedResources' {
                    $rows = $data.Orphans
                    $cols = @('Category', 'ResourceName', 'ResourceGroup', 'Detail')
                }
                'Get-IdleVMs' {
                    $scanned = if ($data.ScannedVMs) { $data.ScannedVMs } else { 0 }
                    if ($data.IdleVMs -and @($data.IdleVMs).Count -gt 0) {
                        Write-Host "    Scanned $scanned running VMs — $(@($data.IdleVMs).Count) idle/underutilized" -ForegroundColor White
                        $rows = $data.IdleVMs
                        $cols = @('VMName', 'ResourceGroup', 'VMSize', 'AvgCPU14d', 'Classification')
                    }
                    else {
                        Write-Host "    Scanned $scanned running VMs — no idle or underutilized VMs detected" -ForegroundColor Green
                    }
                }
                'Get-StorageTierAdvice' {
                    $hotCount = if ($data.TotalHotAccounts) { $data.TotalHotAccounts } else { 0 }
                    if ($data.Recommendations -and @($data.Recommendations).Count -gt 0) {
                        Write-Host "    $hotCount Hot-tier accounts scanned — $(@($data.Recommendations).Count) can be optimized" -ForegroundColor White
                        $rows = $data.Recommendations
                        $cols = @('StorageAccount', 'ResourceGroup', 'CurrentTier', 'CapacityGB', 'Recommendation')
                    }
                    else {
                        Write-Host "    $hotCount Hot-tier accounts scanned — all are appropriately tiered" -ForegroundColor Green
                    }
                }
                'Get-AHBOpportunities' {
                    $rows = @()
                    if ($data.WindowsVMs) {
                        $rows += @($data.WindowsVMs) | ForEach-Object {
                            [PSCustomObject]@{ Type = 'Windows VM'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.vmSize; License = $_.currentLicense }
                        }
                    }
                    if ($data.SQLVMs) {
                        $rows += @($data.SQLVMs) | ForEach-Object {
                            [PSCustomObject]@{ Type = 'SQL VM'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.sqlEdition; License = $_.currentLicense }
                        }
                    }
                    if ($data.SQLDatabases) {
                        $rows += @($data.SQLDatabases) | ForEach-Object {
                            [PSCustomObject]@{ Type = 'SQL DB'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.sku; License = $_.currentLicense }
                        }
                    }
                    $cols = @('Type', 'Name', 'ResourceGroup', 'Size', 'License')
                }
                'Get-ReservationAdvice' {
                    if ($data.AccessDenied) {
                        Show-PermissionReadout -Fn 'Get-ReservationAdvice' -PermissionInfo $permissionInfo -Activity 'Advisor / reservation recommendations'
                    }
                    else {
                    $rows = $data.AdvisorRecommendations | ForEach-Object {
                        $resLabel = if ($_.Subscription -and $_.Subscription -ne $_.SubscriptionId) { $_.Subscription }
                        elseif ($_.Solution) { $_.Solution.Substring(0, [math]::Min(50, $_.Solution.Length)) }
                        else { ($_.ResourceName -split '/')[-1] }
                        [PSCustomObject]@{
                            Resource = $resLabel
                            Type     = ($_.ResourceType -split '/')[-1]
                            Term     = $_.Term
                            Savings  = '{0:C0}' -f [double]$_.AnnualSavings
                            Impact   = $_.Impact
                        }
                    }
                    $cols = @('Resource', 'Type', 'Term', 'Savings', 'Impact')
                    if ($data.EstimatedAnnualSavings) {
                        Write-ColorizedLine -Text "    Est. annual savings: $($data.EstimatedAnnualSavings.ToString('C0'))" -DefaultColor 'White'
                    }
                    }
                }
                'Get-CommitmentUtilization' {
                    if ($data.HasData) {
                        Write-Host "    RIs: $($data.RICount) (avg $($data.RIAvgUtilization)% util)  |  Savings Plans: $($data.SPCount) (avg $($data.SPAvgUtilization)% util)" -ForegroundColor White
                        $rows = $data.UnderutilizedRIs | ForEach-Object {
                            [PSCustomObject]@{ SKU = $_.SkuName; Kind = $_.Kind; AvgUtil = "$($_.AvgUtilization)%"; MinUtil = "$($_.MinUtilization)%" }
                        }
                        $cols = @('SKU', 'Kind', 'AvgUtil', 'MinUtil')
                    }
                    elseif ($data.AccessDenied) {
                        Show-PermissionReadout -Fn 'Get-CommitmentUtilization' -PermissionInfo $permissionInfo -Activity 'reservation / savings plan utilization'
                    }
                    else {
                        Write-Host "    No active reservations or savings plans found." -ForegroundColor DarkGray
                    }
                }
                'Get-SavingsRealized' {
                    Write-Host "    Monthly savings breakdown:" -ForegroundColor White
                    Write-ColorizedLine -Text "      RI:  $($data.RISavingsMonthly.ToString('C0'))   SP: $($data.SPSavingsMonthly.ToString('C0'))   AHB: $($data.AHBSavingsMonthly.ToString('C0'))" -DefaultColor 'Cyan'
                    Write-ColorizedLine -Text "      Total monthly: $($data.TotalMonthly.ToString('C0'))   Annual: $($data.TotalAnnual.ToString('C0'))" -DefaultColor 'White'
                    $rows = $null  # summary only
                }
                'Get-CostData' {
                    # CostData is a hashtable keyed by subscription ID
                    if ($data -is [hashtable]) {
                        $rows = $data.GetEnumerator() | ForEach-Object {
                            $subLabel = if ($subNameLookup.ContainsKey($_.Key)) { $subNameLookup[$_.Key] } else { $_.Key.Substring(0, [Math]::Min(36, $_.Key.Length)) }
                            [PSCustomObject]@{
                                Subscription = $subLabel
                                Actual       = '{0:C0}' -f [double]$_.Value.Actual
                                Forecast     = '{0:C0}' -f [double]$_.Value.Forecast
                                Currency     = $_.Value.Currency
                            }
                        }
                        $cols = @('Subscription', 'Actual', 'Forecast', 'Currency')
                    }
                }
                'Get-ResourceCosts' {
                    $rows = @($data) | Sort-Object { [double]$_.Actual } -Descending | Select-Object -First 20 | ForEach-Object {
                        [PSCustomObject]@{
                            ResourceGroup = $_.ResourceGroup
                            ResourceType  = ($_.ResourceType -split '/')[-1]
                            Cost          = '{0:C2}' -f [double]$_.Actual
                        }
                    }
                    $cols = @('ResourceGroup', 'ResourceType', 'Cost')
                    if (@($data).Count -gt 20) {
                        Write-Host "    (showing top 20 of $(@($data).Count) resources by cost)" -ForegroundColor DarkGray
                    }
                }
                'Get-CostByTag' {
                    if ($data.CostByTag -and $data.CostByTag.Count -gt 0) {
                        if ($data.Source) { Write-Host "    Source: $($data.Source)" -ForegroundColor DarkGray }
                        $rows = foreach ($tag in $data.CostByTag.GetEnumerator()) {
                            foreach ($v in $tag.Value) {
                                $displayVal = if ($v.TagValue.Length -gt 40) { $v.TagValue.Substring(0, 37) + '...' } else { $v.TagValue }
                                [PSCustomObject]@{ Tag = $tag.Key; Value = $displayVal; Cost = '{0:C0}' -f [double]$v.Cost }
                            }
                        }
                        $cols = @('Tag', 'Value', 'Cost')
                    }
                    elseif ($data.NoTagsFound) {
                        Write-Host "    No tags found in environment to query cost against." -ForegroundColor DarkGray
                    }
                    else {
                        $tagCount = if ($data.TagsQueried) { $data.TagsQueried.Count } else { 0 }
                        $cbtCount = if ($data.CostByTag) { $data.CostByTag.Count } else { 0 }
                        Write-Host "    Tags queried: $tagCount, results: $cbtCount — no cost data returned." -ForegroundColor DarkGray
                        if ($data.UsedTimeframe) { Write-Host "    Timeframe: $($data.UsedTimeframe)" -ForegroundColor DarkGray }
                    }
                }
                'Get-CostTrend' {
                    # Per-sub data only counts when a subscription actually has months
                    $nonEmptySubs = @()
                    if ($data.BySubscription -and $data.BySubscription.Count -gt 0) {
                        $nonEmptySubs = @($data.BySubscription.GetEnumerator() | Where-Object { $_.Value -and @($_.Value).Count -gt 0 })
                    }
                    $hasMonths = ($data.Months -and @($data.Months).Count -gt 0)

                    if ((-not $nonEmptySubs -or $nonEmptySubs.Count -eq 0) -and -not $hasMonths) {
                        Write-Host "    No cost trend data returned. Requires Cost Management Reader at the subscription or MG scope, or there is no historical spend in the selected period." -ForegroundColor DarkGray
                        $rows = $null
                        $cols = $null
                    }
                    elseif ($nonEmptySubs -and $nonEmptySubs.Count -gt 0) {
                        foreach ($subEntry in $nonEmptySubs) {
                            $subName = if ($subNameLookup.ContainsKey($subEntry.Key)) { $subNameLookup[$subEntry.Key] } else { $subEntry.Key }
                            Write-Host "    $subName" -ForegroundColor White
                            $subRows = $subEntry.Value | ForEach-Object {
                                [PSCustomObject]@{ Month = $_.Month; Cost = '{0:C0}' -f [double]$_.Cost; Currency = $_.Currency }
                            }
                            @($subRows) | Format-Table -AutoSize | Out-String | ForEach-Object {
                                $lines = $_.TrimEnd() -split "`n" | Where-Object { $_.Trim() }
                                $hdrDone = $false
                                foreach ($ln in $lines) {
                                    if (-not $hdrDone) {
                                        if ($ln -match '^[\s\-]+$') { Write-Host "    $ln" -ForegroundColor DarkCyan; $hdrDone = $true }
                                        else { Write-Host "    $ln" -ForegroundColor Cyan }
                                    }
                                    else { Write-ColorizedLine -Text "    $ln" -DefaultColor 'White' }
                                }
                            }
                        }
                        # Skip default table rendering
                        $rows = $null
                        $cols = $null
                    }
                    else {
                        # Fallback: aggregate months with sub name header
                        if ($Subscriptions -and $Subscriptions.Count -gt 0) {
                            $subNames = ($Subscriptions | ForEach-Object { if ($_.Name) { $_.Name } else { $_.Id } }) -join ', '
                            Write-Host "    $subNames" -ForegroundColor White
                        }
                        $rows = $data.Months | ForEach-Object {
                            [PSCustomObject]@{ Month = $_.Month; Cost = '{0:C0}' -f [double]$_.Cost; Currency = $_.Currency }
                        }
                        $cols = @('Month', 'Cost', 'Currency')
                    }
                }
                'Get-TagInventory' {
                    Write-Host "    Coverage: $($data.TagCoverage)%  |  $($data.TaggedCount) tagged / $($data.UntaggedCount) untagged  |  $($data.TagCount) unique tags" -ForegroundColor White
                    if ($data.TagNames -and $data.TagNames.Count -gt 0) {
                        $rows = $data.TagNames.GetEnumerator() | Sort-Object { $_.Value.TotalResources } -Descending | Select-Object -First 15 | ForEach-Object {
                            [PSCustomObject]@{ Tag = $_.Key; Resources = $_.Value.TotalResources; UniqueValues = @($_.Value.Values).Count }
                        }
                        $cols = @('Tag', 'Resources', 'UniqueValues')
                    }
                }
                'Get-TagRecommendations' {
                    $rows = $data.Analysis | ForEach-Object {
                        [PSCustomObject]@{ Tag = $_.TagName; Status = $_.Status; Priority = $_.Priority; Pillar = $_.Pillar; Example = $_.Example }
                    }
                    $cols = @('Tag', 'Status', 'Priority', 'Pillar', 'Example')
                    Write-Host "    Compliance: $($data.CompliancePercent)%" -ForegroundColor White
                }
                'Get-PolicyInventory' {
                    $hasComplianceData = if ($null -ne $data.HasComplianceData) { $data.HasComplianceData } else { (($data.TotalCompliant + $data.TotalNonCompliant) -gt 0) }
                    if ($hasComplianceData) {
                        Write-Host "    Assignments: $($data.AssignmentCount)  |  Compliance: $($data.CompliancePct)%  ($($data.TotalCompliant) compliant, $($data.TotalNonCompliant) non-compliant)" -ForegroundColor White
                    }
                    else {
                        Write-Host "    Assignments: $($data.AssignmentCount)  |  Compliance: data unavailable (no evaluated policy states)" -ForegroundColor White
                    }
                    $rows = $data.Assignments | Select-Object -First 15 | ForEach-Object {
                        # Parse scope into a readable label
                        $scopeRaw = $_.Scope
                        $scopeLabel = if ($scopeRaw -match '/managementGroups/([^/]+)') {
                            $mgId = $Matches[1]
                            if ($mgId.Length -gt 20) { "MG: $($mgId.Substring(0,17))..." } else { "MG: $mgId" }
                        }
                        elseif ($scopeRaw -match '/resourceGroups/([^/]+)') { "RG: $($Matches[1])" }
                        elseif ($scopeRaw -match '/subscriptions/([^/]+)') {
                            $subId = $Matches[1]
                            $subName = if ($subNameLookup.ContainsKey($subId)) { $subNameLookup[$subId] } else { $subId.Substring(0, 8) + '...' }
                            "Sub: $subName"
                        }
                        else { $scopeRaw }
                        # Truncate long policy names (some embed subscription GUIDs)
                        $displayName = $_.AssignmentName
                        if ($displayName.Length -gt 60) { $displayName = $displayName.Substring(0, 57) + '...' }
                        [PSCustomObject]@{ Name = $displayName; Effect = $_.Effect; Enforcement = $_.EnforcementMode; Scope = $scopeLabel }
                    }
                    $cols = @('Name', 'Effect', 'Enforcement', 'Scope')
                    if ($data.AssignmentCount -gt 15) {
                        Write-Host "    (showing 15 of $($data.AssignmentCount) assignments)" -ForegroundColor DarkGray
                    }
                }
                'Get-PolicyRecommendations' {
                    $rows = $data.Analysis | ForEach-Object {
                        [PSCustomObject]@{ Policy = $_.DisplayName; Status = $_.Status; Category = $_.Category; Priority = $_.Priority; Effect = $_.DefaultEffect }
                    }
                    $cols = @('Policy', 'Status', 'Category', 'Priority', 'Effect')
                    Write-Host "    Compliance: $($data.CompliancePct)%" -ForegroundColor White
                }
                'Get-BudgetStatus' {
                    $bSumColor = if ($data.OverBudgetCount -gt 0) { 'Red' } elseif ($data.AtRiskCount -gt 0) { 'Yellow' } else { 'Green' }
                    Write-Host "    Budgets: $($data.TotalBudgets)  |  " -ForegroundColor White -NoNewline
                    Write-Host "At risk: $($data.AtRiskCount)" -ForegroundColor $(if ($data.AtRiskCount -gt 0) { 'Yellow' } else { 'Green' }) -NoNewline
                    Write-Host "  |  " -ForegroundColor White -NoNewline
                    Write-Host "Over budget: $($data.OverBudgetCount)" -ForegroundColor $(if ($data.OverBudgetCount -gt 0) { 'Red' } else { 'Green' }) -NoNewline
                    Write-Host "  |  Coverage: $($data.BudgetCoverage)%" -ForegroundColor White
                    $rows = $data.Budgets | ForEach-Object {
                        [PSCustomObject]@{
                            Budget  = $_.BudgetName
                            Amount  = '{0:C0}' -f [double]$_.Amount
                            Spent   = '{0:C0}' -f [double]$_.ActualSpend
                            PctUsed = "$($_.PctUsed)%"
                            Risk    = $_.Risk
                        }
                    }
                    $cols = @('Budget', 'Amount', 'Spent', 'PctUsed', 'Risk')
                }
                'Get-BudgetHistory' {
                    if ($data -and @($data).Count -gt 0) {
                        $rows = @($data) | ForEach-Object {
                            [PSCustomObject]@{
                                Subscription = $_.Subscription
                                Budget       = $_.BudgetName
                                Month        = $_.Month
                                Budgeted     = '{0:C0}' -f [double]$_.BudgetAmount
                                Actual       = '{0:C0}' -f [double]$_.ActualSpend
                                PctUsed      = "$($_.PctUsed)%"
                                Status       = $_.Status
                            }
                        }
                        $cols = @('Subscription', 'Budget', 'Month', 'Budgeted', 'Actual', 'PctUsed', 'Status')
                    }
                    else {
                        Write-Host "    No budget history available (no budgets configured, or no cost data for the period)." -ForegroundColor DarkGray
                    }
                }
                'Get-AnomalyAlerts' {
                    Write-Host "    Alerts: $($data.TotalAlerts)  |  Anomaly: $($data.AnomalyAlertCount)  |  Active: $($data.ActiveAlertCount)  |  Rules: $($data.ConfiguredRuleCount)" -ForegroundColor White
                    $rows = $data.TriggeredAlerts | Select-Object -First 10 | ForEach-Object {
                        [PSCustomObject]@{ Alert = $_.AlertName; Type = $_.AlertType; Status = $_.Status; Subscription = $_.Subscription }
                    }
                    $cols = @('Alert', 'Type', 'Status', 'Subscription')
                }
                'Get-BillingStructure' {
                    $rows = $data.BillingAccounts | ForEach-Object {
                        [PSCustomObject]@{ Account = $_.DisplayName; Agreement = $_.AgreementType; Type = $_.AccountType; Status = $_.AccountStatus }
                    }
                    $cols = @('Account', 'Agreement', 'Type', 'Status')
                }
                'Get-ContractInfo' {
                    $rows = @($data) | ForEach-Object {
                        [PSCustomObject]@{ Account = $_.AccountName; Agreement = $_.AgreementType; Type = $_.FriendlyType; Currency = $_.Currency; Status = $_.AccountStatus }
                    }
                    $cols = @('Account', 'Agreement', 'Type', 'Currency', 'Status')
                }
                'Get-MaccCommitment' {
                    if (-not $data.Applicable) {
                        Write-Host "    $($data.Reason)" -ForegroundColor DarkGray
                    }
                    elseif ($data.HasMacc -and @($data.Commitments).Count -gt 0) {
                        $rows = @($data.Commitments) | ForEach-Object {
                            [PSCustomObject]@{
                                Account    = $_.BillingAccount
                                Commitment = '{0:C0}' -f [double]$_.Commitment
                                Consumed   = '{0:C0}' -f [double]$_.Consumed
                                Remaining  = '{0:C0}' -f [double]$_.Remaining
                                PctUsed    = "$($_.PctUsed)%"
                                Status     = $_.Status
                                Expires    = $_.ExpirationDate
                            }
                        }
                        $cols = @('Account', 'Commitment', 'Consumed', 'Remaining', 'PctUsed', 'Status', 'Expires')
                    }
                    else {
                        Write-Host "    $($data.Reason)" -ForegroundColor DarkGray
                    }
                }
                'Get-OptimizationAdvice' {
                    if ($data.EstimatedAnnualSavings) {
                        Write-ColorizedLine -Text "    Est. annual savings: `$$($data.EstimatedAnnualSavings)  |  $($data.TotalCount) recommendations" -DefaultColor 'White'
                    }
                    $rows = $data.Recommendations | Sort-Object { if ($_.AnnualSavings) { [double]$_.AnnualSavings } else { 0 } } -Descending | Select-Object -First 15 | ForEach-Object {
                        [PSCustomObject]@{
                            Category = $_.Category
                            Impact   = $_.Impact
                            Resource = $_.ResourceName
                            Problem  = ($_.Problem -replace '(.{60}).+', '$1...')
                            Savings  = if ($_.AnnualSavings) { '{0:C0}/yr' -f [double]$_.AnnualSavings } else { '-' }
                        }
                    }
                    $cols = @('Category', 'Impact', 'Resource', 'Problem', 'Savings')
                    if ($data.TotalCount -gt 15) {
                        Write-Host "    (showing top 15 of $($data.TotalCount) by savings)" -ForegroundColor DarkGray
                    }
                }
                'Get-CarbonMetrics' {
                    $arrow = if ($data.ChangeValueKg -gt 0) { 'up' } elseif ($data.ChangeValueKg -lt 0) { 'down' } else { 'flat' }
                    Write-ColorizedLine -Text "    Latest month ($($data.LatestMonth)): $($data.TotalEmissionsKg) $($data.Unit)  |  MoM $arrow $($data.ChangeRatio)%" -DefaultColor 'White'
                    $rows = $data.BySubscription | Select-Object -First 15 | ForEach-Object {
                        [PSCustomObject]@{
                            Subscription = $_.Subscription
                            Emissions    = "$($_.EmissionsKg) kg"
                        }
                    }
                    $cols = @('Subscription', 'Emissions')
                }
                'Get-LegacyResources' {
                    Write-ColorizedLine -Text "    $($data.TotalCount) legacy/retiring resources found" -DefaultColor 'White'
                    $rows = $data.LegacyResources | Select-Object -First 20 | ForEach-Object {
                        [PSCustomObject]@{
                            Category = $_.Category
                            Resource = $_.ResourceName
                            Detail   = ($_.Detail -replace '(.{55}).+', '$1...')
                            Impact   = $_.Impact
                        }
                    }
                    $cols = @('Category', 'Resource', 'Detail', 'Impact')
                }
                'Get-UnitEconomics' {
                    Write-ColorizedLine -Text "    Compute: $($data.Currency) $($data.ComputeCost) over $($data.VmCount) VMs / ~$($data.TotalVCpu) vCPU" -DefaultColor 'White'
                    Write-ColorizedLine -Text "    Storage: $($data.Currency) $($data.StorageCost) over $($data.TotalStorageGb) GB" -DefaultColor 'White'
                    $rows = @(
                        [PSCustomObject]@{ Metric = 'Cost per vCPU'; Value = "$($data.Currency) $($data.CostPerVCpu)" }
                        [PSCustomObject]@{ Metric = 'Cost per VM'; Value = "$($data.Currency) $($data.CostPerVm)" }
                        [PSCustomObject]@{ Metric = 'Cost per GB'; Value = "$($data.Currency) $($data.CostPerGb)" }
                    )
                    $cols = @('Metric', 'Value')
                }
                'Get-AIWorkloadMetrics' {
                    if (-not $data.HasData) {
                        Write-Host "    No AI workloads detected — AI KPIs skipped." -ForegroundColor Green
                    }
                    else {
                        $fp = $data.AIFootprint
                        Write-ColorizedLine -Text "    AI footprint — OpenAI/AIServices: $($fp.OpenAIAccounts + $fp.AIServices)  ML workspaces: $($fp.MLWorkspaces)  AI Search: $($fp.SearchServices)  GPU VMs: $($fp.GpuVmCount)" -DefaultColor 'White'
                        Write-ColorizedLine -Text "    Tokens (MTD): $($data.TotalTokens) total ($($data.TotalPromptTokens) in / $($data.TotalGeneratedTokens) out) over $($data.TotalRequests) requests" -DefaultColor 'White'
                        Write-ColorizedLine -Text "    AI spend (MTD): $($data.Currency) $($data.TotalAICost)  |  $($data.Currency) $($data.CostPer1KTokens)/1K tokens  |  $($data.Currency) $($data.CostPerRequest)/request" -DefaultColor 'White'
                        if ($data.Note) { Write-Host "    $($data.Note)" -ForegroundColor DarkGray }
                        if ($data.ByModel -and @($data.ByModel).Count -gt 0) {
                            $rows = $data.ByModel
                            $cols = @('Deployment', 'PromptTokens', 'GeneratedTokens', 'TotalTokens', 'PctOfTokens')
                        }
                        elseif ($data.ByAccount -and @($data.ByAccount).Count -gt 0) {
                            $rows = $data.ByAccount
                            $cols = @('Name', 'Tokens', 'Requests', 'Cost', 'CostPer1KTokens')
                        }
                    }
                }
                default {
                    # Fallback: try to display as-is with first 4 properties
                    $items = @($data)
                    $sample = $items[0]
                    if ($sample.PSObject) {
                        $cols = $sample.PSObject.Properties.Name | Select-Object -First 4
                        $rows = $items
                    }
                }
            }

            # Render the table
            if ($rows -and @($rows).Count -gt 0) {
                $validCols = $cols | Where-Object { $_ }
                if ($validCols) {
                    # Budget Status: color each row by risk level
                    if ($mod.Fn -eq 'Get-BudgetStatus') {
                        $budgetRows = @($rows)
                        # Render header manually
                        $headerStr = @($budgetRows) | Select-Object $validCols | Format-Table -AutoSize | Out-String |
                        ForEach-Object { $_.TrimEnd() -split "`n" | Where-Object { $_.Trim() } }
                        if ($headerStr.Count -ge 2) {
                            Write-Host "    $($headerStr[0])" -ForegroundColor Cyan
                            Write-Host "    $($headerStr[1])" -ForegroundColor DarkCyan
                        }
                        # Render each data row with risk-based color
                        for ($ri = 2; $ri -lt $headerStr.Count; $ri++) {
                            $budgetLine = $headerStr[$ri]
                            $matchedBudget = $null
                            if ($ri - 2 -lt $budgetRows.Count) { $matchedBudget = $budgetRows[$ri - 2] }
                            $riskVal = if ($matchedBudget -and $matchedBudget.Risk) { $matchedBudget.Risk } else { '' }
                            $rowColor = switch ($riskVal) {
                                'Over Budget' { 'Red' }
                                'Forecast Over' { 'Yellow' }
                                'At Risk' { 'Yellow' }
                                'Watch' { 'DarkYellow' }
                                default { 'Green' }
                            }
                            Write-ColorizedLine -Text "    $budgetLine" -DefaultColor $rowColor
                        }
                    }
                    else {
                        $tableLines = @($rows) | Select-Object $validCols | Format-Table -AutoSize | Out-String |
                        ForEach-Object { $_.TrimEnd() -split "`n" | Where-Object { $_.Trim() } }
                        $headerDone = $false
                        foreach ($line in $tableLines) {
                            if (-not $headerDone) {
                                # First two lines are header + separator
                                if ($line -match '^[\s\-]+$') {
                                    Write-Host "    $line" -ForegroundColor DarkCyan
                                    $headerDone = $true
                                }
                                else {
                                    Write-Host "    $line" -ForegroundColor Cyan
                                }
                            }
                            else {
                                Write-ColorizedLine -Text "    $line" -DefaultColor 'White'
                            }
                        }
                    }
                }
            }
            elseif (-not $rows) {
                # Module used inline Write-Host (like SavingsRealized) — no table needed
            }
            else {
                Write-Host "    (no findings)" -ForegroundColor DarkGray
            }

            # -- Contextual Guidance ---------------------------------------
            # Severity: Red = address immediately, Yellow = needs attention, Green = doing well
            $guidanceItems = @()
            switch ($mod.Fn) {
                'Get-OrphanedResources' {
                    $orphanCount = if ($data.Orphans) { @($data.Orphans).Count } else { 0 }
                    if ($orphanCount -gt 10) {
                        $categories = @($data.Orphans | ForEach-Object { $_.Category } | Sort-Object -Unique) -join ', '
                        $guidanceItems = @(
                            @{ Severity = 'Red'; Message = "$orphanCount orphaned resources found ($categories). These generate cost with zero value." }
                            @{ Severity = 'Red'; Message = "FinOps Principle: Eliminate waste before optimizing. Orphaned resources are the easiest wins." }
                            @{ Severity = 'Yellow'; Message = "Set up Azure Policy to audit unattached disks, NICs, and public IPs to prevent future orphans." }
                            @{ Severity = 'Yellow'; Message = "Build a monthly cleanup cadence — orphans accumulate fast as teams scale up and down."; Docs = 'https://learn.microsoft.com/azure/advisor/advisor-cost-recommendations' }
                        )
                    }
                    elseif ($orphanCount -gt 0) {
                        $categories = @($data.Orphans | ForEach-Object { $_.Category } | Sort-Object -Unique) -join ', '
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "$orphanCount orphaned resources found ($categories). Review and delete to reclaim spend." }
                            @{ Severity = 'Yellow'; Message = "Use Azure Policy to audit unattached disks and NICs going forward."; Docs = 'https://learn.microsoft.com/azure/advisor/advisor-cost-recommendations' }
                        )
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "No orphaned resources. Environment is clean — good operational hygiene." }
                        )
                    }
                }
                'Get-IdleVMs' {
                    $idleCount = if ($data.IdleVMs) { @($data.IdleVMs).Count } else { 0 }
                    $scanned = if ($data.ScannedVMs) { $data.ScannedVMs } else { 0 }
                    if ($idleCount -gt 5) {
                        $guidanceItems = @(
                            @{ Severity = 'Red'; Message = "$idleCount of $scanned VMs are idle or underutilized. This is likely significant wasted spend." }
                            @{ Severity = 'Red'; Message = "FinOps Action: Check Azure Advisor for right-size recommendations before deleting — some may just need a smaller SKU." }
                            @{ Severity = 'Yellow'; Message = "For dev/test workloads, implement auto-shutdown schedules (saves 50-70% on non-production VMs)." }
                            @{ Severity = 'Yellow'; Message = "Consider Azure Spot VMs for fault-tolerant workloads — up to 90% discount vs. pay-as-you-go."; Docs = 'https://learn.microsoft.com/azure/virtual-machines/spot-vms' }
                        )
                    }
                    elseif ($idleCount -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "$idleCount idle VMs detected. Right-size or deallocate to reduce spend." }
                            @{ Severity = 'Yellow'; Message = "Check Advisor for SKU recommendations. Auto-shutdown schedules help for dev/test."; Docs = 'https://learn.microsoft.com/azure/advisor/advisor-cost-recommendations#optimize-virtual-machine-spend' }
                        )
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "All $scanned running VMs are actively utilized. Compute spend looks healthy." }
                        )
                    }
                }
                'Get-StorageTierAdvice' {
                    $recoCount = if ($data.Recommendations) { @($data.Recommendations).Count } else { 0 }
                    if ($recoCount -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "$recoCount storage accounts can be moved to a cheaper tier (Cool or Cold saves 50-75%)." }
                            @{ Severity = 'Yellow'; Message = "FinOps Principle: Match storage tier to access patterns. Most data is written once and rarely read." }
                            @{ Severity = 'Yellow'; Message = "Enable lifecycle management policies to auto-tier blobs based on last access time — set it and forget it."; Docs = 'https://learn.microsoft.com/azure/storage/blobs/lifecycle-management-overview' }
                        )
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "All storage accounts are appropriately tiered. Good data lifecycle management." }
                        )
                    }
                }
                'Get-AHBOpportunities' {
                    $ahbCount = if ($rows) { @($rows).Count } else { 0 }
                    if ($ahbCount -gt 5) {
                        $guidanceItems = @(
                            @{ Severity = 'Red'; Message = "$ahbCount resources eligible for Azure Hybrid Benefit — up to 40% savings on Windows, 55% on SQL licensing." }
                            @{ Severity = 'Red'; Message = "FinOps Action: AHB is one of the highest-impact, lowest-effort optimizations. Apply to all eligible VMs and SQL resources." }
                            @{ Severity = 'Yellow'; Message = "Requires Software Assurance or qualifying subscription licenses. Check with your licensing team."; Docs = 'https://learn.microsoft.com/azure/virtual-machines/windows/hybrid-use-benefit-licensing' }
                        )
                    }
                    elseif ($ahbCount -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "$ahbCount resources can use Azure Hybrid Benefit (up to 40% Windows / 55% SQL savings)." }
                            @{ Severity = 'Yellow'; Message = "Requires Software Assurance. Low effort to apply — high cost impact."; Docs = 'https://learn.microsoft.com/azure/virtual-machines/windows/hybrid-use-benefit-licensing' }
                        )
                    }
                }
                'Get-TagInventory' {
                    $coverage = if ($data.TagCoverage) { $data.TagCoverage } else { 0 }
                    if ($coverage -lt 30) {
                        $guidanceItems = @(
                            @{ Severity = 'Red'; Message = "Tag coverage is critically low at $coverage%." }
                            @{ Severity = 'Red'; Message = "FinOps Foundation: Tags are the #1 requirement for cost allocation. Without tags, you cannot do chargeback, showback, or unit economics." }
                            @{ Severity = 'Red'; Message = "Start with these 5 essential tags: CostCenter, Environment, Owner, Application, Department." }
                            @{ Severity = 'Yellow'; Message = "Use Azure Policy 'Require a tag and its value' to enforce tagging at deployment time." }
                            @{ Severity = 'Yellow'; Message = "Use 'Inherit a tag from the resource group' policy to auto-tag existing resources."; Docs = 'https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging' }
                        )
                    }
                    elseif ($coverage -lt 50) {
                        $guidanceItems = @(
                            @{ Severity = 'Red'; Message = "Tag coverage at $coverage% — below the minimum for reliable cost allocation." }
                            @{ Severity = 'Yellow'; Message = "FinOps requires 80%+ tag coverage for meaningful chargeback. Prioritize tagging high-cost resources first." }
                            @{ Severity = 'Yellow'; Message = "Essential tags: CostCenter, Environment, Owner, Application, Department." }
                            @{ Severity = 'Yellow'; Message = "Deploy tag inheritance policies to propagate subscription/RG tags to child resources."; Docs = 'https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging' }
                        )
                    }
                    elseif ($coverage -lt 80) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "Tag coverage at $coverage% — good progress, but target 80%+ for reliable cost allocation." }
                            @{ Severity = 'Yellow'; Message = "Focus on the highest-cost untagged resources. Use Cost Management views to find them." }
                            @{ Severity = 'Yellow'; Message = "Enable tag inheritance policies to auto-apply subscription/RG tags to new resources." }
                        )
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "Tag coverage at $coverage% — strong tagging discipline." }
                            @{ Severity = 'Green'; Message = "Enable tag-based cost allocation in Cost Management to leverage your tags for chargeback." }
                            @{ Severity = 'Green'; Message = "Consider adding a 'Criticality' tag for incident response prioritization."; Docs = 'https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging' }
                        )
                    }
                }
                'Get-CostByTag' {
                    if ($data.CostByTag -and $data.CostByTag.Count -gt 0) {
                        # Use the MAX untagged cost across any single tag to avoid double-counting
                        # (the same resource appears as "(untagged)" under every tag it lacks)
                        $maxUntaggedCost = 0
                        $maxUntaggedTag = ''
                        foreach ($tag in $data.CostByTag.GetEnumerator()) {
                            foreach ($v in $tag.Value) {
                                if ($v.TagValue -eq '(untagged)' -and [double]$v.Cost -gt $maxUntaggedCost) {
                                    $maxUntaggedCost = [double]$v.Cost
                                    $maxUntaggedTag = $tag.Key
                                }
                            }
                        }
                        if ($maxUntaggedCost -gt 1000) {
                            $guidanceItems = @(
                                @{ Severity = 'Red'; Message = "Untagged spend: $("{0:C0}" -f $maxUntaggedCost) (resources missing '$maxUntaggedTag'). This cost cannot be allocated to any team, project, or budget." }
                                @{ Severity = 'Red'; Message = "FinOps Impact: Untagged spend creates 'shadow IT' — no one owns it, no one optimizes it." }
                                @{ Severity = 'Yellow'; Message = "Use Cost Management tag views to identify the highest-cost untagged resources and tag them first." }
                            )
                        }
                        elseif ($maxUntaggedCost -gt 0) {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "Some untagged spend detected ($("{0:C0}" -f $maxUntaggedCost) missing '$maxUntaggedTag'). Tag remaining resources for full cost traceability." }
                            )
                        }
                        else {
                            $guidanceItems = @(
                                @{ Severity = 'Green'; Message = "All scanned cost is tagged. Cost allocation is fully traceable — enables chargeback and showback." }
                            )
                        }
                    }
                    elseif ($data.NoTagsFound) {
                        $guidanceItems = @(
                            @{ Severity = 'Red'; Message = "No tags exist to analyze cost against. Cost allocation is impossible without tags." }
                            @{ Severity = 'Red'; Message = "FinOps Foundation: Start with CostCenter, Environment, and Owner tags. These 3 enable basic chargeback/showback." }
                            @{ Severity = 'Yellow'; Message = "Run Tag Inventory first, then come back to Cost by Tag to see the financial impact."; Docs = 'https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging' }
                        )
                    }
                }
                'Get-CostTrend' {
                    if ($data.Months -and @($data.Months).Count -ge 2) {
                        $sorted = @($data.Months) | Sort-Object Month -Descending | Select-Object -First 2
                        $current = [double]$sorted[0].Cost
                        $previous = [double]$sorted[1].Cost
                        if ($previous -gt 0) {
                            $change = [math]::Round((($current - $previous) / $previous) * 100, 1)
                            if ($change -gt 20) {
                                $guidanceItems = @(
                                    @{ Severity = 'Red'; Message = "Cost spiked $change% month-over-month. Investigate immediately — this is abnormal growth." }
                                    @{ Severity = 'Red'; Message = "FinOps Action: Check for new deployments, usage spikes, or runaway auto-scale." }
                                    @{ Severity = 'Yellow'; Message = "Set up Cost Management budget alerts at 80%, 90%, 100% to catch spikes early."; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending' }
                                )
                            }
                            elseif ($change -gt 5) {
                                $guidanceItems = @(
                                    @{ Severity = 'Yellow'; Message = "Cost increased $change% MoM. Moderate growth — review new resources deployed this period." }
                                    @{ Severity = 'Yellow'; Message = "FinOps Practice: Establish a monthly cost review cadence to catch trends before they become problems." }
                                )
                            }
                            elseif ($change -lt -5) {
                                $guidanceItems = @(
                                    @{ Severity = 'Green'; Message = "Cost decreased $([math]::Abs($change))% MoM. Optimization efforts are working." }
                                )
                            }
                            else {
                                $guidanceItems = @(
                                    @{ Severity = 'Green'; Message = "Cost trend is stable ($change% change). Good cost discipline and predictable spend." }
                                )
                            }
                        }
                    }
                }
                'Get-ReservationAdvice' {
                    if ($data.AdvisorRecommendations -and @($data.AdvisorRecommendations).Count -gt 0) {
                        $totalSavings = if ($data.EstimatedAnnualSavings) { $data.EstimatedAnnualSavings } else { 0 }
                        if ($totalSavings -gt 10000) {
                            $guidanceItems = @(
                                @{ Severity = 'Red'; Message = "Significant reservation savings available: $("{0:C0}" -f $totalSavings)/year." }
                                @{ Severity = 'Red'; Message = "FinOps Principle: Commitment-based discounts (RIs, Savings Plans) are the single largest cost lever — typically 30-60% savings." }
                                @{ Severity = 'Yellow'; Message = "Start with 1-year terms for flexibility. Use shared scope to maximize utilization across subscriptions." }
                                @{ Severity = 'Yellow'; Message = "Review 14-day usage trends before purchasing to ensure steady-state workloads."; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/reservations/save-compute-costs-reservations' }
                            )
                        }
                        else {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "Reservation savings available: $("{0:C0}" -f $totalSavings)/year. Consider purchasing for steady-state workloads." }
                                @{ Severity = 'Yellow'; Message = "Start with 1-year terms. Use shared scope for best utilization."; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/reservations/save-compute-costs-reservations' }
                            )
                        }
                    }
                    else {
                        if ($data.AccessDenied) {
                            $guidanceItems = @(
                                @{ Severity = 'Red'; Message = "Access denied reading Advisor / reservation recommendations — results are blocked, not empty." }
                                @{ Severity = 'Yellow'; Message = "Required role: $($permissionInfo['Get-ReservationAdvice'].Role) at $($permissionInfo['Get-ReservationAdvice'].Scope) scope. Ask a billing/subscription admin to assign it, then re-scan."; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/reservations/save-compute-costs-reservations' }
                            )
                        }
                        else {
                            $guidanceItems = @(
                                @{ Severity = 'Green'; Message = "No reservation recommendations. Current commitment coverage appears sufficient." }
                            )
                        }
                    }
                }
                'Get-CommitmentUtilization' {
                    if ($data.HasData) {
                        $riUtil = if ($data.RIAvgUtilization) { [double]$data.RIAvgUtilization } else { 100 }
                        $spUtil = if ($data.SPAvgUtilization) { [double]$data.SPAvgUtilization } else { 100 }
                        $lowUtil = ($riUtil -lt 80) -or ($spUtil -lt 80)
                        $medUtil = ($riUtil -lt 95) -or ($spUtil -lt 95)
                        if ($lowUtil) {
                            $guidanceItems = @(
                                @{ Severity = 'Red'; Message = "Commitment utilization below 80%. You may be paying more than on-demand pricing." }
                                @{ Severity = 'Red'; Message = "FinOps Action: Review scope and SKU alignment. Exchange underused RIs for better-fitting ones." }
                                @{ Severity = 'Yellow'; Message = "Target 95%+ utilization. Consider switching unused RIs to Savings Plans for more flexibility."; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/reservations/manage-reserved-vm-instance' }
                            )
                        }
                        elseif ($medUtil) {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "Commitment utilization at RI: $($data.RIAvgUtilization)%, SP: $($data.SPAvgUtilization)%. Room to improve." }
                                @{ Severity = 'Yellow'; Message = "Review scope settings — broadening scope can improve utilization across subscriptions." }
                            )
                        }
                        else {
                            $guidanceItems = @(
                                @{ Severity = 'Green'; Message = "Commitment utilization is excellent (RI: $($data.RIAvgUtilization)%, SP: $($data.SPAvgUtilization)%). Maximum discount realized." }
                            )
                        }
                    }
                    elseif ($data.AccessDenied) {
                        $guidanceItems = @(
                            @{ Severity = 'Red'; Message = "Access denied reading reservation / savings plan utilization — results are blocked, not empty." }
                            @{ Severity = 'Yellow'; Message = "Required role: $($permissionInfo['Get-CommitmentUtilization'].Role) at $($permissionInfo['Get-CommitmentUtilization'].Scope) scope. Ask a billing/subscription admin to assign it, then re-scan."; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/reservations/manage-reserved-vm-instance' }
                        )
                    }
                }
                'Get-SavingsRealized' {
                    if ($data.TotalMonthly -and $data.TotalMonthly -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "Realizing $($data.TotalMonthly.ToString('C0'))/month ($($data.TotalAnnual.ToString('C0'))/year) in commitment discounts." }
                            @{ Severity = 'Green'; Message = "FinOps Maturity: Active savings tracking shows Run-level FinOps maturity. Keep reviewing quarterly." }
                        )
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "No savings from commitments detected. Evaluate RIs and Savings Plans for steady-state workloads." }
                            @{ Severity = 'Yellow'; Message = "FinOps Practice: Commitment discounts are the #1 cost optimization lever (30-60% savings)."; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/reservations/save-compute-costs-reservations' }
                        )
                    }
                }
                'Get-BudgetStatus' {
                    $atRisk = if ($data.AtRiskCount) { $data.AtRiskCount } else { 0 }
                    $over = if ($data.OverBudgetCount) { $data.OverBudgetCount } else { 0 }
                    $bCoverage = if ($data.BudgetCoverage) { $data.BudgetCoverage } else { 0 }
                    if ($over -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Red'; Message = "$over budget(s) exceeded. Immediate review needed — spending is above approved levels." }
                            @{ Severity = 'Red'; Message = "FinOps Action: Identify the cause (new deployments, usage spike, missing commitment) and remediate." }
                            @{ Severity = 'Yellow'; Message = "Add action groups with alerts at 80%, 90%, 100% thresholds to catch overruns earlier next period."; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets' }
                        )
                    }
                    elseif ($atRisk -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "$atRisk budget(s) at risk of overrun. Review forecasted spend vs. remaining budget." }
                            @{ Severity = 'Yellow'; Message = "FinOps Practice: Proactive budget monitoring prevents end-of-period surprises. Consider cost reduction now." }
                        )
                    }
                    elseif ($bCoverage -lt 50) {
                        $guidanceItems = @(
                            @{ Severity = 'Red'; Message = "Budget coverage is only $bCoverage%. Most subscriptions have no budget — spending is untracked." }
                            @{ Severity = 'Red'; Message = "FinOps Foundation: Budgets are the starting point for cost accountability. Without them, there's no alerting, no forecasting, no governance." }
                            @{ Severity = 'Yellow'; Message = "Create a budget for every subscription. Start with last month's actual spend + 10% buffer."; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets' }
                        )
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "Budgets are healthy. All within thresholds with $bCoverage% coverage. Good financial governance." }
                        )
                    }
                }
                'Get-AnomalyAlerts' {
                    $activeAlerts = if ($data.ActiveAlertCount) { $data.ActiveAlertCount } else { 0 }
                    $rules = if ($data.ConfiguredRuleCount) { $data.ConfiguredRuleCount } else { 0 }
                    if ($activeAlerts -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "$activeAlerts active anomaly alerts. Review to determine if they indicate unexpected spend patterns." }
                            @{ Severity = 'Yellow'; Message = "FinOps Practice: Cost anomaly detection is an early warning system. Investigate anomalies promptly." }
                        )
                    }
                    elseif ($rules -eq 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "No anomaly detection rules configured. Set up Cost Management anomaly alerts for early spend warnings." }
                            @{ Severity = 'Yellow'; Message = "Anomaly detection is built into Azure Cost Management at no extra cost."; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/understand/analyze-unexpected-charges' }
                        )
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "Anomaly detection is configured with $rules rule(s) and no active alerts. Monitoring is working." }
                        )
                    }
                }
                'Get-PolicyInventory' {
                    $compliance = if ($data.CompliancePct) { $data.CompliancePct } else { 0 }
                    $nonCompliant = if ($data.TotalNonCompliant) { $data.TotalNonCompliant } else { 0 }
                    $hasComplianceData = if ($null -ne $data.HasComplianceData) { $data.HasComplianceData } else { (($data.TotalCompliant + $data.TotalNonCompliant) -gt 0) }
                    if (-not $hasComplianceData) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "No policy compliance data available. Resource Graph 'policystates' returned no rows - Policy Insights may not have evaluated resources yet, or the identity lacks Policy Insights read access." }
                            @{ Severity = 'Yellow'; Message = "Assignments detected: $($data.AssignmentCount). Compliance percentages require evaluated policy states."; Docs = 'https://learn.microsoft.com/azure/governance/policy/how-to/get-compliance-data' }
                        )
                    }
                    elseif ($nonCompliant -gt 20) {
                        $guidanceItems = @(
                            @{ Severity = 'Red'; Message = "$nonCompliant non-compliant resources ($compliance% compliance). Governance gaps are significant." }
                            @{ Severity = 'Yellow'; Message = "FinOps Governance: Use 'Deny' for critical policies (e.g., required tags). Use 'Audit' first during rollout." }
                            @{ Severity = 'Yellow'; Message = "Create remediation tasks for existing non-compliant resources."; Docs = 'https://learn.microsoft.com/azure/governance/policy/how-to/remediate-resources' }
                        )
                    }
                    elseif ($nonCompliant -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "$nonCompliant non-compliant resources ($compliance% compliance). Review and remediate or create exemptions." }
                        )
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "Full policy compliance ($compliance%). Strong governance posture." }
                        )
                    }
                }
                'Get-PolicyRecommendations' {
                    if ($data.Analysis -and @($data.Analysis).Count -gt 0) {
                        $missing = @($data.Analysis | Where-Object { $_.Status -eq 'Missing' })
                        if ($missing.Count -gt 5) {
                            $guidanceItems = @(
                                @{ Severity = 'Red'; Message = "$($missing.Count) recommended FinOps policies are not assigned. Governance foundation is incomplete." }
                                @{ Severity = 'Yellow'; Message = "Priority policies: tag enforcement, allowed VM SKUs, allowed locations, resource naming." }
                                @{ Severity = 'Yellow'; Message = "FinOps Practice: Policy-driven governance prevents cost waste at deployment time — cheaper than cleanup."; Docs = 'https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies' }
                            )
                        }
                        elseif ($missing.Count -gt 0) {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "$($missing.Count) recommended policies not yet assigned. Review and deploy as needed." }
                                @{ Severity = 'Yellow'; Message = "Start with: tag enforcement, allowed locations, and allowed VM SKUs."; Docs = 'https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies' }
                            )
                        }
                        else {
                            $guidanceItems = @(
                                @{ Severity = 'Green'; Message = "All recommended FinOps policies are assigned. Strong governance foundation." }
                            )
                        }
                    }
                }
                'Get-OptimizationAdvice' {
                    if ($data.Recommendations -and @($data.Recommendations).Count -gt 0) {
                        $highImpact = @($data.Recommendations | Where-Object { $_.Impact -eq 'High' })
                        if ($highImpact.Count -gt 5) {
                            $guidanceItems = @(
                                @{ Severity = 'Red'; Message = "$($highImpact.Count) high-impact Advisor recommendations. Significant savings available." }
                                @{ Severity = 'Red'; Message = "FinOps Action: Start with high-impact items — they offer the largest return for effort." }
                                @{ Severity = 'Yellow'; Message = "Dismiss recommendations you've evaluated to keep the list actionable. Review monthly." }
                            )
                        }
                        else {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "$(@($data.Recommendations).Count) Advisor recommendations ($($highImpact.Count) high-impact). Review and prioritize." }
                                @{ Severity = 'Yellow'; Message = "Dismiss evaluated items to keep the list clean. Azure Advisor refreshes daily." }
                            )
                        }
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "No Advisor cost recommendations. Environment is well optimized." }
                        )
                    }
                }
                'Get-CostData' {
                    if ($data -is [hashtable] -and $data.Count -gt 0) {
                        $totalActual = 0
                        foreach ($sub in $data.GetEnumerator()) { $totalActual += [double]$sub.Value.Actual }
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "Current period spend: $("{0:C0}" -f $totalActual) across $($data.Count) subscription(s)." }
                            @{ Severity = 'Green'; Message = "FinOps Practice: Review actual vs. forecast regularly. Pair this data with Budget Status to track variance." }
                        )
                    }
                }
                'Get-ResourceCosts' {
                    $topCount = if ($data) { @($data).Count } else { 0 }
                    if ($topCount -gt 0) {
                        $topCost = [double](@($data) | Sort-Object { [double]$_.Actual } -Descending | Select-Object -First 1).Actual
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "Top resource costs $("{0:C2}" -f $topCost). Focus optimization on the largest cost drivers." }
                            @{ Severity = 'Yellow'; Message = "FinOps Practice: The top 20% of resources typically drive 80% of spend. Optimize these first." }
                        )
                    }
                }
                'Get-AIWorkloadMetrics' {
                    if (-not $data.HasData) {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "No AI/LLM workloads detected. No AI-specific cost optimization needed right now." }
                        )
                    }
                    elseif ($data.CostPer1KTokens -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "Effective AI rate: $($data.Currency) $($data.CostPer1KTokens) per 1K tokens across $($data.TotalTokens) tokens (MTD). Track this as your core AI unit-economics KPI." }
                            @{ Severity = 'Yellow'; Message = "Compare model deployments above — shift high-volume traffic to cheaper SKUs (e.g., gpt-4o-mini) and reserve premium models for tasks that need them." }
                            @{ Severity = 'Yellow'; Message = "For steady, predictable token volume, evaluate Provisioned Throughput Units (PTUs) — they can beat pay-as-you-go at scale."; Docs = 'https://learn.microsoft.com/azure/ai-services/openai/concepts/provisioned-throughput' }
                        )
                    }
                    elseif ($data.TotalTokens -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "Token usage detected ($($data.TotalTokens) MTD) but cost could not be mapped. Grant Cost Management Reader to compute cost per 1K tokens." }
                        )
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "AI footprint present but no token-metered usage this month. Confirm whether idle AI resources can be deprovisioned to avoid baseline cost." }
                        )
                    }
                }
            }

            # Render guidance with severity colors
            if ($guidanceItems.Count -gt 0) {
                Write-Host ""
                # Determine overall severity for the header
                $hasCritical = $guidanceItems | Where-Object { $_.Severity -eq 'Red' }
                $hasWarning = $guidanceItems | Where-Object { $_.Severity -eq 'Yellow' }
                $headerColor = if ($hasCritical) { 'Red' } elseif ($hasWarning) { 'Yellow' } else { 'Green' }
                $headerIcon = switch ($headerColor) { 'Red' { '[!]' } 'Yellow' { '[~]' } 'Green' { '[+]' } }
                Write-Host "    $headerIcon GUIDANCE" -ForegroundColor $headerColor

                foreach ($item in $guidanceItems) {
                    $color = switch ($item.Severity) { 'Red' { 'Red' } 'Yellow' { 'DarkYellow' } 'Green' { 'Green' } default { 'Gray' } }
                    $icon = switch ($item.Severity) { 'Red' { '!' } 'Yellow' { '~' } 'Green' { '+' } default { '-' } }
                    Write-Host "    $icon $($item.Message)" -ForegroundColor $color
                    if ($item.Docs) {
                        Write-Host "      $($item.Docs)" -ForegroundColor DarkCyan
                    }
                }
            }

            Write-Host ""
        }

        # -- Export option -------------------------------------------------
        if ($ExportPath) {
            $exportDir = $ExportPath
        }
        else {
            $defaultPath = Join-Path (Get-Location) 'FinOpsResults'
            Write-Host "  Export results?  [E] Export  [Enter] Skip" -ForegroundColor DarkGray
            $eKey = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            if ($eKey.Character -eq 'e' -or $eKey.Character -eq 'E') {
                Write-Host ""
                Write-Host "  Path [$defaultPath]: " -ForegroundColor White -NoNewline
                $exportDir = Read-Host
                if (-not $exportDir -or $exportDir.Trim() -eq '') {
                    $exportDir = $defaultPath
                }
            }
            else {
                $exportDir = $null
            }
        }

        if ($exportDir -and $exportDir.Trim() -ne '') {
            if (-not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }

            # -- CSV exports per module --
            foreach ($mod in ($Modules | Where-Object { $_.Selected })) {
                $data = $Results[$mod.Fn]
                if ($data -and @($data).Count -gt 0) {
                    $safeName = $mod.Fn -replace '[^a-zA-Z0-9\-]', ''
                    $csvPath = Join-Path $exportDir "$safeName.csv"
                    $data | Export-Csv -Path $csvPath -NoTypeInformation
                }
            }

            # -- HTML report --
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $subList = if ($Subscriptions) { ($Subscriptions | ForEach-Object { if ($_.Name) { $_.Name } else { $_.Id } }) -join ', ' } else { 'N/A' }
            $htmlSb = [System.Text.StringBuilder]::new()
            [void]$htmlSb.Append(@"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>FinOps Multitool Report — $timestamp</title>
<style>
body { font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; background: #0d1117; color: #c9d1d9; margin: 0; padding: 20px 40px; }
h1 { color: #58a6ff; border-bottom: 2px solid #30363d; padding-bottom: 12px; font-size: 24px; }
h2 { color: #58a6ff; margin-top: 32px; border-bottom: 1px solid #21262d; padding-bottom: 8px; }
.meta { color: #8b949e; font-size: 13px; margin-bottom: 24px; }
.summary-grid { display: flex; flex-wrap: wrap; gap: 12px; margin-bottom: 24px; }
.summary-card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 12px 18px; min-width: 180px; }
.summary-card .label { color: #8b949e; font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; }
.summary-card .value { font-size: 22px; font-weight: 600; color: #c9d1d9; }
table { border-collapse: collapse; width: 100%; margin: 12px 0 24px 0; font-size: 13px; }
th { background: #161b22; color: #58a6ff; text-align: left; padding: 8px 12px; border-bottom: 2px solid #30363d; font-weight: 600; }
td { padding: 6px 12px; border-bottom: 1px solid #21262d; }
tr:hover { background: #161b22; }
.severity-red { color: #f85149; font-weight: 600; }
.severity-yellow { color: #d29922; }
.severity-green { color: #3fb950; }
.guidance { background: #161b22; border-left: 3px solid #30363d; padding: 10px 16px; margin: 8px 0 16px 0; border-radius: 0 6px 6px 0; font-size: 13px; }
.guidance.red { border-left-color: #f85149; }
.guidance.yellow { border-left-color: #d29922; }
.guidance.green { border-left-color: #3fb950; }
.guidance a { color: #58a6ff; text-decoration: none; }
.guidance a:hover { text-decoration: underline; }
.no-data { color: #8b949e; font-style: italic; padding: 8px 0; }
.money { color: #3fb950; font-weight: 500; }
.tag-error { background: #1c1210; border: 1px solid #f8514950; border-radius: 6px; padding: 10px 16px; margin: 8px 0; }
.permission-hint { color: #d29922; font-size: 12px; }
@media print { body { background: #fff; color: #1a1a1a; } h1, h2, th { color: #0366d6; } td, th { border-color: #ddd; } .summary-card { border-color: #ddd; } }
</style>
</head>
<body>
<h1>FinOps Multitool Report</h1>
<div class="meta">Generated: $timestamp &nbsp;|&nbsp; Subscriptions: $([System.Net.WebUtility]::HtmlEncode($subList))</div>
"@)

            # Summary cards
            $errorCount = ($Modules | Where-Object { $_.Selected } | Where-Object { $Results.ContainsKey("_error_$($_.Fn)") }).Count
            [void]$htmlSb.Append('<div class="summary-grid">')
            [void]$htmlSb.Append("<div class=`"summary-card`"><div class=`"label`">Total Findings</div><div class=`"value`">$totalFindings</div></div>")
            [void]$htmlSb.Append("<div class=`"summary-card`"><div class=`"label`">Scans Run</div><div class=`"value`">$(($Modules | Where-Object { $_.Selected }).Count)</div></div>")
            if ($errorCount -gt 0) {
                [void]$htmlSb.Append("<div class=`"summary-card`"><div class=`"label`">Errors</div><div class=`"value severity-red`">$errorCount</div></div>")
            }
            [void]$htmlSb.Append('</div>')

            # Per-module sections
            foreach ($mod in ($Modules | Where-Object { $_.Selected })) {
                $fn = $mod.Fn
                $data = $Results[$fn]
                $eName = [System.Net.WebUtility]::HtmlEncode($mod.Name)
                [void]$htmlSb.Append("<h2>$eName</h2>")

                $errorKey = "_error_$fn"
                if ($Results.ContainsKey($errorKey)) {
                    $eMsg = [System.Net.WebUtility]::HtmlEncode($Results[$errorKey])
                    [void]$htmlSb.Append("<div class=`"tag-error`"><strong>Error:</strong> $eMsg")
                    if ($permissionInfo.ContainsKey($fn)) {
                        $pi = $permissionInfo[$fn]
                        [void]$htmlSb.Append("<br/><span class=`"permission-hint`">Required: $([System.Net.WebUtility]::HtmlEncode($pi.Role)) at $([System.Net.WebUtility]::HtmlEncode($pi.Scope)) scope ($([System.Net.WebUtility]::HtmlEncode($pi.API)))</span>")
                    }
                    [void]$htmlSb.Append('</div>')
                    continue
                }

                if (-not $data -or @($data).Count -eq 0) {
                    $noDataMsg = 'No data returned.'
                    if ($permissionInfo.ContainsKey($fn)) {
                        $noDataMsg += " $($permissionInfo[$fn].Reason)"
                    }
                    [void]$htmlSb.Append("<div class=`"no-data`">$([System.Net.WebUtility]::HtmlEncode($noDataMsg))</div>")
                    continue
                }

                # Render module-specific summaries + table
                $htmlRows = $null
                $htmlCols = $null
                switch ($fn) {
                    'Get-OrphanedResources' {
                        $htmlRows = $data.Orphans
                        $htmlCols = @('Category', 'ResourceName', 'ResourceGroup', 'Detail')
                    }
                    'Get-IdleVMs' {
                        [void]$htmlSb.Append("<p>Scanned $($data.ScannedVMs) running VMs</p>")
                        $htmlRows = $data.IdleVMs
                        $htmlCols = @('VMName', 'ResourceGroup', 'VMSize', 'AvgCPU14d', 'Classification')
                    }
                    'Get-StorageTierAdvice' {
                        [void]$htmlSb.Append("<p>$($data.TotalHotAccounts) Hot-tier accounts scanned</p>")
                        $htmlRows = $data.Recommendations
                        $htmlCols = @('StorageAccount', 'ResourceGroup', 'CurrentTier', 'CapacityGB', 'Recommendation')
                    }
                    'Get-AHBOpportunities' {
                        $ahbRows = @()
                        if ($data.WindowsVMs) { $ahbRows += @($data.WindowsVMs) | ForEach-Object { [PSCustomObject]@{ Type = 'Windows VM'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.vmSize; License = $_.currentLicense } } }
                        if ($data.SQLVMs) { $ahbRows += @($data.SQLVMs) | ForEach-Object { [PSCustomObject]@{ Type = 'SQL VM'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.sqlEdition; License = $_.currentLicense } } }
                        if ($data.SQLDatabases) { $ahbRows += @($data.SQLDatabases) | ForEach-Object { [PSCustomObject]@{ Type = 'SQL DB'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.sku; License = $_.currentLicense } } }
                        $htmlRows = $ahbRows
                        $htmlCols = @('Type', 'Name', 'ResourceGroup', 'Size', 'License')
                    }
                    'Get-TagInventory' {
                        [void]$htmlSb.Append("<p>Coverage: $($data.TagCoverage)% &nbsp;|&nbsp; $($data.TaggedCount) tagged / $($data.UntaggedCount) untagged &nbsp;|&nbsp; $($data.TagCount) unique tags</p>")
                        if ($data.TagNames) {
                            $htmlRows = $data.TagNames.GetEnumerator() | Sort-Object { $_.Value.TotalResources } -Descending | Select-Object -First 15 | ForEach-Object {
                                [PSCustomObject]@{ Tag = $_.Key; Resources = $_.Value.TotalResources; UniqueValues = @($_.Value.Values).Count }
                            }
                            $htmlCols = @('Tag', 'Resources', 'UniqueValues')
                        }
                    }
                    'Get-CostData' {
                        if ($data -is [hashtable]) {
                            $htmlRows = $data.GetEnumerator() | ForEach-Object {
                                $sl = if ($subNameLookup.ContainsKey($_.Key)) { $subNameLookup[$_.Key] } else { $_.Key }
                                [PSCustomObject]@{ Subscription = $sl; Actual = '{0:C0}' -f [double]$_.Value.Actual; Forecast = '{0:C0}' -f [double]$_.Value.Forecast; Currency = $_.Value.Currency }
                            }
                            $htmlCols = @('Subscription', 'Actual', 'Forecast', 'Currency')
                        }
                    }
                    'Get-ResourceCosts' {
                        $htmlRows = @($data) | Sort-Object { $_.Actual } -Descending | Select-Object -First 50 | ForEach-Object {
                            [PSCustomObject]@{ ResourceGroup = $_.ResourceGroup; ResourceType = ($_.ResourceType -split '/')[-1]; Cost = '{0:C2}' -f [double]$_.Actual }
                        }
                        $htmlCols = @('ResourceGroup', 'ResourceType', 'Cost')
                    }
                    'Get-CostByTag' {
                        if ($data.CostByTag) {
                            $htmlRows = foreach ($tag in $data.CostByTag.GetEnumerator()) {
                                foreach ($v in $tag.Value) {
                                    [PSCustomObject]@{ Tag = $tag.Key; Value = $v.TagValue; Cost = '{0:C0}' -f [double]$v.Cost }
                                }
                            }
                            $htmlCols = @('Tag', 'Value', 'Cost')
                        }
                    }
                    'Get-CostTrend' {
                        if ($data.Months) {
                            $htmlRows = $data.Months | ForEach-Object { [PSCustomObject]@{ Month = $_.Month; Cost = '{0:C0}' -f [double]$_.Cost; Currency = $_.Currency } }
                            $htmlCols = @('Month', 'Cost', 'Currency')
                        }
                    }
                    'Get-ReservationAdvice' {
                        if ($data.EstimatedAnnualSavings) { [void]$htmlSb.Append("<p>Est. annual savings: <span class=`"money`">`$$($data.EstimatedAnnualSavings.ToString('N0'))</span></p>") }
                        $htmlRows = $data.AdvisorRecommendations | ForEach-Object {
                            [PSCustomObject]@{ Resource = ($_.ResourceName -split '/')[-1]; Type = ($_.ResourceType -split '/')[-1]; Term = $_.Term; Savings = '{0:C0}' -f [double]$_.AnnualSavings; Impact = $_.Impact }
                        }
                        $htmlCols = @('Resource', 'Type', 'Term', 'Savings', 'Impact')
                    }
                    'Get-CommitmentUtilization' {
                        if ($data.HasData) {
                            [void]$htmlSb.Append("<p>RIs: $($data.RICount) (avg $($data.RIAvgUtilization)%) &nbsp;|&nbsp; Savings Plans: $($data.SPCount) (avg $($data.SPAvgUtilization)%)</p>")
                            $htmlRows = $data.UnderutilizedRIs | ForEach-Object { [PSCustomObject]@{ SKU = $_.SkuName; Kind = $_.Kind; AvgUtil = "$($_.AvgUtilization)%"; MinUtil = "$($_.MinUtilization)%" } }
                            $htmlCols = @('SKU', 'Kind', 'AvgUtil', 'MinUtil')
                        }
                    }
                    'Get-SavingsRealized' {
                        [void]$htmlSb.Append("<p>RI: <span class=`"money`">$($data.RISavingsMonthly.ToString('C0'))</span> &nbsp;|&nbsp; SP: <span class=`"money`">$($data.SPSavingsMonthly.ToString('C0'))</span> &nbsp;|&nbsp; AHB: <span class=`"money`">$($data.AHBSavingsMonthly.ToString('C0'))</span> &nbsp;|&nbsp; Total: <span class=`"money`">$($data.TotalMonthly.ToString('C0'))/mo</span></p>")
                    }
                    'Get-BudgetStatus' {
                        [void]$htmlSb.Append("<p>Budgets: $($data.TotalBudgets) &nbsp;|&nbsp; At risk: $($data.AtRiskCount) &nbsp;|&nbsp; Over budget: $($data.OverBudgetCount) &nbsp;|&nbsp; Coverage: $($data.BudgetCoverage)%</p>")
                        $htmlRows = $data.Budgets | ForEach-Object {
                            $riskClass = switch ($_.Risk) { 'Over Budget' { 'severity-red' } 'Forecast Over' { 'severity-yellow' } 'At Risk' { 'severity-yellow' } 'Watch' { 'severity-yellow' } default { 'severity-green' } }
                            [PSCustomObject]@{ Budget = $_.BudgetName; Amount = '{0:C0}' -f [double]$_.Amount; Spent = '{0:C0}' -f [double]$_.ActualSpend; PctUsed = "$($_.PctUsed)%"; Risk = $_.Risk; _riskClass = $riskClass }
                        }
                        $htmlCols = @('Budget', 'Amount', 'Spent', 'PctUsed', 'Risk')
                    }
                    'Get-AnomalyAlerts' {
                        [void]$htmlSb.Append("<p>Total: $($data.TotalAlerts) &nbsp;|&nbsp; Anomaly: $($data.AnomalyAlertCount) &nbsp;|&nbsp; Active: $($data.ActiveAlertCount)</p>")
                        $htmlRows = $data.TriggeredAlerts | Select-Object -First 10 | ForEach-Object {
                            [PSCustomObject]@{ Alert = $_.AlertName; Type = $_.AlertType; Status = $_.Status; Subscription = $_.Subscription }
                        }
                        $htmlCols = @('Alert', 'Type', 'Status', 'Subscription')
                    }
                    'Get-OptimizationAdvice' {
                        if ($data.EstimatedAnnualSavings) { [void]$htmlSb.Append("<p>Est. annual savings: <span class=`"money`">`$$($data.EstimatedAnnualSavings)</span> &nbsp;|&nbsp; $($data.TotalCount) recommendations</p>") }
                        $htmlRows = $data.Recommendations | Sort-Object { if ($_.AnnualSavings) { [double]$_.AnnualSavings } else { 0 } } -Descending | Select-Object -First 25 | ForEach-Object {
                            [PSCustomObject]@{ Category = $_.Category; Impact = $_.Impact; Resource = $_.ResourceName; Problem = ($_.Problem -replace '(.{80}).+', '$1...'); Savings = if ($_.AnnualSavings) { '{0:C0}/yr' -f [double]$_.AnnualSavings } else { '-' } }
                        }
                        $htmlCols = @('Category', 'Impact', 'Resource', 'Problem', 'Savings')
                    }
                    'Get-TagRecommendations' {
                        $htmlRows = $data.Analysis | ForEach-Object { [PSCustomObject]@{ Tag = $_.TagName; Status = $_.Status; Priority = $_.Priority; Pillar = $_.Pillar; Example = $_.Example } }
                        $htmlCols = @('Tag', 'Status', 'Priority', 'Pillar', 'Example')
                    }
                    'Get-PolicyInventory' {
                        $htmlRows = $data.Assignments | ForEach-Object { [PSCustomObject]@{ Name = $_.AssignmentName; Effect = $_.Effect; Enforcement = $_.EnforcementMode; Scope = $_.Scope } }
                        $htmlCols = @('Name', 'Effect', 'Enforcement', 'Scope')
                    }
                    'Get-PolicyRecommendations' {
                        $htmlRows = $data.Analysis | ForEach-Object { [PSCustomObject]@{ Policy = $_.DisplayName; Status = $_.Status; Category = $_.Category; Priority = $_.Priority; Effect = $_.DefaultEffect } }
                        $htmlCols = @('Policy', 'Status', 'Category', 'Priority', 'Effect')
                    }
                    'Get-BillingStructure' {
                        $htmlRows = $data.BillingAccounts | ForEach-Object { [PSCustomObject]@{ Account = $_.DisplayName; Agreement = $_.AgreementType; Type = $_.AccountType; Status = $_.AccountStatus } }
                        $htmlCols = @('Account', 'Agreement', 'Type', 'Status')
                    }
                    'Get-ContractInfo' {
                        $htmlRows = @($data) | ForEach-Object { [PSCustomObject]@{ Account = $_.AccountName; Agreement = $_.AgreementType; Type = $_.FriendlyType; Currency = $_.Currency; Status = $_.AccountStatus } }
                        $htmlCols = @('Account', 'Agreement', 'Type', 'Currency', 'Status')
                    }
                }

                # Render HTML table
                if ($htmlRows -and $htmlCols) {
                    [void]$htmlSb.Append('<table><thead><tr>')
                    foreach ($c in $htmlCols) { [void]$htmlSb.Append("<th>$([System.Net.WebUtility]::HtmlEncode($c))</th>") }
                    [void]$htmlSb.Append('</tr></thead><tbody>')
                    foreach ($r in $htmlRows) {
                        [void]$htmlSb.Append('<tr>')
                        foreach ($c in $htmlCols) {
                            $val = $r.$c
                            $enc = [System.Net.WebUtility]::HtmlEncode([string]$val)
                            # Colorize money values and risk/severity
                            if ($enc -match '^\$') { $enc = "<span class=`"money`">$enc</span>" }
                            if ($c -eq 'Risk' -and $r.PSObject.Properties['_riskClass']) { $enc = "<span class=`"$($r._riskClass)`">$enc</span>" }
                            if ($c -eq 'Impact') {
                                $impClass = switch ($val) { 'High' { 'severity-red' } 'Medium' { 'severity-yellow' } default { 'severity-green' } }
                                $enc = "<span class=`"$impClass`">$enc</span>"
                            }
                            [void]$htmlSb.Append("<td>$enc</td>")
                        }
                        [void]$htmlSb.Append('</tr>')
                    }
                    [void]$htmlSb.Append('</tbody></table>')
                }

                # Render guidance
                # (Re-evaluate guidance items for HTML — reuse the same logic)
            }

            [void]$htmlSb.Append('<div class="meta" style="margin-top:40px;border-top:1px solid #30363d;padding-top:12px;">Generated by FinOps Multitool &mdash; part of the <a href="https://aka.ms/finops/toolkit" style="color:#58a6ff;">FinOps Toolkit</a></div>')
            [void]$htmlSb.Append('</body></html>')

            $htmlPath = Join-Path $exportDir 'FinOpsReport.html'
            $htmlSb.ToString() | Out-File -FilePath $htmlPath -Encoding utf8

            # Summary text file
            $summaryPath = Join-Path $exportDir 'ScanSummary.txt'
            $summaryLines = @(
                "FinOps Multitool Scan Summary"
                "Generated: $timestamp"
                "Subscriptions: $subList"
                "Total findings: $totalFindings"
                ""
            )
            foreach ($mod in ($Modules | Where-Object { $_.Selected })) {
                $count = if ($Results[$mod.Fn]) { @($Results[$mod.Fn]).Count } else { 0 }
                $errorKey = "_error_$($mod.Fn)"
                $status = if ($Results.ContainsKey($errorKey)) { "ERROR: $($Results[$errorKey])" } elseif ($count -eq 0) { "No data" } else { "$count findings" }
                $summaryLines += "$($mod.Name): $status"
            }
            $summaryLines | Out-File -FilePath $summaryPath -Encoding utf8

            Write-Host ""
            Write-Host "  Exported to: $exportDir" -ForegroundColor Green
            $csvCount = (Get-ChildItem $exportDir -Filter '*.csv').Count
            Write-Host "  Files: $csvCount CSVs + FinOpsReport.html + ScanSummary.txt" -ForegroundColor DarkGray
        }

        # Interactive drill-down
        Write-Host ""
        Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  Results are stored in `$FinOpsResults. Examples:" -ForegroundColor DarkGray
        Write-Host '    $FinOpsResults["Get-OrphanedResources"] | Format-Table' -ForegroundColor DarkGray
        Write-Host '    $FinOpsResults["Get-IdleVMs"] | Where-Object Impact -eq "High"' -ForegroundColor DarkGray
        Write-Host ""

        return $Results
    }

    # =====================================================================
    #  MAIN FLOW
    # =====================================================================
    Show-Banner

    # Step 1: Connect & pick subscription
    $subs = Select-Subscription -PreselectedId $SubscriptionId
    if (-not $subs) {
        Write-Host "  Cancelled." -ForegroundColor Yellow
        return
    }

    # Capture tenant ID from current context
    $tenantId = (Get-AzContext).Tenant.Id

    # Step 2: Pick data source
    $dataSource = Select-DataSource -TenantId $tenantId -Subscriptions $subs

    # If "Resource Graph only", disable cost modules
    $costModuleFns = @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag', 'Get-CostTrend',
        'Get-SavingsRealized', 'Get-CommitmentUtilization', 'Get-ReservationAdvice',
        'Get-BudgetStatus', 'Get-AnomalyAlerts', 'Get-BillingStructure', 'Get-ContractInfo')
    if ($dataSource.Source -eq 'GraphOnly') {
        foreach ($mod in $scanModules) {
            if ($mod.Fn -in $costModuleFns) { $mod.Selected = $false }
        }
    }

    # Show active data source
    $sourceLabel = switch ($dataSource.Source) {
        'Hub' { "FinOps Hub ($($dataSource.HubStorage.name))" }
        'API' { 'Cost Management API (real-time)' }
        'GraphOnly' { 'Resource Graph only (no cost data)' }
    }
    $sourceColor = switch ($dataSource.Source) { 'Hub' { 'Green' } 'API' { 'Yellow' } 'GraphOnly' { 'DarkGray' } }
    Write-Host ""
    Write-Host "  Data source: $sourceLabel" -ForegroundColor $sourceColor
    Write-Host ""

    # Step 3: Pick scans
    $finalModules = Select-ScanModules -Modules $scanModules
    if (-not $finalModules) {
        Write-Host "  Cancelled." -ForegroundColor Yellow
        return
    }

    # Auto-enable dependencies
    $selected = $finalModules | Where-Object { $_.Selected }
    $selectedFns = $selected.Fn
    $deps = @{
        'Get-CostByTag'             = @('Get-CostData', 'Get-TagInventory')
        'Get-TagRecommendations'    = @('Get-TagInventory')
        'Get-PolicyRecommendations' = @('Get-PolicyInventory')
        'Get-BudgetStatus'          = @('Get-CostData')
        'Get-BudgetHistory'         = @('Get-BudgetStatus', 'Get-CostTrend')
    }
    foreach ($depEntry in $deps.GetEnumerator()) {
        if ($depEntry.Key -in $selectedFns) {
            foreach ($req in $depEntry.Value) {
                if ($req -notin $selectedFns) {
                    $mod = $finalModules | Where-Object { $_.Fn -eq $req }
                    if ($mod) {
                        $mod.Selected = $true
                        Write-Host "  Auto-enabled: $($mod.Name) (required by $($depEntry.Key -replace 'Get-',''))" -ForegroundColor DarkGray
                    }
                }
            }
        }
    }

    # Step 4: Run
    $results = Invoke-SelectedScans -Modules $finalModules -Subscriptions $subs -TenantId $tenantId -DataSource $dataSource

    # Step 5: Summary + export
    $global:FinOpsResults = Show-ResultsSummary -Results $results -Modules $finalModules -ExportPath $OutputPath -Subscriptions $subs

    Write-Host "  Done. Results available in `$FinOpsResults" -ForegroundColor Green
    Write-Host ""
}

# Auto-invoke when run directly (not dot-sourced or imported as module)
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-FinOpsMultitool @PSBoundParameters
}
