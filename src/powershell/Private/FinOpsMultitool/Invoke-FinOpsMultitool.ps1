# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Private helper named for the collection it processes.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Accepted for signature parity; callers pass these uniformly across the scan family.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'Scan results are published to the caller session by design.')]
param()

###########################################################################
# INVOKE-FINOPSMULTITOOL.PS1
# INTERACTIVE TERMINAL LAUNCHER FOR FINOPS MULTITOOL
###########################################################################
# Purpose: Provides an arrow-key driven TUI for selecting and running
#          FinOps Multitool scan modules without a GUI dependency.
#
# Usage:   Invoke-FinOpsMultitool
#          Invoke-FinOpsMultitool -SubscriptionId '00000000-0000-0000-0000-000000000000'
#          Invoke-FinOpsMultitool -OutputPath './results'
#
# Requirements:
#   - PowerShell 7+
#   - Az PowerShell modules: Az.Accounts, Az.ResourceGraph, Az.Storage
#   - Azure RBAC: Reader + Cost Management Reader on target scope
###########################################################################

function Invoke-FinOpsMultitool {
    # .SYNOPSIS
    # Runs the private FinOps Multitool terminal interface and creates local reports.
    # .DESCRIPTION
    # Uses the existing Azure identity to run read-only analysis within the selected tenant
    # and subscriptions. Use Start-FinOpsMultitool as the supported public entry point.
    # .PARAMETER SubscriptionId
    # Selects a subscription in the current tenant. An unresolved ID stops the scan.
    # .PARAMETER OutputPath
    # Selects the local parent directory for a new private report folder, outside Git repositories.
    # .PARAMETER Scans
    # Selects scan function names, such as Get-CostData. Omit for interactive selection.
    # .PARAMETER DataSource
    # Selects Hub, Export, API, or GraphOnly. An unavailable explicit source does not fall back silently.
    # .PARAMETER NonInteractive
    # Disables prompts. Requires an existing Azure context; this switch does not sign in.
    # .PARAMETER Accessible
    # Uses numbered prompts without clearing the screen or repainting menus. NonInteractive disables all prompts.
    # .EXAMPLE
    # Invoke-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-CostData -DataSource API -NonInteractive
    # Runs the cost-data scan for one selected subscription and saves reports locally.
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'NonInteractive', Justification = 'Read by the nested picker functions, which PSScriptAnalyzer does not trace into.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Accessible', Justification = 'Read by nested console helpers to disable cursor-driven interaction.')]
    param(
        [string]$SubscriptionId,
        [string]$OutputPath,
        [ValidateNotNullOrEmpty()]
        [string[]]$Scans,
        [ValidateSet('Hub', 'Export', 'API', 'GraphOnly')]
        [string]$DataSource,
        [switch]$NonInteractive,
        [switch]$Accessible
    )

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "FinOps Multitool requires PowerShell 7 or later. This session is PowerShell $($PSVersionTable.PSVersion). Open PowerShell 7 with 'pwsh', import the module there, and run the scan again. No scan was started."
    }

    function Write-FinOpsConsole {
        [CmdletBinding()]
        param(
            [Parameter(Position = 0)][AllowNull()][AllowEmptyString()][object]$Object,
            [ConsoleColor]$ForegroundColor,
            [ConsoleColor]$BackgroundColor,
            [switch]$NoNewline
        )
        $parameters = @{} + $PSBoundParameters
        $parameters.Object = [regex]::Replace([string]$Object, '[\p{Cc}\p{Cf}]', {
                param($character)
                '\u{0:X4}' -f [int][char]$character.Value
            })
        Write-Host @parameters
    }

    # -- Load modules (always force-reimport to pick up latest changes) ----
    $multitoolRoot = $PSScriptRoot
    # Re-probe the console every run; the host can differ between invocations.
    $script:FinOpsRichConsole = $null
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
        Write-FinOpsConsole ""
        Write-FinOpsConsole "  MISSING REQUIRED MODULES" -ForegroundColor Red
        Write-FinOpsConsole "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
        foreach ($m in $missing) {
            Write-FinOpsConsole "    $($m.Name)" -ForegroundColor Red -NoNewline
            Write-FinOpsConsole "  — $($m.Reason)" -ForegroundColor DarkGray
        }
        Write-FinOpsConsole ""
        Write-FinOpsConsole "  Install with:" -ForegroundColor White
        $names = ($missing.Name | ForEach-Object { "'$_'" }) -join ', '
        Write-FinOpsConsole "    Install-Module $names -Scope CurrentUser" -ForegroundColor Yellow
        Write-FinOpsConsole ""
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

    # An explicit -Scans list replaces the default selection. Names match either the
    # scan function or its display name, so both the docs and the menu labels work.
    if ($Scans -and $Scans.Count -gt 0) {
        if ($Scans.Count -eq 1 -and $Scans[0] -match '^(?i)all$') {
            foreach ($m in $scanModules) { $m.Selected = $true }
        }
        else {
            foreach ($m in $scanModules) { $m.Selected = $false }
            $unknownScans = @()
            foreach ($name in $Scans) {
                $matched = @($scanModules | Where-Object { $_.Fn -eq $name -or $_.Name -eq $name })
                if ($matched.Count -gt 0) { foreach ($m in $matched) { $m.Selected = $true } }
                else { $unknownScans += $name }
            }
            if ($unknownScans.Count -gt 0) {
                Write-Error "Unknown scan name(s): $($unknownScans -join ', '). Valid names: $(($scanModules | ForEach-Object { $_.Fn }) -join ', ')"
                return
            }
        }
    }

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
        'Get-UnitEconomics'         = @{ Role = 'Cost Management Reader + Reader'; Scope = 'Management Group'; API = 'Cost Management Query API + Azure Resource Graph + Azure Monitor metrics'; Reason = 'Requires amortized cost (Cost Management), capacity counts (Resource Graph), and storage-account used capacity (Monitor UsedCapacity metric) to compute $/vCPU, $/GB RAM and $/GB stored.' }
        'Get-AIWorkloadMetrics'     = @{ Role = 'Cost Management Reader + Reader'; Scope = 'Management Group'; API = 'Azure Resource Graph + Monitor Metrics + Cost Management Query API'; Reason = 'Requires Reader to detect AI resources and read Azure OpenAI token metrics, plus Cost Management Reader to map token usage to spend. Skips the deep scan when no AI workloads are present.' }
        'Get-ReservationAdvice'     = @{ Role = 'Cost Management Reader'; Scope = 'Subscription'; API = 'Consumption Reservation Recommendations API'; Reason = 'Requires Microsoft.Consumption/reservationRecommendations/read to retrieve reservation purchase advice.' }
        'Get-CommitmentUtilization' = @{ Role = 'MCA Billing account reader or Billing profile reader, or EA Enterprise Administrator (read only)'; Scope = 'Billing account or billing profile'; API = 'Consumption Reservation Summaries + Cost Management Benefit Utilization APIs'; Reason = 'Reservation and savings plan utilization is published at billing scope only; a subscription-scoped read returns 404. Without billing access, the scan reports that no billing scope was resolved rather than reporting zero commitments.' }
        'Get-SavingsRealized'       = @{ Role = 'Cost Management Reader + Reader'; Scope = 'Subscription or Management Group'; API = 'Cost Management Query API + Azure Resource Graph'; Reason = 'Requires Microsoft.CostManagement/query/action for commitment spend and Reader access for Azure Hybrid Benefit inventory. Savings amounts use assumed discounts, not measured benefit utilization.' }
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
        if (-not $Accessible) {
            try { Clear-Host } catch { Write-Debug "Clear-Host is unavailable in this host: $_" }
        }

        # Version comes from the toolkit so the TUI and the module cannot drift.
        # Get-VersionNumber is a sibling private function, absent when this script runs standalone.
        if (-not (Get-Command -Name Get-VersionNumber -ErrorAction SilentlyContinue)) {
            # Nested Join-Path, not -AdditionalChildPath: that parameter is PowerShell 7+ only.
            $verFile = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ChildPath 'Get-VersionNumber.ps1'
            if (Test-Path -Path $verFile) { . $verFile }
        }
        $verText = if (Get-Command -Name Get-VersionNumber -ErrorAction SilentlyContinue) { "v$(Get-VersionNumber)" } else { '' }
        # Keeps the banner box interior at a fixed 72 characters for any version length.
        $verPad = ' ' * [math]::Max(1, 32 - $verText.Length)

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
  ║   Azure FinOps Scanner & Optimizer$verPad$verText     ║
  ║                                                                        ║
  ╚════════════════════════════════════════════════════════════════════════╝

