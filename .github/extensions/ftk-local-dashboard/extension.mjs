// Extension: ftk-local-dashboard
// A FinOps dashboard canvas for local and remote FinOps hubs.
//
// open() boots a per-instance loopback HTTP server that serves the static
// dashboard (public/) and JSON endpoints for configuration, shared canvas
// state, dashboard views, and read-only KQL.
// The dashboard renderer fetches /api/dashboard, which runs the FinOps query
// layer (kusto.mjs) against the selected Hub database.

import { createServer } from "node:http";
import { readFile, mkdir, rename, rm, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import {
  runQuery,
  getDashboard,
  getTokenomics,
  getAllocation,
  getRate,
  getUsage,
  getAnomaly,
  getCapacity,
  normalizeConnection,
  normalizeCapacityClassId,
  validateFilters,
  ALLOWED_FILTER_COLUMNS,
  CAPACITY_CLASS_REGISTRY,
} from "./kusto.mjs";

const TEST_MODE = process.env.FTK_LOCAL_DASHBOARD_TEST === "1";
let joinSession, createCanvas, CanvasError;
if (TEST_MODE) {
  createCanvas = (definition) => definition;
  CanvasError = class extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  };
} else {
  ({ joinSession, createCanvas, CanvasError } = await import("@github/copilot-sdk/extension"));
}

const GETTERS = {
  overview: getDashboard,
  tokenomics: getTokenomics,
  allocation: getAllocation,
  rate: getRate,
  usage: getUsage,
  anomaly: getAnomaly,
  capacity: getCapacity,
};

const PUBLIC_DIR = new URL("./public/", import.meta.url);
const HARDCODED_CLUSTER = "http://localhost:8082";
const HARDCODED_DB = "Hub";
const VALID_PRESETS = ["all", "12m", "6m", "3m"];
const DASHBOARD_TABS = Object.keys(GETTERS);
const VALID_TABS = [...DASHBOARD_TABS, "monaco"];
const QUERY_MAX_LENGTH = 65536;
const QUERY_ROW_LIMIT = 500;
const REQUEST_BODY_LIMIT = 128 * 1024;
const BUILD_ID = "ftk-local-dashboard-capacity-v1";
const SOURCE_SCOPE = import.meta.url.includes("/.github/extensions/") ? "project" : "user";

// Use stable, scope-specific ports so the project source can run beside an
// installed user copy without falling back to a changing ephemeral URL.
const DEFAULT_DASHBOARD_PORT = SOURCE_SCOPE === "project" ? 47822 : 47821;
const DASHBOARD_PORT = Number(process.env.FTK_LOCAL_DASHBOARD_PORT) || DEFAULT_DASHBOARD_PORT;

// Per-user preference file: the selected hub/database is a user choice, not a
// repo-wide constant, so it's remembered across sessions instead of hardcoded.
// See create-canvas skill's
// "State model" — per-user preference, not per-session/instance.
const CONFIG_DIR = join(process.env.COPILOT_HOME || join(homedir(), ".copilot"), "extensions", "ftk-local-dashboard", "artifacts");
const CONFIG_FILE = join(CONFIG_DIR, "config.json");

async function loadPersistedConfig() {
  try {
    const raw = await readFile(CONFIG_FILE, "utf8");
    const parsed = JSON.parse(raw);
    return {
      clusterUri: typeof parsed.clusterUri === "string" ? parsed.clusterUri : undefined,
      database: typeof parsed.database === "string" ? parsed.database : undefined,
      lastQuery: typeof parsed.lastQuery === "string" ? parsed.lastQuery : undefined,
    };
  } catch {
    return {};
  }
}

// Merges `patch` onto whatever is currently on disk instead of overwriting the
// whole file, so saving the query editor's text can't clobber the persisted
// clusterUri/database (and vice versa) -- the two are updated independently
// and on different cadences (query text on every edit; connection on Settings
// dialog submit). Writes are serialized onto a single chained promise: two
// concurrent callers (e.g. a Settings-dialog POST landing while the query
// editor's debounced autosave is also writing) both read-modify-write the
// same file, and without serialization the second writer's stale read can
// silently discard the first writer's change. Chaining forces each write to
// see the previous one's result.
let configWriteChain = Promise.resolve();

async function savePersistedConfig(patch) {
  configWriteChain = configWriteChain.catch(() => {}).then(async () => {
    await mkdir(CONFIG_DIR, { recursive: true });
    const current = await loadPersistedConfig();
    const tempFile = `${CONFIG_FILE}.${process.pid}.tmp`;
    try {
      await writeFile(tempFile, JSON.stringify({ ...current, ...patch }, null, 2));
      await rename(tempFile, CONFIG_FILE);
    } catch (err) {
      await rm(tempFile, { force: true }).catch(() => {});
      throw err;
    }
  });
  return configWriteChain;
}

