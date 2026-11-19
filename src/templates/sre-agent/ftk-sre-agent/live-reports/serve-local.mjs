import { execFile } from "node:child_process";
import { createReadStream } from "node:fs";
import { readFile, stat } from "node:fs/promises";
import { createServer } from "node:http";
import { dirname, join } from "node:path";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);
const root = dirname(fileURLToPath(import.meta.url));
const reports = JSON.parse(await readFile(join(root, "local-reports.json"), "utf8"));
const reportRoutes = new Map(reports.flatMap((report) =>
  report.routes.map((route) => [route, join(root, report.output)])));
const reportPolicies = new Map(reports.map((report) => [report.id, new Set(report.allowedTools)]));
const host = "127.0.0.1";
const port = Number.parseInt(process.env.PORT || "4174", 10);
const tenant = process.env.AZURE_TENANT_ID || "";
const subscription = process.env.AZURE_SUBSCRIPTION_ID || "";
const clusterUri = normalizeClusterUri(process.env.KUSTO_CLUSTER_URI);
const database = process.env.KUSTO_DATABASE || "Hub";
const tokenResource = "https://api.kusto.windows.net";
const toolName = "system-mcp-kusto_kusto_query";
const recommendationTool = "azure-resource-manager-mcp_get_benefit_recommendations";
const utilizationTool = "azure-resource-manager-mcp_list_benefit_utilization";
const armOrigin = "https://management.azure.com";
const benefitScopePattern = /^\/providers\/microsoft\.billing\/billingaccounts\/[a-z0-9_.:-]+\/billingprofiles\/[a-z0-9_.-]+$/i;
const maxRequestBytes = 2 * 1024 * 1024;
const allowedOrigins = new Set([
  `http://${host}:${port}`,
  `http://localhost:${port}`,
]);

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error(`Invalid PORT value: ${process.env.PORT}`);
}
if (!/^[A-Za-z0-9_.-]+$/.test(database)) {
  throw new Error("KUSTO_DATABASE contains unsupported characters.");
}

const tokenCache = new Map();
const pendingTokens = new Map();
let pendingBenefitScopes;

function normalizeClusterUri(value) {
  if (!value) {
    throw new Error("KUSTO_CLUSTER_URI is required.");
  }

  const url = new URL(value);
  if (url.protocol !== "https:") {
    throw new Error("KUSTO_CLUSTER_URI must use HTTPS.");
  }
  if (url.pathname !== "/" || url.search || url.hash) {
    throw new Error(
      "KUSTO_CLUSTER_URI must be the cluster origin without a database path.",
    );
  }
  return url.origin;
}

function isLoopback(address) {
  return (
    address === "127.0.0.1" ||
    address === "::1" ||
    address === "::ffff:127.0.0.1"
  );
}

function sendJson(response, status, payload) {
  const body = JSON.stringify(payload);
  response.writeHead(status, {
    "Cache-Control": "no-store",
    "Content-Length": Buffer.byteLength(body),
    "Content-Type": "application/json; charset=utf-8",
    "X-Content-Type-Options": "nosniff",
  });
  response.end(body);
}

function hostedToolResult(payload) {
  return { $type: "text", text: JSON.stringify(payload), annotations: null, additionalProperties: {} };
}

function tokenExpiry(payload) {
  const epochSeconds = Number(payload.expires_on);
  if (Number.isFinite(epochSeconds) && epochSeconds > 0) {
    return epochSeconds * 1000;
  }

  const parsed = Date.parse(payload.expiresOn || "");
  if (!Number.isFinite(parsed)) {
    throw new Error("Az PowerShell returned an invalid token expiry.");
  }
  return parsed;
}

