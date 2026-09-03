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
| where type !~ 'microsoft.cognitiveservices/accounts' or kind in~ ('OpenAI', 'AIServices')
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
        metric: "microsoft.cognitiveservices/accounts-Azure OpenAI  Usage-ProcessedPromptTokens",
        aggregation: 7,
        columnName: "Input tokens",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-Azure OpenAI  Usage-GeneratedTokens",
        aggregation: 7,
        columnName: "Output tokens",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-Azure OpenAI  Usage-TokenTransaction",
        aggregation: 7,
        columnName: "Total tokens",
    },
];

export const requestMetrics = [
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-Azure OpenAI  HTTP Requests-AzureOpenAIRequests",
        aggregation: 7,
        columnName: "Model requests",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-Azure OpenAI  HTTP Requests-AzureOpenAIRequests",
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
        metric: "microsoft.cognitiveservices/accounts-Azure OpenAI  HTTP Requests-AzureOpenAITimeToResponse",
        aggregation: 4,
        columnName: "Time to response",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-Azure OpenAI  HTTP Requests-TimeToLastByte",
        aggregation: 4,
        columnName: "Time to last byte",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-Azure OpenAI  HTTP Requests-TokensPerSecond",
        aggregation: 4,
        columnName: "Tokens per second",
    },
    {
        namespace: "microsoft.cognitiveservices/accounts",
        metric: "microsoft.cognitiveservices/accounts-Azure OpenAI  HTTP Requests-AzureOpenAIContextTokensCacheMatchRate",
        aggregation: 4,
        columnName: "Prompt cache match rate",
    },
];

export const foundryAgentsQuery = `set query_results_cache_max_age = time(30s);
set best_effort=true;
let StartTime = todatetime({TimeRange:start});
let EndTime = todatetime({TimeRange:end});
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
let ProjectScope =
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
        RegionId=tolower(location);
let HubCosts =
    adx('__KUSTO_QUERY_URI__/Hub').Costs
    | where ChargePeriodStart between (StartTime .. EndTime)
    | where x_SkuMeterSubcategory has 'Agent'
    | extend AgentResourceId=tolower(ResourceId);
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
let PricingCostScope =
    adx('__KUSTO_QUERY_URI__/Hub').Costs
    | where ChargePeriodStart >= ago(400d)
    | extend ScopeSubAccountId=tolower(iff(
        SubAccountId startswith '/',
        tostring(split(SubAccountId, '/')[2]),
        SubAccountId))
;
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
    (adx('__KUSTO_QUERY_URI__/Hub').Region | project PriceRegionKey=tolower(ResourceLocation), PriceRegionId=tolower(RegionId)),
    (adx('__KUSTO_QUERY_URI__/Hub').Region | project PriceRegionKey=tolower(RegionName), PriceRegionId=tolower(RegionId)),
    (adx('__KUSTO_QUERY_URI__/Hub').Region | project PriceRegionKey=tolower(RegionId), PriceRegionId=tolower(RegionId))
    | where isnotempty(PriceRegionKey)
    | summarize PriceRegionId=take_any(PriceRegionId) by PriceRegionKey;
let ScopedTokenRates =
    adx('__KUSTO_QUERY_URI__/Hub').Prices
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
;
let EstimatedCosts = ModelUsage
    | extend FoundryProjectId=tolower(FoundryProjectId), ModelKey=tolower(Model)
    | join hint.remote=left kind=leftouter (ProjectScope) on FoundryProjectId
    | join hint.remote=left kind=leftouter (
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
let RelevantTokenRates = EstimatedCosts
    | project
        RowType='ScopedTokenRate',
        AgentKey,
        AgentId,
        AgentName,
        FoundryProjectId,
        Model,
        SubAccountId,
        RegionId,
        InputTokenRate,
        OutputTokenRate,
        PricingCurrency,
        RateStatus;
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
    RelevantTokenRates,
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

const catalogDeclaration = (name, catalogName) => `let ${name} = (
${catalogQuery(catalogName)}
);`;

const supplyRegistry = Object.freeze([
    {
        id: "app-service",
        label: "App Service",
        title: "App Service quota",
        sourceType: "AppServiceUsage",
        evidenceType: "Provider metric",
        sourceNote: "Provider-reported App Service quota - point-in-time",
        emptyLabel: "No App Service quota observations were ingested; this does not mean zero usage or unlimited capacity.",
    },
    {
        id: "azure-ai",
        label: "Azure AI",
        title: "Azure AI quota pools",
        sourceType: "CognitiveServicesUsage",
        evidenceType: "Provider metric",
        sourceNote: "Provider-reported Azure AI quota - point-in-time",
        emptyLabel: "No Azure AI quota observations were ingested; check query coverage and provider access.",
    },
    {
        id: "compute",
        label: "Compute",
        title: "Compute quota",
        sourceType: "ComputeUsage",
        evidenceType: "Provider metric",
        sourceNote: "Provider-reported compute quota - point-in-time",
        emptyLabel: "No Compute quota observations were ingested; deployment capacity is unknown.",
    },
    {
        id: "azure-sql",
        label: "Azure SQL",
        title: "Azure SQL subscription quota and counters",
        sourceType: "SqlSubscriptionUsage",
        evidenceType: "Provider metric",
        sourceNote: "Provider-reported SQL quota - point-in-time",
        emptyLabel: "No Azure SQL subscription-usage observations were ingested; SQL quota posture is unknown.",
    },
    {
        id: "storage",
        label: "Storage",
        title: "Storage quotas",
        sourceType: "StorageUsage",
        evidenceType: "Provider metric",
        sourceNote: "Provider-reported storage quota - point-in-time",
        emptyLabel: "No Storage quota was reported. Validate ingestion, permissions, supported regions, and source execution.",
    },
    {
        id: "capacity-reservations",
        label: "Capacity reservations",
        title: "Capacity reservation groups",
        sourceType: "CapacityReservation",
        evidenceType: "Inventory",
        sourceNote: "Capacity reservation group observed - inventory only",
        emptyLabel: "No capacity reservation groups were observed; absence is unverified without a complete snapshot.",
    },
    {
        id: "premium-ssd-v2",
        label: "Premium SSD v2",
        title: "Premium SSD v2 disks",
        sourceType: "PremiumSSDv2Disk",
        evidenceType: "Inventory",
        sourceNote: "Observed Premium SSD v2 provisioned size - GiB inventory; no quota limit",
        emptyLabel: "No Premium SSD v2 disks were observed; this is not a disk quota or regional availability conclusion.",
    },
]);

const kqlValue = (value) => `'${value.replaceAll("'", "''")}'`;
const kqlColumn = (value) => `['${value.replaceAll("'", "''")}']`;
const registryRows = supplyRegistry
    .map((item) => [
        item.id,
        item.title,
        item.evidenceType,
        item.sourceType,
        item.sourceNote,
        item.emptyLabel,
    ].map(kqlValue).join(", "))
    .join(",\n    ");

