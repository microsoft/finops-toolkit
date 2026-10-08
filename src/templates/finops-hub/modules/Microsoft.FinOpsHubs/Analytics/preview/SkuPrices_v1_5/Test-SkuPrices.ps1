<#
.SYNOPSIS
Validates SkuPrices_v1_5 on ftk-dev against the source price sheet and the PR 2424 SKU Price requirements.
#>
[CmdletBinding()]
param(
  [string] $Cluster = 'https://ftk-dev.westus.kusto.windows.net',
  [string] $Database = 'Ingestion',
  [string] $Context = 'fh-dev'
)

$ErrorActionPreference = 'Stop'
Set-AzContext -Context (Get-AzContext -Name $Context) -Scope Process | Out-Null
$secure = (Get-AzAccessToken -ResourceUrl $Cluster -AsSecureString).Token
$headers = @{ Authorization = "Bearer $([System.Net.NetworkCredential]::new('', $secure).Password)"; 'Content-Type' = 'application/json' }

function Invoke-Kusto([string] $Csl) {
  $body = @{ db = $Database; csl = $Csl; properties = @{ Options = @{ servertimeout = '00:30:00' } } } | ConvertTo-Json -Depth 5
  $t = (Invoke-RestMethod -Uri "$Cluster/v1/rest/query" -Method Post -Headers $headers -Body $body -TimeoutSec 1800).Tables[0]
  $names = $t.Columns | ForEach-Object ColumnName
  $t.Rows | ForEach-Object { $r = $_; $o = [ordered]@{}; for ($i = 0; $i -lt $names.Count; $i++) { $o[$names[$i]] = $r[$i] }; [pscustomobject]$o }
}

# Latest price sheet per billing account, same as the build
$sheet = @'
let latestSheet = Prices_final_v1_2 | summarize tmp_LatestDay = max(startofday(x_IngestionTime)) by BillingAccountId;
let sheet = Prices_final_v1_2 | lookup kind=inner latestSheet on BillingAccountId | where startofday(x_IngestionTime) == tmp_LatestDay;
'@

