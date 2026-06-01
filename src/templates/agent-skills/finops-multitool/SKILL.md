---
name: finops-multitool
description: This skill should be used when the user asks to "scan for cost savings", "find orphaned resources", "find idle VMs", "check Azure Hybrid Benefit", "review tags", "tag coverage", "tag recommendations", "policy coverage", "cost by tag", "cost trend", "top resources by cost", "reservation recommendations", "commitment utilization", "realized savings", "budget status", "cost anomaly alerts", "Advisor cost recommendations", "billing structure", "contract info", or run a "FinOps assessment", "FinOps scan", or "cost optimization scan" using the FinOps Multitool MCP server. Also use it proactively whenever the conversation turns to Azure cost, waste, savings, governance, or FinOps health and a live read-only scan would answer the question.
license: MIT
compatibility: Requires the finops-multitool MCP server to be running (see .vscode/mcp.json) and an authenticated Azure session (Connect-AzAccount) with at least Reader access. All tools are read-only.
metadata:
  author: microsoft
  version: "1.0"
---

# FinOps Multitool

The FinOps Multitool MCP server exposes 22 read-only tools that scan a live Azure environment for cost savings, governance gaps, and FinOps health. Use it to ground answers about waste, savings, tags, policy, budgets, and commitments in the customer's actual resource state instead of guessing.

All tools query Azure Resource Graph, Cost Management, and Azure Advisor with **Reader** scope. They never modify resources. Be proactive: when a user raises a cost, waste, savings, or governance topic, offer to run the matching scan rather than answering abstractly.

## When to use the server

Run a scan whenever the user wants real numbers from their environment. Examples that should trigger a tool call:

- "Where am I wasting money?" → `scan_orphaned_resources`, `scan_idle_vms`, then `run_full_scan` if they want the full picture
- "Are we using reservations well?" → `scan_commitment_utilization`, `scan_reservation_advice`
- "What's our tag coverage?" → `scan_tag_inventory`
- "Break cost down by CostCenter / team / app" → `scan_cost_by_tag` (run `scan_tag_inventory` first)
- "Run a FinOps assessment" → `run_full_scan`

If the user is only asking a conceptual question ("what is Azure Hybrid Benefit?"), answer directly — don't force a scan.

## Tool routing

Pick the narrowest tool that answers the question. Use `run_full_scan` only for a broad assessment.

| Intent | Tool | Category |
|--------|------|----------|
| Orphaned disks, NICs, public IPs, NSGs, deallocated VMs | `scan_orphaned_resources` | Optimization |
| Idle / underutilized VMs (<5% CPU) | `scan_idle_vms` | Optimization |
| Storage tier optimization (Hot→Cool/Cold/Archive) | `scan_storage_tier_advice` | Optimization |
| Windows/SQL not using Azure Hybrid Benefit | `scan_ahb_opportunities` | Optimization |
| Tag coverage, tag names, untagged resources | `scan_tag_inventory` | Governance |
| Tag quality fixes (CAF gaps, casing, duplicates) | `scan_tag_recommendations` | Governance |
| Azure Policy assignments + compliance | `scan_policy_inventory` | Governance |
| Policy coverage gaps + recommended guardrails | `scan_policy_recommendations` | Governance |
| Decide hub export vs live API before a cost scan | `detect_cost_data_source` | Cost Analysis |
| Current month actual + forecast spend | `scan_cost_data` | Cost Analysis |
| Top resources by cost | `scan_resource_costs` | Cost Analysis |
| Cost broken down by tag key/value | `scan_cost_by_tag` | Cost Analysis |
| Month-over-month cost trend | `scan_cost_trend` | Cost Analysis |
| Reservation purchase recommendations | `scan_reservation_advice` | Commitments |
| Reservation / savings plan utilization | `scan_commitment_utilization` | Commitments |
| Realized savings (RI, SP, AHB) | `scan_savings_realized` | Commitments |
| Budget consumption vs thresholds | `scan_budget_status` | Monitoring |
| Cost anomaly alerts + detection rules | `scan_anomaly_alerts` | Monitoring |
| Advisor cost recommendations | `scan_optimization_advice` | Advisor |
| Billing account hierarchy (EA/MCA/CSP) | `scan_billing_structure` | Account |
| Agreement, offer, currency, support plan | `scan_contract_info` | Account |
| Full FinOps assessment across all modules | `run_full_scan` | Assessment |

## Scope: subscriptionId

Every tool takes an optional `subscriptionId`.

- **Omit it** and the tool scans **every accessible subscription**. In large tenants this can mean hundreds of subscriptions — slow, and the result is written to a file you must read back.
- **Pass it** to scope to one subscription. Prefer this when the user only has access to (or only cares about) a single subscription, or when iterating quickly.

Always confirm scope before a broad scan if the tenant is large. If the user says they only have access to one subscription, always pass that `subscriptionId`.

## Tool dependencies

Three tools depend on inventory data being gathered first. When calling them individually, run the prerequisite first:

