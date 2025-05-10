# Column: ResourceName

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Provider column                                                                                                                                                                  |
|-----------|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| AWS       | CUR                      | Not present as a separate column in data. <br>Name available in some cases as a part of line_item_resource_id (in the ARN OR as the id for things like s3 buckets)                  |
| GCP       | Big Query Billing Export | Not present as a separate column in data. <br>Column resource.global_name seems to have a resource name at the very end of the fully qualified resource name (resource.global_name). |
| Microsoft | Cost details             | ResourceName                                                                                                                                                                     |
| OCI | Cost reports | Not present. Closest thing is product/resourceId |

## Example usage scenarios

Current values observed in billing data for various scenarios:

See supporting content for [ResourceId](./resourceid.md). In some cases, the resource name is provided in the Resource ID as a part of the fully-qualified name.

## Discussion / Scratch space

- Should this be prefixed with 'Provider' e.g. ProviderResourceName to show that it's a 1:1 mapping to a column possibly in the data from the provider namespace (no data normalization done).
  - No, keep the name simple for now. Larger namespace discussion will happen before v1.0
- Need to consider if we should account for using [*tags*](#glossary:tag) for custom display names.
  - If a display name is provided (regardless of via *tag* or directly for the resource), it should appear in this column
- Should a FullResourceName be introduced as well? Seems several providers have a fully qualified name that they provide at least in some cases (e.g. gcp resource.global_name, AWS ARN in some cases)
- Should the description say user-defined? Some providers set 'name' using system defined logic (kubernetes)
  - For now, we've settled on the 'display name' terminology
- Clarification on nullability 
  - Should governance include language like "Nullable where cost is not associated with a resource or the provider doesn't allow users to specify a name on a resource"
  - Should ResourceId be specified as ResourceName  when name is null (when resource id is not null)
  - Do providers put Id / name for everything?
    - Azure doesn't have a resource information for some things like marketplace subscriptions currently
  - Based on these findings, ResourceName column cannot be a non-null column
