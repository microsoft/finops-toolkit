# Azure Data Explorer API Reference

Azure Data Explorer provides a set of REST APIs and client libraries that allow you to manage resources and query data programmatically.

## API Categories

### Data Plane APIs

These APIs are used for querying data and managing database objects:

- **Query API**: Execute KQL queries against Azure Data Explorer clusters
- **Management API**: Manipulate schema objects like databases, tables, and functions
- **Ingestion API**: Ingest data into Azure Data Explorer tables

### Control Plane APIs

These APIs are used for managing Azure Data Explorer clusters:

- **Cluster Management**: Create, modify, and delete clusters
- **Subscription Management**: Manage subscriptions and resource groups
- **Security Management**: Manage identity and access

## Client Libraries

Azure Data Explorer offers client libraries in several programming languages:

| Language | Client Libraries |
|----------|------------------|
| .NET | Azure.Data.Kusto, Microsoft.Azure.Kusto.Data, Microsoft.Azure.Kusto.Ingest |
| Python | azure-kusto-data, azure-kusto-ingest |
| Java | azure-kusto-data, azure-kusto-ingest |
| Node.js | azure-kusto-data, azure-kusto-ingest |
| Go | kusto |

## Common API Tasks

### Querying Data

Use the Query API to execute KQL queries against your Azure Data Explorer cluster. Example in .NET:

```csharp
using Kusto.Data;
using Kusto.Data.Common;
using Kusto.Data.Net.Client;

// Create client
var kcsb = new KustoConnectionStringBuilder("https://clustername.region.kusto.windows.net")
{
    FederatedSecurity = true,
    InitialCatalog = "databaseName"
};

using (var client = KustoClientFactory.CreateCslQueryProvider(kcsb))
{
    // Execute query
    var query = "StormEvents | take 10";
    var reader = client.ExecuteQuery(query);
    
    // Process results
    while (reader.Read())
    {
        // Access columns by name or index
        var eventType = reader["EventType"];
        var startTime = reader.GetDateTime(1);
    }
}
```

### Data Ingestion

Use the Ingestion API to load data into Azure Data Explorer. Example in Python:

```python
from azure.kusto.data import KustoConnectionStringBuilder
from azure.kusto.ingest import QueuedIngestClient, IngestionProperties, FileDescriptor

# Create connection string
kcsb = KustoConnectionStringBuilder.with_aad_device_authentication("https://ingest-clustername.region.kusto.windows.net")
kcsb.authority_id = "microsoft.com"

# Create client
client = QueuedIngestClient(kcsb)

# Define ingestion properties
ingestion_props = IngestionProperties(
    database="databaseName",
    table="tableName",
    data_format="csv"
)

# Ingest data
file_descriptor = FileDescriptor("data.csv", 0)
client.ingest_from_file(file_descriptor, ingestion_properties=ingestion_props)
```

## Authentication Methods

All Azure Data Explorer APIs support multiple authentication methods:

- Azure Active Directory (Microsoft Entra ID) authentication
- Azure Active Directory application authentication
- Azure Active Directory user authentication
- Access tokens

## Rate Limits and Best Practices

- Implement retry logic with exponential backoff for transient failures
- Use connection pooling for better performance
- Monitor API usage to stay within rate limits
- Consider batching operations when possible
- Use appropriate timeouts for your operations

## More Information

For detailed API references and examples, see:

- [Query API Reference](/azure/data-explorer/kusto/api/netfx/about-kusto-data)
- [Management API Reference](/azure/data-explorer/kusto/management)
- [Ingestion API Reference](/azure/data-explorer/kusto/api/netfx/about-kusto-ingest)
- [REST API Reference](/rest/api/azurerekusto)
