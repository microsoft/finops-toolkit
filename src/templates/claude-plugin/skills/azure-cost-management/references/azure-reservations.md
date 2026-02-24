---
name: Azure Reservations
description: Query the Azure Cost Management Benefit Recommendations API to retrieve reserved instance purchase recommendations. Analyze potential savings, utilization, coverage, and optimal commitment amounts for specific Azure resource types.
---

**Key Features:**
- Up to 72% savings vs pay-as-you-go pricing for stable workloads
- Resource-type specific (VMs, SQL DB, Cosmos DB, App Service, Synapse, Storage, etc.)
- Instance size flexibility within VM series
- Self-service returns (up to $50K/year) and exchanges within product family
- 1-year and 3-year terms
- Applied before savings plans in the benefit stack

---

## Benefit Recommendations API

The same Benefit Recommendations API endpoint used for savings plans also returns reservation recommendations. The key difference is the `kind` filter parameter.

### Request

```http
GET https://management.azure.com/{billingScope}/providers/Microsoft.CostManagement/benefitRecommendations?$filter=properties/lookBackPeriod eq '{lookBackPeriod}' AND properties/term eq '{term}'&$expand=properties/usage,properties/allRecommendationDetails&api-version=2024-08-01
Authorization: Bearer {token}
```

When no `kind` filter is specified, the API returns both savings plan and reservation recommendations. The `kind` property is at the top level of each result (not under `properties`), so filter client-side:

```powershell
# Filter API results for reservations only
$reservations = $jsonResult.value | Where-Object { $_.kind -eq 'Reservation' }
```

**Note:** The documented `$filter` query parameters support `properties/lookBackPeriod`, `properties/term`, `properties/scope`, `properties/subscriptionId`, and `properties/resourceGroup`. Filtering by `kind` is not a documented server-side filter — do it client-side after retrieving results.

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `billingScope` | Yes | - | Billing account, subscription, or resource group scope |
| `lookBackPeriod` | No | Last7Days | Analysis period: Last7Days, Last30Days, Last60Days |
| `term` | No | P3Y | Reservation term: P1Y (1-year) or P3Y (3-year) |
| `kind` | No | - | Top-level property on results: `Reservation` or `SavingsPlan`. Filter client-side (not a supported `$filter` param). |

### Scope formats

| Scope Type | Format |
|------------|--------|
| Billing Account | `providers/Microsoft.Billing/billingAccounts/{billingAccountId}` |
| Billing Profile | `providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}` |
| Subscription | `subscriptions/{subscriptionId}` |
| Resource Group | `subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}` |

---

## PowerShell examples

The `Get-BenefitRecommendations.ps1` script (see `azure-savings-plans.md` for full source) works for both savings plans and reservations. Filter the results for reservation recommendations:

### Get reservation recommendations only

```powershell
# Get all benefit recommendations and parse JSON
$scope = "subscriptions/12345678-1234-1234-1234-123456789012"
$url = "https://management.azure.com/$scope/providers/Microsoft.CostManagement/benefitRecommendations?`$filter=properties/lookBackPeriod eq 'Last30Days' AND properties/term eq 'P3Y'&`$expand=properties/usage,properties/allRecommendationDetails&api-version=2024-08-01"
$uri = [uri]::new($url)
$result = Invoke-AzRestMethod -Uri $uri.AbsoluteUri -Method GET
$jsonResult = $result.Content | ConvertFrom-Json

# Filter for reservation recommendations only (kind is top-level, not under properties)
$reservations = $jsonResult.value | Where-Object { $_.kind -eq 'Reservation' }

# Display summary
$reservations | ForEach-Object {
    $rec = $_.properties
    Write-Host "ARM SKU: $($rec.armSkuName)"
    Write-Host "  Commitment: $($rec.recommendationDetails.commitmentAmount)/hr"
    Write-Host "  Savings: $($rec.recommendationDetails.savingsPercentage)%"
    Write-Host "  Term: $($rec.term)"
    Write-Host ""
}
```

### Compare reservation vs savings plan recommendations

