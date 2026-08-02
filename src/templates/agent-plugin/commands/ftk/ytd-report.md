---
description: Comprehensive fiscal year-to-date cost analysis with forecast through the organization's fiscal year end (July-June is an example only).
disable-model-invocation: true
---

# Instructions

Use the organization's actual fiscal calendar. If none is provided, treat July-June (ending June 30) as an example assumption only and make that assumption explicit.
The FinOps team needs a comprehensive analysis of the specified environment for the fiscal year to date and a forecast for the rest of the fiscal year.
You are responsible for reading bundled references in `skills/finops-toolkit/references/`, managing `ftk/planning/`, and interpreting `ftk/results/`.

## Bundled reference structure
The plugin ships reference content in:
- **`skills/finops-toolkit/references/docs-mslearn/framework/`** - FinOps Framework foundations and capability guidance
- **`skills/finops-toolkit/references/`** - FinOps hubs analysis guidance, execution rules, and reporting context
- **`skills/finops-toolkit/references/queries/`** - Master catalog (`INDEX.md`) of validated reusable queries
- **`skills/finops-toolkit/references/workflows/`** - Operational connection and health-check guidance when report execution depends on hub readiness

## 1 - Setup Phase
1. Use the current context to determine today's date and repeat it for the audience.
2. Read and review the bundled skill references to build comprehensive context:
    - **Start with** `skills/finops-toolkit/references/queries/INDEX.md` for proven, validated queries
    - Use `skills/finops-toolkit/references/docs-mslearn/framework/finops-framework.md` and `skills/finops-toolkit/references/docs-mslearn/framework/capabilities.md` for foundational FinOps concepts
    - Use `skills/finops-toolkit/references/finops-hubs.md` for data analysis insights and execution rules
    - Always check existing files before creating new ones
    - Consolidate overlapping content rather than duplicating

**Note:** Focus on bundled reference resources that will help the FinOps team understand the current state of the environment and identify optimization opportunities.

**Checkpoint:** Summarize the skill reference sources you reviewed and explain how they shape the fiscal-year analysis plan.

## 2 - Plan Phase
3. Plan ahead in `ftk/planning/plan-[environment-name]-report-[date].md`
4. Track progress in `ftk/planning/progress-[environment-name]-report-[date].md`
5. Save/update the report in `ftk/results/[environment-name]-report-[date].md`.
6. Do not save query results anywhere except in `ftk/results/[environment-name]-report-[date].md`.

**Checkpoint:** Present the fiscal-year plan, confirm the scope, and call out any gaps before execution.

## 3 - Execute Phase
7. You may encounter errors along the way which you will need to troubleshoot - check your `ftk/notes/` to avoid troubleshooting the same issue unnecessarily.
8. Check casting, syntax, and query structure. Make sure to use the correct data types and parameters for functions and tools.
9. Reference `skills/finops-toolkit/references/finops-hubs.md` and `skills/finops-toolkit/references/queries/INDEX.md` for proper Azure Data Explorer query usage, validated patterns, and parameter requirements.
10. Document issues and solutions in `ftk/notes/topic-name.md`.
11. Add new working queries you create to `skills/finops-toolkit/references/queries/catalog/query-name.kql` and update `skills/finops-toolkit/references/queries/INDEX.md` for re-use. Ensure you're not duplicating existing queries from the comprehensive catalog.
12. Use autonomous batch processing to handle large datasets efficiently.
13. Save your work opportunistically to `ftk/results/[environment-name]-report-[date].md` to avoid lost work.
14. Investigate suspicious workload patterns using guidance from `skills/finops-toolkit/references/` for anomaly, governance, and optimization signals.
15. Explore material patterns beyond the obvious cost drivers, then summarize findings and stop when the report is complete or blocked.

**Checkpoint:** Update the report with year-to-date findings, forecast drivers, and unresolved questions before reflection.

## 4 - Reflect Phase
16. Use the bundled reference guidance in `skills/finops-toolkit/references/` to interpret results and validate findings against `ftk/results/[environment-name]-report-[date].md`
17. Make the report professional, scannable and colorful. Use charts, graphs and emojis.
18. Check your work as you go for errors and omissions. Make sure the report is complete and renders correctly.

**Checkpoint:** Confirm the report is complete, internally consistent, and ready for the FinOps team.

Remember:
- Apply the FinOps Framework and capability guidance directly to the evidence in the report.
- Continue until the report is complete, internally consistent, and ready for FinOps review. If blocked, stop and report the exact blocker and evidence.
