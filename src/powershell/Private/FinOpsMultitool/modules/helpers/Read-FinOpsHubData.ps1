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
                # Sort descending to get newest export run first
                $csvBlobs = $csvBlobs | Sort-Object Path -Descending

                # Group by export run folder (parent of the CSV)
                $runs = [ordered]@{}
                foreach ($blob in $csvBlobs) {
                    $runFolder = Split-Path $blob.Path -Parent
                    if (-not $runs.Contains($runFolder)) {
                        $runs[$runFolder] = [System.Collections.Generic.List[object]]::new()
                    }
                    $runs[$runFolder].Add($blob)
                }

                # Take the most recent run
                $latestRun = ($runs.GetEnumerator() | Select-Object -First 1).Value
                Write-Host "    Found $($latestRun.Count) CSV file(s) from latest export" -ForegroundColor DarkGray

                foreach ($blob in $latestRun) {
                    $localFile = Join-Path $tempDir "$(Split-Path $blob.Path -Leaf)"
                    try {
                        Get-AzDataLakeGen2ItemContent -Context $ctx -FileSystem 'msexports' -Path $blob.Path -Destination $localFile -Force -ErrorAction Stop | Out-Null
                        $rows = Import-Csv -Path $localFile
                        if ($rows -and @($rows).Count -gt 0) {
                            foreach ($row in $rows) { $allData.Add($row) }
                            Write-Host "    Loaded $(@($rows).Count) rows from CSV" -ForegroundColor DarkGray
                        }
                    }
                    catch {
                        Write-Warning "Failed to read CSV: $($_.Exception.Message)"
                    }
                    finally {
                        Remove-Item $localFile -Force -ErrorAction SilentlyContinue
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
