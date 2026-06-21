---
description: Autonomous month-over-month cost analysis with anomaly detection, forecasting, and actionable recommendations.
---

# Instructions

Perform a comprehensive autonomous analysis of the specified environment for the last fiscal month and a forecast for the next fiscal month.
You are responsible for reviewing bundled references in `skills/finops-toolkit/references/`, managing `ftk/planning/`, and interpreting `ftk/results/`.

This is an iterative, cumulative workflow. Each run builds on previous runs — prior research, notes, and results carry forward. The analysis is intentionally open-ended: explore broadly, follow leads, and surface insights that a static report template would miss.

## 1 - Setup Phase
1. Use the current context to determine today's date.
2. Read the bundled skill references in `skills/finops-toolkit/references/` before starting new analysis.
3. Start with `skills/finops-toolkit/references/queries/INDEX.md` for validated KQL assets and `skills/finops-toolkit/references/finops-hubs.md` for hub-specific analysis guidance.
4. Review `skills/finops-toolkit/references/docs-mslearn/framework/finops-framework.md` and `skills/finops-toolkit/references/docs-mslearn/framework/capabilities.md` so your findings stay aligned to FinOps terminology, reporting, anomalies, and forecasting.

**Checkpoint:** Confirm which skill reference sources you reviewed and summarize the most relevant guidance before proceeding.

## 2 - Plan Phase
3. Plan ahead in `ftk/planning/plan-[environment-name]-report-[date].md`
4. Track progress in `ftk/planning/progress-[environment-name]-report-[date].md`
5. Save/update the report in `ftk/results/[environment-name]-report-[date].md`.
6. Do not save query results anywhere except in `ftk/results/[environment-name]-report-[date].md`.

**Checkpoint:** Present the plan and confirm it covers the right scope before executing.

## 3 - Execute Phase
7. You may encounter errors along the way which you will need to troubleshoot — check your `ftk/notes/` to avoid troubleshooting the same issue unnecessarily.
8. Check casting, syntax, and query structure. Make sure to use the correct data types and parameters for functions and tools.
9. Document issues and solutions in `ftk/notes/topic-name.md`.
10. Add new working queries you create to `skills/finops-toolkit/references/queries/catalog/query-name.kql` and update `skills/finops-toolkit/references/queries/INDEX.md` for re-use.
11. Use autonomous batch processing to handle large datasets efficiently.
12. Save your work as you go to `ftk/results/[environment-name]-report-[date].md` to avoid lost work.
13. Investigate suspicious workload patterns using `skills/finops-toolkit/references/finops-hubs.md` for anomaly, budget, and optimization context.
14. Explore material patterns beyond the obvious cost drivers, then summarize findings and stop when the report is complete or blocked.

**Checkpoint:** Update the report and summarize key findings so far before moving to reflection.

## 4 - Reflect Phase
15. Use the bundled reference guidance in `skills/finops-toolkit/references/` to interpret `ftk/results/[environment-name]-report-[date].md` and validate whether the month-over-month story is evidence-backed.
16. Make the report professional, scannable and colorful. Use charts, graphs and emojis.
17. Check your work as you go for errors and omissions. Make sure the report is complete and renders correctly.

**Remember:**
- Apply the FinOps Framework — demonstrate mastery of `skills/finops-toolkit/references/docs-mslearn/framework/finops-framework.md` and `skills/finops-toolkit/references/docs-mslearn/framework/capabilities.md`.
- Continue until the report is complete, internally consistent, and ready for FinOps review. If blocked, stop and report the exact blocker and evidence.
