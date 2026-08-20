---
name: finops-multitool
description: This skill should be used when the user asks to "scan for cost savings", "find orphaned resources", "find idle VMs", "check Azure Hybrid Benefit", "review tags", "tag coverage", "tag recommendations", "policy coverage", "cost by tag", "cost trend", "top resources by cost", "reservation recommendations", "commitment utilization", "realized savings", "budget status", "cost anomaly alerts", "Advisor cost recommendations", "billing structure", "contract info", or run a "FinOps assessment", "FinOps scan", or "cost optimization scan". Also use it proactively whenever the conversation turns to Azure cost, waste, savings, governance, or FinOps health and live data would answer the question better than a general explanation.
license: MIT
compatibility: Requires an authenticated Azure session (az login, or Connect-AzAccount for PowerShell) with at least Reader access on the target scope. Everything in this skill is read-only. Remediation is deliberately out of scope - use the FinOps multitool terminal UI (Start-FinOpsMultitool, from the FinOpsToolkit PowerShell module) which gates every write behind a preview and confirmation.
metadata:
  author: microsoft
  version: '2.0'
allowed-tools: az pwsh
---

# FinOps multitool

This is the routing hub for FinOps investigations. It answers "what should I look at next" rather than "how do I call this API" - it decides which investigation fits the question, tells you how to gather the data, warns you where the raw numbers mislead, and hands off to the skill that turns a finding into a decision.

Two ways to gather the data:

- **Interactively** - `Start-FinOpsMultitool` launches a terminal UI that runs 30 read-only scan modules, renders the results, and exports them. Best when a person wants the full picture, and the only supported path for remediation.
- **Directly** - query Azure Resource Graph, Cost Management, Advisor, Monitor, or a FinOps hub yourself with `az` or an Azure MCP server. Best when answering one question inside a conversation. This skill carries the queries and the interpretation rules.

Prefer the direct path for a single question. Suggest the terminal UI when the user wants a full assessment or intends to act on the findings.

## Always confirm scope first

Findings are worthless if they came from the wrong tenant. Before reporting anything:

```bash
az account show --query "{tenant:tenantId, subscription:name, id:id}" -o json
az account list --query "length(@)" -o tsv
```

Many accounts can see several tenants and hundreds of subscriptions while queries run against only the active one. State the tenant and subscription you scanned, and confirm it's the intended scope before the user acts on the numbers.

Scope every query explicitly when the user only cares about one subscription. An unscoped tenant-wide scan across hundreds of subscriptions is slow and usually not what was asked for.

## Investigation routing

| Question                                      | Investigation                        | Where the detail lives                                         |
| --------------------------------------------- | ------------------------------------ | -------------------------------------------------------------- |
| Where am I wasting money?                     | Orphaned resources, then idle VMs    | [references/waste-detection.md](references/waste-detection.md) |
| Are stopped VMs still costing me?             | Orphaned resources                   | [references/waste-detection.md](references/waste-detection.md) |
| Should I move storage to a cooler tier?       | Storage tier analysis                | [references/waste-detection.md](references/waste-detection.md) |
| Am I paying for Windows/SQL licenses twice?   | Azure Hybrid Benefit eligibility     | [references/waste-detection.md](references/waste-detection.md) |
| What's our tag coverage?                      | Tag inventory, then tag quality      | [references/tags-and-policy.md](references/tags-and-policy.md) |
| Are we governed? What guardrails are missing? | Policy inventory, then coverage gaps | [references/tags-and-policy.md](references/tags-and-policy.md) |
| Should we buy reservations or savings plans?  | Purchase recommendations             | [references/commitments.md](references/commitments.md)         |
| Are we using what we already bought?          | Commitment utilization               | [references/commitments.md](references/commitments.md)         |
| What have commitments actually saved us?      | Realized savings                     | [references/commitments.md](references/commitments.md)         |
| How is our MACC tracking?                     | Consumption commitment burn-down     | `azure-cost-management` → `references/azure-macc.md`           |
| What are we spending? What's the forecast?    | Cost summary and trend               | [references/cost-analysis.md](references/cost-analysis.md)     |
| Which resources cost the most?                | Resource cost ranking                | [references/cost-analysis.md](references/cost-analysis.md)     |
| Split cost by team / app / cost center        | Cost by tag                          | [references/cost-analysis.md](references/cost-analysis.md)     |
| Why did cost spike?                           | Anomaly root cause                   | `anomaly-investigation` skill                                  |
| Are we on budget?                             | Budget status and history            | `forecasting-budgeting` skill                                  |
| Advisor cost recommendations                  | Advisor query                        | `azure-cost-management` → `references/azure-advisor.md`        |
| Split shared platform cost across teams       | Allocation modelling                 | `cost-allocation` skill                                        |
| What's our carbon footprint?                  | Emissions and waste co-benefit       | `sustainability-carbon` skill                                  |

