# Knowledge file descriptions for Copilot Studio

Use these descriptions when uploading knowledge files to your Copilot Studio agent.

## schema-reference.md

Column reference for building KQL queries against Costs_v1_2(). Contains all column names, data types, usage notes, and edge cases like blank meter categories and BilledCost vs EffectiveCost divergence. Use to look up correct column names before writing queries.

## query-catalog.md

Ready-to-use KQL query templates for FinOps analysis. Covers cost breakdowns by subscription/service/region, monthly trends, anomaly detection, forecasting, savings summary, commitment utilization, and reservation recommendations. Adapt these patterns to answer cost questions.

## weekly-report-guide.md

Step-by-step workflow for producing structured weekly cost anomaly reports. Contains 7 KQL queries (totals, category summary, resource increases/decreases, commitment coverage drops, marketplace), post-processing rules for grouping and severity classification, and the final report structure.
