// Extension: ftk-local-dashboard
// A FinOps dashboard canvas for the local (ftklocal) Kusto emulator.
//
// open() boots a per-instance loopback HTTP server that serves the static
// dashboard (public/) and two JSON endpoints (/api/config, /api/dashboard).
// The dashboard renderer fetches /api/dashboard, which runs the FinOps query
// layer (kusto.mjs) against the emulator's Hub database.

import { createServer } from "node:http";
import { readFile, mkdir, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { joinSession, createCanvas, CanvasError } from "@github/copilot-sdk/extension";
import { runQuery, getDashboard, getTokenomics, getAllocation, getRate, getUsage, getAnomaly } from "./kusto.mjs";

const GETTERS = {
  overview: getDashboard,
  tokenomics: getTokenomics,
  allocation: getAllocation,
  rate: getRate,
  usage: getUsage,
  anomaly: getAnomaly,
};

const PUBLIC_DIR = new URL("./public/", import.meta.url);
const HARDCODED_CLUSTER = "http://localhost:8082";
const HARDCODED_DB = "Hub";

// Fixed loopback port for the dashboard's own HTTP server (distinct from the
// Kusto emulator's configurable clusterUri/port above). The CLI reloads every
// extension process whenever the foreground session changes (see the SDK's
// extensions.md: "Extensions are reloaded on `/clear` or if the foreground
// session is replaced") -- which happens routinely just from switching
// between chat/session tabs, not from any crash. Each restart used to call
// `server.listen(0, ...)` for a fresh OS-assigned ephemeral port, so the
// already-open canvas panel's iframe URL went stale on every single restart
// and never recovered until the panel was manually reopened. Binding to a
// fixed port instead means the URL never changes across restarts, so a
// panel can always be closed and reopened (or simply retried) successfully.
const DASHBOARD_PORT = Number(process.env.FTK_LOCAL_DASHBOARD_PORT) || 47821;

// Per-user preference file: the emulator's port/database is a local dev
// choice (docker `-p <port>:8080`), not a repo-wide constant, so it's
// remembered across sessions instead of hardcoded. See create-canvas skill's
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
    await writeFile(CONFIG_FILE, JSON.stringify({ ...current, ...patch }, null, 2));
  });
  try {
    await configWriteChain;
  } catch (err) {
    console.error("[ftk-local-dashboard]", "Could not persist config", err);
  }
}

const persisted = await loadPersistedConfig();

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
let singleton = null; // { server, url, clusterUri, database, lastQuery, openInstances: Set<string> }

async function getOrCreateSingleton(clusterUri, database) {
  if (!singleton) {
    singleton = {
      clusterUri,
      database,
      lastQuery: persisted.lastQuery ?? DEFAULT_QUERY,
      openInstances: new Set(),
    };
    await startServer(singleton);
  }
  return singleton;
}

/** Parse `?filters=<JSON>` from a URL search params; returns plain object (column->array). */
function parseFilters(url) {
  const raw = url.searchParams.get("filters");
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) return parsed;
  } catch { /* ignore malformed */ }
  return {};
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
    error: "Could not query the local FinOps hub. Check the extension logs for details.",
    clusterUri: entry.clusterUri,
    database: entry.database,
  });
}

