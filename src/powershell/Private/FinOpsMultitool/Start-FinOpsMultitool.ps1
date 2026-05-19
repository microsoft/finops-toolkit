# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# FINOPSMULTITOOL
###########################################################################
# Purpose: Launch the AZURE FINOPS MULTITOOL WPF application. Authenticates
#          to Azure, scans the tenant for cost/tag/optimization data, and
#          displays results in an interactive GUI.
#
# Usage:   .\Start-FinOpsMultitool.ps1
#
# Requirements:
#   - PowerShell 5.1+ (Windows) or 7+ with WindowsCompatibility
#   - Az PowerShell modules: Az.Accounts, Az.Resources, Az.ResourceGraph,
#     Az.CostManagement, Az.Advisor, Az.Billing
#   - Azure RBAC: Reader + Cost Management Reader on target scope
###########################################################################

#Requires -Version 5.1

# -- Load WPF Assemblies ------------------------------------------------
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# -- Shared Helper: Get-PlainAccessToken ------------------------------------
# Get-AzAccessToken returns SecureString in Az.Accounts >= 3.0.
# This helper always returns a plain-text bearer token string.
function Get-PlainAccessToken {
    param([string]$ResourceUrl = 'https://management.azure.com')
    $tok = (Get-AzAccessToken -ResourceUrl $ResourceUrl).Token
    if ($tok -is [securestring]) {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tok)
        try   { [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
        finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    } else { $tok }
}

# -- Shared Helper: Invoke-AzRestMethodWithRetry ----------------------------
# Wraps Invoke-AzRestMethod with:
#   - Background runspace with 60s timeout (prevents indefinite hangs)
#   - Automatic retry on HTTP 429 (throttling) with DispatcherFrame UI wait
# Cost Management API rate-limits aggressively; per-sub queries across
# multiple scan stages can exhaust the quota quickly.
function Invoke-AzRestMethodWithRetry {
    param(
        [string]$Path,
        [string]$Method = 'POST',
        [string]$Payload,
        [int]$MaxRetries = 3,
        [int]$TimeoutSeconds = 60
    )
    for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
        # Run Invoke-AzRestMethod in a background runspace so it can be
        # killed on timeout (the cmdlet has no TimeoutSec parameter).
        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript({
            param($p, $m, $pl)
            $params = @{ Path = $p; Method = $m; ErrorAction = 'Stop' }
            if ($pl) { $params['Payload'] = $pl }
            $r = Invoke-AzRestMethod @params
            # Return a simple hashtable that survives runspace serialization
            $hdrs = @{}
            if ($r.Headers) {
                foreach ($k in $r.Headers.Keys) { $hdrs[$k] = $r.Headers[$k] }
            }
            [PSCustomObject]@{
                StatusCode = $r.StatusCode
                Content    = $r.Content
                Headers    = $hdrs
            }
        }).AddArgument($Path).AddArgument($Method).AddArgument($Payload)

        $asyncResult = $ps.BeginInvoke()
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

        # DispatcherFrame loop keeps WPF UI responsive while waiting
        while (-not $asyncResult.IsCompleted -and (Get-Date) -lt $deadline) {
            $frame = [System.Windows.Threading.DispatcherFrame]::new()
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action]{ $frame.Continue = $false }
            )
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
            Start-Sleep -Milliseconds 100
        }

        $resp = $null
        if ($asyncResult.IsCompleted) {
            try {
                $raw = $ps.EndInvoke($asyncResult)
                $resp = if ($raw -and $raw.Count -gt 0) { $raw[0] } else { $null }
            } catch {
                $ps.Dispose(); $rs.Close()
                throw
            }
        } else {
            $ps.Stop()
            Write-Warning "  REST call timed out after $($TimeoutSeconds)s: $Method $Path"
            $ps.Dispose(); $rs.Close()
            # Return a synthetic timeout response
            return [PSCustomObject]@{ StatusCode = 408; Content = '{"error":{"message":"Request timed out"}}'; Headers = @{} }
        }

        $ps.Dispose()
        $rs.Close()

        # Ensure we never return null or a response with null Content
        if (-not $resp) {
            $resp = [PSCustomObject]@{ StatusCode = 0; Content = $null; Headers = @{} }
        }
        if ($null -eq $resp.Content) {
            $resp = [PSCustomObject]@{ StatusCode = $resp.StatusCode; Content = '{}'; Headers = if ($resp.Headers) { $resp.Headers } else { @{} } }
        }

        if ($resp.StatusCode -ne 429) { return $resp }

        # Parse Retry-After header or default to exponential backoff
        $retryAfter = 10
        if ($resp.Headers -and $resp.Headers['Retry-After']) {
            $parsed = 0
            if ([int]::TryParse($resp.Headers['Retry-After'], [ref]$parsed)) {
                $retryAfter = [math]::Max($parsed, 5)
            }
        } else {
            $retryAfter = [math]::Min(10 * [math]::Pow(2, $attempt), 60)
        }
        Write-Host "  [429 Throttled] Waiting $($retryAfter)s before retry ($($attempt+1)/$MaxRetries)..." -ForegroundColor Yellow

        # Update status bar if available
        if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
            Update-ScanStatus "Rate limited - waiting $($retryAfter)s before retry ($($attempt+1)/$MaxRetries)..."
        }

        # Dispatcher-friendly wait: DispatcherFrame nested message loop
        $waitEnd = (Get-Date).AddSeconds($retryAfter)
        while ((Get-Date) -lt $waitEnd) {
            $frame = [System.Windows.Threading.DispatcherFrame]::new()
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action]{ $frame.Continue = $false }
            )
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
            Start-Sleep -Milliseconds 100
        }
    }
    return $resp  # Return last 429 response if all retries exhausted
}

# -- Shared MG-Scope State ------------------------------------------------
# First cost module that gets 401/403 at MG scope sets this to $true.
# All subsequent modules check it and skip to per-sub immediately.
$script:MgCostScopeFailed = $false

function Test-MgCostScope {
    return (-not $script:MgCostScopeFailed)
}

function Set-MgCostScopeFailed {
    $script:MgCostScopeFailed = $true
    Write-Host "  MG-scope cost access unavailable for this tenant - all subsequent modules will use per-subscription queries" -ForegroundColor Yellow
}

# -- Shared Helper: Search-AzGraphSafe ------------------------------------
# Wraps Search-AzGraph with:
#   - 60-second timeout via background runspace (prevents indefinite hangs)
#   - Automatic retry on 429 throttling with DispatcherFrame UI-responsive wait
#   - Returns $null on timeout so callers can handle gracefully
function Search-AzGraphSafe {
    param(
        [Parameter(Mandatory)][string]$Query,
        [string[]]$Subscription,
        [int]$First = 1000,
        [string]$SkipToken,
        [int]$TimeoutSeconds = 60,
        [int]$MaxRetries = 2
    )
    for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
        # Build Search-AzGraph in a background runspace so it can be killed on timeout
        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript({
            param($q, $s, $f, $st)
            $p = @{ Query = $q; Subscription = $s; First = $f; ErrorAction = 'Stop' }
            if ($st) { $p['SkipToken'] = $st }
            $r = Search-AzGraph @p
            # Serialize data to JSON inside the runspace to preserve nested
            # property hierarchy.  Deserialized PSObjects lose navigability
            # for deep properties like $row.properties.displayName.
            $json = if ($r.Data -and $r.Data.Count -gt 0) {
                $r.Data | ConvertTo-Json -Depth 20 -Compress
            } else { '[]' }
            [PSCustomObject]@{
                JsonData  = $json
                SkipToken = $r.SkipToken
                Count     = if ($r.Data) { $r.Data.Count } else { 0 }
            }
        }).AddArgument($Query).AddArgument($Subscription).AddArgument($First).AddArgument($SkipToken)

        $asyncResult = $ps.BeginInvoke()
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

        # DispatcherFrame loop keeps WPF UI responsive while waiting
        while (-not $asyncResult.IsCompleted -and (Get-Date) -lt $deadline) {
            $frame = [System.Windows.Threading.DispatcherFrame]::new()
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action]{ $frame.Continue = $false }
            )
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
            Start-Sleep -Milliseconds 100
        }

        $result = $null
        $is429  = $false
        if ($asyncResult.IsCompleted) {
            try {
                $raw = $ps.EndInvoke($asyncResult)
                # EndInvoke returns PSDataCollection; unwrap to get our PSCustomObject
                $wrapper = if ($raw -and $raw.Count -gt 0) { $raw[0] } else { $null }
                if ($wrapper) {
                    # Re-hydrate data from JSON to restore nested property hierarchy
                    $data = if ($wrapper.JsonData -and $wrapper.JsonData -ne '[]') {
                        $parsed = $wrapper.JsonData | ConvertFrom-Json
                        # ConvertFrom-Json returns single object if 1 row, wrap in array
                        if ($parsed -is [array]) { $parsed } else { @($parsed) }
                    } else { @() }
                    $result = [PSCustomObject]@{
                        Data      = $data
                        SkipToken = $wrapper.SkipToken
                        Count     = $wrapper.Count
                    }
                }
                # Check for 429 errors in the error stream
                if ($ps.Streams.Error.Count -gt 0) {
                    $errMsg = $ps.Streams.Error[0].Exception.Message
                    if ($errMsg -match '429|throttl|Too Many Requests') { $is429 = $true; $result = $null }
                    elseif (-not $result) { throw $ps.Streams.Error[0].Exception }
                }
            } catch {
                if ($_.Exception.Message -match '429|throttl|Too Many Requests') { $is429 = $true }
                else { $ps.Dispose(); $rs.Close(); throw }
            }
        } else {
            $ps.Stop()
            Write-Warning "  Resource Graph query timed out after $($TimeoutSeconds)s"
        }

        $ps.Dispose()
        $rs.Close()

        # If not 429, return whatever we got
        if (-not $is429) { return $result }

        # 429 retry with DispatcherFrame wait
        $retryAfter = [math]::Min(10 * [math]::Pow(2, $attempt), 30)
        Write-Host "  [429 Throttled - Resource Graph] Waiting $($retryAfter)s before retry ($($attempt+1)/$MaxRetries)..." -ForegroundColor Yellow
        if (Get-Command Update-ScanStatus -ErrorAction SilentlyContinue) {
            Update-ScanStatus "Resource Graph rate limited - waiting $($retryAfter)s..."
        }
        $waitEnd = (Get-Date).AddSeconds($retryAfter)
        while ((Get-Date) -lt $waitEnd) {
            $frame = [System.Windows.Threading.DispatcherFrame]::new()
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action]{ $frame.Continue = $false }
            )
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
            Start-Sleep -Milliseconds 100
        }
    }
    return $null  # All retries exhausted
}

# -- Dot-Source Modules -------------------------------------------------
$script:ScriptRootDir = $PSScriptRoot
$modulePath = Join-Path $PSScriptRoot 'modules'
. (Join-Path $modulePath 'Initialize-Scanner.ps1')
. (Join-Path $modulePath 'Get-TenantHierarchy.ps1')
. (Join-Path $modulePath 'Get-ContractInfo.ps1')
. (Join-Path $modulePath 'Get-CostData.ps1')
. (Join-Path $modulePath 'Get-ResourceCosts.ps1')
. (Join-Path $modulePath 'Get-TagInventory.ps1')
. (Join-Path $modulePath 'Get-CostByTag.ps1')
. (Join-Path $modulePath 'Get-AHBOpportunities.ps1')
. (Join-Path $modulePath 'Get-ReservationAdvice.ps1')
. (Join-Path $modulePath 'Get-OptimizationAdvice.ps1')
. (Join-Path $modulePath 'Get-TagRecommendations.ps1')
. (Join-Path $modulePath 'Get-CostTrend.ps1')
. (Join-Path $modulePath 'Deploy-ResourceTag.ps1')
. (Join-Path $modulePath 'Get-BillingStructure.ps1')
. (Join-Path $modulePath 'Get-CommitmentUtilization.ps1')
. (Join-Path $modulePath 'Get-OrphanedResources.ps1')
. (Join-Path $modulePath 'Get-BudgetStatus.ps1')
. (Join-Path $modulePath 'Get-AnomalyAlerts.ps1')
. (Join-Path $modulePath 'Get-SavingsRealized.ps1')
. (Join-Path $modulePath 'Get-PolicyInventory.ps1')
. (Join-Path $modulePath 'Get-PolicyRecommendations.ps1')
. (Join-Path $modulePath 'Deploy-PolicyAssignment.ps1')
. (Join-Path $modulePath 'Get-StorageTierAdvice.ps1')
. (Join-Path $modulePath 'Get-IdleVMs.ps1')

# -- Load XAML ----------------------------------------------------------
$xamlPath = Join-Path $PSScriptRoot 'gui\MainWindow.xaml'
$xamlContent = Get-Content $xamlPath -Raw

# Remove x:Name -> Name for FindName compatibility
$xamlContent = $xamlContent -replace 'x:Name=', 'Name='
# Remove x:Key and x:Class attributes that cause parse issues
$xamlContent = $xamlContent -replace 'x:Class="[^"]*"', ''

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
$window = [System.Windows.Markup.XamlReader]::Load($reader)
$script:window = $window

# Set custom window icon
$icoPath = Join-Path $PSScriptRoot 'gui\app.ico'
if (Test-Path $icoPath) {
    $iconUri = [System.Uri]::new($icoPath)
    $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create($iconUri)
}

# -- Find Named Controls -----------------------------------------------
$controls = @(
    'TenantLabel', 'VersionLabel', 'TenantButton', 'GovTenantButton', 'ScanButton', 'ExportButton',
    'ProgressBar', 'StatusText', 'HierarchyTree', 'DetailTabs',
    # Overview
    'ContractTypeText', 'ContractDetailText', 'TotalCostText',
    'ForecastText', 'SubCountText', 'TotalSavingsText', 'SubCostGrid',
    'ResourceCostGrid',
    'ResourceCountNote',
    # Cost Analysis
    'TrendChart', 'TrendNote', 'TrendSubSelector',
    'TagSelector', 'CostByTagGrid', 'NoTagsLabel',
    # Tags
    'TagCountText', 'TagCoverageText', 'UntaggedCountText',
    'TagInventoryGrid', 'TagComplianceText', 'TagRecsGrid',
    'UntaggedNote', 'UntaggedResourcesGrid',
    'CustomTagButton', 'TagDeployPanel', 'TagDeployTitle',
    'TagNameLabel', 'TagNameInput',
    'TagScopeSelector', 'TagValueInput', 'TagDeployButton',
    'TagDeployCancelButton', 'TagDeployStatus',
    # Overview - Budget & Scorecard
    'SavingsRealizedText', 'SavingsRealizedDetail',
    'BudgetSummaryText', 'BudgetGrid', 'ScorecardGrid',
    # Cost Analysis - Anomalies
    'AnomalyNote', 'AnomalyGrid',
    # Cost Analysis - API Alerts
    'AlertsSummaryNote', 'TriggeredAlertsGrid', 'ConfiguredRulesGrid',
    # Optimization
    'AHBCountText', 'AHBDetailText', 'OrphanCountText', 'OrphanDetailText',
    'RIUtilText', 'RIUtilDetail', 'RIContractNote', 'SPContractNote',
    'AdvisorCountText', 'AdvisorSavingsText', 'AHBSummaryText',
    'AHBGrid', 'RIGrid', 'SPGrid', 'AdvisorGrid',
    'CommitmentGrid', 'OrphanGrid', 'OrphanSummaryText',
    'IdleVMGrid', 'IdleVMSummaryText',
    'StorageTierGrid', 'StorageTierSummaryText',
    # Resources Tab
    'ResourcesPanel', 'ResourcesFinOpsPanel', 'ResourcesCostPanel',
    'ResourcesRatePanel', 'ResourcesGovernancePanel', 'ResourcesToolsPanel',
    # Billing
    'BillingAccessNote', 'BillingAccountsGrid', 'BillingProfilesGrid',
    'InvoiceSectionsGrid', 'EADeptHeader', 'EADeptGrid', 'CostAllocationGrid',
    # Budgets Tab
    'BudgetSubSelector', 'BudgetSubSummary', 'BudgetDetailGrid',
    'BudgetDeployPanel', 'BudgetDeployScopeSelector',
    'BudgetDeployNameInput', 'BudgetDeployAmountInput', 'BudgetDeployGrainSelector',
    'BudgetDeployEmailInput', 'BudgetActionGroupSelector',
    'BudgetThreshold1', 'BudgetThreshold1Type',
    'BudgetThreshold2', 'BudgetThreshold2Type',
    'BudgetThreshold3', 'BudgetThreshold3Type',
    'BudgetThreshold4', 'BudgetThreshold4Type',
    'BudgetDeployTagNameSelector', 'BudgetDeployTagValueInput',
    'BudgetDeployButton', 'BudgetDeployCancelButton', 'BudgetDeployStatus',
    'BudgetPolicyPanel', 'BudgetPolicyEffectSelector', 'BudgetPolicyScopeSelector',
    'BudgetPolicyDeployButton', 'BudgetPolicyCancelButton', 'BudgetPolicyStatus',
    # Guidance
    'GuidanceScorePanel', 'ActionPlanSubtitle', 'ActionPlanPanel',
    'UnderstandPanel', 'QuantifyPanel', 'OptimizePanel',
    'PersonasPanel',
    # Policy
    'PolicyCountText', 'PolicyComplianceText', 'PolicyNonCompliantText',
    'PolicyRecsCountText', 'PolicyInventoryGrid', 'PolicyComplianceGrid',
    'PolicyRecsComplianceText', 'PolicyRecsGrid',
    'PolicyDeployPanel', 'PolicyDeployTitle', 'PolicyScopeSelector',
    'PolicyEffectSelector', 'PolicyParamsPanel', 'PolicyDeployButton',
    'PolicyRemediateButton', 'PolicyDeployCancelButton', 'PolicyDeployStatus'
)

foreach ($name in $controls) {
    $ctrl = $window.FindName($name)
    if ($ctrl) { Set-Variable -Name $name -Value $ctrl -Scope Script }
}

# -- Global Scan Data --------------------------------------------------
$script:scanData = @{
    Auth          = $null
    Hierarchy     = $null
    Contract      = $null
    Costs         = $null
    ResourceCosts = $null
    Tags          = $null
    CostByTag     = $null
    CostTrend     = $null
    AHB           = $null
    Reservations  = $null
    Optimization  = $null
    TagRecs       = $null
    Billing       = $null
    Commitments   = $null
    Orphans       = $null
    Budgets       = $null
    Savings       = $null
    PolicyInv     = $null
    PolicyRecs    = $null
    StorageTier   = $null
    IdleVMs       = $null
}

# -- Session Action Log (tags deployed/removed, policies assigned/unassigned) --
$script:actionLog = [System.Collections.Generic.List[PSCustomObject]]::new()

###########################################################################
# HELPER FUNCTIONS
###########################################################################

function Update-UIStatus {
    param([string]$Message, [int]$Percent)
    $script:StatusText.Text = $Message
    $script:ProgressBar.Value = $Percent
    # Force UI refresh
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
        [action]{}, [System.Windows.Threading.DispatcherPriority]::Background
    )
}

# Lightweight status update for modules to call mid-loop (no progress bar change).
# Keeps the UI responsive during long per-subscription iterations.
function Update-ScanStatus {
    param([string]$Message)
    if ($script:StatusText) {
        $script:StatusText.Text = $Message
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [action]{}, [System.Windows.Threading.DispatcherPriority]::Background
        )
    }
}

function Get-CurrencySymbol {
    param([string]$Code)
    switch ($Code) {
        'USD' { '$' }
        'EUR' { [char]0x20AC }
        'GBP' { [char]0x00A3 }
        'JPY' { [char]0x00A5 }
        'CAD' { 'C$' }
        'AUD' { 'A$' }
        'CHF' { 'CHF ' }
        'INR' { [char]0x20B9 }
        'BRL' { 'R$' }
        'KRW' { [char]0x20A9 }
        'MXN' { 'MX$' }
        'SEK' { 'kr ' }
        'NOK' { 'kr ' }
        'DKK' { 'kr ' }
        'ZAR' { 'R ' }
        default { "$Code " }
    }
}

# -- Tree View Population ----------------------------------------------
function Add-HierarchyNode {
    param(
        [object]$Group,
        [System.Windows.Controls.ItemsControl]$Parent,
        [hashtable]$CostMap,
        [object[]]$Subscriptions
    )

    $groupItem = [System.Windows.Controls.TreeViewItem]::new()
    $groupItem.Header = "[MG] $($Group.DisplayName)"
    $groupItem.IsExpanded = $true
    $groupItem.Tag = @{ Type = 'MG'; Id = $Group.Name; Name = $Group.DisplayName }
    $groupItem.FontWeight = 'SemiBold'
    $Parent.Items.Add($groupItem) | Out-Null

    if ($Group.Children) {
        foreach ($child in $Group.Children) {
            if ($child.Type -eq '/subscriptions') {
                $subItem = [System.Windows.Controls.TreeViewItem]::new()
                $cost = ''
                if ($CostMap -and $CostMap.ContainsKey($child.Name)) {
                    $c = $CostMap[$child.Name]
                    $cost = "  [$($c.Currency) $($c.Actual.ToString('N2'))]"
                }
                $subItem.Header = "[$] $($child.DisplayName)$cost"
                $subItem.Tag = @{ Type = 'Sub'; Id = $child.Name; Name = $child.DisplayName }
                $subItem.FontWeight = 'Normal'
                $groupItem.Items.Add($subItem) | Out-Null
            }
            elseif ($child.Children -or $child.Type -match 'managementGroups') {
                Add-HierarchyNode -Group $child -Parent $groupItem -CostMap $CostMap -Subscriptions $Subscriptions
            }
        }
    }
}

