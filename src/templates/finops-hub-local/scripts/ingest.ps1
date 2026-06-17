#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Bulk-ingest FOCUS Cost + Price Sheet parquet exports into local Kustainer raw tables.

.DESCRIPTION
    Bulk-ingests FOCUS parquet exports. Walks export/{scope}/{type}/{period}/{run-uuid},
    selects the latest manifest run per (scope,type,period), tracks idempotency in
    Ingest_Manifest by checksum, enforces overwrite semantics for superseded runs, disables
    transactional final-table update policies during bulk ingest, and explicitly backfills finals.

.PARAMETER Scope
    Filter to one scope subfolder under export/.

.PARAMETER Period
    Filter to one period (YYYYMMDD-YYYYMMDD).

.PARAMETER DryRun
    Plan and print work, including manifest skip decisions, without mutating Kustainer.

.PARAMETER ForcePolicyRecapture
    Allow capturing update policies that are already disabled. Dangerous; mirrors the ingest policy-capture guard.

.EXAMPLE
    pwsh scripts/ingest.ps1 --dry-run

.EXAMPLE
    pwsh scripts/ingest.ps1 --scope ea --period 20260501-20260531
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $CliArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

function Get-ExportDir {
    if ($env:EXPORT_DIR) { return $env:EXPORT_DIR }
    $envFilePath = Join-Path $script:RepoRoot '.env'
    if (Test-Path -LiteralPath $envFilePath) {
        foreach ($lineText in Get-Content -LiteralPath $envFilePath) {
            $trimmed = $lineText.Trim()
            if ($trimmed -like 'EXPORT_DIR=*') { return ($trimmed -split '=', 2)[1].Trim() }
        }
    }
    return (Join-Path $script:RepoRoot 'export')
}

$script:ExportDirHost = Get-ExportDir
$script:ExportDirContainer = '/data/export'
$script:DbName = if ($env:FTK_DB) { $env:FTK_DB } else { 'Ingestion' }
$script:IngestManifestTable = 'Ingest_Manifest'
$script:RowCountTolerance = 0.001
$script:IngestTimeoutSec = 1800
$script:DatasetTableMap = @{
    'ms--focus-cost' = [pscustomobject]@{ Table = 'Costs_raw';  Mapping = 'Costs_raw_mapping' }
    'ms--pricesheet' = [pscustomobject]@{ Table = 'Prices_raw'; Mapping = 'Prices_raw_mapping' }
}
$script:RawToFinalPolicy = @{
    'Costs_raw'  = [pscustomobject]@{ FinalTable = 'Costs_final_v1_2';  TransformFn = 'Costs_transform_v1_2' }
    'Prices_raw' = [pscustomobject]@{ FinalTable = 'Prices_final_v1_2'; TransformFn = 'Prices_transform_v1_2' }
}

# Proactive chunked-backfill thresholds.
# Measured baseline: MEM_LIMIT=16g, amd64-Rosetta; idle-loaded engine ~12.4 GiB working
# set (78% of 16g), ~3.5 GiB headroom. Costs 1.35M rows → single-pass OK; Prices 12.7M
# rows → single-pass OOMs (>16 GiB). Default row threshold 2,000,000 is safely above the
# largest known single-pass success (1.35M) and well below the smallest known OOM point (12.7M).
# Extent threshold: >4 extents also triggers chunked backfill regardless of row count
# (many small extents indicate a fragmented raw table that benefits from chunking).
# Override at runtime: BACKFILL_CHUNK_ROW_THRESHOLD=5000000 pwsh scripts/ingest.ps1
$script:BackfillChunkRowThreshold    = if ($env:BACKFILL_CHUNK_ROW_THRESHOLD)    { [int64]$env:BACKFILL_CHUNK_ROW_THRESHOLD }    else { [int64]2000000 }
$script:BackfillChunkExtentThreshold = if ($env:BACKFILL_CHUNK_EXTENT_THRESHOLD) { [int64]$env:BACKFILL_CHUNK_EXTENT_THRESHOLD } else { [int64]4 }

function Get-HostPort {
    if ($env:HOST_PORT) { return $env:HOST_PORT }
    $envFilePath = Join-Path $script:RepoRoot '.env'
    if (Test-Path -LiteralPath $envFilePath) {
        foreach ($lineText in Get-Content -LiteralPath $envFilePath) {
            $trimmed = $lineText.Trim()
            if ($trimmed -like 'HOST_PORT=*') { return ($trimmed -split '=', 2)[1].Trim() }
        }
    }
    return '8082'
}

function Get-KustainerMgmtUrl {
    if ($env:KUSTAINER_MGMT) { return $env:KUSTAINER_MGMT }
    return "http://localhost:$(Get-HostPort)/v1/rest/mgmt"
}

function Get-KustainerQueryUrl {
    return (Get-KustainerMgmtUrl) -replace '/mgmt$', '/query'
}

$script:KustainerMgmt = Get-KustainerMgmtUrl
$script:KustainerQuery = Get-KustainerQueryUrl

function New-PostResult {
    param([int] $StatusCode, [string] $BodyText)
    [pscustomobject]@{ Status = $StatusCode; Body = $BodyText }
}

function Write-InfoLine {
    param([string] $Message = '')
    [Console]::Out.WriteLine($Message)
}

function Sort-ByNameOrdinal {
    param([object[]] $Items)
    $arr = @($Items)
    [Array]::Sort($arr, [Comparison[object]] { param($left, $right) [StringComparer]::Ordinal.Compare($left.Name, $right.Name) })
    return $arr
}

