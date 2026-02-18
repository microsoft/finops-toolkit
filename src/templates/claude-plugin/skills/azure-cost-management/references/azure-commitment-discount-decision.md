---
name: Commitment discount decision framework
description: Decision framework for choosing between Azure Reservations, Savings Plans, or pay-as-you-go based on workload characteristics, risk tolerance, and organizational maturity. Includes comparison criteria, hybrid strategies, and key performance indicators.
---

**Key Features:**
- Side-by-side comparison of reservations vs savings plans
- Decision criteria based on workload stability and flexibility needs
- Hybrid commitment strategy guidance
- Key performance indicators for commitment discount health
- FinOps Framework alignment with rate optimization capability

---

## Decision flow

Use this text-based decision flow to determine the right commitment type:

1. **Do you have consistent compute usage for 30+ days?**
   - No: Stay on pay-as-you-go, revisit in 30 days
   - Yes: Continue to step 2
2. **Is usage concentrated on specific VM SKUs in specific regions?**
   - Yes: Start with reservations (up to 72% savings)
   - No: Continue to step 3
3. **Is usage spread across multiple VM types, regions, or services?**
   - Yes: Start with savings plans (up to 65% savings)
   - No: Continue to step 4
4. **Do you need cancellation flexibility?**
   - Yes: Reservations only (savings plans cannot be canceled)
   - No: Continue to step 5
5. **Do you have both stable and variable compute?**
   - Yes: Use hybrid strategy (see below)
   - No: Default to savings plans for simplicity

---

## Comparison table

| Factor | Reservations | Savings plans | Pay-as-you-go |
|--------|-------------|---------------|---------------|
| Maximum savings | Up to 72% | Up to 65% | 0% (baseline) |
| Flexibility | Low (specific SKU, region) | High (any eligible compute) | Maximum |
| Cancellation | Returns up to $50K/year | No cancellation or refund | N/A |
| Exchange | Yes, within same product family (prorated) | No (but can trade in reservations for savings plans) | N/A |
| Applies to | Specific resource type and region | All eligible compute services | All services |
| Benefit application order | First (highest priority) | Second (after reservations) | N/A |
| Scope options | Shared, management group, subscription, RG | Shared, management group, subscription, RG | N/A |
| Agreement types | EA, MCA, MPA, CSP, PAYG, Sponsorship | EA, MCA, MPA | All |
| Term options | 1 year, 3 years | 1 year, 3 years | None |
| Payment options | All upfront, monthly | All upfront, monthly | Usage-based |
| Instance size flexibility | Yes (within VM series) | N/A (applies to all compute) | N/A |

---

## Hybrid commitment strategy

The optimal approach for most organizations:

1. **Buy reservations first** for stable, predictable workloads (baseline)
2. **Buy savings plans second** for variable or growing compute (covers the rest)
3. **Pay-as-you-go** for truly unpredictable or temporary workloads

Key principle: Reservations are applied first in the benefit stack, so they always "win" for matching workloads. Savings plans catch remaining eligible charges that reservations don't cover.

**Migration path:** If existing reservations no longer fit your workloads, you can trade them in for savings plans via self-service (no time limit). This is a one-way conversion — savings plans cannot be traded back to reservations.

---

## Scope selection guidance

| Scenario | Recommended scope | Rationale |
|----------|-------------------|-----------|
| Single team, dedicated workloads | Resource group | Maximum control, clear cost attribution |
| Shared infrastructure, multiple teams | Subscription | Balance of savings and governance |
| Enterprise-wide optimization | Shared or management group | Maximum savings, automatic benefit distribution |
| New to commitments | Shared | Safest starting point -- benefits auto-distribute |

---

## Data requirements before committing

- Minimum 30 days of consistent usage data (60 days preferred)
- Use the Benefit Recommendations API with `Last30Days` or `Last60Days` lookback
- Coefficient of variation (CV) in hourly usage:
  - **< 0.3** = stable (reservation candidate)
  - **0.3 - 0.6** = variable (savings plan candidate)
  - **> 0.6** = volatile (stay on pay-as-you-go)
- Check for planned migrations, decommissions, or workload changes that would invalidate historical patterns

### Evaluate usage stability

```powershell
# Calculate coefficient of variation from hourly usage data
$hourlyUsage = @(10.2, 10.5, 10.1, 10.8, 10.3)  # Replace with actual hourly data
$mean = ($hourlyUsage | Measure-Object -Average).Average
$stdDev = [Math]::Sqrt(($hourlyUsage | ForEach-Object { [Math]::Pow($_ - $mean, 2) } | Measure-Object -Sum).Sum / $hourlyUsage.Count)
$cv = $stdDev / $mean

switch ($cv) {
    { $_ -lt 0.3 } { Write-Host "CV: $([Math]::Round($cv, 3)) - Stable: reservation candidate"; break }
    { $_ -lt 0.6 } { Write-Host "CV: $([Math]::Round($cv, 3)) - Variable: savings plan candidate"; break }
    default         { Write-Host "CV: $([Math]::Round($cv, 3)) - Volatile: stay on pay-as-you-go" }
}
```

---

## The 70% rule for management group scope

The Benefit Recommendations API does not support management group scope. Microsoft's documented workaround:

