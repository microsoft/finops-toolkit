# Cost allocation

Splitting shared cost across the teams that consume it. Two distinct problems with different solutions.

`cost-allocation` covers the showback/chargeback model design. This page covers the arithmetic.

## Which problem are you solving?

| Consumer is...                                             | Native Azure allocation?        | Method                                                |
| ---------------------------------------------------------- | ------------------------------- | ----------------------------------------------------- |
| A subscription, resource group, or tag                     | **Yes** — cost allocation rules | Write a rule; cost moves in Cost Management           |
| A hub resource shared by spoke subscriptions               | Partly                          | Split by a measured key, then optionally write a rule |
| A Kubernetes namespace, APIM product, or OpenAI deployment | **No**                          | Telemetry-keyed showback only                         |

That last row is the trap. Azure cost allocation rules can only key on **SubscriptionId, ResourceGroupName, or Tag**. A namespace is none of those. Any split you produce for it is a reporting artifact — it can never be written back into Cost Management, and presenting it as though it can is a promise you can't keep.

## Shared hub cost

Shared connectivity — ExpressRoute gateway and circuit, VPN gateway, Azure Firewall, shared bandwidth — bills entirely to the hub subscription. Cost Management cannot tell which spoke generated which gigabyte, because the split key lives in network telemetry rather than billing data.

### The split model

```text
spoke_i = (Fixed / nSpokes) + (Variable × weight_i / totalWeight)

Fixed    = pool × FixedRatio           split evenly
Variable = pool × (1 − FixedRatio)     split by measured weight
```

The fixed component exists because a gateway costs money at zero traffic. Splitting the whole pool by transfer volume charges a spoke that sent nothing exactly nothing, which is wrong — it still had the circuit available.

A `FixedRatio` of 0.3 to 0.5 is a reasonable starting point for connectivity. State the ratio you used; it's a policy decision, not a fact.

### Weighting providers, best to worst

| Provider           | Accuracy | Source                                                 |
| ------------------ | -------- | ------------------------------------------------------ |
| `inline`           | Exact    | Caller supplies a measured GB/TB map                   |
| `trafficAnalytics` | Exact    | Traffic Analytics / VNet flow logs in Log Analytics    |
| `resourceCount`    | Proxy    | Billable resource count per spoke, from Resource Graph |
| `equal`            | None     | Even split                                             |

**Per-spoke ExpressRoute attribution is impossible from billing data alone.** It requires the flow-log key. Without flow logs you are estimating — label the output that way rather than presenting a proxy split as measured.

### Reporting it

Each spoke's full solution cost is its own resources **plus** its allocated share. Reporting only the allocated share understates what the team actually consumes, and reporting only their own resources hides the shared cost entirely — which is the problem you started with.

## Telemetry-keyed showback

For consumers with no billing dimension, pull a usage signal from Log Analytics and apportion the pool by it.

### AKS namespace

Source: Container Insights.

```kusto
InsightsMetrics
| where TimeGenerated >= ago(30d)
| where Name in ('cpuUsageNanoCores', 'memoryWorkingSetBytes')
| extend ns = tostring(parse_json(Tags)['container.azm.ms/namespace'])
| where isnotempty(ns)
| summarize cpuCores = avgif(Val, Name == 'cpuUsageNanoCores') / 1000000000.0,
            memGB = avgif(Val, Name == 'memoryWorkingSetBytes') / 1073741824.0
        by ns
| extend Weight = cpuCores + (memGB / 4.0)
| project Consumer = ns, Weight
```

The `cpuCores + (memGB / 4)` blend approximates how AKS node SKUs are actually priced — roughly 4 GB of memory per vCPU. Weighting on CPU alone overcharges compute-light, memory-heavy workloads.

### APIM by product or subscription

Source: workspace-based Application Insights.

```kusto
AppMetrics
| where TimeGenerated >= ago(30d)
| where Name in ('Total Tokens', 'Tokens', 'TotalTokens', 'total_tokens')
| extend consumer = tostring(Properties['Subscription Id'])
| where isnotempty(consumer)
| summarize Weight = sum(Sum) by Consumer = consumer
```

Swap the `Properties[...]` key for `API ID` or `Product` depending on which consumer you're charging. The metric name varies by APIM version, hence the `in (...)` list.

### Azure OpenAI by deployment

Source: Azure Monitor metrics.

```kusto
AzureMetrics
| where TimeGenerated >= ago(30d)
| where ResourceProvider == 'MICROSOFT.COGNITIVESERVICES'
| where MetricName in ('ProcessedPromptTokens', 'GeneratedTokens', 'TokenTransaction', 'ProcessedInferenceTokens')
| summarize Weight = sum(Total) by Consumer = Resource
```

**Prompt and generated tokens are not priced the same.** Summing them into one weight is a simplification. If the split drives real chargeback, weight them separately at their respective rates.

### Any custom consumer

The pattern generalizes: a query returning two columns, `Consumer` (string) and `Weight` (number). Everything downstream is the same apportionment.

## Applying the split

Once weights exist:

```text
consumer_i = pool × (weight_i / totalWeight)
```

Then decide what happens to it:

- **Subscription, resource group, or tag consumers** — writable as a native cost allocation rule. Percentages are normalized to sum to 100.
- **Everything else** — showback only. Report it; don't imply Cost Management will reflect it.

## Sanity checks before reporting

- **Do the parts sum to the pool?** Rounding across many consumers drifts. Reconcile and put the remainder somewhere explicit.
- **Is the telemetry window the same as the cost window?** 30 days of usage against a calendar month of cost is a mismatch that nobody notices until the numbers are questioned.
- **Did every consumer emit telemetry?** A namespace with no metrics gets zero weight and therefore zero cost, which is almost never true. Flag missing consumers rather than silently charging them nothing.
- **Is the pool the right pool?** Resolve the shared resources explicitly. Sweeping in a resource group can pick up non-shared resources and inflate every share.

## Related

- `cost-allocation` skill for the showback/chargeback model and tag strategy
- `tags-and-policy.md` for the tag coverage that native allocation depends on
- `azure-cost-management` → `references/azure-cost-exports.md` for the underlying cost data
