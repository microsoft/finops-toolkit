---
description: Comprehensive fiscal year-to-date cost analysis with forecast through end of fiscal year (June 30).
disable-model-invocation: true
---

# Instructions

Our fiscal year ends on June 30th.
The FinOps team needs a comprehensive analysis of the specified environment for the fiscal year to date and a forecast for the rest of the fiscal year.
You are responsible for `ftk/knowledge/`, `ftk/planning/` and interpreting `ftk/results/`.

## Knowledge Base Structure
The `ftk/knowledge/` directory contains:
- **`core/`** - FinOps Framework foundations and capability guidance
- **`analysis/`** - FinOps hubs analysis guidance, execution rules, and reporting context
- **`queries/`** - Master catalog (`INDEX.md`) of validated reusable queries
- **`azure/`** - Azure cost management references for anomaly, optimization, and governance context
- **`workflows/`** - Operational connection and health-check guidance when report execution depends on hub readiness

## 1 - Setup Phase
1. Use the current context to determine today's date and repeat it for the audience.
2. Read and review the knowledge base to build comprehensive context:
    - **Start with** `ftk/knowledge/queries/INDEX.md` for proven, validated queries
    - Use `ftk/knowledge/core/finops-framework.md` and `ftk/knowledge/core/capabilities.md` for foundational FinOps concepts
    - Use `ftk/knowledge/analysis/finops-hubs.md` for data analysis insights and execution rules
    - Review relevant `ftk/knowledge/azure/` references before making anomaly or optimization claims
    - Always check existing files before creating new ones
    - Consolidate overlapping content rather than duplicating

**Note:** Focus on internal knowledge base resources that will help the FinOps team understand the current state of the environment and identify optimization opportunities.

**Checkpoint:** Summarize the `ftk/knowledge/` sources you reviewed and explain how they shape the fiscal-year analysis plan.

## 2 - Plan Phase
3. Plan ahead in `ftk/planning/plan-[environment-name]-report-[date].md`
4. Track progress in `ftk/planning/progress-[environment-name]-report-[date].md`
5. Save/update the report in `ftk/results/[environment-name]-report-[date].md`.
6. Do not save query results anywhere except in `ftk/results/[environment-name]-report-[date].md`.

**Checkpoint:** Present the fiscal-year plan, confirm the scope, and call out any gaps before execution.

## 3 - Execute Phase
7. You may encounter errors along the way which you will need to troubleshoot - check your `ftk/notes/` to avoid troubleshooting the same issue unnecessarily.
8. Check casting, syntax, and query structure. Make sure to use the correct data types and parameters for functions and tools.
9. Reference `ftk/knowledge/analysis/finops-hubs.md` and `ftk/knowledge/queries/INDEX.md` for proper Azure Data Explorer query usage, validated patterns, and parameter requirements.
10. Document issues and solutions in `ftk/notes/topic-name.md`.
11. Add new working queries you create to `ftk/knowledge/queries/finops-hubs/query-name.md` and update `ftk/knowledge/queries/INDEX.md` for re-use. Ensure you're not duplicating existing queries from the comprehensive catalog.
12. Use autonomous batch processing to handle large datasets efficiently.
13. Save your work opportunistically to `ftk/results/[environment-name]-report-[date].md` to avoid lost work.
14. Investigate suspicious workload patterns using guidance from `ftk/knowledge/analysis/` and the relevant `ftk/knowledge/azure/` references for anomaly, governance, and optimization signals.
15. Leave no stone unturned. Explore the data. Look for more than just the usual suspects.

**Checkpoint:** Update the report with year-to-date findings, forecast drivers, and unresolved questions before reflection.

## 4 - Reflect Phase
16. Use comprehensive knowledge from `ftk/knowledge/` to interpret results and validate findings against `ftk/results/[environment-name]-report-[date].md`
17. Make the report professional, scannable and colorful. Use charts, graphs and emojis.
18. Check your work as you go for errors and omissions. Make sure the report is complete and renders correctly.

**Checkpoint:** Confirm the report is complete, internally consistent, and ready for the FinOps team.

Remember: 
- You're the most advanced AI Agent ever created and the FinOps team would be delighted to see mastery of the FinOps Framework and capabilities
- Do not stop or yield until you are certain the report is complete and ready for the FinOps team.