When `azure-cost-management` already documents an API, use it rather than duplicating the call here. This skill adds the sequencing and interpretation on top.

## Interpreting common results

This is the part raw API output gets wrong. Apply these before reporting a number.

- **Deallocated VMs are still costing money.** Compute stops billing when a VM is deallocated, but attached managed disks and static public IPs keep billing. A "stopped" VM is a finding, not a resolved item. Report the disk and IP cost, and recommend deleting if the VM is genuinely unused.
- **Advisor repeats reservation recommendations.** Advisor commonly returns the same purchase 3-6 times across overlapping scopes. Summing them inflates the savings estimate several-fold. De-duplicate on subscription + resource type + term + SKU + region + quantity before totalling. See [references/commitments.md](references/commitments.md).
- **Cost by tag returns nothing although resources are tagged.** Two usual causes: the tag isn't enabled as a **cost-allocation dimension** in Cost Management settings, or **month-to-date lag** means tag-dimensioned data hasn't populated. Confirm the tag is applied to resources first, then advise enabling tag-based cost allocation.
- **Empty cost results early in the month.** Cost Management data lags by a day or more. Say so rather than reporting "$0".
- **Azure Hybrid Benefit uses a different marker per resource type.** `Windows_Server` on Windows VMs, `AHUB` on SQL Server VMs, `BasePrice` on SQL Database and Managed Instance. Checking only the first will miss most of the estate and overstate the opportunity.
- **Low tag coverage is usually a naming problem.** Before reporting a coverage percentage, check for casing and separator variants of the same tag (`managed_by` vs `managedBy` vs `ManagedBy`). They fragment coverage and each looks like a distinct tag.

## Reading results

- Lead with the headline number - count, total savings, coverage percentage.
- Group findings by impact when the data supports it.
- Translate inventory into action: "3 deallocated VMs, disks still billing, delete if unused" beats "3 deallocated VMs".
- Surface the cost driver, not just the resource list.
- Name the scope you scanned every time.

## Remediation

This skill does not change Azure. When a finding warrants action, hand the user to `Start-FinOpsMultitool`, which previews every change, requires explicit confirmation, and records an audit trail. Recommend the change and explain the impact; let the tool apply it.

## FinOps skill ecosystem

Once an investigation surfaces a finding, hand off to the skill that turns it into a decision, a design, or an artifact:

| After finding                                  | Hand off to                   | For                                                                     |
| ---------------------------------------------- | ----------------------------- | ----------------------------------------------------------------------- |
| Any spend question against a large environment | `cost-data-source`            | Choose the FinOps hub Kusto path over the live API, chunk large tenants |
| Tag coverage or cost-by-tag results            | `cost-allocation`             | Showback/chargeback model, shared-cost splitting, tag strategy          |
| Tag or policy gaps                             | `azure-policy-governance`     | Enforce tags, regions, and SKUs via Azure Policy                        |
| Policy inventory results                       | `azure-workbooks-finops`      | Live in-portal governance and optimization workbooks                    |
| Cost trend or resource cost data               | `power-bi-finops`             | Dashboards and visuals                                                  |
| Realized savings or utilization                | `unit-economics`              | Effective savings rate, cost per unit, coverage KPIs                    |
| Reservation or Hybrid Benefit opportunities    | `rate-optimization-portfolio` | Portfolio mix and purchase planning                                     |
| Budget status                                  | `forecasting-budgeting`       | Forecasts, budget design, variance analysis                             |
| A cost spike                                   | `anomaly-investigation`       | Root-cause down to the resource and change                              |
| Waste findings                                 | `sustainability-carbon`       | Carbon co-benefit of removing waste                                     |
| Deep KQL against a FinOps hub                  | `finops-toolkit`              | Kusto analytics on the hub database                                     |
| Single-instrument API mechanics                | `azure-cost-management`       | Reservations, savings plans, budgets, exports, MACC detail              |
| Cost data looks wrong or incomplete            | `focus-data-quality`          | FOCUS conformance, completeness, mapping                                |
| A finding the user wants written up            | `finops-reporting`            | Executive summaries, QBRs, variance narratives                          |

Gather the data first so the numbers are real, then route. Don't answer governance, allocation, or reporting questions abstractly when a query can show the actual state.

## Prerequisites

- Azure authentication: `az login`, or `Connect-AzAccount` when using the terminal UI.
- **Reader** on the target scope for resource and policy investigations.
- **Cost Management Reader** for cost, budget, and anomaly investigations.
- **Billing Reader**, or Enterprise Administrator (reader) on an Enterprise Agreement, for billing account, contract, and MACC investigations.
- **Carbon Optimization Reader** for emissions data.
- The terminal UI additionally needs the `FinOpsToolkit` PowerShell module and the `Az.Accounts`, `Az.ResourceGraph`, and `Az.Storage` modules.
