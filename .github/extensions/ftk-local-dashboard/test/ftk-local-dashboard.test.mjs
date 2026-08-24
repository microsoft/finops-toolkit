import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import test from "node:test";

process.env.FTK_LOCAL_DASHBOARD_TEST = "1";

const kusto = await import("../kusto.mjs");
const extension = await import("../extension.mjs");
const app = await import("../public/app.js");

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
    const fields = csl.startsWith("Quota() | getschema")
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
    { clusterUri: "http://localhost:8082", database: "Hub", mode: "local", authentication: "none" }
  );
  assert.equal(
    kusto.normalizeConnection("https://example-cluster.westus.kusto.windows.net", "Hub").mode,
    "remote"
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
    "topServices", "topResourceGroups", "topRegions", "chargeCategory", "macc",
  ]);
  assert.equal(requests.length, 11);
  assert.ok(requests.every((headers) => headers.authorization === undefined));
  assert.ok(requests.every((headers) => headers["x-ms-readonly"] === "true"));
});

test("remote requests deduplicate tokens, add read-only headers, and recover after failure", async () => {
  kusto.resetKustoAuthForTests();
  let providerCalls = 0;
  let release;
  const provider = async () => {
    providerCalls++;
    await new Promise((resolve) => { release = resolve; });
    return { accessToken: "secret-token", expires_on: Math.floor(Date.now() / 1000) + 3600 };
  };
  const seen = [];
  const fetchImpl = async (_url, options) => {
    seen.push(options.headers);
    return kustoResponse([{ Ready: 1 }]);
  };
  const first = kusto.runQuery("https://cluster.westus.kusto.windows.net", "Hub", "print Ready=1", { tokenProvider: provider, fetchImpl });
  const second = kusto.runQuery("https://cluster.westus.kusto.windows.net", "Hub", "print Ready=1", { tokenProvider: provider, fetchImpl });
  await new Promise((resolve) => setImmediate(resolve));
  release();
  await Promise.all([first, second]);
  assert.equal(providerCalls, 1);
  assert.equal(seen.length, 2);
  assert.ok(seen.every((headers) => headers.Authorization === "Bearer secret-token"));
  assert.ok(seen.every((headers) => headers["x-ms-readonly"] === "true"));
  assert.notEqual(seen[0]["x-ms-client-request-id"], seen[1]["x-ms-client-request-id"]);

  kusto.resetKustoAuthForTests();
  await assert.rejects(() => kusto.runQuery(
    "https://cluster.westus.kusto.windows.net",
    "Hub",
    "print Ready=1",
    { tokenProvider: async () => { throw new Error("temporary"); }, fetchImpl }
  ));
  await kusto.runQuery(
    "https://cluster.westus.kusto.windows.net",
    "Hub",
    "print Ready=1",
    {
      tokenProvider: async () => ({ accessToken: "recovered", expires_on: Math.floor(Date.now() / 1000) + 3600 }),
      fetchImpl,
    }
  );
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
    () => kusto.runQuery("https://cluster.westus.kusto.windows.net", "Hub", "print Ready=1", {
      tokenProvider: async () => { throw new Error("secret-token-value"); },
      fetchImpl: async () => assert.fail("fetch must not run without a token"),
    }),
    (err) => /Azure CLI could not acquire/.test(err.message) && !err.message.includes("secret-token-value")
  );
});

