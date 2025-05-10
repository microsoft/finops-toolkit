# Column: CommitmentDiscountQuantity

## Example provider mappings

Current column mappings found in available data sets:

| Provider | Data set | Column |
|----------|----------|--------|
| AWS | CUR | reservation/UnusedQuantity (inverse), reservation/TotalReservedUnits, savingsPlan/UsedCommitment, savingsPlan/TotalCommitmentToDate |
| Google Cloud | BigQuery Billing Export | Not available |
| Microsoft | Cost Details | Not available |

## Example usage scenarios

Current values observed in billing data for various scenarios:

AWS Reservation Utilization Rate: (1 - (reservation/UnusedQuantity / reservation/TotalReservedUnits)) * 100
AWS Savings Plan Utilization Rate: savingsPlan/UsedCommitment / savingsPlan/TotalCommitmentToDate * 100

## Documentation
- AWS
  - Reservation details - https://docs.aws.amazon.com/cur/latest/userguide/reservation-columns.html
  - Savings Plans details - https://docs.aws.amazon.com/cur/latest/userguide/savingsplans-columns.html


