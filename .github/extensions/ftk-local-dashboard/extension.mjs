// Extension: ftk-local-dashboard
// A FinOps dashboard canvas for the local (ftklocal) Kusto emulator.
//
// open() boots a per-instance loopback HTTP server that serves the static
// dashboard (public/) and two JSON endpoints (/api/config, /api/dashboard).
// The dashboard renderer fetches /api/dashboard, which runs the FinOps query
// layer (kusto.mjs) against the emulator's Hub database.

import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
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
const DEFAULT_CLUSTER = "http://localhost:8082";
const DEFAULT_DB = "Hub";

const STATIC = {
  "/": ["index.html", "text/html; charset=utf-8"],
  "/index.html": ["index.html", "text/html; charset=utf-8"],
  "/app.css": ["app.css", "text/css; charset=utf-8"],
  "/app.js": ["app.js", "application/javascript; charset=utf-8"],
};

// instanceId -> { server, url, clusterUri, database }
const servers = new Map();

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" });
  res.end(body);
}

function logError(context, err) {
  console.error(`[ftk-local-dashboard] ${context}`, err);
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

  if (path === "/api/config") {
    sendJson(res, 200, { clusterUri: entry.clusterUri, database: entry.database, instanceId: entry.instanceId });
    return;
  }

  if (path === "/api/dashboard") {
    const preset = url.searchParams.get("preset") || "all";
    try {
      const payload = await getDashboard(entry.clusterUri, entry.database, preset);
      sendJson(res, 200, payload);
    } catch (err) {
      sendQueryError(res, entry, "overview", err);
    }
    return;
  }

  if (path === "/api/tokenomics") {
    const preset = url.searchParams.get("preset") || "all";
    try {
      const payload = await getTokenomics(entry.clusterUri, entry.database, preset);
      sendJson(res, 200, payload);
    } catch (err) {
      sendQueryError(res, entry, "tokenomics", err);
    }
    return;
  }

  if (path === "/api/view") {
    const name = url.searchParams.get("name") || "overview";
    const preset = url.searchParams.get("preset") || "all";
    const getter = GETTERS[name];
    if (!getter) { sendJson(res, 200, { error: `Unknown view '${name}'` }); return; }
    try {
      const payload = await getter(entry.clusterUri, entry.database, preset);
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
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
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
          clusterUri: { type: "string", description: "Base URI of the Kusto emulator. Default http://localhost:8082." },
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
            const entry = servers.get(ctx.instanceId);
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
            const entry = servers.get(ctx.instanceId);
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
        const clusterUri = (ctx.input?.clusterUri || DEFAULT_CLUSTER).trim();
        const database = (ctx.input?.database || DEFAULT_DB).trim();
        let entry = servers.get(ctx.instanceId);
        if (!entry) {
          entry = { instanceId: ctx.instanceId, clusterUri, database };
          await startServer(entry);
          servers.set(ctx.instanceId, entry);
        } else {
          // Reopen may carry updated connection input.
          entry.clusterUri = clusterUri;
          entry.database = database;
        }
        return { title: "FinOps hub · local", url: entry.url, status: `${clusterUri} · ${database}` };
      },
      onClose: async (ctx) => {
        const entry = servers.get(ctx.instanceId);
        if (entry) {
          servers.delete(ctx.instanceId);
          await new Promise((resolve) => entry.server.close(() => resolve()));
        }
      },
    }),
  ],
});