export const supplyQuery = `let Registry = datatable(
    ClassId:string,
    QuotaArea:string,
    EvidenceType:string,
    SourceType:string,
    SourceNote:string,
    EmptyState:string
)
[
    ${registryRows}
];
let Observed = Quota()
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
    SnapshotDays=dcount(startofday(x_IngestionTime)),
    LatestObservation=max(x_IngestionTime)
    by SourceType=x_SourceType;
Registry
| join kind=leftouter Observed on SourceType
| extend
    EvidenceState=iff(coalesce(Observations, 0) == 0, 'Not reported - collection outcome unknown', 'Observed'),
    Observations=iff(coalesce(Observations, 0) == 0, long(null), Observations),
    Resources=iff(coalesce(Resources, 0) == 0, long(null), Resources),
    Subscriptions=iff(coalesce(Subscriptions, 0) == 0, long(null), Subscriptions),
    SnapshotDays=iff(coalesce(SnapshotDays, 0) == 0, long(null), SnapshotDays)
| project QuotaArea, EvidenceType, EvidenceState, Observations, Resources, Subscriptions, SnapshotDays, LatestObservation, SourceNote, EmptyState, ClassId
| order by EvidenceType asc, QuotaArea asc`;

const statusOptionsQuery = `datatable(value:string, label:string, selected:bool)
[
    'all', 'All', true,
    'in-use', 'In use', false,
    'at-limit', 'At limit', false,
    'no-quota', 'No quota', false
]`;

const highWaterOptionsQuery = `datatable(value:string, label:string, selected:bool)
[
    '60', '60%', false,
    '70', '70%', true,
    '80', '80%', false,
    '90', '90%', false
]`;

const detailPageSize = 50;

const matrixControlNames = (id) => {
    const prefix = id
        .split("-")
        .map((part) => part[0].toUpperCase() + part.slice(1))
        .join("");
    return {
        search: `Supply${prefix}Search`,
        subscriptionSearch: `Supply${prefix}SubscriptionSearch`,
        pairsPage: `Supply${prefix}PairsPage`,
        subscriptionPage: `Supply${prefix}SubscriptionPage`,
        demand: `Supply${prefix}DemandSeries`,
        status: `Supply${prefix}Status`,
        region: `Supply${prefix}Region`,
        highWater: `Supply${prefix}HighWater`,
        detail: `Supply${prefix}Detail`,
    };
};

const matrixDefinitions = Object.freeze({
    "app-service": {
        declaration: catalogDeclaration("AppServiceQuotaUsage", "quota-app-service-usage.kql"),
        body: `AppServiceQuotaUsage
| summarize
    RowLabel=take_any(iff(ResourceName == '*', 'Total Regional VMs', displayName)),
    Used=sum(currentValue),
    Quota=sum(limit),
    Subscriptions=dcount(SubAccountId),
    InUseSubscriptions=dcountif(SubAccountId, currentValue > 0),
    AtLimitSubscriptions=dcountif(SubAccountId, limit > 0 and currentValue >= limit),
    QuotaSubscriptions=dcountif(SubAccountId, limit > 0),
    NoQuotaSubscriptions=dcountif(SubAccountId, coalesce(limit, 0.0) <= 0),
    NegativeLimitSubscriptions=dcountif(SubAccountId, limit < 0),
    LatestObservation=max(x_IngestionTime)
    by RowKey=ResourceName, Unit=unit, Location=location`,
        pairLabel: "SKU-region pairs",
        rowLabel: "Plan SKU",
        panelTitle: "Estate quota by plan SKU and region",
        panelDescription: "Provider-reported App Service instance usage, quota, and headroom. Total Regional VMs and the selected SKU both constrain deployment.",
        detailTitle: "SKU and region",
        sourceType: "AppServiceUsage",
        demandPredicate: `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where x_ResourceType startswith 'microsoft.web/'`,
    },
    "azure-ai": {
        declaration: catalogDeclaration("AzureAiQuotaUsage", "quota-cognitive-services-usage.kql"),
        body: `AzureAiQuotaUsage
| summarize
    RowLabel=take_any(displayName),
    Used=sum(currentValue),
    Quota=sum(limit),
    Subscriptions=dcount(SubAccountId),
    InUseSubscriptions=dcountif(SubAccountId, currentValue > 0),
    AtLimitSubscriptions=dcountif(SubAccountId, limit > 0 and currentValue >= limit),
    QuotaSubscriptions=dcountif(SubAccountId, limit > 0),
    NoQuotaSubscriptions=dcountif(SubAccountId, coalesce(limit, 0.0) <= 0),
    NegativeLimitSubscriptions=dcountif(SubAccountId, limit < 0),
    LatestObservation=max(x_IngestionTime)
    by RowKey=ResourceName, Unit=unit, Location=location`,
        pairLabel: "Model-region pairs",
        rowLabel: "Model and tier",
        panelTitle: "Estate quota by Azure AI model and region",
        panelDescription: "Each model and deployment-tier pool is independent. Quota is never summed across models, and units remain provider-reported.",
        detailTitle: "Model and region",
        sourceType: "CognitiveServicesUsage",
        demandPredicate: `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where ServiceName in~ ('Azure AI services', 'Azure OpenAI Service', 'Cognitive Services')`,
    },
    compute: {
        declaration: `${catalogDeclaration("ComputeFamilyUsage", "quota-compute-family-usage.kql")}
${catalogDeclaration("ComputeFamilyOfferStatus", "quota-compute-family-offer-status.kql")}`,
        body: `ComputeFamilyUsage
| join kind=leftouter ComputeFamilyOfferStatus on SubscriptionId, FamilyKey, Location
| summarize
    RowLabel=take_any(Family),
    Used=sum(CoresUsed),
    Quota=sum(CoresTotal),
    Subscriptions=dcount(SubscriptionId),
    InUseSubscriptions=dcountif(SubscriptionId, CoresUsed > 0),
    AtLimitSubscriptions=dcountif(SubscriptionId, CoresTotal > 0 and CoresUsed >= CoresTotal),
    QuotaSubscriptions=dcountif(SubscriptionId, CoresTotal > 0),
    NoQuotaSubscriptions=dcountif(SubscriptionId, CoresTotal <= 0),
    NegativeLimitSubscriptions=dcountif(SubscriptionId, CoresTotal < 0),
    OfferSubscriptions=dcountif(SubscriptionId, isnotempty(RepresentativeSku)),
    RegionRestrictedSubscriptions=dcountif(SubscriptionId, RegionRestricted),
    ZoneRestrictedSubscriptions=dcountif(SubscriptionId, array_length(ZonesRestricted) > 0),
    RepresentativeSkus=make_set_if(RepresentativeSku, isnotempty(RepresentativeSku), 100),
    RepresentativeVcpus=min(RepresentativeVcpus),
    ZonesPresent=make_list_if(ZonesPresent, array_length(ZonesPresent) > 0, 100),
    ZonesRestricted=make_list_if(ZonesRestricted, array_length(ZonesRestricted) > 0, 100),
    LatestObservation=max(x_IngestionTime),
    OfferObservation=max(x_IngestionTime1)
    by RowKey=FamilyKey, Unit=unit, Location`,
        pairLabel: "Family-region pairs",
        rowLabel: "VM family",
        panelTitle: "Estate quota by VM family and region",
        panelDescription: "Quota utilization and offer availability are independent signals. Offer status uses the smallest-vCPU SKU in each family.",
        detailTitle: "Family and region",
        sourceType: "ComputeUsage",
        coverageSourceTypes: ["ComputeUsage", "ComputeResourceSku"],
    },
    "azure-sql": {
        declaration: catalogDeclaration("AzureSqlQuotaUsage", "quota-sql-subscription-usage.kql"),
        body: `AzureSqlQuotaUsage
| where ResourceName in~ (
    'RegionalVCoreQuotaForSQLDBAndDW',
    'ServerQuota',
    'SubscriptionSQLManagedInstanceStandardSeriesVCoreQuota',
    'SubscriptionSQLManagedInstancePremiumSeriesVCoreQuota',
    'SubscriptionSQLManagedInstancePremiumSeriesMemoryOptimizedVCoreQuota'
)
| extend RowLabel=case(
    ResourceName =~ 'RegionalVCoreQuotaForSQLDBAndDW', 'Azure SQL Database and Synapse vCores',
    ResourceName =~ 'ServerQuota', 'Logical servers',
    ResourceName =~ 'SubscriptionSQLManagedInstanceStandardSeriesVCoreQuota', 'SQL MI standard-series vCores',
    ResourceName =~ 'SubscriptionSQLManagedInstancePremiumSeriesVCoreQuota', 'SQL MI premium-series vCores',
    ResourceName =~ 'SubscriptionSQLManagedInstancePremiumSeriesMemoryOptimizedVCoreQuota', 'SQL MI memory-optimized premium vCores',
    ResourceName)
| summarize
    RowLabel=take_any(RowLabel),
    Used=sumif(currentValue, limit > 0),
    Quota=sumif(limit, limit > 0),
    Subscriptions=dcount(SubAccountId),
    InUseSubscriptions=dcountif(SubAccountId, limit > 0 and currentValue > 0),
    AtLimitSubscriptions=dcountif(SubAccountId, limit > 0 and currentValue >= limit),
    QuotaSubscriptions=dcountif(SubAccountId, limit > 0),
    NoQuotaSubscriptions=dcountif(SubAccountId, coalesce(limit, 0.0) <= 0),
    NegativeLimitSubscriptions=dcountif(SubAccountId, limit < 0),
    LatestObservation=max(x_IngestionTime)
    by RowKey=ResourceName, Unit=unit, Location=location`,
        pairLabel: "Quota-region pairs",
        rowLabel: "Azure SQL quota",
        panelTitle: "Estate quota by Azure SQL metric and region",
        panelDescription: "Only the five supported regional quota metrics are included. Negative limits remain explicit and non-comparable.",
        detailTitle: "Quota and region",
        sourceType: "SqlSubscriptionUsage",
        demandPredicate: `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where ServiceName in~ ('Azure SQL Database', 'Azure SQL Managed Instance')`,
    },
});

