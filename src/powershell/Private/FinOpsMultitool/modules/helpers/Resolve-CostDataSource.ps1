###########################################################################
# RESOLVE-COSTDATASOURCE.PS1
# COST DATA SOURCE RESOLVER (EXPORT-FIRST ROUTING)
###########################################################################
# Purpose: Decide whether cost scans should read FinOps Hub / Cost
#          Management export data (fast) or the live Cost Management API.
# Author: Zac Larsen
# Date: Created for FinOps Multitool MCP server export-first routing
#
# Description:
# Non-interactive detector used by the MCP server and the agent skill.
# It inspects the requested scope and returns a structured decision so
# the agent can take the fast path when an export is readable, or set
# expectations (and ask) before falling back to the slow API path.
#
# 1. Detects a FinOps Hub storage account via Resource Graph
# 2. Verifies the hub storage is actually readable, with a blocker reason
#    (RBAC / public access disabled / firewall deny) when it is not
# 3. Determines which subscriptions the export covers vs. those requested
# 4. Reports export freshness (latest data date)
# 5. Estimates how long the live API path would take (resource-count based)
# 6. Emits a recommendation:
#      UseHub | UseHubPartial | FixAccessThenHub      (FinOps Hub fast path)
#      UseExport | UseExportPartial                   (generic CSV export)
#      UseApi                                         (live Cost Management API)
#
# ── Parameters ──────────────────────────────────────────────
# RequestedSubscriptionIds   Subscription IDs the caller intends to scan
# TenantId                   Tenant ID (for messaging only)
#
# Prerequisites:
# - Az.ResourceGraph, Az.Storage, Az.Accounts modules
# - Search-AzGraphSafe + RunspacePool helpers loaded
# - Read access to the Hub storage account for the fast path (optional)
###########################################################################

