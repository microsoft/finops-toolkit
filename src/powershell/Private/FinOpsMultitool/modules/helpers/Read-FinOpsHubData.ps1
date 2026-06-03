###########################################################################
# READ-FINOPSHUBDATA.PS1
# FINOPS HUB STORAGE DATA READER
###########################################################################
# Purpose: Read cost data from a FinOps Hub storage account
# Author: Zac Larsen
# Date: Created for FinOps Multitool TUI integration
#
# Description:
# Reads FOCUS-schema cost data from a Hub storage account.
# Prefers parquet from the ingestion container (normalized FOCUS);
# falls back to CSV from msexports if ingestion is empty.
# Parquet.Net + all transitive deps are auto-installed via nuget.exe.
#
# 1. Checks ingestion container for parquet (preferred)
# 2. Falls back to msexports CSV if no parquet found
# 3. Returns FOCUS-schema cost objects for Multitool consumption
#
# ── Parameters ──────────────────────────────────────────────
# StorageAccountName   Hub storage account name
# ResourceGroupName    Resource group containing the storage account
# Months               Number of months to read (default: 1)
#
# Prerequisites:
# - Az.Storage module
# - Storage Blob Data Reader RBAC on the Hub storage account
###########################################################################

# Helper: Convert JSON to hashtable (PS 5.1 compatible — no -AsHashtable)
function ConvertTo-HashtableFromJson {
    param([string]$Json)
    $obj = $Json | ConvertFrom-Json -ErrorAction Stop
    $ht = @{}
    foreach ($p in $obj.PSObject.Properties) { $ht[$p.Name] = $p.Value }
    return $ht
}

function Install-ParquetReader {
    [CmdletBinding()]
    param()

    # Check if Parquet is already loaded in this session
    $loaded = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
        $_.GetName().Name -eq 'Parquet'
    }
    if ($loaded) { return $true }

    $parquetDir = Join-Path ([System.IO.Path]::GetTempPath()) 'FinOpsMultitool-Parquet'
    $markerFile = Join-Path $parquetDir '.installed'

    # If all DLLs were previously installed, just load them
    if (Test-Path $markerFile) {
        try {
            Import-ParquetAssemblies -BasePath $parquetDir
            return $true
        }
        catch {
            # Corrupt install — wipe and redo
            Remove-Item $parquetDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "    Installing Parquet reader (one-time setup)..." -ForegroundColor DarkGray

    try {
        New-Item -ItemType Directory -Path $parquetDir -Force | Out-Null

        # Download nuget.exe if needed
        $nugetExe = Join-Path $parquetDir 'nuget.exe'
        if (-not (Test-Path $nugetExe)) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nugetExe -UseBasicParsing
        }

        # Use nuget.exe to resolve ALL transitive dependencies
        $pkgDir = Join-Path $parquetDir 'packages'
        & $nugetExe install Parquet.Net -Version 4.24.0 -OutputDirectory $pkgDir -Framework net8.0 2>&1 | Out-Null

        # Copy managed DLLs to flat directory (prefer net8.0 > net6.0 > netstandard2.0)
        $libDir = Join-Path $parquetDir 'lib'
        New-Item -ItemType Directory -Path $libDir -Force | Out-Null

        $fxPriority = @('net8.0', 'net6.0', 'netstandard2.1', 'netstandard2.0')
        $packages = Get-ChildItem $pkgDir -Directory
        foreach ($pkg in $packages) {
            $libRoot = Join-Path $pkg.FullName 'lib'
            if (-not (Test-Path $libRoot)) { continue }
            $copied = $false
            foreach ($fx in $fxPriority) {
                $fxDir = Join-Path $libRoot $fx
                if (Test-Path $fxDir) {
                    Get-ChildItem $fxDir -Filter '*.dll' | ForEach-Object {
                        Copy-Item $_.FullName $libDir -Force
                    }
                    $copied = $true
                    break
                }
            }
            # Copy native runtimes (IronCompress needs nironcompress.dll)
            $nativeDir = Join-Path $pkg.FullName 'runtimes\win-x64\native'
            if (Test-Path $nativeDir) {
                $targetNative = Join-Path $parquetDir 'runtimes\win-x64\native'
                New-Item -ItemType Directory -Path $targetNative -Force | Out-Null
                Get-ChildItem $nativeDir -Filter '*.dll' | ForEach-Object {
                    Copy-Item $_.FullName $targetNative -Force
                }
            }
        }

        # Write marker so next session skips the nuget step
        'installed' | Set-Content $markerFile

        Import-ParquetAssemblies -BasePath $parquetDir
        Write-Host "    Parquet reader installed." -ForegroundColor DarkGray
        return $true
    }
    catch {
        Write-Warning "Failed to install Parquet reader: $($_.Exception.Message)"
        return $false
    }
}