async function getAccessToken(forceRefresh = false, audience = tokenResource) {
  const cached = tokenCache.get(audience);
  if (
    !forceRefresh &&
    cached &&
    cached.expiresAt - 2 * 60 * 1000 > Date.now()
  ) {
    return cached.value;
  }
  if (!tenant || !subscription) {
    throw new Error("AZURE_TENANT_ID and AZURE_SUBSCRIPTION_ID must identify an existing Az PowerShell context. This bridge does not sign in or change context.");
  }
  if (pendingTokens.has(audience)) return pendingTokens.get(audience);
  const pending = (async () => {
    const script = `
$ErrorActionPreference = 'Stop'
Import-Module Az.Accounts -ErrorAction Stop
$contexts = @(Get-AzContext -ListAvailable | Where-Object {
  $_.Tenant.Id -eq $env:AZURE_TENANT_ID -and $_.Subscription.Id -eq $env:AZURE_SUBSCRIPTION_ID
})
if ($contexts.Count -ne 1) {
  throw "Expected exactly one existing Az PowerShell context for tenant $env:AZURE_TENANT_ID and subscription $env:AZURE_SUBSCRIPTION_ID; found $($contexts.Count). No authentication or context was changed."
}
$token = Get-AzAccessToken -ResourceUrl $env:FINOPS_REPORT_TOKEN_RESOURCE -DefaultProfile $contexts[0] -WarningAction SilentlyContinue
$value = if ($token.Token -is [Security.SecureString]) { ConvertFrom-SecureString $token.Token -AsPlainText } else { $token.Token }
@{ accessToken = $value; expires_on = $token.ExpiresOn.ToUnixTimeSeconds() } | ConvertTo-Json -Compress
`;
    const { stdout } = await execFileAsync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", script], {
      env: { ...process.env, FINOPS_REPORT_TOKEN_RESOURCE: audience },
      maxBuffer: 4 * 1024 * 1024,
    });
    const payload = JSON.parse(stdout);
    if (typeof payload.accessToken !== "string" || !payload.accessToken) {
      throw new Error("Az PowerShell returned an empty access token.");
    }
    tokenCache.set(audience, { value: payload.accessToken, expiresAt: tokenExpiry(payload) });
    return payload.accessToken;
  })();
  pendingTokens.set(audience, pending);
  try {
    return await pending;
  } finally {
    pendingTokens.delete(audience);
  }
}

function primaryTable(payload) {
  if (!payload || !Array.isArray(payload.Tables)) return null;
  return (
    payload.Tables.find((table) => table.TableKind === "PrimaryResult") ||
    payload.Tables.find((table) => table.TableName === "PrimaryResult") ||
    payload.Tables[0] ||
    null
  );
}

async function executeKusto(query, forceRefresh = false) {
  const token = await getAccessToken(forceRefresh);
  const result = await fetch(`${clusterUri}/v1/rest/query`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      "X-MS-App": "FinOpsHubLiveReportLocal",
      "X-MS-Client-Request-Id": `FinOpsHubLiveReportLocal;${crypto.randomUUID()}`,
    },
    body: JSON.stringify({ db: database, csl: query }),
    signal: AbortSignal.timeout(60_000),
  });

  if (result.status === 401 && !forceRefresh) {
    tokenCache.delete(tokenResource);
    return executeKusto(query, true);
  }

  const text = await result.text();
  let payload;
  try {
    payload = JSON.parse(text);
  } catch {
    throw new Error(
      `Kusto returned HTTP ${result.status} with a non-JSON response.`,
    );
  }
  if (!result.ok) {
    const detail =
      payload?.error?.["@message"] ||
      payload?.error?.message ||
      payload?.message;
    throw new Error(detail || `Kusto query failed with HTTP ${result.status}.`);
  }

  const table = primaryTable(payload);
  if (!table) return { results: { items: [] } };

  const columnNames = table.Columns.map((column) => column.ColumnName);
  const header = Object.fromEntries(columnNames.map((name) => [name, null]));
  return { results: { items: [header, ...table.Rows] } };
}

async function benefitScopes() {
  if (pendingBenefitScopes) return pendingBenefitScopes;
  pendingBenefitScopes = (async () => {
    const result = await executeKusto("Costs() | where ChargePeriodStart >= ago(7d) | summarize Rows=count(), Latest=max(ChargePeriodStart) by BillingAccountId, x_BillingProfileId, BillingCurrency");
    const items = result.results.items;
    const columns = Object.keys(items[0] || {});
    const indexes = ["BillingAccountId", "x_BillingProfileId"].map((name) => columns.indexOf(name));
    if (indexes.some((index) => index < 0)) throw new Error("The Hub did not return billing-profile scope columns.");
    return new Set(items.slice(1).flatMap((row) => indexes.map((index) => row[index]))
      .filter((scope) => typeof scope === "string" && benefitScopePattern.test(scope))
      .map((scope) => scope.toLowerCase()));
  })();
  try {
    return await pendingBenefitScopes;
  } finally {
    pendingBenefitScopes = null;
  }
}