function Resolve-CostDataSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$RequestedSubscriptionIds,

        [string]$TenantId
    )

    $requested = @($RequestedSubscriptionIds | Where-Object { $_ } | Select-Object -Unique)
    $subCount = $requested.Count

    # -- Default result (no hub found → API is the only option) -----------
    $result = [ordered]@{
        HubFound            = $false
        Hub                 = $null
        Readable            = $false
        ReadBlocker         = 'None'
        ReadBlockerDetail   = $null
        RemediationHint     = $null
        CoverageSubs        = @()
        RequestedSubs       = $requested
        CoveragePct         = 0
        Freshness           = $null
        EstimatedApiSeconds = 0
        Recommendation      = 'UseApi'
        ExportFound         = $false
        Exports             = @()
        # Online scalable path: the hub's Azure Data Explorer (Kusto) cluster,
        # discovered via Resource Graph. When present, cost scans push
        # aggregation into the engine instead of reading rows.
        KustoClusterUri     = $null
        KustoDatabase       = $null
        HubVersion          = $null
        Message             = $null
    }

    # -- Step 1: estimate the API path duration (resource-count based) -----
    # One cheap Graph query: total resources in scope. Cost queries scale
    # roughly with subscription count plus a small per-resource component.
    $resourceCount = 0
    try {
        $countQuery = 'Resources | summarize c = count()'
        $countRes = Search-AzGraphSafe -Query $countQuery -Subscription $requested -First 1
        if ($countRes -and $countRes.Data -and @($countRes.Data).Count -gt 0) {
            $resourceCount = [int]($countRes.Data[0].c)
        }
    }
    catch {
        # Non-fatal — fall back to a subscription-only estimate
    }

    # ~10s base per subscription (MG attempt + per-sub fallback + throttle
    # backoff) plus ~1s per 500 resources for the resource-cost breakdown.
    $result.EstimatedApiSeconds = [int]([math]::Ceiling(($subCount * 10) + ($resourceCount / 500.0)))

    # -- Step 2: detect a FinOps Hub via Resource Graph -------------------
    $hub = $null
    try {
        $hubQuery = @"
Resources
| where type == 'microsoft.storage/storageaccounts'
| where tags['cm-resource-parent'] contains 'Microsoft.Cloud/hubs'
| project name, resourceGroup, subscriptionId, location
"@
        $hubRes = Search-AzGraphSafe -Query $hubQuery -Subscription $requested -First 5
        if ($hubRes -and $hubRes.Data -and @($hubRes.Data).Count -gt 0) {
            $hub = @($hubRes.Data)[0]
        }
    }
    catch {
        # Detection failed — treat as no hub
    }

    if (-not $hub) {
        # No FinOps Hub in scope — fall back to detecting any Cost Management
        # export the caller can read (the generic CSV export fast path).
        $exp = Resolve-GenericExportSource -RequestedSubscriptionIds $requested
        if ($exp.ExportFound) {
            $result.ExportFound = $true
            $result.Exports = $exp.Exports
            $result.CoverageSubs = $exp.CoverageSubs
            $result.Freshness = $exp.Freshness
            $result.CoveragePct = $exp.CoveragePct
            $result.Recommendation = $exp.Recommendation
            $result.Message = $exp.Message
            return [pscustomobject]$result
        }

        $apiMin = [math]::Round($result.EstimatedApiSeconds / 60.0, 1)
        $extra = if ($exp.Message) { " $($exp.Message)" } else { '' }
        $result.Message = "No FinOps Hub found in scope. Cost scans will use the Cost Management API (~$apiMin min for $subCount subscription(s)).$extra"
        return [pscustomobject]$result
    }

    $result.HubFound = $true
    $result.Hub = [ordered]@{
        Name           = $hub.name
        ResourceGroup  = $hub.resourceGroup
        SubscriptionId = $hub.subscriptionId
        Location       = $hub.location
    }

    # -- Discover the hub's Azure Data Explorer (Kusto) cluster -----------
    # The scalable ONLINE path. The toolkit deploys the cluster alongside the
    # hub storage (same resource group) and tags it ftk-tool == 'FinOps hubs'.
    # This is the same discovery the toolkit's own ftk-hubs-connect flow uses.
    # Attached here so it flows through every return path below and the MCP
    # detect tool can advertise it without a second Resource Graph call.
    $cluster = Get-HubKustoCluster -RequestedSubscriptionIds $requested -HubResourceGroup $hub.resourceGroup
    if ($cluster -and $cluster.ClusterUri) {
        $result.KustoClusterUri = $cluster.ClusterUri
        $result.KustoDatabase = 'Hub'
        $result.HubVersion = $cluster.HubVersion
    }

    # -- Step 3: verify the hub storage is readable -----------------------
    $access = Test-HubStorageAccess -StorageAccountName $hub.name -ResourceGroupName $hub.resourceGroup
    $result.Readable = $access.Readable
    $result.ReadBlocker = $access.Blocker
    $result.ReadBlockerDetail = $access.Detail
    $result.RemediationHint = $access.Remediation

    if (-not $access.Readable) {
        $apiMin = [math]::Round($result.EstimatedApiSeconds / 60.0, 1)
        if ($result.KustoClusterUri) {
            # Storage isn't readable, but the hub's Kusto cluster is the
            # scalable path anyway - prefer it. Storage access is not required.
            $result.Recommendation = 'UseHub'
            $result.Message = "FinOps Hub '$($hub.name)' storage is not directly readable ($($access.Detail)), but its Kusto cluster ($($result.KustoClusterUri)) was found. Cost scans query the cluster directly (aggregation pushed into the engine). If you also need storage reads, $($access.Remediation)"
            return [pscustomobject]$result
        }
        $result.Recommendation = 'FixAccessThenHub'
        $result.Message = "FinOps Hub '$($hub.name)' found but not readable: $($access.Detail) $($access.Remediation) Otherwise fall back to the Cost Management API (~$apiMin min)."
        return [pscustomobject]$result
    }

    # -- Step 4: coverage (which subscriptions the export contains) -------
    $coverage = Get-HubCoverage -Context $access.Context
    $result.CoverageSubs = $coverage.Subs
    $result.Freshness = $coverage.Freshness

    $coveredRequested = @($requested | Where-Object { $coverage.Subs -contains $_ })
    if ($coverage.Subs.Count -eq 0) {
        # Coverage could not be determined — assume it covers the scope but
        # flag it so the agent can mention the uncertainty.
        $result.CoveragePct = 100
        $result.Recommendation = 'UseHub'
        $kustoNote0 = if ($result.KustoClusterUri) {
            " A FinOps Hub Kusto cluster was found ($($result.KustoClusterUri)); cost scans query it directly and push aggregation into the engine (scales to large datasets)."
        }
        else {
            ' Cost scans use the FinOps Hub storage reader (small-dataset convenience path). For large hubs, use a Kusto database (Azure Data Explorer / Fabric, or set FINOPS_HUB_KUSTO_URI for a local ftklocal emulator).'
        }
        $result.Message = "FinOps Hub '$($hub.name)' is readable. Coverage could not be confirmed from export metadata; proceeding with hub data (verify the 'as of' date in results).$kustoNote0"
        return [pscustomobject]$result
    }

    $result.CoveragePct = [int][math]::Round((($coveredRequested.Count / [double]$subCount) * 100))

    $asOf = if ($coverage.Freshness) { " as of $($coverage.Freshness)" } else { '' }
    $kustoNote = if ($result.KustoClusterUri) {
        " A FinOps Hub Kusto cluster was found ($($result.KustoClusterUri)); cost scans query it directly and push aggregation into the engine (scales to large datasets)."
    }
    else {
        ' Cost scans use the FinOps Hub storage reader (rows aggregated in PowerShell) - the small-dataset convenience path. For large hubs, use a Kusto database: an Azure Data Explorer / Fabric cluster, or set FINOPS_HUB_KUSTO_URI to a local ftklocal emulator.'
    }
    if ($coveredRequested.Count -eq $subCount) {
        $result.Recommendation = 'UseHub'
        $result.Message = "FinOps Hub '$($hub.name)' covers all $subCount requested subscription(s)$asOf.$kustoNote"
    }
    else {
        $result.Recommendation = 'UseHubPartial'
        $apiMin = [math]::Round($result.EstimatedApiSeconds / 60.0, 1)
        $result.Message = "FinOps Hub '$($hub.name)' covers $($coveredRequested.Count) of $subCount subscription(s)$asOf. Choose: hub-only (partial), full API (~$apiMin min), or hybrid (hub where covered, API for the rest).$kustoNote"
    }

    return [pscustomobject]$result
}

