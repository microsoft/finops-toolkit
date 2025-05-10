# Machine Learning in KQL

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Kusto Query Language (KQL) provides built-in machine learning capabilities that enable advanced analytics without requiring external ML tools or services. This document explores the ML functions, plugins, and techniques available in KQL.

## Overview of Machine Learning in KQL

KQL offers several approaches to machine learning:

1. **Native ML functions**: Built-in functions for common ML tasks
2. **Python & R integration**: For custom ML algorithms
3. **ML plugins**: Pre-built modules for specific ML tasks

## Native ML Functions

### Anomaly Detection

KQL provides several functions for detecting anomalies in time series data:

#### series_decompose_anomalies()

Applies time series decomposition and returns anomaly points:

```kusto
let min_t = datetime(2019-01-01);
let max_t = datetime(2019-02-01);
let dt = 1h;
demo_make_series2
| make-series num=avg(num) on TimeStamp from min_t to max_t step dt
| extend (anomalies, score, baseline) = series_decompose_anomalies(num, 1.5, -1, 'linefit')
| render anomalychart with(anomalycolumns=anomalies)
```

#### series_detect_outliers()

Identifies statistical outliers in a time series:

```kusto
let min_t = datetime(2019-01-01);
let max_t = datetime(2019-02-01);
let dt = 1h;
demo_make_series2
| make-series num=avg(num) on TimeStamp from min_t to max_t step dt
| extend outliers = series_detect_outliers(num, 1.5)
| render anomalychart with(anomalycolumns=outliers)
```

### Forecasting

#### series_decompose_forecast()

Predicts future values based on seasonal decomposition:

```kusto
let min_t = datetime(2019-01-01);
let max_t = datetime(2019-02-01);
let dt = 1h;
let horizon = 24h;
demo_make_series2
| make-series num=avg(num) on TimeStamp from min_t to max_t step dt
| extend forecast = series_decompose_forecast(num, toint(horizon/dt))
| render timechart with(title='Forecasting the next 24 hours')
```

### Clustering

#### autocluster

Groups similar events based on common attribute patterns:

```kusto
Events
| where EventType == "Error"
| evaluate autocluster()
```

#### basket

Discovers frequent patterns in the data:

```kusto
Events
| evaluate basket()
```

## The Python Plugin

The `python()` plugin allows executing Python code as part of a KQL query, enabling custom ML models:

```kusto
ExternalData
| extend dimension1 = toreal(dimension1), dimension2 = toreal(dimension2)
| python
    // Complete code block
    ```
    from sklearn.cluster import KMeans
    import pandas as pd
    import numpy as np
    
    # Get data from KQL
    df = kql_input_df
    
    # Select features for clustering
    features = df[['dimension1', 'dimension2']]
    
    # Create and fit KMeans model
    kmeans = KMeans(n_clusters=3, random_state=0).fit(features)
    
    # Add cluster labels to dataframe
    df['cluster'] = kmeans.labels_
    
    # Calculate cluster centers
    centers = kmeans.cluster_centers_
    
    # Return augmented dataframe
    result = df
    ```
| project dimension1, dimension2, cluster
| render scatterchart with (xcolumn=dimension1, ycolumn=dimension2, series=cluster)
```

## Advanced ML Techniques

### Multivariate Anomaly Detection

Detect anomalies across multiple metrics simultaneously:

```kusto
let min_t = datetime(2019-01-01);
let max_t = datetime(2019-02-01);
let dt = 1h;
demo_make_series3
| make-series 
    cpu=avg(cpu) on TimeStamp from min_t to max_t step dt,
    memory=avg(memory) on TimeStamp from min_t to max_t step dt,
    network=avg(network) on TimeStamp from min_t to max_t step dt
| extend series_mvad = series_mv_anomalies(pack_array(cpu, memory, network), 1.5)
| mv-expand series_mvad
| extend anomaly_cpu = series_mvad[0], anomaly_mem = series_mvad[1], anomaly_net = series_mvad[2]
```

### Time Series Decomposition

Decompose a time series into trend, seasonality, and residuals:

```kusto
let min_t = datetime(2019-01-01);
let max_t = datetime(2019-02-01);
let dt = 1h;
demo_make_series2
| make-series num=avg(num) on TimeStamp from min_t to max_t step dt
| extend (baseline, seasonal, trend, residual) = series_decompose(num, 'linefit')
| render timechart with(title='Time Series Decomposition')
```

### Root Cause Analysis

Identify factors contributing to an anomaly:

```kusto
let startTime = ago(7d);
let endTime = ago(1d);
let anomalyTime = ago(3d);
Events
| where TimeGenerated between (startTime .. endTime)
| where EventType == "Error"
| evaluate topk_by_anomalies(EventName, TimeGenerated, 5, 10, anomalyTime, 1h, 1)
```