1. Get recommendations for each subscription individually
2. Sum the recommended commitment amounts
3. Purchase approximately 70% of the total (conservative start)
4. Wait 3 days for the recommendation engine to recalculate
5. Iterate -- get new recommendations that account for existing commitments
6. Repeat until incremental savings are negligible

```powershell
# Aggregate recommendations across subscriptions by calling the API directly
$subscriptions = Get-AzSubscription
$totalRecommended = 0

foreach ($sub in $subscriptions) {
    Set-AzContext -Subscription $sub.Id
    $scope = "subscriptions/$($sub.Id)"
    $url = "https://management.azure.com/$scope/providers/Microsoft.CostManagement/benefitRecommendations?`$filter=properties/lookBackPeriod eq 'Last30Days' AND properties/term eq 'P3Y'&`$expand=properties/allRecommendationDetails&api-version=2024-08-01"
    $uri = [uri]::new($url)
    $result = Invoke-AzRestMethod -Uri $uri.AbsoluteUri -Method GET
    $recs = ($result.Content | ConvertFrom-Json).value

    foreach ($rec in $recs) {
        $details = $rec.properties.recommendationDetails
        if ($details -and $details.averageUtilizationPercentage -ge 90) {
            $totalRecommended += $details.commitmentAmount
        }
    }
}

$mgScopeCommitment = $totalRecommended * 0.7
Write-Host "Total recommended: `$$totalRecommended/hr"
Write-Host "Management group purchase (70%): `$$mgScopeCommitment/hr"
```

---

## Waiting periods

| Event | Wait period | Reason |
|-------|-------------|--------|
| After purchasing, before evaluating other commitment types | 7 days | Allows recommendation engine to recalculate across both reservation and savings plan models |
| Iterative same-type purchasing (management group workaround) | 3 days | Allows new commitment to affect subscription-level recommendations before next iteration |

The recommendation engine uses recent utilization data. New commitments change the usage pattern, so recommendations generated before the engine recalculates may be inaccurate.

---

## Key performance indicators

| KPI | Formula | Target | Description |
|-----|---------|--------|-------------|
| Effective savings rate (ESR) | (List cost - effective cost) / list cost | >20% | Percentage savings vs on-demand pricing |
| Utilization rate | Used hours / committed hours | >90% | How much of the commitment is actually used |
| Coverage percentage | Covered cost / total eligible cost | 60-80% | What portion of eligible spend is under commitment |
| Wastage rate | Wasted cost / commitment cost | <10% | Unused commitment (use-it-or-lose-it per hour) |

**Interpretation guidelines:**
- ESR below 10% indicates no commitment discounts in place -- opportunity for savings
- Utilization below 80% indicates overcommitment -- consider exchanging or not renewing
- Coverage above 80% may indicate overcommitment risk -- leave room for usage variability
- Target ESR varies by organization and industry -- track trend over time rather than targeting a specific number

---

## FinOps Framework alignment

This decision framework maps to the FinOps Framework's rate optimization capability:

- **Inform**: Analyze current spend, identify commitment-eligible workloads, assess usage stability, track ESR/utilization/wastage
- **Optimize**: Purchase commitments based on this decision framework, exchange underutilized reservations, adjust commitment levels
- **Operate**: Establish governance processes for commitment purchases, renewals, and exchanges; monitor utilization weekly; report savings to stakeholders

Link: [Rate optimization (FinOps Framework)](https://learn.microsoft.com/cloud-computing/finops/framework/optimize/rates)

---

## Common mistakes

| Mistake | Impact | Prevention |
|---------|--------|------------|
| Buying savings plans before reservations | Lower savings (reservations offer up to 72% vs 65%) | Always buy reservations first for stable workloads |
| Purchasing 100% coverage | High wastage risk | Target 60-80% coverage, leave buffer for variability |
| Using 7-day lookback for large purchases | Overcommitment risk | Use 30 or 60-day lookback for commitments over $1K/month |
| Ignoring pending migrations | Stranded commitments | Check with infrastructure teams before purchasing |
| No renewal governance | Expired commitments, lost savings | Set calendar reminders 30 days before expiry |
| Purchasing without checking existing commitments | Double coverage, wastage | Always check current utilization before new purchases |

---

## Prerequisites

- Understanding of current Azure spend patterns (30+ days of data)
- Access to Benefit Recommendations API (Cost Management Reader role)
- Knowledge of planned workload changes
- Stakeholder alignment on commitment term and risk tolerance

---

## References

- [Azure savings plan overview](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/savings-plan-compute-overview)
- [Azure Reservations overview](https://learn.microsoft.com/azure/cost-management-billing/reservations/save-compute-costs-reservations)
- [Decide between a savings plan and a reservation](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/decide-between-savings-plan-reservation)
- [Rate optimization (FinOps Framework)](https://learn.microsoft.com/cloud-computing/finops/framework/optimize/rates)
- [Choose commitment amount](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/choose-commitment-amount)
- [Benefit Recommendations API](https://learn.microsoft.com/rest/api/cost-management/benefit-recommendations)
- [Reservation trade-in to savings plans](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/reservation-trade-in)
- [Exchange and refund policies](https://learn.microsoft.com/azure/cost-management-billing/reservations/exchange-and-refund-azure-reservations)
