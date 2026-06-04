# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

###########################################################################
# GET-COSTEXPORT.PS1
# COST MANAGEMENT EXPORT DETECTION & FAST READ (TUI / MCP)
###########################################################################
# Purpose: Detect existing Cost Management exports (any export, not just a
#          FinOps Hub) and read their CSV data from blob storage so the MCP
#          server can serve cost tools from a pre-materialized export
#          instead of the throttle-bound live Cost Management query API.
# Author: Zac Larsen
# Date: Created for FinOps Multitool MCP generic export detection
#
# Description:
# Read-only port of the GUI scanner's export module. Supplies the same
# cost data contracts the FinOps Hub fast path provides, but sourced from
# any Cost Management export the caller has read access to:
# 1. Find-CostExport          - enumerate exports at each subscription scope
# 2. Get-CostExportData       - read the newest run's CSV into normalized rows
# 3. ConvertTo-*FromExport    - shape rows into the cost-tool data contracts
#
# Format: CSV only. Parquet exports are detected and reported but not parsed
#         natively in PowerShell.
#
# ── Parameters ──────────────────────────────────────────────
# (per-function; see each function below)
#
# Prerequisites:
# - Get-PlainAccessToken + Invoke-AzRestMethodWithRetry helpers loaded
# - Storage Blob Data Reader on the export's storage account for the read
#
# Reference: https://learn.microsoft.com/rest/api/cost-management/exports
###########################################################################

# -- Blob endpoint suffix for the active cloud ----------------------------
function Get-ExportBlobSuffix {
    param([string]$Environment = 'AzureCloud')
    switch ($Environment) {
        'AzureUSGovernment' { 'blob.core.usgovcloudapi.net' }
        'AzureChinaCloud'   { 'blob.core.chinacloudapi.cn' }
        default             { 'blob.core.windows.net' }
    }
}

# -- Storage blob data-plane REST call (list / get) -----------------------
# Uses an AAD bearer token scoped to storage.azure.com. Returns the raw
# response content (XML for list, CSV text for get) or $null on failure.
function Invoke-StorageBlobRest {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [string]$StorageToken,
        [int]$TimeoutSeconds = 60
    )
    if (-not $StorageToken) {
        try { $StorageToken = Get-PlainAccessToken -ResourceUrl 'https://storage.azure.com' }
        catch { Write-Warning "  Could not acquire storage token: $($_.Exception.Message)"; return $null }
    }
    $headers = @{
        Authorization  = "Bearer $StorageToken"
        'x-ms-version' = '2021-08-06'
    }
    try {
        return Invoke-RestMethod -Uri $Uri -Headers $headers -Method GET -TimeoutSec $TimeoutSeconds -ErrorAction Stop
    }
    catch {
        $code = $null
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        Write-Warning "  Storage request failed (HTTP $code): $Uri"
        return $null
    }
}

# -- Flat blob listing under a prefix -------------------------------------
# Lists every blob under $Prefix (no delimiter = recursive). Robust to two
# quirks: (1) Invoke-RestMethod often returns the list XML as a raw string
# (with a UTF-8 BOM) instead of an XmlDocument, so parse defensively; and
# (2) follows NextMarker so large accounts are not silently truncated.
function Get-StorageBlobList {
    param(
        [Parameter(Mandatory)][string]$BlobBase,
        [Parameter(Mandatory)][string]$Container,
        [string]$Prefix = '',
        [string]$StorageToken
    )
    $out    = [System.Collections.Generic.List[PSCustomObject]]::new()
    $marker = $null
    $listed = $false
    do {
        $listUri = "$BlobBase/$Container`?restype=container&comp=list"
        if ($Prefix) { $listUri += "&prefix=$([uri]::EscapeDataString($Prefix))" }
        if ($marker) { $listUri += "&marker=$([uri]::EscapeDataString($marker))" }
        $resp = Invoke-StorageBlobRest -Uri $listUri -StorageToken $StorageToken
        if (-not $resp) { break }
        $listed = $true

        # Normalize the response into an XmlDocument.
        $doc = $null
        if ($resp -is [System.Xml.XmlDocument]) {
            $doc = $resp
        }
        elseif ($resp -is [string]) {
            $txt = $resp
            $i = $txt.IndexOf('<?xml')
            if ($i -lt 0) { $i = $txt.IndexOf('<EnumerationResults') }
            if ($i -gt 0) { $txt = $txt.Substring($i) }
            try { $doc = New-Object System.Xml.XmlDocument; $doc.LoadXml($txt) } catch { $doc = $null }
        }
        if (-not $doc -or -not $doc.EnumerationResults) { break }

        $nodes = @()
        if ($doc.EnumerationResults.Blobs -and $doc.EnumerationResults.Blobs.Blob) {
            $nodes = @($doc.EnumerationResults.Blobs.Blob)
        }
        foreach ($b in $nodes) {
            $lm = $null
            if ($b.Properties.'Last-Modified') { try { $lm = [datetime]$b.Properties.'Last-Modified' } catch { } }
            [void]$out.Add([PSCustomObject]@{ Name = $b.Name; LastModified = $lm })
        }
        $marker = $null
        if ($doc.EnumerationResults.NextMarker) { $marker = ([string]$doc.EnumerationResults.NextMarker).Trim() }
    } while ($marker)

    return [PSCustomObject]@{ Blobs = $out; Listed = $listed }
}