const matrixDeclaration = (definition) => `${definition.declaration}
let Matrix = materialize(
${definition.body}
| extend
    UtilizationPercent=iff(Quota > 0 and Used >= 0, round(100.0 * Used / Quota, 1), real(null)),
    Headroom=iff(Quota > 0 and Used >= 0, Quota - Used, real(null))
);`;

const matrixQuery = (definition) => `${matrixDeclaration(definition)}
Matrix`;

const matrixCoverageQuery = (definition) => {
    const sourceTypes = definition.coverageSourceTypes ?? [definition.sourceType];
    const sourceRows = sourceTypes.map(kqlValue).join(",\n    ");
    return `let Required = datatable(EvidenceSource:string)
[
    ${sourceRows}
];
let Observed = Quota()
| where x_SourceType in~ (${sourceTypes.map(kqlValue).join(", ")})
| summarize
    Observations=count(),
    Resources=dcount(ResourceId),
    Subscriptions=dcount(SubAccountId),
    SnapshotDays=dcount(startofday(x_IngestionTime)),
    LatestObservation=max(x_IngestionTime)
    by EvidenceSource=x_SourceType;
Required
| join kind=leftouter Observed on EvidenceSource
| extend EvidenceState=iff(coalesce(Observations, 0) == 0, 'Not reported - collection outcome unknown', 'Observed')
| project EvidenceSource, EvidenceState, Observations, Resources, Subscriptions, SnapshotDays, LatestObservation`;
};

const matrixSummaryQuery = (definition) => `${matrixDeclaration(definition)}
union
    (Matrix | summarize Value=count() | extend Sort=1, Metric='${definition.pairLabel}'),
    (Matrix | summarize Value=countif(Used > 0) | extend Sort=2, Metric='In use'),
    (Matrix | summarize Value=countif(AtLimitSubscriptions > 0) | extend Sort=3, Metric='At limit'),
    (Matrix | summarize Value=countif(NoQuotaSubscriptions >= Subscriptions) | extend Sort=4, Metric='No quota')
| order by Sort asc
| project Metric, Value`;

const matrixRegionQuery = (definition) => `${matrixQuery(definition)}
| summarize by value=tolower(Location)
| extend label=value, selected=false
| union (print value='*', label='All regions', selected=true)
| extend Sort=iff(value == '*', 0, 1)
| order by Sort asc, label asc
| project value, label, selected`;

const matrixStatusExpression = (definition) => definition === matrixDefinitions.compute
    ? `case(
        NoQuotaSubscriptions >= Subscriptions, 'No quota',
        AtLimitSubscriptions > 0, 'Exhausted',
        UtilizationPercent >= 90, 'Action',
        UtilizationPercent >= 80, 'Watch',
        'Healthy')`
    : `case(
        QuotaSubscriptions == 0 and NegativeLimitSubscriptions > 0, 'Invalid',
        QuotaSubscriptions == 0, 'No quota',
        AtLimitSubscriptions > 0, 'Exhausted',
        UtilizationPercent >= 90, 'Action',
        UtilizationPercent >= 80, 'Watch',
        'Healthy')`;

