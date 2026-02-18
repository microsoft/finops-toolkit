---
name: azure-cost-management
description: This skill should be used when the user asks about "Azure Advisor", "cost recommendations", "savings plans", "reservations", "reserved instances", "RI", "Azure budgets", "cost exports", "anomaly alerts", "MACC", "Azure credits", "Azure Prepayment", "commitment discounts", "cost optimization", "reservations vs savings plans", "which commitment discount", or any Azure Cost Management operations.
license: MIT
compatibility: Requires Azure CLI authentication (az login) and appropriate RBAC permissions for Cost Management APIs.
metadata:
  author: microsoft
  version: "1.0"
---

# Azure Cost Management

Azure Cost Management and optimization skills. Provides recommendations, budget management, exports, alerts, and commitment tracking capabilities.

## Domain Knowledge

| Domain | Purpose | Key Operations |
|--------|---------|----------------|
| **azure-advisor** | Cost recommendations | Query, suppress, manage recommendations |
| **azure-savings-plans** | Savings plan analysis | Benefit recommendations, coverage, ROI |
| **azure-budgets** | Budget management | Create budgets, notifications, action groups |
| **azure-cost-exports** | Scheduled exports | FOCUS exports, backfill, troubleshooting |
| **azure-anomaly-alerts** | Cost anomaly detection | Bulk alert deployment across subscriptions |
| **azure-reservations** | Reserved instance analysis | Reservation recommendations, utilization, coverage, exchange/return |
| **azure-commitment-discount-decision** | Commitment discount framework | Reservations vs savings plans decision criteria, hybrid strategy |
| **azure-credits** | Credit tracking | Azure Prepayment balance, expiration risk |
| **azure-macc** | MACC commitment tracking | Balance, decrements, milestone tracking |

## Cost Optimization

### Azure Advisor Recommendations

```bash
az advisor recommendation list --category Cost --output table
```

**Suppression:** Up to 90-day TTL, bulk suppression via management groups.

For detailed documentation: `references/azure-advisor.md`

### Savings plans and reservations

**Benefit Recommendations API** for:
- Savings plan purchase recommendations (up to 65% savings)
- Reservation recommendations (up to 72% savings)
- Coverage analysis and utilization monitoring
- Decision framework: when to use which commitment type

For detailed documentation:
- `references/azure-savings-plans.md` — savings plan analysis and script
- `references/azure-reservations.md` — reserved instance analysis
- `references/azure-commitment-discount-decision.md` — decision framework

## Budget & Alerts

### Budgets

- Up to 5 notifications per budget
- Action Groups at Subscription/Resource Group scope only
- Threshold types: Actual, Forecasted

```bash
az consumption budget list --output table
```

For detailed documentation: `references/azure-budgets.md`

### Anomaly Alerts

Enterprise-scale deployment with pagination for large environments.

For detailed documentation: `references/azure-anomaly-alerts.md`

### Cost Exports

FOCUS format exports to storage accounts with backfill support.

For detailed documentation: `references/azure-cost-exports.md`

## Commitment Tracking

### Azure Credits (Prepayment)

Track EA/MCA credit balances, expiration dates, consumption history.

For detailed documentation: `references/azure-credits.md`

### MACC (Azure Consumption Commitment)

Track MACC balance, decrements, milestone progress, eligible spend.

For detailed documentation: `references/azure-macc.md`

## Reference documentation

- **Optimization**: `references/azure-advisor.md`, `references/azure-savings-plans.md`, `references/azure-reservations.md`
- **Decision framework**: `references/azure-commitment-discount-decision.md`
- **Budgets and alerts**: `references/azure-budgets.md`, `references/azure-anomaly-alerts.md`, `references/azure-cost-exports.md`
- **Commitments**: `references/azure-credits.md`, `references/azure-macc.md`
Load the appropriate reference file when detailed workflows, API examples, or troubleshooting are needed.