# -- Decompress a gzip blob body into CSV text ----------------------------
# Newer Cost Management exports can write '.csv.gz' parts. Invoke-RestMethod
# hands these back as bytes (or a mojibake string); gunzip into UTF-8 text.
function Expand-GzipText {
    param($Content)
    try {
        $bytes = if ($Content -is [byte[]]) { $Content }
        elseif ($Content -is [string]) { [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetBytes($Content) }
        else { return $null }
        $inStream  = New-Object System.IO.MemoryStream(, $bytes)
        $gzip      = New-Object System.IO.Compression.GZipStream($inStream, [System.IO.Compression.CompressionMode]::Decompress)
        $reader    = New-Object System.IO.StreamReader($gzip, [System.Text.Encoding]::UTF8)
        $text      = $reader.ReadToEnd()
        $reader.Dispose(); $gzip.Dispose(); $inStream.Dispose()
        return $text
    }
    catch {
        Write-Warning "  Could not gunzip export part: $($_.Exception.Message)"
        return $null
    }
}

# -- Extract the first GUID from any string (bare or resource-path form) ---
function Get-GuidFromString {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $m = [regex]::Match($Value, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    if ($m.Success) { return $m.Value } else { return $null }
}

# -- Canonical export column resolver -------------------------------------
# Cost Management exports vary in schema (classic ActualCost vs FOCUS). Map
# the columns we need to whatever synonym the export actually used.
function Resolve-ExportColumns {
    param([Parameter(Mandatory)][string[]]$Header)

    $syn = @{
        Date          = @('Date', 'UsageDateTime', 'UsageDate', 'ChargePeriodStart', 'BillingPeriodStartDate')
        SubscriptionId = @('SubscriptionId', 'SubscriptionGuid', 'SubAccountId')
        SubscriptionName = @('SubscriptionName', 'SubAccountName')
        ResourceGroup = @('ResourceGroup', 'ResourceGroupName', 'x_ResourceGroupName')
        ResourceId    = @('ResourceId', 'InstanceId', 'InstanceName', 'x_ResourceId')
        ServiceName   = @('ServiceName', 'MeterCategory', 'ConsumedService', 'x_ServiceName')
        Cost          = @('CostInBillingCurrency', 'BilledCost', 'EffectiveCost', 'PreTaxCost', 'Cost', 'CostInUSD')
        Currency      = @('BillingCurrency', 'BillingCurrencyCode', 'Currency')
        Tags          = @('Tags')
    }

    # Build a case-insensitive lookup of the actual header
    $actual = @{}
    foreach ($h in $Header) { if ($h) { $actual[$h.Trim().ToLower()] = $h.Trim() } }

    $map = @{}
    foreach ($canon in $syn.Keys) {
        foreach ($candidate in $syn[$canon]) {
            $key = $candidate.ToLower()
            if ($actual.ContainsKey($key)) { $map[$canon] = $actual[$key]; break }
        }
    }
    return $map
}

# -- Parse an export Tags cell into a hashtable ---------------------------
# Handles both classic ("env": "prod", "owner": "team") and FOCUS JSON
# ({"env":"prod"}) tag encodings.
function ConvertFrom-ExportTagString {
    param([string]$Raw)
    $out = @{}
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $out }
    $text = $Raw.Trim().Trim('{', '}')
    foreach ($m in [regex]::Matches($text, '"([^"]+)"\s*:\s*"([^"]*)"')) {
        $k = $m.Groups[1].Value
        $v = $m.Groups[2].Value
        if ($k) { $out[$k] = $v }
    }
    return $out
}

# -- Discover configured Cost Management Exports --------------------------
# Enumerates exports at each selected subscription scope. Returns one
# descriptor per export plus its newest run date (for the freshness prompt).
function Find-CostExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Subscriptions,
        [string]$Environment = 'AzureCloud'
    )

    $apiVer = '2023-08-01'
    $found  = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($sub in $Subscriptions) {
        $scope = "/subscriptions/$($sub.Id)"
        $path  = "$scope/providers/Microsoft.CostManagement/exports?api-version=$apiVer"
        $resp  = Invoke-AzRestMethodWithRetry -Path $path -Method GET
        if (-not $resp -or $resp.StatusCode -ne 200) { continue }

        $list = $null
        try { $list = ($resp.Content | ConvertFrom-Json).value } catch { continue }
        if (-not $list) { continue }

        foreach ($exp in $list) {
            $def    = $exp.properties.definition
            $dest   = $exp.properties.deliveryInfo.destination
            $format = if ($exp.properties.format) { $exp.properties.format } else { 'Csv' }

            # Resolve the latest run date from run history (best-effort)
            $lastRun = $null
            try {
                $rhPath = "$scope/providers/Microsoft.CostManagement/exports/$($exp.name)/runHistory?api-version=$apiVer"
                $rh = Invoke-AzRestMethodWithRetry -Path $rhPath -Method GET
                if ($rh -and $rh.StatusCode -eq 200) {
                    $runs = ($rh.Content | ConvertFrom-Json).value
                    if ($runs) {
                        $dates = $runs | ForEach-Object {
                            $p = $_.properties
                            if ($p.processingEndTime) { [datetime]$p.processingEndTime }
                            elseif ($p.submittedTime) { [datetime]$p.submittedTime }
                        } | Where-Object { $_ } | Sort-Object -Descending
                        if ($dates) { $lastRun = $dates[0] }
                    }
                }
            }
            catch { }

            [void]$found.Add([PSCustomObject]@{
                Name              = $exp.name
                SubId             = $sub.Id
                SubName           = $sub.Name
                Scope             = $scope
                Type              = $def.type
                Granularity       = $def.dataSet.granularity
                Format            = $format
                Partitioned       = [bool]$exp.properties.partitionData
                StorageResourceId = $dest.resourceId
                Container         = $dest.container
                RootFolder        = $dest.rootFolderPath
                LastRunDate       = $lastRun
            })
        }
    }

    return $found
}