function Import-ParquetAssemblies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BasePath
    )

    $libDir = Join-Path $BasePath 'lib'

    # Load order matters — dependencies before dependents
    $loadOrder = @(
        'System.Buffers.dll'
        'System.Memory.dll'
        'System.Runtime.CompilerServices.Unsafe.dll'
        'System.Collections.Immutable.dll'
        'Microsoft.IO.RecyclableMemoryStream.dll'
        'ZstdSharp.dll'
        'Snappier.dll'
        'IronCompress.dll'
        'Apache.Arrow.dll'
        'Microsoft.ML.DataView.dll'
        'Microsoft.Data.Analysis.dll'
        'Parquet.dll'
    )

    foreach ($dll in $loadOrder) {
        $path = Join-Path $libDir $dll
        if (-not (Test-Path $path)) { continue }

        $asmName = [IO.Path]::GetFileNameWithoutExtension($dll)
        $already = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
            $_.GetName().Name -eq $asmName
        }
        if ($already) { continue }

        try {
            Add-Type -Path $path -ErrorAction Stop
        }
        catch {
            # Swallow if the runtime already provides this assembly
            $recheck = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {
                $_.GetName().Name -eq $asmName
            }
            if (-not $recheck) { throw }
        }
    }
}

function Read-ParquetFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $table = [Parquet.ParquetReader]::ReadTableFromFileAsync($Path, $null).GetAwaiter().GetResult()
        if (-not $table -or $table.Count -eq 0) { return @() }

        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        $colNames = @($table.Schema.GetDataFields() | ForEach-Object { $_.Name })

        for ($i = 0; $i -lt $table.Count; $i++) {
            $obj = [ordered]@{}
            foreach ($colName in $colNames) {
                $col = $table[$colName]
                $obj[$colName] = if ($col -and $i -lt $col.Data.Length) { $col.Data[$i] } else { $null }
            }
            $results.Add([PSCustomObject]$obj)
        }

        return $results
    }
    catch {
        Write-Warning "Failed to read parquet file $Path`: $($_.Exception.Message)"
        return @()
    }
}

