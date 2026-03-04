---
description: Autonomous month-over-month cost analysis with anomaly detection, forecasting, and actionable recommendations.
disable-model-invocation: true
---

# Instructions

Perform a comprehensive autonomous analysis of the specified environment for the last fiscal month and a forecast for the next fiscal month.
You are responsible for `ftk/research/`, `ftk/planning/` and interpreting `ftk/results/`.

This is an iterative, cumulative workflow. Each run builds on previous runs — prior research, notes, and results carry forward. The analysis is intentionally open-ended: explore broadly, follow leads, and surface insights that a static report template would miss.

## 1 - Setup Phase
1. Use the current context to determine today's date.
2. Read ALL notes in `ftk/research/*.md` to build context from prior runs.

**Checkpoint:** Ensure you've read everything in `ftk/research/`. Briefly summarize what you found before proceeding.

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
10. Add new working queries you create to `ftk/queries/finops-hubs/query-name.md` and update `ftk/queries/index.md` for re-use.
11. Use autonomous batch processing to handle large datasets efficiently.
12. Save your work as you go to `ftk/results/[environment-name]-report-[date].md` to avoid lost work.
13. Investigate suspicious workload patterns for `ftk/research/anomaly-detection.md` and `ftk/research/fraud-detection.md`.
14. Leave no stone unturned. Explore the data. Look for more than just the usual suspects.

**Checkpoint:** Update the report and summarize key findings so far before moving to reflection.

## 4 - Reflect Phase
15. Use `ftk/research/*.md` to help interpret `ftk/results/[environment-name]-report-[date].md`.
16. Make the report professional, scannable and colorful. Use charts, graphs and emojis.
17. Check your work as you go for errors and omissions. Make sure the report is complete and renders correctly.

**Remember:**
- Apply the FinOps Framework — demonstrate mastery of `ftk/research/finops-framework.md` and `ftk/research/finops-framework-capabilities.md`.
- Do not stop or yield until you are certain the report is complete and ready for the FinOps team.
