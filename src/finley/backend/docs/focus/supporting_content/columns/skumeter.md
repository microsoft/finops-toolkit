# Column: SkuMeter

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column                             |
|-----------|--------------------------|------------------------------------|
| AWS       | CUR                      | line_item_usage_type               |
| GCP       | Big Query Billing Export | service.description                |
| Microsoft | Cost details             | MeterName                          |
| OCI       | Cost reports             | TBD                                |

## Background

Cloud Services, such as managed databases, virtual machines for compute, and object storage, have billing models in which the usage of that service is metered and then charged based on multiple parameters. For example, Amazon S3 charges customers for Storage, API requests, Data transfer, Encryption, Object management, Replication, and custom API requests, and ALL of these functionalities are metered and billed under the service name “Amazon S3”.

Cloud providers use different SKUs to differentiate between these different types of usage of a given service, but the SKU is a GUID that does not have any semantic meaning to a FinOps practitioner. This is problematic because as a FinOps practitioner, I want to be able to understand what the breakdown is of how I am being charged for a particular service so that I can use this information to report what the primary cost drivers are for a particular service and so that I can make optimization decisions. For example, I might want to understand what my data transfer costs within all of my Amazon S3 charges so that I can recommend my development team to change their storage access patterns in order to achieve cost savings.

Research across cloud providers suggests that there are 4 main categories of attributes that contribute to a SKU. They are:
Product: What is the public name of the thing (eg the resource or service) being sold?
Region: Where is the thing being sold?
Function: What is the functionality being measured and sold?
Size: How big is the thing (eg the resource or service) being sold (if applicable)?

This column addresses the "Function" attribute of a SKU by making it a first class part of the FOCUS schema.

## Problem

Today, FOCUS does not have any columns that enable FinOps practitioners to understand the meaning of different SKUs that appear and group them (such as with SQL GROUP BY) in order to better understand the main contributors to the cost of a given service.

As a practitioner, I want to be able to write a SQL query that easily breaks down my charges for a given service so that I can understand how each kind of "Function" is contributing to the overall cost of a service.

## Solution Discussion

**Short term (V1.1):** 
Given that these data may not be readily available immediately from providers, we are starting with a single column which providers can populate with as much useful data as they can that helps meet this need.

We believe it will be OK for providers to decide how to populate this column with the data they have available today. This means the data within this column may cover more than just the "Function" attribute described above. When populating this column, Providers should keep in mind that it will be painful for practitioners if the provider decides to change it in the future.

**Longer term (timeframe TBD):**
In the future we would like to move to separate columns, one for each of Product, Region, Function, Size, and have each of these columns be populated with only this data.

There may be an opportunity for some of these values to be normalized, or at least the format standardized, but some values will need to be provider-specific. This is similar to how the Unit Attribute works today where the most common units are normalized across providers (such as Hours), while other units are provider specific.