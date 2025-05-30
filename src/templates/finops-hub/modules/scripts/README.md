# FinOps hub scripts

## Data ingestion

Data ingestion workflow:

- All data is ingested into tables named "*_raw".
  - Raw tables are declared in [IngestionSetup_raw.kql](IngestionSetup_raw.kql).
  - These tables have a union schema to support multiple sources and versions.
- All data is transformed to the latest FOCUS schema using an update policy into a "*_final_vX_Y" table named after the version (for example, "1.0" = "_v1_0"). Final tables, Transform functions, and update policies are in the versioned setup files:
  - [IngestionSetup_v1_0.kql](IngestionSetup_v1_0.kql)
- Data ingestion from previous version of hubs will remain in the versioned tables.
- Data is read from versioned functions in the Hub database. See [HubSetup.kql](HubSetup.kql) for details.

To add a new FOCUS versions:

1. Add new columns to the *_raw tables per dataset
2. Add new *_final_vX_Y tables per dataset
3. Add new *_transform_vX_Y functions per dataset
4. Change the update policy for the *_raw tables to use the new transform functions
5. Update HubSetup.kql to read from the new *_final_vX_Y tables
