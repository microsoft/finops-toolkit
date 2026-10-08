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
  [string] $OutFile = (Join-Path ([IO.Path]::GetTempPath()) "SkuPrices_v1_5_scenarios.results.json"),
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
  foreach ($l in $lines) { if ($l -match '^// (Question|Source|Expect): (.+)$') { $meta[$Matches[1]] = $Matches[2].Trim() } }
  $rowsQuery = (($block -split '(?m)^// ### Rows\s*$')[1] -split '(?m)^// ### Columns\s*$')[0]
  $colsQuery = ($block -split '(?m)^// ### Columns\s*$')[1]
  [pscustomobject]@{ Id = $id; Name = $name.Trim(); Question = $meta.Question; Source = $meta.Source; Expect = $meta.Expect; RowsQuery = $rowsQuery.Trim(); ColumnsQuery = $colsQuery.Trim() }
}
if ($Only) { $scenarios = $scenarios | Where-Object Id -in $Only }

$results = foreach ($s in $scenarios) {
  $runsBySide = @{ Rows = @(); Columns = @() }
  $err = @{}
  for ($i = 0; $i -lt $Runs; $i++) {
    foreach ($side in $(if ($i % 2) { 'Columns', 'Rows' } else { 'Rows', 'Columns' })) {
      if ($err[$side]) { continue }
      try { $runsBySide[$side] += Invoke-Kusto $s."${side}Query" } catch { $err[$side] = $_.Exception.Message }
    }
  }
  $sides = @{}
  foreach ($side in 'Rows', 'Columns') {
    $q = $s."${side}Query"; $shape = Get-Shape $q; $rs = $runsBySide[$side]
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
  $R = $sides.Rows; $C = $sides.Columns
  $match = -not $R.Error -and -not $C.Error -and $R.Signature -eq $C.Signature
  $expectSame = $s.Expect -like 'same*'
  $status = if ($R.Error -or $C.Error) { 'ERROR' } elseif ($match -eq $expectSame) { 'PASS' } else { 'FAIL' }

  # Winners: lower is better; within 15% (or tiny absolute gap) is a tie
  function Win($r, $c, $minGap = 0) { if ($null -eq $r -or $null -eq $c) { return 'n/a' }; $hi = [math]::Max($r, $c); if ($hi -eq 0 -or [math]::Abs($r - $c) -le [math]::Max($minGap, 0.15 * $hi)) { 'Tie' } elseif ($r -lt $c) { 'Rows' } else { 'Columns' } }
  $score = if ($status -ne 'ERROR') {
    [ordered]@{
      Simpler = Win ($R.Operators + 2 * $R.Joins + $R.Lets) ($C.Operators + 2 * $C.Joins + $C.Lets) 1
      Faster  = Win $R.Ms $C.Ms 50
      Cpu     = Win $R.CpuMs $C.CpuMs 50
      Memory  = Win $R.MemoryMB $C.MemoryMB 5
      Scanned = Win $R.RowsScanned $C.RowsScanned
      Portable = Win $R.XColumns $C.XColumns
      Correct = if ($match) { 'Tie' } elseif ($s.Expect -match 'different') { 'Rows' } else { 'n/a' }
    }
  }
  Write-Host ("{0,-5} {1} {2,-42} rows {3,6}ms cpu {4,6}ms {5,6}MB {6,4}ops  cols {7,6}ms cpu {8,6}ms {9,6}MB {10,4}ops  match={11}" -f $status, $s.Id, $s.Name, $R.Ms, $R.CpuMs, $R.MemoryMB, $R.Operators, $C.Ms, $C.CpuMs, $C.MemoryMB, $C.Operators, $match)
  if ($status -eq 'ERROR') { Write-Host "      Rows: $($R.Error)`n      Columns: $($C.Error)" }
  [pscustomobject]@{ Id = $s.Id; Name = $s.Name; Question = $s.Question; Source = $s.Source; Expect = $s.Expect; Status = $status; Match = $match; Score = $score
    RowsQuery = $s.RowsQuery; ColumnsQuery = $s.ColumnsQuery
    Rows = $R | Select-Object * -ExcludeProperty Signature; Columns = $C | Select-Object * -ExcludeProperty Signature }
}

$results | ConvertTo-Json -Depth 8 | Set-Content -Path $OutFile
Write-Host "`nPassed: $(@($results | Where-Object Status -eq 'PASS').Count) of $($results.Count). Results: $OutFile"