async function readAzure(endpoint, forceRefresh = false) {
  const result = await fetch(endpoint, {
    headers: { Accept: "application/json", Authorization: `Bearer ${await getAccessToken(forceRefresh, `${armOrigin}/`)}` },
    redirect: "error",
    signal: AbortSignal.timeout(60_000),
  });
  if (result.status === 401 && !forceRefresh) {
    tokenCache.delete(`${armOrigin}/`);
    return readAzure(endpoint, true);
  }
  const text = await result.text();
  let payload;
  try {
    payload = JSON.parse(text);
  } catch {
    throw new Error(`Azure benefits returned HTTP ${result.status} with a non-JSON response.`);
  }
  if (!result.ok || payload?.error) {
    throw new Error(payload?.error?.message || `Azure benefit query failed with HTTP ${result.status}.`);
  }
  return payload;
}

async function executeBenefit(name, args) {
  if (!args || typeof args !== "object" || Array.isArray(args) ||
      typeof args.scope !== "string" || !benefitScopePattern.test(args.scope)) {
    throw new Error("A full MCA billing-profile scope discovered from this Hub is required.");
  }
  const keys = name === recommendationTool
    ? ["scope", "recommendationScope", "term", "lookBackPeriod", "expand"]
    : ["scope", "grain"];
  if (Object.keys(args).some((key) => !keys.includes(key))) throw new Error("Unsupported Azure benefit arguments.");
  if (name === recommendationTool && (args.recommendationScope !== "Shared" ||
      !["P1Y", "P3Y"].includes(args.term) || args.lookBackPeriod !== "Last30Days" || args.expand !== true)) {
    throw new Error("Only expanded Shared P1Y/P3Y Last30Days recommendations are allowed.");
  }
  if (name === utilizationTool && args.grain !== "Daily") throw new Error("Only Daily benefit utilization is allowed.");
  if (!(await benefitScopes()).has(args.scope.toLowerCase())) throw new Error("The requested billing profile is not present in this Hub's recent cost records.");
  const operation = name === recommendationTool ? "benefitRecommendations" : "benefitUtilizationSummaries";
  const endpoint = new URL(`${args.scope}/providers/Microsoft.CostManagement/${operation}`, armOrigin);
  endpoint.searchParams.set("api-version", "2025-03-01");
  if (name === recommendationTool) {
    endpoint.searchParams.set("$filter", `properties/lookBackPeriod eq 'Last30Days' AND properties/term eq '${args.term}' AND properties/scope eq 'Shared'`);
    endpoint.searchParams.set("$expand", "properties/usage,properties/allRecommendationDetails");
  } else {
    endpoint.searchParams.set("grainParameter", "Daily");
  }
  const records = [];
  const seen = new Set();
  let next = endpoint;
  while (next) {
    if (next.origin !== armOrigin || next.pathname.toLowerCase() !== endpoint.pathname.toLowerCase() ||
        next.username || next.password || next.hash || seen.has(next.href) || seen.size >= 100) {
      throw new Error("Azure returned an invalid or repeated benefit pagination link.");
    }
    seen.add(next.href);
    const page = await readAzure(next);
    if (!Array.isArray(page.value)) throw new Error("Azure did not return a benefit result list.");
    records.push(...page.value);
    next = page.nextLink ? new URL(page.nextLink, armOrigin) : null;
  }
  return { structuredContent: { result: { value: records } } };
}