## Implementing Common ML Scenarios

### Customer Segmentation

Segment customers based on behavior patterns:

```kusto
// Using K-means clustering
UserEvents
| where Timestamp > ago(30d)
| summarize 
    LoginCount = countif(EventName == "Login"),
    PurchaseCount = countif(EventName == "Purchase"),
    TotalAmount = sumif(Amount, EventName == "Purchase"),
    LastSeen = max(Timestamp)
    by UserId
| extend DaysSinceLastSeen = datetime_diff('day', now(), LastSeen)
| where isnotempty(UserId)
| project-away LastSeen
| python
    ```
    from sklearn.preprocessing import StandardScaler
    from sklearn.cluster import KMeans
    import pandas as pd
    
    # Prepare features
    features = df[['LoginCount', 'PurchaseCount', 'TotalAmount', 'DaysSinceLastSeen']]
    
    # Standardize features
    scaler = StandardScaler()
    features_scaled = scaler.fit_transform(features)
    
    # Apply K-means clustering
    kmeans = KMeans(n_clusters=4, random_state=0)
    df['Segment'] = kmeans.fit_predict(features_scaled)
    
    # Create meaningful segment names
    segment_map = {
        0: 'High Value',
        1: 'Engaged',
        2: 'New',
        3: 'At Risk'
    }
    
    df['SegmentName'] = df['Segment'].map(segment_map)
    
    # Return the result
    result = df
    ```
| project UserId, LoginCount, PurchaseCount, TotalAmount, DaysSinceLastSeen, SegmentName
```

### Intelligent Alerting

Create ML-based alert thresholds that adapt to patterns:

```kusto
// Dynamic threshold calculation
let history = 
    Perf
    | where TimeGenerated between (ago(30d) .. ago(1d))
    | where CounterName == "% Processor Time";
let current = 
    Perf
    | where TimeGenerated > ago(1d)
    | where CounterName == "% Processor Time";
// Calculate dynamic thresholds from historical data
let thresholds = 
    history
    | make-series CPU=avg(CounterValue) on TimeGenerated from ago(30d) to ago(1d) step 1h by Computer
    | extend (anomalies, ModelParams) = series_decompose_anomalies(CPU)
    | project Computer, ModelParams;
// Apply thresholds to current data
current
| join kind=inner (thresholds) on Computer
| invoke series_detect_anomalies_fl(TimeGenerated, CounterValue, ModelParams)
| where IsAnomaly == 1
| project 
    Computer,
    TimeGenerated,
    CounterValue,
    ExpectedValue,
    UpperLimit,
    LowerLimit
```

### Predictive Maintenance

Predict equipment failures before they occur:

```kusto
// Train a model to predict failures
DeviceTelemetry
| where Timestamp between (ago(90d) .. ago(1d))
| extend 
    IsPreFailure = Timestamp > FailureTime - 24h and Timestamp < FailureTime,
    Features = pack('Temperature', Temperature, 'Pressure', Pressure, 'Vibration', Vibration)
| summarize 
    Features = make_list(Features),
    Label = max(IsPreFailure)
    by DeviceId, bin(Timestamp, 1h)
| invoke python(```
    import pandas as pd
    from sklearn.ensemble import RandomForestClassifier
    import pickle
    import base64
    
    # Prepare data
    X = pd.json_normalize(df['Features'].apply(lambda x: x))
    y = df['Label']
    
    # Train model
    model = RandomForestClassifier(n_estimators=100)
    model.fit(X, y)
    
    # Serialize model
    model_bytes = pickle.dumps(model)
    model_b64 = base64.b64encode(model_bytes).decode('utf-8')
    
    # Return model
    result = pd.DataFrame({'ModelBlob': [model_b64]})
    ```)
| project ModelBlob
```

## Best Practices

1. **Preprocess data**: Clean and normalize data before applying ML functions
2. **Choose appropriate algorithms**: Select ML functions that match your use case
3. **Handle seasonality**: Account for daily, weekly, or monthly patterns
4. **Cross-validate**: Test ML models on different data segments
5. **Performance considerations**: For large datasets, use sampling or aggregation
6. **Combine techniques**: Use multiple ML functions for complex scenarios
7. **Visualize results**: Use `render` to visualize ML outputs

## Limitations

1. Resource constraints for complex ML operations
2. Limited support for very large models
3. Python sandbox restrictions
4. Need for retraining ML models regularly

## See Also

- [Python Integration](plugins/python-integration.md)
- [Time Series Analysis](time-series-analysis.md)
- [Anomaly Detection](anomaly-detection.md)