function Get-HubKustoCluster {
    # Discover the FinOps Hub's Azure Data Explorer (Kusto) cluster via Resource
    # Graph. Mirrors the toolkit's own ftk-hubs-connect query: the cluster is
    # tagged ftk-tool == 'FinOps hubs' and (for toolkit deployments) lives in the
    # hub's resource group. Returns @{ ClusterUri; HubVersion; ResourceGroup }
    # or $null. Read-only; failures degrade to no cluster (storage path is used).
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$RequestedSubscriptionIds,
        [string]$HubResourceGroup
    )
    try {
        $query = @"
resources
| where type =~ 'microsoft.kusto/clusters'
| where tags['ftk-tool'] == 'FinOps hubs'
| extend hubVersion = tostring(tags['ftk-version'])
| project clusterUri = tostring(properties['uri']), hubVersion, resourceGroup, subscriptionId
"@
        $res = Search-AzGraphSafe -Query $query -Subscription $RequestedSubscriptionIds -First 10
        if (-not $res -or -not $res.Data -or @($res.Data).Count -eq 0) { return $null }

        $rows = @($res.Data | Where-Object { $_.clusterUri })
        if ($rows.Count -eq 0) { return $null }

        # Prefer the cluster in the same resource group as the hub storage
        # (toolkit co-locates them); otherwise take the first FinOps hub cluster.
        $match = $null
        if ($HubResourceGroup) {
            $match = $rows | Where-Object { $_.resourceGroup -eq $HubResourceGroup } | Select-Object -First 1
        }
        if (-not $match) { $match = $rows[0] }

        return @{
            ClusterUri    = [string]$match.clusterUri
            HubVersion    = if ($match.hubVersion) { [string]$match.hubVersion } else { $null }
            ResourceGroup = [string]$match.resourceGroup
        }
    }
    catch {
        return $null
    }
}