const matrixSupplyExpression = (definition) => definition === matrixDefinitions.compute
    ? `case(
        Quota <= 0 or OfferSubscriptions == 0, 'Not reported',
        RegionRestrictedSubscriptions > 0, 'Blocked',
        ZoneRestrictedSubscriptions > 0, 'Partial',
        'Open')`
    : `case(
        QuotaSubscriptions == 0, 'Not reported',
        AtLimitSubscriptions > 0, 'Blocked',
        NoQuotaSubscriptions > 0, 'Partial',
        'Open')`;

const matrixFilterPipeline = (definition, controls) => `| extend Search=base64_decode_tostring('{${controls.search}:base64}')
| where isempty(Search) or RowLabel contains Search or RowKey contains Search
| extend
    QuotaStatus=${matrixStatusExpression(definition)},
    SupplyStatus=${matrixSupplyExpression(definition)}
| where '{${controls.region}}' == '*' or Location =~ '{${controls.region}}'
| where '{${controls.status}}' == 'all'
    or ('{${controls.status}}' == 'in-use' and Used > 0)
    or ('{${controls.status}}' == 'at-limit' and AtLimitSubscriptions > 0)
    or ('{${controls.status}}' == 'no-quota' and NoQuotaSubscriptions >= Subscriptions)
| extend
    HighWaterMark=todouble('{${controls.highWater}}'),
    HighWater=case(
        isnull(UtilizationPercent), 'Not comparable',
        UtilizationPercent >= todouble('{${controls.highWater}}'), strcat('At or above ', '{${controls.highWater}}', '%'),
        strcat('Below ', '{${controls.highWater}}', '%'))`;

const filteredMatrixQuery = (definition, controls) => `${matrixQuery(definition)}
${matrixFilterPipeline(definition, controls)}`;

const pageOptionsProjection = `| summarize TotalRows=count()
| extend TotalPages=max_of(1, toint(ceiling(todouble(TotalRows) / ${detailPageSize}.0)))
| mv-expand Page=range(1, TotalPages, 1) to typeof(long)
| order by Page asc
| project
    value=tostring(Page),
    label=strcat('Page ', Page, ' of ', TotalPages, ' - ', TotalRows, ' rows'),
    selected=Page == 1`;

const pagedQuery = (query, pageParameter) => `${query}
| serialize PageRow=row_number()
| extend PageNumber=coalesce(toint('{${pageParameter}}'), 1)
| where PageRow > (PageNumber - 1) * ${detailPageSize}
    and PageRow <= PageNumber * ${detailPageSize}
| project-away PageRow, PageNumber`;

const matrixPivotQuery = (definition, controls) => `${matrixDeclaration(definition)}
let Filtered = materialize(
    Matrix
    ${matrixFilterPipeline(definition, controls)}
);
let Rows = Filtered
| summarize Unit=take_any(Unit) by RowLabel;
let Regions = Filtered
| summarize by Location;
Rows
| extend JoinKey=1
| join kind=inner (Regions | extend JoinKey=1) on JoinKey
| project-away JoinKey
| join kind=leftouter (
    Filtered
    | project RowLabel, Unit, Location, UtilizationPercent
) on RowLabel, Unit, Location
| extend UtilizationPercent=coalesce(UtilizationPercent, -1.0)
| project ${kqlColumn(definition.rowLabel)}=RowLabel, Unit, Location, UtilizationPercent
| evaluate pivot(Location, take_any(UtilizationPercent), ${kqlColumn(definition.rowLabel)}, Unit)
| order by ${kqlColumn(definition.rowLabel)} asc`;

const matrixDetailDatasetQuery = (definition, controls) => {
    const computeColumns = definition === matrixDefinitions.compute
        ? ", OfferSubscriptions, RegionRestrictedSubscriptions, ZoneRestrictedSubscriptions, RepresentativeSkus, RepresentativeVcpus, ZonesPresent, ZonesRestricted, OfferObservation"
        : "";
    return `${filteredMatrixQuery(definition, controls)}
| project
    ${kqlColumn(definition.rowLabel)}=RowLabel,
    Region=Location,
    Used,
    Quota,
    Headroom,
    UtilizationPercent,
    Unit,
    Subscriptions,
    InUseSubscriptions,
    AtLimitSubscriptions,
    NoQuotaSubscriptions,
    NegativeLimitSubscriptions,
    QuotaStatus,
    SupplyStatus,
    HighWater,
    LatestObservation${computeColumns}
| order by UtilizationPercent desc nulls last, ${kqlColumn(definition.rowLabel)} asc, Region asc`;
};

const matrixDetailQuery = (definition, controls) => pagedQuery(
    matrixDetailDatasetQuery(definition, controls),
    controls.pairsPage
);

const matrixDetailPageQuery = (definition, controls) => `${filteredMatrixQuery(definition, controls)}
${pageOptionsProjection}`;

const computeOfferRestrictionsQuery = `${catalogDeclaration("ComputeFamilyOfferStatus", "quota-compute-family-offer-status.kql")}
ComputeFamilyOfferStatus
| where RegionRestricted or array_length(ZonesRestricted) > 0
| mv-apply ZoneGroup=ZonesRestricted to typeof(dynamic) on (
    mv-expand RestrictedZone=ZoneGroup to typeof(string)
    | summarize RestrictedZones=make_set(RestrictedZone)
)
| extend
    OfferRestriction=iff(RegionRestricted, 'Region restricted', 'Availability zone restricted'),
    AvailableZones=iff(array_length(ZonesPresent) == 0, 'None reported', strcat_array(ZonesPresent, ', ')),
    RestrictedZones=iff(RegionRestricted, 'All zones in region', strcat_array(RestrictedZones, ', '))
| project
    SubscriptionId,
    ['VM family']=FamilyKey,
    Region=Location,
    ['Offer restriction']=OfferRestriction,
    ['Available zones']=AvailableZones,
    ['Restricted zones']=RestrictedZones,
    ['Representative SKU']=RepresentativeSku,
    ['Representative vCPUs']=RepresentativeVcpus,
    ['Latest observation']=x_IngestionTime
| order by Region asc, ['VM family'] asc, SubscriptionId asc`;