function Read-FinOpsHubData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StorageAccountName,

        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter()]
        [int]$Months = 1
    )

    Write-Host "    Connecting to Hub storage: $StorageAccountName" -ForegroundColor DarkGray

    try {
        $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount -ErrorAction Stop
    }
    catch {
        Write-Host "    Failed to connect to Hub storage: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }

    $allData = [System.Collections.Generic.List[PSCustomObject]]::new()
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "FinOpsHub-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        # -- Strategy 1: Parquet from ingestion (normalized FOCUS) ---------
        $now = Get-Date
        for ($m = 0; $m -lt $Months; $m++) {
            $d = $now.AddMonths(-$m)
            $basePath = "Costs/$($d.ToString('yyyy'))/$($d.ToString('MM'))"
            try {
                $blobs = @(Get-AzDataLakeGen2ChildItem -Context $ctx -FileSystem 'ingestion' -Path $basePath -Recurse -ErrorAction Stop |
                    Where-Object { -not $_.IsDirectory -and $_.Name -like '*.parquet' })

                if ($blobs.Count -gt 0) {
                    # Install parquet reader on first parquet file encountered
                    if ($allData.Count -eq 0) {
                        $hasParquet = Install-ParquetReader
                        if (-not $hasParquet) {
                            Write-Warning "Parquet reader failed — falling back to CSV exports"
                            break
                        }
                    }

                    Write-Host "    Reading ingestion: $basePath ($($blobs.Count) file(s))" -ForegroundColor DarkGray
                    foreach ($blob in $blobs) {
                        $localFile = Join-Path $tempDir "$([guid]::NewGuid().ToString('N')).parquet"
                        try {
                            Get-AzDataLakeGen2ItemContent -Context $ctx -FileSystem 'ingestion' -Path $blob.Path -Destination $localFile -Force -ErrorAction Stop | Out-Null
                            $rows = Read-ParquetFile -Path $localFile
                            if ($rows -and @($rows).Count -gt 0) {
                                foreach ($row in $rows) { $allData.Add($row) }
                                Write-Host "    Loaded $(@($rows).Count) rows from $(Split-Path $blob.Path -Leaf)" -ForegroundColor DarkGray
                            }
                        }
                        finally {
                            Remove-Item $localFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
            catch {
                # Path doesn't exist yet — that's OK
            }
        }

        # -- Strategy 2: CSV from msexports (raw FOCUS export) -------------
        if ($allData.Count -eq 0) {
            Write-Host "    No parquet in ingestion — reading CSV from msexports..." -ForegroundColor DarkGray

            $csvBlobs = @(Get-AzDataLakeGen2ChildItem -Context $ctx -FileSystem 'msexports' -Recurse -ErrorAction SilentlyContinue |
                Where-Object { -not $_.IsDirectory -and $_.Path -like '*.csv' })

            if ($csvBlobs.Count -gt 0) {
                # Export layout is: .../<billingPeriod>/<runTimestamp>/<guid>/part_*.csv
                # where billingPeriod = yyyyMMdd-yyyyMMdd and runTimestamp = 12 digits.
                # Group by billing period, and within each period keep only the latest
                # run. Walking periods newest-first and skipping empty ones means a
                # just-started current month (header-only export) falls back to the
                # latest populated period instead of returning nothing.
                $periods = [ordered]@{}
                foreach ($blob in $csvBlobs) {
                    $period = [regex]::Match($blob.Path, '(\d{8}-\d{8})').Value
                    $run = [regex]::Match($blob.Path, '[\\/](\d{12})[\\/]').Groups[1].Value
                    if (-not $period) { $period = Split-Path (Split-Path $blob.Path -Parent) -Parent }
                    if (-not $periods.Contains($period)) {
                        $periods[$period] = @{ Runs = [ordered]@{} }
                    }
                    if (-not $periods[$period].Runs.Contains($run)) {
                        $periods[$period].Runs[$run] = [System.Collections.Generic.List[object]]::new()
                    }
                    $periods[$period].Runs[$run].Add($blob)
                }

                # Newest billing period first.
                $orderedPeriods = $periods.Keys | Sort-Object -Descending
                $periodsLoaded = 0

                foreach ($period in $orderedPeriods) {
                    if ($periodsLoaded -ge $Months) { break }

                    # Latest run within this period.
                    $latestRunKey = $periods[$period].Runs.Keys | Sort-Object -Descending | Select-Object -First 1
                    $runBlobs = $periods[$period].Runs[$latestRunKey]
                    Write-Host "    Period $period — latest run has $($runBlobs.Count) CSV file(s)" -ForegroundColor DarkGray

                    $periodRows = 0
                    foreach ($blob in $runBlobs) {
                        $localFile = Join-Path $tempDir "$([guid]::NewGuid().ToString('N'))-$(Split-Path $blob.Path -Leaf)"
                        try {
                            Get-AzDataLakeGen2ItemContent -Context $ctx -FileSystem 'msexports' -Path $blob.Path -Destination $localFile -Force -ErrorAction Stop | Out-Null
                            $rows = Import-Csv -Path $localFile
                            if ($rows -and @($rows).Count -gt 0) {
                                foreach ($row in $rows) { $allData.Add($row) }
                                $periodRows += @($rows).Count
                            }
                        }
                        catch {
                            Write-Warning "Failed to read CSV: $($_.Exception.Message)"
                        }
                        finally {
                            Remove-Item $localFile -Force -ErrorAction SilentlyContinue
                        }
                    }

                    if ($periodRows -gt 0) {
                        Write-Host "    Loaded $periodRows rows from period $period" -ForegroundColor DarkGray
                        $periodsLoaded++
                    }
                    else {
                        Write-Host "    Period $period had no rows — skipping to next" -ForegroundColor DarkGray
                    }
                }
            }
            else {
                Write-Host "    No cost data found in Hub storage" -ForegroundColor Yellow
            }
        }
    }
    finally {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($allData.Count -gt 0) {
        $source = if ($allData[0].PSObject.Properties.Name -contains 'x_SkuTier') { 'CSV' } else { 'parquet' }
        Write-Host "    Total rows from Hub ($source): $($allData.Count)" -ForegroundColor Green
    }

    return $allData
}

function ConvertTo-CostDataFromHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$HubData
    )

    # Convert FOCUS-schema Hub data into the same hashtable format
    # that Get-CostData returns: @{ subscriptionId = @{ Actual; Forecast; Currency } }
    $costMap = @{}
    $props = $HubData[0].PSObject.Properties.Name

    foreach ($row in $HubData) {
        $subId = if ($props -contains 'SubAccountId' -and $row.SubAccountId) { $row.SubAccountId }
        elseif ($props -contains 'SubscriptionId' -and $row.SubscriptionId) { $row.SubscriptionId }
        elseif ($props -contains 'x_SubscriptionId' -and $row.x_SubscriptionId) { $row.x_SubscriptionId }
        else { 'unknown' }

        # FOCUS SubAccountId may be full resource path — extract just the GUID
        if ($subId -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') {
            $subId = $Matches[0]
        }

        $cost = if ($props -contains 'CostInBillingCurrency' -and $row.CostInBillingCurrency) { [double]$row.CostInBillingCurrency }
        elseif ($props -contains 'BilledCost' -and $row.BilledCost) { [double]$row.BilledCost }
        elseif ($props -contains 'EffectiveCost' -and $row.EffectiveCost) { [double]$row.EffectiveCost }
        else { 0 }

        $currency = if ($props -contains 'BillingCurrency' -and $row.BillingCurrency) { $row.BillingCurrency }
        elseif ($props -contains 'BillingCurrencyCode' -and $row.BillingCurrencyCode) { $row.BillingCurrencyCode }
        else { 'USD' }

        if (-not $costMap.ContainsKey($subId)) {
            $costMap[$subId] = @{ Actual = 0.0; Forecast = 0.0; Currency = $currency }
        }
        $costMap[$subId].Actual += $cost
    }

    return $costMap
}

function ConvertTo-ResourceCostsFromHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$HubData
    )

    # Aggregate by resource and return in the same format as Get-ResourceCosts
    $resourceMap = @{}
    $props = $HubData[0].PSObject.Properties.Name

    foreach ($row in $HubData) {
        $subName = if ($props -contains 'SubAccountName' -and $row.SubAccountName) { $row.SubAccountName }
        elseif ($props -contains 'SubscriptionName' -and $row.SubscriptionName) { $row.SubscriptionName }
        elseif ($props -contains 'SubAccountId') { $row.SubAccountId }
        else { 'unknown' }

        $rg = if ($props -contains 'x_ResourceGroupName' -and $row.x_ResourceGroupName) { $row.x_ResourceGroupName }
        elseif ($props -contains 'ResourceGroup' -and $row.ResourceGroup) { $row.ResourceGroup }
        elseif ($props -contains 'ResourceGroupName' -and $row.ResourceGroupName) { $row.ResourceGroupName }
        else { 'unknown' }

        $resType = if ($props -contains 'ResourceType' -and $row.ResourceType) { $row.ResourceType }
        elseif ($props -contains 'x_ResourceType' -and $row.x_ResourceType) { $row.x_ResourceType }
        elseif ($props -contains 'ConsumedService' -and $row.ConsumedService) { $row.ConsumedService }
        else { 'unknown' }

        $resId = if ($props -contains 'ResourceId' -and $row.ResourceId) { $row.ResourceId }
        elseif ($props -contains 'x_ResourceId' -and $row.x_ResourceId) { $row.x_ResourceId }
        else { "$rg/$resType" }

        $cost = if ($props -contains 'CostInBillingCurrency' -and $row.CostInBillingCurrency) { [double]$row.CostInBillingCurrency }
        elseif ($props -contains 'BilledCost' -and $row.BilledCost) { [double]$row.BilledCost }
        elseif ($props -contains 'EffectiveCost' -and $row.EffectiveCost) { [double]$row.EffectiveCost }
        else { 0 }

        $currency = if ($props -contains 'BillingCurrency' -and $row.BillingCurrency) { $row.BillingCurrency }
        elseif ($props -contains 'BillingCurrencyCode' -and $row.BillingCurrencyCode) { $row.BillingCurrencyCode }
        else { 'USD' }

        $key = $resId
        if (-not $resourceMap.ContainsKey($key)) {
            $resourceMap[$key] = [PSCustomObject]@{
                Subscription  = $subName
                ResourceGroup = $rg
                ResourceType  = $resType
                ResourcePath  = $resId
                Actual        = 0.0
                Forecast      = 0.0
                Currency      = $currency
            }
        }
        $resourceMap[$key].Actual += $cost
    }

    return @($resourceMap.Values | Sort-Object { $_.Actual } -Descending)
}

