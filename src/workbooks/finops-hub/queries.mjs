import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const queryDir = resolve(dirname(fileURLToPath(import.meta.url)), "../../queries/catalog");
const catalogQuery = (name) => readFileSync(resolve(queryDir, name), "utf8").trim();

export const foundryInventoryQuery = `resources
| where type in~ (
    'microsoft.cognitiveservices/accounts',
    'microsoft.cognitiveservices/accounts/projects',
    'microsoft.cognitiveservices/accounts/deployments'
)
| extend ParentAccountId=iff(
    type =~ 'microsoft.cognitiveservices/accounts',
    id,
    substring(id, 0, indexof(tolower(id), '/projects/')))
| summarize
    Resources=count(),
    Accounts=countif(type =~ 'microsoft.cognitiveservices/accounts'),
    Projects=countif(type =~ 'microsoft.cognitiveservices/accounts/projects'),
    Deployments=countif(type =~ 'microsoft.cognitiveservices/accounts/deployments')
    by subscriptionId, resourceGroup, location, ParentAccountId
| order by subscriptionId asc, resourceGroup asc, ParentAccountId asc`;

export const foundryCostQuery = `Costs()
| where ChargePeriodStart between (datetime({TimeRange:start}) .. datetime({TimeRange:end}))
| where x_ResourceType startswith_cs 'microsoft.cognitiveservices/accounts'
| summarize
    BilledCost=sum(BilledCost),
    EffectiveCost=sum(EffectiveCost),
    UsageQuantity=sum(ConsumedQuantity)
    by ChargeMonth=startofmonth(ChargePeriodStart),
        SubAccountId,
        RegionId,
        ResourceId,
        ResourceName,
        x_SkuMeterCategory,
        x_SkuMeterSubcategory,
        SkuMeter,
        BillingCurrency,
        ConsumedUnit
| order by ChargeMonth asc, SubAccountId asc, ResourceName asc, SkuMeter asc`;

export const tokenMetrics = [
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-ProcessedPromptTokens",
        aggregation: 7,
        columnName: "Input tokens",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-GeneratedTokens",
        aggregation: 7,
        columnName: "Output tokens",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-TokenTransaction",
        aggregation: 7,
        columnName: "Total tokens",
    },
];

export const requestMetrics = [
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-AzureOpenAIRequests",
        aggregation: 7,
        columnName: "Model requests",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-AzureOpenAIRequests",
        aggregation: 7,
        splitBy: [
            "StatusCode"
        ],
        splitBySortOrder: -1,
        columnName: "Requests by status code",
    },
];

export const latencyMetrics = [
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-AzureOpenAITimeToResponse",
        aggregation: 4,
        columnName: "Time to response",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-AzureOpenAITTLTInMS",
        aggregation: 4,
        columnName: "Time to last byte",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-AzureOpenAITokenPerSecond",
        aggregation: 4,
        columnName: "Tokens per second",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-AzureOpenAIContextTokensCacheMatchRate",
        aggregation: 4,
        columnName: "Prompt cache match rate",
    },
];

