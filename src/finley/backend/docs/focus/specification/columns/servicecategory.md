# Service Category

The Service Category is the highest-level classification of a [*service*](#glossary:service) based on the core function of the *service*. Each *service* should have one and only one category that best aligns with its primary purpose. The Service Category is commonly used for scenarios like analyzing costs across providers and tracking the migration of workloads across fundamentally different architectures.

The ServiceCategory column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) and MUST NOT be null. This column is of type String and MUST be one of the allowed values.

## Column ID

ServiceCategory

## Display Name

Service Category

## Description

Highest-level classification of a *service* based on the core function of the *service*.

## Content Constraints

| Constraint      | Value          |
| :-------------- | :------------- |
| Column type     | Dimension      |
| Feature level   | Mandatory      |
| Allows nulls    | False          |
| Data type       | String         |
| Value format    | Allowed Values |

Allowed values:

| Service Category          | Description                                                                                    |
| :------------------------ | :--------------------------------------------------------------------------------------------- |
| AI and Machine Learning   | Artificial Intelligence and Machine Learning related technologies.                             |
| Analytics                 | Data processing, analytics, and visualization capabilities.                                    |
| Business Applications     | Business and productivity applications and services.                                           |
| Compute                   | Virtual, containerized, serverless, or high-performance computing infrastructure and services. |
| Databases                 | Database platforms and services that allow for storage and querying of data.                   |
| Developer Tools           | Software development and delivery tools and services.                                          |
| Multicloud                | Support for interworking of multiple cloud and/or on-premises environments.                    |
| Identity                  | Identity and access management services.                                                       |
| Integration               | Services that allow applications to interact with one another.                                 |
| Internet of Things        | Development and management of IoT devices and networks.                                        |
| Management and Governance | Management, logging, and observability of a customer's use of cloud.                           |
| Media                     | Media and entertainment streaming and processing services.                                     |
| Migration                 | Moving applications and data to the cloud.                                                     |
| Mobile                    | Services enabling cloud applications to interact via mobile technologies.                      |
| Networking                | Network connectivity and management.                                                           |
| Security                  | Security monitoring and compliance services.                                                   |
| Storage                   | Storage services for structured or unstructured data.                                          |
| Web                       | Services enabling cloud applications to interact via the Internet.                             |
| Other                     | New or emerging services that do not align with an existing category.                          |

## Introduced (version)

0.5