const persisted = TEST_MODE ? {} : await loadPersistedConfig();

// Resolution order: remembered last choice (highest, once anything has ever
// been persisted) > explicit `open` input > FTK_LOCAL_CLUSTER_URI/
// FTK_LOCAL_DATABASE env vars > hardcoded fallback.
//
// This used to put `open` input first, on the theory that a later open()
// call carrying input meant "the Settings dialog reopened this canvas with
// a new connection." That's wrong: the SDK's actual open() wire type
// (CanvasProviderOpenRequest, generated/rpc.d.ts) carries no `reason` field,
// so extension code cannot tell a genuine user-driven reopen apart from the
// host silently replaying the *original, creation-time* input on one of its
// frequent restart-driven rehydrates (see DASHBOARD_PORT comment above).
// Once a real connection has ever been persisted via POST /api/config (the
// only channel the Settings dialog actually uses -- see public/app.js), it
// must always win, or every host restart silently reverts the user's
// deliberate choice back to whatever input the panel first opened with.
const DEFAULT_CLUSTER = persisted.clusterUri || process.env.FTK_LOCAL_CLUSTER_URI || HARDCODED_CLUSTER;
const DEFAULT_DB = persisted.database || process.env.FTK_LOCAL_DATABASE || HARDCODED_DB;
const DEFAULT_QUERY = "Costs\n| take 20";

const STATIC = {
  "/": ["index.html", "text/html; charset=utf-8"],
  "/index.html": ["index.html", "text/html; charset=utf-8"],
  "/app.css": ["app.css", "text/css; charset=utf-8"],
  "/app.js": ["app.js", "application/javascript; charset=utf-8"],
};

// This canvas has no legitimate multi-instance use case -- it's one live
// dashboard onto one Kusto emulator. Per-instance servers (keyed by
// caller-supplied instanceId) meant any duplicate panel -- whether from the
// host reopening under a new id, or an agent mistakenly inventing one --
// spun up its own ephemeral port with independently diverging state
// (connection settings, in-progress query text). A singleton removes the
// possibility entirely: every open(), regardless of instanceId, resolves to
// the same server/port/state, so duplicate panels can never diverge.
let singleton = null; // { server, url, clusterUri, database, lastQuery, canvasState, openInstances: Set<string> }

async function getOrCreateSingleton(clusterUri, database) {
  if (!singleton) {
    const connection = normalizeConnection(clusterUri, database);
    singleton = {
      clusterUri: connection.clusterUri,
      database: connection.database,
      lastQuery: persisted.lastQuery ?? DEFAULT_QUERY,
      canvasState: {
        tab: "overview",
        preset: "all",
        filters: {},
        capacityClass: "home",
        capacitySelections: {},
        revision: Date.now(),
      },
      openInstances: new Set(),
    };
    await startServer(singleton);
  }
  return singleton;
}

/** Parse and validate `?filters=<JSON>` from a URL search params. */
function parseFilters(url) {
  const raw = url.searchParams.get("filters");
  if (!raw) return {};
  try {
    return validateFilters(JSON.parse(raw));
  } catch (err) {
    throw new Error(`Invalid filters: ${err.message}`);
  }
}

function connectionInfo(entry) {
  const normalized = normalizeConnection(entry.clusterUri, entry.database);
  return {
    clusterUri: normalized.clusterUri,
    database: normalized.database,
    mode: normalized.mode,
    authentication: normalized.authentication,
  };
}

export function getBuildInfo() {
  return { buildId: BUILD_ID, sourceScope: SOURCE_SCOPE };
}

const CAPACITY_SELECTION_FIELDS = Object.freeze({
  quotaSelection: new Set(["subAccountId", "location", "resourceName", "unit", "sourceVersion", "resourceId"]),
  metricSelection: new Set(["resourceName", "unit", "sourceVersion"]),
  demandSelection: new Set([
    "meterCategory",
    "meterSubcategory",
    "meter",
    "priceId",
    "unit",
    "currency",
    "resourceId",
    "capacityReservationId",
    "capacityReservationStatus",
  ]),
});