test("response parsing detects partial failures and enforces the byte limit before parsing", async () => {
  assert.throws(() => kusto.parseKustoResponse({
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
  }), /Partial query failure/);
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
  assert.equal(Object.keys(kusto.CAPACITY_METRIC_REGISTRY).length, 3);

  const enabled = kusto.resolveCapacityMetric({
    x_SourceType: " computeusage ",
    x_SourceVersion: "1.0-USAGE",
    ResourceName: " CORES ",
    unit: " count ",
  });
  assert.equal(enabled.capability, "enabled");
  assert.equal(enabled.metricRole, "total-regional-vcpu");

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
  assert.equal(sqlNegative.state, "unclassified");
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
  const heatmap = kusto.buildCapacityHeatmapQuery("compute", {
    resourceName: "cores",
    unit: "Count",
    sourceVersion: "1.0-usage",
  });
  const demand = kusto.buildCapacityDemandSelectorQuery("compute");
  const reconciliation = kusto.buildCapacityReservationReconciliationQuery();
  const disk = kusto.buildCapacityDemandSelectorQuery("premium-ssd-v2");

  assert.match(current, /\| take 251$/);
  assert.match(selectors, /\| take 501$/);
  assert.match(heatmap, /\| take 501$/);
  assert.match(demand, /\| take 501$/);
  for (const dimension of ["ConsumedUnit", "x_SkuMeterCategory", "x_SkuMeterSubcategory", "SkuMeter", "SkuPriceId", "BillingCurrency"]) {
    assert.ok(demand.includes(dimension));
  }
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
    assert.equal(payload.schema.costs.available, true);
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
  assert.equal(quotaPayload.schema.costs.available, true);
  assert.equal(quotaPayload.capability.mode, "disabled");
  assert.equal(quotaPayload.history.status, "disabled");
  assert.equal(quotaPayload.demand.capability.mode, "parallel");

  const missingCost = await startCapacityServer(t, {
    costFields: COST_SCHEMA_FIELDS.filter((field) => field !== "BillingCurrency"),
  });
  const costPayload = await kusto.getCapacity(missingCost, "Hub", "compute");
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

test("capacity markup retains module loading, tab semantics, and visible text states", async () => {
  const [html, source, css] = await Promise.all([
    readFile(new URL("../public/index.html", import.meta.url), "utf8"),
    readFile(new URL("../public/app.js", import.meta.url), "utf8"),
    readFile(new URL("../public/app.css", import.meta.url), "utf8"),
  ]);
  assert.match(html, /data-tab="capacity"/);
  assert.match(html, /<script type="module" src="\/app\.js"><\/script>/);
  assert.match(source, /role="tablist"/);
  assert.match(source, /aria-selected=/);
  assert.match(source, /Every colored cell includes the same value and state in text/);
  assert.match(css, /\*:focus-visible/);
  assert.match(css, /\.capacity-table-scroll\s*\{[^}]*overflow-x:\s*auto/s);
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
    canvasState: { tab: "overview", preset: "all", filters: {}, revision: 0 },
  };
  await assert.rejects(() => extension.changeConnection(entry, {
    clusterUri: "https://cluster.westus.kusto.windows.net",
    database: "Hub",
  }, {
    runQueryFn: async () => { throw new Error("probe failed"); },
    persistConfig: async () => assert.fail("must not persist after a failed probe"),
  }));
  assert.equal(entry.clusterUri, "http://localhost:8082");

  await assert.rejects(() => extension.changeConnection(entry, {
    clusterUri: "https://cluster.westus.kusto.windows.net",
    database: "Hub",
  }, {
    runQueryFn: async () => [],
    persistConfig: async () => { throw new Error("disk failed"); },
  }));
  assert.equal(entry.clusterUri, "http://localhost:8082");
  assert.equal(entry.canvasState.revision, 0);
});

test("canvas definition exposes collaborative actions on the one shared database", async () => {
  const calls = [];
  const entry = {
    clusterUri: "http://localhost:8082",
    database: "SharedHub",
    canvasState: { tab: "overview", preset: "all", filters: {}, revision: 0 },
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
  assert.deepEqual(
    await canvas.actions.find((action) => action.name === "get_build_info").handler({ input: {} }),
    { buildId: "ftk-local-dashboard-capacity-v1", sourceScope: "project" }
  );
  const result = await canvas.actions.find((action) => action.name === "run_query").handler({ input: { kql: "print Value=1" } });
  assert.equal(calls[0].database, "SharedHub");
  assert.equal(result.rows.length, 500);
  assert.equal(result.truncated, true);
  assert.equal(result.rowLimit, 500);
});

test("estate Compute family view keeps regional quota at family grain and states joins explicitly", () => {
  const query = kusto.buildComputeFamilyQuery({});
  // Regional core quota must never be duplicated across zones.
  assert.match(query, /by Family, FamilyKey, Location/);
  assert.doesNotMatch(query, /by [^\n]*PhysicalZone[^\n]*,\s*CoresTotal/);
  // Repository rule: never a bare join.
  for (const join of query.match(/\|\s*join[^\n]*/g) || []) {
    assert.match(join, /kind=/, `join without explicit kind: ${join}`);
  }
  // Bounded output.
  assert.match(query, new RegExp(`take ${kusto.CAPACITY_LIMITS.familyCells + 1}`));
  // Zone sets are descriptive only and drop empty sentinels.
  assert.match(query, /where isnotempty\(PhysicalZone\)/);

  const filtered = kusto.buildComputeFamilyQuery({ SubAccountId: ["abc"], location: ["eastus"] });
  assert.match(filtered, /where SubscriptionId in~ \("abc"\)/);
  assert.match(filtered, /where Location in~ \("eastus"\)/);
  assert.doesNotMatch(filtered, /SubAccountId in~/);
});

test("Compute family cells classify supply and demand without fabricating headroom", () => {
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

  // Restriction only applies when every contributing subscription is restricted.
  const restricted = kusto.computeFamilyCell({ CoresUsed: 0, CoresTotal: 0, Subscriptions: 2, RestrictedSubscriptions: 2 });
  assert.equal(restricted.state, "restricted");
  assert.equal(restricted.regionRestricted, true);
  const partial = kusto.computeFamilyCell({ CoresUsed: 0, CoresTotal: 0, Subscriptions: 2, RestrictedSubscriptions: 1 });
  assert.equal(partial.regionRestricted, false);

  // A restriction never invents headroom on a family that still holds quota.
  const restrictedWithQuota = kusto.computeFamilyCell({ CoresUsed: 5, CoresTotal: 50, Subscriptions: 1, RestrictedSubscriptions: 1 });
  assert.equal(restrictedWithQuota.state, "restricted");
  assert.equal(restrictedWithQuota.regionRestricted, true);
  assert.equal(restrictedWithQuota.text, "10.0%", "demand is still reported, it just does not drive the bar");

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

test("family rows stay lean and keep the region restriction visible alongside real quota", () => {
  const [withQuota] = kusto.annotateComputeFamilyRows([{
    Family: "Standard Dv5 Family vCPUs", FamilyKey: "standardDv5Family", Location: "eastus",
    CoresUsed: 10, CoresTotal: 100, Subscriptions: 1, RestrictedSubscriptions: 1,
    ZonesPresent: ["eastus-az1", "eastus-az2"], ZonesRestricted: ["eastus-az2"],
    x_IngestionTime: "2026-08-24T00:00:00Z",
  }]);
  // Zone name arrays are not shipped wholesale; only the count survives.
  assert.equal(withQuota.ZonesPresentCount, 2);
  assert.equal(withQuota.ZonesPresent, undefined);
  assert.deepEqual(withQuota.ZonesRestricted, ["eastus-az2"]);
  // Real quota keeps its own demand reading, and the restriction now drives the state.
  assert.equal(withQuota.semantic.state, "restricted");
  assert.equal(withQuota.semantic.supply, "blocked");
  assert.equal(withQuota.semantic.text, "10.0%");
  assert.equal(withQuota.semantic.regionRestricted, true);
  assert.equal(withQuota.semantic.headroomCores, 90);
});

test("family matrix filters reduce a lookup-scale grid without stranding the operator", () => {
  const rows = [
    { Family: "Standard Dv5 Family vCPUs", FamilyKey: "dv5", Location: "eastus", CoresUsed: 10, CoresTotal: 100, semantic: {} },
    { Family: "Standard Ev5 Family vCPUs", FamilyKey: "ev5", Location: "westus", CoresUsed: 0, CoresTotal: 200, semantic: {} },
    { Family: "Standard NC Family vCPUs", FamilyKey: "nc", Location: "eastus", CoresUsed: 0, CoresTotal: 0, semantic: { regionRestricted: true } },
    { Family: "Standard Fsv2 Family vCPUs", FamilyKey: "fsv2", Location: "westus", CoresUsed: 0, CoresTotal: 50, ZonesRestricted: ["westus-az1"], semantic: {} },
  ];
  const ids = (filter) => app.filterFamilyRows(rows, filter).map((row) => row.FamilyKey);

  // The default lens answers "what do we actually run", not "show me everything".
  assert.deepEqual(ids({ status: "in-use" }), ["dv5"]);
  // A region restriction and a zone restriction are both supply constraints.
  assert.deepEqual(ids({ status: "restricted" }), ["nc", "fsv2"]);
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
  assert.deepEqual(app.FAMILY_STATUS_FILTERS.map((lens) => lens.id), ["in-use", "restricted", "no-quota", "all"]);
});

test("family matrix keeps both scrollbars and its frozen panes reachable", async () => {
  const [css, js] = await Promise.all([
    readFile(new URL("../public/app.css", import.meta.url), "utf8"),
    readFile(new URL("../public/app.js", import.meta.url), "utf8"),
  ]);
  const matrix = css.slice(css.indexOf(".capacity-matrix {"));

  // A bounded viewport is what keeps the horizontal bar on screen; without the
  // height cap the table outgrows the window and the bar sits below the fold.
  assert.match(matrix, /max-height:\s*min\(70vh/);
  assert.match(matrix, /overflow:\s*auto/);
  // macOS overlay scrollbars fade when idle, so they are drawn permanently.
  assert.match(matrix, /::-webkit-scrollbar-thumb/);
  assert.match(matrix, /scrollbar-color:/);

  // Frozen panes on both axes: region header, family column, and the corner.
  assert.match(css, /\.capacity-heatmap--family thead th\s*\{[^}]*position:\s*sticky[^}]*top:\s*0/s);
  assert.match(css, /\.capacity-heatmap--family tbody th:first-child\s*\{[^}]*position:\s*sticky[^}]*left:\s*0/s);
  assert.match(css, /\.capacity-heatmap--family thead th:first-child\s*\{[^}]*z-index:\s*3/s);

  // The scroll region is keyboard reachable and named for assistive tech.
  assert.match(js, /class="capacity-matrix" tabindex="0" role="region" aria-label="[^"]+"/);
  // Filter controls carry state in markup, not colour alone.
  assert.match(js, /role="radiogroup"/);
  assert.match(js, /aria-checked="\$\{filter\.status === lens\.id/);
  assert.match(js, /aria-pressed="\$\{filter\.regions\.includes\(region\)/);
  // The count summary tells the operator how much of the grid is hidden.
  assert.match(js, /capacity-filter-summary" role="status"/);
});

test("a restricted region never reads as healthy headroom", () => {
  // The defect this guards: supply used to inherit the utilization state, so a
  // region nobody can deploy into rendered green whenever quota sat untouched.
  const blocked = kusto.computeFamilyCell({
    CoresTotal: 1000, CoresUsed: 30, Subscriptions: 2, RestrictedSubscriptions: 2,
  });
  assert.equal(blocked.supply, "blocked");
  assert.equal(blocked.state, "restricted");
  assert.notEqual(blocked.state, "healthy");
  assert.equal(blocked.text, "3.0%", "demand is still reported, it is just not the bar");
  assert.equal(blocked.regionRestricted, true);

  const partial = kusto.computeFamilyCell({
    CoresTotal: 1000, CoresUsed: 30, Subscriptions: 2, RestrictedSubscriptions: 0,
    ZonesPresent: ["1", "2", "3"], ZonesRestricted: ["1"],
  });
  assert.equal(partial.supply, "partial", "some zones restricted is a real but partial constraint");
  assert.equal(partial.state, "healthy", "partial supply does not overwrite demand");

  // Every zone restricted is not partial. Regional placement may still work, so it
  // stays distinct from a region restriction, but it must never read as healthy.
  const allZones = kusto.computeFamilyCell({
    CoresTotal: 1000, CoresUsed: 30, Subscriptions: 2, RestrictedSubscriptions: 0,
    ZonesPresent: ["1", "2"], ZonesRestricted: ["1", "2"],
  });
  assert.equal(allZones.supply, "blocked");
  assert.equal(allZones.state, "zone-restricted");
  assert.notEqual(allZones.state, "healthy");
  assert.equal(allZones.regionRestricted, false, "a zone block is not a region block");
  assert.equal(allZones.text, "3.0%");

  const open = kusto.computeFamilyCell({
    CoresTotal: 1000, CoresUsed: 950, Subscriptions: 2, RestrictedSubscriptions: 0,
  });
  assert.equal(open.supply, "open");
  assert.equal(open.state, "action", "open supply still escalates on demand");

  const none = kusto.computeFamilyCell({ CoresTotal: 0, CoresUsed: 0, Subscriptions: 1, RestrictedSubscriptions: 0 });
  assert.equal(none.supply, "none");
  assert.equal(none.state, "no-entitlement");
});

test("the high-water mark moves the demand alarm without losing the exhausted case", () => {
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

test("supply and demand stay separate channels in the rendered matrix", async () => {
  const css = await readFile(new URL("../public/app.css", import.meta.url), "utf8");
  const js = await readFile(new URL("../public/app.js", import.meta.url), "utf8");

  // Supply owns the bar, demand owns the number. Neither may borrow the other's channel.
  for (const supply of ["open", "partial", "blocked", "none"]) {
    assert.match(css, new RegExp(`\\.capacity-supply--${supply}\\b`), `${supply} needs a bar`);
  }
  assert.match(css, /\.capacity-supply--blocked\s*\{[^}]*inset 3px 0 0 var\(--neg\)/s);
  assert.doesNotMatch(
    css,
    /capacity-heatmap--family[^\n]*capacity-state--healthy[^\n]*border-right-color/,
    "utilization must not colour the supply bar again",
  );
  assert.match(css, /\.capacity-demand--over strong\s*\{[^}]*var\(--neg-ink\)/s);
  assert.match(css, /--neg-ink:\s*color-mix/, "alert text needs an AA-safe token, not raw --neg");

  // Colour is never the only channel: crossing the mark is also stated in words.
  assert.match(js, /Over \$\{mark\}% mark/);
  assert.match(js, /Quota exhausted/);
  assert.match(js, /capacity-supply--\$\{esc\(semantic\.supply/);
  assert.match(js, /capacity-demand--\$\{esc\(tier\)\}/);
  assert.match(js, /data-family-mark=/, "the mark must be the operator's to set");
});