# -- Read an export's newest CSV data into normalized rows ----------------
# Lists blobs under the export's folder, locates the newest run, downloads
# the CSV (or manifest-referenced CSV parts), and returns normalized rows.
function Get-CostExportData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Export,
        [string]$Environment = 'AzureCloud'
    )

    if ($Export.Format -and $Export.Format -notmatch 'csv') {
        Write-Warning "  Export '$($Export.Name)' is $($Export.Format) format - CSV required."
        return [PSCustomObject]@{ Rows = @(); DataDate = $null; Currency = 'USD'; Unsupported = $true }
    }

    # Parse the storage account name from its ARM resource id
    if ($Export.StorageResourceId -notmatch '/storageAccounts/([^/]+)') {
        Write-Warning "  Could not parse storage account from export destination."
        return [PSCustomObject]@{ Rows = @(); DataDate = $null; Currency = 'USD' }
    }
    $account   = $Matches[1]
    $suffix    = Get-ExportBlobSuffix -Environment $Environment
    $blobBase  = "https://$account.$suffix"
    $container = $Export.Container
    $root      = ($Export.RootFolder).Trim('/')

    $token = $null
    try { $token = Get-PlainAccessToken -ResourceUrl 'https://storage.azure.com' }
    catch { Write-Warning "  Storage token error: $($_.Exception.Message)"; return [PSCustomObject]@{ Rows = @(); DataDate = $null; Currency = 'USD' } }

    # Export layouts vary:
    #   Standard Cost Management export : {root}/{name}/{dateRange}/{runId}/*.csv
    #   FinOps Hub (manifest) export    : subscriptions/{subId}/{name}/{dateRange}/{runTs}/{runId}/*.csv
    # Try progressively looser prefixes until CSV data blobs are found. The
    # subscription-scoped path is tried first so we don't accidentally pick up
    # a different export's data from a whole-container scan.
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($Export.SubId) { [void]$candidates.Add("subscriptions/$($Export.SubId)/$($Export.Name)/") }
    if ($root) {
        [void]$candidates.Add("$root/$($Export.Name)/")
        [void]$candidates.Add("$root/")
    }
    [void]$candidates.Add("$($Export.Name)/")
    [void]$candidates.Add('')

    $blobs      = [System.Collections.Generic.List[PSCustomObject]]::new()
    $csvBlobs   = @()
    $usedPrefix = $null
    $anyListed  = $false
    $seen       = @{}
    foreach ($prefix in $candidates) {
        if ($seen.ContainsKey($prefix)) { continue }
        $seen[$prefix] = $true

        $listed = Get-StorageBlobList -BlobBase $blobBase -Container $container -Prefix $prefix -StorageToken $token
        if ($listed.Listed) { $anyListed = $true }
        $blobs = $listed.Blobs

        $csvBlobs = @($blobs | Where-Object { $_.Name -match '\.csv(\.gz)?$' })
        if ($csvBlobs.Count -gt 0) { $usedPrefix = $prefix; break }
    }

    if (-not $anyListed) {
        Write-Warning "  Could not list export blobs (storage access denied? needs Storage Blob Data Reader)."
        return [PSCustomObject]@{ Rows = @(); DataDate = $null; Currency = 'USD'; AccessDenied = $true }
    }

    if ($csvBlobs.Count -eq 0) {
        $hasParquet = @($blobs | Where-Object { $_.Name -match '\.parquet$' }).Count -gt 0
        $reason = if ($hasParquet) { 'Export writes Parquet, not CSV. Recreate the export with CSV format.' }
        else { "No CSV data blobs found for export '$($Export.Name)' in container '$container'." }
        Write-Warning "  $reason"
        return [PSCustomObject]@{ Rows = @(); DataDate = $null; Currency = 'USD'; Unsupported = $hasParquet; Reason = $reason; NoData = $true }
    }

    $newest = ($csvBlobs | Sort-Object LastModified -Descending | Select-Object -First 1)
    # A partitioned export writes multiple CSV parts in the same run folder.
    # Group by the run folder (everything up to the last '/') of the newest blob.
    $runFolder = ($newest.Name -replace '/[^/]+$', '/')
    $runParts  = @($csvBlobs | Where-Object { $_.Name -like "$runFolder*" })
    if ($runParts.Count -eq 0) { $runParts = @($newest) }

    $dataDate = ($runParts | Sort-Object LastModified -Descending | Select-Object -First 1).LastModified

    # Download + parse each CSV part
    $rows        = [System.Collections.Generic.List[object]]::new()
    $colMap      = $null
    $firstHeader = @()
    foreach ($part in $runParts) {
        $blobUri = "$blobBase/$container/$([uri]::EscapeUriString($part.Name))"
        $raw = Invoke-StorageBlobRest -Uri $blobUri -StorageToken $token
        if (-not $raw) { continue }
        $csvText = $null
        if ($part.Name -match '\.gz$') {
            $csvText = Expand-GzipText -Content $raw
        }
        elseif ($raw -is [byte[]]) { $csvText = [System.Text.Encoding]::UTF8.GetString($raw) }
        else { $csvText = $raw }
        if (-not $csvText) { continue }

        $parsed = @($csvText | ConvertFrom-Csv)
        if ($parsed.Count -eq 0) { continue }
        if (-not $colMap) {
            $firstHeader = @($parsed[0].PSObject.Properties.Name)
            $colMap = Resolve-ExportColumns -Header $firstHeader
        }
        foreach ($r in $parsed) { [void]$rows.Add($r) }
    }

    # Determine currency from the first row that has one
    $currency = 'USD'
    if ($colMap -and $colMap.Currency) {
        $c = ($rows | Where-Object { $_.$($colMap.Currency) } | Select-Object -First 1)
        if ($c) { $currency = $c.$($colMap.Currency) }
    }

    return [PSCustomObject]@{
        Rows         = $rows
        ColMap       = $colMap
        DataDate     = $dataDate
        Currency     = $currency
        RowCount     = $rows.Count
        Headers      = $firstHeader
        NoCostColumn = ($colMap -and -not $colMap.Cost)
        NoData       = ($rows.Count -eq 0)
    }
}

