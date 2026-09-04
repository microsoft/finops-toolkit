import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import test from "node:test";

process.env.FTK_LOCAL_DASHBOARD_TEST = "1";

const kusto = await import("../kusto.mjs");
const azureMonitor = await import("../azure-monitor.mjs");
const extension = await import("../extension.mjs");
const app = await import("../public/app.js");
const ui = await import("../public/ui.js");

const QUOTA_SCHEMA_FIELDS = [
  "ResourceId", "ResourceName", "SubAccountId", "location", "currentValue",
  "limit", "unit", "x_SourceType", "x_SourceVersion", "x_IngestionTime",
];
const COST_SCHEMA_FIELDS = [
  "ChargePeriodStart", "ProviderName", "ChargeCategory", "ResourceId",
  "SubAccountId", "RegionId", "x_ResourceType", "x_SkuMeterCategory",
  "x_SkuMeterSubcategory", "SkuMeter", "SkuPriceId", "EffectiveCost",
  "BillingCurrency", "ConsumedQuantity", "ConsumedUnit",
  "CapacityReservationId", "CapacityReservationStatus",
];

function kustoResponse(rows, columns = rows[0] ? Object.keys(rows[0]) : []) {
  return new Response(JSON.stringify({
    Tables: [{
      TableName: "Table_0",
      Columns: columns.map((ColumnName) => ({ ColumnName })),
      Rows: rows.map((row) => columns.map((column) => row[column])),
    }],
  }), { headers: { "Content-Type": "application/json" } });
}