# -- Tab Population Functions ------------------------------------------
function Populate-OverviewTab {
    $d = $script:scanData

    # Contract
    if ($d.Contract -and $d.Contract.Count -gt 0) {
        $primary = $d.Contract[0]
        $script:ContractTypeText.Text = $primary.FriendlyType
        $script:ContractDetailText.Text = $primary.AccountName
    }

    # Subscription count
    $subCount = $d.Auth.Subscriptions.Count
    $skippedCount = if ($d.Auth.SkippedSubs) { $d.Auth.SkippedSubs.Count } else { 0 }
    if ($skippedCount -gt 0) {
        $script:SubCountText.Text = "$subCount (+$skippedCount skipped)"
    } else {
        $script:SubCountText.Text = $subCount.ToString()
    }

    # Total costs
    $totalActual = 0; $totalForecast = 0; $currency = 'USD'
    if ($d.Costs) {
        foreach ($entry in $d.Costs.GetEnumerator()) {
            $totalActual   += $entry.Value.Actual
            $totalForecast += $entry.Value.Forecast
            $currency = $entry.Value.Currency
        }
    }
    $script:TotalCostText.Text  = "$(Get-CurrencySymbol $currency)$($totalActual.ToString('N2'))"
    $script:ForecastText.Text   = "$(Get-CurrencySymbol $currency)$($totalForecast.ToString('N2'))"

    # Total savings
    $totalSavings = 0
    if ($d.Optimization) { $totalSavings += $d.Optimization.EstimatedAnnualSavings }
    if ($d.Reservations) { $totalSavings += $d.Reservations.EstimatedAnnualSavings }
    $script:TotalSavingsText.Text = "`$$($totalSavings.ToString('N2'))/yr"

    # Savings Realized card
    if ($d.Savings) {
        $sym = Get-CurrencySymbol $currency
        $script:SavingsRealizedText.Text = "$sym$($d.Savings.TotalMonthly.ToString('N2'))/mo"
        $parts = @()
        if ($d.Savings.RISavingsMonthly -gt 0) { $parts += "RI: $sym$($d.Savings.RISavingsMonthly.ToString('N0'))" }
        if ($d.Savings.SPSavingsMonthly -gt 0) { $parts += "SP: $sym$($d.Savings.SPSavingsMonthly.ToString('N0'))" }
        if ($d.Savings.AHBSavingsMonthly -gt 0) { $parts += "AHB: $sym$($d.Savings.AHBSavingsMonthly.ToString('N0'))" }
        $script:SavingsRealizedDetail.Text = if ($parts.Count -gt 0) { $parts -join ' | ' } else { 'No existing commitment savings detected' }
    }

    # Subscription cost grid
    $subRows = [System.Collections.Generic.List[PSCustomObject]]::new()
    $totalSubActual = 0
    if ($d.Costs) {
        foreach ($entry in $d.Costs.GetEnumerator()) { $totalSubActual += $entry.Value.Actual }
    }
    foreach ($sub in $d.Auth.Subscriptions) {
        $c = if ($d.Costs -and $d.Costs.ContainsKey($sub.Id)) { $d.Costs[$sub.Id] } else { @{ Actual = 0; Forecast = 0; Currency = 'USD' } }
        $pct = if ($totalSubActual -gt 0) { [math]::Round(($c.Actual / $totalSubActual) * 100, 2) } else { 0 }

        # Estimate orphan savings for this sub
        $orphanSave = 0.0
        if ($d.Orphans -and $d.Orphans.Orphans) {
            $subOrphans = @($d.Orphans.Orphans | Where-Object { $_.SubscriptionId -eq $sub.Id })
            foreach ($o in $subOrphans) {
                $orphanSave += switch ($o.Category) {
                    'Orphaned Disk'          {
                        $diskGb = 0
                        if ($o.Detail -match '(\d+)\s*GB') { $diskGb = [int]$Matches[1] }
                        if ($o.Detail -match 'Premium')    { $diskGb * 0.12 }
                        elseif ($o.Detail -match 'Standard_SSD') { $diskGb * 0.075 }
                        else { $diskGb * 0.04 }
                    }
                    'Unattached Public IP'   { 3.65 }
                    'Unattached NIC'         { 0 }
                    'Deallocated VM'         { 15 }
                    'Empty App Service Plan' { 55 }
                    'Old Snapshot'           { 5 }
                    default                  { 5 }
                }
            }
        }
        $sym = Get-CurrencySymbol $c.Currency

        [void]$subRows.Add([PSCustomObject]@{
            Subscription         = $sub.Name
            'Actual (MTD)'       = $c.Actual.ToString('N2')
            'Forecast'           = $c.Forecast.ToString('N2')
            '% of Total'         = "$pct%"
            Currency             = $c.Currency
        })
    }
    $script:SubCostGrid.ItemsSource = @($subRows | Sort-Object { [double]($_.'Actual (MTD)') } -Descending)

    # Resource cost grid — dynamic threshold: include resources >= 0.1% of total forecast
    if ($d.ResourceCosts -and $d.ResourceCosts.Count -gt 0) {
        $totalActualAll = ($d.ResourceCosts | Measure-Object -Property Actual -Sum).Sum
        $sorted = @($d.ResourceCosts | Sort-Object { $_.Actual } -Descending)
        $totalResources = $sorted.Count

        # Dynamic spend threshold: 0.1% of total actual spend (minimum $1 to filter noise)
        $threshold = [math]::Max(1.0, $totalActualAll * 0.001)
        $display = @($sorted | Where-Object { $_.Actual -ge $threshold })
        # Safety: if threshold filters everything, show top 50
        if ($display.Count -eq 0) { $display = @($sorted | Select-Object -First 50) }

        $resRows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($r in $display) {
            $pct = if ($totalActualAll -gt 0) { [math]::Round(($r.Actual / $totalActualAll) * 100, 2) } else { 0 }
            [void]$resRows.Add([PSCustomObject]@{
                'Resource Group' = $r.ResourceGroup
                'Resource Type'  = $r.ResourceType
                'Actual (MTD)'   = $r.Actual.ToString('N2')
                'Forecast'       = $r.Forecast.ToString('N2')
                '% of Total'     = "$pct%"
                'Currency'       = $r.Currency
                'Resource Path'  = $r.ResourcePath
            })
        }
        $script:ResourceCostGrid.ItemsSource = @($resRows)

        $excluded = $totalResources - $display.Count
        if ($excluded -gt 0) {
            $script:ResourceCountNote.Text = "$($display.Count) of $totalResources resources shown (threshold: $(Get-CurrencySymbol $currency)$($threshold.ToString('N2'))/mo MTD, $excluded below threshold)"
        } else {
            $script:ResourceCountNote.Text = "$totalResources resources"
        }
    }

    # Populate tree
    $script:HierarchyTree.Items.Clear()
    if ($d.Hierarchy -and $d.Hierarchy.RootGroup) {
        Add-HierarchyNode -Group $d.Hierarchy.RootGroup -Parent $script:HierarchyTree `
            -CostMap $d.Costs -Subscriptions $d.Auth.Subscriptions
    }
    elseif ($d.Hierarchy -and $d.Hierarchy.FlatSubs) {
        foreach ($sub in $d.Hierarchy.FlatSubs) {
            $item = [System.Windows.Controls.TreeViewItem]::new()
            $cost = ''
            if ($d.Costs -and $d.Costs.ContainsKey($sub.Id)) {
                $c = $d.Costs[$sub.Id]
                $cost = "  [$($c.Currency) $($c.Actual.ToString('N2'))]"
            }
            $item.Header = "[$] $($sub.Name)$cost"
            $item.Tag = @{ Type = 'Sub'; Id = $sub.Id; Name = $sub.Name }
            $script:HierarchyTree.Items.Add($item) | Out-Null
        }
    }
}

function Populate-CostTab {
    $d = $script:scanData.CostByTag

    if (-not $d -or $d.NoTagsFound) {
        $script:NoTagsLabel.Text = "[!] No cost-allocation tags found (CostCenter, Environment, Application, etc.). Without these tags, costs cannot be broken down by business dimension. See the Tags tab for recommended tags to implement."
        return
    }

    if ($script:TagSelector) {
        $script:TagSelector.Items.Clear()
        foreach ($tagName in $d.TagsQueried) {
            $script:TagSelector.Items.Add($tagName) | Out-Null
        }
        if ($d.TagsQueried.Count -gt 0) {
            $script:TagSelector.SelectedIndex = 0
        }
    }
}

function Populate-TagsTab {
    $d = $script:scanData

    # Tag summary
    if ($d.Tags) {
        $script:TagCountText.Text     = if ($null -ne $d.Tags.TagCount) { $d.Tags.TagCount.ToString() } else { '0' }
        $script:TagCoverageText.Text  = if ($null -ne $d.Tags.TagCoverage) { "$($d.Tags.TagCoverage)%" } else { '0%' }
        $script:UntaggedCountText.Text = if ($null -ne $d.Tags.UntaggedCount) { $d.Tags.UntaggedCount.ToString('N0') } else { '0' }

        # Inventory grid - preserve all tag value casing variants for discovery
        $script:TagInventoryGrid.AutoGenerateColumns = $false
        $script:TagInventoryGrid.Columns.Clear()

        # Data columns
        foreach ($col in @('Tag Name','Resources','Unique Values','Values')) {
            $dgCol = [System.Windows.Controls.DataGridTextColumn]::new()
            $dgCol.Header = $col
            $dgCol.Binding = [System.Windows.Data.Binding]::new($col)
            if ($col -eq 'Values') {
                $dgCol.Width = [System.Windows.Controls.DataGridLength]::new(1, [System.Windows.Controls.DataGridLengthUnitType]::Star)
                $dgCol.ElementStyle = [System.Windows.Style]::new([System.Windows.Controls.TextBlock])
                $dgCol.ElementStyle.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.TextBlock]::TextWrappingProperty, [System.Windows.TextWrapping]::Wrap))
            }
            $script:TagInventoryGrid.Columns.Add($dgCol)
        }

        # Action button template column (Remove)
        $invActionCol = [System.Windows.Controls.DataGridTemplateColumn]::new()
        $invActionCol.Header = 'Action'
        $invActionCol.Width = 75

        $invCellFactory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.Button])
        $invCellFactory.SetValue([System.Windows.Controls.Button]::ContentProperty, 'Remove')
        $invCellFactory.SetBinding([System.Windows.Controls.Button]::TagProperty, [System.Windows.Data.Binding]::new('Tag Name'))
        $invCellFactory.SetValue([System.Windows.Controls.Button]::FontSizeProperty, [double]10)
        $invCellFactory.SetValue([System.Windows.Controls.Button]::PaddingProperty, [System.Windows.Thickness]::new(6,1,6,1))
        $invCellFactory.SetValue([System.Windows.Controls.Button]::MarginProperty, [System.Windows.Thickness]::new(2,1,2,1))
        $invCellFactory.SetValue([System.Windows.Controls.Button]::CursorProperty, [System.Windows.Input.Cursors]::Hand)
        $invCellFactory.SetValue([System.Windows.Controls.Button]::BorderThicknessProperty, [System.Windows.Thickness]::new(1))
        $invCellFactory.SetValue([System.Windows.Controls.Button]::BackgroundProperty, [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FDE7E9'))
        $invCellFactory.SetValue([System.Windows.Controls.Button]::ForegroundProperty, [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D13438'))
        $invCellFactory.AddHandler([System.Windows.Controls.Button]::ClickEvent, [System.Windows.RoutedEventHandler]{
            param($sender, $e)
            Show-TagRemovePanel -TagName $sender.Tag
        })

        $invCellTemplate = [System.Windows.DataTemplate]::new()
        $invCellTemplate.VisualTree = $invCellFactory
        $invActionCol.CellTemplate = $invCellTemplate
        $script:TagInventoryGrid.Columns.Add($invActionCol)

        $tagRows = @()
        foreach ($entry in $(if ($d.Tags.TagNames) { $d.Tags.TagNames.GetEnumerator() } else { @() })) {
            $allValues = @($entry.Value.Values | ForEach-Object { $_.Value })
            $values = $allValues -join ', '
            $tagRows += [PSCustomObject]@{
                'Tag Name'       = $entry.Key
                'Resources'      = $entry.Value.TotalResources
                'Unique Values'  = $allValues.Count
                'Values'         = $values
            }
        }
        $script:TagInventoryGrid.ItemsSource = @($tagRows | Sort-Object 'Resources' -Descending)

        # Untagged resources detail grid
        if ($d.Tags.UntaggedResources -and $d.Tags.UntaggedResources.Count -gt 0) {
            $total = $d.Tags.UntaggedCount
            $shown = $d.Tags.UntaggedResources.Count
            if ($shown -lt $total) {
                $script:UntaggedNote.Text = "Showing $shown of $total untagged resources"
            } else {
                $script:UntaggedNote.Text = "$shown untagged resource$(if($shown -ne 1){'s'})"
            }
            $script:UntaggedResourcesGrid.ItemsSource = @($d.Tags.UntaggedResources)
        } else {
            $script:UntaggedNote.Text = "No untagged resources found"
            $script:UntaggedResourcesGrid.ItemsSource = @()
        }
    }

    # Tag recommendations with inline action buttons
    if ($d.TagRecs) {
        $presentCount  = $d.TagRecs.Present.Count
        $analysisCount = $d.TagRecs.Analysis.Count
        $script:TagComplianceText.Text = "Tag compliance: $($d.TagRecs.CompliancePercent)% ($presentCount of $analysisCount recommended tags found)"

        # Build the tag recs grid with programmatic columns including an Action button
        $script:TagRecsGrid.AutoGenerateColumns = $false
        $script:TagRecsGrid.Columns.Clear()

        # Data columns
        foreach ($col in @('Tag','Status','Location','Priority','Pillar','Purpose')) {
            $dgCol = [System.Windows.Controls.DataGridTextColumn]::new()
            $dgCol.Header = $col
            $dgCol.Binding = [System.Windows.Data.Binding]::new($col)
            if ($col -in @('Location','Purpose')) {
                $dgCol.Width = [System.Windows.Controls.DataGridLength]::new(1, [System.Windows.Controls.DataGridLengthUnitType]::Star)
                $dgCol.ElementStyle = [System.Windows.Style]::new([System.Windows.Controls.TextBlock])
                $dgCol.ElementStyle.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.TextBlock]::TextWrappingProperty, [System.Windows.TextWrapping]::Wrap))
            }
            $script:TagRecsGrid.Columns.Add($dgCol)
        }

        # Action button template column
        $actionCol = [System.Windows.Controls.DataGridTemplateColumn]::new()
        $actionCol.Header = 'Action'
        $actionCol.Width = 75

        $cellFactory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.Button])
        $cellFactory.SetBinding([System.Windows.Controls.Button]::ContentProperty, [System.Windows.Data.Binding]::new('ActionLabel'))
        $cellFactory.SetBinding([System.Windows.Controls.Button]::BackgroundProperty, [System.Windows.Data.Binding]::new('ActionBg'))
        $cellFactory.SetBinding([System.Windows.Controls.Button]::ForegroundProperty, [System.Windows.Data.Binding]::new('ActionFg'))
        $cellFactory.SetBinding([System.Windows.Controls.Button]::TagProperty, [System.Windows.Data.Binding]::new('ActionTagName'))
        $cellFactory.SetValue([System.Windows.Controls.Button]::FontSizeProperty, [double]10)
        $cellFactory.SetValue([System.Windows.Controls.Button]::PaddingProperty, [System.Windows.Thickness]::new(6,1,6,1))
        $cellFactory.SetValue([System.Windows.Controls.Button]::MarginProperty, [System.Windows.Thickness]::new(2,1,2,1))
        $cellFactory.SetValue([System.Windows.Controls.Button]::CursorProperty, [System.Windows.Input.Cursors]::Hand)
        $cellFactory.SetValue([System.Windows.Controls.Button]::BorderThicknessProperty, [System.Windows.Thickness]::new(1))
        $cellFactory.AddHandler([System.Windows.Controls.Button]::ClickEvent, [System.Windows.RoutedEventHandler]{
            param($sender, $e)
            $tagName = $sender.Tag
            $status  = $sender.Content
            if ($status -eq 'Add') {
                Show-TagDeployPanel -TagName $tagName
            } elseif ($status -eq 'Remove') {
                Show-TagRemovePanel -TagName $tagName
            }
        })

        $cellTemplate = [System.Windows.DataTemplate]::new()
        $cellTemplate.VisualTree = $cellFactory
        $actionCol.CellTemplate = $cellTemplate
        $script:TagRecsGrid.Columns.Add($actionCol)

        # Populate rows with action metadata
        $brushConv = [System.Windows.Media.BrushConverter]::new()
        $recRows = $d.TagRecs.Analysis | ForEach-Object {
            $isMissing = $_.Status -eq 'Missing'
            # For Remove: use the actual tag name found in Azure (handles variations + correct case)
            # For Add: use the recommended tag name
            $actionTag = if ($isMissing) { $_.TagName } elseif ($_.ActualTagName) { $_.ActualTagName } else { $_.TagName }
            [PSCustomObject]@{
                'Tag'           = $_.TagName
                'TagName'       = $_.TagName
                'ActionTagName' = $actionTag
                'Status'        = $_.Status
                'Location'      = $_.Location
                'Priority'      = $_.Priority
                'Pillar'        = $_.Pillar
                'Purpose'       = $_.Purpose
                'ActionLabel'   = if ($isMissing) { 'Add' } else { 'Remove' }
                'ActionBg'      = if ($isMissing) { $brushConv.ConvertFromString('#DFF6DD') } else { $brushConv.ConvertFromString('#FDE7E9') }
                'ActionFg'      = if ($isMissing) { $brushConv.ConvertFromString('#107C10') } else { $brushConv.ConvertFromString('#D13438') }
            }
        }
        $script:TagRecsGrid.ItemsSource = @($recRows)
    }
}

#-----------------------------------------------------------------------
# SHARED RESOURCE COST LOOKUP (used by Optimization + Orphan sections)
#-----------------------------------------------------------------------
$script:resCostMap = @{}
$script:resCostMapBuilt = $false

function Build-ResourceCostMap {
    $d = $script:scanData
    $script:resCostMap = @{}
    if ($d.ResourceCosts) {
        foreach ($rc in $d.ResourceCosts) {
            if ($rc.ResourcePath) {
                $script:resCostMap[$rc.ResourcePath.ToLower()] = $rc
            }
            if ($rc.ResourcePath -match '/([^/]+)$') {
                $nameKey = $Matches[1].ToLower()
                if (-not $script:resCostMap.ContainsKey($nameKey)) { $script:resCostMap[$nameKey] = $rc }
            }
        }
    }
    $script:resCostMapBuilt = $true
}

function Find-ResourceCost {
    param($Name, $SubscriptionId, $ResourceGroup, $ResourceType)
    if (-not $script:resCostMapBuilt) { Build-ResourceCostMap }
    $rc = $null
    if ($SubscriptionId -and $ResourceGroup -and $ResourceType -and $Name) {
        $armId = "/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroup/providers/$ResourceType/$Name".ToLower()
        $rc = $script:resCostMap[$armId]
    }
    if (-not $rc -and $Name) {
        $rc = $script:resCostMap[$Name.ToLower()]
    }
    return $rc
}

function Populate-OptimizationTab {
    $d = $script:scanData

    # Ensure shared resource cost map is built
    if (-not $script:resCostMapBuilt) { Build-ResourceCostMap }

    # Currency helper
    $currency = if ($d.ResourceCosts -and $d.ResourceCosts.Count -gt 0) {
        Get-CurrencySymbol -Code $d.ResourceCosts[0].Currency
    } else { '$' }

    # AHB
    if ($d.AHB) {
        $script:AHBCountText.Text   = "$($d.AHB.TotalOpportunities) resources"
        $script:AHBDetailText.Text  = "$($d.AHB.WindowsVMs.Count) VMs, $($d.AHB.SQLVMs.Count) SQL VMs, $($d.AHB.SQLDatabases.Count) SQL DBs"
        $script:AHBSummaryText.Text = $d.AHB.Summary

        $ahbRows = @()
        foreach ($vm in $d.AHB.WindowsVMs) {
            $rc = Find-ResourceCost -Name $vm.name -SubscriptionId $vm.subscriptionId -ResourceGroup $vm.resourceGroup -ResourceType 'microsoft.compute/virtualmachines'
            $actual   = if ($rc) { $rc.Actual } else { $null }
            $forecast = if ($rc) { $rc.Forecast } else { $null }
            # AHB saves ~40% on Windows VM licensing component
            $ahbActual   = if ($actual)   { [math]::Round($actual   * 0.6, 2) } else { $null }
            $ahbForecast = if ($forecast)  { [math]::Round($forecast * 0.6, 2) } else { $null }
            $ahbRows += [PSCustomObject]@{
                Type              = 'Windows VM'
                Name              = $vm.name
                ResourceGroup     = $vm.resourceGroup
                Size              = $vm.vmSize
                CurrentLicense    = $vm.currentLicense
                Location          = $vm.location
                'Actual (MTD)'    = if ($actual)      { "$currency$($actual.ToString('N2'))" }      else { '-' }
                'Forecast'        = if ($forecast)     { "$currency$($forecast.ToString('N2'))" }    else { '-' }
                'With AHB (MTD)'  = if ($ahbActual)    { "$currency$($ahbActual.ToString('N2'))" }   else { '-' }
                'With AHB (Mo.)'  = if ($ahbForecast)  { "$currency$($ahbForecast.ToString('N2'))" } else { '-' }
            }
        }
        foreach ($sql in $d.AHB.SQLVMs) {
            $rc = Find-ResourceCost -Name $sql.name -SubscriptionId $sql.subscriptionId -ResourceGroup $sql.resourceGroup -ResourceType 'microsoft.sqlvirtualmachine/sqlvirtualmachines'
            $actual   = if ($rc) { $rc.Actual } else { $null }
            $forecast = if ($rc) { $rc.Forecast } else { $null }
            $ahbActual   = if ($actual)   { [math]::Round($actual   * 0.45, 2) } else { $null }
            $ahbForecast = if ($forecast)  { [math]::Round($forecast * 0.45, 2) } else { $null }
            $ahbRows += [PSCustomObject]@{
                Type              = 'SQL VM'
                Name              = $sql.name
                ResourceGroup     = $sql.resourceGroup
                Size              = $sql.sqlEdition
                CurrentLicense    = $sql.currentLicense
                Location          = $sql.location
                'Actual (MTD)'    = if ($actual)      { "$currency$($actual.ToString('N2'))" }      else { '-' }
                'Forecast'        = if ($forecast)     { "$currency$($forecast.ToString('N2'))" }    else { '-' }
                'With AHB (MTD)'  = if ($ahbActual)    { "$currency$($ahbActual.ToString('N2'))" }   else { '-' }
                'With AHB (Mo.)'  = if ($ahbForecast)  { "$currency$($ahbForecast.ToString('N2'))" } else { '-' }
            }
        }
        foreach ($db in $d.AHB.SQLDatabases) {
            $rc = Find-ResourceCost -Name $db.name -SubscriptionId $db.subscriptionId -ResourceGroup $db.resourceGroup -ResourceType 'microsoft.sql/servers/databases'
            $actual   = if ($rc) { $rc.Actual } else { $null }
            $forecast = if ($rc) { $rc.Forecast } else { $null }
            # AHB saves ~55% on SQL DB licensing component
            $ahbActual   = if ($actual)   { [math]::Round($actual   * 0.45, 2) } else { $null }
            $ahbForecast = if ($forecast)  { [math]::Round($forecast * 0.45, 2) } else { $null }
            $ahbRows += [PSCustomObject]@{
                Type              = 'SQL Database'
                Name              = $db.name
                ResourceGroup     = $db.resourceGroup
                Size              = $db.sku
                CurrentLicense    = $db.currentLicense
                Location          = $db.location
                'Actual (MTD)'    = if ($actual)      { "$currency$($actual.ToString('N2'))" }      else { '-' }
                'Forecast'        = if ($forecast)     { "$currency$($forecast.ToString('N2'))" }    else { '-' }
                'With AHB (MTD)'  = if ($ahbActual)    { "$currency$($ahbActual.ToString('N2'))" }   else { '-' }
                'With AHB (Mo.)'  = if ($ahbForecast)  { "$currency$($ahbForecast.ToString('N2'))" } else { '-' }
            }
        }
        if ($ahbRows.Count -eq 0) {
            $script:AHBGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No AHB-eligible resources found. All resources are using Azure Hybrid Benefit or are not eligible.' })
        } else {
            $script:AHBGrid.ItemsSource = @($ahbRows)
        }
    } else {
        $script:AHBGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No AHB-eligible resources found.' })
    }

    # Reservations - split RI vs SP
    if ($d.Reservations) {
        # Classify advisor recs as RI or SP
        $riRecs = @()
        $spRecs = @()
        foreach ($rec in $d.Reservations.AdvisorRecommendations) {
            if ($rec.Problem -match 'savings plan' -or $rec.Solution -match 'savings plan') {
                $spRecs += $rec
            } else {
                $riRecs += $rec
            }
        }

        # Contract-aware note
        $contractType = ''
        if ($d.Contract -and $d.Contract.Count -gt 0) {
            $contractType = $d.Contract[0].AgreementType
        }
        $contractNote = switch -Regex ($contractType) {
            'EnterpriseAgreement'              { 'EA customers: RI/SP pricing reflects your negotiated EA rates. Savings shown are vs. your EA pay-as-you-go rate.' }
            'MicrosoftCustomerAgreement'       { 'MCA customers: RI/SP savings are calculated against your MCA list prices. Actual savings may vary based on negotiated discounts.' }
            'MicrosoftOnlineServicesProgram'   { 'PAYGO customers: Savings shown are vs. retail pay-as-you-go rates. Consider an EA or MCA for even deeper discounts on top of RI/SP.' }
            default                             { 'Savings are estimated against your current pricing model.' }
        }
        if ($script:RIContractNote) { $script:RIContractNote.Text = $contractNote }
        if ($script:SPContractNote) { $script:SPContractNote.Text = $contractNote }

        # RI grid - Advisor RI recs + Reservation API recs
        $riRows = @()
        foreach ($rec in $riRecs) {
            $rc = Find-ResourceCost -Name $rec.ResourceName -SubscriptionId $rec.SubscriptionId -ResourceGroup $null -ResourceType $rec.ResourceType
            $actual   = if ($rc) { $rc.Actual } else { $null }
            $forecast = if ($rc) { $rc.Forecast } else { $null }
            $monthlySavings = if ($rec.AnnualSavings) { [math]::Round($rec.AnnualSavings / 12, 2) } else { $null }
            $riRows += [PSCustomObject]@{
                Subscription     = $rec.Subscription
                Resource         = $rec.ResourceName
                'Resource Type'  = $rec.ResourceType
                Impact           = $rec.Impact
                Problem          = $rec.Problem
                Solution         = $rec.Solution
                Term             = if ($rec.Term) { $rec.Term } else { '-' }
                'Actual (MTD)'   = if ($actual) { "$currency$($actual.ToString('N2'))" } else { '-' }
                'Forecast'       = if ($forecast) { "$currency$($forecast.ToString('N2'))" } else { '-' }
                'With RI (Mo.)'  = if ($monthlySavings -and $forecast) { "$currency$([math]::Round($forecast - $monthlySavings, 2).ToString('N2'))" } else { '-' }
                'Annual Savings' = if ($rec.AnnualSavings) { "$currency$($rec.AnnualSavings.ToString('N2'))" } else { '-' }
            }
        }
        foreach ($rr in $d.Reservations.ReservationRecommendations) {
            $riRows += [PSCustomObject]@{
                Subscription     = '-'
                Resource         = if ($rr.SKU) { $rr.SKU } else { $rr.ResourceType }
                'Resource Type'  = $rr.ResourceType
                Impact           = 'High'
                Problem          = "$($rr.RecommendedQty) x $($rr.ResourceType) at PAYG rates"
                Solution         = "Purchase $($rr.RecommendedQty) reserved instance(s) ($($rr.Term))"
                Term             = if ($rr.Term) { $rr.Term } else { '-' }
                'Actual (MTD)'   = '-'
                'Forecast'       = if ($rr.CostWithoutRI) { "$currency$($rr.CostWithoutRI.ToString('N2'))" } else { '-' }
                'With RI (Mo.)'  = if ($rr.CostWithRI) { "$currency$($rr.CostWithRI.ToString('N2'))" } else { '-' }
                'Annual Savings' = if ($rr.NetSavings) { "$currency$($rr.NetSavings.ToString('N2'))" } else { '-' }
            }
        }
        if ($riRows.Count -eq 0) {
            $script:RIGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No Reserved Instance recommendations at this time.' })
        } else {
            $script:RIGrid.ItemsSource = @($riRows)
        }

        # SP grid
        $spRows = @()
        foreach ($rec in $spRecs) {
            $rc = Find-ResourceCost -Name $rec.ResourceName -SubscriptionId $rec.SubscriptionId -ResourceGroup $null -ResourceType $rec.ResourceType
            $actual   = if ($rc) { $rc.Actual } else { $null }
            $forecast = if ($rc) { $rc.Forecast } else { $null }
            $monthlySavings = if ($rec.AnnualSavings) { [math]::Round($rec.AnnualSavings / 12, 2) } else { $null }
            $spRows += [PSCustomObject]@{
                Subscription     = $rec.Subscription
                Resource         = $rec.ResourceName
                'Resource Type'  = $rec.ResourceType
                Impact           = $rec.Impact
                Problem          = $rec.Problem
                Solution         = $rec.Solution
                Term             = if ($rec.Term) { $rec.Term } else { '-' }
                'Actual (MTD)'   = if ($actual) { "$currency$($actual.ToString('N2'))" } else { '-' }
                'Forecast'       = if ($forecast) { "$currency$($forecast.ToString('N2'))" } else { '-' }
                'With SP (Mo.)'  = if ($monthlySavings -and $forecast) { "$currency$([math]::Round($forecast - $monthlySavings, 2).ToString('N2'))" } else { '-' }
                'Annual Savings' = if ($rec.AnnualSavings) { "$currency$($rec.AnnualSavings.ToString('N2'))" } else { '-' }
            }
        }
        if ($spRows.Count -eq 0) {
            $script:SPGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No Savings Plan recommendations at this time.' })
        } else {
            $script:SPGrid.ItemsSource = @($spRows)
        }
    } else {
        $script:RIGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No Reserved Instance recommendations at this time.' })
        $script:SPGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No Savings Plan recommendations at this time.' })
    }

    # Advisor
    if ($d.Optimization -and $d.Optimization.TotalCount -gt 0) {
        $script:AdvisorCountText.Text   = $d.Optimization.TotalCount.ToString()
        $script:AdvisorSavingsText.Text = "Est. $currency$($d.Optimization.EstimatedAnnualSavings.ToString('N2'))/yr"

        $advRows = @()
        foreach ($rec in $d.Optimization.Recommendations) {
            $rc = Find-ResourceCost -Name $rec.ResourceName -SubscriptionId $rec.SubscriptionId -ResourceGroup $null -ResourceType $rec.ResourceType
            $actual   = if ($rc) { $rc.Actual } else { $null }
            $forecast = if ($rc) { $rc.Forecast } else { $null }
            $monthlySavings = if ($rec.AnnualSavings) { [math]::Round($rec.AnnualSavings / 12, 2) } else { $null }
            $advRows += [PSCustomObject]@{
                Category         = $rec.Category
                Subscription     = $rec.Subscription
                Impact           = $rec.Impact
                Resource         = $rec.ResourceName
                Problem          = $rec.Problem
                Solution         = $rec.Solution
                'Actual (MTD)'   = if ($actual) { "$currency$($actual.ToString('N2'))" } else { '-' }
                'Forecast'       = if ($forecast) { "$currency$($forecast.ToString('N2'))" } else { '-' }
                'With Fix (Mo.)' = if ($monthlySavings -and $forecast) { "$currency$([math]::Round($forecast - $monthlySavings, 2).ToString('N2'))" } else { '-' }
                'Annual Savings' = if ($rec.AnnualSavings) { "$currency$($rec.AnnualSavings.ToString('N2'))" } else { '-' }
            }
        }
        $script:AdvisorGrid.ItemsSource = @($advRows)
    } else {
        $script:AdvisorCountText.Text   = '0'
        $script:AdvisorSavingsText.Text = "$currency" + "0.00/yr"
        $script:AdvisorGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No Advisor cost optimization recommendations at this time. This is normal for well-optimized or small environments.' })
    }
}

function Populate-GuidanceTab {
    $d = $script:scanData

    # Currency helper
    $currency = if ($d.ResourceCosts -and $d.ResourceCosts.Count -gt 0) {
        Get-CurrencySymbol -Code $d.ResourceCosts[0].Currency
    } else { '$' }

    # =====================================================================
    # HELPER: Add a rich text line to a StackPanel
    # =====================================================================
    function Add-GuidanceLine {
        param(
            [System.Windows.Controls.StackPanel]$Panel,
            [string]$Icon,          # Emoji-style prefix e.g. [!] or checkmark
            [string]$Bold,          # Bold portion
            [string]$Normal,        # Normal text after bold
            [string]$Color = '#444',
            [double]$FontSize = 12.5,
            [double]$BottomMargin = 6
        )
        $tb = [System.Windows.Controls.TextBlock]::new()
        $tb.TextWrapping = 'Wrap'
        $tb.FontSize = $FontSize
        $tb.Margin = [System.Windows.Thickness]::new(0, 0, 0, $BottomMargin)

        if ($Icon) {
            $iconRun = [System.Windows.Documents.Run]::new("$Icon ")
            $iconRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
            $iconRun.FontWeight = 'Bold'
            $tb.Inlines.Add($iconRun) | Out-Null
        }
        if ($Bold) {
            $boldRun = [System.Windows.Documents.Run]::new($Bold)
            $boldRun.FontWeight = 'Bold'
            $boldRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#222')
            $tb.Inlines.Add($boldRun) | Out-Null
        }
        if ($Normal) {
            $sep = if ($Bold) { '  ' } else { '' }
            $normRun = [System.Windows.Documents.Run]::new("$sep$Normal")
            $normRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#444')
            $tb.Inlines.Add($normRun) | Out-Null
        }
        $Panel.Children.Add($tb) | Out-Null
    }

    # =====================================================================
    # FINOPS MATURITY SCORE (0-100)
    # Based on FinOps Foundation Maturity Model + Microsoft CAF
    # Categories: Visibility (25), Allocation (20), Budgeting (15),
    #             Optimization (20), Governance (20)
    # =====================================================================
    $score = 0
    $maxScore = 100
    $breakdown = @{}

    # --- Visibility (25 pts) -------------------------------------------
    $visScore = 0
    # Tag coverage: 0-10 pts
    if ($d.Tags) {
        $visScore += [math]::Min([math]::Floor($d.Tags.TagCoverage / 10), 10)
    }
    # Cost data available: 5 pts
    if ($d.Costs -and $d.Costs.Count -gt 0) { $visScore += 5 }
    # Cost trend available: 5 pts
    if ($d.CostTrend -and $d.CostTrend.HasData) { $visScore += 5 }
    # Resource-level cost visibility: 5 pts
    if ($d.ResourceCosts -and $d.ResourceCosts.Count -gt 0) { $visScore += 5 }
    $breakdown['Visibility'] = [math]::Min($visScore, 25)
    $score += $breakdown['Visibility']

    # --- Allocation (20 pts) -------------------------------------------
    # Weighted per-tag scoring: CostCenter/BusinessUnit matter most for chargeback
    $allocScore = 0
    # Weighted tag presence: 0-12 pts
    if ($d.Tags -and $d.Tags.TagNames) {
        $lcKeys = $d.Tags.TagNames.Keys | ForEach-Object { $_.ToLower() }
        $tagWeights = @{
            'CostCenter'          = @{ Weight = 3; Alts = @('costcenter', 'cost-center', 'cost_center', 'cc') }
            'BusinessUnit'        = @{ Weight = 3; Alts = @('businessunit', 'bu', 'business-unit', 'department', 'dept') }
            'ApplicationName'     = @{ Weight = 2; Alts = @('applicationname', 'application', 'app', 'appname') }
            'WorkloadName'        = @{ Weight = 1; Alts = @('workloadname', 'workload', 'workload-name') }
            'OpsTeam'             = @{ Weight = 1; Alts = @('opsteam', 'ops-team', 'ops_team', 'owner', 'technicalowner') }
            'Criticality'         = @{ Weight = 1; Alts = @('criticality', 'sla', 'tier') }
            'DataClassification'  = @{ Weight = 1; Alts = @('dataclassification', 'data-classification', 'classification') }
        }
        foreach ($tag in $tagWeights.Keys) {
            $allNames = @($tag.ToLower()) + $tagWeights[$tag].Alts
            if ($lcKeys | Where-Object { $_ -in $allNames }) {
                $allocScore += $tagWeights[$tag].Weight
            }
        }
    }
    # Cost-by-tag data available: 4 pts
    if ($d.CostByTag -and -not $d.CostByTag.NoTagsFound -and $d.CostByTag.CostByTag.Count -gt 0) { $allocScore += 4 }
    # Cost allocation rules configured: 4 pts
    if ($d.Billing -and $d.Billing.CostAllocationRules -and $d.Billing.CostAllocationRules.Count -gt 0) { $allocScore += 4 }
    $breakdown['Allocation'] = [math]::Min($allocScore, 20)
    $score += $breakdown['Allocation']

    # --- Budgeting & Forecasting (15 pts) ------------------------------
    $budgetScore = 0
    # Has budgets: 5 pts
    if ($d.Budgets -and $d.Budgets.HasData) { $budgetScore += 5 }
    # Budget coverage: 0-5 pts
    if ($d.Budgets) {
        $budgetScore += [math]::Min([math]::Floor($d.Budgets.BudgetCoverage / 20), 5)
    }
    # No budgets over 100%: 5 pts (or partial credit)
    if ($d.Budgets -and $d.Budgets.HasData) {
        if ($d.Budgets.OverBudgetCount -eq 0) { $budgetScore += 5 }
        elseif ($d.Budgets.AtRiskCount -eq 0) { $budgetScore += 3 }
    }
    $breakdown['Budgeting'] = [math]::Min($budgetScore, 15)
    $score += $breakdown['Budgeting']

    # --- Optimization (20 pts) -----------------------------------------
    $optScore = 0
    # Commitment utilization > 80%: 5 pts
    if ($d.Commitments -and $d.Commitments.HasData) {
        if ($d.Commitments.RIAvgUtilization -ge 80) { $optScore += 5 }
        elseif ($d.Commitments.RIAvgUtilization -ge 60) { $optScore += 3 }
    } else {
        # No commitments = no waste, partial credit
        $optScore += 2
    }
    # Savings realized from commitments: 5 pts
    if ($d.Savings -and $d.Savings.TotalMonthly -gt 0) { $optScore += 5 }
    # Low Advisor recommendations (fewer = better optimized): 0-5 pts
    if ($d.Optimization) {
        if ($d.Optimization.TotalCount -eq 0) { $optScore += 5 }
        elseif ($d.Optimization.TotalCount -le 3) { $optScore += 3 }
        elseif ($d.Optimization.TotalCount -le 10) { $optScore += 1 }
    } else { $optScore += 2 }
    # Few orphaned resources: 5 pts
    if ($d.Orphans) {
        $orphanTotal = if ($d.Orphans.TotalCount) { $d.Orphans.TotalCount } else { 0 }
        if ($orphanTotal -eq 0) { $optScore += 5 }
        elseif ($orphanTotal -le 3) { $optScore += 3 }
        elseif ($orphanTotal -le 10) { $optScore += 1 }
    } else { $optScore += 2 }
    $breakdown['Optimization'] = [math]::Min($optScore, 20)
    $score += $breakdown['Optimization']

    # --- Governance (20 pts) -------------------------------------------
    $govScore = 0
    # Has Azure policies: 5 pts
    if ($d.PolicyInv -and $d.PolicyInv.AssignmentCount -gt 0) { $govScore += 5 }
    # FinOps policies coverage: 0-5 pts
    if ($d.PolicyRecs) {
        $policyPct = if ($d.PolicyRecs.Analysis.Count -gt 0) {
            [math]::Round(($d.PolicyRecs.Assigned.Count / $d.PolicyRecs.Analysis.Count) * 100, 0)
        } else { 0 }
        $govScore += [math]::Min([math]::Floor($policyPct / 20), 5)
    }
    # Policy compliance > 80%: 5 pts
    if ($d.PolicyInv -and $d.PolicyInv.CompliancePct -ge 80) { $govScore += 5 }
    elseif ($d.PolicyInv -and $d.PolicyInv.CompliancePct -ge 50) { $govScore += 3 }
    # Has management group hierarchy: 5 pts
    if ($d.Hierarchy -and $d.Hierarchy.RootGroup) { $govScore += 5 }
    elseif ($d.Hierarchy -and $d.Hierarchy.FlatSubs) { $govScore += 2 }
    $breakdown['Governance'] = [math]::Min($govScore, 20)
    $score += $breakdown['Governance']

    $score = [math]::Min($score, $maxScore)

    # Grade label
    $grade = switch ($true) {
        ($score -ge 85) { 'Excellent'; break }
        ($score -ge 70) { 'Good'; break }
        ($score -ge 50) { 'Developing'; break }
        ($score -ge 30) { 'Foundational'; break }
        default { 'Getting Started' }
    }

    $gradeColor = switch ($true) {
        ($score -ge 85) { '#107C10'; break }
        ($score -ge 70) { '#0078D4'; break }
        ($score -ge 50) { '#8764B8'; break }
        ($score -ge 30) { '#FF8C00'; break }
        default { '#D13438' }
    }

    # Store computed score on scan data so Export-ScanReport can reuse it
    $d | Add-Member -NotePropertyName 'MaturityScore' -NotePropertyValue $score -Force
    $d | Add-Member -NotePropertyName 'MaturityBreakdown' -NotePropertyValue $breakdown -Force
    $d | Add-Member -NotePropertyName 'MaturityGrade' -NotePropertyValue $grade -Force
    $d | Add-Member -NotePropertyName 'MaturityGradeColor' -NotePropertyValue $gradeColor -Force

    # =====================================================================
    # RENDER SCORE CARD
    # =====================================================================
    $script:GuidanceScorePanel.Children.Clear()

    # Score card container
    $scoreCard = [System.Windows.Controls.Border]::new()
    $scoreCard.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F8F9FA')
    $scoreCard.CornerRadius = [System.Windows.CornerRadius]::new(8)
    $scoreCard.Padding = [System.Windows.Thickness]::new(24)
    $scoreCard.Margin = [System.Windows.Thickness]::new(0, 10, 0, 10)
    $scoreCard.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#E0E0E0')
    $scoreCard.BorderThickness = [System.Windows.Thickness]::new(1)

    $scoreStack = [System.Windows.Controls.StackPanel]::new()

    # Title
    $titleTb = [System.Windows.Controls.TextBlock]::new()
    $titleTb.FontSize = 18
    $titleTb.FontWeight = 'SemiBold'
    $titleTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#333')
    $titleTb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
    $titleTb.Inlines.Add([System.Windows.Documents.Run]::new('FinOps Maturity Score:  ')) | Out-Null
    $scoreRun = [System.Windows.Documents.Run]::new("$score / $maxScore")
    $scoreRun.FontSize = 24
    $scoreRun.FontWeight = 'Bold'
    $scoreRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($gradeColor)
    $titleTb.Inlines.Add($scoreRun) | Out-Null
    $gradeRun = [System.Windows.Documents.Run]::new("  ($grade)")
    $gradeRun.FontSize = 16
    $gradeRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($gradeColor)
    $titleTb.Inlines.Add($gradeRun) | Out-Null
    $scoreStack.Children.Add($titleTb) | Out-Null

    # Methodology note
    $methodTb = [System.Windows.Controls.TextBlock]::new()
    $methodTb.Text = 'Score based on FinOps Foundation Maturity Model and Microsoft Cloud Adoption Framework. Categories: Visibility (25), Allocation (20), Budgeting (15), Optimization (20), Governance (20).'
    $methodTb.TextWrapping = 'Wrap'
    $methodTb.FontSize = 11
    $methodTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#888')
    $methodTb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
    $scoreStack.Children.Add($methodTb) | Out-Null

    # Category breakdown in a horizontal WrapPanel
    $catPanel = [System.Windows.Controls.WrapPanel]::new()
    $catColors = @{
        'Visibility'   = '#0078D4'
        'Allocation'   = '#005A9E'
        'Budgeting'    = '#8764B8'
        'Optimization' = '#107C10'
        'Governance'   = '#D83B01'
    }
    $catMax = @{ 'Visibility' = 25; 'Allocation' = 20; 'Budgeting' = 15; 'Optimization' = 20; 'Governance' = 20 }
    foreach ($cat in @('Visibility', 'Allocation', 'Budgeting', 'Optimization', 'Governance')) {
        $catBorder = [System.Windows.Controls.Border]::new()
        $catBorder.Background = [System.Windows.Media.Brushes]::White
        $catBorder.CornerRadius = [System.Windows.CornerRadius]::new(4)
        $catBorder.Padding = [System.Windows.Thickness]::new(14, 8, 14, 8)
        $catBorder.Margin = [System.Windows.Thickness]::new(0, 0, 10, 6)
        $catBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#DDD')
        $catBorder.BorderThickness = [System.Windows.Thickness]::new(1)

        $catTb = [System.Windows.Controls.TextBlock]::new()
        $catTb.FontSize = 12
        $nameRun = [System.Windows.Documents.Run]::new("$cat  ")
        $nameRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#666')
        $catTb.Inlines.Add($nameRun) | Out-Null

        $valRun = [System.Windows.Documents.Run]::new("$($breakdown[$cat]) / $($catMax[$cat])")
        $valRun.FontWeight = 'Bold'
        $valRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($catColors[$cat])
        $catTb.Inlines.Add($valRun) | Out-Null

        $catBorder.Child = $catTb
        $catPanel.Children.Add($catBorder) | Out-Null
    }
    $scoreStack.Children.Add($catPanel) | Out-Null

    $scoreCard.Child = $scoreStack
    $script:GuidanceScorePanel.Children.Add($scoreCard) | Out-Null

    # =====================================================================
    # PRIORITIZED ACTION PLAN
    # Build a list of actions sorted by impact, with priority numbering
    # =====================================================================
    $script:ActionPlanPanel.Children.Clear()
    $actions = [System.Collections.Generic.List[PSCustomObject]]::new()

    # --- Critical: Tag coverage ---
    if ($d.Tags -and $d.Tags.TagCoverage -lt 50) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 1; Impact = 'Critical'; Category = 'Allocation'
            Title = "Increase tag coverage from $($d.Tags.TagCoverage)% to 80%+"
            Detail = 'Untagged resources cannot be allocated to business units. Use Azure Policy to enforce tagging at resource creation. Start with CostCenter, Environment, and Application tags.'
        })
    } elseif ($d.Tags -and $d.Tags.TagCoverage -lt 80) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 2; Impact = 'High'; Category = 'Allocation'
            Title = "Improve tag coverage from $($d.Tags.TagCoverage)% to 80%+"
            Detail = 'Good progress on tagging. Focus on untagged resources using Azure Policy tag inheritance and the Deploy Missing Tags feature on the Tags tab.'
        })
    }

    # --- Critical: No budgets ---
    if (-not $d.Budgets -or -not $d.Budgets.HasData) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 1; Impact = 'Critical'; Category = 'Budgeting'
            Title = 'Set up Azure Budgets with alert thresholds'
            Detail = 'No budgets detected. Create budgets at the subscription level with 50%, 75%, 90%, and 100% alert thresholds. Use action groups to notify finance and engineering teams.'
        })
    } elseif ($d.Budgets.BudgetCoverage -lt 50) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 2; Impact = 'High'; Category = 'Budgeting'
            Title = "Expand budget coverage from $($d.Budgets.BudgetCoverage)% to 100%"
            Detail = "Only $($d.Budgets.SubsWithBudget) of $($d.Budgets.SubsWithBudget + $d.Budgets.SubsWithoutBudget) subscriptions have budgets. Every production subscription should have an Azure Budget."
        })
    }

    # --- High: Over-budget subscriptions ---
    if ($d.Budgets -and $d.Budgets.OverBudgetCount -gt 0) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 1; Impact = 'Critical'; Category = 'Budgeting'
            Title = "$($d.Budgets.OverBudgetCount) subscription(s) are over budget"
            Detail = 'Investigate the over-budget subscriptions on the Overview tab. Check for unexpected scaling events, new resource deployments, or pricing changes.'
        })
    }

    # --- High: Missing required tags ---
    if ($d.TagRecs -and $d.TagRecs.MissingRequired.Count -gt 0) {
        $names = ($d.TagRecs.MissingRequired | ForEach-Object { $_.TagName }) -join ', '
        [void]$actions.Add([PSCustomObject]@{
            Priority = 2; Impact = 'High'; Category = 'Allocation'
            Title = "Deploy missing required tags: $names"
            Detail = 'Microsoft Cloud Adoption Framework requires these tags for chargeback/showback. Use the Tags tab to deploy them to subscriptions or resource groups.'
        })
    }

    # --- High: No FinOps policies ---
    if ($d.PolicyRecs -and $d.PolicyRecs.Missing.Count -gt 0) {
        $missingCount = $d.PolicyRecs.Missing.Count
        $totalPolicies = $d.PolicyRecs.Analysis.Count
        [void]$actions.Add([PSCustomObject]@{
            Priority = 2; Impact = 'High'; Category = 'Governance'
            Title = "Deploy $missingCount of $totalPolicies recommended FinOps policies"
            Detail = 'Azure Policy enforces cost governance at scale. Start with Audit mode to measure impact, then move to Deny for critical policies like allowed VM sizes and required tags. Use the Policy tab to deploy.'
        })
    }

    # --- Medium: AHB opportunities ---
    if ($d.AHB -and $d.AHB.TotalOpportunities -gt 0) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 3; Impact = 'Medium'; Category = 'Optimization'
            Title = "Enable Azure Hybrid Benefit on $($d.AHB.TotalOpportunities) resource(s)"
            Detail = 'If you have existing Windows Server or SQL Server licenses with Software Assurance, AHB saves 40-85% on compute. This is free money with no architectural changes.'
        })
    }

    # --- Medium: Advisor recommendations ---
    if ($d.Optimization -and $d.Optimization.TotalCount -gt 0) {
        $estSavings = $d.Optimization.EstimatedAnnualSavings.ToString('N2')
        [void]$actions.Add([PSCustomObject]@{
            Priority = 3; Impact = 'Medium'; Category = 'Optimization'
            Title = "$($d.Optimization.TotalCount) Advisor cost recommendations (est. $currency$estSavings/yr)"
            Detail = 'Review Azure Advisor recommendations on the Optimization tab. Common quick wins: rightsize VMs, delete unused resources, shut down dev/test outside business hours.'
        })
    }

    # --- Medium: Orphaned resources ---
    if ($d.Orphans) {
        $orphanTotal = if ($d.Orphans.TotalCount) { $d.Orphans.TotalCount } else { 0 }
        if ($orphanTotal -gt 0) {
            [void]$actions.Add([PSCustomObject]@{
                Priority = 3; Impact = 'Medium'; Category = 'Optimization'
                Title = "Clean up $orphanTotal orphaned/idle resource(s)"
                Detail = 'Orphaned disks, unattached IPs, deallocated VMs, and empty App Service Plans cost money but serve no purpose. Review on the Optimization tab.'
            })
        }
    }

    # --- Medium: Reservation/SP advice ---
    if ($d.Reservations -and ($d.Reservations.TotalAdvisorCount + $d.Reservations.TotalReservationCount) -gt 0) {
        $riSavings = $d.Reservations.EstimatedAnnualSavings.ToString('N2')
        [void]$actions.Add([PSCustomObject]@{
            Priority = 3; Impact = 'Medium'; Category = 'Optimization'
            Title = "Evaluate RI/Savings Plan opportunities (est. $currency$riSavings/yr)"
            Detail = 'For steady-state workloads, Reserved Instances save 30-72% vs. pay-as-you-go. Savings Plans offer flexibility across VM families. Start with 1-year terms to reduce risk.'
        })
    }

    # --- Lower: Commitment utilization ---
    if ($d.Commitments -and $d.Commitments.HasData -and $d.Commitments.UnderutilizedRIs.Count -gt 0) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 4; Impact = 'Low'; Category = 'Optimization'
            Title = "$($d.Commitments.UnderutilizedRIs.Count) underutilized reservation(s) (below 80%)"
            Detail = 'Exchange or refund underperforming reservations. Azure allows one-time exchanges to better-fitting SKUs or regions. Target 80%+ utilization on all commitments.'
        })
    }

    # --- No MG hierarchy = flat org ---
    if (-not $d.Hierarchy -or -not $d.Hierarchy.RootGroup) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 4; Impact = 'Low'; Category = 'Governance'
            Title = 'Set up Management Group hierarchy'
            Detail = 'Management Groups enable policy inheritance and cost rollup at the organizational level. Structure as: Tenant Root > Platform / Landing Zones > Production / Dev / Sandbox.'
        })
    }

    # --- Positive: Add encouragement for things done well ---
    if ($d.Budgets -and $d.Budgets.HasData -and $d.Budgets.BudgetCoverage -ge 80) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 10; Impact = 'Strength'; Category = 'Budgeting'
            Title = "Budget coverage is $($d.Budgets.BudgetCoverage)% - well governed"
            Detail = 'Consider adding action groups that auto-scale down or shut off dev resources when budgets hit 90%.'
        })
    }
    if ($d.Tags -and $d.Tags.TagCoverage -ge 80) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 10; Impact = 'Strength'; Category = 'Allocation'
            Title = "Tag coverage at $($d.Tags.TagCoverage)% - strong cost allocation"
            Detail = 'Next step: implement tag-based cost allocation rules in Cost Management to automatically distribute shared costs to business units.'
        })
    }
    if ($d.PolicyInv -and $d.PolicyInv.AssignmentCount -gt 5) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 10; Impact = 'Strength'; Category = 'Governance'
            Title = "$($d.PolicyInv.AssignmentCount) policies in place - governance foundation established"
            Detail = 'Review compliance % on the Policy tab. Move Audit-mode policies to Deny for critical rules once compliance is above 90%.'
        })
    }
    if ($d.Savings -and $d.Savings.TotalMonthly -gt 0) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 10; Impact = 'Strength'; Category = 'Optimization'
            Title = "Already saving $currency$($d.Savings.TotalMonthly.ToString('N2'))/mo from commitments"
            Detail = 'Great foundation. Monitor utilization monthly and consider expanding coverage as workloads stabilize.'
        })
    }

    # Fall back if nothing
    if ($actions.Count -eq 0) {
        [void]$actions.Add([PSCustomObject]@{
            Priority = 5; Impact = 'Info'; Category = 'General'
            Title = 'Run a full scan with Cost Management Reader permissions for detailed recommendations'
            Detail = 'The scanner needs cost and policy data to generate specific actions. Ensure the account has Reader + Cost Management Reader at the management group or subscription scope.'
        })
    }

    # Sort: Critical first, Strength last
    $sortedActions = @($actions | Sort-Object Priority, Category)
    $impactToColor = @{
        Critical = '#D13438'; High = '#FF8C00'; Medium = '#0078D4'
        Low = '#666'; Info = '#888'; Strength = '#107C10'
    }

    $subtitle = "Based on your scan results, here are $($sortedActions.Count) recommendations in priority order."
    if ($score -ge 70) { $subtitle += ' Your environment is in good shape - focus on the refinements below.' }
    elseif ($score -ge 50) { $subtitle += ' You have a solid foundation - the items below will accelerate FinOps maturity.' }
    else { $subtitle += ' Start with the Critical and High-impact items to build your FinOps foundation.' }
    $script:ActionPlanSubtitle.Text = $subtitle

    $actionNum = 0
    foreach ($a in $sortedActions) {
        $actionNum++
        $color = if ($impactToColor.ContainsKey($a.Impact)) { $impactToColor[$a.Impact] } else { '#444' }

        $actionBorder = [System.Windows.Controls.Border]::new()
        $actionBorder.Background = [System.Windows.Media.Brushes]::White
        $actionBorder.CornerRadius = [System.Windows.CornerRadius]::new(4)
        $actionBorder.Padding = [System.Windows.Thickness]::new(14, 10, 14, 10)
        $actionBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
        $actionBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#E8E8E8')
        $actionBorder.BorderThickness = [System.Windows.Thickness]::new(1)

        $actionStack = [System.Windows.Controls.StackPanel]::new()

        # Title line: #1 [Critical] Title
        $titleLine = [System.Windows.Controls.TextBlock]::new()
        $titleLine.TextWrapping = 'Wrap'
        $titleLine.FontSize = 13
        $titleLine.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)

        $numRun = [System.Windows.Documents.Run]::new("#$actionNum  ")
        $numRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#999')
        $numRun.FontWeight = 'Bold'
        $titleLine.Inlines.Add($numRun) | Out-Null

        $tagRun = [System.Windows.Documents.Run]::new("[$($a.Impact)]  ")
        $tagRun.FontWeight = 'Bold'
        $tagRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($color)
        $titleLine.Inlines.Add($tagRun) | Out-Null

        $titleRun = [System.Windows.Documents.Run]::new($a.Title)
        $titleRun.FontWeight = 'SemiBold'
        $titleRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#222')
        $titleLine.Inlines.Add($titleRun) | Out-Null

        $actionStack.Children.Add($titleLine) | Out-Null

        # Detail line
        $detailTb = [System.Windows.Controls.TextBlock]::new()
        $detailTb.Text = $a.Detail
        $detailTb.TextWrapping = 'Wrap'
        $detailTb.FontSize = 12
        $detailTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#555')
        $actionStack.Children.Add($detailTb) | Out-Null

        $actionBorder.Child = $actionStack
        $script:ActionPlanPanel.Children.Add($actionBorder) | Out-Null
    }

    # =====================================================================
    # UNDERSTAND PILLAR (rich formatted)
    # =====================================================================
    $script:UnderstandPanel.Children.Clear()
    if ($d.Tags) {
        if ($d.Tags.TagCoverage -lt 50) {
            Add-GuidanceLine -Panel $script:UnderstandPanel -Icon '!' -Bold 'CRITICAL:' -Normal "Only $($d.Tags.TagCoverage)% of resources are tagged. Target 80%+ for meaningful cost allocation. Use Azure Policy to auto-apply tags at resource creation." -Color '#D13438'
        } elseif ($d.Tags.TagCoverage -lt 80) {
            Add-GuidanceLine -Panel $script:UnderstandPanel -Icon '!' -Bold 'Tag coverage:' -Normal "$($d.Tags.TagCoverage)%. Good progress. Focus on the remaining untagged resources using tag inheritance policies." -Color '#FF8C00'
        } else {
            Add-GuidanceLine -Panel $script:UnderstandPanel -Icon '+' -Bold 'Tag coverage:' -Normal "$($d.Tags.TagCoverage)% - strong foundation for showback/chargeback." -Color '#107C10'
        }
    }
    if ($d.TagRecs -and $d.TagRecs.MissingRequired.Count -gt 0) {
        $names = ($d.TagRecs.MissingRequired | ForEach-Object { $_.TagName }) -join ', '
        Add-GuidanceLine -Panel $script:UnderstandPanel -Icon '!' -Bold 'Missing required tags:' -Normal "$names. These are essential for cost allocation per Microsoft CAF." -Color '#D13438'
    }
    if ($d.CostByTag -and $d.CostByTag.NoTagsFound) {
        Add-GuidanceLine -Panel $script:UnderstandPanel -Icon '!' -Bold 'No cost-allocation tags found.' -Normal 'All spend is unallocated. Finance teams cannot attribute costs to business units without CostCenter, Environment, or Application tags.' -Color '#D13438'
    }
    if ($d.Tags -and $d.Tags.TagCoverage -ge 80 -and ($d.TagRecs -and $d.TagRecs.MissingRequired.Count -eq 0)) {
        Add-GuidanceLine -Panel $script:UnderstandPanel -Icon '+' -Bold 'Cost visibility is strong.' -Normal 'Tags are well-deployed and CAF-compliant. Consider implementing tag-based cost allocation rules for shared resources.' -Color '#107C10'
    }

    # =====================================================================
    # QUANTIFY PILLAR (rich formatted)
    # =====================================================================
    $script:QuantifyPanel.Children.Clear()
    $totalActual = 0; $totalForecast = 0
    if ($d.Costs) {
        foreach ($entry in $d.Costs.GetEnumerator()) {
            $totalActual += $entry.Value.Actual
            $totalForecast += $entry.Value.Forecast
        }
    }
    $dayOfMonth = (Get-Date).Day
    $daysInMonth = [DateTime]::DaysInMonth((Get-Date).Year, (Get-Date).Month)
    $pctMonthElapsed = [math]::Round(($dayOfMonth / $daysInMonth) * 100, 0)

    if ($dayOfMonth -le 3) {
        Add-GuidanceLine -Panel $script:QuantifyPanel -Icon 'i' -Bold "Day $dayOfMonth of billing period ($pctMonthElapsed% elapsed)." -Normal 'Forecasts are less reliable this early. Check back after day 7 for more accurate projections.' -Color '#0078D4'
    } elseif ($dayOfMonth -le 7) {
        Add-GuidanceLine -Panel $script:QuantifyPanel -Icon 'i' -Bold "Early in billing period (day $dayOfMonth)." -Normal 'Forecast accuracy improves after week 1.' -Color '#0078D4'
    } else {
        if ($totalActual -gt 0 -and $totalForecast -gt $totalActual * 1.2) {
            $increase = [math]::Round((($totalForecast - $totalActual) / $totalActual) * 100, 0)
            Add-GuidanceLine -Panel $script:QuantifyPanel -Icon '!' -Bold "Forecast is $increase% above MTD spend." -Normal "$currency$($totalForecast.ToString('N2')) projected vs $currency$($totalActual.ToString('N2')) actual on day $dayOfMonth/$daysInMonth. Review scaling patterns and set budget alerts." -Color '#FF8C00'
        } elseif ($totalForecast -gt 0) {
            Add-GuidanceLine -Panel $script:QuantifyPanel -Icon '+' -Bold 'Costs appear stable.' -Normal "Forecast $currency$($totalForecast.ToString('N2')) is within 20% of MTD spend on day $dayOfMonth/$daysInMonth." -Color '#107C10'
        }
    }
    if ($totalForecast -gt 0) {
        Add-GuidanceLine -Panel $script:QuantifyPanel -Icon 'i' -Bold "Current forecast:" -Normal "$currency$($totalForecast.ToString('N2')) for the full month (MTD actual: $currency$($totalActual.ToString('N2')))." -Color '#0078D4'
    }
    if (-not $d.Budgets -or -not $d.Budgets.HasData) {
        Add-GuidanceLine -Panel $script:QuantifyPanel -Icon '!' -Bold 'No Azure Budgets detected.' -Normal 'Set budgets at subscription or resource group level with 50%, 75%, 90%, 100% thresholds. Use action groups for email + auto-shutdown.' -Color '#D13438'
    } else {
        Add-GuidanceLine -Panel $script:QuantifyPanel -Icon '+' -Bold "Budget coverage: $($d.Budgets.BudgetCoverage)%." -Normal "$($d.Budgets.SubsWithBudget) subscription(s) have budgets configured." -Color '#107C10'
    }
    Add-GuidanceLine -Panel $script:QuantifyPanel -Icon '>' -Bold 'TIP:' -Normal 'Use Cost Management Exports to send daily/monthly cost data to a Storage Account for Power BI dashboards and FinOps reporting.' -Color '#8764B8'

    # =====================================================================
    # OPTIMIZE PILLAR (rich formatted)
    # =====================================================================
    $script:OptimizePanel.Children.Clear()
    if ($d.AHB -and $d.AHB.TotalOpportunities -gt 0) {
        Add-GuidanceLine -Panel $script:OptimizePanel -Icon '$' -Bold "$($d.AHB.TotalOpportunities) AHB opportunity(s)." -Normal 'Apply Azure Hybrid Benefit to save 40-85% if you have existing Windows/SQL licenses with Software Assurance. Zero architectural change required.' -Color '#107C10'
    }
    if ($d.Reservations -and ($d.Reservations.TotalAdvisorCount + $d.Reservations.TotalReservationCount) -gt 0) {
        $riSavings = $d.Reservations.EstimatedAnnualSavings.ToString('N2')
        Add-GuidanceLine -Panel $script:OptimizePanel -Icon '$' -Bold "RI/SP opportunities: est. $currency$riSavings/yr savings." -Normal 'For steady-state workloads, commit to 1-year terms first to reduce risk. Savings Plans offer VM family flexibility.' -Color '#107C10'
    }
    if ($d.Optimization -and $d.Optimization.TotalCount -gt 0) {
        foreach ($cat in $d.Optimization.ByCategory) {
            $catSavings = $cat.TotalSavings.ToString('N2')
            Add-GuidanceLine -Panel $script:OptimizePanel -Icon '>' -Bold "$($cat.Count) $($cat.Category) recommendation(s)" -Normal "(est. $currency$catSavings/yr). Review details on the Optimization tab." -Color '#0078D4'
        }
    }
    if ($d.Contract) {
        $type = $d.Contract[0].AgreementType
        if ($type -eq 'MicrosoftOnlineServicesProgram') {
            Add-GuidanceLine -Panel $script:OptimizePanel -Icon '!' -Bold 'Pay-As-You-Go (PAYGO) account detected.' -Normal 'Consider an Enterprise Agreement (EA) or Microsoft Customer Agreement (MCA) for volume discounts, negotiated rates, and better cost management tooling.' -Color '#FF8C00'
        }
    }
    if ($d.Savings -and $d.Savings.TotalMonthly -gt 0) {
        Add-GuidanceLine -Panel $script:OptimizePanel -Icon '+' -Bold "Already saving $currency$($d.Savings.TotalMonthly.ToString('N2'))/mo" -Normal 'from existing reservations, savings plans, and/or AHB. Monitor utilization monthly.' -Color '#107C10'
    }
    if ($script:OptimizePanel.Children.Count -eq 0) {
        Add-GuidanceLine -Panel $script:OptimizePanel -Icon '+' -Bold 'No major optimization gaps detected.' -Normal 'Continue monitoring Azure Advisor and Cost Management for new opportunities.' -Color '#107C10'
    }

    # =====================================================================
    # PERSONAS - FinOps Foundation defined roles
    # =====================================================================
    $script:PersonasPanel.Children.Clear()
    $personas = @(
        @{ Role = 'FinOps Practitioner'; Desc = 'Drives the FinOps practice: runs cost reviews, manages tooling, builds reports, educates teams. Often the first hire for a FinOps program.'; When = 'Always needed' }
        @{ Role = 'Engineering / DevOps Lead'; Desc = 'Implements rightsizing, AHB, auto-shutdown, and tagging at the resource level. Owns technical optimization actions.'; When = 'Always needed' }
        @{ Role = 'Finance / Procurement'; Desc = 'Manages budgets, forecasts, commitment purchases (RIs/SPs), and licensing agreements. Owns the commercial relationship.'; When = 'Always needed' }
        @{ Role = 'Executive Sponsor (VP/Director)'; Desc = 'Champions FinOps across the organization, breaks down silos between finance and engineering, approves commitment purchases.'; When = 'Critical for organizational buy-in' }
        @{ Role = 'Cloud Architect'; Desc = 'Designs cost-efficient architectures, evaluates PaaS vs IaaS trade-offs, and ensures workloads are right-sized from the start.'; When = 'During design reviews and migrations' }
        @{ Role = 'Business Unit Owners'; Desc = 'Consume cost reports (showback/chargeback), validate tag accuracy, and make build-vs-buy decisions for their teams.'; When = 'For cost allocation and accountability' }
    )
    foreach ($p in $personas) {
        $personaTb = [System.Windows.Controls.TextBlock]::new()
        $personaTb.TextWrapping = 'Wrap'
        $personaTb.FontSize = 12.5
        $personaTb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 8)

        $roleRun = [System.Windows.Documents.Run]::new("$($p.Role):  ")
        $roleRun.FontWeight = 'Bold'
        $roleRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#222')
        $personaTb.Inlines.Add($roleRun) | Out-Null

        $descRun = [System.Windows.Documents.Run]::new($p.Desc)
        $descRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#444')
        $personaTb.Inlines.Add($descRun) | Out-Null

        $whenRun = [System.Windows.Documents.Run]::new("  ($($p.When))")
        $whenRun.FontStyle = 'Italic'
        $whenRun.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#888')
        $personaTb.Inlines.Add($whenRun) | Out-Null

        $script:PersonasPanel.Children.Add($personaTb) | Out-Null
    }
}

#-----------------------------------------------------------------------
# COST TREND BAR CHART (pure WPF Canvas drawing)
#-----------------------------------------------------------------------
function Populate-TrendChart {
    $d = $script:scanData.CostTrend
    if (-not $d -or -not $d.HasData) {
        $script:TrendNote.Text = "No cost trend data available."
        return
    }

    # Populate subscription dropdown (only on first call)
    if ($script:TrendSubSelector.Items.Count -eq 0) {
        $script:TrendSubSelector.Items.Add('All Subscriptions') | Out-Null
        if ($d.BySubscription -and $d.BySubscription.Count -gt 0) {
            foreach ($sub in $script:scanData.Auth.Subscriptions) {
                if ($d.BySubscription.ContainsKey($sub.Id)) {
                    $script:TrendSubSelector.Items.Add($sub.Name) | Out-Null
                }
            }
        }
        $script:TrendSubSelector.SelectedIndex = 0
    }

    Draw-TrendChart -Months $d.Months
}

function Draw-TrendChart {
    param([object[]]$Months)

    $canvas = $script:TrendChart
    $canvas.Children.Clear()
    $script:TrendNote.Text = ''

    if (-not $Months -or $Months.Count -eq 0) {
        $script:TrendNote.Text = 'No cost data for selected subscription.'
        return
    }

    $months = $Months

    $currency = if ($months[0].Currency) { Get-CurrencySymbol -Code $months[0].Currency } else { '$' }
    $maxCost = ($months | Measure-Object -Property Cost -Maximum).Maximum
    if ($maxCost -le 0) { $maxCost = 1 }

    $canvasW  = 900
    $canvasH  = 200
    $barGap   = 12
    $labelH   = 30
    $chartH   = $canvasH - $labelH
    $barCount = $months.Count
    $barW     = [math]::Floor(($canvasW - ($barGap * ($barCount + 1))) / $barCount)
    if ($barW -gt 120) { $barW = 120 }

    $colors = @('#0078D4', '#005A9E', '#0063B1', '#2B88D8', '#106EBE', '#004578')

    for ($i = 0; $i -lt $barCount; $i++) {
        $m = $months[$i]
        $barH = [math]::Max(([math]::Round(($m.Cost / $maxCost) * $chartH, 0)), 2)
        $x = $barGap + ($i * ($barW + $barGap))
        $y = $chartH - $barH

        # Bar rectangle
        $rect = [System.Windows.Shapes.Rectangle]::new()
        $rect.Width  = $barW
        $rect.Height = $barH
        $rect.Fill   = [System.Windows.Media.BrushConverter]::new().ConvertFromString($colors[$i % $colors.Count])
        $rect.RadiusX = 3
        $rect.RadiusY = 3
        [System.Windows.Controls.Canvas]::SetLeft($rect, $x)
        [System.Windows.Controls.Canvas]::SetTop($rect, $y)
        $canvas.Children.Add($rect) | Out-Null

        # Cost label above bar (or inside bar if it would clip above canvas)
        $costLabel = [System.Windows.Controls.TextBlock]::new()
        $costLabel.Text = "$currency$($m.Cost.ToString('N0'))"
        $costLabel.FontSize = 10
        $costLabel.TextAlignment = 'Center'
        $costLabel.Width = $barW
        $labelTop = $y - 16
        if ($labelTop -lt 0) {
            # Place label inside the top of the bar with white text
            $labelTop = $y + 4
            $costLabel.Foreground = [System.Windows.Media.Brushes]::White
            $costLabel.FontWeight = 'SemiBold'
        } else {
            $costLabel.Foreground = [System.Windows.Media.Brushes]::Gray
        }
        [System.Windows.Controls.Canvas]::SetLeft($costLabel, $x)
        [System.Windows.Controls.Canvas]::SetTop($costLabel, $labelTop)
        $canvas.Children.Add($costLabel) | Out-Null

        # Month label below bar
        $monthLabel = [System.Windows.Controls.TextBlock]::new()
        $monthLabel.Text = $m.Month
        $monthLabel.FontSize = 10
        $monthLabel.FontWeight = 'SemiBold'
        $monthLabel.Foreground = [System.Windows.Media.Brushes]::DimGray
        $monthLabel.TextAlignment = 'Center'
        $monthLabel.Width = $barW
        [System.Windows.Controls.Canvas]::SetLeft($monthLabel, $x)
        [System.Windows.Controls.Canvas]::SetTop($monthLabel, $chartH + 4)
        $canvas.Children.Add($monthLabel) | Out-Null
    }

    # Trend note
    $firstCost = $months[0].Cost
    $lastCost  = $months[$months.Count - 1].Cost
    if ($firstCost -gt 0) {
        $changePct = [math]::Round((($lastCost - $firstCost) / $firstCost) * 100, 1)
        $direction = if ($changePct -gt 0) { "up" } elseif ($changePct -lt 0) { "down" } else { "flat" }
        $script:TrendNote.Text = "6-month trend: $currency$($firstCost.ToString('N2')) -> $currency$($lastCost.ToString('N2')) ($direction $([math]::Abs($changePct))%)"
    } else {
        $script:TrendNote.Text = ""
    }
}

# Trend subscription dropdown handler
$script:TrendSubSelector.Add_SelectionChanged({
    $d = $script:scanData.CostTrend
    if (-not $d -or -not $d.HasData) { return }

    $selectedIdx = $script:TrendSubSelector.SelectedIndex
    if ($selectedIdx -le 0) {
        # All subscriptions
        Draw-TrendChart -Months $d.Months
    } else {
        $selectedName = $script:TrendSubSelector.SelectedItem
        $sub = $script:scanData.Auth.Subscriptions | Where-Object { $_.Name -eq $selectedName } | Select-Object -First 1
        if ($sub -and $d.BySubscription -and $d.BySubscription.ContainsKey($sub.Id)) {
            Draw-TrendChart -Months $d.BySubscription[$sub.Id]
        } else {
            Draw-TrendChart -Months @()
        }
    }
})

#-----------------------------------------------------------------------
# TAG DEPLOYMENT UI WIRING
#-----------------------------------------------------------------------
$script:tagDeployCurrentTag = $null
$script:tagDeployScopesLoaded = $false
$script:tagDeployScopes = @()
$script:tagRemoveMode = $false
$script:tagCustomMode = $false

function Load-TagScopes {
    if (-not $script:tagDeployScopesLoaded -and $script:scanData.Auth) {
        $script:TagDeployStatus.Text = 'Loading scopes...'
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [action]{}, [System.Windows.Threading.DispatcherPriority]::Background
        )
        $script:tagDeployScopes = Get-TagScopes -Subscriptions $script:scanData.Auth.Subscriptions
        $script:tagDeployScopesLoaded = $true
        $script:TagDeployStatus.Text = ''
    }

    $script:TagScopeSelector.Items.Clear()
    foreach ($s in $script:tagDeployScopes) {
        $script:TagScopeSelector.Items.Add($s.DisplayName) | Out-Null
    }
    if ($script:tagDeployScopes.Count -gt 0) {
        $script:TagScopeSelector.SelectedIndex = 0
    }
}

function Show-TagDeployPanel {
    param([string]$TagName)

    $script:tagDeployCurrentTag = $TagName
    $script:tagRemoveMode = $false
    $script:tagCustomMode = $false
    $script:TagDeployTitle.Text = "Deploy tag: $TagName"
    $script:TagDeployStatus.Text = ''
    $script:TagValueInput.Text = ''
    $script:TagValueInput.Visibility = 'Visible'
    $script:TagNameInput.Visibility = 'Collapsed'
    $script:TagNameLabel.Visibility = 'Collapsed'
    # Show the tag value label
    $valIdx = $script:TagDeployPanel.Child.Children.IndexOf($script:TagValueInput)
    if ($valIdx -gt 0) {
        $script:TagDeployPanel.Child.Children[$valIdx - 1].Visibility = 'Visible'
    }
    $script:TagDeployButton.Content = 'Deploy Tag'
    $script:TagDeployButton.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#0078D4')
    $script:TagDeployPanel.Visibility = 'Visible'

    Load-TagScopes
}

function Show-CustomTagDeployPanel {
    $script:tagDeployCurrentTag = $null
    $script:tagRemoveMode = $false
    $script:tagCustomMode = $true
    $script:TagDeployTitle.Text = "Deploy Custom Tag"
    $script:TagDeployStatus.Text = ''
    $script:TagNameInput.Text = ''
    $script:TagNameInput.Visibility = 'Visible'
    $script:TagNameLabel.Visibility = 'Visible'
    $script:TagValueInput.Text = ''
    $script:TagValueInput.Visibility = 'Visible'
    $valIdx = $script:TagDeployPanel.Child.Children.IndexOf($script:TagValueInput)
    if ($valIdx -gt 0) {
        $script:TagDeployPanel.Child.Children[$valIdx - 1].Visibility = 'Visible'
    }
    $script:TagDeployButton.Content = 'Deploy Tag'
    $script:TagDeployButton.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#0078D4')
    $script:TagDeployPanel.Visibility = 'Visible'

    Load-TagScopes
}

function Show-TagRemovePanel {
    param([string]$TagName)

    $script:tagDeployCurrentTag = $TagName
    $script:tagRemoveMode = $true
    $script:tagCustomMode = $false
    $script:TagDeployTitle.Text = "Remove tag: $TagName"
    $script:TagDeployStatus.Text = ''
    $script:TagNameInput.Visibility = 'Collapsed'
    $script:TagNameLabel.Visibility = 'Collapsed'

    # Show value input as optional filter
    $valIdx = $script:TagDeployPanel.Child.Children.IndexOf($script:TagValueInput)
    if ($valIdx -gt 0) {
        $script:TagDeployPanel.Child.Children[$valIdx - 1].Text = 'Value Filter (blank = all values):'
        $script:TagDeployPanel.Child.Children[$valIdx - 1].Visibility = 'Visible'
    }
    $script:TagValueInput.Text = ''
    $script:TagValueInput.Visibility = 'Visible'
    $script:TagDeployButton.Content = 'Remove Tag'
    $script:TagDeployButton.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D13438')
    $script:TagDeployPanel.Visibility = 'Visible'

    Load-TagScopes

    # Insert "All Scopes" entries at the top of the scope selector for mass removal
    # One per subscription: removes from the sub + all its RGs in a single click
    $allEntries = @()
    foreach ($sub in $script:scanData.Auth.Subscriptions) {
        $allEntries += [PSCustomObject]@{
            DisplayName = "[ALL] $($sub.Name) (Sub + all RGs)"
            SubId       = $sub.Id
        }
    }
    # Insert at position 0 so they appear first
    for ($i = $allEntries.Count - 1; $i -ge 0; $i--) {
        $script:TagScopeSelector.Items.Insert(0, $allEntries[$i].DisplayName)
    }
    # Track in a script-scoped list so the handler knows which indices are "all" entries
    $script:tagRemoveAllEntries = $allEntries
    $script:TagScopeSelector.SelectedIndex = 0
}

#-----------------------------------------------------------------------
# POLICY TAB POPULATION
#-----------------------------------------------------------------------
function Populate-PolicyTab {
    $d = $script:scanData

    # Summary cards
    if ($d.PolicyInv) {
        $script:PolicyCountText.Text      = $d.PolicyInv.AssignmentCount.ToString()
        $script:PolicyComplianceText.Text  = "$($d.PolicyInv.CompliancePct)%"
        $script:PolicyNonCompliantText.Text = $d.PolicyInv.TotalNonCompliant.ToString('N0')

        # Assignment inventory grid with inline Unassign button
        $script:PolicyInventoryGrid.AutoGenerateColumns = $false
        $script:PolicyInventoryGrid.Columns.Clear()

        foreach ($col in @('Assignment Name','Type','Effect','Enforcement','Origin','Subscription','Scope')) {
            $dgCol = [System.Windows.Controls.DataGridTextColumn]::new()
            $dgCol.Header = $col
            $dgCol.Binding = [System.Windows.Data.Binding]::new($col)
            if ($col -in @('Assignment Name','Scope')) {
                $dgCol.Width = [System.Windows.Controls.DataGridLength]::new(1, [System.Windows.Controls.DataGridLengthUnitType]::Star)
                $dgCol.ElementStyle = [System.Windows.Style]::new([System.Windows.Controls.TextBlock])
                $dgCol.ElementStyle.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.TextBlock]::TextWrappingProperty, [System.Windows.TextWrapping]::Wrap))
            }
            $script:PolicyInventoryGrid.Columns.Add($dgCol)
        }

        # Unassign button template column
        $actionCol = [System.Windows.Controls.DataGridTemplateColumn]::new()
        $actionCol.Header = 'Action'
        $actionCol.Width = 75

        $cellFactory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.Button])
        $cellFactory.SetValue([System.Windows.Controls.Button]::ContentProperty, 'Unassign')
        $cellFactory.SetBinding([System.Windows.Controls.Button]::TagProperty, [System.Windows.Data.Binding]::new('AssignmentIndex'))
        $cellFactory.SetValue([System.Windows.Controls.Button]::FontSizeProperty, [double]10)
        $cellFactory.SetValue([System.Windows.Controls.Button]::PaddingProperty, [System.Windows.Thickness]::new(6,1,6,1))
        $cellFactory.SetValue([System.Windows.Controls.Button]::MarginProperty, [System.Windows.Thickness]::new(2,1,2,1))
        $cellFactory.SetValue([System.Windows.Controls.Button]::CursorProperty, [System.Windows.Input.Cursors]::Hand)
        $cellFactory.SetValue([System.Windows.Controls.Button]::BackgroundProperty, [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FDE7E9'))
        $cellFactory.SetValue([System.Windows.Controls.Button]::ForegroundProperty, [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D13438'))
        $cellFactory.SetValue([System.Windows.Controls.Button]::BorderThicknessProperty, [System.Windows.Thickness]::new(1))
        $cellFactory.AddHandler([System.Windows.Controls.Button]::ClickEvent, [System.Windows.RoutedEventHandler]{
            param($sender, $e)
            $idx = [int]$sender.Tag
            $assignment = $script:scanData.PolicyInv.Assignments[$idx]
            $displayName = $assignment.AssignmentName
            $policyDefId = $assignment.PolicyDefId

            # Find ALL assignments with the same PolicyDefId (same policy assigned multiple times)
            $matchingAssignments = @($script:scanData.PolicyInv.Assignments | Where-Object {
                $_.PolicyDefId -and $policyDefId -and $_.PolicyDefId.ToLower() -eq $policyDefId.ToLower()
            })

            $matchCount = $matchingAssignments.Count
            $statusLabel = if ($matchCount -gt 1) { "Removing $matchCount assignments of this policy..." } else { "Removing assignment..." }

            $script:PolicyDeployTitle.Text = "Unassign: $displayName"
            $script:PolicyDeployStatus.Text = $statusLabel
            $script:PolicyDeployStatus.Foreground = [System.Windows.Media.Brushes]::Gray
            $script:PolicyDeployPanel.Visibility = 'Visible'
            $script:PolicyScopeSelector.Visibility = 'Collapsed'
            $script:PolicyEffectSelector.Visibility = 'Collapsed'
            $script:PolicyParamsPanel.Visibility = 'Collapsed'
            $script:PolicyRemediateButton.Visibility = 'Collapsed'
            foreach ($ctrl in @($script:PolicyScopeSelector, $script:PolicyEffectSelector)) {
                $parent = $ctrl.Parent
                if ($parent) {
                    $ctrlIdx = $parent.Children.IndexOf($ctrl)
                    if ($ctrlIdx -gt 0) { $parent.Children[$ctrlIdx - 1].Visibility = 'Collapsed' }
                }
            }
            $script:PolicyDeployButton.Visibility = 'Collapsed'

            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
                [System.Windows.Threading.DispatcherPriority]::Render, [action]{})

            $successCount = 0
            $failMsg = ''
            foreach ($ma in $matchingAssignments) {
                try {
                    $result = Remove-PolicyAssignment -AssignmentId $ma.AssignmentId
                    if ($result.Success) {
                        $successCount++
                    } else {
                        $failMsg = $result.Message
                    }
                } catch {
                    $failMsg = $_.Exception.Message
                }
            }

            if ($successCount -eq $matchCount) {
                $script:PolicyDeployStatus.Text = "Unassigned: $displayName ($successCount assignment(s) removed)"
                $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#107C10')
                $script:actionLog.Add([PSCustomObject]@{ Time = (Get-Date -Format 'HH:mm:ss'); Type = 'Policy Unassigned'; Detail = "$displayName ($successCount removed)" })
                # Disable all matching buttons in the grid
                $sender.Content = 'Removed'
                $sender.IsEnabled = $false
            } elseif ($successCount -gt 0) {
                $script:PolicyDeployStatus.Text = "Partial: $successCount of $matchCount removed. Error: $failMsg"
                $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
            } else {
                $script:PolicyDeployStatus.Text = "Failed: $failMsg"
                $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
            }
            $script:PolicyDeployButton.Visibility = 'Visible'
        })

        $cellTemplate = [System.Windows.DataTemplate]::new()
        $cellTemplate.VisualTree = $cellFactory
        $actionCol.CellTemplate = $cellTemplate
        $script:PolicyInventoryGrid.Columns.Add($actionCol)

        $idx = 0
        $invRows = $d.PolicyInv.Assignments | ForEach-Object {
            $type = if ($_.PolicyDefId -match '/policySetDefinitions/') { 'Initiative' } else { 'Policy' }
            $row = [PSCustomObject]@{
                'Assignment Name' = $_.AssignmentName
                'Type'            = $type
                'Effect'          = $_.Effect
                'Enforcement'     = $_.EnforcementMode
                'Origin'          = $_.Origin
                'Subscription'    = $_.Subscription
                'Scope'           = if ($_.Scope.Length -gt 60) { '...' + $_.Scope.Substring($_.Scope.Length - 57) } else { $_.Scope }
                'AssignmentIndex' = $idx
            }
            $idx++
            $row
        }
        $script:PolicyInventoryGrid.ItemsSource = @($invRows)

        # Per-subscription compliance grid
        $compRows = $d.PolicyInv.ComplianceBySubMap.Values | ForEach-Object {
            [PSCustomObject]@{
                'Subscription'    = $_.Subscription
                'Compliant'       = $_.Compliant
                'Non-Compliant'   = $_.NonCompliant
                'Total Evaluated' = $_.TotalResources
                'Compliance %'    = if (($_.Compliant + $_.NonCompliant) -gt 0) {
                    [math]::Round(($_.Compliant / ($_.Compliant + $_.NonCompliant)) * 100, 1).ToString() + '%'
                } else { '-' }
            }
        }
        $script:PolicyComplianceGrid.ItemsSource = @($compRows)
    }

    # Policy recommendations with inline action buttons
    if ($d.PolicyRecs) {
        $assignedCount  = $d.PolicyRecs.Assigned.Count
        $analysisCount  = $d.PolicyRecs.Analysis.Count
        $script:PolicyRecsCountText.Text = "$assignedCount / $analysisCount"
        $script:PolicyRecsComplianceText.Text = "CAF policy coverage: $($d.PolicyRecs.CompliancePct)% ($assignedCount of $analysisCount recommended policies assigned)"

        # Build the policy recs grid with programmatic columns including an Action button
        $script:PolicyRecsGrid.AutoGenerateColumns = $false
        $script:PolicyRecsGrid.Columns.Clear()

        # Data columns
        foreach ($col in @('Policy','Status','Category','Priority','Pillar','Effect','Purpose')) {
            $dgCol = [System.Windows.Controls.DataGridTextColumn]::new()
            $dgCol.Header = $col
            $dgCol.Binding = [System.Windows.Data.Binding]::new($col)
            if ($col -eq 'Purpose') {
                $dgCol.Width = [System.Windows.Controls.DataGridLength]::new(1, [System.Windows.Controls.DataGridLengthUnitType]::Star)
                $dgCol.ElementStyle = [System.Windows.Style]::new([System.Windows.Controls.TextBlock])
                $dgCol.ElementStyle.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.TextBlock]::TextWrappingProperty, [System.Windows.TextWrapping]::Wrap))
            }
            $script:PolicyRecsGrid.Columns.Add($dgCol)
        }

        # Action button template column
        $actionCol = [System.Windows.Controls.DataGridTemplateColumn]::new()
        $actionCol.Header = 'Action'
        $actionCol.Width = 85

        $cellFactory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.Button])
        $cellFactory.SetBinding([System.Windows.Controls.Button]::ContentProperty, [System.Windows.Data.Binding]::new('ActionLabel'))
        $cellFactory.SetBinding([System.Windows.Controls.Button]::BackgroundProperty, [System.Windows.Data.Binding]::new('ActionBg'))
        $cellFactory.SetBinding([System.Windows.Controls.Button]::ForegroundProperty, [System.Windows.Data.Binding]::new('ActionFg'))
        $cellFactory.SetBinding([System.Windows.Controls.Button]::TagProperty, [System.Windows.Data.Binding]::new('PolicyIndex'))
        $cellFactory.SetValue([System.Windows.Controls.Button]::FontSizeProperty, [double]10)
        $cellFactory.SetValue([System.Windows.Controls.Button]::PaddingProperty, [System.Windows.Thickness]::new(6,1,6,1))
        $cellFactory.SetValue([System.Windows.Controls.Button]::MarginProperty, [System.Windows.Thickness]::new(2,1,2,1))
        $cellFactory.SetValue([System.Windows.Controls.Button]::CursorProperty, [System.Windows.Input.Cursors]::Hand)
        $cellFactory.SetValue([System.Windows.Controls.Button]::BorderThicknessProperty, [System.Windows.Thickness]::new(1))
        $cellFactory.AddHandler([System.Windows.Controls.Button]::ClickEvent, [System.Windows.RoutedEventHandler]{
            param($sender, $e)
            $idx = [int]$sender.Tag
            $pol = $script:scanData.PolicyRecs.Analysis[$idx]
            if ($pol.Status -eq 'Missing') {
                $polParams = if ($pol.Parameters) { $pol.Parameters } else { @() }
                Show-PolicyDeployPanel -PolicyDisplayName $pol.DisplayName -PolicyDefId $pol.PolicyDefId -AllowedEffects $pol.AllowedEffects -DefaultEffect $pol.DefaultEffect -Parameters $polParams
            } else {
                Show-PolicyUnassignPanel -PolicyDisplayName $pol.DisplayName -PolicyDefId $pol.PolicyDefId
            }
        })

        $cellTemplate = [System.Windows.DataTemplate]::new()
        $cellTemplate.VisualTree = $cellFactory
        $actionCol.CellTemplate = $cellTemplate
        $script:PolicyRecsGrid.Columns.Add($actionCol)

        # Populate rows with action metadata
        $brushConv = [System.Windows.Media.BrushConverter]::new()
        $idx = 0
        $recRows = $d.PolicyRecs.Analysis | ForEach-Object {
            $isMissing = $_.Status -eq 'Missing'
            $row = [PSCustomObject]@{
                'Policy'      = $_.DisplayName
                'Status'      = $_.Status
                'Category'    = $_.Category
                'Priority'    = $_.Priority
                'Pillar'      = $_.Pillar
                'Effect'      = $_.DefaultEffect
                'Purpose'     = $_.Purpose
                'PolicyIndex' = $idx
                'ActionLabel' = if ($isMissing) { 'Deploy' } else { 'Unassign' }
                'ActionBg'    = if ($isMissing) { $brushConv.ConvertFromString('#DFF6DD') } else { $brushConv.ConvertFromString('#FDE7E9') }
                'ActionFg'    = if ($isMissing) { $brushConv.ConvertFromString('#107C10') } else { $brushConv.ConvertFromString('#D13438') }
            }
            $idx++
            $row
        }
        $script:PolicyRecsGrid.ItemsSource = @($recRows)
    }
}

function Show-PolicyDeployPanel {
    param(
        [string]$PolicyDisplayName,
        [string]$PolicyDefId,
        [string[]]$AllowedEffects,
        [string]$DefaultEffect,
        [object[]]$Parameters = @()
    )

    $script:policyDeployCurrentDefId   = $PolicyDefId
    $script:policyDeployCurrentName    = $PolicyDisplayName
    $script:policyDeployCurrentParams  = $Parameters
    $script:policyUnassignMode = $false
    $script:PolicyDeployTitle.Text     = "Deploy policy: $PolicyDisplayName"
    $script:PolicyDeployStatus.Text    = ''
    $script:PolicyDeployPanel.Visibility = 'Visible'
    $script:PolicyDeployButton.Content = 'Deploy Policy'
    $script:PolicyDeployButton.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#0078D4')

    # Ensure scope/effect/params are visible (may have been hidden by unassign)
    $script:PolicyScopeSelector.Visibility = 'Visible'
    $script:PolicyEffectSelector.Visibility = 'Visible'
    $script:PolicyParamsPanel.Visibility = 'Visible'
    foreach ($ctrl in @($script:PolicyScopeSelector, $script:PolicyEffectSelector)) {
        $parent = $ctrl.Parent
        if ($parent) {
            $idx = $parent.Children.IndexOf($ctrl)
            if ($idx -gt 0) { $parent.Children[$idx - 1].Visibility = 'Visible' }
        }
    }

    # Populate effect selector
    $script:PolicyEffectSelector.Items.Clear()
    foreach ($eff in $AllowedEffects) {
        $script:PolicyEffectSelector.Items.Add($eff) | Out-Null
    }
    # Pre-select default (Audit for safety)
    $safeDefault = if ($AllowedEffects -contains 'Audit') { 'Audit' } else { $DefaultEffect }
    $idx = [Array]::IndexOf($AllowedEffects, $safeDefault)
    $script:PolicyEffectSelector.SelectedIndex = if ($idx -ge 0) { $idx } else { 0 }

    # Build dynamic parameter inputs
    $script:PolicyParamsPanel.Children.Clear()
    $script:policyParamTextBoxes = @{}
    if ($Parameters -and $Parameters.Count -gt 0) {
        foreach ($p in $Parameters) {
            $lbl = [System.Windows.Controls.TextBlock]::new()
            $lbl.Text = "$($p.Label)$(if ($p.Required) { ' *' } else { '' }):"
            $lbl.FontSize = 12
            $lbl.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
            $script:PolicyParamsPanel.Children.Add($lbl) | Out-Null

            $tb = [System.Windows.Controls.TextBox]::new()
            $tb.Width = 500
            $tb.HorizontalAlignment = 'Left'
            $tb.FontSize = 12
            $tb.Padding = [System.Windows.Thickness]::new(6, 4, 6, 4)
            $tb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
            $script:PolicyParamsPanel.Children.Add($tb) | Out-Null
            $script:policyParamTextBoxes[$p.Name] = @{ TextBox = $tb; Param = $p }
        }
    }

    # Load scopes lazily (once per scan)
    if (-not $script:policyDeployScopesLoaded -and $script:scanData.Auth) {
        $script:PolicyDeployStatus.Text = 'Loading scopes...'
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [action]{}, [System.Windows.Threading.DispatcherPriority]::Background
        )
        $script:policyDeployScopes = Get-PolicyScopes -Subscriptions $script:scanData.Auth.Subscriptions
        $script:policyDeployScopesLoaded = $true
        $script:PolicyDeployStatus.Text = ''
    }

    $script:PolicyScopeSelector.Items.Clear()
    foreach ($s in $script:policyDeployScopes) {
        $script:PolicyScopeSelector.Items.Add($s.DisplayName) | Out-Null
    }
    if ($script:policyDeployScopes.Count -gt 0) {
        $script:PolicyScopeSelector.SelectedIndex = 0
    }
}

function Show-PolicyUnassignPanel {
    param(
        [string]$PolicyDisplayName,
        [string]$PolicyDefId
    )

    $script:policyDeployCurrentDefId = $PolicyDefId
    $script:policyDeployCurrentName  = $PolicyDisplayName
    $script:policyUnassignMode = $true
    $script:PolicyDeployTitle.Text     = "Unassign policy: $PolicyDisplayName"
    $script:PolicyDeployStatus.Text    = ''
    $script:PolicyDeployPanel.Visibility = 'Visible'
    $script:PolicyRemediateButton.Visibility = 'Collapsed'

    # Hide scope/effect/params (not needed for unassign)
    $script:PolicyScopeSelector.Visibility = 'Collapsed'
    $script:PolicyEffectSelector.Visibility = 'Collapsed'
    $script:PolicyParamsPanel.Visibility = 'Collapsed'
    # Hide their labels by finding previous siblings
    foreach ($ctrl in @($script:PolicyScopeSelector, $script:PolicyEffectSelector)) {
        $parent = $ctrl.Parent
        if ($parent) {
            $idx = $parent.Children.IndexOf($ctrl)
            if ($idx -gt 0) { $parent.Children[$idx - 1].Visibility = 'Collapsed' }
        }
    }

    $script:PolicyDeployButton.Content = 'Unassign Policy'
    $script:PolicyDeployButton.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D13438')

    # Find matching assignment(s) from inventory
    $matchingAssignments = @()
    if ($script:scanData.PolicyInv -and $script:scanData.PolicyInv.Assignments) {
        $matchingAssignments = @($script:scanData.PolicyInv.Assignments | Where-Object {
            $_.PolicyDefId -and $_.PolicyDefId.ToLower() -eq $PolicyDefId.ToLower()
        })
    }

    if ($matchingAssignments.Count -eq 0) {
        $script:PolicyDeployStatus.Text = "No assignment found for this policy in the inventory. It may be assigned with a different name."
        $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
        return
    }

    # Store for the unassign handler
    $script:policyUnassignTargets = $matchingAssignments
    $count = $matchingAssignments.Count
    $script:PolicyDeployStatus.Text = "$count assignment(s) found. Click Unassign to remove."
    $script:PolicyDeployStatus.Foreground = [System.Windows.Media.Brushes]::Gray
}

$script:policyUnassignMode = $false
$script:policyUnassignTargets = @()

#-----------------------------------------------------------------------
# BILLING TAB POPULATION
#-----------------------------------------------------------------------
function Populate-BillingTab {
    $d = $script:scanData.Billing

    if (-not $d -or -not $d.HasBillingAccess) {
        $script:BillingAccessNote.Text = "[!] No billing account access. Assign Billing Reader on your billing account to see billing profiles, invoice sections, and cost allocation rules."
        return
    }
    $script:BillingAccessNote.Text = ''

    # Billing Accounts
    if ($d.BillingAccounts.Count -gt 0) {
        $baRows = $d.BillingAccounts | ForEach-Object {
            [PSCustomObject]@{
                'Account Name'   = $_.DisplayName
                'Agreement Type' = $_.AgreementType
                'Account Type'   = $_.AccountType
                'Status'         = $_.AccountStatus
            }
        }
        $script:BillingAccountsGrid.ItemsSource = @($baRows)
    } else {
        $script:BillingAccountsGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No billing accounts found.' })
    }

    # Billing Profiles
    if ($d.BillingProfiles.Count -gt 0) {
        $bpRows = $d.BillingProfiles | ForEach-Object {
            [PSCustomObject]@{
                'Profile Name'    = $_.DisplayName
                'Billing Account' = $_.BillingAccount
                'Currency'        = $_.Currency
                'Invoice Day'     = $_.InvoiceDay
                'Status'          = $_.Status
            }
        }
        $script:BillingProfilesGrid.ItemsSource = @($bpRows)
    } else {
        $script:BillingProfilesGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No billing profiles found (MCA/MPA only).' })
    }

    # Invoice Sections
    if ($d.InvoiceSections.Count -gt 0) {
        $isRows = $d.InvoiceSections | ForEach-Object {
            [PSCustomObject]@{
                'Section Name'    = $_.DisplayName
                'Billing Profile' = $_.BillingProfile
                'Billing Account' = $_.BillingAccount
                'State'           = $_.State
            }
        }
        $script:InvoiceSectionsGrid.ItemsSource = @($isRows)
    } else {
        $script:InvoiceSectionsGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No invoice sections found (MCA only).' })
    }

    # EA Departments
    if ($d.EADepartments.Count -gt 0) {
        $script:EADeptHeader.Visibility = 'Visible'
        $script:EADeptGrid.Visibility = 'Visible'
        $eaRows = $d.EADepartments | ForEach-Object {
            [PSCustomObject]@{
                'Department'      = $_.DisplayName
                'Billing Account' = $_.BillingAccount
                'Cost Center'     = $_.CostCenter
                'Status'          = $_.Status
            }
        }
        $script:EADeptGrid.ItemsSource = @($eaRows)
    }

    # Cost Allocation Rules
    if ($d.CostAllocationRules.Count -gt 0) {
        $carRows = $d.CostAllocationRules | ForEach-Object {
            [PSCustomObject]@{
                'Rule Name'       = $_.RuleName
                'Description'     = $_.Description
                'Status'          = $_.Status
                'Source Count'    = $_.SourceCount
                'Target Count'    = $_.TargetCount
                'Created'         = $_.CreatedDate
                'Updated'         = $_.UpdatedDate
            }
        }
        $script:CostAllocationGrid.ItemsSource = @($carRows)
    } else {
        $script:CostAllocationGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No cost allocation rules configured. Cost allocation rules let you redistribute shared costs across subscriptions.' })
    }
}

#-----------------------------------------------------------------------
# BUDGET STATUS POPULATION
#-----------------------------------------------------------------------
function Populate-BudgetSection {
    # BudgetSummaryText / BudgetGrid were removed from the XAML (budget
    # management lives on the Budgets tab now).  Skip silently when the
    # legacy overview elements no longer exist.
    if (-not $script:BudgetSummaryText -and -not $script:BudgetGrid) { return }

    $d = $script:scanData
    if (-not $d.Budgets) {
        if ($script:BudgetSummaryText) { $script:BudgetSummaryText.Text = 'Budget data not available.' }
        return
    }

    $b = $d.Budgets
    $riskText = "$($b.SubsWithBudget) of $($b.SubsWithBudget + $b.SubsWithoutBudget) subscriptions have budgets ($($b.BudgetCoverage)% coverage)"
    if ($b.SubsWithoutBudget -gt 0) {
        $riskText += " | $($b.SubsWithoutBudget) subs have NO budget configured"
    }
    if ($script:BudgetSummaryText) { $script:BudgetSummaryText.Text = $riskText }

    if ($script:BudgetGrid) {
        if ($b.Budgets.Count -gt 0) {
            $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
            foreach ($budget in $b.Budgets) {
                $sym = Get-CurrencySymbol $budget.Currency
                [void]$rows.Add([PSCustomObject]@{
                    Subscription   = $budget.Subscription
                    'Budget Name'  = $budget.BudgetName
                    Category       = $budget.Category
                    'Budget Amount' = "$sym$(([double]$budget.Amount).ToString('N2'))"
                    'Actual Spend' = "$sym$(([double]$budget.ActualSpend).ToString('N2'))"
                    '% Used'       = "$($budget.PctUsed)%"
                    'Forecast'     = "$sym$(([double]$budget.Forecast).ToString('N2'))"
                    '% Forecast'   = "$($budget.PctForecast)%"
                    Risk           = $budget.Risk
                    Thresholds     = $budget.Thresholds
                    Contacts       = if ($budget.ContactEmails) { $budget.ContactEmails } else { '' }
                })
            }
            $script:BudgetGrid.ItemsSource = @($rows | Sort-Object { [double]($_.'% Used' -replace '%','') } -Descending)
        } else {
            $script:BudgetGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No budgets configured. Set up Azure Budgets to track spend against targets.' })
        }
    }
}

#-----------------------------------------------------------------------
# COST ANOMALY DETECTION (month-over-month per subscription)
#-----------------------------------------------------------------------
function Populate-AnomalySection {
    $d = $script:scanData
    if (-not $d.CostTrend -or -not $d.CostTrend.HasData) {
        $script:AnomalyNote.Text = 'Cost trend data not available for anomaly detection.'
        return
    }

    # Build per-subscription month-over-month from cost data + trend
    $anomalies = [System.Collections.Generic.List[PSCustomObject]]::new()
    $currency = if ($d.CostTrend.Months[0].Currency) { Get-CurrencySymbol -Code $d.CostTrend.Months[0].Currency } else { '$' }

    if ($d.Costs) {
        $months = $d.CostTrend.Months
        $lastMonth = if ($months.Count -ge 2) { $months[$months.Count - 2] } else { $null }
        $currentMonth = $months[$months.Count - 1]

        foreach ($sub in $d.Auth.Subscriptions) {
            $currentCost = if ($d.Costs.ContainsKey($sub.Id)) { $d.Costs[$sub.Id].Forecast } else { 0 }
            # Use the ratio of this sub's cost to total to estimate per-sub last month
            $totalCurrent = 0
            foreach ($entry in $d.Costs.GetEnumerator()) { $totalCurrent += $entry.Value.Forecast }
            $subShare = if ($totalCurrent -gt 0) { $currentCost / $totalCurrent } else { 0 }

            if ($lastMonth -and $lastMonth.Cost -gt 0) {
                $estLastMonth = [math]::Round($lastMonth.Cost * $subShare, 2)
                if ($estLastMonth -gt 50) {
                    $change = $currentCost - $estLastMonth
                    $changePct = [math]::Round(($change / $estLastMonth) * 100, 1)
                    if ([math]::Abs($changePct) -ge 25) {
                        $direction = if ($changePct -gt 0) { 'Up' } else { 'Down' }
                        [void]$anomalies.Add([PSCustomObject]@{
                            Subscription = $sub.Name
                            'Prior Month (est.)' = "$currency$($estLastMonth.ToString('N2'))"
                            'Current Forecast' = "$currency$($currentCost.ToString('N2'))"
                            'Change' = "$currency$($change.ToString('N2'))"
                            'Change %' = "$changePct%"
                            Direction = $direction
                        })
                    }
                }
            }
        }
    }

    if ($anomalies.Count -gt 0) {
        $script:AnomalyNote.Text = "$($anomalies.Count) subscription(s) with 25%+ month-over-month cost change detected."
        $script:AnomalyGrid.ItemsSource = @($anomalies | Sort-Object { [math]::Abs([double]($_.'Change %' -replace '%','')) } -Descending)
    } else {
        $script:AnomalyNote.Text = 'No significant cost anomalies detected (all subscriptions within 25% of prior month).'
        $script:AnomalyGrid.ItemsSource = @()
    }
}

#-----------------------------------------------------------------------
# COST MANAGEMENT ALERTS (API-based triggered alerts + configured rules)
#-----------------------------------------------------------------------
function Populate-AlertsSection {
    $d = $script:scanData
    if (-not $d.AnomalyAlerts -or -not $d.AnomalyAlerts.HasData) {
        $script:AlertsSummaryNote.Text = 'No Cost Management alerts found.'
        $script:TriggeredAlertsGrid.ItemsSource = @()
        $script:ConfiguredRulesGrid.ItemsSource = @()
        return
    }

    $aa = $d.AnomalyAlerts
    $parts = @()
    if ($aa.TotalAlerts -gt 0) { $parts += "$($aa.TotalAlerts) triggered alert(s)" }
    if ($aa.ActiveAlertCount -gt 0) { $parts += "$($aa.ActiveAlertCount) active" }
    if ($aa.AnomalyAlertCount -gt 0) { $parts += "$($aa.AnomalyAlertCount) anomaly" }
    if ($aa.BudgetAlertCount -gt 0) { $parts += "$($aa.BudgetAlertCount) budget" }
    if ($aa.ConfiguredRuleCount -gt 0) { $parts += "$($aa.ConfiguredRuleCount) configured rule(s)" }
    $script:AlertsSummaryNote.Text = if ($parts.Count -gt 0) { $parts -join ' | ' } else { 'No alerts found.' }

    # Triggered alerts grid
    if ($aa.TriggeredAlerts.Count -gt 0) {
        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($a in $aa.TriggeredAlerts) {
            $sym = Get-CurrencySymbol $a.Unit
            [void]$rows.Add([PSCustomObject]@{
                Subscription = $a.Subscription
                Type         = $a.AlertType
                Category     = $a.Category
                Status       = $a.Status
                Amount       = "$sym$(([double]$a.Amount).ToString('N2'))"
                'Current Spend' = "$sym$(([double]$a.CurrentSpend).ToString('N2'))"
                Contacts     = $a.Contacts
                Created      = $a.CreatedAt
            })
        }
        $script:TriggeredAlertsGrid.ItemsSource = @($rows | Sort-Object Created -Descending)
    } else {
        $script:TriggeredAlertsGrid.ItemsSource = @()
    }

    # Configured anomaly rules grid
    if ($aa.ConfiguredRules.Count -gt 0) {
        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($r in $aa.ConfiguredRules) {
            [void]$rows.Add([PSCustomObject]@{
                Subscription = $r.Subscription
                'Rule Name'  = $r.DisplayName
                Status       = $r.Status
                Recipients   = $r.ToEmails
                'Next Run'   = $r.NextRunTime
            })
        }
        $script:ConfiguredRulesGrid.ItemsSource = @($rows)
    } else {
        $script:ConfiguredRulesGrid.ItemsSource = @()
    }
}

#-----------------------------------------------------------------------
# COMMITMENT UTILIZATION POPULATION
#-----------------------------------------------------------------------
function Populate-CommitmentSection {
    $d = $script:scanData

    # RI Util card
    if ($d.Commitments) {
        $riAvg = $d.Commitments.RIAvgUtilization
        $script:RIUtilText.Text = if ($riAvg -ge 0) { "$riAvg%" } else { 'N/A' }
        $riCount = $d.Commitments.Reservations.Count
        $spCount = $d.Commitments.SavingsPlans.Count
        $underutil = $d.Commitments.UnderutilizedRIs
        $detailParts = @()
        if ($riCount -gt 0) { $detailParts += "$riCount RIs" }
        if ($spCount -gt 0) { $detailParts += "$spCount SPs" }
        if ($underutil -gt 0) { $detailParts += "$underutil underutilized" }
        $script:RIUtilDetail.Text = if ($detailParts.Count -gt 0) { $detailParts -join ' | ' } else { 'No existing commitments found' }

        # Commitment grid - combine RIs and SPs
        $commitRows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($ri in $d.Commitments.Reservations) {
            [void]$commitRows.Add([PSCustomObject]@{
                Type = 'Reservation'
                Name = $ri.Name
                'Resource Type' = $ri.ResourceType
                Quantity = $ri.Quantity
                'Utilization %' = "$($ri.UtilizationPercent)%"
                Status = $ri.Status
            })
        }
        foreach ($sp in $d.Commitments.SavingsPlans) {
            [void]$commitRows.Add([PSCustomObject]@{
                Type = 'Savings Plan'
                Name = $sp.Name
                'Resource Type' = $sp.BenefitType
                Quantity = '-'
                'Utilization %' = "$($sp.UtilizationPercent)%"
                Status = $sp.Status
            })
        }
        if ($commitRows.Count -gt 0) {
            $script:CommitmentGrid.ItemsSource = @($commitRows)
        } else {
            $script:CommitmentGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No active reservations or savings plans found.' })
        }
    } else {
        $script:RIUtilText.Text = 'N/A'
        $script:RIUtilDetail.Text = 'Could not query commitment data'
        $script:CommitmentGrid.ItemsSource = @([PSCustomObject]@{ Status = 'Commitment utilization data not available.' })
    }
}

#-----------------------------------------------------------------------
# ORPHANED RESOURCES POPULATION
#-----------------------------------------------------------------------
function Populate-OrphanedSection {
    $d = $script:scanData

    # Map orphan categories to ARM resource types for cost lookup
    $categoryToType = @{
        'Orphaned Disk'         = 'microsoft.compute/disks'
        'Unattached Public IP'  = 'microsoft.network/publicipaddresses'
        'Unattached NIC'        = 'microsoft.network/networkinterfaces'
        'Deallocated VM'        = 'microsoft.compute/virtualmachines'
        'Empty App Service Plan'= 'microsoft.web/serverfarms'
        'Old Snapshot'          = 'microsoft.compute/snapshots'
    }

    # Currency helper
    $currency = if ($d.ResourceCosts -and $d.ResourceCosts.Count -gt 0) {
        Get-CurrencySymbol -Code $d.ResourceCosts[0].Currency
    } else { '$' }

    if ($d.Orphans -and $d.Orphans.Orphans.Count -gt 0) {
        $orphans = $d.Orphans.Orphans
        $script:OrphanCountText.Text = "$($orphans.Count) found"

        # Summarize by category
        $byCat = $orphans | Group-Object Category
        $catParts = $byCat | ForEach-Object { "$($_.Count) $($_.Name)" }
        $script:OrphanDetailText.Text = ($catParts -join ', ')

        $orphanRows = [System.Collections.Generic.List[PSCustomObject]]::new()
        $totalWaste = 0.0
        $costedCount = 0

        foreach ($o in $orphans) {
            $rc = $null
            $armType = $categoryToType[$o.Category]
            if ($armType -and $d.ResourceCosts) {
                $rc = Find-ResourceCost -Name $o.ResourceName -SubscriptionId $o.SubscriptionId -ResourceGroup $o.ResourceGroup -ResourceType $armType
            }
            $mtdCost = if ($rc -and $rc.Actual) { $rc.Actual } else { $null }
            $annualEst = if ($mtdCost -and $mtdCost -gt 0) {
                $dayOfMonth = (Get-Date).Day
                $daysInMonth = [DateTime]::DaysInMonth((Get-Date).Year, (Get-Date).Month)
                $projectedMonthly = $mtdCost / $dayOfMonth * $daysInMonth
                [math]::Round($projectedMonthly * 12, 2)
            } else { $null }

            if ($mtdCost -and $mtdCost -gt 0) {
                $totalWaste += $mtdCost
                $costedCount++
            }

            [void]$orphanRows.Add([PSCustomObject]@{
                Category         = $o.Category
                Resource         = $o.ResourceName
                'Resource Group' = $o.ResourceGroup
                Location         = $o.Location
                Detail           = $o.Detail
                'Cost (MTD)'     = if ($mtdCost) { "$currency$($mtdCost.ToString('N2'))" } else { '-' }
                'Est. Annual'    = if ($annualEst) { "$currency$($annualEst.ToString('N2'))" } else { '-' }
            })
        }
        $script:OrphanGrid.ItemsSource = @($orphanRows)

        # Summary with dollar amounts
        $summary = "$($orphans.Count) orphaned/idle resources found across $($byCat.Count) categories."
        if ($costedCount -gt 0) {
            $annualTotal = 0.0
            $dayOfMonth = (Get-Date).Day
            $daysInMonth = [DateTime]::DaysInMonth((Get-Date).Year, (Get-Date).Month)
            $annualTotal = [math]::Round(($totalWaste / $dayOfMonth * $daysInMonth) * 12, 2)
            $summary += " Estimated waste: $currency$($totalWaste.ToString('N2')) MTD ($currency$($annualTotal.ToString('N2'))/yr projected) across $costedCount costed resources."
        }
        $uncosted = $orphans.Count - $costedCount
        if ($uncosted -gt 0) {
            $summary += " $uncosted resources had no cost data (may be zero-cost or recently created)."
        }
        $script:OrphanSummaryText.Text = $summary
    } else {
        $script:OrphanCountText.Text = '0'
        $script:OrphanDetailText.Text = 'No orphaned resources'
        $script:OrphanSummaryText.Text = 'No orphaned or idle resources detected. Environment looks clean.'
        $script:OrphanGrid.ItemsSource = @([PSCustomObject]@{ Status = 'No orphaned resources found. All disks, IPs, NICs, VMs, and App Service Plans appear to be in use.' })
    }
}

#-----------------------------------------------------------------------
# IDLE VM SECTION (Optimization tab)
#-----------------------------------------------------------------------
function Populate-IdleVMSection {
    $d = $script:scanData
    if (-not $d.IdleVMs -or -not $d.IdleVMs.HasData) {
        $script:IdleVMSummaryText.Text = "No idle or underutilized VMs detected (scanned $($d.IdleVMs.ScannedVMs) running VMs)."
        $script:IdleVMGrid.ItemsSource = @([PSCustomObject]@{ Status = 'All running VMs show healthy utilization. No action needed.' })
        return
    }

    if (-not $script:resCostMapBuilt) { Build-ResourceCostMap }
    $currency = if ($d.ResourceCosts -and $d.ResourceCosts.Count -gt 0) {
        Get-CurrencySymbol -Code $d.ResourceCosts[0].Currency
    } else { '$' }

    $idleCount = ($d.IdleVMs.IdleVMs | Where-Object { $_.Classification -eq 'Idle' }).Count
    $underCount = ($d.IdleVMs.IdleVMs | Where-Object { $_.Classification -eq 'Underutilized' }).Count
    $script:IdleVMSummaryText.Text = "$($d.IdleVMs.Count) VM(s) flagged: $idleCount idle, $underCount underutilized (of $($d.IdleVMs.ScannedVMs) running VMs scanned)"

    $rows = @()
    foreach ($vm in $d.IdleVMs.IdleVMs) {
        $rc = Find-ResourceCost -Name $vm.VMName -SubscriptionId $vm.SubscriptionId -ResourceGroup $vm.ResourceGroup -ResourceType 'microsoft.compute/virtualmachines'
        $actual   = if ($rc) { "$currency$($rc.Actual.ToString('N2'))" } else { '-' }
        $forecast = if ($rc) { "$currency$($rc.Forecast.ToString('N2'))" } else { '-' }
        $rows += [PSCustomObject]@{
            Classification = $vm.Classification
            VM             = $vm.VMName
            'Resource Group' = $vm.ResourceGroup
            Size           = $vm.VMSize
            OS             = $vm.OS
            'Avg CPU (14d)' = "$($vm.AvgCPU14d)%"
            'Net/Day'      = $vm.NetworkPerDay
            'Cost (MTD)'   = $actual
            Forecast       = $forecast
            Recommendation = $vm.Recommendation
        }
    }
    $script:IdleVMGrid.ItemsSource = @($rows)
}

#-----------------------------------------------------------------------
# STORAGE TIER SECTION (Optimization tab)
#-----------------------------------------------------------------------
function Populate-StorageTierSection {
    $d = $script:scanData
    if (-not $d.StorageTier -or -not $d.StorageTier.HasData) {
        $total = if ($d.StorageTier) { $d.StorageTier.TotalHotAccounts } else { 0 }
        $script:StorageTierSummaryText.Text = "No storage tier optimization found ($total hot-tier accounts scanned)."
        $script:StorageTierGrid.ItemsSource = @([PSCustomObject]@{ Status = 'All hot-tier storage accounts show healthy transaction activity. No action needed.' })
        return
    }

    $archiveCount = ($d.StorageTier.Recommendations | Where-Object { $_.Recommendation -eq 'Archive' }).Count
    $coolCount    = ($d.StorageTier.Recommendations | Where-Object { $_.Recommendation -eq 'Cool' }).Count
    $script:StorageTierSummaryText.Text = "$($d.StorageTier.Count) account(s) flagged: $archiveCount for Archive, $coolCount for Cool (of $($d.StorageTier.TotalHotAccounts) hot-tier accounts)"

    $rows = @()
    foreach ($sa in $d.StorageTier.Recommendations) {
        $rows += [PSCustomObject]@{
            'Storage Account' = $sa.StorageAccount
            'Resource Group'  = $sa.ResourceGroup
            Location          = $sa.Location
            SKU               = $sa.SKU
            'Current Tier'    = $sa.CurrentTier
            'Capacity (GB)'   = $sa.CapacityGB
            'Transactions (30d)' = $sa.Transactions30d
            Recommendation    = $sa.Recommendation
            'Est. Savings'    = "$($sa.EstSavingsPct)%"
        }
    }
    $script:StorageTierGrid.ItemsSource = @($rows)
}

#-----------------------------------------------------------------------
# RESOURCES TAB (static links — no scan data needed)
#-----------------------------------------------------------------------
function Populate-ResourcesTab {
    # Helper to create a clickable hyperlink block
    function New-LinkBlock {
        param([string]$Text, [string]$Url, [string]$Description)
        $panel = [System.Windows.Controls.StackPanel]::new()
        $panel.Margin = [System.Windows.Thickness]::new(0, 2, 0, 6)

        $link = [System.Windows.Documents.Hyperlink]::new()
        $link.Inlines.Add($Text)
        $link.NavigateUri = [Uri]::new($Url)
        $link.Add_RequestNavigate({ Start-Process $_.Uri.AbsoluteUri })

        $tb = [System.Windows.Controls.TextBlock]::new()
        $tb.FontSize = 13
        $tb.Inlines.Add($link)
        $panel.Children.Add($tb) | Out-Null

        if ($Description) {
            $desc = [System.Windows.Controls.TextBlock]::new()
            $desc.Text = $Description
            $desc.FontSize = 11
            $desc.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#666')
            $desc.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $desc.Margin = [System.Windows.Thickness]::new(12, 0, 0, 0)
            $panel.Children.Add($desc) | Out-Null
        }
        $panel
    }

    # FinOps Framework
    $script:ResourcesFinOpsPanel.Children.Clear()
    $finopsLinks = @(
        ,@('FinOps Foundation', 'https://www.finops.org/', 'The FinOps Foundation — framework, community, certifications.')
        ,@('FinOps with Azure', 'https://learn.microsoft.com/en-us/azure/cost-management-billing/finops/', 'Microsoft Learn — FinOps principles applied to Azure.')
        ,@('Cloud Adoption Framework — Cost Management', 'https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/manage/azure-server-management/cost-management', 'CAF discipline for managing cloud costs at enterprise scale.')
        ,@('FinOps Toolkit (GitHub)', 'https://github.com/microsoft/finops-toolkit', 'Open-source Power BI reports, workbooks, and Bicep modules from Microsoft.')
    )
    foreach ($item in $finopsLinks) {
        $script:ResourcesFinOpsPanel.Children.Add((New-LinkBlock -Text $item[0] -Url $item[1] -Description $item[2])) | Out-Null
    }

    # Cost Management
    $script:ResourcesCostPanel.Children.Clear()
    $costLinks = @(
        ,@('Azure Cost Management Overview', 'https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/overview-cost-management', 'Core service for analyzing, monitoring, and optimizing Azure costs.')
        ,@('Azure Advisor — Cost Recommendations', 'https://learn.microsoft.com/en-us/azure/advisor/advisor-cost-recommendations', 'Automated right-sizing, shutdown, and purchase recommendations.')
        ,@('Azure Pricing Calculator', 'https://azure.microsoft.com/en-us/pricing/calculator/', 'Estimate costs before deploying resources.')
        ,@('Cost Management Best Practices', 'https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-best-practices', 'Official best practices for Azure cost management.')
    )
    foreach ($item in $costLinks) {
        $script:ResourcesCostPanel.Children.Add((New-LinkBlock -Text $item[0] -Url $item[1] -Description $item[2])) | Out-Null
    }

    # Rate Optimization
    $script:ResourcesRatePanel.Children.Clear()
    $rateLinks = @(
        ,@('Azure Reservations', 'https://learn.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations', 'Lock in discounted rates for VMs, SQL, Cosmos, and more (30-72% savings).')
        ,@('Azure Savings Plans', 'https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/', 'Flexible hourly commitment across compute services (15-65% savings).')
        ,@('Azure Hybrid Benefit', 'https://learn.microsoft.com/en-us/azure/virtual-machines/windows/hybrid-use-benefit-licensing', 'Use existing Windows/SQL licenses to save 40-85% on Azure VMs and SQL.')
        ,@('Dev/Test Pricing', 'https://azure.microsoft.com/en-us/pricing/dev-test/', 'Discounted rates for dev/test workloads — no Windows license charges.')
    )
    foreach ($item in $rateLinks) {
        $script:ResourcesRatePanel.Children.Add((New-LinkBlock -Text $item[0] -Url $item[1] -Description $item[2])) | Out-Null
    }

    # Governance
    $script:ResourcesGovernancePanel.Children.Clear()
    $govLinks = @(
        ,@('Azure Policy Overview', 'https://learn.microsoft.com/en-us/azure/governance/policy/overview', 'Enforce organizational standards and assess compliance at scale.')
        ,@('Tagging Strategy', 'https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging', 'CAF tagging best practices for cost allocation and governance.')
        ,@('Management Group Hierarchy', 'https://learn.microsoft.com/en-us/azure/governance/management-groups/overview', 'Organize subscriptions and apply policies at scale.')
        ,@('Azure Budgets', 'https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets', 'Set spending thresholds and receive alerts when costs exceed targets.')
    )
    foreach ($item in $govLinks) {
        $script:ResourcesGovernancePanel.Children.Add((New-LinkBlock -Text $item[0] -Url $item[1] -Description $item[2])) | Out-Null
    }

    # Workbooks & Tools
    $script:ResourcesToolsPanel.Children.Clear()
    $toolLinks = @(
        ,@('Orphaned Resources Workbook', 'https://github.com/dolevshor/azure-orphan-resources', 'Community Azure Workbook showing orphaned resources across subscriptions.')
        ,@('Azure Optimization Engine (AOE)', 'https://github.com/helderpinto/AzureOptimizationEngine', 'Automated optimization recommendations engine using Log Analytics.')
        ,@('Cost Management Labs', 'https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/quick-acm-cost-analysis', 'Hands-on quickstart: analyze costs in the Azure portal.')
        ,@('Azure Charts', 'https://azurecharts.com/', 'Visual changelog of Azure services, regions, and updates.')
        ,@('Azure FinOps Multitool (this app)', 'https://github.com/z-larsen/Azure-FinOps-Multitool', 'Source code and documentation for this scanner.')
    )
    foreach ($item in $toolLinks) {
        $script:ResourcesToolsPanel.Children.Add((New-LinkBlock -Text $item[0] -Url $item[1] -Description $item[2])) | Out-Null
    }
}

#-----------------------------------------------------------------------
# BUDGETS TAB
#-----------------------------------------------------------------------
function Populate-BudgetsTab {
    $d = $script:scanData
    if (-not $d.Auth -or -not $d.Auth.Subscriptions) { return }

    # Populate subscription dropdown (for viewing budgets)
    $script:BudgetSubSelector.Items.Clear()
    $script:BudgetSubSelector.Items.Add('All Subscriptions') | Out-Null
    foreach ($sub in $d.Auth.Subscriptions) {
        $script:BudgetSubSelector.Items.Add($sub.Name) | Out-Null
    }
    $script:BudgetSubSelector.SelectedIndex = 0

    # Populate budget deploy scope selector with actual subscriptions
    $script:BudgetDeployScopeSelector.Items.Clear()
    $allItem = [System.Windows.Controls.ComboBoxItem]::new()
    $allItem.Content = 'All Subscriptions'
    $script:BudgetDeployScopeSelector.Items.Add($allItem) | Out-Null
    foreach ($sub in $d.Auth.Subscriptions) {
        $item = [System.Windows.Controls.ComboBoxItem]::new()
        $item.Content = $sub.Name
        $item.Tag = $sub.Id
        $script:BudgetDeployScopeSelector.Items.Add($item) | Out-Null
    }
    $script:BudgetDeployScopeSelector.SelectedIndex = 0

    # Populate Action Group selector
    $script:BudgetActionGroupSelector.Items.Clear()
    $noneItem = [System.Windows.Controls.ComboBoxItem]::new()
    $noneItem.Content = '(None)'
    $noneItem.Tag = ''
    $script:BudgetActionGroupSelector.Items.Add($noneItem) | Out-Null
    foreach ($sub in $d.Auth.Subscriptions) {
        try {
            $agPath = "/subscriptions/$($sub.Id)/providers/microsoft.insights/actionGroups?api-version=2023-01-01"
            $agResp = Invoke-AzRestMethodWithRetry -Path $agPath -Method GET
            if ($agResp.StatusCode -eq 200) {
                $ags = ($agResp.Content | ConvertFrom-Json).value
                foreach ($ag in $ags) {
                    $agItem = [System.Windows.Controls.ComboBoxItem]::new()
                    $agItem.Content = "$($ag.name) ($($sub.Name))"
                    $agItem.Tag = $ag.id
                    $script:BudgetActionGroupSelector.Items.Add($agItem) | Out-Null
                }
            }
        } catch {
            Write-Warning "Could not list action groups for $($sub.Name): $($_.Exception.Message)"
        }
    }
    $script:BudgetActionGroupSelector.SelectedIndex = 0

    # Populate tag name dropdown for tag-scoped budgets
    $script:BudgetDeployTagNameSelector.Items.Clear()
    $noneTagItem = [System.Windows.Controls.ComboBoxItem]::new()
    $noneTagItem.Content = '(No tag filter)'
    $script:BudgetDeployTagNameSelector.Items.Add($noneTagItem) | Out-Null
    if ($d.Tags -and $d.Tags.TagNames) {
        foreach ($tagEntry in $d.Tags.TagNames.GetEnumerator()) {
            $tagItem = [System.Windows.Controls.ComboBoxItem]::new()
            $tagItem.Content = "$($tagEntry.Key) ($($tagEntry.Value.ResourceCount) resources)"
            $tagItem.Tag = $tagEntry.Key
            $script:BudgetDeployTagNameSelector.Items.Add($tagItem) | Out-Null
        }
    }
    $script:BudgetDeployTagNameSelector.SelectedIndex = 0

    # Populate budget policy scope selector
    $script:BudgetPolicyScopeSelector.Items.Clear()
    foreach ($sub in $d.Auth.Subscriptions) {
        $script:BudgetPolicyScopeSelector.Items.Add("[Sub] $($sub.Name)") | Out-Null
    }
    if ($d.Auth.Subscriptions.Count -gt 0) {
        $script:BudgetPolicyScopeSelector.SelectedIndex = 0
    }
}

function Update-BudgetDetailView {
    $d = $script:scanData
    $selectedName = $script:BudgetSubSelector.SelectedItem
    if (-not $selectedName -or -not $d.Budgets) {
        $script:BudgetSubSummary.Text = 'No budget data available. Run a scan first.'
        return
    }

    $budgets = $d.Budgets.Budgets
    if ($selectedName -ne 'All Subscriptions') {
        $budgets = @($budgets | Where-Object { $_.Subscription -eq $selectedName })
    }

    if ($budgets.Count -gt 0) {
        $overBudget = @($budgets | Where-Object { $_.Risk -eq 'Over Budget' }).Count
        $atRisk = @($budgets | Where-Object { $_.Risk -eq 'At Risk' }).Count
        $script:BudgetSubSummary.Text = "$($budgets.Count) budget(s) found. $overBudget over budget, $atRisk at risk."

        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($b in $budgets) {
            $sym = Get-CurrencySymbol $b.Currency
            [void]$rows.Add([PSCustomObject]@{
                Subscription   = $b.Subscription
                'Budget Name'  = $b.BudgetName
                Category       = $b.Category
                'Amount'       = "$sym$(([double]$b.Amount).ToString('N2'))"
                'Actual Spend' = "$sym$(([double]$b.ActualSpend).ToString('N2'))"
                '% Used'       = "$($b.PctUsed)%"
                'Forecast'     = "$sym$(([double]$b.Forecast).ToString('N2'))"
                '% Forecast'   = "$($b.PctForecast)%"
                'Risk'         = $b.Risk
                'Tag Filter'   = if ($b.TagFilter) { $b.TagFilter } else { '' }
                'Time Grain'   = $b.TimeGrain
                'Thresholds'   = $b.Thresholds
                'Contacts'     = if ($b.ContactEmails) { $b.ContactEmails } else { '' }
            })
        }
        $script:BudgetDetailGrid.ItemsSource = @($rows | Sort-Object { [double]($_.'% Used' -replace '[^0-9.]','') } -Descending)
    } else {
        if ($selectedName -eq 'All Subscriptions') {
            $script:BudgetSubSummary.Text = "No budgets configured on any subscription. Use the section below to deploy one."
        } else {
            $script:BudgetSubSummary.Text = "No budget configured on '$selectedName'. Use the section below to deploy one."
        }
        $script:BudgetDetailGrid.ItemsSource = @()
    }
}

function Deploy-BudgetFromTab {
    $d = $script:scanData
    $scope = $script:BudgetDeployScopeSelector.SelectedItem.Content
    $scopeSubId = $script:BudgetDeployScopeSelector.SelectedItem.Tag
    $budgetName = $script:BudgetDeployNameInput.Text.Trim()
    $amountText = $script:BudgetDeployAmountInput.Text.Trim()
    $timeGrain = $script:BudgetDeployGrainSelector.SelectedItem.Content
    $emails = $script:BudgetDeployEmailInput.Text.Trim()

    # Get selected action group
    $actionGroupId = ''
    if ($script:BudgetActionGroupSelector.SelectedItem -and $script:BudgetActionGroupSelector.SelectedItem.Tag) {
        $actionGroupId = $script:BudgetActionGroupSelector.SelectedItem.Tag
    }

    if (-not $budgetName) {
        $script:BudgetDeployStatus.Foreground = '#D83B01'
        $script:BudgetDeployStatus.Text = 'Budget name is required.'
        return
    }
    if (-not $amountText -or -not [double]::TryParse($amountText, [ref]$null)) {
        $script:BudgetDeployStatus.Foreground = '#D83B01'
        $script:BudgetDeployStatus.Text = 'Amount must be a valid number.'
        return
    }
    $amount = [int][double]$amountText

    # Collect user-defined thresholds (up to 4)
    $thresholds = @()
    $thresholdControls = @(
        @{ Value = $script:BudgetThreshold1; Type = $script:BudgetThreshold1Type },
        @{ Value = $script:BudgetThreshold2; Type = $script:BudgetThreshold2Type },
        @{ Value = $script:BudgetThreshold3; Type = $script:BudgetThreshold3Type },
        @{ Value = $script:BudgetThreshold4; Type = $script:BudgetThreshold4Type }
    )
    foreach ($tc in $thresholdControls) {
        $val = $tc.Value.Text.Trim()
        if ($val -and [double]::TryParse($val, [ref]$null)) {
            $pct = [double]$val
            $thresholdType = if ($tc.Type.SelectedItem) { $tc.Type.SelectedItem.Content } else { 'Actual' }
            $thresholds += @{ Threshold = $pct; ThresholdType = $thresholdType }
        }
    }

    if ($thresholds.Count -eq 0) {
        $script:BudgetDeployStatus.Foreground = '#D83B01'
        $script:BudgetDeployStatus.Text = 'At least one threshold is required.'
        return
    }

    $startDate = (Get-Date -Day 1).ToString('yyyy-MM-01')
    $endDate = (Get-Date -Day 1).AddYears(1).ToString('yyyy-MM-01')

    $contactEmails = @()
    if ($emails) { $contactEmails = @($emails -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    $contactRoles = @('Owner', 'Contributor')

    # Build notifications from user thresholds
    $notifications = @{}
    for ($i = 0; $i -lt $thresholds.Count; $i++) {
        $t = $thresholds[$i]
        $notif = @{
            enabled       = $true
            operator      = 'GreaterThan'
            threshold     = $t.Threshold
            thresholdType = $t.ThresholdType
            contactEmails = $contactEmails
            contactRoles  = $contactRoles
        }
        if ($actionGroupId) {
            $notif['contactGroups'] = @($actionGroupId)
        }
        $notifications["NotificationForExceededBudget$($i + 1)"] = $notif
    }

    # Get tag filter values
    $tagFilterName  = ''
    $tagFilterValue = ''
    if ($script:BudgetDeployTagNameSelector.SelectedItem -and $script:BudgetDeployTagNameSelector.SelectedItem.Tag) {
        $tagFilterName = $script:BudgetDeployTagNameSelector.SelectedItem.Tag
        $tagFilterValue = $script:BudgetDeployTagValueInput.Text.Trim()
        if ($tagFilterName -and -not $tagFilterValue) {
            $script:BudgetDeployStatus.Foreground = '#D83B01'
            $script:BudgetDeployStatus.Text = 'Tag value is required when a tag name is selected.'
            return
        }
    }

    $script:BudgetDeployButton.IsEnabled = $false
    $tagNote = if ($tagFilterName -and $tagFilterValue) { " (filtered by $tagFilterName=$tagFilterValue)" } else { '' }
    $script:BudgetDeployStatus.Foreground = '#0078D4'
    $script:BudgetDeployStatus.Text = "Deploying budget '$budgetName'$tagNote..."

    # Force UI update
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
        [action]{}, [System.Windows.Threading.DispatcherPriority]::Background
    )

    $successCount = 0
    $failCount = 0
    $targetSubs = @()

    if ($scope -eq 'All Subscriptions') {
        $targetSubs = $d.Auth.Subscriptions
    } else {
        # Specific subscription selected
        $targetSubs = @($d.Auth.Subscriptions | Where-Object { $_.Id -eq $scopeSubId })
        if ($targetSubs.Count -eq 0) {
            $targetSubs = @($d.Auth.Subscriptions | Where-Object { $_.Name -eq $scope })
        }
    }

    foreach ($sub in $targetSubs) {
        try {
            $budgetProps = @{
                category      = 'Cost'
                amount        = $amount
                timeGrain     = $timeGrain
                timePeriod    = @{ startDate = $startDate; endDate = $endDate }
                notifications = $notifications
            }

            # Add tag filter if specified
            if ($tagFilterName -and $tagFilterValue) {
                $budgetProps.filter = @{
                    tags = @{
                        $tagFilterName = @{
                            name     = $tagFilterName
                            operator = 'In'
                            values   = @($tagFilterValue)
                        }
                    }
                }
            }

            $budgetBody = @{ properties = $budgetProps } | ConvertTo-Json -Depth 10

            $budgetPath = "/subscriptions/$($sub.Id)/providers/Microsoft.Consumption/budgets/$($budgetName)?api-version=2023-05-01"
            $resp = Invoke-AzRestMethodWithRetry -Path $budgetPath -Method PUT -Payload $budgetBody

            if ($resp.StatusCode -in @(200, 201)) {
                $successCount++
            } else {
                $failCount++
                Write-Warning "Budget deploy failed on $($sub.Name): $($resp.StatusCode) $($resp.Content)"
            }
        } catch {
            $failCount++
            Write-Warning "Budget deploy error on $($sub.Name): $($_.Exception.Message)"
        }
    }

    $script:BudgetDeployButton.IsEnabled = $true
    if ($failCount -eq 0) {
        $script:BudgetDeployStatus.Foreground = '#107C10'
        $script:BudgetDeployStatus.Text = "Successfully deployed budget '$budgetName' to $successCount subscription(s) with $($thresholds.Count) threshold(s).$tagNote"
    } else {
        $script:BudgetDeployStatus.Foreground = '#D83B01'
        $script:BudgetDeployStatus.Text = "Deployed to $successCount sub(s), $failCount failed. Check console for details."
    }
}

function Deploy-BudgetPolicyFromTab {
    $d = $script:scanData
    $effect = if ($script:BudgetPolicyEffectSelector.SelectedItem) { $script:BudgetPolicyEffectSelector.SelectedItem.Content } else { 'AuditIfNotExists' }
    $selectedIdx = $script:BudgetPolicyScopeSelector.SelectedIndex

    if ($selectedIdx -lt 0 -or $selectedIdx -ge $d.Auth.Subscriptions.Count) {
        $script:BudgetPolicyStatus.Foreground = '#D83B01'
        $script:BudgetPolicyStatus.Text = 'Please select a scope.'
        return
    }

    $sub = $d.Auth.Subscriptions[$selectedIdx]
    $scope = "/subscriptions/$($sub.Id)"

    # Built-in policy: "Budgets should be configured on subscriptions"
    $policyDefId = '/providers/Microsoft.Authorization/policyDefinitions/b60f1662-afbe-4583-8543-26c9e20fa0ca'

    $script:BudgetPolicyDeployButton.IsEnabled = $false
    $script:BudgetPolicyStatus.Foreground = '#0078D4'
    $script:BudgetPolicyStatus.Text = "Deploying budget policy ($effect)..."

    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
        [System.Windows.Threading.DispatcherPriority]::Render, [action]{})

    try {
        $result = Deploy-PolicyAssignment -Scope $scope -PolicyDefinitionId $policyDefId `
            -Effect $effect -DisplayName "Budget Policy ($effect)"
        if ($result.Success) {
            $script:BudgetPolicyStatus.Foreground = '#107C10'
            $script:BudgetPolicyStatus.Text = "Budget policy deployed ($effect) to $($sub.Name)."
        } else {
            $script:BudgetPolicyStatus.Foreground = '#D83B01'
            $script:BudgetPolicyStatus.Text = "Failed: $($result.Message)"
        }
    } catch {
        $script:BudgetPolicyStatus.Foreground = '#D83B01'
        $script:BudgetPolicyStatus.Text = "Error: $($_.Exception.Message)"
    }
    $script:BudgetPolicyDeployButton.IsEnabled = $true
}