export function validateCapacitySelections(input = {}) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new Error("Capacity selections must be an object.");
  }
  const normalized = {};
  for (const [selectionName, selection] of Object.entries(input)) {
    const allowedFields = CAPACITY_SELECTION_FIELDS[selectionName];
    if (!allowedFields) throw new Error(`Unsupported capacity selection '${selectionName}'.`);
    if (!selection || typeof selection !== "object" || Array.isArray(selection)) {
      throw new Error(`Capacity selection '${selectionName}' must be an object.`);
    }
    const clean = {};
    for (const [field, value] of Object.entries(selection)) {
      if (!allowedFields.has(field)) throw new Error(`Unsupported ${selectionName} field '${field}'.`);
      if (typeof value !== "string" || !value.trim() || value.length > 512 || /[\u0000-\u001f\u007f]/.test(value)) {
        throw new Error(`${selectionName}.${field} must be 1-512 printable characters.`);
      }
      clean[field] = value.trim();
    }
    normalized[selectionName] = clean;
  }
  return normalized;
}

export function validateCanvasStatePatch(input = {}) {
  if (!input || typeof input !== "object" || Array.isArray(input)) throw new Error("Canvas state must be an object.");
  const allowed = new Set(["tab", "preset", "filters", "capacityClass", "capacitySelections", "expectedRevision"]);
  for (const key of Object.keys(input)) {
    if (!allowed.has(key)) throw new Error(`Unsupported canvas state property '${key}'.`);
  }
  const patch = {};
  if ("tab" in input) {
    if (!VALID_TABS.includes(input.tab)) throw new Error(`Unknown canvas tab '${input.tab}'.`);
    patch.tab = input.tab;
  }
  if ("preset" in input) {
    if (!VALID_PRESETS.includes(input.preset)) throw new Error(`Unknown time preset '${input.preset}'.`);
    patch.preset = input.preset;
  }
  if ("filters" in input) patch.filters = validateFilters(input.filters);
  if ("capacityClass" in input) patch.capacityClass = normalizeCapacityClassId(input.capacityClass);
  if ("capacitySelections" in input) patch.capacitySelections = validateCapacitySelections(input.capacitySelections);
  if ("expectedRevision" in input && (!Number.isInteger(input.expectedRevision) || input.expectedRevision < 0)) {
    throw new Error("expectedRevision must be a non-negative integer.");
  }
  return { patch, expectedRevision: input.expectedRevision };
}

export function updateCanvasState(current, input = {}) {
  const { patch, expectedRevision } = validateCanvasStatePatch(input);
  if (expectedRevision !== undefined && expectedRevision !== current.revision) {
    const err = new Error("Canvas state changed before this update.");
    err.code = "revision_conflict";
    err.state = current;
    throw err;
  }
  return { ...current, ...patch, revision: current.revision + 1 };
}

function queryStructure(kql) {
  let output = "";
  let state = "code";
  for (let i = 0; i < kql.length; i++) {
    const char = kql[i], next = kql[i + 1];
    if (state === "line") {
      if (char === "\n") { state = "code"; output += "\n"; } else output += " ";
    } else if (state === "block") {
      if (char === "*" && next === "/") { output += "  "; i++; state = "code"; }
      else output += char === "\n" ? "\n" : " ";
    } else if (state === "single" || state === "double") {
      const quote = state === "single" ? "'" : '"';
      if (char === "\\") { output += "  "; i++; }
      else if (char === quote) { output += " "; state = "code"; }
      else output += char === "\n" ? "\n" : " ";
    } else if (char === "/" && next === "/") {
      output += "  "; i++; state = "line";
    } else if (char === "/" && next === "*") {
      output += "  "; i++; state = "block";
    } else if (char === "'" || char === '"') {
      output += " "; state = char === "'" ? "single" : "double";
    } else {
      output += char;
    }
  }
  return output;
}

export function validateReadOnlyQuery(kql) {
  if (typeof kql !== "string" || !kql.trim()) throw new Error("KQL is required.");
  if (kql.length > QUERY_MAX_LENGTH) throw new Error(`KQL must be at most ${QUERY_MAX_LENGTH} characters.`);
  const structure = queryStructure(kql);
  for (const match of structure.matchAll(/(?:^|[;\n])\s*\.(\w+)/gim)) {
    if (match[1].toLowerCase() !== "show") throw new Error(`Management command '.${match[1]}' is not allowed.`);
  }
  return kql.trim();
}

async function readJsonBody(req) {
  let body = "";
  for await (const chunk of req) {
    body += chunk;
    if (Buffer.byteLength(body) > REQUEST_BODY_LIMIT) throw new Error("Request body is too large.");
  }
  try {
    return JSON.parse(body || "{}");
  } catch {
    throw new Error("Invalid JSON.");
  }
}

