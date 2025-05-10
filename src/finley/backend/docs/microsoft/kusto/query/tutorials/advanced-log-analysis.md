# Advanced KQL Techniques for Log Analysis

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

This guide covers advanced Kusto Query Language (KQL) techniques specifically designed for effective log analysis. These patterns help security analysts, operations teams, and developers extract insights from large volumes of log data.

## Session Analysis

### Session Identification and Analysis

Identify and analyze user sessions based on activity patterns:

```kusto
// Define session timeout (30 minutes of inactivity)
let sessionTimeout = 30m;

Events
| where Timestamp > ago(1d)
| where EventType == "UserActivity"
| sort by UserId asc, Timestamp asc
| extend 
    SessionId = iff(
        isempty(prev(UserId)) or 
        UserId != prev(UserId) or 
        Timestamp > prev(Timestamp) + sessionTimeout, 
        guid(), 
        prev(SessionId)
    )
| summarize 
    SessionStart = min(Timestamp),
    SessionEnd = max(Timestamp),
    SessionDuration = max(Timestamp) - min(Timestamp),
    ActivityCount = count(),
    Activities = make_set(Activity)
    by UserId, SessionId
| where SessionDuration > 1m // Filter out very short sessions
```

### Funnel Analysis

Track users through a series of steps:

```kusto
let step1 = Events | where EventType == "PageView" and Page == "HomePage";
let step2 = Events | where EventType == "PageView" and Page == "ProductPage";
let step3 = Events | where EventType == "AddToCart";
let step4 = Events | where EventType == "Checkout";
let step5 = Events | where EventType == "Purchase";

let allSteps = 
    union
        (step1 | extend Step = 1, StepName = "Homepage View"),
        (step2 | extend Step = 2, StepName = "Product View"),
        (step3 | extend Step = 3, StepName = "Add to Cart"),
        (step4 | extend Step = 4, StepName = "Checkout"),
        (step5 | extend Step = 5, StepName = "Purchase");

// Funnel by unique users
allSteps
| summarize arg_min(Timestamp, *) by UserId, Step, StepName
| summarize Users = dcount(UserId) by Step, StepName
| order by Step asc
```

## Anomaly Detection

### Statistical Outlier Detection

Identify values that deviate significantly from normal patterns:

```kusto
// Z-score method for outlier detection
Events
| where Timestamp > ago(7d)
| summarize 
    RequestCount = count(),
    avg_count = avg(RequestCount),
    stdev_count = stdev(RequestCount)
    by bin(Timestamp, 1h), ServiceName
| extend
    ZScore = abs(RequestCount - avg_count) / stdev_count
| where ZScore > 3 // Values more than 3 standard deviations from mean
```

### Baseline Deviation Detection

Compare current activity to historical baselines:

```kusto
// Define baseline period and current period
let baselinePeriod = 7d;
let baselineStartTime = ago(baselinePeriod + 1d);
let baselineEndTime = ago(1d);
let currentStartTime = ago(1d);
let currentEndTime = now();

// Get baseline metrics
let baseline = Events
| where Timestamp between (baselineStartTime .. baselineEndTime)
| summarize 
    BaselineCount = count(),
    BaselineAvg = avg(ResponseTime),
    BaselineMax = max(ResponseTime),
    BaselineP95 = percentile(ResponseTime, 95)
    by bin(Timestamp, 1h), ServiceName;

// Compare current to baseline
Events
| where Timestamp between (currentStartTime .. currentEndTime)
| summarize 
    CurrentCount = count(),
    CurrentAvg = avg(ResponseTime),
    CurrentMax = max(ResponseTime),
    CurrentP95 = percentile(ResponseTime, 95)
    by bin(Timestamp, 1h), ServiceName
| join kind=leftouter (baseline) on Timestamp, ServiceName
| extend
    CountChange = CurrentCount - BaselineCount,
    CountPercentChange = iff(BaselineCount == 0, 0.0, 100.0 * (CurrentCount - BaselineCount) / BaselineCount),
    AvgPercentChange = 100.0 * (CurrentAvg - BaselineAvg) / BaselineAvg
| where abs(CountPercentChange) > 25 or abs(AvgPercentChange) > 50
```

## Pattern Detection

### Sequence Pattern Detection

Identify specific sequences of events:

```kusto
// Define patterns to search for (e.g., failed login followed by successful login)
let failedLoginPattern = Events 
| where EventType == "Login" and Status == "Failed";

let successfulLoginPattern = Events 
| where EventType == "Login" and Status == "Success";

// Find sequence: failed login followed by successful login within 5 minutes
failedLoginPattern
| project FailedTimestamp = Timestamp, UserId, ClientIP
| join kind=inner (
    successfulLoginPattern
    | project SuccessTimestamp = Timestamp, UserId, ClientIP
) on UserId, ClientIP
| where SuccessTimestamp between (FailedTimestamp .. (FailedTimestamp + 5m))
| summarize 
    FailedAttempts = count(),
    FirstFailure = min(FailedTimestamp),
    LastSuccess = max(SuccessTimestamp)
    by UserId, ClientIP
| order by FailedAttempts desc
```

