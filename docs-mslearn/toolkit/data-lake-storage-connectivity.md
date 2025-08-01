---
title: Data Lake Storage connectivity options
description: Learn about tools and services that can connect to Data Lake Storage for FinOps analytics beyond Power BI, including Azure Data Explorer, Microsoft Fabric, and Azure Synapse Analytics.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps practitioner, I want to understand Data Lake Storage connectivity options outside of Power BI so that I can build custom reports that meet my organizational needs.
---

<!-- markdownlint-disable-next-line MD025 -->
# Data Lake Storage connectivity options

As a FinOps practitioner, you may need to build custom reports and analytics solutions outside of Power BI to meet specific organizational requirements. Azure Data Lake Storage provides a central repository for your FinOps data that can be accessed by multiple tools and services for advanced analytics, custom applications, and integration scenarios.

This article covers the primary tools and services that can connect to Data Lake Storage for FinOps analytics and reporting.

<br>

## Azure Data Explorer (ADX)

Azure Data Explorer is a fast, highly scalable data exploration service for log and telemetry data that provides powerful analytics capabilities for your FinOps data.

If you're using [FinOps hubs](hubs/finops-hubs-overview.md), Azure Data Explorer is automatically configured with pre-built data ingestion pipelines, optimized data models, sample dashboards and queries, and automated data processing.

> [!div class="nextstepaction"]
> [Configure Data Explorer dashboards](hubs/configure-dashboards.md)

<br>

## Microsoft Fabric

Microsoft Fabric is an all-in-one analytics solution that combines data integration, data engineering, data warehousing, data science, real-time analytics, and business intelligence into a unified platform.

Fabric provides a unified analytics platform with OneLake storage, AI and machine learning capabilities, seamless Power BI integration, and support for real-time insights.

> [!div class="nextstepaction"]
> [Create a Fabric workspace for FinOps](../fabric/create-fabric-workspace-finops.md)

<br>

## Azure Synapse Analytics

Azure Synapse Analytics is an enterprise data warehouse solution that combines big data and data warehousing capabilities.

### Benefits for FinOps

- **Scalable data warehouse**: Handle large volumes of historical FinOps data
- **SQL and Spark support**: Use familiar SQL or Apache Spark for data processing
- **Integrated machine learning**: Build predictive models for cost forecasting
- **Data lake integration**: Native integration with Data Lake Storage
- **Enterprise security**: Advanced security and governance features

### Getting started with Synapse

1. **Create a Synapse workspace**
   - Deploy Azure Synapse Analytics in your Azure subscription
   - Configure networking and security settings

2. **Mount Data Lake Storage**
   - Create external data sources pointing to your FinOps data
   - Set up linked services for authentication

3. **Create external tables**
   - Define external tables to query data directly from Data Lake Storage
   - Use partitioned views for performance optimization

4. **Build data pipelines**
   - Create ETL pipelines to process and transform FinOps data
   - Schedule regular data processing jobs

### Synapse SQL example

```sql
-- Create external data source
CREATE EXTERNAL DATA SOURCE FinOpsDataLake
WITH (
    LOCATION = 'abfss://container@storage.dfs.core.windows.net/finops-data',
    CREDENTIAL = ManagedIdentity
);

-- Create external table
CREATE EXTERNAL TABLE dbo.CostData (
    Date DATE,
    SubscriptionId NVARCHAR(100),
    ResourceGroup NVARCHAR(100),
    ServiceName NVARCHAR(100),
    EffectiveCost DECIMAL(18,2)
)
WITH (
    LOCATION = 'costs/',
    DATA_SOURCE = FinOpsDataLake,
    FILE_FORMAT = ParquetFileFormat
);

-- Query cost trends
SELECT 
    Date,
    ServiceName,
    SUM(EffectiveCost) as TotalCost
FROM dbo.CostData
WHERE Date >= DATEADD(month, -3, GETDATE())
GROUP BY Date, ServiceName
ORDER BY Date, TotalCost DESC;
```

