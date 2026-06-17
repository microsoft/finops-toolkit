#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs FTK-Local parity checks against the local Kustainer databases.

.DESCRIPTION
    Runs the ftklocal parity-check suite against the two-DB topology
    (Ingestion + Hub). Reads tests/parity-checks.kql, executes each numbered
    CHECK block against the appropriate database, evaluates the EVAL rule from
    the block's comment header, and prints a pass/fail report.

    Database routing (enforced per-check):
      Checks 1–8, 11  → Ingestion  (raw tables, final tables)
      Checks  9, 10   → Hub        (Costs_v1_2 and other Hub view functions)

    After the file-based checks, a synthetic NAME-PARITY check (CHECK 12)
    verifies that no object in either database has a FtkLocal-prefixed name and
    that all expected core tables / functions are present.

    Exit code 0 only if ALL checks pass. Non-zero means at least one parity
    violation.

    Connection:
      KUSTAINER_QUERY  full query URL (default http://localhost:<HOST_PORT>/v1/rest/query)
      HOST_PORT        port           (default 8082; read from .env if present)
      FTK_DB           default database for Ingestion-targeted checks
                       (default Ingestion; Hub checks are always routed to Hub)

.EXAMPLE
    pwsh scripts/run-parity-checks.ps1

.EXAMPLE
    pwsh scripts/run-parity-checks.ps1 --check 3 --check 5
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$script:ParityFile = Join-Path $script:RepoRoot 'tests/parity-checks.kql'

function Get-HostPort {
    if ($env:HOST_PORT) { return $env:HOST_PORT }
    $envFile = Join-Path $script:RepoRoot '.env'
    if (Test-Path $envFile) {
        foreach ($line in Get-Content -Path $envFile) {
            $trimmed = $line.Trim()
            if ($trimmed -like 'HOST_PORT=*') { return ($trimmed -split '=', 2)[1].Trim() }
        }
    }
    return '8082'
}

function Get-QueryUrl {
    param([string] $Override)
    if ($Override) { return $Override }
    if ($env:KUSTAINER_QUERY) {
        if ($env:KUSTAINER_QUERY -match '/v1/rest/(query|mgmt)$') { return $env:KUSTAINER_QUERY }
        return "$($env:KUSTAINER_QUERY.TrimEnd('/'))/v1/rest/query"
    }
    return "http://localhost:$(Get-HostPort)/v1/rest/query"
}

function Get-Database {
    param([string] $Override)
    if ($Override) { return $Override }
    if ($env:FTK_DB) { return $env:FTK_DB }
    return 'Ingestion'
}

class ParityCheck {
    [int] $Number
    [string] $Name
    [string] $Expect
    [string] $Evaluator
    [string] $Kql
    [string] $EvalKind = 'manual'
    [Nullable[double]] $EvalArg
    [string] $EvalCol
    # Which Kustainer database to run this check against.  Defaults to the
    # caller-supplied baseline (Ingestion).  Hub checks (9, 10) are overridden
    # to 'Hub' after parsing so they resolve Costs_v1_2 and other Hub functions.
    [string] $Database = ''

    ParityCheck([int] $number, [string] $name, [string] $expect, [string] $evaluator, [string] $kql) {
        $this.Number = $number
        $this.Name = $name
        $this.Expect = $expect
        $this.Evaluator = $evaluator
        $this.Kql = $kql
    }
}

function Set-Evaluator {
    param([Parameter(Mandatory)] [ParityCheck] $CheckItem)

    $evaluatorText = $CheckItem.Evaluator.ToLowerInvariant()
    if ($evaluatorText.Contains('result == 0') -or $evaluatorText.Contains('should be 0')) {
        $CheckItem.EvalKind = 'zero'
    }
    elseif ($evaluatorText.Contains('abs(') -and ($evaluatorText.Contains('<=') -or $evaluatorText.Contains('<'))) {
        $match = [regex]::Match($evaluatorText, '<=?\s*([0-9.]+)')
        if ($match.Success) {
            $CheckItem.EvalKind = 'within_pct'
            $value = [double]$match.Groups[1].Value
            if ($evaluatorText.Contains('pct') -or $value -lt 1.0) {
                $CheckItem.EvalArg = $value * 100
            }
            else {
                $CheckItem.EvalArg = $value
            }
        }
    }
    elseif ($evaluatorText.Contains('at least one row') -or $evaluatorText.Contains('non-empty')) {
        $CheckItem.EvalKind = 'nonzero'
    }
    else {
        $CheckItem.EvalKind = 'manual'
    }
}

function Get-ParityChecks {
    param([Parameter(Mandatory)] [string] $Text)

    $parts = [regex]::Split($Text, '(?m)^// CHECK ')
    if ($parts.Count -lt 2) {
        throw 'No CHECK blocks found in parity-checks.kql'
    }

    $checks = @()
    foreach ($block in @($parts | Select-Object -Skip 1)) {
        $headerMatch = [regex]::Match($block, '(\d+):\s*(.+)')
        if (-not $headerMatch.Success) { continue }

        $number = [int]$headerMatch.Groups[1].Value
        $name = $headerMatch.Groups[2].Value.Trim()

        $expectMatch = [regex]::Match($block, '(?m)^// EXPECT:\s*(.+?)$')
        $evalMatch = [regex]::Match($block, '(?m)^// EVAL:\s*(.+?)$')
        $expect = if ($expectMatch.Success) { $expectMatch.Groups[1].Value.Trim() } else { '' }
        $evaluator = if ($evalMatch.Success) { $evalMatch.Groups[1].Value.Trim() } else { '' }

        $kqlLines = @()
        $inKql = $false
        foreach ($line in ($block -split "`r?`n")) {
            if (-not $inKql) {
                if ($line.StartsWith('//') -or $line -match '^\d+:' -or -not $line.Trim()) {
                    continue
                }
                $inKql = $true
            }
            $kqlLines += $line
        }
        $kql = ($kqlLines -join "`n").Trim()

        $checkItem = [ParityCheck]::new($number, $name, $expect, $evaluator, $kql)
        Set-Evaluator -CheckItem $checkItem
        $checks += $checkItem
    }

    return $checks
}

function Invoke-KustoQuery {
    param(
        [Parameter(Mandatory)] [string] $Endpoint,
        [Parameter(Mandatory)] [string] $Database,
        [Parameter(Mandatory)] [string] $Kql
    )

    $url = if ($Endpoint -match '/v1/rest/query$') { $Endpoint } else { "$($Endpoint.TrimEnd('/'))/v1/rest/query" }
    $body = @{ db = $Database; csl = $Kql } | ConvertTo-Json -Compress
    $headers = @{
        'Content-Type'        = 'application/json'
        'x-ms-client-version' = 'Kusto.Python.Client:1.0.0'
    }

    try {
        return Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $body -TimeoutSec 60
    }
    catch {
        $raw = $null
        try { $raw = $_.ErrorDetails.Message } catch { }
        if (-not $raw) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $raw = (New-Object IO.StreamReader($stream)).ReadToEnd()
            } catch { }
        }
        if (-not $raw) { $raw = $_.Exception.Message }

        $status = $null
        try { $status = [int]$_.Exception.Response.StatusCode } catch { }
        if ($status) {
            throw "Kusto HTTP ${status}: $($raw.Substring(0, [Math]::Min(500, $raw.Length)))"
        }
        throw $raw
    }
}