async function handleRequest(entry, req, res) {
  const url = new URL(req.url, "http://127.0.0.1");
  const path = url.pathname;

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
      clusterUri: entry.clusterUri,
      database: entry.database,
      lastQuery: entry.lastQuery ?? DEFAULT_QUERY,
    });
    return;
  }

  // User-driven reconnect from the Settings dialog: update this instance's
  // live connection and remember it as the default for future opens.
  if (path === "/api/config" && req.method === "POST") {
    let body = "";
    for await (const chunk of req) body += chunk;
    let clusterUri, database;
    try { ({ clusterUri, database } = JSON.parse(body)); } catch { sendJson(res, 400, { error: "Invalid JSON" }); return; }
    clusterUri = typeof clusterUri === "string" ? clusterUri.trim() : "";
    database = typeof database === "string" && database.trim() ? database.trim() : "Hub";
    if (!clusterUri) { sendJson(res, 400, { error: "clusterUri is required" }); return; }
    entry.clusterUri = clusterUri;
    entry.database = database;
    await savePersistedConfig({ clusterUri, database });
    sendJson(res, 200, { clusterUri, database });
    return;
  }

  // The query editor tab autosaves its text here (debounced) so that a page
  // reload -- whether from a manual refresh or the host restarting this
  // extension process (the URL itself is now fixed and survives restarts,
  // but the server process, and any unpersisted in-memory state, does not)
  // -- never silently discards an in-progress, unrun query.
  if (path === "/api/query-state" && req.method === "POST") {
    let body = "";
    for await (const chunk of req) body += chunk;
    let query;
    try { ({ query } = JSON.parse(body)); } catch { sendJson(res, 400, { error: "Invalid JSON" }); return; }
    if (typeof query !== "string") { sendJson(res, 400, { error: "query must be a string" }); return; }
    entry.lastQuery = query;
    await savePersistedConfig({ lastQuery: query });
    sendJson(res, 200, { ok: true });
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
    const preset = url.searchParams.get("preset") || "all";
    const filters = parseFilters(url);
    try {
      const payload = await getDashboard(entry.clusterUri, entry.database, preset, filters);
      sendJson(res, 200, payload);
    } catch (err) {
      sendQueryError(res, entry, "overview", err);
    }
    return;
  }

  if (path === "/api/tokenomics") {
    const preset = url.searchParams.get("preset") || "all";
    const filters = parseFilters(url);
    try {
      const payload = await getTokenomics(entry.clusterUri, entry.database, preset, filters);
      sendJson(res, 200, payload);
    } catch (err) {
      sendQueryError(res, entry, "tokenomics", err);
    }
    return;
  }

  if (path === "/api/view") {
    const name = url.searchParams.get("name") || "overview";
    const preset = url.searchParams.get("preset") || "all";
    const filters = parseFilters(url);
    const getter = GETTERS[name];
    if (!getter) { sendJson(res, 200, { error: `Unknown view '${name}'` }); return; }
    try {
      const payload = await getter(entry.clusterUri, entry.database, preset, filters);
      sendJson(res, 200, payload);
    } catch (err) {
      sendQueryError(res, entry, name, err);
    }
    return;
  }

  if (path === "/api/kql" && req.method === "POST") {
    let body = "";
    for await (const chunk of req) body += chunk;
    let kql, database;
    try { ({ kql, database } = JSON.parse(body)); } catch { sendJson(res, 400, { error: "Invalid JSON" }); return; }
    if (!kql) { sendJson(res, 400, { error: "Missing kql" }); return; }
    // Checkpoint the query text every time it's actually run, in addition to
    // the editor's own debounced autosave -- belt and suspenders against
    // losing it to a restart.
    entry.lastQuery = kql;
    void savePersistedConfig({ lastQuery: kql });
    try {
      const rows = await runQuery(entry.clusterUri, database || entry.database, kql);
      sendJson(res, 200, { rows });
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

await joinSession({
  canvases: [
    createCanvas({
      id: "ftk-local-dashboard",
      displayName: "FinOps hub local dashboard",
      description: "Live FinOps dashboard for the local (ftklocal) Kusto emulator with six views: cost overview, allocation, rate optimization, usage & unit economics, anomalies & forecast, and AI tokenomics.",
      inputSchema: {
        type: "object",
        properties: {
          clusterUri: { type: "string", description: `Base URI of the Kusto emulator (e.g. http://localhost:8083 if your container maps that port). Only used to seed the connection on the very first run before anything has been persisted; falls back to FTK_LOCAL_CLUSTER_URI or ${HARDCODED_CLUSTER}. Once a connection has been used, it's remembered and this input is ignored -- reconnect via the in-canvas Settings dialog instead.` },
          database: { type: "string", description: "Database name. Default Hub." },
        },
      },
      actions: [
        {
          name: "summary",
          description: "Run the dashboard queries against the emulator and return headline FinOps KPIs (effective cost, savings, ESR, untagged %, commitment coverage, top services) for a time window.",
          inputSchema: {
            type: "object",
            properties: {
              preset: { type: "string", enum: ["all", "12m", "6m", "3m"], description: "Time window. Default all." },
            },
          },
          handler: async (ctx) => {
            const entry = singleton;
            const clusterUri = entry?.clusterUri || DEFAULT_CLUSTER;
            const database = entry?.database || DEFAULT_DB;
            const preset = ctx.input?.preset || "all";
            try {
              const payload = await getDashboard(clusterUri, database, preset);
              return headline(payload);
            } catch (err) {
              logError(`Could not query summary for ${clusterUri}/${database}`, err);
              throw new CanvasError("query_failed", "Could not query the local FinOps hub. Check the extension logs for details.");
            }
          },
        },
        {
          name: "tokenomics",
          description: "Run the AI token-economics queries against the emulator and return headline token KPIs (AI token cost, total tokens, blended cost per 1M tokens, cached-input share, AI share of cloud, top models, direction mix) for a time window.",
          inputSchema: {
            type: "object",
            properties: {
              preset: { type: "string", enum: ["all", "12m", "6m", "3m"], description: "Time window. Default all." },
            },
          },
          handler: async (ctx) => {
            const entry = singleton;
            const clusterUri = entry?.clusterUri || DEFAULT_CLUSTER;
            const database = entry?.database || DEFAULT_DB;
            const preset = ctx.input?.preset || "all";
            try {
              const payload = await getTokenomics(clusterUri, database, preset);
              return tokenHeadline(payload);
            } catch (err) {
              logError(`Could not query tokenomics for ${clusterUri}/${database}`, err);
              throw new CanvasError("query_failed", "Could not query the local FinOps hub. Check the extension logs for details.");
            }
          },
        },
      ],
      open: async (ctx) => {
        // `ctx.input` is only trusted to seed the connection on a genuinely
        // first-ever run (no persisted config exists yet). Once persisted,
        // `persisted.clusterUri`/`database` always win -- see the
        // "Resolution order" comment above DEFAULT_CLUSTER for why this
        // can't be the other way around. getOrCreateSingleton() only reads
        // these values on the very first call anyway (it never overwrites
        // an already-running singleton), so this only matters for the
        // process's first open() after a (re)start.
        const clusterUri = (persisted.clusterUri || ctx.input?.clusterUri || DEFAULT_CLUSTER).trim();
        const database = (persisted.database || ctx.input?.database || DEFAULT_DB).trim();
        const entry = await getOrCreateSingleton(clusterUri, database);
        entry.openInstances.add(ctx.instanceId);
        return { title: "FinOps hub · local", url: entry.url, status: `${entry.clusterUri} · ${entry.database}` };
      },
      onClose: async (ctx) => {
        if (!singleton) return;
        singleton.openInstances.delete(ctx.instanceId);
        // Deliberately keep the server alive even at zero open panels: a
        // fresh reopen (which the host does routinely -- reconnects,
        // rehydrates, focus-switches) should reuse in-memory state (current
        // connection, in-flight query text) rather than losing it. The
        // process only actually goes away when the extension itself is
        // stopped/reloaded by the host -- and even then, DASHBOARD_PORT
        // being fixed means the next process's URL is identical.
      },
    }),
  ],
});