async function startCapacityServer(t, options = {}) {
  const quotaFields = options.quotaFields || QUOTA_SCHEMA_FIELDS;
  const costFields = options.costFields || COST_SCHEMA_FIELDS;
  const server = createServer(async (req, res) => {
    let body = "";
    for await (const chunk of req) body += chunk;
    const { csl } = JSON.parse(body);
    const fields = csl.includes("Quota()") && csl.includes("| getschema")
      ? quotaFields
      : csl.startsWith("Costs() | getschema")
        ? costFields
        : null;
    const rows = fields
      ? fields.map((ColumnName) => ({ ColumnName, ColumnType: "System.String" }))
      : typeof options.rows === "function"
        ? options.rows(csl)
        : [];
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(await kustoResponse(rows).text());
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  t.after(() => server.close());
  return `http://127.0.0.1:${server.address().port}`;
}

test("connection validation permits only local loopback or remote Kusto origins", () => {
  assert.deepEqual(
    kusto.normalizeConnection("http://LOCALHOST:8082/", " Hub "),
    { clusterUri: "http://localhost:8082", database: "Hub", tenantId: null, mode: "local", authentication: "none" }
  );
  assert.deepEqual(
    kusto.normalizeConnection(
      "https://example-cluster.westus.kusto.windows.net",
      "Hub",
      "72F988BF-86F1-41AF-91AB-2D7CD011DB47"
    ),
    {
      clusterUri: "https://example-cluster.westus.kusto.windows.net",
      database: "Hub",
      tenantId: "72f988bf-86f1-41af-91ab-2d7cd011db47",
      mode: "remote",
      authentication: "azure-cli",
    }
  );
  assert.equal(
    kusto.normalizeConnection(
      "http://localhost:8082",
      "Hub",
      "72F988BF-86F1-41AF-91AB-2D7CD011DB47"
    ).tenantId,
    "72f988bf-86f1-41af-91ab-2d7cd011db47"
  );
  assert.throws(
    () => kusto.normalizeConnection("https://example-cluster.westus.kusto.windows.net", "Hub", "not-a-tenant"),
    /valid Microsoft Entra tenant GUID/
  );
  assert.deepEqual(
    kusto.azureCliTokenArgs("72F988BF-86F1-41AF-91AB-2D7CD011DB47"),
    [
      "account", "get-access-token",
      "--resource", "https://api.kusto.windows.net",
      "--tenant", "72f988bf-86f1-41af-91ab-2d7cd011db47",
      "--output", "json",
    ]
  );
  for (const uri of [
    "http://example.com",
    "https://example.com",
    "https://kusto.windows.net",
    "https://user:pass@cluster.westus.kusto.windows.net",
    "https://cluster.westus.kusto.windows.net/path",
    "https://cluster.westus.kusto.windows.net?x=1",
  ]) {
    assert.throws(() => kusto.normalizeConnection(uri, "Hub"));
  }
});

test("AI Foundry Azure CLI tokens are tenant-scoped and resource-bound", () => {
  const tenant = "72F988BF-86F1-41AF-91AB-2D7CD011DB47";
  assert.deepEqual(
    azureMonitor.azureMonitorTokenArgs("https://metrics.monitor.azure.com/", tenant),
    [
      "account", "get-access-token",
      "--resource", "https://metrics.monitor.azure.com/",
      "--tenant", tenant.toLowerCase(),
      "--output", "json",
    ]
  );
  assert.ok(
    azureMonitor.azureMonitorTokenArgs("https://management.azure.com/", tenant)
      .includes("https://management.azure.com/")
  );
  assert.ok(
    azureMonitor.azureMonitorTokenArgs("https://api.loganalytics.io", tenant)
      .includes("https://api.loganalytics.io")
  );
  assert.throws(() => azureMonitor.normalizeAzureTenantId("organizations"), /tenant GUID/);
  assert.throws(
    () => azureMonitor.azureMonitorTokenArgs("https://management.core.windows.net/", tenant),
    /Unsupported Azure token resource/
  );
});

test("persisted configuration ignores the retired Azure Monitor tenant field", () => {
  assert.equal(
    extension.normalizePersistedConfig({ monitorTenantId: "11111111-2222-4333-8444-555555555555" }).monitorTenantId,
    undefined
  );
  assert.equal(extension.normalizePersistedConfig({ tenantId: "11111111-2222-4333-8444-555555555555" }).tenantId,
    "11111111-2222-4333-8444-555555555555");
});

test("AI Foundry metrics preserve dimensions, reconcile TotalTokens, and price explicit blocks", () => {
  const metric = (name, metadata, data, valueKey = "total") => ({
    name: { value: name },
    errorCode: "Success",
    timeseries: [{
      metadatavalues: Object.entries(metadata).map(([key, value]) => ({ name: { value: key }, value })),
      data: data.map(([timeStamp, value]) => ({ timeStamp, [valueKey]: value })),
    }],
  });
  const identity = { ModelDeploymentName: "chat-prod" };
  const timestamp = "2026-03-01T00:00:00Z";
  const subscriptionId = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
  const accountId = `/subscriptions/${subscriptionId}/resourceGroups/ai-rg/providers/Microsoft.CognitiveServices/accounts/foundry`;
  const resource = (value) => ({ resourceid: accountId, value });
  const payloads = [
    {
      group: "tokens",
      payload: {
        values: [resource([
            metric("InputTokens", identity, [[timestamp, 1000]]),
            metric("OutputTokens", identity, [[timestamp, 500]]),
            metric("TotalTokens", identity, [[timestamp, 1500]]),
        ])],
      },
    },
    {
      group: "requests",
      payload: {
        values: [resource([metric("ModelRequests", identity, [[timestamp, 12]])])],
      },
    },
    {
      group: "request-errors",
      payload: {
        values: [resource([metric("ModelRequests", { StatusCode: "429" }, [[timestamp, 2]])])],
      },
    },
    {
      group: "latency",
      payload: {
        values: [resource([
            metric("TimeToLastByte", identity, [[timestamp, 250]], "average"),
            metric("AzureOpenAITTLTInMS", identity, [[timestamp, 275]], "average"),
        ])],
      },
    },
    {
      group: "throughput",
      payload: {
        values: [resource([
          metric("AzureOpenAITokenPerSecond", identity, [[timestamp, 40]], "average"),
        ])],
      },
    },
  ];
  const prices = [
    {
      SubAccountId: subscriptionId,
      Direction: "Input",
      Variant: "Standard",
      ModelText: "GPT-4o 2024-08-06 input tokens",
      PriceRegionId: "eastus",
      PriceScope: "Regional",
      SelectedUnitPrice: 0.002,
      x_PricingBlockSize: 1000,
      PricingCurrency: "USD",
      PriceSource: "Contracted",
      ScopeMatch: true,
      ScopeCurrency: "USD",
      x_EffectivePeriodStart: "2026-01-01T00:00:00Z",
      x_EffectivePeriodEnd: null,
    },
    {
      SubAccountId: subscriptionId,
      Direction: "Output",
      Variant: "Standard",
      ModelText: "GPT-4o 2024-08-06 output tokens",
      PriceRegionId: "eastus",
      PriceScope: "Regional",
      SelectedUnitPrice: 0.008,
      x_PricingBlockSize: 1000,
      PricingCurrency: "USD",
      PriceSource: "Contracted",
      ScopeMatch: true,
      ScopeCurrency: "USD",
      x_EffectivePeriodStart: "2026-01-01T00:00:00Z",
      x_EffectivePeriodEnd: null,
    },
  ];
  const flattened = azureMonitor.flattenMetricBatch(payloads);
  const account = {
    id: accountId,
    name: "foundry",
    resourceGroup: "ai-rg",
    subscriptionId,
    location: "eastus",
    kind: "AIServices",
    sku: "S0",
  };
  const deployment = {
    name: "chat-prod",
    skuName: "Standard",
    modelName: "gpt-4o",
    modelVersion: "2024-08-06",
  };
  const result = azureMonitor.summarizeFoundryMetrics(
    flattened,
    [account],
    new Map([[accountId.toLowerCase(), [deployment]]]),
    new Map([[subscriptionId, prices]])
  );
  assert.equal(result.summary.TotalTokens, 1500);
  assert.equal(result.summary.InputTokens, 1000);
  assert.equal(result.summary.OutputTokens, 500);
  assert.equal(result.summary.Requests, 12);
  assert.equal(result.summary.Errors, 2);
  assert.equal(result.summary.ErrorRate, 2 / 12);
  assert.equal(result.summary.EstimatedCost, 0.006);
  assert.equal(result.summary.InputEstimatedCost, 0.002);
  assert.equal(result.summary.OutputEstimatedCost, 0.004);
  assert.equal(result.summary.PriceCoverage, 1);
  assert.equal(result.stats.inputTokens[0].EstimatedCost, 0.002);
  assert.equal(result.stats.outputTokens[0].EstimatedCost, 0.004);
  assert.equal(result.charts.inputTokens[0].Points[0].Cost, 0.002);
  assert.equal(result.charts.outputTokens[0].Points[0].Cost, 0.004);
  assert.equal(result.charts.totalTokens[0].Points[0].Cost, 0.006);
  assert.equal(result.charts.latency.find((series) => series.Name.includes("Time to last byte")).Points[0].Value, 250);
  assert.equal(result.charts.tokensPerSecond[0].Points[0].Value, 40);
});

test("AI Foundry price matching rejects specialized, missing-block, and disagreeing rates", () => {
  const base = {
    Direction: "Input",
    Variant: "Standard",
    ModelText: "GPT-4o 2024-08-06 input tokens",
    PriceRegionId: "eastus",
    PriceScope: "Regional",
    SelectedUnitPrice: 0.002,
    x_PricingBlockSize: 1000,
    PricingCurrency: "USD",
    ScopeMatch: true,
    ScopeCurrency: "USD",
    x_EffectivePeriodStart: "2026-01-01T00:00:00Z",
    x_EffectivePeriodEnd: null,
  };
  const deployment = {
    name: "chat-prod",
    skuName: "Standard",
    modelName: "gpt-4o",
    modelVersion: "2024-08-06",
  };
  assert.equal(
    azureMonitor.matchFoundryPrice("gpt-4o", "2024-08-06", "Input", "eastus", [{ ...base, Variant: "Batch" }], deployment, "2026-03-01T00:00:00Z").status,
    "unmatched"
  );
  assert.equal(
    azureMonitor.matchFoundryPrice("gpt-4o", "2024-08-06", "Input", "eastus", [{ ...base, x_PricingBlockSize: null }], deployment, "2026-03-01T00:00:00Z").status,
    "unmatched"
  );
  assert.equal(
    azureMonitor.matchFoundryPrice("gpt-4o", "2024-08-06", "Input", "eastus", [
      base,
      { ...base, SelectedUnitPrice: 0.003, BillingAccountId: "different" },
    ], deployment, "2026-03-01T00:00:00Z").status,
    "ambiguous"
  );
  assert.equal(
    azureMonitor.matchFoundryPrice("gpt-4o", "", "Input", "eastus", [base], deployment, "2026-03-01T00:00:00Z").status,
    "unmatched"
  );
  assert.equal(
    azureMonitor.matchFoundryPrice("gpt-4o", "2024-08-06", "Input", "eastus", [
      { ...base, ScopeMatch: false },
    ], deployment, "2026-03-01T00:00:00Z").status,
    "unmatched"
  );
  assert.equal(
    azureMonitor.matchFoundryPrice(
      "gpt-4.1",
      "2025-04-14",
      "Input",
      "eastus",
      [{ ...base, ModelText: "GPT-4.1-mini 2025-04-14 input tokens" }],
      { ...deployment, modelName: "gpt-4.1", modelVersion: "2025-04-14" },
      "2026-03-01T00:00:00Z"
    ).status,
    "unmatched",
    "a base model must not use a suffixed model's price"
  );
  const previousMonth = {
    ...base,
    x_EffectivePeriodStart: "2026-08-01T00:00:00Z",
    x_EffectivePeriodEnd: "2026-09-01T00:00:00Z",
  };
  const fallback = azureMonitor.matchFoundryPrice(
    "gpt-4o",
    "2024-08-06",
    "Input",
    "eastus",
    [previousMonth],
    deployment,
    "2026-09-02T00:00:00Z"
  );
  assert.equal(fallback.status, "matched");
  assert.equal(fallback.rateBasis, "previous-month");
  assert.match(fallback.reason, /previous month's rate/);
  assert.equal(
    azureMonitor.matchFoundryPrice(
      "gpt-4o",
      "2024-08-06",
      "Input",
      "eastus",
      [previousMonth],
      deployment,
      "2026-10-01T00:00:00Z"
    ).status,
    "unmatched",
    "the fallback must not use a price sheet older than the previous month"
  );
  const currentMonth = {
    ...base,
    SelectedUnitPrice: 0.003,
    x_EffectivePeriodStart: "2026-09-01T00:00:00Z",
    x_EffectivePeriodEnd: "2026-10-01T00:00:00Z",
  };
  const current = azureMonitor.matchFoundryPrice(
    "gpt-4o",
    "2024-08-06",
    "Input",
    "eastus",
    [previousMonth, currentMonth],
    deployment,
    "2026-09-02T00:00:00Z"
  );
  assert.equal(current.status, "matched");
  assert.equal(current.rateBasis, "active");
  assert.equal(current.unitPricePerToken, 0.000003);
  const cached = azureMonitor.matchFoundryPrice(
    "gpt-4o",
    "2024-08-06",
    "Cached input",
    "eastus",
    [{ ...base, Variant: "Cached", ModelText: "GPT-4o 2024-08-06 cached input tokens", SelectedUnitPrice: 0.0005 }],
    deployment,
    "2026-03-01T00:00:00Z"
  );
  assert.equal(cached.status, "matched");
  assert.equal(cached.unitPricePerToken, 0.0000005);
  assert.equal(
    azureMonitor.matchFoundryPrice(
      "gpt-4o",
      "2024-08-06",
      "Cached input",
      "eastus",
      [{
        ...base,
        Variant: "Cached",
        ModelText: "GPT-4o 2024-08-06 LongCo Cd Inp tokens",
        SkuMeter: "GPT-4o 2024-08-06 LongCo Cd Inp tokens",
      }],
      deployment,
      "2026-03-01T00:00:00Z"
    ).status,
    "unmatched",
    "cached-input estimates must not mix in long-context cache meters"
  );

  const lunaDeployment = {
    name: "gpt-5.6-luna",
    skuName: "GlobalStandard",
    modelName: "gpt-5.6-luna",
    modelVersion: "2026-07-09",
  };
  const lunaPrice = {
    Direction: "Input",
    Variant: "Standard",
    ModelText: "5.6 luna ShortCo Inp Std Gl 1M Tokens",
    SkuMeter: "5.6 luna ShortCo Inp Std Gl 1M Tokens",
    PriceScope: "Global",
    SelectedUnitPrice: 2,
    x_PricingBlockSize: 10000000,
    PricingCurrency: "USD",
    ScopeMatch: true,
    ScopeCurrency: "USD",
    x_EffectivePeriodStart: "2026-08-01T00:00:00Z",
    x_EffectivePeriodEnd: "2026-09-01T00:00:00Z",
  };
  const luna = azureMonitor.matchFoundryPrice(
    "gpt-5.6-luna",
    "2026-07-09",
    "Input",
    "eastus",
    [lunaPrice],
    lunaDeployment,
    "2026-09-02T00:00:00Z"
  );
  assert.equal(luna.status, "matched");
  assert.equal(luna.rateBasis, "previous-month");
  assert.equal(luna.unitPricePerToken, 0.0000002);
  assert.equal(
    azureMonitor.matchFoundryPrice(
      "gpt-5.6-luna",
      "2026-07-09",
      "Input",
      "eastus",
      [{ ...lunaPrice, ModelText: "5.6 luna LongCo Inp Std Gl 1M Tokens", SkuMeter: "5.6 luna LongCo Inp Std Gl 1M Tokens" }],
      lunaDeployment,
      "2026-09-02T00:00:00Z"
    ).status,
    "unmatched",
    "the canonical estimate must not mix long-context rates into undifferentiated token metrics"
  );
});

test("agent token pricing reports partial coverage without treating estimates as billed cost", () => {
  const account = {
    id: "/subscriptions/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/resourceGroups/ai/providers/Microsoft.CognitiveServices/accounts/foundry",
    subscriptionId: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
    location: "eastus",
  };
  const deployment = {
    name: "chat-prod", skuName: "Standard", modelName: "gpt-4o", modelVersion: "2024-08-06",
  };
  const price = {
    Direction: "Input", Variant: "Standard", ModelText: "GPT-4o 2024-08-06 input tokens",
    PriceRegionId: "eastus", PriceScope: "Regional", SelectedUnitPrice: 0.002,
    x_PricingBlockSize: 1000, PricingCurrency: "USD", ScopeMatch: true, ScopeCurrency: "USD",
    x_EffectivePeriodStart: "2026-01-01T00:00:00Z", x_EffectivePeriodEnd: null,
  };
  const result = azureMonitor.priceAgentTokenUsage(
    {
      AccountId: account.id, Model: "chat-prod", InputTokens: 1000,
      CachedInputTokens: 0, OutputTokens: 500,
    },
    [account],
    new Map([[account.id.toLowerCase(), [deployment]]]),
    new Map([[account.subscriptionId, [price]]]),
    "2026-03-01T00:00:00Z"
  );
  assert.equal(result.PriceStatus, "partial");
  assert.equal(result.PriceCoverage, 2 / 3);
  assert.equal(result.EstimatedCost, 0.002);
  assert.equal("BilledCost" in result, false);
});

test("AI Foundry dashboard batches platform metrics and supports estate drill-down", async () => {
  const tenantId = "11111111-2222-4333-8444-555555555555";
  const subscriptionId = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
  const accountA = `/subscriptions/${subscriptionId}/resourceGroups/ai-rg/providers/Microsoft.CognitiveServices/accounts/foundry-a`;
  const accountB = `/subscriptions/${subscriptionId}/resourceGroups/ai-rg/providers/Microsoft.CognitiveServices/accounts/foundry-b`;
  const accounts = [
    { id: accountA, name: "foundry-a", resourceGroup: "ai-rg", subscriptionId, location: "eastus", kind: "AIServices", sku: "S0" },
    { id: accountB, name: "foundry-b", resourceGroup: "ai-rg", subscriptionId, location: "eastus", kind: "AIServices", sku: "S0" },
  ];
  const tokenCalls = [];
  const fetchCalls = [];
  const execFileFn = async (_file, args) => {
    tokenCalls.push(args);
    return {
      stdout: JSON.stringify({
        accessToken: `token-${tokenCalls.length}`,
        expires_on: Math.floor(Date.now() / 1000) + 3600,
      }),
    };
  };
  const metricPayload = (url, resourceIds) => {
    const parsed = new URL(url);
    const metricNames = parsed.searchParams.get("metricnames").split(",");
    const filter = parsed.searchParams.get("filter");
    return {
      values: resourceIds.map((resourceId, accountIndex) => ({
        resourceid: resourceId,
        value: metricNames.map((metricName) => {
          const base = accountIndex + 1;
          const modelName = accountIndex ? "gpt-4o-mini" : "gpt-4o";
          const modelVersion = accountIndex ? "2024-07-18" : "2024-08-06";
          const values = {
            InputTokens: 1000 * base,
            OutputTokens: 500 * base,
            TotalTokens: 1500 * base,
            TimeToLastByte: 200 * base,
            AzureOpenAITTLTInMS: 250 * base,
            AzureOpenAITokenPerSecond: 40 * base,
            AzureOpenAIContextTokensCacheMatchRate: 80,
          };
          const metadata = [
            { name: { value: "ModelDeploymentName" }, value: "chat-prod" },
            { name: { value: "ModelName" }, value: modelName },
            { name: { value: "ModelVersion" }, value: modelVersion },
          ];
          const timeseries = metricName === "ModelRequests"
            ? [
              {
                metadatavalues: [...metadata, { name: { value: "StatusCode" }, value: "200" }],
                data: [{ timeStamp: "2026-03-01T12:00:00Z", total: 9 * base }],
              },
              {
                metadatavalues: [...metadata, { name: { value: "StatusCode" }, value: "429" }],
                data: [{ timeStamp: "2026-03-01T12:00:00Z", total: base }],
              },
            ]
            : [{
              metadatavalues: metadata,
              data: [{
                timeStamp: "2026-03-01T12:00:00Z",
                [["InputTokens", "OutputTokens", "TotalTokens"].includes(metricName) ? "total" : "average"]:
                  values[metricName],
              }],
            }];
          return {
            name: { value: metricName },
            timeseries,
          };
        }),
      })),
    };
  };
  const fetchFn = async (url, init = {}) => {
    const target = String(url);
    fetchCalls.push({ url: target, init });
    if (target.includes("Microsoft.ResourceGraph")) {
      return Response.json({ data: accounts });
    }
    if (target.includes("/batch?")) {
      const requests = JSON.parse(init.body).requests;
      return Response.json({
        responses: requests.map((request, index) => ({
          httpStatusCode: 200,
          content: {
            value: [{
              name: "chat-prod",
              sku: { name: "GlobalStandard" },
              properties: {
                model: {
                  name: index ? "gpt-4o-mini" : "gpt-4o",
                  version: index ? "2024-07-18" : "2024-08-06",
                  format: "OpenAI",
                },
                provisioningState: "Succeeded",
              },
            }],
          },
        })),
      });
    }
    if (target.includes(".metrics.monitor.azure.com/")) {
      return Response.json(metricPayload(target, JSON.parse(init.body).resourceids));
    }
    throw new Error(`Unexpected test URL: ${url}`);
  };
  const priceRows = [
    {
      SubAccountId: subscriptionId,
      Direction: "Input",
      Variant: "Standard",
      ModelText: "GPT-4o 2024-08-06 input tokens",
      PriceScope: "Global",
      SelectedUnitPrice: 0.002,
      x_PricingBlockSize: 1000,
      PricingCurrency: "USD",
      ScopeMatch: true,
      ScopeCurrency: "USD",
      x_EffectivePeriodStart: "2026-03-01T00:00:00Z",
      x_EffectivePeriodEnd: "2026-04-01T00:00:00Z",
    },
    {
      SubAccountId: subscriptionId,
      Direction: "Output",
      Variant: "Standard",
      ModelText: "GPT-4o 2024-08-06 output tokens",
      PriceScope: "Global",
      SelectedUnitPrice: 0.008,
      x_PricingBlockSize: 1000,
      PricingCurrency: "USD",
      ScopeMatch: true,
      ScopeCurrency: "USD",
      x_EffectivePeriodStart: "2026-03-01T00:00:00Z",
      x_EffectivePeriodEnd: "2026-04-01T00:00:00Z",
    },
    {
      SubAccountId: subscriptionId,
      Direction: "Input",
      Variant: "Standard",
      ModelText: "GPT-4o-mini 2024-07-18 input tokens",
      PriceScope: "Global",
      SelectedUnitPrice: 0.002,
      x_PricingBlockSize: 1000,
      PricingCurrency: "USD",
      ScopeMatch: true,
      ScopeCurrency: "USD",
      x_EffectivePeriodStart: "2026-03-01T00:00:00Z",
      x_EffectivePeriodEnd: "2026-04-01T00:00:00Z",
    },
    {
      SubAccountId: subscriptionId,
      Direction: "Output",
      Variant: "Standard",
      ModelText: "GPT-4o-mini 2024-07-18 output tokens",
      PriceScope: "Global",
      SelectedUnitPrice: 0.008,
      x_PricingBlockSize: 1000,
      PricingCurrency: "USD",
      ScopeMatch: true,
      ScopeCurrency: "USD",
      x_EffectivePeriodStart: "2026-03-01T00:00:00Z",
      x_EffectivePeriodEnd: "2026-04-01T00:00:00Z",
    },
  ];
  const priceCalls = [];
  const common = {
    connection: {},
    database: "Hub",
    tenantId,
    preset: "24h",
    getPrices: async (_connection, _database, subscriptionIds, options) => {
      priceCalls.push({ subscriptionIds, models: options.models });
      return priceRows;
    },
    options: { execFileFn, fetchFn, now: "2026-03-02T00:00:00Z" },
  };
  const payload = await azureMonitor.getFoundryDashboard(common);
  assert.equal(payload.selectedAccountId, null);
  assert.equal(payload.accounts.length, 2);
  assert.equal(payload.panels.length, 11);
  assert.equal(payload.data.summary.InputTokens, 3000);
  assert.equal(payload.data.summary.OutputTokens, 1500);
  assert.equal(payload.data.summary.TotalTokens, 4500);
  assert.equal(payload.data.summary.Requests, 30);
  assert.equal(payload.data.summary.Errors, 3);
  assert.ok(Math.abs(payload.data.summary.EstimatedCost - 0.018) < 1e-12);
  assert.equal(payload.data.summary.PriceCoverage, 1);
  assert.equal(payload.data.charts.modelRequests.length, 2);
  assert.equal(payload.data.charts.requestErrors[0].Points[0].Value, 3);
  assert.equal(payload.data.charts.latency.length, 4);
  assert.equal(payload.data.charts.tokensPerSecond.length, 2);
  assert.equal(payload.data.charts.cacheMatchRate.length, 2);
  assert.deepEqual(payload.data.stats.costs.map((row) => row.Model).sort(), ["gpt-4o", "gpt-4o-mini"]);
  assert.equal("agents" in payload, false);
  assert.deepEqual(priceCalls, [{
    subscriptionIds: [subscriptionId],
    models: ["gpt-4o", "gpt-4o-mini"],
  }]);
  assert.equal(tokenCalls.length, 2);
  assert.ok(tokenCalls.some((args) => args.includes("https://management.azure.com/")));
  assert.ok(tokenCalls.some((args) => args.includes("https://metrics.monitor.azure.com/")));
  assert.equal(fetchCalls.filter((call) => call.url.includes(".metrics.monitor.azure.com/")).length, 1);
  assert.equal(fetchCalls.filter((call) => call.url.includes("/batch?")).length, 1);
  assert.ok(fetchCalls.filter((call) => call.url.includes(".metrics.monitor.azure.com/"))
    .every((call) => JSON.parse(call.init.body).resourceids.length === 2));
  assert.ok(fetchCalls.every((call) => !call.url.includes("applicationinsights")));
  assert.ok(fetchCalls.every((call) => !call.url.includes("loganalytics")));

  const scoped = await azureMonitor.getFoundryDashboard({ ...common, accountId: accountB });
  assert.equal(scoped.selectedAccountId, accountB);
  assert.equal(scoped.data.summary.AccountCount, 1);
  assert.equal(scoped.data.summary.TotalTokens, 3000);
  assert.ok(scoped.data.charts.modelRequests.every((series) => !series.Name.includes(" / ")));
  assert.equal(fetchCalls.filter((call) => call.url.includes(".metrics.monitor.azure.com/")).length, 1);
});

test("AI Foundry panel contract matches the canonical Grafana export", () => {
  assert.deepEqual(
    azureMonitor.FOUNDRY_PANEL_CONTRACT.map(({ id, title, type, gridPos, unit, style, fillOpacity }) =>
      ({ id, title, type, gridPos, unit, style, fillOpacity })),
    [
      { id: 13, title: "Estimated Cost", type: "stat", gridPos: { h: 4, w: 24, x: 0, y: 0 }, unit: "currency", style: undefined, fillOpacity: undefined },
      { id: 11, title: "Input Tokens (total)", type: "stat", gridPos: { h: 5, w: 24, x: 0, y: 4 }, unit: "short", style: undefined, fillOpacity: undefined },
      { id: 12, title: "Output Tokens (total)", type: "stat", gridPos: { h: 5, w: 24, x: 0, y: 9 }, unit: "short", style: undefined, fillOpacity: undefined },
      { id: 2, title: "Model Requests", type: "timeseries", gridPos: { h: 10, w: 12, x: 0, y: 14 }, unit: "short", style: "bars", fillOpacity: 60 },
      { id: 16, title: "Non-200 Model Requests (Throttling & Errors)", type: "timeseries", gridPos: { h: 10, w: 12, x: 12, y: 14 }, unit: "short", style: "bars", fillOpacity: 80 },
      { id: 7, title: "Average Latency (Time to Last Byte)", type: "timeseries", gridPos: { h: 10, w: 12, x: 0, y: 24 }, unit: "ms", style: "lines", fillOpacity: 21 },
      { id: 17, title: "Tokens per Second (OpenAI models)", type: "timeseries", gridPos: { h: 10, w: 12, x: 12, y: 24 }, unit: "short", style: "lines", fillOpacity: 10 },
      { id: 4, title: "Input Tokens", type: "timeseries", gridPos: { h: 10, w: 12, x: 0, y: 34 }, unit: "short", style: "bars", fillOpacity: 60 },
      { id: 5, title: "Output Tokens", type: "timeseries", gridPos: { h: 10, w: 12, x: 12, y: 34 }, unit: "short", style: "bars", fillOpacity: 60 },
      { id: 8, title: "Total Tokens", type: "timeseries", gridPos: { h: 10, w: 12, x: 0, y: 44 }, unit: "short", style: "bars", fillOpacity: 60 },
      { id: 14, title: "Token Cache Match Rate (OpenAI models)", type: "timeseries", gridPos: { h: 10, w: 12, x: 12, y: 44 }, unit: "percent", style: "lines", fillOpacity: 21 },
    ]
  );
});

test("AI Foundry Hub price query is bounded and preserves pricing identity", async () => {
  let query = "";
  await kusto.getFoundryPriceCatalog(
    { clusterUri: "http://localhost:8082", database: "Hub" },
    "Hub",
    [
      "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
      "11111111-2222-4333-8444-555555555555",
    ],
    {
      fetchImpl: async (_url, init) => {
        query = JSON.parse(init.body).csl;
        return kustoResponse([]);
      },
      start: "2026-01-01T00:00:00Z",
      end: "2026-03-01T00:00:00Z",
      models: ["gpt-5.6-luna"],
    }
  );
  assert.match(query, /Prices\(\)/);
  assert.match(query, /x_PricingBlockSize/);
  assert.match(query, /lookup kind=leftouter regions/);
  assert.match(query, /lookup kind=inner scope/);
  assert.match(query, /ResourceLocation/);
  assert.match(query, /ScopeSubAccountId in \(targetSubscriptions\)/);
  assert.match(query, /PricingUnit has 'Tokens'/);
  assert.match(query, /SkuMeter has_all \("5\.6", "luna"\)/);
  assert.doesNotMatch(query, /OriginalValue|x_SkuMeterName|x_PricingCurrency/);
  assert.match(query, /x_SkuPriceType =~ 'Consumption'/);
  assert.match(query, /Variant=case/);
  assert.match(query, /SkuMeter has_any \('Cached', 'Cache', 'Cd', 'Wr'\), 'Cached'/);
  assert.ok(
    query.indexOf("SkuMeter has 'LongCo', 'LongContext'") <
      query.indexOf("SkuMeter has_any ('Cached', 'Cache', 'Cd', 'Wr'), 'Cached'"),
    "specialized meters must be classified before generic cached-input meters"
  );
  assert.match(query, /PriceScope=case/);
  assert.match(query, /SkuMeter has 'Gl'/);
  assert.match(query, /'Opt'\), 'Output'/);
  assert.match(query, /ScopeCurrency/);
  assert.match(query, /where ScopeMatch and PricingCurrency =~ ScopeCurrency/);
  assert.match(query, /x_SkuMeterId/);
  assert.match(query, /x_EffectivePeriodStart < metricEnd/);
  assert.match(query, /metricStart < datetime_add\('month', 1, x_EffectivePeriodEnd\)/);
  assert.match(query, /ScopeBillingAccountId/);
  assert.match(query, /ScopeBillingProfileId/);
  assert.match(query, /x_BillingAccountId/);
  assert.match(query, /x_BillingProfileId/);
  assert.match(query, /take 10000/);
  assert.doesNotMatch(query, /\|\s*join(?!\s+kind=)/);
});

test("AI Foundry agent cost query keeps Hub work bounded", () => {
  const query = kusto.buildFoundryAgentCostsQuery({
    start: "2026-02-01T00:00:00Z",
    end: "2026-03-01T00:00:00Z",
  });
  assert.match(query, /Costs\(\)/);
  assert.match(query, /ChargePeriodStart >= CostStart and ChargePeriodStart < ActivityEnd/);
  assert.match(query, /x_SkuMeterSubcategory has 'Agent'/);
  assert.match(query, /by AgentResourceId, BillingCurrency/);
  assert.doesNotMatch(query, /AppTraces|AppDependencies|macro-expand|\|\s*join(?!\s+kind=)/);
  assert.throws(
    () => kusto.buildFoundryAgentCostsQuery({
      start: "invalid",
      end: "2026-03-01T00:00:00Z",
    }),
    /valid start and end time/
  );
});

test("Foundry agents dashboard shares rich telemetry across account scopes and keeps billed cost separate", async () => {
  const tenantId = "99999999-2222-4333-8444-555555555555";
  const subscriptionId = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
  const accountId = `/subscriptions/${subscriptionId}/resourceGroups/ai-rg/providers/Microsoft.CognitiveServices/accounts/foundry-a`;
  const projectId = `${accountId}/projects/finops`;
  const workspaceId = `/subscriptions/${subscriptionId}/resourceGroups/monitor-rg/providers/Microsoft.OperationalInsights/workspaces/law-prod`;
  const discoveryRows = [
    {
      ResourceKind: "account", id: accountId, name: "foundry-a", resourceGroup: "ai-rg",
      subscriptionId, location: "eastus", kind: "AIServices", sku: "S0",
    },
    {
      ResourceKind: "deployment", id: `${accountId}/deployments/chat-prod`, name: "foundry-a/chat-prod",
      subscriptionId, location: "eastus", sku: "GlobalStandard", modelName: "gpt-4o",
      modelVersion: "2024-08-06", modelFormat: "OpenAI", provisioningState: "Succeeded",
    },
    {
      ResourceKind: "project", id: projectId, name: "finops",
      subscriptionId, location: "eastus",
    },
    {
      ResourceKind: "workspace", id: workspaceId, name: "law-prod", resourceGroup: "monitor-rg",
      subscriptionId, location: "westus", customerId: "11111111-2222-4333-8444-555555555555",
    },
    {
      ResourceKind: "workspace", id: workspaceId.toLowerCase(), name: "law-prod", resourceGroup: "monitor-rg",
      subscriptionId, location: "westus", customerId: "11111111-2222-4333-8444-555555555555",
    },
    {
      ResourceKind: "application-insights",
      id: `/subscriptions/${subscriptionId}/resourceGroups/monitor-rg/providers/Microsoft.Insights/components/appi-prod`,
      name: "appi-prod",
      workspaceResourceId: workspaceId,
    },
  ];
  const priceRows = [
    {
      RowType: "Price", SubAccountId: subscriptionId,
      Direction: "Input", Variant: "Standard", ModelText: "GPT-4o 2024-08-06 input tokens",
      PriceScope: "Global", SelectedUnitPrice: 0.002, x_PricingBlockSize: 1000,
      PricingCurrency: "USD", ScopeMatch: true, ScopeCurrency: "USD",
      x_EffectivePeriodStart: "2026-02-01T00:00:00Z", x_EffectivePeriodEnd: null,
    },
    {
      RowType: "Price", SubAccountId: subscriptionId,
      Direction: "Input", Variant: "Cached", ModelText: "GPT-4o 2024-08-06 cached input tokens",
      PriceScope: "Global", SelectedUnitPrice: 0.0005, x_PricingBlockSize: 1000,
      PricingCurrency: "USD", ScopeMatch: true, ScopeCurrency: "USD",
      x_EffectivePeriodStart: "2026-02-01T00:00:00Z", x_EffectivePeriodEnd: null,
    },
    {
      RowType: "Price", SubAccountId: subscriptionId,
      Direction: "Output", Variant: "Standard", ModelText: "GPT-4o 2024-08-06 output tokens",
      PriceScope: "Global", SelectedUnitPrice: 0.008, x_PricingBlockSize: 1000,
      PricingCurrency: "USD", ScopeMatch: true, ScopeCurrency: "USD",
      x_EffectivePeriodStart: "2026-02-01T00:00:00Z", x_EffectivePeriodEnd: null,
    },
  ];
  const telemetryRows = [
    {
      RowType: "AgentSummary", AgentKey: "finops-hub-demo-foundry-agent:3",
      AgentName: "foundry-agent", AgentId: "finops-hub-demo-foundry-agent:3",
      FoundryProjectId: projectId, ActivityEvents: 20, Operations: 1, Successes: 1, Errors: 0,
      TotalDurationMs: 400, AverageLatencyMs: 400, P95LatencyMs: 400,
      InputTokens: 1000, CachedInputTokens: 200, OutputTokens: 300, LastSeen: "2026-03-01T23:56:00Z",
    },
    {
      RowType: "TokenBucket", BucketStart: "2026-03-01T23:00:00Z", AgentKey: "finops-hub-demo-foundry-agent:3",
      AgentName: "foundry-agent", AgentId: "finops-hub-demo-foundry-agent:3", FoundryProjectId: projectId,
      Model: "gpt-4o-2024-08-06", InputTokens: 1000, CachedInputTokens: 200, OutputTokens: 300,
    },
    {
      RowType: "ModelUsage", AgentKey: "finops-hub-demo-foundry-agent:3", AgentName: "foundry-agent",
      AgentId: "finops-hub-demo-foundry-agent:3", FoundryProjectId: projectId, Model: "gpt-4o-2024-08-06",
      Chats: 1, InputTokens: 1000, CachedInputTokens: 200, OutputTokens: 300,
      AverageLatencyMs: 300, P95LatencyMs: 300, LastSeen: "2026-03-01T23:56:00Z",
    },
    {
      RowType: "Run", Timestamp: "2026-03-01T23:56:00Z", TraceId: "trace-1",
      AgentKey: "finops-hub-demo-foundry-agent:3", AgentName: "foundry-agent",
      AgentId: "finops-hub-demo-foundry-agent:3", FoundryProjectId: projectId, Model: "gpt-4o-2024-08-06",
      InputTokens: 1000, CachedInputTokens: 200, OutputTokens: 300, DurationMs: 400, Success: true,
    },
    {
      RowType: "FinishReason", AgentKey: "finops-hub-demo-foundry-agent:3", AgentName: "foundry-agent",
      FoundryProjectId: projectId, FinishReason: "[\"stop\"]", Count: 1,
    },
    {
      RowType: "Tool", AgentKey: "finops-hub-demo-foundry-agent:3", AgentName: "foundry-agent",
      FoundryProjectId: projectId, ToolName: "Costs", Calls: 2, Errors: 0, AverageLatencyMs: 50,
    },
    ...priceRows,
  ];
  let discoveryCalls = 0;
  let connectionCalls = 0;
  let kustoCalls = 0;
  const fetchFn = async (url, init = {}) => {
    const target = String(url);
    if (target.includes("Microsoft.ResourceGraph")) {
      const query = JSON.parse(init.body).query;
      discoveryCalls += 1;
      assert.match(query, /microsoft\.cognitiveservices\/accounts\/deployments/);
      assert.match(query, /microsoft\.cognitiveservices\/accounts\/projects/);
      assert.doesNotMatch(query, /microsoft\.app\/agents/);
      assert.match(query, /microsoft\.insights\/components/);
      assert.match(query, /microsoft\.operationalinsights\/workspaces/);
      return Response.json({ data: discoveryRows });
    }
    if (target.includes("management.azure.com/batch")) {
      const requests = JSON.parse(init.body).requests;
      connectionCalls += 1;
      assert.equal(requests.length, 1);
      assert.match(requests[0].relativeUrl, /\/projects\/finops\/connections\?category=AppInsights&api-version=2025-06-01$/);
      return Response.json({
        responses: [{
          httpStatusCode: 200,
          content: {
            value: [{
              properties: {
                category: "AppInsights",
                target: `/subscriptions/${subscriptionId}/resourceGroups/monitor-rg/providers/Microsoft.Insights/components/appi-prod`,
              },
            }],
          },
        }],
      });
    }
    throw new Error(`Unexpected test URL: ${url}`);
  };
  const runQuery = async (_connection, _database, query, queryOptions) => {
    kustoCalls += 1;
    assert.match(query, /^set query_results_cache_max_age = time\(30s\);/);
    assert.match(query, /let MonitorWorkspaces = entity_group/);
    assert.match(query, /macro-expand kind=inner isfuzzy=true MonitorWorkspaces/);
    assert.match(query, /let Base = materialize\(/);
    assert.match(query, /isnotempty\(AgentKey\) and isnotempty\(FoundryProjectId\)/);
    assert.match(query, /adx\.monitor\.azure\.com\/subscriptions/);
    assert.match(query, /SourceTable endswith 'AppDependencies'/);
    assert.match(query, /OperationName =~ 'chat'/);
    assert.match(query, /OperationName =~ 'execute_tool'/);
    assert.match(query, /join kind=leftouter RunModels/);
    assert.match(query, /let CostRows = materialize\(/);
    assert.match(query, /let BilledCostRows = CostRows/);
    assert.match(query, /let PriceRows = Prices\(\)/);
    assert.match(query, /ScopeBillingAccountId/);
    assert.match(query, /ScopeBillingProfileId/);
    assert.match(query, /union AgentRows, BilledCostRows/);
    assert.equal(queryOptions.maxResponseBytes, 16 * 1024 * 1024);
    await new Promise((resolve) => setTimeout(resolve, 10));
    return telemetryRows;
  };
  const common = {
    connection: { clusterUri: "http://localhost:8082", database: "Hub" },
    database: "Hub",
    tenantId,
    preset: "7d",
    runQuery,
    options: {
      fetchFn,
      execFileFn: async () => ({
        stdout: JSON.stringify({ accessToken: "token", expires_on: Math.floor(Date.now() / 1000) + 3600 }),
      }),
      now: "2026-03-02T00:00:00Z",
      agentCacheTtlMs: 1000,
    },
  };
  const [estate, account] = await Promise.all([
    azureMonitor.getAgentsDashboard(common),
    azureMonitor.getAgentsDashboard({ ...common, accountId }),
  ]);
  assert.equal(discoveryCalls, 1);
  assert.equal(connectionCalls, 1);
  assert.equal(kustoCalls, 1);
  assert.equal(estate.workspaceCount, 1);
  assert.equal(estate.summary.AgentCount, 1);
  assert.equal(account.summary.AgentCount, 1);
  assert.equal(account.agents[0].AgentName, "foundry-agent");
  assert.equal(account.recentRuns[0].TraceId, "trace-1");
  assert.ok(Math.abs(account.recentRuns[0].EstimatedCost - 0.0041) < 1e-12);
  assert.equal(account.recentRuns[0].UncachedInputTokens, 800);
  assert.ok(Math.abs(account.recentRuns[0].UncachedInputCost - 0.0016) < 1e-12);
  assert.ok(Math.abs(account.recentRuns[0].CachedInputCost - 0.0001) < 1e-12);
  assert.ok(Math.abs(account.recentRuns[0].OutputCost - 0.0024) < 1e-12);
  assert.equal(account.recentRuns[0].PriceCoverage, 1);
  assert.ok(Math.abs(account.summary.UncachedInputCost - 0.0016) < 1e-12);
  assert.ok(Math.abs(account.summary.CachedInputCost - 0.0001) < 1e-12);
  assert.ok(Math.abs(account.summary.OutputCost - 0.0024) < 1e-12);
  assert.ok(Math.abs(account.agents[0].UncachedInputCost - 0.0016) < 1e-12);
  assert.ok(Math.abs(account.models[0].CachedInputCost - 0.0001) < 1e-12);
  assert.ok(Math.abs(account.charts.tokens[0].OutputCost - 0.0024) < 1e-12);
  assert.equal(account.agents[0].BilledCostStatus, "Not an ARM resource identity");
  assert.equal(estate.agents[0].AgentType, "Microsoft Foundry agent");
});

test("local dashboard semantics stay unauthenticated and preserve the payload shape", async (t) => {
  const requests = [];
  const server = createServer(async (req, res) => {
    let body = "";
    for await (const chunk of req) body += chunk;
    const { csl } = JSON.parse(body);
    requests.push(req.headers);
    const rows = csl.includes("MinDate=min")
      ? [{ MinDate: "2025-01-01T00:00:00Z", MaxDate: "2025-04-01T00:00:00Z", Rows: 4 }]
      : [];
    const columns = rows[0] ? Object.keys(rows[0]) : [];
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(await kustoResponse(rows, columns).text());
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  t.after(() => server.close());

  const { port } = server.address();
  const payload = await kusto.getDashboard(`http://127.0.0.1:${port}`, "Hub");
  assert.equal(payload.empty, false);
  assert.deepEqual(Object.keys(payload.data), [
    "summary", "tagged", "pricing", "trend", "serviceCategory",
    "topServices", "topResourceGroups", "topRegions", "chargeCategory",
  ]);
  assert.equal(requests.length, 10);
  assert.ok(requests.every((headers) => headers.authorization === undefined));
  assert.ok(requests.every((headers) => headers["x-ms-readonly"] === "true"));
});

test("remote requests deduplicate tokens, add read-only headers, and recover after failure", async () => {
  kusto.resetKustoAuthForTests();
  const tenantId = "72f988bf-86f1-41af-91ab-2d7cd011db47";
  const providerCalls = [];
  let release;
  const provider = async (requestedTenantId) => {
    providerCalls.push(requestedTenantId);
    await new Promise((resolve) => { release = resolve; });
    return { accessToken: "secret-token", expires_on: Math.floor(Date.now() / 1000) + 3600 };
  };
  const seen = [];
  const fetchImpl = async (_url, options) => {
    seen.push(options.headers);
    return kustoResponse([{ Ready: 1 }]);
  };
  const connection = { clusterUri: "https://cluster.westus.kusto.windows.net", tenantId };
  const first = kusto.runQuery(connection, "Hub", "print Ready=1", { tokenProvider: provider, fetchImpl });
  const second = kusto.runQuery(connection, "Hub", "print Ready=1", { tokenProvider: provider, fetchImpl });
  await new Promise((resolve) => setImmediate(resolve));
  release();
  await Promise.all([first, second]);
  assert.deepEqual(providerCalls, [tenantId]);
  assert.equal(seen.length, 2);
  assert.ok(seen.every((headers) => headers.Authorization === "Bearer secret-token"));
  assert.ok(seen.every((headers) => headers["x-ms-readonly"] === "true"));
  assert.notEqual(seen[0]["x-ms-client-request-id"], seen[1]["x-ms-client-request-id"]);

  const otherTenantId = "91700184-c314-4dc9-bb7e-a411df456a1e";
  const otherTenantCalls = [];
  await kusto.runQuery(
    { clusterUri: connection.clusterUri, tenantId: otherTenantId },
    "Hub",
    "print Ready=1",
    {
      tokenProvider: async (requestedTenantId) => {
        otherTenantCalls.push(requestedTenantId);
        return { accessToken: "other-secret-token", expires_on: Math.floor(Date.now() / 1000) + 3600 };
      },
      fetchImpl,
    }
  );
  assert.deepEqual(otherTenantCalls, [otherTenantId]);

  kusto.resetKustoAuthForTests();
  await assert.rejects(() => kusto.runQuery(
    connection,
    "Hub",
    "print Ready=1",
    { tokenProvider: async () => { throw new Error("temporary"); }, fetchImpl }
  ));
  await kusto.runQuery(
    connection,
    "Hub",
    "print Ready=1",
    {
      tokenProvider: async () => ({ accessToken: "recovered", expires_on: Math.floor(Date.now() / 1000) + 3600 }),
      fetchImpl,
    }
  );
});

test("remote transport bounds concurrent Kusto requests", async () => {
  kusto.resetKustoAuthForTests();
  const connection = {
    clusterUri: "https://cluster.westus.kusto.windows.net",
    tenantId: "72f988bf-86f1-41af-91ab-2d7cd011db47",
  };
  let active = 0;
  let maximum = 0;
  const fetchImpl = async () => {
    active++;
    maximum = Math.max(maximum, active);
    await new Promise((resolve) => setTimeout(resolve, 5));
    active--;
    return kustoResponse([{ Ready: 1 }]);
  };
  await Promise.all(Array.from({ length: 12 }, (_, index) => kusto.runQuery(
    connection,
    "Hub",
    `print Ready=${index}`,
    {
      tokenProvider: async () => ({
        accessToken: "secret-token",
        expires_on: Math.floor(Date.now() / 1000) + 3600,
      }),
      fetchImpl,
    }
  )));
  assert.equal(maximum, 1);
});

test("remote transport retries transient fetch failures", async () => {
  kusto.resetKustoAuthForTests();
  let attempts = 0;
  const result = await kusto.runQuery(
    {
      clusterUri: "https://cluster.westus.kusto.windows.net",
      tenantId: "72f988bf-86f1-41af-91ab-2d7cd011db47",
    },
    "Hub",
    "print Ready=1",
    {
      tokenProvider: async () => ({
        accessToken: "secret-token",
        expires_on: Math.floor(Date.now() / 1000) + 3600,
      }),
      fetchImpl: async () => {
        attempts++;
        if (attempts < 3) throw new TypeError("fetch failed");
        return kustoResponse([{ Ready: 1 }]);
      },
    }
  );
  assert.equal(attempts, 3);
  assert.deepEqual(result, [{ Ready: 1 }]);
});

test("transport errors are actionable and authentication failures redact provider output", async () => {
  await assert.rejects(
    () => kusto.runQuery("http://localhost:8082", "Hub", "print Ready=1", {
      fetchImpl: async () => { throw new Error("ECONNREFUSED"); },
    }),
    /Could not reach Kusto at http:\/\/localhost:8082: ECONNREFUSED/
  );

  kusto.resetKustoAuthForTests();
  await assert.rejects(
    () => kusto.runQuery("https://cluster.westus.kusto.windows.net", "Hub", "print Ready=1"),
    /Tenant ID is required for remote hubs/
  );
  await assert.rejects(
    () => kusto.runQuery({
      clusterUri: "https://cluster.westus.kusto.windows.net",
      tenantId: "72f988bf-86f1-41af-91ab-2d7cd011db47",
    }, "Hub", "print Ready=1", {
      tokenProvider: async () => { throw new Error("secret-token-value"); },
      fetchImpl: async () => assert.fail("fetch must not run without a token"),
    }),
    (err) => /Azure CLI could not acquire/.test(err.message) && !err.message.includes("secret-token-value")
  );
});

test("response parsing detects partial failures and enforces the byte limit before parsing", async () => {
  const partialResponse = {
    Tables: [
      { TableName: "Table_0", Columns: [{ ColumnName: "Value" }], Rows: [[1]] },
      {
        TableName: "Table_2",
        Columns: [
          { ColumnName: "Severity" },
          { ColumnName: "StatusCode" },
          { ColumnName: "StatusDescription" },
        ],
        Rows: [[2, -1, "Partial query failure"]],
      },
    ],
  };
  assert.throws(() => kusto.parseKustoResponse(partialResponse), /Partial query failure/);
  const partialRows = kusto.parseKustoResponse(partialResponse, { allowPartialResults: true });
  assert.deepEqual(partialRows, [{ Value: 1 }]);
  assert.deepEqual(partialRows.queryWarnings, [
    "One or more remote workspaces failed during the federated query. Results are partial.",
  ]);
  await assert.rejects(() => kusto.readBoundedBody(new Response("12345"), 4), /4-byte limit/);
});

test("filter encoding keeps adversarial values inside one Kusto string literal", () => {
  const values = [
    "O'Reilly",
    "back\\slash",
    "line\r\nbreak",
    "x; .drop table Costs",
    "// comment",
    "/* comment */",
    "東京",
    ".show tables",
  ];
  const where = kusto.buildFilterWhere({ ServiceName: values });
  for (const value of values) assert.ok(where.includes(JSON.stringify(value)));
  assert.equal((where.match(/\| where/g) || []).length, 1);
  assert.throws(() => kusto.buildFilterWhere({ BadColumn: ["x"] }), /Unsupported filter/);
  assert.throws(() => kusto.validateFilters({ ServiceName: Array(9).fill("x") }), /at most 8/);
});

test("capacity registry is exact, versioned, and fail-closed", () => {
  assert.equal(Object.keys(kusto.CAPACITY_CLASS_REGISTRY).length, 7);
  assert.equal(Object.keys(kusto.CAPACITY_METRIC_REGISTRY).length, 8);

  const enabled = kusto.resolveCapacityMetric({
    x_SourceType: " computeusage ",
    x_SourceVersion: "1.0-USAGE",
    ResourceName: " CORES ",
    unit: " count ",
  });
  assert.equal(enabled.capability, "enabled");
  assert.equal(enabled.metricRole, "total-regional-vcpu");
  const sqlEnabled = kusto.resolveCapacityMetric({
    x_SourceType: "SqlSubscriptionUsage",
    x_SourceVersion: "1.0-sql",
    ResourceName: "RegionalVCoreQuotaForSQLDBAndDW",
    unit: "Count",
  });
  assert.equal(sqlEnabled.capability, "enabled");
  assert.equal(sqlEnabled.metricRole, "sql-database-vcore");

  assert.deepEqual(
    kusto.resolveCapacityMetric({
      x_SourceType: "ComputeUsage",
      x_SourceVersion: "1.0-usage",
      ResourceName: "cores-extra",
      unit: "Count",
    }).capability,
    "descriptive-only"
  );
  assert.equal(kusto.resolveCapacityMetric({
    x_SourceType: "ComputeUsage",
    x_SourceVersion: "2.0-usage",
    ResourceName: "cores",
    unit: "Count",
  }).reasonCode, "source-version-mismatch");
  assert.equal(kusto.resolveCapacityMetric({
    x_SourceType: "AppServiceUsage",
    x_SourceVersion: "1.0-usage",
    ResourceName: "P1v3",
    unit: "Instances",
  }).reasonCode, "unclassified-metric");
  assert.equal(kusto.resolveCapacityMetric({
    x_SourceType: "UnknownUsage",
    x_SourceVersion: "1.0",
    ResourceName: "cores",
    unit: "Count",
  }).capability, "disabled");
});

test("capacity observation precedence handles invalid, stale, unclassified, and limit states", () => {
  const now = new Date("2026-08-23T12:00:00Z");
  const base = {
    x_SourceType: "ComputeUsage",
    x_SourceVersion: "1.0-usage",
    ResourceName: "cores",
    unit: "Count",
    currentValue: 79,
    limit: 100,
    x_IngestionTime: "2026-08-23T10:00:00Z",
  };
  assert.equal(kusto.classifyCapacityObservation(base, now).state, "healthy");
  assert.equal(kusto.classifyCapacityObservation({ ...base, currentValue: 80 }, now).state, "watch");
  assert.equal(kusto.classifyCapacityObservation({ ...base, currentValue: 90 }, now).state, "action");
  assert.equal(kusto.classifyCapacityObservation({ ...base, currentValue: 100 }, now).state, "exhausted");
  assert.equal(kusto.classifyCapacityObservation({ ...base, currentValue: 0, limit: 0 }, now).state, "no-entitlement");
  assert.equal(kusto.classifyCapacityObservation({ ...base, currentValue: 1, limit: 0 }, now).reasonCode, "conflicting-provider-values");
  assert.equal(kusto.classifyCapacityObservation({ ...base, currentValue: null, x_IngestionTime: "2026-08-20T10:00:00Z" }, now).reasonCode, "invalid-provider-values");
  assert.equal(kusto.classifyCapacityObservation({ ...base, x_IngestionTime: "2026-08-21T12:00:00Z" }, now).state, "healthy");
  assert.equal(kusto.classifyCapacityObservation({ ...base, x_IngestionTime: "2026-08-21T11:59:59Z" }, now).state, "stale");

  const unknown = { ...base, ResourceName: "regionalFamilyCores" };
  assert.equal(kusto.classifyCapacityObservation(unknown, now).state, "unclassified");
  assert.equal(kusto.classifyCapacityObservation({ ...unknown, x_IngestionTime: "2026-08-20T10:00:00Z" }, now).state, "stale");

  const sqlNegative = kusto.classifyCapacityObservation({
    ...base,
    x_SourceType: "SqlSubscriptionUsage",
    x_SourceVersion: "1.0-sql",
    ResourceName: "RegionalVCoreQuotaForSQLDBAndDW",
    limit: -1,
  }, now);
  assert.equal(sqlNegative.state, "invalid");
  assert.equal(sqlNegative.reasonCode, "unexpected-negative-limit");
  assert.match(sqlNegative.sourceNote, /interpretation unverified/i);
});

test("inventory observations never receive quota arithmetic", () => {
  const result = kusto.classifyCapacityObservation({
    x_SourceType: "PremiumSSDv2Disk",
    x_SourceVersion: "1.0-disk",
    ResourceId: "/subscriptions/s/resourceGroups/rg/providers/Microsoft.Compute/disks/d1",
    ResourceName: "d1",
    unit: "",
    currentValue: 128,
    limit: null,
    x_IngestionTime: "2026-08-23T10:00:00Z",
  }, new Date("2026-08-23T12:00:00Z"));
  assert.equal(result.state, "inventory");
  assert.equal(result.currentValue, 128);
  assert.equal(result.limit, null);
  assert.equal(result.utilizationPercent, null);
  assert.equal(result.headroom, null);
});

test("capacity history gates activate only supported readings", () => {
  assert.equal(kusto.resolveCapacityHistoryCapability(1).mode, "current-only");
  assert.equal(kusto.resolveCapacityHistoryCapability(2).mode, "observed-delta");
  assert.equal(kusto.resolveCapacityHistoryCapability(3).mode, "provisional-runway");
  assert.equal(kusto.resolveCapacityHistoryCapability(7).mode, "trend-runway");
  assert.equal(kusto.resolveCapacityHistoryCapability(7, { quotaType: "inventory" }).mode, "observed-history");
});

test("capacity KQL is bounded and preserves semantic dimensions", () => {
  const current = kusto.buildCapacityCurrentQuery("compute");
  const selectors = kusto.buildCapacitySelectorQuery("compute");
  const subscriptions = kusto.buildComputeSubscriptionQuery({
    status: "in-use",
    familySearch: "Dsv5",
    regions: ["eastus"],
    subscriptionSearch: "64e3",
    page: 2,
    pageSize: 50,
  });
  const appService = kusto.buildAppServiceSkuQuery({ SubAccountId: ["abc"], location: ["eastus"] });
  const appServiceSubscriptions = kusto.buildAppServiceSubscriptionQuery({
    status: "no-quota",
    skuSearch: "P1v4",
    regions: ["eastus"],
    subscriptionSearch: "64e3",
    page: 2,
    pageSize: 50,
  });
  const azureSql = kusto.buildAzureSqlQuotaQuery({ SubAccountId: ["abc"], location: ["eastus"] });
  const azureSqlSubscriptions = kusto.buildAzureSqlSubscriptionQuery({
    status: "no-quota",
    resourceSearch: "vCore",
    regions: ["eastus"],
    subscriptionSearch: "64e3",
    page: 2,
    pageSize: 50,
  });
  const heatmap = kusto.buildCapacityHeatmapQuery("compute", {
    resourceName: "cores",
    unit: "Count",
    sourceVersion: "1.0-usage",
  });
  const reconciliation = kusto.buildCapacityReservationReconciliationQuery();
  const disk = kusto.buildCapacityDemandSelectorQuery("premium-ssd-v2");

  assert.match(current, /\| take 251$/);
  assert.match(selectors, /\| take 501$/);
  assert.match(selectors, /summarize displayName=take_any\(displayName\).+by ResourceName, unit, x_SourceType, x_SourceVersion/s);
  assert.match(selectors, /NAME: Compute quota usage/);
  assert.match(subscriptions, /where CoresUsed > 0/);
  assert.match(subscriptions, /Family contains "Dsv5"/);
  assert.match(subscriptions, /Location in~ \("eastus"\)/);
  assert.match(subscriptions, /SubscriptionId startswith "64e3"/);
  assert.match(subscriptions, /NAME: Compute VM family quota usage/);
  assert.doesNotMatch(subscriptions, /ComputeQuota\(\)|Costs\(\)/);
  assert.match(subscriptions, /RowNumber between \(51 \.\. 100\)/);
  assert.match(subscriptions, /real\(null\)/);
  assert.match(subscriptions, /\| take 50$/);
  assert.throws(() => kusto.buildComputeSubscriptionQuery({ regions: "eastus" }), /must be an array/);
  assert.match(appService, /NAME: App Service quota usage/);
  assert.match(appService, /SkuKey=ResourceName, Unit=unit, Location=location/);
  assert.match(appService, /NoQuotaSubscriptions=dcountif\(SubAccountId, coalesce\(limit, 0\.0\) <= 0\)/);
  assert.match(appService, /where SubAccountId in~ \("abc"\)/);
  assert.match(appService, /where location in~ \("eastus"\)/);
  assert.match(appService, new RegExp(`take ${kusto.CAPACITY_LIMITS.familyCells + 1}`));
  assert.match(appServiceSubscriptions, /coalesce\(limit, 0\.0\) <= 0/);
  assert.match(appServiceSubscriptions, /ResourceName contains "P1v4"/);
  assert.match(appServiceSubscriptions, /location in~ \("eastus"\)/);
  assert.match(appServiceSubscriptions, /SubAccountId startswith "64e3"/);
  assert.match(appServiceSubscriptions, /RowNumber between \(51 \.\. 100\)/);
  assert.match(appServiceSubscriptions, /\| take 50$/);
  assert.doesNotMatch(appServiceSubscriptions, /Costs\(\)/);
  assert.doesNotMatch(appServiceSubscriptions, /sum\(currentValue\)|sum\(limit\)|HeadroomInstances/);
  assert.match(appServiceSubscriptions, /SkuRegionPairs=count\(\)/);
  assert.match(azureSql, /NAME: SQL subscription quota usage/);
  assert.match(azureSql, /Metric=take_any\(QuotaMetric\)/);
  assert.match(azureSql, /Used=sumif\(currentValue, limit > 0\)/);
  assert.match(azureSql, /NegativeLimitSubscriptions=dcountif\(SubAccountId, limit < 0\)/);
  assert.match(azureSql, /where SubAccountId in~ \("abc"\)/);
  assert.match(azureSql, /where location in~ \("eastus"\)/);
  assert.match(azureSql, new RegExp(`take ${kusto.CAPACITY_LIMITS.familyCells + 1}`));
  assert.match(azureSqlSubscriptions, /coalesce\(limit, 0\.0\) <= 0/);
  assert.match(azureSqlSubscriptions, /ResourceName contains "vCore"/);
  assert.match(azureSqlSubscriptions, /location in~ \("eastus"\)/);
  assert.match(azureSqlSubscriptions, /SubAccountId startswith "64e3"/);
  assert.match(azureSqlSubscriptions, /MetricRegionPairs=count\(\)/);
  assert.match(azureSqlSubscriptions, /RowNumber between \(51 \.\. 100\)/);
  assert.match(azureSqlSubscriptions, /\| take 50$/);
  assert.doesNotMatch(azureSqlSubscriptions, /Costs\(\)/);
  assert.match(heatmap, /\| take 501$/);
  assert.throws(
    () => kusto.buildCapacityDemandSelectorQuery("compute"),
    /Compute billed-demand queries are not supported/
  );
  assert.throws(
    () => kusto.buildCapacityDemandHistoryQuery("compute", {}),
    /Compute billed-demand queries are not supported/
  );
  assert.throws(
    () => kusto.buildCapacityDemandCoverageQuery("compute"),
    /Compute billed-demand queries are not supported/
  );
  assert.match(reconciliation, /\| join kind=fullouter billed on GroupKey/);
  assert.match(reconciliation, /inventory-only/);
  assert.match(reconciliation, /cost-only/);
  assert.match(disk, /\| join kind=leftouter diskCost on JoinResourceId/);
  assert.match(disk, /InventoryResourceId/);
});

test("all seven capacity classes return the bounded payload contract", async (t) => {
  const clusterUri = await startCapacityServer(t);
  for (const classId of Object.keys(kusto.CAPACITY_CLASS_REGISTRY)) {
    const payload = await kusto.getCapacity(clusterUri, "Hub", classId);
    assert.equal(payload.classId, classId);
    assert.equal(payload.contract.id, classId);
    assert.equal(payload.schema.quota.available, true);
    if (["compute", "app-service", "azure-sql", "azure-ai"].includes(classId)) {
      assert.equal(payload.schema.costs, undefined);
      assert.equal(payload.series.status, "not-applicable");
      assert.equal(payload.demand.capability.reasonCode, "class-uses-quota-only");
    } else {
      assert.equal(payload.schema.costs.available, true);
    }
    assert.equal(payload.table.rowLimit, 250);
    assert.equal(payload.selectors.itemLimit, 500);
    assert.equal(payload.history.pointLimit, 430);
    assert.equal(payload.heatmap.limit, 500);
    assert.equal(payload.series.pointLimit, 430);
    assert.equal(payload.demand.selectors.itemLimit, 500);
  }
});

test("missing schema fields disable only panels that depend on that source", async (t) => {
  const missingQuota = await startCapacityServer(t, {
    quotaFields: QUOTA_SCHEMA_FIELDS.filter((field) => field !== "x_SourceVersion"),
  });
  const quotaPayload = await kusto.getCapacity(missingQuota, "Hub", "compute");
  assert.equal(quotaPayload.schema.quota.available, false);
  assert.equal(quotaPayload.schema.costs, undefined);
  assert.equal(quotaPayload.capability.mode, "disabled");
  assert.equal(quotaPayload.history.status, "disabled");
  assert.equal(quotaPayload.demand.capability.mode, "disabled");
  assert.equal(quotaPayload.demand.capability.reasonCode, "class-uses-quota-only");

  const missingCost = await startCapacityServer(t, {
    costFields: COST_SCHEMA_FIELDS.filter((field) => field !== "BillingCurrency"),
  });
  const appServicePayload = await kusto.getCapacity(missingCost, "Hub", "app-service");
  assert.equal(appServicePayload.schema.quota.available, true);
  assert.equal(appServicePayload.schema.costs, undefined);
  assert.equal(appServicePayload.history.status, "no-selection");
  assert.equal(appServicePayload.demand.capability.reasonCode, "class-uses-quota-only");
  assert.equal(appServicePayload.series.status, "not-applicable");

  const costPayload = await kusto.getCapacity(missingCost, "Hub", "storage");
  assert.equal(costPayload.schema.quota.available, true);
  assert.equal(costPayload.schema.costs.available, false);
  assert.equal(costPayload.capability.mode, "descriptive-only");
  assert.equal(costPayload.history.status, "no-selection");
  assert.equal(costPayload.demand.capability.mode, "disabled");
  assert.equal(costPayload.series.status, "disabled");
});

test("capacity selections reject unknown fields and keys outside the selector catalog", async (t) => {
  assert.throws(
    () => extension.validateViewInput({
      name: "capacity",
      capacityClass: "compute",
      capacitySelections: { quotaSelection: { resourceName: "cores", injected: "value" } },
    }),
    /Unsupported quotaSelection field/
  );
  assert.throws(
    () => extension.validateViewInput({ name: "capacity", capacityClass: "unknown" }),
    /Unsupported capacity class/
  );

  const selectorRow = {
    ResourceId: "/subscriptions/one/providers/Microsoft.Compute/locations/eastus/usages/cores",
    ResourceName: "cores",
    SubAccountId: "one",
    location: "eastus",
    unit: "Count",
    x_SourceType: "ComputeUsage",
    x_SourceVersion: "1.0-usage",
    x_IngestionTime: "2026-08-23T12:00:00Z",
  };
  const clusterUri = await startCapacityServer(t, { rows: () => [selectorRow] });
  await assert.rejects(
    () => kusto.getCapacity(clusterUri, "Hub", "compute", {
      quotaSelection: {
        subAccountId: "one",
        location: "westus",
        resourceName: "cores",
        unit: "Count",
        sourceVersion: "1.0-usage",
      },
    }),
    /not present in the bounded selector catalog/
  );
});

test("capacity navigation, selection, and heatmap helpers preserve accessible text parity", () => {
  assert.equal(app.nextCapacityTabIndex(0, "ArrowLeft"), 7);
  assert.equal(app.nextCapacityTabIndex(7, "ArrowRight"), 0);
  assert.equal(app.nextCapacityTabIndex(4, "Home"), 0);
  assert.equal(app.nextCapacityTabIndex(2, "End"), 7);
  assert.equal(app.nextCapacityTabIndex(3, "Enter"), 3);

  const sourceRow = {
    SubAccountId: "subscription",
    location: "eastus",
    ResourceName: "cores",
    unit: "Count",
    x_SourceVersion: "1.0-usage",
  };
  assert.deepEqual(app.capacitySelectionFromRow("quota", "compute", sourceRow), {
    subAccountId: "subscription",
    location: "eastus",
    resourceName: "cores",
    unit: "Count",
    sourceVersion: "1.0-usage",
  });
  assert.deepEqual(app.capacitySelectionFromRow("metric", "compute", sourceRow), {
    resourceName: "cores",
    unit: "Count",
    sourceVersion: "1.0-usage",
  });
  assert.deepEqual(app.capacityHeatmapCell({
    semantic: { utilizationPercent: 91.25, state: "action" },
  }, "compute"), {
    value: 91.25,
    text: "91.3%",
    state: "action",
  });
});

test("capacity markup retains module loading, shared controls, and visible text states", async () => {
  const [html, source, uiSource, extensionSource, css, uiCss] = await Promise.all([
    readFile(new URL("../public/index.html", import.meta.url), "utf8"),
    readFile(new URL("../public/app.js", import.meta.url), "utf8"),
    readFile(new URL("../public/ui.js", import.meta.url), "utf8"),
    readFile(new URL("../extension.mjs", import.meta.url), "utf8"),
    readFile(new URL("../public/app.css", import.meta.url), "utf8"),
    readFile(new URL("../public/ui.css", import.meta.url), "utf8"),
  ]);
  assert.match(html, /data-tab="capacity"/);
  assert.match(html, /<link rel="stylesheet" href="\/ui\.css"\s*\/>/);
  assert.match(html, /<script type="module" src="\/app\.js"><\/script>/);
  assert.match(extensionSource, /"\/ui\.css": \["ui\.css", "text\/css; charset=utf-8"\]/);
  assert.match(extensionSource, /"\/ui\.js": \["ui\.js", "application\/javascript; charset=utf-8"\]/);
  assert.match(uiSource, /role="tablist"/);
  assert.match(uiSource, /aria-selected=/);
  assert.match(source, /Every colored cell includes the same value and state in text/);
  assert.match(uiSource, /data-ui-tab=/);
  assert.match(uiSource, /data-ui-search=/);
  assert.match(uiSource, /data-ui-page=/);
  assert.match(source, /Filtered quota detail/);
  assert.match(source, /row\.HeadroomCores != null/);
  assert.match(source, /invalidateCapacitySubscriptions\(\);\s*\n\s*load\(\);/);
  assert.match(source, /id="capacity-subscription-summary"[^>]*tabindex="-1"/);
  assert.match(source, /querySelector\("#capacity-subscription-search"\)/);
  assert.match(source, /state\.capacitySelections = next;[\s\S]*?}\s*\n\s*\nfunction setCapacityDetailTab/);
  assert.match(source, /matrixClass \? "" : capacityPanel\("Observed history"/);
  assert.match(css, /\*:focus-visible/);
  assert.match(uiCss, /\.ui-segment:focus-visible/);
  assert.match(css, /\.capacity-panel--wide\s*\{\s*grid-column:\s*span 12/);
  // The horizontal-scroll rule is shared with the generic `.table-scroll`
  // wrapper, so match the grouped selector rather than a lone one.
  assert.match(css, /\.capacity-table-scroll,\s*\.table-scroll\s*\{[^}]*overflow-x:\s*auto/s);
});

test("shared UI helpers escape data, expose state in text, and reject invalid control names", () => {
  const segments = ui.uiSegmentedControl({
    name: "matrix-status",
    label: "Status <all>",
    labelId: "status-label",
    selected: "all",
    items: [
      { value: "all", label: "All", count: 4 },
      { value: 'at-"limit"', label: "At limit", count: 1 },
    ],
  });
  assert.match(segments, /role="radiogroup"/);
  assert.match(segments, /Status &lt;all&gt;/);
  assert.match(segments, /data-ui-value="all"[\s\S]*aria-checked="true" tabindex="0"/);
  assert.match(segments, /data-ui-value="at-&quot;limit&quot;"/);

  const toggles = ui.uiToggleList({
    name: "matrix-region",
    label: "Region",
    labelId: "region-label",
    selected: ["eastus"],
    items: [{ value: "eastus", label: "East US" }, { value: "westus", label: "West US" }],
  });
  assert.match(toggles, /data-ui-value="eastus"[\s\S]*aria-pressed="true"/);
  assert.match(toggles, /data-ui-value="westus"[\s\S]*aria-pressed="false"/);

  const pagination = ui.uiPagination({ name: "matrix", page: 1, totalPages: 3, label: "Matrix pages" });
  assert.match(pagination, /data-ui-value="0" disabled/);
  assert.match(pagination, /Page 1 of 3/);
  assert.throws(() => ui.uiSearchField({ name: "Bad name", id: "x", label: "X" }), /Invalid UI control name/);
});

test("read-only KQL guard ignores strings and comments but rejects management commands", () => {
  assert.equal(extension.validateReadOnlyQuery("Costs() | take 1"), "Costs() | take 1");
  assert.equal(extension.validateReadOnlyQuery(".show tables"), ".show tables");
  assert.equal(extension.validateReadOnlyQuery('print x="\\n.drop table Costs"'), 'print x="\\n.drop table Costs"');
  assert.equal(extension.validateReadOnlyQuery("// .drop table Costs\nCosts() | take 1"), "// .drop table Costs\nCosts() | take 1");
  assert.throws(() => extension.validateReadOnlyQuery("Costs() | take 1;\n.drop table Costs"), /not allowed/);
  assert.throws(() => extension.validateReadOnlyQuery(".show tables;\n.alter table Costs"), /not allowed/);
  assert.throws(() => extension.validateReadOnlyQuery("x".repeat(65537)), /65536/);
});

test("revision conflicts do not mutate canvas state", () => {
  const initial = { tab: "overview", preset: "all", filters: {}, revision: 3 };
  const next = extension.updateCanvasState(initial, { tab: "rate", expectedRevision: 3 });
  assert.deepEqual(next, { tab: "rate", preset: "all", filters: {}, revision: 4 });
  assert.throws(
    () => extension.updateCanvasState(next, { preset: "3m", expectedRevision: 3 }),
    (err) => err.code === "revision_conflict" && err.state === next
  );
  assert.equal(next.preset, "all");
});

test("loopback policy blocks rebound hosts, cross-site origins, and non-JSON posts", () => {
  const entry = { url: "http://127.0.0.1:47821/" };
  const request = (headers, method = "GET") => ({ headers, method });
  assert.equal(extension.validateLoopbackRequest(
    entry,
    request({ host: "127.0.0.1:47821", origin: "http://127.0.0.1:47821", "sec-fetch-site": "same-origin" }),
    "/api/config"
  ), null);
  assert.equal(extension.validateLoopbackRequest(entry, request({ host: "attacker.example" }), "/api/config").status, 403);
  assert.equal(extension.validateLoopbackRequest(
    entry,
    request({ host: "127.0.0.1:47821", origin: "https://attacker.example" }),
    "/api/config"
  ).status, 403);
  assert.equal(extension.validateLoopbackRequest(
    entry,
    request({ host: "127.0.0.1:47821", "sec-fetch-site": "cross-site" }),
    "/api/config"
  ).status, 403);
  assert.equal(extension.validateLoopbackRequest(
    entry,
    request({ host: "127.0.0.1:47821", "content-type": "text/plain" }, "POST"),
    "/api/view"
  ).status, 415);
  assert.equal(extension.validateLoopbackRequest(
    entry,
    request({ host: "127.0.0.1:47821", "content-type": "application/json; charset=utf-8" }, "POST"),
    "/api/view"
  ), null);
});

test("maximum valid filter state fits the bounded JSON view request", () => {
  const filters = Object.fromEntries([...kusto.ALLOWED_FILTER_COLUMNS].map((column) => [
    column,
    Array.from({ length: 8 }, (_, index) => `${index}${"x".repeat(255)}`),
  ]));
  const view = extension.validateViewInput({ name: "overview", preset: "all", filters });
  const body = JSON.stringify(view);
  assert.ok(Buffer.byteLength(body) < 128 * 1024);
  assert.equal(Object.keys(view.filters).length, 7);
  assert.ok(Object.values(view.filters).every((values) => values.length === 8));
});

test("connection changes probe and persist before mutating shared state", async () => {
  const entry = {
    clusterUri: "http://localhost:8082",
    database: "Hub",
    tenantId: null,
    canvasState: { tab: "overview", preset: "all", filters: {}, foundryAccountId: "/old-account", revision: 0 },
  };
  await assert.rejects(() => extension.changeConnection(entry, {
    clusterUri: "https://cluster.westus.kusto.windows.net",
    database: "Hub",
    tenantId: "72f988bf-86f1-41af-91ab-2d7cd011db47",
  }, {
    runQueryFn: async () => { throw new Error("probe failed"); },
    persistConfig: async () => assert.fail("must not persist after a failed probe"),
  }));
  assert.equal(entry.clusterUri, "http://localhost:8082");

  await assert.rejects(() => extension.changeConnection(entry, {
    clusterUri: "https://cluster.westus.kusto.windows.net",
    database: "Hub",
    tenantId: "72f988bf-86f1-41af-91ab-2d7cd011db47",
  }, {
    runQueryFn: async () => [],
    persistConfig: async () => { throw new Error("disk failed"); },
  }));
  assert.equal(entry.clusterUri, "http://localhost:8082");
  assert.equal(entry.canvasState.revision, 0);

  let persisted;
  let probed;
  const connection = await extension.changeConnection(entry, {
    clusterUri: "https://cluster.westus.kusto.windows.net",
    database: "Hub",
    tenantId: "72F988BF-86F1-41AF-91AB-2D7CD011DB47",
  }, {
    runQueryFn: async (target) => { probed = target; return []; },
    persistConfig: async (next) => { persisted = next; },
  });
  assert.equal(connection.tenantId, "72f988bf-86f1-41af-91ab-2d7cd011db47");
  assert.equal(probed.tenantId, connection.tenantId);
  assert.equal(persisted.tenantId, connection.tenantId);
  assert.equal(entry.tenantId, connection.tenantId);
  assert.equal(entry.canvasState.foundryAccountId, null);
});

test("canvas definition exposes collaborative actions on the one shared database", async () => {
  const calls = [];
  const entry = {
    clusterUri: "http://localhost:8082",
    database: "SharedHub",
    tenantId: "72f988bf-86f1-41af-91ab-2d7cd011db47",
    canvasState: {
      tab: "overview",
      preset: "all",
      filters: {},
      foundryPreset: "7d",
      foundryAccountId: null,
      revision: 0,
    },
  };
  const canvas = extension.createDashboardCanvas({
    canvasFactory: (definition) => definition,
    getEntry: () => entry,
    runQueryFn: async (clusterUri, database, kql) => {
      calls.push({ clusterUri, database, kql });
      return Array.from({ length: 501 }, (_, Value) => ({ Value }));
    },
    persistConfig: async () => {},
  });
  const names = canvas.actions.map((action) => action.name);
  for (const name of ["get_build_info", "get_connection", "set_connection", "get_canvas_state", "set_canvas_state", "get_view", "run_query"]) {
    assert.ok(names.includes(name));
  }
  assert.ok(canvas.inputSchema.properties.tenantId);
  assert.equal(canvas.inputSchema.properties.monitorTenantId, undefined);
  assert.ok(canvas.actions.find((action) => action.name === "set_connection").inputSchema.properties.tenantId);
  assert.equal(canvas.actions.find((action) => action.name === "set_connection").inputSchema.properties.monitorTenantId, undefined);
  assert.ok(canvas.actions.find((action) => action.name === "set_canvas_state").inputSchema.properties.foundryAccountId);
  assert.ok(canvas.actions.find((action) => action.name === "get_view").inputSchema.properties.view.enum.includes("agents"));
  assert.deepEqual(
    await canvas.actions.find((action) => action.name === "get_build_info").handler({ input: {} }),
    { buildId: "ftk-local-dashboard-agents-v1", sourceScope: "project" }
  );
  const result = await canvas.actions.find((action) => action.name === "run_query").handler({ input: { kql: "print Value=1" } });
  assert.equal(calls[0].clusterUri.tenantId, "72f988bf-86f1-41af-91ab-2d7cd011db47");
  assert.equal(calls[0].database, "SharedHub");
  assert.equal(result.rows.length, 500);
  assert.equal(result.truncated, true);
  assert.equal(result.rowLimit, 500);
});

test("estate Compute family view joins family quota to the smallest-SKU offer status", async () => {
  const query = kusto.buildComputeFamilyQuery({});
  const [quotaCatalog, offerCatalog] = await Promise.all([
    readFile(new URL("../../../../src/queries/catalog/quota-compute-family-usage.kql", import.meta.url), "utf8"),
    readFile(new URL("../../../../src/queries/catalog/quota-compute-family-offer-status.kql", import.meta.url), "utf8"),
  ]);
  assert.ok(query.includes(quotaCatalog.trim()));
  assert.ok(query.includes(offerCatalog.trim()));
  assert.match(query, /x_SourceType =~ 'ComputeUsage'/);
  assert.match(query, /ResourceType =~ 'Microsoft\.Compute\/locations\/usages'/);
  assert.match(query, /summarize arg_max\(x_IngestionTime, \*\) by ResourceId/);
  assert.match(query, /ResourceName endswith 'Family'/);
  assert.match(offerCatalog, /RepresentativeVcpus = minif/);
  assert.match(offerCatalog, /RepresentativeVcpus asc,\s*ResourceName asc/s);
  assert.match(offerCatalog, /FamilySkuRank = row_number/);
  assert.match(offerCatalog, /where FamilySkuRank == 1/);
  assert.match(query, /join kind=leftouter ComputeFamilyOfferStatus/);
  assert.match(query, /RegionRestrictedSubscriptions=dcountif/);
  assert.match(query, /by FamilyKey, Location/);
  assert.doesNotMatch(query, /ComputeQuota\(\)|Costs\(\)|PhysicalZone/);
  // Bounded output.
  assert.match(query, new RegExp(`take ${kusto.CAPACITY_LIMITS.familyCells + 1}`));
  const filtered = kusto.buildComputeFamilyQuery({ SubAccountId: ["abc"], location: ["eastus"] });
  assert.match(filtered, /where SubscriptionId in~ \("abc"\)/);
  assert.match(filtered, /where Location in~ \("eastus"\)/);
});

test("App Service matrix uses exact plan SKU quota and stays separate from billed demand", async () => {
  const query = kusto.buildAppServiceSkuQuery({});
  const catalog = await readFile(
    new URL("../../../../src/queries/catalog/quota-app-service-usage.kql", import.meta.url),
    "utf8"
  );
  assert.ok(query.includes(catalog.trim()));
  assert.match(query, /SkuKey=ResourceName, Unit=unit, Location=location/);
  assert.match(query, /Sku=iff\(SkuKey == '\*', 'Total Regional VMs', Sku\)/);
  assert.doesNotMatch(query, /Costs\(\)|PhysicalZone|Offer/);
});

test("App Service cells expose quota status separately from utilization text", () => {
  const open = kusto.appServiceSkuCell({
    UsedInstances: 3, QuotaInstances: 30, Subscriptions: 1,
    QuotaSubscriptions: 1, NoQuotaSubscriptions: 0, AtLimitSubscriptions: 0,
  });
  assert.equal(open.supply, "open");
  assert.equal(open.state, "healthy");
  assert.equal(open.text, "10.0%");
  assert.equal(open.headroomInstances, 27);
  assert.equal(open.quotaText, "Quota reported");

  const partial = kusto.appServiceSkuCell({
    UsedInstances: 3, QuotaInstances: 30, Subscriptions: 2,
    QuotaSubscriptions: 1, NoQuotaSubscriptions: 1, AtLimitSubscriptions: 0,
  });
  assert.equal(partial.supply, "partial");
  assert.equal(partial.quotaText, "1 subscription without quota");

  const blocked = kusto.appServiceSkuCell({
    UsedInstances: 30, QuotaInstances: 30, Subscriptions: 1,
    QuotaSubscriptions: 1, NoQuotaSubscriptions: 0, AtLimitSubscriptions: 1,
  });
  assert.equal(blocked.supply, "blocked");
  assert.equal(blocked.state, "exhausted");
  assert.equal(blocked.quotaText, "1 subscription at limit");

  const none = kusto.appServiceSkuCell({
    UsedInstances: 0, QuotaInstances: 0, Subscriptions: 1,
    QuotaSubscriptions: 0, NoQuotaSubscriptions: 1, AtLimitSubscriptions: 0,
  });
  assert.equal(none.supply, "none");
  assert.equal(none.state, "no-entitlement");
  assert.equal(none.utilizationPercent, null);
  assert.equal(none.headroomInstances, null);
  assert.equal(none.quotaText, "No quota reported");
});

test("App Service payload and subscription detail are quota-only and paged", async (t) => {
  const clusterUri = await startCapacityServer(t, {
    rows: (query) => {
      if (query.includes("Sku=take_any(displayName)")) {
        return [{
          Sku: "Premium V4 P1V4", SkuKey: "P1v4", Unit: "Instances", Location: "eastus",
          UsedInstances: 3, QuotaInstances: 30, Subscriptions: 1, InUseSubscriptions: 1,
          AtLimitSubscriptions: 0, QuotaSubscriptions: 1, NoQuotaSubscriptions: 0,
        }];
      }
      if (query.includes("SkuRegionPairs=count()")) {
        return [{
          SubscriptionId: "sub-1", Skus: 2, Regions: 1, SkuRegionPairs: 2,
          InUsePairs: 1, AtLimitPairs: 0, NoQuotaPairs: 1,
          TotalSubscriptions: 1, RowNumber: 1,
        }];
      }
      return [];
    },
  });
  const payload = await kusto.getCapacity(clusterUri, "Hub", "app-service");
  assert.equal(payload.schema.costs, undefined);
  assert.equal(payload.capability.mode, "enabled");
  assert.equal(payload.capability.reasonCode, "catalog-quota-present");
  assert.equal(payload.appServiceHeatmap.rows.length, 1);
  assert.equal(payload.appServiceHeatmap.rows[0].semantic.supply, "open");
  assert.equal(payload.demand.capability.reasonCode, "class-uses-quota-only");

  const page = await kusto.getCapacitySubscriptionPage(clusterUri, "Hub", {
    classId: "app-service",
    page: 1,
    pageSize: 50,
  });
  assert.equal(page.classId, "app-service");
  assert.equal(page.totalSubscriptions, 1);
  assert.equal(page.totalPages, 1);
  assert.equal(page.rows[0].SubscriptionId, "sub-1");
  assert.equal(page.rows[0].SkuRegionPairs, 2);
  assert.equal(page.rows[0].InUsePairs, 1);
  assert.equal(page.rows[0].TotalSubscriptions, undefined);
  assert.equal(page.rows[0].RowNumber, undefined);
});

test("Azure SQL matrix includes only current regional quota contracts", async () => {
  const query = kusto.buildAzureSqlQuotaQuery({});
  const catalog = await readFile(
    new URL("../../../../src/queries/catalog/quota-sql-subscription-usage.kql", import.meta.url),
    "utf8"
  );
  assert.ok(query.includes(catalog.trim()));
  assert.equal(kusto.AZURE_SQL_QUOTA_METRICS.length, 5);
  for (const metric of kusto.AZURE_SQL_QUOTA_METRICS) {
    assert.match(query, new RegExp(metric.resourceName));
  }
  assert.doesNotMatch(query, /FreeLimitQuota|SubscriptionFreeDatabaseDaysLeft|SubnetQuota|"VCoreQuota"/);
  assert.doesNotMatch(query, /Costs\(\)|PhysicalZone|Offer/);
});

test("Azure SQL cells keep quota coverage separate from utilization", () => {
  const open = kusto.azureSqlQuotaCell({
    MetricKey: "ServerQuota", Used: 3, Quota: 250, Subscriptions: 1,
    QuotaSubscriptions: 1, NoQuotaSubscriptions: 0, NegativeLimitSubscriptions: 0,
    AtLimitSubscriptions: 0,
  });
  assert.equal(open.supply, "open");
  assert.equal(open.state, "healthy");
  assert.equal(open.text, "1.2%");
  assert.equal(open.headroomUnits, 247);
  assert.equal(open.unitLabel, "servers");
  assert.equal(open.quotaText, "Quota reported");

  const partial = kusto.azureSqlQuotaCell({
    MetricKey: "SubscriptionSQLManagedInstanceStandardSeriesVCoreQuota",
    Used: 80, Quota: 320, Subscriptions: 2,
    QuotaSubscriptions: 1, NoQuotaSubscriptions: 1, NegativeLimitSubscriptions: 0,
    AtLimitSubscriptions: 0,
  });
  assert.equal(partial.supply, "partial");
  assert.equal(partial.text, "25.0%");
  assert.equal(partial.quotaText, "1 subscription has no usable quota");

  const blocked = kusto.azureSqlQuotaCell({
    MetricKey: "RegionalVCoreQuotaForSQLDBAndDW",
    Used: 2000, Quota: 2000, Subscriptions: 1,
    QuotaSubscriptions: 1, NoQuotaSubscriptions: 0, NegativeLimitSubscriptions: 0,
    AtLimitSubscriptions: 1,
  });
  assert.equal(blocked.supply, "blocked");
  assert.equal(blocked.state, "exhausted");
  assert.equal(blocked.quotaText, "1 subscription at limit");

  const negative = kusto.azureSqlQuotaCell({
    MetricKey: "RegionalVCoreQuotaForSQLDBAndDW",
    Used: 0, Quota: 0, Subscriptions: 1,
    QuotaSubscriptions: 0, NoQuotaSubscriptions: 1, NegativeLimitSubscriptions: 1,
    AtLimitSubscriptions: 0,
  });
  assert.equal(negative.supply, "none");
  assert.equal(negative.state, "no-entitlement");
  assert.equal(negative.utilizationPercent, null);
  assert.equal(negative.headroomUnits, null);
  assert.match(negative.quotaText, /unsupported negative limit/i);
});

test("Azure SQL payload and subscription detail are quota-only and paged", async (t) => {
  const clusterUri = await startCapacityServer(t, {
    rows: (query) => {
      if (query.includes("Metric=take_any(QuotaMetric)")) {
        return [{
          Metric: "Logical servers", MetricKey: "ServerQuota", Unit: "Count", Location: "eastus",
          Used: 3, Quota: 250, Subscriptions: 1, InUseSubscriptions: 1,
          AtLimitSubscriptions: 0, QuotaSubscriptions: 1, NoQuotaSubscriptions: 0,
          NegativeLimitSubscriptions: 0,
        }];
      }
      if (query.includes("MetricRegionPairs=count()")) {
        return [{
          SubscriptionId: "sub-1", Metrics: 5, Regions: 1, MetricRegionPairs: 5,
          InUsePairs: 1, AtLimitPairs: 0, NoQuotaPairs: 1, NegativeLimitPairs: 1,
          TotalSubscriptions: 1, RowNumber: 1,
        }];
      }
      return [];
    },
  });
  const payload = await kusto.getCapacity(clusterUri, "Hub", "azure-sql");
  assert.equal(payload.schema.costs, undefined);
  assert.equal(payload.capability.mode, "enabled");
  assert.equal(payload.capability.reasonCode, "catalog-quota-present");
  assert.equal(payload.azureSqlHeatmap.rows.length, 1);
  assert.equal(payload.azureSqlHeatmap.rows[0].semantic.supply, "open");
  assert.equal(payload.azureSqlHeatmap.rows[0].semantic.unitLabel, "servers");
  assert.equal(payload.demand.capability.reasonCode, "class-uses-quota-only");

  const page = await kusto.getCapacitySubscriptionPage(clusterUri, "Hub", {
    classId: "azure-sql",
    page: 1,
    pageSize: 50,
  });
  assert.equal(page.classId, "azure-sql");
  assert.equal(page.totalSubscriptions, 1);
  assert.equal(page.totalPages, 1);
  assert.equal(page.rows[0].SubscriptionId, "sub-1");
  assert.equal(page.rows[0].MetricRegionPairs, 5);
  assert.equal(page.rows[0].NegativeLimitPairs, 1);
  assert.equal(page.rows[0].TotalSubscriptions, undefined);
  assert.equal(page.rows[0].RowNumber, undefined);
});

test("Azure AI matrix groups by exact model/tier resource name, not a fixed metric registry", async () => {
  const query = kusto.buildAzureAiModelQuery({});
  const catalog = await readFile(
    new URL("../../../../src/queries/catalog/quota-cognitive-services-usage.kql", import.meta.url),
    "utf8"
  );
  assert.ok(query.includes(catalog.trim()));
  assert.match(query, /Model=take_any\(displayName\)/);
  assert.match(query, /by ModelKey=ResourceName, Unit=unit, Location=location/);
  assert.doesNotMatch(query, /Costs\(\)|PhysicalZone|Offer/);
});

test("Azure AI cells keep quota coverage separate from utilization", () => {
  const open = kusto.azureAiModelCell({
    ModelKey: "OpenAI.GlobalStandard.gpt-4o", Used: 30, Quota: 300, Subscriptions: 1,
    QuotaSubscriptions: 1, NoQuotaSubscriptions: 0, AtLimitSubscriptions: 0,
  });
  assert.equal(open.supply, "open");
  assert.equal(open.state, "healthy");
  assert.equal(open.text, "10.0%");
  assert.equal(open.headroomUnits, 270);
  assert.equal(open.unitLabel, "units");
  assert.equal(open.quotaText, "Quota reported");

  const partial = kusto.azureAiModelCell({
    ModelKey: "AIServices.GlobalStandard.Codestral-2501", Used: 30, Quota: 300, Subscriptions: 2,
    QuotaSubscriptions: 1, NoQuotaSubscriptions: 1, AtLimitSubscriptions: 0,
  });
  assert.equal(partial.supply, "partial");
  assert.equal(partial.quotaText, "1 subscription has no usable quota");

  const blocked = kusto.azureAiModelCell({
    ModelKey: "AIServices.GlobalProvisionedManaged", Used: 300, Quota: 300, Subscriptions: 1,
    QuotaSubscriptions: 1, NoQuotaSubscriptions: 0, AtLimitSubscriptions: 1,
  });
  assert.equal(blocked.supply, "blocked");
  assert.equal(blocked.state, "exhausted");
  assert.equal(blocked.quotaText, "1 subscription at limit");

  const none = kusto.azureAiModelCell({
    ModelKey: "OpenAI.GlobalStandard.o3", Used: 0, Quota: 0, Subscriptions: 1,
    QuotaSubscriptions: 0, NoQuotaSubscriptions: 1, AtLimitSubscriptions: 0,
  });
  assert.equal(none.supply, "none");
  assert.equal(none.state, "no-entitlement");
  assert.equal(none.utilizationPercent, null);
  assert.equal(none.headroomUnits, null);
  assert.equal(none.quotaText, "No quota reported");
});

test("Azure AI payload and subscription detail are quota-only and paged", async (t) => {
  const clusterUri = await startCapacityServer(t, {
    rows: (query) => {
      if (query.includes("Model=take_any(displayName)")) {
        return [{
          Model: "Tokens Per Minute (thousands) - gpt-4o", ModelKey: "OpenAI.GlobalStandard.gpt-4o",
          Unit: "Count", Location: "eastus",
          Used: 30, Quota: 300, Subscriptions: 1, InUseSubscriptions: 1,
          AtLimitSubscriptions: 0, QuotaSubscriptions: 1, NoQuotaSubscriptions: 0,
        }];
      }
      if (query.includes("ModelRegionPairs=count()")) {
        return [{
          SubscriptionId: "sub-1", Models: 2, Regions: 1, ModelRegionPairs: 2,
          InUsePairs: 1, AtLimitPairs: 0, NoQuotaPairs: 1,
          TotalSubscriptions: 1, RowNumber: 1,
        }];
      }
      return [];
    },
  });
  const payload = await kusto.getCapacity(clusterUri, "Hub", "azure-ai");
  assert.equal(payload.schema.costs, undefined);
  assert.equal(payload.capability.mode, "enabled");
  assert.equal(payload.capability.reasonCode, "catalog-quota-present");
  assert.equal(payload.azureAiHeatmap.rows.length, 1);
  assert.equal(payload.azureAiHeatmap.rows[0].semantic.supply, "open");
  assert.equal(payload.demand.capability.reasonCode, "class-uses-quota-only");

  const page = await kusto.getCapacitySubscriptionPage(clusterUri, "Hub", {
    classId: "azure-ai",
    page: 1,
    pageSize: 50,
  });
  assert.equal(page.classId, "azure-ai");
  assert.equal(page.totalSubscriptions, 1);
  assert.equal(page.totalPages, 1);
  assert.equal(page.rows[0].SubscriptionId, "sub-1");
  assert.equal(page.rows[0].ModelRegionPairs, 2);
  assert.equal(page.rows[0].InUsePairs, 1);
  assert.equal(page.rows[0].TotalSubscriptions, undefined);
  assert.equal(page.rows[0].RowNumber, undefined);
});

test("Compute family cells classify only provider-reported quota values", () => {
  const healthy = kusto.computeFamilyCell({ CoresUsed: 10, CoresTotal: 100, Subscriptions: 1 });
  assert.equal(healthy.state, "healthy");
  assert.equal(healthy.headroomCores, 90);
  assert.equal(healthy.text, "10.0%");

  assert.equal(kusto.computeFamilyCell({ CoresUsed: 85, CoresTotal: 100, Subscriptions: 1 }).state, "watch");
  assert.equal(kusto.computeFamilyCell({ CoresUsed: 95, CoresTotal: 100, Subscriptions: 1 }).state, "action");
  assert.equal(kusto.computeFamilyCell({ CoresUsed: 100, CoresTotal: 100, Subscriptions: 1 }).state, "exhausted");

  // Zero quota is not zero utilization.
  const none = kusto.computeFamilyCell({ CoresUsed: 0, CoresTotal: 0, Subscriptions: 1 });
  assert.equal(none.state, "no-entitlement");
  assert.equal(none.utilizationPercent, null);
  assert.equal(none.headroomCores, null);

  assert.deepEqual(
    kusto.annotateComputeFamilyRows([{ CoresUsed: 1, CoresTotal: 4, Subscriptions: 1 }])[0].semantic.text,
    "25.0%"
  );
});

test("dashboard speaks capacity vocabulary and never says evidence", async () => {
  const sources = await Promise.all(
    ["kusto.mjs", "extension.mjs", "public/app.js", "public/app.css", "README.md", "PRODUCT.md"]
      .map((file) => readFile(new URL(`../${file}`, import.meta.url), "utf8"))
  );
  for (const [index, text] of sources.entries()) {
    assert.doesNotMatch(text, /evidence/i, `evidence terminology remains in source ${index}`);
  }
  // Capacity managers read quota, headroom, utilization, and restrictions.
  const contract = kusto.CAPACITY_CLASS_REGISTRY.compute;
  assert.equal(contract.quotaType, "quota");
  assert.match(contract.sourceNote, /quota/i);
});

test("family rows keep family quota separate from representative-SKU offer status", () => {
  const [withQuota] = kusto.annotateComputeFamilyRows([{
    Family: "Standard Dv5 Family vCPUs", FamilyKey: "standardDv5Family", Location: "eastus",
    CoresUsed: 10, CoresTotal: 100, Subscriptions: 1,
    OfferSubscriptions: 1, RegionRestrictedSubscriptions: 0, ZoneRestrictedSubscriptions: 1,
    RepresentativeSkus: ["Standard_D2s_v5"], RepresentativeVcpus: 2,
    ZonesPresent: [["1", "2", "3"]], ZonesRestricted: [["3"]],
    x_IngestionTime: "2026-08-24T00:00:00Z",
  }]);
  assert.deepEqual(withQuota.ZonesPresent, ["1", "2", "3"]);
  assert.deepEqual(withQuota.ZonesRestricted, ["3"]);
  assert.deepEqual(withQuota.RepresentativeSkus, ["Standard_D2s_v5"]);
  assert.equal(withQuota.semantic.state, "healthy");
  assert.equal(withQuota.semantic.supply, "partial");
  assert.equal(withQuota.semantic.offerText, "1 AZ restricted");
  assert.equal(withQuota.semantic.text, "10.0%");
  assert.equal(withQuota.semantic.headroomCores, 90);
});

test("shared matrix filters reduce Compute, App Service, Azure SQL, and Azure AI grids without dead ends", () => {
  const rows = [
    { Family: "Standard Dv5 Family vCPUs", FamilyKey: "dv5", Location: "eastus", CoresUsed: 10, CoresTotal: 100, semantic: { offerState: "available" } },
    { Family: "Standard Ev5 Family vCPUs", FamilyKey: "ev5", Location: "westus", CoresUsed: 0, CoresTotal: 200, semantic: { offerState: "zone-restricted", zonesRestricted: ["1"] } },
    { Family: "Standard NC Family vCPUs", FamilyKey: "nc", Location: "eastus", CoresUsed: 0, CoresTotal: 0, semantic: { offerState: "no-quota" } },
    { Family: "Standard Fsv2 Family vCPUs", FamilyKey: "fsv2", Location: "westus", CoresUsed: 50, CoresTotal: 50, semantic: { offerState: "available" } },
  ];
  const ids = (filter) => app.filterCapacityMatrixRows(rows, "compute", filter).map((row) => row.FamilyKey);

  // The default lens answers "what do we actually run", not "show me everything".
  assert.deepEqual(ids({ status: "in-use" }), ["dv5", "fsv2"]);
  assert.deepEqual(ids({ status: "at-limit" }), ["fsv2"]);
  assert.deepEqual(ids({ status: "available" }), ["dv5"]);
  assert.deepEqual(ids({ status: "restricted" }), ["ev5"]);
  assert.deepEqual(ids({ status: "no-quota" }), ["nc"]);
  assert.equal(ids({ status: "all" }).length, 4);

  // Family search and region chips compose rather than replace each other.
  assert.deepEqual(ids({ status: "all", search: "ev5" }), ["ev5"]);
  assert.deepEqual(ids({ status: "all", regions: ["eastus"] }), ["dv5", "nc"]);
  assert.deepEqual(ids({ status: "all", search: "standard", regions: ["westus"] }), ["ev5", "fsv2"]);
  // Search matches the family key as well as the display label.
  assert.deepEqual(ids({ status: "all", search: "fsv2" }), ["fsv2"]);
  // An unmatched needle returns nothing rather than falling back to everything.
  assert.deepEqual(ids({ status: "all", search: "nosuchfamily" }), []);
  // Every lens is reachable and counted, so no lens can become a dead end.
  assert.deepEqual(app.MATRIX_STATUS_FILTERS.map((lens) => lens.id), ["in-use", "at-limit", "available", "all"]);
  assert.deepEqual(app.FAMILY_STATUS_FILTERS.map((lens) => lens.id), ["in-use", "at-limit", "available", "restricted", "all"]);

  const appServiceRows = [
    {
      Sku: "Premium V4 P1V4", SkuKey: "P1v4", Location: "eastus",
      UsedInstances: 0, QuotaInstances: 30, AtLimitSubscriptions: 0, QuotaSubscriptions: 1,
    },
    {
      Sku: "Standard S1", SkuKey: "S1", Location: "westus",
      UsedInstances: 1, QuotaInstances: 1, AtLimitSubscriptions: 1, QuotaSubscriptions: 1,
    },
    {
      Sku: "Total Regional VMs", SkuKey: "*", Location: "eastus",
      UsedInstances: 0, QuotaInstances: 0, AtLimitSubscriptions: 0, QuotaSubscriptions: 0,
    },
  ];
  const skuIds = (filter) => app.filterCapacityMatrixRows(appServiceRows, "app-service", filter).map((row) => row.SkuKey);
  assert.deepEqual(skuIds({ status: "at-limit" }), ["S1"]);
  assert.deepEqual(skuIds({ status: "available" }), ["P1v4"]);
  assert.deepEqual(skuIds({ status: "no-quota" }), ["*"]);
  assert.deepEqual(skuIds({ status: "all", search: "premium", regions: ["eastus"] }), ["P1v4"]);

  const azureSqlRows = [
    {
      Metric: "Logical servers", MetricKey: "ServerQuota", Location: "eastus",
      Used: 3, Quota: 250, AtLimitSubscriptions: 0, QuotaSubscriptions: 1,
    },
    {
      Metric: "Azure SQL Database and Synapse vCores", MetricKey: "RegionalVCoreQuotaForSQLDBAndDW",
      Location: "westus", Used: 2000, Quota: 2000, AtLimitSubscriptions: 1, QuotaSubscriptions: 1,
    },
    {
      Metric: "SQL MI premium-series vCores", MetricKey: "SubscriptionSQLManagedInstancePremiumSeriesVCoreQuota",
      Location: "eastus", Used: 0, Quota: 0, AtLimitSubscriptions: 0, QuotaSubscriptions: 0,
    },
  ];
  const sqlIds = (filter) => app.filterCapacityMatrixRows(azureSqlRows, "azure-sql", filter).map((row) => row.MetricKey);
  assert.deepEqual(sqlIds({ status: "in-use" }), ["ServerQuota", "RegionalVCoreQuotaForSQLDBAndDW"]);
  assert.deepEqual(sqlIds({ status: "at-limit" }), ["RegionalVCoreQuotaForSQLDBAndDW"]);
  assert.deepEqual(sqlIds({ status: "available" }), ["ServerQuota"]);
  assert.deepEqual(sqlIds({ status: "no-quota" }), ["SubscriptionSQLManagedInstancePremiumSeriesVCoreQuota"]);
  assert.deepEqual(sqlIds({ status: "all", search: "server", regions: ["eastus"] }), ["ServerQuota"]);

  const azureAiRows = [
    {
      Model: "Tokens Per Minute (thousands) - gpt-4o", ModelKey: "OpenAI.GlobalStandard.gpt-4o",
      Location: "eastus", Used: 30, Quota: 300, AtLimitSubscriptions: 0, QuotaSubscriptions: 1,
    },
    {
      Model: "Tokens Per Minute (thousands) - Codestral-2501", ModelKey: "AIServices.GlobalStandard.Codestral-2501",
      Location: "westus", Used: 300, Quota: 300, AtLimitSubscriptions: 1, QuotaSubscriptions: 1,
    },
    {
      Model: "Provisioned Managed Throughput Units", ModelKey: "AIServices.GlobalProvisionedManaged",
      Location: "eastus", Used: 0, Quota: 0, AtLimitSubscriptions: 0, QuotaSubscriptions: 0,
    },
  ];
  const modelIds = (filter) => app.filterCapacityMatrixRows(azureAiRows, "azure-ai", filter).map((row) => row.ModelKey);
  assert.deepEqual(modelIds({ status: "in-use" }), ["OpenAI.GlobalStandard.gpt-4o", "AIServices.GlobalStandard.Codestral-2501"]);
  assert.deepEqual(modelIds({ status: "at-limit" }), ["AIServices.GlobalStandard.Codestral-2501"]);
  assert.deepEqual(modelIds({ status: "available" }), ["OpenAI.GlobalStandard.gpt-4o"]);
  assert.deepEqual(modelIds({ status: "no-quota" }), ["AIServices.GlobalProvisionedManaged"]);
  assert.deepEqual(modelIds({ status: "all", search: "gpt-4o" }), ["OpenAI.GlobalStandard.gpt-4o"]);
  assert.deepEqual(modelIds({ status: "all", search: "standard", regions: ["westus"] }), ["AIServices.GlobalStandard.Codestral-2501"]);
});

test("shared matrix keeps both scrollbars and its frozen panes reachable", async () => {
  const [css, js] = await Promise.all([
    readFile(new URL("../public/ui.css", import.meta.url), "utf8"),
    readFile(new URL("../public/ui.js", import.meta.url), "utf8"),
  ]);
  const matrix = css.slice(css.indexOf(".ui-matrix-viewport {"));

  // A bounded viewport is what keeps the horizontal bar on screen; without the
  // height cap the table outgrows the window and the bar sits below the fold.
  assert.match(matrix, /max-height:\s*min\(70vh/);
  assert.match(matrix, /overflow:\s*auto/);
  // macOS overlay scrollbars fade when idle, so they are drawn permanently.
  assert.match(matrix, /::-webkit-scrollbar-thumb/);
  assert.match(matrix, /scrollbar-color:/);

  // Frozen panes on both axes: region header, family column, and the corner.
  assert.match(css, /\.ui-matrix thead th\s*\{[^}]*position:\s*sticky[^}]*top:\s*0/s);
  assert.match(css, /\.ui-matrix tbody th:first-child\s*\{[^}]*position:\s*sticky[^}]*left:\s*0/s);
  assert.match(css, /\.ui-matrix thead th:first-child\s*\{[^}]*z-index:\s*3/s);

  // The scroll region is keyboard reachable and named for assistive tech.
  assert.match(js, /class="ui-matrix-viewport" tabindex="0" role="region" aria-label=/);
  // Filter controls carry state in markup, not colour alone.
  assert.match(js, /role="radiogroup"/);
  assert.match(js, /aria-checked="\$\{active\}"/);
  assert.match(js, /aria-pressed="\$\{selectedValues\.has/);
  // The count summary tells the operator how much of the grid is hidden.
  assert.match(js, /ui-filter-summary" role="status"/);
});

test("offer status uses the representative SKU while utilization uses family quota", () => {
  const open = kusto.computeFamilyCell({
    CoresTotal: 1000, CoresUsed: 950, Subscriptions: 2, OfferSubscriptions: 2,
  });
  assert.equal(open.supply, "open");
  assert.equal(open.state, "action", "open supply still escalates on demand");
  assert.equal(open.offerText, "Region available");

  const zoneRestricted = kusto.computeFamilyCell({
    CoresTotal: 100, CoresUsed: 0, OfferSubscriptions: 1,
    RegionRestrictedSubscriptions: 0, ZonesPresent: ["1", "2", "3"], ZonesRestricted: ["2"],
  });
  assert.equal(zoneRestricted.supply, "partial");
  assert.equal(zoneRestricted.offerText, "1 AZ restricted");
  assert.deepEqual(zoneRestricted.zoneStates, [
    { zone: "1", restricted: false },
    { zone: "2", restricted: true },
    { zone: "3", restricted: false },
  ]);

  const regionRestricted = kusto.computeFamilyCell({
    CoresTotal: 100, CoresUsed: 0, OfferSubscriptions: 1,
    RegionRestrictedSubscriptions: 1, ZonesPresent: ["1", "2", "3"], ZonesRestricted: [],
  });
  assert.equal(regionRestricted.supply, "blocked");
  assert.equal(regionRestricted.offerText, "Region restricted");
  assert.ok(regionRestricted.zoneStates.every((zone) => zone.restricted));

  const none = kusto.computeFamilyCell({ CoresTotal: 0, CoresUsed: 0, Subscriptions: 1, OfferSubscriptions: 1 });
  assert.equal(none.supply, "none");
  assert.equal(none.state, "no-entitlement");
  assert.equal(none.offerText, "No quota reported");

  const exhausted = kusto.computeFamilyCell({ CoresTotal: 100, CoresUsed: 100, Subscriptions: 1, OfferSubscriptions: 1 });
  assert.equal(exhausted.supply, "open", "quota exhaustion does not change offer status");
  assert.equal(exhausted.state, "exhausted");
});

test("the high-water mark moves the utilization alarm without losing the exhausted case", () => {
  assert.equal(app.DEFAULT_HIGH_WATER_MARK, 70);
  assert.deepEqual(app.HIGH_WATER_MARKS, [60, 70, 80, 90]);

  assert.equal(app.familyDemandTier(69.9), "under");
  assert.equal(app.familyDemandTier(70), "over", "at the mark is over the mark");
  assert.equal(app.familyDemandTier(99.9), "over");
  assert.equal(app.familyDemandTier(100), "exhausted", "100% stays distinct from merely over");
  assert.equal(app.familyDemandTier(140), "exhausted");

  assert.equal(app.familyDemandTier(65, 60), "over", "the mark is the operator's, not ours");
  assert.equal(app.familyDemandTier(65, 90), "under");

  assert.equal(app.familyDemandTier(null), "none");
  assert.equal(app.familyDemandTier(undefined), "none");
  assert.equal(app.familyDemandTier(NaN), "none");
});

test("quota status and utilization stay separate channels in the rendered matrix", async () => {
  const [css, uiCss, js, html] = await Promise.all([
    readFile(new URL("../public/app.css", import.meta.url), "utf8"),
    readFile(new URL("../public/ui.css", import.meta.url), "utf8"),
    readFile(new URL("../public/app.js", import.meta.url), "utf8"),
    readFile(new URL("../public/index.html", import.meta.url), "utf8"),
  ]);

  // Offer status owns the bar, utilization owns the number.
  for (const supply of ["open", "partial", "blocked", "none"]) {
    assert.match(uiCss, new RegExp(`\\.capacity-supply--${supply}\\b`), `${supply} needs a bar`);
  }
  assert.match(uiCss, /\.ui-matrix-cell\.capacity-supply--blocked\s*\{[^}]*inset 3px 0 0 var\(--neg\)/s);
  assert.match(uiCss, /\.ui-matrix-cell--missing,\s*\.ui-matrix-cell\.capacity-supply--none\s*\{[^}]*inset 3px 0 0 color-mix/s);
  assert.doesNotMatch(
    uiCss,
    /capacity-heatmap--family[^\n]*capacity-state--healthy[^\n]*border-right-color/,
    "utilization must not colour the supply bar again",
  );
  assert.match(uiCss, /\.ui-matrix-cell\.capacity-demand--over strong\s*\{[^}]*var\(--neg-ink\)/s);
  assert.match(css, /--neg-ink:\s*color-mix/, "alert text needs an AA-safe token, not raw --neg");

  // Colour is never the only channel: crossing the mark is also stated in words.
  assert.match(js, /Over \$\{mark\}% mark/);
  assert.match(js, /Quota exhausted/);
  assert.match(js, /capacity-supply--\$\{esc\(semantic\.supply/);
  assert.match(js, /capacity-demand--\$\{esc\(tier\)\}/);
  assert.match(js, /name: "matrix-mark"/, "the mark must be the operator's to set");
  assert.match(js, /Offer status" : "Quota status"\}, the left bar/);
  assert.match(js, /Quota utilization, the percentage/);
  assert.match(js, /AZ \$\{esc\(item\.zone\)\}/);
  assert.match(js, /capacityMatrixFilters: \{/, "shared matrix state must exist");
  assert.match(js, /status: "all"/, "the zero-usage estate must not start with every cell hidden");
  assert.match(uiCss, /\.ui-matrix-cell \.capacity-zone--restricted\s*\{[^}]*var\(--warn-ink\)/s);
  assert.match(uiCss, /\.ui-cell-status--danger\s*\{[^}]*var\(--neg-ink\)/s);
  assert.match(uiCss, /\.ui-cell-status--warning\s*\{[^}]*var\(--warn-ink\)/s);
  assert.match(html, /data-tab="capacity"[^>]*>Supply<\/button>/);
});

test("last closed month skips a partial ingestion month", () => {
  // Data stops mid-month: that month is still ingesting, so the month before
  // it is the newest one safe to compare against.
  assert.equal(kusto.lastClosedMonthStart("2026-08-20").toISOString().slice(0, 10), "2026-07-01");
  // Data reaches the final day: the month is complete and is itself the anchor.
  assert.equal(kusto.lastClosedMonthStart("2026-08-31").toISOString().slice(0, 10), "2026-08-01");
  assert.equal(kusto.lastClosedMonthStart("2026-02-28").toISOString().slice(0, 10), "2026-02-01");
  assert.equal(kusto.lastClosedMonthStart(null), null);
});

test("AI KPIs anchor month-over-month to the closed month, not the partial one", () => {
  const payload = {
    monthly: [
      { Month: "2026-06", Cloud: 1000, Estate: 400, MlGpu: 300, Tokens: 1000000, TokenCost: 10 },
      { Month: "2026-07", Cloud: 1200, Estate: 500, MlGpu: 380, Tokens: 2000000, TokenCost: 30 },
      { Month: "2026-08", Cloud: 200, Estate: 80, MlGpu: 60, Tokens: 400000, TokenCost: 6 },
    ],
    allocation: [{ Total: 980, App: 490, Owner: 0, CostCenter: 980, ResourceGroup: 980 }],
    posture: [{ Total: 980, Committed: 245 }],
    recommendations: [{ Count: 3 }],
    transactions: [{ Count: 0 }],
  };
  const k = app.deriveAiKpis(payload, "2026-07");

  // July (500) against June (400) is +25%. Anchoring to the partial August
  // month instead would report a -84% collapse that never happened.
  assert.equal(k.closedMonth, "2026-07");
  assert.equal(k.partialMonth, "2026-08");
  assert.ok(Math.abs(k.mom - 0.25) < 1e-9);

  // Totals still span the whole window, including the partial month.
  assert.equal(k.estate, 980);
  assert.equal(k.cloud, 2400);
  assert.equal(k.tokens, 3400000);
  assert.ok(Math.abs(k.cpmt - (46 / 3400000) * 1000000) < 1e-9);
  assert.ok(Math.abs(k.appCoverage - 0.5) < 1e-9);
  assert.ok(Math.abs(k.committedShare - 0.25) < 1e-9);
  assert.equal(k.recommendations, 3);
  assert.equal(k.transactions, 0);
});

test("AI KPIs degrade to null rather than dividing by zero", () => {
  const k = app.deriveAiKpis({ monthly: [], allocation: [], posture: [] }, null);
  assert.equal(k.mom, null);
  assert.equal(k.cpmt, null);
  assert.equal(k.appCoverage, null);
  assert.equal(k.committedShare, null);
  assert.equal(k.estateShare, 0);
  assert.equal(k.recommendations, 0);
});

test("AI tab is wired end to end and every panel can show its query", async () => {
  const [html, source] = await Promise.all([
    readFile(new URL("../public/index.html", import.meta.url), "utf8"),
    readFile(new URL("../public/app.js", import.meta.url), "utf8"),
  ]);
  assert.match(html, /data-tab="ai"/);
  assert.match(source, /const VALID_TABS = \[[^\]]*"ai"/);
  assert.match(source, /state\.tab === "ai"\) renderAi\(p\)/);
  // The server must accept "ai" as a view name, which proves the getter is
  // registered and reachable through /api/view.
  assert.equal(extension.validateViewInput({ name: "ai", preset: "6m" }).name, "ai");

  // Every panel the AI tab renders must resolve to a named query, or its
  // "KQL" button opens an empty dialog.
  const panelIds = [...source.matchAll(/panelHtml\("(ai-[a-z-]+)"/g)].map((m) => m[1]);
  assert.ok(panelIds.length >= 15);
  const mapped = source.slice(source.indexOf("const PANEL_QUERY"), source.indexOf("};", source.indexOf("const PANEL_QUERY")));
  for (const id of panelIds) {
    assert.ok(mapped.includes(`"${id}"`), `PANEL_QUERY is missing '${id}'`);
  }
});

test("AI Foundry tab renders the canonical platform-metrics dashboard", async () => {
  const [html, source, styles] = await Promise.all([
    readFile(new URL("../public/index.html", import.meta.url), "utf8"),
    readFile(new URL("../public/app.js", import.meta.url), "utf8"),
    readFile(new URL("../public/app.css", import.meta.url), "utf8"),
  ]);
  assert.match(html, /data-tab="foundry"/);
  assert.doesNotMatch(html, /settings-monitor-tenant/);
  assert.match(html, /This tenant ID controls remote Hub authentication and tenant-wide AI Foundry resource discovery/);
  assert.match(source, /state\.tab === "foundry"\) renderFoundry\(p\)/);
  assert.match(source, /Azure Monitor platform metrics/);
  assert.match(source, /Hub Prices\(\) estimate/);
  assert.match(source, /Costs\(\) remains authoritative/);
  assert.match(source, /Prices can't be estimated for AI resources outside this Hub's billing scope/);
  assert.match(source, /companion:\s*\[4,\s*5,\s*8\]\.includes\(panel\.id\)\s*\?\s*\{\s*label:\s*"Estimated cost"\s*\}/);
  assert.match(source, /foundry-dashboard-grid/);
  assert.match(source, /data-foundry-account/);
  assert.match(source, /previous month's price sheet/);
  assert.match(source, /state\.foundryPreset = sharedState\.foundryPreset/);
  const foundryRenderer = source.slice(source.indexOf("function renderFoundry"), source.indexOf("function renderAgents"));
  assert.doesNotMatch(foundryRenderer, /Agents|agent telemetry|dependency spans|Costs\(\) matches/);
  assert.match(styles, /\.foundry-dashboard-grid\s*\{[^}]*grid-template-rows:\s*repeat\(54,\s*36px\)/s);
  assert.match(styles, /\.foundry-panel-content\s*\{[^}]*overflow:\s*hidden/s);
  assert.match(
    app.foundryMetricChart(
      [{
        Name: "chat-prod",
        Points: [{
          Bucket: "2026-03-01T00:00:00Z",
          Value: 3,
          Cost: 0.004,
          Currency: "USD",
        }],
      }],
      {
        title: "Total Tokens",
        unit: "short",
        style: "bars",
        fillOpacity: 0.6,
        calculations: ["Sum", "Mean", "Max"],
        companion: { label: "Estimated cost" },
      }
    ),
    /Estimated cost[\s\S]*\$0\.004/
  );
  const lineChart = app.foundryMetricChart(
    [{
      Name: "chat-prod",
      Points: [
        { Bucket: "2026-03-01T00:00:00Z", Value: 3 },
        { Bucket: "2026-03-01T00:05:00Z", Value: 4 },
      ],
    }],
    { title: "Latency", unit: "ms", style: "lines", fillOpacity: 0.21, calculations: ["Mean", "Max"] }
  );
  assert.match(lineChart, /fill-opacity="0\.21"/);
  assert.match(lineChart, /--foundry-legend-calcs:2/);
  assert.equal(extension.validateViewInput({ name: "foundry", preset: "7d" }).name, "foundry");
  assert.throws(() => extension.validateViewInput({ name: "foundry", preset: "6m" }), /Unknown time preset/);
  const accountId = "/subscriptions/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/resourceGroups/ai-rg/providers/Microsoft.CognitiveServices/accounts/foundry";
  assert.deepEqual(
    extension.validateCanvasStatePatch({ foundryPreset: "30d", foundryAccountId: accountId }).patch,
    { foundryPreset: "30d", foundryAccountId: accountId }
  );
  assert.throws(
    () => extension.validateViewInput({
      name: "foundry",
      preset: "7d",
      accountId: "/subscriptions/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/resourceGroups/monitor-rg/providers/Microsoft.Insights/components/monitor",
    }),
    /Cognitive Services account resource ID/
  );
});

test("Foundry agents tab is a complete separate operational dashboard", async () => {
  const [html, source, styles, readme, product] = await Promise.all([
    readFile(new URL("../public/index.html", import.meta.url), "utf8"),
    readFile(new URL("../public/app.js", import.meta.url), "utf8"),
    readFile(new URL("../public/app.css", import.meta.url), "utf8"),
    readFile(new URL("../README.md", import.meta.url), "utf8"),
    readFile(new URL("../PRODUCT.md", import.meta.url), "utf8"),
  ]);
  assert.match(html, /data-tab="foundry"[\s\S]*data-tab="agents"/);
  assert.match(html, /data-tab="agents"[^>]*>Foundry agents</);
  assert.match(source, /state\.tab === "agents"\) renderAgents\(p\)/);
  assert.match(source, /Estimated run cost/);
  assert.match(source, /Authoritative billed cost/);
  assert.match(source, /Uncached input[\s\S]*Est\. input[\s\S]*Cached input[\s\S]*Est\. cache[\s\S]*Output[\s\S]*Est\. output/);
  assert.match(source, /Trace ID/);
  assert.match(source, /Cached input tokens/);
  assert.match(source, /Tool usage leaderboard/);
  assert.match(source, /Chat finish reasons/);
  assert.match(source, /Every panel and control derives from the same cached tenant and time-range result/);
  assert.match(styles, /\.agents-dashboard-grid\s*\{[^}]*grid-template-columns:\s*repeat\(12,/s);
  assert.match(styles, /\.agent-kpis\s*\{[^}]*grid-template-columns:\s*repeat\(4,/s);
  assert.equal(extension.validateViewInput({ name: "agents", preset: "30d" }).name, "agents");
  assert.throws(() => extension.validateViewInput({ name: "agents", preset: "6m" }), /Unknown time preset/);
  assert.match(readme, /Token charts and agent, model, and recent-run tables show each token class beside its estimated cost/);
  assert.match(readme, /Input, output, and total token tiles and charts also show the corresponding estimated cost/);
  assert.match(product, /separate Foundry agents view/);
  assert.equal(azureMonitor.AGENT_PANEL_CONTRACT.length, 12);
});

test("dashboard canvas is desktop only", async () => {
  const [html, appStyles, uiStyles] = await Promise.all([
    readFile(new URL("../public/index.html", import.meta.url), "utf8"),
    readFile(new URL("../public/app.css", import.meta.url), "utf8"),
    readFile(new URL("../public/ui.css", import.meta.url), "utf8"),
  ]);
  assert.match(html, /meta name="viewport" content="width=1280"/);
  assert.match(appStyles, /--canvas-min-width:\s*1280px/);
  assert.match(appStyles, /html,\s*body\s*\{[^}]*min-width:\s*var\(--canvas-min-width\)/s);
  assert.doesNotMatch(`${appStyles}\n${uiStyles}`, /@media\s*\(max-width:/);
});

test("unit rates keep precision instead of rounding to zero dollars", () => {
  // $/VM-hour on a large denominator is genuinely sub-cent; whole-dollar
  // formatting would render every one of these as "$0".
  assert.equal(app.fmtRate(0.000148966), "$0.00015");
  assert.equal(app.fmtRate(0.526), "$0.526");
  assert.equal(app.fmtRate(75.2341), "$75.23");
  assert.equal(app.fmtRate(1234.5), "$1,234.50");
  // An exact zero must keep the column's decimal shape, or "$0" sits beside
  // "$0.130" and breaks the right-aligned stack.
  assert.equal(app.fmtRate(0), "$0.00");
  assert.equal(app.fmtRate(null), "—");
  assert.equal(app.fmtRate(NaN), "—");
});

test("quantities stay unambiguous instead of leaking locale decimals", () => {
  // toLocaleString's 3-decimal default rendered "22.033" directly beneath
  // "22,247" — three orders of magnitude apart, one separator glyph different.
  assert.equal(app.fmtQty(22247), "22.2K");
  assert.equal(app.fmtQty(22.033), "22.03");
  assert.equal(app.fmtQty(163922.121), "163.9K");
  assert.equal(app.fmtQty(8.414), "8.41");
  assert.equal(app.fmtQty(0), "0");
  assert.equal(app.fmtQty(null), "—");
  assert.ok(!app.fmtQty(22.033).includes(","), "small quantities must not look like thousands");
});

test("a visible nonzero share never reports as 0.0%", () => {
  // A row showing real cost beside "0.0%" reads as a broken calculation, and
  // the column visibly fails to sum to 100%.
  assert.equal(app.fmtShare(0.0000255), "<0.1%");
  assert.equal(app.fmtShare(0.923), "92.3%");
  assert.equal(app.fmtShare(0), "0.0%");
  assert.equal(app.fmtShare(null), "—");
});

test("every table on the AI tab can scroll instead of forcing the page sideways", async () => {
  // .dtable sets white-space: nowrap, and .panel sets min-width: 0 with no
  // overflow. An unwrapped table therefore escapes its card and drags the whole
  // document sideways -- it broke the page below 560px before wideTable() was
  // applied to the posture table.
  const source = await readFile(new URL("../public/app.js", import.meta.url), "utf8");
  const ai = source.slice(source.indexOf("AI & emerging workloads render"), source.indexOf("anomalies & forecast render"));
  const calls = [...ai.matchAll(/(wideTable\(\s*)?tableHtml\(/g)];
  assert.ok(calls.length >= 8, `expected the AI tab to build several tables, found ${calls.length}`);
  const unwrapped = calls.filter((m) => !m[1]).length;
  assert.equal(unwrapped, 0, `${unwrapped} table(s) on the AI tab are not wrapped in wideTable()`);
});

test("a money column shares one precision and never zeroes real spend", () => {
  // Mixed precision in a right-aligned stack destroys the alignment's meaning,
  // but a fixed precision must not report real spend as exactly zero.
  const big = app.moneyColumn([{ c: 178528 }, { c: 421 }, { c: 2.08 }, { c: 0.12 }], "c");
  assert.equal(big(178528), "$178,528");
  assert.equal(big(421), "$421");
  assert.equal(big(2.08), "$2");
  assert.equal(big(0.12), "<$1", "real spend below the column precision needs a floor marker");

  const small = app.moneyColumn([{ c: 358 }, { c: 58.16 }, { c: 0.004 }], "c");
  assert.equal(small(358), "$358.00");
  assert.equal(small(58.16), "$58.16");
  assert.equal(small(0.004), "<$0.01");
  assert.equal(small(0), "$0.00", "an exact zero is legitimately zero");

  // A shared scale across two columns of the same measure.
  const pair = app.moneyColumn([{ a: 13400, b: 871 }, { a: 18, b: 17.92 }], "a", "b");
  assert.equal(pair(13400), "$13,400");
  assert.equal(pair(17.92), "$18");
  assert.equal(pair(-871), "-$871");
  assert.equal(app.moneyColumn([], "c")(5), "$5.00");
});

test("rate columns hold one precision across the column", () => {
  // The AI direction table put "$0.248" directly above "$1.20" -- a reader
  // scanning the column has to re-parse the decimal place on every row.
  const rate = app.rateColumn([{ c: 0.248 }, { c: 1.2 }, { c: 6.09 }, { c: 0.13 }], "c");
  const out = [0.248, 1.2, 6.09, 0.13].map(rate);
  assert.deepEqual(out, ["$0.25", "$1.20", "$6.09", "$0.13"]);
  const dp = new Set(out.map((s) => s.split(".")[1].length));
  assert.equal(dp.size, 1, "every cell in a rate column must share one precision");

  // Sub-dollar columns need more resolution than money columns get.
  const fine = app.rateColumn([{ c: 0.149 }, { c: 0.021 }], "c");
  assert.equal(fine(0.149), "$0.149");
  assert.equal(fine(0.021), "$0.021");
  assert.equal(app.rateColumn([{ c: 0.0004 }], "c")(0.0004), "$0.0004");

  // A real but tiny rate must never render as free.
  assert.equal(rate(0.0001), "<$0.01");
  assert.equal(app.rateColumn([], "c")(0), "$0.00");
});

test("axis ceilings round up to readable steps without clipping the series", () => {
  // Gridlines exist to be read off, so the ceiling must be a nice number --
  // and it must never fall below the largest plotted value.
  for (const v of [17300, 372300000, 1.93, 0.0004, 7, 1]) {
    const m = app.niceMax(v, 4);
    assert.ok(m >= v, `niceMax(${v}) = ${m} would clip the series`);
    const step = m / 4;
    const mag = Math.pow(10, Math.floor(Math.log10(step)));
    assert.ok([1, 2, 2.5, 5, 10].some((x) => Math.abs(step / mag - x) < 1e-9),
      `step ${step} for niceMax(${v}) is not a 1/2/2.5/5 multiple`);
  }
  assert.equal(app.niceMax(0, 4), 1);
});

test("AI capability colors cover every capability the query can emit", async () => {
  const [source, queries] = await Promise.all([
    readFile(new URL("../public/app.js", import.meta.url), "utf8"),
    readFile(new URL("../kusto.mjs", import.meta.url), "utf8"),
  ]);
  const clause = queries.slice(queries.indexOf("const AI_CAPABILITY ="));
  // Each `case()` arm ends with the label it emits, so the emitted value is
  // the last quoted string on the line. Matching every quoted string instead
  // would also pick up condition operands like 'Foundry Models'.
  const emitted = clause.slice(0, clause.indexOf("`;")).split("\n")
    .map((line) => [...line.matchAll(/'([^']+)'/g)].pop())
    .filter(Boolean)
    .map((m) => m[1]);
  const mapped = source.slice(source.indexOf("const AI_CAPABILITY_COLORS"), source.indexOf("};", source.indexOf("const AI_CAPABILITY_COLORS")));
  // A capability missing from the map silently renders in the "no data" grey,
  // which reads as an unclassified slice rather than a real workload.
  for (const capability of emitted) {
    assert.ok(mapped.includes(`"${capability}"`), `AI_CAPABILITY_COLORS is missing '${capability}'`);
  }
});
