# Column: ServiceName

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column                                                    |
|-----------|--------------------------|-----------------------------------------------------------|
| AWS       | CUR                      | line_item_product_code                                    |
| GCP       | Big Query Billing Export | service.description                                       |
| Microsoft | Cost details             | ConsumedService (represents the Azure Resource Manager resource provider, which is not a 1:1 relationship to the actual service)<br>Related:<br>ServiceName (EA only)<br>MeterCategory (EA and MCA)<br>(Both are functionally the same. ServiceName has “cleaner” values for EA only.)<br>Description: Name of the classification category for the meter. Same as the service in the Microsoft Customer Agreement Price Sheet. Exact string values differ. |
| Microsoft | Price sheet              | serviceName                                               |
| OCI       | Cost reports             | product/service                                           |

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Data set                 | Example Value                                      |
| --------- | ------------------------ | -------------------------------------------------- |
| AWS       | CUR                      | AmazonS3, AmazonRDS                                |
| GCP       | Big Query Billing Export | Networking, Cloud SQL, BigQuery                    |
| Microsoft | Cost details             | Virtual Machines, Azure App Service, Azure Monitor |
| OCI       | Cost reports             | OBJECTSTORE, COMPUTE, BLOCK_STORAGE                |

- Microsoft: [understand-usage-details-fields](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields)
- AWS: The code of the product measured
- GCP: The service.description column contains the name of the service.
- OCI: [Cost Report Schema](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/usagereportsoverview.htm#Cost_and_Usage_Reports_Overview__cost_report_schema)

## Discussion / Scratch space

- Definition for ‘Service’ to come from the glossary
