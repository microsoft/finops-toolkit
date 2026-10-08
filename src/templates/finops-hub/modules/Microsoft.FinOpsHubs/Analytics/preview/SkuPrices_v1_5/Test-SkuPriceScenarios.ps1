<#
.SYNOPSIS
Runs each scenario in SkuPrices_v1_5_scenarios.kql against both layouts and compares results.

.DESCRIPTION
Parses "// ## <id> <name>" scenarios with "// ### Rows" and "// ### Columns" queries, runs both on ftk-dev,
and reports duration, result rows, query size, and whether the two results match. Writes results to JSON for reporting.
#>
[CmdletBinding()]
param(
  [string] $Cluster = 'https://ftk-dev.westus.kusto.windows.net',
  [string] $Database = 'Ingestion',
  [string] $Context = 'fh-dev',
  [string] $Path = "$PSScriptRoot/SkuPrices_v1_5_scenarios.kql",
  [string] $OutFile = (Join-Path ([IO.Path]::GetTempPath()) "SkuPrices_v1_5_scenarios.results.json")
)

$ErrorActionPreference = 'Stop'
Set-AzContext -Context (Get-AzContext -Name $Context) -Scope Process | Out-Null
$secure = (Get-AzAccessToken -ResourceUrl $Cluster -AsSecureString).Token
$headers = @{ Authorization = "Bearer $([System.Net.NetworkCredential]::new('', $secure).Password)"; 'Content-Type' = 'application/json' }

function Invoke-Kusto([string] $Csl) {
  $body = @{ db = $Database; csl = $Csl; properties = @{ Options = @{ servertimeout = '00:20:00'; query_results_cache_max_age = '00:00:00' } } } | ConvertTo-Json -Depth 5
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $t = (Invoke-RestMethod -Uri "$Cluster/v1/rest/query" -Method Post -Headers $headers -Body $body -TimeoutSec 1200).Tables[0]
  [pscustomobject]@{ Ms = $sw.ElapsedMilliseconds; Columns = @($t.Columns | ForEach-Object ColumnName); Rows = @($t.Rows) }
}

# Normalize a result so equivalent outputs compare equal (sorted rows, rounded numbers)
function Get-Signature($Result) {
  $lines = $Result.Rows | ForEach-Object { ($_ | ForEach-Object { if ($_ -is [double] -or $_ -is [decimal]) { [math]::Round([double]$_, 6) } else { "$_" } }) -join '|' } | Sort-Object
  ($lines -join "`n")
}

# Parse scenarios
$text = Get-Content -Path $Path -Raw
$scenarios = foreach ($block in ($text -split '(?m)^// ## ') | Select-Object -Skip 1) {
  $lines = $block -split "`n"
  $id, $name = $lines[0].Trim() -split ' ', 2
  $meta = @{}
  foreach ($l in $lines) { if ($l -match '^// (Question|Source|Expect): (.+)$') { $meta[$Matches[1]] = $Matches[2].Trim() } }
  $rowsQuery = ($block -split '(?m)^// ### Rows\s*$')[1] -split '(?m)^// ### Columns\s*$' | Select-Object -First 1
  $colsQuery = ($block -split '(?m)^// ### Columns\s*$')[1]
  [pscustomobject]@{ Id = $id; Name = $name.Trim(); Question = $meta.Question; Source = $meta.Source; Expect = $meta.Expect; RowsQuery = $rowsQuery.Trim(); ColumnsQuery = $colsQuery.Trim() }
}

$results = foreach ($s in $scenarios) {
  $r = @{}
  foreach ($side in 'Rows', 'Columns') {
    $q = $s."${side}Query"
    try {
      $res = Invoke-Kusto $q
      $r[$side] = [pscustomobject]@{
        Ms = $res.Ms; ResultRows = $res.Rows.Count; Columns = $res.Columns
        Data = @($res.Rows | Select-Object -First 15 | ForEach-Object { , @($_) })
        Signature = Get-Signature $res; Error = $null
        Lines = @($q -split "`n" | Where-Object { $_.Trim() }).Count
        Operators = ([regex]::Matches($q, '(?m)^\s*\|')).Count
        Joins = ([regex]::Matches($q, '\b(join|lookup)\b')).Count
      }
    }
    catch { $r[$side] = [pscustomobject]@{ Error = ($_.ErrorDetails.Message ?? $_.Exception.Message) } }
  }
  $match = -not $r.Rows.Error -and -not $r.Columns.Error -and $r.Rows.Signature -eq $r.Columns.Signature
  $expectSame = $s.Expect -like 'same*'
  $status = if ($r.Rows.Error -or $r.Columns.Error) { 'ERROR' } elseif ($match -eq $expectSame) { 'PASS' } else { 'FAIL' }
  Write-Host ("{0,-5} {1} {2,-40} rows {3,6}ms/{4,3}L/{5}J  cols {6,6}ms/{7,3}L/{8}J  match={9}" -f $status, $s.Id, $s.Name, $r.Rows.Ms, $r.Rows.Lines, $r.Rows.Joins, $r.Columns.Ms, $r.Columns.Lines, $r.Columns.Joins, $match)
  if ($status -eq 'ERROR') { Write-Host "      Rows: $($r.Rows.Error)`n      Columns: $($r.Columns.Error)" }
  [pscustomobject]@{ Id = $s.Id; Name = $s.Name; Question = $s.Question; Source = $s.Source; Expect = $s.Expect; Status = $status; Match = $match
    RowsQuery = $s.RowsQuery; ColumnsQuery = $s.ColumnsQuery
    Rows = $r.Rows | Select-Object * -ExcludeProperty Signature; Columns = $r.Columns | Select-Object * -ExcludeProperty Signature }
}

$results | ConvertTo-Json -Depth 8 | Set-Content -Path $OutFile
Write-Host "`nPassed: $(@($results | Where-Object Status -eq 'PASS').Count) of $($results.Count). Results: $OutFile"
