---
name: rate-optimization-portfolio
description: Use when the user manages commitment discounts as a portfolio over time — deciding the right mix of reservations, savings plans, and Azure Hybrid Benefit, planning purchases against coverage gaps, tracking utilization and expirations, and maximizing Effective Savings Rate across the whole estate rather than one instrument at a time.
license: MIT
compatibility: Requires Cost Management read access (or a FinOps hub) for usage, recommendations, and commitment data. Purchase actions need Billing/Reservation permissions. Pairs with the finops-multitool skill and the azure-cost-management skill.
metadata:
  author: microsoft
  version: "1.0"
---

# Rate optimization portfolio

Getting the best *rate* is a portfolio problem, not a one-off purchase. This skill manages the mix of reservations, savings plans, and Azure Hybrid Benefit over time to maximize Effective Savings Rate (ESR) without over-committing.

## When to use this skill

Use it when the user asks about reservations vs savings plans, commitment strategy, coverage gaps, utilization, expirations, or "are we paying the best rate." For a single instrument's mechanics defer to the `azure-cost-management` skill (azure-reservations, azure-savings-plans, azure-commitment-discount-decision); use *this* skill for the portfolio-level view across all of them.

## The instruments

| Instrument | Discount | Flexibility | Best for |
|------------|----------|-------------|----------|
| **Reservation (RI)** | Highest | Locked to a service/family/region (some exchange) | Stable, predictable workloads on a specific SKU |
| **Savings plan** | Lower than RI | Flexible across compute services/regions | Variable compute you'll keep running but may reshape |
| **Azure Hybrid Benefit (AHB)** | Removes Windows/SQL license cost | Reassignable | Existing Windows Server / SQL with Software Assurance |
| **On-demand** | None | Total | Spiky, short-lived, or uncertain workloads |

Layer them: AHB first (license), then RIs for the stable base, then a savings plan over the flexible remainder, leaving truly variable load on-demand.

## Portfolio workflow

1. **Baseline coverage** — what % of commitment-eligible cost is already covered? (commitment utilization, `commitment-discount-utilization.kql`)
2. **Utilization** — are existing commitments fully used? Under-utilization is waste *worse than* on-demand. Fix before buying more.
3. **Gap** — the stable, uncovered base is the buy target. Size to baseline usage, not peak — you can always add, you can't easily unwind.
4. **Instrument choice** — RI for steady single-SKU base; savings plan for flexible compute; AHB for eligible Windows/SQL (ahb opportunities).
5. **Term** — 1-year for changing estates, 3-year for proven-stable workloads (higher discount, longer lock).
6. **Track expirations** — model the ESR cliff when a commitment lapses; renew or re-shape ahead of expiry.

## Key signals

| Signal | Meaning | Action |
|--------|---------|--------|
| Coverage low, utilization high | Under-committed | Buy into the stable base |
| Utilization low | Over-committed / wrong SKU | Exchange, right-size, or let lapse — don't buy more |
| ESR falling with no usage change | A commitment expired | Renew/re-shape (`anomaly-investigation`) |
| AHB-eligible VMs at full rate | Leaving license savings on the table | Apply AHB (ahb opportunities) |
| Recommendations show large net savings | Genuine gap | Validate against baseline, then commit |

## Guardrails

- Never size a commitment to peak — size to the floor of sustained usage.
- Prefer flexibility (savings plan, 1-year) when the estate is changing; take the deeper discount (RI, 3-year) only when stability is proven.
- Treat utilization as the first KPI — an unused reservation costs more than paying on-demand.

## Hand-offs

- Single-instrument mechanics / decision criteria → `azure-cost-management` skill.
- Coverage/utilization/AHB data → `finops-multitool` scans.
- Express the result as ESR / coverage KPIs → `unit-economics`.
- Recommendation breakdown from hub data → `finops-toolkit` (`reservation-recommendation-breakdown.kql`).
