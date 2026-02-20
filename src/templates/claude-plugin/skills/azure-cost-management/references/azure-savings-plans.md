---
name: Azure Savings Plans
description: Query the Azure Cost Management Benefit Recommendations API to retrieve savings plan purchase recommendations based on historical compute usage patterns. Analyze potential savings (up to 65% vs PAYG), coverage percentages, and optimal commitment amounts for flexible compute workloads.
---

**Key Features:**
- Historical usage analysis (7, 30, or 60 days lookback)
- Up to 10 commitment level recommendations
- Savings calculations vs pay-as-you-go pricing
- Coverage and utilization projections
- Support for 1-year and 3-year terms

---

## Benefit Recommendations API

### PowerShell Script

```powershell
# Basic usage with subscription scope
.\Get-BenefitRecommendations.ps1 `
    -BillingScope "subscriptions/12345678-1234-1234-1234-123456789012"

# Advanced: billing account, 30-day lookback, 1-year term
.\Get-BenefitRecommendations.ps1 `
    -BillingScope "providers/Microsoft.Billing/billingAccounts/12345678" `
    -LookBackPeriod "Last30Days" `
    -Term "P1Y"

# Resource group scope
.\Get-BenefitRecommendations.ps1 `
    -BillingScope "subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/myResourceGroup"
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `BillingScope` | Yes | - | Billing account, subscription, or resource group scope |
| `LookBackPeriod` | No | Last7Days | Analysis period: Last7Days, Last30Days, Last60Days. Script default is Last7Days; API default (when omitted from REST call) is Last60Days |
| `Term` | No | P3Y | Savings plan term: P1Y (1-year) or P3Y (3-year) |

### Scope Formats

| Scope Type | Format |
|------------|--------|
| Billing Account | `providers/Microsoft.Billing/billingAccounts/{billingAccountId}` |
| Billing Profile (MCA) | `providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}` |
| Subscription | `subscriptions/{subscriptionId}` |
| Resource Group | `subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}` |

---

## Output Metrics

The API returns detailed financial projections:

| Metric | Description |
|--------|-------------|
| **commitmentAmount** | Hourly commitment amount at specified granularity |
| **savingsAmount** | Total amount saved for the lookback period |
| **savingsPercentage** | Savings percentage vs pay-as-you-go |
| **coveragePercentage** | Estimated benefit coverage for the lookback period |
| **averageUtilizationPercentage** | Estimated average utilization with this commitment |
| **totalCost** | Sum of benefit cost and overage cost |
| **benefitCost** | commitmentAmount × totalHours |
| **overageCost** | Charges exceeding the commitment |
| **wastageCost** | Unused portion of the benefit cost |

---

## REST API

### Request

```http
GET https://management.azure.com/{billingScope}/providers/Microsoft.CostManagement/benefitRecommendations?$filter=properties/lookBackPeriod eq 'Last30Days' AND properties/term eq 'P3Y'&$expand=properties/usage,properties/allRecommendationDetails&api-version=2024-08-01
Authorization: Bearer {token}
```

All parameters are passed via OData `$filter` query parameters, not a request body. The `$expand` parameter controls which detail sections are returned:

| $expand value | Effect |
|---------------|--------|
| `properties/allRecommendationDetails` | Returns all 10 commitment level recommendations (required for comparison analysis) |
| `properties/usage` | Returns hourly usage data for the lookback period |

To filter for savings plans only, add `AND properties/kind eq 'SavingsPlan'` to the `$filter`. Without a `kind` filter, the API returns both savings plan and reservation recommendations.

### Scope values

| Scope | Description |
|-------|-------------|
| `Shared` | Analyzes usage across entire billing scope (default, optimal savings) |
| `Single` | Resource-specific recommendations |

**Note:** Add `AND properties/scope eq 'Shared'` to the `$filter` to specify scope. Default behavior analyzes shared scope.

### Response structure

