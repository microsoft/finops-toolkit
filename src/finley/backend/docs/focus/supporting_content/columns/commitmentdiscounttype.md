# Column: CommitmentDiscountType

## Example provider mappings

| Provider  | Data set                 | Column                                                   |
| --------- | ------------------------ | -------------------------------------------------------- |
| AWS       | CUR                      | reservation/ReservationARN<br>savingsPlan/SavingsPlanArn |
| GCP       | Big Query Billing Export | credits.id                                               |
| Microsoft | Cost details             | ReservationId (old)<br>BenefitId (new)                   |

## Example usage scenarios

Examples of found in available data sets:

| Provider | Example Values  |
|----------|--------------------------|
| AWS | Reserved Instances (RI) |
| AWS | Savings Plan |
| AWS | Capacity Blocks for ML |
| Google Cloud | Committed Use Discount (CUD) |
| Google Cloud | BigQuery Reservations |
| Microsoft | Savings Plan |
| Microsoft | Reservation |

## Discussion topics

- Alternative names discussed:
  - Commitment Discount Program
  - Commitment Discount Plan
  - Commitment Discount Plan Name
  - Decided to use "Type" to be consistent with "ResourceType"

  Note: See [Supporting Content for CommitmentDiscountCategory](commitmentdiscountcategory.md) for further explanation