function Start-PolicyRemediation {
    param(
        [Parameter(Mandatory)][string]$Scope,
        [Parameter(Mandatory)][string]$PolicyAssignmentId
    )

    Write-Host "  Creating remediation task for assignment: $PolicyAssignmentId" -ForegroundColor Cyan

    $remediationName = "remediate-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $body = @{
        properties = @{
            policyAssignmentId = $PolicyAssignmentId
        }
    } | ConvertTo-Json -Depth 5

    $remediationPath = "$Scope/providers/Microsoft.PolicyInsights/remediations/$($remediationName)?api-version=2021-10-01"

    try {
        $resp = Invoke-AzRestMethodWithRetry -Path $remediationPath -Method PUT -Payload $body
        if ($resp.StatusCode -in @(200, 201)) {
            Write-Host "    Remediation task '$remediationName' created." -ForegroundColor Green
            return [PSCustomObject]@{ Success = $true; Message = "Remediation task '$remediationName' created. Check Policy > Remediation in the portal for progress."; Name = $remediationName }
        } else {
            $errBody = ($resp.Content | ConvertFrom-Json -ErrorAction SilentlyContinue)
            $errMsg = if ($errBody.error) { $errBody.error.message } else { "HTTP $($resp.StatusCode)" }
            return [PSCustomObject]@{ Success = $false; Message = $errMsg }
        }
    } catch {
        return [PSCustomObject]@{ Success = $false; Message = $_.Exception.Message }
    }
}