### Pattern Clustering

Group similar events using pattern recognition:

```kusto
// Extract and cluster error messages
Logs
| where Level == "Error"
| extend MessageTemplate = replace_regex(
    Message,
    @'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})', '<guid>'
)
| extend MessageTemplate = replace_regex(
    MessageTemplate,
    @'\b([0-9]+)\b', '<number>'
)
| summarize 
    Count = count(),
    Examples = take_any(Message, 3),
    FirstSeen = min(Timestamp),
    LastSeen = max(Timestamp)
    by MessageTemplate
| order by Count desc
```

## Distributed Tracing Analysis

### Trace Correlation and Path Analysis

Track requests across distributed systems:

```kusto
// Join traces from different services using correlation IDs
let appLogs = AppServiceLogs
| where Timestamp > ago(1h)
| project Timestamp, TraceId, SpanId, ParentSpanId, ServiceName="AppService", Message;

let dbLogs = DatabaseLogs
| where Timestamp > ago(1h)
| project Timestamp, TraceId, SpanId, ParentSpanId, ServiceName="Database", Message;

let apiLogs = ApiLogs
| where Timestamp > ago(1h)
| project Timestamp, TraceId, SpanId, ParentSpanId, ServiceName="API", Message;

// Combine all logs
let allLogs = union appLogs, dbLogs, apiLogs;

// Find complete traces
allLogs
| where isnotempty(TraceId)
| summarize 
    EndToEndDuration = max(Timestamp) - min(Timestamp),
    ServicesInvolved = make_set(ServiceName),
    SpanCount = dcount(SpanId)
    by TraceId
| where array_length(ServicesInvolved) >= 3 // Traces that touch all services
| top 100 by EndToEndDuration desc
```

## Resource Attribution Analysis

### Resource Attribution and Trend Analysis

Analyze resource usage and attribute it to services or operations:

```kusto
// Analyze CPU utilization by service and operation
Metrics
| where MetricName == "cpu_percent"
| summarize 
    AvgCPU = avg(Value),
    MaxCPU = max(Value),
    P95CPU = percentile(Value, 95)
    by ServiceName, OperationName, bin(Timestamp, 1h)
| order by AvgCPU desc

// Analyze trends over time
Metrics
| where MetricName == "cpu_percent" or MetricName == "memory_percent"
| make-series 
    MetricAvg = avg(Value) 
    on Timestamp from ago(7d) to now() step 1h
    by ServiceName, MetricName
| extend (Trend, Seasonality, Residual) = series_decompose(MetricAvg)
| project ServiceName, MetricName, Timestamp, MetricAvg, Trend
```

## Advanced Text Analysis

### Log Text Mining

Extract structured information from unstructured log text:

```kusto
// Extract IP addresses from messages
Logs
| where TimeGenerated > ago(1d)
| extend ExtractedIP = extract(@"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})", 1, Message)
| where isnotempty(ExtractedIP)
| summarize 
    Count = count(),
    FirstSeen = min(TimeGenerated),
    LastSeen = max(TimeGenerated),
    Sources = make_set(SourceSystem, 10)
    by ExtractedIP
| order by Count desc

// Extract JSON from messages
Logs
| where TimeGenerated > ago(1d)
| extend JsonText = extract(@"({.*})", 1, Message)
| where isnotempty(JsonText)
| extend ParsedJson = parse_json(JsonText)
| project TimeGenerated, ParsedJson, Message
```

## Advanced Time Window Analysis

### Rolling Window Calculations

Calculate metrics over rolling time windows:

```kusto
// Calculate 15-minute rolling average with 5-minute steps
let startTime = ago(4h);
let endTime = now();
let windowSize = 15m;
let windowStep = 5m;

Metrics
| where Timestamp between (startTime .. endTime)
| where MetricName == "RequestCount"
| make-series RequestSum = sum(Value) on Timestamp from startTime to endTime step windowStep
| extend RollingAvg = series_fir(RequestSum, repeat(1, windowSize / windowStep), true)
| mvexpand Timestamp to typeof(datetime), RequestSum to typeof(long), RollingAvg to typeof(double)
| project Timestamp, RequestSum, RollingAvg
```

## Best Practices for Advanced KQL

1. **Balance complexity with readability** - Document complex queries with comments
2. **Use let statements for modularity** - Break complex logic into named components
3. **Test on small data samples first** - Validate complex patterns with limited data
4. **Consider performance implications** - Monitor query execution statistics
5. **Build a library of reusable patterns** - Create functions for common analysis patterns

## See Also

- [Time Series Analysis](../time-series-analysis.md)
- [Python Integration](../plugins/python-integration.md)
- [Advanced Join Techniques](../operators/join-advanced.md)