export async function changeConnection(entry, input, dependencies = {}) {
  const query = dependencies.runQueryFn || runQuery;
  const persist = dependencies.persistConfig || savePersistedConfig;
  const next = normalizeConnection(input?.clusterUri, input?.database || "Hub");
  await query(next.clusterUri, next.database, "Costs() | take 0");
  await persist({ clusterUri: next.clusterUri, database: next.database });
  entry.clusterUri = next.clusterUri;
  entry.database = next.database;
  entry.canvasState = { ...entry.canvasState, revision: entry.canvasState.revision + 1 };
  return connectionInfo(entry);
}

export function validateLoopbackRequest(entry, req, path) {
  if (!entry.url) return { status: 503, error: "Dashboard server is starting." };
  const expected = new URL(entry.url);
  const host = String(req.headers.host || "").toLowerCase();
  if (host !== expected.host.toLowerCase()) {
    return { status: 403, error: "Request host is not allowed." };
  }
  const origin = req.headers.origin;
  if (origin && origin !== expected.origin) {
    return { status: 403, error: "Request origin is not allowed." };
  }
  if (req.headers["sec-fetch-site"] === "cross-site") {
    return { status: 403, error: "Cross-site requests are not allowed." };
  }
  if (path.startsWith("/api/") && req.method === "POST") {
    const contentType = String(req.headers["content-type"] || "");
    if (!/^application\/json(?:\s*;|$)/i.test(contentType)) {
      return { status: 415, error: "POST requests require application/json." };
    }
  }
  return null;
}

export function validateViewInput(input = {}) {
  const name = input.name || "overview";
  const preset = input.preset || "all";
  if (!DASHBOARD_TABS.includes(name)) throw new Error(`Unknown view '${name}'.`);
  if (!VALID_PRESETS.includes(preset)) throw new Error(`Unknown time preset '${preset}'.`);
  const capacityClass = normalizeCapacityClassId(input.capacityClass || "home");
  const capacitySelections = validateCapacitySelections(input.capacitySelections || {});
  return { name, preset, filters: validateFilters(input.filters || {}), capacityClass, capacitySelections };
}

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" });
  res.end(body);
}

function logError(context, err) {
  console.error("[ftk-local-dashboard]", context, err);
}

function sendQueryError(res, entry, viewName, err) {
  logError(`Could not query ${viewName} for ${entry.clusterUri}/${entry.database}`, err);
  sendJson(res, 200, {
    error: err?.message || "Could not query the FinOps hub. Check the extension logs for details.",
    clusterUri: entry.clusterUri,
    database: entry.database,
  });
}

