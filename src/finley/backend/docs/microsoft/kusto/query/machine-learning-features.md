# Machine Learning and AIOps in Kusto Query Language

Kusto Query Language (KQL) provides powerful built-in time series analysis and machine learning capabilities that enable anomaly detection, forecasting, and root cause analysis.

## Anomaly Diagnosis for Root Cause Analysis

KQL has built-in anomaly detection and forecasting functions to check for anomalous behavior. Once such a pattern is detected, a Root Cause Analysis (RCA) can be run to mitigate or resolve the anomaly.

The diagnosis process typically includes:
1. Fetching and joining more data from different sources for the same time frame
2. Looking for changes in the distribution of values on multiple dimensions
3. Charting more variables
4. Other techniques based on domain knowledge and intuition

Machine learning plugins are available to make the diagnosis phase easier, and shorten the duration of the RCA:

- `autocluster`: Clusters a single record set
- `basket`: Clusters a single record set
- `diffpatterns`: Clusters the differences between two record sets

## Machine Learning Capabilities

KQL offers two approaches to implementing machine learning in your queries:

### 1. Built-in KQL Machine Learning Capabilities

**Advantages**:
- Gets you started very quickly
- No data science knowledge and programming skills required
- Optimal performance and cost savings

**Best for**:
- Anomaly detection
- Root cause analysis
- Time series analysis

### 2. Create Your Own Machine Learning Pipeline

**Advantages**:
- Supports larger scales
- Enables advanced, more complex scenarios
- Flexibility in choosing libraries, models, parameters

**Best for**:
- Anomaly detection
- Root cause analysis
- Time series analysis
- Advanced analysis and AIOps scenarios

## Python Plugin Integration

The Python plugin allows you to embed Python code in KQL queries, extending KQL native functionalities with Python packages. This enables:

- Advanced machine learning algorithms
- Artificial intelligence applications
- Statistical analysis
- Time series forecasting

Example usage:

```kusto
T
| evaluate python(typeof(*),
```
with Python code here
```
)
```

## Integration with Other Tools

KQL can be integrated with several tools for enhanced machine learning capabilities:

- **Apache Spark**: For machine learning, ETL, and log analytics scenarios
- **Matlab**: For analyzing data, developing algorithms, and creating models
- **Real-Time Intelligence in Microsoft Fabric**: For ingestion, export, query, and visualization

These integrations provide additional flexibility for implementing more complex machine learning solutions on your data.
