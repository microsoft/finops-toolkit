# Column: BillingAccountName

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column                                                    |
|-----------|--------------------------|-----------------------------------------------------------|
| AWS       | CUR                      | Not available (bill_payer_account_id maps to BillingAccountId) |
| GCP       | BigQuery Billing Export  | Not available (billing_account_id maps to BillingAccountId) |
| Microsoft | Cost details             | EA: BillingAccountName, MCA: BillingProfileName, MOSA: SubscriptionName |

## Documentation

- GCP: [Resource Hierarchy](https://cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy#resource-hierarchy-detail)
- Azure: [Organizing resources](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/view-all-accounts)
- AWS: [Org Concepts](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_getting-started_concepts.html)

## Example usage scenarios

Current values observed in billing data for various scenarios:
| Provider  | Data set                 | Scenario      | Value              |
|-----------|--------------------------|---------------|--------------------|
| AWS       | CUR                      | Not available |                    |
| GCP       | BigQuery Billing Export  | Not available |                    |
| Microsoft | Cost details             | EA            | BillingAccountName |
