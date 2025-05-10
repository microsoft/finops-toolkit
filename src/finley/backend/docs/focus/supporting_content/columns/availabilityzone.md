# Column: Availability Zone

## Example provider mappings

Current column mappings found in available data sets:

| Provider | Data set                 | Column                    |
|----------|--------------------------|---------------------------|
| AWS | CUR                      | lineItem/AvailabilityZone |
| Google Cloud | BigQuery Billing Export | location.zone             |
| Microsoft | Cost details             | Not available             |
| OCI | Cost reports             | product/availabilityDomain |

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider | Data set                 | Example Value                                  |
|----------|--------------------------|------------------------------------------------|
| AWS | CUR                      | us-east-1a, me-south-1, ap-southeast-4 |
| Google Cloud | BigQuery Billing Export | us-central1-a, europe-west6-b, asia-east2-b |
| Microsoft | Cost details             | N/A |
| OCI | Cost reports             | product/availabilityDomain | EnnW:CA-TORONTO-1-AD-1, EnnW:EU-STOCKHOLM-1-AD-1, EnnW:US-ASHBURN-AD-1 |   

## Discussion / Scratch space:

Discussion of zone definition

- Original A zone is an identifier assigned to a geographic location by the provider.
- The zone is commonly used for cost reporting, cost-effective location migration scenarios.
- Revised A zone is a logical data center within a region.
- Regions typically consist of multiple physically separated and isolated zones which provide high availability and fault tolerance.
- Availability zones are physically separated and isolated areas within a region which provide high availability and fault tolerance.
- Allow nulls - changed from False to True
- References:
  - AWS Billing: [Product details - AWS Cost and Usage Reports](https://docs.aws.amazon.com/cur/latest/userguide/product-columns.html#R)
  - GCP Billing: [Structure of Detailed data export | Cloud Billing](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/detailed-usage#detailed-usage-cost-data-schema)
  - Azure Billing: [Understand cost details fields](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields)
  - OCI Billing: [OCI Cost report schema - Cost and Usage Reports Overview](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/usagereportsoverview.htm)
  - Azure Zone: [What are Azure regions and availability zones? | Microsoft Learn](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview)
  - GCP Zone: [Geography and regions](https://cloud.google.com/docs/geography-and-regions)
  - AWS Zone: [AWS Regions and Availability Zones](https://docs.aws.amazon.com/whitepapers/latest/get-started-documentdb/aws-regions-and-availability-zones.html)
  - OCI Zone: [OCI Regions and Availability Domains](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm)
