# Commitment discounts

Reservations, savings plans, and the analysis around them: what to buy, whether existing commitments are being used, and what they've actually saved.

`azure-cost-management` documents the underlying APIs in `references/azure-reservations.md`, `references/azure-savings-plans.md`, and `references/azure-commitment-discount-decision.md`. This page covers the sequencing and the places the raw data misleads.

## Purchase recommendations

Two sources, and they disagree by design:

| Source                         | Endpoint                                           | Scope                           |
| ------------------------------ | -------------------------------------------------- | ------------------------------- |
| Azure Advisor                  | `az advisor recommendation list --category Cost`   | Subscription, filtered to cost  |
| Reservation Recommendation API | `Microsoft.Consumption/reservationRecommendations` | Billing account or subscription |

Advisor is easier to reach and is what most agents land on first. It has a serious reporting trap.

### Advisor emits duplicate recommendations

Azure Advisor commonly returns **the same purchase 3-6 times**. The records differ only by recommendation GUID, produced by overlapping generation cycles. They are not distinct opportunities.

Summing `annualSavingsAmount` across raw Advisor records inflates the estimate several-fold. On a large estate this turns a real $40k opportunity into a reported $200k, and nothing in the response signals that anything is wrong.

De-duplicate on the meaningful tuple before totalling:

```text
subscriptionId | resourceType | term | SKU | region | quantity | annualSavings
```

Keep a count of how many records collapsed into each row. It's useful context, and a high count is itself a signal that Advisor is churning recommendations.

Report the de-duplicated total. If you present a raw Advisor sum, say explicitly that it may contain duplicates.

### Interpreting the recommendation

- **Term.** Advisor usually recommends both 1-year and 3-year. They're alternatives, not additive. Never sum across terms.
- **Lookback.** Recommendations are generated from a 7, 30, or 60-day window. A 7-day lookback after an atypical week produces a bad recommendation. Prefer 30 or 60 day where available.
- **Scope.** Shared-scope reservations apply across subscriptions and generally utilize better than single-subscription ones. A recommendation scoped to one subscription may still be the wrong shape.
- **Quantity.** Advisor recommends the quantity that maximizes savings at its assumed utilization. If the workload is shrinking, buy under the recommendation.

## Commitment utilization

The question behind this: _are we wasting what we already bought?_

```bash
az rest --method get --url "https://management.azure.com/providers/Microsoft.Capacity/reservationOrders?api-version=2022-11-01"
```

Utilization comes from `Microsoft.Consumption/reservationSummaries`, aggregated daily or monthly.

Thresholds worth flagging:

| Utilization | Reading                                                                  |
| ----------- | ------------------------------------------------------------------------ |
| Below 70%   | Material waste. Investigate scope and workload changes.                  |
| 70-90%      | Normal for a fluctuating estate. Watch, don't act.                       |
| Above 95%   | Healthy, and possibly under-bought. Check for uncovered on-demand usage. |

Low utilization has three usual causes, in order of frequency: the reservation is scoped too narrowly, the workload moved region or SKU family, or the workload shrank. Check scope first — it's the cheapest to fix, since scope can be changed without an exchange.

## Realized savings

What commitments have already delivered, versus on-demand rates. This is the number FinOps teams report upward, and it's distinct from _projected_ savings in a recommendation.

Sources: cost data with `pricingModel` or `benefitId` populated, compared against retail rates from the Retail Prices API (`azure-cost-management` → `references/azure-retail-prices.md`).

Report realized savings and projected savings separately and label them clearly. Blending "we saved $X" with "we could save $Y" is how a savings number loses credibility.

The FinOps multitool reports this figure as an estimate and labels it as one. It derives savings from amortized cost and an assumed discount rate rather than comparing each line against its retail rate, so treat it as an order-of-magnitude number. When you need a defensible figure, use the retail-rate comparison described above and say which method produced it.

## MACC

Microsoft Azure Consumption Commitment burn-down is documented fully in `azure-cost-management` → `references/azure-macc.md`, including the critical detail that `closedBalance` is the **remaining** balance, not the consumed amount.

Consumed is `originalAmount - closedBalance`. Reporting `closedBalance` as spend inverts the number.

## Sequencing

For a commitment review, run in this order:

1. **Utilization first.** No point recommending purchases while existing commitments sit at 60%.
2. **Coverage second.** How much on-demand usage is uncovered? That's the actual opportunity size.
3. **Recommendations third.** De-duplicated, with term treated as a choice rather than a sum.
4. **Realized savings last.** Establishes credibility for the recommendation that precedes it.

Leading with purchase recommendations before checking utilization is the most common way a commitment conversation goes wrong.

## Related

- `rate-optimization-portfolio` for portfolio mix and purchase planning
- `unit-economics` for effective savings rate and coverage KPIs
- `azure-cost-management` → `references/azure-commitment-discount-decision.md` for reservations vs savings plans