#-----------------------------------------------------------------------
# SUBSCRIPTION SCORECARD
#-----------------------------------------------------------------------
function Populate-Scorecard {
    $d = $script:scanData
    if (-not $d.Auth -or -not $d.Auth.Subscriptions) { return }

    $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($sub in $d.Auth.Subscriptions) {
        # Cost info
        $costActual = 0; $costForecast = 0; $currency = 'USD'
        if ($d.Costs -and $d.Costs.ContainsKey($sub.Id)) {
            $c = $d.Costs[$sub.Id]
            $costActual = $c.Actual
            $costForecast = $c.Forecast
            $currency = $c.Currency
        }
        $sym = Get-CurrencySymbol $currency

        # Tag compliance
        $tagScore = 'N/A'
        if ($d.Tags -and $d.Tags.PerSubscription -and $d.Tags.PerSubscription.ContainsKey($sub.Id)) {
            $tagScore = "$($d.Tags.PerSubscription[$sub.Id].Coverage)%"
        } elseif ($d.Tags) {
            $tagScore = "$($d.Tags.TagCoverage)%"
        }

        # Optimization count
        $optCount = 0
        if ($d.Optimization -and $d.Optimization.Recommendations) {
            $optCount += @($d.Optimization.Recommendations | Where-Object { $_.SubscriptionId -eq $sub.Id }).Count
        }

        # Orphan count
        $orphanCount = 0
        $orphanSavings = 0.0
        if ($d.Orphans -and $d.Orphans.Orphans) {
            $subOrphans = @($d.Orphans.Orphans | Where-Object { $_.SubscriptionId -eq $sub.Id })
            $orphanCount = $subOrphans.Count
            # Estimate monthly savings per orphan category (conservative Azure pricing)
            foreach ($o in $subOrphans) {
                $orphanSavings += switch ($o.Category) {
                    'Orphaned Disk'          {
                        # Estimate based on disk size from Detail field
                        $diskGb = 0
                        if ($o.Detail -match '(\d+)\s*GB') { $diskGb = [int]$Matches[1] }
                        if ($o.Detail -match 'Premium')    { $diskGb * 0.12 }    # ~$0.12/GB/mo Premium SSD
                        elseif ($o.Detail -match 'Standard_SSD') { $diskGb * 0.075 }
                        else { $diskGb * 0.04 }                                   # Standard HDD
                    }
                    'Unattached Public IP'   { 3.65 }    # ~$0.005/hr static IP
                    'Unattached NIC'         { 0 }       # NICs are free but clutter
                    'Deallocated VM'         { 15 }      # OS disk + IP costs while deallocated
                    'Empty App Service Plan' { 55 }      # Basic tier ~$55/mo
                    'Old Snapshot'           { 5 }       # ~$0.05/GB, typical 100GB
                    default                  { 5 }
                }
            }
        }

        # Budget risk
        $budgetRisk = 'No Budget'
        if ($d.Budgets -and $d.Budgets.Budgets) {
            $subBudgets = @($d.Budgets.Budgets | Where-Object { $_.SubscriptionId -eq $sub.Id })
            if ($subBudgets.Count -gt 0) {
                $worstRisk = ($subBudgets | Sort-Object PercentUsed -Descending | Select-Object -First 1).Risk
                $budgetRisk = $worstRisk
            }
        }

        # Cost trend direction
        $trendDir = '-'
        if ($d.CostTrend -and $d.CostTrend.HasData -and $d.CostTrend.Months.Count -ge 2) {
            $last = $d.CostTrend.Months[$d.CostTrend.Months.Count - 1].Cost
            $prev = $d.CostTrend.Months[$d.CostTrend.Months.Count - 2].Cost
            if ($prev -gt 0) {
                $pct = [math]::Round((($last - $prev) / $prev) * 100, 1)
                $trendDir = if ($pct -gt 5) { "Up $pct%" } elseif ($pct -lt -5) { "Down $([math]::Abs($pct))%" } else { 'Stable' }
            }
        }

        [void]$rows.Add([PSCustomObject]@{
            Subscription     = $sub.Name
            'Actual (MTD)'   = "$sym$($costActual.ToString('N2'))"
            'Forecast'       = "$sym$($costForecast.ToString('N2'))"
            'Tag Coverage'   = $tagScore
            'Optimizations'  = $optCount
            'Orphaned'       = $orphanCount
            'Orphan Savings' = if ($orphanSavings -gt 0) { "$sym$([math]::Round($orphanSavings, 2).ToString('N2'))/mo" } else { '-' }
            'Budget Status'  = $budgetRisk
            'Cost Trend'     = $trendDir
        })
    }

    $script:ScorecardGrid.ItemsSource = @($rows | Sort-Object { [double]($_.'Actual (MTD)' -replace '[^0-9.]','') } -Descending)
}

