---
name: Azure MACC (Microsoft Azure Consumption Commitment)
description: MACC is a contractual commitment to spend a specific amount on Azure over a defined period (typically 3-5 years). Missing the commitment results in a **shortfall charge** - an invoice for the remaining balance converted to Azure Prepayment credit.
---

## Eligibility Rules

Understanding what counts toward MACC is critical to avoid surprises.

**Counts toward MACC:**
- Direct Azure consumption billed to your account
- Azure Prepayment purchases (the purchase itself, not consumption from it)
- Azure Marketplace offers with "Azure benefit eligible" badge (100% of pretax amount)

**Does NOT count toward MACC:**
- Consumption covered by Azure Prepayment credits
- Consumption covered by shortfall credits (the trap!)
- Marketplace offers without the eligible badge
- Purchases not linked to your billing account
- Hybrid/on-premises license usage

**The shortfall trap:** If MACC is missed, the shortfall becomes Prepayment credit. Consumption against that credit does NOT count toward any future MACC commitment.

## Workflow: Assess MACC Status

### Step 1: Get Current Position

Query the Lots API for active commitments:

```bash
# List billing accounts first
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts?api-version=2020-05-01" \
  --query "value[].{Name:name, DisplayName:properties.displayName}"

# Get MACC commitments (replace <billingAccountId>)
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<billingAccountId>/providers/Microsoft.Consumption/lots?api-version=2021-05-01&\$filter=source%20eq%20%27ConsumptionCommitment%27" \
  --query "value[?properties.status=='Active'].{Original:properties.originalAmount.value, Remaining:properties.closedBalance.value, StartDate:properties.startDate, EndDate:properties.expirationDate}"
```

**Key fields:**
- `originalAmount` - Total commitment amount
- `closedBalance` - Remaining balance as of last invoice
- `purchasedDate` - When MACC was purchased
- `startDate` - When MACC became active
- `expirationDate` - Deadline
- `status` - Active, Completed, Expired, or Canceled

### Step 2: Calculate Burn Rate

Query recent decrement events:

```bash
# Get decrements for last 6 months (adjust dates)
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<billingAccountId>/providers/Microsoft.Consumption/events?api-version=2021-05-01&startDate=2024-07-01&endDate=2025-01-01&\$filter=lotsource%20eq%20%27ConsumptionCommitment%27" \
  --query "value[].{Date:properties.transactionDate, Decrement:properties.charges.value, Remaining:properties.closedBalance.value, Invoice:properties.invoiceNumber}"
```

**Event fields:**
- `transactionDate` - When event occurred
- `description` - Description of the event
- `charges` - MACC decrement amount
- `closedBalance` - Remaining balance after event
- `invoiceNumber` - Invoice that triggered the decrement
- `eventType` - SettledCharges (only type for MACC)
- `billingProfileDisplayName` - Billing profile name (MCA only)

Calculate average monthly decrement from results.

### Step 3: Assess Risk

```
Required Monthly Rate = closedBalance ÷ Months Until Expiration
Actual Monthly Rate = Sum of decrements ÷ Number of months
```

| Situation | Risk Level | Action |
|-----------|------------|--------|
| Actual > Required × 1.1 | Low | Monitor quarterly |
| Actual within ±10% of Required | Medium | Monitor monthly |
| Actual < Required × 0.9 | High | Acceleration needed |

### Step 4: Check for Milestones

Some MACCs have interim milestones with their own deadlines and shortfall penalties. Check the Azure portal: **Cost Management + Billing → Credits + Commitments → MACC → Milestones tab**.

Milestones are not exposed via API - use portal to verify.

## Accelerating MACC Burn

When behind on commitment:

1. **Accelerate planned projects** - Move deployments forward
2. **Purchase Reservations/Savings Plans** - Purchases count toward MACC
3. **Azure Marketplace** - Find "Azure benefit eligible" solutions
4. **Contact Microsoft** - Discuss commitment amendments

## Alerts

Microsoft automatically emails Billing Account Admins:
- 90 days before MACC expiration
- 60 days before MACC expiration
- 30 days before MACC expiration
- Same intervals for milestone deadlines

No configuration needed - alerts are automatic for accounts not on track.

## Prerequisites

- **EA:** Enterprise Administrator role required
- **MCA:** Owner, Contributor, or Reader on billing account
- **Direct agreements only** - Indirect (partner) agreements cannot use portal/API

## References

- [Track your MACC](https://learn.microsoft.com/azure/cost-management-billing/manage/track-consumption-commitment) - Portal and API guidance
- [MACC FAQ](https://learn.microsoft.com/marketplace/macc-frequently-asked-questions) - Marketplace eligibility details
- [Azure benefit eligible offers](https://learn.microsoft.com/marketplace/azure-consumption-commitment-benefit) - Finding eligible Marketplace solutions
- [Consumption Lots API](https://learn.microsoft.com/rest/api/consumption/lots) - API reference
- [Consumption Events API](https://learn.microsoft.com/rest/api/consumption/events) - API reference
