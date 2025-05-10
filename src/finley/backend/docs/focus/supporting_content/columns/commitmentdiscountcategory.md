# Column: CommitmentDiscountCategory

## Example provider mappings

Current column mappings found in available data sets:

| Provider | Data set                 | Column                    |  Example Values  |
|----------|--------------------------|---------------------------|------------------|
| AWS | CUR                      | Not available   | N/A |
| Google Cloud | BigQuery Billing Export | credit.type              | COMMITTED_USAGE_DISCOUNT, COMMITTED_USAGE_DISCOUNT_DOLLAR_BASE |
| Microsoft | Cost Details             | Not available               | N/A |

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider | Data set                 | CommitmentDiscountCategory     | CommitmentDiscountProgram (Name TBD)     |
|----------|--------------------------|----------------------------|------------------------------------------|
| AWS | CUR (PurchaseOption)                   | Usage               | Reserved Instances              |
| AWS | CUR (PurchaseOption)                   | Spend               | Savings Plans                   |
| Google Cloud | BigQuery Billing Export | Usage        | Resource-based CUD                            |
| Google Cloud | BigQuery Billing Export | Spend        | Spend-based CUD                               |
| Microsoft | Cost Details (PricingModel)| Spend                     | Savings Plan                     |
| Microsoft | Cost Details (PricingModel)| Usage                     | Reservation                      |

## Documentation
- Microsoft
  - Azure:  Understand usage details fields: https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields
- GCP
  - Google Commitment Types:  https://cloud.google.com/docs/cuds#spend_versus_resource_commitments (This is the most similar to our selected implementation)
  - https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/standard-usage - see credit.type
- AWS
  - Amazon: Reservation details - https://docs.aws.amazon.com/cur/latest/userguide/reservation-columns.html

## Discussion Topics
It was discussed whether or not this field should be a normalized list of values OR if we should make it a suggestive, freeform text field as different cloud providers have different names for their implementation of Commitment Usage Discounts. For example:
  - Savings Plan
  - RI/CUD
  - Flexible CUDs

For AWS, this column could possibly calculated as such:
  if reservation/ReservationARN <> '' then Usage, else if savingsPlan/SavingsPlanArn <> '' then Spend, else nullThis column

It was agreed that another column would be added (ideally in V1.0) that would identify the CUD name as termed by the Cloud Provider and that this column would be normalized to allow practitioners to have a standard interface to group and compare CUDs from multiple sources. This would be a non-normalized string.

Update: The name of this additional column has been determined as Commitment Discount Type.

- Microsoft
  - Azure:  PricingModel: https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields
- GCP
  - Google Commitment Types:  https://cloud.google.com/docs/cuds#spend_versus_resource_commitments (This is the most similar to our selected implementation)
  - https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/standard-usage
- AWS
  - Amazon: Instance purchasing options - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-purchasing-options.html