function Test-HubStorageAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$StorageAccountName,
        [Parameter(Mandatory)][string]$ResourceGroupName
    )

    $out = @{
        Readable    = $false
        Blocker     = 'Unknown'
        Detail      = $null
        Remediation = $null
        Context     = $null
    }

    # Ensure the storage module is available before calling its cmdlets so
    # a module-load failure is not mistaken for an access problem.
    foreach ($m in @('Az.Accounts', 'Az.Storage')) {
        if (-not (Get-Module $m)) { Import-Module $m -ErrorAction SilentlyContinue }
    }
    if (-not (Get-Module 'Az.Storage')) {
        $out.Blocker = 'DependencyMissing'
        $out.Detail = 'The Az.Storage module is not installed or could not be loaded.'
        $out.Remediation = "Install it with: Install-Module Az.Storage -Scope CurrentUser"
        return $out
    }

    # Read network configuration first so blockers can be named precisely.
    $publicAccess = $null
    $defaultAction = $null
    try {
        $acct = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
        $publicAccess = $acct.PublicNetworkAccess
        $defaultAction = $acct.NetworkRuleSet.DefaultAction
    }
    catch {
        $msg = $_.Exception.Message
        if ($msg -match 'could not be loaded|not loaded|Install-Module') {
            $out.Blocker = 'DependencyMissing'
            $out.Detail = "A required module failed to load: $msg"
            $out.Remediation = 'Ensure Az.Storage and Az.Accounts are installed and importable.'
        }
        else {
            # ARM read failed — likely no reader role on the account.
            $out.Blocker = 'NoRbac'
            $out.Detail = "Cannot read the storage account ('$msg')."
            $out.Remediation = 'Grant at least Reader on the hub storage account.'
        }
        return $out
    }

    # Attempt a lightweight data-plane read to confirm true readability.
    try {
        $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount -ErrorAction Stop
        $null = Get-AzDataLakeGen2ChildItem -Context $ctx -FileSystem 'msexports' -MaxCount 1 -ErrorAction Stop
        $out.Readable = $true
        $out.Blocker = 'None'
        $out.Context = $ctx
        return $out
    }
    catch {
        $msg = $_.Exception.Message
    }

    # Classify the failure into an actionable blocker.
    if ("$publicAccess" -eq 'Disabled') {
        $out.Blocker = 'PublicAccessDisabled'
        $out.Detail = 'Public network access is disabled on the hub storage account.'
        $out.Remediation = 'Re-enable public network access (or run from an allowed private endpoint), then retry.'
    }
    elseif ($msg -match '403|AuthorizationPermissionMismatch|does not have permission|not authorized') {
        $out.Blocker = 'NoRbac'
        $out.Detail = 'You lack a data role on the hub storage account.'
        $out.Remediation = "Grant 'Storage Blob Data Reader' on the hub storage account, then retry."
    }
    elseif ("$defaultAction" -eq 'Deny' -or $msg -match '403.*firewall|network rule|not allowed to access') {
        $out.Blocker = 'NetworkDenied'
        $out.Detail = 'The hub storage firewall denied access from this network.'
        $out.Remediation = 'Add your IP to the storage firewall, or run from an allowed network/private endpoint.'
    }
    else {
        $out.Blocker = 'Unknown'
        $out.Detail = "Hub storage read failed: $msg"
        $out.Remediation = 'Verify access to the hub storage account, then retry.'
    }

    return $out
}