# -- Internal: friendly resource type from an ARM resource id -------------
function Get-ExportResourceType {
    param([string]$ResourceId)
    if ($ResourceId -match '/providers/([^/]+/[^/]+)/[^/]+$') {
        return ($Matches[1] -replace '(?i)microsoft\.', '')
    }
    return 'Unknown'
}

# -- Converter: export rows -> Get-CostData costMap -----------------------
function ConvertTo-CostDataFromExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$ExportData,
        [Parameter(Mandatory)][object[]]$Subscriptions
    )
    $costMap = @{}
    $cm = $ExportData.ColMap
    if (-not $cm -or -not $cm.Cost) { return $costMap }

    # Map selected-sub GUIDs (lowercased) back to their canonical sub.Id key
    $guidToKey = @{}
    foreach ($s in $Subscriptions) {
        $g = Get-GuidFromString -Value "$($s.Id)"
        if ($g) { $guidToKey[$g.ToLower()] = $s.Id }
    }

    # Seed every selected sub so the UI shows them even at $0
    foreach ($s in $Subscriptions) { $costMap[$s.Id] = @{ Actual = 0; Forecast = 0; Currency = $ExportData.Currency } }

    foreach ($r in $ExportData.Rows) {
        # SubscriptionId may be a bare GUID (classic) or a /subscriptions/<guid>
        # path (FOCUS SubAccountId). Fall back to ResourceId when absent.
        $rawSub = if ($cm.SubscriptionId) { "$($r.$($cm.SubscriptionId))" } else { '' }
        if ([string]::IsNullOrWhiteSpace($rawSub) -and $cm.ResourceId) { $rawSub = "$($r.$($cm.ResourceId))" }
        $g = Get-GuidFromString -Value $rawSub
        if (-not $g) { continue }
        $key = if ($guidToKey.ContainsKey($g.ToLower())) { $guidToKey[$g.ToLower()] } else { $g }
        $cost = 0.0; [double]::TryParse("$($r.$($cm.Cost))", [ref]$cost) | Out-Null
        if (-not $costMap.ContainsKey($key)) {
            $costMap[$key] = @{ Actual = 0; Forecast = 0; Currency = $ExportData.Currency }
        }
        $costMap[$key].Actual += $cost
    }

    # Linear month-to-date projection for a sensible forecast
    $now       = Get-Date
    $daysInMo  = [DateTime]::DaysInMonth($now.Year, $now.Month)
    $dayOfMo   = [math]::Max(1, $now.Day)
    foreach ($k in @($costMap.Keys)) {
        $costMap[$k].Actual = [math]::Round($costMap[$k].Actual, 2)
        $costMap[$k].Forecast = [math]::Round($costMap[$k].Actual / $dayOfMo * $daysInMo, 2)
    }
    return $costMap
}

