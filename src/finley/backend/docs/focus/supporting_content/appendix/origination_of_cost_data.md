# Origination of cost data

## Example usage scenarios

Current values observed in billing data or potential values that should be supplied for various scenarios:

| #  | Scenario                                                                                                                                                                           | Provider                 | Publisher         | Invoice Issuer           |
|----|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------|-------------------|--------------------------|
| 1  | Direct cloud usage: You use an instance of CosmosDB (Scenario #1.1)                                                                                                                | Microsoft                | Microsoft         | Microsoft                |
| 2  | MSP cloud usage: You purchase GCP through SADA (Scenario #2.1)                                                                                                                     | Google                   | Google            | SADA                     |
| 3  | Professional services: IT infrastructure outsourcing (Scenario #2.2)                                                                                                               | Accenture                | Accenture         | Accenture                |
| 4  | Professional services: IT labor outsourcing (Scenario #2.3)                                                                                                                        | Accenture                | Accenture         | Accenture                |
| 5  | License for cloud usage: You use a Microsoft SQL Server license purchased on AWS Marketplace on EC2 (Scenario #3.1)                                                                | Amazon Web Services, Inc | Microsoft         | Amazon Web Services, Inc |
| 6  | Infrastructure via marketplace: You purchase PaloAlto Networks Firewall (charged based on type of VM instance you run on) through AWS Marketplace (Scenario #3.1)                  | Amazon Web Services, Inc | PaloAlto Networks | Amazon Web Services, Inc |
| 7  | Purchase business solution via marketplace: You purchase Udemy Business Licenses through AWS Marketplace (Scenario #3.2)                                                           | Amazon Web Services, Inc | Udemy             | Amazon Web Services, Inc |
| 8  | SaaS purchase via cloud marketplace: You purchase DataDog through AWS Marketplace (Scenario #3.2)                                                                                  | Amazon Web Services, Inc | DataDog           | Amazon Web Services, Inc |
| 9  | Professional services: You purchased Accenture consulting services via GCP Marketplace (Scenario #3.2)                                                                             | Google                   | Accenture         | Google                   |
| 10 | Reseller scenario - Purchase DataDog via Azure marketplace through SADA as reseller (Scenario #3.3)                                                                                | Microsoft                | DataDog           | SADA                     |
| 11 | Direct SaaS purchase: You purchase DataDog directly from DataDog (Scenario #4.1)                                                                                                   | DataDog                  | DataDog           | DataDog                  |
| 12 | Direct SaaS purchase: You purchased and used Databricks Classic  (Scenario #4.1)                                                                                                   | Databricks               | Databricks        | Databricks               |
| 13 | Direct SaaS purchase (where a portion runs on your cloud environment): Compute / storage / network cost associated with running Databricks in your AWS environment (Scenario #4.2) | AWS                      | AWS               | AWS                      |
| 14 | On premises: You use Kubernetes via an internal PaaS service built in your organization called Kube4U which runs on-prem (Scenario #5.1)                                           | Kube4U                   | Kube4U            | Kube4U                   |
| 15 | Internal cloud platform: You use Kubernetes via an internal PaaS service built in your organization called Kube4U which runs in hybrid mode or in AWS (Scenario #5.2)              | Kube4U                   | Kube4U            | Kube4U                   |
| 16 | Software Licenses: You purchased SQLServer licenses from Microsoft that are used in an internal DBaaS platform service (Scenario #5.3)                                             | Internal platform name   | Microsoft         | Internal platform name   |

## Discussion / Scratch space

- Provider is the entity through which you're purchasing the products regardless of the purchasing mechanism
- Publisher value matches who developed or produced the customer-facing infrastructure, software or services regardless of the purchasing mechanism. Where the resources and/or services are provided as a 'managed' offering, the branded name of the managed offering may be used as the publisher. E.g. If managed Kubernetes was provided via EKS / AKS / GKE / Internal cloud, the publisher would be the cloud providers, not the Kubernetes project or the CNCF.
- Invoice Issuer always matches who did the billing for the transaction regardless of the purchasing mechanism.
  - Invoice Issuer oddities:
    - There would be differentiation between (e.g.) Google France SarL and Google, Inc. USA even though it's really "one Google"
    - Azure in China is operated by SomeCompany, so this will be the Invoice Issuer, even if it looks like you are buying it from Microsoft. ("franchise model")

- Cost reporting queries currently not possible with the current columns:
  - Total cost of resources and/or services running on a particular provider (e.g., AWS)\
    In order to answer this query we would either need another dimension that can show the platform delivering the infra/services OR switch provider to show this value.
    - Invalid query: group by provider, sum (invoice cost OR amortized cost) will include cost of other software and services that have been purchased on AWS (e.g. cases 7,8,9 above) 
    - Invalid query: group by publisher, sum (invoice cost OR amortized cost) will exclude cost of 3rd party software/services purchased on marketplace that runs on your AWS environment (e.g. cases 6 above)