function Get-HubCoverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Context
    )

    $out = @{
        Subs      = @()
        Freshness = $null
    }

    # The Cost Management manifest written per export run records the export
    # scope and the data date range. Reading the newest manifest gives both
    # coverage and freshness without downloading the cost rows themselves.
    try {
        $manifests = @(Get-AzDataLakeGen2ChildItem -Context $Context -FileSystem 'msexports' -Recurse -ErrorAction Stop |
            Where-Object { -not $_.IsDirectory -and $_.Path -like '*manifest.json' })

        if ($manifests.Count -eq 0) { return $out }

        # Newest run first (run folders are timestamped in the path).
        $manifests = $manifests | Sort-Object Path -Descending

        $subs = [System.Collections.Generic.HashSet[string]]::new()
        $latestDate = $null

        # Inspect up to a handful of recent manifests to gather coverage.
        foreach ($m in ($manifests | Select-Object -First 10)) {
            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "ftk-manifest-$([guid]::NewGuid().ToString('N')).json"
            try {
                Get-AzDataLakeGen2ItemContent -Context $Context -FileSystem 'msexports' -Path $m.Path -Destination $tempFile -Force -ErrorAction Stop | Out-Null
                $json = Get-Content -Path $tempFile -Raw | ConvertFrom-Json -ErrorAction Stop

                $scope = $json.exportConfig.resourceId
                if (-not $scope) { $scope = $json.runInfo.scope }
                if ($scope -match '/subscriptions/([0-9a-f-]{36})') {
                    [void]$subs.Add($Matches[1])
                }

                $end = $json.dateRange.end
                if (-not $end) { $end = $json.runInfo.endDate }
                if ($end) {
                    try {
                        $d = [datetime]$end
                        if (-not $latestDate -or $d -gt $latestDate) { $latestDate = $d }
                    }
                    catch { }
                }
            }
            catch { }
            finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }

        $out.Subs = @($subs)
        if ($latestDate) { $out.Freshness = $latestDate.ToString('yyyy-MM-dd') }
    }
    catch {
        # Coverage stays empty (unknown) on any failure.
    }

    return $out
}

