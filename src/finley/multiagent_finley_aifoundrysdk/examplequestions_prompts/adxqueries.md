# 💰 AI Cost Explorer – Example Queries & Output

---

## 💡 Example Query 1: Top 5 Services by Daily Cost in the Last 7 Days

### 🔍 KQL Query
```kql
let DailyCosts = Costs_v1_0
    | where ChargePeriodStart >= ago(7d)
    | summarize TotalCost = sum(EffectiveCost) by bin(ChargePeriodStart, 1d), ServiceName
    | extend ChargePeriodStart = format_datetime(ChargePeriodStart, 'yyyy-MM-dd')
    | project ChargePeriodStart, ServiceName, TotalCost
    | order by TotalCost desc
    | top 5 by TotalCost;
DailyCosts
```
### 📊 Output
| ChargePeriodStart |  ServiceName |  TotalCost| 
|-----------------|----------------|---------------------------|
| 2025-03-28	| Storage Accounts| 	15.2454991409424368| 
| 2025-03-31	| Storage Accounts| 	15.240916704413689086| 
| 2025-03-30	| Storage Accounts| 	15.239584485482731692| 
| 2025-03-29	| Storage Accounts| 	15.237518518568097531| 
| 2025-04-01 | 	Storage Accounts| 	15.057558938548348978| 
---

# 💰 AI Cost Explorer – Question Examples & Output
## ❓ Question 1

**Q:** Give me a summary table of the consumption for **AI and Machine Learning** service category of this month and list the resources by name based on aggregated cost by subscription name.


### 📊 Output
✅ **ADX query successful** — Returned 2 rows.

| BillingCurrency | EffectiveCost | ResourceName             | SubAccountName                        |
|-----------------|----------------|---------------------------|----------------------------------------|
| USD             | 4.92008385     | ai-adminai3148890574496362 | ME-MngEnvMCAP149877-jachahbar-1       |
| USD             | 8e-07          | admin-8320                | ME-MngEnvMCAP149877-jachahbar-1       |

---

## ❓ Follow-up Question 1

**Q:** Give me a detailed breakdown of the costs for this resource: `ai-adminai3148890574496362` with all the meters based on the usage of last 7 days, per day please.


### 📊 Output
✅ **ADX query successful** — Returned 18 rows.

| BillingCurrency | DailyCost   | Day        | x_SkuMeterName                         |
|-----------------|-------------|------------|----------------------------------------|
| USD             | 2.33786     | 2025-03-28 | gpt 4o 0513 Input global Tokens        |
| USD             | 0.82083     | 2025-03-28 | gpt 4o 0513 Output global Tokens       |
| USD             | 0.001125    | 2025-03-28 | Standard Text Records                  |
| USD             | 1.01958     | 2025-03-29 | gpt 4o 0513 Output global Tokens       |
| USD             | 3.91811     | 2025-03-29 | gpt 4o 0513 Input global Tokens        |
| USD             | 3.36831     | 2025-03-30 | gpt 4o 0513 Input global Tokens        |
| USD             | 0.91419     | 2025-03-30 | gpt 4o 0513 Output global Tokens       |
| USD             | 1.869315    | 2025-03-31 | gpt 4o 0513 Output global Tokens       |
| USD             | 8.301505    | 2025-03-31 | gpt 4o 0513 Input global Tokens        |
| USD             | 0.0221184   | 2025-04-01 | R1 Outp glbl Tokens                    |
| USD             | 3.52415     | 2025-04-01 | gpt 4o 0513 Input global Tokens        |
| USD             | 0.00207345  | 2025-04-01 | gpt-4o-mini-0718-Inp-glbl Tokens       |
| USD             | 0.0013644   | 2025-04-01 | gpt-4o-mini-0718-Outp-glbl Tokens      |
| USD             | 1.026495    | 2025-04-01 | gpt 4o 0513 Output global Tokens       |
| USD             | 0.0005076   | 2025-04-01 | R1 Inp glbl Tokens                     |
| USD             | 0.0015      | 2025-04-01 | Standard Text Records                  |
| USD             | 0.27478     | 2025-04-02 | gpt 4o 0513 Input global Tokens        |
| USD             | 0.067095    | 2025-04-02 | gpt 4o 0513 Output global Tokens       |

---
