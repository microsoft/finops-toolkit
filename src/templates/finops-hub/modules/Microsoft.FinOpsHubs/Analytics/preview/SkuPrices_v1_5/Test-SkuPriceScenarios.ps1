<#
.SYNOPSIS
Runs each scenario in SkuPrices_v1_5_scenarios.kql against both layouts, compares results, and scores them.

.DESCRIPTION
Parses "// ## <id> <name>" scenarios with "// ### Rows" and "// ### Columns" queries. Runs each query -Runs times
(alternating sides, results cache off), and records the median of the server's execution time, CPU, peak memory, and rows
scanned (from QueryResourceConsumption). Also measures query size (lines, operators, joins, lets, x_ column references) and
whether both sides return the same answer. Writes everything to JSON for reporting.
#>
[CmdletBinding()]
param(
  [string] $Cluster = 'https://ftk-dev.westus.kusto.windows.net',
  [string] $Database = 'Ingestion',
  [string] $Context = 'fh-dev',
  [string] $Path = "$PSScriptRoot/SkuPrices_v1_5_scenarios.kql",
  [string] $OutFile = (Join-Path ([IO.Path]::GetTempPath()) 'SkuPrices_v1_5_scenarios.results.json'),
  [int] $Runs = 3,
  [string[]] $Only
)

$ErrorActionPreference = 'Stop'
Set-AzContext -Context (Get-AzContext -Name $Context) -Scope Process | Out-Null
$secure = (Get-AzAccessToken -ResourceUrl $Cluster -AsSecureString).Token
$headers = @{ Authorization = "Bearer $([System.Net.NetworkCredential]::new('', $secure).Password)" }

function ConvertTo-Seconds([string] $ts) { if (-not $ts) { return 0.0 }; [TimeSpan]::Parse($ts).TotalSeconds }

# Run a query on the v2 endpoint; return result rows plus server statistics
function Invoke-Kusto([string] $Csl) {
  $body = @{ db = $Database; csl = $Csl; properties = @{ Options = @{ servertimeout = '00:20:00'; query_results_cache_max_age = '00:00:00' } } } | ConvertTo-Json -Depth 5
  $resp = Invoke-WebRequest -Uri "$Cluster/v2/rest/query" -Method Post -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 1200 -SkipHttpErrorCheck
  if ($resp.StatusCode -ne 200) { throw "HTTP $($resp.StatusCode): $($resp.Content.Substring(0, [Math]::Min(300, $resp.Content.Length)))" }
  $frames = $resp.Content | ConvertFrom-Json -Depth 50
  $primary = $frames | Where-Object { $_.FrameType -eq 'DataTable' -and $_.TableKind -eq 'PrimaryResult' } | Select-Object -First 1
  $errors = $frames | Where-Object { $_.FrameType -eq 'DataTable' -and $_.TableKind -eq 'PrimaryResult' } | ForEach-Object { $_.Rows } | Where-Object { $_ -isnot [array] -and $_.OneApiErrors }
  if ($errors) { throw ($errors[0].OneApiErrors[0].error.'@message') }
  $info = $frames | Where-Object { $_.TableKind -eq 'QueryCompletionInformation' } | Select-Object -First 1
  $stats = $null
  if ($info) {
    $cols = $info.Columns.ColumnName
    foreach ($row in $info.Rows) { if ($row[$cols.IndexOf('EventTypeName')] -eq 'QueryResourceConsumption') { $stats = $row[$cols.IndexOf('Payload')] | ConvertFrom-Json -Depth 50 } }
  }
  [pscustomobject]@{
    Columns   = @($primary.Columns.ColumnName)
    Rows      = @($primary.Rows | Where-Object { $_ -is [array] })
    Ms        = if ($stats) { [math]::Round($stats.ExecutionTime * 1000) } else { $null }
    CpuMs     = if ($stats) { [math]::Round((ConvertTo-Seconds $stats.resource_usage.cpu.'total cpu') * 1000) } else { $null }
    MemoryMB  = if ($stats) { [math]::Round($stats.resource_usage.memory.peak_per_node / 1MB, 1) } else { $null }
    RowsScanned = if ($stats) { [long]$stats.input_dataset_statistics.rows.scanned } else { $null }
  }
}