# -- Subscription Selector Dialog ----------------------------------------
# Shows a popup with checkboxes for each subscription. Returns only selected subs.
# Called after tenant connection so users can narrow the scan scope.
function Show-SubscriptionSelector {
    param(
        [Parameter(Mandatory)][object[]]$Subscriptions,
        [object[]]$SkippedSubs,
        [System.Windows.Window]$ParentWindow
    )

    $subCount = $Subscriptions.Count
    # For small tenants (≤5 subs), skip the selector — just scan everything
    if ($subCount -le 5) { return $Subscriptions }

    $dlgHeight = [math]::Min(560, 220 + ($subCount * 26))

    $dlgXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Select Subscriptions to Scan" Width="560" Height="$dlgHeight"
        WindowStartupLocation="CenterOwner" ResizeMode="CanResizeWithGrip" Background="#F3F3F3"
        MinHeight="300" MinWidth="400">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" FontSize="16" FontWeight="SemiBold" Foreground="#333" Margin="0,0,0,8">
            <Run Text="$subCount production subscriptions found"/>
        </TextBlock>
        <TextBlock Grid.Row="1" Text="Uncheck any subscriptions you want to exclude from the scan."
                   FontSize="12" Foreground="#666" Margin="0,0,0,12"/>

        <Border Grid.Row="2" BorderBrush="#DDD" BorderThickness="1" CornerRadius="4" Background="White">
            <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="6">
                <StackPanel Name="SubListPanel"/>
            </ScrollViewer>
        </Border>

        <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,10,0,8">
            <Button Name="SelectAllBtn" Content="Select All" Width="90" Height="28" Margin="0,0,8,0"
                    Background="White" BorderBrush="#CCC" Foreground="#333" FontSize="11.5" Cursor="Hand"/>
            <Button Name="SelectNoneBtn" Content="Select None" Width="90" Height="28"
                    Background="White" BorderBrush="#CCC" Foreground="#333" FontSize="11.5" Cursor="Hand"/>
            <TextBlock Name="CountLabel" Text="" FontSize="11.5" Foreground="#666"
                       VerticalAlignment="Center" Margin="16,0,0,0"/>
        </StackPanel>

        <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="CancelBtn" Content="Cancel" Width="90" Height="32" Margin="0,0,10,0"
                    Background="White" BorderBrush="#CCC" Foreground="#333" FontSize="12.5" Cursor="Hand"/>
            <Button Name="OkBtn" Content="Scan Selected" Width="120" Height="32"
                    Background="#0078D4" Foreground="White" BorderBrush="#0078D4" FontSize="12.5"
                    FontWeight="SemiBold" Cursor="Hand"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($dlgXaml))
    $dlgWin = [System.Windows.Markup.XamlReader]::Load($reader)
    if ($ParentWindow) { $dlgWin.Owner = $ParentWindow }

    $subListPanel = $dlgWin.FindName('SubListPanel')
    $selectAllBtn = $dlgWin.FindName('SelectAllBtn')
    $selectNoneBtn = $dlgWin.FindName('SelectNoneBtn')
    $countLabel   = $dlgWin.FindName('CountLabel')
    $cancelBtn    = $dlgWin.FindName('CancelBtn')
    $okBtn        = $dlgWin.FindName('OkBtn')

    # Build checkbox list
    $checkboxes = [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]::new()
    foreach ($sub in ($Subscriptions | Sort-Object Name)) {
        $cb = [System.Windows.Controls.CheckBox]::new()
        $cb.Content = "$($sub.Name)  ($($sub.Id))"
        $cb.IsChecked = $true
        $cb.Tag = $sub
        $cb.Margin = [System.Windows.Thickness]::new(4, 3, 4, 3)
        $cb.FontSize = 12
        [void]$checkboxes.Add($cb)
        [void]$subListPanel.Children.Add($cb)
    }

    # Update count label
    $updateCount = {
        $sel = ($checkboxes | Where-Object { $_.IsChecked }).Count
        $countLabel.Text = "$sel of $subCount selected"
        $okBtn.IsEnabled = ($sel -gt 0)
    }
    & $updateCount

    foreach ($cb in $checkboxes) {
        $cb.Add_Checked($updateCount)
        $cb.Add_Unchecked($updateCount)
    }

    # Select All / None
    $selectAllBtn.Add_Click({ foreach ($c in $checkboxes) { $c.IsChecked = $true } }.GetNewClosure())
    $selectNoneBtn.Add_Click({ foreach ($c in $checkboxes) { $c.IsChecked = $false } }.GetNewClosure())

    # OK / Cancel
    $script:_subSelectorResult = $null
    $okBtn.Add_Click({
        $script:_subSelectorResult = @($checkboxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
        $dlgWin.Close()
    }.GetNewClosure())
    $cancelBtn.Add_Click({ $dlgWin.Close() }.GetNewClosure())

    [void]$dlgWin.ShowDialog()

    # If user cancelled or closed, return all subs (don't block scan)
    if ($null -eq $script:_subSelectorResult) { return $Subscriptions }
    if ($script:_subSelectorResult.Count -eq 0) { return $Subscriptions }
    return $script:_subSelectorResult
}

