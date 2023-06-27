# 📜 FinOps toolkit changelog

- [v0.0.1](#v001)

---

<!--
## Unreleased
-->

## v0.0.1

Added:

1. FinOps hubs
   1. [finops-hub template](finops-hub) to deploy a storage account and Data Factory instance.
   2. [Cost summary report](./finops-hub/reports/cost-summary.md) for various out-of-the-box cost breakdowns.
   3. [Commitment discounts report](./finops-hub/reports/commitment-discounts.md) for commitment-based discount reports.
2. Bicep modules
   1. [Scheduled action modules](bicep-registry/README.md#scheduled-actions) submitted to the Bicep Registry (pending release).
3. Azure Monitor workbooks
   1. [Cost optimization workbook](optimization-workbook) to centralize cost optimization.

<br>

## v0.0.2

Added:

1. FinOps hubs
   1. Add actuals dataset
   2. Add managed exports feature
      1. Add pipeline to automatically configure Cost Management exports for supported scopes
      2. Add pipelines to trigger Cost Management exports on schedule for supported scopes
      3. Add daily and monthly schedules for supported scopes
   3. Add historical backfill feature
      1. Add pipelines to backfill dataset based on ingestion container retention settings defined in settings.json

<br>
