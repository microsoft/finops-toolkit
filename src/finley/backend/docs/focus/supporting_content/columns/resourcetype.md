# Column: ResourceType

## Example provider mappings

Current resource types found or extracted from available data sets:

| Provider  | Data set                | Column                                                                                                                                   |
| :-------- | :---------------------- | :--------------------------------------------------------------------------------------------------------------------------------------- |
| AWS       | CUR                     | `lineItem/ResourceId` (only if resource-type exists within an ARN - arn:partition:service:region:account-id:*resource-type*/resource-id) |
| GCP       | BigQuery Billing Export | (Does not exist)                                                                                                                         |
| Microsoft | Cost details            | `ResourceType`                                                                                                                           |

## Example usage scenarios

The following is a list of potential Resource Type values that AWS, Azure, and GCP may choose to provide.

| Resource Type             | AWS                       | Azure                                 | GCP                               |
|:------------------------- |:------------------------- |:------------------------------------- |:--------------------------------- |
| Virtual Machine           | EC2 Virtual Machine       | Azure Virtual Machine                 | Compute Engine Virtual Machine    |
| Disk                      | EBS Volume                | Managed Disk                          | Persistent Disk                   |
| Serverless Function       | Lambda Function           | Azure Function                        | Cloud Functions Function          |
| Blob Storage Bucket       | S3 Bucket                 | Blob Storage Container                | GCS Bucket                        |
| File System               | EFS File System           | File Storage                          | File Store                        |
| Load Balancer             | Elastic Load Balancer     | Public Load Balancer                  | Cloud Load Balancer               |
| Relational Database       | Amazon Aurora Cluster     | Database for MySQL/Postgres Cluster   | CloudSQL Cluster                  |
| Data Warehouse            | Redshift Cluster          | Synapse Analytics Warehouse           | BigQuery Storage/Analysis         |

## Discussion / Scratch space

- Too much effort to ask for Resource Type normalization across clouds.
- Provider-based Resource Type is the first step towards potentially normalizing across clouds.
- Happy medium is a provider-based ResourceType
- It should be a required field that is nullable

