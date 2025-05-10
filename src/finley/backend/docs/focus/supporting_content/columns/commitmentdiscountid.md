# Column: CommitmentDiscountId

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column                                                   |
| --------- | ------------------------ | -------------------------------------------------------- |
| AWS       | CUR                      | reservation/ReservationARN<br>savingsPlan/SavingsPlanArn |
| GCP       | Big Query Billing Export | credits.id                                               |
| Microsoft | Cost details             | ReservationId (old)<br>BenefitId (new)                   |

## Documentation

- AWS: [Reserved Instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-reserved-instances.html), [Savings Plans](https://docs.aws.amazon.com/savingsplans/latest/userguide/what-is-savings-plans.html)
- GCP: [Structure of Standard data export](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/standard-usage), [Committed Use Discounts](https://cloud.google.com/docs/cuds)
- Microsoft: [Azure Savings Plans](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/savings-plan-compute-overview), [Azure Reservations](https://learn.microsoft.com/azure/cost-management-billing/reservations/save-compute-costs-reservations)

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Data set                 | Scenario                                                         |
| --------- | ------------------------ | ---------------------------------------------------------------- |
| AWS       | CUR                      | arn:partition:service:region:account-id:reserved-instances/\<id> |
| AWS       | CUR                      | arn:partition:savingsplans:[region]:account-id:savingsplan/\<id> |
| GCP       | Big Query Billing Export | \<alphanumeric identifier>                                       |
| GCP       | Big Query Billing Export | \<credit description>, i.e. "Committed Use Discount: CPU"        |
| Microsoft | Cost details             | Commitment order GUID for purchase rows                          |
| Microsoft | Cost details             | Commitment instance GUID for amortized usage                     |

## Discussion / Scratch space:

- Column names considered:
  - CommitmentBasedDiscountId
  - CommitmentId
  - CommitmentDiscountId
  - DiscountId
  - BenefitId
- In AWS, includes RI and SP, commitments that don’t map 1:1 with a single resource, capacity reservations (i.e. DynamoDB).
- Only commitments were identified to require an explicit id/name.
- The name “commitment” was agreed upon. Applies to both id and name.