# Helper: pick the first present/non-empty property from a row.
function Get-HubRowValue {
    param(
        [Parameter(Mandatory)][object]$Row,
        [Parameter(Mandatory)][string[]]$Names,
        [string[]]$Props
    )
    if (-not $Props) { $Props = $Row.PSObject.Properties.Name }
    foreach ($n in $Names) {
        if ($Props -contains $n -and $null -ne $Row.$n -and "$($Row.$n)".Trim() -ne '') {
            return $Row.$n
        }
    }
    return $null
}

# Helper: convert a billing unit string (e.g. "1K", "1M", "1,000",
# "100 Tokens") into the number of tokens one unit of quantity represents.
# Azure OpenAI token meters are billed per-1K tokens, so an unqualified
# unit defaults to 1000 (flagged as approximate by the caller).
function Get-TokenUnitMultiplier {
    param([string]$Unit)
    if (-not $Unit) { return @{ Multiplier = 1000.0; Known = $false } }
    $u = $Unit.Trim()

    # Pure number, e.g. "1000" or "1,000,000".
    $numOnly = ($u -replace '[,\s]', '')
    if ($numOnly -match '^\d+(\.\d+)?$') { return @{ Multiplier = [double]$numOnly; Known = $true } }

    # Scaled, e.g. "1K", "10K", "1M".
    $m = [regex]::Match($u, '(?i)([\d,\.]+)?\s*([KM])\b')
    if ($m.Success) {
        $n = if ($m.Groups[1].Value) { [double]($m.Groups[1].Value -replace ',', '') } else { 1.0 }
        $scale = if ($m.Groups[2].Value -match '(?i)M') { 1e6 } else { 1e3 }
        return @{ Multiplier = ($n * $scale); Known = $true }
    }

    # Plain "tokens" / "count" / "units" — quantity is already raw tokens.
    if ($u -match '(?i)\b(token|tokens|count|units|unit)\b') { return @{ Multiplier = 1.0; Known = $true } }

    # Unknown unit — assume the AOAI per-1K convention but flag it.
    return @{ Multiplier = 1000.0; Known = $false }
}