export const foundryAgentsQuery = `set query_results_cache_max_age = time(30s);
set best_effort=true;
let StartTime = datetime({TimeRange:start});
let EndTime = datetime({TimeRange:end});
let Bucket = case(
    EndTime - StartTime <= 1d, 15m,
    EndTime - StartTime <= 7d, 1h,
    EndTime - StartTime <= 30d, 6h,
    1d);
let Base = materialize(
    union isfuzzy=true withsource=SourceTable AppDependencies, AppTraces
    | where TimeGenerated >= StartTime and TimeGenerated < EndTime
    | extend
        SpanName=tostring(column_ifexists('Name', '')),
        SpanProperties=column_ifexists('Properties', dynamic({})),
        SpanSuccess=tobool(column_ifexists('Success', true)),
        SpanDurationMs=todouble(column_ifexists('DurationMs', 0.0))
    | extend
        OperationName=tostring(SpanProperties['gen_ai.operation.name']),
        AgentName=tostring(SpanProperties['gen_ai.agent.name']),
        AgentId=tostring(SpanProperties['gen_ai.agent.id']),
        FoundryProjectId=tolower(tostring(SpanProperties['microsoft.foundry.project.id'])),
        InputTokens=tolong(SpanProperties['gen_ai.usage.input_tokens']),
        CachedInputTokens=tolong(SpanProperties['gen_ai.usage.cache_read.input_tokens']),
        OutputTokens=tolong(SpanProperties['gen_ai.usage.output_tokens']),
        RequestModel=tostring(SpanProperties['gen_ai.request.model']),
        ResponseModel=tostring(SpanProperties['gen_ai.response.model']),
        FinishReason=tostring(SpanProperties['gen_ai.response.finish_reasons']),
        ToolName=tostring(SpanProperties['gen_ai.tool.name']),
        ErrorType=tostring(SpanProperties['error.type'])
    | extend
        AgentKey=iff(isnotempty(AgentId), AgentId, AgentName),
        Model=iff(isnotempty(ResponseModel), ResponseModel, RequestModel)
    | project
        SourceTable,
        TimeGenerated,
        OperationId,
        SpanName,
        SpanSuccess,
        SpanDurationMs,
        OperationName,
        AgentName,
        AgentId,
        FoundryProjectId,
        InputTokens,
        CachedInputTokens,
        OutputTokens,
        Model,
        FinishReason,
        ToolName,
        ErrorType,
        AgentKey
);
let AgentIdentities = Base
    | where isnotempty(AgentKey) and isnotempty(FoundryProjectId)
    | project TimeGenerated, OperationId, AgentKey, AgentName, AgentId, FoundryProjectId;
let TraceIdentities = AgentIdentities
    | summarize
        TraceAgentCount=dcount(strcat(AgentKey, '|', FoundryProjectId)),
        TraceAgentKey=take_any(AgentKey),
        TraceAgentName=take_any(AgentName),
        TraceAgentId=take_any(AgentId),
        TraceFoundryProjectId=take_any(FoundryProjectId)
        by OperationId;
let AgentInvocations = Base
    | where SourceTable endswith 'AppDependencies'
    | where SpanName has 'invoke_agent' or OperationName =~ 'invoke_agent'
    | where isnotempty(AgentKey) and isnotempty(FoundryProjectId)
    | project
        TimeGenerated,
        OperationId,
        AgentKey,
        AgentName,
        AgentId,
        FoundryProjectId,
        DurationMs=SpanDurationMs,
        Success=SpanSuccess,
        ErrorType;
let ChatSpans = Base
    | where OperationName =~ 'chat'
    | lookup kind=leftouter TraceIdentities on OperationId
    | extend
        AssignedAgentKey=iff(isnotempty(AgentKey), AgentKey, iff(TraceAgentCount == 1, TraceAgentKey, '')),
        AssignedAgentName=iff(isnotempty(AgentKey), AgentName, iff(TraceAgentCount == 1, TraceAgentName, '')),
        AssignedAgentId=iff(isnotempty(AgentKey), AgentId, iff(TraceAgentCount == 1, TraceAgentId, '')),
        AssignedFoundryProjectId=iff(isnotempty(FoundryProjectId), FoundryProjectId, iff(TraceAgentCount == 1, TraceFoundryProjectId, ''))
    | where isnotempty(AssignedAgentKey) and isnotempty(AssignedFoundryProjectId)
    | project
        TimeGenerated,
        OperationId,
        AgentKey=AssignedAgentKey,
        AgentName=AssignedAgentName,
        AgentId=AssignedAgentId,
        FoundryProjectId=AssignedFoundryProjectId,
        Model,
        InputTokens=max_of(0, InputTokens),
        CachedInputTokens=max_of(0, CachedInputTokens),
        OutputTokens=max_of(0, OutputTokens),
        DurationMs=SpanDurationMs,
        FinishReason;
let ToolSpans = Base
    | where OperationName =~ 'execute_tool'
    | lookup kind=leftouter TraceIdentities on OperationId
    | extend
        AssignedAgentKey=iff(isnotempty(AgentKey), AgentKey, iff(TraceAgentCount == 1, TraceAgentKey, '')),
        AssignedAgentName=iff(isnotempty(AgentKey), AgentName, iff(TraceAgentCount == 1, TraceAgentName, '')),
        AssignedAgentId=iff(isnotempty(AgentKey), AgentId, iff(TraceAgentCount == 1, TraceAgentId, '')),
        AssignedFoundryProjectId=iff(isnotempty(FoundryProjectId), FoundryProjectId, iff(TraceAgentCount == 1, TraceFoundryProjectId, ''))
    | where isnotempty(AssignedAgentKey) and isnotempty(AssignedFoundryProjectId)
    | project
        TimeGenerated,
        OperationId,
        AgentKey=AssignedAgentKey,
        AgentName=AssignedAgentName,
        AgentId=AssignedAgentId,
        FoundryProjectId=AssignedFoundryProjectId,
        ToolName,
        DurationMs=SpanDurationMs,
        Success=SpanSuccess,
        ErrorType;
let Activity = AgentIdentities
    | summarize ActivityEvents=count(), LastSeen=max(TimeGenerated)
        by AgentKey, AgentName, AgentId, FoundryProjectId;
let InvocationSummary = AgentInvocations
    | summarize
        Operations=count(),
        Successes=countif(Success != false and isempty(ErrorType)),
        Errors=countif(Success == false or isnotempty(ErrorType)),
        TotalDurationMs=sum(DurationMs),
        AverageLatencyMs=avg(DurationMs),
        P95LatencyMs=percentile(DurationMs, 95)
        by AgentKey, FoundryProjectId;
let ChatSummary = ChatSpans
    | summarize
        InputTokens=sum(InputTokens),
        CachedInputTokens=sum(CachedInputTokens),
        OutputTokens=sum(OutputTokens)
        by AgentKey, FoundryProjectId;
let AgentSummary = materialize(
    Activity
    | lookup kind=leftouter InvocationSummary on AgentKey, FoundryProjectId
    | lookup kind=leftouter ChatSummary on AgentKey, FoundryProjectId
    | project
        RowType='AgentSummary',
        AgentKey,
        AgentName,
        AgentId,
        FoundryProjectId,
        ActivityEvents,
        Operations=coalesce(Operations, 0),
        Successes=coalesce(Successes, 0),
        Errors=coalesce(Errors, 0),
        TotalDurationMs=coalesce(TotalDurationMs, 0.0),
        AverageLatencyMs=coalesce(AverageLatencyMs, 0.0),
        P95LatencyMs=coalesce(P95LatencyMs, 0.0),
        LastSeen,
        InputTokens=coalesce(InputTokens, 0),
        CachedInputTokens=coalesce(CachedInputTokens, 0),
        OutputTokens=coalesce(OutputTokens, 0)
);
let InvocationBuckets = AgentInvocations
    | summarize
        Operations=count(),
        Successes=countif(Success != false and isempty(ErrorType)),
        Errors=countif(Success == false or isnotempty(ErrorType)),
        AverageLatencyMs=avg(DurationMs),
        P95LatencyMs=percentile(DurationMs, 95)
        by BucketStart=bin(TimeGenerated, Bucket), AgentKey, AgentName, AgentId, FoundryProjectId
    | extend RowType='TimeBucket';
let TokenBuckets = ChatSpans
    | summarize
        InputTokens=sum(InputTokens),
        CachedInputTokens=sum(CachedInputTokens),
        OutputTokens=sum(OutputTokens),
        AverageLatencyMs=avg(DurationMs),
        P95LatencyMs=percentile(DurationMs, 95)
        by BucketStart=bin(TimeGenerated, Bucket), AgentKey, AgentName, AgentId, FoundryProjectId, Model
    | extend RowType='TokenBucket';
let ModelUsage = materialize(
    ChatSpans
    | summarize
        Chats=count(),
        InputTokens=sum(InputTokens),
        CachedInputTokens=sum(CachedInputTokens),
        OutputTokens=sum(OutputTokens),
        AverageLatencyMs=avg(DurationMs),
        P95LatencyMs=percentile(DurationMs, 95),
        LastSeen=max(TimeGenerated)
        by AgentKey, AgentName, AgentId, FoundryProjectId, Model
    | extend RowType='ModelUsage'
);
let FinishReasons = ChatSpans
    | extend FinishReason=iff(isempty(FinishReason), '(not reported)', FinishReason)
    | summarize Count=count()
        by AgentKey, AgentName, AgentId, FoundryProjectId, FinishReason
    | extend RowType='FinishReason';
let Tools = ToolSpans
    | extend ToolName=iff(isempty(ToolName), '(not reported)', ToolName)
    | summarize
        Calls=count(),
        Errors=countif(Success == false or isnotempty(ErrorType)),
        AverageLatencyMs=avg(DurationMs)
        by AgentKey, AgentName, AgentId, FoundryProjectId, ToolName
    | extend RowType='Tool';
let RunModels = ChatSpans
    | summarize
        InputTokens=sum(InputTokens),
        CachedInputTokens=sum(CachedInputTokens),
        OutputTokens=sum(OutputTokens)
        by OperationId, AgentKey, FoundryProjectId, Model;
let RecentRuns = AgentInvocations
    | join kind=leftouter RunModels on OperationId, AgentKey, FoundryProjectId
    | project
        RowType='Run',
        Timestamp=TimeGenerated,
        TraceId=OperationId,
        AgentKey,
        AgentName,
        AgentId,
        FoundryProjectId,
        Model,
        InputTokens,
        CachedInputTokens,
        OutputTokens,
        DurationMs,
        Success,
        ErrorType
    | top 100 by Timestamp desc;
let RecentErrors = AgentInvocations
    | where Success == false or isnotempty(ErrorType)
    | project
        RowType='Error',
        Timestamp=TimeGenerated,
        TraceId=OperationId,
        AgentKey,
        AgentName,
        AgentId,
        FoundryProjectId,
        DurationMs,
        ErrorType
    | top 20 by Timestamp desc;
let ProjectScope = materialize(
    arg('').Resources
    | where type =~ 'microsoft.cognitiveservices/accounts/projects'
    | extend
        FoundryProjectId=tolower(id),
        AccountResourceId=tolower(substring(id, 0, indexof(tolower(id), '/projects/')))
    | project
        FoundryProjectId,
        AccountResourceId,
        SubAccountId=tolower(subscriptionId),
        ProjectName=name,
        RegionId=tolower(location)
);
let HubCosts = materialize(
    adx('{HubQueryUri}/{HubDatabase}').Costs()
    | where ChargePeriodStart between (StartTime .. EndTime)
    | where x_SkuMeterSubcategory has 'Agent'
    | extend AgentResourceId=tolower(ResourceId)
);
let BilledAgentCost = HubCosts
    | summarize
        BilledCost=sum(BilledCost),
        EffectiveCost=sum(EffectiveCost),
        BillingRows=count()
        by
            AgentResourceId,
            BillingCurrency,
            SubAccountId,
            RegionId,
            x_SkuMeterCategory,
            x_SkuMeterSubcategory,
            SkuMeter;
let TargetSubscriptions = toscalar(ProjectScope | summarize make_set(SubAccountId));
let TargetRegions = toscalar(ProjectScope | summarize make_set(RegionId));
let PricingCostScope = materialize(
    adx('{HubQueryUri}/{HubDatabase}').Costs()
    | where ChargePeriodStart >= ago(400d)
    | extend ScopeSubAccountId=tolower(iff(
        SubAccountId startswith '/',
        tostring(split(SubAccountId, '/')[2]),
        SubAccountId))
    | where set_has_element(TargetSubscriptions, ScopeSubAccountId)
);
let BillingScope = PricingCostScope
    | summarize arg_max(
        ChargePeriodStart,
        BillingCurrency,
        BillingAccountId,
        x_BillingAccountId,
        x_BillingProfileId)
        by ScopeSubAccountId
    | project
        SubAccountId=ScopeSubAccountId,
        ScopeBillingAccountId=tolower(coalesce(x_BillingAccountId, BillingAccountId)),
        ScopeBillingProfileId=tolower(coalesce(x_BillingProfileId, x_BillingAccountId, BillingAccountId)),
        ScopeCurrency=BillingCurrency,
        ScopeMatch=true;
let Regions = union
    (adx('{HubQueryUri}/{HubDatabase}').Region() | project PriceRegionKey=tolower(ResourceLocation), PriceRegionId=tolower(RegionId)),
    (adx('{HubQueryUri}/{HubDatabase}').Region() | project PriceRegionKey=tolower(RegionName), PriceRegionId=tolower(RegionId)),
    (adx('{HubQueryUri}/{HubDatabase}').Region() | project PriceRegionKey=tolower(RegionId), PriceRegionId=tolower(RegionId))
    | where isnotempty(PriceRegionKey)
    | summarize PriceRegionId=take_any(PriceRegionId) by PriceRegionKey;
let ScopedTokenRates = materialize(
    adx('{HubQueryUri}/{HubDatabase}').Prices()
    | where ChargeCategory =~ 'Usage'
    | where PricingCategory =~ 'Standard'
    | where x_SkuPriceType =~ 'Consumption'
    | where
        x_SkuMeterCategory has 'OpenAI'
        or x_SkuMeterCategory has 'Foundry'
        or x_SkuMeterSubcategory has 'OpenAI'
        or x_SkuDescription has 'OpenAI'
    | where
        PricingUnit has 'Tokens'
        or x_PricingUnitDescription has 'Tokens'
        or SkuMeter has 'Tokens'
        or x_SkuDescription has 'Tokens'
    | where x_EffectivePeriodStart < EndTime
    | where isnull(x_EffectivePeriodEnd) or StartTime < datetime_add('month', 1, x_EffectivePeriodEnd)
    | summarize arg_max(x_IngestionTime, *)
        by x_BillingAccountId, x_BillingProfileId, x_SkuMeterId, x_EffectivePeriodStart
    | extend PriceRegionKey=tolower(x_SkuRegion)
    | lookup kind=leftouter Regions on PriceRegionKey
    | extend PriceRegionId=iff(isempty(x_SkuRegion), 'global', PriceRegionId)
    | where PriceRegionId == 'global' or set_has_element(TargetRegions, PriceRegionId)
    | extend
        PriceBillingAccountId=tolower(coalesce(x_BillingAccountId, BillingAccountId)),
        PriceBillingProfileId=tolower(coalesce(x_BillingProfileId, x_BillingAccountId, BillingAccountId))
    | lookup kind=inner BillingScope on
        $left.PriceBillingAccountId == $right.ScopeBillingAccountId,
        $left.PriceBillingProfileId == $right.ScopeBillingProfileId
    | extend
        Direction=case(
            SkuMeter has_any ('Input', 'Prompt', 'Inp') or x_SkuDescription has_any ('Input', 'Prompt', 'Inp'), 'Input',
            SkuMeter has_any ('Output', 'Completion', 'Outp', 'Opt') or x_SkuDescription has_any ('Output', 'Completion', 'Outp', 'Opt'), 'Output',
            ''),
        Variant=case(
            SkuMeter has 'Batch', 'Batch',
            SkuMeter has 'LongCo', 'LongContext',
            SkuMeter has 'PP', 'Priority',
            SkuMeter has_any ('FineTuned', 'Fine-tuned', 'Training'), 'Fine-tuned',
            SkuMeter has_any ('Audio', 'Image', 'Video'), 'Multimodal',
            SkuMeter has_any ('Cached', 'Cache', 'Cd', 'Wr'), 'Cached',
            'Standard'),
        ModelText=tolower(strcat(SkuMeter, ' ', x_SkuDescription, ' ', x_SkuMeterSubcategory)),
        PricingCurrency=coalesce(PricingCurrency, BillingCurrency),
        SelectedUnitPrice=coalesce(ContractedUnitPrice, ListUnitPrice),
        PriceSource=iff(isnotnull(ContractedUnitPrice), 'Contracted', 'List'),
        ScopeMatch=coalesce(ScopeMatch, false)
    | where ScopeMatch and PricingCurrency =~ ScopeCurrency
    | where Direction in ('Input', 'Output') and Variant =~ 'Standard'
    | project
        SubAccountId,
        BillingCurrency,
        PricingCurrency,
        PricingUnit,
        x_SkuMeterId,
        SelectedUnitPrice,
        PriceSource,
        x_PricingBlockSize,
        SkuMeter,
        x_SkuDescription,
        x_SkuMeterSubcategory,
        x_SkuRegion,
        PriceRegionId,
        Direction,
        Variant,
        ModelText
);
let EstimatedCosts = ModelUsage
    | extend FoundryProjectId=tolower(FoundryProjectId), ModelKey=tolower(Model)
    | lookup kind=leftouter ProjectScope on FoundryProjectId
    | join kind=leftouter (
        ScopedTokenRates
        | where x_PricingBlockSize > 0
        | extend UnitPricePerToken=SelectedUnitPrice / x_PricingBlockSize
        | project
            SubAccountId,
            PriceRegionId,
            ModelText,
            Direction,
            UnitPricePerToken,
            PricingCurrency,
            PriceSource,
            SkuMeter
    ) on SubAccountId
    | where isempty(ModelText) or indexof(ModelText, ModelKey) >= 0
    | where isempty(PriceRegionId) or PriceRegionId == 'global' or PriceRegionId == RegionId
    | summarize
        InputRateCount=dcountif(UnitPricePerToken, Direction == 'Input'),
        OutputRateCount=dcountif(UnitPricePerToken, Direction == 'Output'),
        InputTokenRateCandidate=maxif(UnitPricePerToken, Direction == 'Input'),
        OutputTokenRateCandidate=maxif(UnitPricePerToken, Direction == 'Output'),
        InputTokens=take_any(InputTokens),
        CachedInputTokens=take_any(CachedInputTokens),
        OutputTokens=take_any(OutputTokens),
        Chats=take_any(Chats),
        PricingCurrency=take_any(PricingCurrency)
        by AgentKey, AgentId, AgentName, FoundryProjectId, Model, SubAccountId, RegionId
    | extend
        InputTokenRate=iff(InputRateCount == 1, InputTokenRateCandidate, real(null)),
        OutputTokenRate=iff(OutputRateCount == 1, OutputTokenRateCandidate, real(null)),
        RateStatus=case(
            InputRateCount > 1 or OutputRateCount > 1, 'Ambiguous',
            InputRateCount == 0 and OutputRateCount == 0, 'Missing',
            'Matched')
    | extend
        InputEstimatedCost=iff(InputTokens == 0, 0.0, InputTokens * InputTokenRate),
        OutputEstimatedCost=iff(OutputTokens == 0, 0.0, OutputTokens * OutputTokenRate)
    | extend EstimatedCost=InputEstimatedCost + OutputEstimatedCost
    | project-away InputTokenRateCandidate, OutputTokenRateCandidate;
union
    AgentSummary,
    InvocationBuckets,
    TokenBuckets,
    ModelUsage,
    FinishReasons,
    Tools,
    RecentRuns,
    RecentErrors,
    (BilledAgentCost | extend RowType='BilledCost', AgentKey=AgentResourceId, AgentId=AgentResourceId),
    (ScopedTokenRates | extend RowType='ScopedTokenRate'),
    (EstimatedCosts | extend RowType='EstimatedCost')
| project-reorder
    RowType,
    AgentKey,
    AgentId,
    AgentName,
    Timestamp,
    BucketStart,
    TraceId,
    FoundryProjectId,
    Model`;

