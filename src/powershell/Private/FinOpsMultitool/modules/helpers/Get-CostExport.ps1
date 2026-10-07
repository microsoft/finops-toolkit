# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Private helper; the returned shape varies by export schema and is not a declared contract.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Private helper named for the collection it processes.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Accepted for signature parity across the export converter family.')]
param()

###########################################################################
# GET-COSTEXPORT.PS1
# COST MANAGEMENT EXPORT DETECTION & FAST READ
###########################################################################
# Purpose: Detect existing Cost Management exports (any export, not just a
#          FinOps Hub) and read their CSV data from blob storage so the
#          server can serve cost tools from a pre-materialized export
#          instead of the throttle-bound live Cost Management query API.
# Date: Created for FinOps Multitool generic export detection
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
        'AzureChinaCloud' { 'blob.core.chinacloudapi.cn' }
        default { 'blob.core.windows.net' }
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
    $null = Resolve-FinOpsRequestUri -Uri $Uri
    if (-not $StorageToken) {
        try { $StorageToken = Get-PlainAccessToken -ResourceUrl 'https://storage.azure.com' }
        catch { Write-Warning "  Could not acquire storage token: $($_.Exception.Message)"; return $null }
    }
    $headers = @{
        Authorization  = "Bearer $StorageToken"
        'x-ms-version' = '2021-08-06'
    }
    try {
        return Invoke-RestMethod -Uri $Uri -Headers $headers -Method GET -TimeoutSec $TimeoutSeconds -MaximumRedirection 0 -ErrorAction Stop
    }
    catch {
        $code = $null
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        Write-Warning "  Storage request failed (HTTP $code): $Uri"
        return $null
    }
}

# -- Download a blob's raw bytes (binary-safe) ----------------------------
# Invoke-RestMethod decodes a response body as text using the content-type
# charset, which corrupts binary payloads - notably '.csv.gz' parts, where the
# mangled bytes can no longer be gunzipped ("unsupported compression method").
# Use HttpClient to read the exact bytes so gzip and plain CSV both decode.
function Get-StorageBlobBytes {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [string]$StorageToken,
        [int]$TimeoutSeconds = 120
    )
    $null = Resolve-FinOpsRequestUri -Uri $Uri
    if (-not $StorageToken) {
        try { $StorageToken = Get-PlainAccessToken -ResourceUrl 'https://storage.azure.com' }
        catch { Write-Warning "  Could not acquire storage token: $($_.Exception.Message)"; return $null }
    }
    $client = $null; $handler = $null; $req = $null; $resp = $null
    try {
        $handler = [System.Net.Http.HttpClientHandler]::new()
        $handler.AllowAutoRedirect = $false
        $client = [System.Net.Http.HttpClient]::new($handler)
        $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
        $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $Uri)
        [void]$req.Headers.TryAddWithoutValidation('Authorization', "Bearer $StorageToken")
        [void]$req.Headers.TryAddWithoutValidation('x-ms-version', '2021-08-06')
        $resp = $client.SendAsync($req).GetAwaiter().GetResult()
        if (-not $resp.IsSuccessStatusCode) {
            Write-Warning "  Storage blob GET failed (HTTP $([int]$resp.StatusCode)): $Uri"
            return $null
        }
        $data = $resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        # Unary comma stops PowerShell from unrolling the byte[] into a stream
        # of individual bytes (which the caller would receive as an Object[]).
        return , $data
    }
    catch { Write-Warning "  Storage blob GET error: $($_.Exception.Message)"; return $null }
    finally {
        if ($resp) { $resp.Dispose() }
        if ($req) { $req.Dispose() }
        if ($client) { $client.Dispose() }
        elseif ($handler) { $handler.Dispose() }
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
    $out = [System.Collections.Generic.List[PSCustomObject]]::new()
    $marker = $null
    $listed = $false
    $markers = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    do {
        $listUri = "$BlobBase/$Container`?restype=container&comp=list"
        if ($Prefix) { $listUri += "&prefix=$([uri]::EscapeDataString($Prefix))" }
        if ($marker) { $listUri += "&marker=$([uri]::EscapeDataString($marker))" }
        $resp = Invoke-StorageBlobRest -Uri $listUri -StorageToken $StorageToken
        if (-not $resp) { throw 'Export blob listing failed; listing coverage is incomplete.' }
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
        if (-not $doc -or -not $doc.EnumerationResults) { throw 'Export blob listing returned invalid XML; listing coverage is incomplete.' }

        $nodes = @()
        if ($doc.EnumerationResults.Blobs -and $doc.EnumerationResults.Blobs.Blob) {
            $nodes = @($doc.EnumerationResults.Blobs.Blob)
        }
        foreach ($b in $nodes) {
            $lm = $null
            if ($b.Properties.'Last-Modified') { try { $lm = [datetime]$b.Properties.'Last-Modified' } catch {
                Write-Verbose "Non-fatal: $($_.Exception.Message)"
            } }
            [void]$out.Add([PSCustomObject]@{ Name = $b.Name; LastModified = $lm })
        }
        $marker = $null
        if ($doc.EnumerationResults.NextMarker) { $marker = ([string]$doc.EnumerationResults.NextMarker).Trim() }
        if ($marker -and (-not $markers.Add($marker) -or $markers.Count -ge 10000)) { throw 'Export blob listing pagination did not complete.' }
    } while ($marker)

    return [PSCustomObject]@{ Blobs = $out; Listed = $listed }
}

# -- List the containers in a storage account (data-plane) ----------------
# Used by storage-first discovery to find candidate export drop containers
# without a control-plane export definition (e.g. cross-tenant Lighthouse).
function Get-StorageContainerList {
    param(
        [Parameter(Mandatory)][string]$BlobBase,
        [string]$StorageToken
    )
    $out    = [System.Collections.Generic.List[string]]::new()
    $marker = $null
    $listed = $false
    $markers = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    do {
        $listUri = "$BlobBase/?comp=list"
        if ($marker) { $listUri += "&marker=$([uri]::EscapeDataString($marker))" }
        $resp = Invoke-StorageBlobRest -Uri $listUri -StorageToken $StorageToken
        if (-not $resp) { throw 'Export container listing failed; listing coverage is incomplete.' }
        $listed = $true

        $doc = $null
        if ($resp -is [System.Xml.XmlDocument]) { $doc = $resp }
        elseif ($resp -is [string]) {
            $txt = $resp
            $i = $txt.IndexOf('<?xml')
            if ($i -lt 0) { $i = $txt.IndexOf('<EnumerationResults') }
            if ($i -gt 0) { $txt = $txt.Substring($i) }
            try { $doc = New-Object System.Xml.XmlDocument; $doc.LoadXml($txt) } catch { $doc = $null }
        }
        if (-not $doc -or -not $doc.EnumerationResults) { throw 'Export container listing returned invalid XML; listing coverage is incomplete.' }

        $nodes = @()
        if ($doc.EnumerationResults.Containers -and $doc.EnumerationResults.Containers.Container) {
            $nodes = @($doc.EnumerationResults.Containers.Container)
        }
        foreach ($c in $nodes) { if ($c.Name) { [void]$out.Add([string]$c.Name) } }

        $marker = $null
        if ($doc.EnumerationResults.NextMarker) { $marker = ([string]$doc.EnumerationResults.NextMarker).Trim() }
        if ($marker -and (-not $markers.Add($marker) -or $markers.Count -ge 10000)) { throw 'Export container listing pagination did not complete.' }
    } while ($marker)

    return [PSCustomObject]@{ Containers = $out; Listed = $listed }
}