async function handleRequest(entry, req, res) {
  const url = new URL(req.url, "http://127.0.0.1");
  const path = url.pathname;
  const policyError = validateLoopbackRequest(entry, req, path);
  if (policyError) {
    sendJson(res, policyError.status, { error: policyError.error });
    return;
  }

  if (STATIC[path]) {
    const [file, type] = STATIC[path];
    try {
      const buf = await readFile(new URL(file, PUBLIC_DIR));
      res.writeHead(200, { "Content-Type": type, "Cache-Control": "no-store" });
      res.end(buf);
    } catch (err) {
      logError(`Could not serve asset ${file}`, err);
      res.writeHead(500, { "Content-Type": "text/plain" });
      res.end("Asset error");
    }
    return;
  }

  if (path === "/api/config" && req.method === "GET") {
    sendJson(res, 200, {
      ...connectionInfo(entry),
      lastQuery: entry.lastQuery ?? DEFAULT_QUERY,
    });
    return;
  }

  // Probe and persist a new connection before changing the live singleton.
  if (path === "/api/config" && req.method === "POST") {
    try {
      const body = await readJsonBody(req);
      const connection = await changeConnection(entry, body);
      sendJson(res, 200, connection);
    } catch (err) {
      logError("Could not change FinOps hub connection", err);
      sendJson(res, 400, { error: err.message || "Could not change connection." });
    }
    return;
  }

  // The query editor tab autosaves its text here (debounced) so that a page
  // reload -- whether from a manual refresh or the host restarting this
  // extension process (the URL itself is now fixed and survives restarts,
  // but the server process, and any unpersisted in-memory state, does not)
  // -- never silently discards an in-progress, unrun query.
  if (path === "/api/query-state" && req.method === "POST") {
    let query;
    try { ({ query } = await readJsonBody(req)); } catch (err) { sendJson(res, 400, { error: err.message }); return; }
    if (typeof query !== "string") { sendJson(res, 400, { error: "query must be a string" }); return; }
    entry.lastQuery = query;
    try {
      await savePersistedConfig({ lastQuery: query });
      sendJson(res, 200, { ok: true });
    } catch (err) {
      logError("Could not persist query text", err);
      sendJson(res, 200, { ok: false });
    }
    return;
  }

  if (path === "/api/session-state" && req.method === "GET") {
    sendJson(res, 200, entry.canvasState);
    return;
  }

  if (path === "/api/session-state" && req.method === "POST") {
    try {
      entry.canvasState = updateCanvasState(entry.canvasState, await readJsonBody(req));
      sendJson(res, 200, entry.canvasState);
    } catch (err) {
      if (err.code === "revision_conflict") {
        sendJson(res, 409, { error: err.code, state: err.state });
      } else {
        sendJson(res, 400, { error: err.message || "Invalid canvas state." });
      }
    }
    return;
  }

  if (path === "/api/config") {
    res.writeHead(405, { "Content-Type": "text/plain" });
    res.end("Method not allowed");
    return;
  }

  // Database schema for the experimental Monaco KQL tab's autocomplete
  // (monaco-kusto's worker.setSchemaFromShowSchema expects the parsed
  // `.show schema as json` object, not generic query rows).
  if (path === "/api/schema") {
    try {
      const rows = await runQuery(entry.clusterUri, entry.database, ".show schema as json");
      const cell = rows[0] ? Object.values(rows[0])[0] : null;
      const schema = typeof cell === "string" ? JSON.parse(cell) : cell;
      sendJson(res, 200, { schema, clusterUri: entry.clusterUri, database: entry.database });
    } catch (err) {
      sendQueryError(res, entry, "schema", err);
    }
    return;
  }

  if (path === "/api/dashboard") {
    try {
      const preset = url.searchParams.get("preset") || "all";
      if (!VALID_PRESETS.includes(preset)) throw new Error(`Unknown time preset '${preset}'.`);
      const filters = parseFilters(url);
      const payload = await getDashboard(entry.clusterUri, entry.database, preset, filters);
      sendJson(res, 200, payload);
    } catch (err) {
      sendQueryError(res, entry, "overview", err);
    }
    return;
  }

  if (path === "/api/tokenomics") {
    try {
      const preset = url.searchParams.get("preset") || "all";
      if (!VALID_PRESETS.includes(preset)) throw new Error(`Unknown time preset '${preset}'.`);
      const filters = parseFilters(url);
      const payload = await getTokenomics(entry.clusterUri, entry.database, preset, filters);
      sendJson(res, 200, payload);
    } catch (err) {
      sendQueryError(res, entry, "tokenomics", err);
    }
    return;
  }

  if (path === "/api/view" && (req.method === "GET" || req.method === "POST")) {
    try {
      const input = req.method === "POST"
        ? await readJsonBody(req)
        : {
          name: url.searchParams.get("name") || "overview",
          preset: url.searchParams.get("preset") || "all",
          filters: parseFilters(url),
        };
      const { name, preset, filters, capacityClass, capacitySelections } = validateViewInput(input);
      const getter = GETTERS[name];
      const payload = name === "capacity"
        ? await getter(entry.clusterUri, entry.database, capacityClass, capacitySelections)
        : await getter(entry.clusterUri, entry.database, preset, filters);
      sendJson(res, 200, payload);
    } catch (err) {
      sendQueryError(res, entry, "view", err);
    }
    return;
  }

  if (path === "/api/kql" && req.method === "POST") {
    try {
      const body = await readJsonBody(req);
      if ("database" in body) throw new Error("Change databases through connection settings.");
      const kql = validateReadOnlyQuery(body.kql);
      entry.lastQuery = kql;
      void savePersistedConfig({ lastQuery: kql }).catch((err) => logError("Could not persist query text", err));
      const rows = await runQuery(entry.clusterUri, entry.database, kql);
      sendJson(res, 200, {
        rows: rows.slice(0, QUERY_ROW_LIMIT),
        truncated: rows.length > QUERY_ROW_LIMIT,
        rowLimit: QUERY_ROW_LIMIT,
      });
    } catch (err) {
      logError("Custom KQL error", err);
      sendJson(res, 200, { error: err.message || "Query failed" });
    }
    return;
  }

  res.writeHead(404, { "Content-Type": "text/plain" });
  res.end("Not found");
}