function Get-PrimaryResult {
    param([Parameter(Mandatory)] $Response)

    if (-not ($Response.PSObject.Properties.Name -contains 'Tables') -or -not $Response.Tables) {
        $json = $Response | ConvertTo-Json -Depth 20 -Compress
        throw "Unexpected response shape: $($json.Substring(0, [Math]::Min(200, $json.Length)))"
    }
    $table = $Response.Tables[0]
    $cols = @($table.Columns | ForEach-Object { $_.ColumnName })
    $rows = @($table.Rows)
    return [pscustomobject]@{ Columns = $cols; Rows = $rows }
}

function Format-PythonValue {
    param($Value)

    if ($null -eq $Value) { return 'None' }
    if ($Value -is [string]) { return "'" + ($Value -replace "'", "\'") + "'" }
    if ($Value -is [bool]) { return $(if ($Value) { 'True' } else { 'False' }) }
    return [string]$Value
}

function Format-PythonList {
    param($Value)

    if ($null -eq $Value) { return 'None' }
    if ($Value -is [System.Array]) {
        $items = foreach ($item in $Value) { Format-PythonList $item }
        return '[' + ($items -join ', ') + ']'
    }
    return (Format-PythonValue $Value)
}

function Get-Cell {
    param($Row, [int] $Index)

    if ($Row -is [System.Array]) { return $Row[$Index] }
    return $Row[$Index]
}

function Get-RowCount {
    param($Rows)
    if ($null -eq $Rows) { return 0 }
    return @($Rows).Count
}

