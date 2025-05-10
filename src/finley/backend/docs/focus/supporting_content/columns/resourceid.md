# Column: ResourceId

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column                               |
|-----------|--------------------------|--------------------------------------|
| AWS       | CUR                      | line_item_resource_id                |
| GCP       | Big Query Billing Export | resource.global_name                 |
| Microsoft | Cost details             | ResourceId                           |
| OCI       | Cost reports             | product/resourceId                   |

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Scenario                                          | Pattern                                                                                               |
|-----------|---------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| AWS       | ARN provided which includes a resource name or id | arn:partition:service:region:account-id:resource-id <br>arn:partition:service:region:account-id:resource-type/resource-id<br> arn:partition:service:region:account-id:resource-type:resource-id|
| AWS       | Some cases, just a resource-id is provided        | I-0b21f4c4434558933 OR my-cur-bucket                                                                  |
| AWS       | Tax, API call charges etc.                        | (null)                                                                                                |
| GCP       | Resource based                                    | //container.googleapis.com/projects/<project_id>/locations/\<location>/clusters/\<cluster>            |
| GCP       | Non-resource based (e.g. network egress)          | (null)                                                                                                |
| Microsoft | Resource group resources                          | /subscriptions/\<guid>/resourceGroups/\<name>/providers/\<provider>/\<resource-type>/\<resource-name> |
| Microsoft | Subscription resources                            | /subscriptions/\<guid>/providers/\<provider>/\<resource-type>/\<resource-name>                        |
| Microsoft | Tenant resources                                  | /providers/\<provider>/\<resource-type>/\<resource-name>                                              |
| Microsoft | Reservation purchases                             | /providers/Microsoft.Capacity/reservationOrders/\<guid>                                               |
| Microsoft | Savings plan purchases                            | /providers/Microsoft.BillingBenefits/savingsPlanOrders/\<guid>                                        |
| Microsoft | Marketplace and other purchases                   | (null)                                                                                                |
| OCI       | Resource based                                    | ocid1.\<RESOURCE TYPE>.\<REALM>.\[REGION]\[.FUTURE USE].\<UNIQUE ID>

### Documentation

AWS:
> [AWS User Guide documentation on ARNs](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference-arns.html)

Interesting note from above link on the "The resource identifier" regarding the last part of the ARN:

"This is the name of the resource, the ID of the resource, or a [resource path](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference-arns.html#arns-paths). Some resource identifiers include a parent resource (sub-resource-type/parent-resource/sub-resource) or a qualifier such as a version (resource-type:resource-name:qualifier)."

Microsoft:
> [Usage details](https://learn.microsoft.com/azure/cost-management-billing/automate/understand-usage-details-fields)

GCP:
> [Resource Names documentation](https://cloud.google.com/asset-inventory/docs/resource-name-format)

OCI:
> [OCI guide on Resource identifiers](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/identifiers.htm)

## Discussion / Scratch space

- Should there be a resource name and a separate fully qualified name? Use one column for resource ID and make a recommendation for the value to be globally unique within the provider (e.g. a fully qualified name)
- Should this be prefixed with 'Provider' e.g. ProviderResourceID to show that it's a 1:1 mapping to a provider provided column.
- Should governance say "Nullable where cost is not associated with a resource" to account for cost data not associated with a resource (e.g. API calls)
- Do we make any statements about uniqueness? Or is this where we request a uniqueness composite key to be specified in a schema document
  - Can we guarantee uniqueness and can it change over time?
  - ResourceId can only be required to be unique within a provider not across providers (unless we dictate a format for fully qualifying the id e.g. ARN that includes provider).
  - Also, note this is not the same as a line-item level uniqueness key. It's common for resource id's to show up many times in billing data for different time periods and different types of consumption
- Empty values should not be allowed if a user or system generated ResourceId is null (should this be an attribute specified as a higher level attribute OR within this scope)?
  - Should be specified in a higher-level attribute that applies spec-wide on how nulls/empty values and placeholders
- Future attribute/dimension:
  - Suggestion (Erik): Embrace a "Cloud Resource ID (CRID)" convention such as:
    <br>  `Crid:provider:service-type:region:owner-account-id:resource-type:cloud-local-id`
