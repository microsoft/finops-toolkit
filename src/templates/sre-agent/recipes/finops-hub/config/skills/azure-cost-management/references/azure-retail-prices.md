---
name: Azure Retail Prices
description: Query the Azure Retail Prices API (prices.azure.com) to look up public pricing for any Azure service by SKU, region, and tier. Public API, no authentication required. Use for price comparisons, rightsizing calculations, and validating Advisor savings estimates.
---

**Key Features:**
- Public API — no authentication required
- OData filter syntax for precise queries
- Coverage across all Azure services and regions
- Reserved vs pay-as-you-go price comparison
- Cross-region price comparison
- Pagination support for large result sets

---

## Base URL

```
https://prices.azure.com/api/retail/prices
```

No API key or Azure authentication needed. Rate-limited but generous for interactive use.

---

## OData filter syntax

### Common filter properties

| Property | Type | Description | Example |
|----------|------|-------------|---------|
| `serviceName` | string | Azure service name | `Virtual Machines`, `Storage` |
| `armSkuName` | string | ARM SKU identifier | `Standard_D4s_v5`, `Standard_LRS` |
| `armRegionName` | string | Azure region | `eastus`, `westeurope` |
| `skuName` | string | Human-readable SKU | `D4s v5`, `D4s v5 Low Priority` |
| `priceType` | string | Pricing model | `Consumption`, `Reservation` |
| `currencyCode` | string | ISO currency code | `USD`, `EUR` |
| `productName` | string | Product family | `Virtual Machines DS Series` |
| `meterName` | string | Meter name | `D4s v5`, `D4s v5 Spot` |
| `type` | string | Rate type | `Consumption`, `DevTestConsumption` |
| `reservationTerm` | string | RI term length | `1 Year`, `3 Years` |
| `tierMinimumUnits` | number | Volume tier minimum | `0` |

### Filter operators

```
eq    - equals
ne    - not equals
gt    - greater than
lt    - less than
ge    - greater than or equal
le    - less than or equal
and   - logical AND
or    - logical OR
contains(field, 'value') - substring match
```

---

## Common query patterns

### VM pricing by SKU and region

```bash
curl -s "https://prices.azure.com/api/retail/prices?\$filter=armSkuName eq 'Standard_D4s_v5' and armRegionName eq 'eastus' and priceType eq 'Consumption'" | jq '.Items[] | {skuName, retailPrice, unitOfMeasure, meterName}'
```

```powershell
$response = Invoke-RestMethod "https://prices.azure.com/api/retail/prices?`$filter=armSkuName eq 'Standard_D4s_v5' and armRegionName eq 'eastus' and priceType eq 'Consumption'"
$response.Items | Select-Object skuName, retailPrice, unitOfMeasure, meterName | Format-Table
```

### Storage pricing by tier and redundancy

```bash
curl -s "https://prices.azure.com/api/retail/prices?\$filter=serviceName eq 'Storage' and armRegionName eq 'eastus' and skuName eq 'Hot LRS' and productName eq 'Azure Data Lake Storage Gen2'" | jq '.Items[] | {meterName, retailPrice, unitOfMeasure}'
```

### Reserved vs pay-as-you-go price comparison

```powershell
# Get PAYG and reserved prices for a VM SKU
$sku = "Standard_D4s_v5"
$region = "eastus"

$payg = Invoke-RestMethod "https://prices.azure.com/api/retail/prices?`$filter=armSkuName eq '$sku' and armRegionName eq '$region' and priceType eq 'Consumption'"
$ri1yr = Invoke-RestMethod "https://prices.azure.com/api/retail/prices?`$filter=armSkuName eq '$sku' and armRegionName eq '$region' and priceType eq 'Reservation' and reservationTerm eq '1 Year'"
$ri3yr = Invoke-RestMethod "https://prices.azure.com/api/retail/prices?`$filter=armSkuName eq '$sku' and armRegionName eq '$region' and priceType eq 'Reservation' and reservationTerm eq '3 Years'"

# Calculate hourly equivalent rates
$paygHourly = ($payg.Items | Where-Object { $_.meterName -eq 'D4s v5' -and $_.type -eq 'Consumption' }).retailPrice
# Reservation retailPrice is already the hourly equivalent rate (unitOfMeasure = "1 Hour")
$ri1yrHourly = ($ri1yr.Items | Where-Object { $_.meterName -eq 'D4s v5' }).retailPrice
$ri3yrHourly = ($ri3yr.Items | Where-Object { $_.meterName -eq 'D4s v5' }).retailPrice

Write-Host "PAYG hourly:     `$$([math]::Round($paygHourly, 4))"
Write-Host "1-yr RI hourly:  `$$([math]::Round($ri1yrHourly, 4)) ($([math]::Round((1 - $ri1yrHourly/$paygHourly) * 100, 1))% savings)"
Write-Host "3-yr RI hourly:  `$$([math]::Round($ri3yrHourly, 4)) ($([math]::Round((1 - $ri3yrHourly/$paygHourly) * 100, 1))% savings)"
```

### Cross-region price comparison

```powershell
$sku = "Standard_D4s_v5"
$regions = @("eastus", "westus2", "westeurope", "southeastasia")

$results = foreach ($region in $regions) {
    $response = Invoke-RestMethod "https://prices.azure.com/api/retail/prices?`$filter=armSkuName eq '$sku' and armRegionName eq '$region' and priceType eq 'Consumption'"
    $price = ($response.Items | Where-Object { $_.meterName -eq 'D4s v5' -and $_.type -eq 'Consumption' }).retailPrice
    [PSCustomObject]@{
        Region = $region
        HourlyPrice = $price
        MonthlyEstimate = [math]::Round($price * 730, 2)
    }
}

