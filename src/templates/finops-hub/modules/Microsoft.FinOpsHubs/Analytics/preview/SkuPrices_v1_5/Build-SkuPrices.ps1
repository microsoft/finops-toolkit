<#
.SYNOPSIS
Rebuilds the FOCUS 1.5 SkuPrices preview tables on a hub from Prices_final_v1_2 and Costs_final_v1_2 using SkuPrices_v1_5.kql.

.DESCRIPTION
1. Creates or updates every function in the KQL file.
2. Builds SkuPrices_v1_5_runs_table (runs of unchanged prices) for each price type and the wide layout.
3. Builds SkuPrices_v1_5 (rows layout) one month and price type at a time, and SkuPricesWide_v1_5 (columns layout) one month at a time.
4. Builds SkuPriceIdv2_map and CostsWithSkuPriceIdv2 (Costs copy with SkuPriceIdv2) one month at a time.
Small steps keep each query within memory on small clusters.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string] $Cluster = 'https://ftk-dev.westus.kusto.windows.net',
  [string] $Database = 'Ingestion',
  [string] $Context = 'fh-dev',
  [string] $KqlPath = "$PSScriptRoot/SkuPrices_v1_5.kql",
  [switch] $SkipCosts
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

# Run one command, timing it; the first command for a table replaces it, the rest append
function Invoke-Step([string] $Table, [string] $Query, [ref] $First, [string] $Label) {
  $csl = if ($First.Value) { ".set-or-replace $Table with (folder = 'FOCUS 1.5 preview', recreate_schema = true) <| $Query" } else { ".append $Table <| $Query" }
  if ($PSCmdlet.ShouldProcess($Table, $csl)) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Kusto $csl | Out-Null
    Write-Host "$Label done in $([int]$sw.Elapsed.TotalSeconds)s"
  }
  $First.Value = $false
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

$types = 'List', 'Base', 'Contracted', 'Effective'

# 2. Runs of unchanged prices, per price type and for the wide layout
$first = $true
$parts = 8  # Hash partitions of keys, to stay within memory
foreach ($type in $types + 'Wide') { for ($p = 0; $p -lt $parts; $p++) { Invoke-Step 'SkuPrices_v1_5_runs_table' "SkuPrices_v1_5_runs_build('$type', $p, $parts)" ([ref]$first) "Runs $type $p" } }

# 3. Rows and columns layouts, one month (and price type) at a time
$months = (Invoke-Kusto 'Prices_final_v1_2 | summarize by M = startofmonth(x_IngestionTime) | order by M asc' 'query').Rows | ForEach-Object { ([datetime]$_[0]).ToString('yyyy-MM-dd') }
$firstRows = $true; $firstWide = $true
foreach ($m in $months) {
  foreach ($type in $types) { Invoke-Step 'SkuPrices_v1_5' "SkuPrices_v1_5_build('$type', datetime($m))" ([ref]$firstRows) "Rows $m $type" }
  Invoke-Step 'SkuPricesWide_v1_5' "SkuPricesWide_v1_5_build(datetime($m))" ([ref]$firstWide) "Wide $m"
}

# 4. SkuPriceIdv2 map, then a Costs copy with SkuPriceIdv2, one month at a time
if (-not $SkipCosts) {
  $first = $true
  Invoke-Step 'SkuPriceIdv2_map' 'SkuPriceIdv2_map_build()' ([ref]$first) 'Map'
  $costMonths = (Invoke-Kusto 'Costs_final_v1_2 | summarize by M = startofmonth(ChargePeriodStart) | order by M asc' 'query').Rows | ForEach-Object { ([datetime]$_[0]).ToString('yyyy-MM-dd') }
  $first = $true
  foreach ($m in $costMonths) { Invoke-Step 'CostsWithSkuPriceIdv2' "CostsWithSkuPriceIdv2_build(datetime($m))" ([ref]$first) "Costs $m" }
}

# 5. Verify
foreach ($t in 'SkuPrices_v1_5', 'SkuPricesWide_v1_5') {
  $c = (Invoke-Kusto "$t | summarize Rows = count(), Current = countif(isnull(SkuPriceEffectiveEnd))" 'query').Rows[0]
  $columns = (Invoke-Kusto "$t | getschema | project ColumnName" 'query').Rows | ForEach-Object { $_[0] }
  $sorted = [string[]] $columns.Clone(); [Array]::Sort($sorted, [StringComparer]::Ordinal)
  Write-Host "${t}: $($c[0]) rows ($($c[1]) current); $($columns.Count) columns; alphabetical: $(-not (Compare-Object $columns $sorted -SyncWindow 0))"
}