# -- Export Format Chooser Dialog ----------------------------------------
function Show-ExportDialog {
    $d = $script:scanData
    if (-not $d -or -not $d.Auth) {
        [System.Windows.MessageBox]::Show('No scan data available. Run a scan first.', 'Export', 'OK', 'Warning')
        return
    }

    $dlgXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Export Scan Results" Width="520" Height="280" WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize" Background="#F3F3F3">
    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="Choose an export format" FontSize="17" FontWeight="SemiBold"
                   Foreground="#333" Margin="0,0,0,16"/>
        <UniformGrid Grid.Row="1" Columns="3" Margin="0">
            <Border Name="HtmlTile" Background="White" CornerRadius="6" Margin="0,0,8,0" Cursor="Hand"
                    BorderBrush="#DDD" BorderThickness="1">
                <Border.Effect><DropShadowEffect ShadowDepth="1" BlurRadius="4" Opacity="0.12"/></Border.Effect>
                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                    <TextBlock Text="&#x1F4C4;" FontSize="36" HorizontalAlignment="Center" Margin="0,0,0,8"/>
                    <TextBlock Text="HTML Report" FontSize="14" FontWeight="SemiBold" HorizontalAlignment="Center" Foreground="#333"/>
                    <TextBlock Text="Full formatted report" FontSize="10.5" Foreground="#888" HorizontalAlignment="Center" Margin="0,2,0,0"/>
                </StackPanel>
            </Border>
            <Border Name="CsvTile" Background="White" CornerRadius="6" Margin="4,0,4,0" Cursor="Hand"
                    BorderBrush="#DDD" BorderThickness="1">
                <Border.Effect><DropShadowEffect ShadowDepth="1" BlurRadius="4" Opacity="0.12"/></Border.Effect>
                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                    <TextBlock Text="&#x1F4CB;" FontSize="36" HorizontalAlignment="Center" Margin="0,0,0,8"/>
                    <TextBlock Text="CSV File" FontSize="14" FontWeight="SemiBold" HorizontalAlignment="Center" Foreground="#333"/>
                    <TextBlock Text="Subscription cost data" FontSize="10.5" Foreground="#888" HorizontalAlignment="Center" Margin="0,2,0,0"/>
                </StackPanel>
            </Border>
            <Border Name="PbiTile" Background="White" CornerRadius="6" Margin="8,0,0,0" Cursor="Hand"
                    BorderBrush="#DDD" BorderThickness="1">
                <Border.Effect><DropShadowEffect ShadowDepth="1" BlurRadius="4" Opacity="0.12"/></Border.Effect>
                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                    <TextBlock Text="&#x1F4CA;" FontSize="36" HorizontalAlignment="Center" Margin="0,0,0,8"/>
                    <TextBlock Text="Power BI" FontSize="14" FontWeight="SemiBold" HorizontalAlignment="Center" Foreground="#333"/>
                    <TextBlock Text="Template + data files" FontSize="10.5" Foreground="#888" HorizontalAlignment="Center" Margin="0,2,0,0"/>
                </StackPanel>
            </Border>
        </UniformGrid>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($dlgXaml))
    $exportWin = [System.Windows.Markup.XamlReader]::Load($reader)
    $exportWin.Owner = $script:window

    $htmlTile = $exportWin.FindName('HtmlTile')
    $csvTile  = $exportWin.FindName('CsvTile')
    $pbiTile  = $exportWin.FindName('PbiTile')

    # Hover effects
    $hoverIn  = { param($s,$e) $s.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#EBF5FF'); $s.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#0078D4') }
    $hoverOut = { param($s,$e) $s.Background = [System.Windows.Media.Brushes]::White; $s.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#DDD') }
    foreach ($tile in @($htmlTile, $csvTile, $pbiTile)) {
        $tile.Add_MouseEnter($hoverIn)
        $tile.Add_MouseLeave($hoverOut)
    }

    $htmlTile.Add_MouseLeftButtonDown({
        $exportWin.Tag = 'HTML'
        $exportWin.Close()
    }.GetNewClosure())

    $csvTile.Add_MouseLeftButtonDown({
        $exportWin.Tag = 'CSV'
        $exportWin.Close()
    }.GetNewClosure())

    $pbiTile.Add_MouseLeftButtonDown({
        $exportWin.Tag = 'PBI'
        $exportWin.Close()
    }.GetNewClosure())

    $exportWin.ShowDialog() | Out-Null

    switch ($exportWin.Tag) {
        'HTML' { Export-ScanReport -Format 'HTML' }
        'CSV'  { Export-ScanReport -Format 'CSV' }
        'PBI'  { Export-PowerBIData }
    }
}

# -- Power BI Export Function --------------------------------------------
function Export-PowerBIData {
    $d = $script:scanData
    if (-not $d -or -not $d.Auth) {
        [System.Windows.MessageBox]::Show('No scan data available. Run a scan first.', 'Export', 'OK', 'Warning')
        return
    }

    # Pick export folder via FolderBrowserDialog
    Add-Type -AssemblyName System.Windows.Forms
    $fbd = [System.Windows.Forms.FolderBrowserDialog]::new()
    $fbd.Description = 'Select folder for Power BI export'
    $fbd.ShowNewFolderButton = $true
    if ($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    $stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $exportDir = Join-Path $fbd.SelectedPath "FinOps-PowerBI-$stamp"
    New-Item -Path $exportDir -ItemType Directory -Force | Out-Null

    $fileCount = 0

    # Helper: safe CSV export
    $writeCsv = {
        param([string]$Name, [object[]]$Rows)
        if ($Rows -and $Rows.Count -gt 0) {
            $Rows | Export-Csv -Path (Join-Path $exportDir "$Name.csv") -NoTypeInformation -Encoding UTF8
            $script:fileCount++
        }
    }

    # 1. Subscription Costs
    $subRows = @()
    foreach ($sub in $d.Auth.Subscriptions) {
        $c = if ($d.Costs -and $d.Costs.ContainsKey($sub.Id)) { $d.Costs[$sub.Id] } else { @{ Actual = 0; Forecast = 0; Currency = 'USD' } }
        $subRows += [PSCustomObject]@{
            Subscription   = $sub.Name
            SubscriptionId = $sub.Id
            ActualMTD      = [math]::Round($c.Actual, 2)
            Forecast       = [math]::Round($c.Forecast, 2)
            Currency       = $c.Currency
        }
    }
    & $writeCsv 'SubscriptionCosts' $subRows

    # 2. Resource Costs
    if ($d.ResourceCosts -and $d.ResourceCosts.Count -gt 0) {
        $rcRows = $d.ResourceCosts | ForEach-Object {
            [PSCustomObject]@{
                Subscription  = $_.Subscription
                ResourceGroup = $_.ResourceGroup
                ResourceType  = $_.ResourceType
                ResourcePath  = $_.ResourcePath
                ActualMTD     = [math]::Round($_.Actual, 2)
                Forecast      = [math]::Round($_.Forecast, 2)
                Currency      = $_.Currency
            }
        }
        & $writeCsv 'ResourceCosts' $rcRows
    }

    # 3. Tag Inventory
    if ($d.Tags -and $d.Tags.TagNames) {
        $tagRows = @()
        foreach ($tn in $d.Tags.TagNames.Keys) {
            $info = $d.Tags.TagNames[$tn]
            foreach ($v in $info.Values) {
                $tagRows += [PSCustomObject]@{
                    TagName       = $tn
                    TagValue      = $v.Value
                    ResourceCount = $v.ResourceCount
                }
            }
        }
        & $writeCsv 'TagInventory' $tagRows
    }

    # 4. Tag Recommendations
    if ($d.TagRecs -and $d.TagRecs.Analysis) {
        $trRows = $d.TagRecs.Analysis | ForEach-Object {
            [PSCustomObject]@{
                TagName  = $_.TagName
                Status   = $_.Status
                Priority = $_.Priority
                Pillar   = $_.Pillar
                Purpose  = $_.Purpose
            }
        }
        & $writeCsv 'TagRecommendations' $trRows
    }

    # 5. Policy Inventory
    if ($d.PolicyInv -and $d.PolicyInv.Assignments) {
        $piRows = $d.PolicyInv.Assignments | ForEach-Object {
            [PSCustomObject]@{
                AssignmentName  = $_.AssignmentName
                PolicyDefId     = $_.PolicyDefId
                Scope           = $_.Scope
                Effect          = $_.Effect
                EnforcementMode = $_.EnforcementMode
                Origin          = $_.Origin
                Subscription    = $_.Subscription
            }
        }
        & $writeCsv 'PolicyInventory' $piRows
    }

    # 6. Policy Recommendations
    if ($d.PolicyRecs -and $d.PolicyRecs.Analysis) {
        $prRows = $d.PolicyRecs.Analysis | ForEach-Object {
            [PSCustomObject]@{
                DisplayName   = $_.DisplayName
                Category      = $_.Category
                Pillar        = $_.Pillar
                Priority      = $_.Priority
                DefaultEffect = $_.DefaultEffect
                Purpose       = $_.Purpose
                Status        = if ($_.PolicyDefId -in ($d.PolicyInv.Assignments.PolicyDefId)) { 'Assigned' } else { 'Missing' }
            }
        }
        & $writeCsv 'PolicyRecommendations' $prRows
    }

    # 7. Budgets
    if ($d.Budgets -and $d.Budgets.Budgets) {
        $bRows = $d.Budgets.Budgets | ForEach-Object {
            [PSCustomObject]@{
                Subscription   = $_.Subscription
                SubscriptionId = $_.SubscriptionId
                BudgetName     = $_.BudgetName
                Amount         = $_.Amount
                TimeGrain      = $_.TimeGrain
                ActualSpend    = [math]::Round($_.ActualSpend, 2)
                Forecast       = [math]::Round($_.Forecast, 2)
                PercentUsed    = [math]::Round($_.PctUsed, 1)
                Risk           = $_.Risk
                Currency       = $_.Currency
            }
        }
        & $writeCsv 'Budgets' $bRows
    }

    # 8. Orphaned Resources
    if ($d.Orphans -and $d.Orphans.Orphans) {
        $oRows = $d.Orphans.Orphans | ForEach-Object {
            [PSCustomObject]@{
                Category       = $_.Category
                ResourceName   = $_.ResourceName
                ResourceGroup  = $_.ResourceGroup
                SubscriptionId = $_.SubscriptionId
                Location       = $_.Location
                Detail         = $_.Detail
                Impact         = $_.Impact
            }
        }
        & $writeCsv 'OrphanedResources' $oRows
    }

    # 9. Cost by Tag
    if ($d.CostByTag -and $d.CostByTag.CostByTag) {
        $ctRows = @()
        foreach ($tagKey in $d.CostByTag.CostByTag.Keys) {
            foreach ($entry in $d.CostByTag.CostByTag[$tagKey]) {
                $ctRows += [PSCustomObject]@{
                    TagName  = $tagKey
                    TagValue = $entry.TagValue
                    Cost     = [math]::Round($entry.Cost, 2)
                    Currency = $entry.Currency
                }
            }
        }
        & $writeCsv 'CostByTag' $ctRows
    }

    # 10. Cost Trend
    if ($d.CostTrend -and $d.CostTrend.HasData -and $d.CostTrend.Months) {
        $tRows = $d.CostTrend.Months | ForEach-Object {
            [PSCustomObject]@{
                Month    = $_.Month
                Cost     = [math]::Round($_.Cost, 2)
                Currency = $_.Currency
            }
        }
        & $writeCsv 'CostTrend' $tRows
    }

    # 11. Commitment Utilization
    if ($d.Commitments -and $d.Commitments.HasData) {
        $cmRows = @()
        if ($d.Commitments.Reservations) {
            $cmRows += $d.Commitments.Reservations | ForEach-Object {
                [PSCustomObject]@{
                    Type           = 'Reservation'
                    Id             = $_.ReservationId
                    SkuName        = $_.SkuName
                    AvgUtilization = [math]::Round($_.AvgUtilization, 1)
                    MinUtilization = [math]::Round($_.MinUtilization, 1)
                    MaxUtilization = [math]::Round($_.MaxUtilization, 1)
                    ReservedHours  = $_.ReservedHours
                    UsedHours      = $_.UsedHours
                }
            }
        }
        if ($d.Commitments.SavingsPlans) {
            $cmRows += $d.Commitments.SavingsPlans | ForEach-Object {
                [PSCustomObject]@{
                    Type           = 'SavingsPlan'
                    Id             = $_.BenefitId
                    SkuName        = ''
                    AvgUtilization = [math]::Round($_.AvgUtilization, 1)
                    MinUtilization = 0
                    MaxUtilization = 0
                    ReservedHours  = 0
                    UsedHours      = 0
                }
            }
        }
        & $writeCsv 'CommitmentUtilization' $cmRows
    }

    # 12. AHB Opportunities
    if ($d.AHB -and $d.AHB.TotalOpportunities -gt 0) {
        $ahbRows = @()
        foreach ($prop in @('WindowsVMs','SQLVMs','SQLDatabases')) {
            if ($d.AHB.$prop) {
                $ahbRows += $d.AHB.$prop | ForEach-Object {
                    [PSCustomObject]@{
                        Category       = $prop
                        ResourceName   = $_.name
                        ResourceGroup  = $_.resourceGroup
                        SubscriptionId = $_.subscriptionId
                        Location       = $_.location
                    }
                }
            }
        }
        & $writeCsv 'AHBOpportunities' $ahbRows
    }

    # 13. Optimization / Advisor Recommendations
    if ($d.Optimization -and $d.Optimization.Recommendations) {
        $optRows = $d.Optimization.Recommendations | ForEach-Object {
            [PSCustomObject]@{
                Subscription  = $_.Subscription
                Category      = $_.Category
                Impact        = $_.Impact
                Problem       = $_.Problem
                Solution      = $_.Solution
                ResourceType  = $_.ResourceType
                ResourceName  = $_.ResourceName
                AnnualSavings = if ($_.AnnualSavings) { [math]::Round($_.AnnualSavings, 2) } else { '' }
                Currency      = $_.Currency
            }
        }
        & $writeCsv 'OptimizationAdvice' $optRows
    }

    # 14. Reservation Recommendations
    if ($d.Reservations) {
        $resRows = @()
        if ($d.Reservations.AdvisorRecommendations) {
            $resRows += $d.Reservations.AdvisorRecommendations | ForEach-Object {
                [PSCustomObject]@{
                    Source        = 'Advisor'
                    Subscription  = $_.Subscription
                    ResourceType  = $_.ResourceType
                    Impact        = $_.Impact
                    Problem       = $_.Problem
                    AnnualSavings = if ($_.AnnualSavings) { [math]::Round($_.AnnualSavings, 2) } else { '' }
                    Term          = $_.Term
                    Currency      = $_.Currency
                }
            }
        }
        if ($d.Reservations.ReservationRecommendations) {
            $resRows += $d.Reservations.ReservationRecommendations | ForEach-Object {
                [PSCustomObject]@{
                    Source        = 'ReservationAPI'
                    Subscription  = ''
                    ResourceType  = $_.ResourceType
                    Impact        = ''
                    Problem       = "Buy $($_.RecommendedQty)x $($_.SKU) ($($_.Term))"
                    AnnualSavings = if ($_.NetSavings) { [math]::Round($_.NetSavings, 2) } else { '' }
                    Term          = $_.Term
                    Currency      = ''
                }
            }
        }
        & $writeCsv 'ReservationAdvice' $resRows
    }

    # 15. Savings Realized
    if ($d.Savings -and $d.Savings.HasData -and $d.Savings.Details) {
        $sRows = $d.Savings.Details | ForEach-Object {
            [PSCustomObject]@{
                Subscription = $_.Subscription
                Category     = $_.Category
                Amount       = [math]::Round($_.Amount, 2)
                Type         = $_.Type
            }
        }
        & $writeCsv 'SavingsRealized' $sRows
    }

    # 16. Scorecard (pre-computed)
    if ($script:ScorecardGrid.ItemsSource) {
        & $writeCsv 'Scorecard' @($script:ScorecardGrid.ItemsSource)
    }

    # ================================================================
    # Generate Power BI Template (.pbit)
    # ================================================================
    Add-Type -AssemblyName System.IO.Compression

    $csvFiles = Get-ChildItem -Path $exportDir -Filter '*.csv'
    $numericCols = @('ActualMTD','Forecast','Cost','Amount','ActualSpend','PercentUsed','AnnualSavings','AvgUtilization','MinUtilization','MaxUtilization','ReservedHours','UsedHours','ResourceCount')
    $exportDirEscaped = $exportDir -replace '\\', '\\\\'

    # Build DataModelSchema JSON manually to avoid ConvertTo-Json issues
    $sb = [System.Text.StringBuilder]::new(8192)
    [void]$sb.Append('{"name":"Model","compatibilityLevel":1550,"model":{"culture":"en-US","dataAccessOptions":{"legacyRedirects":true,"returnErrorValuesAsNull":true},"defaultPowerBIDataSourceVersion":"powerBI_V3","sourceQueryCulture":"en-US","tables":[')

    # CsvFolderPath parameter table
    $paramGuid = [guid]::NewGuid().ToString()
    $paramColGuid = [guid]::NewGuid().ToString()
    [void]$sb.Append('{"name":"CsvFolderPath","lineageTag":"' + $paramGuid + '","columns":[{"name":"CsvFolderPath","dataType":"string","isHidden":true,"sourceColumn":"CsvFolderPath","lineageTag":"' + $paramColGuid + '"}],"partitions":[{"name":"CsvFolderPath","mode":"import","source":{"type":"m","expression":["\"' + $exportDirEscaped + '\" meta [IsParameterQuery=true, Type=\"Text\", IsParameterQueryRequired=true]"]}}],"annotations":[{"name":"PBI_ResultType","value":"Text"},{"name":"PBI_NavigationStepName","value":"Navigation"}]}')

    # Data tables from CSVs
    foreach ($csv in $csvFiles) {
        $tblName = [System.IO.Path]::GetFileNameWithoutExtension($csv.Name)
        $headerLine = Get-Content $csv.FullName -First 1
        $headers = ($headerLine -replace '"','') -split ','
        $tblGuid = [guid]::NewGuid().ToString()

        [void]$sb.Append(',{"name":"' + $tblName + '","lineageTag":"' + $tblGuid + '","columns":[')
        $colFragments = @()
        $typeCasts = @()
        foreach ($h in $headers) {
            $cGuid = [guid]::NewGuid().ToString()
            $isNum = $h -in $numericCols
            $dt = if ($isNum) { 'double' } else { 'string' }
            $sum = if ($isNum) { 'sum' } else { 'none' }
            $colFragments += '{"name":"' + $h + '","dataType":"' + $dt + '","sourceColumn":"' + $h + '","summarizeBy":"' + $sum + '","lineageTag":"' + $cGuid + '"}'
            if ($isNum) { $typeCasts += '{\"' + $h + '\", type number}' }
        }
        [void]$sb.Append($colFragments -join ',')
        [void]$sb.Append('],')

        # Partition with M expression
        $mExpr = @()
        $mExpr += '"let"'
        if ($typeCasts.Count -gt 0) {
            $mExpr += '"    Source = Csv.Document(File.Contents(CsvFolderPath & \"\\\\' + $tblName + '.csv\"), [Delimiter=\",\", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),"'
            $mExpr += '"    Headers = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),"'
            $castStr = $typeCasts -join ', '
            $mExpr += '"    Typed = Table.TransformColumnTypes(Headers, {' + $castStr + '})"'
            $mExpr += '"in"'
            $mExpr += '"    Typed"'
        } else {
            $mExpr += '"    Source = Csv.Document(File.Contents(CsvFolderPath & \"\\\\' + $tblName + '.csv\"), [Delimiter=\",\", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),"'
            $mExpr += '"    Headers = Table.PromoteHeaders(Source, [PromoteAllScalars=true])"'
            $mExpr += '"in"'
            $mExpr += '"    Headers"'
        }

        [void]$sb.Append('"partitions":[{"name":"' + $tblName + '","mode":"import","source":{"type":"m","expression":[' + ($mExpr -join ',') + ']}}]}')
    }

    [void]$sb.Append('],') # end tables

    # Relationships
    $tblNames = @('CsvFolderPath') + @($csvFiles | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) })
    $relFragments = @()
    $subIdTables = @('Budgets','OrphanedResources','AHBOpportunities')
    foreach ($ft in $subIdTables) {
        if ($ft -in $tblNames -and 'SubscriptionCosts' -in $tblNames) {
            $rGuid = [guid]::NewGuid().ToString()
            $relFragments += '{"name":"' + $rGuid + '","fromTable":"' + $ft + '","fromColumn":"SubscriptionId","toTable":"SubscriptionCosts","toColumn":"SubscriptionId"}'
        }
    }
    [void]$sb.Append('"relationships":[' + ($relFragments -join ',') + '],')
    [void]$sb.Append('"annotations":[{"name":"PBI_QueryGroup","value":"{}"},{"name":"PBIDesktopVersion","value":"2.138.0.0"}]}}')

    $modelJson = $sb.ToString()

    # Clone skeleton .pbit and inject our DataModelSchema
    $rootDir = $script:ScriptRootDir
    if (-not $rootDir) { $rootDir = $PSScriptRoot }
    if (-not $rootDir) { $rootDir = Split-Path -Parent $MyInvocation.ScriptName }
    if (-not $rootDir) { $rootDir = Split-Path -Parent (Get-Item $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue).FullName }
    $skelPath = Join-Path (Join-Path $rootDir 'gui') 'skeleton.pbit'
    if (-not (Test-Path $skelPath)) {
        [System.Windows.MessageBox]::Show("skeleton.pbit not found at:`n$skelPath`n`nScriptRootDir=$($script:ScriptRootDir)`nPSScriptRoot=$PSScriptRoot", 'Power BI Export Error', 'OK', 'Error')
        return
    }
    $pbitPath = Join-Path $exportDir 'FinOps-Report.pbit'
    Copy-Item $skelPath $pbitPath -Force
    if ((Get-Item $pbitPath).Length -lt 1000) {
        [System.Windows.MessageBox]::Show("skeleton.pbit copy failed — file too small.`nSource: $skelPath`nDest: $pbitPath", 'Power BI Export Error', 'OK', 'Error')
        return
    }

    $unicodeNoBom = [System.Text.UnicodeEncoding]::new($false, $false)
    $zip = [System.IO.Compression.ZipFile]::Open($pbitPath, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $dmEntry = $zip.Entries | Where-Object { $_.FullName -eq 'DataModelSchema' }
        if (-not $dmEntry) { throw 'DataModelSchema entry not found in skeleton' }
        $dmName = $dmEntry.FullName
        $dmEntry.Delete()
        $newDm = $zip.CreateEntry($dmName)
        $sw = [System.IO.StreamWriter]::new($newDm.Open(), $unicodeNoBom)
        $sw.Write($modelJson)
        $sw.Close()
    } finally {
        $zip.Dispose()
    }

    $csvCount = $csvFiles.Count
    Update-UIStatus "Power BI export: $csvCount CSVs + template saved to $exportDir" $script:ProgressBar.Value
    [System.Windows.MessageBox]::Show("Exported $csvCount CSVs + Power BI template to:`n$exportDir`n`nOpen FinOps-Report.pbit in Power BI Desktop.`nThe CsvFolderPath parameter is pre-set to this folder.", 'Power BI Export', 'OK', 'Information')
}