const matrixSubscriptionDatasetQuery = (id, controls) => {
    const search = `| where isempty(ResourceSearch) or RowLabel contains ResourceSearch or RowKey contains ResourceSearch
| where isempty(SubscriptionSearch) or SubscriptionId startswith SubscriptionSearch`;
    const status = `| where '{${controls.status}}' == 'all'
    or ('{${controls.status}}' == 'in-use' and Used > 0)
    or ('{${controls.status}}' == 'at-limit' and Quota > 0 and Used >= Quota)
    or ('{${controls.status}}' == 'no-quota' and Quota <= 0)`;
    const region = `| where '{${controls.region}}' == '*' or Region =~ '{${controls.region}}'`;
    if (id === "compute") {
        return `let ResourceSearch=base64_decode_tostring('{${controls.search}:base64}');
let SubscriptionSearch=base64_decode_tostring('{${controls.subscriptionSearch}:base64}');
${catalogDeclaration("ComputeFamilyUsage", "quota-compute-family-usage.kql")}
ComputeFamilyUsage
| project SubscriptionId, Region=Location, RowKey=FamilyKey, RowLabel=Family, Used=CoresUsed, Quota=CoresTotal, LatestObservation=x_IngestionTime
${search}
${status}
${region}
| summarize
    Families=dcount(RowKey),
    Regions=dcount(Region),
    UsedCores=sum(Used),
    QuotaCores=sum(Quota),
    HeadroomCores=sum(Quota) - sum(Used),
    LatestObservation=max(LatestObservation)
    by SubscriptionId
| order by UsedCores desc, SubscriptionId asc`;
    }

    const catalogName = id === "app-service"
        ? "quota-app-service-usage.kql"
        : id === "azure-ai"
            ? "quota-cognitive-services-usage.kql"
            : "quota-sql-subscription-usage.kql";
    const declarationName = id === "app-service"
        ? "AppServiceQuotaUsage"
        : id === "azure-ai"
            ? "AzureAiQuotaUsage"
            : "AzureSqlQuotaUsage";
    const sqlFilter = id === "azure-sql"
        ? `| where ResourceName in~ (
    'RegionalVCoreQuotaForSQLDBAndDW',
    'ServerQuota',
    'SubscriptionSQLManagedInstanceStandardSeriesVCoreQuota',
    'SubscriptionSQLManagedInstancePremiumSeriesVCoreQuota',
    'SubscriptionSQLManagedInstancePremiumSeriesMemoryOptimizedVCoreQuota'
)`
        : "";
    const dimension = id === "app-service" ? "SKUs" : id === "azure-ai" ? "Models" : "Quota metrics";
    return `let ResourceSearch=base64_decode_tostring('{${controls.search}:base64}');
let SubscriptionSearch=base64_decode_tostring('{${controls.subscriptionSearch}:base64}');
${catalogDeclaration(declarationName, catalogName)}
${declarationName}
${sqlFilter}
| project SubscriptionId=SubAccountId, Region=location, RowKey=ResourceName, RowLabel=coalesce(displayName, ResourceName), Used=currentValue, Quota=limit, LatestObservation=x_IngestionTime
${search}
${status}
${region}
| summarize
    ['${dimension}']=dcount(RowKey),
    Regions=dcount(Region),
    Pairs=count(),
    InUse=countif(Used > 0),
    AtLimit=countif(Quota > 0 and Used >= Quota),
    NoQuota=countif(coalesce(Quota, 0.0) <= 0),
    LatestObservation=max(LatestObservation)
    by SubscriptionId
| order by AtLimit desc, NoQuota desc, InUse desc, SubscriptionId asc`;
};

const matrixSubscriptionQuery = (id, controls) => pagedQuery(
    matrixSubscriptionDatasetQuery(id, controls),
    controls.subscriptionPage
);

const matrixSubscriptionPageQuery = (id, controls) => `${matrixSubscriptionDatasetQuery(id, controls)}
${pageOptionsProjection}`;

const matrixView = (registryItem, definition) => {
    const controls = matrixControlNames(registryItem.id);
    const viewControls = [
        { name: controls.search, label: "Search", value: "", text: true },
        { name: controls.status, label: "Show", query: statusOptionsQuery },
        { name: controls.region, label: "Region", query: matrixRegionQuery(definition) },
        { name: controls.highWater, label: "High-water mark", query: highWaterOptionsQuery },
        { name: controls.detail, value: "pairs", hidden: true },
    ];
    const panels = [
        {
            id: "summary",
            role: "summary",
            title: `${registryItem.title} summary`,
            query: matrixSummaryQuery(definition),
            visualization: "tiles",
            width: "100",
            size: 0,
        },
        {
            id: "coverage",
            role: "coverage",
            title: "Evidence coverage",
            query: matrixCoverageQuery(definition),
            width: "100",
            size: 0,
        },
        {
            id: "matrix",
            role: "matrix",
            title: definition.panelTitle,
            query: matrixPivotQuery(definition, controls),
            matrixDimension: definition.rowLabel.replaceAll(" ", ""),
            width: "100",
            size: 3,
            noDataMessage: registryItem.emptyLabel,
        },
        ...(registryItem.id === "compute" ? [{
            id: "offer-restrictions",
            role: "offer-restrictions",
            title: "Compute offer restrictions and availability zones",
            query: computeOfferRestrictionsQuery,
            width: "100",
            size: 1,
            rowLimit: detailPageSize,
            noDataMessage: "No compute offer restrictions were reported.",
        }] : []),
        {
            id: "pairs",
            role: "detail",
            title: `Filtered ${definition.detailTitle.toLowerCase()} detail`,
            query: matrixDetailQuery(definition, controls),
            width: "100",
            size: 3,
            noDataMessage: "No quota rows match the selected status and region.",
            detailValue: "pairs",
            rowLimit: detailPageSize,
        },
        {
            id: "subscriptions",
            role: "subscription-detail",
            title: "Subscriptions",
            query: matrixSubscriptionQuery(registryItem.id, controls),
            width: "100",
            size: 3,
            noDataMessage: "No subscriptions match the selected status and region.",
            detailValue: "subscriptions",
            rowLimit: detailPageSize,
        },
    ];
    return {
        ...registryItem,
        kind: "matrix",
        description: definition.panelDescription,
        nextAction: {
            "app-service": "Validate region access and SKU availability separately before requesting an exact SKU quota increase.",
            "azure-ai": "Validate model availability, deployment scope, and actual capacity separately from the provider quota row.",
            compute: "Check total regional and applicable VM-family vCPU quota, then validate SKU, zone, and physical capacity separately.",
            "azure-sql": "Use the exact SQL metric and service workflow. Validate region and zone-redundant access separately.",
        }[registryItem.id],
        controls: viewControls,
        detailParameter: controls.detail,
        detailControls: [
            {
                detailValue: "pairs",
                controls: [
                    { name: controls.pairsPage, label: "Page", query: matrixDetailPageQuery(definition, controls) },
                ],
            },
            {
                detailValue: "subscriptions",
                controls: [
                    { name: controls.subscriptionSearch, label: "Search subscriptions", value: "", text: true },
                    { name: controls.subscriptionPage, label: "Page", query: matrixSubscriptionPageQuery(registryItem.id, controls) },
                ],
            },
        ],
        detailTabs: [
            { id: "pairs", label: definition.detailTitle },
            { id: "subscriptions", label: "Subscriptions" },
        ],
        panels,
    };
};

