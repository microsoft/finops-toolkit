# 📜 FinOps toolkit changelog

- [v0.0.2](#v002)
- [v0.0.1](#v001)

---

<!--
## Unreleased
-->
## v0.0.2

Added:

1. FinOps hubs
   1. Support for actual (billed) cost data.
   2. Add managed exports feature
   3. Backfill historical cost data to streamline first-time setup.

<br>

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