# -- Generic Cost Management export fallback ------------------------------
# When no FinOps Hub is present, look for any Cost Management export the
# caller can read (classic or FOCUS, CSV). Picks the newest-run CSV export
# per subscription (deduping overlapping exports so cost is not double
# counted), and reports coverage + freshness so the MCP server can take the
# export fast path the same way it does for a hub. CSV only — Parquet
# exports are detected and reported but not read in PowerShell.
function Resolve-GenericExportSource {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$RequestedSubscriptionIds)

    $out = @{
        ExportFound    = $false
        Exports        = @()
        CoverageSubs   = @()
        CoveragePct    = 0
        Freshness      = $null
        Recommendation = 'UseApi'
        Message        = $null
    }

    # Export module not loaded — nothing to do.
    if (-not (Get-Command Find-CostExport -ErrorAction SilentlyContinue)) { return $out }

    $requested = @($RequestedSubscriptionIds | Where-Object { $_ } | Select-Object -Unique)
    if ($requested.Count -eq 0) { return $out }
    $subCount = $requested.Count

    # Find-CostExport needs subscription objects (Id + Name). The resolver
    # only has IDs; names are not needed for detection (the MCP dispatch
    # supplies the real sub objects to the converters).
    $subObjs = $requested | ForEach-Object { [pscustomobject]@{ Id = $_; Name = $_ } }

    $exports = @()
    try { $exports = @(Find-CostExport -Subscriptions $subObjs) } catch { $exports = @() }

    # Storage-first discovery: some exports can't be found via Cost Management
    # at all from this tenant - e.g. a hub export defined at a customer's
    # management group (in the customer's tenant) and delivered cross-tenant
    # via Azure Lighthouse, which only delegates subscription scope. The
    # definition is invisible, but the blobs land in a storage account we can
    # read. Reconstruct those from the blob layout and merge (deduped).
    #
    # Always runs (not just when control plane is empty): the common
    # cross-tenant case is MIXED - control plane surfaces some subs' exports
    # while the MG-scoped hub export stays invisible. The tax is modest
    # (~1 ARM call/sub + 1 container-list/storage-acct; blob-listing only on
    # accounts that actually have an export-named container).
    if (Get-Command Find-CostExportFromStorage -ErrorAction SilentlyContinue) {
        try {
            $knownKeys = @{}
            foreach ($e in $exports) {
                if ($e.StorageResourceId -and $e.Container -and $e.Name) {
                    $knownKeys[("$($e.StorageResourceId)|$($e.Container)|$($e.Name)").ToLowerInvariant()] = $true
                }
            }
            $storageExports = @(Find-CostExportFromStorage -Subscriptions $subObjs -KnownKeys $knownKeys)
            if ($storageExports.Count -gt 0) { $exports = @($exports) + $storageExports }
        }
        catch { }
    }

    if ($exports.Count -eq 0) { return $out }

    $csv = @($exports | Where-Object { $_.Format -match 'csv' })
    if ($csv.Count -eq 0) {
        $out.Message = 'Found Cost Management export(s), but they write Parquet, which is not read in PowerShell. Recreate the export with CSV format to enable the export fast path.'
        return $out
    }

    # Dedupe by subscription: keep the newest-run CSV export per SubId so two
    # exports covering the same subscription do not double-count.
    $bestBySub = @{}
    foreach ($e in $csv) {
        $sid = "$($e.SubId)"
        if ([string]::IsNullOrWhiteSpace($sid)) { continue }
        $existing = $bestBySub[$sid]
        if (-not $existing) { $bestBySub[$sid] = $e; continue }
        $a = if ($e.LastRunDate) { [datetime]$e.LastRunDate } else { [datetime]::MinValue }
        $b = if ($existing.LastRunDate) { [datetime]$existing.LastRunDate } else { [datetime]::MinValue }
        if ($a -gt $b) { $bestBySub[$sid] = $e }
    }
    $chosen = @($bestBySub.Values)
    if ($chosen.Count -eq 0) { $chosen = $csv }

    $coverageSubs = @($chosen | ForEach-Object { "$($_.SubId)" } | Where-Object { $_ } | Select-Object -Unique)
    $coveredRequested = @($requested | Where-Object { $coverageSubs -contains $_ })

    $dates = @($chosen | ForEach-Object { $_.LastRunDate } | Where-Object { $_ } | Sort-Object -Descending)
    $freshness = if ($dates.Count -gt 0) { ([datetime]$dates[0]).ToString('yyyy-MM-dd') } else { $null }

    $out.ExportFound = $true
    $out.Exports = $chosen
    $out.CoverageSubs = $coverageSubs
    $out.Freshness = $freshness
    $out.CoveragePct = if ($subCount -gt 0) { [int][math]::Round((($coveredRequested.Count / [double]$subCount) * 100)) } else { 0 }

    $asOf = if ($freshness) { " as of $freshness" } else { '' }
    $names = (($chosen | ForEach-Object { $_.Name } | Select-Object -Unique) -join ', ')
    if ($coveredRequested.Count -ge $subCount) {
        $out.Recommendation = 'UseExport'
        $out.Message = "Cost Management export(s) [$names] cover all $subCount requested subscription(s)$asOf. Using export data (fast)."
    }
    else {
        $out.Recommendation = 'UseExportPartial'
        $out.Message = "Cost Management export(s) [$names] cover $($coveredRequested.Count) of $subCount subscription(s)$asOf. The remaining subscriptions need the live Cost Management API."
    }

    return $out
}