const nonMatrixDefinitions = Object.freeze({
    storage: {
        current: `Quota()
| where x_SourceType =~ 'StorageUsage'
| summarize arg_max(x_IngestionTime, *) by ResourceId`,
        sourceType: "StorageUsage",
        inventory: false,
        demandPredicate: `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where x_ResourceType =~ 'microsoft.storage/storageaccounts'
| where ConsumedUnit in~ ('Units', 'Units/Hour', 'GB', 'GB/Month', 'Units/Month')`,
    },
    "capacity-reservations": {
        current: catalogQuery("quota-capacity-reservations.kql"),
        sourceType: "CapacityReservation",
        inventory: true,
        demandPredicate: `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where isnotempty(CapacityReservationId)
| where CapacityReservationStatus in~ ('Used', 'Unused')
| where ConsumedUnit =~ 'Hours'`,
    },
    "premium-ssd-v2": {
        current: catalogQuery("quota-premium-ssd-v2-disks.kql"),
        sourceType: "PremiumSSDv2Disk",
        inventory: true,
        demandPredicate: `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where x_ResourceType =~ 'microsoft.compute/disks'`,
    },
});

const currentDataset = (definition) => `let Current = (
${definition.current}
);`;

const nonMatrixCoverageQuery = (definition) => `Quota()
| where x_SourceType =~ '${definition.sourceType}'
| summarize
    Observations=count(),
    Resources=dcount(ResourceId),
    Subscriptions=dcount(SubAccountId),
    SnapshotDays=dcount(startofday(x_IngestionTime)),
    LatestObservation=max(x_IngestionTime)
| extend EvidenceState=iff(Observations == 0, 'Not reported - collection outcome unknown', 'Observed')
| project EvidenceState, Observations, Resources, Subscriptions, SnapshotDays, LatestObservation`;

const nonMatrixSummaryQuery = (definition) => `${currentDataset(definition)}
let Coverage = Quota()
| where x_SourceType =~ '${definition.sourceType}'
| summarize Observations=count(), SnapshotDays=dcount(startofday(x_IngestionTime));
let CurrentSummary = Current
| summarize ResourceKeys=count(), Stale=countif(datetime_diff('hour', now(), x_IngestionTime) > 48);
union
    (Coverage | project Sort=1, Metric='Observations', Value=Observations),
    (Coverage | project Sort=2, Metric='Snapshot days', Value=SnapshotDays),
    (CurrentSummary | project Sort=3, Metric='Current resource keys', Value=ResourceKeys),
    (CurrentSummary | project Sort=4, Metric='Stale', Value=Stale)
| order by Sort asc
| project Metric, Value`;

const nonMatrixCurrentQuery = (definition, id) => `${currentDataset(definition)}
Current
| extend
    CurrentValue=todouble(currentValue),
    LimitValue=todouble(limit),
    AgeHours=round(todouble(datetime_diff('minute', now(), x_IngestionTime)) / 60.0, 1)
| extend EvidenceState=${definition.inventory
        ? `case(
        AgeHours > 48, 'Stale',
        '${id}' == 'premium-ssd-v2' and (isnull(CurrentValue) or CurrentValue < 0), 'Invalid',
        'Observed inventory')`
        : `case(
        AgeHours > 48, 'Stale',
        'Unknown or unclassified')`}
| project
    Subscription=SubAccountId,
    Region=location,
    ${definition.inventory ? "Resource" : "Metric"}=coalesce(displayName, ResourceName),
    ${id === "premium-ssd-v2" ? "SizeGiB" : "Current"}=CurrentValue,
    Limit=iff(${definition.inventory}, real(null), LimitValue),
    Unit=iff('${id}' == 'premium-ssd-v2', 'GiB', unit),
    EvidenceState,
    AgeHours,
    LatestObservation=x_IngestionTime,
    ${definition.inventory ? "ResourceId" : "SourceKey"}=ResourceId
| order by Subscription asc, Region asc`;

const quotaSelectorQuery = (definition, id) => `${currentDataset(definition)}
Current
| order by SubAccountId asc, location asc, ResourceName asc
| serialize
| extend
    value=base64_encode_tostring(strcat(
        ResourceId, '|||',
        SubAccountId, '|||',
        location, '|||',
        ResourceName, '|||',
        unit, '|||',
        x_SourceVersion)),
    label=strcat(coalesce(displayName, ResourceName), ' | ', SubAccountId, ' | ', coalesce(location, 'global')),
    selected=row_number() == 1
| project value, label, selected`;

const quotaHistoryQuery = (definition, id, parameterName) => `let Selection=split(base64_decode_tostring('{${parameterName}}'), '|||');
let SelectedResourceId=tostring(Selection[0]);
let SelectedSubscription=tostring(Selection[1]);
let SelectedRegion=tostring(Selection[2]);
let SelectedResourceName=tostring(Selection[3]);
let SelectedUnit=tostring(Selection[4]);
let SelectedSourceVersion=tostring(Selection[5]);
let History = Quota()
| where x_SourceType =~ '${definition.sourceType}'
| where isnotempty(SelectedResourceId)
| where ResourceId =~ SelectedResourceId
| where SubAccountId =~ SelectedSubscription
| where location =~ SelectedRegion
| where ResourceName =~ SelectedResourceName
| where unit =~ SelectedUnit
| where x_SourceVersion =~ SelectedSourceVersion
| extend Day=startofday(x_IngestionTime)
| summarize arg_max(x_IngestionTime, *) by Day, ResourceId;
let SnapshotDays=toscalar(History | summarize dcount(Day));
History
| extend HistoryMode=case(
    SnapshotDays == 1, 'Collecting history - trends are disabled',
    ${definition.inventory}, 'Observed inventory history - runway is not applicable',
    SnapshotDays == 2, 'Observed delta - insufficient trend points',
    SnapshotDays < 7, 'Provisional trend - low confidence',
    'Compatible daily history')
| project
    Day,
    ${id === "premium-ssd-v2" ? "SizeGiB" : "Current"}=currentValue,
    Limit=iff(${definition.inventory}, real(null), limit),
    Unit=iff('${id}' == 'premium-ssd-v2', 'GiB', unit),
    HistoryMode,
    Ingested=x_IngestionTime
| order by Day asc`;

const inventoryHeatmapQuery = (definition, id) => `${currentDataset(definition)}
Current
| summarize
    ObservedObjects=count(),
    ObservedGiB=sum(todouble(currentValue)),
    LatestObservation=max(x_IngestionTime)
    by Subscription=SubAccountId, Region=coalesce(location, 'global')
| extend Cell=${id === "premium-ssd-v2"
        ? "strcat(round(ObservedGiB, 1), ' GiB | Observed inventory')"
        : "strcat(ObservedObjects, ' groups | Observed inventory')"}
| project Subscription, Region, Cell
| evaluate pivot(Region, take_any(Cell), Subscription)
| order by Subscription asc`;