function Get-RowSlice {
    param($Rows, [int] $Count)
    $allRows = @($Rows)
    if ($allRows.Count -eq 0) { return @() }
    $slice = @()
    for ($i = 0; $i -lt [Math]::Min($Count, $allRows.Count); $i++) {
        $slice += , $allRows[$i]
    }
    return , $slice
}

function Test-ParityCheck {
    param(
        [Parameter(Mandatory)] [ParityCheck] $CheckItem,
        [Parameter(Mandatory)] [string[]] $Columns,
        [Parameter(Mandatory)] $Rows
    )

    $rowCount = Get-RowCount $Rows

    if ($CheckItem.EvalKind -eq 'zero') {
        if ($rowCount -eq 0) {
            return [pscustomobject]@{ Status = 'FAIL'; Explanation = 'no rows returned (expected one with value 0)' }
        }
        $value = Get-Cell -Row $Rows[0] -Index 0
        if ($null -eq $value -or $value -eq 0 -or $value -eq 0.0) {
            return [pscustomobject]@{ Status = 'PASS'; Explanation = "result = $(Format-PythonValue $value)" }
        }
        return [pscustomobject]@{ Status = 'FAIL'; Explanation = "expected 0, got $value" }
    }

    if ($CheckItem.EvalKind -eq 'within_pct') {
        if (($Columns -contains 'delta_pct') -and $rowCount -gt 0) {
            $delta = [Math]::Abs([double](Get-Cell -Row $Rows[0] -Index ([array]::IndexOf($Columns, 'delta_pct'))))
            $tolerance = if ($null -ne $CheckItem.EvalArg) { [double]$CheckItem.EvalArg } else { 5.0 }
            if ($delta -le $tolerance) {
                return [pscustomobject]@{ Status = 'PASS'; Explanation = ('delta = {0:F4}% within {1}%' -f $delta, $tolerance) }
            }
            return [pscustomobject]@{ Status = 'FAIL'; Explanation = ('delta = {0:F4}% exceeds {1}%' -f $delta, $tolerance) }
        }
        if (($Columns -contains 'delta_abs') -and $rowCount -gt 0) {
            $delta = [Math]::Abs([double](Get-Cell -Row $Rows[0] -Index ([array]::IndexOf($Columns, 'delta_abs'))))
            if ($delta -lt 1.0) {
                return [pscustomobject]@{ Status = 'PASS'; Explanation = ('delta = ${0:F6}' -f $delta) }
            }
            return [pscustomobject]@{ Status = 'FAIL'; Explanation = ('delta = ${0:F2} (too large for rounding)' -f $delta) }
        }
        $firstRow = if ($rowCount -gt 0) { Format-PythonList $Rows[0] } else { 'empty' }
        return [pscustomobject]@{ Status = 'MANUAL'; Explanation = "cols=$(Format-PythonList $Columns), first_row=$firstRow" }
    }

    if ($CheckItem.EvalKind -eq 'nonzero') {
        if ($rowCount -eq 0) {
            return [pscustomobject]@{ Status = 'FAIL'; Explanation = 'no rows returned (expected at least one)' }
        }
        for ($colIndex = 0; $colIndex -lt $Columns.Count; $colIndex++) {
            try {
                if ([double](Get-Cell -Row $Rows[0] -Index $colIndex) -gt 0) {
                    return [pscustomobject]@{ Status = 'PASS'; Explanation = "top row $($Columns[$colIndex]) = $(Get-Cell -Row $Rows[0] -Index $colIndex)" }
                }
            }
            catch {
                continue
            }
        }
        return [pscustomobject]@{ Status = 'FAIL'; Explanation = "no positive numeric in top row: $(Format-PythonList $Rows[0])" }
    }

    $preview = if ($rowCount -gt 0) { Get-RowSlice -Rows $Rows -Count 5 } else { @() }
    return [pscustomobject]@{ Status = 'MANUAL'; Explanation = "cols=$(Format-PythonList $Columns), rows[:5]=$(Format-PythonList $preview)" }
}

function Read-Options {
    param([string[]] $Tokens)

    $opts = @{ checks = @() }
    $i = 0
    while ($i -lt $Tokens.Count) {
        switch ($Tokens[$i]) {
            '--db'       { $opts.db = $Tokens[++$i] }
            '-Db'        { $opts.db = $Tokens[++$i] }
            '--endpoint' { $opts.endpoint = $Tokens[++$i] }
            '-Endpoint'  { $opts.endpoint = $Tokens[++$i] }
            '--check'    { $opts.checks += [int]$Tokens[++$i] }
            '-Check'     { $opts.checks += [int]$Tokens[++$i] }
            default      { throw "unrecognized arguments: $($Tokens[$i])" }
        }
        $i++
    }
    return $opts
}

