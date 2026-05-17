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
   1. Ensure the FOCUS specification has been ratified for the target version. Support for working draft FOCUS versions should not be shipped before official ratification to prevent customer churn sinc FOCUS working drafts may change without notice.
   2. Check whether Microsoft Cost Management has shipped a matching FOCUS export dataset version. The hub depends on a `focuscost_X.Y.json` schema mapping file in [Microsoft.CostManagement/Exports/schemas](../modules/Microsoft.CostManagement/Exports/schemas/) when ingesting from Cost Management. If the export is not yet available, the hub schema can still ship as GA. Note the gap in the changelog so adopters know what additional setup will be required.
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
   1. Create a `FocusCost_<version>.json` file into [src/open-data/dataset-metadata](../../../open-data/dataset-metadata/) for each Cost Management cost export version.
   2. Create a `FinOpsHubs_<dataset>_<schema-version>.json` file into [src/open-data/dataset-metadata](../../../open-data/dataset-metadata/) for each FinOps hub managed dataset schema version.
   3. Mirror the schema details (columns, types, descriptions) from the matching Cost Management export or FinOps hubs schema so downstream consumers see consistent metadata.
6. Update plugin skill files
   1. Refresh the FOCUS schema and function references in the following files so plugin guidance does not go stale:
      - [src/templates/agent-skills/finops-toolkit/references/finops-hubs.md](../../agent-skills/finops-toolkit/references/finops-hubs.md)
      - [src/templates/agent-skills/finops-toolkit/references/finops-hubs-deployment.md](../../agent-skills/finops-toolkit/references/finops-hubs-deployment.md)
      - [src/templates/agent-skills/azure-cost-management/references/azure-cost-exports.md](../../agent-skills/azure-cost-management/references/azure-cost-exports.md)
      - [src/templates/claude-plugin/agents/ftk-database-query.md](../../claude-plugin/agents/ftk-database-query.md)
      - [src/templates/claude-plugin/output-styles/ftk-output-style.md](../../claude-plugin/output-styles/ftk-output-style.md)
7. Update changelog
   1. Add an entry under the next version in [docs-mslearn/toolkit/changelog.md](../../../../docs-mslearn/toolkit/changelog.md) describing the new FOCUS version support and any preview status.
