---
name: sustainability-carbon
description: Use when the user wants to measure or reduce the carbon emissions of their Azure footprint — the Emissions Impact Dashboard, carbon optimization recommendations, or aligning cost optimization with sustainability goals. Treats carbon as a FinOps-adjacent efficiency dimension alongside cost.
license: MIT
compatibility: Requires access to the Microsoft Emissions Impact Dashboard / Azure carbon optimization (Reader on the relevant scope). Pairs with the finops-multitool MCP server for the cost side of the same resources.
metadata:
  author: microsoft
  version: "1.0"
---

# Sustainability and carbon

Cost and carbon are two views of the same efficiency story: idle, over-provisioned, and wasteful resources burn both money and emissions. This skill brings the carbon dimension into FinOps work.

## When to use this skill

Use it when the user mentions carbon, emissions, sustainability, ESG, green/efficient cloud, or wants to pair cost optimization with environmental impact. The waste findings from the `finops-multitool` scans are also carbon findings — surface both.

## Where the data comes from

| Tool | Provides |
|------|----------|
| **Emissions Impact Dashboard (EID)** | Scope 1/2/3 emissions for the Microsoft Cloud footprint, by service/subscription/time |
| **Azure carbon optimization** | Per-resource emissions estimates and reduction recommendations in the portal |
| **Cloud for Sustainability** | Broader org-level sustainability data model |

Reference: https://learn.microsoft.com/azure/carbon-optimization/

## Cost and carbon overlap

The same actions reduce both — lead with these because they need no trade-off:

| Action | Cost effect | Carbon effect |
|--------|-------------|---------------|
| Delete orphaned/idle resources (`scan_orphaned_resources`, `scan_idle_vms`) | ↓ spend | ↓ emissions (nothing running) |
| Rightsize over-provisioned VMs | ↓ spend | ↓ emissions (less compute) |
| Increase utilization / consolidate | ↓ unit cost | ↓ emissions per unit |
| Shut down non-prod off-hours | ↓ spend | ↓ emissions |

Where they diverge: a **low-carbon region** may cost more, and **reservations** cut cost without changing emissions (same hardware runs). Be explicit when a recommendation trades one for the other.

## Carbon-aware levers

- **Region choice** — Azure regions vary widely in carbon intensity; new workloads can prefer low-carbon regions where latency/data-residency allow.
- **Scheduling** — shift flexible/batch workloads to times or regions with cleaner energy.
- **Efficient SKUs** — newer hardware generations deliver more work per watt; pair with rightsizing.
- **Storage tiering** — cooler tiers for cold data reduce both cost and energy.

## Reporting carbon alongside cost

When the user reports cost optimization, offer the carbon co-benefit: "removing these 3 idle VMs saves ~$X/mo and ~Y kgCO₂e/mo." This strengthens the business case and ties FinOps to ESG goals. Pull the cost figure from the multitool scans and the emissions figure from EID/carbon optimization for the same resources.

## Hand-offs

- The wasteful resources (cost side) → `finops-multitool` (`scan_orphaned_resources`, `scan_idle_vms`, `scan_storage_tier_advice`).
- Express carbon-per-unit → `unit-economics` skill.
- Put cost + carbon co-benefits in a report → `finops-reporting`.