// Binds to DASHBOARD_PORT so the canvas URL survives host-triggered extension
// restarts. A restarted process's predecessor has already exited by the time
// this runs (the OS reclaims a LISTEN socket's port immediately on process
// exit), so this normally succeeds on the first try; the short retries only
// guard against the rare case of two processes briefly overlapping during
// teardown. Falls back to an OS-assigned ephemeral port as a last resort so
// the dashboard still works (with a non-stable URL) if the fixed port is
// genuinely held by something else.
async function bindServer(server) {
  const maxAttempts = 5;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await new Promise((resolve, reject) => {
        const onError = (err) => reject(err);
        server.once("error", onError);
        server.listen(DASHBOARD_PORT, "127.0.0.1", () => {
          server.removeListener("error", onError);
          resolve();
        });
      });
      return;
    } catch (err) {
      if (err.code !== "EADDRINUSE") throw err;
      if (attempt === maxAttempts) {
        logError(`Fixed port ${DASHBOARD_PORT} unavailable after ${maxAttempts} attempts, falling back to an ephemeral port`, err);
        await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
        return;
      }
      await new Promise((r) => setTimeout(r, 150));
    }
  }
}

async function startServer(entry) {
  const server = createServer((req, res) => {
    handleRequest(entry, req, res).catch((err) => {
      logError("Unhandled dashboard request failure", err);
      if (res.headersSent) {
        res.destroy();
      } else {
        sendJson(res, 500, { error: "Unexpected dashboard server error" });
      }
    });
  });
  await bindServer(server);
  const addr = server.address();
  const port = typeof addr === "object" && addr ? addr.port : 0;
  entry.server = server;
  entry.url = `http://127.0.0.1:${port}/`;
  return entry;
}

// Compact headline KPIs for the agent-facing `summary` action.
function headline(payload) {
  if (payload.empty) return { empty: true, window: payload.window };
  const d = payload.data;
  const s = d.summary?.[0] || {};
  const list = s.List || 0, eff = s.Effective || 0, contracted = s.Contracted || 0;
  const tag = Object.fromEntries((d.tagged || []).map((r) => [r._t, r.Cost || 0]));
  const tagTotal = (tag.Tagged || 0) + (tag.Untagged || 0);
  const price = Object.fromEntries((d.pricing || []).map((r) => [r.PricingCategory, r.Cost || 0]));
  const priceTotal = Object.values(price).reduce((a, b) => a + b, 0);
  return {
    window: payload.window,
    effectiveCost: Math.round(eff * 100) / 100,
    billedCost: Math.round((s.Billed || 0) * 100) / 100,
    totalSavings: Math.round((list - eff) * 100) / 100,
    effectiveSavingsRate: list > 0 ? +((list - eff) / list).toFixed(4) : 0,
    negotiatedSavings: Math.round((list - contracted) * 100) / 100,
    commitmentSavings: Math.round((contracted - eff) * 100) / 100,
    untaggedPercent: tagTotal > 0 ? +((tag.Untagged || 0) / tagTotal).toFixed(4) : 0,
    commitmentCoverage: priceTotal > 0 ? +((price.Committed || 0) / priceTotal).toFixed(4) : 0,
    resources: s.Resources || 0,
    services: s.Services || 0,
    subscriptions: s.Subscriptions || 0,
    regions: s.Regions || 0,
    topServices: (d.topServices || []).slice(0, 5).map((r) => ({ name: r.ServiceName, cost: Math.round((r.Cost || 0) * 100) / 100 })),
    generatedAt: payload.generatedAt,
  };
}

// Compact headline token KPIs for the agent-facing `tokenomics` action.
function tokenHeadline(payload) {
  if (payload.empty) return { empty: true, window: payload.window };
  const d = payload.data;
  const s = d.summary?.[0] || {};
  const tokens = s.Tokens || 0, eff = s.Effective || 0;
  const cloud = d.totalCloud?.[0]?.Effective || 0;
  const dir = Object.fromEntries((d.direction || []).map((r) => [r.Direction, r]));
  const inTok = dir["Input"]?.Tokens || 0;
  const cachedTok = dir["Cached input"]?.Tokens || 0;
  return {
    window: payload.window,
    aiTokenCost: Math.round(eff * 100) / 100,
    totalTokens: tokens,
    blendedCostPerMillionTokens: tokens > 0 ? +((eff / tokens) * 1e6).toFixed(4) : 0,
    cachedInputShareOfInputTokens: inTok + cachedTok > 0 ? +(cachedTok / (inTok + cachedTok)).toFixed(4) : 0,
    aiShareOfCloudCost: cloud > 0 ? +(eff / cloud).toFixed(4) : 0,
    modelCount: s.Models || 0,
    directionMix: (d.direction || []).map((r) => ({ direction: r.Direction, tokens: r.Tokens, cost: Math.round((r.Cost || 0) * 100) / 100 })),
    topModels: (d.models || []).slice(0, 5).map((r) => ({
      model: r.Model, tokens: r.Tokens, cost: Math.round((r.Cost || 0) * 100) / 100,
      costPerMillionTokens: +((r.CostPer1K || 0) * 1000).toFixed(4),
    })),
    generatedAt: payload.generatedAt,
  };
}