"@
        foreach ($line in ($banner -split '\r?\n')) { Write-FinOpsConsole $line -ForegroundColor Cyan }
    }

    # =====================================================================
    #  CONSOLE HELPERS
    # =====================================================================
    # Menu rows must never reach the console width. A row that wraps occupies two
    # physical lines, which desynchronizes the cursor-up math the pickers use to
    # redraw in place and makes the menu smear down the screen.
    function Get-MenuWidth {
        param([int]$Cap)
        $consoleWidth = 0
        try { $consoleWidth = [Console]::WindowWidth } catch { $consoleWidth = 0 }
        if ($consoleWidth -lt 20) { return $Cap }
        return [math]::Min($Cap, $consoleWidth - 1)
    }

    # Hosts without a usable console (remoting, CI, some editor terminals) still
    # expose $Host.UI.RawUI, and there ReadKey blocks forever rather than failing,
    # so probe a real console operation instead of testing for the object.
    function Test-FinOpsRichConsole {
        if ($Accessible) { return $false }
        if ($null -ne $script:FinOpsRichConsole) { return $script:FinOpsRichConsole }
        $rich = $true
        try { $null = [Console]::CursorTop } catch { $rich = $false }
        if ($rich) {
            $redirected = $false
            try { $redirected = [Console]::IsInputRedirected } catch { $redirected = $false }
            if ($redirected) { $rich = $false }
        }
        $script:FinOpsRichConsole = $rich
        if (-not $rich) {
            Write-FinOpsConsole ""
            Write-FinOpsConsole "  This console does not support the arrow-key menus. Using numbered prompts." -ForegroundColor DarkGray
        }
        return $rich
    }

    # Repositioning can still fail after the capability probe passes, for example
    # when the buffer shrinks mid-render, so a failure re-renders lower rather
    # than surfacing a .NET stack trace.
    function Move-FinOpsCursorLine {
        param([int]$LinesUp = 0)
        try {
            $top = [Console]::CursorTop
            if ($LinesUp -gt 0) { $top = [math]::Max(0, $top - $LinesUp) }
            [Console]::SetCursorPosition(0, $top)
        }
        catch {
            Write-Verbose "Cursor repositioning unavailable: $($_.Exception.Message)"
        }
    }

    # Read-Host returns an empty string in a host that cannot prompt, which would
    # spin a validation loop forever, so every caller needs an attempt ceiling.
    function Read-FinOpsAnswer {
        param([string]$Prompt)
        Write-FinOpsConsole $Prompt -ForegroundColor White -NoNewline
        $answer = $null
        try { $answer = Read-Host }
        catch [System.Management.Automation.PipelineStoppedException] { throw }
        catch { $answer = $null }
        if ($null -eq $answer) { return '' }
        return $answer.Trim()
    }

    # =====================================================================
    #  DATA SOURCE PICKER
    # =====================================================================
    function Select-ExportSource {
        param([string]$TenantId, [array]$Subscriptions, [switch]$OfferApiFallback)

        $context = Get-AzContext -ErrorAction Stop
        if (-not $context -or $context.Tenant.Id -ne $TenantId -or -not $Subscriptions.Count -or
            @($Subscriptions | Where-Object { [string]::IsNullOrWhiteSpace($_.Id) -or $_.TenantId -ne $TenantId }).Count -gt 0) {
            throw 'Export discovery requires the verified selected tenant and subscriptions.'
        }
        Write-FinOpsConsole "  Reading export definitions for $($Subscriptions.Count) subscription(s), their management-group ancestors, and linked billing accounts..." -ForegroundColor Cyan
        $exports = @()
        $discoveryIssues = [Collections.Generic.List[string]]::new()
        $environmentName = if ($context.Environment.Name) { $context.Environment.Name } else { 'AzureCloud' }
        $definitionWarnings = @()
        $storageWarnings = @()
        try { $exports = @(Find-CostExport -Subscriptions $Subscriptions -Environment $environmentName -TenantId $TenantId -IncludeManagementGroups -IncludeBillingAccounts -SkipRunHistory -WarningAction SilentlyContinue -WarningVariable definitionWarnings) }
        catch { $discoveryIssues.Add("Export definitions: $($_.Exception.Message)") }
        if ($definitionWarnings.Count) { Write-FinOpsConsole "  Export definition discovery reported $($definitionWarnings.Count) warning(s). Available choices are retained; use -Verbose for details." -ForegroundColor Yellow }
        foreach ($warning in @($definitionWarnings)) { Write-Verbose ([regex]::Replace([string]$warning, '[\p{Cc}\p{Cf}]', ' ')) }
        Write-FinOpsConsole "  Export definitions found: $($exports.Count)." -ForegroundColor DarkGray
        $knownKeys = @{}
        foreach ($export in $exports) {
            if ($export.StorageResourceId -and $export.Container -and $export.Name) { $knownKeys["$($export.StorageResourceId)|$($export.Container)|$(([string]$export.RootFolder).Trim('/'))|$($export.Name)".ToLowerInvariant()] = $true }
        }
        # Runs even when definitions exist and is deduped against them: a cross-tenant
        # scan commonly sees some subscriptions' exports while a central
        # management-group export stays invisible to Cost Management.
        Write-FinOpsConsole '  Scanning storage accounts in the selected subscriptions for exports Cost Management cannot see...' -ForegroundColor Cyan
        $definitionCount = $exports.Count
        $storageSkipped = $false
        try {
            $stores = @(Get-ExportStorageCandidates -Subscriptions $Subscriptions -WarningAction SilentlyContinue -WarningVariable storageWarnings)
            if ($stores.Count -gt 100 -and -not $NonInteractive) {
                Write-FinOpsConsole "  Found $($stores.Count) storage accounts. Azure allows 100 container listings per 5 minutes in each subscription and region, so scanning them all can be slow." -ForegroundColor Yellow
                Write-FinOpsConsole "  Scan all $($stores.Count) storage accounts? " -ForegroundColor White -NoNewline
                Write-FinOpsConsole '(N = skip the storage scan)' -ForegroundColor DarkGray
                $storageSkipped = (Read-FinOpsAnswer '  Select [Y/N]: ') -notmatch '^(?i)(y|yes)$'
            }
            if ($storageSkipped) { $discoveryIssues.Add("Export storage: skipped $($stores.Count) storage accounts by choice, so exports Cost Management can't see weren't checked.") }
            else { $exports += @(Find-CostExportFromStorage -Subscriptions $Subscriptions -StorageAccounts $stores -Environment $environmentName -KnownKeys $knownKeys -WarningAction SilentlyContinue -WarningVariable +storageWarnings) }
        }
        catch { $discoveryIssues.Add("Export storage: $($_.Exception.Message)") }
        if ($storageWarnings.Count) { Write-FinOpsConsole "  Storage discovery reported $($storageWarnings.Count) warning(s). Unreadable locations were skipped, not treated as empty. Available export choices are retained; use -Verbose for details." -ForegroundColor Yellow }
        foreach ($warning in @($storageWarnings)) { Write-Verbose ([regex]::Replace([string]$warning, '[\p{Cc}\p{Cf}]', ' ')) }
        if (-not $storageSkipped) { Write-FinOpsConsole "  Additional exports found directly in storage: $($exports.Count - $definitionCount)." -ForegroundColor DarkGray }
        foreach ($issue in $discoveryIssues) { Write-FinOpsConsole "  $issue" -ForegroundColor Yellow }
        $seen = @{}
        $candidates = @($exports | Where-Object {
                if (-not $_ -or -not $_.StorageResourceId -or -not $_.Container -or -not $_.Name) { return $false }
                $key = "$($_.StorageResourceId)|$($_.Container)|$(([string]$_.RootFolder).Trim('/'))|$($_.Name)".ToLowerInvariant()
                if ($seen.ContainsKey($key)) { return $false }
                $seen[$key] = $true
                return $true
            } | Sort-Object Name, StorageResourceId, Container)
        if (-not $candidates.Count) {
            if ($OfferApiFallback) {
                Write-FinOpsConsole ''
                Write-FinOpsConsole '  No export candidates could be verified for the selected subscriptions.' -ForegroundColor Yellow
                Write-FinOpsConsole '  Use the live Cost Management API instead? ' -ForegroundColor White -NoNewline
                Write-FinOpsConsole '(N = stop without scanning)' -ForegroundColor DarkGray
                if ((Read-FinOpsAnswer '  Select [Y/N]: ') -match '^(?i)(y|yes)$') { return @{ Source = 'API'; HubStorage = $null } }
            }
            throw 'No export candidates could be verified. Some definitions or destinations may be inaccessible; this does not establish that no exports exist. Check access and network connectivity to the intended export destination, then retry with -Verbose for details.'
        }
        Write-FinOpsConsole '  Export data will be filtered to the selected subscriptions. Missing coverage will not be filled with live API costs.' -ForegroundColor DarkGray
        $readable = @($candidates | Where-Object { [string]$_.Format -match '(?i)^csv' -and -not ($_.ScopeKind -ne 'Storage' -and $_.Type -eq 'AmortizedCost') })
        for ($exportIndex = 0; $exportIndex -lt $candidates.Count; $exportIndex++) {
            $candidate = $candidates[$exportIndex]
            $format = if ($candidate.Format) { $candidate.Format } else { 'Unknown format' }
            $scopeLabel = if ($candidate.ScopeLabel) { $candidate.ScopeLabel } elseif ($candidate.SubName) { $candidate.SubName } else { $candidate.ScopeKind }
            $readableLabel = if ($readable -contains $candidate) { '' } else { ' | not readable by this source' }
            Write-FinOpsConsole "  [$($exportIndex + 1)] $($candidate.Name) | $format | $($candidate.Type) | $scopeLabel$readableLabel" -ForegroundColor White
            Write-FinOpsConsole "       $($candidate.StorageResourceId) / $($candidate.Container) / $($candidate.RootFolder)" -ForegroundColor DarkGray
        }
        $selectedExport = $null
        if ($NonInteractive) {
            if ($readable.Count -gt 1) { throw 'Multiple export candidates were found. Run interactively to choose one; exports are not combined automatically.' }
            # With nothing readable, keeping the first candidate lets the format and
            # cost-basis checks below report the specific reason it was rejected.
            $selectedExport = if ($readable.Count -eq 1) { $readable[0] } else { $candidates[0] }
        }
        else {
            for ($attempt = 0; $attempt -lt 3 -and -not $selectedExport; $attempt++) {
                $answer = Read-FinOpsAnswer "  Select export [1-$($candidates.Count)] or C to cancel: "
                if ($answer -eq 'C') { throw 'Export selection cancelled. No export data was read.' }
                $selection = 0
                if ([int]::TryParse($answer, [ref]$selection) -and $selection -ge 1 -and $selection -le $candidates.Count) { $selectedExport = $candidates[$selection - 1] }
                else { Write-FinOpsConsole '  Invalid export selection.' -ForegroundColor Yellow }
            }
        }
        if (-not $selectedExport) { throw 'No export was selected. No export data was read.' }
        if ($selectedExport.Format -notmatch '(?i)^csv') { throw "The selected export uses '$($selectedExport.Format)'. This reader supports CSV and CSV.gz exports; it will not switch to live API costs." }
        if ($selectedExport.ScopeKind -ne 'Storage' -and $selectedExport.Type -eq 'AmortizedCost') { throw 'The selected export contains amortized cost. The current export-backed scans require ActualCost or FOCUS BilledCost; no live fallback was attempted.' }
        Write-FinOpsConsole '  CSV parts are loaded into local memory. For very large exports, use a compatible FinOps Hub Kusto database.' -ForegroundColor Yellow
        return @{ Source = 'Export'; Export = $selectedExport; TenantId = $TenantId; Environment = if ($context.Environment.Name) { $context.Environment.Name } else { 'AzureCloud' }; HubStorage = $null }
    }

    function Select-DataSource {
        param(
            [string]$TenantId,
            [array]$Subscriptions,
            [string]$Preselected
        )

        if ([string]::IsNullOrWhiteSpace($TenantId) -or -not $Subscriptions.Count -or
            @($Subscriptions | Where-Object { [string]::IsNullOrWhiteSpace($_.Id) -or $_.TenantId -ne $TenantId }).Count -gt 0) {
            throw 'Every selected subscription must have a verified ID and belong to the selected tenant. No source discovery was started.'
        }
        $discoveryContext = Get-AzContext -ErrorAction Stop
        if (-not $discoveryContext -or $discoveryContext.Tenant.Id -ne $TenantId) {
            throw 'The current Azure context does not match the selected tenant. No source discovery was started.'
        }

        Write-FinOpsConsole ""
        Write-FinOpsConsole "  DATA SOURCE" -ForegroundColor Cyan
        Write-FinOpsConsole "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-FinOpsConsole ""

        if ($Preselected -in @('API', 'GraphOnly')) {
            Write-FinOpsConsole "  Data source set by parameter: $Preselected" -ForegroundColor DarkGray
            return @{ Source = $Preselected; HubStorage = $null }
        }
        if ($Preselected -eq 'Export') { return Select-ExportSource -TenantId $TenantId -Subscriptions $Subscriptions }
        if (-not [string]::IsNullOrWhiteSpace($env:FINOPS_HUB_KUSTO_URI)) {
            $provider = Resolve-FOHubProvider -Subscriptions @($Subscriptions.Id)
            return @{ Source = 'Hub'; HubStorage = $null; HubProvider = $provider }
        }

        # Try to detect a FinOps Hub in the selected subscriptions
        $hubStorage = $null
        $discoveryErrors = [Collections.Generic.List[string]]::new()
        Write-FinOpsConsole "  Checking for FinOps Hub deployment..." -ForegroundColor DarkGray
        foreach ($sub in $Subscriptions) {
            try {
                $query = "resources | where type == 'microsoft.storage/storageaccounts' and tags['cm-resource-parent'] contains 'Microsoft.Cloud/hubs' | project name, resourceGroup, subscriptionId, location"
                $result = Search-AzGraph -Query $query -Subscription $sub.Id -DefaultProfile $discoveryContext -ErrorAction Stop
                if ($result -and @($result).Count -gt 0) {
                    $hubStorage = $result[0]
                    break
                }
            }
            catch {
                $discoveryErrors.Add("$($sub.Name): $($_.Exception.Message)")
                Write-FinOpsConsole "  Hub discovery failed for $($sub.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        if (-not $hubStorage -and $discoveryErrors.Count -gt 0) {
            if ($Preselected -eq 'Hub') {
                throw "FinOps hub discovery is incomplete: $($discoveryErrors -join '; '). Select API or GraphOnly explicitly, or configure FINOPS_HUB_KUSTO_URI."
            }
            Write-FinOpsConsole '  Hub discovery is incomplete. Continuing with the selected subscriptions only.' -ForegroundColor Yellow
        }

        if ($Preselected) {
            if ($Preselected -eq 'Hub' -and -not $hubStorage) {
                throw 'No FinOps hub was found in the selected subscriptions. Configure FINOPS_HUB_KUSTO_URI or select API for a separate live scan.'
            }
            Write-FinOpsConsole "  Data source set by parameter: $Preselected" -ForegroundColor DarkGray
            return @{ Source = $Preselected; HubStorage = $hubStorage }
        }

        if ($NonInteractive) {
            $autoSource = if ($hubStorage) { 'Hub' } else { 'API' }
            Write-FinOpsConsole "  Non-interactive run. Using $autoSource." -ForegroundColor DarkGray
            return @{ Source = $autoSource; HubStorage = $hubStorage }
        }

        if ($hubStorage) {
            Write-FinOpsConsole "  FinOps Hub detected: " -ForegroundColor Green -NoNewline
            Write-FinOpsConsole "$($hubStorage.name)" -ForegroundColor White -NoNewline
            Write-FinOpsConsole " ($($hubStorage.resourceGroup))" -ForegroundColor DarkGray
            Write-FinOpsConsole ""
            Write-FinOpsConsole "  [1] FinOps Hub" -ForegroundColor Green -NoNewline
            Write-FinOpsConsole "  - Pre-processed data from your Hub's ingestion pipeline" -ForegroundColor DarkGray
            Write-FinOpsConsole "       Faster, consistent, includes normalized/amortized costs" -ForegroundColor DarkGray
            Write-FinOpsConsole ""
            Write-FinOpsConsole '  [2] Cost Management exports (CSV storage)' -ForegroundColor Cyan
            Write-FinOpsConsole '       Discover existing exports without requiring a FinOps Hub' -ForegroundColor DarkGray
            Write-FinOpsConsole ''
            Write-FinOpsConsole "  [3] Cost Management API" -ForegroundColor Yellow -NoNewline
            Write-FinOpsConsole "  - Query Azure Cost Management REST APIs directly" -ForegroundColor DarkGray
            Write-FinOpsConsole "       Real-time, no Hub required, subject to API throttling" -ForegroundColor DarkGray
            Write-FinOpsConsole "       Best for smaller tenants or when no exports exist" -ForegroundColor DarkGray
            Write-FinOpsConsole ""
            Write-FinOpsConsole "  [4] Resource Graph only" -ForegroundColor DarkGray -NoNewline
            Write-FinOpsConsole "  - Skip cost modules, run governance/optimization scans only" -ForegroundColor DarkGray
            Write-FinOpsConsole ""

            $attempts = 0
            while ($true) {
                $choice = Read-FinOpsAnswer '  Select [1/2/3/4]: '
                switch ($choice) {
                    '1' {
                        # The [1] Hub choice uses the scalable Kusto engine when the
                        # hub has an ADX/Fabric cluster (auto-discovered) or
                        # FINOPS_HUB_KUSTO_URI is set (ftklocal). If neither exists,
                        # cost scans fall back to the STORAGE READER, which loads cost
                        # rows into PowerShell.
                        $hubSubIds = @($Subscriptions | ForEach-Object { $_.Id })
                        $prov = $null
                        try { $prov = Resolve-FOHubProvider -Subscriptions $hubSubIds } catch {
                            Write-FinOpsConsole "  FinOps hub provider discovery failed: $($_.Exception.Message) Checking the detected Hub's storage reader instead." -ForegroundColor Yellow
                        }
                        if ($prov -and $prov.Found) {
                            # A scalable Kusto path exists - no warning needed.
                            return @{ Source = 'Hub'; HubStorage = $hubStorage; HubProvider = $prov }
                        }

                        # Size the hub before judging the reader. An unmeasurable hub
                        # is treated as large, so a failed probe never downgrades the
                        # warning.
                        $hubSize = @{ Known = $false; Reachable = $true; IsLarge = $true; Display = 'unknown size'; Issue = $null }
                        if ($hubStorage -and $hubStorage.name) {
                            try { $hubSize = Measure-FinOpsHubSize -StorageAccountName $hubStorage.name } catch {
                                Write-Verbose "Non-fatal: $($_.Exception.Message)"
                            }
                        }

                        if (-not $hubSize.Reachable) {
                            # Storage refused access, so the reader cannot run at all.
                            # Speed is not the problem here; reachability is.
                            Write-FinOpsConsole ""
                            Write-FinOpsConsole "  This FinOps Hub's storage account is not reachable from here." -ForegroundColor Yellow
                            Write-FinOpsConsole "  Hub cost scans need to read the ingestion container, so they will return nothing." -ForegroundColor DarkGray
                            Write-FinOpsConsole "  Common causes: the storage firewall denies this network, public network access is" -ForegroundColor DarkGray
                            Write-FinOpsConsole "  disabled, or the account is reachable only through a private endpoint." -ForegroundColor DarkGray
                            Write-FinOpsConsole ""
                            Write-FinOpsConsole "  Use the live Cost Management API instead? " -ForegroundColor White -NoNewline
                            Write-FinOpsConsole "(N = continue with the Hub anyway)" -ForegroundColor DarkGray
                            $useApi = Read-FinOpsAnswer '  Select [Y/N]: '
                            for ($attempt = 1; $useApi -notmatch '^(?i)(y|yes|n|no)$'; $attempt++) {
                                if ($Accessible -or $attempt -ge 3) { throw 'No valid data source was selected. No scan was started.' }
                                Write-FinOpsConsole '  Enter Y or N.' -ForegroundColor Yellow
                                $useApi = Read-FinOpsAnswer '  Select [Y/N]: '
                            }
                            if ($useApi -match '^(?i)(y|yes)$') {
                                return @{ Source = 'API'; HubStorage = $hubStorage }
                            }
                            return @{ Source = 'Hub'; HubStorage = $hubStorage; HubProviderResolved = $true }
                        }

                        if (-not $hubSize.IsLarge) {
                            # Small enough for the reader. Still name it the small-dataset
                            # path so it is never mistaken for the scalable engine.
                            Write-FinOpsConsole ""
                            Write-FinOpsConsole "  Using the FinOps Hub storage reader (small-dataset path; $($hubSize.Display))." -ForegroundColor DarkGray
                            Write-FinOpsConsole "  Larger hubs should query Kusto: deploy ADX/Fabric, or set FINOPS_HUB_KUSTO_URI (ftklocal)." -ForegroundColor DarkGray
                            return @{ Source = 'Hub'; HubStorage = $hubStorage; HubProviderResolved = $true }
                        }

                        Write-FinOpsConsole ""
                        Write-FinOpsConsole "  Note: no Kusto provider was selected for this FinOps Hub." -ForegroundColor Yellow
                        if ($hubSize.Known) {
                            Write-FinOpsConsole "  Ingestion data measured at $($hubSize.Display)." -ForegroundColor Yellow
                        }
                        Write-FinOpsConsole "  Cost scans will use the storage reader, which loads cost rows into" -ForegroundColor DarkGray
                        Write-FinOpsConsole "  memory. On a large hub (tens of GB) this can be slow or run out of" -ForegroundColor DarkGray
                        Write-FinOpsConsole "  memory before completing." -ForegroundColor DarkGray
                        Write-FinOpsConsole "  For the scalable engine path: deploy ADX/Fabric on the hub, or set" -ForegroundColor DarkGray
                        Write-FinOpsConsole "  FINOPS_HUB_KUSTO_URI to a local ftklocal emulator, then re-run." -ForegroundColor DarkGray
                        Write-FinOpsConsole ""
                        Write-FinOpsConsole "  Switch to the live Cost Management API instead? " -ForegroundColor White -NoNewline
                        Write-FinOpsConsole "(N = continue with the storage reader)" -ForegroundColor DarkGray
                        $useApi = Read-FinOpsAnswer '  Select [Y/N]: '
                        if ($Accessible -and $useApi -notmatch '^(?i)(y|yes|n|no)$') { throw 'No valid data source was selected. No scan was started.' }
                        if ($useApi -match '^(?i)(y|yes)$') {
                            return @{ Source = 'API'; HubStorage = $hubStorage }
                        }
                        return @{ Source = 'Hub'; HubStorage = $hubStorage; HubProviderResolved = $true }
                    }
                    '2' { return Select-ExportSource -TenantId $TenantId -Subscriptions $Subscriptions -OfferApiFallback }
                    '3' { return @{ Source = 'API'; HubStorage = $hubStorage } }
                    '4' { return @{ Source = 'GraphOnly'; HubStorage = $hubStorage } }
                    default {
                        $attempts++
                        # A console that cannot take input returns empty forever, so only give
                        # up there. A real terminal keeps asking until it gets an answer.
                        if ($attempts -ge 3 -and -not (Test-FinOpsRichConsole)) {
                            if ($Accessible) { throw 'No valid data source was selected. No scan was started.' }
                            Write-FinOpsConsole "  No valid selection. Using the FinOps Hub." -ForegroundColor Yellow
                            return @{ Source = 'Hub'; HubStorage = $hubStorage }
                        }
                        Write-FinOpsConsole "  Invalid choice." -ForegroundColor Red
                    }
                }
            }
        }
        else {
            if ($discoveryErrors.Count -gt 0) {
                Write-FinOpsConsole "  A FinOps Hub could not be verified in the selected subscriptions." -ForegroundColor Yellow
            }
            else {
                Write-FinOpsConsole "  No FinOps Hub found in selected subscriptions." -ForegroundColor DarkGray
            }
            Write-FinOpsConsole ""
            Write-FinOpsConsole '  [1] Cost Management exports (CSV storage)' -ForegroundColor Cyan
            Write-FinOpsConsole '       Discover existing exports without requiring a FinOps Hub' -ForegroundColor DarkGray
            Write-FinOpsConsole ''
            Write-FinOpsConsole "  [2] Cost Management API" -ForegroundColor Yellow -NoNewline
            Write-FinOpsConsole "  - Query Azure Cost Management REST APIs directly" -ForegroundColor DarkGray
            Write-FinOpsConsole "       Real-time, subject to API throttling on large tenants" -ForegroundColor DarkGray
            Write-FinOpsConsole "       Best for smaller tenants or when no exports exist" -ForegroundColor DarkGray
            Write-FinOpsConsole ""
            Write-FinOpsConsole "  [3] Resource Graph only" -ForegroundColor DarkGray -NoNewline
            Write-FinOpsConsole "  - Skip cost modules, run governance/optimization scans only" -ForegroundColor DarkGray
            Write-FinOpsConsole ""

            $attempts = 0
            while ($true) {
                $choice = Read-FinOpsAnswer '  Select [1/2/3]: '
                switch ($choice) {
                    '1' { return Select-ExportSource -TenantId $TenantId -Subscriptions $Subscriptions -OfferApiFallback }
                    '2' { return @{ Source = 'API'; HubStorage = $null } }
                    '3' { return @{ Source = 'GraphOnly'; HubStorage = $null } }
                    default {
                        $attempts++
                        if ($attempts -ge 3 -and -not (Test-FinOpsRichConsole)) {
                            if ($Accessible) { throw 'No valid data source was selected. No scan was started.' }
                            Write-FinOpsConsole "  No valid selection. Using the Cost Management API." -ForegroundColor Yellow
                            return @{ Source = 'API'; HubStorage = $null }
                        }
                        Write-FinOpsConsole "  Invalid choice." -ForegroundColor Red
                    }
                }
            }
        }
    }

    # =====================================================================
    #  SUBSCRIPTION PICKER
    # =====================================================================
    function Select-Subscription {
        param([string]$PreselectedId)

        Write-FinOpsConsole "  Checking Azure connection..." -ForegroundColor DarkGray
        $ctx = Get-AzContext -ErrorAction SilentlyContinue
        if (-not $ctx) {
            if ($NonInteractive) { throw 'NonInteractive requires an existing Azure context. Run Connect-AzAccount with the intended identity before starting the scan.' }
            Write-FinOpsConsole "  Not connected. Launching browser login..." -ForegroundColor Yellow
            Connect-AzAccount | Out-Null
            $ctx = Get-AzContext
        }
        if ([string]::IsNullOrWhiteSpace($ctx.Tenant.Id)) {
            throw 'The current tenant could not be verified. Sign in to the intended tenant before starting the scan.'
        }
        Write-FinOpsConsole "  Signed in as: $($ctx.Account.Id)" -ForegroundColor Green
        Write-FinOpsConsole ""

        # -- Explicit scope: resolve before either picker ------------------
        # An explicit subscription must resolve in the current tenant. Never
        # search other tenants or widen the scope when that lookup fails.
        if ($PreselectedId) {
            $sub = Get-AzSubscription -SubscriptionId $PreselectedId -TenantId $ctx.Tenant.Id -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            if (-not $sub) {
                throw "Subscription '$PreselectedId' could not be resolved in the current tenant '$($ctx.Tenant.Id)'. Refusing to widen the scan to all subscriptions. Sign in to the intended tenant before trying again."
            }
            if (@($sub).Count -ne 1 -or $sub.Id -ne $PreselectedId -or $sub.TenantId -ne $ctx.Tenant.Id) {
                throw "Subscription '$PreselectedId' could not be verified in the current tenant. No context change or scan was started."
            }
            $null = Set-AzContext -SubscriptionId $sub.Id -TenantId $ctx.Tenant.Id -Scope Process -ErrorAction Stop -WarningAction SilentlyContinue
            Write-FinOpsConsole "  Using subscription: $($sub.Name)" -ForegroundColor Green
            Write-FinOpsConsole "  Tenant: $($sub.TenantId)" -ForegroundColor Green
            Write-FinOpsConsole ""
            return @($sub)
        }

        # -- Tenant picker ------------------------------------------------
        $tenants = @(Get-AzTenant -ErrorAction SilentlyContinue)
        if ($tenants.Count -gt 1 -and ($NonInteractive -or -not (Test-FinOpsRichConsole))) {
            # The tenant picker is arrow-key only, so stay in the signed-in tenant
            # until the user explicitly signs in to another one.
            $currentTenant = (Get-AzContext -ErrorAction SilentlyContinue).Tenant.Id
            Write-FinOpsConsole "  Tenant: $currentTenant" -ForegroundColor Green
            Write-FinOpsConsole "  $($tenants.Count) tenants available. Sign in to the intended tenant before targeting another one." -ForegroundColor DarkGray
            Write-FinOpsConsole ""
        }
        elseif ($tenants.Count -gt 1) {
            Write-FinOpsConsole "  $($tenants.Count) tenants available:" -ForegroundColor White
            Write-FinOpsConsole ""

            $tCursor = 0
            $currentTenantId = $ctx.Tenant.Id
            # Pre-select current tenant
            for ($t = 0; $t -lt $tenants.Count; $t++) {
                if ($tenants[$t].TenantId -eq $currentTenantId) { $tCursor = $t; break }
            }

            while ($true) {
                $tWidth = Get-MenuWidth 85
                Move-FinOpsCursorLine
                for ($t = 0; $t -lt $tenants.Count; $t++) {
                    $tPrefix = if ($t -eq $tCursor) { '  > ' } else { '    ' }
                    $tColor = if ($t -eq $tCursor) { 'Green' } else { 'Gray' }
                    $tLabel = if ($tenants[$t].Name -and $tenants[$t].Name -ne $tenants[$t].TenantId) {
                        "$($tenants[$t].Name)  ($($tenants[$t].TenantId))"
                    }
                    else { $tenants[$t].TenantId }
                    $current = if ($tenants[$t].TenantId -eq $currentTenantId) { ' (current)' } else { '' }
                    $tLine = "$tPrefix$tLabel$current"
                    if ($tLine.Length -gt $tWidth) { $tLine = $tLine.Substring(0, $tWidth - 3) + '...' }
                    Write-FinOpsConsole $tLine.PadRight($tWidth) -ForegroundColor $tColor
                }
                Write-FinOpsConsole ""
                Write-FinOpsConsole "  ↑↓ Navigate  │  Enter = Select tenant  │  Q = Stay in current" -ForegroundColor DarkGray

                $tKey = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                switch ($tKey.VirtualKeyCode) {
                    38 { if ($tCursor -gt 0) { $tCursor-- } }
                    40 { if ($tCursor -lt $tenants.Count - 1) { $tCursor++ } }
                    13 {
                        $selectedTenant = $tenants[$tCursor]
                        if ($selectedTenant.TenantId -ne $currentTenantId) {
                            Write-FinOpsConsole ""
                            Write-FinOpsConsole "  Switching to tenant: $($selectedTenant.Name)..." -ForegroundColor Yellow
                            Connect-AzAccount -TenantId $selectedTenant.TenantId | Out-Null
                            $ctx = Get-AzContext
                            Write-FinOpsConsole "  Connected to: $($ctx.Tenant.Id)" -ForegroundColor Green
                        }
                        else {
                            Write-FinOpsConsole ""
                            Write-FinOpsConsole "  Staying in current tenant." -ForegroundColor Green
                        }
                        break
                    }
                    81 {
                        Write-FinOpsConsole ""
                        Write-FinOpsConsole "  Staying in current tenant." -ForegroundColor Green
                        break
                    }
                }
                if ($tKey.VirtualKeyCode -eq 13 -or $tKey.VirtualKeyCode -eq 81) { break }

                # Move cursor back up to re-render
                $tLinesToClear = $tenants.Count + 2
                Move-FinOpsCursorLine -LinesUp $tLinesToClear
            }
            Write-FinOpsConsole ""
        }
        elseif ($tenants.Count -eq 1) {
            $tLabel = if ($tenants[0].Name -and $tenants[0].Name -ne $tenants[0].TenantId) { $tenants[0].Name } else { $tenants[0].TenantId }
            Write-FinOpsConsole "  Tenant: $tLabel" -ForegroundColor Green
            Write-FinOpsConsole ""
        }

        # Scope subscription enumeration to the SELECTED tenant only.
        # Get-AzSubscription with no -TenantId returns subscriptions across every
        # tenant the signed-in account can access, which incorrectly mixes tenants
        # together when the user picks one tenant and chooses "All subscriptions".
        $effectiveTenantId = (Get-AzContext -ErrorAction SilentlyContinue).Tenant.Id
        if ([string]::IsNullOrWhiteSpace($effectiveTenantId) -or $effectiveTenantId -ne $ctx.Tenant.Id) {
            throw 'The selected tenant changed or could not be verified. No subscriptions were enumerated.'
        }
        $allSubs = @(Get-AzSubscription -TenantId $effectiveTenantId -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Enabled' })
        if ($allSubs.Count -eq 0) {
            Write-Error "No enabled subscriptions found in tenant $effectiveTenantId."
            return $null
        }
        if ($allSubs.Count -eq 1) {
            Write-FinOpsConsole "  Using only subscription: $($allSubs[0].Name)" -ForegroundColor Green
            return $allSubs
        }

        # Multi-sub picker
        if ($NonInteractive) {
            Write-FinOpsConsole "  Non-interactive run. Scanning all $($allSubs.Count) subscriptions." -ForegroundColor Green
            return $allSubs
        }

        Write-FinOpsConsole "  Found $($allSubs.Count) subscriptions. Select scope:" -ForegroundColor White
        Write-FinOpsConsole ""
        Write-FinOpsConsole "    [A] All subscriptions" -ForegroundColor White
        Write-FinOpsConsole "    [S] Single subscription (pick from list)" -ForegroundColor White
        Write-FinOpsConsole ""
        $choice = Read-FinOpsAnswer '  Choice (A/S): '

        if ($choice -match '^(?i)(a|all)$') {
            Write-FinOpsConsole "  Scanning all $($allSubs.Count) subscriptions" -ForegroundColor Green
            return $allSubs
        }

        if (-not (Test-FinOpsRichConsole)) {
            Write-FinOpsConsole ""
            for ($i = 0; $i -lt $allSubs.Count; $i++) {
                Write-FinOpsConsole ("    [{0}] {1}" -f ($i + 1), $allSubs[$i].Name)
            }
            Write-FinOpsConsole ""
            $pick = Read-FinOpsAnswer '  Subscription number (blank = all): '
            if ($pick -eq '') { return $allSubs }
            $pickIndex = 0
            if ([int]::TryParse($pick, [ref]$pickIndex) -and $pickIndex -ge 1 -and $pickIndex -le $allSubs.Count) {
                Write-FinOpsConsole "  Selected: $($allSubs[$pickIndex - 1].Name)" -ForegroundColor Green
                return @($allSubs[$pickIndex - 1])
            }
            # Cancel rather than fall through to every subscription; a mistyped number
            # should not silently widen the scan to the whole tenant.
            Write-FinOpsConsole "  '$pick' is not one of the listed numbers. Cancelled." -ForegroundColor Yellow
            return $null
        }

        # Arrow-key single subscription picker
        $cursor = 0
        $pageSize = 15
        $offset = 0

        while ($true) {
            # Render list
            $renderStart = $offset
            $renderEnd = [math]::Min($offset + $pageSize, $allSubs.Count) - 1
            $width = Get-MenuWidth 75
            Move-FinOpsCursorLine

            for ($i = $renderStart; $i -le $renderEnd; $i++) {
                $prefix = if ($i -eq $cursor) { '  > ' } else { '    ' }
                $color = if ($i -eq $cursor) { 'Green' } else { 'Gray' }
                $line = "$prefix$($allSubs[$i].Name)"
                if ($line.Length -gt $width) { $line = $line.Substring(0, $width - 3) + '...' }
                Write-FinOpsConsole $line.PadRight($width) -ForegroundColor $color
            }
            Write-FinOpsConsole ""
            Write-FinOpsConsole "  ↑↓ Navigate  │  Enter = Select  │  Q = Cancel" -ForegroundColor DarkGray

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
                    Write-FinOpsConsole ""
                    Write-FinOpsConsole "  Selected: $($allSubs[$cursor].Name)" -ForegroundColor Green
                    return @($allSubs[$cursor])
                }
                81 { return $null } # Q
            }

            # Move cursor back up to re-render
            $linesToClear = ($renderEnd - $renderStart + 1) + 2
            Move-FinOpsCursorLine -LinesUp $linesToClear
        }
    }

    # =====================================================================
    #  SCAN MODULE PICKER (checkbox menu)
    # =====================================================================
    # Numbered alternative to the checkbox menu for hosts that cannot render it.
    function Select-ScanModulesLineMode {
        param([array]$Modules)

        Write-FinOpsConsole ""
        Write-FinOpsConsole "  SELECT SCANS" -ForegroundColor White
        Write-FinOpsConsole ""
        for ($i = 0; $i -lt $Modules.Count; $i++) {
            $mark = if ($Modules[$i].Selected) { 'x' } else { ' ' }
            Write-FinOpsConsole ("    [{0,2}] [{1}] {2}  ({3})" -f ($i + 1), $mark, $Modules[$i].Name, $Modules[$i].Category)
        }
        Write-FinOpsConsole ""
        Write-FinOpsConsole "  Enter numbers separated by commas, 'all', or blank to keep the [x] defaults." -ForegroundColor DarkGray
        $entry = Read-FinOpsAnswer '  Scans: '

        if ($entry -eq '') { return $Modules }
        if ($entry -match '^(?i)all$') {
            foreach ($m in $Modules) { $m.Selected = $true }
            return $Modules
        }

        $picked = @()
        $ignored = @()
        foreach ($piece in ($entry -split ',')) {
            $parsed = 0
            if ([int]::TryParse($piece.Trim(), [ref]$parsed) -and $parsed -ge 1 -and $parsed -le $Modules.Count) {
                $picked += ($parsed - 1)
            }
            elseif ($piece.Trim() -ne '') {
                $ignored += $piece.Trim()
            }
        }
        if ($ignored.Count -gt 0) {
            Write-FinOpsConsole "  Ignored, not a listed number: $($ignored -join ', ')" -ForegroundColor Yellow
        }
        if ($picked.Count -eq 0) {
            Write-FinOpsConsole "  No valid numbers. Keeping the default selection." -ForegroundColor Yellow
            return $Modules
        }
        for ($i = 0; $i -lt $Modules.Count; $i++) { $Modules[$i].Selected = ($i -in $picked) }
        return $Modules
    }

    function Select-ScanModules {
        param([array]$Modules)

        # -Scans, or the defaults, already carry the selection when nothing can prompt.
        if ($NonInteractive) { return $Modules }
        if (-not (Test-FinOpsRichConsole)) { return (Select-ScanModulesLineMode -Modules $Modules) }

        $cursor = 0
        $categories = $Modules | ForEach-Object { $_.Category } | Select-Object -Unique

        while ($true) {
            # Build display lines grouped by category
            $lines = @()
            $lineToIndex = @{}  # map display line -> module index

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
            Write-FinOpsConsole ""
            Write-FinOpsConsole "  SELECT SCANS" -ForegroundColor White
            Write-FinOpsConsole "  ↑↓ Move  │  Space = Toggle  │  A = All  │  N = None  │  Enter = Run  │  Q = Quit" -ForegroundColor DarkGray
            Write-FinOpsConsole ""

            $selectedCount = ($Modules | Where-Object { $_.Selected }).Count

            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lineToIndex[$i] -eq -1) {
                    # Category header or blank
                    if ($lines[$i] -match '──') {
                        Write-FinOpsConsole $lines[$i] -ForegroundColor Yellow
                    }
                    else {
                        Write-FinOpsConsole $lines[$i]
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
                    Write-FinOpsConsole "  $pointer $check $($mod.Name)" -ForegroundColor $color
                }
            }

            Write-FinOpsConsole ""
            Write-FinOpsConsole "  $selectedCount of $($Modules.Count) scans selected" -ForegroundColor DarkGray
            Write-FinOpsConsole ""

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
                        Write-FinOpsConsole "  No scans selected. Press any key..." -ForegroundColor Red
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
            [hashtable]$DataSource,
            [hashtable]$PermissionInfo = @{}
        )

        $selected = @($Modules | Where-Object { $_.Selected })
        $results = @{}
        $total = $selected.Count
        $current = 0

        # Pre-load Hub data if Hub source selected
        $hubCostData = $null
        $hubResourceCosts = $null
        $hubRaw = $null
        $hubTagInventory = $null
        $hubCostByTag = $null
        $hubScanErrors = @{}

        # Scalable Kusto path: when a FinOps Hub Kusto database is reachable
        # (a FINOPS_HUB_KUSTO_URI override for an ftklocal emulator or a pinned
        # cluster, or a discovered ADX/Fabric cluster), push aggregation into
        # the engine and return only summaries - never load raw rows. This is
        # what lets the tool scale to large hub datasets. Falls back to the
        # storage reader below when no cluster is available.
        $kustoProvider = $null
        $subIdsForDisco = @($Subscriptions | ForEach-Object { $_.Id })
        if ($DataSource.Source -eq 'Hub') {
            $kp = $DataSource.HubProvider
            if (-not $kp -and -not $DataSource.HubProviderResolved) {
                try { $kp = Resolve-FOHubProvider -Subscriptions $subIdsForDisco }
                catch {
                    if (-not $DataSource.HubStorage -or -not [string]::IsNullOrWhiteSpace($env:FINOPS_HUB_KUSTO_URI)) { throw }
                    Write-FinOpsConsole "  FinOps hub provider discovery failed: $($_.Exception.Message) Using the selected Hub's storage reader." -ForegroundColor Yellow
                }
            }
            if ($kp -and $kp.Found) {
                $kustoProvider = $kp
                $DataSource.HubProvider = $kp
            }
        }

        if ($DataSource.Source -eq 'Hub') {
            $hubPermission = if ($kustoProvider -and $kustoProvider.Mode -eq 'KustoLocal') {
                @{ Role = 'None (local emulator)'; Scope = 'Local Kusto endpoint'; API = 'Kusto query API'; Reason = 'Check that the local emulator is running and the configured database is available.' }
            }
            elseif ($kustoProvider) {
                @{ Role = 'Database Viewer'; Scope = 'Kusto database'; API = 'Kusto query API'; Reason = 'Confirm database Viewer access or an equivalent role, and that the Kusto endpoint permits your connection.' }
            }
            else {
                @{ Role = 'Storage Blob Data Reader'; Scope = 'Hub storage account or export container'; API = 'Azure Storage data API'; Reason = 'Confirm Storage Blob Data Reader or equivalent data access, and check the storage firewall or private endpoint connection. Subscription Reader alone does not grant storage data access.' }
            }
            foreach ($hubScan in @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag')) {
                $permissionInfo[$hubScan] = $hubPermission
            }
        }

        if ($kustoProvider) {
            Write-FinOpsConsole ""
            Write-FinOpsConsole "  Querying FinOps Hub Kusto database ($($kustoProvider.Mode))..." -ForegroundColor Green

            # Scope every query to the selected subscriptions. Without this the
            # hub returns every subscription it holds, contaminating a report
            # the user asked to be scoped to one.
            $hubErrors = [System.Collections.Generic.List[string]]::new()
            $hubOk = 0

            $cs = Get-FOHubCostSummary -Provider $kustoProvider -SubscriptionIds $subIdsForDisco
            if ($cs -is [System.Collections.IDictionary] -and $cs.Contains('Error') -and $cs.Error) { $hubErrors.Add("cost summary: $($cs.Error)"); $hubScanErrors['Get-CostData'] = $cs.Error }
            else { $hubCostData = $cs; $hubOk++ }

            $rc = Get-FOHubResourceCosts -Provider $kustoProvider -SubscriptionIds $subIdsForDisco
            if ($rc -is [System.Collections.IDictionary] -and $rc.Contains('Error') -and $rc.Error) { $hubErrors.Add("resource costs: $($rc.Error)"); $hubScanErrors['Get-ResourceCosts'] = $rc.Error }
            else { $hubResourceCosts = $rc; $hubOk++ }

            $ct = Get-FOHubCostByTag -Provider $kustoProvider -SubscriptionIds $subIdsForDisco
            if ($ct -is [System.Collections.IDictionary] -and $ct.Contains('Error') -and $ct.Error) { $hubErrors.Add("cost by tag: $($ct.Error)"); $hubScanErrors['Get-CostByTag'] = $ct.Error }
            else { $hubCostByTag = $ct; $hubOk++ }

            if ($hubOk -gt 0) {
                Write-FinOpsConsole "  Hub data summarized in-engine (no rows loaded). Forecast is not included; choose API source for live forecast." -ForegroundColor DarkGray
            }
            foreach ($e in $hubErrors) {
                Write-FinOpsConsole "  Hub query failed - $e" -ForegroundColor Yellow
            }
            if ($hubOk -eq 0) {
                Write-FinOpsConsole '  Hub cost results are unavailable. Select API as the data source to run a separate live scan.' -ForegroundColor Yellow
            }
        }
        elseif ($DataSource.Source -eq 'Hub' -and $DataSource.HubStorage) {
            # Storage reader: small-dataset convenience path (rows loaded into
            # PowerShell). For large hubs, the Kusto path above is preferred.
            $hub = $DataSource.HubStorage
            Write-FinOpsConsole ""
            Write-FinOpsConsole "  Loading cost data from FinOps Hub storage (small-dataset reader)..." -ForegroundColor Green
            Write-FinOpsConsole "  For large hubs, query the Kusto database instead (ADX/Fabric, or set FINOPS_HUB_KUSTO_URI for ftklocal)." -ForegroundColor DarkGray
            try {
                $hubRaw = Read-FinOpsHubData -StorageAccountName $hub.name -ResourceGroupName $hub.resourceGroup -Months 1 -SubscriptionIds $subIdsForDisco
            }
            catch {
                Write-FinOpsConsole "  Hub data load failed: $($_.Exception.Message)" -ForegroundColor Yellow
                if ($DataSource.Source -eq 'Hub') {
                    foreach ($scan in @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag', 'Get-AIWorkloadMetrics')) { $hubScanErrors[$scan] = $_.Exception.Message }
                }
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
                                Write-FinOpsConsole "  Tag coverage corrected via Resource Graph: $argCoverage% ($argTagged/$argTotal)" -ForegroundColor DarkGray
                            }
                        }
                    }
                }
                catch {
                    Write-FinOpsConsole "  Could not verify tag coverage via ARG: $($_.Exception.Message)" -ForegroundColor DarkGray
                }

                try {
                    $hubCostData = ConvertTo-CostDataFromHub -HubData $hubRaw
                }
                catch {
                    $hubScanErrors['Get-CostData'] = $_.Exception.Message
                    $hubCostData = $null
                }
                try {
                    $hubResourceCosts = ConvertTo-ResourceCostsFromHub -HubData $hubRaw
                }
                catch {
                    $hubScanErrors['Get-ResourceCosts'] = $_.Exception.Message
                    $hubResourceCosts = $null
                }
                $currentMonth = (Get-Date).ToUniversalTime()
                $currentMonth = $currentMonth.Date.AddDays(1 - $currentMonth.Day)
                $forecastSubscriptions = @($Subscriptions | Where-Object {
                        $entry = if ($hubCostData) { $hubCostData[$_.Id] } else { $null }
                        $entry -and $null -ne $entry.ActualPeriodStart -and $null -ne $entry.ActualPeriodEnd -and
                        $entry.ActualPeriodStart -ge $currentMonth -and $entry.ActualPeriodEnd -lt $currentMonth.AddMonths(1)
                    })
                if ($hubCostData -and $forecastSubscriptions.Count -gt 0) {
                    try {
                        $liveCost = Get-CostData -TenantId $TenantId -Subscriptions $forecastSubscriptions -RestrictToSelected
                        foreach ($subId in $forecastSubscriptions.Id) {
                            $forecast = $liveCost[$subId]
                            if ($forecast -and $forecast.ForecastSource -eq 'Forecast' -and $forecast.Currency -eq $hubCostData[$subId].Currency) {
                                $hubCostData[$subId].Forecast = $forecast.Forecast
                                $hubCostData[$subId].ForecastSource = 'Cost Management API (current month)'
                            }
                        }
                    }
                    catch { Write-FinOpsConsole "  Live forecast unavailable; hub actuals remain available. $($_.Exception.Message)" -ForegroundColor Yellow }
                }

                Write-FinOpsConsole "  Hub data loaded: $(@($hubRaw).Count) cost records, $($hubTagInventory.TagCount) tags, $($hubTagInventory.TagCoverage)% coverage" -ForegroundColor Green
            }
            else {
                $hubRaw = $null
                if ($DataSource.Source -eq 'Hub') {
                    foreach ($scan in @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag', 'Get-AIWorkloadMetrics')) {
                        if (-not $hubScanErrors.ContainsKey($scan)) { $hubScanErrors[$scan] = 'No hub data is available; cost coverage is incomplete.' }
                    }
                    Write-FinOpsConsole '  Hub data is unavailable. Select API as the data source to run a separate live scan.' -ForegroundColor Yellow
                }
            }
            if ($DataSource.Source -eq 'Hub') { Write-FinOpsConsole "" }
        }

        $exportData = $null
        $exportIssue = $null
        $exportSubscriptions = @()
        $exportCoverage = $null
        $exportScans = @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag', 'Get-CostTrend')
        if ($DataSource.Source -eq 'Export') {
            $exportContext = Get-AzContext -ErrorAction Stop
            if (-not $DataSource.Export -or $DataSource.TenantId -ne $TenantId -or $exportContext.Tenant.Id -ne $TenantId -or
                -not $Subscriptions.Count -or @($Subscriptions | Where-Object { $_.TenantId -ne $TenantId -or [string]::IsNullOrWhiteSpace($_.Id) }).Count -gt 0) {
                throw 'The selected tenant or subscriptions changed before the export read. No export data was read.'
            }
            foreach ($scan in $exportScans) {
                $permissionInfo[$scan] = @{ Role = 'Storage Blob Data Reader'; Scope = 'Selected export container'; API = 'Azure Storage data API'; Reason = 'Export scans require the selected destination to be readable. Failed reads do not switch to live Cost Management queries.' }
            }
            try {
                $rawExport = Get-CostExportData -Export $DataSource.Export -Environment $DataSource.Environment
                $exportData = Select-CostExportData -ExportData $rawExport -Subscriptions $Subscriptions -SkipCoverageCheck
                if (-not $exportData.Rows.Count) { throw 'No cost rows match the selected subscriptions.' }
                $exportSubscriptions = @($Subscriptions | Where-Object { $_.Id -in $exportData.CoveredSubscriptionIds })
                $missingIds = @($Subscriptions.Id | Where-Object { $_ -notin $exportData.CoveredSubscriptionIds })
                $exportCoverage = [pscustomobject]@{
                    Name = $DataSource.Export.Name; CoverageIncomplete = ($missingIds.Count -gt 0)
                    CoveredSubscriptionIds = @($exportData.CoveredSubscriptionIds); UnverifiedSubscriptionIds = $missingIds
                    TotalSubs = $Subscriptions.Count; ScannedSubs = $exportSubscriptions.Count
                    ActualPeriod = $exportData.ActualPeriod; DataDate = $exportData.DataDate
                    Note = "Export rows cover $($exportSubscriptions.Count) of $($Subscriptions.Count) selected subscriptions. Subscriptions without returned rows are unverified, not zero cost. Export period: $($exportData.ActualPeriod)."
                }
                $results['_source_Export'] = $exportCoverage
                $DataSource.CoverageNote = $exportCoverage.Note
                Write-FinOpsConsole "  Export loaded: $($exportData.RowCount) selected-scope rows; period $($exportData.ActualPeriod)." -ForegroundColor Green
                Write-FinOpsConsole "  $($exportCoverage.Note)" -ForegroundColor $(if ($missingIds.Count) { 'Yellow' } else { 'DarkGray' })
            }
            catch { $exportIssue = "Selected export data is unavailable or incomplete: $($_.Exception.Message)" }
        }

        $srcLabel = switch ($DataSource.Source) {
            'Hub' { if ($kustoProvider) { "FinOps Hub ($($kustoProvider.ClusterUri), $($kustoProvider.Database))" } else { "FinOps Hub ($($DataSource.HubStorage.name))" } }
            'Export' { "Cost Management export ($($DataSource.Export.Name); selected subscriptions only)" }
            'API' { "Cost Management API (real-time)" }
            'GraphOnly' { "Resource Graph only" }
        }
        Write-SectionHeader "RUNNING $total SCANS"
        $srcColor = switch ($DataSource.Source) { 'Hub' { 'Green' } 'Export' { 'Cyan' } 'API' { 'Yellow' } 'GraphOnly' { 'DarkGray' } }
        Write-FinOpsConsole "  $srcLabel" -ForegroundColor $srcColor
        Write-FinOpsConsole ""

        foreach ($mod in $selected) {
            $current++
            $pct = [math]::Round(($current / $total) * 100)
            $bar = ('█' * [math]::Floor($pct / 5)).PadRight(20, '░')

            Write-FinOpsConsole "  [$bar] $pct%  ($current/$total) $($mod.Name)" -ForegroundColor White

            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $fn = $mod.Fn
                $output = $null
                if ($hubScanErrors.ContainsKey($fn)) { throw $hubScanErrors[$fn] }
                if ($DataSource.Source -eq 'Export' -and $fn -in @('Get-AIWorkloadMetrics', 'Get-UnitEconomics', 'Get-SavingsRealized', 'Get-BudgetHistory', 'Get-BudgetStatus', 'Get-CommitmentUtilization', 'Get-ReservationAdvice', 'Get-AnomalyAlerts', 'Get-BillingStructure', 'Get-ContractInfo', 'Get-MaccCommitment', 'Get-VmCostBreakdown', 'Get-SharedCostAllocation', 'Get-UsageProportionalAllocation')) {
                    throw "$($mod.Name) is not supported by the selected CSV export source. Select API or a supported Hub source explicitly for a separate scan; no live cost fallback was attempted."
                }

                # Route parameters based on what each function expects
                # Hub shortcut: return pre-loaded Hub data for cost/tag modules
                switch ($fn) {
                    { $DataSource.Source -eq 'Export' -and $_ -in $exportScans } {
                        if ($exportIssue) { throw $exportIssue }
                        switch ($fn) {
                            'Get-CostData' {
                                $output = ConvertTo-CostDataFromExport -ExportData $exportData -Subscriptions $exportSubscriptions
                                foreach ($entry in $output.Values) { $entry.CoverageIncomplete = $exportCoverage.CoverageIncomplete; $entry.Note = $exportCoverage.Note; $entry.CostBasis = 'ActualCost' }
                            }
                            'Get-ResourceCosts' {
                                $output = @(ConvertTo-ResourceCostsFromExport -ExportData $exportData -Subscriptions $exportSubscriptions)
                                foreach ($row in $output) { $row | Add-Member -NotePropertyName CoverageIncomplete -NotePropertyValue $exportCoverage.CoverageIncomplete; $row | Add-Member -NotePropertyName Note -NotePropertyValue $exportCoverage.Note }
                            }
                            'Get-CostByTag' { $output = ConvertTo-CostByTagFromExport -ExportData $exportData -Subscriptions $exportSubscriptions }
                            'Get-CostTrend' {
                                $output = ConvertTo-CostTrendFromExport -ExportData $exportData -Subscriptions $exportSubscriptions
                                $output | Add-Member -NotePropertyMembers @{ SelectedSubscriptionCount = $Subscriptions.Count; SubscriptionsWithData = $exportSubscriptions.Count; UnverifiedSubscriptionIds = $exportCoverage.UnverifiedSubscriptionIds; NoDataSubscriptionIds = @(); CostBasis = 'ActualCost'; QueryScope = "Selected export: $($DataSource.Export.Name)" }
                            }
                        }
                        if ($fn -in @('Get-CostByTag', 'Get-CostTrend')) {
                            $output | Add-Member -NotePropertyMembers @{ CoverageIncomplete = $exportCoverage.CoverageIncomplete; Note = $exportCoverage.Note; ActualPeriod = $exportData.ActualPeriod; ExportDataDate = $exportData.DataDate; Source = 'Export' }
                        }
                        break
                    }
                    { $_ -eq 'Get-CostData' -and $hubCostData } {
                        $output = $hubCostData; break
                    }
                    { $_ -eq 'Get-ResourceCosts' -and $hubResourceCosts } {
                        $output = $hubResourceCosts; break
                    }
                    { $_ -eq 'Get-TagInventory' -and $hubTagInventory } {
                        $output = $hubTagInventory; break
                    }
                    { $_ -eq 'Get-CostByTag' -and $hubCostByTag } {
                        # Scalable Kusto path: cost-by-tag summarized in-engine.
                        $output = $hubCostByTag; break
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
                        $tagInventory = if ($results.ContainsKey('Get-TagInventory')) { $results['Get-TagInventory'] } else { $hubTagInventory }
                        if ($results.ContainsKey('_error_Get-TagInventory') -or -not $tagInventory -or $tagInventory.CoverageIncomplete) {
                            throw 'Tag recommendations are unavailable because tag inventory is incomplete. No tags are assumed missing.'
                        }
                        $tags = if ($results.ContainsKey('Get-TagInventory') -and $results['Get-TagInventory'].TagNames) {
                            $results['Get-TagInventory'].TagNames
                        }
                        elseif ($hubTagInventory) { $hubTagInventory.TagNames }
                        else { @{} }
                        $output = & $fn -ExistingTags $tags; break
                    }
                    'Get-PolicyRecommendations' {
                        if ($results.ContainsKey('_error_Get-PolicyInventory') -or -not $results.ContainsKey('Get-PolicyInventory') -or
                            $results['Get-PolicyInventory'].CoverageIncomplete) {
                            throw 'Policy recommendations are unavailable because the policy inventory did not complete. No policies are assumed missing.'
                        }
                        # Keep an empty array from becoming null at parameter binding.
                        $assignments = if ($results.ContainsKey('Get-PolicyInventory') -and $results['Get-PolicyInventory'].Assignments) {
                            $results['Get-PolicyInventory'].Assignments
                        }
                        else { , @() }
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
                        if ($results.ContainsKey('_error_Get-BudgetStatus') -or -not $budgetResult) {
                            throw "Budget history is unavailable because the budget inventory failed. $($results['_error_Get-BudgetStatus'])"
                        }
                        $budgetRows = if ($budgetResult -and $budgetResult.Budgets) { @($budgetResult.Budgets) } else { @() }
                        if ($budgetResult.CoverageIncomplete -and $budgetRows.Count -eq 0) {
                            throw "Budget history is unavailable because the budget inventory is incomplete. $($budgetResult.Note)"
                        }
                        if ($budgetRows.Count -gt 0) {
                            # Reuse Cost Trend's already-fetched monthly spend so we don't
                            # re-hit the throttle-prone Cost Management Query API.
                            $trendResult = if ($results.ContainsKey('Get-CostTrend')) { $results['Get-CostTrend'] } else { $null }
                            $output = & $fn -Budgets $budgetRows -MonthsBack 6 -CostTrend $trendResult
                            if ($budgetResult.CoverageIncomplete) {
                                $coverageNote = "Budget history covers only the available budget definitions. $($budgetResult.Note)".TrimEnd()
                                if (-not $output) { throw "Budget history is unavailable because the budget inventory is incomplete. $($budgetResult.Note)" }
                                foreach ($historyRow in @($output)) {
                                    $historyNote = (@($historyRow.Note, $coverageNote) | Where-Object { $_ }) -join ' '
                                    $historyRow | Add-Member -NotePropertyMembers @{ CoverageIncomplete = $true; Note = $historyNote } -Force
                                }
                            }
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
                        if ($results.ContainsKey('_error_Get-TagInventory') -or $results['Get-TagInventory'].CoverageIncomplete) {
                            throw 'Cost by tag is unavailable because the tag inventory is incomplete.'
                        }
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
                        if ($DataSource.Source -eq 'Hub' -and (-not $hubRaw -or @($hubRaw).Count -eq 0)) {
                            throw 'AI metrics are unavailable for the selected Kusto hub source. Select API as the data source for a separate live scan.'
                        }
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
                        # The user picked a subscription set, so management-group
                        # scope queries must be filtered back down to it.
                        if ($cmdInfo -and $cmdInfo.Parameters.ContainsKey('RestrictToSelected')) {
                            $params['RestrictToSelected'] = $true
                        }
                        if ($fn -eq 'Get-OrphanedResources' -and $DataSource.Source -in @('GraphOnly', 'Export')) { $params.SkipCost = $true }
                        if ($fn -eq 'Get-ResourceCosts' -and $results['Get-CostData'] -is [hashtable]) { $params.CostData = $results['Get-CostData'] }
                        $output = & $fn @params
                    }
                }

                $sw.Stop()
                $count = if ($output) { @($output).Count } else { 0 }
                $results[$fn] = $output

                Write-FinOpsConsole "    Completed: $($mod.Name) - $count results ($([math]::Round($sw.Elapsed.TotalSeconds, 1))s)" -ForegroundColor Green
            }
            catch {
                $sw.Stop()
                Write-FinOpsConsole "    FAILED: $($mod.Name)" -ForegroundColor Red
                Write-FinOpsConsole "      $($_.Exception.Message)" -ForegroundColor Red
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
        Write-FinOpsConsole ""
        Write-FinOpsConsole "  $line" -ForegroundColor $Color
        Write-FinOpsConsole "  $Title" -ForegroundColor $Color
        Write-FinOpsConsole "  $line" -ForegroundColor $Color
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
                Write-FinOpsConsole $part -ForegroundColor $MoneyColor -NoNewline
            }
            else {
                Write-FinOpsConsole $part -ForegroundColor $DefaultColor -NoNewline
            }
        }
        Write-FinOpsConsole ""
    }
    function Show-PermissionReadout {
        param(
            [string]$Fn,
            [hashtable]$PermissionInfo,
            [string]$Activity
        )
        $pInfo = if ($PermissionInfo -and $PermissionInfo.ContainsKey($Fn)) { $PermissionInfo[$Fn] } else { $null }
        $what = if ($Activity) { " reading $Activity" } else { '' }
        Write-FinOpsConsole "    [!] ACCESS DENIED$what (the API returned access denied, not empty results)." -ForegroundColor Red
        if ($pInfo) {
            Write-FinOpsConsole "    Required role:  $($pInfo.Role)" -ForegroundColor Yellow
            Write-FinOpsConsole "    Scope:          $($pInfo.Scope)" -ForegroundColor Yellow
            Write-FinOpsConsole "    API:            $($pInfo.API)" -ForegroundColor DarkGray
            Write-FinOpsConsole "    $($pInfo.Reason)" -ForegroundColor DarkGray
            Write-FinOpsConsole "    Ask a billing or subscription admin to assign the matching role, then re-scan." -ForegroundColor DarkGray
        }
    }

    # A cell opening with =, +, -, @, tab, or CR is treated as a formula by
    # spreadsheet apps, and resource names, tags, and policy display names are
    # all controlled by whoever created the resource.
    function Protect-FinOpsExportText {
        param([string]$Text)
        if ($Text -match '^(?:[\s\p{Cf}]*[=+\-@]|[\t\r\n])') { return "'" + $Text }
        return $Text
    }

    # CSV cells must be scalars. Anything else lands as "System.Collections.Hashtable"
    # or "System.Object[]" in the file.
    function ConvertTo-FinOpsExportCell {
        param($Value)

        if ($null -eq $Value) { return '' }
        # Numbers, booleans, and dates carry no formula risk, and prefixing one
        # would stop a negative cost being read as a number.
        if ($Value -is [datetime] -or $Value -is [datetimeoffset]) {
            return $Value.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
        }
        if ($Value -is [ValueType]) {
            return [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture)
        }
        if ($Value -is [string]) { return Protect-FinOpsExportText $Value }
        return Protect-FinOpsExportText (ConvertTo-Json -InputObject $Value -Depth 30 -Compress -ErrorAction Stop)
    }

    # Scan results are wrapper objects whose payload is a nested collection or a
    # hashtable keyed by subscription. Exporting the wrapper directly produces
    # object-type cells, and for the cost contracts it turns subscription IDs
    # into columns. Project each result to flat rows before writing CSV.
    function ConvertTo-FinOpsExportRows {
        param(
            [string]$Fn,
            $Data
        )

        if ($null -eq $Data) { return @() }

        $rows = $null
        $payloadsByScan = @{
            'Get-AHBOpportunities'            = @('WindowsVMs', 'SQLVMs', 'SQLDatabases')
            'Get-AIWorkloadMetrics'           = @('ByModel', 'ByAccount')
            'Get-AnomalyAlerts'               = @('TriggeredAlerts', 'ConfiguredRules')
            'Get-BillingAccount'              = @('Accounts')
            'Get-BillingStructure'            = @('BillingAccounts', 'BillingProfiles', 'InvoiceSections', 'EADepartments', 'CostAllocationRules')
            'Get-BudgetStatus'                = @('Budgets')
            'Get-CarbonMetrics'               = @('MonthlyTrend', 'BySubscription')
            'Get-CommitmentUtilization'       = @('Reservations', 'SavingsPlans')
            'Get-CostByTag'                   = @('CostByTag')
            'Get-CostTrend'                   = @('Months', 'BySubscription')
            'Get-IdleVMs'                     = @('IdleVMs')
            'Get-LegacyResources'             = @('LegacyResources')
            'Get-MaccCommitment'              = @('Commitments')
            'Get-OptimizationAdvice'          = @('Recommendations')
            'Get-OrphanedResources'           = @('Orphans')
            'Get-PolicyInventory'             = @('Assignments', 'ComplianceBySubMap')
            'Get-PolicyRecommendations'       = @('Analysis')
            'Get-ReservationAdvice'           = @('AdvisorRecommendations', 'ReservationRecommendations')
            'Get-SavingsRealized'             = @('Details')
            'Get-SharedCostAllocation'        = @('Allocations', 'RuleTargets')
            'Get-StorageTierAdvice'           = @('Recommendations')
            'Get-TagInventory'                = @('TagNames', 'CaseVariants', 'UntaggedResources')
            'Get-TagRecommendations'          = @('Analysis')
            'Get-UsageProportionalAllocation' = @('Allocations', 'RuleTargets')
            'Get-VmCostBreakdown'             = @('Breakdown')
        }

        $metadata = [ordered]@{}
        $summaryCollections = [ordered]@{}
        if ($payloadsByScan.ContainsKey($Fn)) {
            $payloadNames = $payloadsByScan[$Fn]
            if ($Data -is [System.Collections.IDictionary]) {
                foreach ($field in $Data.GetEnumerator()) {
                    if ($field.Key -notin $payloadNames) { $metadata["Summary.$($field.Key)"] = $field.Value }
                }
            }
            else {
                foreach ($property in $Data.PSObject.Properties) {
                    if ($property.Name -notin $payloadNames) { $metadata["Summary.$($property.Name)"] = $property.Value }
                }
            }
            foreach ($name in @($metadata.Keys)) {
                $value = $metadata[$name]
                if ($null -ne $value -and $value -isnot [string] -and $value -isnot [ValueType]) {
                    $summaryCollections[$name] = $value
                    $metadata.Remove($name)
                }
            }
        }

        # Contracts whose payload is not a plain collection.
        if ($Fn -eq 'Get-CostData' -and $Data -is [System.Collections.IDictionary]) {
            $rows = @($Data.GetEnumerator() | ForEach-Object {
                    $record = [ordered]@{ SubscriptionId = $_.Key }
                    foreach ($field in $_.Value.GetEnumerator()) { $record[$field.Key] = $field.Value }
                    [PSCustomObject]$record
                })
        }
        elseif ($payloadsByScan.ContainsKey($Fn)) {
            $rows = @(
                if ($Fn -eq 'Get-CostByTag' -and $Data.CostByTag) {
                    foreach ($tag in $Data.CostByTag.GetEnumerator()) {
                        foreach ($entry in @($tag.Value)) {
                            $record = [ordered]@{
                                RecordType = 'CostByTag'
                                TagKey     = $tag.Key
                                TagValue   = $entry.TagValue
                                Cost       = $entry.Cost
                                Currency   = $entry.Currency
                            }
                            foreach ($field in $metadata.GetEnumerator()) { $record[$field.Key] = $field.Value }
                            [PSCustomObject]$record
                        }
                    }
                }
                foreach ($collection in @($payloadNames | Where-Object { $_ -ne 'CostByTag' }) + @($summaryCollections.Keys)) {
                    $payload = if ($summaryCollections.Contains($collection)) { $summaryCollections[$collection] } else { $Data.$collection }
                    $entries = if ($payload -is [System.Collections.IDictionary]) {
                        foreach ($group in $payload.GetEnumerator()) {
                            foreach ($entry in @($group.Value | Where-Object { $null -ne $_ })) {
                                $record = [ordered]@{ Key = $group.Key }
                                if ($collection -eq 'BySubscription') { $record = [ordered]@{ SubscriptionId = $group.Key } }
                                elseif ($collection -eq 'TagNames') { $record = [ordered]@{ TagKey = $group.Key } }
                                if ($entry -is [System.Collections.IDictionary]) {
                                    foreach ($field in $entry.GetEnumerator()) { $record[$field.Key] = $field.Value }
                                }
                                elseif ($entry -is [string] -or $entry -is [ValueType]) { $record['Value'] = $entry }
                                else { foreach ($property in $entry.PSObject.Properties) { $record[$property.Name] = $property.Value } }
                                [PSCustomObject]$record
                            }
                        }
                    }
                    else { @($payload | Where-Object { $null -ne $_ }) }
                    foreach ($entry in $entries) {
                        $record = [ordered]@{ RecordType = $collection }
                        if ($entry -is [System.Collections.IDictionary]) {
                            foreach ($field in $entry.GetEnumerator()) { $record[$field.Key] = $field.Value }
                        }
                        elseif ($entry -is [string] -or $entry -is [ValueType]) { $record['Value'] = $entry }
                        else { foreach ($property in $entry.PSObject.Properties) { $record[$property.Name] = $property.Value } }
                        foreach ($field in $metadata.GetEnumerator()) { $record[$field.Key] = $field.Value }
                        [PSCustomObject]$record
                    }
                })
        }
        elseif ($Data -is [System.Collections.IDictionary]) {
            $rows = @($Data.GetEnumerator() | ForEach-Object {
                    [PSCustomObject]@{ Key = $_.Key; Value = $_.Value }
                })
        }
        elseif ($Data -is [System.Collections.IEnumerable] -and $Data -isnot [string]) {
            $rows = @($Data)
        }
        else {
            $rows = @($Data)
        }

        if ($payloadsByScan.ContainsKey($Fn)) {
            $primaryRows = @($rows | Where-Object { $_.RecordType -in $payloadNames })
            if ($primaryRows.Count -eq 0) {
                $record = [ordered]@{
                    RecordType = 'Status'
                    Scan       = $Fn
                    Status     = if ($Data.AccessDenied -or $Data.Error) { 'Error' } else { 'No data' }
                    Error      = if ($Data.Error) { $Data.Error } elseif ($Data.AccessDenied) { $Data.Note } else { $null }
                }
                foreach ($field in $metadata.GetEnumerator()) { $record[$field.Key] = $field.Value }
                $rows = @([PSCustomObject]$record) + @($rows)
            }
        }

        # Whatever projection was chosen, guarantee scalar cells.
        $flatRows = @($rows | Where-Object { $null -ne $_ } | ForEach-Object {
                $row = $_
                if ($row -is [System.Collections.IDictionary]) {
                    $ordered = [ordered]@{}
                    foreach ($k in $row.Keys) { $ordered[[string]$k] = ConvertTo-FinOpsExportCell $row[$k] }
                    [PSCustomObject]$ordered
                }
                elseif ($row.PSObject.Properties.Count -gt 0 -and $row -isnot [string] -and $row -isnot [ValueType]) {
                    $ordered = [ordered]@{}
                    foreach ($p in $row.PSObject.Properties) { $ordered[$p.Name] = ConvertTo-FinOpsExportCell $p.Value }
                    [PSCustomObject]$ordered
                }
                else {
                    [PSCustomObject]@{ Value = ConvertTo-FinOpsExportCell $row }
                }
            })
        $columnNames = [System.Collections.Generic.List[string]]::new()
        $seenColumns = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($row in $flatRows) {
            foreach ($property in $row.PSObject.Properties) {
                if ((Protect-FinOpsExportText $property.Name) -cne $property.Name) { throw 'CSV column header contains an unsafe formula prefix.' }
                if ($seenColumns.Add($property.Name)) { [void]$columnNames.Add($property.Name) }
            }
        }
        if ($flatRows.Count -eq 0) { return @() }
        return @($flatRows | Select-Object -Property $columnNames.ToArray())
    }

    function Get-FinOpsReportRoot {
        $localData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData, [Environment+SpecialFolderOption]::DoNotVerify)
        if ([string]::IsNullOrWhiteSpace($localData)) {
            throw 'Local application data is unavailable. Specify a local OutputPath outside any Git repository.'
        }
        return (Join-Path $localData 'FinOpsToolkit/Multitool/Reports')
    }

    function Assert-FinOpsReportPath {
        param([Parameter(Mandatory)][string]$Path)

        if ($Path -match '^[\\/]{2}|::|[\x00-\x1f]' -or ($Path.Contains(':') -and $Path -notmatch '^[A-Za-z]:[\\/][^:]*$')) {
            throw 'Reports require a local filesystem path, not a network, device, or provider path.'
        }
        $provider = $null
        $drive = $null
        $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive)
        if ($provider.Name -ne 'FileSystem' -or $fullPath -match '^[\\/]{2}') {
            throw 'Reports require a local filesystem path.'
        }
        $fullPath = [System.IO.Path]::GetFullPath($fullPath)
        if ($IsWindows -and ([System.IO.DriveInfo]::new([System.IO.Path]::GetPathRoot($fullPath))).DriveType -eq [System.IO.DriveType]::Network) {
            throw 'Reports require a local drive, not a mapped network drive.'
        }
        $ancestor = $fullPath
        while ($ancestor) {
            if ([System.IO.Path]::GetFileName($ancestor) -ieq '.git') {
                throw 'Reports cannot be saved in a Git metadata directory.'
            }
            try {
                $attributes = [System.IO.File]::GetAttributes($ancestor)
                if (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw 'Report paths cannot contain symbolic links or junctions.'
                }
                if (($attributes -band [System.IO.FileAttributes]::Directory) -eq 0) {
                    throw 'The report destination must be a local directory.'
                }
                $gitMarker = Join-Path $ancestor '.git'
                $hasGitMarker = $false
                try {
                    $null = [System.IO.File]::GetAttributes($gitMarker)
                    $hasGitMarker = $true
                }
                catch [System.IO.FileNotFoundException] { $hasGitMarker = $false }
                catch [System.IO.DirectoryNotFoundException] { $hasGitMarker = $false }
                if ($hasGitMarker -or ([System.IO.File]::Exists((Join-Path $ancestor 'HEAD')) -and [System.IO.Directory]::Exists((Join-Path $ancestor 'objects')))) {
                    throw 'Reports cannot be saved inside a Git repository or worktree. Choose a different local OutputPath.'
                }
            }
            catch [System.IO.FileNotFoundException] { Write-Verbose "The report path '$ancestor' does not exist yet." }
            catch [System.IO.DirectoryNotFoundException] { Write-Verbose "The report path '$ancestor' does not exist yet." }
            $ancestor = [System.IO.Path]::GetDirectoryName($ancestor)
        }
        return $fullPath
    }

    function New-FinOpsReportDirectory {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates only a new private report directory for the requested scan.')]
        [CmdletBinding()]
        param([string]$OutputPath)

        $basePath = if ([string]::IsNullOrWhiteSpace($OutputPath)) { Get-FinOpsReportRoot } else { $OutputPath }
        $basePath = Assert-FinOpsReportPath -Path $basePath
        [void][System.IO.Directory]::CreateDirectory($basePath)
        $runName = '{0}-{1}' -f [datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ', [cultureinfo]::InvariantCulture), [guid]::NewGuid().ToString('N')
        $runPath = Assert-FinOpsReportPath -Path (Join-Path $basePath $runName)
        if (Test-Path -LiteralPath $runPath) { throw 'The report run directory already exists. No files were written.' }

        if ($IsWindows) {
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            try {
                $security = [System.Security.AccessControl.DirectorySecurity]::new()
                $security.SetAccessRuleProtection($true, $false)
                $security.SetOwner($identity.User)
                $inheritance = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
                $security.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new(
                        $identity.User, [System.Security.AccessControl.FileSystemRights]::FullControl,
                        $inheritance, [System.Security.AccessControl.PropagationFlags]::None, [System.Security.AccessControl.AccessControlType]::Allow))
                [System.IO.FileSystemAclExtensions]::Create([System.IO.DirectoryInfo]::new($runPath), $security)
            }
            finally { $identity.Dispose() }
        }
        else {
            $unixModeType = 'System.IO.UnixFileMode' -as [type]
            if ($unixModeType) {
                [void][System.IO.Directory]::CreateDirectory($runPath, [Enum]::ToObject($unixModeType, 448))
            }
            else {
                $mkdir = Get-Command -Name mkdir -CommandType Application -ErrorAction Stop
                & $mkdir.Source -m 700 $runPath
                if ($LASTEXITCODE -ne 0) { throw 'Could not create a private report directory.' }
            }
        }
        $runPath = Assert-FinOpsReportPath -Path $runPath
        Write-FinOpsReportFile -Directory $runPath -Name '.gitignore' -Lines @('*')
        return $runPath
    }

    function Write-FinOpsReportFile {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)][string]$Directory,
            [Parameter(Mandatory)][string]$Name,
            [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines
        )

        $Directory = Assert-FinOpsReportPath -Path $Directory
        if ($Name -notmatch '^(?:[A-Za-z0-9][A-Za-z0-9._-]*|\.gitignore)$') { throw 'Invalid report file name.' }
        $path = Join-Path $Directory $Name
        $stream = [System.IO.FileStream]::new($path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            if (-not $IsWindows) {
                $unixModeType = 'System.IO.UnixFileMode' -as [type]
                if ($unixModeType) { [System.IO.File]::SetUnixFileMode($path, [Enum]::ToObject($unixModeType, 384)) }
                else {
                    $chmod = Get-Command -Name chmod -CommandType Application -ErrorAction Stop
                    & $chmod.Source 600 $path
                    if ($LASTEXITCODE -ne 0) { throw 'Could not restrict report file permissions.' }
                }
            }
            $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
            try { foreach ($line in $Lines) { $writer.WriteLine($line) } }
            finally { $writer.Dispose() }
        }
        finally { $stream.Dispose() }
    }

    function Show-ResultsSummary {
        param(
            [hashtable]$Results,
            [array]$Modules,
            [string]$ExportPath,
            [array]$Subscriptions,

            [string]$DataSourceLabel
        )

        function Format-ReportMetric {
            param($Value, [string]$Format = 'N0', [string]$Suffix = '')
            $number = 0.0
            if ($null -eq $Value -or -not [double]::TryParse([Convert]::ToString($Value, [cultureinfo]::InvariantCulture), [Globalization.NumberStyles]::Float, [cultureinfo]::InvariantCulture, [ref]$number) -or
                [double]::IsNaN($number) -or [double]::IsInfinity($number)) { return 'Unavailable' }
            $number.ToString($Format, [cultureinfo]::InvariantCulture) + $Suffix
        }

        function ConvertTo-ReportTableControlHtml {
            param([string]$TableId, [string]$Title, [int]$RowCount)

            if ($RowCount -le 25) { return '' }
            $filterId = [System.Net.WebUtility]::HtmlEncode(($TableId -replace '^table-', 'filter-'))
            $encodedId = [System.Net.WebUtility]::HtmlEncode($TableId)
            $encodedTitle = [System.Net.WebUtility]::HtmlEncode($Title)
            return "<div class=`"report-table-controls`" data-table-id=`"$encodedId`"><label for=`"$filterId`">Filter $encodedTitle<input id=`"$filterId`" type=`"search`" aria-controls=`"$encodedId`"></label><output aria-live=`"polite`">$RowCount rows</output><button type=`"button`" data-page-action=`"previous`" aria-label=`"Previous page of $encodedTitle`">Previous</button><button type=`"button`" data-page-action=`"next`" aria-label=`"Next page of $encodedTitle`">Next</button></div>"
        }

        function ConvertTo-ResourceIdentityHtml {
            param([object]$Resource)

            $label = if ($Resource.ResourceName) { [string]$Resource.ResourceName }
            elseif ($Resource.ResourcePath) { [string]$Resource.ResourcePath }
            else { 'No resource ID recorded' }
            $html = [System.Net.WebUtility]::HtmlEncode($label)
            if ($Resource.ResourceName -and $Resource.ResourcePath -and $Resource.ResourceName -ne $Resource.ResourcePath) {
                $html += "<details class=`"cell-details`"><summary>Resource ID</summary><div class=`"detail-content`"><code>$([System.Net.WebUtility]::HtmlEncode([string]$Resource.ResourcePath))</code></div></details>"
            }
            return $html
        }

        function ConvertTo-PolicyScopeHtml {
            param([object]$Assignment)

            $scopeId = [string]$Assignment.Scope
            $label = if ($Assignment.ScopeDisplayName) { [string]$Assignment.ScopeDisplayName }
            elseif ($scopeId -match '^/subscriptions/([^/]+)$' -and $subNameLookup.ContainsKey($Matches[1])) { [string]$subNameLookup[$Matches[1]] }
            elseif ($scopeId) { $scopeId }
            else { 'Scope not recorded' }
            $html = [System.Net.WebUtility]::HtmlEncode($label)
            if ($scopeId -and $label -ne $scopeId) {
                $html += "<details class=`"cell-details`"><summary>Scope ID</summary><div class=`"detail-content`"><code>$([System.Net.WebUtility]::HtmlEncode($scopeId))</code></div></details>"
            }
            return $html
        }

        # Build sub ID → name lookup for display functions
        $subNameLookup = @{}
        if ($Subscriptions) { foreach ($s in $Subscriptions) { if ($s.Id -and $s.Name) { $subNameLookup[$s.Id] = $s.Name } } }

        Write-SectionHeader 'SCAN COMPLETE'
        Write-FinOpsConsole ""

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
            Write-FinOpsConsole "  $icon $($mod.Name.PadRight(30)) $suffix" -ForegroundColor $color
        }

        Write-FinOpsConsole ""
        Write-FinOpsConsole "  Total findings: $totalFindings" -ForegroundColor White
        Write-FinOpsConsole ""

        # -- Display results per module ------------------------------------
        # Guidance is built per scan during this pass; the HTML report is written
        # later, so keep it here rather than recomputing the whole switch.
        $guidanceByFn = @{}
        # KPIs are collected across every scan so the report can retell them by
        # FinOps domain rather than scattered under the scan that produced them.
        $kpiCollected = [System.Collections.Generic.List[PSCustomObject]]::new()
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
                        Write-FinOpsConsole "    [!] ACCESS DENIED" -ForegroundColor Red
                        Write-FinOpsConsole "    $errorMsg" -ForegroundColor DarkGray
                        Write-FinOpsConsole ""
                        Write-FinOpsConsole "    Required role:  $($pInfo.Role)" -ForegroundColor Yellow
                        Write-FinOpsConsole "    Scope:          $($pInfo.Scope)" -ForegroundColor Yellow
                        Write-FinOpsConsole "    API:            $($pInfo.API)" -ForegroundColor DarkGray
                        Write-FinOpsConsole "    $($pInfo.Reason)" -ForegroundColor DarkGray
                    }
                    else {
                        Write-FinOpsConsole "    [!] ERROR: $errorMsg" -ForegroundColor Red
                        if ($pInfo) {
                            Write-FinOpsConsole "    If this is a permissions issue:" -ForegroundColor DarkGray
                            Write-FinOpsConsole "    Required role: $($pInfo.Role) at $($pInfo.Scope) scope" -ForegroundColor DarkGray
                        }
                    }
                }
                else {
                    # No error but no data — could be legitimately empty
                    Write-FinOpsConsole "    No data returned." -ForegroundColor DarkGray
                    if ($pInfo) {
                        Write-FinOpsConsole "    Possible reasons:" -ForegroundColor DarkGray
                        Write-FinOpsConsole "    - $($pInfo.Reason)" -ForegroundColor DarkGray
                        Write-FinOpsConsole "    - Required role: $($pInfo.Role) at $($pInfo.Scope) scope" -ForegroundColor DarkGray
                    }
                }
                Write-FinOpsConsole ""
                continue
            }

            Write-SectionHeader $mod.Name

            # Extract the displayable rows and columns per module
            $rows = $null
            $cols = $null

            switch ($mod.Fn) {
                'Get-OrphanedResources' {
                    if ($data.MonthlyCost) {
                        Write-FinOpsConsole "    Observed cost ($($data.CostPeriod)): $(Format-BudgetAmount -Value $data.MonthlyCost -Currency $data.Currency) across $($data.CostedCount) of $($data.TotalCount) resources" -ForegroundColor White
                    }
                    if ($data.CostIssue) {
                        Write-FinOpsConsole "    Cost column incomplete - $($data.CostIssue)" -ForegroundColor Yellow
                    }
                    # 'n/a' when the lookup failed, '-' when it succeeded and the resource simply had no spend.
                    $noCost = if ($data.CostAvailable) { '-' } else { 'n/a' }
                    $costCol = if ($data.CostPeriod) { [string]$data.CostPeriod } else { 'Cost' }
                    $rows = $data.Orphans | ForEach-Object {
                        $o = [ordered]@{
                            Category      = $_.Category
                            ResourceName  = $_.ResourceName
                            ResourceGroup = $_.ResourceGroup
                        }
                        $o[$costCol] = if ($null -ne $_.MonthlyCost) { Format-BudgetAmount -Value $_.MonthlyCost -Currency $_.Currency } else { $noCost }
                        $o['Detail'] = $_.Detail
                        [PSCustomObject]$o
                    }
                    $cols = @('Category', 'ResourceName', 'ResourceGroup', $costCol, 'Detail')
                }
                'Get-IdleVMs' {
                    $scanned = if ($data.ScannedVMs) { $data.ScannedVMs } else { 0 }
                    if ($data.MetricFailures -gt 0) { Write-FinOpsConsole "    $($data.MetricFailures) of $scanned VMs could not be evaluated. $($data.Note)" -ForegroundColor Yellow }
                    if ($data.IdleVMs -and @($data.IdleVMs).Count -gt 0) {
                        Write-FinOpsConsole "    Scanned $scanned running VMs — $(@($data.IdleVMs).Count) idle/underutilized" -ForegroundColor White
                        $rows = $data.IdleVMs
                        $cols = @('VMName', 'ResourceGroup', 'VMSize', 'AvgCPU14d', 'Classification')
                    }
                    elseif ($data.MetricFailures -eq 0) {
                        Write-FinOpsConsole "    Scanned $scanned running VMs — no idle or underutilized VMs detected" -ForegroundColor Green
                    }
                }
                'Get-StorageTierAdvice' {
                    $hotCount = if ($data.TotalHotAccounts) { $data.TotalHotAccounts } else { 0 }
                    if ($data.MetricFailures -gt 0) { Write-FinOpsConsole "    $($data.MetricFailures) of $hotCount storage accounts could not be evaluated. Review the metric errors." -ForegroundColor Yellow }
                    if ($data.Recommendations -and @($data.Recommendations).Count -gt 0) {
                        Write-FinOpsConsole "    $hotCount Hot-tier accounts scanned - $(@($data.Recommendations).Count) candidates for tier review" -ForegroundColor White
                        $rows = $data.Recommendations
                        $cols = @('StorageAccount', 'ResourceGroup', 'CurrentTier', 'CapacityGB', 'Recommendation')
                    }
                    else {
                        Write-FinOpsConsole "    $hotCount Hot-tier accounts found. No tier recommendation was produced from the available measurements." -ForegroundColor White
                    }
                }
                'Get-AHBOpportunities' {
                    $rows = @()
                    if ($data.WindowsVMs) {
                        $rows += @($data.WindowsVMs) | ForEach-Object {
                            $est = if ($null -ne $_.estMonthlySavings) { "$(Format-BudgetAmount -Value $_.estMonthlySavings -Currency $data.SavingsCurrency)/mo" } else { 'n/a' }
                            [PSCustomObject]@{ Type = 'Windows VM'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.vmSize; License = $_.currentLicense; 'Est Savings' = $est }
                        }
                    }
                    if ($data.SQLVMs) {
                        $rows += @($data.SQLVMs) | ForEach-Object {
                            [PSCustomObject]@{ Type = 'SQL VM'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.sqlEdition; License = $_.currentLicense; 'Est Savings' = '-' }
                        }
                    }
                    if ($data.SQLDatabases) {
                        $rows += @($data.SQLDatabases) | ForEach-Object {
                            [PSCustomObject]@{ Type = 'SQL DB'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.sku; License = $_.currentLicense; 'Est Savings' = '-' }
                        }
                    }
                    $cols = @('Type', 'Name', 'ResourceGroup', 'Size', 'License', 'Est Savings')
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
                            # Console width is tight once SKU/Region/Qty are shown.
                            if ($resLabel.Length -gt 22) { $resLabel = $resLabel.Substring(0, 21) + [char]0x2026 }
                            [PSCustomObject]@{
                                Resource = $resLabel
                                Type     = ($_.ResourceType -split '/')[-1]
                                SKU      = $_.SKU
                                Region   = $_.Region
                                Qty      = $_.Qty
                                Term     = $_.Term
                                Savings  = Format-BudgetAmount -Value $_.AnnualSavings -Currency $_.Currency
                                Impact   = $_.Impact
                            }
                        }
                        $cols = @('Resource', 'Type', 'SKU', 'Region', 'Qty', 'Term', 'Savings', 'Impact')
                        Write-ColorizedLine -Text "    Est. annual savings: $(Format-BudgetAmount -Value $data.EstimatedAnnualSavings -Currency $data.Currency)" -DefaultColor 'White'
                        if ($data.CostIssue) { Write-FinOpsConsole "    $($data.CostIssue)" -ForegroundColor Yellow }
                    }
                }
                'Get-CommitmentUtilization' {
                    if ($data.HasData) {
                        Write-FinOpsConsole "    Reservations: $($data.RICount) (average $(Format-ReportMetric $data.RIAvgUtilization -Format '0.#' -Suffix '%'))  |  Savings plans: $($data.SPCount) (average $(Format-ReportMetric $data.SPAvgUtilization -Format '0.#' -Suffix '%'))" -ForegroundColor White
                        $rows = $data.Reservations | ForEach-Object {
                            [PSCustomObject]@{ Reservation = if ($_.Name) { $_.Name } else { $_.ReservationId }; SKU = if ($_.SkuName) { $_.SkuName } else { 'Not returned' }; Kind = if ($_.Kind) { $_.Kind } else { 'Not returned' }; AvgUtil = Format-ReportMetric $_.AvgUtilization -Format '0.#' -Suffix '%'; UsageDate = $_.UsageDate }
                        }
                        $cols = @('Reservation', 'SKU', 'Kind', 'AvgUtil', 'UsageDate')
                        if ($data.Note) { Write-FinOpsConsole "    $($data.Note)" -ForegroundColor DarkGray }
                    }
                    elseif ($data.AccessDenied) {
                        Show-PermissionReadout -Fn 'Get-CommitmentUtilization' -PermissionInfo $permissionInfo -Activity 'reservation / savings plan utilization'
                    }
                    else {
                        Write-FinOpsConsole "    $(if ($data.Note) { $data.Note } else { 'No reservation or savings plan results returned.' })" -ForegroundColor DarkGray
                    }
                }
                'Get-SavingsRealized' {
                    Write-FinOpsConsole "    Estimated savings (separate periods):" -ForegroundColor White
                    Write-FinOpsConsole "      Commitment period: $($data.Period)" -ForegroundColor DarkGray
                    Write-ColorizedLine -Text "      RI: $(Format-BudgetAmount -Value $data.RISavingsMonthToDate -Currency $data.Currency)   SP: $(Format-BudgetAmount -Value $data.SPSavingsMonthToDate -Currency $data.Currency)" -DefaultColor 'Cyan'
                    Write-ColorizedLine -Text "      Commitment estimate: $(Format-BudgetAmount -Value $data.CommitmentSavingsMonthToDate -Currency $data.Currency)" -DefaultColor 'White'
                    Write-ColorizedLine -Text "      AHB: $(Format-BudgetAmount -Value $data.AHBSavingsMonthly -Currency $data.AHBCurrency) ($($data.AHBPeriod))" -DefaultColor 'Cyan'
                    if ($data.AHBIssue) { Write-FinOpsConsole "      $($data.AHBIssue)" -ForegroundColor Yellow }
                    if ($data.EstimateBasis) {
                        Write-FinOpsConsole "      $($data.EstimateBasis)" -ForegroundColor DarkGray
                    }
                    $rows = $null  # summary only
                }
                'Get-CostData' {
                    # CostData is a hashtable keyed by subscription ID
                    if ($data -is [hashtable]) {
                        $rows = $data.GetEnumerator() | ForEach-Object {
                            # Prefer the name carried in the cost data itself (hub
                            # FOCUS data), then the selected-subscription lookup,
                            # then a truncated ID as a last resort.
                            $subLabel = if ($_.Value.Name) { $_.Value.Name }
                            elseif ($subNameLookup.ContainsKey($_.Key)) { $subNameLookup[$_.Key] }
                            else { $_.Key.Substring(0, [Math]::Min(36, $_.Key.Length)) }
                            [PSCustomObject]@{
                                Subscription   = $subLabel
                                Actual         = Format-BudgetAmount -Value $_.Value.Actual -Currency $_.Value.Currency
                                ActualPeriod   = if ($_.Value.ActualPeriod) { $_.Value.ActualPeriod } else { 'Current month' }
                                Forecast       = if ($_.Value.ForecastSource -eq 'Actual') { 'Unavailable' } else { Format-BudgetAmount -Value $_.Value.Forecast -Currency $_.Value.Currency }
                                ForecastSource = if ($_.Value.ForecastSource) { $_.Value.ForecastSource } else { 'Unavailable' }
                                Currency       = $_.Value.Currency
                            }
                        }
                        $cols = @('Subscription', 'Actual', 'ActualPeriod', 'Forecast', 'ForecastSource', 'Currency')
                    }
                }
                'Get-ResourceCosts' {
                    $rows = @($data) | Sort-Object { [double]$_.Actual } -Descending | Select-Object -First 50 | ForEach-Object {
                        $resName = if ($_.ResourcePath) { ($_.ResourcePath -split '/')[-1] } else { '-' }
                        [PSCustomObject]@{
                            Resource      = $resName
                            ResourceGroup = $_.ResourceGroup
                            ResourceType  = ($_.ResourceType -split '/')[-1]
                            Cost          = Format-BudgetAmount -Value $_.Actual -Currency $_.Currency
                        }
                    }
                    $cols = @('Resource', 'ResourceGroup', 'ResourceType', 'Cost')
                    if (@($data).Count -gt 50) {
                        Write-FinOpsConsole "    (showing top 50 of $(@($data).Count) resources by cost)" -ForegroundColor DarkGray
                    }
                }
                'Get-CostByTag' {
                    if ($data.CoverageIncomplete) { Write-FinOpsConsole "    $($data.Note)" -ForegroundColor Yellow }
                    if ($data.CostByTag -and $data.CostByTag.Count -gt 0) {
                        if ($data.Source) { Write-FinOpsConsole "    Source: $($data.Source)" -ForegroundColor DarkGray }
                        $rows = foreach ($tag in $data.CostByTag.GetEnumerator()) {
                            foreach ($v in $tag.Value) {
                                $displayVal = if ($v.TagValue.Length -gt 40) { $v.TagValue.Substring(0, 37) + '...' } else { $v.TagValue }
                                [PSCustomObject]@{ Tag = $tag.Key; Value = $displayVal; Cost = Format-BudgetAmount -Value $v.Cost -Currency $v.Currency }
                            }
                        }
                        $cols = @('Tag', 'Value', 'Cost')
                    }
                    elseif ($data.NoTagsFound) {
                        Write-FinOpsConsole "    No tags found in environment to query cost against." -ForegroundColor DarkGray
                    }
                    else {
                        $tagCount = if ($data.TagsQueried) { $data.TagsQueried.Count } else { 0 }
                        $cbtCount = if ($data.CostByTag) { $data.CostByTag.Count } else { 0 }
                        Write-FinOpsConsole "    Tags queried: $tagCount, results: $cbtCount — no cost data returned." -ForegroundColor DarkGray
                        if ($data.UsedTimeframe) { Write-FinOpsConsole "    Timeframe: $($data.UsedTimeframe)" -ForegroundColor DarkGray }
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
                        Write-FinOpsConsole "    No cost trend data returned. Requires Cost Management Reader at the subscription or MG scope, or there is no historical spend in the selected period." -ForegroundColor DarkGray
                        $rows = $null
                        $cols = $null
                    }
                    elseif ($nonEmptySubs -and $nonEmptySubs.Count -gt 0) {
                        foreach ($subEntry in $nonEmptySubs) {
                            $subName = if ($subNameLookup.ContainsKey($subEntry.Key)) { $subNameLookup[$subEntry.Key] } else { $subEntry.Key }
                            Write-FinOpsConsole "    $subName" -ForegroundColor White
                            $subRows = $subEntry.Value | ForEach-Object {
                                [PSCustomObject]@{ Month = $_.Month; Cost = Format-BudgetAmount -Value $_.Cost -Currency $_.Currency; Currency = $_.Currency }
                            }
                            @($subRows) | Format-Table -AutoSize | Out-String | ForEach-Object {
                                $lines = $_.TrimEnd() -split '\r?\n' | Where-Object { $_.Trim() }
                                $hdrDone = $false
                                foreach ($ln in $lines) {
                                    if (-not $hdrDone) {
                                        if ($ln -match '^[\s\-]+$') { Write-FinOpsConsole "    $ln" -ForegroundColor DarkCyan; $hdrDone = $true }
                                        else { Write-FinOpsConsole "    $ln" -ForegroundColor Cyan }
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
                            Write-FinOpsConsole "    $subNames" -ForegroundColor White
                        }
                        $rows = $data.Months | ForEach-Object {
                            [PSCustomObject]@{ Month = $_.Month; Cost = Format-BudgetAmount -Value $_.Cost -Currency $_.Currency; Currency = $_.Currency }
                        }
                        $cols = @('Month', 'Cost', 'Currency')
                    }
                }
                'Get-TagInventory' {
                    $tagCountText = if ($data.SpellingCount -and $data.SpellingCount -ne $data.TagCount) { "$($data.TagCount) unique tag keys ($($data.SpellingCount) spellings)" } else { "$($data.TagCount) unique tags" }
                    $coverageLabel = if ($data.CoverageIncomplete -or $null -eq $data.TagCoverage) { 'Unverified' } else { "$($data.TagCoverage)%" }
                    Write-FinOpsConsole "    Coverage: $coverageLabel  |  $($data.TaggedCount) tagged / $($data.UntaggedCount) untagged  |  $tagCountText" -ForegroundColor White
                    if ($data.CoverageIncomplete) { Write-FinOpsConsole "    $($data.Note)" -ForegroundColor Yellow }
                    if ($data.CaseVariants -and @($data.CaseVariants).Count -gt 0) {
                        Write-FinOpsConsole "    Case-variant keys (Azure treats these as one tag):" -ForegroundColor Yellow
                        foreach ($cv in @($data.CaseVariants)) {
                            Write-FinOpsConsole "      $($cv.TagKey): $($cv.Detail)" -ForegroundColor DarkGray
                        }
                    }
                    if ($data.TagNames -and $data.TagNames.Count -gt 0) {
                        $rows = $data.TagNames.GetEnumerator() | Sort-Object { $_.Value.TotalResources } -Descending | Select-Object -First 15 | ForEach-Object {
                            $vals = @($_.Value.Values | Sort-Object ResourceCount -Descending)
                            $shown = @($vals | Select-Object -First 3 | ForEach-Object { "$($_.Value) ($($_.ResourceCount))" })
                            $more = $vals.Count - $shown.Count
                            $valText = ($shown -join ', ') + $(if ($more -gt 0) { ", +$more more" } else { '' })
                            [PSCustomObject]@{ Tag = $_.Key; Resources = $_.Value.TotalResources; Values = $vals.Count; 'Top values' = $valText }
                        }
                        $cols = @('Tag', 'Resources', 'Values', 'Top values')
                    }
                }
                'Get-TagRecommendations' {
                    $rows = $data.Analysis | ForEach-Object {
                        [PSCustomObject]@{ Tag = $_.TagName; Status = $_.Status; Priority = $_.Priority; Pillar = $_.Pillar; Example = $_.Example }
                    }
                    $cols = @('Tag', 'Status', 'Priority', 'Pillar', 'Example')
                    Write-FinOpsConsole "    Compliance: $($data.CompliancePercent)%" -ForegroundColor White
                }
                'Get-PolicyInventory' {
                    $hasComplianceData = if ($null -ne $data.HasComplianceData) { $data.HasComplianceData } else { (($data.TotalCompliant + $data.TotalNonCompliant) -gt 0) }
                    if ($data.DefinitionCoverageIncomplete) {
                        Write-FinOpsConsole '    Policy definition coverage is incomplete. Some effects could not be resolved.' -ForegroundColor Yellow
                    }
                    if ($data.ComplianceCoverageIncomplete) {
                        Write-FinOpsConsole "    Assignments: $($data.AssignmentCount) | Compliance: unverified because some selected scopes could not be read" -ForegroundColor Yellow
                    }
                    elseif ($hasComplianceData) {
                        Write-FinOpsConsole "    Assignments: $($data.AssignmentCount)  |  Compliance: $($data.CompliancePct)%  ($($data.TotalCompliant) compliant, $($data.TotalNonCompliant) non-compliant)" -ForegroundColor White
                    }
                    else {
                        Write-FinOpsConsole "    Assignments: $($data.AssignmentCount)  |  Compliance: data unavailable (no evaluated policy states)" -ForegroundColor White
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
                        Write-FinOpsConsole "    (showing 15 of $($data.AssignmentCount) assignments)" -ForegroundColor DarkGray
                    }
                }
                'Get-PolicyRecommendations' {
                    $rows = $data.Analysis | ForEach-Object {
                        [PSCustomObject]@{ Policy = $_.DisplayName; Status = $_.Status; Category = $_.Category; Priority = $_.Priority; Effect = $_.DefaultEffect }
                    }
                    $cols = @('Policy', 'Status', 'Category', 'Priority', 'Effect')
                    $assignmentCoverage = if ($data.CoverageIncomplete -or $null -eq $data.CompliancePct) { 'unverified' } else { "$($data.CompliancePct)%" }
                    Write-FinOpsConsole "    Assignment coverage: $assignmentCoverage (recommended definition IDs found, not resource compliance)" -ForegroundColor White
                    foreach ($issue in @($data.InitiativeErrors)) {
                        Write-FinOpsConsole "    Initiative lookup unavailable: $($issue.InitiativeId) - $($issue.Error)" -ForegroundColor Yellow
                    }
                }
                'Get-BudgetStatus' {
                    Write-FinOpsConsole "    Budgets: $($data.TotalBudgets)  |  " -ForegroundColor White -NoNewline
                    Write-FinOpsConsole "At risk: $($data.AtRiskCount)" -ForegroundColor $(if ($data.AtRiskCount -gt 0) { 'Yellow' } else { 'Green' }) -NoNewline
                    Write-FinOpsConsole "  |  " -ForegroundColor White -NoNewline
                    Write-FinOpsConsole "Over budget: $($data.OverBudgetCount)" -ForegroundColor $(if ($data.OverBudgetCount -gt 0) { 'Red' } else { 'Green' }) -NoNewline
                    if ($data.CoverageIncomplete) {
                        Write-FinOpsConsole "  |  Coverage: unverified (read $($data.ScannedSubs) of $($data.TotalSubs) subs)" -ForegroundColor Yellow
                    }
                    else {
                        Write-FinOpsConsole "  |  Coverage: $($data.BudgetCoverage)%" -ForegroundColor White
                    }
                    $rows = $data.Budgets | ForEach-Object {
                        [PSCustomObject]@{
                            Budget   = $_.BudgetName
                            Amount   = Format-BudgetAmount -Value $_.Amount -Currency $_.Currency
                            Spent    = Format-BudgetAmount -Value $_.ActualSpend -Currency $_.Currency
                            Forecast = Format-BudgetAmount -Value $_.Forecast -Currency $_.Currency
                            PctUsed  = if ($null -ne $_.PctUsed) { "$($_.PctUsed)%" } else { 'Unavailable' }
                            Risk     = $_.Risk
                            Note     = $_.Note
                        }
                    }
                    $cols = @('Budget', 'Amount', 'Spent', 'Forecast', 'PctUsed', 'Risk', 'Note')
                }
                'Get-BudgetHistory' {
                    if ($data -and @($data).Count -gt 0) {
                        $rows = @($data) | ForEach-Object {
                            [PSCustomObject]@{
                                Subscription = $_.Subscription
                                Budget       = $_.BudgetName
                                Month        = $_.Month
                                Budgeted     = Format-BudgetAmount -Value $_.BudgetAmount -Currency $_.Currency
                                Actual       = Format-BudgetAmount -Value $_.ActualSpend -Currency $_.Currency
                                PctUsed      = if ($null -ne $_.PctUsed) { "$($_.PctUsed)%" } else { 'Unavailable' }
                                Status       = $_.Status
                                Note         = $_.Note
                            }
                        }
                        $cols = @('Subscription', 'Budget', 'Month', 'Budgeted', 'Actual', 'PctUsed', 'Status', 'Note')
                    }
                    else {
                        Write-FinOpsConsole "    No budget history available (no budgets configured, or no cost data for the period)." -ForegroundColor DarkGray
                    }
                }
                'Get-AnomalyAlerts' {
                    Write-FinOpsConsole "    Alerts: $($data.TotalAlerts)  |  Anomaly: $($data.AnomalyAlertCount)  |  Active: $($data.ActiveAlertCount)  |  Rules: $($data.ConfiguredRuleCount)" -ForegroundColor White
                    $rows = $data.TriggeredAlerts | Select-Object -First 10 | ForEach-Object {
                        $label = if ($_.AlertLabel) { $_.AlertLabel } else { $_.AlertName }
                        if ($label.Length -gt 45) { $label = $label.Substring(0, 42) + '...' }
                        [PSCustomObject]@{ Alert = $label; Type = $_.AlertType; Status = $_.Status; Subscription = $_.Subscription }
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
                        [PSCustomObject]@{ Account = $_.AccountName; Agreement = $_.AgreementType; Type = $_.FriendlyType; Country = $_.SoldToCountry; Status = $_.AccountStatus }
                    }
                    $cols = @('Account', 'Agreement', 'Type', 'Country', 'Status')
                }
                'Get-MaccCommitment' {
                    if ($data.CoverageIncomplete) { Write-FinOpsConsole "    $($data.Reason)" -ForegroundColor Yellow }
                    if (-not $data.Applicable) {
                        Write-FinOpsConsole "    $($data.Reason)" -ForegroundColor DarkGray
                    }
                    elseif ($data.HasMacc -and @($data.Commitments).Count -gt 0) {
                        $rows = @($data.Commitments) | ForEach-Object {
                            [PSCustomObject]@{
                                Account    = $_.BillingAccount
                                Commitment = Format-BudgetAmount -Value $_.Commitment -Currency $_.Currency
                                Consumed   = Format-BudgetAmount -Value $_.Consumed -Currency $_.Currency
                                Remaining  = Format-BudgetAmount -Value $_.Remaining -Currency $_.Currency
                                PctUsed    = if ($null -ne $_.PctUsed) { "$($_.PctUsed)%" } else { 'Unavailable' }
                                Status     = $_.Status
                                Expires    = $_.ExpirationDate
                            }
                        }
                        $cols = @('Account', 'Commitment', 'Consumed', 'Remaining', 'PctUsed', 'Status', 'Expires')
                    }
                    else {
                        Write-FinOpsConsole "    $($data.Reason)" -ForegroundColor DarkGray
                    }
                }
                'Get-OptimizationAdvice' {
                    Write-ColorizedLine -Text "    Est. annual savings: $(Format-BudgetAmount -Value $data.EstimatedAnnualSavings -Currency $data.Currency)  |  $($data.TotalCount) recommendations" -DefaultColor 'White'
                    if ($data.CostIssue) { Write-FinOpsConsole "    $($data.CostIssue)" -ForegroundColor Yellow }
                    $rows = $data.Recommendations | Sort-Object { if ($_.AnnualSavings) { [double]$_.AnnualSavings } else { 0 } } -Descending | Select-Object -First 15 | ForEach-Object {
                        [PSCustomObject]@{
                            Category = $_.Category
                            Impact   = $_.Impact
                            Resource = $_.ResourceName
                            Problem  = ($_.Problem -replace '(.{60}).+', '$1...')
                            Savings  = "$(Format-BudgetAmount -Value $_.AnnualSavings -Currency $_.Currency)/yr"
                        }
                    }
                    $cols = @('Category', 'Impact', 'Resource', 'Problem', 'Savings')
                    if ($data.TotalCount -gt 15) {
                        Write-FinOpsConsole "    (showing top 15 of $($data.TotalCount) by savings)" -ForegroundColor DarkGray
                    }
                }
                'Get-CarbonMetrics' {
                    $emissions = if ($null -ne $data.TotalEmissionsKg) { "$($data.TotalEmissionsKg) $($data.Unit)" } else { 'Unavailable' }
                    $changeLabel = if ($null -ne $data.ChangeRatio) { "$($data.ChangeRatio)%" } else { 'Unavailable' }
                    Write-ColorizedLine -Text "    Latest month ($($data.LatestMonth)): $emissions  |  Month-over-month change: $changeLabel" -DefaultColor 'White'
                    if ($data.Note) { Write-FinOpsConsole "    $($data.Note)" -ForegroundColor Yellow }
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
                    $computeShare = if ($null -ne $data.ComputeSharePct) { "$($data.ComputeSharePct)% of VM compute + storage spend" } else { 'Unavailable' }
                    $storageShare = if ($null -ne $data.StorageSharePct) { "$($data.StorageSharePct)% of VM compute + storage spend" } else { 'Unavailable' }
                    Write-ColorizedLine -Text "    Compute: $(Format-BudgetAmount -Value $data.ComputeCost -Currency $data.Currency) ($computeShare) over $($data.VmCount) VMs / $($data.TotalVCpu) vCPU / $($data.TotalMemoryGb) GB RAM" -DefaultColor 'White'
                    Write-ColorizedLine -Text "    Storage: $(Format-BudgetAmount -Value $data.StorageCost -Currency $data.Currency) ($storageShare) over $($data.TotalStorageGb) GB ($($data.DiskGb) GB disk + $($data.BlobFileGb) GB blob/file)" -DefaultColor 'White'
                    $unitContext = Get-FinOpsUnitCostContext -Data $data
                    Write-FinOpsConsole "    $($unitContext.Summary)" -ForegroundColor DarkGray
                    if ($data.Note) { Write-FinOpsConsole "    $($data.Note)" -ForegroundColor DarkGray }
                    $rows = @(
                        [PSCustomObject]@{ Metric = 'Cost per vCPU'; Value = (Format-FinOpsUnitRate -Value $data.CostPerVCpu -Currency $data.Currency) }
                        [PSCustomObject]@{ Metric = 'Cost per GB RAM'; Value = (Format-FinOpsUnitRate -Value $data.CostPerGbRam -Currency $data.Currency) }
                        [PSCustomObject]@{ Metric = 'Cost per VM'; Value = (Format-FinOpsUnitRate -Value $data.CostPerVm -Currency $data.Currency) }
                        [PSCustomObject]@{ Metric = 'Cost per GB stored'; Value = (Format-FinOpsUnitRate -Value $data.CostPerGb -Currency $data.Currency) }
                    )
                    $cols = @('Metric', 'Value')
                }
                'Get-AIWorkloadMetrics' {
                    if (-not $data.HasData) {
                        Write-FinOpsConsole "    No AI workloads detected — AI KPIs skipped." -ForegroundColor Green
                    }
                    else {
                        $fp = $data.AIFootprint
                        $periodLabel = if ($data.Period -eq 'MonthToDate') { 'Month to date' } elseif ($data.Period) { [string]$data.Period } else { 'Unknown period' }
                        Write-ColorizedLine -Text "    AI footprint — OpenAI/AIServices: $($fp.OpenAIAccounts + $fp.AIServices)  ML workspaces: $($fp.MLWorkspaces)  AI Search: $($fp.SearchServices)  GPU VMs: $($fp.GpuVmCount)" -DefaultColor 'White'
                        Write-ColorizedLine -Text "    Period: $periodLabel" -DefaultColor 'White'
                        Write-ColorizedLine -Text "    Tokens: $(Format-ReportMetric $data.TotalTokens)  |  Requests: $(Format-ReportMetric $data.TotalRequests)" -DefaultColor 'White'
                        Write-ColorizedLine -Text "    AI spend: $(Format-BudgetAmount -Value $data.TotalAICost -Currency $data.Currency)  |  $(Format-FinOpsUnitRate -Value $data.CostPer1KTokens -Currency $data.Currency)/1K tokens  |  $(Format-FinOpsUnitRate -Value $data.CostPerRequest -Currency $data.Currency)/request" -DefaultColor 'White'
                        if ($data.Note) { Write-FinOpsConsole "    $($data.Note)" -ForegroundColor DarkGray }
                        if ($data.ByModel -and @($data.ByModel).Count -gt 0) {
                            $rows = $data.ByModel
                            $cols = @('Account', 'Deployment', 'PromptTokens', 'GeneratedTokens', 'TotalTokens', 'TokenBasis')
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
                        ForEach-Object { $_.TrimEnd() -split '\r?\n' | Where-Object { $_.Trim() } }
                        if ($headerStr.Count -ge 2) {
                            Write-FinOpsConsole "    $($headerStr[0])" -ForegroundColor Cyan
                            Write-FinOpsConsole "    $($headerStr[1])" -ForegroundColor DarkCyan
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
                        ForEach-Object { $_.TrimEnd() -split '\r?\n' | Where-Object { $_.Trim() } }
                        $headerDone = $false
                        foreach ($line in $tableLines) {
                            if (-not $headerDone) {
                                # First two lines are header + separator
                                if ($line -match '^[\s\-]+$') {
                                    Write-FinOpsConsole "    $line" -ForegroundColor DarkCyan
                                    $headerDone = $true
                                }
                                else {
                                    Write-FinOpsConsole "    $line" -ForegroundColor Cyan
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
                Write-FinOpsConsole "    (no findings)" -ForegroundColor DarkGray
            }

            $scanContext = Get-FinOpsScanContext -FunctionName $mod.Fn -Data $data
            if ($scanContext) {
                Write-FinOpsConsole "    $($scanContext.Summary)" -ForegroundColor DarkGray
                foreach ($description in $scanContext.Details) { Write-FinOpsConsole "    $description" -ForegroundColor DarkGray }
            }

            # -- FinOps KPI Insights ---------------------------------------
            # Map this scan's result to the FinOps Foundation KPIs it informs,
            # with a computed value where the data allows. Reuses the same
            # catalog + compute path in both entry points (parity).
            if (Get-Command Get-KpiInsightsForResult -ErrorAction SilentlyContinue) {
                $kpiInsights = @()
                try { $kpiInsights = @(Get-KpiInsightsForResult -FunctionName $mod.Fn -Output $data) } catch { $kpiInsights = @() }
                foreach ($kpi in $kpiInsights) {
                    # One entry per KPI. A computed value replaces an informational one.
                    $existingKpi = $kpiCollected | Where-Object { $_.kpiId -eq $kpi.kpiId } | Select-Object -First 1
                    if (-not $existingKpi) {
                        [void]$kpiCollected.Add($kpi)
                    }
                    elseif ($existingKpi.status -ne 'computed' -and $kpi.status -eq 'computed') {
                        [void]$kpiCollected.Remove($existingKpi)
                        [void]$kpiCollected.Add($kpi)
                    }
                }
                if ($kpiInsights.Count -gt 0) {
                    Write-FinOpsConsole ""
                    Write-FinOpsConsole "    FinOps KPIs:" -ForegroundColor Cyan
                    foreach ($kpi in $kpiInsights) {
                        if ($kpi.status -eq 'computed' -and $kpi.yourValue) {
                            Write-FinOpsConsole "    - $($kpi.kpiName): " -ForegroundColor White -NoNewline
                            Write-FinOpsConsole "$($kpi.yourValue)" -ForegroundColor Green -NoNewline
                            Write-FinOpsConsole "  [$($kpi.domain)]" -ForegroundColor DarkGray
                        }
                        else {
                            Write-FinOpsConsole "    - $($kpi.kpiName) " -ForegroundColor DarkGray -NoNewline
                            Write-FinOpsConsole "(informational, $($kpi.domain))" -ForegroundColor DarkGray
                        }
                    }
                }
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
                    if ($data.MetricFailures -gt 0) {
                        $guidanceItems = @(@{ Severity = 'Yellow'; Message = "VM utilization coverage is incomplete: $($data.MetricFailures) VMs have unavailable metrics. Review the $idleCount candidates found among evaluated VMs." })
                    }
                    elseif ($idleCount -gt 5) {
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
                            @{ Severity = 'Yellow'; Message = "No VMs met the idle thresholds in the available measurements. This does not establish that compute spend is optimized." }
                        )
                    }
                }
                'Get-StorageTierAdvice' {
                    $recoCount = if ($data.Recommendations) { @($data.Recommendations).Count } else { 0 }
                    if ($data.MetricFailures -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "Storage tier assessment is incomplete: $($data.MetricFailures) account(s) have unavailable metrics. $recoCount candidate(s) were found among evaluated accounts; unread accounts are not assumed optimized." }
                        )
                    }
                    elseif ($recoCount -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "$recoCount storage accounts meet the scan's activity thresholds for a tier review. Validate blob access patterns, retrieval needs, retention charges, and supported tiers before making changes." }
                            @{ Severity = 'Yellow'; Message = 'Review lifecycle management rules for eligible blobs; account-level metrics alone do not prove a tier change will save money.'; Docs = 'https://learn.microsoft.com/azure/storage/blobs/lifecycle-management-overview' }
                        )
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = 'No tier candidates met the scan thresholds in the available measurements. This does not establish that every blob is appropriately tiered.' }
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
                    if ($data.CoverageIncomplete -or $null -eq $data.TagCoverage) {
                        $guidanceItems = @(@{ Severity = 'Yellow'; Message = if ($data.Note) { [string]$data.Note } else { 'Tag coverage is unverified because inventory measurements are incomplete.' } })
                    }
                    elseif ($coverage -lt 30) {
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

                    # Case variants are independent of coverage, so append rather than replace.
                    if ($data.CaseVariants -and @($data.CaseVariants).Count -gt 0) {
                        $cvCount = @($data.CaseVariants).Count
                        $cvWord = if ($cvCount -eq 1) { 'tag key is' } else { 'tag keys are' }
                        $guidanceItems += @{ Severity = 'Yellow'; Message = "$cvCount $cvWord applied under more than one spelling. Azure resolves tag keys case-insensitively, so these are a single key to Azure, but Resource Graph and cost exports report each spelling separately." }
                        foreach ($cv in @($data.CaseVariants)) {
                            $guidanceItems += @{ Severity = 'Yellow'; Message = "$($cv.TagKey): $($cv.Detail). Standardize on one spelling, then retag the others." }
                        }
                        $guidanceItems += @{ Severity = 'Yellow'; Message = "Azure Policy 'Require a tag and its value' enforces the key name at deployment, which prevents new variants."; Docs = 'https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging' }
                    }
                }
                'Get-CostByTag' {
                    if ($data.CoverageIncomplete) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = [string]$data.Note }
                        )
                    }
                    elseif ($data.CostByTag -and $data.CostByTag.Count -gt 0) {
                        # Only measure untagged spend against CAF allocation tags
                        # (CostCenter, Customer, Project, Environment, ...), not
                        # identity/marker tags like FinOps or cm-resource-parent
                        # that blanket resources and skew the figure. Same tag set
                        # the FinOps KPI uses, so the guidance and the KPI agree.
                        $allocTags = if (Get-Command Get-CafAllocationTag -ErrorAction SilentlyContinue) {
                            Get-CafAllocationTag
                        }
                        else {
                            @('CostCenter', 'Customer', 'Project', 'Environment', 'Application', 'ApplicationName',
                                'Owner', 'BusinessUnit', 'Department', 'Team', 'OpsTeam', 'Service', 'WorkloadName')
                        }
                        # Prefer the per-resource allocation figure so the guidance
                        # and the FinOps KPI report the same number. Falls back to
                        # the largest single-tag gap when a run aggregated
                        # server-side and never walked resources.
                        $maxUntaggedCost = 0
                        $maxUntaggedTag = ''
                        $seenCost = $data.ResourceCostSeen
                        $unallocCost = $data.UnallocatedCost
                        $tagCostRows = @($data.CostByTag.Values | ForEach-Object { $_ } | Where-Object { $null -ne $_.Cost })
                        $tagCurrencies = @($tagCostRows.Currency | Where-Object { $_ } | Select-Object -Unique)
                        $guidanceCurrency = if ($tagCurrencies.Count -eq 1) { $tagCurrencies[0] } else { $null }
                        $allocationTags = @($data.CostByTag.Keys | Where-Object { $allocTags -contains $_ })
                        $haveResourceTotals = $null -ne $seenCost -and $null -ne $unallocCost
                        $haveCostData = $haveResourceTotals -or $tagCostRows.Count -gt 0
                        $havePositiveCost = [double]$seenCost -gt 0
                        $hasCredits = @($tagCostRows | Where-Object { [double]$_.Cost -lt 0 }).Count -gt 0
                        if ($haveResourceTotals) {
                            $maxUntaggedCost = [double]$unallocCost
                            $maxUntaggedTag = 'any allocation tag'
                            $hasCredits = $hasCredits -or [double]$unallocCost -lt 0 -or [double]$unallocCost -gt [double]$seenCost
                        }
                        else {
                            foreach ($tag in $data.CostByTag.GetEnumerator()) {
                                if (($tag.Value | Measure-Object Cost -Sum).Sum -gt 0) { $havePositiveCost = $true }
                                if ($allocTags -notcontains $tag.Key) { continue }
                                foreach ($tagValue in $tag.Value) {
                                    if ($tagValue.TagValue -eq '(untagged)' -and [double]$tagValue.Cost -gt $maxUntaggedCost) {
                                        $maxUntaggedCost = [double]$tagValue.Cost
                                        $maxUntaggedTag = $tag.Key
                                    }
                                }
                            }
                        }
                        if (-not $haveCostData) {
                            # Nothing to attribute. Blaming the tags here would be wrong:
                            # the tag inventory is fine, the cost side came back empty.
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "No cost data was returned for this period, so spend cannot be split by tag. Tag coverage itself is unaffected - check the data source, permissions, and that the period has usage." }
                            )
                        }
                        elseif ($allocationTags.Count -eq 0) {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "No CAF allocation tag (CostCenter, Customer, Project, Environment, Owner, ...) is in use, so spend cannot be attributed. Add an allocation tag and deploy inheritance to make cost traceable." }
                            )
                        }
                        elseif ($hasCredits) {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = 'Cost data includes credits or negative net costs. Review the amounts by tag; allocation percentages might not be comparable.' }
                            )
                        }
                        elseif (-not $havePositiveCost) {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = 'Cost data is available, but there is no positive net cost for allocation percentages.' }
                            )
                        }
                        elseif ($maxUntaggedCost -gt 1000) {
                            $guidanceItems = @(
                                @{ Severity = 'Red'; Message = "Untagged spend: $(Format-BudgetAmount -Value $maxUntaggedCost -Currency $guidanceCurrency) not allocated by '$maxUntaggedTag'. Review the missing allocation evidence." }
                                @{ Severity = 'Red'; Message = "FinOps Impact: Untagged spend creates 'shadow IT' — no one owns it, no one optimizes it." }
                                @{ Severity = 'Yellow'; Message = "Use Cost Management tag views to identify the highest-cost resources missing '$maxUntaggedTag' and tag them first." }
                            )
                        }
                        elseif ($maxUntaggedCost -gt 0) {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "Some untagged spend detected: $(Format-BudgetAmount -Value $maxUntaggedCost -Currency $guidanceCurrency) not allocated by '$maxUntaggedTag'. Tag remaining resources for full cost traceability." }
                            )
                        }
                        else {
                            $guidanceItems = @(
                                @{ Severity = 'Green'; Message = 'No positive untagged cost was found for the allocation tags in this result.' }
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
                    $nowUtc = if ($data.CostPeriodEndUtc) { ([datetime]$data.CostPeriodEndUtc).ToUniversalTime() } else { (Get-Date).ToUniversalTime() }
                    $currentMonthStart = $nowUtc.Date.AddDays(1 - $nowUtc.Day)
                    $completedMonths = @($data.Months | Where-Object { $_.MonthDate -and [datetime]$_.MonthDate -lt $currentMonthStart } |
                        Sort-Object { [datetime]$_.MonthDate } -Descending | Select-Object -First 2)
                    if ($completedMonths.Count -lt 2) {
                        $guidanceItems = @(@{ Severity = 'Yellow'; Message = 'A month-over-month comparison needs two completed months. The current month is partial and is excluded.' })
                    }
                    elseif (-not $completedMonths[0].Currency -or -not $completedMonths[1].Currency -or
                        $completedMonths[0].Currency -eq 'Mixed' -or $completedMonths[0].Currency -ne $completedMonths[1].Currency) {
                        $guidanceItems = @(@{ Severity = 'Yellow'; Message = 'The completed months have unknown or different currencies. A month-over-month percentage is unavailable.' })
                    }
                    else {
                        $latestDate = [datetime]$completedMonths[0].MonthDate
                        $previousDate = [datetime]$completedMonths[1].MonthDate
                        $latestMonth = $latestDate.Date.AddDays(1 - $latestDate.Day)
                        $previousMonth = $previousDate.Date.AddDays(1 - $previousDate.Day)
                        if ($previousMonth.AddMonths(1) -ne $latestMonth) {
                            $guidanceItems = @(@{ Severity = 'Yellow'; Message = 'The result does not contain two consecutive completed months. A month-over-month percentage is unavailable.' })
                        }
                        elseif ([double]$completedMonths[1].Cost -le 0) {
                            $guidanceItems = @(@{ Severity = 'Yellow'; Message = 'The previous completed month has no positive net cost. A month-over-month percentage is unavailable.' })
                        }
                        else {
                            $change = [math]::Round((([double]$completedMonths[0].Cost - [double]$completedMonths[1].Cost) / [double]$completedMonths[1].Cost) * 100, 1)
                            $direction = if ($change -lt 0) { 'decreased' } elseif ($change -gt 0) { 'increased' } else { 'changed' }
                            $previousLabel = $previousMonth.ToString('MMM yyyy', [cultureinfo]::InvariantCulture)
                            $latestLabel = $latestMonth.ToString('MMM yyyy', [cultureinfo]::InvariantCulture)
                            $guidanceItems = @(
                                @{ Severity = $(if ($change -gt 20) { 'Red' } else { 'Yellow' }); Message = "Observed spend $direction $([math]::Abs($change))% from $previousLabel to $latestLabel ($($completedMonths[0].Currency)). The partial current month is excluded." }
                                @{ Severity = 'Yellow'; Message = 'A change in spend can reflect usage, prices, credits, or optimization. Review the cost drivers before attributing savings.' }
                            )
                        }
                    }
                    if ($data.CoverageIncomplete) {
                        $guidanceItems = @(@{ Severity = 'Yellow'; Message = 'The trend covers returned rows, not a verified total for every selected subscription. Changes may reflect differences in coverage.' }) + $guidanceItems
                    }
                }
                'Get-ReservationAdvice' {
                    if ($data.CostIssue) {
                        $guidanceItems = @(@{ Severity = 'Yellow'; Message = [string]$data.CostIssue })
                    }
                    elseif ($data.AdvisorRecommendations -and @($data.AdvisorRecommendations).Count -gt 0) {
                        $totalSavings = if ($data.EstimatedAnnualSavings) { $data.EstimatedAnnualSavings } else { 0 }
                        if ($totalSavings -gt 10000) {
                            $guidanceItems = @(
                                @{ Severity = 'Red'; Message = "Estimated reservation savings: $(Format-BudgetAmount -Value $data.EstimatedAnnualSavings -Currency $data.Currency)/year." }
                                @{ Severity = 'Red'; Message = "FinOps Principle: Commitment-based discounts (RIs, Savings Plans) are the single largest cost lever — typically 30-60% savings." }
                                @{ Severity = 'Yellow'; Message = "Start with 1-year terms for flexibility. Use shared scope to maximize utilization across subscriptions." }
                                @{ Severity = 'Yellow'; Message = "Review 14-day usage trends before purchasing to ensure steady-state workloads."; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/reservations/save-compute-costs-reservations' }
                            )
                        }
                        else {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "Estimated reservation savings: $(Format-BudgetAmount -Value $data.EstimatedAnnualSavings -Currency $data.Currency)/year. Review the individual recommendations for steady-state workloads." }
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
                        $knownUtilization = @(
                            if ($data.RICount -gt 0 -and $null -ne $data.RIAvgUtilization) { [double]$data.RIAvgUtilization }
                            if ($data.SPCount -gt 0 -and $null -ne $data.SPAvgUtilization) { [double]$data.SPAvgUtilization }
                        )
                        $minimumAverage = ($knownUtilization | Measure-Object -Minimum).Minimum
                        if ($data.CoverageIncomplete -or $data.UnscopedFallback -or $knownUtilization.Count -eq 0) {
                            $guidanceItems = @(@{ Severity = 'Yellow'; Message = 'Overall commitment utilization is unavailable or its scope is unverified. Review the returned commitments and coverage notes; missing values are not zero utilization.' })
                        }
                        elseif ($minimumAverage -lt 80) {
                            $guidanceItems = @(
                                @{ Severity = 'Red'; Message = 'Reported average commitment utilization is below 80%. Review eligible usage, scope, and SKU alignment before changing purchases.' }
                                @{ Severity = 'Yellow'; Message = 'Exchange and refund options depend on the reservation product and current eligibility rules.'; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/reservations/manage-reserved-vm-instance' }
                            )
                        }
                        elseif ($minimumAverage -lt 95) {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = 'Reported average commitment utilization is below 95%. Review whether benefit scope and eligible demand still match the purchase.' }
                            )
                        }
                        else {
                            $guidanceItems = @(
                                @{ Severity = 'Green'; Message = 'Reported average commitment utilization is at least 95%. This is utilization evidence, not a measurement of financial savings.' }
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
                    if ($data.CommitmentSavingsMonthToDate -gt 0 -or $data.AHBSavingsMonthly -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = 'Estimated savings use assumed discounts. Commitment amounts cover the reported month-to-date period; AHB uses a separate 730-hour estimate. They are not combined or annualized.' }
                            @{ Severity = 'Yellow'; Message = 'Validate the estimate against matching pay-as-you-go rates and benefit usage before reporting savings.' }
                        )
                    }
                    else {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = 'No positive savings estimate is available from this scan. Review commitment usage and data access before drawing a conclusion.' }
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
                    elseif ($data.CoverageIncomplete) {
                        if ($data.Sampled) {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "No budgets were returned from $($data.ScannedSubs) sampled subscriptions; the remaining selections were not queried. This is a sampling limit, not evidence of denied access." }
                                @{ Severity = 'Yellow'; Message = 'Run smaller subscription selections to query every selected subscription. This scan reads subscription budgets, not resource-group, management-group, or billing-scope budgets.'; Docs = 'https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets' }
                            )
                        }
                        else {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "Budgets were read for $($data.ScannedSubs) of $($data.TotalSubs) subscriptions. Review the recorded failures before concluding whether access, throttling, or another error caused the gap." }
                            )
                        }
                    }
                    elseif (@($data.Budgets | Where-Object { $null -eq $_.Amount -or $null -eq $_.ActualSpend -or $null -eq $_.Forecast -or $_.Risk -in @('Unknown', 'Forecast unavailable') }).Count -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = 'Budget health is unverified because an amount, current spend, or forecast is unavailable. Review the notes for each budget.' }
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
                    if ($data.CoverageIncomplete) {
                        $guidanceItems = @(@{ Severity = 'Yellow'; Message = [string]$data.Note })
                    }
                    elseif ($activeAlerts -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "$activeAlerts active anomaly alerts. Review to determine if they indicate unexpected spend patterns." }
                            @{ Severity = 'Yellow'; Message = "FinOps Practice: Cost anomaly detection is an early warning system. Investigate anomalies promptly." }
                        )
                    }
                    elseif ($rules -eq 0) {
                        $noRuleMessage = if (@($data.ConfiguredRules).Count -gt 0) { 'Anomaly alert rules exist but none are enabled. Enable a rule for early spend warnings.' } else { 'No anomaly detection rules configured. Set up Cost Management anomaly alerts for early spend warnings.' }
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = $noRuleMessage }
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
                    if ($data.ComplianceCoverageIncomplete) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = 'Policy compliance coverage is incomplete. Review failed scopes before using a compliance percentage or concluding that no violations exist.' }
                        )
                    }
                    elseif (-not $hasComplianceData) {
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
                    if ($data.DefinitionCoverageIncomplete) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = 'Policy definition coverage is incomplete. Review the unreadable definitions before drawing conclusions about unresolved effects.' }
                        ) + @($guidanceItems | Where-Object { $_.Severity -ne 'Green' })
                    }
                }
                'Get-PolicyRecommendations' {
                    if ($data.Analysis -and @($data.Analysis).Count -gt 0) {
                        $missing = @($data.Analysis | Where-Object { $_.Status -eq 'Missing' })
                        if ($data.CoverageIncomplete) {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = 'Some initiative definitions could not be read. Unmatched policies are Unknown, not confirmed missing. Review the initiative lookup errors.' }
                            )
                        }
                        elseif ($missing.Count -gt 0) {
                            $guidanceItems = @(
                                @{ Severity = 'Yellow'; Message = "$($missing.Count) recommended definition IDs were not found in the reported assignments or their initiatives. Check equivalent custom policies and intended scopes before making changes." }
                            )
                        }
                        else {
                            $guidanceItems = @(
                                @{ Severity = 'Green'; Message = 'All recommended definition IDs were found in the reported assignments or their initiatives.' }
                            )
                        }
                        $guidanceItems += @{ Severity = 'Yellow'; Message = 'Assignment presence does not prove enforcement or compliance. Review scopes, exclusions, parameters, and enforcement modes.'; Docs = 'https://learn.microsoft.com/azure/governance/policy/concepts/initiative-definition-structure' }
                    }
                }
                'Get-OptimizationAdvice' {
                    if ($data.CoverageIncomplete) {
                        $guidanceItems = @(@{ Severity = 'Yellow'; Message = [string]$data.Note })
                    }
                    elseif ($data.CostIssue) {
                        $guidanceItems = @(@{ Severity = 'Yellow'; Message = [string]$data.CostIssue })
                    }
                    elseif ($data.Recommendations -and @($data.Recommendations).Count -gt 0) {
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
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = 'Actual costs and forecasts are separate amounts. Compare subscriptions only when their currencies and reporting periods match.' }
                            @{ Severity = 'Green'; Message = "FinOps Practice: Review actual vs. forecast regularly. Pair this data with Budget Status to track variance." }
                        )
                    }
                }
                'Get-ResourceCosts' {
                    $topCount = if ($data) { @($data).Count } else { 0 }
                    if ($topCount -gt 0) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = 'Review the largest resource costs for changes in demand or unused capacity. A high cost alone does not establish waste.' }
                        )
                    }
                }
                'Get-AIWorkloadMetrics' {
                    $periodLabel = if ($data.Period -eq 'MonthToDate') { 'Month to date' } elseif ($data.Period) { [string]$data.Period } else { 'Unknown period' }
                    if (-not $data.HasData) {
                        $guidanceItems = @(
                            @{ Severity = 'Green'; Message = "No AI/LLM workloads detected. No AI-specific cost optimization needed right now." }
                        )
                    }
                    elseif ($data.CostIssue -or $data.RateIssue) {
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = if ($data.RateIssue) { [string]$data.RateIssue } else { [string]$data.CostIssue } }
                        )
                    }
                    elseif ($data.CostPer1KTokens -gt 0) {
                        $periodLabel = if ($data.Period -eq 'MonthToDate') { 'Month to date' } elseif ($data.Period) { [string]$data.Period } else { 'Unknown period' }
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "Effective AI rate: $($data.Currency) $($data.CostPer1KTokens) per 1K tokens across $($data.TotalTokens) tokens ($periodLabel). Track this as your core AI unit-economics KPI." }
                            @{ Severity = 'Yellow'; Message = "Compare model deployments above — shift high-volume traffic to cheaper SKUs (e.g., gpt-4o-mini) and reserve premium models for tasks that need them." }
                            @{ Severity = 'Yellow'; Message = "For steady, predictable token volume, evaluate Provisioned Throughput Units (PTUs) — they can beat pay-as-you-go at scale."; Docs = 'https://learn.microsoft.com/azure/ai-services/openai/concepts/provisioned-throughput' }
                        )
                    }
                    elseif ($data.TotalTokens -gt 0) {
                        $periodLabel = if ($data.Period -eq 'MonthToDate') { 'Month to date' } elseif ($data.Period) { [string]$data.Period } else { 'Unknown period' }
                        $guidanceItems = @(
                            @{ Severity = 'Yellow'; Message = "Token usage detected ($($data.TotalTokens), $periodLabel) but cost could not be mapped. Grant Cost Management Reader to compute cost per 1K tokens." }
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
                $guidanceByFn[$mod.Fn] = $guidanceItems
                Write-FinOpsConsole ""
                # Determine overall severity for the header
                $hasCritical = $guidanceItems | Where-Object { $_.Severity -eq 'Red' }
                $hasWarning = $guidanceItems | Where-Object { $_.Severity -eq 'Yellow' }
                $headerColor = if ($hasCritical) { 'Red' } elseif ($hasWarning) { 'Yellow' } else { 'Green' }
                $headerIcon = switch ($headerColor) { 'Red' { '[!]' } 'Yellow' { '[~]' } 'Green' { '[+]' } }
                Write-FinOpsConsole "    $headerIcon GUIDANCE" -ForegroundColor $headerColor

                foreach ($item in $guidanceItems) {
                    $color = switch ($item.Severity) { 'Red' { 'Red' } 'Yellow' { 'DarkYellow' } 'Green' { 'Green' } default { 'Gray' } }
                    $icon = switch ($item.Severity) { 'Red' { '!' } 'Yellow' { '~' } 'Green' { '+' } default { '-' } }
                    Write-FinOpsConsole "    $icon $($item.Message)" -ForegroundColor $color
                    if ($item.Docs) {
                        Write-FinOpsConsole "      $($item.Docs)" -ForegroundColor DarkCyan
                    }
                }
            }

            Write-FinOpsConsole ""
        }

        $exportDir = $null
        try {
            $exportDir = New-FinOpsReportDirectory -OutputPath $ExportPath -ErrorAction Stop

            # -- CSV exports per module --
            foreach ($mod in ($Modules | Where-Object { $_.Selected })) {
                $data = $Results[$mod.Fn]
                $hasScanError = $Results.ContainsKey("_error_$($mod.Fn)")
                $exportRows = @(if (-not $hasScanError) { ConvertTo-FinOpsExportRows -Fn $mod.Fn -Data $data })
                if ($exportRows.Count -eq 0) {
                    $errorMessage = $Results["_error_$($mod.Fn)"]
                    $statusRow = [pscustomobject]@{
                        RecordType = 'Status'
                        Scan       = $mod.Fn
                        Status     = if ($hasScanError) { 'Error' } else { 'No data' }
                        Error      = $errorMessage
                    }
                    $exportRows = @(ConvertTo-FinOpsExportRows -Fn 'ReportStatus' -Data $statusRow)
                }
                $safeName = $mod.Fn -replace '[^a-zA-Z0-9\-]', ''
                Write-FinOpsReportFile -Directory $exportDir -Name "$safeName.csv" -Lines @($exportRows | ConvertTo-Csv -NoTypeInformation -ErrorAction Stop) -ErrorAction Stop
            }

            # -- HTML report --
            $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'", [cultureinfo]::InvariantCulture)
            $subList = if ($Subscriptions) { ($Subscriptions | ForEach-Object { if ($_.Name) { $_.Name } else { $_.Id } }) -join ', ' } else { 'N/A' }
            $headerScope = if (@($Subscriptions).Count -gt 5) { "$(@($Subscriptions).Count) selected" } else { $subList }
            $htmlSb = [System.Text.StringBuilder]::new()
            [void]$htmlSb.Append(@"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>FinOps Multitool Report &mdash; $timestamp</title>
<style>
:root {
  --energy-blue: #0000B3; --blue: #0078D4; --navy: #0D0061; --deep-blue: #000085;
  --indigo: #5D52EC; --turquoise: #00BBC3; --mint: #CFF3E8; --lavender: #AAC0FC;
  --light-gray: #D9D9D6; --surface: #F7F7F5; --ink: #1A1A1A; --muted: #5A5A5A;
  --danger: #C42B1C; --warning: #8A5300; --success: #0F7B0F;
}
* { box-sizing: border-box; }
body { font-family: 'Segoe Sans Display', 'Segoe UI Variable Display', 'Segoe UI', system-ui, -apple-system, sans-serif; background: #FFFFFF; color: var(--ink); margin: 0; padding: 0 0 48px 0; }
.masthead { background: var(--navy); color: #FFFFFF; padding: 28px 40px 24px 40px; }
.masthead .eyebrow { font-size: 11px; font-weight: 600; letter-spacing: 0.14em; text-transform: uppercase; color: var(--lavender); margin-bottom: 6px; }
.masthead h1 { font-size: 30px; font-weight: 300; margin: 0 0 10px 0; letter-spacing: -0.01em; color: #FFFFFF; }
.masthead .meta { color: #C5CBE8; font-size: 13px; margin: 0; }
.wrap { padding: 0 40px; }
h2 { color: var(--energy-blue); font-size: 19px; font-weight: 600; margin: 30px 0 4px 0; padding-bottom: 8px; border-bottom: 1px solid var(--light-gray); }
h3 { color: var(--navy); font-size: 12px; font-weight: 600; letter-spacing: 0.1em; text-transform: uppercase; margin: 22px 0 4px 0; }
.summary-grid { display: flex; flex-wrap: wrap; gap: 12px; margin: 24px 0 4px 0; }
.summary-card { background: var(--surface); border: 1px solid var(--light-gray); border-top: 3px solid var(--blue); border-radius: 6px; padding: 12px 18px; min-width: 170px; }
.summary-card .label { color: var(--muted); font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.1em; }
.summary-card .value { font-size: 24px; font-weight: 600; color: var(--navy); margin-top: 2px; }
.tabs { display: flex; flex-wrap: wrap; gap: 2px; border-bottom: 2px solid var(--light-gray); margin: 22px 0 0 0; position: sticky; top: 0; background: #FFFFFF; z-index: 10; }
.tab { font: inherit; font-size: 12px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); background: none; border: 0; border-bottom: 3px solid transparent; margin-bottom: -2px; padding: 11px 16px; cursor: pointer; }
.tab:hover { color: var(--energy-blue); background: var(--surface); }
.tab.active { color: var(--energy-blue); border-bottom-color: var(--energy-blue); }
.tabpane { display: none; }
.tabpane.active { display: block; }
table { border-collapse: collapse; width: 100%; margin: 12px 0 22px 0; font-size: 13px; }
th { background: var(--surface); color: var(--navy); text-align: left; padding: 9px 12px; border-bottom: 2px solid var(--light-gray); font-weight: 600; font-size: 11px; letter-spacing: 0.06em; text-transform: uppercase; }
td { padding: 7px 12px; border-bottom: 1px solid #ECECEA; vertical-align: top; overflow-wrap: anywhere; }
tr:hover td { background: var(--surface); }
.severity-red { color: var(--danger); font-weight: 600; }
.severity-yellow { color: var(--warning); font-weight: 600; }
.severity-green { color: var(--success); font-weight: 600; }
.guidance { background: var(--surface); border-left: 4px solid var(--light-gray); padding: 11px 16px; margin: 8px 0 16px 0; border-radius: 0 4px 4px 0; font-size: 13px; }
.guidance.red { border-left-color: var(--danger); }
.guidance.yellow { border-left-color: var(--warning); }
.guidance.green { border-left-color: var(--success); }
.guidance a { color: var(--blue); text-decoration: none; overflow-wrap: anywhere; }
.guidance a:hover { text-decoration: underline; }
.table-note { color: var(--muted); font-size: 12px; font-style: italic; margin: -14px 0 22px 0; max-width: 74ch; }
.story-intro { font-size: 14px; color: var(--ink); max-width: 78ch; margin: 20px 0 4px 0; }
.story-summary { font-size: 15px; font-weight: 600; color: var(--navy); margin: 10px 0 4px 0; }
.story-detail { font-size: 13px; color: var(--muted); max-width: 78ch; margin: 0 0 14px 0; }
.story-caps { font-size: 11px; font-weight: 600; letter-spacing: 0.06em; text-transform: uppercase; color: var(--muted); margin: 0 0 26px 0; }
.story-meta { display: grid; grid-template-columns: minmax(7rem, 11rem) minmax(0, 1fr); gap: 8px 16px; margin: 20px 0; font-size: 13px; }
.story-meta dt { font-weight: 600; color: var(--muted); }
.story-meta dd { margin: 0; overflow-wrap: anywhere; }
.table-scroll { width: 100%; max-width: 100%; overflow-x: auto; }
.report-table { table-layout: fixed; min-width: 48rem; }
.report-table td { overflow-wrap: break-word; word-break: normal; }
.table-cost-by-tag { table-layout: auto; min-width: 36rem; }
.report-table th { overflow-wrap: normal; word-break: normal; }
.report-table .numeric-cell { text-align: right; white-space: nowrap; font-variant-numeric: tabular-nums; }
.cost-trend { margin: 16px 0; }
.cost-trend [hidden] { display: none !important; }
.trend-controls { display: flex; flex-wrap: wrap; align-items: end; gap: 16px 24px; margin: 18px 0; }
.trend-modes { border: 0; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: 0; min-width: 0; }
.trend-modes legend, .trend-subscription-control label { font-size: 13px; font-weight: 600; margin-bottom: 6px; display: block; }
.trend-modes label { display: flex; align-items: center; gap: 6px; min-height: 38px; padding: 8px 12px; border: 1px solid #767676; background: var(--surface); font-size: 13px; cursor: pointer; }
.trend-modes label:has(input:checked) { border-color: var(--energy-blue); color: var(--energy-blue); background: var(--mint); }
.trend-modes input { margin: 0; accent-color: var(--energy-blue); }
.trend-subscription-control { flex: 1 1 20rem; min-width: 0; max-width: 42rem; }
.trend-subscription-control select { width: 100%; min-width: 0; min-height: 38px; padding: 7px; border: 1px solid #767676; border-radius: 4px; background: #FFFFFF; color: var(--ink); font: inherit; font-size: 13px; }
.trend-series h4 { font-size: 15px; margin: 16px 0 8px; overflow-wrap: anywhere; }
.trend-series code { font-size: 12px; overflow-wrap: anywhere; }
.trend-status { font-size: 13px; color: var(--muted); overflow-wrap: anywhere; }
.table-trend { min-width: 30rem; }
.table-trend th:nth-child(1) { width: 45%; }
.table-trend th:nth-child(2) { width: 35%; text-align: right; }
.table-trend th:nth-child(3) { width: 20%; }
.table-tags { min-width: 50rem; }
.table-tags col:nth-child(1) { width: 26%; }
.table-tags col:nth-child(2) { width: 12%; }
.table-tags col:nth-child(3) { width: 10%; }
.table-tags col:nth-child(4) { width: 52%; }
.table-policies { min-width: 56rem; }
.table-policies col:nth-child(1) { width: 30%; }
.table-policies col:nth-child(2) { width: 19%; }
.table-policies col:nth-child(3) { width: 13%; }
.table-policies col:nth-child(4) { width: 12%; }
.table-policies col:nth-child(5) { width: 26%; }
.table-cost-summary { min-width: 64rem; }
.table-cost-summary col:nth-child(1) { width: 25%; }
.table-cost-summary col:nth-child(2) { width: 16%; }
.table-cost-summary col:nth-child(3) { width: 25%; }
.table-cost-summary col:nth-child(4) { width: 18%; }
.table-cost-summary col:nth-child(5) { width: 16%; }
.table-cost-drivers { min-width: 64rem; }
.table-cost-drivers col:nth-child(1) { width: 20%; }
.table-cost-drivers col:nth-child(2) { width: 36%; }
.table-cost-drivers col:nth-child(3) { width: 16%; }
.table-cost-drivers col:nth-child(4) { width: 12%; }
.table-cost-drivers col:nth-child(5) { width: 16%; }
.scope-details summary, .tag-case-details summary, .cell-details summary { cursor: pointer; color: var(--energy-blue); font-weight: 600; line-height: 1.5; padding: 4px 0; }
.scope-details { max-width: 100%; }
.scope-list { list-style: none; padding: 0; margin: 8px 0; max-height: 18rem; overflow-y: auto; }
.scope-list li { display: grid; grid-template-columns: minmax(10rem, 1fr) minmax(16rem, 1fr); gap: 8px 16px; padding: 8px 4px; border-bottom: 1px solid var(--light-gray); }
.scope-list code, .detail-content code { overflow-wrap: anywhere; font-size: 12px; }
.tag-case-details { border-left: 4px solid var(--warning); background: var(--surface); padding: 8px 14px; margin: 12px 0; font-size: 13px; }
.tag-case-details p { max-width: 85ch; }
.cell-details { margin-top: 6px; }
.cell-preview { margin: 0; line-height: 1.5; }
.detail-content { max-height: 18rem; overflow-y: auto; overflow-wrap: anywhere; padding-right: 8px; }
.detail-content dl { margin: 8px 0; }
.detail-content dt { font-weight: 600; margin-top: 10px; }
.detail-content dd { margin: 4px 0 12px; line-height: 1.5; }
.detail-list { list-style: none; margin: 8px 0; padding: 0; }
.detail-list li { padding: 6px 0; border-bottom: 1px solid var(--light-gray); line-height: 1.5; }
.report-table-controls { display: flex; align-items: end; flex-wrap: wrap; gap: 10px 16px; margin: 16px 0 0; font-size: 13px; }
.report-table-controls label { display: grid; gap: 5px; flex: 1 1 16rem; max-width: 28rem; font-weight: 600; }
.report-table-controls input { width: 100%; min-height: 36px; padding: 6px 9px; border: 1px solid #767676; border-radius: 4px; font: inherit; }
.report-table-controls output { min-width: 12rem; padding: 9px 0; font-variant-numeric: tabular-nums; }
.report-table-controls button { min-height: 36px; padding: 6px 12px; border: 1px solid #767676; border-radius: 4px; color: var(--energy-blue); background: #FFFFFF; font: inherit; cursor: pointer; }
.report-table-controls button:disabled { color: var(--muted); opacity: 0.5; cursor: default; }
.report-table tbody tr[hidden] { display: none; }
.report-grid { margin: 14px 0 24px; border: 1px solid #BDBDBD; border-radius: 6px; background: #FFFFFF; overflow: hidden; }
.report-grid .report-table-controls { margin: 0; padding: 10px 12px; border-bottom: 1px solid #D9D9D6; background: #F7F7F5; gap: 8px 12px; }
.report-grid .report-table-controls label { flex-basis: 13rem; max-width: 24rem; min-width: 0; }
.report-grid .report-table-controls output { min-width: 8rem; }
.report-grid .table-scroll { max-height: 30rem; overflow: auto; overscroll-behavior: contain; }
.report-grid table { margin: 0; }
.report-grid th { position: sticky; top: 0; z-index: 2; background: #F2F2F2; border-right: 1px solid #D9D9D6; letter-spacing: 0; text-transform: none; font-size: 12px; }
.report-grid td { border-right: 1px solid #ECECEA; line-height: 1.45; }
.report-grid tbody tr:nth-child(even) td { background: #FAFAFA; }
.report-grid tbody tr:hover td { background: #EEF6FC; }
.report-grid .row-number { width: 3rem; min-width: 3rem; text-align: right; color: var(--muted); font-variant-numeric: tabular-nums; background: #F2F2F2; }
.column-sort { font: inherit; font-weight: 600; color: inherit; background: transparent; border: 0; padding: 0 12px 0 0; width: 100%; text-align: inherit; cursor: pointer; overflow-wrap: anywhere; }
.column-sort span { margin-left: 5px; color: var(--blue); }
.column-resizer { position: absolute; right: 0; top: 0; bottom: 0; width: 8px; cursor: col-resize; touch-action: none; }
.column-resizer:hover, .column-resizer:focus-visible { background: #0078D440; outline: 2px solid var(--blue); outline-offset: -2px; }
.grid-dialog { width: calc(100vw - 32px); height: calc(100vh - 32px); max-width: none; max-height: none; padding: 0; border: 1px solid #767676; border-radius: 6px; background: #FFFFFF; color: var(--ink); }
.grid-dialog::backdrop { background: #00000066; }
.grid-dialog .report-grid { display: flex; flex-direction: column; width: 100%; height: 100%; margin: 0; border: 0; }
.grid-dialog .table-scroll { flex: 1; max-height: none; }
.table-ai-accounts { min-width: 62rem; }
.table-ai-tokens { min-width: 68rem; }
.report-jump { color: var(--blue); text-underline-offset: 3px; }
.evidence-state { font-weight: 600; white-space: nowrap; }
.story-note { color: var(--muted); font-size: 13px; margin: 8px 0 20px; max-width: 85ch; }
.tabs, .tab, .masthead h1, .masthead .eyebrow, .summary-card .label, th, h3, .story-caps, .kpi-name, .kpi-next-label { letter-spacing: 0; }
h2[id] { scroll-margin-top: 85px; }
@media (max-width: 640px) {
    .wrap { padding: 0 16px; }
    .masthead { padding: 20px 16px; }
    .masthead h1 { font-size: 25px; }
    .summary-card { min-width: 0; flex: 1 1 125px; padding: 10px 12px; }
    .story-meta { grid-template-columns: 1fr; gap: 4px; }
    .story-meta dd { margin-bottom: 10px; }
    .scope-list li { grid-template-columns: 1fr; gap: 4px; }
    .tabs { position: static; }
    .tab { padding: 10px; }
    th, td { padding: 7px 8px; }
}
.kpi { border-left: 4px solid var(--blue); background: var(--surface); border-radius: 0 4px 4px 0; padding: 10px 16px; margin: 0 0 10px 0; max-width: 78ch; }
.kpi-name { font-size: 11px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); }
.kpi-value { font-size: 17px; font-weight: 600; color: var(--navy); margin: 2px 0; }
.kpi-plain { font-size: 13px; color: var(--muted); }
.kpi-next { font-size: 13px; color: var(--ink); margin-top: 6px; }
.kpi-next-label { font-size: 10px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; color: var(--blue); margin-right: 6px; }
.calculation-details { margin: 12px 0 18px; max-width: 100ch; border-block: 1px solid var(--light-gray); }
.calculation-details summary { cursor: pointer; padding: 10px 0; color: var(--energy-blue); font-weight: 600; }
.calculation-details p { line-height: 1.55; }
.kpi-reference-filters { display: flex; align-items: end; flex-wrap: wrap; gap: 16px; margin: 20px 0 12px; }
.kpi-reference-filters label { display: grid; gap: 6px; font-size: 13px; font-weight: 600; flex: 1 1 180px; max-width: 420px; }
.kpi-reference-filters input, .kpi-reference-filters select { box-sizing: border-box; width: 100%; min-height: 38px; padding: 8px; border: 1px solid #767676; border-radius: 4px; background: #FFFFFF; color: var(--ink); font: inherit; }
.kpi-reference-filters output { padding: 8px 0; font-size: 13px; color: var(--muted); }
.kpi-reference { table-layout: fixed; width: 100%; min-width: 0; }
.kpi-reference th:first-child { width: 48%; }
.kpi-reference th:nth-child(2) { width: 32%; }
.kpi-reference td { vertical-align: top; overflow-wrap: anywhere; }
.kpi-reference p { margin: 8px 0; line-height: 1.5; }
.kpi-reference details { margin-top: 10px; }
.kpi-reference summary { color: var(--energy-blue); cursor: pointer; padding: 6px 0; }
.kpi-reference dl { margin: 8px 0; }
.kpi-reference dt { font-weight: 600; margin-top: 12px; }
.kpi-reference dd { margin: 4px 0 0; line-height: 1.5; }
.kpi-reference ul { margin: 4px 0; padding-left: 20px; }
.kpi-status { font-weight: 600; }
.kpi-reference-row[hidden], #kpi-no-results[hidden] { display: none; }
@media (max-width: 700px) {
    .kpi-reference, .kpi-reference tbody, .kpi-reference tr, .kpi-reference td { display: block; width: 100%; min-width: 0; }
    .kpi-reference thead { display: none; }
    .kpi-reference tr { border-bottom: 2px solid var(--light-gray); padding: 12px 0; }
    .kpi-reference td { border: 0; padding: 8px; }
    .kpi-reference td[data-label]::before { content: attr(data-label); display: block; color: var(--muted); font-size: 12px; margin-bottom: 6px; }
}
.no-data { color: var(--muted); font-style: italic; padding: 8px 0; }
.money { color: var(--success); font-weight: 600; }
.tag-error { background: #FDF3F2; border: 1px solid #F1C9C4; border-left: 4px solid var(--danger); border-radius: 0 4px 4px 0; padding: 11px 16px; margin: 8px 0; }
.permission-hint { color: var(--warning); font-size: 12px; }
.footer { color: var(--muted); font-size: 12px; margin-top: 40px; border-top: 1px solid var(--light-gray); padding-top: 14px; }
.footer a { color: var(--blue); text-decoration: none; }
@media print {
  .tabs { display: none; }
  .tabpane { display: block !important; }
  .masthead { background: #FFFFFF; color: var(--ink); padding: 0 0 12px 0; border-bottom: 2px solid var(--energy-blue); }
  .masthead h1, .masthead .meta, .masthead .eyebrow { color: var(--ink); }
  .wrap { padding: 0; }
  body { padding: 16px; }
  tr:hover td { background: none; }
    .table-scroll { overflow: visible; }
    .report-grid { overflow: visible; break-inside: auto; }
    .report-grid .report-table-controls, .column-resizer { display: none; }
    .report-grid .table-scroll { max-height: none; overflow: visible; }
    .report-grid th { position: static; }
    .report-grid tr[data-grid-match="true"] { display: table-row !important; }
}
</style>
<noscript><style>.tabpane { display: block; } .tabs { display: none; }</style></noscript>
</head>
<body>
<div class="masthead">
<div class="eyebrow">FinOps Toolkit</div>
<h1>FinOps Multitool report</h1>
<p class="meta">Generated: $timestamp &nbsp;|&nbsp; Subscriptions: $([System.Net.WebUtility]::HtmlEncode($headerScope))$(if ($DataSourceLabel) { " &nbsp;|&nbsp; Cost data: $([System.Net.WebUtility]::HtmlEncode($DataSourceLabel))" })</p>
</div>
<div class="wrap">
"@)

            $selectedMods = @($Modules | Where-Object { $_.Selected })
            $scanEvidence = @(foreach ($selectedMod in $selectedMods) {
                    $scanData = $Results[$selectedMod.Fn]
                    $notes = @(@($scanData.Note; $scanData.Reason; $scanData.CostIssue; $scanData.RateIssue; $scanData.AHBIssue; $scanData.Error) |
                        Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
                    $state = 'Data returned'
                    if ($Results.ContainsKey("_error_$($selectedMod.Fn)")) {
                        $state = 'Failed'
                        $notes = @([string]$Results["_error_$($selectedMod.Fn)"])
                    }
                    elseif (-not $scanData -or @($scanData).Count -eq 0 -or $scanData.HasData -contains $false) { $state = 'No data' }
                    if ($state -ne 'Failed' -and $Results['_source_Export'] -and $selectedMod.Fn -in @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag', 'Get-CostTrend')) {
                        $notes += [string]$Results['_source_Export'].Note
                        if ($Results['_source_Export'].CoverageIncomplete) { $state = 'Limited data' }
                    }
                    if ($state -ne 'Failed' -and ($scanData.CoverageIncomplete -contains $true -or $scanData.ComplianceCoverageIncomplete -contains $true -or $scanData.DefinitionCoverageIncomplete -contains $true -or $scanData.AccessDenied -contains $true -or
                            @(@($scanData.CostIssue; $scanData.RateIssue; $scanData.AHBIssue; $scanData.Error) | Where-Object { $_ }).Count -gt 0 -or
                            @($scanData.MetricFailures | Where-Object { $_ -gt 0 }).Count -gt 0 -or
                            @($scanData.Status | Where-Object { $_ -in @('Unavailable', 'Unknown') }).Count -gt 0)) {
                        $state = 'Limited data'
                    }
                    if ($state -ne 'Failed' -and $selectedMod.Fn -eq 'Get-CostData' -and $scanData -is [System.Collections.IDictionary]) {
                        foreach ($entry in $scanData.GetEnumerator()) {
                            $entryName = if ($entry.Value.Name) { [string]$entry.Value.Name } elseif ($subNameLookup.ContainsKey($entry.Key)) { $subNameLookup[$entry.Key] } else { [string]$entry.Key }
                            if ($entry.Value.Currency -eq 'Mixed' -or (Format-BudgetAmount -Value $entry.Value.Actual -Currency $entry.Value.Currency) -eq 'Unavailable') {
                                $state = 'Limited data'
                                $notes += "${entryName}: Actual cost or billing currency unavailable."
                            }
                            if (-not $entry.Value.ActualPeriod -or $entry.Value.ActualPeriod -eq 'Unknown') {
                                $state = 'Limited data'
                                $notes += "${entryName}: Observed period not recorded."
                            }
                            if (-not $entry.Value.ForecastSource -or $entry.Value.ForecastSource -in @('Actual', 'Unavailable') -or
                                (Format-BudgetAmount -Value $entry.Value.Forecast -Currency $entry.Value.Currency) -eq 'Unavailable') {
                                $state = 'Limited data'
                                $notes += "${entryName}: Full-month forecast unavailable."
                            }
                        }
                    }
                    if ($state -eq 'No data' -and @($notes).Count -eq 0) { $notes = @('This scan returned no data; that is not a measured zero.') }
                    if ($state -eq 'Limited data' -and @($notes).Count -eq 0) { $notes = @('Some data or coverage could not be verified. Review the scan details.') }
                    [pscustomobject]@{
                        Name     = $selectedMod.Name
                        Function = $selectedMod.Fn
                        Target   = 'tab-' + ($selectedMod.Category -replace '[^A-Za-z0-9]', '')
                        Anchor   = 'scan-' + ($selectedMod.Fn -replace '[^a-zA-Z0-9\-]', '')
                        Status   = $state
                        Note     = ($notes -join ' ')
                    }
                })
            $errorCount = @($scanEvidence | Where-Object Status -EQ 'Failed').Count
            $dataGapCount = @($scanEvidence | Where-Object { $_.Status -in @('Limited data', 'No data') }).Count
            [void]$htmlSb.Append('<div class="summary-grid">')
            [void]$htmlSb.Append("<div class=`"summary-card`"><div class=`"label`">Scans run</div><div class=`"value`">$($selectedMods.Count)</div></div>")
            [void]$htmlSb.Append("<div class=`"summary-card`"><div class=`"label`">Scans with gaps</div><div class=`"value`">$dataGapCount</div></div>")
            if ($errorCount -gt 0) {
                [void]$htmlSb.Append("<div class=`"summary-card`"><div class=`"label`">Errors</div><div class=`"value severity-red`">$errorCount</div></div>")
            }
            [void]$htmlSb.Append('</div>')

            # Per-module sections, grouped into one tab per category
            $presentCats = @($selectedMods | ForEach-Object { $_.Category } | Select-Object -Unique)
            # Cost Analysis leads; the rest sort alphabetically so a new category
            # lands in a predictable spot instead of being appended.
            $leadCat = 'Cost Analysis'
            $tabCats = @($presentCats | Where-Object { $_ -eq $leadCat }) +
            @($presentCats | Where-Object { $_ -ne $leadCat } | Sort-Object)

            $storyCatalog = $null
            if (Get-Command Get-KpiCatalog -ErrorAction SilentlyContinue) {
                try { $storyCatalog = Get-KpiCatalog } catch { $storyCatalog = $null }
            }
            $hasStory = $true
            $kpiReferenceIssue = $null
            try { $kpiReference = @(Get-FinOpsKpiReference -Results $Results -Modules $Modules -Insights $kpiCollected) }
            catch {
                $kpiReference = @()
                $kpiReferenceIssue = 'KPI reference unavailable: definitions could not be loaded. Scan results remain available.'
            }

            [void]$htmlSb.Append('<nav class="tabs" role="tablist">')
            if ($hasStory) {
                [void]$htmlSb.Append('<button type="button" class="tab active" role="tab" aria-selected="true" aria-controls="tab-FinOpsStory" data-target="tab-FinOpsStory">FinOps story</button>')
            }
            for ($ti = 0; $ti -lt $tabCats.Count; $ti++) {
                $tabCls = if (-not $hasStory -and $ti -eq 0) { 'tab active' } else { 'tab' }
                $tabId = 'tab-' + ($tabCats[$ti] -replace '[^A-Za-z0-9]', '')
                [void]$htmlSb.Append("<button type=`"button`" class=`"$tabCls`" role=`"tab`" aria-selected=`"false`" tabindex=`"-1`" aria-controls=`"$tabId`" data-target=`"$tabId`">$([System.Net.WebUtility]::HtmlEncode([string]$tabCats[$ti]))</button>")
            }
            if ($kpiReference.Count -gt 0) {
                [void]$htmlSb.Append('<button type="button" class="tab" role="tab" aria-selected="false" tabindex="-1" aria-controls="tab-KpiReference" data-target="tab-KpiReference">KPI reference</button>')
            }
            [void]$htmlSb.Append('</nav>')
            if ($kpiReferenceIssue) {
                [void]$htmlSb.Append("<p class=`"guidance yellow`">$([System.Net.WebUtility]::HtmlEncode($kpiReferenceIssue))</p>")
            }

            if ($hasStory) {
                [void]$htmlSb.Append('<section id="tab-FinOpsStory" class="tabpane active" role="tabpanel">')
                [void]$htmlSb.Append('<p class="story-intro">Observed spend, opportunities, and evidence gaps for the selected subscriptions. Estimates are not realized savings, and unavailable data is not treated as zero.</p>')
                $tenantIds = @($Subscriptions | ForEach-Object { $_.TenantId } | Where-Object { $_ } | Select-Object -Unique)
                $tenantLabel = if ($tenantIds.Count -gt 0) { $tenantIds -join ', ' } else { 'Not recorded' }
                $scopeLabel = if ($Subscriptions) { @($Subscriptions | ForEach-Object { "$($_.Name) [$($_.Id)]" }) -join '; ' } else { 'Not recorded' }
                [void]$htmlSb.Append('<dl class="story-meta">')
                [void]$htmlSb.Append("<dt>Tenant</dt><dd>$([System.Net.WebUtility]::HtmlEncode($tenantLabel))</dd>")
                [void]$htmlSb.Append('<dt>Selected scope</dt><dd>')
                if (@($Subscriptions).Count -gt 5) {
                    [void]$htmlSb.Append("<details class=`"scope-details`"><summary>$(@($Subscriptions).Count) subscriptions</summary><ul class=`"scope-list`">")
                    foreach ($subscription in $Subscriptions | Sort-Object Name, Id) {
                        [void]$htmlSb.Append("<li><span>$([System.Net.WebUtility]::HtmlEncode([string]$subscription.Name))</span><code>$([System.Net.WebUtility]::HtmlEncode([string]$subscription.Id))</code></li>")
                    }
                    [void]$htmlSb.Append('</ul></details>')
                }
                else { [void]$htmlSb.Append([System.Net.WebUtility]::HtmlEncode($scopeLabel)) }
                [void]$htmlSb.Append('</dd>')
                [void]$htmlSb.Append("<dt>Primary cost source</dt><dd>$([System.Net.WebUtility]::HtmlEncode($(if ($DataSourceLabel) { $DataSourceLabel } else { 'Not recorded' })))</dd>")
                [void]$htmlSb.Append('</dl>')
                [void]$htmlSb.Append('<h2>Observed spend</h2>')
                $costData = $Results['Get-CostData']
                if (-not $Results.ContainsKey('_error_Get-CostData') -and $costData -is [System.Collections.IDictionary] -and $costData.Count -gt 0) {
                    [void]$htmlSb.Append((ConvertTo-ReportTableControlHtml -TableId 'table-story-costs' -Title 'observed spend' -RowCount $costData.Count))
                    [void]$htmlSb.Append('<div class="table-scroll"><table class="report-table table-cost-summary" id="table-story-costs"><colgroup><col><col><col><col><col></colgroup><thead><tr><th scope="col">Subscription</th><th scope="col">Actual cost</th><th scope="col">Observed period</th><th scope="col">Full-month forecast</th><th scope="col">Forecast source</th></tr></thead><tbody>')
                    foreach ($entry in $costData.GetEnumerator() | Sort-Object Key) {
                        $currency = if ($entry.Value.Currency -eq 'Mixed') { '' } else { [string]$entry.Value.Currency }
                        $forecastSource = if ($entry.Value.ForecastSource) { [string]$entry.Value.ForecastSource } else { 'Unavailable' }
                        $forecastText = if ($forecastSource -in @('Unavailable', 'Actual')) { 'Unavailable' } else { Format-BudgetAmount -Value $entry.Value.Forecast -Currency $currency }
                        $cells = @(
                            $(if ($entry.Value.Name) { [string]$entry.Value.Name } elseif ($subNameLookup.ContainsKey($entry.Key)) { $subNameLookup[$entry.Key] } else { [string]$entry.Key })
                            (Format-BudgetAmount -Value $entry.Value.Actual -Currency $currency)
                            $(if ($entry.Value.ActualPeriod) { [string]$entry.Value.ActualPeriod } else { 'Not recorded' })
                            $forecastText
                            $forecastSource
                        )
                        [void]$htmlSb.Append('<tr>')
                        for ($cellIndex = 0; $cellIndex -lt $cells.Count; $cellIndex++) {
                            $cellClass = if ($cellIndex -in @(1, 3)) { ' class="numeric-cell"' } else { '' }
                            [void]$htmlSb.Append("<td$cellClass>$([System.Net.WebUtility]::HtmlEncode([string]$cells[$cellIndex]))</td>")
                        }
                        [void]$htmlSb.Append('</tr>')
                    }
                    [void]$htmlSb.Append('</tbody></table></div>')
                    [void]$htmlSb.Append('<p class="story-note">Amounts remain separate by subscription, currency, and reported period. Forecasts are separate full-month estimates, not amounts to add to actual cost.</p>')
                }
                else { [void]$htmlSb.Append('<p class="no-data">Subscription cost totals are unavailable in this run. Other scan results do not establish a zero-spend baseline.</p>') }
                $resourceEvidence = $scanEvidence | Where-Object Function -EQ 'Get-ResourceCosts' | Select-Object -First 1
                if ($resourceEvidence -and $resourceEvidence.Status -ne 'Failed' -and $Results['Get-ResourceCosts']) {
                    $driverRows = @(foreach ($resource in $Results['Get-ResourceCosts']) {
                            if ((Format-BudgetAmount -Value $resource.Actual -Currency $resource.Currency) -eq 'Unavailable') { continue }
                            if ($resource.Currency -eq 'Mixed' -or [double]$resource.Actual -le 0) { continue }
                            $resource
                        })
                    [void]$htmlSb.Append('<div id="story-cost-drivers"><h2>Largest resource costs</h2>')
                    [void]$htmlSb.Append('<p class="story-note">Up to five positive resource or charge costs per subscription, currency, and reported period among the returned rows. Source query limits can omit resources. The detail table retains every returned row, including credits. Charges without subscription attribution remain separate. High cost is not proof of waste.</p>')
                    if ($driverRows.Count -gt 0) {
                        $driverGroups = @($driverRows | Group-Object -Property @{
                                Expression = {
                                    if ($_.SubscriptionId) { [string]$_.SubscriptionId }
                                    elseif ($_.ResourcePath -match '^/subscriptions/([^/]+)/') { $Matches[1] }
                                    else { [string]$_.Subscription }
                                }
                            }, Currency, ActualPeriod | Sort-Object Name)
                        $driverCount = ($driverGroups | ForEach-Object { [math]::Min(5, $_.Count) } | Measure-Object -Sum).Sum
                        [void]$htmlSb.Append((ConvertTo-ReportTableControlHtml -TableId 'table-story-resources' -Title 'largest resource costs' -RowCount $driverCount))
                        [void]$htmlSb.Append('<div class="table-scroll"><table class="report-table table-cost-drivers" id="table-story-resources"><colgroup><col><col><col><col><col></colgroup><thead><tr><th scope="col">Subscription</th><th scope="col">Resource or charge</th><th scope="col">Type</th><th scope="col">Actual cost</th><th scope="col">Cost period</th></tr></thead><tbody>')
                        foreach ($group in $driverGroups) {
                            foreach ($resource in $group.Group | Sort-Object { [double]$_.Actual } -Descending | Select-Object -First 5) {
                                [void]$htmlSb.Append('<tr>')
                                $driverCells = @(
                                    $(if ($resource.Subscription) { [string]$resource.Subscription } else { 'Not attributed' })
                                    $(if ($resource.ResourcePath) { [string]$resource.ResourcePath } else { 'No resource ID recorded' })
                                    [string]$resource.ResourceType
                                    (Format-BudgetAmount -Value $resource.Actual -Currency $resource.Currency)
                                    $(if ($resource.ActualPeriod) { [string]$resource.ActualPeriod } else { 'Not recorded' })
                                )
                                for ($cellIndex = 0; $cellIndex -lt $driverCells.Count; $cellIndex++) {
                                    $cellClass = if ($cellIndex -eq 3) { ' class="numeric-cell"' } else { '' }
                                    $cellHtml = if ($cellIndex -eq 1) { ConvertTo-ResourceIdentityHtml -Resource $resource } else { [System.Net.WebUtility]::HtmlEncode([string]$driverCells[$cellIndex]) }
                                    [void]$htmlSb.Append("<td$cellClass>$cellHtml</td>")
                                }
                                [void]$htmlSb.Append('</tr>')
                            }
                        }
                        [void]$htmlSb.Append('</tbody></table></div>')
                    }
                    else { [void]$htmlSb.Append('<p class="no-data">No positive resource costs with a known currency were available to rank.</p>') }
                    if (@($driverRows | Where-Object ActualPeriodSource -EQ 'Query window').Count -gt 0) {
                        [void]$htmlSb.Append('<p class="story-note">API cost periods are the requested UTC query window. Query windows are not proof that billing data is complete through the end timestamp.</p>')
                    }
                    [void]$htmlSb.Append("<p><a class=`"report-jump`" data-target=`"$($resourceEvidence.Target)`" href=`"#$($resourceEvidence.Anchor)`">All returned resource costs</a></p></div><!-- cost-drivers -->")
                }
                [void]$htmlSb.Append('<h2>Scan status</h2><div class="table-scroll"><table><thead><tr><th>Scan</th><th>Evidence</th><th>Coverage and notes</th></tr></thead><tbody>')
                foreach ($evidence in $scanEvidence) {
                    $stateClass = if ($evidence.Status -eq 'Failed') { 'severity-red' } elseif ($evidence.Status -in @('Limited data', 'No data')) { 'severity-yellow' } else { '' }
                    [void]$htmlSb.Append("<tr><td><a class=`"report-jump`" data-target=`"$($evidence.Target)`" href=`"#$($evidence.Anchor)`">$([System.Net.WebUtility]::HtmlEncode([string]$evidence.Name))</a></td><td class=`"evidence-state $stateClass`">$([System.Net.WebUtility]::HtmlEncode($evidence.Status))</td><td>$([System.Net.WebUtility]::HtmlEncode($evidence.Note))</td></tr>")
                }
                [void]$htmlSb.Append('</tbody></table></div><p class="story-note">Data returned means the scan produced a result, not that every field is available or that the environment is optimized. Individual scans can use live APIs even when the primary cost source is a Hub.</p>')
                $followUps = @(foreach ($evidence in $scanEvidence) {
                        if ($evidence.Status -in @('Failed', 'Limited data', 'No data')) {
                            [pscustomobject]@{ Evidence = $evidence; Action = 'Review the reported limits before using this scan for a decision.' }
                        }
                        elseif ($guidanceByFn.ContainsKey($evidence.Function)) {
                            $action = @($guidanceByFn[$evidence.Function] | Where-Object { $_.Severity -in @('Red', 'Yellow') } | Select-Object -First 1)
                            if ($action.Count -gt 0) { [pscustomobject]@{ Evidence = $evidence; Action = [string]$action[0].Message } }
                        }
                    })
                if ($followUps.Count -gt 0) {
                    [void]$htmlSb.Append('<h2>Review next</h2><ul>')
                    foreach ($followUp in $followUps) {
                        [void]$htmlSb.Append("<li><a class=`"report-jump`" data-target=`"$($followUp.Evidence.Target)`" href=`"#$($followUp.Evidence.Anchor)`">$([System.Net.WebUtility]::HtmlEncode([string]$followUp.Evidence.Name))</a>: $([System.Net.WebUtility]::HtmlEncode($followUp.Action))</li>")
                    }
                    [void]$htmlSb.Append('</ul>')
                }
                foreach ($dom in $storyCatalog.domains) {
                    $domKpis = @($kpiCollected | Where-Object { $_.domain -eq $dom.id })
                    if ($domKpis.Count -eq 0) { continue }
                    [void]$htmlSb.Append("<h2>$([System.Net.WebUtility]::HtmlEncode([string]$dom.name))</h2>")
                    [void]$htmlSb.Append("<p class=`"story-summary`">$([System.Net.WebUtility]::HtmlEncode([string]$dom.summary))</p>")
                    [void]$htmlSb.Append("<p class=`"story-detail`">$([System.Net.WebUtility]::HtmlEncode([string]$dom.detail))</p>")

                    $measured = @($domKpis | Where-Object { $_.status -eq 'computed' -and $_.yourValue })
                    foreach ($kpi in $measured) {
                        [void]$htmlSb.Append('<div class="kpi">')
                        # The formal FinOps definition sits on the title so the card stays readable.
                        $defAttr = if ($kpi.definition) { " title=`"$([System.Net.WebUtility]::HtmlEncode([string]$kpi.definition))`"" } else { '' }
                        [void]$htmlSb.Append("<div class=`"kpi-name`"$defAttr>$([System.Net.WebUtility]::HtmlEncode([string]$kpi.kpiName))</div>")
                        [void]$htmlSb.Append("<div class=`"kpi-value`">$([System.Net.WebUtility]::HtmlEncode([string]$kpi.yourValue))</div>")
                        if ($kpi.plainLanguage) {
                            [void]$htmlSb.Append("<div class=`"kpi-plain`">$([System.Net.WebUtility]::HtmlEncode([string]$kpi.plainLanguage))</div>")
                        }
                        if ($kpi.exploreHint) {
                            [void]$htmlSb.Append("<div class=`"kpi-next`"><span class=`"kpi-next-label`">Next step</span> $([System.Net.WebUtility]::HtmlEncode([string]$kpi.exploreHint))</div>")
                        }
                        [void]$htmlSb.Append('</div>')
                    }

                    $notMeasured = @($domKpis | Where-Object { $_.status -ne 'computed' -or -not $_.yourValue })
                    if ($notMeasured.Count -gt 0) {
                        [void]$htmlSb.Append('<h3>Not measured</h3><ul>')
                        foreach ($kpi in $notMeasured) {
                            $reason = if ($kpi.yourValue) { [string]$kpi.yourValue } elseif ($kpi.exploreHint) { [string]$kpi.exploreHint } else { 'No comparable measurement was available in this run.' }
                            [void]$htmlSb.Append("<li><strong>$([System.Net.WebUtility]::HtmlEncode([string]$kpi.kpiName))</strong>: $([System.Net.WebUtility]::HtmlEncode($reason))</li>")
                        }
                        [void]$htmlSb.Append('</ul>')
                    }
                    [void]$htmlSb.Append("<p class=`"story-caps`">FinOps capabilities in this domain: $([System.Net.WebUtility]::HtmlEncode([string]$dom.capabilities))</p>")
                }
                if ($storyCatalog.learnMoreBase) {
                    $lm = [System.Net.WebUtility]::HtmlEncode([string]$storyCatalog.learnMoreBase)
                    [void]$htmlSb.Append("<p class=`"story-note`">FinOps KPI reference: <a href=`"$lm`">$lm</a>. Scan-derived estimates and proxies are labeled separately from measured values.</p>")
                }
                [void]$htmlSb.Append('</section>')
            }

            if ($kpiReference.Count -gt 0) {
                [void]$htmlSb.Append('<section id="tab-KpiReference" class="tabpane" role="tabpanel"><h2>KPI reference</h2>')
                [void]$htmlSb.Append('<p>No universal healthy value applies across workloads. Compare matched scope, currency, reporting period, cost basis, and service requirements. Computed means a value was derived, not that the environment is optimized; some values are estimates or proxies.</p>')
                [void]$htmlSb.Append('<div class="kpi-reference-filters"><label for="kpi-search">Search KPIs<input id="kpi-search" type="search" autocomplete="off"></label><label for="kpi-status-filter">Status<select id="kpi-status-filter" aria-label="Status"><option value="">All statuses</option><option>Computed</option><option>Unavailable</option><option>Not run</option><option>Informational</option></select></label>')
                [void]$htmlSb.Append("<output id=`"kpi-result-count`" aria-live=`"polite`">$($kpiReference.Count) of $($kpiReference.Count) KPIs</output></div>")
                [void]$htmlSb.Append('<div class="table-scroll"><table class="kpi-reference" role="table" aria-label="KPI definitions and current results"><thead role="rowgroup"><tr role="row"><th scope="col" role="columnheader">Metric and definition</th><th scope="col" role="columnheader">Current result</th><th scope="col" role="columnheader">Source scan</th></tr></thead><tbody role="rowgroup">')
                foreach ($entry in $kpiReference) {
                    $referenceId = 'kpi-' + ($entry.Id -replace '[^A-Za-z0-9-]', '')
                    $searchText = [System.Net.WebUtility]::HtmlEncode((@($entry.Name, $entry.Definition, $entry.Domain, $entry.SourceName, $entry.Calculation, ($entry.RequiredInputs -join ' ')) -join ' '))
                    $statusText = [System.Net.WebUtility]::HtmlEncode($entry.Status)
                    [void]$htmlSb.Append("<tr id=`"$referenceId`" class=`"kpi-reference-row`" role=`"row`" data-kpi-search=`"$searchText`" data-kpi-status=`"$statusText`"><td role=`"cell`"><strong>$([System.Net.WebUtility]::HtmlEncode($entry.Name))</strong><p>$([System.Net.WebUtility]::HtmlEncode($entry.Definition))</p><details><summary>Calculation and interpretation</summary><dl><dt>Calculation</dt><dd>$([System.Net.WebUtility]::HtmlEncode($entry.Calculation))</dd><dt>Required inputs</dt><dd><ul>")
                    foreach ($inputName in $entry.RequiredInputs) { [void]$htmlSb.Append("<li>$([System.Net.WebUtility]::HtmlEncode($inputName))</li>") }
                    [void]$htmlSb.Append("</ul></dd><dt>Interpretation and target</dt><dd>$([System.Net.WebUtility]::HtmlEncode($entry.Interpretation))</dd><dt>Limits</dt><dd>$([System.Net.WebUtility]::HtmlEncode($entry.Limitations))</dd></dl></details></td><td role=`"cell`" data-label=`"Current result`"><span class=`"kpi-status`">$statusText</span><p>$([System.Net.WebUtility]::HtmlEncode($entry.Value))</p>")
                    if ($entry.Context) { [void]$htmlSb.Append("<p class=`"story-note`">$([System.Net.WebUtility]::HtmlEncode($entry.Context))</p>") }
                    [void]$htmlSb.Append('</td><td role="cell" data-label="Source scan">')
                    if ($entry.SourceSelected) {
                        $target = 'tab-' + ($entry.SourceCategory -replace '[^A-Za-z0-9]', '')
                        $anchor = 'scan-' + ($entry.SourceFunction -replace '[^a-zA-Z0-9\-]', '')
                        [void]$htmlSb.Append("<a class=`"report-jump`" data-target=`"$target`" href=`"#$anchor`">$([System.Net.WebUtility]::HtmlEncode($entry.SourceName))</a>")
                    }
                    else { [void]$htmlSb.Append([System.Net.WebUtility]::HtmlEncode($entry.SourceName)) }
                    [void]$htmlSb.Append("<p>$([System.Net.WebUtility]::HtmlEncode($entry.Unit))</p></td></tr>")
                }
                [void]$htmlSb.Append('</tbody></table></div><p id="kpi-no-results" hidden>No matching KPIs.</p></section>')
            }

            $orderedMods = @(foreach ($c in $tabCats) { $selectedMods | Where-Object { $_.Category -eq $c } })
            $currentCat = $null
            foreach ($mod in $orderedMods) {
                if ($mod.Category -ne $currentCat) {
                    if ($null -ne $currentCat) { [void]$htmlSb.Append('</section>') }
                    $currentCat = $mod.Category
                    $paneCls = if (-not $hasStory -and $tabCats[0] -eq $currentCat) { 'tabpane active' } else { 'tabpane' }
                    $paneId = 'tab-' + ($currentCat -replace '[^A-Za-z0-9]', '')
                    [void]$htmlSb.Append("<section id=`"$paneId`" class=`"$paneCls`" role=`"tabpanel`">")
                }
                $fn = $mod.Fn
                $data = $Results[$fn]
                $eName = [System.Net.WebUtility]::HtmlEncode($mod.Name)
                $scanAnchor = 'scan-' + ($fn -replace '[^a-zA-Z0-9\-]', '')
                [void]$htmlSb.Append("<h2 id=`"$scanAnchor`" tabindex=`"-1`">$eName</h2>")
                # Anything appended past this point counts as content for the section.
                $sectionMark = $htmlSb.Length

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
                $tableNote = $null
                $htmlTableClass = 'report-table'
                switch ($fn) {
                    'Get-OrphanedResources' {
                        if ($data.MonthlyCost) {
                            [void]$htmlSb.Append("<p>Observed cost ($([System.Net.WebUtility]::HtmlEncode([string]$data.CostPeriod))): <span class=`"money`">$([System.Net.WebUtility]::HtmlEncode((Format-BudgetAmount -Value $data.MonthlyCost -Currency $data.Currency)))</span> across $($data.CostedCount) of $($data.TotalCount) resources</p>")
                        }
                        if ($data.CostIssue) {
                            [void]$htmlSb.Append("<div class=`"guidance yellow`">Cost column incomplete: $([System.Net.WebUtility]::HtmlEncode([string]$data.CostIssue)). An empty cost cell below means the lookup failed, not that the resource is free.</div>")
                        }
                        # 'n/a' when the lookup failed, '-' when it succeeded and the resource simply had no spend.
                        $noCostHtml = if ($data.CostAvailable) { '-' } else { 'n/a' }
                        $costColHtml = if ($data.CostPeriod) { [string]$data.CostPeriod } else { 'Cost' }
                        $htmlRows = $data.Orphans | ForEach-Object {
                            $o = [ordered]@{
                                Category      = $_.Category
                                ResourceName  = $_.ResourceName
                                ResourceGroup = $_.ResourceGroup
                            }
                            $o[$costColHtml] = if ($null -ne $_.MonthlyCost) { Format-BudgetAmount -Value $_.MonthlyCost -Currency $_.Currency } else { $noCostHtml }
                            $o['Detail'] = $_.Detail
                            [PSCustomObject]$o
                        }
                        $htmlCols = @('Category', 'ResourceName', 'ResourceGroup', $costColHtml, 'Detail')
                        $tableNote = 'Cost is actual billed spend over the stated period, not a projection. A deallocated VM bills nothing on the VM object itself, so its attached managed disks are rolled into its row - those disks are excluded from the orphaned disk rows above, so nothing is double counted. A resource stopped part way through the period shows what it incurred while still running, so the ongoing saving is lower than the figure shown.'
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
                        if ($data.WindowsVMs) { $ahbRows += @($data.WindowsVMs) | ForEach-Object { $est = if ($null -ne $_.estMonthlySavings) { "$(Format-BudgetAmount -Value $_.estMonthlySavings -Currency $data.SavingsCurrency)/mo" } else { 'n/a' }; [PSCustomObject]@{ Type = 'Windows VM'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.vmSize; License = $_.currentLicense; 'Est Savings' = $est } } }
                        if ($data.SQLVMs) { $ahbRows += @($data.SQLVMs) | ForEach-Object { [PSCustomObject]@{ Type = 'SQL VM'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.sqlEdition; License = $_.currentLicense; 'Est Savings' = '-' } } }
                        if ($data.SQLDatabases) { $ahbRows += @($data.SQLDatabases) | ForEach-Object { [PSCustomObject]@{ Type = 'SQL DB'; Name = $_.name; ResourceGroup = $_.resourceGroup; Size = $_.sku; License = $_.currentLicense; 'Est Savings' = '-' } } }
                        $htmlRows = $ahbRows
                        $htmlCols = @('Type', 'Name', 'ResourceGroup', 'Size', 'License', 'Est Savings')
                    }
                    'Get-TagInventory' {
                        $tagCountHtml = if ($data.SpellingCount -and $data.SpellingCount -ne $data.TagCount) { "$($data.TagCount) unique tag keys ($($data.SpellingCount) spellings)" } else { "$($data.TagCount) unique tags" }
                        $coverageLabel = if ($data.CoverageIncomplete -or $null -eq $data.TagCoverage) { 'Unverified' } else { [System.Net.WebUtility]::HtmlEncode("$($data.TagCoverage)%") }
                        $taggedLabel = if ($null -ne $data.TaggedCount) { [System.Net.WebUtility]::HtmlEncode([string]$data.TaggedCount) } else { 'Unknown' }
                        $untaggedLabel = if ($null -ne $data.UntaggedCount) { [System.Net.WebUtility]::HtmlEncode([string]$data.UntaggedCount) } else { 'Unknown' }
                        [void]$htmlSb.Append("<p>Coverage: $coverageLabel &nbsp;|&nbsp; $taggedLabel tagged / $untaggedLabel untagged &nbsp;|&nbsp; $tagCountHtml</p>")
                        if ($data.CaseVariants -and @($data.CaseVariants).Count -gt 0) {
                            [void]$htmlSb.Append("<details class=`"tag-case-details`"><summary>$(@($data.CaseVariants).Count) tag-key spelling groups</summary><p>Azure resolves tag keys case-insensitively. Resource Graph and cost exports can report their spellings separately.</p><div class=`"detail-content`"><dl>")
                            foreach ($variant in $data.CaseVariants) {
                                [void]$htmlSb.Append("<dt>$([System.Net.WebUtility]::HtmlEncode([string]$variant.TagKey))</dt><dd>$([System.Net.WebUtility]::HtmlEncode([string]$variant.Detail))</dd>")
                            }
                            [void]$htmlSb.Append('</dl></div></details>')
                        }
                        if ($data.TagNames) {
                            $htmlRows = $data.TagNames.GetEnumerator() | Sort-Object { $_.Value.TotalResources } -Descending | ForEach-Object {
                                $vals = @($_.Value.Values | Sort-Object ResourceCount -Descending)
                                $valText = (@($vals | Select-Object -First 5 | ForEach-Object { "$($_.Value) ($($_.ResourceCount))" }) -join ', ')
                                [PSCustomObject]@{ Tag = $_.Key; Resources = $_.Value.TotalResources; Values = $vals.Count; 'Top values' = $valText; _MoreValues = @($vals | Select-Object -Skip 5) }
                            }
                            $htmlCols = @('Tag', 'Resources', 'Values', 'Top values')
                            $htmlTableClass = 'report-table table-tags'
                            $tableNote = 'Values are the distinct tag values in use, with the resource count for each. A tag with a single value provides no allocation granularity; a tag with many near-identical values indicates inconsistent tagging.'
                            if ($data.CoverageIncomplete) { $tableNote = "$($data.Note) $tableNote" }
                        }
                    }
                    'Get-CostData' {
                        if ($data -is [hashtable]) {
                            $htmlRows = $data.GetEnumerator() | ForEach-Object {
                                $sl = if ($subNameLookup.ContainsKey($_.Key)) { $subNameLookup[$_.Key] } else { $_.Key }
                                [PSCustomObject]@{
                                    Subscription   = $sl
                                    Actual         = Format-BudgetAmount -Value $_.Value.Actual -Currency $_.Value.Currency
                                    ActualPeriod   = if ($_.Value.ActualPeriod) { $_.Value.ActualPeriod } else { 'Current month' }
                                    Forecast       = if ($_.Value.ForecastSource -eq 'Actual') { 'Unavailable' } else { Format-BudgetAmount -Value $_.Value.Forecast -Currency $_.Value.Currency }
                                    ForecastSource = if ($_.Value.ForecastSource) { $_.Value.ForecastSource } else { 'Unavailable' }
                                    Currency       = $_.Value.Currency
                                }
                            }
                            $htmlCols = @('Subscription', 'Actual', 'ActualPeriod', 'Forecast', 'ForecastSource', 'Currency')
                        }
                    }
                    'Get-ResourceCosts' {
                        $htmlRows = @($data) | Sort-Object { $_.Actual } -Descending | ForEach-Object {
                            [PSCustomObject]@{
                                Subscription  = if ($_.Subscription) { $_.Subscription } else { 'Not attributed' }
                                Resource      = if ($_.ResourceName) { $_.ResourceName } elseif ($_.ResourcePath) { $_.ResourcePath } else { 'No resource ID recorded' }
                                ResourceGroup = $_.ResourceGroup
                                ResourceType  = $_.ResourceType
                                Cost          = Format-BudgetAmount -Value $_.Actual -Currency $_.Currency
                                ActualPeriod  = if ($_.ActualPeriod) { $_.ActualPeriod } else { 'Not recorded' }
                                'Cost period' = if ($_.ActualPeriod) { $_.ActualPeriod } else { 'Not recorded' }
                                ResourceName  = $_.ResourceName
                                ResourcePath  = $_.ResourcePath
                            }
                        }
                        $htmlCols = @('Subscription', 'Resource', 'ResourceGroup', 'ResourceType', 'Cost', 'Cost period')
                        if (@($data | Where-Object ActualPeriodSource -EQ 'Query window').Count -gt 0) {
                            $tableNote = 'API cost periods are the requested UTC query window. Query windows are not proof that billing data is complete through the end timestamp.'
                        }
                    }
                    'Get-CostByTag' {
                        if ($data.CostByTag) {
                            $htmlRows = foreach ($tag in $data.CostByTag.GetEnumerator()) {
                                foreach ($v in $tag.Value) {
                                    [PSCustomObject]@{ Tag = $tag.Key; Value = $v.TagValue; Cost = Format-BudgetAmount -Value $v.Cost -Currency $v.Currency }
                                }
                            }
                            $htmlCols = @('Tag', 'Value', 'Cost')
                            $htmlTableClass = 'report-table table-cost-by-tag'
                            $tableNote = 'Each tag is measured on its own, so a resource missing that tag counts as (untagged) for it and appears once per tag it lacks. Costs overlap between tags and do not sum to total spend.'
                            if ($data.CoverageIncomplete) { $tableNote = "$($data.Note) $tableNote" }
                        }
                    }
                    'Get-CostTrend' {
                        $trendNames = @{}
                        foreach ($subscription in $Subscriptions) {
                            if ($subscription.Id) { $trendNames[[string]$subscription.Id] = if ($subscription.Name) { [string]$subscription.Name } else { [string]$subscription.Id } }
                        }
                        if ($trendNames.Count -eq 0 -and $data.SubscriptionNames) {
                            foreach ($subscriptionId in $data.SubscriptionNames.Keys) { $trendNames[$subscriptionId] = [string]$data.SubscriptionNames[$subscriptionId] }
                        }
                        if ($trendNames.Count -eq 0 -and $data.BySubscription) {
                            foreach ($subscriptionId in $data.BySubscription.Keys) { $trendNames[$subscriptionId] = [string]$subscriptionId }
                        }
                        $trendIds = @($trendNames.Keys | Sort-Object { $trendNames[$_] }, { $_ })
                        $coverageRecorded = $null -ne $data.SelectedSubscriptionCount -and $null -ne $data.CoverageIncomplete
                        $selectedCount = if ($coverageRecorded) { $data.SelectedSubscriptionCount } else { @($Subscriptions).Count }
                        $returnedCount = @($trendIds | Where-Object { $data.BySubscription -and @($data.BySubscription[$_] | Where-Object { $_ }).Count -gt 0 }).Count
                        $coverageLabel = if ($selectedCount -gt 0) { "Returned rows: $returnedCount of $selectedCount selected subscriptions" } else { "Returned rows: $returnedCount subscriptions; selected scope not recorded" }
                        $basisLabel = switch ($data.CostBasis) { 'ActualCost' { 'Actual cost' } 'AmortizedCost' { 'Amortized cost' } default { 'Cost basis not recorded' } }
                        $periodLabel = if ($data.Source -eq 'Export' -and $data.ActualPeriod) { "Export data period: $($data.ActualPeriod)" } else { 'Query window not recorded' }
                        $partialMonth = $null
                        if ($data.CostPeriodStartUtc -and $data.CostPeriodEndUtc) {
                            $periodStart = ([datetime]$data.CostPeriodStartUtc).ToUniversalTime()
                            $periodEnd = ([datetime]$data.CostPeriodEndUtc).ToUniversalTime()
                            $periodLabel = $periodStart.ToString('yyyy-MM-dd HH:mm:ss', [cultureinfo]::InvariantCulture) + ' to ' + $periodEnd.ToString('yyyy-MM-dd HH:mm:ss', [cultureinfo]::InvariantCulture) + ' UTC'
                            $partialMonth = $periodEnd.Date.AddDays(1 - $periodEnd.Day)
                        }
                        [void]$htmlSb.Append('<div class="cost-trend">')
                        [void]$htmlSb.Append("<p class=`"story-summary`">$([System.Net.WebUtility]::HtmlEncode($coverageLabel))</p><p class=`"story-detail`">$basisLabel<br>$([System.Net.WebUtility]::HtmlEncode($periodLabel))</p>")
                        if (-not $coverageRecorded) {
                            [void]$htmlSb.Append('<p class="guidance yellow">Coverage metadata not recorded. The aggregate is based on returned rows and is not a verified selected-scope or whole-tenant total.</p>')
                        }
                        else {
                            [void]$htmlSb.Append("<p class=`"story-detail`">Confirmed empty: $(@($data.NoDataSubscriptionIds).Count). Unverified: $(@($data.UnverifiedSubscriptionIds).Count).</p>")
                            if ($data.Note) { [void]$htmlSb.Append("<p class=`"guidance yellow`">$([System.Net.WebUtility]::HtmlEncode([string]$data.Note))</p>") }
                        }
                        if ($data.QueryScope) {
                            [void]$htmlSb.Append("<details class=`"cell-details`"><summary>Query scope</summary><div class=`"detail-content`"><code>$([System.Net.WebUtility]::HtmlEncode([string]$data.QueryScope))</code></div></details>")
                        }
                        [void]$htmlSb.Append('<div class="trend-controls"><fieldset class="trend-modes"><legend>Trend view</legend><label for="trend-view-scope"><input type="radio" id="trend-view-scope" name="trend-view" value="aggregate" checked>Selected scope</label><label for="trend-view-subscription"><input type="radio" id="trend-view-subscription" name="trend-view" value="subscription">Subscription</label></fieldset>')
                        [void]$htmlSb.Append('<div class="trend-subscription-control" hidden><label for="trend-subscription">Subscription</label><select id="trend-subscription">')
                        foreach ($subscriptionId in $trendIds) {
                            $optionLabel = "$($trendNames[$subscriptionId]) [$subscriptionId]"
                            [void]$htmlSb.Append("<option value=`"$([System.Net.WebUtility]::HtmlEncode($subscriptionId))`">$([System.Net.WebUtility]::HtmlEncode($optionLabel))</option>")
                        }
                        [void]$htmlSb.Append('</select></div></div><p class="trend-status" role="status" aria-live="polite"></p>')
                        $aggregateLabel = if ($coverageRecorded -and -not $data.CoverageIncomplete) { 'Selected-scope aggregate' } else { 'Returned aggregate (coverage not verified)' }
                        $trendSeries = @([pscustomobject]@{ Id = 'aggregate'; Label = $aggregateLabel; Months = @($data.Months | Where-Object { $_ }); EmptyMessage = 'No cost rows were returned for the trend period.' })
                        foreach ($subscriptionId in $trendIds) {
                            $emptyMessage = if ($subscriptionId -in $data.NoDataSubscriptionIds) { 'No cost rows were returned for this subscription.' } else { 'Coverage is not verified for this subscription.' }
                            $subscriptionMonths = if ($data.BySubscription) { @($data.BySubscription[$subscriptionId] | Where-Object { $_ }) } else { @() }
                            $trendSeries += [pscustomobject]@{ Id = $subscriptionId; Label = $trendNames[$subscriptionId]; Months = @($subscriptionMonths); EmptyMessage = $emptyMessage }
                        }
                        foreach ($series in $trendSeries) {
                            $encodedId = [System.Net.WebUtility]::HtmlEncode([string]$series.Id)
                            $encodedLabel = [System.Net.WebUtility]::HtmlEncode([string]$series.Label)
                            $hidden = if ($series.Id -eq 'aggregate') { '' } else { ' hidden' }
                            [void]$htmlSb.Append("<div class=`"trend-series`" data-trend-series=`"$encodedId`" data-trend-label=`"$encodedLabel`"$hidden><h4>$encodedLabel</h4>")
                            if ($series.Id -ne 'aggregate') { [void]$htmlSb.Append("<p><code>$encodedId</code></p>") }
                            if ($series.Months.Count -gt 0) {
                                [void]$htmlSb.Append('<div class="table-scroll"><table class="report-table table-trend"><thead><tr><th scope="col">Month</th><th scope="col">Cost</th><th scope="col">Currency</th></tr></thead><tbody>')
                                foreach ($trendMonth in ($series.Months | Sort-Object MonthDate)) {
                                    $monthLabel = [string]$trendMonth.Month
                                    if ($null -ne $partialMonth -and $trendMonth.MonthDate -and ([datetime]$trendMonth.MonthDate).Date -eq $partialMonth) { $monthLabel += ' (partial)' }
                                    $amount = Format-BudgetAmount -Value $trendMonth.Cost -Currency $trendMonth.Currency
                                    [void]$htmlSb.Append("<tr><td>$([System.Net.WebUtility]::HtmlEncode($monthLabel))</td><td class=`"numeric-cell`">$([System.Net.WebUtility]::HtmlEncode($amount))</td><td>$([System.Net.WebUtility]::HtmlEncode([string]$trendMonth.Currency))</td></tr>")
                                }
                                [void]$htmlSb.Append('</tbody></table></div>')
                            }
                            else { [void]$htmlSb.Append("<p class=`"guidance yellow`">$([System.Net.WebUtility]::HtmlEncode([string]$series.EmptyMessage)) No zero-valued months were added.</p>") }
                            [void]$htmlSb.Append('</div>')
                        }
                        [void]$htmlSb.Append('<p class="story-detail">Query windows do not establish billing-data completeness. Unreturned months are not filled with zero cost.</p></div>')
                    }
                    'Get-ReservationAdvice' {
                        [void]$htmlSb.Append("<p>Est. annual savings: $([System.Net.WebUtility]::HtmlEncode((Format-BudgetAmount -Value $data.EstimatedAnnualSavings -Currency $data.Currency)))</p>")
                        if ($data.CostIssue) { $tableNote = [string]$data.CostIssue }

                        # Wrapping a null in @() yields a one-element array, so filter before counting.
                        $rrRows = @($data.ReservationRecommendations | Where-Object { $_ })
                        if ($rrRows.Count -gt 0) {
                            [void]$htmlSb.Append('<h3>Reservation purchase detail</h3>')
                            [void]$htmlSb.Append('<table><thead><tr>')
                            foreach ($c in @('SKU', 'Resource type', 'Region', 'Qty', 'Term', 'Lookback', 'Cost without RI', 'Cost with RI', 'Net savings')) {
                                [void]$htmlSb.Append("<th>$([System.Net.WebUtility]::HtmlEncode($c))</th>")
                            }
                            [void]$htmlSb.Append('</tr></thead><tbody>')
                            foreach ($rr in $rrRows) {
                                $cells = @(
                                    [string]$rr.SKU
                                    [string]$rr.ResourceType
                                    [string]$rr.Region
                                    [string]$rr.RecommendedQty
                                    [string]$rr.Term
                                    [string]$rr.LookBackPeriod
                                    $(if ($null -ne $rr.CostWithoutRI) { '{0:N2}' -f [double]$rr.CostWithoutRI } else { '-' })
                                    $(if ($null -ne $rr.CostWithRI) { '{0:N2}' -f [double]$rr.CostWithRI } else { '-' })
                                    $(if ($null -ne $rr.NetSavings) { '{0:N2}' -f [double]$rr.NetSavings } else { '-' })
                                )
                                [void]$htmlSb.Append('<tr>')
                                for ($ci = 0; $ci -lt $cells.Count; $ci++) {
                                    $cell = [System.Net.WebUtility]::HtmlEncode([string]$cells[$ci])
                                    if ($ci -eq ($cells.Count - 1) -and $cells[$ci] -ne '-') { $cell = "<span class=`"money`">$cell</span>" }
                                    [void]$htmlSb.Append("<td>$cell</td>")
                                }
                                [void]$htmlSb.Append('</tr>')
                            }
                            [void]$htmlSb.Append('</tbody></table>')
                            [void]$htmlSb.Append('<p class="table-note">From the Consumption reservation recommendation API at single-subscription scope over the last 30 days, queried per resource type. Costs are modeled over the lookback window and the API does not return a currency.</p>')
                            [void]$htmlSb.Append('<h3>Advisor recommendations</h3>')
                        }

                        $htmlRows = $data.AdvisorRecommendations | ForEach-Object {
                            [PSCustomObject]@{
                                Resource = ($_.ResourceName -split '/')[-1]
                                Type     = ($_.ResourceType -split '/')[-1]
                                SKU      = $_.SKU
                                Region   = $_.Region
                                Qty      = $_.Qty
                                Term     = $_.Term
                                Savings  = Format-BudgetAmount -Value $_.AnnualSavings -Currency $_.Currency
                                Impact   = $_.Impact
                            }
                        }
                        $htmlCols = @('Resource', 'Type', 'SKU', 'Region', 'Qty', 'Term', 'Savings', 'Impact')
                    }
                    'Get-CommitmentUtilization' {
                        [void]$htmlSb.Append("<p>Reservations: $($data.RICount) (average $(Format-ReportMetric $data.RIAvgUtilization -Format '0.#' -Suffix '%')) &nbsp;|&nbsp; Savings plans: $($data.SPCount) (average $(Format-ReportMetric $data.SPAvgUtilization -Format '0.#' -Suffix '%'))</p>")
                        [void]$htmlSb.Append('<p class="story-note">Billing-scope results can include commitments beyond the selected subscriptions. Averages are unweighted and use the latest returned period per commitment. Missing metadata is not proof of denied access.</p>')
                        $htmlRows = @(
                            foreach ($reservation in @($data.Reservations | Where-Object { $_ })) {
                                $name = if ($reservation.Name) { $reservation.Name } else { $reservation.ReservationId }
                                [pscustomobject]@{ Type = 'Reservation'; Commitment = $name; ResourceName = $name; ResourcePath = $reservation.ResourceId; SKU = if ($reservation.SkuName) { $reservation.SkuName } else { 'Not returned' }; Kind = if ($reservation.Kind) { $reservation.Kind } else { 'Not returned' }; 'Avg utilization' = Format-ReportMetric $reservation.AvgUtilization -Format '0.#' -Suffix '%'; 'Usage period' = $reservation.UsageDate }
                            }
                            foreach ($plan in @($data.SavingsPlans | Where-Object { $_ })) {
                                $identity = if ($plan.BenefitId) { $plan.BenefitId } else { $plan.BenefitOrderId }
                                [pscustomobject]@{ Type = 'Savings plan'; Commitment = $identity; ResourceName = $identity; ResourcePath = $identity; SKU = 'Not returned'; Kind = $plan.BenefitType; 'Avg utilization' = Format-ReportMetric $plan.AvgUtilization -Format '0.#' -Suffix '%'; 'Usage period' = $plan.UsageDate }
                            }
                        )
                        $htmlCols = @('Type', 'Commitment', 'SKU', 'Kind', 'Avg utilization', 'Usage period')
                        if ($data.Note) { [void]$htmlSb.Append("<p class=`"story-note`">$([System.Net.WebUtility]::HtmlEncode([string]$data.Note))</p>") }
                        if ($data.MetadataErrors) { [void]$htmlSb.Append("<p class=`"guidance yellow`">Metadata could not be verified for $(@($data.MetadataErrors).Count) reservation(s). Available utilization and reservation IDs are retained.</p>") }
                    }
                    'Get-SavingsRealized' {
                        [void]$htmlSb.Append("<p>Estimated commitment savings ($([System.Net.WebUtility]::HtmlEncode([string]$data.Period))): <span class=`"money`">$([System.Net.WebUtility]::HtmlEncode((Format-BudgetAmount -Value $data.CommitmentSavingsMonthToDate -Currency $data.Currency)))</span></p>")
                        [void]$htmlSb.Append("<p>RI: $([System.Net.WebUtility]::HtmlEncode((Format-BudgetAmount -Value $data.RISavingsMonthToDate -Currency $data.Currency))) &nbsp;|&nbsp; SP: $([System.Net.WebUtility]::HtmlEncode((Format-BudgetAmount -Value $data.SPSavingsMonthToDate -Currency $data.Currency)))</p>")
                        [void]$htmlSb.Append("<p>AHB: <span class=`"money`">$([System.Net.WebUtility]::HtmlEncode((Format-BudgetAmount -Value $data.AHBSavingsMonthly -Currency $data.AHBCurrency)))</span> ($([System.Net.WebUtility]::HtmlEncode([string]$data.AHBPeriod)))</p>")
                        if ($data.AHBIssue) { [void]$htmlSb.Append("<p>$([System.Net.WebUtility]::HtmlEncode([string]$data.AHBIssue))</p>") }
                        if ($data.EstimateBasis) { $tableNote = [string]$data.EstimateBasis }
                    }
                    'Get-BudgetStatus' {
                        $htmlCoverage = if ($data.CoverageIncomplete) {
                            "unverified (read $($data.ScannedSubs) of $($data.TotalSubs) subs)"
                        }
                        else { "$($data.BudgetCoverage)%" }
                        [void]$htmlSb.Append("<p>Budgets: $($data.TotalBudgets) &nbsp;|&nbsp; At risk: $($data.AtRiskCount) &nbsp;|&nbsp; Over budget: $($data.OverBudgetCount) &nbsp;|&nbsp; Subscriptions with a budget: $htmlCoverage</p>")
                        $htmlRows = $data.Budgets | ForEach-Object {
                            $riskClass = switch ($_.Risk) { 'Over Budget' { 'severity-red' } 'On Track' { 'severity-green' } default { 'severity-yellow' } }
                            [PSCustomObject]@{
                                Budget = $_.BudgetName
                                Amount = Format-BudgetAmount -Value $_.Amount -Currency $_.Currency
                                Spent = Format-BudgetAmount -Value $_.ActualSpend -Currency $_.Currency
                                Forecast = Format-BudgetAmount -Value $_.Forecast -Currency $_.Currency
                                PctUsed = if ($null -ne $_.PctUsed) { "$($_.PctUsed)%" } else { 'Unavailable' }
                                Risk = $_.Risk; Note = $_.Note; _riskClass = $riskClass
                            }
                        }
                        $htmlCols = @('Budget', 'Amount', 'Spent', 'Forecast', 'PctUsed', 'Risk', 'Note')
                    }
                    'Get-AnomalyAlerts' {
                        [void]$htmlSb.Append("<p>Total: $($data.TotalAlerts) &nbsp;|&nbsp; Anomaly: $($data.AnomalyAlertCount) &nbsp;|&nbsp; Active: $($data.ActiveAlertCount)</p>")
                        $htmlRows = $data.TriggeredAlerts | Select-Object -First 10 | ForEach-Object {
                            $label = if ($_.AlertLabel) { $_.AlertLabel } else { $_.AlertName }
                            [PSCustomObject]@{ Alert = $label; Type = $_.AlertType; Status = $_.Status; Subscription = $_.Subscription }
                        }
                        $htmlCols = @('Alert', 'Type', 'Status', 'Subscription')
                    }
                    'Get-OptimizationAdvice' {
                        [void]$htmlSb.Append("<p>Est. annual savings: $([System.Net.WebUtility]::HtmlEncode((Format-BudgetAmount -Value $data.EstimatedAnnualSavings -Currency $data.Currency))) &nbsp;|&nbsp; $($data.TotalCount) recommendations</p>")
                        if ($data.CostIssue) { $tableNote = [string]$data.CostIssue }
                        $htmlRows = $data.Recommendations | Sort-Object { if ($_.AnnualSavings) { [double]$_.AnnualSavings } else { 0 } } -Descending | Select-Object -First 25 | ForEach-Object {
                            [PSCustomObject]@{ Category = $_.Category; Impact = $_.Impact; Resource = $_.ResourceName; Problem = ($_.Problem -replace '(.{80}).+', '$1...'); Savings = "$(Format-BudgetAmount -Value $_.AnnualSavings -Currency $_.Currency)/yr" }
                        }
                        $htmlCols = @('Category', 'Impact', 'Resource', 'Problem', 'Savings')
                    }
                    'Get-TagRecommendations' {
                        $htmlRows = $data.Analysis | ForEach-Object { [PSCustomObject]@{ Tag = $_.TagName; Status = $_.Status; Priority = $_.Priority; Pillar = $_.Pillar; Example = $_.Example } }
                        $htmlCols = @('Tag', 'Status', 'Priority', 'Pillar', 'Example')
                    }
                    'Get-PolicyInventory' {
                        $htmlRows = $data.Assignments | ForEach-Object { [PSCustomObject]@{ Name = $_.AssignmentName; Effect = $_.Effect; Enforcement = $_.EnforcementMode; Scope = $_.Scope; ScopeDisplayName = $_.ScopeDisplayName } }
                        $htmlCols = @('Name', 'Effect', 'Enforcement', 'Scope')
                    }
                    'Get-PolicyRecommendations' {
                        $htmlRows = $data.Analysis | ForEach-Object {
                            $assignmentLabels = @($_.MatchedAssignments | ForEach-Object { "$($_.AssignmentName) [$($_.Source); $($_.EnforcementMode); $($_.Scope)]" })
                            $detailLabel = if ($assignmentLabels.Count -eq 1) { '1 assignment' } elseif ($assignmentLabels.Count -gt 1) { "$($assignmentLabels.Count) assignments" } else { 'Policy details' }
                            [PSCustomObject]@{ Policy = $_.DisplayName; Status = $_.Status; Category = $_.Category; Priority = $_.Priority; Effect = $_.DefaultEffect; Assignments = ($assignmentLabels -join '; '); Purpose = $_.Purpose; Note = $_.Note; Details = $detailLabel; _AssignmentDetails = @($_.MatchedAssignments) }
                        }
                        $htmlCols = @('Policy', 'Status', 'Priority', 'Effect', 'Details')
                        $htmlTableClass = 'report-table table-policies'
                        $tableNote = 'Assignment coverage compares recommended definition IDs with the reported assignments and their initiative members. It does not measure enforcement or resource compliance.'
                    }
                    'Get-BillingStructure' {
                        $htmlRows = $data.BillingAccounts | ForEach-Object { [PSCustomObject]@{ Account = $_.DisplayName; Agreement = $_.AgreementType; Type = $_.AccountType; Status = $_.AccountStatus } }
                        $htmlCols = @('Account', 'Agreement', 'Type', 'Status')
                    }
                    'Get-ContractInfo' {
                        $htmlRows = @($data) | ForEach-Object { [PSCustomObject]@{ Account = $_.AccountName; Agreement = $_.AgreementType; Type = $_.FriendlyType; Country = $_.SoldToCountry; Status = $_.AccountStatus } }
                        $htmlCols = @('Account', 'Agreement', 'Type', 'Country', 'Status')
                    }
                    'Get-BudgetHistory' {
                        $htmlRows = @($data) | Where-Object { $_ } | ForEach-Object {
                            [PSCustomObject]@{
                                Subscription = $_.Subscription
                                Budget       = $_.BudgetName
                                Month        = $_.Month
                                Budgeted     = Format-BudgetAmount -Value $_.BudgetAmount -Currency $_.Currency
                                Actual       = Format-BudgetAmount -Value $_.ActualSpend -Currency $_.Currency
                                PctUsed      = if ($null -ne $_.PctUsed) { "$($_.PctUsed)%" } else { 'Unavailable' }
                                Status       = $_.Status
                                Note         = $_.Note
                            }
                        }
                        $htmlCols = @('Subscription', 'Budget', 'Month', 'Budgeted', 'Actual', 'PctUsed', 'Status', 'Note')
                    }
                    'Get-CarbonMetrics' {
                        $cLatest = [System.Net.WebUtility]::HtmlEncode([string]$data.LatestMonth)
                        $cUnit = [System.Net.WebUtility]::HtmlEncode([string]$data.Unit)
                        $emissions = if ($null -ne $data.TotalEmissionsKg) { "$($data.TotalEmissionsKg) $cUnit" } else { 'Unavailable' }
                        $changeLabel = if ($null -ne $data.ChangeRatio) { "$($data.ChangeRatio)%" } else { 'Unavailable' }
                        [void]$htmlSb.Append("<p>Latest month ($cLatest): $emissions &nbsp;|&nbsp; month over month $changeLabel</p>")
                        if ($data.Note) { $tableNote = [string]$data.Note }
                        $htmlRows = $data.BySubscription | Where-Object { $_ } | ForEach-Object {
                            [PSCustomObject]@{ Subscription = $_.Subscription; Emissions = "$($_.EmissionsKg) kg" }
                        }
                        $htmlCols = @('Subscription', 'Emissions')
                    }
                    'Get-UnitEconomics' {
                        $computeAmount = [System.Net.WebUtility]::HtmlEncode((Format-BudgetAmount -Value $data.ComputeCost -Currency $data.Currency))
                        $storageAmount = [System.Net.WebUtility]::HtmlEncode((Format-BudgetAmount -Value $data.StorageCost -Currency $data.Currency))
                        $computeShare = if ($null -ne $data.ComputeSharePct) { [System.Net.WebUtility]::HtmlEncode("$($data.ComputeSharePct)% of VM compute + storage spend") } else { 'Unavailable' }
                        $storageShare = if ($null -ne $data.StorageSharePct) { [System.Net.WebUtility]::HtmlEncode("$($data.StorageSharePct)% of VM compute + storage spend") } else { 'Unavailable' }
                        [void]$htmlSb.Append("<p>Compute: $computeAmount ($computeShare) over $($data.VmCount) VMs, $($data.TotalVCpu) vCPU, $($data.TotalMemoryGb) GB RAM</p>")
                        [void]$htmlSb.Append("<p>Storage: $storageAmount ($storageShare) over $($data.TotalStorageGb) GB</p>")
                        $unitContext = Get-FinOpsUnitCostContext -Data $data
                        [void]$htmlSb.Append("<p class=`"story-note`">$([System.Net.WebUtility]::HtmlEncode($unitContext.Summary))</p>")
                        [void]$htmlSb.Append('<details class="calculation-details"><summary>Calculation and thresholds</summary>')
                        foreach ($description in @($unitContext.Formula, $unitContext.Capacity, $unitContext.Target)) {
                            [void]$htmlSb.Append("<p>$([System.Net.WebUtility]::HtmlEncode($description))</p>")
                        }
                        [void]$htmlSb.Append('</details>')
                        $htmlRows = @(
                            [PSCustomObject]@{ Metric = 'Cost per vCPU'; Value = (Format-FinOpsUnitRate -Value $data.CostPerVCpu -Currency $data.Currency) }
                            [PSCustomObject]@{ Metric = 'Cost per GB RAM'; Value = (Format-FinOpsUnitRate -Value $data.CostPerGbRam -Currency $data.Currency) }
                            [PSCustomObject]@{ Metric = 'Cost per VM'; Value = (Format-FinOpsUnitRate -Value $data.CostPerVm -Currency $data.Currency) }
                            [PSCustomObject]@{ Metric = 'Cost per GB stored'; Value = (Format-FinOpsUnitRate -Value $data.CostPerGb -Currency $data.Currency) }
                        )
                        $htmlCols = @('Metric', 'Value')
                        if ($data.Note) { $tableNote = [string]$data.Note }
                    }
                    'Get-LegacyResources' {
                        [void]$htmlSb.Append("<p>$($data.TotalCount) legacy or retiring resources found</p>")
                        $htmlRows = $data.LegacyResources | Where-Object { $_ } | ForEach-Object {
                            [PSCustomObject]@{ Category = $_.Category; Resource = $_.ResourceName; Detail = $_.Detail; Impact = $_.Impact }
                        }
                        $htmlCols = @('Category', 'Resource', 'Detail', 'Impact')
                    }
                    'Get-AIWorkloadMetrics' {
                        if ($data.HasData) {
                            $fp = $data.AIFootprint
                            $aiAmount = [System.Net.WebUtility]::HtmlEncode((Format-BudgetAmount -Value $data.TotalAICost -Currency $data.Currency))
                            $periodLabel = if ($data.Period -eq 'MonthToDate') { 'Month to date' } elseif ($data.Period) { [string]$data.Period } else { 'Unknown period' }
                            if ($data.UsagePeriodStartUtc -and $data.UsagePeriodEndUtc) {
                                $periodLabel = ([datetime]$data.UsagePeriodStartUtc).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss', [cultureinfo]::InvariantCulture) + ' to ' + ([datetime]$data.UsagePeriodEndUtc).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss', [cultureinfo]::InvariantCulture) + ' UTC'
                            }
                            $aPeriod = [System.Net.WebUtility]::HtmlEncode($periodLabel)
                            [void]$htmlSb.Append("<p>AI footprint &mdash; OpenAI/Foundry Tools: $($fp.OpenAIAccounts + $fp.AIServices) &nbsp;|&nbsp; ML workspaces: $($fp.MLWorkspaces) &nbsp;|&nbsp; AI Search: $($fp.SearchServices) &nbsp;|&nbsp; GPU VMs: $($fp.GpuVmCount)</p>")
                            [void]$htmlSb.Append("<p>Period: $aPeriod<br>Tokens: $(Format-ReportMetric $data.TotalTokens) &nbsp;|&nbsp; Requests: $(Format-ReportMetric $data.TotalRequests) &nbsp;|&nbsp; AI account cost: $aiAmount</p>")
                            [void]$htmlSb.Append('<p class="story-note">Cost covers Microsoft.CognitiveServices/accounts, not the ML, Search, or GPU inventory. Effective account rates are not per-model prices or a billing reconciliation. Incomplete usage leaves rates unavailable.</p>')
                            $accountRows = @($data.ByAccount | Where-Object { $_ })
                            if ($accountRows.Count -gt 0) {
                                [void]$htmlSb.Append('<h3>Account costs</h3>')
                                [void]$htmlSb.Append((ConvertTo-ReportTableControlHtml -TableId 'table-ai-accounts' -Title 'AI account costs' -RowCount $accountRows.Count))
                                [void]$htmlSb.Append('<div class="table-scroll"><table class="report-table table-ai-accounts" id="table-ai-accounts"><thead><tr><th scope="col">Account</th><th scope="col">Tokens</th><th scope="col">Requests</th><th scope="col">Cost</th><th scope="col">Cost per 1K tokens</th><th scope="col">Measurements</th></tr></thead><tbody>')
                                foreach ($account in $accountRows) {
                                    $identity = [pscustomobject]@{ ResourceName = $account.Name; ResourcePath = $account.ResourceId }
                                    [void]$htmlSb.Append("<tr><td>$(ConvertTo-ResourceIdentityHtml -Resource $identity)</td>")
                                    $cells = @((Format-ReportMetric $account.Tokens), (Format-ReportMetric $account.Requests), (Format-BudgetAmount -Value $account.Cost -Currency $account.Currency), (Format-FinOpsUnitRate -Value $account.CostPer1KTokens -Currency $account.Currency))
                                    foreach ($cell in $cells) { [void]$htmlSb.Append("<td class=`"numeric-cell`">$([System.Net.WebUtility]::HtmlEncode([string]$cell))</td>") }
                                    $measurements = if ($data.Source -eq 'FinOpsHub') { 'Billed token quantity; requests not recorded' } elseif ($account.MetricsComplete -eq $true) { 'Returned' } elseif ($account.MetricsComplete -eq $false) { 'Incomplete' } else { 'Not recorded' }
                                    [void]$htmlSb.Append("<td>$measurements</td></tr>")
                                }
                                [void]$htmlSb.Append('</tbody></table></div>')
                            }
                            if ($data.ByModel -and @($data.ByModel | Where-Object { $_ }).Count -gt 0) {
                                [void]$htmlSb.Append('<h3>Token usage</h3>')
                                $htmlRows = $data.ByModel | ForEach-Object { [pscustomobject]@{ 'Deployment or model' = $_.Deployment; Account = if ($_.Account) { $_.Account } else { 'Not recorded' }; ResourceName = $_.Account; ResourcePath = $_.ResourceId; 'Input tokens' = Format-ReportMetric $_.PromptTokens; 'Output tokens' = Format-ReportMetric $_.GeneratedTokens; 'Total tokens' = Format-ReportMetric $_.TotalTokens; 'Token share' = Format-ReportMetric $_.PctOfTokens -Format '0.#' -Suffix '%'; 'Token basis' = if ($_.TokenBasis) { $_.TokenBasis } else { 'Not recorded' } } }
                                $htmlCols = @('Deployment or model', 'Account', 'Input tokens', 'Output tokens', 'Total tokens', 'Token share', 'Token basis')
                                $htmlTableClass = 'report-table table-ai-tokens'
                            }
                            if ($data.Note) { $tableNote = [string]$data.Note }
                        }
                        else {
                            [void]$htmlSb.Append('<div class="no-data">No AI workloads detected.</div>')
                        }
                    }
                    'Get-MaccCommitment' {
                        if ($data.CoverageIncomplete) { $tableNote = [string]$data.Reason }
                        if ($data.Applicable -and $data.HasMacc -and @($data.Commitments | Where-Object { $_ }).Count -gt 0) {
                            $htmlRows = @($data.Commitments) | ForEach-Object {
                                [PSCustomObject]@{
                                    Account    = $_.BillingAccount
                                    Commitment = Format-BudgetAmount -Value $_.Commitment -Currency $_.Currency
                                    Consumed   = Format-BudgetAmount -Value $_.Consumed -Currency $_.Currency
                                    Remaining  = Format-BudgetAmount -Value $_.Remaining -Currency $_.Currency
                                    PctUsed    = if ($null -ne $_.PctUsed) { "$($_.PctUsed)%" } else { 'Unavailable' }
                                    Status     = $_.Status
                                    Expires    = $_.ExpirationDate
                                }
                            }
                            $htmlCols = @('Account', 'Commitment', 'Consumed', 'Remaining', 'PctUsed', 'Status', 'Expires')
                        }
                        elseif ($data.Reason) {
                            [void]$htmlSb.Append("<div class=`"no-data`">$([System.Net.WebUtility]::HtmlEncode([string]$data.Reason))</div>")
                        }
                    }
                }

                # Render HTML table
                if ($htmlRows -and $htmlCols) {
                    $tableId = 'table-' + ($fn -replace '[^a-zA-Z0-9\-]', '')
                    [void]$htmlSb.Append((ConvertTo-ReportTableControlHtml -TableId $tableId -Title $mod.Name -RowCount @($htmlRows).Count))
                    [void]$htmlSb.Append("<div class=`"table-scroll`"><table class=`"$htmlTableClass`" id=`"$tableId`">")
                    if ($fn -in @('Get-TagInventory', 'Get-PolicyRecommendations')) {
                        [void]$htmlSb.Append('<colgroup>')
                        foreach ($column in $htmlCols) { [void]$htmlSb.Append('<col>') }
                        [void]$htmlSb.Append('</colgroup>')
                    }
                    [void]$htmlSb.Append('<thead><tr>')
                    foreach ($c in $htmlCols) {
                        $columnLabel = if ($c -eq 'AvgCPU14d') { 'Avg CPU (14 days)' } else { $c }
                        [void]$htmlSb.Append("<th scope=`"col`">$([System.Net.WebUtility]::HtmlEncode($columnLabel))</th>")
                    }
                    [void]$htmlSb.Append('</tr></thead><tbody>')
                    foreach ($r in $htmlRows) {
                        [void]$htmlSb.Append('<tr>')
                        foreach ($c in $htmlCols) {
                            $val = $r.$c
                            $raw = [string]$val
                            if ($fn -eq 'Get-IdleVMs' -and $c -eq 'AvgCPU14d') { $raw = Format-ReportMetric $val -Format '0.#' -Suffix '%' }
                            $enc = [System.Net.WebUtility]::HtmlEncode($raw)
                            # Colorize money values and risk/severity
                            if ($enc -match '^\$') { $enc = "<span class=`"money`">$enc</span>" }
                            if ($c -eq 'Risk' -and $r.PSObject.Properties['_riskClass']) { $enc = "<span class=`"$($r._riskClass)`">$enc</span>" }
                            if ($c -eq 'Impact') {
                                $impClass = switch ($val) { 'High' { 'severity-red' } 'Medium' { 'severity-yellow' } default { 'severity-green' } }
                                $enc = "<span class=`"$impClass`">$enc</span>"
                            }
                            $cellClass = if ($c -in @('Resources', 'Values', 'Cost', 'Actual', 'Forecast', 'Amount', 'Spent', 'PctUsed', 'AvgCPU14d', 'AvgUtil', 'MinUtil', 'PromptTokens', 'GeneratedTokens', 'TotalTokens', 'PctOfTokens', 'Input tokens', 'Output tokens', 'Total tokens', 'Token share', 'Avg utilization')) { ' class="numeric-cell"' } else { '' }
                            [void]$htmlSb.Append("<td$cellClass>")
                            if ($fn -eq 'Get-ResourceCosts' -and $c -eq 'Resource') {
                                [void]$htmlSb.Append((ConvertTo-ResourceIdentityHtml -Resource $r))
                            }
                            elseif (($fn -eq 'Get-CommitmentUtilization' -and $c -eq 'Commitment') -or ($fn -eq 'Get-AIWorkloadMetrics' -and $c -eq 'Account' -and $r.ResourcePath)) {
                                [void]$htmlSb.Append((ConvertTo-ResourceIdentityHtml -Resource $r))
                            }
                            elseif ($fn -eq 'Get-PolicyInventory' -and $c -eq 'Scope') {
                                [void]$htmlSb.Append((ConvertTo-PolicyScopeHtml -Assignment $r))
                            }
                            elseif ($fn -eq 'Get-TagInventory' -and $c -eq 'Top values') {
                                [void]$htmlSb.Append("<p class=`"cell-preview`">$enc</p>")
                                if ($r._MoreValues.Count -gt 0) {
                                    [void]$htmlSb.Append("<details class=`"cell-details`"><summary>$($r._MoreValues.Count) more values</summary><div class=`"detail-content`"><ul class=`"detail-list`">")
                                    foreach ($tagValue in $r._MoreValues) {
                                        [void]$htmlSb.Append("<li>$([System.Net.WebUtility]::HtmlEncode([string]$tagValue.Value)) ($([System.Net.WebUtility]::HtmlEncode([string]$tagValue.ResourceCount)))</li>")
                                    }
                                    [void]$htmlSb.Append('</ul></div></details>')
                                }
                            }
                            elseif ($fn -eq 'Get-PolicyRecommendations' -and $c -eq 'Details') {
                                [void]$htmlSb.Append("<details class=`"cell-details`"><summary>$enc</summary><div class=`"detail-content`"><dl>")
                                foreach ($detailName in @('Category', 'Purpose', 'Note')) {
                                    if ($r.$detailName) {
                                        [void]$htmlSb.Append("<dt>$detailName</dt><dd>$([System.Net.WebUtility]::HtmlEncode([string]$r.$detailName))</dd>")
                                    }
                                }
                                [void]$htmlSb.Append('</dl>')
                                if ($r._AssignmentDetails.Count -gt 0) {
                                    [void]$htmlSb.Append('<ul class="detail-list">')
                                    foreach ($assignment in $r._AssignmentDetails) {
                                        [void]$htmlSb.Append("<li><strong>$([System.Net.WebUtility]::HtmlEncode([string]$assignment.AssignmentName))</strong><br>$([System.Net.WebUtility]::HtmlEncode([string]$assignment.Source)); $([System.Net.WebUtility]::HtmlEncode([string]$assignment.EnforcementMode))<br>$(ConvertTo-PolicyScopeHtml -Assignment $assignment)</li>")
                                    }
                                    [void]$htmlSb.Append('</ul>')
                                }
                                [void]$htmlSb.Append('</div></details>')
                            }
                            else { [void]$htmlSb.Append($enc) }
                            [void]$htmlSb.Append('</td>')
                        }
                        [void]$htmlSb.Append('</tr>')
                    }
                    [void]$htmlSb.Append('</tbody></table></div>')
                    if ($tableNote) {
                        [void]$htmlSb.Append("<p class=`"table-note`">$([System.Net.WebUtility]::HtmlEncode($tableNote))</p>")
                    }
                }

                $scanContext = Get-FinOpsScanContext -FunctionName $fn -Data $data
                if ($scanContext) {
                    [void]$htmlSb.Append("<p class=`"story-note`">$([System.Net.WebUtility]::HtmlEncode($scanContext.Summary))</p>")
                    [void]$htmlSb.Append('<details class="calculation-details"><summary>Calculation and thresholds</summary>')
                    foreach ($description in $scanContext.Details) {
                        [void]$htmlSb.Append("<p>$([System.Net.WebUtility]::HtmlEncode($description))</p>")
                    }
                    [void]$htmlSb.Append('</details>')
                }

                # Render guidance
                if ($guidanceByFn.ContainsKey($fn)) {
                    foreach ($item in $guidanceByFn[$fn]) {
                        $gClass = switch ($item.Severity) { 'Red' { 'guidance red' } 'Yellow' { 'guidance yellow' } 'Green' { 'guidance green' } default { 'guidance' } }
                        [void]$htmlSb.Append("<div class=`"$gClass`">$([System.Net.WebUtility]::HtmlEncode([string]$item.Message))")
                        if ($item.Docs) {
                            $eDocs = [System.Net.WebUtility]::HtmlEncode([string]$item.Docs)
                            if ($item.Docs -match '^https?://') {
                                [void]$htmlSb.Append("<br/><a href=`"$eDocs`">$eDocs</a>")
                            }
                            else {
                                [void]$htmlSb.Append("<br/>$eDocs")
                            }
                        }
                        [void]$htmlSb.Append('</div>')
                    }
                }

                # A scan that produced no table and no summary would otherwise be a bare heading.
                if ($htmlSb.Length -eq $sectionMark) {
                    [void]$htmlSb.Append('<div class="no-data">This scan ran but returned nothing to display.</div>')
                }
            }

            if ($null -ne $currentCat) { [void]$htmlSb.Append('</section>') }
            [void]$htmlSb.Append('<div class="footer">Generated by FinOps Multitool &mdash; part of the <a href="https://aka.ms/finops/toolkit">FinOps Toolkit</a></div>')
            [void]$htmlSb.Append('</div>')
            [void]$htmlSb.Append(@'
<script>
(function () {
    Array.prototype.forEach.call(document.querySelectorAll('.cost-trend'), function (trend) {
        var modes = Array.prototype.slice.call(trend.querySelectorAll('input[name="trend-view"]'));
        var picker = trend.querySelector('#trend-subscription');
        var pickerControl = trend.querySelector('.trend-subscription-control');
        var series = Array.prototype.slice.call(trend.querySelectorAll('[data-trend-series]'));
        var status = trend.querySelector('.trend-status');
        var subscriptionMode = trend.querySelector('#trend-view-subscription');
        subscriptionMode.disabled = picker.options.length === 0;
        function updateTrend() {
            var bySubscription = subscriptionMode.checked;
            var selected = bySubscription ? picker.value : 'aggregate';
            pickerControl.hidden = !bySubscription;
            series.forEach(function (panel) {
                panel.hidden = panel.getAttribute('data-trend-series') !== selected;
                if (!panel.hidden) { status.textContent = panel.getAttribute('data-trend-label'); }
            });
        }
        modes.forEach(function (mode) { mode.addEventListener('change', updateTrend); });
        picker.addEventListener('change', updateTrend);
        updateTrend();
    });
    Array.prototype.forEach.call(document.querySelectorAll('table.report-table'), function (table, tableIndex) {
        if (!table.tBodies.length || !table.tHead) { return; }
        if (!table.id) { table.id = 'report-grid-' + tableIndex; }
        var rows = Array.prototype.slice.call(table.tBodies[0].rows);
        var headers = Array.prototype.slice.call(table.tHead.rows[0].cells);
        var scroller = table.parentElement;
        var controls = Array.prototype.find.call(document.querySelectorAll('.report-table-controls'), function (element) { return element.getAttribute('data-table-id') === table.id; });
        var title = 'Results';
        var series = table.closest('.trend-series');
        if (series) { title = series.getAttribute('data-trend-label'); }
        else {
            Array.prototype.forEach.call(document.querySelectorAll('h2, h3'), function (heading) {
                if (heading.compareDocumentPosition(table) & Node.DOCUMENT_POSITION_FOLLOWING) { title = heading.textContent; }
            });
        }
        table.setAttribute('aria-label', title);
        var frame = document.createElement('div');
        frame.className = 'report-grid';
        scroller.parentNode.insertBefore(frame, scroller);
        if (!controls) {
            controls = document.createElement('div');
            controls.className = 'report-table-controls';
            controls.setAttribute('data-table-id', table.id);
            var label = document.createElement('label');
            label.textContent = 'Filter ' + title;
            var input = document.createElement('input');
            input.type = 'search';
            input.setAttribute('aria-controls', table.id);
            label.appendChild(input);
            controls.appendChild(label);
            var count = document.createElement('output');
            count.setAttribute('aria-live', 'polite');
            controls.appendChild(count);
            ['previous', 'next'].forEach(function (action) {
                var button = document.createElement('button');
                button.type = 'button';
                button.setAttribute('data-page-action', action);
                button.setAttribute('aria-label', action + ' page of ' + title);
                button.textContent = action === 'previous' ? 'Previous' : 'Next';
                controls.appendChild(button);
            });
        }
        frame.appendChild(controls);
        frame.appendChild(scroller);
        scroller.tabIndex = 0;
        scroller.setAttribute('role', 'region');
        scroller.setAttribute('aria-label', title + ' table');
        var colgroup = table.querySelector('colgroup');
        if (!colgroup) {
            colgroup = document.createElement('colgroup');
            headers.forEach(function () { colgroup.appendChild(document.createElement('col')); });
            table.insertBefore(colgroup, table.firstChild);
        }
        var columns = Array.prototype.slice.call(colgroup.children);
        columns.forEach(function (column, index) {
            var width = getComputedStyle(column).width;
            column.style.width = parseFloat(width) > 0 ? width : (100 / columns.length) + '%';
            headers[index].style.width = 'auto';
        });
        var numberColumn = document.createElement('col');
        numberColumn.style.width = '3rem';
        colgroup.insertBefore(numberColumn, colgroup.firstChild);
        var numberHeader = document.createElement('th');
        numberHeader.scope = 'col';
        numberHeader.className = 'row-number';
        numberHeader.textContent = '#';
        numberHeader.setAttribute('aria-label', 'Row number');
        table.tHead.rows[0].insertBefore(numberHeader, table.tHead.rows[0].firstChild);
        rows.forEach(function (row, index) {
            row.setAttribute('data-grid-search', row.textContent.toLowerCase());
            row.setAttribute('data-grid-order', String(index));
            var numberCell = document.createElement('td');
            numberCell.className = 'row-number';
            numberCell.textContent = String(index + 1);
            row.insertBefore(numberCell, row.firstChild);
        });
        var search = controls.querySelector('input[type="search"]');
        var output = controls.querySelector('output');
        var previous = controls.querySelector('[data-page-action="previous"]');
        var next = controls.querySelector('[data-page-action="next"]');
        var pageIndex = 0;
        var pageSize = 25;
        var sortColumn = -1;
        var sortDirection = 1;
        var collator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });
        function parseGridNumber(text) {
            var accounting = /^\(.*\)$/.test(text);
            var value = accounting ? text.slice(1, -1).trim() : text;
            var match = value.match(/^([-+])?\s*([A-Z]{3}|\$)?\s*([-+])?(\d[\d,]*(?:\.\d+)?(?:[eE][-+]?\d+)?)(%|\/yr)?$/);
            if (!match || (match[1] && match[3]) || (accounting && (match[1] || match[3]))) { return null; }
            var amount = Number(match[4].replace(/,/g, ''));
            if (!Number.isFinite(amount)) { return null; }
            if (accounting || match[1] === '-' || match[3] === '-') { amount = -amount; }
            return { value: amount, currency: match[2] || '', unit: match[5] || '' };
        }
        function compareCells(first, second) {
            var firstText = first.cells[sortColumn + 1].textContent.trim();
            var secondText = second.cells[sortColumn + 1].textContent.trim();
            var empty = /^(?:Unavailable|Not returned|Not recorded|Unknown)?$/i;
            if (empty.test(firstText) !== empty.test(secondText)) { return empty.test(firstText) ? 1 : -1; }
            var firstNumber = parseGridNumber(firstText);
            var secondNumber = parseGridNumber(secondText);
            var comparison = firstNumber && secondNumber && firstNumber.currency === secondNumber.currency && firstNumber.unit === secondNumber.unit
                ? firstNumber.value - secondNumber.value
                : collator.compare(firstText, secondText);
            return comparison ? comparison * sortDirection : Number(first.getAttribute('data-grid-order')) - Number(second.getAttribute('data-grid-order'));
        }
        function updateRows() {
            var query = search.value.trim().toLowerCase();
            var matches = rows.filter(function (row) {
                var matched = !query || row.getAttribute('data-grid-search').indexOf(query) !== -1;
                row.setAttribute('data-grid-match', String(matched));
                return matched;
            });
            if (sortColumn >= 0) { matches.sort(compareCells); }
            var lastPage = Math.max(0, Math.ceil(matches.length / pageSize) - 1);
            pageIndex = Math.min(pageIndex, lastPage);
            rows.forEach(function (row) { row.hidden = true; });
            var startIndex = pageIndex * pageSize;
            matches.forEach(function (row) { table.tBodies[0].appendChild(row); });
            matches.slice(startIndex, startIndex + pageSize).forEach(function (row) { row.hidden = false; });
            output.textContent = matches.length ? (startIndex + 1) + '-' + Math.min(startIndex + pageSize, matches.length) + ' of ' + matches.length + (query ? ' matching rows' : ' rows') : 'No matching rows';
            previous.disabled = pageIndex === 0;
            next.disabled = pageIndex >= lastPage;
        }
        function resizeColumn(index, width) {
            var allColumns = Array.prototype.slice.call(colgroup.children);
            var allHeaders = Array.prototype.slice.call(table.tHead.rows[0].cells);
            allColumns.forEach(function (column, columnIndex) { column.style.width = allHeaders[columnIndex].getBoundingClientRect().width + 'px'; });
            columns[index].style.width = Math.max(80, Math.min(1200, width)) + 'px';
            table.style.width = allColumns.reduce(function (sum, column) { return sum + parseFloat(column.style.width); }, 0) + 'px';
            headers[index].querySelector('.column-resizer').setAttribute('aria-valuenow', String(Math.round(parseFloat(columns[index].style.width))));
        }
        headers.forEach(function (header, index) {
            var text = header.textContent;
            header.textContent = '';
            header.setAttribute('aria-sort', 'none');
            var sort = document.createElement('button');
            sort.type = 'button';
            sort.className = 'column-sort';
            sort.textContent = text;
            sort.title = 'Sort by ' + text;
            var direction = document.createElement('span');
            direction.setAttribute('aria-hidden', 'true');
            sort.appendChild(direction);
            sort.addEventListener('click', function () {
                sortDirection = sortColumn === index ? -sortDirection : 1;
                sortColumn = index;
                headers.forEach(function (item) { item.setAttribute('aria-sort', 'none'); item.querySelector('.column-sort span').textContent = ''; });
                header.setAttribute('aria-sort', sortDirection === 1 ? 'ascending' : 'descending');
                direction.textContent = sortDirection === 1 ? '\u2191' : '\u2193';
                pageIndex = 0;
                updateRows();
            });
            header.appendChild(sort);
            var resizer = document.createElement('span');
            resizer.className = 'column-resizer';
            resizer.tabIndex = 0;
            resizer.setAttribute('role', 'separator');
            resizer.setAttribute('aria-orientation', 'vertical');
            resizer.setAttribute('aria-label', 'Resize ' + text + ' column');
            resizer.setAttribute('aria-valuemin', '80');
            resizer.setAttribute('aria-valuemax', '1200');
            resizer.title = 'Resize ' + text + ' column';
            var drag = null;
            resizer.addEventListener('pointerdown', function (event) { event.preventDefault(); drag = { pointer: event.pointerId, start: event.clientX, width: header.getBoundingClientRect().width }; resizer.setPointerCapture(event.pointerId); });
            resizer.addEventListener('pointermove', function (event) { if (drag && drag.pointer === event.pointerId) { resizeColumn(index, drag.width + event.clientX - drag.start); } });
            resizer.addEventListener('pointerup', function () { drag = null; });
            resizer.addEventListener('pointercancel', function () { drag = null; });
            resizer.addEventListener('keydown', function (event) {
                if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') { return; }
                event.preventDefault();
                resizeColumn(index, header.getBoundingClientRect().width + (event.key === 'ArrowRight' ? 16 : -16));
            });
            header.appendChild(resizer);
        });
        var expand = document.createElement('button');
        expand.type = 'button';
        expand.className = 'grid-expand';
        expand.textContent = 'Expand';
        expand.setAttribute('aria-label', 'Expand ' + title + ' table');
        controls.appendChild(expand);
        var dialog = document.createElement('dialog');
        dialog.className = 'grid-dialog';
        dialog.setAttribute('aria-label', title + ' table');
        document.body.appendChild(dialog);
        var placeholder = null;
        function restoreGrid() {
            if (placeholder) { placeholder.parentNode.replaceChild(frame, placeholder); placeholder = null; }
            expand.textContent = 'Expand';
            expand.setAttribute('aria-label', 'Expand ' + title + ' table');
            expand.focus({ preventScroll: true });
        }
        function closeGrid() { if (dialog.open) { dialog.close(); } restoreGrid(); }
        expand.addEventListener('click', function () {
            if (dialog.open) { closeGrid(); return; }
            placeholder = document.createComment('Expanded table');
            frame.parentNode.replaceChild(placeholder, frame);
            dialog.appendChild(frame);
            expand.textContent = 'Close';
            expand.setAttribute('aria-label', 'Close expanded table');
            dialog.showModal();
        });
        dialog.addEventListener('close', function () { if (!dialog.open) { restoreGrid(); } });
        dialog.addEventListener('cancel', function (event) { event.preventDefault(); closeGrid(); });
        window.addEventListener('beforeprint', function () { if (dialog.open) { closeGrid(); } });
        search.addEventListener('input', function () { pageIndex = 0; updateRows(); });
        previous.addEventListener('click', function () { pageIndex--; updateRows(); });
        next.addEventListener('click', function () { pageIndex++; updateRows(); });
        updateRows();
    });
    var kpiSearch = document.getElementById('kpi-search');
    var kpiStatusFilter = document.getElementById('kpi-status-filter');
    var kpiRows = Array.prototype.slice.call(document.querySelectorAll('.kpi-reference-row'));
    if (kpiSearch && kpiStatusFilter) {
        function filterKpis() {
            var query = kpiSearch.value.trim().toLowerCase();
            var status = kpiStatusFilter.value;
            var visibleCount = 0;
            kpiRows.forEach(function (row) {
                var matches = (!query || row.getAttribute('data-kpi-search').toLowerCase().indexOf(query) !== -1) &&
                    (!status || row.getAttribute('data-kpi-status') === status);
                row.hidden = !matches;
                if (matches) { visibleCount++; }
            });
            document.getElementById('kpi-result-count').textContent = visibleCount + ' of ' + kpiRows.length + ' KPIs';
            document.getElementById('kpi-no-results').hidden = visibleCount !== 0;
        }
        kpiSearch.addEventListener('input', filterKpis);
        kpiStatusFilter.addEventListener('change', filterKpis);
    }
  var tabs = Array.prototype.slice.call(document.querySelectorAll('.tab'));
  var panes = Array.prototype.slice.call(document.querySelectorAll('.tabpane'));
    function activate(target) {
        tabs.forEach(function (tab) {
            var active = tab.getAttribute('data-target') === target;
            tab.classList.toggle('active', active);
            tab.setAttribute('aria-selected', String(active));
            tab.tabIndex = active ? 0 : -1;
        });
        panes.forEach(function (pane) { pane.classList.toggle('active', pane.id === target); });
    }
  tabs.forEach(function (t) {
        t.addEventListener('click', function () { activate(t.getAttribute('data-target')); });
        t.addEventListener('keydown', function (event) {
            var index = tabs.indexOf(t);
            if (event.key === 'ArrowRight') { index = (index + 1) % tabs.length; }
            else if (event.key === 'ArrowLeft') { index = (index + tabs.length - 1) % tabs.length; }
            else if (event.key === 'Home') { index = 0; }
            else if (event.key === 'End') { index = tabs.length - 1; }
            else { return; }
            event.preventDefault();
            activate(tabs[index].getAttribute('data-target'));
            tabs[index].focus();
    });
  });
    Array.prototype.forEach.call(document.querySelectorAll('.report-jump'), function (link) {
        link.addEventListener('click', function (event) {
            var heading = document.getElementById(link.getAttribute('href').slice(1));
            if (!heading) { return; }
            event.preventDefault();
            activate(link.getAttribute('data-target'));
            heading.focus();
            heading.scrollIntoView({ block: 'start' });
        });
    });
})();
</script>
</body></html>
'@)

            Write-FinOpsReportFile -Directory $exportDir -Name 'FinOpsReport.html' -Lines @($htmlSb.ToString()) -ErrorAction Stop

            # Summary text file
            $summaryLines = @(
                "FinOps Multitool Scan Summary"
                "Generated: $timestamp"
                "Subscriptions: $subList"
                "Total findings: $totalFindings"
                if ($kpiReferenceIssue) { $kpiReferenceIssue }
                ""
            )
            foreach ($mod in ($Modules | Where-Object { $_.Selected })) {
                $count = if ($Results[$mod.Fn]) { @($Results[$mod.Fn]).Count } else { 0 }
                $errorKey = "_error_$($mod.Fn)"
                $summaryData = $Results[$mod.Fn]
                $summaryNote = @(@($summaryData.Note; $summaryData.Reason; $summaryData.CostIssue; $summaryData.RateIssue; $summaryData.AHBIssue; $summaryData.Error) |
                    Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique) -join ' '
                $status = if ($Results.ContainsKey($errorKey)) { "ERROR: $($Results[$errorKey])" }
                elseif ($Results['_source_Export'].CoverageIncomplete -and $mod.Fn -in @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag', 'Get-CostTrend')) { "Limited data: $($Results['_source_Export'].Note)" }
                elseif ($summaryData.CoverageIncomplete -contains $true -or $summaryData.ComplianceCoverageIncomplete -contains $true -or $summaryData.DefinitionCoverageIncomplete -contains $true -or
                    $summaryData.AccessDenied -contains $true -or @(@($summaryData.CostIssue; $summaryData.RateIssue; $summaryData.AHBIssue; $summaryData.Error) | Where-Object { $_ }).Count -gt 0 -or
                    @($summaryData.MetricFailures | Where-Object { $_ -gt 0 }).Count -gt 0) { "Limited data: $(if ($summaryNote) { $summaryNote } else { 'Some evidence could not be verified.' })" }
                elseif ($count -eq 0) { 'No data' }
                else { "$count findings" }
                $summaryLines += "$($mod.Name): $status"
            }
            Write-FinOpsReportFile -Directory $exportDir -Name 'ScanSummary.txt' -Lines $summaryLines -ErrorAction Stop

            Write-FinOpsConsole ""
            Write-FinOpsConsole "  Exported to: $exportDir" -ForegroundColor Green
            $csvCount = @(Get-ChildItem -LiteralPath $exportDir -Filter '*.csv').Count
            Write-FinOpsConsole "  Files: $csvCount CSVs + FinOpsReport.html + ScanSummary.txt" -ForegroundColor DarkGray
        }
        catch {
            $partialLocation = if ($exportDir) { " Incomplete reports may remain in '$exportDir'." } else { '' }
            Write-Error -Message "Automatic report saving failed: $($_.Exception.Message). Results remain in `$FinOpsResults.$partialLocation" -ErrorId 'FinOpsReportExportFailed' -Category WriteError
        }

        # Interactive drill-down
        Write-FinOpsConsole ""
        Write-FinOpsConsole "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-FinOpsConsole "  Results are stored in `$FinOpsResults. Examples:" -ForegroundColor DarkGray
        Write-FinOpsConsole '    $FinOpsResults["Get-OrphanedResources"] | Format-Table' -ForegroundColor DarkGray
        Write-FinOpsConsole '    $FinOpsResults["Get-IdleVMs"] | Where-Object Impact -eq "High"' -ForegroundColor DarkGray
        Write-FinOpsConsole ""

        return $Results
    }

    # =====================================================================
    #  MAIN FLOW
    # =====================================================================
    Show-Banner

    # Step 1: Connect & pick subscription
    $subs = Select-Subscription -PreselectedId $SubscriptionId
    if (-not $subs) {
        Write-FinOpsConsole "  Cancelled." -ForegroundColor Yellow
        return
    }

    # Capture tenant ID from current context
    $tenantId = (Get-AzContext).Tenant.Id

    # Step 2: Pick data source
    # Must not be named $dataSource: PowerShell variable names are case-insensitive,
    # so that would reassign the -DataSource parameter and trip its ValidateSet.
    $sourceChoice = Select-DataSource -TenantId $tenantId -Subscriptions $subs -Preselected $DataSource

    # If "Resource Graph only", disable cost modules
    $costModuleFns = @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag', 'Get-CostTrend',
        'Get-SavingsRealized', 'Get-CommitmentUtilization', 'Get-ReservationAdvice',
        'Get-BudgetStatus', 'Get-BudgetHistory', 'Get-AnomalyAlerts', 'Get-BillingStructure', 'Get-ContractInfo',
        'Get-UnitEconomics', 'Get-AIWorkloadMetrics', 'Get-MaccCommitment',
        'Get-VmCostBreakdown', 'Get-SharedCostAllocation', 'Get-UsageProportionalAllocation')
    if ($sourceChoice.Source -eq 'GraphOnly') {
        $scanModules = @($scanModules | Where-Object { $_.Fn -notin $costModuleFns })
        if (-not ($scanModules | Where-Object { $_.Selected })) {
            Write-Warning "Every selected scan needs cost data, which the 'Resource Graph only' source excludes. Nothing left to run."
            return
        }
    }
    if ($sourceChoice.Source -eq 'Export') {
        $unsupportedExportScans = @($costModuleFns | Where-Object { $_ -notin @('Get-CostData', 'Get-ResourceCosts', 'Get-CostByTag', 'Get-CostTrend') })
        if ($Scans -and $Scans -notcontains 'All') {
            $requestedUnsupported = @($scanModules | Where-Object { $_.Selected -and $_.Fn -in $unsupportedExportScans })
            if ($requestedUnsupported.Count) { throw "The requested scan(s) are not supported by the CSV export source: $($requestedUnsupported.Fn -join ', '). Select API or Hub explicitly for those scans." }
        }
        $scanModules = @($scanModules | Where-Object { $_.Fn -notin $unsupportedExportScans })
        Write-FinOpsConsole '  Export mode supports cost totals, resource costs, cost by tag, and the months present in the selected export.' -ForegroundColor Cyan
        Write-FinOpsConsole '  Other available scans read live inventory or metrics. Financial scans requiring separate APIs are excluded.' -ForegroundColor DarkGray
    }

    # Show active data source
    $sourceLabel = switch ($sourceChoice.Source) {
        'Hub' { if ($sourceChoice.HubProvider) { "FinOps Hub ($($sourceChoice.HubProvider.ClusterUri), $($sourceChoice.HubProvider.Database))" } else { "FinOps Hub ($($sourceChoice.HubStorage.name))" } }
        'Export' { "Cost Management export ($($sourceChoice.Export.Name); CSV storage)" }
        'API' { 'Cost Management API (real-time)' }
        'GraphOnly' { 'Resource Graph only (no cost data)' }
    }
    $sourceColor = switch ($sourceChoice.Source) { 'Hub' { 'Green' } 'Export' { 'Cyan' } 'API' { 'Yellow' } 'GraphOnly' { 'DarkGray' } }
    Write-FinOpsConsole ""
    Write-FinOpsConsole "  Data source: $sourceLabel" -ForegroundColor $sourceColor
    Write-FinOpsConsole ""

    # Step 3: Pick scans
    $finalModules = Select-ScanModules -Modules $scanModules
    if (-not $finalModules) {
        Write-FinOpsConsole "  Cancelled." -ForegroundColor Yellow
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
    if ($sourceChoice.Source -eq 'Export') { $deps['Get-CostByTag'] = @('Get-CostData') }
    foreach ($depEntry in $deps.GetEnumerator()) {
        if ($depEntry.Key -in $selectedFns) {
            foreach ($req in $depEntry.Value) {
                if ($req -notin $selectedFns) {
                    $mod = $finalModules | Where-Object { $_.Fn -eq $req }
                    if ($mod) {
                        $mod.Selected = $true
                        Write-FinOpsConsole "  Auto-enabled: $($mod.Name) (required by $($depEntry.Key -replace 'Get-',''))" -ForegroundColor DarkGray
                    }
                }
            }
        }
    }

    if ($sourceChoice.Source -eq 'GraphOnly' -and @($finalModules | Where-Object { $_.Selected -and $_.Fn -in $costModuleFns }).Count -gt 0) {
        throw 'Resource Graph only cannot run a scan or dependency that requires cost data.'
    }

    # Step 4: Run
    $results = Invoke-SelectedScans -Modules $finalModules -Subscriptions $subs -TenantId $tenantId -DataSource $sourceChoice -PermissionInfo $permissionInfo
    # Keep the documented drill-down name; each run overwrites any global value, including one set by the caller.
    $global:FinOpsResults = $results

    # Step 5: Summary + export
    $effectiveSource = switch ($sourceChoice.Source) {
        'Hub' { if ($sourceChoice.HubProvider) { "FinOps Hub ($($sourceChoice.HubProvider.ClusterUri), $($sourceChoice.HubProvider.Database))" } else { "FinOps Hub ($($sourceChoice.HubStorage.name))" } }
        'Export' { "Cost Management export ($($sourceChoice.Export.Name)). $($sourceChoice.CoverageNote)" }
        'API' { 'Cost Management API (real-time)' }
        'GraphOnly' { 'Resource Graph only (no cost data)' }
        default { [string]$sourceChoice.Source }
    }
    $null = Show-ResultsSummary -Results $results -Modules $finalModules -ExportPath $OutputPath -Subscriptions $subs -DataSourceLabel $effectiveSource

    Write-FinOpsConsole "  Done. Results available in `$FinOpsResults" -ForegroundColor Green
    Write-FinOpsConsole ""
}

# Auto-invoke when run directly (not dot-sourced or imported as module)
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-FinOpsMultitool @PSBoundParameters
}
