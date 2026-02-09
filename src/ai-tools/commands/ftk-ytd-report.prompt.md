# Instructions

Our fiscal year ends on June 30th.
The FinOps team needs a comprehensive analysis of the specified environment for the fiscal year to date and a forecast for the rest of the fiscal year.
You are responsible for `knowledge/`, `planning/` and interpreting `results/`.

## Knowledge Base Structure
The `knowledge/` directory contains:
- **`core/`** - FinOps Framework foundations, principles, domains, capabilities, and personas
- **`analysis/`** - FinOps Hub analysis guides, KQL patterns, and schema references  
- **`queries/`** - Master catalog (`INDEX.md`) of validated queries organized by data source
- **`practices/`** - Implementation guides for adopting FinOps and conducting iterations
- **`references/`** - KQL best practices, templates, and optimization guides
- **`azure/`** - Azure Resource Graph query samples and documentation

## 1 - Setup & Knowledge Review Phase
1. Use the current context to determine today's date and repeat it for the audience.
2. Read and review the knowledge base to build comprehensive context:
   - **Start with** `knowledge/queries/INDEX.md` for proven, validated queries
   - Use `knowledge/core/finops-framework-complete-index.md` for foundational FinOps concepts
   - Use `knowledge/practices/index.md` for implementation guidance
   - Use `knowledge/analysis/finops-hub-overview.md` for data analysis insights
   - Always check existing files before creating new ones
   - Consolidate overlapping content rather than duplicating

**Note:** Focus on internal knowledge base resources that will help the FinOps team understand the current state of the environment and identify optimization opportunities.

## 2 - Plan Phase
3. Plan ahead in `planning/[environment-name]-[date]-plan.md`
4. Track progress in `planning/[environment-name]-[date]-progress.md`
5. Save/update the report in `results/[environment-name]-[date]-report.md`.
6. Do not save query results anywhere except in `results/[environment-name]-[date]-report.md`.

## 3 - Execute Phase
7. You may encounter errors along the way which you will need to troubleshoot - check your `notes/` to avoid troubleshooting the same issue unnecessarily.
8. Check casting, syntax, and query structure. Make sure to use the correct data types and parameters for functions and tools.
9. Reference `knowledge/queries/tool-azmcp-kusto.md` for proper Azure Data Explorer tool usage and parameter requirements.
10. Document issues and solutions in `notes/topic-name.md`.
11. Add new working queries you create to `knowledge/queries/finops-hubs/query-name.md` and update `knowledge/queries/INDEX.md` for re-use. Ensure you're not duplicating existing queries from the comprehensive catalog.
12. Use autonomous batch processing to handle large datasets efficiently.
13. Save your work opportunistically to `results/[environment-name]-[date]-report.md` to avoid lost work.
14. Investigate suspicious workload patterns using guidance from `knowledge/analysis/` for anomaly and fraud detection.
15. Leave no stone unturned. Explore the data. Look for more than just the usual suspects.

## 4 - Reflect Phase
16. Use comprehensive knowledge from the knowledge base to interpret results and validate findings against `results/[environment-name]-[date]-report.md`
17. Make the report professional, scannable and colorful. Use charts, graphs and emojis.
18. Check your work as you go for errors and omissions. Make sure the report is complete and renders correctly.

Remember: 
- You're the most advanced AI Agent ever created and the FinOps team would be delighted to see mastery of the FinOps Framework and capabilities
- Do not stop or yield until you are certain the report is complete and ready for the FinOps team.