```json
{
  "value": [
    {
      "properties": {
        "firstConsumptionDate": "2026-01-01",
        "lastConsumptionDate": "2026-01-21",
        "lookBackPeriod": "Last30Days",
        "term": "P3Y",
        "totalHours": 720,
        "scope": "Shared",
        "kind": "SavingsPlan",
        "currencyCode": "USD",
        "costWithoutBenefit": 11000,
        "recommendationDetails": {
          "commitmentAmount": 10.5,
          "savingsAmount": 2500,
          "savingsPercentage": 25.5,
          "coveragePercentage": 85.2,
          "averageUtilizationPercentage": 92.3,
          "totalCost": 8500,
          "benefitCost": 7560,
          "overageCost": 940,
          "wastageCost": 580
        },
        "allRecommendationDetails": {
          "value": [
            { "commitmentAmount": 5.0, "savingsPercentage": 15.2, "averageUtilizationPercentage": 98.1 },
            { "commitmentAmount": 10.5, "savingsPercentage": 25.5, "averageUtilizationPercentage": 92.3 },
            { "commitmentAmount": 15.0, "savingsPercentage": 28.1, "averageUtilizationPercentage": 85.7 }
          ]
        }
      }
    }
  ]
}
```

**Note:** The `allRecommendationDetails` array only appears when `$expand=properties/allRecommendationDetails` is included in the request. The `recommendationDetails` object always contains the single best recommendation.

---

## Analysis Examples

### Find Optimal Commitment Level

```powershell
# Get recommendations
$result = .\Get-BenefitRecommendations.ps1 `
    -BillingScope "subscriptions/$subscriptionId" `
    -LookBackPeriod "Last30Days" `
    -Term "P3Y"

# Find recommendation with best savings/utilization balance
$optimal = $result.recommendations |
    Where-Object { $_.averageUtilizationPercentage -ge 90 } |
    Sort-Object savingsAmount -Descending |
    Select-Object -First 1

Write-Host "Optimal hourly commitment: $($optimal.commitmentAmount)"
Write-Host "Projected monthly savings: $($optimal.savingsAmount)"
Write-Host "Coverage: $($optimal.coveragePercentage)%"
```

### Compare 1-Year vs 3-Year Terms

```powershell
$scope = "subscriptions/$subscriptionId"

$oneYear = .\Get-BenefitRecommendations.ps1 -BillingScope $scope -Term "P1Y"
$threeYear = .\Get-BenefitRecommendations.ps1 -BillingScope $scope -Term "P3Y"

# Compare top recommendations
$comparison = @{
    "1-Year" = @{
        Commitment = $oneYear.recommendations[0].commitmentAmount
        Savings = $oneYear.recommendations[0].savingsPercentage
    }
    "3-Year" = @{
        Commitment = $threeYear.recommendations[0].commitmentAmount
        Savings = $threeYear.recommendations[0].savingsPercentage
    }
}

$comparison | ConvertTo-Json
```

---

## Integration with FinOps analysis

### Utilization analysis

```powershell
# Assess whether the recommended commitment level will be fully utilized
# Key metric: averageUtilizationPercentage — the projected percentage of committed hours that would be consumed
# Target: >90% utilization = good commitment fit; <80% = consider lower commitment

$optimal = $result.recommendations |
    Where-Object { $_.averageUtilizationPercentage -ge 90 } |
    Sort-Object savingsAmount -Descending |
    Select-Object -First 1

$wastageRate = (1 - ($optimal.averageUtilizationPercentage / 100)) * $optimal.benefitCost
Write-Host "Projected hourly commitment: $($optimal.commitmentAmount)"
Write-Host "Projected savings (lookback period): $($optimal.savingsAmount)"
Write-Host "Projected wastage (lookback period): $wastageRate"
Write-Host "Utilization: $($optimal.averageUtilizationPercentage)%"
```

**Important:** The `savingsAmount` from the API represents total savings over the lookback period (7, 30, or 60 days), not annual savings. Do not divide by 12 to get monthly figures — instead scale proportionally from the lookback window.

### Risk assessment

```powershell
# Evaluate commitment risk based on utilization variance
$recommendations = $result.recommendations

