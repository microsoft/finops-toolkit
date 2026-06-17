---
title: Cost Analysis
---

# Cost analysis scripts

Azure Cost Management tools for analyzing savings plan purchase recommendations and storage costs to optimize your Azure spend.

> [!TIP]
> Use these scripts when you want to turn Azure Cost Management savings plan purchase recommendations into repeatable analyses for finance and operations teams.[^benefit-api]

---

## Available scripts

### Get-BenefitRecommendations.ps1

Queries the Azure Cost Management API to retrieve savings plan purchase recommendations based on your historical compute usage patterns.

**What it does:**
- Analyzes historical compute usage patterns (7, 30, or 60 days lookback)
- Provides up to 10 savings plan commitment recommendations for specified term (1-year or 3-year)
- Calculates potential cost savings compared to pay-as-you-go pricing
- Shows commitment amounts and usage coverage percentages
- Returns both the top recommended savings plan and all available options

**Output includes:**
- **Raw JSON response** from Cost Management API (for debugging/verification)
- **Recommended savings plan** with detailed financial analysis:
  - Hourly commitment amount
  - Total savings amount and percentage
  - Usage coverage and utilization percentages
  - Overage costs and wastage estimates
- **All savings plan recommendations** showing various commitment levels and their projected performance

---

### Output field descriptions

The formatted tables include these key financial metrics:

| Field | Description |
|-------|-------------|
| **averageUtilizationPercentage** | Estimated average utilization percentage for the look-back period with this commitment |
| **commitmentAmount** | The hourly commitment amount at the specified granularity |
| **coveragePercentage** | Estimated benefit coverage percentage for the look-back period with this commitment |
| **savingsAmount** | The total amount saved for the look-back period by purchasing this savings plan |
| **savingsPercentage** | The savings percentage for the look-back period by purchasing this savings plan |
| **totalCost** | Total projected cost (sum of benefit cost and overage cost) |
| **benefitCost** | The estimated cost with benefit for the look-back period (commitmentAmount × totalHours) |
| **overageCost** | The difference between total cost and benefit cost for the look-back period |
| **wastageCost** | Estimated unused portion of the benefit cost |

---

## Prerequisites and Parameters

**Prerequisites:**
- Azure PowerShell module (`Install-Module -Name Az`)
- Authenticated Azure session (`Connect-AzAccount`)
- Cost Management Reader permissions on the billing scope
- Valid billing account ID or subscription ID

**Parameters:**
- `BillingScope` (required): Billing account, subscription, or resource group scope
  - Billing Account: `providers/Microsoft.Billing/billingAccounts/{billingAccountId}`
  - Subscription: `subscriptions/{subscriptionId}`
  - Resource Group: `subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}`
- `LookBackPeriod`: Historical analysis period (Last7Days, Last30Days, Last60Days) - default: Last7Days
- `Term`: Savings plan term (P1Y for 1-year, P3Y for 3-year) - default: P3Y

**Note:** The API returns recommendations with shared scope by default, analyzing usage across the entire billing scope for optimal savings.

---

## Usage examples

```powershell
# Find your billing scope first
Get-AzBillingAccount  # For billing account scope
Get-AzSubscription    # For subscription scope

# Basic usage with subscription scope
.\Get-BenefitRecommendations.ps1 -BillingScope "subscriptions/12345678-1234-1234-1234-123456789012"

# Advanced usage with billing account, 30-day lookback, and 1-year term
.\Get-BenefitRecommendations.ps1 -BillingScope "providers/Microsoft.Billing/billingAccounts/12345678" -LookBackPeriod "Last30Days" -Term "P1Y"

# Resource group scope analysis
.\Get-BenefitRecommendations.ps1 -BillingScope "subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/myResourceGroup"
```

---

## About the API

This script uses the Azure Cost Management [Benefit Recommendations API](https://learn.microsoft.com/en-us/rest/api/cost-management/benefit-recommendations) to provide **savings plan purchase recommendations**. 

The API analyzes your actual compute usage patterns and calculates optimal hourly commitment amounts that minimize total costs compared to pay-as-you-go pricing. 

Recommendations include detailed financial metrics: commitment amounts, projected savings percentages, coverage percentages, utilization rates, and potential overage/wastage costs. The raw JSON output provides full API response details, while formatted tables present actionable purchase recommendations.

**Source**: [Benefit Recommendations API](https://learn.microsoft.com/en-us/rest/api/cost-management/benefit-recommendations)

---

[^benefit-api]: [Benefit Recommendations API](https://learn.microsoft.com/en-us/rest/api/cost-management/benefit-recommendations)