# -- Converter: export rows -> Get-ResourceCosts rows ---------------------
function ConvertTo-ResourceCostsFromExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$ExportData,
        [Parameter(Mandatory)][object[]]$Subscriptions
    )
    $out = [System.Collections.Generic.List[PSCustomObject]]::new()
    $cm  = $ExportData.ColMap
    if (-not $cm -or -not $cm.Cost -or -not $cm.ResourceId) { return $out }

    $subNameMap = @{}
    foreach ($s in $Subscriptions) { $subNameMap[$s.Id.ToLower()] = $s.Name }

    $agg = @{}
    foreach ($r in $ExportData.Rows) {
        $rid = if ($cm.ResourceId) { "$($r.$($cm.ResourceId))".Trim() } else { '' }
        if (-not $rid) { continue }
        $cost = 0.0; [double]::TryParse("$($r.$($cm.Cost))", [ref]$cost) | Out-Null
        $key = $rid.ToLower()
        if (-not $agg.ContainsKey($key)) {
            $subId = ''
            if ($rid -match '/subscriptions/([^/]+)/') { $subId = $Matches[1].ToLower() }
            $rg = if ($cm.ResourceGroup) { "$($r.$($cm.ResourceGroup))" } else { '' }
            if (-not $rg -and $rid -match '/resourcegroups/([^/]+)/') { $rg = $Matches[1] }
            $agg[$key] = @{
                ResourcePath  = $rid
                ResourceGroup = $rg
                ResourceType  = Get-ExportResourceType -ResourceId $rid
                Subscription  = if ($subId -and $subNameMap.ContainsKey($subId)) { $subNameMap[$subId] } else { '' }
                Cost          = 0.0
            }
        }
        $agg[$key].Cost += $cost
    }

    foreach ($v in $agg.Values) {
        $c = [math]::Round($v.Cost, 2)
        [void]$out.Add([PSCustomObject]@{
            Subscription  = $v.Subscription
            ResourceGroup = $v.ResourceGroup
            ResourceType  = $v.ResourceType
            ResourcePath  = $v.ResourcePath
            Actual        = $c
            Forecast      = $c
            Currency      = $ExportData.Currency
        })
    }
    return @($out | Sort-Object Actual -Descending)
}