export const supplyQuery = `Quota()
| where x_SourceType in~ (
    'AppServiceUsage',
    'CognitiveServicesUsage',
    'ComputeUsage',
    'SqlSubscriptionUsage',
    'StorageUsage',
    'CapacityReservation',
    'PremiumSSDv2Disk'
)
| summarize
    Observations=count(),
    Resources=dcount(ResourceId),
    Subscriptions=dcount(SubAccountId),
    Regions=dcountif(location, isnotempty(location)),
    LatestObservation=max(x_IngestionTime)
    by SourceType=x_SourceType
| extend Evidence=iff(SourceType in~ ('CapacityReservation', 'PremiumSSDv2Disk'), 'Inventory', 'Quota')
| order by Evidence asc, SourceType asc`;

const aggregateQuotaQuery = (catalogName, dimensions) => `let Current = (
${catalogQuery(catalogName)}
);
Current
| extend CurrentValue=todouble(currentValue), LimitValue=todouble(limit)
| summarize
    Current=sum(CurrentValue),
    UsableLimit=sumif(LimitValue, LimitValue > 0),
    QuotaMetrics=dcount(displayName),
    Subscriptions=dcount(SubAccountId),
    Observations=count(),
    LatestObservation=max(x_IngestionTime)
    by ${dimensions}
| extend
    Headroom=UsableLimit - Current,
    UtilizationPercent=iff(UsableLimit > 0, round(100.0 * Current / UsableLimit, 1), real(null))
| order by UtilizationPercent desc nulls last`;