async function readRequestBody(request) {
  const declaredLength = Number.parseInt(
    request.headers["content-length"] || "0",
    10,
  );
  if (declaredLength > maxRequestBytes) {
    throw new Error("Request exceeds the 2 MB bridge limit.");
  }

  const chunks = [];
  let bytes = 0;
  for await (const chunk of request) {
    bytes += chunk.length;
    if (bytes > maxRequestBytes) {
      throw new Error("Request exceeds the 2 MB bridge limit.");
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf8");
}

async function handleQuery(request, response) {
  const origin = request.headers.origin;
  if (origin && !allowedOrigins.has(origin)) {
    return sendJson(response, 403, {
      error: `Origin is not allowed: ${origin}`,
    });
  }
  if (request.method !== "POST") {
    response.writeHead(405, { Allow: "POST" });
    return response.end();
  }

  let body;
  try {
    body = JSON.parse(await readRequestBody(request));
  } catch (error) {
    return sendJson(response, 400, {
      error: error instanceof Error ? error.message : "Invalid request body.",
    });
  }

  if (!reportPolicies.get(body?.report)?.has(body?.name) ||
      ![toolName, recommendationTool, utilizationTool].includes(body?.name)) {
    return sendJson(response, 403, {
      error: `Tool is not approved for report ${String(body?.report || "")}: ${String(body?.name || "")}`,
    });
  }

  const args = body.args;
  if (body.name !== toolName) {
    try {
      return sendJson(response, 200, hostedToolResult(await executeBenefit(body.name, args)));
    } catch (error) {
      console.error(`[benefits] ${error instanceof Error ? error.message : String(error)}`);
      return sendJson(response, 502, {
        error: error instanceof Error ? error.message : "Azure benefit query failed.",
      });
    }
  }
  if (!args || typeof args !== "object" || Array.isArray(args) ||
      Object.keys(args).some((key) => !["cluster-uri", "database", "query"].includes(key))) {
    return sendJson(response, 400, {
      error: "Only cluster-uri, database, and query Kusto arguments are supported.",
    });
  }
  let requestedCluster;
  try {
    requestedCluster = normalizeClusterUri(args?.["cluster-uri"]);
  } catch {
    return sendJson(response, 400, {
      error: "A valid HTTPS cluster-uri is required.",
    });
  }
  if (requestedCluster !== clusterUri || args?.database !== database) {
    return sendJson(response, 403, {
      error: "The requested Kusto target is not allowed by this bridge.",
    });
  }
  if (typeof args?.query !== "string" || !args.query.trim()) {
    return sendJson(response, 400, {
      error: "A non-empty Kusto query is required.",
    });
  }
  if (args.query.trimStart().startsWith(".")) {
    return sendJson(response, 403, {
      error: "Kusto management commands are not allowed by this bridge.",
    });
  }

  try {
    return sendJson(response, 200, hostedToolResult(await executeKusto(args.query)));
  } catch (error) {
    console.error(
      `[kusto] ${error instanceof Error ? error.message : String(error)}`,
    );
    return sendJson(response, 502, {
      error: error instanceof Error ? error.message : "Kusto query failed.",
    });
  }
}

async function handleReport(request, response, targetPath) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    response.writeHead(405, { Allow: "GET, HEAD" });
    return response.end();
  }

  try {
    const fileStat = await stat(targetPath);
    if (!fileStat.isFile()) throw new Error("Local report is not a file.");
    response.writeHead(200, {
      "Cache-Control": "no-store",
      "Content-Length": fileStat.size,
      "Content-Type": "text/html; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    });
    if (request.method === "HEAD") return response.end();
    return createReadStream(targetPath).pipe(response);
  } catch {
    return sendJson(response, 404, {
      error: "Run node build-local.mjs before starting the local server.",
    });
  }
}

const server = createServer(async (request, response) => {
  if (!isLoopback(request.socket.remoteAddress)) {
    return sendJson(response, 403, {
      error: "The local bridge accepts loopback connections only.",
    });
  }

  const url = new URL(
    request.url || "/",
    `http://${request.headers.host || `${host}:${port}`}`,
  );
  if (url.pathname === "/api/health") {
    return sendJson(response, 200, {
      auth: "Az PowerShell existing context",
      clusterUri,
      database,
      dataSource: "live",
      tenant: tenant || "Not configured",
      subscription: subscription || "Not configured",
      toolName,
      benefitTools: [recommendationTool, utilizationTool],
      responseFormat: "hosted-text",
      reports: reports.map(({ id, allowedTools }) => ({ id, allowedTools })),
    });
  }
  if (url.pathname === "/api/kusto/query") {
    return handleQuery(request, response);
  }
  if (reportRoutes.has(url.pathname)) {
    return handleReport(request, response, reportRoutes.get(url.pathname));
  }

  response.writeHead(404);
  return response.end();
});

server.listen(port, host, () => {
  console.log(`MTD KPI Cockpit: http://${host}:${port}/`);
  console.log(`Savings Plans:   http://${host}:${port}/savings-plans`);
  console.log(`Kusto target:    ${clusterUri}/${database}`);
  console.log(`Tenant:          ${tenant || "Not configured"}`);
  console.log(`Subscription:    ${subscription || "Not configured"}`);
});
