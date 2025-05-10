# Column: Region ID
	
## Example provider mappings

Current column mappings found in available data sets:

| Provider | Data set                 | Column            |
|----------|--------------------------|-------------------|
| AWS | CUR                      | Product_region    |
| Google Cloud | BigQuery Billing Export | Location.location |
| Microsoft | EA, MCA                  | ResourceLocation  |
| OCI       | Cost reports             | product/region    |

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider | Data set                 | Example Value                                                                   |
|----------|--------------------------|---------------------------------------------------------------------------------|
| AWS | CUR                      | us-east-1, eu-west-1, us-gov-east-1 |
| Google Cloud | BigQuery Billing Export | northamerica-northeast1, asia-southeast1, us-central2, europe-west3, us |
| Microsoft | Cost details             | Eastasia, AP East, WestUS, centralindia |
| OCI       | Cost reports             | ap-mumbai-1, ca-toronto-1, eu-frankfurt-1, us-ashburn-1 |

## Discussion / Scratch space:

- AWS provides one region (fixed set of values supported)
- Azure has two regions (metered region and the region where a product/resource is running)
  - 99% of the time the meter region is the same as resource region
- There are cases where multiple regions from the same provider or different providers may be specified in the provider specified region column
- Values need to use consistent casing to ensure they can be grouped together (e.g., `EastUS` and `eastus` are not the same). The provider can choose to use lowercase, uppercase, or mixed case, as long as they are consistent.
- Azure: ResourceLocation (Where Azure resource resides),MeterRegion (how resource is billed on)
- For data transfer type use cases (from/to), does the region become the one that you get pricing for?
- Should 'usage' type columns be in the spec?
- Initial 0.5 scope is cost data primarily. Usage reasons are prioritized lower
- GCP: 
  - Location.location: The ResourceName column MUST be present in the billing data. This column MUST be of type String. The ResourceName value MAY be a nullable column as some cost data rows may not be associated with a resource or because a display name cannot be assigned to a resource. ResourceName MUST NOT be null if a display name can be assigned to a resource. Resources not provisioned interactively or only have a system generated ResourceId MUST NOT duplicate the same value as the ResourceName.
  - Location.country --->  When location.location is a country, region, or zone, this field is the country of usage, e.g. US. For more information, see Geography and regions and Google Cloud locations.
  - Location.region ---> When location.location is a region or zone, this field is the region of usage, e.g. us-central1. For more information, see Geography and regions and Google Cloud locations.
  - Location.region ---> When location.location is a region or zone, this field is the region of usage, e.g. us-central1. For more information, see Geography and regions and Google Cloud locations.
  - Another region related column might be billed region, priced region or something of that sort that signifies where the pricing rules are set
- We had a poll about whether Region should be nullable or not and decided it should. Updated this as part of 1.0.

-   Definition discussion:\
    "A Region ID is an identifier for an isolated geographic area where a resource is provisioned in OR a service is provided from. The region identifier is assigned by the provider. Resources and/or services are commonly utilized from different regions based on considerations for data sovereignty, performance, cost, convenience, or geopolitical reasons. "

| Provider  | Provider Region / Location | AZ / Zone  | Region Category(?) | Geographical Region (code? Continent) | Country (code?) | TimeZone (check need) |
|-----------|----------------------------|------------|--------------------|---------------------------------------|-----------------|-----------------------|
| AWS       | eu-west-1                  | eu-west-1a | single-region      | EU?                                   | Ireland?        | GMT +/- n             |
| Google Cloud      | europe-west3               |            | single-region      |                                       |                 |                       |
| Microsoft | WestEurope                 |            | single-region      |                                       | Ireland         |                       |
| AWS       | Global (normalized?)       |            | global             |                                       |                 |                       |
| Google Cloud      | nam-eur-asia1              |            | multi-region       |                                       |                 |                       |


| Provider | Summary (lowest level) | Geo Region (code? Continent) | Country (code?) | Provider Region / Location | AZ / Zone  | Region Category(?) | TimeZone (check need) |
|----------|------------------------|------------------------------|-----------------|----------------------------|------------|--------------------|-----------------------|
| AWS      | eu-west-1a             | EU?                          | Ireland?        | eu-west-1                  | eu-west-1a | single-region      | GMT +/- n             |
| Google Cloud     | europe-west3           | EU                           | Ireland?        | europe-west3               | (null)     | single-region      |                       |
| MS       | WestEurope             | EU                           | Ireland         | WestEurope                 | (null)     | single-region      |                       |
| AWS      | Global                 | Global                       | Global          | Global (normalized?)       | (null)     | global             |                       |
| Google Cloud     | nam-eur-asia1          | Global?                      | Global?         | nam-eur-asia1              | (null)     | multi-region       |                       |

-   Brainstorming secondary region

| Provider | Provider Region | Secondary Region | Secondary Region Type   |
|----------|-----------------|------------------|-------------------------|
|          | WestEurope      | BrazilSouth      | DataTransferDestination |
|          | WestEurope      | External         | DataTransferSource      |
|          | WestEurope      |                  |                         |

- References:
  - AWS: [https://docs.aws.amazon.com/cur/latest/userguide/product-columns.html#R](https://docs.aws.amazon.com/cur/latest/userguide/product-columns.html#R)
  - GCP: [https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/detailed-usage#detailed-usage-cost-data-schema](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/detailed-usage#detailed-usage-cost-data-schema), [https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/standard-usage](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/standard-usage)
  - Azure: [https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields)
  - OCI: [https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm)