# Helper: strip token-type and qualifier words from an Azure OpenAI meter
# name to derive a model/deployment grouping key.
function Get-AIModelKeyFromMeter {
    param([string]$Meter)
    if (-not $Meter) { return 'unknown' }
    $k = $Meter -replace '(?i)\b(inp|input|prompt|outp|output|generated|completion|cached|cache|regional|global|glbl|reg|data|stored|tokens|token)\b', ''
    $k = ($k -replace '\s+', ' ').Trim(' -')
    if ([string]::IsNullOrWhiteSpace($k)) { return ([string]$Meter).Trim() }
    return $k
}

function ConvertTo-AIHubAggregates {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyCollection()]
        [object[]]$HubData
    )

    # Aggregate Azure OpenAI / Cognitive Services spend and billed token
    # volume straight from FOCUS export rows. Only cognitiveservices/accounts
    # rows are priced (matching the live Cost Management filter). Request
    # counts are not billed line items, so cost-per-request is unavailable
    # on this path.
    $modelTokens = @{}   # modelKey -> @{ Prompt; Generated; Total }
    $acctTokens = @{}   # resourceId(lower) -> @{ Name; Tokens; Requests }
    $costByAcct = @{}   # resourceId(lower) -> cost
    $totalPrompt = 0.0
    $totalGen = 0.0
    $totalTokens = 0.0
    $aiCost = 0.0
    $currency = 'USD'
    $tokenRows = 0
    $approximate = $false

    if (-not $HubData -or @($HubData).Count -eq 0) {
        return [PSCustomObject]@{
            RowCount = 0; TotalPrompt = 0; TotalGen = 0; TotalTokens = 0
            AICost = 0; Currency = $currency; ModelTokens = $modelTokens
            AcctTokens = $acctTokens; CostByAcct = $costByAcct
            HasTokens = $false; HasCost = $false; Approximate = $false
        }
    }

    $props = $HubData[0].PSObject.Properties.Name

    foreach ($row in $HubData) {
        $resType = Get-HubRowValue -Row $row -Props $props -Names @('ResourceType', 'x_ResourceType', 'ConsumedService')
        if (-not $resType -or "$resType".ToLowerInvariant() -notmatch 'cognitiveservices') { continue }

        $rid = Get-HubRowValue -Row $row -Props $props -Names @('ResourceId', 'x_ResourceId')
        if (-not $rid) { continue }
        $ridKey = "$rid".ToLowerInvariant()

        $name = Get-HubRowValue -Row $row -Props $props -Names @('ResourceName')
        if (-not $name) { $name = Split-Path "$rid" -Leaf }

        $cost = Get-HubRowValue -Row $row -Props $props -Names @('CostInBillingCurrency', 'BilledCost', 'EffectiveCost')
        $cost = if ($null -ne $cost) { [double]$cost } else { 0.0 }

        $cur = Get-HubRowValue -Row $row -Props $props -Names @('BillingCurrency', 'BillingCurrencyCode')
        if ($cur) { $currency = "$cur" }

        if (-not $acctTokens.ContainsKey($ridKey)) {
            $acctTokens[$ridKey] = @{ Name = "$name"; Tokens = 0.0; Requests = 0.0 }
        }
        if (-not $costByAcct.ContainsKey($ridKey)) { $costByAcct[$ridKey] = 0.0 }
        $costByAcct[$ridKey] += $cost
        $aiCost += $cost

        # Token attribution from the meter name + billed quantity.
        $meter = Get-HubRowValue -Row $row -Props $props -Names @('x_SkuMeterName', 'MeterName', 'SkuMeterName', 'x_SkuDescription')
        if (-not $meter -or "$meter" -notmatch '(?i)token') { continue }

        $qty = Get-HubRowValue -Row $row -Props $props -Names @('ConsumedQuantity', 'x_ConsumedQuantity', 'Quantity', 'UsageQuantity')
        $qty = if ($null -ne $qty) { [double]$qty } else { 0.0 }
        if ($qty -le 0) { continue }

        $unit = Get-HubRowValue -Row $row -Props $props -Names @('ConsumedUnit', 'x_PricingUnitDescription', 'UnitOfMeasure', 'PricingUnit')
        $mult = Get-TokenUnitMultiplier -Unit "$unit"
        if (-not $mult.Known) { $approximate = $true }
        $tokens = $qty * $mult.Multiplier

        $modelKey = Get-AIModelKeyFromMeter -Meter "$meter"
        if (-not $modelTokens.ContainsKey($modelKey)) {
            $modelTokens[$modelKey] = @{ Prompt = 0.0; Generated = 0.0; Total = 0.0 }
        }

        if ("$meter" -match '(?i)\b(inp|input|prompt|cached|cache)\b') {
            $modelTokens[$modelKey].Prompt += $tokens
            $totalPrompt += $tokens
            $acctTokens[$ridKey].Tokens += $tokens
        }
        elseif ("$meter" -match '(?i)\b(outp|output|generated|completion)\b') {
            $modelTokens[$modelKey].Generated += $tokens
            $totalGen += $tokens
            $acctTokens[$ridKey].Tokens += $tokens
        }
        else {
            $acctTokens[$ridKey].Tokens += $tokens
        }
        $modelTokens[$modelKey].Total += $tokens
        $totalTokens += $tokens
        $tokenRows++
    }

    return [PSCustomObject]@{
        RowCount    = $tokenRows
        TotalPrompt = $totalPrompt
        TotalGen    = $totalGen
        TotalTokens = $totalTokens
        AICost      = $aiCost
        Currency    = $currency
        ModelTokens = $modelTokens
        AcctTokens  = $acctTokens
        CostByAcct  = $costByAcct
        HasTokens   = ($totalTokens -gt 0)
        HasCost     = ($aiCost -gt 0)
        Approximate = $approximate
    }
}

