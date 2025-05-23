# IngestionSetup.kql Split Solution

This document provides an overview of the solution for the issue where IngestionSetup.kql exceeded the 128KB Bicep file size limit.

## Summary of Changes

1. The IngestionSetup.kql file (146,705 bytes) was split into seven smaller files, each below the 128KB limit:
   - IngestionSetup_1_Settings.kql (2,245 bytes)
   - IngestionSetup_2_OpenData.kql (3,361 bytes)
   - IngestionSetup_3_Prices.kql (19,111 bytes)
   - IngestionSetup_4_CostUsage.kql (38,165 bytes)
   - IngestionSetup_5_CommitmentDiscountUsage.kql (9,374 bytes)
   - IngestionSetup_6_Recommendations.kql (11,958 bytes)
   - IngestionSetup_7_Transactions.kql (14,359 bytes)

2. The `dataExplorer.bicep` file was updated to load these files in sequence, with each module depending on the previous one to ensure proper execution order.

## Implementation Details

### Splitting Strategy

The original file was split based on logical sections:
- Settings
- Open Data
- Prices
- Cost and Usage
- Commitment Discount Usage
- Recommendations
- Transactions

Each section now has its own file, with the appropriate copyright header and section comments preserved.

### Bicep Changes

The `dataExplorer.bicep` file was modified to:
1. Replace the single `ingestion_SetupScript` module with seven sequential modules
2. Set up proper dependency chains to ensure scripts are executed in the correct order
3. Update the dependency reference in the `hub_SetupScript` module to point to the last ingestion setup module

This approach ensures that the scripts are loaded and executed in the same logical order as before.

## Validation

To validate this solution:
1. Deploy the template to verify that all scripts are loaded and executed successfully
2. Check that all tables, mappings, functions, and update policies are created correctly
3. Ensure data ingestion works as expected

## Future Considerations

As the FinOps toolkit evolves, additional KQL scripts may also grow beyond the Bicep file size limit. Consider applying a similar splitting strategy to other large KQL scripts, or implementing a more dynamic loading mechanism for KQL scripts.