# -- Converter: export rows -> Get-CostByTag result -----------------------
function ConvertTo-CostByTagFromExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$ExportData,
        [hashtable]$ExistingTags = @{}
    )
    $cm = $ExportData.ColMap
    $results = @{}
    if (-not $cm -or -not $cm.Cost -or -not $cm.Tags) {
        return [PSCustomObject]@{ TagsQueried = @(); CostByTag = $results; NoTagsFound = $true; UsedTimeframe = 'Export' }
    }

    # tagKey -> ( tagValue -> cost )
    $byKey = @{}
    foreach ($r in $ExportData.Rows) {
        $raw = "$($r.$($cm.Tags))"
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        $cost = 0.0; [double]::TryParse("$($r.$($cm.Cost))", [ref]$cost) | Out-Null
        if ($cost -eq 0) { continue }
        $tags = ConvertFrom-ExportTagString -Raw $raw
        foreach ($tk in $tags.Keys) {
            $tv = $tags[$tk]
            if (-not $byKey.ContainsKey($tk)) { $byKey[$tk] = @{} }
            if (-not $byKey[$tk].ContainsKey($tv)) { $byKey[$tk][$tv] = 0.0 }
            $byKey[$tk][$tv] += $cost
        }
    }

    foreach ($tk in $byKey.Keys) {
        $vals = foreach ($tv in $byKey[$tk].Keys) {
            [PSCustomObject]@{
                TagValue = $tv
                Cost     = [math]::Round($byKey[$tk][$tv], 2)
                Currency = $ExportData.Currency
            }
        }
        $results[$tk] = @($vals | Sort-Object Cost -Descending)
    }

    return [PSCustomObject]@{
        TagsQueried   = @($byKey.Keys)
        CostByTag     = $results
        NoTagsFound   = ($byKey.Count -eq 0)
        UsedTimeframe = 'Export'
    }
}