# -- Export Function ----------------------------------------------------
function Export-ScanReport {
    param([string]$Format)
    $d = $script:scanData

    if ($Format -eq 'CSV') {
        $dlg = [Microsoft.Win32.SaveFileDialog]::new()
        $dlg.Filter = "CSV File (*.csv)|*.csv"
        $dlg.FileName = "FinOps-Report-$(Get-Date -Format 'yyyy-MM-dd')"
        if ($dlg.ShowDialog() -ne $true) { return }
        $path = $dlg.FileName
    } elseif ($Format -eq 'HTML') {
        $dlg = [Microsoft.Win32.SaveFileDialog]::new()
        $dlg.Filter = "HTML Report (*.html)|*.html"
        $dlg.FileName = "FinOps-Report-$(Get-Date -Format 'yyyy-MM-dd')"
        if ($dlg.ShowDialog() -ne $true) { return }
        $path = $dlg.FileName
    } else {
        # Legacy fallback — combined dialog
        $dlg = [Microsoft.Win32.SaveFileDialog]::new()
        $dlg.Filter = "HTML Report (*.html)|*.html|CSV File (*.csv)|*.csv"
        $dlg.FileName = "FinOps-Report-$(Get-Date -Format 'yyyy-MM-dd')"
        $dlg.FilterIndex = 1
        if ($dlg.ShowDialog() -ne $true) { return }
        $path = $dlg.FileName
    }
    $path = $dlg.FileName

    if ($path -match '\.csv$') {
        # CSV - subscription costs
        $rows = @()
        foreach ($sub in $d.Auth.Subscriptions) {
            $c = if ($d.Costs -and $d.Costs.ContainsKey($sub.Id)) { $d.Costs[$sub.Id] } else { @{ Actual = 0; Forecast = 0; Currency = 'USD' } }
            $rows += [PSCustomObject]@{
                Subscription = $sub.Name
                SubscriptionId = $sub.Id
                ActualMTD = $c.Actual
                Forecast = $c.Forecast
                Currency = $c.Currency
            }
        }
        $rows | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Update-UIStatus "CSV exported to $path" $script:ProgressBar.Value
        return
    }

    # ================================================================
    # HTML REPORT - Professional FinOps Assessment
    # ================================================================
    $esc = [System.Security.SecurityElement]

    # Currency helper
    $sym = '$'
    if ($d.ResourceCosts -and $d.ResourceCosts.Count -gt 0) {
        $sym = Get-CurrencySymbol -Code $d.ResourceCosts[0].Currency
    }

    # Use pre-computed maturity score from Populate-GuidanceTab
    $rptScore = if ($d.MaturityScore) { $d.MaturityScore } else { 0 }
    $rptBreakdown = if ($d.MaturityBreakdown) { $d.MaturityBreakdown } else { @{} }
    $gradeLabel = if ($d.MaturityGrade) { $d.MaturityGrade } else { 'Getting Started' }
    $gradeColor = if ($d.MaturityGradeColor) { $d.MaturityGradeColor } else { '#E81123' }

    # Total spend
    $totalActual = 0.0; $totalForecast = 0.0
    if ($d.Costs) { foreach ($k in $d.Costs.Keys) { $totalActual += $d.Costs[$k].Actual; $totalForecast += $d.Costs[$k].Forecast } }

    # Build HTML
    $sb = [System.Text.StringBuilder]::new(32768)
    [void]$sb.Append(@"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<title>Azure FinOps Assessment Report</title>
<style>
@media print { @page { margin: 0.5in; size: letter; } .no-print { display: none; } .page-break { page-break-before: always; } }
* { box-sizing: border-box; }
body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px 40px; color: #333; line-height: 1.5; background: #fff; }
.header { background: linear-gradient(135deg, #0078D4, #005A9E); color: #fff; padding: 30px 40px; margin: -20px -40px 30px -40px; }
.header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 600; }
.header p { margin: 0; opacity: 0.9; font-size: 13px; }
.header .subtitle { font-size: 14px; margin-top: 4px; opacity: 0.85; }
h2 { color: #0078D4; font-size: 20px; border-bottom: 2px solid #0078D4; padding-bottom: 6px; margin-top: 35px; }
h3 { color: #333; font-size: 16px; margin-top: 20px; }
table { border-collapse: collapse; width: 100%; margin: 12px 0 20px 0; font-size: 12px; }
th { background: #0078D4; color: #fff; padding: 8px 10px; text-align: left; font-weight: 600; font-size: 11px; text-transform: uppercase; letter-spacing: 0.3px; }
td { padding: 7px 10px; border-bottom: 1px solid #e8e8e8; }
tr:nth-child(even) { background: #f9f9f9; }
tr:hover { background: #EBF5FF; }
.cards { display: flex; flex-wrap: wrap; gap: 12px; margin: 15px 0; }
.card { background: #fff; border: 1px solid #ddd; border-radius: 6px; padding: 16px 20px; min-width: 160px; flex: 1; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
.card .label { color: #777; font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; }
.card .value { font-size: 26px; font-weight: 700; margin: 4px 0; }
.card .detail { font-size: 11px; color: #999; }
.score-badge { display: inline-block; background: $gradeColor; color: #fff; padding: 8px 20px; border-radius: 6px; font-size: 28px; font-weight: 700; }
.score-label { display: inline-block; font-size: 18px; color: $gradeColor; font-weight: 600; margin-left: 12px; vertical-align: middle; }
.score-bar { height: 8px; border-radius: 4px; margin: 4px 0; }
.score-bar-bg { background: #e8e8e8; }
.score-bar-fill { background: $gradeColor; }
.chip { display: inline-block; padding: 4px 12px; border-radius: 12px; font-size: 11px; margin: 3px 4px; border: 1px solid #ddd; background: #f9f9f9; }
.chip b { color: #0078D4; }
.status-good { color: #107C10; font-weight: 600; }
.status-warn { color: #D83B01; font-weight: 600; }
.status-info { color: #0078D4; font-weight: 600; }
.status-missing { color: #E81123; }
.status-assigned { color: #107C10; }
.text-right { text-align: right; }
.text-muted { color: #999; font-size: 11px; }
.bar-chart { display: flex; align-items: flex-end; gap: 8px; height: 150px; margin: 15px 0; padding: 0 10px; }
.bar-col { display: flex; flex-direction: column; align-items: center; flex: 1; }
.bar { background: linear-gradient(180deg, #0078D4, #005A9E); border-radius: 3px 3px 0 0; min-width: 30px; width: 100%; }
.bar-label { font-size: 10px; color: #666; margin-top: 4px; text-align: center; }
.bar-value { font-size: 10px; color: #333; font-weight: 600; margin-bottom: 2px; }
footer { margin-top: 40px; padding-top: 15px; border-top: 1px solid #ddd; font-size: 11px; color: #999; text-align: center; }
.toc { background: #f5f8fc; padding: 20px; border-radius: 6px; margin: 15px 0; }
.toc a { color: #0078D4; text-decoration: none; font-size: 13px; display: block; padding: 3px 0; }
.toc a:hover { text-decoration: underline; }
</style>
</head>
<body>
<div class="header">
<h1>Azure FinOps Assessment Report</h1>
<p class="subtitle">Tenant: $($esc::Escape($d.Auth.TenantId)) &nbsp;|&nbsp; $($esc::Escape($d.Auth.AccountName))</p>
<p>Generated: $(Get-Date -Format 'MMMM d, yyyy h:mm tt') &nbsp;|&nbsp; Subscriptions scanned: $($d.Auth.Subscriptions.Count)</p>
</div>

<div class="toc">
<strong>Contents</strong>
<a href="#executive-summary">1. Executive Summary</a>
<a href="#maturity-score">2. FinOps Maturity Score</a>
<a href="#cost-overview">3. Cost Overview</a>
<a href="#cost-trend">4. 6-Month Cost Trend</a>
<a href="#resource-costs">5. Top Resource Costs</a>
<a href="#tagging">6. Tag Compliance</a>
<a href="#policy">7. Policy Compliance</a>
<a href="#optimization">8. Optimization Opportunities</a>
<a href="#budgets">9. Budget Status</a>
<a href="#actions">10. Actions Taken</a>
</div>
"@)

    # == 1. EXECUTIVE SUMMARY ==
    [void]$sb.Append(@"
<h2 id="executive-summary">1. Executive Summary</h2>
<div class="cards">
<div class="card"><div class="label">Total Spend (MTD)</div><div class="value" style="color:#0078D4">$sym$($totalActual.ToString('N2'))</div><div class="detail">Forecast: $sym$($totalForecast.ToString('N2'))</div></div>
<div class="card"><div class="label">FinOps Maturity</div><div class="value" style="color:$gradeColor">$rptScore / 100</div><div class="detail">$gradeLabel</div></div>
<div class="card"><div class="label">Subscriptions</div><div class="value" style="color:#0078D4">$($d.Auth.Subscriptions.Count)</div><div class="detail">Scanned</div></div>
"@)
    if ($d.Tags) {
        [void]$sb.Append("<div class=`"card`"><div class=`"label`">Tag Coverage</div><div class=`"value`" style=`"color:$(if ($d.Tags.TagCoverage -ge 80) { '#107C10' } elseif ($d.Tags.TagCoverage -ge 50) { '#D83B01' } else { '#E81123' })`">$([math]::Round($d.Tags.TagCoverage,1))%</div><div class=`"detail`">$($d.Tags.TaggedCount) of $($d.Tags.TotalResources) resources</div></div>")
    }
    if ($d.PolicyInv) {
        [void]$sb.Append("<div class=`"card`"><div class=`"label`">Policy Compliance</div><div class=`"value`" style=`"color:$(if ($d.PolicyInv.CompliancePct -ge 80) { '#107C10' } elseif ($d.PolicyInv.CompliancePct -ge 50) { '#D83B01' } else { '#E81123' })`">$([math]::Round($d.PolicyInv.CompliancePct,1))%</div><div class=`"detail`">$($d.PolicyInv.TotalNonCompliant) non-compliant</div></div>")
    }
    $optTotal = 0
    if ($d.Orphans) { $optTotal += $d.Orphans.TotalCount }
    if ($d.AHB) { $optTotal += $d.AHB.TotalOpportunities }
    if ($d.Optimization) { $optTotal += $d.Optimization.TotalCount }
    [void]$sb.Append("<div class=`"card`"><div class=`"label`">Optimizations Found</div><div class=`"value`" style=`"color:#D83B01`">$optTotal</div><div class=`"detail`">AHB + Orphans + Advisor</div></div>")
    [void]$sb.Append("</div>")

    # == 2. MATURITY SCORE ==
    [void]$sb.Append(@"
<h2 id="maturity-score">2. FinOps Maturity Score</h2>
<div style="margin:15px 0;">
<span class="score-badge">$rptScore</span>
<span class="score-label">$gradeLabel</span>
</div>
<p class="text-muted">Score based on FinOps Foundation Maturity Model and Microsoft Cloud Adoption Framework. Categories: Visibility (25), Allocation (20), Budgeting (15), Optimization (20), Governance (20).</p>
<div style="margin:15px 0;">
"@)
    foreach ($cat in @('Visibility','Allocation','Budgeting','Optimization','Governance')) {
        $catMax = switch ($cat) { 'Visibility' { 25 } 'Allocation' { 20 } 'Budgeting' { 15 } default { 20 } }
        $catVal = if ($rptBreakdown.ContainsKey($cat)) { $rptBreakdown[$cat] } else { 0 }
        $pct = if ($catMax -gt 0) { [math]::Round(($catVal / $catMax) * 100) } else { 0 }
        [void]$sb.Append("<div style=`"margin:8px 0;`"><strong>$cat</strong> <span style=`"color:#0078D4;`">$catVal / $catMax</span><div class=`"score-bar score-bar-bg`"><div class=`"score-bar score-bar-fill`" style=`"width:${pct}%;`"></div></div></div>")
    }
    [void]$sb.Append("</div>")

    # == 3. COST OVERVIEW ==
    [void]$sb.Append(@"
<h2 id="cost-overview">3. Cost Overview by Subscription</h2>
<table>
<tr><th>Subscription</th><th>Subscription ID</th><th class="text-right">Actual (MTD)</th><th class="text-right">Forecast</th><th class="text-right">Tag Coverage</th><th>Budget Status</th><th>Cost Trend</th></tr>
"@)
    foreach ($sub in $d.Auth.Subscriptions | Sort-Object { if ($d.Costs -and $d.Costs.ContainsKey($_.Id)) { $d.Costs[$_.Id].Actual } else { 0 } } -Descending) {
        $c = if ($d.Costs -and $d.Costs.ContainsKey($sub.Id)) { $d.Costs[$sub.Id] } else { @{ Actual = 0; Forecast = 0 } }

        # Tag coverage per sub
        $tagPct = '-'
        if ($d.Tags -and $d.Tags.RawResults) {
            $subRes = @($d.Tags.RawResults | Where-Object { $_.subscriptionId -eq $sub.Id })
            if ($subRes.Count -gt 0) {
                $tagged = @($subRes | Where-Object { $_.tags -and $_.tags.PSObject.Properties.Count -gt 0 }).Count
                $tagPct = "$([math]::Round(($tagged / $subRes.Count) * 100, 1))%"
            }
        }

        # Budget status
        $budgetTxt = '-'
        if ($d.Budgets -and $d.Budgets.Budgets) {
            $subBudgets = @($d.Budgets.Budgets | Where-Object { $_.SubscriptionId -eq $sub.Id })
            if ($subBudgets.Count -gt 0) {
                $worstRisk = ($subBudgets | Sort-Object PctUsed -Descending | Select-Object -First 1).Risk
                $budgetTxt = $worstRisk
            } else { $budgetTxt = 'No Budget' }
        }
        $budgetClass = switch ($budgetTxt) { 'Over Budget' { 'status-warn' } 'At Risk' { 'status-warn' } 'On Track' { 'status-good' } default { 'text-muted' } }

        # Cost trend
        $trendTxt = '-'
        if ($d.CostTrend -and $d.CostTrend.HasData -and $d.CostTrend.Months.Count -ge 2) {
            $last = $d.CostTrend.Months[-1].Cost; $prev = $d.CostTrend.Months[-2].Cost
            if ($prev -gt 0) {
                $pctChg = [math]::Round((($last - $prev) / $prev) * 100, 1)
                $trendTxt = if ($pctChg -gt 5) { "Up $pctChg%" } elseif ($pctChg -lt -5) { "Down $([math]::Abs($pctChg))%" } else { 'Stable' }
            }
        }

        [void]$sb.Append("<tr><td><strong>$($esc::Escape($sub.Name))</strong></td><td class=`"text-muted`">$($sub.Id)</td>")
        [void]$sb.Append("<td class=`"text-right`">$sym$($c.Actual.ToString('N2'))</td><td class=`"text-right`">$sym$($c.Forecast.ToString('N2'))</td>")
        [void]$sb.Append("<td class=`"text-right`">$tagPct</td><td class=`"$budgetClass`">$budgetTxt</td><td>$trendTxt</td></tr>")
    }
    [void]$sb.Append("<tr style=`"font-weight:700;background:#EBF5FF;`"><td>Total</td><td></td><td class=`"text-right`">$sym$($totalActual.ToString('N2'))</td><td class=`"text-right`">$sym$($totalForecast.ToString('N2'))</td><td></td><td></td><td></td></tr>")
    [void]$sb.Append("</table>")

    # == 4. COST TREND ==
    [void]$sb.Append('<h2 id="cost-trend">4. 6-Month Cost Trend</h2>')
    if ($d.CostTrend -and $d.CostTrend.HasData -and $d.CostTrend.Months.Count -gt 0) {
        # Aggregate trend
        [void]$sb.Append('<h3>All Subscriptions</h3>')
        $months = $d.CostTrend.Months
        $maxCost = ($months | Measure-Object -Property Cost -Maximum).Maximum
        if ($maxCost -le 0) { $maxCost = 1 }
        [void]$sb.Append("<table><tr><th>Month</th><th class=`"text-right`">Spend</th><th>Bar</th></tr>")
        foreach ($m in $months) {
            $barW = [math]::Round(($m.Cost / $maxCost) * 100)
            [void]$sb.Append("<tr><td>$($esc::Escape($m.Month))</td><td class=`"text-right`">$sym$($m.Cost.ToString('N2'))</td>")
            [void]$sb.Append("<td><div style=`"background:linear-gradient(90deg,#0078D4,#005A9E);height:18px;width:${barW}%;border-radius:3px;min-width:2px;`"></div></td></tr>")
        }
        [void]$sb.Append("</table>")

        # Per-subscription trends
        if ($d.CostTrend.BySubscription -and $d.CostTrend.BySubscription.Count -gt 0 -and $d.Auth.Subscriptions.Count -gt 1) {
            foreach ($sub in $d.Auth.Subscriptions) {
                if ($d.CostTrend.BySubscription.ContainsKey($sub.Id)) {
                    $subMonths = $d.CostTrend.BySubscription[$sub.Id]
                    if ($subMonths.Count -gt 0) {
                        $subMax = ($subMonths | Measure-Object -Property Cost -Maximum).Maximum
                        if ($subMax -le 0) { $subMax = 1 }
                        [void]$sb.Append("<h3>$($esc::Escape($sub.Name))</h3>")
                        [void]$sb.Append("<table><tr><th>Month</th><th class=`"text-right`">Spend</th><th>Bar</th></tr>")
                        foreach ($sm in $subMonths) {
                            $bw = [math]::Round(($sm.Cost / $subMax) * 100)
                            [void]$sb.Append("<tr><td>$($esc::Escape($sm.Month))</td><td class=`"text-right`">$sym$($sm.Cost.ToString('N2'))</td>")
                            [void]$sb.Append("<td><div style=`"background:linear-gradient(90deg,#2B88D8,#0063B1);height:18px;width:${bw}%;border-radius:3px;min-width:2px;`"></div></td></tr>")
                        }
                        [void]$sb.Append("</table>")
                    }
                }
            }
        }
    } else {
        [void]$sb.Append('<p class="text-muted">No cost trend data available.</p>')
    }

    # == 5. RESOURCE COSTS ==
    [void]$sb.Append('<div class="page-break"></div><h2 id="resource-costs">5. Top Resource Costs</h2>')
    if ($d.ResourceCosts -and $d.ResourceCosts.Count -gt 0) {
        $topResources = $d.ResourceCosts | Sort-Object Actual -Descending | Select-Object -First 50
        [void]$sb.Append("<p class=`"text-muted`">Showing top $([math]::Min(50, $d.ResourceCosts.Count)) of $($d.ResourceCosts.Count) resources by MTD cost.</p>")
        [void]$sb.Append("<table><tr><th>Resource</th><th>Type</th><th>Resource Group</th><th>Subscription</th><th class=`"text-right`">Actual (MTD)</th><th class=`"text-right`">Forecast</th></tr>")
        foreach ($r in $topResources) {
            $resName = ($r.ResourcePath -split '/')[-1]
            [void]$sb.Append("<tr><td><strong>$($esc::Escape($resName))</strong></td><td>$($esc::Escape($r.ResourceType))</td>")
            [void]$sb.Append("<td>$($esc::Escape($r.ResourceGroup))</td><td>$($esc::Escape($r.Subscription))</td>")
            [void]$sb.Append("<td class=`"text-right`">$sym$($r.Actual.ToString('N2'))</td><td class=`"text-right`">$sym$($r.Forecast.ToString('N2'))</td></tr>")
        }
        [void]$sb.Append("</table>")
    } else {
        [void]$sb.Append('<p class="text-muted">No resource-level cost data available.</p>')
    }

    # == 6. TAG COMPLIANCE ==
    [void]$sb.Append('<h2 id="tagging">6. Tag Compliance</h2>')
    if ($d.Tags) {
        [void]$sb.Append(@"
<div class="cards">
<div class="card"><div class="label">Tag Coverage</div><div class="value" style="color:#0078D4">$([math]::Round($d.Tags.TagCoverage,1))%</div><div class="detail">$($d.Tags.TaggedCount) tagged / $($d.Tags.TotalResources) total</div></div>
<div class="card"><div class="label">Unique Tags</div><div class="value" style="color:#0078D4">$($d.Tags.TagCount)</div><div class="detail">Distinct tag names</div></div>
<div class="card"><div class="label">Untagged Resources</div><div class="value" style="color:#D83B01">$($d.Tags.UntaggedCount)</div></div>
</div>
"@)
        # Tag inventory table
        if ($d.Tags.TagNames -and $d.Tags.TagNames.Count -gt 0) {
            [void]$sb.Append("<h3>Tag Inventory ($($d.Tags.TagNames.Count) tags)</h3>")
            [void]$sb.Append('<table><tr><th>Tag Name</th><th class="text-right">Resources</th><th class="text-right">Unique Values</th><th>Sample Values</th></tr>')
            foreach ($entry in $d.Tags.TagNames.GetEnumerator() | Sort-Object { $_.Value.TotalResources } -Descending) {
                $allValues = @($entry.Value.Values | ForEach-Object { $_.Value })
                $sampleValues = ($allValues | Select-Object -First 5) -join ', '
                if ($allValues.Count -gt 5) { $sampleValues += ", ... (+$($allValues.Count - 5) more)" }
                [void]$sb.Append("<tr><td><strong>$($esc::Escape($entry.Key))</strong></td><td class=`"text-right`">$($entry.Value.TotalResources)</td><td class=`"text-right`">$($allValues.Count)</td><td>$($esc::Escape($sampleValues))</td></tr>")
            }
            [void]$sb.Append('</table>')
        }
        # CAF recommended tags
        if ($d.TagRecs) {
            [void]$sb.Append("<h3>Microsoft CAF Recommended Tags</h3>")
            [void]$sb.Append("<table><tr><th>Tag Name</th><th>Status</th><th>Location</th><th>Purpose</th></tr>")
            foreach ($tr in $d.TagRecs.Analysis) {
                $statusCls = if ($tr.Status -eq 'Present') { 'status-assigned' } else { 'status-missing' }
                $locText = if ($tr.Location) { $esc::Escape($tr.Location) } else { '-' }
                [void]$sb.Append("<tr><td><strong>$($esc::Escape($tr.TagName))</strong></td><td class=`"$statusCls`">$($tr.Status)</td><td>$locText</td><td>$($esc::Escape($tr.Purpose))</td></tr>")
            }
            [void]$sb.Append("</table>")
        }
        # Untagged resources detail list
        if ($d.Tags.UntaggedResources -and $d.Tags.UntaggedResources.Count -gt 0) {
            $utShown = $d.Tags.UntaggedResources.Count
            $utTotal = $d.Tags.UntaggedCount
            $utNote  = if ($utShown -lt $utTotal) { " (showing $utShown of $utTotal)" } else { "" }
            [void]$sb.Append("<h3>Untagged Resources$utNote</h3>")
            [void]$sb.Append("<table><tr><th>Resource Name</th><th>Resource Type</th><th>Resource Group</th><th>Subscription</th><th>Location</th></tr>")
            foreach ($ur in $d.Tags.UntaggedResources) {
                [void]$sb.Append("<tr><td>$($esc::Escape($ur.ResourceName))</td><td>$($esc::Escape($ur.ResourceType))</td><td>$($esc::Escape($ur.ResourceGroup))</td><td>$($esc::Escape($ur.Subscription))</td><td>$($esc::Escape($ur.Location))</td></tr>")
            }
            [void]$sb.Append("</table>")
        }
    } else {
        [void]$sb.Append('<p class="text-muted">No tag data available.</p>')
    }

    # == 7. POLICY COMPLIANCE ==
    [void]$sb.Append('<div class="page-break"></div><h2 id="policy">7. Policy Compliance</h2>')
    if ($d.PolicyInv) {
        [void]$sb.Append(@"
<div class="cards">
<div class="card"><div class="label">Policy Assignments</div><div class="value" style="color:#0078D4">$($d.PolicyInv.AssignmentCount)</div></div>
<div class="card"><div class="label">Compliance</div><div class="value" style="color:$(if ($d.PolicyInv.CompliancePct -ge 80) { '#107C10' } else { '#D83B01' })">$([math]::Round($d.PolicyInv.CompliancePct,1))%</div></div>
<div class="card"><div class="label">Non-Compliant Resources</div><div class="value" style="color:#D83B01">$($d.PolicyInv.TotalNonCompliant)</div></div>
</div>
"@)
        # Per-subscription compliance
        if ($d.PolicyInv.ComplianceBySubMap -and $d.PolicyInv.ComplianceBySubMap.Count -gt 0) {
            [void]$sb.Append("<h3>Per-Subscription Compliance</h3><table><tr><th>Subscription</th><th class=`"text-right`">Compliant</th><th class=`"text-right`">Non-Compliant</th><th class=`"text-right`">Total</th><th class=`"text-right`">Compliance %</th></tr>")
            foreach ($sk in $d.PolicyInv.ComplianceBySubMap.Keys) {
                $cs = $d.PolicyInv.ComplianceBySubMap[$sk]
                $cpct = if (($cs.Compliant + $cs.NonCompliant) -gt 0) { [math]::Round(($cs.Compliant / ($cs.Compliant + $cs.NonCompliant)) * 100, 1) } else { 0 }
                [void]$sb.Append("<tr><td>$($esc::Escape($cs.Subscription))</td><td class=`"text-right`">$($cs.Compliant)</td><td class=`"text-right`">$($cs.NonCompliant)</td><td class=`"text-right`">$($cs.TotalResources)</td><td class=`"text-right`">$cpct%</td></tr>")
            }
            [void]$sb.Append("</table>")
        }
        # Policy assignment inventory
        if ($d.PolicyInv.Assignments -and $d.PolicyInv.Assignments.Count -gt 0) {
            [void]$sb.Append("<h3>Policy Assignment Inventory ($($d.PolicyInv.Assignments.Count) assignments)</h3>")
            [void]$sb.Append('<table><tr><th>Assignment Name</th><th>Type</th><th>Effect</th><th>Enforcement</th><th>Origin</th><th>Subscription</th></tr>')
            foreach ($pa in $d.PolicyInv.Assignments) {
                $paType = if ($pa.PolicyDefId -match '/policySetDefinitions/') { 'Initiative' } else { 'Policy' }
                [void]$sb.Append("<tr><td>$($esc::Escape($pa.AssignmentName))</td><td>$paType</td><td>$($esc::Escape($pa.Effect))</td><td>$($esc::Escape($pa.EnforcementMode))</td><td>$($esc::Escape($pa.Origin))</td><td>$($esc::Escape($pa.Subscription))</td></tr>")
            }
            [void]$sb.Append('</table>')
        }
    }

    # FinOps Policy Recommendations
    if ($d.PolicyRecs) {
        [void]$sb.Append("<h3>FinOps Recommended Policies ($($d.PolicyRecs.Assigned.Count) of $($d.PolicyRecs.Analysis.Count) assigned)</h3>")
        [void]$sb.Append("<table><tr><th>Policy</th><th>Status</th><th>Category</th><th>Priority</th><th>Pillar</th><th>Purpose</th></tr>")
        foreach ($pr in $d.PolicyRecs.Analysis | Sort-Object { switch ($_.Priority) { 'Required' { 0 } 'Recommended' { 1 } 'Optional' { 2 } default { 3 } } }) {
            $sCls = if ($pr.Status -eq 'Assigned') { 'status-assigned' } else { 'status-missing' }
            [void]$sb.Append("<tr><td><strong>$($esc::Escape($pr.DisplayName))</strong></td><td class=`"$sCls`">$($pr.Status)</td>")
            [void]$sb.Append("<td>$($esc::Escape($pr.Category))</td><td>$($pr.Priority)</td><td>$($pr.Pillar)</td><td>$($esc::Escape($pr.Purpose))</td></tr>")
        }
        [void]$sb.Append("</table>")
    }

    # == 8. OPTIMIZATION ==
    [void]$sb.Append('<h2 id="optimization">8. Optimization Opportunities</h2>')
    # AHB
    if ($d.AHB -and $d.AHB.TotalOpportunities -gt 0) {
        [void]$sb.Append("<h3>Azure Hybrid Benefit Opportunities ($($d.AHB.TotalOpportunities))</h3>")
        [void]$sb.Append("<p>$($esc::Escape($d.AHB.Summary))</p>")
        if ($d.AHB.WindowsVMs.Count -gt 0) {
            [void]$sb.Append("<table><tr><th>VM Name</th><th>Resource Group</th><th>Size</th><th>Location</th><th>Current License</th></tr>")
            foreach ($vm in $d.AHB.WindowsVMs) {
                [void]$sb.Append("<tr><td>$($esc::Escape($vm.name))</td><td>$($esc::Escape($vm.resourceGroup))</td><td>$($esc::Escape($vm.vmSize))</td><td>$($esc::Escape($vm.location))</td><td>$($esc::Escape($vm.currentLicense))</td></tr>")
            }
            [void]$sb.Append("</table>")
        }
    }
    # Orphans
    if ($d.Orphans -and $d.Orphans.TotalCount -gt 0) {
        [void]$sb.Append("<h3>Orphaned / Idle Resources ($($d.Orphans.TotalCount))</h3>")
        [void]$sb.Append("<table><tr><th>Category</th><th>Resource</th><th>Resource Group</th><th>Impact</th><th>Detail</th></tr>")
        foreach ($o in $d.Orphans.Orphans | Sort-Object Impact -Descending) {
            $impCls = switch ($o.Impact) { 'High' { 'status-warn' } 'Medium' { 'status-info' } default { 'text-muted' } }
            [void]$sb.Append("<tr><td>$($esc::Escape($o.Category))</td><td><strong>$($esc::Escape($o.ResourceName))</strong></td><td>$($esc::Escape($o.ResourceGroup))</td><td class=`"$impCls`">$($o.Impact)</td><td>$($esc::Escape($o.Detail))</td></tr>")
        }
        [void]$sb.Append("</table>")
    }
    # Advisor
    if ($d.Optimization -and $d.Optimization.TotalCount -gt 0) {
        [void]$sb.Append("<h3>Azure Advisor Cost Recommendations ($($d.Optimization.TotalCount))</h3>")
        if ($d.Optimization.EstimatedAnnualSavings -gt 0) {
            [void]$sb.Append("<p>Estimated annual savings: <strong>$sym$($d.Optimization.EstimatedAnnualSavings.ToString('N2'))</strong></p>")
        }
        [void]$sb.Append("<table><tr><th>Subscription</th><th>Category</th><th>Impact</th><th>Problem</th><th>Solution</th><th class=`"text-right`">Annual Savings</th></tr>")
        foreach ($rec in $d.Optimization.Recommendations | Sort-Object { switch ($_.Impact) { 'High' { 0 } 'Medium' { 1 } default { 2 } } }) {
            $impCls = switch ($rec.Impact) { 'High' { 'status-warn' } 'Medium' { 'status-info' } default { 'text-muted' } }
            $savings = if ($rec.AnnualSavings -and $rec.AnnualSavings -gt 0) { "$sym$($rec.AnnualSavings.ToString('N2'))" } else { '-' }
            [void]$sb.Append("<tr><td>$($esc::Escape($rec.Subscription))</td><td>$($esc::Escape($rec.Category))</td><td class=`"$impCls`">$($rec.Impact)</td>")
            [void]$sb.Append("<td>$($esc::Escape($rec.Problem))</td><td>$($esc::Escape($rec.Solution))</td><td class=`"text-right`">$savings</td></tr>")
        }
        [void]$sb.Append("</table>")
    }
    if ($optTotal -eq 0) {
        [void]$sb.Append('<p class="status-good">No optimization issues found. Well optimized!</p>')
    }

    # == 9. BUDGETS ==
    [void]$sb.Append('<div class="page-break"></div><h2 id="budgets">9. Budget Status</h2>')
    if ($d.Budgets -and $d.Budgets.HasData) {
        [void]$sb.Append(@"
<div class="cards">
<div class="card"><div class="label">Total Budgets</div><div class="value" style="color:#0078D4">$($d.Budgets.TotalBudgets)</div></div>
<div class="card"><div class="label">Budget Coverage</div><div class="value" style="color:#0078D4">$([math]::Round($d.Budgets.BudgetCoverage,0))%</div><div class="detail">$($d.Budgets.SubsWithBudget) of $($d.Budgets.SubsWithBudget + $d.Budgets.SubsWithoutBudget) subscriptions</div></div>
<div class="card"><div class="label">Over Budget</div><div class="value" style="color:$(if ($d.Budgets.OverBudgetCount -gt 0) { '#E81123' } else { '#107C10' })">$($d.Budgets.OverBudgetCount)</div></div>
<div class="card"><div class="label">At Risk</div><div class="value" style="color:$(if ($d.Budgets.AtRiskCount -gt 0) { '#D83B01' } else { '#107C10' })">$($d.Budgets.AtRiskCount)</div></div>
</div>
"@)
        [void]$sb.Append("<table><tr><th>Subscription</th><th>Budget Name</th><th class=`"text-right`">Amount</th><th class=`"text-right`">Actual Spend</th><th class=`"text-right`">% Used</th><th>Risk</th></tr>")
        foreach ($b in $d.Budgets.Budgets | Sort-Object PctUsed -Descending) {
            $riskCls = switch ($b.Risk) { 'Over Budget' { 'status-warn' } 'At Risk' { 'status-warn' } 'On Track' { 'status-good' } default { 'text-muted' } }
            [void]$sb.Append("<tr><td>$($esc::Escape($b.Subscription))</td><td>$($esc::Escape($b.BudgetName))</td>")
            [void]$sb.Append("<td class=`"text-right`">$sym$($b.Amount.ToString('N2'))</td><td class=`"text-right`">$sym$($b.ActualSpend.ToString('N2'))</td>")
            [void]$sb.Append("<td class=`"text-right`">$([math]::Round($b.PctUsed,1))%</td><td class=`"$riskCls`">$($b.Risk)</td></tr>")
        }
        [void]$sb.Append("</table>")
    } else {
        [void]$sb.Append('<p class="text-muted">No budgets configured. Consider creating budgets for all production subscriptions.</p>')
    }

    # == 10. ACTIONS TAKEN ==
    if ($script:actionLog.Count -gt 0) {
        [void]$sb.Append('<div class="section" id="actions"><h2>10. Actions Taken This Session</h2>')
        [void]$sb.Append('<p>The following changes were made during this scan session:</p>')
        [void]$sb.Append('<table><tr><th>Time</th><th>Action</th><th>Detail</th></tr>')
        foreach ($entry in $script:actionLog) {
            [void]$sb.Append("<tr><td>$($esc::Escape($entry.Time))</td><td>$($esc::Escape($entry.Type))</td><td>$($esc::Escape($entry.Detail))</td></tr>")
        }
        [void]$sb.Append('</table></div>')
    }

    # Footer
    [void]$sb.Append(@"
<footer>
<p>Generated by <strong>Azure FinOps Multitool</strong> &mdash; $(Get-Date -Format 'MMMM d, yyyy h:mm tt')</p>
<p>Based on FinOps Foundation Framework and Microsoft Cloud Adoption Framework for Azure.</p>
<p class="no-print" style="margin-top:10px;"><em>Tip: Use your browser's Print function (Ctrl+P) and select "Save as PDF" for a PDF version of this report.</em></p>
</footer>
</body>
</html>
"@)

    [System.IO.File]::WriteAllText($path, $sb.ToString(), [System.Text.Encoding]::UTF8)
    Update-UIStatus "Report exported to $path" $script:ProgressBar.Value

    # Auto-open the report
    try { Start-Process $path } catch { }
}

###########################################################################
# SCAN STAGES (DispatcherTimer-based staged loading)
###########################################################################
$script:scanStages = @(
    @{ Label = 'Verifying tenant context...';         Pct = 5;   Action = {
        if (-not $script:scanData.Auth) {
            throw "No tenant selected. Click 'Commercial Tenant' or 'Gov Tenant' first."
        }
        $script:MgCostScopeFailed = $false  # Reset MG-scope flag for fresh scan
        $envLabel = $script:scanData.Auth.Environment
        $script:TenantLabel.Text = "Tenant: $($script:scanData.Auth.TenantId)  |  $($script:scanData.Auth.AccountName)  |  $envLabel"
        if ($envLabel -eq 'AzureUSGovernment') {
            $script:GovTenantButton.Content = "$($script:LockClosed) Gov Tenant"
        } else {
            $script:TenantButton.Content = "$($script:LockClosed) Commercial Tenant"
        }
    }}
    @{ Label = 'Loading management group hierarchy...'; Pct = 15;  Action = {
        $script:scanData.Hierarchy = Get-TenantHierarchy -TenantId $script:scanData.Auth.TenantId -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Detecting contract type...';           Pct = 25;  Action = {
        $script:scanData.Contract = Get-ContractInfo -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Querying cost data...';                Pct = 30;  Action = {
        $script:scanData.Costs = Get-CostData -TenantId $script:scanData.Auth.TenantId -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Querying resource-level costs...';      Pct = 40;  Action = {
        $script:scanData.ResourceCosts = Get-ResourceCosts -TenantId $script:scanData.Auth.TenantId -Subscriptions $script:scanData.Auth.Subscriptions -CostData $script:scanData.Costs
    }}
    @{ Label = 'Scanning tag inventory...';            Pct = 50;  Action = {
        $script:scanData.Tags = Get-TagInventory -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Querying cost by tag...';              Pct = 55;  Action = {
        $tagNames = if ($script:scanData.Tags) { $script:scanData.Tags.TagNames } else { @{} }
        $script:scanData.CostByTag = Get-CostByTag -TenantId $script:scanData.Auth.TenantId -ExistingTags $tagNames -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Querying 6-month cost trend...';       Pct = 60;  Action = {
        $script:scanData.CostTrend = Get-CostTrend -TenantId $script:scanData.Auth.TenantId -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Scanning AHB opportunities...';        Pct = 64;  Action = {
        $script:scanData.AHB = Get-AHBOpportunities -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Scanning commitment utilization...';   Pct = 68;  Action = {
        $agreementType = if ($script:scanData.Contract -and $script:scanData.Contract[0].AgreementType) { $script:scanData.Contract[0].AgreementType } else { '' }
        $script:scanData.Commitments = Get-CommitmentUtilization -Subscriptions $script:scanData.Auth.Subscriptions -AgreementType $agreementType
    }}
    @{ Label = 'Scanning orphaned resources...';       Pct = 70;  Action = {
        $script:scanData.Orphans = Get-OrphanedResources -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Scanning idle VMs...';                 Pct = 73;  Action = {
        $script:scanData.IdleVMs = Get-IdleVMs -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Scanning storage tier advice...';      Pct = 75;  Action = {
        $script:scanData.StorageTier = Get-StorageTierAdvice -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Loading reservation advice...';        Pct = 77;  Action = {
        $script:scanData.Reservations = Get-ReservationAdvice -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Loading optimization advice...';       Pct = 80;  Action = {
        $script:scanData.Optimization = Get-OptimizationAdvice -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Querying budget status...';            Pct = 82;  Action = {
        $script:scanData.Budgets = Get-BudgetStatus -Subscriptions $script:scanData.Auth.Subscriptions -CostData $script:scanData.Costs
    }}
    @{ Label = 'Querying anomaly alerts...';           Pct = 84;  Action = {
        $script:scanData.AnomalyAlerts = Get-AnomalyAlerts -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Calculating savings realized...';      Pct = 86;  Action = {
        $script:scanData.Savings = Get-SavingsRealized -TenantId $script:scanData.Auth.TenantId -Subscriptions $script:scanData.Auth.Subscriptions -CommitmentData $script:scanData.Commitments
    }}
    @{ Label = 'Analyzing tag compliance...';          Pct = 88;  Action = {
        $tagNames = if ($script:scanData.Tags) { $script:scanData.Tags.TagNames } else { @{} }
        $tagLocs  = if ($script:scanData.Tags) { $script:scanData.Tags.TagLocations } else { @{} }
        $script:scanData.TagRecs = Get-TagRecommendations -ExistingTags $tagNames -TagLocations $tagLocs
    }}
    @{ Label = 'Scanning policy assignments...';       Pct = 89;  Action = {
        $script:scanData.PolicyInv = Get-PolicyInventory -TenantId $script:scanData.Auth.TenantId -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Analyzing FinOps policy coverage...';  Pct = 90;  Action = {
        $assignments = if ($script:scanData.PolicyInv) { $script:scanData.PolicyInv.Assignments } else { @() }
        $script:scanData.PolicyRecs = Get-PolicyRecommendations -ExistingAssignments $assignments
    }}
    @{ Label = 'Querying billing structure...';        Pct = 92;  Action = {
        $script:scanData.Billing = Get-BillingStructure -Subscriptions $script:scanData.Auth.Subscriptions
    }}
    @{ Label = 'Building dashboard...';                Pct = 96;  Action = {
        try { Populate-OverviewTab }      catch { Write-Warning "Populate-OverviewTab failed: $($_.Exception.Message)" }
        try { Populate-CostTab }           catch { Write-Warning "Populate-CostTab failed: $($_.Exception.Message)" }
        try { Populate-TrendChart }        catch { Write-Warning "Populate-TrendChart failed: $($_.Exception.Message)" }
        try { Populate-AnomalySection }    catch { Write-Warning "Populate-AnomalySection failed: $($_.Exception.Message)" }
        try { Populate-AlertsSection }     catch { Write-Warning "Populate-AlertsSection failed: $($_.Exception.Message)" }
        try { Populate-TagsTab }           catch { Write-Warning "Populate-TagsTab failed: $($_.Exception.Message)" }
        try { Populate-PolicyTab }         catch { Write-Warning "Populate-PolicyTab failed: $($_.Exception.Message)" }
        try { Populate-CommitmentSection } catch { Write-Warning "Populate-CommitmentSection failed: $($_.Exception.Message)" }
        try { Populate-OrphanedSection }   catch { Write-Warning "Populate-OrphanedSection failed: $($_.Exception.Message)" }
        try { Populate-OptimizationTab }   catch { Write-Warning "Populate-OptimizationTab failed: $($_.Exception.Message)" }
        try { Populate-IdleVMSection }     catch { Write-Warning "Populate-IdleVMSection failed: $($_.Exception.Message)" }
        try { Populate-StorageTierSection } catch { Write-Warning "Populate-StorageTierSection failed: $($_.Exception.Message)" }
        try { Populate-BudgetSection }     catch { Write-Warning "Populate-BudgetSection failed: $($_.Exception.Message)" }
        try { Populate-BudgetsTab }        catch { Write-Warning "Populate-BudgetsTab failed: $($_.Exception.Message)" }
        try { Populate-Scorecard }         catch { Write-Warning "Populate-Scorecard failed: $($_.Exception.Message)" }
        try { Populate-BillingTab }        catch { Write-Warning "Populate-BillingTab failed: $($_.Exception.Message)" }
        try { Populate-GuidanceTab }       catch { Write-Warning "Populate-GuidanceTab failed: $($_.Exception.Message)" }
        try { Populate-ResourcesTab }      catch { Write-Warning "Populate-ResourcesTab failed: $($_.Exception.Message)" }
        $script:tagDeployScopesLoaded = $false   # Reset so scopes reload on next tag deploy
        $script:policyDeployScopesLoaded = $false  # Reset so scopes reload on next policy deploy
    }}
    @{ Label = 'Scan complete!';                       Pct = 100; Action = {
        $script:ExportButton.IsEnabled = $true
    }}
)

$script:currentStage = 0
$script:scanTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:scanTimer.Interval = [TimeSpan]::FromMilliseconds(50)

$script:scanTimer.Add_Tick({
    if ($script:currentStage -ge $script:scanStages.Count) {
        $script:scanTimer.Stop()
        $script:ScanButton.IsEnabled = $true
        $script:TenantButton.IsEnabled = $true
        $script:GovTenantButton.IsEnabled = $true
        $script:ScanButton.Content = "Re-Scan"
        return
    }

    $stage = $script:scanStages[$script:currentStage]

    try {
        $script:StatusText.Text = $stage.Label
        $script:ProgressBar.Value = $stage.Pct
        # Force UI update before running the action
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [action]{}, [System.Windows.Threading.DispatcherPriority]::Background
        )

        & $stage.Action
    } catch {
        Write-Warning "Stage '$($stage.Label)' failed: $($_.Exception.Message)"
        $script:StatusText.Text = "Warning: $($stage.Label) - $($_.Exception.Message)"

        # If authentication failed, abort the entire scan
        if (-not $script:scanData.Auth) {
            $script:scanTimer.Stop()
            $script:ScanButton.IsEnabled = $true
            $script:TenantButton.IsEnabled = $true
            $script:GovTenantButton.IsEnabled = $true
            $script:ScanButton.Content = "Retry Scan"
            $script:StatusText.Text = "Scan aborted: $($_.Exception.Message)"
            $script:ProgressBar.Value = 0
            return
        }
    }

    $script:currentStage++
})

###########################################################################
# EVENT WIRING
###########################################################################

# Scan Button
$script:ScanButton.Add_Click({
    $script:ScanButton.IsEnabled = $false
    $script:TenantButton.IsEnabled = $false
    $script:GovTenantButton.IsEnabled = $false
    $script:ExportButton.IsEnabled = $false
    $script:currentStage = 0
    $script:scanTimer.Start()
})

# Lock icon characters (surrogates for PS 5.1 compat)
$script:LockOpen   = [char]::ConvertFromUtf32(0x1F513)   # open lock
$script:LockClosed = [char]::ConvertFromUtf32(0x1F512)   # closed lock

# Choose Commercial Tenant Button
$script:TenantButton.Add_Click({
    $script:TenantButton.IsEnabled = $false
    $script:GovTenantButton.IsEnabled = $false
    $script:ScanButton.IsEnabled = $false
    # Show unlocked while choosing
    $script:TenantButton.Content = "$($script:LockOpen) Commercial Tenant"
    $script:StatusText.Text = 'Connecting to Azure Commercial...'
    try {
        $authResult = @(Initialize-Scanner -Environment 'AzureCloud' -ParentWindow $window)
        $script:scanData.Auth = $authResult[-1]
        $envLabel = $script:scanData.Auth.Environment
        $subCount = $script:scanData.Auth.Subscriptions.Count

        # Let user select which subscriptions to scan
        $selected = Show-SubscriptionSelector -Subscriptions $script:scanData.Auth.Subscriptions -SkippedSubs $script:scanData.Auth.SkippedSubs -ParentWindow $window
        $script:scanData.Auth | Add-Member -NotePropertyName Subscriptions -NotePropertyValue @($selected) -Force
        $subCount = $script:scanData.Auth.Subscriptions.Count

        $script:TenantLabel.Text = "Tenant: $($script:scanData.Auth.TenantId)  |  $($script:scanData.Auth.AccountName)  |  $envLabel"
        $tenantSize = if ($script:scanData.Auth.TenantSize) { " [$($script:scanData.Auth.TenantSize)]" } else { '' }
        $script:StatusText.Text = "Connected to $envLabel ($subCount subs$tenantSize). Click 'Scan' to begin."
        # Show locked after successful selection
        $script:TenantButton.Content = "$($script:LockClosed) Commercial Tenant"
    } catch {
        $script:StatusText.Text = "Tenant switch failed: $($_.Exception.Message)"
    }
    $script:TenantButton.IsEnabled = $true
    $script:GovTenantButton.IsEnabled = $true
    $script:ScanButton.IsEnabled = $true
})

# Choose Gov Tenant Button
$script:GovTenantButton.Add_Click({
    $script:TenantButton.IsEnabled = $false
    $script:GovTenantButton.IsEnabled = $false
    $script:ScanButton.IsEnabled = $false
    $script:GovTenantButton.Content = "$($script:LockOpen) Gov Tenant"
    $script:StatusText.Text = 'Connecting to Azure Government...'
    try {
        $authResult = @(Initialize-Scanner -Environment 'AzureUSGovernment' -ParentWindow $window)
        $script:scanData.Auth = $authResult[-1]
        $envLabel = $script:scanData.Auth.Environment
        $subCount = $script:scanData.Auth.Subscriptions.Count

        # Let user select which subscriptions to scan
        $selected = Show-SubscriptionSelector -Subscriptions $script:scanData.Auth.Subscriptions -SkippedSubs $script:scanData.Auth.SkippedSubs -ParentWindow $window
        $script:scanData.Auth | Add-Member -NotePropertyName Subscriptions -NotePropertyValue @($selected) -Force
        $subCount = $script:scanData.Auth.Subscriptions.Count

        $script:TenantLabel.Text = "Tenant: $($script:scanData.Auth.TenantId)  |  $($script:scanData.Auth.AccountName)  |  $envLabel"
        $tenantSize = if ($script:scanData.Auth.TenantSize) { " [$($script:scanData.Auth.TenantSize)]" } else { '' }
        $script:StatusText.Text = "Connected to $envLabel ($subCount subs$tenantSize). Click 'Scan' to begin."
        $script:GovTenantButton.Content = "$($script:LockClosed) Gov Tenant"
    } catch {
        $script:StatusText.Text = "Gov tenant switch failed: $($_.Exception.Message)"
    }
    $script:TenantButton.IsEnabled = $true
    $script:GovTenantButton.IsEnabled = $true
    $script:ScanButton.IsEnabled = $true
})

# Export Button — show export format chooser dialog
$script:ExportButton.Add_Click({
    Show-ExportDialog
})

# Budget Tab - Subscription Selector
$script:BudgetSubSelector.Add_SelectionChanged({
    Update-BudgetDetailView
})

# Budget Tab - Deploy Button
$script:BudgetDeployButton.Add_Click({
    Deploy-BudgetFromTab
})

# Budget Tab - Cancel Button
$script:BudgetDeployCancelButton.Add_Click({
    $script:BudgetDeployNameInput.Text = 'default-budget'
    $script:BudgetDeployAmountInput.Text = '1000'
    $script:BudgetDeployEmailInput.Text = ''
    $script:BudgetThreshold1.Text = ''
    $script:BudgetThreshold2.Text = ''
    $script:BudgetThreshold3.Text = ''
    $script:BudgetThreshold4.Text = ''
    $script:BudgetDeployStatus.Text = ''
})

# Budget Policy - Deploy Button
$script:BudgetPolicyDeployButton.Add_Click({
    Deploy-BudgetPolicyFromTab
})

# Budget Policy - Cancel Button
$script:BudgetPolicyCancelButton.Add_Click({
    $script:BudgetPolicyStatus.Text = ''
})

# Tag Selector (Cost Analysis tab)
$script:TagSelector.Add_SelectionChanged({
    $selectedTag = $script:TagSelector.SelectedItem
    if (-not $selectedTag -or -not $script:scanData.CostByTag) { return }

    $data = $script:scanData.CostByTag.CostByTag
    $tf   = $script:scanData.CostByTag.UsedTimeframe
    $costLabel = if ($tf -eq 'Custom') { 'Cost (Last Month)' } else { 'Cost (MTD)' }

    if ($data.ContainsKey($selectedTag) -and $data[$selectedTag].Count -gt 0) {
        $tfNote = if ($tf -eq 'Custom') { ' (showing last month - current month data still processing)' } else { '' }
        $script:NoTagsLabel.Text = $tfNote
        $rows = $data[$selectedTag] | ForEach-Object {
            [PSCustomObject]@{
                'Tag Value'  = $_.TagValue
                $costLabel   = $_.Cost.ToString('N2')
                'Currency'   = $_.Currency
            }
        }
        $script:CostByTagGrid.ItemsSource = @($rows)
    } else {
        $script:CostByTagGrid.ItemsSource = @()
        $script:NoTagsLabel.Text = "[!] No cost data returned for tag '$selectedTag'. The tag exists on resources but the Cost Management API did not return cost allocations. This can happen if the tagged resources have zero spend this month or if cost data is still processing."
    }
})

# Tag Deploy Button (handles Add, Remove, and Custom modes)
$script:TagDeployButton.Add_Click({
    $tagName = $script:tagDeployCurrentTag

    # In custom mode, read tag name from the input
    if ($script:tagCustomMode) {
        $tagName = $script:TagNameInput.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($tagName)) {
            $script:TagDeployStatus.Text = 'Please enter a tag name.'
            return
        }
        $script:tagDeployCurrentTag = $tagName
    }

    $selectedIdx = $script:TagScopeSelector.SelectedIndex

    if (-not $tagName) {
        $script:TagDeployStatus.Text = 'No tag selected.'
        return
    }
    if ($selectedIdx -lt 0) {
        $script:TagDeployStatus.Text = 'Please select a scope.'
        return
    }

    # Determine target scopes — single scope or mass removal (all scopes for a subscription)
    $allCount = if ($script:tagRemoveMode -and $script:tagRemoveAllEntries) { $script:tagRemoveAllEntries.Count } else { 0 }
    $massRemove = $script:tagRemoveMode -and ($selectedIdx -lt $allCount)

    if ($massRemove) {
        # Mass remove: gather the sub + all its RGs from the loaded scopes
        $selectedAll = $script:tagRemoveAllEntries[$selectedIdx]
        $targetScopes = @($script:tagDeployScopes | Where-Object { $_.Scope -like "/subscriptions/$($selectedAll.SubId)*" })
    } else {
        # Single scope: adjust index if in remove mode (offset by allCount)
        $adjustedIdx = if ($script:tagRemoveMode) { $selectedIdx - $allCount } else { $selectedIdx }
        if ($adjustedIdx -lt 0 -or $adjustedIdx -ge $script:tagDeployScopes.Count) {
            $script:TagDeployStatus.Text = 'Please select a scope.'
            return
        }
        $targetScopes = @($script:tagDeployScopes[$adjustedIdx])
    }

    $scope = $targetScopes[0].Scope
    $script:TagDeployButton.IsEnabled = $false

    if ($script:tagRemoveMode) {
        # REMOVE TAG (single or mass)
        $valueFilter = $script:TagValueInput.Text.Trim()
        $filterLabel = if ($valueFilter) { " (value='$valueFilter')" } else { '' }
        $script:TagDeployStatus.Text = if ($massRemove) { "Removing$filterLabel from sub, RGs, and resources..." } else { "Removing$filterLabel..." }
        $script:TagDeployStatus.Foreground = [System.Windows.Media.Brushes]::Gray

        try {
            $token = Get-PlainAccessToken
        } catch {
            $script:TagDeployStatus.Text = "Failed: Could not get access token - $($_.Exception.Message)"
            $script:TagDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
            $script:TagDeployButton.IsEnabled = $true
            return
        }

        $allScopes = $targetScopes | ForEach-Object { $_.Scope }
        $subId = if ($massRemove) { $script:tagRemoveAllEntries[$selectedIdx].SubId } else { '' }

        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript({
            param($deployScopeList, $deployTagName, $deployToken, $massMode, $subscriptionId, $valueFilter)
            $successCount = 0
            $failCount = 0
            $failMsg = ''
            $baseUri = 'https://management.azure.com'
            $hdrs = @{ 'Authorization' = "Bearer $deployToken"; 'Content-Type' = 'application/json' }

            # If mass mode, find individual resources via Resource Graph (with pagination)
            if ($massMode -and $subscriptionId) {
                try {
                    # Escape single quotes to prevent KQL injection
                    $safeTagName = $deployTagName -replace "'", "\\'"
                    $safeValueFilter = if ($valueFilter) { $valueFilter -replace "'", "\\'" } else { $null }
                    # Use case-insensitive tag lookup: enumerate tag keys and compare with tolower()
                    if ($safeValueFilter) {
                        $tagFilter = "| mv-expand bagexpansion=array tkeys = bag_keys(tags) | where tolower(tostring(tkeys)) == tolower('$safeTagName') and tags[tostring(tkeys)] == '$safeValueFilter'"
                    } else {
                        $tagFilter = "| mv-expand bagexpansion=array tkeys = bag_keys(tags) | where tolower(tostring(tkeys)) == tolower('$safeTagName')"
                    }
                    # Query both resources and resourcecontainers (sub/RG-level tags)
                    $query = "resources $tagFilter | project id | union (resourcecontainers $tagFilter | project id)"
                    $skipToken = $null
                    do {
                        $rgBody = @{
                            subscriptions = @($subscriptionId)
                            query         = $query
                            options       = @{ '$top' = 1000 }
                        }
                        if ($skipToken) { $rgBody.options['$skipToken'] = $skipToken }
                        $rgBodyJson = $rgBody | ConvertTo-Json -Depth 5
                        $rgUri = "$baseUri/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01"
                        $rgResp = Invoke-WebRequest -Uri $rgUri -Method Post -Body $rgBodyJson -Headers $hdrs `
                            -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
                        $rgData = ($rgResp.Content | ConvertFrom-Json)
                        if ($rgData.data) {
                            foreach ($row in $rgData.data) {
                                if ($row.id -and ($row.id -notin $deployScopeList)) {
                                    $deployScopeList += $row.id
                                }
                            }
                        }
                        $skipToken = $rgData.'$skipToken'
                    } while ($skipToken)
                } catch {
                    # Resource Graph query failed — continue with sub/RG scopes only
                }

                # If value filter is set, also filter sub/RG scopes — only remove from those where tag has the specific value
                if ($valueFilter) {
                    $filteredScopes = @()
                    foreach ($s in $deployScopeList) {
                        try {
                            $tagUri = "$baseUri$s/providers/Microsoft.Resources/tags/default?api-version=2021-04-01"
                            $tagResp = Invoke-WebRequest -Uri $tagUri -Method Get -Headers $hdrs `
                                -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
                            $tagData = ($tagResp.Content | ConvertFrom-Json)
                            # Case-insensitive tag name lookup
                            $matched = $false
                            if ($tagData.properties.tags) {
                                foreach ($tk in $tagData.properties.tags.PSObject.Properties) {
                                    if ($tk.Name -ieq $deployTagName -and $tk.Value -eq $valueFilter) {
                                        $matched = $true; break
                                    }
                                }
                            }
                            if ($matched) { $filteredScopes += $s }
                        } catch {
                            # Can't read tags — include scope anyway to attempt removal
                            $filteredScopes += $s
                        }
                    }
                    $deployScopeList = $filteredScopes
                }
            }

            foreach ($deployScope in $deployScopeList) {
                # Resolve the actual tag name casing from the resource to ensure exact match
                $actualTagName = $deployTagName
                try {
                    $tagCheckUri = "$baseUri$deployScope/providers/Microsoft.Resources/tags/default?api-version=2021-04-01"
                    $tagCheckResp = Invoke-WebRequest -Uri $tagCheckUri -Method Get -Headers $hdrs `
                        -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                    $tagCheckData = ($tagCheckResp.Content | ConvertFrom-Json)
                    if ($tagCheckData.properties.tags) {
                        foreach ($tk in $tagCheckData.properties.tags.PSObject.Properties) {
                            if ($tk.Name -ieq $deployTagName) {
                                $actualTagName = $tk.Name
                                break
                            }
                        }
                    }
                } catch {}

                $uri = "$baseUri$deployScope/providers/Microsoft.Resources/tags/default?api-version=2021-04-01"
                $body = @{
                    operation  = 'Delete'
                    properties = @{ tags = @{ $actualTagName = '' } }
                } | ConvertTo-Json -Depth 5
                $hdrs = @{ 'Authorization' = "Bearer $deployToken"; 'Content-Type' = 'application/json' }
                $succeeded = $false
                $lastErr = $null
                for ($retryAttempt = 0; $retryAttempt -lt 3; $retryAttempt++) {
                    try {
                        $resp = Invoke-WebRequest -Uri $uri -Method Patch -Body $body -Headers $hdrs `
                            -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
                        $successCount++
                        $succeeded = $true
                        break
                    } catch {
                        $lastErr = $_
                        $statusCode = 0
                        if ($_.Exception -is [System.Net.WebException] -and $_.Exception.Response) {
                            $statusCode = [int]$_.Exception.Response.StatusCode
                        }
                        if ($statusCode -ge 500 -and $retryAttempt -lt 2) {
                            Start-Sleep -Milliseconds (1000 * ($retryAttempt + 1))
                            continue
                        }
                    }
                }
                if (-not $succeeded) {
                    $failCount++
                    $errMsg = $lastErr.Exception.Message
                    if ($lastErr.Exception -is [System.Net.WebException] -and $lastErr.Exception.Response) {
                        try {
                            $sr = [System.IO.StreamReader]::new($lastErr.Exception.Response.GetResponseStream())
                            $errContent = $sr.ReadToEnd(); $sr.Close()
                            $errBody = $errContent | ConvertFrom-Json -ErrorAction SilentlyContinue
                            if ($errBody.error) { $errMsg = $errBody.error.message }
                        } catch {}
                    }
                    # Include the failing resource scope for diagnostics
                    $shortScope = ($deployScope -split '/')[-1]
                    if (-not $failMsg) { $failMsg = "$errMsg (resource: $shortScope)" }
                }
            }
            [PSCustomObject]@{ SuccessCount = $successCount; FailCount = $failCount; FailMsg = $failMsg }
        }).AddArgument($allScopes).AddArgument($tagName).AddArgument($token).AddArgument($massRemove).AddArgument($subId).AddArgument($valueFilter)

        $asyncResult = $ps.BeginInvoke()
        $deadline = (Get-Date).AddSeconds(300)
        while (-not $asyncResult.IsCompleted -and (Get-Date) -lt $deadline) {
            $frame = [System.Windows.Threading.DispatcherFrame]::new()
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action]{ $frame.Continue = $false }
            )
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
            Start-Sleep -Milliseconds 100
        }

        if ($asyncResult.IsCompleted) {
            try {
                $results = $ps.EndInvoke($asyncResult)
                $result = if ($results.Count -gt 0) { $results[0] } else { $null }
            } catch {
                $result = [PSCustomObject]@{ SuccessCount = 0; FailCount = 1; FailMsg = $_.Exception.Message }
            }
            if ($result -and $result.FailCount -eq 0) {
                $script:TagDeployStatus.Text = "Removed '$tagName' from $($result.SuccessCount) scope(s)"
                $script:TagDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#107C10')
                $script:actionLog.Add([PSCustomObject]@{ Time = (Get-Date -Format 'HH:mm:ss'); Type = 'Tag Removed'; Detail = "$tagName ($($result.SuccessCount) scopes)" })
            } elseif ($result -and $result.SuccessCount -gt 0) {
                $script:TagDeployStatus.Text = "Partial: $($result.SuccessCount) OK, $($result.FailCount) failed - $($result.FailMsg)"
                $script:TagDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
                $script:actionLog.Add([PSCustomObject]@{ Time = (Get-Date -Format 'HH:mm:ss'); Type = 'Tag Removed (Partial)'; Detail = "$tagName ($($result.SuccessCount) OK, $($result.FailCount) failed)" })
            } else {
                $errMsg = if ($result) { $result.FailMsg } else { 'Unknown error' }
                $script:TagDeployStatus.Text = "Failed: $errMsg"
                $script:TagDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
            }
        } else {
            $ps.Stop()
            $script:TagDeployStatus.Text = 'Failed: Removal timed out'
            $script:TagDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
        }
        $ps.Dispose()
        $rs.Close()
    } else {
        # ADD TAG
        $tagValue = $script:TagValueInput.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($tagValue)) {
            $script:TagDeployStatus.Text = 'Please enter a tag value.'
            $script:TagDeployButton.IsEnabled = $true
            return
        }

        $script:TagDeployStatus.Text = 'Deploying...'
        $script:TagDeployStatus.Foreground = [System.Windows.Media.Brushes]::Gray

        try {
            $token = Get-PlainAccessToken
        } catch {
            $script:TagDeployStatus.Text = "Failed: Could not get access token - $($_.Exception.Message)"
            $script:TagDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
            $script:TagDeployButton.IsEnabled = $true
            return
        }

        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript({
            param($deployScope, $deployTagName, $deployTagValue, $deployToken)
            $uri = "https://management.azure.com$deployScope/providers/Microsoft.Resources/tags/default?api-version=2021-04-01"
            $body = @{
                operation  = 'Merge'
                properties = @{ tags = @{ $deployTagName = $deployTagValue } }
            } | ConvertTo-Json -Depth 5
            $hdrs = @{ 'Authorization' = "Bearer $deployToken"; 'Content-Type' = 'application/json' }
            try {
                $resp = Invoke-WebRequest -Uri $uri -Method Patch -Body $body -Headers $hdrs `
                    -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
                [PSCustomObject]@{ Success = $true; Message = "Tag '$deployTagName=$deployTagValue' applied" }
            } catch {
                $errMsg = $_.Exception.Message
                if ($_.Exception -is [System.Net.WebException] -and $_.Exception.Response) {
                    try {
                        $sr = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                        $errContent = $sr.ReadToEnd(); $sr.Close()
                        $errBody = $errContent | ConvertFrom-Json -ErrorAction SilentlyContinue
                        if ($errBody.error) { $errMsg = $errBody.error.message }
                    } catch {}
                }
                [PSCustomObject]@{ Success = $false; Message = $errMsg }
            }
        }).AddArgument($scope).AddArgument($tagName).AddArgument($tagValue).AddArgument($token)

        $asyncResult = $ps.BeginInvoke()
        $deadline = (Get-Date).AddSeconds(35)
        while (-not $asyncResult.IsCompleted -and (Get-Date) -lt $deadline) {
            $frame = [System.Windows.Threading.DispatcherFrame]::new()
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action]{ $frame.Continue = $false }
            )
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
            Start-Sleep -Milliseconds 100
        }

        if ($asyncResult.IsCompleted) {
            try {
                $results = $ps.EndInvoke($asyncResult)
                $result = if ($results.Count -gt 0) { $results[0] } else { $null }
            } catch {
                $result = [PSCustomObject]@{ Success = $false; Message = $_.Exception.Message }
            }
            if ($result -and $result.Success) {
                $script:TagDeployStatus.Text = "Deployed: $tagName=$tagValue"
                $script:TagDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#107C10')
                $script:actionLog.Add([PSCustomObject]@{ Time = (Get-Date -Format 'HH:mm:ss'); Type = 'Tag Deployed'; Detail = "$tagName=$tagValue" })
            } else {
                $errMsg = if ($result) { $result.Message } else { 'Unknown error' }
                $script:TagDeployStatus.Text = "Failed: $errMsg"
                $script:TagDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
            }
        } else {
            $ps.Stop()
            $script:TagDeployStatus.Text = 'Failed: Deployment timed out after 30 seconds'
            $script:TagDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
        }
        $ps.Dispose()
        $rs.Close()
    }

    $script:TagDeployButton.IsEnabled = $true
})

# Tag Deploy Cancel Button
$script:TagDeployCancelButton.Add_Click({
    $script:TagDeployPanel.Visibility = 'Collapsed'
    $script:tagDeployCurrentTag = $null
})

# Deploy Custom Tag Button
$script:CustomTagButton.Add_Click({
    Show-CustomTagDeployPanel
})

# Policy Deploy / Unassign Button (handles both modes)
$script:PolicyDeployButton.Add_Click({
    $defId       = $script:policyDeployCurrentDefId
    $displayName = $script:policyDeployCurrentName

    if (-not $defId) {
        $script:PolicyDeployStatus.Text = 'No policy selected.'
        return
    }

    $script:PolicyDeployButton.IsEnabled = $false

    if ($script:policyUnassignMode) {
        # UNASSIGN MODE
        $targets = $script:policyUnassignTargets
        if (-not $targets -or $targets.Count -eq 0) {
            $script:PolicyDeployStatus.Text = 'No assignment found to remove.'
            $script:PolicyDeployButton.IsEnabled = $true
            return
        }

        $script:PolicyDeployStatus.Text = 'Removing assignment(s)...'
        $script:PolicyDeployStatus.Foreground = [System.Windows.Media.Brushes]::Gray

        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Render, [action]{})

        $successCount = 0
        $failMsg = ''
        foreach ($assignment in $targets) {
            try {
                $result = Remove-PolicyAssignment -AssignmentId $assignment.AssignmentId
                if ($result.Success) {
                    $successCount++
                } else {
                    $failMsg = $result.Message
                }
            } catch {
                $failMsg = $_.Exception.Message
            }
        }

        if ($successCount -eq $targets.Count) {
            $script:PolicyDeployStatus.Text = "Unassigned: $displayName ($successCount assignment(s) removed)"
            $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#107C10')
            $script:actionLog.Add([PSCustomObject]@{ Time = (Get-Date -Format 'HH:mm:ss'); Type = 'Policy Unassigned'; Detail = "$displayName ($successCount removed)" })
        } elseif ($successCount -gt 0) {
            $script:PolicyDeployStatus.Text = "Partial: $successCount of $($targets.Count) removed. Last error: $failMsg"
            $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
        } else {
            $script:PolicyDeployStatus.Text = "Failed: $failMsg"
            $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
        }
    } else {
        # DEPLOY MODE
        $effect      = $script:PolicyEffectSelector.SelectedItem
        $selectedIdx = $script:PolicyScopeSelector.SelectedIndex

        if (-not $effect) {
            $script:PolicyDeployStatus.Text = 'Please select an effect.'
            $script:PolicyDeployButton.IsEnabled = $true
            return
        }
        if ($selectedIdx -lt 0 -or $selectedIdx -ge $script:policyDeployScopes.Count) {
            $script:PolicyDeployStatus.Text = 'Please select a scope.'
            $script:PolicyDeployButton.IsEnabled = $true
            return
        }

        $scope = $script:policyDeployScopes[$selectedIdx].Scope

        # Collect dynamic parameter values
        $additionalParams = @{}
        if ($script:policyParamTextBoxes -and $script:policyParamTextBoxes.Count -gt 0) {
            foreach ($key in $script:policyParamTextBoxes.Keys) {
                $entry = $script:policyParamTextBoxes[$key]
                $val = $entry.TextBox.Text.Trim()
                $paramDef = $entry.Param
                if ($paramDef.Required -and [string]::IsNullOrWhiteSpace($val)) {
                    $script:PolicyDeployStatus.Text = "Required parameter missing: $($paramDef.Label -replace ' \*$','')"
                    $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
                    $script:PolicyDeployButton.IsEnabled = $true
                    return
                }
                if (-not [string]::IsNullOrWhiteSpace($val)) {
                    if ($paramDef.IsArray) {
                        $additionalParams[$key] = @($val -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                    } else {
                        $additionalParams[$key] = $val
                    }
                }
            }
        }

        $script:PolicyDeployStatus.Text = 'Deploying...'
        $script:PolicyDeployStatus.Foreground = [System.Windows.Media.Brushes]::Gray

        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Render, [action]{})

        try {
            $result = Deploy-PolicyAssignment -Scope $scope -PolicyDefinitionId $defId -Effect $effect -DisplayName $displayName -AdditionalParameters $additionalParams
            if ($result.Success) {
                $script:PolicyDeployStatus.Text = "Deployed: $displayName ($effect)"
                $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#107C10')
                $script:actionLog.Add([PSCustomObject]@{ Time = (Get-Date -Format 'HH:mm:ss'); Type = 'Policy Deployed'; Detail = "$displayName ($effect)" })
                if ($effect -in @('DeployIfNotExists', 'Modify')) {
                    $script:lastPolicyAssignmentScope = $scope
                    $script:lastPolicyAssignmentId = "$scope/providers/Microsoft.Authorization/policyAssignments/$($result.AssignmentName)"
                    $script:PolicyRemediateButton.Visibility = 'Visible'
                } else {
                    $script:PolicyRemediateButton.Visibility = 'Collapsed'
                }
            } else {
                $script:PolicyDeployStatus.Text = "Failed: $($result.Message)"
                $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
                $script:PolicyRemediateButton.Visibility = 'Collapsed'
            }
        } catch {
            $script:PolicyDeployStatus.Text = "Failed: $($_.Exception.Message)"
            $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
            $script:PolicyRemediateButton.Visibility = 'Collapsed'
        }
    }
    $script:PolicyDeployButton.IsEnabled = $true
})

# Policy Remediation Button
$script:PolicyRemediateButton.Add_Click({
    if (-not $script:lastPolicyAssignmentId -or -not $script:lastPolicyAssignmentScope) {
        $script:PolicyDeployStatus.Text = 'No policy assignment to remediate.'
        return
    }

    $script:PolicyRemediateButton.IsEnabled = $false
    $script:PolicyDeployStatus.Text = 'Creating remediation task...'
    $script:PolicyDeployStatus.Foreground = [System.Windows.Media.Brushes]::Gray

    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
        [System.Windows.Threading.DispatcherPriority]::Render, [action]{})

    try {
        $remResult = Start-PolicyRemediation -Scope $script:lastPolicyAssignmentScope -PolicyAssignmentId $script:lastPolicyAssignmentId
        if ($remResult.Success) {
            $script:PolicyDeployStatus.Text = $remResult.Message
            $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#107C10')
        } else {
            $script:PolicyDeployStatus.Text = "Remediation failed: $($remResult.Message)"
            $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
        }
    } catch {
        $script:PolicyDeployStatus.Text = "Remediation error: $($_.Exception.Message)"
        $script:PolicyDeployStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D83B01')
    }
    $script:PolicyRemediateButton.IsEnabled = $true
})

# Policy Deploy Cancel Button
$script:PolicyDeployCancelButton.Add_Click({
    $script:PolicyDeployPanel.Visibility = 'Collapsed'
    $script:PolicyRemediateButton.Visibility = 'Collapsed'
    $script:policyDeployCurrentDefId = $null
    $script:policyDeployCurrentName  = $null
    $script:policyUnassignMode = $false
    $script:policyUnassignTargets = @()
    # Restore visibility of scope/effect/params for next open
    $script:PolicyScopeSelector.Visibility = 'Visible'
    $script:PolicyEffectSelector.Visibility = 'Visible'
    $script:PolicyParamsPanel.Visibility = 'Visible'
    foreach ($ctrl in @($script:PolicyScopeSelector, $script:PolicyEffectSelector)) {
        $parent = $ctrl.Parent
        if ($parent) {
            $idx = $parent.Children.IndexOf($ctrl)
            if ($idx -gt 0) { $parent.Children[$idx - 1].Visibility = 'Visible' }
        }
    }
})

# Tree Selection
$script:HierarchyTree.Add_SelectedItemChanged({
    param($s, $e)
    $selected = $e.NewValue
    if (-not $selected -or -not $selected.Tag) { return }

    $info = $selected.Tag
    if ($info.Type -eq 'Sub') {
        $script:StatusText.Text = "Selected: $($info.Name) ($($info.Id))"
    }
    elseif ($info.Type -eq 'MG') {
        $script:StatusText.Text = "Management Group: $($info.Name)"
    }
})

###########################################################################
# LAUNCH
###########################################################################
Write-Host ""
Write-Host "  ========================================" -ForegroundColor Cyan
Write-Host "  AZURE FINOPS MULTITOOL" -ForegroundColor Cyan
Write-Host "  ========================================" -ForegroundColor Cyan
Write-Host "  Launching GUI..." -ForegroundColor Cyan
Write-Host ""

$window.ShowDialog() | Out-Null