```powershell
$scope = "subscriptions/$subscriptionId"
$url = "https://management.azure.com/$scope/providers/Microsoft.CostManagement/benefitRecommendations?`$filter=properties/lookBackPeriod eq 'Last30Days' AND properties/term eq 'P3Y'&`$expand=properties/allRecommendationDetails&api-version=2024-08-01"
$uri = [uri]::new($url)
$result = Invoke-AzRestMethod -Uri $uri.AbsoluteUri -Method GET
$all = ($result.Content | ConvertFrom-Json).value

$reservationSavings = ($all | Where-Object { $_.kind -eq 'Reservation' } |
    Measure-Object -Property { $_.properties.recommendationDetails.savingsAmount } -Sum).Sum

$savingsPlanSavings = ($all | Where-Object { $_.kind -eq 'SavingsPlan' } |
    Measure-Object -Property { $_.properties.recommendationDetails.savingsAmount } -Sum).Sum

Write-Host "Total reservation savings: `$$reservationSavings"
Write-Host "Total savings plan savings: `$$savingsPlanSavings"
```

---

## Eligible resource types

| Resource type | Flexibility | Notes |
|---------------|-------------|-------|
| Virtual machines | Instance size flexibility within series | Ratio-based application across sizes in the same series |
| Azure SQL Database | vCore-based | Applies to General Purpose and Business Critical tiers |
| Azure Cosmos DB | Throughput (RU/s) | Provisioned throughput reservations |
| App Service | Isolated v2 stamps | Isolated tier only |
| Azure Synapse Analytics | Data warehouse units | Compute reservations |
| Azure Managed Disks | Premium SSD capacity | Specific disk sizes |
| Azure Blob Storage | Reserved capacity | Hot, cool, and archive access tiers |
| Azure Files | Reserved capacity | Premium file shares |
| Azure Data Explorer | Markup units | Compute reservations |
| Azure VMware Solution | Node reservations | Host-level reservations |
| Red Hat plans | Software plans | RHEL VMs |
| SUSE plans | Software plans | SLES VMs |
| Azure Databricks | DBU commitments | Pre-purchase plans |

---

## Scope and flexibility

### Scope options

| Scope | Description |
|-------|-------------|
| Shared | Applies across all subscriptions in the billing context (maximum flexibility) |
| Single subscription | Applies only to resources in one subscription |
| Single resource group | Applies only to resources in one resource group |
| Management group | Applies across subscriptions in a management group |

### Instance size flexibility

Within a VM series (e.g., D-series), a reservation for one size automatically applies to other sizes in the same series using a ratio-based approach.

Example for D-series:

| VM Size | Ratio |
|---------|-------|
| Standard_D1 | 1 |
| Standard_D2 | 2 |
| Standard_D4 | 4 |
| Standard_D8 | 8 |

A reservation for one Standard_D4 (ratio 4) can cover four Standard_D1 instances (ratio 1 each) or two Standard_D2 instances (ratio 2 each).

**Important:** Reservations are region-specific. A reservation purchased for East US does not apply to resources in West US.

---

## Exchange and return policy

| Action | Policy |
|--------|--------|
| Returns | Self-service cancellation with prorated refund. Up to $50,000 USD (or equivalent) in returns per rolling 12-month window. Early termination fee is not currently charged. |
| Exchanges | Within the same product family only. Prorated value applied to new reservation. Exchange refunds do NOT count against the $50K return limit. |
| Trade-in | Existing reservations can be traded in for savings plans via self-service (no time limit). |

### Compute reservation exchange grace period

For compute reservations (VMs, Dedicated Host, App Service), cross-series and cross-region exchanges are currently allowed under an extended grace period "until further notice." Microsoft will provide at least 6 months advance notice before ending this grace period. After it ends, compute reservation exchanges will be limited to within the same instance size flexibility group only.

### Reservation types that cannot be exchanged or refunded

Azure Databricks, Synapse Analytics Pre-purchase, Red Hat plans, SUSE Linux plans, Microsoft Defender for Cloud Pre-Purchase, and Microsoft Sentinel Pre-Purchase.

**Important:** These policies differ significantly from savings plans, which have no cancellation, return, or exchange option. Consider reservation trade-in to savings plans as an alternative exit path.

### Calculate refund for a specific reservation

```bash
# Calculate the refund amount for a specific reservation return (not the aggregate $50K balance)
az rest --method POST \
  --url "https://management.azure.com/providers/Microsoft.Capacity/calculateRefund?api-version=2022-11-01" \
  --body '{
    "id": "/providers/Microsoft.Capacity/reservationOrders/{reservationOrderId}",
    "properties": {
      "scope": "Reservation",
      "reservationToReturn": {
        "reservationId": "/providers/Microsoft.Capacity/reservationOrders/{orderId}/reservations/{reservationId}",
        "quantity": 1
      }
    }
  }'
```

---

## Benefit application order

Reservations and savings plans follow a strict application order:

1. **Reservations are applied first** in the benefit stack
2. **Savings plans are applied second** to remaining eligible charges
3. This means reservations "win" for matching workloads; savings plans catch the rest

Within reservations, the most specific scope is applied first:

1. Resource group scope
2. Subscription scope
3. Management group scope
4. Shared scope

---

## Utilization monitoring

### Azure CLI

```bash
# Daily utilization summary for a reservation order
az consumption reservation summary list \
    --reservation-order-id {orderId} \
    --grain daily \
    --start-date 2026-01-01 \
    --end-date 2026-01-31
```

### REST API

```http
GET https://management.azure.com/providers/Microsoft.Capacity/reservationOrders/{reservationOrderId}/providers/Microsoft.Consumption/reservationSummaries?grain=daily&$filter=properties/usageDate ge 2026-01-01 AND properties/usageDate le 2026-01-31&api-version=2024-08-01
Authorization: Bearer {token}
```

### Azure Resource Graph -- Advisor purchase recommendations

Query cross-subscription Advisor recommendations for VM reserved instance purchases (recommendationTypeId is specific to VM reservations):

```kusto
advisorresources
| where type == "microsoft.advisor/recommendations"
| where properties.category == "Cost"
| where properties.recommendationTypeId == "84b1a508-fc21-49da-979e-96894f1665df"
| extend
    savings = todouble(properties.extendedProperties.savingsAmount),
    annualSavings = todouble(properties.extendedProperties.annualSavingsAmount)