const quotaHeatmapQuery = (definition, parameterName) => `let Selection=split(base64_decode_tostring('{${parameterName}}'), '|||');
let SelectedResourceName=tostring(Selection[3]);
let SelectedUnit=tostring(Selection[4]);
let SelectedSourceVersion=tostring(Selection[5]);
Quota()
| where x_SourceType =~ '${definition.sourceType}'
| where isnotempty(SelectedResourceName)
| where ResourceName =~ SelectedResourceName
| where unit =~ SelectedUnit
| where x_SourceVersion =~ SelectedSourceVersion
| summarize arg_max(x_IngestionTime, *) by ResourceId
| summarize
    Current=sum(todouble(currentValue)),
    Limit=sum(todouble(limit)),
    LatestObservation=max(x_IngestionTime)
    by Subscription=SubAccountId, Region=coalesce(location, 'global')
| extend Cell=strcat(
    round(Current, 1), ' current | ',
    round(Limit, 1), ' limit | ',
    SelectedUnit, ' | Unclassified')
| project Subscription, Region, Cell
| evaluate pivot(Region, take_any(Cell), Subscription)
| order by Subscription asc`;

const demandSelectorQuery = (definition, id) => {
    if (id === "premium-ssd-v2") {
        return `${currentDataset(definition)}
let Inventory = Current
| extend JoinResourceId=tolower(ResourceId)
| project JoinResourceId, InventoryResourceId=ResourceId, ResourceName, SubAccountId, location, SizeGiB=currentValue;
let Billed = Costs()
| where ChargePeriodStart >= startofday(now() - 430d)
${definition.demandPredicate}
| extend JoinResourceId=tolower(ResourceId)
| summarize EffectiveCost=sum(EffectiveCost)
    by JoinResourceId, ResourceId, x_SkuMeterCategory, x_SkuMeterSubcategory, SkuMeter, SkuPriceId, BillingCurrency;
Inventory
| join kind=leftouter Billed on JoinResourceId
| order by InventoryResourceId asc, BillingCurrency asc
| serialize
| extend
    value=base64_encode_tostring(strcat(
        InventoryResourceId, '|||',
        x_SkuMeterCategory, '|||',
        x_SkuMeterSubcategory, '|||',
        SkuMeter, '|||',
        SkuPriceId, '|||',
        BillingCurrency)),
    label=strcat(ResourceName, ' | ', coalesce(SkuMeter, 'No matched meter'), ' | ', coalesce(BillingCurrency, 'No currency')),
    selected=row_number() == 1
| project value, label, selected`;
    }
    const extraDimensions = id === "capacity-reservations"
        ? ", CapacityReservationId, CapacityReservationStatus"
        : "";
    const extraValue = id === "capacity-reservations"
        ? ", '|||', CapacityReservationId, '|||', CapacityReservationStatus"
        : "";
    return `Costs()
| where ChargePeriodStart >= startofday(now() - 430d)
${definition.demandPredicate}
| summarize EffectiveCost=sum(EffectiveCost)
    by x_SkuMeterCategory, x_SkuMeterSubcategory, SkuMeter, SkuPriceId, ConsumedUnit, BillingCurrency${extraDimensions}
| order by BillingCurrency asc, x_SkuMeterSubcategory asc, SkuMeter asc
| serialize
| extend
    value=base64_encode_tostring(strcat(
        x_SkuMeterCategory, '|||',
        x_SkuMeterSubcategory, '|||',
        SkuMeter, '|||',
        SkuPriceId, '|||',
        ConsumedUnit, '|||',
        BillingCurrency${extraValue})),
    label=strcat(SkuMeter, ' | ', ConsumedUnit, ' | ', BillingCurrency),
    selected=row_number() == 1
| project value, label, selected`;
};

const demandHistoryQuery = (definition, id, parameterName) => {
    if (id === "premium-ssd-v2") {
        return `let Selection=split(base64_decode_tostring('{${parameterName}}'), '|||');
let SelectedResourceId=tostring(Selection[0]);
let SelectedCategory=tostring(Selection[1]);
let SelectedSubcategory=tostring(Selection[2]);
let SelectedMeter=tostring(Selection[3]);
let SelectedPriceId=tostring(Selection[4]);
let SelectedCurrency=tostring(Selection[5]);
Costs()
| where ChargePeriodStart >= startofday(now() - 430d)
${definition.demandPredicate}
| where isnotempty(SelectedResourceId)
| where ResourceId =~ SelectedResourceId
| where x_SkuMeterCategory =~ SelectedCategory
| where x_SkuMeterSubcategory =~ SelectedSubcategory
| where SkuMeter =~ SelectedMeter
| where SkuPriceId =~ SelectedPriceId
| where BillingCurrency =~ SelectedCurrency
| summarize EffectiveCost=sum(EffectiveCost), Rows=count()
    by Day=startofday(ChargePeriodStart), ResourceId, SkuMeter, BillingCurrency
| project Day, ResourceId, SkuMeter, EffectiveCost, BillingCurrency, Rows
| order by Day asc`;
    }
    const reservationSelection = id === "capacity-reservations"
        ? `| where CapacityReservationId =~ tostring(Selection[6])
| where CapacityReservationStatus =~ tostring(Selection[7])`
        : "";
    return `let Selection=split(base64_decode_tostring('{${parameterName}}'), '|||');
let SelectedCategory=tostring(Selection[0]);
let SelectedSubcategory=tostring(Selection[1]);
let SelectedMeter=tostring(Selection[2]);
let SelectedPriceId=tostring(Selection[3]);
let SelectedUnit=tostring(Selection[4]);
let SelectedCurrency=tostring(Selection[5]);
Costs()
| where ChargePeriodStart >= startofday(now() - 430d)
${definition.demandPredicate}
| where isnotempty(SelectedMeter)
| where x_SkuMeterCategory =~ SelectedCategory
| where x_SkuMeterSubcategory =~ SelectedSubcategory
| where SkuMeter =~ SelectedMeter
| where SkuPriceId =~ SelectedPriceId
| where ConsumedUnit =~ SelectedUnit
| where BillingCurrency =~ SelectedCurrency
${reservationSelection}
| summarize BilledQuantity=sum(ConsumedQuantity), EffectiveCost=sum(EffectiveCost), Rows=count()
    by Day=startofday(ChargePeriodStart), SkuMeter, ConsumedUnit, BillingCurrency
| order by Day asc`;
};