function ConvertTo-TagInventoryFromHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$HubData
    )

    # Extract tag inventory from FOCUS cost data Tags JSON column
    # Returns same structure as Get-TagInventory
    $tagNames = @{}
    $totalResources = 0
    $taggedCount = 0
    $untaggedResources = [System.Collections.Generic.List[PSCustomObject]]::new()
    $seenResources = @{}
    $props = $HubData[0].PSObject.Properties.Name

    foreach ($row in $HubData) {
        $resId = if ($props -contains 'ResourceId' -and $row.ResourceId) { $row.ResourceId }
        elseif ($props -contains 'x_ResourceId' -and $row.x_ResourceId) { $row.x_ResourceId }
        else { $null }

        # Deduplicate by resource ID (cost rows repeat per line item)
        if (-not $resId -or $seenResources.ContainsKey($resId)) { continue }
        $seenResources[$resId] = $true
        $totalResources++

        $resName = if ($props -contains 'ResourceName' -and $row.ResourceName) { $row.ResourceName } else { Split-Path $resId -Leaf }
        $resType = if ($props -contains 'ResourceType' -and $row.ResourceType) { $row.ResourceType }
        elseif ($props -contains 'x_ResourceType' -and $row.x_ResourceType) { $row.x_ResourceType }
        else { 'unknown' }
        $rg = if ($props -contains 'x_ResourceGroupName' -and $row.x_ResourceGroupName) { $row.x_ResourceGroupName }
        elseif ($props -contains 'ResourceGroup' -and $row.ResourceGroup) { $row.ResourceGroup }
        else { 'unknown' }
        $sub = if ($props -contains 'SubAccountName' -and $row.SubAccountName) { $row.SubAccountName }
        elseif ($props -contains 'SubscriptionName' -and $row.SubscriptionName) { $row.SubscriptionName }
        else { 'unknown' }

        # Parse Tags JSON
        $tagsJson = if ($props -contains 'Tags') { $row.Tags } else { $null }
        $tagDict = $null
        if ($tagsJson -and $tagsJson.Trim() -ne '' -and $tagsJson.Trim() -ne '{}') {
            try { $tagDict = ConvertTo-HashtableFromJson -Json $tagsJson } catch { }
        }

        if ($tagDict -and $tagDict.Count -gt 0) {
            $taggedCount++
            foreach ($kv in $tagDict.GetEnumerator()) {
                $tName = $kv.Key
                $tVal = if ($kv.Value) { "$($kv.Value)" } else { '(empty)' }

                if (-not $tagNames.ContainsKey($tName)) {
                    $tagNames[$tName] = @{
                        Values         = @{}
                        TotalResources = 0
                    }
                }
                $tagNames[$tName].TotalResources++

                if (-not $tagNames[$tName].Values.ContainsKey($tVal)) {
                    $tagNames[$tName].Values[$tVal] = @{ ResourceCount = 0; ResourceTypes = @{} }
                }
                $tagNames[$tName].Values[$tVal].ResourceCount++
                $tagNames[$tName].Values[$tVal].ResourceTypes[$resType] = $true
            }
        }
        else {
            if ($untaggedResources.Count -lt 500) {
                $untaggedResources.Add([PSCustomObject]@{
                        ResourceName  = $resName
                        ResourceType  = $resType
                        ResourceGroup = $rg
                        Subscription  = $sub
                        Location      = ''
                    })
            }
        }
    }

    # Convert Values hashes to arrays matching Get-TagInventory format
    $tagNamesOut = @{}
    foreach ($kv in $tagNames.GetEnumerator()) {
        $valArray = @()
        foreach ($v in $kv.Value.Values.GetEnumerator()) {
            $valArray += [PSCustomObject]@{
                TagValue      = $v.Key
                ResourceCount = $v.Value.ResourceCount
                ResourceTypes = @($v.Value.ResourceTypes.Keys)
            }
        }
        $tagNamesOut[$kv.Key] = @{
            Values         = ($valArray | Sort-Object ResourceCount -Descending)
            TotalResources = $kv.Value.TotalResources
        }
    }

    $untaggedCount = $totalResources - $taggedCount
    $coverage = if ($totalResources -gt 0) { [math]::Round(($taggedCount / $totalResources) * 100, 1) } else { 0 }

    return [PSCustomObject]@{
        TagNames          = $tagNamesOut
        TagCount          = $tagNamesOut.Count
        TotalResources    = $totalResources
        TaggedCount       = $taggedCount
        UntaggedCount     = $untaggedCount
        TagCoverage       = $coverage
        UntaggedResources = @($untaggedResources)
        Source            = 'Hub'
    }
}

