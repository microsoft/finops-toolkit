# Azure Cost Management skill

Cost optimization and financial governance for Azure. Provides domain knowledge for Azure Advisor recommendations, commitment discounts (savings plans and reservations), budgets, cost exports, anomaly alerts, credits, and MACC tracking.

## When this skill activates

Triggered when you ask about: Azure Advisor, cost recommendations, savings plans, reservations, Azure budgets, cost exports, anomaly alerts, MACC, Azure credits, Azure Prepayment, commitment discounts, or cost optimization.

## Prerequisites

- Azure CLI authenticated (`az login`)
- Appropriate RBAC permissions for Cost Management APIs

## Domains

| Domain | Purpose | Key operations |
|--------|---------|----------------|
| **Azure Advisor** | Cost recommendations | Query, suppress, and manage recommendations (up to 90-day TTL suppression, bulk via management groups) |
| **Savings plans and reservations** | Commitment discount analysis | Benefit recommendations, coverage analysis, ROI calculations |
| **Budgets** | Budget management | Create budgets with up to 5 notifications, actual/forecasted thresholds, action groups |
| **Cost exports** | Scheduled data exports | FOCUS format exports to storage accounts with backfill support |
| **Anomaly alerts** | Cost spike detection | Enterprise-scale anomaly alert deployment with pagination |
| **Credits** | Azure Prepayment tracking | EA/MCA credit balances, expiration dates, consumption history |
| **MACC** | Consumption commitment tracking | Balance, decrements, milestone progress, eligible spend |

## Reference documentation

Each domain has a detailed reference file loaded on demand:

| File | Contents |
|------|----------|
| `references/azure-advisor.md` | Recommendation queries, suppression workflows, management group bulk operations |
| `references/azure-savings-plans.md` | Benefit Recommendations API, savings plan vs reservation comparison, coverage analysis |
| `references/azure-budgets.md` | Budget creation, notification thresholds, action group integration |
| `references/azure-cost-exports.md` | FOCUS export configuration, backfill procedures, troubleshooting |
| `references/azure-anomaly-alerts.md` | Bulk anomaly alert deployment across subscriptions |
| `references/azure-credits.md` | EA/MCA credit balance tracking, expiration risk assessment |
| `references/azure-macc.md` | MACC balance monitoring, decrement tracking, milestone progress |

## Quick examples

```bash
# List cost recommendations
az advisor recommendation list --category Cost --output table

# List budgets
az consumption budget list --output table
```