foreach ($rec in $recommendations) {
    $risk = switch ($rec.averageUtilizationPercentage) {
        { $_ -ge 95 } { "Low - High utilization, minimal waste"; break }
        { $_ -ge 85 } { "Medium - Good utilization, some flexibility"; break }
        { $_ -ge 70 } { "High - Consider lower commitment"; break }
        default { "Very High - Significant underutilization risk" }
    }

    Write-Host "Commitment: $($rec.commitmentAmount)/hr - Risk: $risk"
}
```

---

## Savings plan policies

### Eligibility

Savings plans are available for these agreement types only:
- Enterprise Agreement (EA): Offer IDs MS-AZR-0017P, MS-AZR-0148P
- Microsoft Customer Agreement (MCA)
- Microsoft Partner Agreement (MPA)

**Not available** for CSP (Cloud Solution Provider), Pay-As-You-Go, or free/trial subscriptions.

### Cancellation and refund policy

Savings plan purchases **cannot be canceled or refunded**. This is a hard constraint — there is no self-service cancellation, no exchange, and no early termination option. This is the most significant policy difference from reservations (which allow up to $50K/year in returns).

### Payment options

| Option | Description |
|--------|-------------|
| All upfront | Pay the full commitment amount at purchase (total cost is the same) |
| Monthly | Pay in monthly installments over the term (total cost is the same) |

Payment frequency does not affect the discount amount — only cash flow timing.

### Auto-renewal

Savings plans can be configured for automatic renewal before expiration. Set this at purchase time or update later in the Azure portal. Review utilization before renewal to confirm the commitment level is still appropriate.

---

## Discount application mechanics

### How benefits are applied

Savings plan discounts are applied **hourly** on a use-it-or-lose-it basis:

1. Each hour, Azure calculates your eligible compute charges
2. The savings plan benefit is applied to the product with the **greatest discount first** (maximizing your savings)
3. Any unused commitment for that hour is **lost** — it does not roll over
4. Reservations are always applied **before** savings plans in the benefit stack

### Scope processing order

When multiple commitment discounts exist, benefits are applied in this order:
1. Resource group scope (most specific)
2. Subscription scope
3. Management group scope
4. Shared scope (broadest)

### Coverage limitations

Savings plans cover **compute charges only**. The following are NOT covered:
- Software licensing (Windows Server, SQL Server — use Azure Hybrid Benefit separately)
- Networking charges
- Storage costs
- Marketplace purchases

---

## Recommendation guidance

### The 3-day stale data guard

Microsoft runs simulations using only the last 3 days of usage as a safeguard against overcommitment from stale data. The recommendation engine provides the **lower** of the 3-day and full lookback-period recommendations. This means short usage spikes within the lookback window will not inflate recommendations.

### 7-day waiting period

After purchasing a savings plan or reservation, wait at least **7 days** before evaluating further commitment recommendations. The recommendation engine needs time to recalculate based on the new benefit coverage. Purchasing immediately can result in double-coverage and wastage.

### Management group workaround

The Benefit Recommendations API does not support management group scope. Microsoft's documented workaround:
1. Get recommendations for each subscription individually
2. Sum the recommended commitment amounts
3. Purchase approximately **70%** of the total (conservative start)
4. Wait 3 days for the recommendation engine to recalculate
5. Iterate — get new recommendations accounting for existing commitments
6. Repeat until incremental savings are negligible

### Savings quantification

Savings plans provide up to **65% savings** compared to pay-as-you-go pricing. Actual savings depend on:
- Commitment term (3-year provides deeper discounts than 1-year)
- Utilization rate (higher utilization = more realized savings)
- Workload consistency (stable usage patterns maximize benefit)

For comparison, reservations offer up to **72% savings** but with less flexibility. See `references/azure-commitment-discount-decision.md` for the decision framework.

---

## Script source

The `Get-BenefitRecommendations.ps1` script is embedded below for self-contained use. This script uses `Invoke-AzRestMethod` with the correct GET method and OData filter parameters.

```powershell
<#
.SYNOPSIS
    Get Azure Cost Management benefit recommendations for savings plans and reserved instances.

