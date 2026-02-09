---
name: Azure Savings Plans
description: Query the Azure Cost Management Benefit Recommendations API to retrieve savings plan purchase recommendations based on historical compute usage patterns. Analyze potential savings, coverage percentages, and optimal commitment amounts.
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
| `LookBackPeriod` | No | Last7Days | Analysis period: Last7Days, Last30Days, Last60Days |
| `Term` | No | P3Y | Savings plan term: P1Y (1-year) or P3Y (3-year) |

### Scope Formats

| Scope Type | Format |
|------------|--------|
| Billing Account | `providers/Microsoft.Billing/billingAccounts/{billingAccountId}` |
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
POST https://management.azure.com/{scope}/providers/Microsoft.CostManagement/benefitRecommendations?api-version=2023-08-01
Content-Type: application/json
Authorization: Bearer {token}

{
  "properties": {
    "lookBackPeriod": "Last30Days",
    "term": "P3Y",
    "scope": "Shared",
    "kind": "SavingsPlan"
  }
}
```

### Scope Values

| Scope | Description |
|-------|-------------|
| `Shared` | Analyzes usage across entire billing scope (default, optimal savings) |
| `Single` | Resource-specific recommendations |

### Response Structure

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
        "recommendations": [
          {
            "commitmentAmount": 10.5,
            "savingsAmount": 2500,
            "savingsPercentage": 25.5,
            "coveragePercentage": 85.2,
            "averageUtilizationPercentage": 92.3,
            "totalCost": 8500,
            "benefitCost": 7560,
            "overageCost": 940,
            "wastageCost": 580
          }
        ]
      }
    }
  ]
}
```

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

## EA Storage Report

Analyze storage account costs across an Enterprise Agreement:

```powershell
# Default (MonthToDate, configured EA)
.\Get-EAStorageReport.ps1

# Custom billing account and timeframe
.\Get-EAStorageReport.ps1 -BillingAccountId "1234567" -Timeframe "TheLastMonth"
```

### Output

- **Summary by subscription**: Account count, total cost, storage GiB per subscription
- **Top 20 storage accounts by cost**: Highest-cost storage accounts
- **All storage accounts**: Complete listing sorted by cost

**Note:** Storage quantities are reported in GiB (gibibytes, base-2) as returned by Azure billing meters.

---

## Integration with FinOps Analysis

### Calculate Break-Even Point

```powershell
# Get current pay-as-you-go costs
$payg = $result.recommendations |
    Select-Object -First 1 |
    ForEach-Object { $_.totalCost + $_.savingsAmount }

# Calculate break-even
$commitment = $result.recommendations[0]
$monthlyCommitment = $commitment.commitmentAmount * 730  # hours/month
$monthlySavings = $commitment.savingsAmount / 12

$breakEvenMonths = $monthlyCommitment / $monthlySavings

Write-Host "Monthly commitment: $$monthlyCommitment"
Write-Host "Monthly savings: $$monthlySavings"
Write-Host "Break-even: $breakEvenMonths months"
```

### Risk Assessment

```powershell
# Evaluate commitment risk based on utilization variance
$recommendations = $result.recommendations

foreach ($rec in $recommendations) {
    $risk = switch ($rec.averageUtilizationPercentage) {
        { $_ -ge 95 } { "Low - High utilization, minimal waste" }
        { $_ -ge 85 } { "Medium - Good utilization, some flexibility" }
        { $_ -ge 70 } { "High - Consider lower commitment" }
        default { "Very High - Significant underutilization risk" }
    }

    Write-Host "Commitment: $($rec.commitmentAmount)/hr - Risk: $risk"
}
```

---

## Prerequisites

- Azure PowerShell module (`Install-Module -Name Az`)
- Authenticated Azure session (`Connect-AzAccount`)
- **Cost Management Reader** permissions on the billing scope
- Valid billing account ID or subscription ID

---

## References

- [Benefit Recommendations API](https://learn.microsoft.com/rest/api/cost-management/benefit-recommendations)
- [Azure savings plan overview](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/savings-plan-compute-overview)
- [Choose commitment amount](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/choose-commitment-amount)
- [Source scripts (azcapman)](https://github.com/msbrettorg/azcapman/tree/main/scripts/rate)