# -- Converter: export rows -> Get-CostTrend result -----------------------
# A single export run usually covers the current billing month; trend will
# show whatever months the export's date range contains.
function ConvertTo-CostTrendFromExport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$ExportData)

    $cm = $ExportData.ColMap
    $months = [System.Collections.Generic.List[PSCustomObject]]::new()
    $bySub  = @{}
    if (-not $cm -or -not $cm.Cost -or -not $cm.Date) {
        return [PSCustomObject]@{ Months = @(); BySubscription = $bySub; HasData = $false }
    }

    $agg     = @{}   # yyyy-MM -> @{ Cost; Date }
    $subAgg  = @{}   # subId -> ( yyyy-MM -> @{ Cost; Date } )
    foreach ($r in $ExportData.Rows) {
        $dt = $null
        try { $dt = [datetime]"$($r.$($cm.Date))" } catch { continue }
        $cost = 0.0; [double]::TryParse("$($r.$($cm.Cost))", [ref]$cost) | Out-Null
        $firstOfMo = Get-Date -Year $dt.Year -Month $dt.Month -Day 1 -Hour 0 -Minute 0 -Second 0
        $key = $dt.ToString('yyyy-MM')

        if (-not $agg.ContainsKey($key)) { $agg[$key] = @{ Cost = 0.0; Date = $firstOfMo } }
        $agg[$key].Cost += $cost

        if ($cm.SubscriptionId) {
            $subId = Get-GuidFromString -Value "$($r.$($cm.SubscriptionId))"
            if ($subId) {
                if (-not $subAgg.ContainsKey($subId)) { $subAgg[$subId] = @{} }
                if (-not $subAgg[$subId].ContainsKey($key)) { $subAgg[$subId][$key] = @{ Cost = 0.0; Date = $firstOfMo } }
                $subAgg[$subId][$key].Cost += $cost
            }
        }
    }

    foreach ($entry in $agg.GetEnumerator() | Sort-Object Key) {
        [void]$months.Add([PSCustomObject]@{
            Month     = $entry.Value.Date.ToString('MMM yyyy')
            MonthDate = $entry.Value.Date
            Cost      = [math]::Round($entry.Value.Cost, 2)
            Currency  = $ExportData.Currency
        })
    }

    foreach ($subId in $subAgg.Keys) {
        $list = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($entry in $subAgg[$subId].GetEnumerator() | Sort-Object Key) {
            [void]$list.Add([PSCustomObject]@{
                Month     = $entry.Value.Date.ToString('MMM yyyy')
                MonthDate = $entry.Value.Date
                Cost      = [math]::Round($entry.Value.Cost, 2)
                Currency  = $ExportData.Currency
            })
        }
        $bySub[$subId] = @($list | Sort-Object MonthDate)
    }

    $sorted = @($months | Sort-Object MonthDate)
    return [PSCustomObject]@{
        Months         = $sorted
        BySubscription = $bySub
        HasData        = ($sorted.Count -gt 0)
    }
}

# -- Read + merge the newest CSV data across several exports ---------------
# Reads each export's newest run and concatenates the normalized rows into a
# single ExportData object. When more than one export covers the same
# subscription, only the export with the newest run date for that sub is
# kept, so overlapping exports do not double-count cost. Returns the same
# shape as Get-CostExportData (Rows / ColMap / DataDate / Currency).
function Get-MergedCostExportData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Exports,
        [string]$Environment = 'AzureCloud'
    )

    # Dedupe by subscription: keep the newest-run export per SubId so two
    # exports covering the same subscription do not double-count.
    $bestBySub = @{}
    $noSub     = [System.Collections.Generic.List[object]]::new()
    foreach ($exp in $Exports) {
        if (-not $exp) { continue }
        $sid = "$($exp.SubId)"
        if ([string]::IsNullOrWhiteSpace($sid)) { [void]$noSub.Add($exp); continue }
        $existing = $bestBySub[$sid]
        if (-not $existing) { $bestBySub[$sid] = $exp; continue }
        $a = if ($exp.LastRunDate) { [datetime]$exp.LastRunDate } else { [datetime]::MinValue }
        $b = if ($existing.LastRunDate) { [datetime]$existing.LastRunDate } else { [datetime]::MinValue }
        if ($a -gt $b) { $bestBySub[$sid] = $exp }
    }
    $chosen = @($bestBySub.Values) + @($noSub)

    $allRows  = [System.Collections.Generic.List[object]]::new()
    $colMap   = $null
    $headers  = @()
    $currency = 'USD'
    $dataDate = $null
    $readAny  = $false

    foreach ($exp in $chosen) {
        $data = Get-CostExportData -Export $exp -Environment $Environment
        if (-not $data -or $data.NoData -or -not $data.Rows -or @($data.Rows).Count -eq 0) { continue }
        $readAny = $true
        if (-not $colMap -and $data.ColMap) { $colMap = $data.ColMap; $headers = $data.Headers }
        if ($data.Currency) { $currency = $data.Currency }
        if ($data.DataDate -and (-not $dataDate -or [datetime]$data.DataDate -gt $dataDate)) { $dataDate = [datetime]$data.DataDate }
        foreach ($r in $data.Rows) { [void]$allRows.Add($r) }
    }

    return [PSCustomObject]@{
        Rows         = $allRows
        ColMap       = $colMap
        DataDate     = $dataDate
        Currency     = $currency
        RowCount     = $allRows.Count
        Headers      = $headers
        NoCostColumn = ($colMap -and -not $colMap.Cost)
        NoData       = (-not $readAny -or $allRows.Count -eq 0)
        ExportCount  = @($chosen).Count
    }
}