function Test-NameParity {
    param(
        [Parameter(Mandatory)] [string] $Endpoint,
        [Parameter(Mandatory)] [string] $IngestionDb,
        [Parameter(Mandatory)] [string] $HubDb
    )

    $ingestionQueryUrl = if ($Endpoint -match '/v1/rest/query$') { $Endpoint } else { "$($Endpoint.TrimEnd('/'))/v1/rest/query" }

    function Invoke-NameQuery {
        param([string] $Db, [string] $Csl)
        $body = @{ db = $Db; csl = $Csl } | ConvertTo-Json -Compress
        $headers = @{ 'Content-Type' = 'application/json'; 'x-ms-client-version' = 'Kusto.Python.Client:1.0.0' }
        try {
            $resp = Invoke-RestMethod -Method Post -Uri $ingestionQueryUrl -Headers $headers -Body $body -TimeoutSec 30
            $cols = @($resp.Tables[0].Columns | ForEach-Object { $_.ColumnName })
            $rows = @($resp.Tables[0].Rows)
            return @{ Cols = $cols; Rows = $rows; Error = $null }
        }
        catch { return @{ Cols = @(); Rows = @(); Error = $_.Exception.Message } }
    }

    $ingTables = Invoke-NameQuery -Db $IngestionDb -Csl '.show tables | project TableName'
    if ($ingTables.Error) {
        return [pscustomobject]@{ Status = 'FAIL'; Explanation = "cannot query Ingestion tables: $($ingTables.Error)" }
    }

    $hubFunctions = Invoke-NameQuery -Db $HubDb -Csl '.show functions | project Name'
    if ($hubFunctions.Error) {
        return [pscustomobject]@{ Status = 'FAIL'; Explanation = "cannot query Hub functions: $($hubFunctions.Error)" }
    }

    $tableNames = @($ingTables.Rows | ForEach-Object { [string]$_[0] })
    $funcNames  = @($hubFunctions.Rows | ForEach-Object { [string]$_[0] })

    # Assert no FtkLocal-prefixed or -suffixed objects exist
    $ftkLocalObjects = @($tableNames | Where-Object { $_ -imatch 'FtkLocal' }) +
                       @($funcNames  | Where-Object { $_ -imatch 'FtkLocal' })
    if ($ftkLocalObjects.Count -gt 0) {
        return [pscustomobject]@{ Status = 'FAIL'; Explanation = "FtkLocal-named objects found: $($ftkLocalObjects -join ', ')" }
    }

    # Assert expected core Ingestion tables are present
    $requiredTables = @('Costs_raw','Prices_raw','Costs_final_v1_2','Prices_final_v1_2')
    $missingTables = @($requiredTables | Where-Object { $tableNames -notcontains $_ })
    if ($missingTables.Count -gt 0) {
        return [pscustomobject]@{ Status = 'FAIL'; Explanation = "Ingestion missing expected tables: $($missingTables -join ', ')" }
    }

    # Assert expected core Hub functions are present
    $requiredFuncs = @('Costs_v1_2','Prices_v1_2','Costs','Prices')
    $missingFuncs = @($requiredFuncs | Where-Object { $funcNames -notcontains $_ })
    if ($missingFuncs.Count -gt 0) {
        return [pscustomobject]@{ Status = 'FAIL'; Explanation = "Hub missing expected functions: $($missingFuncs -join ', ')" }
    }

    return [pscustomobject]@{ Status = 'PASS'; Explanation = "Ingestion: $($tableNames.Count) table(s), Hub: $($funcNames.Count) function(s); no FtkLocal objects; all core names present" }
}

