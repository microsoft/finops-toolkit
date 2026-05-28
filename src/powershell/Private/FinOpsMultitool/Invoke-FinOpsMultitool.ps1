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
        @{ Name = 'AHB Opportunities'; Fn = 'Get-AHBOpportunities'; Selected = $true; Category = 'Optimization' }
        # -- Governance (run early — other modules depend on these) --
        @{ Name = 'Tag Inventory'; Fn = 'Get-TagInventory'; Selected = $true; Category = 'Governance' }
        @{ Name = 'Tag Recommendations'; Fn = 'Get-TagRecommendations'; Selected = $false; Category = 'Governance' }
        @{ Name = 'Policy Inventory'; Fn = 'Get-PolicyInventory'; Selected = $false; Category = 'Governance' }
        @{ Name = 'Policy Recommendations'; Fn = 'Get-PolicyRecommendations'; Selected = $false; Category = 'Governance' }
        # -- Cost Analysis (depends on Tag Inventory for Cost by Tag) --
        @{ Name = 'Cost Data'; Fn = 'Get-CostData'; Selected = $false; Category = 'Cost Analysis' }
        @{ Name = 'Resource Costs'; Fn = 'Get-ResourceCosts'; Selected = $false; Category = 'Cost Analysis' }
        @{ Name = 'Cost by Tag'; Fn = 'Get-CostByTag'; Selected = $false; Category = 'Cost Analysis' }
        @{ Name = 'Cost Trend'; Fn = 'Get-CostTrend'; Selected = $false; Category = 'Cost Analysis' }
        # -- Commitments --
        @{ Name = 'Reservation Advice'; Fn = 'Get-ReservationAdvice'; Selected = $false; Category = 'Commitments' }
        @{ Name = 'Commitment Utilization'; Fn = 'Get-CommitmentUtilization'; Selected = $false; Category = 'Commitments' }
        @{ Name = 'Savings Realized'; Fn = 'Get-SavingsRealized'; Selected = $false; Category = 'Commitments' }
        # -- Monitoring --
        @{ Name = 'Budget Status'; Fn = 'Get-BudgetStatus'; Selected = $false; Category = 'Monitoring' }
        @{ Name = 'Anomaly Alerts'; Fn = 'Get-AnomalyAlerts'; Selected = $false; Category = 'Monitoring' }
        # -- Advisor --
        @{ Name = 'Optimization Advice'; Fn = 'Get-OptimizationAdvice'; Selected = $true; Category = 'Advisor' }
        # -- Account --
        @{ Name = 'Billing Structure'; Fn = 'Get-BillingStructure'; Selected = $false; Category = 'Account' }
        @{ Name = 'Contract Info'; Fn = 'Get-ContractInfo'; Selected = $false; Category = 'Account' }
    )

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

        if ($PreselectedId) {
            $sub = Get-AzSubscription -SubscriptionId $PreselectedId -ErrorAction SilentlyContinue
            if ($sub) {
                Write-Host "  Using subscription: $($sub.Name)" -ForegroundColor Green
                return @($sub)
            }
            Write-Host "  Subscription $PreselectedId not found, showing picker..." -ForegroundColor Yellow
        }

        $allSubs = @(Get-AzSubscription -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Enabled' })
        if ($allSubs.Count -eq 0) {
            Write-Error "No enabled subscriptions found."
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
                if ($DataSource.Source -eq 'Hub') {
                    $hubCostData = ConvertTo-CostDataFromHub -HubData $hubRaw
                    $hubResourceCosts = ConvertTo-ResourceCostsFromHub -HubData $hubRaw
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
                    { $_ -eq 'Get-CostByTag' -and -not $hubRaw } {
                        # No Hub data — fall back to API
                        $existingTags = if ($results.ContainsKey('Get-TagInventory') -and $results['Get-TagInventory'].TagNames) {
                            $results['Get-TagInventory'].TagNames
                        }
                        else { @{} }
                        $output = & $fn -TenantId $TenantId -ExistingTags $existingTags -Subscriptions $Subscriptions; break
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
            $count = if ($data) { @($data).Count } else { 0 }
            $totalFindings += $count
            $icon = if ($count -gt 0) { '*' } else { '-' }
            $color = if ($count -gt 0) { 'Yellow' } else { 'DarkGray' }
            Write-Host "  $icon $($mod.Name.PadRight(30)) $count findings" -ForegroundColor $color
        }

        Write-Host ""
        Write-Host "  Total findings: $totalFindings" -ForegroundColor White
        Write-Host ""

        # -- Display results per module ------------------------------------
        foreach ($mod in ($Modules | Where-Object { $_.Selected })) {
            $data = $Results[$mod.Fn]
            if (-not $data -or @($data).Count -eq 0) { continue }

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
                        Write-Host "    Est. annual savings: $($data.EstimatedAnnualSavings.ToString('C0'))" -ForegroundColor Green
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
                    else {
                        Write-Host "    No active reservations or savings plans found." -ForegroundColor DarkGray
                    }
                }
                'Get-SavingsRealized' {
                    Write-Host "    Monthly savings breakdown:" -ForegroundColor White
                    Write-Host "      RI:  $($data.RISavingsMonthly.ToString('C0'))   SP: $($data.SPSavingsMonthly.ToString('C0'))   AHB: $($data.AHBSavingsMonthly.ToString('C0'))" -ForegroundColor Cyan
                    Write-Host "      Total monthly: $($data.TotalMonthly.ToString('C0'))   Annual: $($data.TotalAnnual.ToString('C0'))" -ForegroundColor Green
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
                    # Show per-subscription trend when BySubscription data is available
                    if ($data.BySubscription -and $data.BySubscription.Count -gt 0) {
                        foreach ($subEntry in $data.BySubscription.GetEnumerator()) {
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
                                    else { Write-Host "    $ln" }
                                }
                            }
                        }
                        # Skip default table rendering
                        $rows = $null
                        $cols = $null
                    }
                    else {
                        # Fallback: show aggregate with sub name header
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
                    Write-Host "    Assignments: $($data.AssignmentCount)  |  Compliance: $($data.CompliancePct)%  ($($data.TotalCompliant) compliant, $($data.TotalNonCompliant) non-compliant)" -ForegroundColor White
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
                    Write-Host "    Budgets: $($data.TotalBudgets)  |  At risk: $($data.AtRiskCount)  |  Over budget: $($data.OverBudgetCount)  |  Coverage: $($data.BudgetCoverage)%" -ForegroundColor White
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
                'Get-OptimizationAdvice' {
                    if ($data.EstimatedAnnualSavings) {
                        Write-Host "    Est. annual savings: `$$($data.EstimatedAnnualSavings)  |  $($data.TotalCount) recommendations" -ForegroundColor Green
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
                            Write-Host "    $line"
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
            $guidance = $null
            switch ($mod.Fn) {
                'Get-OrphanedResources' {
                    $orphanCount = if ($data.Orphans) { @($data.Orphans).Count } else { 0 }
                    if ($orphanCount -gt 0) {
                        $categories = @($data.Orphans | ForEach-Object { $_.Category } | Sort-Object -Unique) -join ', '
                        $guidance = @(
                            "Review and delete orphaned resources to eliminate waste ($categories)."
                            "Use Azure Policy 'Audit unattached disks' to prevent future orphans."
                            "Docs: https://learn.microsoft.com/azure/advisor/advisor-cost-recommendations"
                        )
                    }
                    else {
                        $guidance = @("No orphaned resources found — environment is clean.")
                    }
                }
                'Get-IdleVMs' {
                    $idleCount = if ($data.IdleVMs) { @($data.IdleVMs).Count } else { 0 }
                    if ($idleCount -gt 0) {
                        $guidance = @(
                            "Right-size or deallocate idle VMs. Check Azure Advisor for SKU recommendations."
                            "Consider auto-shutdown schedules for dev/test VMs (saves 50-70%)."
                            "Docs: https://learn.microsoft.com/azure/advisor/advisor-cost-recommendations#optimize-virtual-machine-spend"
                        )
                    }
                }
                'Get-StorageTierAdvice' {
                    $recoCount = if ($data.Recommendations) { @($data.Recommendations).Count } else { 0 }
                    if ($recoCount -gt 0) {
                        $guidance = @(
                            "Move infrequently accessed data to Cool or Cold tiers (up to 50-75% savings)."
                            "Enable lifecycle management policies to auto-tier based on last access time."
                            "Docs: https://learn.microsoft.com/azure/storage/blobs/access-tiers-overview"
                        )
                    }
                }
                'Get-AHBOpportunities' {
                    $ahbCount = if ($rows) { @($rows).Count } else { 0 }
                    if ($ahbCount -gt 0) {
                        $guidance = @(
                            "Apply Azure Hybrid Benefit to save up to 40% on Windows and 55% on SQL licensing."
                            "Requires active Software Assurance or qualifying subscription licenses."
                            "Docs: https://learn.microsoft.com/azure/virtual-machines/windows/hybrid-use-benefit-licensing"
                        )
                    }
                }
                'Get-TagInventory' {
                    $coverage = if ($data.TagCoverage) { $data.TagCoverage } else { 0 }
                    if ($coverage -lt 50) {
                        $guidance = @(
                            "Tag coverage is low ($coverage%). Start with these cost allocation tags:"
                            "  CostCenter, Environment, Owner, Application, Department"
                            "Use Azure Policy 'Require a tag and its value' to enforce tagging at deployment."
                            "Docs: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging"
                        )
                    }
                    elseif ($coverage -lt 80) {
                        $guidance = @(
                            "Tag coverage at $coverage% — good progress. Target 80%+ for reliable cost allocation."
                            "Focus on untagged resources with the highest cost first."
                            "Use tag inheritance policies to auto-apply subscription/RG tags to resources."
                        )
                    }
                    else {
                        $guidance = @(
                            "Tag coverage at $coverage% — excellent. Enable tag-based cost allocation in Cost Management."
                            "Consider adding a 'Criticality' tag for workload priority in incident response."
                        )
                    }
                }
                'Get-CostByTag' {
                    if ($data.CostByTag -and $data.CostByTag.Count -gt 0) {
                        # Find the tag with highest untagged cost
                        $untaggedCost = 0
                        foreach ($tag in $data.CostByTag.GetEnumerator()) {
                            foreach ($v in $tag.Value) {
                                if ($v.TagValue -eq '(untagged)') { $untaggedCost += [double]$v.Cost }
                            }
                        }
                        if ($untaggedCost -gt 0) {
                            $guidance = @(
                                "Untagged spend detected ($("{0:C0}" -f $untaggedCost)). This cost cannot be allocated to teams or projects."
                                "Prioritize tagging high-cost untagged resources. Use Cost Management tag views to identify them."
                            )
                        }
                        else {
                            $guidance = @("All scanned cost is tagged — cost allocation is fully traceable.")
                        }
                    }
                    elseif ($data.NoTagsFound) {
                        $guidance = @(
                            "No tags exist to analyze cost against. Tag resources first (see Tag Inventory guidance)."
                            "Start with: CostCenter, Environment, Owner — these enable chargeback/showback."
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
                                $guidance = @(
                                    "Cost increased $change% month-over-month. Investigate new deployments or usage spikes."
                                    "Set up Cost Management alerts to catch unexpected increases early."
                                    "Docs: https://learn.microsoft.com/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending"
                                )
                            }
                            elseif ($change -gt 5) {
                                $guidance = @("Cost increased $change% MoM — moderate growth. Review new resources deployed this period.")
                            }
                            else {
                                $guidance = @("Cost trend is stable ($change% change). Good cost discipline.")
                            }
                        }
                    }
                }
                'Get-ReservationAdvice' {
                    if ($data.AdvisorRecommendations -and @($data.AdvisorRecommendations).Count -gt 0) {
                        $totalSavings = if ($data.EstimatedAnnualSavings) { $data.EstimatedAnnualSavings } else { 0 }
                        $guidance = @(
                            "Reservation purchase opportunities found ($("{0:C0}" -f $totalSavings)/year estimated savings)."
                            "Start with 1-year terms for flexibility. Use shared scope to maximize utilization."
                            "Review 14-day utilization trends before purchasing to ensure steady-state usage."
                            "Docs: https://learn.microsoft.com/azure/cost-management-billing/reservations/save-compute-costs-reservations"
                        )
                    }
                    else {
                        $guidance = @("No reservation recommendations from Advisor. Current commitment coverage may be sufficient.")
                    }
                }
                'Get-CommitmentUtilization' {
                    if ($data.HasData) {
                        $riUtil = if ($data.RIAvgUtilization) { [double]$data.RIAvgUtilization } else { 100 }
                        $spUtil = if ($data.SPAvgUtilization) { [double]$data.SPAvgUtilization } else { 100 }
                        if ($riUtil -lt 80 -or $spUtil -lt 80) {
                            $guidance = @(
                                "Underutilized commitments detected. Review scope and SKU alignment."
                                "Consider exchanging underused RIs or adjusting savings plan scope."
                                "Target 95%+ utilization — below 80% may cost more than on-demand."
                            )
                        }
                        else {
                            $guidance = @("Commitment utilization is healthy (RI: $($data.RIAvgUtilization)%, SP: $($data.SPAvgUtilization)%).")
                        }
                    }
                }
                'Get-BudgetStatus' {
                    $atRisk = if ($data.AtRiskCount) { $data.AtRiskCount } else { 0 }
                    $over = if ($data.OverBudgetCount) { $data.OverBudgetCount } else { 0 }
                    $coverage = if ($data.BudgetCoverage) { $data.BudgetCoverage } else { 0 }
                    if ($over -gt 0) {
                        $guidance = @(
                            "$over budget(s) exceeded. Review overage causes and adjust budget amounts or spending."
                            "Add action groups to trigger alerts at 80%, 90%, 100% thresholds."
                        )
                    }
                    elseif ($atRisk -gt 0) {
                        $guidance = @(
                            "$atRisk budget(s) at risk of overrun. Review forecasted spend vs. remaining budget."
                            "Consider proactive cost reduction before period end."
                        )
                    }
                    elseif ($coverage -lt 50) {
                        $guidance = @(
                            "Budget coverage is $coverage%. Create budgets for each subscription or resource group."
                            "Budgets are the foundation of FinOps — they enable alerts, forecasting, and accountability."
                            "Docs: https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets"
                        )
                    }
                    else {
                        $guidance = @("Budgets are healthy. All within thresholds with $coverage% coverage.")
                    }
                }
                'Get-PolicyInventory' {
                    $compliance = if ($data.CompliancePct) { $data.CompliancePct } else { 0 }
                    $nonCompliant = if ($data.TotalNonCompliant) { $data.TotalNonCompliant } else { 0 }
                    if ($nonCompliant -gt 0) {
                        $guidance = @(
                            "$nonCompliant non-compliant resources found ($compliance% compliance)."
                            "Review non-compliant resources and remediate or create exemptions."
                            "Use 'Deny' effect for critical policies, 'Audit' for visibility during rollout."
                        )
                    }
                }
                'Get-PolicyRecommendations' {
                    if ($data.Analysis -and @($data.Analysis).Count -gt 0) {
                        $missing = @($data.Analysis | Where-Object { $_.Status -eq 'Missing' })
                        if ($missing.Count -gt 0) {
                            $guidance = @(
                                "$($missing.Count) recommended policies are not assigned."
                                "Start with: tag enforcement, allowed locations, and allowed VM SKUs."
                                "Docs: https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies"
                            )
                        }
                    }
                }
                'Get-OptimizationAdvice' {
                    if ($data.Recommendations -and @($data.Recommendations).Count -gt 0) {
                        $highImpact = @($data.Recommendations | Where-Object { $_.Impact -eq 'High' })
                        $guidance = @(
                            "$(@($data.Recommendations).Count) Advisor recommendations ($($highImpact.Count) high-impact)."
                            "Prioritize high-impact items first — they offer the largest return for effort."
                            "Dismiss recommendations you've already evaluated to keep the list actionable."
                        )
                    }
                    else {
                        $guidance = @("No Advisor cost recommendations — well optimized.")
                    }
                }
            }

            # Render guidance
            if ($guidance) {
                Write-Host ""
                Write-Host "    GUIDANCE" -ForegroundColor Yellow
                foreach ($line in $guidance) {
                    $color = if ($line -match '^Docs:') { 'DarkCyan' } else { 'DarkYellow' }
                    Write-Host "    $line" -ForegroundColor $color
                }
            }

            Write-Host ""
        }

        # -- Export option -------------------------------------------------
        if ($ExportPath) {
            $exportDir = $ExportPath
        }
        else {
            Write-Host "  Export results to CSV?  [E] Export  [Enter] Skip" -ForegroundColor DarkGray
            $eKey = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            if ($eKey.Character -eq 'e' -or $eKey.Character -eq 'E') {
                Write-Host ""
                Write-Host "  Path (or Enter for ./FinOpsResults): " -ForegroundColor White -NoNewline
                $exportDir = Read-Host
                if (-not $exportDir -or $exportDir.Trim() -eq '') {
                    $exportDir = Join-Path (Get-Location) 'FinOpsResults'
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

            foreach ($mod in ($Modules | Where-Object { $_.Selected })) {
                $data = $Results[$mod.Fn]
                if ($data -and @($data).Count -gt 0) {
                    $safeName = $mod.Fn -replace '[^a-zA-Z0-9\-]', ''
                    $csvPath = Join-Path $exportDir "$safeName.csv"
                    $data | Export-Csv -Path $csvPath -NoTypeInformation
                }
            }

            # Summary report
            $summaryPath = Join-Path $exportDir 'ScanSummary.txt'
            $summaryLines = @(
                "FinOps Multitool Scan Summary"
                "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                "Total findings: $totalFindings"
                ""
            )
            foreach ($mod in ($Modules | Where-Object { $_.Selected })) {
                $count = if ($Results[$mod.Fn]) { @($Results[$mod.Fn]).Count } else { 0 }
                $summaryLines += "$($mod.Name): $count findings"
            }
            $summaryLines | Out-File -FilePath $summaryPath -Encoding utf8

            Write-Host ""
            Write-Host "  Exported to: $exportDir" -ForegroundColor Green
            Write-Host "  Files: $((Get-ChildItem $exportDir -Filter '*.csv').Count) CSVs + ScanSummary.txt" -ForegroundColor DarkGray
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