function Get-Median([double[]] $v) { $s = $v | Sort-Object; $s[[int][math]::Floor(($s.Count - 1) / 2)] }

# Normalize a result so equivalent outputs compare equal (sorted rows, rounded numbers)
function Get-Signature($Rows) {
  ($Rows | ForEach-Object { ($_ | ForEach-Object { if ($_ -is [double] -or $_ -is [decimal] -or $_ -is [long] -or $_ -is [int]) { [math]::Round([double]$_, 4) } else { "$_" } }) -join '|' } | Sort-Object) -join "`n"
}

# Query size measures (comments ignored)
function Get-Shape([string] $q) {
  $code = ($q -split "`n" | ForEach-Object { ($_ -replace '//.*$', '').TrimEnd() } | Where-Object { $_.Trim() }) -join "`n"
  [pscustomobject]@{
    Lines     = @($code -split "`n").Count
    Operators = ([regex]::Matches($code, '\|\s*[a-z-]+')).Count
    Joins     = ([regex]::Matches($code, '\b(join|lookup)\b')).Count
    Lets      = ([regex]::Matches($code, '(?m)^\s*let\b')).Count
    XColumns  = @([regex]::Matches($code, '\bx_[A-Za-z0-9]+\b') | ForEach-Object Value | Select-Object -Unique).Count
  }
}

# Parse scenarios
$text = Get-Content -Path $Path -Raw
$scenarios = foreach ($block in ($text -split '(?m)^// ## ') | Select-Object -Skip 1) {
  $lines = $block -split "`n"
  $id, $name = $lines[0].Trim() -split ' ', 2
  $meta = @{}
  foreach ($l in $lines) { if ($l -match '^// (Question|Source|Expect|Check): (.+)$') { $meta[$Matches[1]] = $Matches[2].Trim() } }
  $q = @{}
  foreach ($part in ($block -split '(?m)^(?=// ### (?:Rows|Columns|Monthly)\s*$)') | Select-Object -Skip 1) {
    if ($part -match '^// ### (Rows|Columns|Monthly)') { $q[$Matches[1]] = ($part -replace '^// ### \w+\s*\n', '').Trim() }
  }
  [pscustomobject]@{ Id = $id; Name = $name.Trim(); Question = $meta.Question; Source = $meta.Source; Expect = $meta.Expect; Check = $meta.Check; Queries = $q }
}
if ($Only) { $scenarios = $scenarios | Where-Object Id -in $Only }

# Winner among sides: lowest value wins; within 15% (or a tiny absolute gap) of the runner-up is a tie
function Get-Winner([hashtable] $values, [double] $minGap = 0) {
  $v = $values.GetEnumerator() | Where-Object { $null -ne $_.Value } | Sort-Object Value
  if (@($v).Count -lt 2) { return 'n/a' }
  $best = $v[0]; $next = $v[1]; $hi = [math]::Max([double]$best.Value, [double]$next.Value)
  if ($hi -eq 0 -or [math]::Abs($next.Value - $best.Value) -le [math]::Max($minGap, 0.15 * $hi)) { 'Tie' } else { $best.Key }
}