# -- Decompress a gzip blob body into CSV text ----------------------------
# Newer Cost Management exports can write '.csv.gz' parts. Invoke-RestMethod
# hands these back as bytes (or a mojibake string); gunzip into UTF-8 text.
function Expand-GzipText {
    param($Content, [long]$MaxBytes = 512MB)
    $inStream = $null; $gzip = $null; $outStream = $null
    try {
        $bytes = if ($Content -is [byte[]]) { $Content }
        elseif ($Content -is [string]) { [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetBytes($Content) }
        elseif ($Content -is [System.Collections.IEnumerable]) { [byte[]]@($Content) }
        else { return $null }
        # Read in bounded chunks (rather than StreamReader.ReadToEnd) because the
        # latter can return empty on large GZipStreams, and this also reads all
        # members of a concatenated/multi-member gzip. The ceiling stops a
        # highly compressed blob in the container from exhausting memory.
        $inStream = New-Object System.IO.MemoryStream(, $bytes)
        $gzip = New-Object System.IO.Compression.GZipStream($inStream, [System.IO.Compression.CompressionMode]::Decompress)
        $outStream = New-Object System.IO.MemoryStream
        $buffer = [byte[]]::new(81920)
        while (($read = $gzip.Read($buffer, 0, $buffer.Length)) -gt 0) {
            if (($outStream.Length + $read) -gt $MaxBytes) {
                throw "Decompressed export part exceeded the $MaxBytes byte ceiling."
            }
            $outStream.Write($buffer, 0, $read)
        }
        $outBytes = $outStream.ToArray()
        return [System.Text.Encoding]::UTF8.GetString($outBytes)
    }
    catch {
        Write-Warning "  Could not gunzip export part: $($_.Exception.Message)"
        return $null
    }
    finally {
        if ($gzip) { $gzip.Dispose() }
        if ($outStream) { $outStream.Dispose() }
        if ($inStream) { $inStream.Dispose() }
    }
}

# -- Extract the first GUID from any string (bare or resource-path form) ---
function Get-GuidFromString {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $m = [regex]::Match($Value, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    if ($m.Success) { return $m.Value } else { return $null }
}

# Export amounts are always invariant-culture. Parsing them under the operator's
# culture reads "123.45" as 12345 wherever '.' is the thousands separator.
function ConvertTo-ExportAmount {
    param([string]$Value)
    return Get-HubCostValue -Row ([pscustomobject]@{ Cost = $Value }) -Column 'Cost'
}

# -- Canonical export column resolver -------------------------------------
# Cost Management exports vary in schema (classic ActualCost vs FOCUS). Map
# the columns we need to whatever synonym the export actually used.
function Resolve-ExportColumns {
    param([Parameter(Mandatory)][string[]]$Header)

    $syn = @{
        Date             = @('Date', 'UsageDateTime', 'UsageDate', 'ChargePeriodStart', 'BillingPeriodStartDate')
        SubscriptionId   = @('SubscriptionId', 'SubscriptionGuid', 'SubAccountId')
        SubscriptionName = @('SubscriptionName', 'SubAccountName')
        ResourceGroup    = @('ResourceGroup', 'ResourceGroupName', 'x_ResourceGroupName')
        ResourceId       = @('ResourceId', 'InstanceId', 'InstanceName', 'x_ResourceId')
        ServiceName      = @('ServiceName', 'MeterCategory', 'ConsumedService', 'x_ServiceName')
        Cost             = @('BilledCost', 'CostInBillingCurrency', 'PreTaxCost', 'Cost', 'CostInUSD')
        Currency         = @('BillingCurrency', 'BillingCurrencyCode', 'Currency')
        Tags             = @('Tags')
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

function Select-CostExportData {
    param(
        [Parameter(Mandatory)][object]$ExportData,
        [object[]]$Subscriptions,
        [switch]$SkipCoverageCheck
    )

    if ($ExportData.CoverageIncomplete -or $ExportData.Unsupported -or $ExportData.NoData -or -not $ExportData.Rows) {
        throw 'Export data is unavailable or incomplete; subscription coverage cannot be verified.'
    }
    $sourceMap = $ExportData.ColMap
    if (-not $sourceMap) { $sourceMap = Resolve-ExportColumns -Header $ExportData.Rows[0].PSObject.Properties.Name }
    $resolved = Resolve-ExportColumns -Header $ExportData.Rows[0].PSObject.Properties.Name
    $costColumn = $resolved.Cost
    if (-not $costColumn -or ($costColumn -ne 'BilledCost' -and $ExportData.CostBasis -ne 'ActualCost')) {
        throw 'The export does not provide actual cost; BilledCost or an actual-cost dataset is required.'
    }
    $expected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $requestedIds = if ($Subscriptions) { @($Subscriptions | ForEach-Object { $_.Id }) } else { @($ExportData.SelectedSubscriptionIds | Where-Object { $_ }) }
    foreach ($subscriptionId in $requestedIds) {
        $parsedId = [guid]::Empty
        if (-not [guid]::TryParse([string]$subscriptionId, [ref]$parsedId)) { throw 'Invalid subscription ID; refusing to drop the export scope filter.' }
        [void]$expected.Add($parsedId.ToString())
    }
    $covered = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $rows = [System.Collections.Generic.List[object]]::new()
    $currency = $null
    # FOCUS permits a null SubAccountId on tenant-level charges such as MCA
    # purchases and refunds. They belong to no subscription, so a scoped read
    # excludes and counts them rather than failing the whole export.
    $unattributedRows = 0
    $columnMap = @{ Cost = 'Cost'; SubscriptionId = 'SubscriptionId'; Currency = 'Currency' }
    $optional = @('Date', 'SubscriptionName', 'ResourceGroup', 'ResourceId', 'ServiceName', 'Tags')
    foreach ($column in $optional) { if ($sourceMap.$column) { $columnMap[$column] = $column } }

    foreach ($row in $ExportData.Rows) {
        $rawId = if ($sourceMap.SubscriptionId) { [string]$row.($sourceMap.SubscriptionId) } else { '' }
        if (-not $rawId -and $sourceMap.ResourceId) { $rawId = [string]$row.($sourceMap.ResourceId) }
        $parsedId = [guid]::Empty
        if ($rawId -match '^/subscriptions/([0-9a-fA-F-]{36})(?:/|$)') { $rawId = $Matches[1] }
        if ([string]::IsNullOrWhiteSpace($rawId)) {
            if ($expected.Count -gt 0) { $unattributedRows++; continue }
            throw 'An export row has no subscription ID; coverage is incomplete.'
        }
        if (-not [guid]::TryParse($rawId, [ref]$parsedId)) { throw 'An export row has no valid subscription ID; coverage is incomplete.' }
        $subscriptionId = $parsedId.ToString()
        if ($expected.Count -gt 0 -and -not $expected.Contains($subscriptionId)) { continue }

        $amount = Get-HubCostValue -Row $row -Column $costColumn
        $rowCurrency = if ($costColumn -eq 'CostInUSD') { 'USD' }
        elseif ($sourceMap.Currency) { [string]$row.($sourceMap.Currency) }
        else { [string]$ExportData.Currency }
        if ([string]::IsNullOrWhiteSpace($rowCurrency)) { throw 'An export row has no billing currency; cost results are incomplete.' }
        $rowCurrency = $rowCurrency.Trim().ToUpperInvariant()
        if ($rowCurrency -notmatch '^[A-Z]{3}$' -or $rowCurrency -in @('XXX', 'XTS')) { throw 'An export row has an invalid billing currency; cost results are incomplete.' }
        if ($currency -and $currency -ne $rowCurrency) { throw 'Multiple billing currencies cannot be combined into one export cost total.' }
        $currency = $rowCurrency
        $normalized = [ordered]@{ Cost = $amount; SubscriptionId = $subscriptionId; Currency = $currency }
        foreach ($column in $optional) {
            $sourceColumn = $sourceMap.$column
            if ($sourceColumn -and $row.PSObject.Properties.Name -notcontains $sourceColumn) {
                throw "Export row schema is missing '$sourceColumn'; cost results are incomplete."
            }
            $normalized[$column] = if ($sourceColumn) { $row.$sourceColumn } else { $null }
        }
        [void]$rows.Add([pscustomobject]$normalized)
        [void]$covered.Add($subscriptionId)
    }
    if (-not $SkipCoverageCheck) {
        foreach ($subscriptionId in $expected) {
            if (-not $covered.Contains($subscriptionId)) { throw "No rows for selected subscription '$subscriptionId'; export coverage is incomplete." }
        }
    }
    $period = if ($rows.Count -gt 0) { Get-HubCostSchema -HubData $rows.ToArray() } else { @{ Period = 'Unknown'; PeriodStart = $null; PeriodEnd = $null } }
    return [pscustomobject]@{
        Rows = $rows.ToArray(); ColMap = $columnMap; Currency = $currency; DataDate = $ExportData.DataDate
        ActualPeriod = $period.Period; ActualPeriodStart = $period.PeriodStart; ActualPeriodEnd = $period.PeriodEnd
        PeriodsBySubscription = $period.PeriodsBySubscription
        RowCount = $rows.Count; NoData = ($rows.Count -eq 0); CostBasis = 'ActualCost'
        CoveredSubscriptionIds = @($covered); SelectedSubscriptionIds = @($expected)
        UnattributedRowCount = $unattributedRows
        ExportCount = $ExportData.ExportCount
        Headers = @($columnMap.Keys); NoCostColumn = $false; CoverageIncomplete = $false
    }
}

# -- Parse an export Tags cell into a hashtable ---------------------------
# Handles both classic ("env": "prod", "owner": "team") and FOCUS JSON
# ({"env":"prod"}) tag encodings.
function ConvertFrom-ExportTagString {
    param([string]$Raw)
    $out = @{}
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $out }
    $text = $Raw.Trim()
    if (-not $text.StartsWith('{')) { $text = '{' + $text + '}' }
    $parsed = $text | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    if ($parsed -isnot [System.Collections.IDictionary]) { throw 'Export tags must be a JSON object; tag cost coverage is incomplete.' }
    foreach ($property in $parsed.GetEnumerator()) {
        if ($null -ne $property.Value -and $property.Value -isnot [string]) { throw 'Export tag values must be strings; tag cost coverage is incomplete.' }
        if ($out.ContainsKey($property.Key) -and $out[$property.Key] -cne [string]$property.Value) {
            $out[$property.Key] = '(conflicting tag values)'
        }
        else { $out[$property.Key] = [string]$property.Value }
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
        [string]$Environment = 'AzureCloud',
        [switch]$SkipRunHistory,
        [switch]$IncludeManagementGroups,
        [switch]$IncludeBillingAccounts,
        [string]$TenantId
    )

    $apiVer = '2023-08-01'
    $found = [System.Collections.Generic.List[PSCustomObject]]::new()
    $scopes = [Collections.Generic.List[object]]::new()
    $selectedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($sub in $Subscriptions) {
        $subscriptionGuid = [guid]::Empty
        if (-not [guid]::TryParse([string]$sub.Id, [ref]$subscriptionGuid)) { throw 'Export discovery requires a valid selected subscription ID.' }
        if ($selectedIds.Add($subscriptionGuid.ToString())) { $scopes.Add([pscustomobject]@{ Id = "/subscriptions/$($sub.Id)"; Kind = 'Subscription'; Label = $sub.Name; SubscriptionId = $sub.Id; SubscriptionName = $sub.Name }) }
    }
    if ($IncludeManagementGroups -or $IncludeBillingAccounts) {
        $context = Get-AzContext -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($TenantId) -or -not $context -or $context.Tenant.Id -ne $TenantId -or -not $selectedIds.Count -or
            @($Subscriptions | Where-Object { $_.TenantId -ne $TenantId }).Count -gt 0) { throw 'Extended export discovery requires the verified selected tenant and subscriptions.' }
    }
    if ($IncludeManagementGroups) {
        try {
            $ancestry = Search-AzGraphSafe -Query "resourcecontainers | where type =~ 'microsoft.resources/subscriptions' | project subscriptionId, ancestors = properties.managementGroupAncestorsChain" -Subscription @($selectedIds) -First 1000 -All
            $groups = @{}
            foreach ($row in @($ancestry.Data)) {
                if (-not $selectedIds.Contains([string]$row.subscriptionId)) { continue }
                $ancestors = if ($row.ancestors -is [string]) { @($row.ancestors | ConvertFrom-Json -ErrorAction Stop) } else { @($row.ancestors) }
                foreach ($group in $ancestors) {
                    if ([string]$group.name -notmatch '^[a-zA-Z0-9_.()-]{1,90}$') { Write-Warning 'An invalid management-group ancestor was excluded from export discovery.'; continue }
                    $groups[[string]$group.name] = if ($group.displayName) { [string]$group.displayName } else { [string]$group.name }
                }
            }
            if ($groups.Count -gt 50) { Write-Warning 'Export discovery is limited to 50 selected-subscription management-group ancestors; other ancestor scopes remain unverified.' }
            foreach ($groupName in @($groups.Keys | Sort-Object | Select-Object -First 50)) {
                $scopes.Add([pscustomobject]@{ Id = "/providers/Microsoft.Management/managementGroups/$groupName"; Kind = 'ManagementGroup'; Label = "Management group: $($groups[$groupName])"; SubscriptionId = $null; SubscriptionName = $null })
            }
        }
        catch { Write-Warning "Management-group export discovery is incomplete: $($_.Exception.Message)" }
    }
    if ($IncludeBillingAccounts) {
        try {
            $billingResponse = Invoke-AzRestMethodWithRetry -Path '/providers/Microsoft.Billing/billingAccounts?api-version=2024-04-01' -Method GET
            $billingAccounts = @(foreach ($page in (Get-CostQueryResponsePage -FirstResponse $billingResponse -Context 'export billing accounts' -RootNextLink)) { ($page.Content | ConvertFrom-Json -ErrorAction Stop).value })
            $billingAccounts = @($billingAccounts | Where-Object { $_.name -match '^[a-zA-Z0-9_.():-]+$' -and $_.id -eq "/providers/Microsoft.Billing/billingAccounts/$($_.name)" })
            $billingScope = Get-FinOpsBillingScope -BillingAccounts $billingAccounts -Subscriptions $Subscriptions
            if ($billingScope.CoverageIncomplete) { Write-Warning $billingScope.Reason }
            foreach ($account in @($billingScope.Accounts)) {
                $scopes.Add([pscustomobject]@{ Id = $account.id; Kind = 'BillingAccount'; Label = "Billing account: $($account.properties.displayName)"; SubscriptionId = $null; SubscriptionName = $null })
            }
        }
        catch { Write-Warning "Billing-account export discovery is incomplete: $($_.Exception.Message)" }
    }

    $scopeIndex = 0
    foreach ($scopeRecord in $scopes) {
        $scopeIndex++
        Write-Progress -Id 71 -Activity 'Reading Cost Management export definitions' -Status "Scope $scopeIndex of $($scopes.Count): $([regex]::Replace([string]$scopeRecord.Label, '[\p{Cc}\p{Cf}]', ' '))" -PercentComplete ([int](100 * $scopeIndex / $scopes.Count))
        $scope = $scopeRecord.Id
        $path = "$scope/providers/Microsoft.CostManagement/exports?api-version=$apiVer"
        try {
            $resp = Invoke-AzRestMethodWithRetry -Path $path -Method GET
            $list = @(foreach ($page in (Get-CostQueryResponsePage -FirstResponse $resp -Context "export definitions for $($scopeRecord.Label)" -RootNextLink)) { ($page.Content | ConvertFrom-Json -ErrorAction Stop).value })
        }
        catch { Write-Warning "Export definition discovery is incomplete for $($scopeRecord.Label): $($_.Exception.Message)"; continue }
        if (-not $list) { continue }

        foreach ($exp in $list) {
            if (-not $exp -or [string]::IsNullOrWhiteSpace($exp.name) -or $exp.name -match '[/\\\x00-\x1f]' -or $exp.name -in @('.', '..')) { Write-Warning 'An export definition returned an invalid name and was not selected.'; continue }
            $def = $exp.properties.definition
            $dest = $exp.properties.deliveryInfo.destination
            $format = if ($exp.properties.format) { $exp.properties.format } else { 'Csv' }

            # Resolve the latest run date from run history (best-effort)
            $lastRun = $null
            try {
                $rhPath = "$scope/providers/Microsoft.CostManagement/exports/$([uri]::EscapeDataString($exp.name))/runHistory?api-version=$apiVer"
                if (-not $SkipRunHistory) {
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
            }
            catch {
                Write-Verbose "Non-fatal: $($_.Exception.Message)"
            }

            [void]$found.Add([PSCustomObject]@{
                    Name              = $exp.name
                    SubId             = $scopeRecord.SubscriptionId
                    SubName           = $scopeRecord.SubscriptionName
                    Scope             = $scope
                    ScopeKind         = $scopeRecord.Kind
                    ScopeLabel        = $scopeRecord.Label
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
    Write-Progress -Id 71 -Activity 'Reading Cost Management export definitions' -Completed

    return $found
}

# -- Enumerate storage accounts across the selected subscriptions ---------
# Storage-first discovery target list. Uses a control-plane list per sub so a
# cross-tenant Lighthouse hub storage account (readable via delegation) is
# surfaced even when its export definition lives in the customer tenant.
function Get-ExportStorageCandidates {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Subscriptions)

    $out = [System.Collections.Generic.List[PSCustomObject]]::new()
    $subIndex = 0
    foreach ($sub in $Subscriptions) {
        $subIndex++
        Write-Progress -Id 72 -Activity 'Listing storage accounts for export discovery' -Status "Subscription $subIndex of $($Subscriptions.Count)" -PercentComplete ([int](100 * $subIndex / $Subscriptions.Count))
        $path = "/subscriptions/$($sub.Id)/providers/Microsoft.Storage/storageAccounts?api-version=2023-01-01"
        $subscriptionGuid = [guid]::Empty
        if (-not [guid]::TryParse([string]$sub.Id, [ref]$subscriptionGuid)) { throw 'Storage discovery requires a valid selected subscription ID.' }
        try {
            $resp = Invoke-AzRestMethodWithRetry -Path $path -Method GET
            $accts = @(foreach ($page in (Get-CostQueryResponsePage -FirstResponse $resp -Context "export storage accounts for $($sub.Name)" -RootNextLink)) { ($page.Content | ConvertFrom-Json -ErrorAction Stop).value })
        }
        catch { Write-Warning ([regex]::Replace("Export storage discovery is incomplete for $($sub.Name): $($_.Exception.Message)", '[\p{Cc}\p{Cf}]', ' ')); continue }
        foreach ($a in $accts) {
            if ($a.name -cnotmatch '^[a-z0-9]{3,24}$' -or $a.id -notmatch "^/subscriptions/$([regex]::Escape([string]$sub.Id))/resourceGroups/[^/]+/providers/Microsoft\.Storage/storageAccounts/$([regex]::Escape([string]$a.name))$") {
                Write-Warning 'A storage candidate did not match the selected subscription and was excluded.'
                continue
            }
            [void]$out.Add([PSCustomObject]@{
                    Name       = $a.name
                    ResourceId = $a.id
                    SubId      = $sub.Id
                    SubName    = $sub.Name
                    Location   = $a.location
                })
        }
    }
    Write-Progress -Id 72 -Activity 'Listing storage accounts for export discovery' -Completed
    return $out
}

# -- Storage-first export discovery (cross-tenant / Lighthouse) -----------
# Some exports can't be found via Cost Management at all from this tenant -
# e.g. a hub export defined at a customer's management group (in the
# customer's tenant) and delivered cross-tenant via Azure Lighthouse, which
# only delegates subscription scope. The definition is invisible, but the
# blobs land in a storage account we can read. Reconstruct those exports from
# the blob layout so the export fast path still works. Deduped against
# control-plane results via -KnownKeys.
function Find-CostExportFromStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Subscriptions,
        [string]$Environment = 'AzureCloud',
        [hashtable]$KnownKeys,
        [object[]]$StorageAccounts
    )

    if (-not $KnownKeys) { $KnownKeys = @{} }
    $suffix = Get-ExportBlobSuffix -Environment $Environment
    $found  = [System.Collections.Generic.List[PSCustomObject]]::new()
    $seen   = @{}

    $token = $null

    # Only probe containers whose name looks like a cost-export drop. Keeps the
    # scan fast and avoids listing unrelated data (diagnostics, backups, etc.).
    $containerPattern = 'export|msexports|ingestion|finops|cost|focus'

    $stores = @(if ($PSBoundParameters.ContainsKey('StorageAccounts')) { $StorageAccounts } else { Get-ExportStorageCandidates -Subscriptions $Subscriptions })
    $selectedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($sub in $Subscriptions) { [void]$selectedIds.Add([string]$sub.Id) }
    $storeIndex = 0
    $slowResponses = $false
    foreach ($sa in $stores) {
        $storeIndex++
        # The storage token goes to this account's host, so supplied accounts get the same checks as discovered ones.
        if ([string]$sa.Name -cnotmatch '^[a-z0-9]{3,24}\z' -or -not $selectedIds.Contains([string]$sa.SubId) -or
            [string]$sa.ResourceId -notmatch "^/subscriptions/$([regex]::Escape([string]$sa.SubId))/resourceGroups/[^/]+/providers/Microsoft\.Storage/storageAccounts/$([regex]::Escape([string]$sa.Name))\z") {
            Write-Warning 'A storage candidate did not match the selected subscriptions and was skipped.'
            continue
        }
        # Narrow consoles cut off the end of the status, so running notes go in the title.
        $notes = @()
        if ($found.Count) { $notes += "$($found.Count) export$(if ($found.Count -ne 1) { 's' }) found so far" }
        if ($slowResponses) { $notes += 'some requests were throttled or timed out' }
        $activity = 'Scanning storage accounts for exports' + $(if ($notes) { " ($($notes -join '; '))" })
        Write-Progress -Id 73 -Activity $activity -Status "Storage account $storeIndex of $($stores.Count): $($sa.Name)" -PercentComplete ([int](100 * $storeIndex / $stores.Count))
        $blobBase = "https://$($sa.Name).$suffix"

        $containerNames = @()
        try {
            $containerResponse = Invoke-AzRestMethodWithRetry -Path "$($sa.ResourceId)/blobServices/default/containers?api-version=2023-01-01" -Method GET
            # 408 means the call outlived its timeout, usually while Az PowerShell retried a 429.
            if ($containerResponse.StatusCode -in 408, 429) { $slowResponses = $true }
            $containerNames = @(foreach ($page in (Get-CostQueryResponsePage -FirstResponse $containerResponse -Context "container metadata for $($sa.Name)" -RootNextLink)) {
                foreach ($item in @(($page.Content | ConvertFrom-Json -ErrorAction Stop).value)) {
                    if ([string]$item.name -match '^\$') { continue }
                    if ($item.name -cnotmatch '^[a-z0-9](?:[a-z0-9-]{1,61})[a-z0-9]\z' -or $item.name.Contains('--')) { throw 'Container metadata returned an invalid name.' }
                    [string]$item.name
                }
            })
        }
        catch {
            $metadataIssue = $_.Exception.Message
            try {
                if (-not $token) { $token = Get-PlainAccessToken -ResourceUrl 'https://storage.azure.com' }
                $containerWarning = @()
                $cl = Get-StorageContainerList -BlobBase $blobBase -StorageToken $token -WarningAction SilentlyContinue -WarningVariable containerWarning
                if (-not $cl.Listed) { throw 'Container listing could not be verified.' }
                $containerNames = @(foreach ($containerName in $cl.Containers) {
                        if ([string]$containerName -match '^\$') { continue }
                        if ($containerName -isnot [string] -or $containerName -cnotmatch '^[a-z0-9](?:[a-z0-9-]{1,61})[a-z0-9]\z' -or $containerName.Contains('--')) {
                            throw 'Container listing returned an invalid name.'
                        }
                        $containerName
                    })
            }
            catch {
                Write-Warning ([regex]::Replace("Export storage discovery for $($sa.Name) was skipped because its containers could not be listed. $($_.Exception.Message)", '[\p{Cc}\p{Cf}]', ' '))
                Write-Verbose ([regex]::Replace("Container metadata lookup: $metadataIssue", '[\p{Cc}\p{Cf}]', ' '))
                foreach ($warning in @($containerWarning)) { Write-Verbose ([regex]::Replace([string]$warning, '[\p{Cc}\p{Cf}]', ' ')) }
                continue
            }
        }
        $knownContainers = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($key in $KnownKeys.Keys) {
            $parts = [string]$key -split '\|', 4
            if ($parts.Count -ge 2 -and $parts[0] -eq $sa.ResourceId) { [void]$knownContainers.Add($parts[1]) }
        }
        $containers = @($containerNames | Where-Object { $_ -match $containerPattern -or $knownContainers.Contains($_) } | Select-Object -Unique)
        if (-not $containers.Count) { continue }
        if (-not $token) {
            try { $token = Get-PlainAccessToken -ResourceUrl 'https://storage.azure.com' }
            catch {
                Write-Warning ([regex]::Replace("Storage-first discovery could not acquire a storage token: $($_.Exception.Message)", '[\p{Cc}\p{Cf}]', ' '))
                Write-Progress -Id 73 -Activity 'Scanning storage accounts for exports' -Completed
                return $found
            }
        }

        foreach ($container in $containers) {
            $blobWarnings = @()
            try { $listed = Get-StorageBlobList -BlobBase $blobBase -Container $container -Prefix '' -StorageToken $token -WarningAction SilentlyContinue -WarningVariable blobWarnings }
            catch {
                Write-Warning ([regex]::Replace("Export discovery in $($sa.Name)/$container is incomplete: $($_.Exception.Message)", '[\p{Cc}\p{Cf}]', ' '))
                foreach ($warning in @($blobWarnings)) { Write-Verbose ([regex]::Replace([string]$warning, '[\p{Cc}\p{Cf}]', ' ')) }
                continue
            }
            if (-not $listed.Listed) { continue }
            $csvBlobs = @($listed.Blobs | Where-Object { $_.Name -match '\.(csv(\.gz)?|parquet)$' })
            if ($csvBlobs.Count -eq 0) { continue }

            # Group CSV parts by their export folder = path before the
            # {dateRange} (YYYYMMDD-YYYYMMDD) token. The segment just before the
            # date range is the export Name; everything earlier is the RootFolder.
            $groups = @{}
            foreach ($b in $csvBlobs) {
                $m = [regex]::Match($b.Name, '^(?<folder>.*?)/(?<range>\d{8}-\d{8})/')
                if (-not $m.Success) {
                    # No date-range folder: treat the directory holding the CSV
                    # as the export folder so flat layouts still surface.
                    $dir = [System.IO.Path]::GetDirectoryName($b.Name) -replace '\\', '/'
                    if (-not $dir) { continue }
                    $folder = $dir
                }
                else { $folder = $m.Groups['folder'].Value }
                if ([string]::IsNullOrWhiteSpace($folder)) { continue }
                if (-not $groups.ContainsKey($folder)) { $groups[$folder] = [System.Collections.Generic.List[PSCustomObject]]::new() }
                [void]$groups[$folder].Add($b)
            }

            foreach ($folder in $groups.Keys) {
                $segs = @($folder.Trim('/') -split '/')
                $name = $segs[-1]
                $root = if ($segs.Count -gt 1) { ($segs[0..($segs.Count - 2)] -join '/') } else { '' }

                $key = ("$($sa.ResourceId)|$container|$root|$name").ToLowerInvariant()
                if ($KnownKeys.ContainsKey($key) -or $seen.ContainsKey($key)) { continue }
                $seen[$key] = $true

                $parts   = $groups[$folder]
                $lastRun = ($parts | ForEach-Object { $_.LastModified } | Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1)
                $partitioned = (@($parts | Where-Object { $_.Name -match '/part_\d+(?:_\d+)?\.csv(?:\.gz)?$' }).Count -gt 1)

                # Infer the cost type from the folder name (best-effort, display only)
                $type = if ($name -match 'amortiz') { 'AmortizedCost' }
                elseif ($name -match 'actual') { 'ActualCost' }
                elseif ($name -match 'focus') { 'FocusCost' }
                else { 'Usage' }

                [void]$found.Add([PSCustomObject]@{
                        Name              = $name
                        SubId             = $sa.SubId
                        SubName           = $sa.SubName
                        Scope             = $sa.ResourceId
                        ScopeKind         = 'Storage'
                        ScopeLabel        = "Storage: $($sa.Name)/$container"
                        Type              = $type
                        Granularity       = 'Daily'
                        Format            = if (@($parts | Where-Object Name -Match '\.parquet$').Count) { 'Parquet' } else { 'Csv' }
                        Partitioned       = $partitioned
                        StorageResourceId = $sa.ResourceId
                        Container         = $container
                        RootFolder        = $root
                        LastRunDate       = $lastRun
                    })
            }
        }
    }
    Write-Progress -Id 73 -Activity 'Scanning storage accounts for exports' -Completed

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
    if ($Export.StorageResourceId -notmatch '^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.Storage/storageAccounts/([a-z0-9]{3,24})$') { throw 'The selected export has an invalid storage resource ID.' }
    $account = $Matches[1]
    $suffix = Get-ExportBlobSuffix -Environment $Environment
    $blobBase = "https://$account.$suffix"
    $container = [string]$Export.Container
    if ($container -cnotmatch '^[a-z0-9](?:[a-z0-9-]{1,61})[a-z0-9]\z' -or $container.Contains('--')) { throw 'The selected export has an invalid container name.' }
    $root = ([string]$Export.RootFolder).Trim('/')
    $exportName = [string]$Export.Name
    if ([string]::IsNullOrWhiteSpace($exportName) -or $exportName -match '[/\\\x00-\x1f]' -or $exportName -in @('.', '..') -or
        $root -match '(?:^|/)\.{1,2}(?:/|$)|[\\\x00-\x1f]') { throw 'The selected export has an invalid folder path.' }

    $token = $null
    try { $token = Get-PlainAccessToken -ResourceUrl 'https://storage.azure.com' }
    catch { Write-Warning "  Storage token error: $($_.Exception.Message)"; return [PSCustomObject]@{ Rows = @(); DataDate = $null; Currency = 'USD' } }

    $prefix = if ($root) { "$root/$exportName/" } else { "$exportName/" }
    $listed = Get-StorageBlobList -BlobBase $blobBase -Container $container -Prefix $prefix -StorageToken $token
    if (-not $listed.Listed) { throw 'The selected export folder could not be listed; cost coverage is incomplete.' }
    $blobs = @($listed.Blobs | Where-Object { ([string]$_.Name).StartsWith($prefix, [StringComparison]::Ordinal) })
    foreach ($blob in $blobs) {
        if ([string]$blob.Name -match '(?:^|/)\.{1,2}(?:/|$)|[\\\p{Cc}\p{Cf}]') {
            throw 'The selected export listing contains an unsafe blob path; no export data was downloaded.'
        }
    }
    $csvBlobs = @($blobs | Where-Object { $_.Name -match '\.csv(\.gz)?$' })

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
    $runParts = @($csvBlobs | Where-Object { ($_.Name -replace '/[^/]+$', '/') -ceq $runFolder })
    if ($runParts.Count -eq 0) { $runParts = @($newest) }

    # Improved exports write manifest.json beside the parts, declaring every
    # partition in the run. Without this check a run that is still being written,
    # or one whose parts are partly unreadable, would total up as if complete.
    $manifestBlob = @($blobs | Where-Object { ([string]$_.Name) -ceq ($runFolder + 'manifest.json') })[0]
    # Partitioned and run-ID folders come from exports that always write a manifest.
    $requiresManifest = [bool]$Export.Partitioned -or $runFolder -match '/[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}/$' -or
        @($runParts | Where-Object { $_.Name -match '/part_\d+(?:_\d+)?\.csv(?:\.gz)?$' }).Count -gt 0
    if (-not $manifestBlob -and $requiresManifest) {
        throw 'The export run has no manifest.json, so it might still be writing or be incomplete. No export data was read.'
    }
    if ($manifestBlob) {
        $manifestEncoded = (($manifestBlob.Name -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/')
        $manifestBytes = Get-StorageBlobBytes -Uri "$blobBase/$container/$manifestEncoded" -StorageToken $token
        if (-not $manifestBytes) { throw 'The export run manifest could not be read; cost coverage is incomplete.' }
        $manifest = $null
        try { $manifest = [System.Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json -ErrorAction Stop }
        catch { throw 'The export run manifest could not be parsed; cost coverage is incomplete.' }
        $declared = @($manifest.blobs)
        if ($declared.Count -eq 0) { throw 'The export run manifest lists no partitions; cost coverage is incomplete.' }
        $foundNames = [Collections.Generic.HashSet[string]]::new([string[]]@($runParts | ForEach-Object { [string]$_.Name }), [StringComparer]::Ordinal)
        $declaredNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $invalidDeclarations = 0
        foreach ($declaration in $declared) {
            $declaredName = ([string]$declaration.blobName).TrimStart('/')
            if ([string]::IsNullOrWhiteSpace($declaredName) -or -not $declaredNames.Add($declaredName)) { $invalidDeclarations++ }
        }
        if ($invalidDeclarations -gt 0 -or -not $declaredNames.SetEquals($foundNames)) {
            throw "The export run declares $($declared.Count) partition(s) but $($runParts.Count) readable CSV part(s) matched; cost coverage is incomplete."
        }
    }
    elseif ($runParts.Count -gt 1 -and $runFolder -match '/\d{8}-\d{8}/$' -and
        @($runParts | Where-Object { ([string]$_.Name).Substring($runFolder.Length) -notmatch ('^' + [regex]::Escape($exportName) + '_[^/]+\.csv(?:\.gz)?$') }).Count -eq 0) {
        # Legacy unpartitioned exports add a month-to-date snapshot on each run; only the newest is current.
        $runParts = @($newest)
    }

    $dataDate = ($runParts | Sort-Object LastModified -Descending | Select-Object -First 1).LastModified

    # Download + parse each CSV part
    $rows = [System.Collections.Generic.List[object]]::new()
    $colMap = $null
    $firstHeader = @()
    foreach ($part in $runParts) {
        $encodedName = (($part.Name -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/')
        $blobUri = "$blobBase/$container/$encodedName"
        $bytes = Get-StorageBlobBytes -Uri $blobUri -StorageToken $token
        if (-not $bytes) { throw "Export part '$($part.Name)' could not be read; cost coverage is incomplete." }
        $csvText = $null
        if ($part.Name -match '\.gz$') {
            $csvText = Expand-GzipText -Content $bytes
        }
        else { $csvText = [System.Text.Encoding]::UTF8.GetString($bytes) }
        if (-not $csvText) { throw "Export part '$($part.Name)' could not be decoded; cost coverage is incomplete." }

        $parsed = @($csvText | ConvertFrom-Csv -ErrorAction Stop)
        if ($parsed.Count -eq 0) { throw "Export part '$($part.Name)' contains no cost rows; coverage is unverified." }
        if (-not $colMap) {
            $firstHeader = @($parsed[0].PSObject.Properties.Name)
            $colMap = Resolve-ExportColumns -Header $firstHeader
        }
        $headerSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$firstHeader, [System.StringComparer]::OrdinalIgnoreCase)
        if (-not $headerSet.SetEquals([string[]]$parsed[0].PSObject.Properties.Name)) {
            throw 'Export part schemas differ; cost coverage is incomplete.'
        }
        foreach ($r in $parsed) { [void]$rows.Add($r) }
    }

    # Determine currency from the first row that has one
    $currency = if ($colMap.Cost -eq 'CostInUSD') { 'USD' } else { $null }
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
        CostBasis    = if ($Export.ScopeKind -eq 'Storage') { 'Unknown' } else { $Export.Type }
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
    $ExportData = Select-CostExportData -ExportData $ExportData -Subscriptions $Subscriptions
    $costMap = @{}
    $cm = $ExportData.ColMap
    if (-not $cm -or -not $cm.Cost) { return $costMap }

    # Map selected-sub GUIDs (lowercased) back to their canonical sub.Id key
    $guidToKey = @{}
    foreach ($s in $Subscriptions) {
        $g = Get-GuidFromString -Value "$($s.Id)"
        if ($g) { $guidToKey[$g.ToLower()] = $s.Id }
    }

    $skippedRows = 0
    foreach ($r in $ExportData.Rows) {
        # SubscriptionId may be a bare GUID (classic) or a /subscriptions/<guid>
        # path (FOCUS SubAccountId). Fall back to ResourceId when absent.
        $rawSub = if ($cm.SubscriptionId) { "$($r.$($cm.SubscriptionId))" } else { '' }
        if ([string]::IsNullOrWhiteSpace($rawSub) -and $cm.ResourceId) { $rawSub = "$($r.$($cm.ResourceId))" }
        $g = Get-GuidFromString -Value $rawSub
        if (-not $g) { continue }

        # An export is written at its own scope, which is usually the whole billing
        # account. A row for a subscription the user did not select is out of scope,
        # so skipping it keeps the total matching the requested scope.
        if (-not $guidToKey.ContainsKey($g.ToLower())) { $skippedRows++; continue }
        $key = $guidToKey[$g.ToLower()]

        $cost = ConvertTo-ExportAmount "$($r.$($cm.Cost))"
        if (-not $costMap.ContainsKey($key)) {
            $subscriptionPeriod = $ExportData.PeriodsBySubscription[$g]
            $costMap[$key] = @{
                Actual = 0; Forecast = $null; ForecastSource = 'Unavailable'; Currency = $ExportData.Currency
                ActualPeriod = $subscriptionPeriod.Period; ActualPeriodStart = $subscriptionPeriod.PeriodStart; ActualPeriodEnd = $subscriptionPeriod.PeriodEnd
            }
        }
        $costMap[$key].Actual += $cost
    }

    if ($skippedRows -gt 0) {
        Write-Verbose "  Export covers a wider scope: ignored $skippedRows row(s) for unselected subscriptions."
    }

    foreach ($k in @($costMap.Keys)) {
        $costMap[$k].Actual = [math]::Round($costMap[$k].Actual, 2)
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
    $ExportData = Select-CostExportData -ExportData $ExportData -Subscriptions $Subscriptions
    $out = [System.Collections.Generic.List[PSCustomObject]]::new()
    $cm = $ExportData.ColMap
    if (-not $cm.ResourceId) { throw 'Resource IDs are unavailable for part of this export; resource cost coverage is incomplete.' }

    $subNameMap = @{}
    foreach ($s in $Subscriptions) { $subNameMap[$s.Id.ToLower()] = $s.Name }

    $agg = @{}
    foreach ($r in $ExportData.Rows) {
        $rid = if ($cm.ResourceId) { "$($r.$($cm.ResourceId))".Trim() } else { '' }
        $subId = [string]$r.($cm.SubscriptionId)
        $cost = ConvertTo-ExportAmount "$($r.$($cm.Cost))"
        # Classic exports can carry a bare instance name, so the subscription has
        # to be part of the key or same-named resources would merge across them.
        $key = if ($rid) { "$subId|$($rid.ToLower())" } else { "$subId|non-resource charges" }
        if (-not $agg.ContainsKey($key)) {
            $rg = if ($cm.ResourceGroup) { "$($r.$($cm.ResourceGroup))" } else { '' }
            if (-not $rg -and $rid -match '/resourcegroups/([^/]+)/') { $rg = $Matches[1] }
            $agg[$key] = @{
                ResourcePath  = if ($rid) { $rid } else { '(non-resource charges)' }
                ResourceGroup = $rg
                ResourceType  = if ($rid) { Get-ExportResourceType -ResourceId $rid } else { 'Non-resource charge' }
                Subscription  = if ($subNameMap.ContainsKey($subId)) { $subNameMap[$subId] } else { $subId }
                ActualPeriod  = $ExportData.PeriodsBySubscription[$subId].Period
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
                Forecast      = $null
                ForecastSource = 'Unavailable'
                Currency      = $ExportData.Currency
                ActualPeriod  = $v.ActualPeriod
            })
    }
    return @($out | Sort-Object Actual -Descending)
}

# -- Converter: export rows -> Get-CostByTag result -----------------------
function ConvertTo-CostByTagFromExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$ExportData,
        [hashtable]$ExistingTags = @{},
        [object[]]$Subscriptions
    )
    $ExportData = Select-CostExportData -ExportData $ExportData -Subscriptions $Subscriptions
    $cm = $ExportData.ColMap
    $results = @{}
    if (-not $cm.Tags) { throw 'Tags are unavailable for part of this export; tag cost coverage is incomplete.' }

    # tagKey -> ( tagValue -> cost )
    $byKey = @{}
    $keys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($tagKey in $ExistingTags.Keys) { [void]$keys.Add($tagKey) }
    $tagRows = [System.Collections.Generic.List[object]]::new()
    foreach ($r in $ExportData.Rows) {
        $raw = "$($r.$($cm.Tags))"
        $cost = ConvertTo-ExportAmount "$($r.$($cm.Cost))"
        $tags = ConvertFrom-ExportTagString -Raw $raw
        if ($ExistingTags.Count -eq 0) { foreach ($tagKey in $tags.Keys) { [void]$keys.Add($tagKey) } }
        [void]$tagRows.Add(@{ Cost = $cost; Tags = $tags })
    }
    foreach ($row in $tagRows) {
        foreach ($tk in $keys) {
            $tv = if ($row.Tags.ContainsKey($tk)) { if ($row.Tags[$tk]) { $row.Tags[$tk] } else { '(empty)' } } else { '(untagged)' }
            if (-not $byKey.ContainsKey($tk)) { $byKey[$tk] = [System.Collections.Generic.Dictionary[string, double]]::new([System.StringComparer]::Ordinal) }
            if (-not $byKey[$tk].ContainsKey($tv)) { $byKey[$tk][$tv] = 0.0 }
            $byKey[$tk][$tv] += $row.Cost
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
    param(
        [Parameter(Mandatory)][object]$ExportData,
        [object[]]$Subscriptions
    )

    $ExportData = Select-CostExportData -ExportData $ExportData -Subscriptions $Subscriptions
    $cm = $ExportData.ColMap
    $months = [System.Collections.Generic.List[PSCustomObject]]::new()
    $bySub = @{}
    if (-not $cm.Date) { throw 'Dates are unavailable for part of this export; cost trend coverage is incomplete.' }

    $agg = @{}   # yyyy-MM -> @{ Cost; Date }
    $subAgg = @{}   # subId -> ( yyyy-MM -> @{ Cost; Date } )
    foreach ($r in $ExportData.Rows) {
        $dt = $null
        $rawDate = $r.($cm.Date)
        try {
            $dt = if ($rawDate -is [datetime]) { $rawDate.ToUniversalTime() }
            elseif ([string]$rawDate -match '^\d{8}$') { [datetime]::ParseExact([string]$rawDate, 'yyyyMMdd', [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime() }
            else { [datetimeoffset]::Parse([string]$rawDate, [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).UtcDateTime }
        }
        catch { throw 'An export row has an invalid date; cost trend coverage is incomplete.' }
        $cost = ConvertTo-ExportAmount "$($r.$($cm.Cost))"
        $firstOfMo = $dt.Date.AddDays(1 - $dt.Day)
        # Invariant culture keeps the key Gregorian; a Hijri or Buddhist host
        # calendar would otherwise split one month across two trend rows.
        $key = $dt.ToString('yyyy-MM', [cultureinfo]::InvariantCulture)

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
        [string]$Environment = 'AzureCloud',
        [object[]]$Subscriptions
    )

    $bestBySub = @{}
    $sourceIndex = 0
    foreach ($exp in $Exports) {
        if (-not $exp) { throw 'An export descriptor is missing; cost coverage is incomplete.' }
        $sourceIndex++
        $rawData = Get-CostExportData -Export $exp -Environment $Environment
        if (-not $rawData) { throw "Export '$($exp.Name)' could not be read; cost coverage is incomplete." }
        $data = Select-CostExportData -ExportData $rawData -Subscriptions $Subscriptions -SkipCoverageCheck
        $runDate = if ($data.DataDate) { [datetime]$data.DataDate }
        elseif ($exp.LastRunDate) { [datetime]$exp.LastRunDate }
        else { [datetime]::MinValue }
        foreach ($group in ($data.Rows | Group-Object SubscriptionId)) {
            $existing = $bestBySub[$group.Name]
            if (-not $existing -or $runDate -gt $existing.RunDate) {
                $bestBySub[$group.Name] = @{ Rows = @($group.Group); ColMap = $data.ColMap; RunDate = $runDate; SourceIndex = $sourceIndex }
            }
        }
    }

    $allRows = [System.Collections.Generic.List[object]]::new()
    $colMap = $null
    $dataDate = $null
    $usedSources = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($data in $bestBySub.Values) {
        if (-not $colMap) { $colMap = $data.ColMap.Clone() }
        else {
            foreach ($column in @($colMap.Keys)) {
                if (-not $data.ColMap.ContainsKey($column)) { $colMap.Remove($column) }
            }
        }
        if (-not $dataDate -or $data.RunDate -gt $dataDate) { $dataDate = $data.RunDate }
        [void]$usedSources.Add($data.SourceIndex)
        foreach ($row in $data.Rows) { [void]$allRows.Add($row) }
    }
    $merged = [pscustomobject]@{
        Rows = $allRows.ToArray(); ColMap = $colMap; DataDate = $dataDate; ExportCount = $usedSources.Count
        NoData = ($allRows.Count -eq 0); CostBasis = 'ActualCost'
    }
    return Select-CostExportData -ExportData $merged -Subscriptions $Subscriptions
}