function ConvertTo-CostByTagFromHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$HubData,

        [Parameter()]
        [hashtable]$ExistingTags
    )

    # Aggregate cost by tag key/value from FOCUS cost data
    # Returns same structure as Get-CostByTag
    $props = $HubData[0].PSObject.Properties.Name
    $costByTag = @{}
    $currency = 'USD'

    # Determine which tags to report on
    $targetTags = if ($ExistingTags -and $ExistingTags.Count -gt 0) {
        @($ExistingTags.Keys)
    }
    else { @() }

    foreach ($row in $HubData) {
        $cost = if ($props -contains 'CostInBillingCurrency' -and $row.CostInBillingCurrency) { [double]$row.CostInBillingCurrency }
        elseif ($props -contains 'BilledCost' -and $row.BilledCost) { [double]$row.BilledCost }
        elseif ($props -contains 'EffectiveCost' -and $row.EffectiveCost) { [double]$row.EffectiveCost }
        else { 0 }

        if ($props -contains 'BillingCurrency' -and $row.BillingCurrency) { $currency = $row.BillingCurrency }

        $tagsJson = if ($props -contains 'Tags') { $row.Tags } else { $null }
        $tagDict = $null
        if ($tagsJson -and $tagsJson.Trim() -ne '' -and $tagsJson.Trim() -ne '{}') {
            try { $tagDict = ConvertTo-HashtableFromJson -Json $tagsJson } catch { }
        }

        if ($targetTags.Count -eq 0 -and $tagDict -and $tagDict.Count -gt 0) {
            $targetTags = @($tagDict.Keys)
        }

        foreach ($tagKey in $targetTags) {
            if (-not $costByTag.ContainsKey($tagKey)) { $costByTag[$tagKey] = @{} }
            $tagVal = if ($tagDict -and $tagDict.ContainsKey($tagKey)) { "$($tagDict[$tagKey])" } else { '(untagged)' }
            if (-not $tagVal -or $tagVal -eq '') { $tagVal = '(empty)' }

            if (-not $costByTag[$tagKey].ContainsKey($tagVal)) { $costByTag[$tagKey][$tagVal] = 0.0 }
            $costByTag[$tagKey][$tagVal] += $cost
        }
    }

    # Convert to output format matching Get-CostByTag
    $costByTagOut = @{}
    foreach ($kv in $costByTag.GetEnumerator()) {
        $costByTagOut[$kv.Key] = @($kv.Value.GetEnumerator() | ForEach-Object {
                [PSCustomObject]@{
                    TagValue = $_.Key
                    Cost     = [math]::Round($_.Value, 2)
                    Currency = $currency
                }
            } | Sort-Object Cost -Descending)
    }

    return [PSCustomObject]@{
        TagsQueried   = @($costByTagOut.Keys)
        CostByTag     = $costByTagOut
        NoTagsFound   = ($costByTagOut.Count -eq 0)
        UsedTimeframe = 'Hub export period'
        Source        = 'Hub'
    }
}
