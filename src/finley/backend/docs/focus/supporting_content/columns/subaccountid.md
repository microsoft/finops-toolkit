# Column: Sub Account ID

## Example provider mappings 

Current column mappings found in available data sets:

| Provider  | Data set | Column |
|-----------|----------|--------|
| AWS       | CUR      | lineItem/UsageAccountId |
| GCP       | Big Query Billing Export | project.id |
| Microsoft | Cost details | SubscriptionGuid |
| Microsoft | Price Sheet | |
| OCI       | Cost reports | lineItem/tenantId |

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Data set | Scenario |
|-----------|----------|--------|
| AWS       | CUR | Accounts are used for resource grouping, access management and cost segregation purposes within a payer / management account. |
| GCP       | Big Query Billing Export | Projects are used for resource grouping, access management and cost segregation purposes within a billing account. |
| Microsoft | Cost details | Subscriptions are used for resource grouping, access management and cost segregation purposes within a billing profile. |
| Microsoft | Price sheet | |
| OCI       | Cost reports | Tenancies are used for segregating resources and access management. Multiple tenancies can be mapped to a "Subscription" (Billing Construct) in an Organization |

- GCP: [Resource Hierarchy](https://cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy#resource-hierarchy-detail)
- Azure: [Resource Hierarchy](https://learn.microsoft.com/en-us/azure/governance/management-groups/overview), [Organizing Resources](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/view-all-accounts)
- AWS: [Org Concepts](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_getting-started_concepts.html)
- OCI: [OCI resource hierarchy](https://docs.oracle.com/en/cloud/foundation/cloud_architecture/governance/tenancy.html#how-many-tenancies-do-i-need)

FOCUS plans to include Level 1, Level 3 in the specification. Level 5 (resource name, resource id) are already in the specification.

| Provider | Level 1 | Level 2 | Level 3 | Level 4 | Level 5 | |
|----------|---------|---------|---------|---------|---------|---------|
| | Billing Account | Sub Account Group (optional) | Sub Account | | | |
| AWS | Management Account | Org | Account | Resource Group (optional) | Resource | |
| GCP | Billing Account | Folder | Project | | | |
| MS EA | Billing Account (Invoice Scope) | Department | Enrollment Account | Subscription | Resource Group | Resource |
| MS MCA | Billing Account | Billing Profile (Invoice Scope) | Invoice Section | Subscription | Resource Group | Resource |
| MS PAYG | Billing Account | Subscription (Invoice Scope) | Resource Group | Resource | | |
| MS Internal | Subscription (Invoice Scope) | Resource Group | Resource | | | |
|OCI | Organization | Subscription (Invoice Scope) | Tenancy | Compartment | Resource |

## Discussion / Scratch space:

- Use provider terminology - or customers will get confused
- How about if we start with a definition: 
  - Logical grouping of resources
  - May contain access restrictions 
- Billing Account (L1), Account Group (L2), Account (L3)
  - Will there be confusion about Account vs Billing Account
  - What about "Usage Account" for L3
  - Billing account could say "grouping of Usage accounts"
- Names considered:
  - Billing Account / Account
  - Billing Account / Member Account
  - Billing Account / Sub Account
  - Billing Account / Resource Account
  - Billing Scope / Service Scope
  - Invoice Scope / Resource Management Scope
  - Billed to / Managed in
- Other descriptions considered:
  - Logical grouping of resources based on usage, access and/or billing boundaries.
  - Resource Container
  - Base level organizing entity of resources / resource container
  - A usage account is an organizing entity of provider resources.
  - (Combined) A usage account is a base-level organizing entity of provider resources often used to manage access and cost. A usage account is one of several structural elements of provider hierarchies.