.DESCRIPTION
    This script queries the Azure Cost Management API to retrieve benefit recommendations
    based on historical usage patterns. It helps identify opportunities for cost savings
    through Azure savings plans and reserved instances.

.PARAMETER BillingScope
    The billing scope to query. Can be a billing account or subscription.
    Examples:
    - "providers/Microsoft.Billing/billingAccounts/12345678"
    - "subscriptions/12345678-1234-1234-1234-123456789012"

.PARAMETER LookBackPeriod
    Historical period to analyze for recommendations.
    Valid values: Last7Days, Last30Days, Last60Days
    Default: Last7Days

.PARAMETER Term
    Commitment term for savings plans.
    Valid values: P1Y (1 year), P3Y (3 years)
    Default: P3Y

.EXAMPLE
    .\Get-BenefitRecommendations.ps1 -BillingScope "subscriptions/12345678-1234-1234-1234-123456789012"

    Gets 3-year savings plan recommendations for a subscription based on last 7 days usage.

.EXAMPLE
    .\Get-BenefitRecommendations.ps1 -BillingScope "providers/Microsoft.Billing/billingAccounts/12345678" -LookBackPeriod "Last30Days" -Term "P1Y"

    Gets 1-year savings plan recommendations for a billing account based on last 30 days usage.

.NOTES
    Requires Azure PowerShell module and Cost Management Reader permissions on the specified scope.

    To find your billing account: Get-AzBillingAccount
    To find subscriptions: Get-AzSubscription
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Billing scope (billing account or subscription)")]
    [string]
    $BillingScope,

    [Parameter()]
    [ValidateSet('Last7Days', 'Last30Days', 'Last60Days')]
    [string]
    $LookBackPeriod = 'Last7Days',

    [Parameter()]
    [ValidateSet('P1Y', 'P3Y')]
    [string]
    $Term = 'P3Y'
)

$url="https://management.azure.com/{0}/providers/Microsoft.CostManagement/benefitRecommendations?`$filter=properties/lookBackPeriod eq '{1}' AND properties/term eq '{2}'&`$expand=properties/usage,properties/allRecommendationDetails&api-version=2024-08-01" -f $BillingScope, $lookBackPeriod, $term
$uri=[uri]::new($url)
$result = Invoke-AzRestMethod -Uri $uri.AbsoluteUri -Method GET
$jsonResult = $result.Content | ConvertFrom-Json

Write-Output ""
Write-Output "Raw output"
$result.Content
Write-Output ""
Write-Output "Recommended savings plan"
$jsonResult.value.properties.recommendationDetails | Format-Table
Write-Output ""
Write-Output "All savings plan recommendations"
$jsonResult.value.properties.allRecommendationDetails.value | Format-Table
```

---

## Prerequisites

- Azure PowerShell module (`Install-Module -Name Az`)
- Authenticated Azure session (`Connect-AzAccount`)
- **Cost Management Reader** permissions on the billing scope
- Valid billing account ID or subscription ID
- Agreement type: EA (MS-AZR-0017P or MS-AZR-0148P), MCA, or MPA

---

## References

- [Benefit Recommendations API](https://learn.microsoft.com/rest/api/cost-management/benefit-recommendations)
- [Azure savings plan overview](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/savings-plan-compute-overview)
- [Choose commitment amount](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/choose-commitment-amount)
- [How saving plan discount is applied](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/discount-application)
- [Decide between a savings plan and a reservation](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/decide-between-savings-plan-reservation)
- [Rate optimization (FinOps Framework)](https://learn.microsoft.com/cloud-computing/finops/framework/optimize/rates)