| Tool | Run first |
|------|-----------|
| `scan_cost_by_tag` | `scan_tag_inventory` |
| `scan_tag_recommendations` | `scan_tag_inventory` |
| `scan_policy_recommendations` | `scan_policy_inventory` |

`run_full_scan` handles this chaining automatically — it gathers inventory before the dependent modules, so you don't need to sequence calls yourself when running the full assessment.

## run_full_scan

`run_full_scan` executes every module (Optimization, Governance, Cost Analysis, Commitments, Monitoring, Advisor) and returns one comprehensive object. Use the optional `modules` array to run a subset:

- Full assessment: call with no arguments (or just `subscriptionId`).
- Targeted multi-module: pass `modules` (e.g., `["scan_cost_by_tag"]`) to run only those, with dependencies resolved automatically.

Prefer individual tools for a single question — `run_full_scan` is heavier and returns a large payload.

## Reading results

Tool output is JSON. Large results (tag inventory, full scans) are written to a file and the tool returns the file path — read that file to get the data. Each result includes a `permission` block (`role`, `scope`, `api`) confirming the read-only access path used.

When summarizing for the user:

- Lead with the headline number (count, total savings, coverage %).
- Group findings by impact (High/Medium/Low) when the data provides it.
- Translate raw findings into action (e.g., "3 deallocated VMs — the disks keep billing; delete if unused").
- Surface the cost driver, not just the inventory.

## Interpreting common results

- **`scan_cost_by_tag` returns `NoTagsFound` but resources are tagged.** The tag exists on resources but isn't appearing in cost data. Two usual causes: (1) the tag isn't enabled as a **cost-allocation dimension** in Cost Management settings, or (2) **month-to-date lag** — tag-dimensioned cost data hasn't populated yet. Run `scan_tag_inventory` to confirm the tag is applied, then advise enabling tag-based cost allocation.
- **Deallocated VMs in `scan_orphaned_resources`.** Compute isn't billing, but attached managed disks and static public IPs still are. Recommend deleting if truly unused.
- **Low tag coverage in `scan_tag_inventory`.** Pair with `scan_tag_recommendations` to flag casing/duplicate issues (e.g., `managed_by` vs `managedBy`) and missing CAF-standard tags.
- **Empty cost results early in the month.** Cost Management data lags; note this rather than reporting "$0".

## FinOps skill ecosystem

The multitool is the data engine. Once a scan surfaces a finding, hand off to the skill that turns it into a decision, a design, or an artifact. Treat this as the routing hub for the wider FinOps practice:

| After this scan / question | Hand off to | For |
|----------------------------|-------------|-----|
| Any spend question (`scan_cost_data`, `scan_resource_costs`, `scan_cost_by_tag`) | `cost-data-source` | Choose the fast hub export vs the live API, warn before slow scans, chunk large tenants |
| `scan_tag_inventory`, `scan_cost_by_tag` | `cost-allocation` | Showback/chargeback model, shared-cost splitting, tag strategy |
| `scan_tag_recommendations`, `scan_policy_recommendations` | `azure-policy-governance` | Enforce tags/regions/SKUs via Azure Policy (Bicep/ARM) |
| `scan_policy_inventory` results | `azure-workbooks-finops` | Live in-portal Governance/Optimization workbooks |
| `scan_cost_trend`, `scan_resource_costs` | `power-bi-finops` | Dashboards and visuals on cost data |
| `scan_savings_realized`, `scan_commitment_utilization` | `unit-economics` | ESR, cost-per-unit, coverage/utilization KPIs |
| `scan_reservation_advice`, `scan_ahb_opportunities` | `rate-optimization-portfolio` | RI/SP/AHB portfolio mix and purchase planning |
| `scan_budget_status`, `scan_cost_data` | `forecasting-budgeting` | Forecasts, budget design, variance analysis |
| `scan_anomaly_alerts` | `anomaly-investigation` | Root-cause a spike down to the resource/change |
| `scan_orphaned_resources`, `scan_idle_vms` | `sustainability-carbon` | Carbon co-benefit of removing waste |
| Any deep KQL / FinOps hub query | `finops-toolkit` | Kusto analytics on the Hub database |
| Single-instrument commitment mechanics | `azure-cost-management` | Reservations, savings plans, budgets, exports detail |
| Cost data looks wrong/incomplete | `focus-data-quality` | FOCUS conformance, completeness, mapping |
| Any finding the user wants written up | `finops-reporting` | Exec summaries, QBRs, variance narratives |

Run the scan first to ground the numbers, then route to the matching skill — don't answer governance, allocation, or reporting questions abstractly when a scan can provide the real state.

## Prerequisites

- The `finops-multitool` MCP server must be running. It's defined in `.vscode/mcp.json` and started via the MCP server list in VS Code.
- An authenticated Azure session is required (`Connect-AzAccount`). Tools fail or hang without it.
- Access is read-only (Reader). The skill never deploys, modifies, or deletes anything — recommendations are advisory.