function Main {
    param([string[]] $Tokens)

    $opts = Read-Options -Tokens $Tokens
    $endpoint = Get-QueryUrl $(if ($opts.ContainsKey('endpoint')) { $opts.endpoint } else { $null })
    $database = Get-Database $(if ($opts.ContainsKey('db')) { $opts.db } else { $null })

    $text = Get-Content -Raw -Path $script:ParityFile
    $checks = @(Get-ParityChecks -Text $text)

    # Route Hub-view checks to the Hub database regardless of --db default.
    # CHECK 9: Costs_v1_2 aggregation (Hub function)
    # CHECK 10: Costs_v1_2 vs Costs_final_v1_2 reconciliation (Hub, with cross-DB ref)
    foreach ($checkItem in $checks) {
        if ($checkItem.Number -in @(9, 10)) {
            $checkItem.Database = 'Hub'
        }
    }

    if ($opts.checks.Count -gt 0) {
        $selected = @{}
        foreach ($checkNumber in $opts.checks) { $selected[$checkNumber] = $true }
        $checks = @($checks | Where-Object { $selected.ContainsKey($_.Number) })
    }

    Write-Host "Loaded $($checks.Count) parity check(s) from $script:ParityFile`n"

    $passCount = 0
    $failCount = 0
    $manualCount = 0
    $failures = @()

    foreach ($checkItem in $checks) {
        # Per-check database: Hub checks use Hub; all others use the $database default (Ingestion).
        $checkDb = if ($checkItem.Database) { $checkItem.Database } else { $database }
        Write-Host "━━━ CHECK $($checkItem.Number): $($checkItem.Name) [DB: $checkDb] ━━━"
        Write-Host "  EXPECT: $($checkItem.Expect)"
        try {
            $response = Invoke-KustoQuery -Endpoint $endpoint -Database $checkDb -Kql $checkItem.Kql
            $result = Get-PrimaryResult -Response $response
            $columns = $result.Columns
            $rows = $result.Rows
            $evaluation = Test-ParityCheck -CheckItem $checkItem -Columns $columns -Rows $rows
            $status = $evaluation.Status
            $explanation = $evaluation.Explanation
        }
        catch {
            $status = 'FAIL'
            $explanation = "query error: $($_.Exception.Message)"
            $columns = @()
            $rows = @()
        }

        $marker = @{ PASS = '✓'; FAIL = '✗'; MANUAL = '?' }[$status]
        Write-Host "  $marker ${status}: $explanation"
        if ((Get-RowCount $rows) -gt 0 -and $status -ne 'PASS') {
            $preview = Get-RowSlice -Rows $rows -Count 3
            Write-Host "    rows[:3] = $(Format-PythonList $preview)"
        }
        Write-Host ''

        if ($status -eq 'PASS') {
            $passCount++
        }
        elseif ($status -eq 'FAIL') {
            $failCount++
            $failures += [pscustomobject]@{ Check = $checkItem; Explanation = $explanation; Columns = $columns; Rows = $rows }
        }
        else {
            $manualCount++
        }
    }

    # Synthetic CHECK 12: name-parity — Ingestion tables and Hub functions.
    # Only skip if the user filtered to specific checks and didn't include 12.
    $runNameParity = $opts.checks.Count -eq 0 -or ($opts.checks -contains 12)
    if ($runNameParity) {
        Write-Host "━━━ CHECK 12: Name parity — Ingestion tables + Hub functions [DB: Ingestion+Hub] ━━━"
        Write-Host "  EXPECT: No FtkLocal-named objects; required core tables and functions present."
        try {
            $evaluation = Test-NameParity -Endpoint $endpoint -IngestionDb $database -HubDb 'Hub'
            $status = $evaluation.Status
            $explanation = $evaluation.Explanation
        }
        catch {
            $status = 'FAIL'
            $explanation = "name-parity check error: $($_.Exception.Message)"
        }
        $marker = @{ PASS = '✓'; FAIL = '✗'; MANUAL = '?' }[$status]
        Write-Host "  $marker ${status}: $explanation"
        Write-Host ''
        if ($status -eq 'PASS') { $passCount++ }
        elseif ($status -eq 'FAIL') {
            $failCount++
            $dummyCheck = [ParityCheck]::new(12, 'Name parity', '', '', '')
            $failures += [pscustomobject]@{ Check = $dummyCheck; Explanation = $explanation; Columns = @(); Rows = @() }
        }
        else { $manualCount++ }
    }

    Write-Host ('━' * 60)
    Write-Host "SUMMARY: $passCount pass, $failCount fail, $manualCount manual (of $($checks.Count + ($runNameParity ? 1 : 0)) total)"
    if ($failures.Count -gt 0) {
        Write-Host "`nFAILURES:"
        foreach ($failure in $failures) {
            Write-Host "  CHECK $($failure.Check.Number) ($($failure.Check.Name)): $($failure.Explanation)"
        }
        Write-Host "`nWrite a gap report at notes/parity-gaps.md for each failure before re-running."
        return 1
    }
    if ($manualCount -gt 0) {
        Write-Host "`nManual checks above require human inspection but did not block the run."
    }
    return 0
}

exit (Main -Tokens $args)
