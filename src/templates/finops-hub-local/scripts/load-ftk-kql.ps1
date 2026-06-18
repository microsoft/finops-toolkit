#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Load the FinOps Toolkit analytics KQL into local Kustainer (two-DB topology).

.DESCRIPTION
    Reads the combineKql bundles from src/templates/finops-hub/.build.config,
    concatenates the listed .kql files in dependency order, and submits each
    bundle to its target database.

    Two persisted databases are created idempotently:
      Ingestion  -- raw tables, transforms, final tables, open-data lookups
      Hub        -- view functions referencing database('Ingestion').*

    The $$rawRetentionInDays$$ macro in the Ingestion bundle is replaced with
    RawRetentionDays (default 3650).  The Hub bundle is submitted verbatim --
    database('Ingestion'). cross-DB references are preserved and resolve once
    both databases exist.

    Open-data CSVs (PricingUnits/Regions/ResourceTypes/Services) are ingested
    into the Ingestion database.

    Connection:
      KUSTAINER_MGMT  full mgmt URL (default http://localhost:<HOST_PORT>/v1/rest/mgmt)
      HOST_PORT       port (default 8082; read from .env if present)

    FTK source paths (all derived from repo root by default):
      FTK_BUILD_CONFIG   path to finops-hub .build.config
      FTK_OPEN_DATA      overrides src/open-data path
      FTK_REPO           repo root override

.EXAMPLE
    pwsh scripts/load-ftk-kql.ps1

.EXAMPLE
    pwsh scripts/load-ftk-kql.ps1 --dry-run
#>
[CmdletBinding()]
param(
    [switch] $DryRun,
    [switch] $SkipOpenData,
    [switch] $SkipKql,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $RemainingArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($RemainingArgs) {
    for ($argIndex = 0; $argIndex -lt $RemainingArgs.Count; $argIndex++) {
        switch ($RemainingArgs[$argIndex]) {
            '--dry-run'        { $DryRun = $true }
            '--skip-open-data' { $SkipOpenData = $true }
            '--skip-kql'       { $SkipKql = $true }
            default            { throw "unrecognized argument: $($RemainingArgs[$argIndex])" }
        }
    }
}

# Script lives at <repo>/src/templates/finops-hub-local/scripts/
$script:FtkLocalHome         = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$script:RepoRoot             = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $script:FtkLocalHome))
$script:RawRetentionDays     = '3650'  # default; overridden by settings.json retention.raw.days when > 0
$settingsFile = Join-Path $script:FtkLocalHome 'settings.json'
if (Test-Path $settingsFile) {
    try {
        $rawDays = (Get-Content -Raw -Path $settingsFile | ConvertFrom-Json).retention.raw.days
        if ($null -ne $rawDays -and [int]$rawDays -gt 0) {
            $script:RawRetentionDays = [string][int]$rawDays
            if ([int]$rawDays -lt 90) {
                Write-Warning "retention.raw.days=$rawDays (settings.json): local raw tables will soft-delete data older than $rawDays days. Re-ingest restores it. Consider setting raw.days >= 3650 for local analysis."
            }
        }
    }
    catch { <# silently fall back to the 3650 default above #> }
}
$script:IdempotentOkTypes    = @('Kusto.Common.Svc.Exceptions.EntityNameAlreadyExistsException')

# --------------------------------------------------------------------------- #
# Configuration / path resolution
# --------------------------------------------------------------------------- #
function Get-HostPort {
    if ($env:HOST_PORT) { return $env:HOST_PORT }
    $envFile = Join-Path $script:FtkLocalHome '.env'
    if (Test-Path $envFile) {
        foreach ($line in Get-Content -Path $envFile) {
            $trimmed = $line.Trim()
            if ($trimmed -like 'HOST_PORT=*') { return ($trimmed -split '=', 2)[1].Trim() }
        }
    }
    return '8082'
}

function Get-RepoRoot {
    if ($env:FTK_REPO) { return $env:FTK_REPO }
    return $script:RepoRoot
}

function Get-BuildConfigPath {
    if ($env:FTK_BUILD_CONFIG) { return $env:FTK_BUILD_CONFIG }
    return Join-Path (Get-RepoRoot) 'src/templates/finops-hub/.build.config'
}

function Get-OpenDataPath {
    if ($env:FTK_OPEN_DATA) { return $env:FTK_OPEN_DATA }
    return Join-Path (Get-RepoRoot) 'src/open-data'
}

function Get-MgmtUrl {
    if ($env:KUSTAINER_MGMT) { return $env:KUSTAINER_MGMT }
    return "http://localhost:$(Get-HostPort)/v1/rest/mgmt"
}

function Get-QueryUrl {
    return ((Get-MgmtUrl) -replace '/mgmt$', '/query')
}

$script:OpenData = Get-OpenDataPath
$script:MgmtUrl  = Get-MgmtUrl

# --------------------------------------------------------------------------- #
# Bundle builder -- reads .build.config and concatenates .kql files in order
# --------------------------------------------------------------------------- #
function Build-KqlBundle {
    param([Parameter(Mandatory)] [string] $BundleName)
    $configPath  = Get-BuildConfigPath
    $config      = Get-Content -Raw -Path $configPath | ConvertFrom-Json
    $entry       = $config.combineKql | Where-Object { $_.name -eq $BundleName } | Select-Object -First 1
    if (-not $entry) { throw "combineKql entry '$BundleName' not found in $(Split-Path -Leaf $configPath)" }
    $templateDir = Split-Path -Parent $configPath
    $parts       = foreach ($relPath in $entry.files) {
        Get-Content -Raw -Path (Join-Path $templateDir $relPath)
    }
    return ($parts -join "`n")
}

function Invoke-SubstMacros {
    param([Parameter(Mandatory)] [string] $Text)
    return $Text.Replace('$$rawRetentionInDays$$', $script:RawRetentionDays)
}

# --------------------------------------------------------------------------- #
# Kustainer REST poster
# --------------------------------------------------------------------------- #
function ConvertTo-BodyString {
    param($Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [string]) { return $Value }
    return ($Value | ConvertTo-Json -Depth 100 -Compress)
}

function Post-Kql {
    param(
        [Parameter(Mandatory)] [string] $Csl,
        [Parameter(Mandatory)] [string] $DatabaseName,
        [int] $TimeoutSec = 60
    )
    $payload = @{ db = $DatabaseName; csl = $Csl } | ConvertTo-Json -Compress
    $headers = @{
        'Content-Type'        = 'application/json'
        'x-ms-client-version' = 'Kusto.Python.Client:1.0.0'
        'Accept'              = 'application/json'
    }
    try {
        $statusCodeValue = $null
        $responseBody = Invoke-RestMethod -Method Post -Uri $script:MgmtUrl -Headers $headers -Body $payload `
            -TimeoutSec $TimeoutSec -SkipHttpErrorCheck -StatusCodeVariable statusCodeValue
        return [pscustomobject]@{ Status = [int]$statusCodeValue; Body = (ConvertTo-BodyString $responseBody) }
    }
    catch {
        return [pscustomobject]@{ Status = 599; Body = "URL error: $($_.Exception.GetType().FullName): $($_.Exception.Message)" }
    }
}

function Parse-KustoError {
    param([Parameter(Mandatory)] [string] $Body)
    try {
        $json = $Body | ConvertFrom-Json
        $err  = $null
        if ($json.PSObject.Properties.Name -contains 'error') { $err = $json.error }
        if ($null -ne $err) {
            $typeValue    = if ($err.PSObject.Properties.Name -contains '@type'    -and $err.'@type')    { $err.'@type'    }
                            elseif ($err.PSObject.Properties.Name -contains 'code'    -and $err.code)    { $err.code       }
                            else                                                                          { 'Unknown' }
            $messageValue = if ($err.PSObject.Properties.Name -contains '@message' -and $err.'@message') { $err.'@message' }
                            elseif ($err.PSObject.Properties.Name -contains 'message' -and $err.message) { $err.message    }
                            else                                                                          { $Body.Substring(0, [Math]::Min(200, $Body.Length)) }
            return @([string]$typeValue, [string]$messageValue)
        }
        return @('Unknown', $Body.Substring(0, [Math]::Min(200, $Body.Length)))
    }
    catch { return @('RawText', $Body.Substring(0, [Math]::Min(300, $Body.Length))) }
}

function Test-IdempotentSuccess {
    param([Parameter(Mandatory)] [string] $Body)
    return ($script:IdempotentOkTypes -contains (Parse-KustoError -Body $Body)[0])
}

# --------------------------------------------------------------------------- #
# Step reporting and execution
# --------------------------------------------------------------------------- #
function New-StepReport {
    param([Parameter(Mandatory)] [string] $Label)
    return [pscustomobject]@{
        Label        = $Label
        Total        = 0
        Ok           = 0
        IdempotentOk = 0
        Dropped      = [System.Collections.Generic.List[object]]::new()
        Failed       = [System.Collections.Generic.List[object]]::new()
    }
}

function Invoke-BundleLoad {
    param(
        [Parameter(Mandatory)] [string] $Label,
        [Parameter(Mandatory)] [string] $BundleText,
        [Parameter(Mandatory)] [string] $DatabaseName,
        [bool] $IsDryRun = $false
    )
    $report = New-StepReport -Label $Label
    Write-Host ""
    Write-Host "=== $Label [$DatabaseName] ==="
    if ($IsDryRun) {
        Write-Host "  dry   would submit the bundle as one '.execute database script' command"
        return $report
    }
    # The whole bundle is submitted as a single database script. ContinueOnErrors=true
    # makes the engine attempt every statement and return a per-statement result table
    # (OperationId, CommandType, CommandText, Result, Reason) -- so we keep per-statement
    # diagnostics without splitting the bundle ourselves.
    $databaseScript = ".execute database script with (ContinueOnErrors=true)`n<|`n$BundleText"
    $result = Post-Kql -Csl $databaseScript -DatabaseName $DatabaseName
    if ($result.Status -lt 200 -or $result.Status -ge 300) {
        $parsed = Parse-KustoError -Body $result.Body
        $report.Total = 1
        [void]$report.Failed.Add([pscustomobject]@{ Command = $Label; Error = "HTTP $($result.Status): [$($parsed[0])] $($parsed[1])" })
        Write-Host "  FAIL  batch submission failed: HTTP $($result.Status) [$($parsed[0])] $($parsed[1])"
        return $report
    }
    $rows = @()
    try { $rows = @((ConvertFrom-Json $result.Body).Tables[0].Rows) } catch { }
    $report.Total = $rows.Count
    foreach ($row in $rows) {
        if ($row[3] -eq 'Completed') {
            $report.Ok++
        }
        else {
            $commandText = if ($row[2]) { ($row[2] -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1) } else { $row[1] }
            if ($commandText.Length -gt 110) { $commandText = $commandText.Substring(0, 110) }
            [void]$report.Failed.Add([pscustomobject]@{ Command = $commandText; Error = $row[4] })
        }
    }
    Write-Host "  loaded $($report.Total) statements: $($report.Ok) completed, $($report.Failed.Count) failed"
    foreach ($failure in $report.Failed) { Write-Host "  FAIL  $($failure.Command) -- $($failure.Error)" }
    return $report
}

# --------------------------------------------------------------------------- #
# Open-data CSV ingestion (into Ingestion database)
# --------------------------------------------------------------------------- #
function ConvertTo-InlineCsvBlock {
    param([Parameter(Mandatory)] [object[]] $Rows)
    $builder = [System.Text.StringBuilder]::new()
    foreach ($row in $Rows) {
        $cells = foreach ($cell in $row) {
            $value = if ($null -eq $cell) { '' } else { [string]$cell }
            '"' + ($value -replace '"', '""') + '"'
        }
        [void]$builder.AppendLine(($cells -join ','))
    }
    return $builder.ToString()
}

function Read-CsvRows {
    param([Parameter(Mandatory)] [string] $Path)
    $csvRows = @(Import-Csv -Path $Path)
    if ($csvRows.Count -gt 0) {
        $headers = [string[]]@($csvRows[0].PSObject.Properties.Name)
    }
    else {
        $headerLine = Get-Content -Path $Path -TotalCount 1
        $headers = if ($headerLine) { [string[]]($headerLine -split ',' | ForEach-Object { $_.Trim().Trim('"') }) } else { [string[]]@() }
    }
    return [pscustomobject]@{ Headers = $headers; Rows = $csvRows }
}

function Invoke-OpenDataIngestion {
    $db     = 'Ingestion'
    $report = New-StepReport -Label 'Open-data CSV ingestion (PricingUnits/Regions/ResourceTypes/Services)'
    $plans  = @(
        [pscustomobject]@{ Table = 'PricingUnits'; Path = (Join-Path $script:OpenData 'PricingUnits.csv'); Columns = @(
            [pscustomobject]@{ Target = 'x_PricingUnitDescription'; Source = 'UnitOfMeasure';   Type = 'string' },
            [pscustomobject]@{ Target = 'x_PricingBlockSize';       Source = 'PricingBlockSize'; Type = 'real'   },
            [pscustomobject]@{ Target = 'PricingUnit';              Source = 'DistinctUnits';    Type = 'string' }
        ) },
        [pscustomobject]@{ Table = 'Regions'; Path = (Join-Path $script:OpenData 'Regions.csv'); Columns = @(
            [pscustomobject]@{ Target = 'ResourceLocation'; Source = 'OriginalValue'; Type = 'string' },
            [pscustomobject]@{ Target = 'RegionId';         Source = 'RegionId';      Type = 'string' },
            [pscustomobject]@{ Target = 'RegionName';       Source = 'RegionName';    Type = 'string' }
        ) },
        [pscustomobject]@{ Table = 'ResourceTypes'; Path = (Join-Path $script:OpenData 'ResourceTypes.csv'); Columns = @(
            [pscustomobject]@{ Target = 'x_ResourceType';           Source = 'ResourceType';             Type = 'string' },
            [pscustomobject]@{ Target = 'SingularDisplayName';      Source = 'SingularDisplayName';      Type = 'string' },
            [pscustomobject]@{ Target = 'PluralDisplayName';        Source = 'PluralDisplayName';        Type = 'string' },
            [pscustomobject]@{ Target = 'LowerSingularDisplayName'; Source = 'LowerSingularDisplayName'; Type = 'string' },
            [pscustomobject]@{ Target = 'LowerPluralDisplayName';   Source = 'LowerPluralDisplayName';   Type = 'string' },
            [pscustomobject]@{ Target = 'IsPreview';                Source = 'IsPreview';                Type = 'bool'   },
            [pscustomobject]@{ Target = 'Description';              Source = 'Description';              Type = 'string' },
            [pscustomobject]@{ Target = 'IconUri';                  Source = 'Icon';                     Type = 'string' }
        ) },
        [pscustomobject]@{ Table = 'Services'; Path = (Join-Path $script:OpenData 'Services.csv'); Columns = @(
            [pscustomobject]@{ Target = 'x_ConsumedService';   Source = 'ConsumedService';   Type = 'string' },
            [pscustomobject]@{ Target = 'x_ResourceType';      Source = 'ResourceType';      Type = 'string' },
            [pscustomobject]@{ Target = 'ServiceName';         Source = 'ServiceName';       Type = 'string' },
            [pscustomobject]@{ Target = 'ServiceCategory';     Source = 'ServiceCategory';   Type = 'string' },
            [pscustomobject]@{ Target = 'ServiceSubcategory';  Source = 'ServiceSubcategory'; Type = 'string' },
            [pscustomobject]@{ Target = 'PublisherName';       Source = 'PublisherName';     Type = 'string' },
            [pscustomobject]@{ Target = 'x_PublisherCategory'; Source = 'PublisherType';     Type = 'string' },
            [pscustomobject]@{ Target = 'x_Environment';       Source = 'Environment';       Type = 'string' },
            [pscustomobject]@{ Target = 'x_ServiceModel';      Source = 'ServiceModel';      Type = 'string' }
        ) }
    )

    Write-Host ""
    Write-Host "=== $($report.Label) [$db] ==="
    foreach ($plan in $plans) {
        $report.Total++
        try {
            $csvData = Read-CsvRows -Path $plan.Path
            foreach ($col in $plan.Columns) {
                if ($csvData.Headers -notcontains $col.Source) { throw "'$($col.Source)' not found in CSV headers" }
            }
        }
        catch {
            [void]$report.Failed.Add([pscustomobject]@{ Command = $plan.Table; Error = "CSV header mismatch: $($_.Exception.Message)" })
            Write-Host "  FAIL  $($plan.Table): header mismatch $($_.Exception.Message)"
            continue
        }

        $projectedRows = foreach ($csvRow in $csvData.Rows) {
            $rowValues = foreach ($col in $plan.Columns) {
                $prop = $csvRow.PSObject.Properties[$col.Source]
                if ($null -eq $prop -or $null -eq $prop.Value) { '' } else { [string]$prop.Value }
            }
            ,([object[]]$rowValues)
        }
        $csvBody = ConvertTo-InlineCsvBlock -Rows @($projectedRows)

        $clearResult = Post-Kql -Csl ".clear table $($plan.Table) data" -DatabaseName $db
        if (-not ($clearResult.Status -ge 200 -and $clearResult.Status -lt 300)) {
            [void]$report.Failed.Add([pscustomobject]@{ Command = $plan.Table; Error = "clear failed: HTTP $($clearResult.Status): $($clearResult.Body.Substring(0, [Math]::Min(200, $clearResult.Body.Length)))" })
            Write-Host "  FAIL  $($plan.Table): clear failed $($clearResult.Status)"
            continue
        }

        $ingestCommand = ".ingest inline into table $($plan.Table) with (format='csv') <|`n$($csvBody.TrimEnd("`r", "`n"))"
        $ingestResult  = Post-Kql -Csl $ingestCommand -DatabaseName $db -TimeoutSec 180
        if (-not ($ingestResult.Status -ge 200 -and $ingestResult.Status -lt 300)) {
            $shortBody = $ingestResult.Body.Substring(0, [Math]::Min(200, $ingestResult.Body.Length))
            [void]$report.Failed.Add([pscustomobject]@{ Command = $plan.Table; Error = "ingest failed: HTTP $($ingestResult.Status): $shortBody" })
            Write-Host "  FAIL  $($plan.Table): ingest failed $($ingestResult.Status): $shortBody"
            continue
        }

        try {
            $countPayload  = @{ db = $db; csl = "$($plan.Table) | count" } | ConvertTo-Json -Compress
            $queryResponse = Invoke-RestMethod -Method Post -Uri (Get-QueryUrl) -Headers @{ 'Content-Type' = 'application/json' } -Body $countPayload -TimeoutSec 30
            $count         = [int]$queryResponse.Tables[0].Rows[0][0]
            $expected      = @($csvData.Rows).Count
            if ($count -ne $expected) {
                [void]$report.Failed.Add([pscustomobject]@{ Command = $plan.Table; Error = "row count $count != expected $expected" })
                Write-Host "  FAIL  $($plan.Table): row count $count != expected $expected"
                continue
            }
            $report.Ok++
            Write-Host "  OK    $($plan.Table): $count rows"
        }
        catch {
            [void]$report.Failed.Add([pscustomobject]@{ Command = $plan.Table; Error = "count verification failed: $($_.Exception.Message)" })
            Write-Host "  FAIL  $($plan.Table): count verification $($_.Exception.Message)"
        }
    }
    return $report
}

# --------------------------------------------------------------------------- #
# Summary / main
# --------------------------------------------------------------------------- #
function Write-Summary {
    param([Parameter(Mandatory)] [object[]] $Reports)
    Write-Host ""
    Write-Host ('=' * 78)
    Write-Host 'SUMMARY'
    Write-Host ('=' * 78)
    $anyFailed = $false
    foreach ($rpt in $Reports) {
        Write-Host ("  $($rpt.Label): total=$($rpt.Total) ok=$($rpt.Ok) idempotent_ok=$($rpt.IdempotentOk) dropped=$($rpt.Dropped.Count) failed=$($rpt.Failed.Count)")
        if ($rpt.Failed.Count -gt 0) {
            $anyFailed = $true
            foreach ($failure in $rpt.Failed) {
                Write-Host "      FAIL: $($failure.Command)"
                Write-Host "            $($failure.Error)"
            }
        }
    }
    return (-not $anyFailed)
}

try {
    $reports = [System.Collections.Generic.List[object]]::new()

    if (-not $SkipKql) {
        # 1. Bootstrap: create Ingestion and Hub databases (idempotent)
        foreach ($dbName in @('Ingestion', 'Hub')) {
            $csl = ".create database $dbName persist (@'/kustodata/dbs/$dbName/md', @'/kustodata/dbs/$dbName/data')"
            if ($DryRun) {
                Write-Host "  BOOTSTRAP  dry  .create database $dbName persist ..."
            }
            else {
                $result = Post-Kql -Csl $csl -DatabaseName 'NetDefaultDB'
                if ($result.Status -ge 200 -and $result.Status -lt 300) {
                    Write-Host "  BOOTSTRAP  Created database '$dbName'."
                }
                elseif (Test-IdempotentSuccess -Body $result.Body) {
                    Write-Host "  BOOTSTRAP  Database '$dbName' already exists (idempotent)."
                }
                else {
                    $parsed = Parse-KustoError -Body $result.Body
                    throw "Failed to create database '$dbName': [$($parsed[0])] $($parsed[1])"
                }
            }
        }

        # 2. Ingestion bundle -- apply $$rawRetentionInDays$$ macro substitution
        $ingestionText = Invoke-SubstMacros -Text (Build-KqlBundle -BundleName 'finops-hub-fabric-setup-Ingestion.kql')
        [void]$reports.Add((Invoke-BundleLoad -Label 'finops-hub-fabric-setup-Ingestion.kql' `
            -BundleText $ingestionText -DatabaseName 'Ingestion' -IsDryRun:$DryRun.IsPresent))

        # 3. Hub bundle -- submitted verbatim; database('Ingestion'). refs preserved
        $hubText = Build-KqlBundle -BundleName 'finops-hub-fabric-setup-Hub.kql'
        [void]$reports.Add((Invoke-BundleLoad -Label 'finops-hub-fabric-setup-Hub.kql' `
            -BundleText $hubText -DatabaseName 'Hub' -IsDryRun:$DryRun.IsPresent))
    }

    if (-not $SkipOpenData -and -not $DryRun) {
        [void]$reports.Add((Invoke-OpenDataIngestion))
    }

    $ok = Write-Summary -Reports ([object[]]$reports.ToArray())
    if ($ok) { exit 0 }
    exit 1
}
catch {
    Write-Error "error: $($_.Exception.Message)"
    exit 2
}
