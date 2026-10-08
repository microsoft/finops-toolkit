<#
.SYNOPSIS
Renders the SKU Price layout comparison report (HTML) from scenario results and live table sizes.
#>
[CmdletBinding()]
param(
  [string] $Cluster = 'https://ftk-dev.westus.kusto.windows.net',
  [string] $Database = 'Ingestion',
  [string] $Context = 'fh-dev',
  [string] $Template = "$PSScriptRoot/SkuPrices_v1_5_report.template.html",
  [string] $Results = (Join-Path ([IO.Path]::GetTempPath()) 'SkuPrices_v1_5_scenarios.results.json'),
  [string] $OutFile = (Join-Path ([IO.Path]::GetTempPath()) "sku-price-layouts.html")
)

$ErrorActionPreference = 'Stop'
Set-AzContext -Context (Get-AzContext -Name $Context) -Scope Process | Out-Null
$secure = (Get-AzAccessToken -ResourceUrl $Cluster -AsSecureString).Token
$headers = @{ Authorization = "Bearer $([System.Net.NetworkCredential]::new('', $secure).Password)"; 'Content-Type' = 'application/json' }
function Invoke-Kusto([string] $Csl, [string] $Endpoint = 'query') {
  $body = @{ db = $Database; csl = $Csl } | ConvertTo-Json
  , @((Invoke-RestMethod -Uri "$Cluster/v1/rest/$Endpoint" -Method Post -Headers $headers -Body $body -TimeoutSec 600).Tables[0].Rows)
}

function Get-Size([string] $Table, [string] $Filter = '') {
  $r = Invoke-Kusto ".show table $Table extents $Filter | summarize Rows = sum(RowCount), Extent = sum(ExtentSize), Compressed = sum(CompressedSize)" 'mgmt'
  $cols = (Invoke-Kusto "$Table | getschema | count")[0][0]
  [pscustomobject]@{ Rows = [double]$r[0][0]; Extent = [double]$r[0][1]; Compressed = [double]$r[0][2]; Columns = $cols }
}
function M($v) { '{0:0.00}M' -f ($v / 1e6) }
function G($v) { '{0:0.00}' -f ($v / 1GB) }
function X($a, $b) { '{0:0.0}×' -f ($a / $b) }

$p = Get-Size 'Prices_final_v1_2'
$r = Get-Size 'SkuPrices_v1_5'
$c = Get-Size 'SkuPricesWide_v1_5'
$rCur = (Invoke-Kusto 'SkuPrices_v1_5 | where isnull(SkuPriceEffectiveEnd) | count')[0][0]
$cCur = (Invoke-Kusto 'SkuPricesWide_v1_5 | where isnull(SkuPriceEffectiveEnd) | count')[0][0]

function Card($cls, $label, $table, $s, $ratio, [string[]] $bullets) {
  @"
<div class="tcard $cls"><div class="tname">$label <code>$table</code></div>
<div class="stats"><div class="stat"><b>$(M $s.Rows)</b><span>Rows</span></div><div class="stat"><b>$(G $s.Extent)</b><span>GB extent</span></div><div class="stat"><b>$(G $s.Compressed)</b><span>GB compressed</span></div></div>
<div class="ratio">$ratio</div><ul>$(($bullets | ForEach-Object { "<li>$_</li>" }) -join '')</ul></div>
"@
}
$tables = (Card 'mon' 'Today' 'Prices_final_v1_2' $p "$($p.Columns) columns. 14 monthly price sheets." @(
    'One row per price per month', 'All price types as columns', 'Month-level dates; joins match on month')) +
  (Card 'rows' 'Rows' 'SkuPrices_v1_5' $r "$($r.Columns) columns. $(X $r.Rows $p.Rows) rows, $(X $r.Extent $p.Extent) extent of today. $(M $rCur) current." @(
    'One row per price type (<code>x_UnitPriceType</code>) per run of unchanged months', 'List rows are public: no contract, global eligibility', 'Effective start and end per price type')) +
  (Card 'cols' 'Columns' 'SkuPricesWide_v1_5' $c "$($c.Columns) columns. $(X $c.Rows $p.Rows) rows, $(X $c.Extent $p.Extent) extent of today. $(M $cCur) current." @(
    'One row per price per contract per run; a new row when any price changes', 'List price repeats per contract and is scoped to it', 'One effective start and end for all prices on the row'))

$json = ((Get-Content $Results -Raw | ConvertFrom-Json) | ConvertTo-Json -Depth 8 -Compress).Replace('</', '<\/')
(Get-Content $Template -Raw).Replace('__TABLES__', $tables).Replace('__DATA__', $json).Replace('__GENERATED__', (Get-Date -Format 'yyyy-MM-dd')) | Set-Content $OutFile -NoNewline
Write-Host "Today: $(M $p.Rows) rows $(G $p.Extent) GB | Rows: $(M $r.Rows) ($(M $rCur) current) $(G $r.Extent) GB | Columns: $(M $c.Rows) ($(M $cCur) current) $(G $c.Extent) GB"
Write-Host "Wrote $OutFile"