const FILTER_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: Object.fromEntries(
    [...ALLOWED_FILTER_COLUMNS].map((name) => [name, {
      type: "array",
      maxItems: 8,
      items: { type: "string", minLength: 1, maxLength: 256 },
    }])
  ),
};

const SELECTION_VALUE_SCHEMA = { type: "string", minLength: 1, maxLength: 512 };
const CAPACITY_SELECTION_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: Object.fromEntries(
    Object.entries(CAPACITY_SELECTION_FIELDS).map(([name, fields]) => [name, {
      type: "object",
      additionalProperties: false,
      properties: Object.fromEntries([...fields].map((field) => [field, SELECTION_VALUE_SCHEMA])),
    }])
  ),
};

export function createDashboardCanvas(dependencies = {}) {
  const canvasFactory = dependencies.canvasFactory || createCanvas;
  const query = dependencies.runQueryFn || runQuery;
  const getters = dependencies.getters || GETTERS;
  const persist = dependencies.persistConfig || savePersistedConfig;
  const getEntry = dependencies.getEntry || (() => singleton);
  const requireEntry = () => {
    const entry = getEntry();
    if (!entry) throw new CanvasError("canvas_not_open", "Open the FinOps hub dashboard first.");
    return entry;
  };
  const queryFailure = (context, err) => {
    logError(context, err);
    throw new CanvasError("query_failed", err?.message || "Could not query the FinOps hub.");
  };

  return canvasFactory({
    id: "ftk-local-dashboard",
    displayName: "FinOps hub dashboard",
    description: "Live FinOps dashboard for local and remote hubs with cost, allocation, rate, usage, anomaly, AI tokenomics, and capacity views.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        clusterUri: { type: "string", description: `Local loopback or remote Kusto cluster origin. Seeds only the first run before a connection is persisted; defaults to ${HARDCODED_CLUSTER}.` },
        database: { type: "string", description: "Database name. Default Hub." },
      },
    },
    actions: [
      {
        name: "get_build_info",
        description: "Return the dashboard build identifier and project or user source scope.",
        inputSchema: { type: "object", additionalProperties: false },
        handler: async () => getBuildInfo(),
      },
      {
        name: "get_connection",
        description: "Return the shared FinOps hub connection and authentication mode without credentials.",
        inputSchema: { type: "object", additionalProperties: false },
        handler: async () => connectionInfo(requireEntry()),
      },
      {
        name: "set_connection",
        description: "Probe and switch the shared FinOps hub connection, then persist it for future sessions.",
        inputSchema: {
          type: "object",
          additionalProperties: false,
          required: ["clusterUri"],
          properties: {
            clusterUri: { type: "string" },
            database: { type: "string", default: "Hub" },
          },
        },
        handler: async (ctx) => {
          const entry = requireEntry();
          try {
            return await changeConnection(entry, ctx.input, { runQueryFn: query, persistConfig: persist });
          } catch (err) {
            logError("Could not change FinOps hub connection", err);
            throw new CanvasError("connection_failed", err.message || "Could not change connection.");
          }
        },
      },
      {
        name: "get_canvas_state",
        description: "Return the visible tab, Capacity class and selectors, time preset, filters, and state revision shared with the open canvas.",
        inputSchema: { type: "object", additionalProperties: false },
        handler: async () => ({ ...requireEntry().canvasState }),
      },
      {
        name: "set_canvas_state",
        description: "Change the visible tab, Capacity class or selectors, time preset, or filters with optional revision conflict detection.",
        inputSchema: {
          type: "object",
          additionalProperties: false,
          properties: {
            tab: { type: "string", enum: VALID_TABS },
            preset: { type: "string", enum: VALID_PRESETS },
            filters: FILTER_SCHEMA,
            capacityClass: { type: "string", enum: ["home", ...Object.keys(CAPACITY_CLASS_REGISTRY)] },
            capacitySelections: CAPACITY_SELECTION_SCHEMA,
            expectedRevision: { type: "integer", minimum: 0 },
          },
        },
        handler: async (ctx) => {
          const entry = requireEntry();
          try {
            entry.canvasState = updateCanvasState(entry.canvasState, ctx.input);
            return { ...entry.canvasState };
          } catch (err) {
            if (err.code === "revision_conflict") {
              throw new CanvasError("revision_conflict", `Canvas state is now at revision ${err.state.revision}.`);
            }
            throw new CanvasError("invalid_canvas_state", err.message);
          }
        },
      },
      {
        name: "get_view",
        description: "Run any dashboard view against the shared connection and return its structured payload.",
        inputSchema: {
          type: "object",
          additionalProperties: false,
          required: ["view"],
          properties: {
            view: { type: "string", enum: DASHBOARD_TABS },
            preset: { type: "string", enum: VALID_PRESETS, default: "all" },
            filters: FILTER_SCHEMA,
            capacityClass: { type: "string", enum: ["home", ...Object.keys(CAPACITY_CLASS_REGISTRY)], default: "home" },
            capacitySelections: CAPACITY_SELECTION_SCHEMA,
          },
        },
        handler: async (ctx) => {
          const entry = requireEntry();
          try {
            const input = validateViewInput({
              name: ctx.input?.view,
              preset: ctx.input?.preset,
              filters: ctx.input?.filters,
              capacityClass: ctx.input?.capacityClass,
              capacitySelections: ctx.input?.capacitySelections,
            });
            return input.name === "capacity"
              ? await getters[input.name](entry.clusterUri, entry.database, input.capacityClass, input.capacitySelections)
              : await getters[input.name](entry.clusterUri, entry.database, input.preset, input.filters);
          } catch (err) {
            return queryFailure(`Could not query ${ctx.input?.view}`, err);
          }
        },
      },
      {
        name: "run_query",
        description: "Run bounded read-only KQL against the shared connection and return up to 500 rows.",
        inputSchema: {
          type: "object",
          additionalProperties: false,
          required: ["kql"],
          properties: { kql: { type: "string", minLength: 1, maxLength: QUERY_MAX_LENGTH } },
        },
        handler: async (ctx) => {
          const entry = requireEntry();
          try {
            const kql = validateReadOnlyQuery(ctx.input?.kql);
            const rows = await query(entry.clusterUri, entry.database, kql);
            return { rows: rows.slice(0, QUERY_ROW_LIMIT), truncated: rows.length > QUERY_ROW_LIMIT, rowLimit: QUERY_ROW_LIMIT };
          } catch (err) {
            return queryFailure("Could not run custom KQL", err);
          }
        },
      },
      {
        name: "summary",
        description: "Return headline FinOps KPIs for a time window from the shared connection.",
        inputSchema: {
          type: "object",
          additionalProperties: false,
          properties: { preset: { type: "string", enum: VALID_PRESETS, description: "Time window. Default all." } },
        },
        handler: async (ctx) => {
          const entry = requireEntry();
          try {
            return headline(await getters.overview(entry.clusterUri, entry.database, ctx.input?.preset || "all"));
          } catch (err) {
            return queryFailure("Could not query summary", err);
          }
        },
      },
      {
        name: "tokenomics",
        description: "Return headline AI token-economics KPIs for a time window from the shared connection.",
        inputSchema: {
          type: "object",
          additionalProperties: false,
          properties: { preset: { type: "string", enum: VALID_PRESETS, description: "Time window. Default all." } },
        },
        handler: async (ctx) => {
          const entry = requireEntry();
          try {
            return tokenHeadline(await getters.tokenomics(entry.clusterUri, entry.database, ctx.input?.preset || "all"));
          } catch (err) {
            return queryFailure("Could not query tokenomics", err);
          }
        },
      },
    ],
    open: async (ctx) => {
      try {
        const clusterUri = persisted.clusterUri || ctx.input?.clusterUri || DEFAULT_CLUSTER;
        const database = persisted.database || ctx.input?.database || DEFAULT_DB;
        const entry = await getOrCreateSingleton(clusterUri, database);
        entry.openInstances.add(ctx.instanceId);
        const connection = connectionInfo(entry);
        return {
          title: "FinOps hub dashboard",
          url: entry.url,
          status: `${connection.mode} · ${entry.clusterUri} · ${entry.database}`,
        };
      } catch (err) {
        throw new CanvasError("invalid_connection", err.message || "Could not open the FinOps hub dashboard.");
      }
    },
    onClose: async (ctx) => {
      if (!singleton) return;
      singleton.openInstances.delete(ctx.instanceId);
    },
  });
}

if (!TEST_MODE) {
  await joinSession({ canvases: [createDashboardCanvas()] });
}