function Invoke-KustoPost {
    param(
        [Parameter(Mandatory)] [string] $CslText,
        [string] $EndpointUrl = $script:KustainerMgmt,
        [int] $TimeoutSec = 60
    )
    $payload = @{ db = $script:DbName; csl = $CslText } | ConvertTo-Json -Compress
    $headers = @{
        'Content-Type'        = 'application/json'
        'x-ms-client-version' = 'Kusto.Python.Client:1.0.0'
        'Accept'              = 'application/json'
    }
    try {
        $response = Invoke-WebRequest -Method Post -Uri $EndpointUrl -Headers $headers -Body $payload `
            -TimeoutSec $TimeoutSec -SkipHttpErrorCheck
        return (New-PostResult -StatusCode ([int]$response.StatusCode) -BodyText ([string]$response.Content))
    }
    catch {
        $bodyText = $null
        try { $bodyText = $_.ErrorDetails.Message } catch { }
        if (-not $bodyText) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $bodyText = (New-Object IO.StreamReader($stream)).ReadToEnd()
            } catch { }
        }
        # Guard against strict-mode PropertyNotFoundException when the exception has no .Response property.
        try {
            if ($_.Exception.Response -and $bodyText) {
                try { return (New-PostResult -StatusCode ([int]$_.Exception.Response.StatusCode) -BodyText $bodyText) } catch { }
            }
        } catch { }
        $messageText = "Connection error: $($_.Exception.GetType().Name): $($_.Exception.Message)"
        if ($_.Exception.GetType().Name -match 'WebException|HttpRequestException|IOException') {
            return (New-PostResult -StatusCode 599 -BodyText $messageText)
        }
        return (New-PostResult -StatusCode 599 -BodyText $messageText)
    }
}

function Get-KustoJson {
    param([Parameter(Mandatory)] [string] $BodyText)
    return ($BodyText | ConvertFrom-Json)
}

function Get-PrimaryRows {
    param($JsonObject)
    if (-not $JsonObject.Tables -or @($JsonObject.Tables).Count -eq 0) { return ,@() }
    return ,@($JsonObject.Tables[0].Rows)
}

function Get-PrimaryColumnNames {
    param($JsonObject)
    if (-not $JsonObject.Tables -or @($JsonObject.Tables).Count -eq 0) { return ,@() }
    return ,@($JsonObject.Tables[0].Columns | ForEach-Object { $_.ColumnName })
}

function Get-QueryScalar {
    param([Parameter(Mandatory)] [string] $CslText)
    $postResult = Invoke-KustoPost -CslText $CslText -EndpointUrl $script:KustainerQuery -TimeoutSec 60
    if ($postResult.Status -lt 200 -or $postResult.Status -ge 300) { return $null }
    try {
        $jsonObject = Get-KustoJson -BodyText $postResult.Body
        $rows = Get-PrimaryRows $jsonObject
        if ($rows.Count -eq 0) { return $null }
        return $rows[0][0]
    }
    catch { return $null }
}

function Parse-KustoError {
    param([string] $BodyText)
    try {
        $jsonObject = $BodyText | ConvertFrom-Json
        $err = $null
        if ($jsonObject.PSObject.Properties.Name -contains 'error') { $err = $jsonObject.error }
        if ($err) {
            $errType = $err.'@type'; if (-not $errType) { $errType = $err.code }; if (-not $errType) { $errType = 'Unknown' }
            $errMsg = $err.'@message'; if (-not $errMsg) { $errMsg = $err.message }; if (-not $errMsg) { $errMsg = $BodyText.Substring(0, [Math]::Min(200, $BodyText.Length)) }
            return @([string]$errType, [string]$errMsg)
        }
    }
    catch { }
    return @('RawText', $BodyText.Substring(0, [Math]::Min(300, $BodyText.Length)))
}

function Get-JsonPropertyValue {
    param($ObjectValue, [string] $Name, $DefaultValue = $null)
    if ($null -eq $ObjectValue) { return $DefaultValue }
    if ($ObjectValue.PSObject.Properties.Name -contains $Name) { return $ObjectValue.$Name }
    return $DefaultValue
}

function Get-SubmittedTime {
    param($ManifestObject)
    $runInfo = Get-JsonPropertyValue -ObjectValue $ManifestObject -Name 'runInfo'
    $submitted = Get-JsonPropertyValue -ObjectValue $runInfo -Name 'submittedTime'
    if ($submitted) { return [string]$submitted }
    $created = Get-JsonPropertyValue -ObjectValue $runInfo -Name 'createdDate'
    if ($created) { return [string]$created }
    return $null
}

function Read-RunManifest {
    param([Parameter(Mandatory)] [string] $RunDirPath)
    $manifestPath = Join-Path $RunDirPath 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $null }
    try { return (Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json) }
    catch { [Console]::Error.WriteLine("  WARN: cannot read $manifestPath`: $($_.Exception.Message)"); return $null }
}

function New-RunPlan {
    param(
        [string] $ScopeName,
        [string] $ExportTypeName,
        [string] $PeriodName,
        [string] $RunUuidValue,
        [string] $RunDirPath,
        [string] $SubmittedTimeValue,
        [int64] $ExpectedRowsValue,
        [object[]] $ParquetFilesValue,
        [string[]] $SupersededRunUuidsValue
    )
    [pscustomobject]@{
        Scope = $ScopeName
        ExportType = $ExportTypeName
        Period = $PeriodName
        RunUuid = $RunUuidValue
        RunDir = $RunDirPath
        SubmittedTime = $SubmittedTimeValue
        ExpectedRows = $ExpectedRowsValue
        ParquetFiles = @($ParquetFilesValue)
        SupersededRunUuids = @($SupersededRunUuidsValue)
    }
}

function Build-Plan {
    param([string] $ExportRootPath, [string] $ScopeFilter, [string] $PeriodFilter)
    $plans = @()
    if (-not (Test-Path -LiteralPath $ExportRootPath -PathType Container)) { throw "export root not found: $ExportRootPath" }
    foreach ($scopeDir in @(Sort-ByNameOrdinal @(Get-ChildItem -LiteralPath $ExportRootPath -Directory))) {
        if ($ScopeFilter -and $scopeDir.Name -ne $ScopeFilter) { continue }
        foreach ($typeDir in @(Sort-ByNameOrdinal @(Get-ChildItem -LiteralPath $scopeDir.FullName -Directory))) {
            if (-not $script:DatasetTableMap.ContainsKey($typeDir.Name)) {
                [Console]::Error.WriteLine("  skip: unknown dataset $($scopeDir.Name)/$($typeDir.Name)")
                continue
            }
            foreach ($periodDir in @(Sort-ByNameOrdinal @(Get-ChildItem -LiteralPath $typeDir.FullName -Directory))) {
                if ($PeriodFilter -and $periodDir.Name -ne $PeriodFilter) { continue }
                $runs = @()
                foreach ($runDir in @(Sort-ByNameOrdinal @(Get-ChildItem -LiteralPath $periodDir.FullName -Directory))) {
                    $manifestObject = Read-RunManifest -RunDirPath $runDir.FullName
                    if ($null -eq $manifestObject) { continue }
                    $runs += [pscustomobject]@{
                        RunDir = $runDir
                        Submitted = Get-SubmittedTime -ManifestObject $manifestObject
                        Manifest = $manifestObject
                        SubmittedSort = if (Get-SubmittedTime -ManifestObject $manifestObject) { Get-SubmittedTime -ManifestObject $manifestObject } else { '' }
                        Mtime = $runDir.LastWriteTimeUtc.Ticks
                        RunName = $runDir.Name
                    }
                }
                if ($runs.Count -eq 0) { continue }
                $sortedRuns = @($runs | Sort-Object SubmittedSort, Mtime, RunName)
                $latest = $sortedRuns[$sortedRuns.Count - 1]
                $superseded = @()
                if ($sortedRuns.Count -gt 1) { $superseded = @($sortedRuns[0..($sortedRuns.Count - 2)] | ForEach-Object { $_.RunDir.Name }) }
                $parts = @(Sort-ByNameOrdinal @(Get-ChildItem -LiteralPath $latest.RunDir.FullName -Filter '*.parquet' -File))
                if ($parts.Count -eq 0) {
                    [Console]::Error.WriteLine("  WARN: latest run has no parquet parts: $($latest.RunDir.FullName)")
                    continue
                }
                $expectedRaw = Get-JsonPropertyValue -ObjectValue $latest.Manifest -Name 'dataRowCount' -DefaultValue 0
                $plans += New-RunPlan -ScopeName $scopeDir.Name -ExportTypeName $typeDir.Name -PeriodName $periodDir.Name `
                    -RunUuidValue $latest.RunDir.Name -RunDirPath $latest.RunDir.FullName -SubmittedTimeValue $latest.Submitted `
                    -ExpectedRowsValue ([int64]$expectedRaw) -ParquetFilesValue $parts -SupersededRunUuidsValue $superseded
            }
        }
    }
    return @($plans)
}

function Get-FileSha256Lower {
    param([Parameter(Mandatory)] [string] $PathValue)
    return (Get-FileHash -LiteralPath $PathValue -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Join-ManifestKey {
    param([string] $ScopeName, [string] $ExportTypeName, [string] $PeriodName, [string] $RunUuidValue, [string] $FileNameValue)
    $sep = [string][char]31
    return @($ScopeName, $ExportTypeName, $PeriodName, $RunUuidValue, $FileNameValue) -join $sep
}

function Initialize-IngestManifestTable {
    $schema = 'scope:string, export_type:string, period:string, run_uuid:string, file_name:string, file_size:long, rows_ingested:long, checksum_sha256:string, ingested_at:datetime'
    $cslText = ".create-merge table $script:IngestManifestTable ($schema)"
    $postResult = Invoke-KustoPost -CslText $cslText -TimeoutSec 60
    if ($postResult.Status -lt 200 -or $postResult.Status -ge 300) {
        $errParts = Parse-KustoError -BodyText $postResult.Body
        throw "failed to ensure $script:IngestManifestTable table: $($errParts[0]): $($errParts[1])"
    }
}

function Fetch-ManifestIndex {
    $cslText = "$script:IngestManifestTable | project scope, export_type, period, run_uuid, file_name, file_size, rows_ingested, checksum_sha256, ingested_at"
    $postResult = Invoke-KustoPost -CslText $cslText -EndpointUrl $script:KustainerQuery -TimeoutSec 60
    if ($postResult.Status -lt 200 -or $postResult.Status -ge 300) {
        $errParts = Parse-KustoError -BodyText $postResult.Body
        $msgLower = $errParts[1].ToLowerInvariant()
        if ($msgLower.Contains('not found') -or $msgLower.Contains('failed to resolve') -or $msgLower.Contains('could not be resolved') -or $errParts[0].Contains('EntityNotFound') -or $errParts[1].Contains('SEM0100')) { return @{} }
        throw "failed to read $script:IngestManifestTable`: $($errParts[0]): $($errParts[1])"
    }
    $jsonObject = Get-KustoJson -BodyText $postResult.Body
    $rows = Get-PrimaryRows $jsonObject
    $cols = Get-PrimaryColumnNames $jsonObject
    $index = @{}
    foreach ($row in $rows) {
        $rec = [ordered]@{}
        for ($idx = 0; $idx -lt $cols.Count; $idx++) { $rec[$cols[$idx]] = $row[$idx] }
        $key = Join-ManifestKey -ScopeName $rec['scope'] -ExportTypeName $rec['export_type'] -PeriodName $rec['period'] -RunUuidValue $rec['run_uuid'] -FileNameValue $rec['file_name']
        $index[$key] = [pscustomobject]$rec
    }
    return $index
}

function ConvertTo-CsvQuotedField {
    param($Value)
    $textValue = if ($null -eq $Value) { '' } else { [string]$Value }
    return '"' + ($textValue -replace '"', '""') + '"'
}

function Insert-ManifestRow {
    param([Parameter(Mandatory)] $RecordObject)
    $fields = @(
        $RecordObject.scope, $RecordObject.export_type, $RecordObject.period, $RecordObject.run_uuid,
        $RecordObject.file_name, [string]$RecordObject.file_size, [string]$RecordObject.rows_ingested,
        $RecordObject.checksum_sha256, $RecordObject.ingested_at
    ) | ForEach-Object { ConvertTo-CsvQuotedField $_ }
    $csvLine = $fields -join ','
    $cslText = ".ingest inline into table $script:IngestManifestTable with (format='csv') <|`n$csvLine"
    $postResult = Invoke-KustoPost -CslText $cslText -TimeoutSec 60
    if ($postResult.Status -lt 200 -or $postResult.Status -ge 300) {
        $errParts = Parse-KustoError -BodyText $postResult.Body
        throw "failed to insert $script:IngestManifestTable row: $($errParts[0]): $($errParts[1])"
    }
}

function Get-UpdatePolicy {
    param([Parameter(Mandatory)] [string] $FinalTableName)
    $postResult = Invoke-KustoPost -CslText ".show table $FinalTableName policy update" -TimeoutSec 30
    if ($postResult.Status -lt 200 -or $postResult.Status -ge 300) { return $null }
    try {
        $jsonObject = Get-KustoJson -BodyText $postResult.Body
        $rows = Get-PrimaryRows $jsonObject
        if ($rows.Count -eq 0) { return $null }
        $bodyText = $rows[0][2]
        if (-not $bodyText) { return $null }
        return @($bodyText | ConvertFrom-Json)
    }
    catch { return $null }
}

function Set-UpdatePolicy {
    param([Parameter(Mandatory)] [string] $FinalTableName, [Parameter(Mandatory)] [object[]] $PolicyObject)
    # Kusto expects a JSON array of policy objects. Serialize each element and
    # join, so a single-element collection isn't emitted as a bare JSON object.
    $elements = @($PolicyObject | ForEach-Object { $_ | ConvertTo-Json -Depth 20 -Compress })
    $bodyText = '[' + ($elements -join ',') + ']'
    $cslText = '.alter table ' + $FinalTableName + ' policy update ```' + $bodyText + '```'
    $postResult = Invoke-KustoPost -CslText $cslText -TimeoutSec 60
    if ($postResult.Status -lt 200 -or $postResult.Status -ge 300) {
        $errParts = Parse-KustoError -BodyText $postResult.Body
        throw "failed to set update policy on ${FinalTableName}: $($errParts[0]): $($errParts[1])"
    }
}

function Disable-UpdatePolicies {
    param([bool] $ForceRecapture = $false)
    $saved = @{}
    foreach ($rawTableName in @('Costs_raw', 'Prices_raw')) {
        $finalTableName = $script:RawToFinalPolicy[$rawTableName].FinalTable
        $policy = @(Get-UpdatePolicy -FinalTableName $finalTableName)
        if ($policy.Count -eq 0) {
            [Console]::Error.WriteLine("  NOTE: no update policy on $finalTableName; skipping disable")
            continue
        }
        $alreadyDisabled = $false
        foreach ($polItem in $policy) {
            $enabledValue = Get-JsonPropertyValue -ObjectValue $polItem -Name 'IsEnabled' -DefaultValue $true
            if (-not [bool]$enabledValue) { $alreadyDisabled = $true; break }
        }
        if ($alreadyDisabled -and -not $ForceRecapture) {
            throw "$finalTableName update policy is ALREADY disabled (IsEnabled=false). A previous ingest run likely crashed between disable/restore. Refusing to capture the disabled state as 'original' — that would silently bake the broken state into future runs.`n`nResolution: manually re-enable the policy via`n  make kql QUERY=`".alter table $finalTableName policy update '<json-with-IsEnabled-true>'`"`nThen re-run this script. Or override with --force-policy-recapture if you know what you're doing."
        }
        $saved[$finalTableName] = @($policy | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
        $disabled = @($policy | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
        foreach ($polItem in $disabled) { $polItem.IsEnabled = $false }
        Set-UpdatePolicy -FinalTableName $finalTableName -PolicyObject $disabled
        $firstPolicy = $policy[0]
        $wasEnabled = Get-JsonPropertyValue -ObjectValue $firstPolicy -Name 'IsEnabled'
        $wasTransactional = Get-JsonPropertyValue -ObjectValue $firstPolicy -Name 'IsTransactional'
        Write-InfoLine "  PRE-INGEST: disabled update policy on $finalTableName (was: IsEnabled=$wasEnabled, IsTransactional=$wasTransactional)"
    }
    return $saved
}

function Restore-UpdatePolicies {
    param([System.Collections.IDictionary] $SavedPolicies)
    foreach ($finalTableName in $SavedPolicies.Keys) {
        try {
            Set-UpdatePolicy -FinalTableName $finalTableName -PolicyObject @($SavedPolicies[$finalTableName])
            Write-InfoLine "  POST-INGEST: restored update policy on $finalTableName"
        }
        catch { [Console]::Error.WriteLine("  ERROR: could not restore update policy on $finalTableName`: $($_.Exception.Message)") }
    }
}

function Get-RowsFromSetOrAppendResponse {
    param([string] $BodyText)
    $rowsAdded = 0L
    try {
        $jsonObject = Get-KustoJson -BodyText $BodyText
        $cols = Get-PrimaryColumnNames $jsonObject
        $rcIdx = [Array]::IndexOf([object[]]$cols, 'RowCount')
        if ($rcIdx -ge 0) {
            foreach ($row in (Get-PrimaryRows $jsonObject)) { $rowsAdded += [int64]($row[$rcIdx] ?? 0) }
        }
    }
    catch { }
    return $rowsAdded
}

function Invoke-BackfillFinalTable {
    param([string] $FinalTableName, [string] $TransformFunctionName)
    $cslText = ".set-or-append $FinalTableName <| $TransformFunctionName()"
    Write-InfoLine "  BACKFILL: running $cslText ..."
    $startTime = [Diagnostics.Stopwatch]::StartNew()
    $postResult = Invoke-KustoPost -CslText $cslText -TimeoutSec $script:IngestTimeoutSec
    $startTime.Stop()
    if ($postResult.Status -lt 200 -or $postResult.Status -ge 300) {
        $errParts = Parse-KustoError -BodyText $postResult.Body
        [Console]::Error.WriteLine("  BACKFILL FAIL: $($errParts[0]): $($errParts[1].Substring(0, [Math]::Min(300, $errParts[1].Length)))")
        return [pscustomobject]@{ Ok = $false; Rows = 0L }
    }
    $rowsAdded = Get-RowsFromSetOrAppendResponse -BodyText $postResult.Body
    Write-InfoLine ("  BACKFILL OK: {0:N0} rows in {1:N1}s" -f $rowsAdded, $startTime.Elapsed.TotalSeconds)
    return [pscustomobject]@{ Ok = $true; Rows = $rowsAdded }
}

function Get-TableExtents {
    param([Parameter(Mandatory)] [string] $TableName)
    $postResult = Invoke-KustoPost -CslText ".show table $TableName extents | project ExtentId" -TimeoutSec 120
    if ($postResult.Status -lt 200 -or $postResult.Status -ge 300) { return @() }
    try {
        $jsonObject = Get-KustoJson -BodyText $postResult.Body
        return @((Get-PrimaryRows $jsonObject) | ForEach-Object { [string]$_[0] })
    }
    catch { return @() }
}

function Wait-ForHealth {
    param([int] $TimeoutSec = 60)
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSec)
    while ([DateTimeOffset]::UtcNow -lt $deadline) {
        $postResult = Invoke-KustoPost -CslText '.show version' -TimeoutSec 5
        if ($postResult.Status -ge 200 -and $postResult.Status -lt 300) { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Invoke-ChunkedBackfillFinalTable {
    param(
        [Parameter(Mandatory)] [string] $RawTableName,
        [Parameter(Mandatory)] [string] $FinalTableName,
        [Parameter(Mandatory)] [string] $TransformFunctionName,
        [int] $ExtentsPerBatch = 2
    )
    $extents = @(Get-TableExtents -TableName $RawTableName)
    if ($extents.Count -eq 0) {
        Write-InfoLine "  CHUNKED BACKFILL: no extents in $RawTableName, nothing to do"
        return [pscustomobject]@{ Ok = $true; Rows = 0L }
    }
    $totalRows = 0L
    $batchCount = [int][Math]::Ceiling($extents.Count / [double]$ExtentsPerBatch)
    Write-InfoLine "  CHUNKED BACKFILL: $($extents.Count) extents → $batchCount batches of up to $ExtentsPerBatch extents each"
    for ($batchIndex = 0; $batchIndex -lt $batchCount; $batchIndex++) {
        $startIdx = $batchIndex * $ExtentsPerBatch
        $endIdx = [Math]::Min($startIdx + $ExtentsPerBatch - 1, $extents.Count - 1)
        $chunk = @($extents[$startIdx..$endIdx])
        $extentGuids = ($chunk | ForEach-Object { "guid($_)" }) -join ', '
        $cslText = ".set-or-append $FinalTableName <|`nlet $RawTableName = __table(`"$RawTableName`", 'All', 'AllButRowStore')`n  | where extent_id() in ($extentGuids);`n$TransformFunctionName()"
        if ($batchIndex -gt 0) { Start-Sleep -Seconds 5 }
        $maxAttempts = 4
        $attempt = 0
        $rowsAdded = 0L
        $postResult = $null
        $preExtentSet = @{}
        foreach ($extentId in @(Get-TableExtents -TableName $FinalTableName)) { $preExtentSet[$extentId] = $true }
        while ($attempt -lt $maxAttempts) {
            $attempt++
            $stopwatch = [Diagnostics.Stopwatch]::StartNew()
            $postResult = Invoke-KustoPost -CslText $cslText -TimeoutSec $script:IngestTimeoutSec
            $stopwatch.Stop()
            if ($postResult.Status -ge 200 -and $postResult.Status -lt 300) { break }
            $errParts = Parse-KustoError -BodyText $postResult.Body
            $errType = [string]$errParts[0]
            $errMsg = [string]$errParts[1]
            $isTransient = ($errMsg.Contains('Connection') -or $errMsg.Contains('RemoteDisconnected') -or $errType.Contains('Internal service') -or $errType.Contains('LowMemoryCondition') -or $errMsg.Contains('LowMemoryCondition') -or $errMsg.ToLowerInvariant().Contains('memory') -or $errType -eq 'Unknown' -or $postResult.Status -eq 599)
            if ($isTransient -and $attempt -lt $maxAttempts) {
                $waitSeconds = 15 * $attempt
                [Console]::Error.WriteLine("  CHUNK $($batchIndex + 1)/$batchCount attempt $attempt/$maxAttempts`: transient error ($($errType.Substring(0, [Math]::Min(40, $errType.Length))): $($errMsg.Substring(0, [Math]::Min(80, $errMsg.Length)))), waiting ${waitSeconds}s for engine recovery...")
                Start-Sleep -Seconds $waitSeconds
                [void](Wait-ForHealth -TimeoutSec 120)
                $postExtentSet = @{}
                foreach ($extentId in @(Get-TableExtents -TableName $FinalTableName)) { $postExtentSet[$extentId] = $true }
                $partial = @($postExtentSet.Keys | Where-Object { -not $preExtentSet.ContainsKey($_) } | Sort-Object)
                if ($partial.Count -gt 0) {
                    $preview = ($partial | Select-Object -First 3) -join ', '
                    if ($partial.Count -gt 3) { $preview += '...' }
                    [Console]::Error.WriteLine("  CHUNK $($batchIndex + 1)/$batchCount`: dropping $($partial.Count) partial extent(s) from failed attempt before retry: $preview")
                    $partialGuids = ($partial | ForEach-Object { "guid($_)" }) -join ', '
                    $dropCsl = ".drop extents <| .show table $FinalTableName extents where ExtentId in ($partialGuids)"
                    $dropResult = Invoke-KustoPost -CslText $dropCsl -TimeoutSec 60
                    if ($dropResult.Status -lt 200 -or $dropResult.Status -ge 300) {
                        $dropErr = Parse-KustoError -BodyText $dropResult.Body
                        [Console]::Error.WriteLine("  CHUNK $($batchIndex + 1)/$batchCount ABORT: could not drop partial extents ($($dropErr[0]): $($dropErr[1].Substring(0, [Math]::Min(120, $dropErr[1].Length))))")
                        return [pscustomobject]@{ Ok = $false; Rows = $totalRows }
                    }
                }
                continue
            }
            [Console]::Error.WriteLine("  CHUNK $($batchIndex + 1)/$batchCount FAIL after $attempt attempt(s): $errType`: $($errMsg.Substring(0, [Math]::Min(200, $errMsg.Length)))")
            return [pscustomobject]@{ Ok = $false; Rows = $totalRows }
        }
        if ($null -eq $postResult -or $postResult.Status -lt 200 -or $postResult.Status -ge 300) { return [pscustomobject]@{ Ok = $false; Rows = $totalRows } }
        $rowsAdded = Get-RowsFromSetOrAppendResponse -BodyText $postResult.Body
        $totalRows += $rowsAdded
        Write-InfoLine ("  CHUNK {0}/{1}: +{2:N0} rows in {3:N1}s" -f ($batchIndex + 1), $batchCount, $rowsAdded, $stopwatch.Elapsed.TotalSeconds)
    }
    return [pscustomobject]@{ Ok = $true; Rows = $totalRows }
}

function Invoke-BackfillFinalsPerPeriod {
    param([object[]] $Plans)
    $appended = @{}
    foreach ($rawTableName in @('Costs_raw', 'Prices_raw')) {
        $policyInfo = $script:RawToFinalPolicy[$rawTableName]
        $rawCount = Get-QueryScalar -CslText "$rawTableName | count"
        if (-not $rawCount) {
            Write-InfoLine "  $($policyInfo.FinalTable): $rawTableName is empty; skipping"
            $appended[$policyInfo.FinalTable] = 0
            continue
        }
        $extentCount = (Get-TableExtents -TableName $rawTableName).Count
        # Proactive chunking: skip single-pass if row count OR extent count exceed the
        # measured-headroom thresholds to avoid OOM on large/fragmented raw tables.
        $overRowThreshold    = [int64]$rawCount -gt $script:BackfillChunkRowThreshold
        $overExtentThreshold = [int64]$extentCount -gt $script:BackfillChunkExtentThreshold
        if ($overRowThreshold -or $overExtentThreshold) {
            $reason = if ($overRowThreshold -and $overExtentThreshold) {
                "{0:N0} rows > {1:N0} and {2} extents > {3}" -f [int64]$rawCount, $script:BackfillChunkRowThreshold, $extentCount, $script:BackfillChunkExtentThreshold
            } elseif ($overRowThreshold) {
                "{0:N0} rows > threshold {1:N0}" -f [int64]$rawCount, $script:BackfillChunkRowThreshold
            } else {
                "{0} extents > extent threshold {1}" -f $extentCount, $script:BackfillChunkExtentThreshold
            }
            Write-InfoLine "  $($policyInfo.FinalTable): $reason — proactively using per-extent chunked backfill (skipping single-pass)"
            $chunked = Invoke-ChunkedBackfillFinalTable -RawTableName $rawTableName -FinalTableName $policyInfo.FinalTable -TransformFunctionName $policyInfo.TransformFn -ExtentsPerBatch 1
            $appended[$policyInfo.FinalTable] = if ($chunked.Ok) { $chunked.Rows } else { -1 }
            if (-not $chunked.Ok) { [Console]::Error.WriteLine("  ERROR: $($policyInfo.FinalTable) still incomplete after chunked backfill; manual intervention required.") }
            continue
        }
        # Below both thresholds: try single-pass (fast), fall back to chunked as a safety net.
        Write-InfoLine ("  $($policyInfo.FinalTable): {0:N0} rows ≤ threshold {1:N0}, {2} extents ≤ {3} — using single-pass backfill" -f [int64]$rawCount, $script:BackfillChunkRowThreshold, $extentCount, $script:BackfillChunkExtentThreshold)
        $result = Invoke-BackfillFinalTable -FinalTableName $policyInfo.FinalTable -TransformFunctionName $policyInfo.TransformFn
        if ($result.Ok) { $appended[$policyInfo.FinalTable] = $result.Rows; continue }
        [Console]::Error.WriteLine("  $($policyInfo.FinalTable): single-pass backfill failed, falling back to per-extent chunked backfill...")
        [void](Wait-ForHealth -TimeoutSec 60)
        $chunked = Invoke-ChunkedBackfillFinalTable -RawTableName $rawTableName -FinalTableName $policyInfo.FinalTable -TransformFunctionName $policyInfo.TransformFn -ExtentsPerBatch 1
        $appended[$policyInfo.FinalTable] = if ($chunked.Ok) { $chunked.Rows } else { -1 }
        if (-not $chunked.Ok) { [Console]::Error.WriteLine("  ERROR: $($policyInfo.FinalTable) still incomplete; manual intervention required (raise Kustainer mem_limit or shrink extents).") }
    }
    return $appended
}

function Drop-SupersededExtents {
    param(
        [string] $TableName,
        [string] $ScopeName,
        [string] $ExportTypeName,
        [string] $PeriodName,
        [string] $KeepRunUuid,
        [hashtable] $ManifestIndex
    )
    $supersededRuns = @{}
    foreach ($entry in $ManifestIndex.GetEnumerator()) {
        $rec = $entry.Value
        if ($rec.scope -eq $ScopeName -and $rec.export_type -eq $ExportTypeName -and $rec.period -eq $PeriodName -and $rec.run_uuid -ne $KeepRunUuid) {
            if (-not $supersededRuns.ContainsKey($rec.run_uuid)) { $supersededRuns[$rec.run_uuid] = @() }
            $supersededRuns[$rec.run_uuid] = @($supersededRuns[$rec.run_uuid]) + $rec
        }
    }
    if ($supersededRuns.Count -eq 0) { return 0L }
    $totalRows = 0L
    foreach ($runUuidValue in @($supersededRuns.Keys)) {
        $records = @($supersededRuns[$runUuidValue])
        foreach ($rec in $records) { $totalRows += [int64]($rec.rows_ingested ?? 0) }
        $dropCsl = ".drop extents <| .show table $TableName extents where tags has 'run:$runUuidValue'"
        $dropResult = Invoke-KustoPost -CslText $dropCsl -TimeoutSec 120
        if ($dropResult.Status -lt 200 -or $dropResult.Status -ge 300) {
            $errParts = Parse-KustoError -BodyText $dropResult.Body
            [Console]::Error.WriteLine("  WARN: drop superseded extents for $TableName/$runUuidValue failed: $($errParts[0]): $($errParts[1])")
            continue
        }
        $deleteCsl = ".delete table $script:IngestManifestTable records <| $script:IngestManifestTable | where scope == '$ScopeName' and export_type == '$ExportTypeName' and period == '$PeriodName' and run_uuid == '$runUuidValue'"
        $deleteResult = Invoke-KustoPost -CslText $deleteCsl -TimeoutSec 120
        if ($deleteResult.Status -lt 200 -or $deleteResult.Status -ge 300) {
            $errParts = Parse-KustoError -BodyText $deleteResult.Body
            [Console]::Error.WriteLine("  WARN: delete superseded manifest rows for $runUuidValue failed: $($errParts[0]): $($errParts[1])")
        }
        $keysToDrop = @($ManifestIndex.Keys | Where-Object {
            $rec = $ManifestIndex[$_]
            $rec.scope -eq $ScopeName -and $rec.export_type -eq $ExportTypeName -and $rec.period -eq $PeriodName -and $rec.run_uuid -eq $runUuidValue
        })
        foreach ($keyValue in $keysToDrop) { $ManifestIndex.Remove($keyValue) }
    }
    return $totalRows
}

function Get-ContainerPath {
    param([Parameter(Mandatory)] [string] $HostPathValue)
    $rootFull = [IO.Path]::GetFullPath($script:ExportDirHost).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $pathFull = [IO.Path]::GetFullPath($HostPathValue)
    if (-not $pathFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::Ordinal)) {
        throw "parquet file $HostPathValue is outside $script:ExportDirHost"
    }
    $relPath = $pathFull.Substring($rootFull.Length + 1).Replace([IO.Path]::DirectorySeparatorChar, '/')
    return "$script:ExportDirContainer/$relPath"
}

function Escape-KqlHUri {
    param([string] $UriText)
    return ($UriText -replace '"', '\"')
}

function Invoke-DoIngest {
    param(
        [string] $TableName,
        [string] $MappingReference,
        [string] $HostPathValue,
        [string] $RunUuidValue,
        [string] $ScopeName,
        [string] $ExportTypeName,
        [string] $PeriodName
    )
    $uriText = Escape-KqlHUri -UriText (Get-ContainerPath -HostPathValue $HostPathValue)
    $tagItems = @("run:$RunUuidValue", "scope:$ScopeName", "type:$ExportTypeName", "period:$PeriodName")
    $tagsLiteral = '[' + (($tagItems | ForEach-Object { "'$_'" }) -join ',') + ']'
    $cslText = ".ingest into table $TableName (h@`"$uriText`") with (format='parquet', ingestionMappingReference='$MappingReference', tags=`"$tagsLiteral`")"
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $postResult = Invoke-KustoPost -CslText $cslText -TimeoutSec $script:IngestTimeoutSec
    $stopwatch.Stop()
    if ($postResult.Status -lt 200 -or $postResult.Status -ge 300) {
        $errParts = Parse-KustoError -BodyText $postResult.Body
        throw "ingest failed for $([IO.Path]::GetFileName($HostPathValue)): HTTP $($postResult.Status) [$($errParts[0])] $($errParts[1])"
    }
    try {
        $jsonObject = Get-KustoJson -BodyText $postResult.Body
        $rows = Get-PrimaryRows $jsonObject
        if ($rows.Count -gt 0) {
            foreach ($row in $rows) { if ($row[3]) { throw "ingest reported HasErrors=true for $([IO.Path]::GetFileName($HostPathValue)): $($rows | ConvertTo-Json -Compress)" } }
        }
    }
    catch { throw "could not parse ingest response: $($_.Exception.Message); body=$($postResult.Body.Substring(0, [Math]::Min(300, $postResult.Body.Length)))" }
    return [pscustomobject]@{ Rows = 0; Seconds = $stopwatch.Elapsed.TotalSeconds }
}

function New-IngestStats { [pscustomobject]@{ files_ingested = 0; files_skipped = 0; files_failed = 0; bytes_ingested = 0L; rows_ingested = 0L; expected_rows = 0L; seconds = 0.0 } }

function Get-ManifestRowsForBlob {
    param($ManifestObject, [string] $BlobFileName)
    $blobs = Get-JsonPropertyValue -ObjectValue $ManifestObject -Name 'blobs'
    foreach ($blob in @($blobs)) {
        $blobName = [string](Get-JsonPropertyValue -ObjectValue $blob -Name 'blobName' -DefaultValue '')
        if ($blobName.EndsWith('/' + $BlobFileName, [StringComparison]::Ordinal) -or $blobName -eq $BlobFileName) {
            return [int64](Get-JsonPropertyValue -ObjectValue $blob -Name 'dataRowCount' -DefaultValue 0)
        }
    }
    return $null
}

function Invoke-RunIngest {
    param([object[]] $Plans, [bool] $DryRun = $false, [bool] $ForcePolicyRecapture = $false)
    if (-not $DryRun) { Initialize-IngestManifestTable }
    $manifestIndex = Fetch-ManifestIndex
    if ($manifestIndex.Count -gt 0) { [Console]::Error.WriteLine("INFO: Ingest_Manifest has $($manifestIndex.Count) existing rows") }
    if ($manifestIndex.Count -eq 0) {
        $rawTotal = 0L
        foreach ($rawTableName in @('Costs_raw', 'Prices_raw')) {
            try {
                $postResult = Invoke-KustoPost -CslText "$rawTableName | count" -EndpointUrl $script:KustainerQuery -TimeoutSec 30
                if ($postResult.Status -ge 200 -and $postResult.Status -lt 300) {
                    $jsonObject = Get-KustoJson -BodyText $postResult.Body
                    $rawTotal += [int64](Get-PrimaryRows $jsonObject)[0][0]
                }
            } catch { }
        }
        if ($rawTotal -gt 0) {
            throw "Raw tables have $($rawTotal.ToString('N0')) rows but Ingest_Manifest is empty. The container was likely recreated and lost the manifest while leaving raw data orphaned.`n`nResolution: either drop all raw extents to start fresh`n  make kql QUERY=`".clear table Costs_raw data`"`n  make kql QUERY=`".clear table Prices_raw data`"`n…then re-run, OR re-populate Ingest_Manifest from a backup. Refusing to proceed — silently treating every file as new would double-ingest the orphaned data."
        }
    }

    $fileUnits = @()
    foreach ($plan in $Plans) {
        $manifestObject = Read-RunManifest -RunDirPath $plan.RunDir
        foreach ($part in @($plan.ParquetFiles)) {
            $perBlob = Get-ManifestRowsForBlob -ManifestObject $manifestObject -BlobFileName $part.Name
            if ($null -eq $perBlob) { $perBlob = 0L }
            $fileUnits += [pscustomobject]@{ Plan = $plan; HostPath = $part; ExpectedRows = [int64]$perBlob }
        }
    }
    $totalFiles = $fileUnits.Count
    if ($totalFiles -eq 0) { Write-InfoLine 'no parquet files matched filters; nothing to do'; return @{} }
    Write-InfoLine "PLAN: $($Plans.Count) (scope,type,period) tuples → $totalFiles parquet parts"
    foreach ($plan in $Plans) {
        $sup = if ($plan.SupersededRunUuids.Count -gt 0) { " (supersedes $($plan.SupersededRunUuids.Count) prior run-uuids)" } else { '' }
        Write-InfoLine ("  - {0}/{1}/{2} → run {3}…  {4} part(s) · {5:N0} rows expected{6}" -f $plan.Scope, $plan.ExportType, $plan.Period, $plan.RunUuid.Substring(0, [Math]::Min(8, $plan.RunUuid.Length)), $plan.ParquetFiles.Count, $plan.ExpectedRows, $sup)
    }

    if (-not $DryRun) {
        foreach ($plan in $Plans) {
            $tableName = $script:DatasetTableMap[$plan.ExportType].Table
            $droppedRows = Drop-SupersededExtents -TableName $tableName -ScopeName $plan.Scope -ExportTypeName $plan.ExportType -PeriodName $plan.Period -KeepRunUuid $plan.RunUuid -ManifestIndex $manifestIndex
            if ($droppedRows) { Write-InfoLine ("  OVERWRITE: dropped {0:N0} rows from {1} for superseded run(s) of {2}/{3}/{4}" -f $droppedRows, $tableName, $plan.Scope, $plan.ExportType, $plan.Period) }
        }
    }

    $statsByDataset = @{}
    $overall = [Diagnostics.Stopwatch]::StartNew()
    $savedPolicies = @{}
    if (-not $DryRun) { $savedPolicies = Disable-UpdatePolicies -ForceRecapture $ForcePolicyRecapture }
    $paceFloorSec = if ($env:INGEST_PACE_FLOOR_S) { [double]$env:INGEST_PACE_FLOOR_S } else { 1.5 }
    $pacePerMbSec = if ($env:INGEST_PACE_PER_MB_S) { [double]$env:INGEST_PACE_PER_MB_S } else { 0.05 }
    try {
        for ($unitIndex = 0; $unitIndex -lt $fileUnits.Count; $unitIndex++) {
            $unit = $fileUnits[$unitIndex]
            $plan = $unit.Plan
            $mapInfo = $script:DatasetTableMap[$plan.ExportType]
            $bucketKey = "$($plan.Scope)$([char]31)$($plan.ExportType)"
            if (-not $statsByDataset.ContainsKey($bucketKey)) { $statsByDataset[$bucketKey] = New-IngestStats }
            $bucket = $statsByDataset[$bucketKey]
            $bucket.expected_rows += [int64]$unit.ExpectedRows
            $sizeBytes = [int64]$unit.HostPath.Length
            $bucket.bytes_ingested += $sizeBytes
            $sha = Get-FileSha256Lower -PathValue $unit.HostPath.FullName
            $manifestKey = Join-ManifestKey -ScopeName $plan.Scope -ExportTypeName $plan.ExportType -PeriodName $plan.Period -RunUuidValue $plan.RunUuid -FileNameValue $unit.HostPath.Name
            $prior = if ($manifestIndex.ContainsKey($manifestKey)) { $manifestIndex[$manifestKey] } else { $null }
            $displayIndex = $unitIndex + 1
            if ($prior -and $prior.checksum_sha256 -eq $sha) {
                $bucket.files_skipped++
                Write-InfoLine ("[{0,3}/{1}] SKIP {2}/{3}/{4}/{5}  ({6} KB, {7:N0} rows) already in Ingest_Manifest with matching checksum" -f $displayIndex, $totalFiles, $plan.Scope, $plan.ExportType, $plan.Period, $unit.HostPath.Name, [Math]::Floor($sizeBytes / 1024), [int64]$unit.ExpectedRows)
                $bucket.rows_ingested += [int64]($prior.rows_ingested ?? 0)
                continue
            }
            elseif ($prior) {
                # Same composite key (scope/type/period/run-uuid/filename) exists in
                # Ingest_Manifest but with a DIFFERENT checksum. Proceeding would silently
                # append a second copy of the data and corrupt cost totals (parity check 1's
                # 5% tolerance would mask the duplication).
                throw ("File '$($unit.HostPath.Name)' under run-uuid '$($plan.RunUuid)' for " +
                       "($($plan.Scope)/$($plan.ExportType)/$($plan.Period)) changed since last " +
                       "ingest (checksum mismatch: manifest=$($prior.checksum_sha256), file=$sha). " +
                       "Re-ingesting under the same run-uuid duplicates rows. " +
                       "Stage corrected data under a NEW run-uuid for the same (scope,type,period) to replace it (supersede).")
            }
            $progressPrefix = ("[{0,3}/{1}] ingesting {2}/{3}/{4}/{5} ({6} KB, {7:N0} rows expected)" -f $displayIndex, $totalFiles, $plan.Scope, $plan.ExportType, $plan.Period, $unit.HostPath.Name, [Math]::Floor($sizeBytes / 1024), [int64]$unit.ExpectedRows)
            Write-Host -NoNewline ($progressPrefix + ' ... ')
            if ($DryRun) { Write-InfoLine 'dry-run skip'; continue }
            $paceSec = $paceFloorSec + ($sizeBytes / (1024.0 * 1024.0)) * $pacePerMbSec
            if ($displayIndex -gt 1 -and $paceSec -gt 0) { Start-Sleep -Seconds $paceSec }
            try {
                $ingestResult = Invoke-DoIngest -TableName $mapInfo.Table -MappingReference $mapInfo.Mapping -HostPathValue $unit.HostPath.FullName -RunUuidValue $plan.RunUuid -ScopeName $plan.Scope -ExportTypeName $plan.ExportType -PeriodName $plan.Period
            }
            catch {
                $bucket.files_failed++
                Write-InfoLine "FAIL ($($_.Exception.Message))"
                if ($_.Exception.Message.Contains('Connection reset') -or $_.Exception.Message.Contains('RemoteDisconnected')) {
                    Write-InfoLine '  (engine may have crashed; waiting 30s for recovery)'
                    Start-Sleep -Seconds 30
                }
                continue
            }
            $bucket.files_ingested++
            $bucket.rows_ingested += [int64]$unit.ExpectedRows
            $bucket.seconds += [double]$ingestResult.Seconds
            Write-InfoLine ("{0:N1}s OK" -f $ingestResult.Seconds)
            $recordObject = [pscustomobject]@{
                scope = $plan.Scope; export_type = $plan.ExportType; period = $plan.Period; run_uuid = $plan.RunUuid
                file_name = $unit.HostPath.Name; file_size = $sizeBytes; rows_ingested = [int64]$unit.ExpectedRows
                checksum_sha256 = $sha; ingested_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            }
            try { Insert-ManifestRow -RecordObject $recordObject; $manifestIndex[$manifestKey] = $recordObject }
            catch { [Console]::Error.WriteLine("  WARN: could not record Ingest_Manifest row: $($_.Exception.Message)") }
        }
    }
    finally {
        if ($savedPolicies.Count -gt 0) { Restore-UpdatePolicies -SavedPolicies $savedPolicies }
    }
    $overall.Stop()
    Write-InfoLine ("`nINGEST WALL-CLOCK: {0:N1}s ({1:N1} min)" -f $overall.Elapsed.TotalSeconds, ($overall.Elapsed.TotalSeconds / 60.0))
    $anyIngested = $false
    foreach ($statsItem in $statsByDataset.Values) { if ($statsItem.files_ingested -gt 0) { $anyIngested = $true; break } }
    if (-not $DryRun -and $anyIngested) {
        Write-InfoLine "`n=== Backfilling final tables via FTK transforms ==="
        [void](Invoke-BackfillFinalsPerPeriod -Plans $Plans)
    }
    return $statsByDataset
}

function Invoke-VerifyAndSummarize {
    param([object[]] $Plans, [hashtable] $StatsByDataset)
    Write-InfoLine ('')
    Write-InfoLine ('=' * 78)
    Write-InfoLine 'INGEST SUMMARY'
    Write-InfoLine ('=' * 78)
    $anyMismatch = $false
    foreach ($bucketKey in @($StatsByDataset.Keys | Sort-Object)) {
        $parts = $bucketKey -split [string][char]31, 2
        $scopeName = $parts[0]
        $exportTypeName = $parts[1]
        $stats = $StatsByDataset[$bucketKey]
        $tableName = $script:DatasetTableMap[$exportTypeName].Table
        Write-InfoLine ("  {0,10} / {1,-16} → {2,-14}  files ok={3}  skip={4}  fail={5}  manifest-rows={6,11:N0}  size={7,7:N1} MB  ingest-time={8:N1}s" -f $scopeName, $exportTypeName, $tableName, $stats.files_ingested, $stats.files_skipped, $stats.files_failed, $stats.expected_rows, ($stats.bytes_ingested / 1024.0 / 1024.0), $stats.seconds)
        if ($stats.files_failed) { $anyMismatch = $true }
    }
    $declared = @{}
    $bucketFilters = @{}
    foreach ($bucketKey in $StatsByDataset.Keys) {
        $parts = $bucketKey -split [string][char]31, 2
        $scopeName = $parts[0]
        $exportTypeName = $parts[1]
        $tableName = $script:DatasetTableMap[$exportTypeName].Table
        if (-not $declared.ContainsKey($tableName)) { $declared[$tableName] = 0L; $bucketFilters[$tableName] = @() }
        $declared[$tableName] += [int64]$StatsByDataset[$bucketKey].expected_rows
        $bucketFilters[$tableName] = @($bucketFilters[$tableName]) + [pscustomobject]@{ Scope = $scopeName; ExportType = $exportTypeName }
    }
    Write-InfoLine ''
    foreach ($tableName in @($declared.Keys | Sort-Object)) {
        $bucketPairs = (@($bucketFilters[$tableName]) | ForEach-Object { "(scope=='$($_.Scope)' and export_type=='$($_.ExportType)')" }) -join ', '
        $actualCsl = "$script:IngestManifestTable | where $bucketPairs | summarize sum(rows_ingested)"
        $got = Get-QueryScalar -CslText $actualCsl
        if ($null -eq $got) { Write-InfoLine "  $tableName`: count query failed (cannot verify)"; $anyMismatch = $true; continue }
        $want = [int64]$declared[$tableName]
        $diff = [Math]::Abs([int64]$got - $want)
        $pct = if ($want -gt 0) { $diff / [double]$want } else { 0.0 }
        $status = if ($pct -le $script:RowCountTolerance) { 'OK' } else { 'MISMATCH' }
        if ($status -eq 'MISMATCH') { $anyMismatch = $true }
        Write-InfoLine ("  {0}: ingested={1,11:N0}  manifest-declared={2,11:N0}  diff={3,7:N0} ({4:N4}%)  {5}" -f $tableName, [int64]$got, $want, $diff, ($pct * 100.0), $status)
        $full = Get-QueryScalar -CslText "$tableName | count"
        if ($null -ne $full) { Write-InfoLine ("    (table total across all runs: {0:N0})" -f [int64]$full) }
    }
    Write-InfoLine ''
    $summaryCsl = "$script:IngestManifestTable | summarize files=count(), rows=sum(rows_ingested) by scope, export_type | order by scope asc, export_type asc"
    $postResult = Invoke-KustoPost -CslText $summaryCsl -EndpointUrl $script:KustainerQuery -TimeoutSec 60
    if ($postResult.Status -ge 200 -and $postResult.Status -lt 300) {
        $jsonObject = Get-KustoJson -BodyText $postResult.Body
        $cols = Get-PrimaryColumnNames $jsonObject
        $rows = Get-PrimaryRows $jsonObject
        Write-InfoLine 'Ingest_Manifest summary:'
        Write-InfoLine ('  ' + (($cols | ForEach-Object { '{0,14}' -f $_ }) -join ' | '))
        foreach ($row in $rows) { Write-InfoLine ('  ' + (($row | ForEach-Object { '{0,14}' -f ([string]$_) }) -join ' | ')) }
    }
    return (-not $anyMismatch)
}

function Read-IngestOptions {
    param([string[]] $Tokens)
    $Tokens = @($Tokens | Where-Object { $null -ne $_ -and $_ -ne '' })
    $opts = @{ Scope = $null; Period = $null; DryRun = $false; ForcePolicyRecapture = $false }
    $idx = 0
    while ($idx -lt $Tokens.Count) {
        switch -Regex ($Tokens[$idx]) {
            '^--scope$|^-Scope$' { $idx++; if ($idx -ge $Tokens.Count) { throw 'argument --scope: expected one argument' }; $opts.Scope = $Tokens[$idx] }
            '^--period$|^-Period$' { $idx++; if ($idx -ge $Tokens.Count) { throw 'argument --period: expected one argument' }; $opts.Period = $Tokens[$idx] }
            '^--dry-run$|^-DryRun$' { $opts.DryRun = $true }
            '^--force-policy-recapture$|^-ForcePolicyRecapture$' { $opts.ForcePolicyRecapture = $true }
            '^--help$|^-h$|^-\?$' { $opts.Help = $true }
            default { throw "unrecognized arguments: $($Tokens[$idx])" }
        }
        $idx++
    }
    return $opts
}

function Show-IngestUsage {
    @'
usage: ingest.ps1 [--scope SCOPE] [--period PERIOD] [--dry-run] [--force-policy-recapture]

Bulk-ingest FOCUS Cost + Price Sheet parquet exports under ./export/ into Kustainer raw tables.
'@
}

function Invoke-IngestMain {
    param([string[]] $Arguments)
    try { $opts = Read-IngestOptions -Tokens @($Arguments) }
    catch { [Console]::Error.WriteLine("error: $($_.Exception.Message)"); return 2 }
    if ($opts.ContainsKey('Help') -and $opts.Help) { Show-IngestUsage; return 0 }
    try {
        $plans = Build-Plan -ExportRootPath $script:ExportDirHost -ScopeFilter $opts.Scope -PeriodFilter $opts.Period
        if ($plans.Count -eq 0) { Write-InfoLine 'no (scope,type,period) tuples matched filters; nothing to do'; return 0 }
        $stats = Invoke-RunIngest -Plans $plans -DryRun ([bool]$opts.DryRun) -ForcePolicyRecapture ([bool]$opts.ForcePolicyRecapture)
        if ($opts.DryRun) { Write-InfoLine "`n(dry-run; no actual ingest occurred)"; return 0 }
        $ok = Invoke-VerifyAndSummarize -Plans $plans -StatsByDataset $stats
        if ($ok) { return 0 }
        return 2
    }
    catch { [Console]::Error.WriteLine("error: $($_.Exception.Message)"); return 1 }
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-IngestMain -Arguments @($CliArgs))
}
