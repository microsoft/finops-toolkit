# Column: ServiceCategory

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column                                     |
| --------- | ------------------------ | ------------------------------------------ |
| AWS       | CUR                      | None                                       |
| GCP       | Big Query Billing Export | None                                       |
| Microsoft | Cost details             | ServiceFamily is close, but based on usage |
| OCI | Cost reports | Closest thing is column product/service in cost reports |

## Discussion / Scratch space

Principles behind Service Category, granularity, when to add, when to split etc.

- Every category must represent a single technology. Do not "and" multiple categories together unless they are synonymous.
- Each category should be unique and should not be a logical child of another category (e.g., Containers are a subclassification of Compute).
- Categories are used for cost classification purposes only. Do not create new categories for marketing differentiation (e.g., Containers).
- Avoid unnecessary words. Prefer short, concise names.
- Each service should have 1 and only 1 category that best aligns to its purpose.
- Each category should have around 3-10 services for the major cloud providers. Avoid categories with only 1 or with over 20 services. No category should have more than 20% of services.
- Do not create categories that describe traits of the service that could be applied to many categories (e.g., "serverless").
- Beyond purely cost categorization purposes, the category is based on the primary function the service intends to solve.

Note: While a service can only be in one category, usage/cost for that service may include charges related to another category. For example, resources under the Databases category can have storage and compute cost - however, the primary function of the overall service is to provide database functionality therefore it’s considered to be under the database category.

Cloud provider mappings:

| Category                                              | [AWS](https://aws.amazon.com/products)   | [GCP](https://cloud.google.com/products) | [Microsoft](https://azure.microsoft.com/en-us/products) | [Alibaba Cloud](https://www.alibabacloud.com/product) | Oracle Cloud (OCI)             |
| ----------------------------------------------------- | ---------------------------------------- | ---------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------- | ------------------------------ |
| AI and Machine Learning                               | Machine Learning                         | AI and machine learning                  | AI + machine learning                                   | AI & Machine Learning                                 | AI and Machine Learning        |
| Analytics                                             | Analytics                                | Data Analytics                           | Analytics                                               | Analytics Computing                                   | Analytics and BI               |
| (Use Analytics)                                       |                                          |                                          | (Under Analytics)                                       | (N/A)                                                 | Big Data                       |
| (Use Analytics)                                       |                                          |                                          | (Under Analytics)                                       | (Under Analytics Computing)                           | Data Lake                      |
| Business Applications                                 | Business Applications                    | (Tracked separately)                     | (Tracked separately)                                    | (N/A)                                                 | SaaS Applications              |
| (Use Business Applications)                           | End User Computing                       | (N/A)                                    | Virtual desktop infrastructure                          | (N/A)                                                 | (N/A)                          |
| (Consider Business Applications or Developer Tools)   | AR & VR                                  | (N/A)                                    | Mixed reality                                           | (N/A)                                                 | (N/A)                          |
| Compute                                               | Compute                                  | Compute                                  | Compute                                                 | Computing                                             | Compute                        |
| (Use Compute)                                         | Quantum Technologies                     | (N/A)                                    | (Under Compute)                                         | (N/A)                                                 | (N/A)                          |
| (Use Compute; consider subcategory)                   | Blockchain                               | (N/A)                                    | (N/A)                                                   | (Under Enterprise & Media Services)                   | (N/A)                          |
| (Use Compute; consider subcategory)                   | Containers                               | Containers                               | Containers                                              | Container & Middleware                                | Containers and Functions       |
| Databases                                             | Database                                 | Databases                                | Databases                                               | Database                                              | Database Services              |
| Developer Tools                                       | Developer Tools                          | Developer Tools                          | Developer Tools                                         | Developer Tools                                       | Developer Services             |
| (Use Developer Tools)                                 | (N/A)                                    | (N/A)                                    | DevOps                                                  | (N/A)                                                 | DevOps                         |
| Identity                                              | (Under Security, Identity, & Compliance) | (Under Security and Identity)            | Identity                                                | (Under Security)                                      | (N/A)                          |
| Integration                                           | Application Integration                  | (Under Serverless)                       | Integration                                             | (Under Container & Middleware)                        | Integration                    |
| (Use Integration)                                     |                                          | API management                           | (Under Web / Integration)                               | (N/A)                                                 | (N/A)                          |
| Internet of Things                                    | Internet of Things                       | Internet of things (IoT)                 | Internet of Things                                      | Internet of Things                                    | (N/A)                          |
| (Consider IoT)                                        | Robotics                                 | (N/A)                                    | (N/A)                                                   | (N/A)                                                 | (N/A)                          |
| Management and Governance                             | Management & Governance                  | Management tools                         | Management and governance                               | (N/A)                                                 | Observability and Management   |
| (Use Management and Governance; consider subcategory) | Cloud Financial Management               | (Under Management Tools)                 | (Under Management and governance)                       | (N/A)                                                 | Cost Management and Governance |
| (Use Management and Governance; consider subcategory) | (Under Management & Governance)          | Operations                               | (Under Management and governance)                       | Operations and Maintenance                            | (N/A)                          |
| Media                                                 | Media Services                           | Media and Gaming                         | Media                                                   | Enterprise Services & Media Services                  | (N/A)                          |
| Migration                                             | Migration & Transfer                     | Migration                                | Migration                                               | (N/A)                                                 | (N/A)                          |
| Mobile                                                |                                          |                                          | Mobile                                                  |                                                       |                                |
| Multicloud                                            | (Under Compute)                          | Hybrid and Multicloud                    | Hybrid + multicloud                                     | (Under Networking)                                    | Hybrid Cloud                   |
| Networking                                            | Networking & Content Delivery            | Networking                               | Networking                                              | Networking                                            | Networking                     |
| (Use Networking)                                      | Satellite                                | (N/A)                                    | (Under Networking)                                      | (N/A)                                                 | (N/A)                          |
| (Use Networking)                                      | (Under Networking & Content Delivery)    | (Under Networking)                       | (Under Networking)                                      | CDN & Cloud Communication                             | (N/A)                          |
| Security                                              | (Under Security, Identity, & Compliance) | Security and identity                    | Security                                                | Security                                              | Security                       |
| (Use Security)                                        | Security, Identity, & Compliance         | (N/A)                                    | (Tracked separately)                                    | (N/A)                                                 | Compliance                     |
| Storage                                               | Storage                                  | Storage                                  | Storage                                                 | Storage                                               | Storage                        |
| Web                                                   | Front-End Web & Mobile                   |                                          | Web                                                     | (N/A)                                                 | (N/A)                          |
| Other                                                 | (N/A)                                    | (N/A)                                    | (N/A)                                                   | (N/A)                                                 | (N/A)                          |
| (Use category aligned to the specific services)       | (N/A)                                    | Financial Services                       | (N/A)                                                   | (N/A)                                                 | (N/A)                          |
| (Use category aligned to the specific services)       | (Under ML)                               | Healthcare and Life Sciences             | (Under Integration / AI+ML)                             | (N/A)                                                 | (N/A)                          |
| (Use category aligned to the specific services)       | (Under other areas)                      | Serverless Computing                     | (Under other areas)                                     | (Under Compute)                                       | (Under other areas)            |

Other vendor mappings:

| Category                  | CloudZero               |
| ------------------------- | ----------------------- |
| Analytics                 | Analytics               |
| Compute                   | Compute                 |
| (Use Networking)          | Content Delivery        |
| Databases                 | Database                |
| Integration               | Application Integration |
| Management and Governance | Cloud Management        |
| Security                  | Security                |
| Storage                   | Storage                 |
| Other                     | Other                   |
