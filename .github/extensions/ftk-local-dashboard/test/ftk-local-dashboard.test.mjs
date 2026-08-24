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
  assert.match(sqlNegative.evidenceLabel, /interpretation unverified/i);
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

test("capacity history gates activate only supported evidence", () => {
  assert.equal(kusto.resolveCapacityHistoryCapability(1).mode, "current-only");
  assert.equal(kusto.resolveCapacityHistoryCapability(2).mode, "observed-delta");
  assert.equal(kusto.resolveCapacityHistoryCapability(3).mode, "provisional-runway");
  assert.equal(kusto.resolveCapacityHistoryCapability(7).mode, "trend-runway");
  assert.equal(kusto.resolveCapacityHistoryCapability(7, { evidenceClass: "inventory" }).mode, "observed-history");
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
  // The horizontal-scroll rule is shared with the generic `.table-scroll`
  // wrapper, so match the grouped selector rather than a lone one.
  assert.match(css, /\.capacity-table-scroll,\s*\.table-scroll\s*\{[^}]*overflow-x:\s*auto/s);
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
