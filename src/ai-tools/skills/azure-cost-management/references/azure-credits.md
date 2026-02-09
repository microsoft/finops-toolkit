---
name: Azure Credits (Prepayment)
description: Azure Prepayment (formerly Monetary Commitment) provides prepaid funds that cover eligible Azure services. Credits have **expiration dates** - unused credits are lost. Credits may also be granted via promotions or strategic investments.
---

**Key distinction from MACC:**
- **Azure Prepayment**: Prepaid credits covering eligible services - consumption covered by prepayment does NOT count toward MACC
- **MACC**: Contractual commitment tracking total consumption

## How Credits Are Applied

Credits are automatically applied to eligible charges when an invoice is generated. The remaining balance after credits is paid via other payment methods.

**Products NOT covered by credits:**
- Azure Marketplace products
- Azure support plans
- Canonical, Citrix XenApp/XenDesktop
- Visual Studio subscriptions (Monthly/Annual)
- Ubuntu Advantage

## Workflow: Assess Credit Health

### Step 1: Identify Agreement Type

EA and MCA use different APIs. Check agreement type first:

```bash
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts?api-version=2020-05-01" \
  --query "value[].{Name:name, Type:properties.agreementType}"
```

### Step 2: Get Current Balance

**For EA:**
```bash
CURRENT_PERIOD=$(date +%Y%m)
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<billingAccountId>/billingPeriods/${CURRENT_PERIOD}/providers/Microsoft.Consumption/balances?api-version=2024-08-01" \
  --query "{Beginning:properties.beginningBalance, Ending:properties.endingBalance, Utilized:properties.utilized, Overage:properties.serviceOverage}"
```

**For MCA:**
```bash
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<billingAccountId>/billingProfiles/<billingProfileId>/providers/Microsoft.Consumption/lots?api-version=2023-03-01" \
  --query "value[?properties.status=='Active'].{Source:properties.source, Original:properties.originalAmount.value, Remaining:properties.closedBalance.value, Expires:properties.expirationDate}"
```

### Step 3: Check Expiration Risk

Query credits expiring in next 90 days:

```bash
# MCA - find expiring credits
NINETY_DAYS=$(date -v+90d +%Y-%m-%d)  # macOS
# NINETY_DAYS=$(date -d "+90 days" +%Y-%m-%d)  # Linux

az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<billingAccountId>/billingProfiles/<billingProfileId>/providers/Microsoft.Consumption/lots?api-version=2023-03-01" \
  --query "value[?properties.status=='Active'].{Source:properties.source, Balance:properties.closedBalance.value, Expires:properties.expirationDate}" | \
  jq --arg date "$NINETY_DAYS" '[.[] | select(.Expires <= $date)]'
```

### Step 4: Assess Risk Level

| Situation | Risk | Action |
|-----------|------|--------|
| No credits expiring in 90 days | Low | Monitor quarterly |
| Credits expiring, balance < monthly consumption | Low | Will be consumed naturally |
| Credits expiring, balance > monthly consumption | High | Accelerate consumption or lose credits |
| Credits already expired | Loss | Review for future prevention |

## EA Balance API

Query balance for a specific billing period (YYYYMM format):

```bash
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<billingAccountId>/billingPeriods/<YYYYMM>/providers/Microsoft.Consumption/balances?api-version=2024-08-01"
```

**Response fields:**

| Field | Description |
|-------|-------------|
| `beginningBalance` | Starting Azure Prepayment balance for the month |
| `endingBalance` | Remaining balance (updated daily for open periods) |
| `newPurchases` | New Azure Prepayment purchases during month |
| `adjustments` | Total adjustment amount |
| `adjustmentDetails[]` | Array of credit types and amounts |
| `utilized` | Amount of Azure Prepayment consumed |
| `serviceOverage` | Overage for Azure services |
| `chargesBilledSeparately` | Charges billed separately from Prepayment |
| `azureMarketplaceServiceCharges` | Total Marketplace charges |
| `currency` | ISO currency code (e.g., USD) |

**Credit types in adjustmentDetails:**

| Credit Type | Description |
|-------------|-------------|
| `Promo Credit` | Promotional credits |
| `Strategic Investment Credit` | Microsoft investment credits |
| `Billing Correction Credit` | Billing adjustments |
| `Reservations - Exchange Credit` | RI exchange credits |

## MCA Credit Lots API

Query credit lots for a billing profile:

```bash
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<billingAccountId>/billingProfiles/<billingProfileId>/providers/Microsoft.Consumption/lots?api-version=2023-03-01"
```

**Response fields:**

| Field | Description |
|-------|-------------|
| `originalAmount` | Original credit amount |
| `closedBalance` | Remaining credit balance (as of last invoice) |
| `source` | Credit source (e.g., "Azure Promotional Credit") |
| `startDate` | When credit became active |
| `expirationDate` | When credit expires |
| `poNumber` | PO number of invoice where credit was billed |

## MCA Credit Events API

Query credit transactions over time:

```bash
az rest --method GET \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<billingAccountId>/billingProfiles/<billingProfileId>/providers/Microsoft.Consumption/events?api-version=2023-03-01&startDate=YYYY-MM-DD&endDate=YYYY-MM-DD"
```

**Response fields:**

| Field | Description |
|-------|-------------|
| `transactionDate` | When transaction occurred |
| `description` | Description of the transaction |
| `newCredit` | New credits added |
| `adjustments` | Credit adjustments |
| `creditExpired` | Credits that expired |
| `charges` | Charges applied against credits |
| `closedBalance` | Balance after transaction |
| `eventType` | PendingCharges, SettledCharges, PendingNewCredit, etc. |
| `invoiceNumber` | Invoice number (empty for pending) |

## Important Notes

1. **EA vs MCA**: Query patterns differ significantly - verify agreement type first
2. **Billing period format**: EA uses YYYYMM (e.g., 202207 for July 2022)
3. **Credit expiration**: Unused credits expire and cannot be recovered
4. **Overage**: When credits exhausted, charges appear as `serviceOverage` (EA) or standard invoiced charges (MCA)
5. **Permissions**: Requires billing account reader or billing profile reader role

## References

- [View Azure credits balance (EA)](https://learn.microsoft.com/azure/cost-management-billing/manage/ea-portal-enrollment-invoices#view-enrollment-credit-balance)
- [Track Azure credit balance (MCA)](https://learn.microsoft.com/azure/cost-management-billing/manage/mca-check-azure-credits-balance)
- [Consumption Balances API](https://learn.microsoft.com/rest/api/consumption/balances)
- [Consumption Lots API](https://learn.microsoft.com/rest/api/consumption/lots)