const capacityReservationReconciliationQuery = `${currentDataset(nonMatrixDefinitions["capacity-reservations"])}
let Inventory = Current
| extend GroupKey=tolower(ResourceId)
| project GroupKey, GroupResourceId=ResourceId, GroupName=ResourceName, Subscription=SubAccountId, Region=location, InventoryObservation=x_IngestionTime;
let Billed = Costs()
| where ChargePeriodStart >= startofday(now() - 430d)
${nonMatrixDefinitions["capacity-reservations"].demandPredicate}
| extend CapacityReservationGroupId=extract(@"(?i)^(.*)/capacityreservations/[^/]+$", 1, CapacityReservationId)
| where isnotempty(CapacityReservationGroupId)
| extend GroupKey=tolower(CapacityReservationGroupId)
| summarize
    UsedHours=sumif(ConsumedQuantity, CapacityReservationStatus =~ 'Used'),
    UnusedHours=sumif(ConsumedQuantity, CapacityReservationStatus =~ 'Unused'),
    ReservationCount=dcount(CapacityReservationId),
    LinkedResources=dcount(ResourceId),
    FirstDay=min(startofday(ChargePeriodStart)),
    LastDay=max(startofday(ChargePeriodStart))
    by GroupKey, CostGroupResourceId=CapacityReservationGroupId, BillingCurrency;
Inventory
| join kind=fullouter Billed on GroupKey
| extend ReconciliationState=case(
    isnotempty(GroupResourceId) and isnotempty(CostGroupResourceId), 'Matched',
    isnotempty(GroupResourceId), 'Inventory only',
    'Cost only')
| project
    CapacityReservationGroup=coalesce(GroupResourceId, CostGroupResourceId),
    GroupName,
    Subscription,
    Region,
    ReconciliationState,
    UsedHours,
    UnusedHours,
    ReservationCount,
    LinkedResources,
    BillingCurrency,
    FirstDay,
    LastDay,
    InventoryObservation
| order by CapacityReservationGroup asc, BillingCurrency asc`;

const nonMatrixView = (registryItem, definition) => {
    const prefix = registryItem.id
        .split("-")
        .map((part) => part[0].toUpperCase() + part.slice(1))
        .join("");
    const quotaParameter = `Supply${prefix}QuotaSeries`;
    const demandParameter = `Supply${prefix}DemandSeries`;
    const panels = [
        {
            id: "summary",
            role: "summary",
            title: `${registryItem.title} summary`,
            query: nonMatrixSummaryQuery(definition),
            visualization: "tiles",
            width: "100",
            size: 0,
        },
        {
            id: "coverage",
            role: "coverage",
            title: "Evidence coverage",
            query: nonMatrixCoverageQuery(definition),
            width: "100",
            size: 0,
        },
        {
            id: "current",
            role: "current",
            title: definition.inventory ? "Current inventory" : "Current quota",
            query: nonMatrixCurrentQuery(definition, registryItem.id),
            width: "100",
            size: 3,
            noDataMessage: registryItem.emptyLabel,
        },
        {
            id: "history",
            role: "history",
            title: "Observed history",
            query: quotaHistoryQuery(definition, registryItem.id, quotaParameter),
            width: "50",
            size: 2,
            noDataMessage: "Select an exact source key with compatible observations to view history.",
        },
        {
            id: "heatmap",
            role: "heatmap",
            title: "Subscription x region",
            query: definition.inventory
                ? inventoryHeatmapQuery(definition, registryItem.id)
                : quotaHeatmapQuery(definition, quotaParameter),
            width: "50",
            size: 2,
        },
        {
            id: "demand",
            role: "demand",
            title: registryItem.id === "premium-ssd-v2" ? "Parallel matched cost" : "Parallel billed demand",
            query: demandHistoryQuery(definition, registryItem.id, demandParameter),
            width: "100",
            size: 2,
            noDataMessage: "Select one exact meter, unit, price, and currency series. Quota and billed demand are never combined.",
        },
    ];
    if (registryItem.id === "capacity-reservations") {
        panels.push({
            id: "reconciliation",
            role: "reconciliation",
            title: "Inventory and billing reconciliation",
            query: capacityReservationReconciliationQuery,
            width: "100",
            size: 3,
            noDataMessage: "No capacity reservation inventory or linked billing data is available.",
        });
    }
    return {
        ...registryItem,
        kind: "evidence",
        description: {
            storage: "Review raw provider-reported Storage observations. This class remains unclassified because the capacity registry does not define a Storage utilization metric.",
            "capacity-reservations": "Review reservation-group inventory independently from billed Used and Unused hours.",
            "premium-ssd-v2": "Review provisioned Premium SSD v2 GiB independently from quota, availability, and matched cost.",
        }[registryItem.id],
        nextAction: {
            storage: "Validate ingestion and expected subscription-region coverage before drawing a Storage quota conclusion.",
            "capacity-reservations": "Inspect reservation quantity, SKU, zones, sharing, associations, and utilization in Azure; inventory count is not reserved capacity.",
            "premium-ssd-v2": "Inspect disk zone, attachment, IOPS, throughput, and service quota separately; observed GiB is inventory, not quota.",
        }[registryItem.id],
        controls: [
            { name: quotaParameter, label: definition.inventory ? "Inventory series" : "Quota series", query: quotaSelectorQuery(definition, registryItem.id) },
            { name: demandParameter, label: registryItem.id === "premium-ssd-v2" ? "Matched cost series" : "Billed-demand series", query: demandSelectorQuery(definition, registryItem.id) },
        ],
        panels,
    };
};

const registryById = new Map(supplyRegistry.map((item) => [item.id, item]));

export const supplyViews = Object.freeze([
    {
        id: "home",
        label: "Home",
        title: "Supply coverage",
        kind: "home",
        description: "Seven independent quota and inventory sources. Missing observations are unknown, not healthy.",
        panels: [
            {
                id: "coverage",
                role: "coverage-index",
                title: "Quota coverage",
                query: supplyQuery,
                width: "100",
                size: 3,
                noDataMessage: "Supply coverage is unavailable.",
                exportFieldName: "ClassId",
                exportParameterName: "SelectedSupplyTab",
                exportDefaultValue: "home",
            },
        ],
    },
    matrixView(registryById.get("app-service"), matrixDefinitions["app-service"]),
    matrixView(registryById.get("azure-ai"), matrixDefinitions["azure-ai"]),
    matrixView(registryById.get("compute"), matrixDefinitions.compute),
    matrixView(registryById.get("azure-sql"), matrixDefinitions["azure-sql"]),
    nonMatrixView(registryById.get("storage"), nonMatrixDefinitions.storage),
    nonMatrixView(registryById.get("capacity-reservations"), nonMatrixDefinitions["capacity-reservations"]),
    nonMatrixView(registryById.get("premium-ssd-v2"), nonMatrixDefinitions["premium-ssd-v2"]),
]);