# Each check returns one row; Pass = expected
$checks = [ordered]@{
  'Dupes: extended key (+x_UnitPriceType)' = @{ Expect = 0; Csl = 'SkuPrices_v1_5 | summarize n = count() by ServiceProviderName, SkuPriceId, ContractId, SkuPriceEffectiveStart, PricingCurrency, x_UnitPriceType | where n > 1 | count' }
  'Dupes: FOCUS 1.5 key (info: price type collisions)' = @{ Expect = $null; Csl = 'SkuPrices_v1_5 | summarize n = count() by ServiceProviderName, SkuPriceId, ContractId, SkuPriceEffectiveStart, PricingCurrency | where n > 1 | count' }
  'Overlapping effective periods (extended key)' = @{ Expect = 0; Csl = @'
SkuPrices_v1_5
| project k = strcat(ServiceProviderName, '|', SkuPriceId, '|', ContractId, '|', PricingCurrency, '|', x_UnitPriceType), SkuPriceEffectiveStart, SkuPriceEffectiveEnd
| sort by k asc, SkuPriceEffectiveStart asc
| where next(k) == k and (isnull(SkuPriceEffectiveEnd) or next(SkuPriceEffectiveStart) < SkuPriceEffectiveEnd)
| count
'@ }
  'Source: same key, different prices (hidden by take_any)' = @{ Expect = 0; Csl = $sheet + @'
sheet
| summarize List = dcount(ListUnitPrice), Base = dcount(x_BaseUnitPrice), Contracted = dcount(ContractedUnitPrice), Effective = dcount(x_EffectiveUnitPrice), n = count()
    by BillingAccountId, SkuPriceIdv2, x_EffectivePeriodStart, PricingCurrency
| where List > 1 or Base > 1 or Contracted > 1 or Effective > 1
| count
'@ }
  'Source: duplicate rows on key (info)' = @{ Expect = $null; Csl = $sheet + 'sheet | summarize n = count() by BillingAccountId, SkuPriceIdv2, x_EffectivePeriodStart, PricingCurrency | where n > 1 | summarize Keys = count(), ExtraRows = sum(n - 1)' }
  'Row count: List vs source' = @{ Expect = 0; Csl = $sheet + "let s = toscalar(sheet | where isnotnull(ListUnitPrice) and x_SkuPriceType != 'SavingsPlan' | summarize by SkuPriceIdv2, x_EffectivePeriodStart, PricingCurrency | count); SkuPrices_v1_5 | where x_UnitPriceType == 'List' | summarize Diff = count() - s, Rows = count(), Source = s" }
  'Row count: Base vs source' = @{ Expect = 0; Csl = $sheet + "let s = toscalar(sheet | where isnotnull(x_BaseUnitPrice) and x_SkuPriceType != 'SavingsPlan' | summarize by BillingAccountId, SkuPriceIdv2, x_EffectivePeriodStart, PricingCurrency | count); SkuPrices_v1_5 | where x_UnitPriceType == 'Base' | summarize Diff = count() - s, Rows = count(), Source = s" }
  'Row count: Contracted vs source' = @{ Expect = 0; Csl = $sheet + "let s = toscalar(sheet | where isnotnull(ContractedUnitPrice) and x_SkuPriceType != 'SavingsPlan' | summarize by BillingAccountId, SkuPriceIdv2, x_EffectivePeriodStart, PricingCurrency | count); SkuPrices_v1_5 | where x_UnitPriceType == 'Contracted' | summarize Diff = count() - s, Rows = count(), Source = s" }
  'Row count: Effective vs source' = @{ Expect = 0; Csl = $sheet + "let s = toscalar(sheet | where isnotnull(x_EffectiveUnitPrice) | summarize by BillingAccountId, SkuPriceIdv2, x_EffectivePeriodStart, PricingCurrency | count); SkuPrices_v1_5 | where x_UnitPriceType == 'Effective' | summarize Diff = count() - s, Rows = count(), Source = s" }
  'UnitPrice + discount match the source sheet' = @{ Expect = 0; Csl = $sheet + @'
let s = sheet | summarize take_any(ListUnitPrice, x_BaseUnitPrice, ContractedUnitPrice, x_EffectiveUnitPrice) by SkuPriceIdv2, PricingCurrency;
SkuPrices_v1_5
| lookup kind=leftouter s on $left.x_SkuPriceIdv2 == $right.SkuPriceIdv2, PricingCurrency
| extend Src = case(x_UnitPriceType == 'List', ListUnitPrice, x_UnitPriceType == 'Base', x_BaseUnitPrice, x_UnitPriceType == 'Contracted', ContractedUnitPrice, x_EffectiveUnitPrice)
| where isnull(Src) or UnitPrice != Src or (x_UnitPriceType != 'List' and abs(x_UnitPriceDiscount - (ListUnitPrice - UnitPrice)) > 1e-9)
| count
'@ }
  'Mandatory columns null/empty' = @{ Expect = 0; Csl = @'
SkuPrices_v1_5
| where isempty(ChargeCategory) or isempty(PricingCurrency) or isempty(PricingCurrencyCategory) or isempty(PricingServiceName) or isempty(PricingUnit)
     or isempty(ServiceProviderName) or isempty(SkuId) or isempty(SkuPriceDescription) or isempty(SkuPriceId) or isnull(SkuPriceCreated)
     or isnull(SkuPriceLastUpdated) or isnull(UnitPrice) or isnull(SkuPriceEligibility) or isnull(QuantityTierMinimum)
| count
'@ }
  'Mandatory column gaps by column (info)' = @{ Expect = $null; Csl = @'
SkuPrices_v1_5
| summarize ChargeCategory = countif(isempty(ChargeCategory)), PricingServiceName = countif(isempty(PricingServiceName)), PricingUnit = countif(isempty(PricingUnit)),
    SkuId = countif(isempty(SkuId)), SkuPriceDescription = countif(isempty(SkuPriceDescription)), PricingRegionId = countif(isempty(PricingRegionId)), SkuPriceEffectiveEnd = countif(isnull(SkuPriceEffectiveEnd)), SkuPriceEffectiveStart = countif(isnull(SkuPriceEffectiveStart))
'@ }
  'ContractId empty iff List' = @{ Expect = 0; Csl = "SkuPrices_v1_5 | where (x_UnitPriceType == 'List') != isempty(ContractId) | count" }
  'Negative UnitPrice' = @{ Expect = 0; Csl = 'SkuPrices_v1_5 | where UnitPrice < 0 | count' }
  'ChargeCategory not Usage/Purchase/Credit' = @{ Expect = 0; Csl = "SkuPrices_v1_5 | where ChargeCategory !in ('Usage', 'Purchase', 'Credit') | count" }
  'PurchaseDurationType set on non-Purchase' = @{ Expect = 0; Csl = "SkuPrices_v1_5 | where ChargeCategory != 'Purchase' and isnotempty(PurchaseDurationType) | count" }
  'EffectiveEnd <= EffectiveStart' = @{ Expect = 0; Csl = 'SkuPrices_v1_5 | where isnotnull(SkuPriceEffectiveEnd) and isnotnull(SkuPriceEffectiveStart) and SkuPriceEffectiveEnd <= SkuPriceEffectiveStart | count' }
  'Tier max <= tier min' = @{ Expect = 0; Csl = 'SkuPrices_v1_5 | where isnotnull(QuantityTierMaximum) and QuantityTierMaximum <= QuantityTierMinimum | count' }
  'SkuPriceId with >1 SkuId/PricingUnit/ChargeCategory' = @{ Expect = 0; Csl = 'SkuPrices_v1_5 | summarize s = dcount(SkuId), u = dcount(PricingUnit), c = dcount(ChargeCategory) by SkuPriceId | where s > 1 or u > 1 or c > 1 | count' }
  'Effective start distribution (info)' = @{ Expect = $null; Csl = "SkuPrices_v1_5 | summarize Rows = count() by Start = startofmonth(SkuPriceEffectiveStart), x_UnitPriceType | summarize Rows = sum(Rows), Types = make_set(x_UnitPriceType) by Start | order by Start asc" }
  'Price changed after its effective start (sample of 2000 Contracted)' = @{ Expect = 0; Csl = @'
let s = SkuPrices_v1_5 | where x_UnitPriceType == 'Contracted' | sample 2000 | project SkuPriceIdv2 = x_SkuPriceIdv2, PricingCurrency, Start = SkuPriceEffectiveStart, Cur = UnitPrice;
Prices_final_v1_2
| where x_SkuPriceType != 'SavingsPlan'
| lookup kind=inner s on SkuPriceIdv2, PricingCurrency
| summarize Changed = countif(x_EffectivePeriodStart >= Start and ContractedUnitPrice != Cur), PriorSame = countif(startofmonth(x_EffectivePeriodStart) == datetime_add('month', -1, Start) and ContractedUnitPrice == Cur) by SkuPriceIdv2, PricingCurrency
| where Changed > 0 or PriorSame > 0
| count
'@ }
  'Savings plan rows not Effective' = @{ Expect = 0; Csl = "SkuPrices_v1_5 | where x_SkuPriceType == 'SavingsPlan' and x_UnitPriceType != 'Effective' | count" }
  'SkuPriceId with >1 tier minimum' = @{ Expect = 0; Csl = 'SkuPrices_v1_5 | summarize t = dcount(QuantityTierMinimum) by SkuPriceId | where t > 1 | count' }
  'Price types by CommitmentDiscountCategory (info)' = @{ Expect = $null; Csl = "SkuPrices_v1_5 | summarize Rows = count() by x_UnitPriceType, CommitmentDiscountCategory, ChargeCategory | order by x_UnitPriceType asc, Rows desc" }
  'Base/Contracted equal to List (info)' = @{ Expect = $null; Csl = @'
SkuPrices_v1_5
| where x_UnitPriceType in ('Base', 'Contracted')
| lookup kind=leftouter (SkuPrices_v1_5 | where x_UnitPriceType == 'List' | project SkuPriceId, SkuPriceEffectiveStart, PricingCurrency, ListPrice = UnitPrice) on SkuPriceId, SkuPriceEffectiveStart, PricingCurrency
| summarize Rows = count(), SameAsList = countif(UnitPrice == ListPrice), NoList = countif(isnull(ListPrice)) by x_UnitPriceType
'@ }
}

$failed = 0
foreach ($name in $checks.Keys) {
  $c = $checks[$name]
  try { $rows = @(Invoke-Kusto $c.Csl) } catch { Write-Host "ERROR  $name -> $($_.ErrorDetails.Message ?? $_.Exception.Message)"; $failed++; continue }
  if ($null -eq $c.Expect) {
    Write-Host "INFO   $name"; $rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
  }
  else {
    $first = $rows[0].PSObject.Properties.Value | Select-Object -First 1
    $ok = [long]$first -eq $c.Expect
    if (-not $ok) { $failed++ }
    Write-Host ("{0}   {1} -> {2}" -f ($(if ($ok) { 'PASS' } else { 'FAIL' })), $name, (($rows[0].PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', '))
  }
}
Write-Host "`nFailed: $failed"