| project subscriptionId, resourceGroup, savings, annualSavings,
    problem = properties.shortDescription.problem,
    solution = properties.shortDescription.solution
| order by savings desc
```

**Note:** This query surfaces Advisor purchase recommendations, not utilization data. For utilization monitoring, use the Azure CLI or REST API examples above.

---

## Eligibility

### Agreement types

| Agreement Type | Offer IDs | Can purchase reservations |
|----------------|----------------|--------------------------|
| EA | MS-AZR-0017P, MS-AZR-0148P | Yes |
| MCA | - | Yes |
| MPA | - | Yes |
| CSP | - | Yes (partners purchase via Partner Center; customers cannot self-service manage) |
| Pay-As-You-Go | MS-AZR-0003P, MS-AZR-0023P | Yes |
| Azure Sponsorship | MS-AZR-0036P | Yes |

### Required roles

| Action | Required role |
|--------|---------------|
| View recommendations | Cost Management Reader |
| View utilization | Cost Management Reader or Reservation Reader |
| Purchase reservations | Owner or Reservation Purchaser |
| Manage reservations | Owner or Reservation Administrator |

---

## Payment options

| Option | Description |
|--------|-------------|
| All upfront | Pay the full commitment amount at purchase |
| Monthly | Pay in monthly installments over the term |

Payment frequency does not affect the discount amount — only cash flow timing. Total cost is the same for either option.

---

## Auto-renewal

Reservations can be configured for automatic renewal before expiration. Review utilization data before renewal to confirm the commitment level and SKU are still appropriate. Auto-renewal is enabled by default for new purchases — disable it in the Azure portal if you prefer manual renewal.

---

## Coverage limitations

Reservation discounts cover the **compute or capacity portion** of the specified resource type only. The following are NOT covered:

- Software licensing (Windows Server, SQL Server — use Azure Hybrid Benefit separately)
- Networking charges
- Storage costs (except for Azure Blob Storage and Azure Files reserved capacity)
- Marketplace purchases

---

## Best practices

1. **Normalize usage for at least 30 days** before purchasing to ensure stable baseline
2. **Use instance size flexibility** - buy the normalized size for maximum coverage within a VM series
3. **Monitor utilization weekly** - exchange underutilized reservations before waste accumulates
4. **Start with shared scope** for maximum flexibility across subscriptions
5. **Use the 3-day stale data guard** - Microsoft provides the lower of 3-day and lookback-period recommendations as a safeguard against overcommitment
6. **Compare with savings plans** - use the Benefit Recommendations API to evaluate both options before purchasing
7. **Layer reservations and savings plans** - buy reservations for stable, predictable workloads; use savings plans as a safety net for variable compute

See `references/azure-commitment-discount-decision.md` for the full decision framework.

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Low utilization | VM stopped/deallocated or wrong SKU | Check VM state, consider exchange for a different SKU or region |
| Reservation not applying | Scope mismatch or region mismatch | Verify scope and region settings match the target resources |
| No recommendations | Insufficient usage history | Wait for 7+ days of consistent usage before querying |
| Exchange failed | Exceeded $50K return limit | Check remaining return balance in Azure portal |
| Wrong VM size covered | Instance size flexibility ratio | Review the flexibility group ratio table for the VM series |
| Reservation expired | Term ended | Purchase a new reservation; set calendar reminders before expiration |

---

## Prerequisites

- Azure PowerShell module (`Install-Module -Name Az`) or Azure CLI
- Authenticated Azure session (`Connect-AzAccount` or `az login`)
- **Cost Management Reader** permissions on the billing scope (for recommendations)
- **Owner** or **Reservation Purchaser** role (for purchasing)

---

## References

- [Azure Reservations overview](https://learn.microsoft.com/azure/cost-management-billing/reservations/save-compute-costs-reservations)
- [Reservation recommendations](https://learn.microsoft.com/azure/cost-management-billing/reservations/reserved-instance-purchase-recommendations)
- [Instance size flexibility](https://learn.microsoft.com/azure/virtual-machines/reserved-vm-instance-size-flexibility)
- [Self-service exchanges and refunds](https://learn.microsoft.com/azure/cost-management-billing/reservations/exchange-and-refund-azure-reservations)
- [Benefit Recommendations API](https://learn.microsoft.com/rest/api/cost-management/benefit-recommendations)
- [Manage reservations](https://learn.microsoft.com/azure/cost-management-billing/reservations/manage-reserved-vm-instance)
- [Reservation trade-in to savings plans](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/reservation-trade-in)
- [Reservation exchange policy changes](https://learn.microsoft.com/azure/cost-management-billing/reservations/reservation-exchange-policy-changes)
