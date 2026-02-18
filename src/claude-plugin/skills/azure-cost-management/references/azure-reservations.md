---
name: Azure Reservations
description: Query the Azure Cost Management Benefit Recommendations API to retrieve reserved instance purchase recommendations. Analyze potential savings, utilization, coverage, and optimal commitment amounts for specific Azure resource types.
---

**Key Features:**
- Up to 72% savings vs pay-as-you-go pricing for stable workloads
- Resource-type specific (VMs, SQL DB, Cosmos DB, App Service, Synapse, Storage, etc.)
- Instance size flexibility within VM series
- Exchange and return policy (up to $50K/year in returns)
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

When no `kind` filter is specified, the API returns both savings plan and reservation recommendations. To retrieve reservations only, add the filter:

```
$filter=properties/kind eq 'Reservation' AND properties/lookBackPeriod eq '{lookBackPeriod}' AND properties/term eq '{term}'
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `billingScope` | Yes | - | Billing account, subscription, or resource group scope |
| `lookBackPeriod` | No | Last7Days | Analysis period: Last7Days, Last30Days, Last60Days |
| `term` | No | P3Y | Reservation term: P1Y (1-year) or P3Y (3-year) |
| `kind` | No | - | Filter by benefit type: `Reservation` or `SavingsPlan` |

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
# Get all benefit recommendations
$result = .\Get-BenefitRecommendations.ps1 `
    -BillingScope "subscriptions/12345678-1234-1234-1234-123456789012" `
    -LookBackPeriod "Last30Days" `
    -Term "P3Y"

# Filter for reservation recommendations only
$reservations = $result | Where-Object { $_.properties.kind -eq 'Reservation' }

# Display summary
$reservations | ForEach-Object {
    $rec = $_.properties
    Write-Host "Resource type: $($rec.resourceType)"
    Write-Host "  Recommended quantity: $($rec.recommendedQuantity)"
    Write-Host "  Savings percentage: $($rec.savingsPercentage)%"
    Write-Host "  Term: $($rec.term)"
    Write-Host ""
}
```

### Compare reservation vs savings plan recommendations

```powershell
$scope = "subscriptions/$subscriptionId"

$all = .\Get-BenefitRecommendations.ps1 -BillingScope $scope -LookBackPeriod "Last30Days"

$reservationSavings = ($all | Where-Object { $_.properties.kind -eq 'Reservation' } |
    Measure-Object -Property { $_.properties.recommendations[0].savingsAmount } -Sum).Sum

$savingsPlanSavings = ($all | Where-Object { $_.properties.kind -eq 'SavingsPlan' } |
    Measure-Object -Property { $_.properties.recommendations[0].savingsAmount } -Sum).Sum

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
| Azure Blob Storage | Reserved capacity | Hot and cool access tiers |
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
| Returns | Up to $50,000 USD (or equivalent) in self-service returns per rolling 12-month window |
| Exchanges | Can exchange for different SKU, region, or term at any time (prorated) |
| Cancellation | Self-service cancellation with prorated refund minus 12% early termination fee |

**Important:** These policies differ significantly from savings plans, which have no cancellation or return option. This makes reservations more flexible for workloads with uncertain long-term usage patterns.

To check remaining return balance:

```bash
# View return balance in Azure portal
# Navigate to: Reservations → Exchange/Return → View remaining return balance
# Or use the REST API:
az rest --method GET \
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

### Azure Resource Graph

Query cross-subscription reservation utilization:

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

---

## Eligibility

### Agreement types

| Agreement Type | Enrollment IDs | Can purchase reservations |
|----------------|----------------|--------------------------|
| EA | MS-AZR-0017P, MS-AZR-0148P | Yes |
| MCA | - | Yes |
| MPA | - | Yes |
| CSP | - | Yes (unlike some savings plan scenarios) |

### Required roles

| Action | Required role |
|--------|---------------|
| View recommendations | Cost Management Reader |
| View utilization | Cost Management Reader or Reservation Reader |
| Purchase reservations | Owner or Reservation Purchaser |
| Manage reservations | Owner or Reservation Administrator |

---

## Best practices

1. **Normalize usage for at least 30 days** before purchasing to ensure stable baseline
2. **Use instance size flexibility** - buy the normalized size for maximum coverage within a VM series
3. **Monitor utilization weekly** - exchange underutilized reservations before waste accumulates
4. **Start with shared scope** for maximum flexibility across subscriptions
5. **Use the 3-day stale data guard** - Microsoft provides the lower of 3-day and lookback-period recommendations as a safeguard against overcommitment
6. **Compare with savings plans** - use the Benefit Recommendations API to evaluate both options before purchasing
7. **Layer reservations and savings plans** - buy reservations for stable, predictable workloads; use savings plans as a safety net for variable compute

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