export const supplyViews = Object.freeze([
    {
        id: "home",
        label: "Home",
        title: "Supply coverage",
        description: "Seven independent quota and inventory sources. Missing observations are unknown, not healthy.",
        query: supplyQuery,
    },
    {
        id: "app-service",
        label: "App Service",
        title: "App Service quota",
        description: "Provider-reported App Service quota, aggregated by region and unit.",
        query: aggregateQuotaQuery("quota-app-service-usage.kql", "Region=location, Unit=unit"),
    },
    {
        id: "azure-ai",
        label: "Azure AI",
        title: "Azure AI quota pools",
        description: "Provider-reported Azure AI quota, aggregated by region and unit.",
        query: aggregateQuotaQuery("quota-cognitive-services-usage.kql", "Region=location, Unit=unit"),
    },
    {
        id: "compute",
        label: "Compute",
        title: "Compute family quota",
        description: "VM-family vCPU quota aggregated across subscriptions without implying SKU-level quota.",
        query: `let Current = (
${catalogQuery("quota-compute-family-usage.kql")}
);
Current
| summarize
    CoresUsed=sum(CoresUsed),
    CoresTotal=sumif(CoresTotal, CoresTotal > 0),
    Families=dcount(Family),
    Subscriptions=dcount(SubscriptionId),
    Observations=count(),
    LatestObservation=max(x_IngestionTime)
    by Region=Location
| extend
    HeadroomCores=CoresTotal - CoresUsed,
    PercentUsed=iff(CoresTotal > 0, round(100.0 * CoresUsed / CoresTotal, 1), real(null))
| order by PercentUsed desc nulls last`,
    },
    {
        id: "azure-sql",
        label: "Azure SQL",
        title: "Azure SQL subscription quota",
        description: "Provider-reported SQL quota and counters by region and unit. Negative and missing limits remain non-comparable.",
        query: aggregateQuotaQuery("quota-sql-subscription-usage.kql", "Region=location, Unit=unit"),
    },
    {
        id: "storage",
        label: "Storage",
        title: "Storage quota",
        description: "Storage accounts, disks, and snapshot quota aggregated by source, region, and unit.",
        query: aggregateQuotaQuery("quota-storage-usage.kql", "SourceType=x_SourceType, Region=location, Unit=unit"),
    },
    {
        id: "capacity-reservations",
        label: "Capacity reservations",
        title: "Capacity reservation inventory",
        description: "Observed reservation-group inventory. This view does not infer reserved quantity or utilization.",
        query: `let Current = (
${catalogQuery("quota-capacity-reservations.kql")}
);
Current
| summarize
    ReservationGroups=dcount(ResourceId),
    Subscriptions=dcount(SubAccountId),
    LatestObservation=max(x_IngestionTime)
    by Region=location
| order by ReservationGroups desc`,
    },
    {
        id: "premium-ssd-v2",
        label: "Premium SSD v2",
        title: "Premium SSD v2 inventory",
        description: "Observed Premium SSD v2 disks and provisioned GiB. This is inventory, not quota or regional availability.",
        query: `let Current = (
${catalogQuery("quota-premium-ssd-v2-disks.kql")}
);
Current
| summarize
    Disks=dcount(ResourceId),
    ProvisionedGiB=sum(todouble(currentValue)),
    Subscriptions=dcount(SubAccountId),
    LatestObservation=max(x_IngestionTime)
    by Region=location
| order by ProvisionedGiB desc`,
    },
]);
