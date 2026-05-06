# FinOps hub developer documentation

## Data ingestion workflow

- All data is ingested into tables named "*_raw".
  - Raw tables are declared in [IngestionSetup_raw.kql](../modules/scripts/IngestionSetup_raw.kql).
  - These tables have a union schema to support multiple sources and versions.
- All data is transformed to the latest FOCUS schema using an update policy into a "*_final_vX_Y" table named after the version (for example, "1.0" = "_v1_0"). Final tables, Transform functions, and update policies are in the versioned setup files:
  - [IngestionSetup_v1_0.kql](../modules/scripts/IngestionSetup_v1_0.kql)
- Data ingestion from previous version of hubs will remain in the versioned tables.
- Data is read from versioned functions in the Hub database. See HubSetup_vX_Y.kql in the [modules/scripts folder](../modules/scripts) for details.

## Versioning strategy

- Each dataset includes a function that returns the latest version of the data (for example, "Costs()").
- Every supported version of FOCUS should have a corresponding function (for example, "Costs_v1_0").
- Each versioned function unions data from versioned tables in the Ingestion database and transforms it to that FOCUS version for back compat.
- Consumers should use the unversioned function for the latest and the versioned functions for back compat.

To add a new FOCUS version:

0. Confirm dependencies
   1. Verify Microsoft Cost Management has shipped a matching FOCUS export dataset version. The hub depends on a `focuscost_X.Y.json` schema mapping file in [Microsoft.CostManagement/Exports/schemas](../modules/Microsoft.CostManagement/Exports/schemas/).
   2. If the Cost Management export is not yet available, ship hub support as **preview** and call out the upstream dependency in the changelog and the [data model documentation](../../../../docs-mslearn/toolkit/hubs/data-model.md).
1. Add schema mapping file
   1. Create new schema mapping file for the Cost Management export dataset version in the schemas folder
   2. Add file to file upload list in [storage.bicep](../modules/storage.bicep)
2. Update ingestion database scripts
   1. Add new columns to the *_raw tables per dataset in [IngestionSetup_RawTables.kql](../modules/scripts/IngestionSetup_RawTables.kql)
   2. Save a copy of the latest version of the IngestionSetup_vX_Y.kql using the latest FOCUS version
      - If updating the same version, increment the release number (e.g., `r2`)
   3. Rename all functions, tables, and policies in the new file to the new version (leave the old as-is)
   4. Update the *_final_vX_Y tables to account for any new columns
   5. Update the *_transform_vX_Y functions to account for any new columns
   6. Update the script to delete the old update policy for the *_raw tables
   7. Confirm the new file has the update policy set to use the latest version of the transform function and final table
3. Update hub database scripts
   1. Add new FOCUS version section after the latest version section and before existing version sections
   2. Create new *_vX_Y functions per dataset that transforms older data to the new FOCUS version
   3. Update the unversioned functions to use the new *_vX_Y functions
   4. Update older versioned functions to also pull from the new *_vX_Y functions and transform to the old schema
4. Update reports and dashboards
   1. Update the storage reports to use the new columns
   2. Update the KQL reports to use the new versioned functions
   3. Update the ADX dashboard to use the new versioned functions
   4. Update the FOCUS queries in the best practices library to use the new versioned functions
5. Update open-data metadata
   1. Drop a new `FocusCost_<version>.json` file into [src/open-data/dataset-metadata](../../../open-data/dataset-metadata/).
   2. Mirror the schema details (columns, types, descriptions) from the matching Cost Management export schema so downstream consumers see consistent metadata.
6. Regenerate conformance reports
   1. Run `pwsh src/scripts/Build-FocusConformance.ps1 -Branch <FOCUS spec branch>` to refresh [docs-mslearn/focus/conformance-full-report.md](../../../../docs-mslearn/focus/conformance-full-report.md) and [conformance-summary.md](../../../../docs-mslearn/focus/conformance-summary.md).
7. Update plugin skill files
   1. Refresh the FOCUS schema and function references in the following files so plugin guidance does not go stale:
      - [src/templates/agent-skills/finops-toolkit/references/finops-hubs.md](../../agent-skills/finops-toolkit/references/finops-hubs.md)
      - [src/templates/agent-skills/finops-toolkit/references/finops-hubs-deployment.md](../../agent-skills/finops-toolkit/references/finops-hubs-deployment.md)
      - [src/templates/agent-skills/azure-cost-management/references/azure-cost-exports.md](../../agent-skills/azure-cost-management/references/azure-cost-exports.md)
      - [src/templates/claude-plugin/agents/ftk-database-query.md](../../claude-plugin/agents/ftk-database-query.md)
      - [src/templates/claude-plugin/output-styles/ftk-output-style.md](../../claude-plugin/output-styles/ftk-output-style.md)
8. Update changelog
   1. Add an entry under the next version in [docs-mslearn/toolkit/changelog.md](../../../../docs-mslearn/toolkit/changelog.md) describing the new FOCUS version support and any preview status.

### Handling multiple FOCUS versions in one cycle

Occasionally, the toolkit needs to support two FOCUS versions in a single release &ndash; for example, a newly ratified version alongside a working draft of the next version. When that happens:

- The older version follows the standard `_v1_X` naming and ships as generally available (GA).
- The newer version uses the next `_v1_Y` suffix and is labeled **preview** in user-facing documentation, including [data-model.md](../../../../docs-mslearn/toolkit/hubs/data-model.md) and [changelog.md](../../../../docs-mslearn/toolkit/changelog.md).
- Preview schemas may change without notice between releases. Treat them as opt-in for early adopters only.
- The unversioned functions (`Costs()`, `Prices()`, etc.) alias to the latest **GA** schema, not the preview. The aliases promote to the newer version only after it transitions from preview to GA.

This guarantees backwards compatibility for production consumers while still enabling early validation of the next FOCUS version.