> [!div class="nextstepaction"]
> [Learn about Synapse partitioned views](https://learn.microsoft.com/en-us/azure/synapse-analytics/sql/create-use-views#partitioned-views)

<br>

## Azure Databricks

Azure Databricks is a unified analytics platform that provides collaborative Apache Spark-based analytics for advanced data science and machine learning scenarios.

### Benefits for FinOps

- **Advanced analytics**: Perform complex cost modeling and forecasting
- **Machine learning**: Build predictive models for cost optimization
- **Collaborative notebooks**: Share analysis with data science teams
- **Delta Lake support**: ACID transactions and versioning for data quality
- **Integration capabilities**: Connect to multiple data sources and tools

### Getting started with Databricks

1. **Create a Databricks workspace**
   - Deploy Azure Databricks in your Azure subscription
   - Configure cluster policies and security settings

2. **Mount Data Lake Storage**
   - Configure mount points to access FinOps data
   - Set up service principal authentication

3. **Create notebooks**
   - Develop analytics notebooks using Python, R, Scala, or SQL
   - Build cost optimization models and scenarios

### Databricks example

```python
# Mount Data Lake Storage
dbutils.fs.mount(
    source = "abfss://container@storage.dfs.core.windows.net/finops-data",
    mount_point = "/mnt/finops-data",
    extra_configs = {
        "fs.azure.account.auth.type.storage.oauth2.client.endpoint": "https://login.microsoftonline.com/tenant-id/oauth2/token"
    }
)

# Load and analyze FinOps data
from pyspark.sql import functions as F

# Read cost data
cost_df = spark.read.format("delta").load("/mnt/finops-data/costs/")

# Analyze spending patterns
monthly_trends = cost_df.groupBy(
    F.year("date").alias("year"),
    F.month("date").alias("month"),
    "service_name"
).agg(F.sum("effective_cost").alias("total_cost"))

# Build cost forecasting model
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.regression import LinearRegression

# Prepare features for ML model
assembler = VectorAssembler(inputCols=["month", "historical_avg"], outputCol="features")
model_data = assembler.transform(monthly_trends)

# Train linear regression model
lr = LinearRegression(featuresCol="features", labelCol="total_cost")
model = lr.fit(model_data)
```

<br>

## Azure Machine Learning

Azure Machine Learning provides enterprise-grade machine learning capabilities for building advanced cost optimization and forecasting models.

### Benefits for FinOps

- **MLOps capabilities**: End-to-end machine learning lifecycle management
- **Automated ML**: Automatically build and optimize cost prediction models
- **Model deployment**: Deploy models as web services for real-time predictions
- **Responsible AI**: Built-in tools for model interpretability and fairness
- **Integration**: Connect with other Azure services and tools

### Use cases for FinOps

- **Cost forecasting**: Predict future spending based on historical patterns
- **Anomaly detection**: Identify unusual cost spikes or patterns
- **Optimization recommendations**: Generate automated cost optimization suggestions
- **Budget planning**: Support budget planning with predictive insights

<br>

## Custom applications and APIs

Data Lake Storage provides REST APIs and SDKs that enable you to build custom applications and integrate FinOps data with existing systems.

### Benefits

- **Custom integrations**: Build integrations with existing business systems
- **Automated reporting**: Create automated report generation and distribution
- **Real-time monitoring**: Build custom monitoring and alerting solutions
- **API access**: Programmatic access to FinOps data for any application

### SDK examples

```python
# Python SDK example
from azure.storage.filedatalake import DataLakeServiceClient

# Initialize client
service_client = DataLakeServiceClient(
    account_url="https://storage.dfs.core.windows.net",
    credential=credential
)

# List files
file_system_client = service_client.get_file_system_client("finops-data")
paths = file_system_client.get_paths(path="costs/")

for path in paths:
    print(f"File: {path.name}")
```

```csharp
// C# SDK example
using Azure.Storage.Files.DataLake;

// Initialize client
var service = new DataLakeServiceClient(connectionString);
var fileSystem = service.GetFileSystemClient("finops-data");

// Read file contents
var fileClient = fileSystem.GetFileClient("costs/2024/01/costs.parquet");
var response = await fileClient.ReadAsync();
```

<br>

## Choosing the right tool

The choice of tool depends on your specific requirements:

| Tool | Best for | Complexity | Cost model |
|------|----------|------------|------------|
| **Azure Data Explorer** | Real-time analytics, KQL queries, built-in dashboards | Medium | Pay-per-use |
| **Microsoft Fabric** | Unified analytics platform, AI/ML integration | Medium-High | Capacity-based |
| **Azure Synapse** | Data warehousing, large-scale ETL, enterprise scenarios | High | Pay-per-use or dedicated |
| **Azure Databricks** | Advanced analytics, machine learning, data science | High | Pay-per-use |
| **Azure Machine Learning** | MLOps, automated ML, model deployment | High | Pay-per-use |
| **Custom applications** | Specific integrations, custom workflows | Variable | Development cost |

<br>

## Security and governance

When connecting to Data Lake Storage, ensure proper security and governance:

- **Authentication**: Use Azure Active Directory and managed identities
- **Authorization**: Implement role-based access control (RBAC)
- **Network security**: Configure private endpoints and network restrictions
- **Data classification**: Classify and protect sensitive financial data
- **Auditing**: Enable audit logging for access and operations

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20Data%20Lake%20Storage%20connectivity%20options%3F/cvaQuestion/How%20valuable%20are%20the%20Data%20Lake%20Storage%20connectivity%20options%3F/surveyId/FTK/bladeName/DataLakeConnectivity/featureName/Documentation)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%2B1-desc)

<br>

## Related content

Related resources:

- [FinOps Open Cost and Usage Specification (FOCUS)](../focus/what-is-focus.md)
- [Data ingestion best practices](../framework/understand/ingestion.md)

Related FinOps capabilities:

- [Reporting and analytics](../framework/understand/reporting.md)
- [Data analysis](../framework/understand/analysis.md)

Related products:

- [Azure Data Explorer](/azure/data-explorer/)
- [Microsoft Fabric](/fabric/get-started/microsoft-fabric-overview)
- [Azure Synapse Analytics](/azure/synapse-analytics/)
- [Azure Databricks](/azure/databricks/)
- [Azure Machine Learning](/azure/machine-learning/)
- [Azure Data Lake Storage](/azure/storage/blobs/data-lake-storage-introduction)

Related solutions:

- [FinOps hubs](hubs/finops-hubs-overview.md)
- [FinOps toolkit Power BI reports](power-bi/reports.md)
- [FinOps toolkit open data](open-data.md)

<br>