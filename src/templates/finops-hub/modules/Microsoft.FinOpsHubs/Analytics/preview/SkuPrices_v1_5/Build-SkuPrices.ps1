<#
.SYNOPSIS
Rebuilds SkuPrices_v1_5 on ftk-dev from Prices_final_v1_2 using SkuPrices_v1_5.kql.

.DESCRIPTION
Creates or updates SkuPrices_v1_5_build from the KQL file, then builds the table one price type at a time
(List replaces the table and its schema; Base, Contracted, and Effective append) to stay within memory.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string] $Cluster = 'https://ftk-dev.westus.kusto.windows.net',
  [string] $Database = 'Ingestion',
  [string] $Context = 'fh-dev',
  [string] $KqlPath = "$PSScriptRoot/SkuPrices_v1_5.kql"
)

$ErrorActionPreference = 'Stop'

$ctx = Get-AzContext -Name $Context
if (-not $ctx) { throw "Az context '$Context' not found" }
Set-AzContext -Context $ctx -Scope Process -WhatIf:$false | Out-Null  # This process only; leaves the saved default alone
$secure = (Get-AzAccessToken -ResourceUrl $Cluster -AsSecureString).Token
$headers = @{ Authorization = "Bearer $([System.Net.NetworkCredential]::new('', $secure).Password)"; 'Content-Type' = 'application/json' }

function Invoke-Kusto {
  param([string] $Csl, [string] $Endpoint = 'mgmt')
  $body = @{ db = $Database; csl = $Csl; properties = @{ Options = @{ servertimeout = '01:00:00' } } } | ConvertTo-Json -Depth 5
  (Invoke-RestMethod -Uri "$Cluster/v1/rest/$Endpoint" -Method Post -Headers $headers -Body $body -TimeoutSec 3600).Tables[0]
}

# 1. Functions from the KQL file (every .create-or-alter function block, in order)
$raw = Get-Content -Path $KqlPath -Raw
$pos = 0
while (($start = $raw.IndexOf('.create-or-alter function', $pos)) -ge 0) {
  $depth = 0; $end = -1
  for ($i = $raw.IndexOf('{', $start); $i -lt $raw.Length; $i++) {
    if ($raw[$i] -eq '{') { $depth++ }
    elseif ($raw[$i] -eq '}') { $depth--; if ($depth -eq 0) { $end = $i + 1; break } }
  }
  if ($end -lt 0) { throw "Unbalanced function body in $KqlPath" }
  $fn = $raw.Substring($start, $end - $start)
  $name = [regex]::Match($fn, '\)\s*(\w+)\s*\(').Groups[1].Value
  if ($PSCmdlet.ShouldProcess($name, '.create-or-alter function')) { Invoke-Kusto $fn | Out-Null; Write-Host "Updated $name" }
  $pos = $end
}

# 2. Effective starts table, one price type at a time
foreach ($type in 'List', 'Base', 'Contracted', 'Effective') {
  $csl = if ($type -eq 'List') { ".set-or-replace SkuPrices_v1_5_starts_table with (folder = 'FOCUS 1.5 preview', recreate_schema = true) <| SkuPrices_v1_5_starts('$type')" }
         else { ".append SkuPrices_v1_5_starts_table <| SkuPrices_v1_5_starts('$type')" }
  if ($PSCmdlet.ShouldProcess('SkuPrices_v1_5_starts_table', $csl)) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Kusto $csl | Out-Null
    Write-Host "Starts $type done in $([int]$sw.Elapsed.TotalSeconds)s"
  }
}

# 3. Build the table one price type at a time
$steps = [ordered]@{
  List       = ".set-or-replace SkuPrices_v1_5 with (folder = 'FOCUS 1.5 preview', recreate_schema = true) <| SkuPrices_v1_5_build('List')"
  Base       = ".append SkuPrices_v1_5 <| SkuPrices_v1_5_build('Base')"
  Contracted = ".append SkuPrices_v1_5 <| SkuPrices_v1_5_build('Contracted')"
  Effective  = ".append SkuPrices_v1_5 <| SkuPrices_v1_5_build('Effective')"
}
foreach ($type in $steps.Keys) {
  if ($PSCmdlet.ShouldProcess('SkuPrices_v1_5', $steps[$type])) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Kusto $steps[$type] | Out-Null
    Write-Host "$type done in $([int]$sw.Elapsed.TotalSeconds)s"
  }
}

# 4. Comparison table (one row per price, price types as columns)
$csl = ".set-or-replace SkuPricesWide_v1_5 with (folder = 'FOCUS 1.5 preview', recreate_schema = true) <| SkuPricesWide_v1_5_build()"
if ($PSCmdlet.ShouldProcess('SkuPricesWide_v1_5', $csl)) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  Invoke-Kusto $csl | Out-Null
  Write-Host "Wide done in $([int]$sw.Elapsed.TotalSeconds)s"
}

# 5. SkuPriceIdv2 map, then a Costs copy with SkuPriceIdv2, one month at a time
$csl = ".set-or-replace SkuPriceIdv2_map with (folder = 'FOCUS 1.5 preview', recreate_schema = true) <| SkuPriceIdv2_map_build()"
if ($PSCmdlet.ShouldProcess('SkuPriceIdv2_map', $csl)) { Invoke-Kusto $csl | Out-Null; Write-Host 'Map done' }
$months = (Invoke-Kusto 'Costs_final_v1_2 | summarize by M = startofmonth(ChargePeriodStart) | order by M asc' 'query').Rows | ForEach-Object { ([datetime]$_[0]).ToString('yyyy-MM-dd') }
$first = $true
foreach ($m in $months) {
  $csl = if ($first) { ".set-or-replace CostsWithSkuPriceIdv2 with (folder = 'FOCUS 1.5 preview', recreate_schema = true) <| CostsWithSkuPriceIdv2_build(datetime($m))" }
         else { ".append CostsWithSkuPriceIdv2 <| CostsWithSkuPriceIdv2_build(datetime($m))" }
  if ($PSCmdlet.ShouldProcess('CostsWithSkuPriceIdv2', $csl)) { Invoke-Kusto $csl | Out-Null; Write-Host "Costs $m done" }
  $first = $false
}

# 6. Verify
$counts = Invoke-Kusto 'SkuPrices_v1_5 | summarize Rows = count() by x_UnitPriceType' 'query'
$counts.Rows | ForEach-Object { Write-Host "$($_[0]): $($_[1])" }
$columns = (Invoke-Kusto 'SkuPrices_v1_5 | getschema | project ColumnName' 'query').Rows | ForEach-Object { $_[0] }
$sorted = [string[]] $columns.Clone(); [Array]::Sort($sorted, [StringComparer]::Ordinal)
Write-Host "Columns: $($columns.Count); alphabetical: $(-not (Compare-Object $columns $sorted -SyncWindow 0))"