$results = foreach ($s in $scenarios) {
  $sideNames = @('Rows', 'Columns', 'Monthly' | Where-Object { $s.Queries[$_] })
  $runsBySide = @{}; $err = @{}
  foreach ($side in $sideNames) { $runsBySide[$side] = @() }
  for ($i = 0; $i -lt $Runs; $i++) {
    $order = if ($i % 2) { [array]::Reverse(($o = @($sideNames))); $o } else { $sideNames }
    foreach ($side in $order) {
      if ($err[$side]) { continue }
      $csl = $s.Queries[$side] + $(if ($s.Check) { "`n" + $s.Check } else { '' })
      try { $runsBySide[$side] += Invoke-Kusto $csl } catch { $err[$side] = $_.Exception.Message }
    }
  }
  $sides = [ordered]@{}
  foreach ($side in $sideNames) {
    $shape = Get-Shape $s.Queries[$side]; $rs = $runsBySide[$side]
    $sides[$side] = if ($err[$side]) { [pscustomobject]@{ Error = $err[$side] } } else {
      [pscustomobject]@{
        Ms = Get-Median ($rs.Ms); CpuMs = Get-Median ($rs.CpuMs); MemoryMB = Get-Median ($rs.MemoryMB); RowsScanned = Get-Median ($rs.RowsScanned)
        ResultRows = $rs[0].Rows.Count; Columns = $rs[0].Columns
        Data = @($rs[0].Rows | Select-Object -First 15 | ForEach-Object { , @($_) })
        Signature = Get-Signature $rs[0].Rows
        Lines = $shape.Lines; Operators = $shape.Operators; Joins = $shape.Joins; Lets = $shape.Lets; XColumns = $shape.XColumns
      }
    }
  }
  $ok = @($sides.Values | Where-Object { -not $_.Error })
  $hasError = $ok.Count -lt $sides.Count
  $match = -not $hasError -and @($ok.Signature | Select-Object -Unique).Count -eq 1
  $expectSame = $s.Expect -like 'same*'
  $status = if ($hasError) { 'ERROR' } elseif ($match -eq $expectSame) { 'PASS' } else { 'FAIL' }
  $score = if ($status -ne 'ERROR') {
    $m = { param($f) $h = @{}; foreach ($k in $sides.Keys) { $h[$k] = & $f $sides[$k] }; $h }
    [ordered]@{
      Simpler  = Get-Winner (& $m { param($x) $x.Operators + 2 * $x.Joins + $x.Lets }) 1
      Faster   = Get-Winner (& $m { param($x) $x.Ms }) 50
      Cpu      = Get-Winner (& $m { param($x) $x.CpuMs }) 50
      Memory   = Get-Winner (& $m { param($x) $x.MemoryMB }) 5
      Scanned  = Get-Winner (& $m { param($x) $x.RowsScanned })
      Portable = Get-Winner (& $m { param($x) $x.XColumns })
      Correct  = if ($match) { 'Tie' } elseif ($s.Expect -match 'different') { 'Rows' } else { 'n/a' }
    }
  }
  $line = ($sides.Keys | ForEach-Object { $x = $sides[$_]; "{0} {1}ms cpu {2}ms {3}MB {4}ops" -f $_, $x.Ms, $x.CpuMs, $x.MemoryMB, $x.Operators }) -join '  |  '
  Write-Host ("{0,-5} {1} {2,-40} {3}  match={4}" -f $status, $s.Id, $s.Name, $line, $match)
  if ($status -eq 'ERROR') { $sides.Keys | ForEach-Object { if ($sides[$_].Error) { Write-Host "      ${_}: $($sides[$_].Error)" } } }
  $out = [ordered]@{ Id = $s.Id; Name = $s.Name; Question = $s.Question; Source = $s.Source; Expect = $s.Expect; Check = $s.Check; Status = $status; Match = $match; Score = $score; Sides = @($sideNames) }
  foreach ($side in $sideNames) { $out["${side}Query"] = $s.Queries[$side]; $out[$side] = $sides[$side] | Select-Object * -ExcludeProperty Signature }
  [pscustomobject]$out
}

$results | ConvertTo-Json -Depth 8 | Set-Content -Path $OutFile
Write-Host "`nPassed: $(@($results | Where-Object Status -eq 'PASS').Count) of $($results.Count). Results: $OutFile"
