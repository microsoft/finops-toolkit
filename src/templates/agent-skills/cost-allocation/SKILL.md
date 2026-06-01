---
name: cost-allocation
description: Use when the user wants to design showback or chargeback, allocate shared costs, build a tagging strategy for cost accountability, map spend to teams/products/cost centers, split shared platform costs, or model a financial hierarchy from billing and tag data.
license: MIT
compatibility: Requires read access to cost data (Cost Management scope or a FinOps hub) and resource tags. Pairs with the finops-multitool MCP server (tag and cost-by-tag scans) and the azure-policy-governance skill for enforcement.
metadata:
  author: microsoft
  version: "1.0"
---

# Cost allocation

Allocate Azure cost to the teams, products, and cost centers that own it — the foundation of showback and chargeback. This skill covers tag strategy, shared-cost splitting, financial hierarchy mapping, and allocation readiness.

## When to use this skill

Use it when the user mentions showback, chargeback, allocation, cost centers, "who owns this spend", splitting shared costs, or building a tag strategy for accountability. For raw tag coverage numbers, run the `finops-multitool` scans first (`scan_tag_inventory`, `scan_tag_recommendations`, `scan_cost_by_tag`) and bring the results here to design the model.

## Allocation readiness checklist

1. **Coverage** — what % of cost carries the allocation tag(s)? Below ~95% means material spend is unallocated. Use `scan_tag_inventory`.
2. **Consistency** — no casing or spelling drift in tag keys/values (`CostCenter` vs `costcenter`, `managed_by` vs `managedBy`). Use `scan_tag_recommendations`.
3. **Cost dimension** — the allocation tag must be enabled as a cost-allocation dimension in Cost Management, or tag-dimensioned cost data will be empty even when the tags exist.
4. **Inheritance** — resources that can't be tagged directly (or are missed) should inherit from the resource group via Azure Policy. See the `azure-policy-governance` skill.

## Tagging strategy

Anchor on the Cloud Adoption Framework resource-tagging standard. The seven CAF-aligned tags map cleanly to allocation:

| Tag | Allocation role |
|-----|-----------------|
| `CostCenter` | Primary chargeback dimension (finance ledger) |
| `BusinessUnit` | Org rollup |
| `ApplicationName` / `WorkloadName` | Product / service showback |
| `OpsTeam` | Operational ownership |
| `Criticality` | Prioritization, not allocation |
| `DataClassification` | Compliance, not allocation |

Reference: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging

Pick **one** authoritative allocation key (usually `CostCenter`) and enforce it everywhere; use the others for rollup and filtering.

## Shared cost splitting

Costs that no single team owns (shared platform, networking, management tooling, support, marketplace, unallocated remainder) must be distributed. Choose a split method per shared pool:

| Method | How | Use when |
|--------|-----|----------|
| **Proportional** | Split in ratio to each team's direct/allocated cost | Default; "you pay for shared services in proportion to what you use" |
| **Even** | Equal share across N teams | Small, fixed set of consumers |
| **Fixed / manual** | Hard-coded percentages | Contractual or negotiated splits |
| **Usage-based** | Split by a usage metric (vCPU-hours, GB, requests) | A real consumption signal exists |

Document the rule, the source pool, and the target dimension so the allocation is reproducible and auditable.

## Financial hierarchy

Map raw billing + tags into a reporting hierarchy: **Billing account → Billing profile / EA enrollment → Invoice section / department → Subscription → Resource group → Tag (CostCenter / App)**. In FinOps hub data, the `cost-by-financial-hierarchy.kql` catalog query (see the `finops-toolkit` skill) already produces this shape — start there rather than rebuilding it.

## Showback vs chargeback

- **Showback** — report allocated cost to each team for visibility; no money moves. Start here.
- **Chargeback** — actually bill teams' budgets. Only attempt once coverage is high, splits are agreed, and the data is trusted, or it will erode trust on day one.

## Hand-offs

- Tag coverage / drift numbers → `finops-multitool` MCP tools.
- Enforce tags and inheritance → `azure-policy-governance` skill.
- Visualize allocation → `power-bi-finops` skill (governance / cost-summary reports).
- Express allocation efficiency as KPIs → `unit-economics` skill.