$results | Sort-Object HourlyPrice | Format-Table
```

---

## Response structure

```json
{
  "BillingCurrency": "USD",
  "CustomerEntityId": "Default",
  "CustomerEntityType": "Retail",
  "Items": [
    {
      "currencyCode": "USD",
      "tierMinimumUnits": 0.0,
      "retailPrice": 0.192,
      "unitPrice": 0.192,
      "armRegionName": "eastus",
      "location": "US East",
      "effectiveStartDate": "2023-04-01T00:00:00Z",
      "meterId": "...",
      "meterName": "D4s v5",
      "productId": "...",
      "skuId": "...",
      "productName": "Virtual Machines DSv5 Series",
      "skuName": "D4s v5",
      "serviceName": "Virtual Machines",
      "serviceId": "...",
      "serviceFamily": "Compute",
      "unitOfMeasure": "1 Hour",
      "type": "Consumption",
      "isPrimaryMeterRegion": true,
      "armSkuName": "Standard_D4s_v5"
    }
  ],
  "NextPageLink": "https://prices.azure.com/api/retail/prices?$skip=100&...",
  "Count": 1
}
```

### Key fields

| Field | Description |
|-------|-------------|
| `retailPrice` | List price (no discounts applied) |
| `unitPrice` | Same as `retailPrice` for retail customers |
| `unitOfMeasure` | Billing unit: `1 Hour`, `1 GB/Month`, `10,000 Transactions` |
| `armSkuName` | ARM SKU for programmatic cross-reference |
| `isPrimaryMeterRegion` | `true` for the canonical region meter; filter on this to avoid duplicates |
| `type` | `Consumption` (PAYG), `DevTestConsumption` (Dev/Test), `Reservation` |
| `reservationTerm` | Present only for `Reservation` type: `1 Year` or `3 Years` |

---

## Pagination

Results are paginated at 100 items per page. Use `NextPageLink` to iterate:

```powershell
function Get-AllRetailPrices {
    param([string]$Filter)

    $url = "https://prices.azure.com/api/retail/prices?`$filter=$Filter"
    $allItems = @()

    while ($url) {
        $response = Invoke-RestMethod $url
        $allItems += $response.Items
        $url = $response.NextPageLink
    }

    return $allItems
}

# Usage
$prices = Get-AllRetailPrices -Filter "serviceName eq 'Virtual Machines' and armRegionName eq 'eastus' and priceType eq 'Consumption'"
Write-Host "Found $($prices.Count) pricing records"
```

```bash
# Bash pagination with jq
url="https://prices.azure.com/api/retail/prices?\$filter=armSkuName eq 'Standard_D4s_v5' and armRegionName eq 'eastus'"
while [ "$url" != "null" ] && [ -n "$url" ]; do
    response=$(curl -s "$url")
    echo "$response" | jq '.Items[]'
    url=$(echo "$response" | jq -r '.NextPageLink')
done
```

---

## Integration patterns

### Validate Advisor savings estimates

Cross-reference Advisor right-size recommendations with actual retail prices to validate savings claims:

```powershell
# Get Advisor right-size recommendation details
$rec = Get-AzAdvisorRecommendation |
    Where-Object { $_.RecommendationTypeId -eq 'e10b1381-5f0a-47ff-8c7b-37bd13d7c974' } |
    Select-Object -First 1

$currentSku = $rec.ExtendedProperty["currentSku"]
$targetSku = $rec.ExtendedProperty["targetSku"]
$region = $rec.ExtendedProperty["regionId"]

# Look up actual prices
$currentPrice = (Get-AllRetailPrices -Filter "armSkuName eq '$currentSku' and armRegionName eq '$region' and priceType eq 'Consumption'" |
    Where-Object { $_.isPrimaryMeterRegion -and $_.type -eq 'Consumption' }).retailPrice

$targetPrice = (Get-AllRetailPrices -Filter "armSkuName eq '$targetSku' and armRegionName eq '$region' and priceType eq 'Consumption'" |
    Where-Object { $_.isPrimaryMeterRegion -and $_.type -eq 'Consumption' }).retailPrice

$monthlySavings = ($currentPrice - $targetPrice) * 730
Write-Host "Current: $currentSku @ `$$currentPrice/hr"
Write-Host "Target:  $targetSku @ `$$targetPrice/hr"
Write-Host "Monthly savings: `$$([math]::Round($monthlySavings, 2))"
```

### Calculate rightsizing savings

See `references/azure-vm-rightsizing.md` for the full rightsizing workflow that uses this API to validate target SKU pricing.

---

## Limitations

| Limitation | Impact |
|-----------|--------|
| **Retail/list prices only** | No EA/MCA negotiated rates, no discount-adjusted prices |
| **No real-time availability** | Prices may lag behind actual availability by hours |
| **Rate limiting** | No published limits, but excessive requests may be throttled |
| **No savings plan pricing** | Savings plan effective rates are not exposed (use Benefit Recommendations API instead) |
| **Currency conversion** | Prices are listed per currency; exchange rates are Microsoft-determined |

**Important:** Retail prices are useful for relative comparisons (SKU A vs SKU B, region X vs region Y) and for estimating savings percentages. For actual bill amounts, use Cost Management APIs or FinOps hubs cost data.

---

## References

- [Azure Retail Prices API overview](https://learn.microsoft.com/rest/api/cost-management/retail-prices/azure-retail-prices)
- [Retail Prices OData query examples](https://learn.microsoft.com/rest/api/cost-management/retail-prices/azure-retail-prices#api-examples)
- [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/)
- [Rate optimization (FinOps Framework)](https://learn.microsoft.com/cloud-computing/finops/framework/optimize/rates)
