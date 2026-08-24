// KQL query layer for local and remote FinOps hubs.
//
// Talks to the Kusto HTTP API (/v1/rest/query) and parses the v1
// response shape (Tables[0]) into plain row objects. The dashboard queries are
// grounded in the FinOps Framework domains and the FinOps toolkit query
// catalog (src/queries/INDEX.md, KPI.md, finops-hub-database-guide.md).

import { randomUUID } from "node:crypto";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const DEFAULT_TIMEOUT_MS = 20000;
const TOKEN_TIMEOUT_MS = 15000;
const TOKEN_MAX_BUFFER = 1024 * 1024;
const TOKEN_REFRESH_SKEW_MS = 2 * 60 * 1000;
export const MAX_RESPONSE_BYTES = 4 * 1024 * 1024;
export const ALLOWED_FILTER_COLUMNS = new Set([
    "ServiceName",
    "ServiceCategory",
    "RegionId",
    "x_ResourceGroupName",
    "SubAccountName",
    "CommitmentDiscountName",
    "x_SkuMeterSubcategory",
]);
export const CAPACITY_LIMITS = Object.freeze({
    primaryRows: 250,
    selectorKeys: 500,
    dailyPoints: 430,
    heatmapCells: 500,
});
export const CAPACITY_FRESHNESS_HOURS = 48;

const CAPACITY_SOURCE_TYPES = Object.freeze([
    "AppServiceUsage",
    "CognitiveServicesUsage",
    "ComputeUsage",
    "SqlSubscriptionUsage",
    "StorageUsage",
    "CapacityReservation",
    "PremiumSSDv2Disk",
]);

export const CAPACITY_CLASS_REGISTRY = Object.freeze({
    "app-service": Object.freeze({
        id: "app-service",
        sourceType: "AppServiceUsage",
        sourceVersions: Object.freeze(["1.0-usage"]),
        providerApiVersion: "2024-11-01",
        title: "App Service quota",
        evidenceClass: "quota",
        evidenceLabel: "Provider-reported App Service quota — point-in-time",
        emptyLabel: "No App Service quota observations were ingested; this does not mean zero usage or unlimited capacity.",
        demandPredicateId: "app-service-cost",
    }),
    "azure-ai": Object.freeze({
        id: "azure-ai",
        sourceType: "CognitiveServicesUsage",
        sourceVersions: Object.freeze(["1.0-usage"]),
        providerApiVersion: "2023-05-01",
        title: "Azure AI quota pools",
        evidenceClass: "provider-counter",
        evidenceLabel: "Provider-reported Azure AI quota — point-in-time",
        emptyLabel: "No Azure AI quota observations were ingested; check query coverage and provider access.",
        demandPredicateId: "azure-ai-cost",
    }),
    compute: Object.freeze({
        id: "compute",
        sourceType: "ComputeUsage",
        sourceVersions: Object.freeze(["1.0-usage"]),
        providerApiVersion: "2024-07-01",
        title: "Compute quota",
        evidenceClass: "quota",
        evidenceLabel: "Provider-reported compute quota — point-in-time",
        emptyLabel: "No Compute quota observations were ingested; deployment capacity is unknown.",
        demandPredicateId: "compute-cost",
    }),
    "azure-sql": Object.freeze({
        id: "azure-sql",
        sourceType: "SqlSubscriptionUsage",
        sourceVersions: Object.freeze(["1.0-sql"]),
        providerApiVersion: "2023-08-01",
        title: "Azure SQL subscription quota and counters",
        evidenceClass: "provider-counter",
        evidenceLabel: "Provider-reported SQL quota — point-in-time",
        emptyLabel: "No Azure SQL subscription-usage observations were ingested; SQL quota posture is unknown.",
        demandPredicateId: "azure-sql-cost",
    }),
    storage: Object.freeze({
        id: "storage",
        sourceType: "StorageUsage",
        sourceVersions: Object.freeze(["1.0-usage"]),
        providerApiVersion: "2025-06-01",
        title: "Storage quotas",
        evidenceClass: "quota",
        evidenceLabel: "Provider-reported storage quota — point-in-time",
        emptyLabel: "No Storage quota evidence for the selected scope and time. Validate ingestion, permissions, supported regions, and source execution.",
        demandPredicateId: "storage-cost",
    }),
    "capacity-reservations": Object.freeze({
        id: "capacity-reservations",
        sourceType: "CapacityReservation",
        sourceVersions: Object.freeze(["1.0-capacity-reservation"]),
        providerApiVersion: "2024-03-01",
        title: "Capacity reservation groups",
        evidenceClass: "inventory",
        evidenceLabel: "Capacity reservation group observed — inventory only",
        emptyLabel: "No capacity reservation groups were observed in the latest ingestion window; absence is unverified without complete-snapshot evidence.",
        demandPredicateId: "capacity-reservation-cost",
    }),
    "premium-ssd-v2": Object.freeze({
        id: "premium-ssd-v2",
        sourceType: "PremiumSSDv2Disk",
        sourceVersions: Object.freeze(["1.0-disk"]),
        providerApiVersion: "2024-03-02",
        title: "Premium SSD v2 disks",
        evidenceClass: "inventory",
        evidenceLabel: "Observed Premium SSD v2 provisioned size — GiB inventory; no quota limit",
        emptyLabel: "No Premium SSD v2 disks were observed in the latest ingestion window; this is not a disk quota or regional availability conclusion.",
        demandPredicateId: "premium-ssd-cost",
    }),
});

const CAPACITY_CLASS_BY_SOURCE = new Map(
    Object.values(CAPACITY_CLASS_REGISTRY).map((entry) => [entry.sourceType.toLowerCase(), entry])
);

export const CAPACITY_METRIC_REGISTRY = Object.freeze({
    "computeusage|cores|count": Object.freeze({
        metricRole: "total-regional-vcpu",
        direction: "higher-is-worse",
        limitMode: "positive-denominator",
        zeroLimitMode: "no-entitlement",
        historyMode: "quota-series",
        heatmapMode: "regional-percent",
        evidenceLabel: "Total regional vCPU quota",
    }),
    "computeusage|lowprioritycores|count": Object.freeze({
        metricRole: "low-priority-vcpu",
        direction: "higher-is-worse",
        limitMode: "positive-denominator",
        zeroLimitMode: "no-entitlement",
        historyMode: "quota-series",
        heatmapMode: "regional-percent",
        evidenceLabel: "Regional low-priority or Spot vCPU quota",
    }),
    "computeusage|virtualmachines|count": Object.freeze({
        metricRole: "virtual-machine-count",
        direction: "higher-is-worse",
        limitMode: "positive-denominator",
        zeroLimitMode: "no-entitlement",
        historyMode: "quota-series",
        heatmapMode: "regional-percent",
        evidenceLabel: "Regional virtual machine count quota",
    }),
});

export const CAPACITY_DEMAND_REGISTRY = Object.freeze({
    "app-service": Object.freeze({
        units: Object.freeze(["Hours", "GiB Hours", "GB", "Units/Hour"]),
        label: "Billed App Service usage — daily {unit}, grouped by meter; not quota usage",
    }),
    "azure-ai": Object.freeze({
        units: Object.freeze(["Units", "Seconds", "Minutes", "Hours"]),
        label: "Billed Azure AI usage — daily {unit}, meter-specific; not requests, tokens, or quota unless named by the meter",
    }),
    compute: Object.freeze({
        units: Object.freeze(["Hours", "Units/Hour", "GB", "Units/Month", "Units", "GB/Month"]),
        label: "Billed compute usage — {unit}, meter-specific; not peak cores or capacity availability",
    }),
    "azure-sql": Object.freeze({
        units: Object.freeze(["Units/Day", "Hours", "GB/Month", "Units/Hour", "Units/Month"]),
        label: "Billed SQL usage — daily {unit}, exact meter; not quota utilization",
    }),
    storage: Object.freeze({
        units: Object.freeze(["Units", "Units/Hour", "GB", "GB/Month", "Units/Month"]),
        label: "Billed storage demand — daily {unit}, meter-specific; not quota utilization",
    }),
    "capacity-reservations": Object.freeze({
        units: Object.freeze(["Hours"]),
        label: "Capacity-reservation-linked billed hours — accounting status Used/Unused; not allocated or guaranteed capacity",
    }),
    "premium-ssd-v2": Object.freeze({
        units: Object.freeze([]),
        label: "Resource-matched disk effective cost ({currency}) — financial context; usage quantity not classified",
    }),
});

let cachedToken = null;
let tokenInFlight = null;

export function normalizeConnection(clusterUri, database = "Hub") {
    if (typeof clusterUri !== "string" || !clusterUri.trim()) {
        throw new Error("Cluster URI is required.");
    }

    let url;
    try {
        url = new URL(clusterUri.trim());
    } catch {
        throw new Error("Cluster URI must be a valid absolute URL.");
    }
    if (url.username || url.password || url.pathname !== "/" || url.search || url.hash) {
        throw new Error("Cluster URI must contain only the cluster origin.");
    }

    const hostname = url.hostname.toLowerCase();
    const isLoopback = hostname === "localhost" || hostname === "127.0.0.1" || hostname === "[::1]";
    let mode;
    if (isLoopback && url.protocol === "http:") {
        mode = "local";
    } else if (
        url.protocol === "https:" &&
        !url.port &&
        hostname.endsWith(".kusto.windows.net") &&
        hostname.length > ".kusto.windows.net".length
    ) {
        mode = "remote";
    } else {
        throw new Error("Use loopback HTTP for a local hub or HTTPS for a *.kusto.windows.net cluster.");
    }

    const normalizedDatabase = typeof database === "string" ? database.trim() : "";
    if (!normalizedDatabase || normalizedDatabase.length > 256 || /[\u0000-\u001f\u007f]/.test(normalizedDatabase)) {
        throw new Error("Database must be a non-empty name of at most 256 characters.");
    }

    return {
        clusterUri: url.origin,
        database: normalizedDatabase,
        mode,
        authentication: mode === "remote" ? "azure-cli" : "none",
    };
}

function tokenExpiryMs(value) {
    if (typeof value === "number" || /^\d+$/.test(String(value ?? ""))) {
        const numeric = Number(value);
        return numeric < 1e12 ? numeric * 1000 : numeric;
    }
    const parsed = Date.parse(String(value ?? ""));
    return Number.isFinite(parsed) ? parsed : NaN;
}

async function acquireAzureCliToken() {
    try {
        const { stdout } = await execFileAsync(
            "az",
            ["account", "get-access-token", "--resource", "https://api.kusto.windows.net", "--output", "json"],
            { timeout: TOKEN_TIMEOUT_MS, maxBuffer: TOKEN_MAX_BUFFER, windowsHide: true }
        );
        return JSON.parse(stdout);
    } catch {
        throw new Error("Azure CLI could not acquire a Kusto token. Run az login and retry.");
    }
}

async function getRemoteToken(tokenProvider = acquireAzureCliToken) {
    const now = Date.now();
    if (cachedToken && cachedToken.expiresOnMs - TOKEN_REFRESH_SKEW_MS > now) {
        return cachedToken.accessToken;
    }
    if (!tokenInFlight) {
        tokenInFlight = Promise.resolve()
            .then(() => tokenProvider())
            .then((result) => {
                const accessToken = result?.accessToken ?? result?.access_token;
                const expiresOnMs = tokenExpiryMs(result?.expiresOnMs ?? result?.expires_on);
                if (typeof accessToken !== "string" || !accessToken || !Number.isFinite(expiresOnMs) || expiresOnMs <= Date.now()) {
                    throw new Error("Azure CLI returned an invalid or expired Kusto token.");
                }
                cachedToken = { accessToken, expiresOnMs };
                return accessToken;
            })
            .catch(() => {
                cachedToken = null;
                throw new Error("Azure CLI could not acquire a Kusto token. Run az login and retry.");
            })
            .finally(() => {
                tokenInFlight = null;
            });
    }
    return tokenInFlight;
}

export function resetKustoAuthForTests() {
    cachedToken = null;
    tokenInFlight = null;
}

export async function readBoundedBody(response, maxBytes = MAX_RESPONSE_BYTES) {
    const declaredLength = Number(response.headers.get("content-length"));
    if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
        throw new Error(`Kusto response exceeded the ${maxBytes}-byte limit.`);
    }
    if (!response.body?.getReader) {
        const text = await response.text();
        if (Buffer.byteLength(text) > maxBytes) throw new Error(`Kusto response exceeded the ${maxBytes}-byte limit.`);
        return text;
    }

    const reader = response.body.getReader();
    const chunks = [];
    let total = 0;
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        total += value.byteLength;
        if (total > maxBytes) {
            await reader.cancel();
            throw new Error(`Kusto response exceeded the ${maxBytes}-byte limit.`);
        }
        chunks.push(Buffer.from(value));
    }
    return Buffer.concat(chunks, total).toString("utf8");
}

function rowsFromTable(table) {
    if (!table) return [];
    const cols = table.Columns.map((c) => c.ColumnName);
    return table.Rows.map((r) => Object.fromEntries(cols.map((c, i) => [c, r[i]])));
}

export function parseKustoResponse(json) {
    if (json?.error || json?.Exceptions || json?.OneApiErrors) {
        const msg = json?.error?.["@message"] || JSON.stringify(json).slice(0, 300);
        throw new Error(`Kusto query error: ${msg}`);
    }
    const tables = Array.isArray(json?.Tables) ? json.Tables : [];
    const statusTable = tables.find((table) => {
        const names = new Set((table.Columns || []).map((column) => column.ColumnName));
        return names.has("Severity") && names.has("StatusCode") && names.has("StatusDescription");
    });
    const failure = rowsFromTable(statusTable).find((row) => Number(row.StatusCode) !== 0 || Number(row.Severity) <= 2);
    if (failure) {
        throw new Error(`Kusto query failed: ${failure.StatusDescription || `status ${failure.StatusCode}`}`);
    }
    return rowsFromTable(tables[0]);
}

/**
 * Run a single KQL query against a FinOps hub and return rows as objects.
 * Throws on transport error or Kusto error payload.
 */
export async function runQuery(clusterUri, database, csl, options = {}) {
    if (typeof options === "number") options = { timeoutMs: options };
    const {
        timeoutMs = DEFAULT_TIMEOUT_MS,
        fetchImpl = fetch,
        tokenProvider = acquireAzureCliToken,
        maxResponseBytes = MAX_RESPONSE_BYTES,
    } = options;
    const connection = normalizeConnection(clusterUri, database);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    let res, text;
    try {
        const headers = {
            "Content-Type": "application/json",
            Accept: "application/json",
            "x-ms-readonly": "true",
            "x-ms-client-request-id": `FinOpsToolkit.FtkDashboard;${randomUUID()}`,
        };
        if (connection.mode === "remote") {
            headers.Authorization = `Bearer ${await getRemoteToken(tokenProvider)}`;
        }
        res = await fetchImpl(`${connection.clusterUri}/v1/rest/query`, {
            method: "POST",
            headers,
            body: JSON.stringify({ db: connection.database, csl }),
            signal: controller.signal,
        });
        text = await readBoundedBody(res, maxResponseBytes);
    } catch (err) {
        if (err?.name === "AbortError") {
            throw new Error(`Timed out after ${timeoutMs}ms reaching ${connection.clusterUri}`);
        }
        if (/Azure CLI|Kusto token|Kusto response exceeded/.test(err?.message || "")) throw err;
        throw new Error(`Could not reach Kusto at ${connection.clusterUri}: ${err?.message ?? err}`);
    } finally {
        clearTimeout(timer);
    }

    if (!res.ok) {
        throw new Error(`Kusto returned HTTP ${res.status}. ${text.slice(0, 300)}`);
    }

    let json;
    try {
        json = JSON.parse(text);
    } catch {
        throw new Error("Kusto returned an invalid JSON response.");
    }
    return parseKustoResponse(json);
}

// --- date helpers (work in UTC to match Kusto datetimes) ----------------------

function startOfMonthUTC(d) {
    return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1));
}
function addMonthsUTC(d, n) {
    return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + n, 1));
}
function isoDay(d) {
    return d.toISOString().slice(0, 10);
}

/**
 * Resolve a preset window (all | 12m | 6m | 3m) against the actual data range.
 * Returns inclusive start and exclusive end ISO-day strings plus the data range.
 */
export async function resolveWindow(clusterUri, database, preset) {
    const range = await runQuery(
        clusterUri,
        database,
        "Costs() | summarize MinDate=min(ChargePeriodStart), MaxDate=max(ChargePeriodStart), Rows=count()"
    );
    const row = range[0] ?? {};
    if (!row.MaxDate) {
        return { start: null, end: null, dataMin: null, dataMax: null, rows: 0, empty: true };
    }
    const dataMin = new Date(row.MinDate);
    const dataMax = new Date(row.MaxDate);
    const endExclusive = addMonthsUTC(startOfMonthUTC(dataMax), 1); // include the whole last month
    const lastMonth = startOfMonthUTC(dataMax);

    let start;
    switch (preset) {
        case "3m": start = addMonthsUTC(lastMonth, -2); break;
        case "6m": start = addMonthsUTC(lastMonth, -5); break;
        case "12m": start = addMonthsUTC(lastMonth, -11); break;
        case "all":
        default: start = startOfMonthUTC(dataMin); break;
    }
    if (start < startOfMonthUTC(dataMin)) start = startOfMonthUTC(dataMin);

    return {
        start: isoDay(start),
        end: isoDay(endExclusive),
        dataMin: isoDay(dataMin),
        dataMax: isoDay(dataMax),
        rows: row.Rows ?? 0,
        empty: false,
    };
}

/**
 * Build a KQL `| where` clause from a filters object `{ ColumnName: ["val1","val2"] }`.
 * Returns an empty string when there are no filters.
 */
export function validateFilters(filters = {}) {
    if (!filters || typeof filters !== "object" || Array.isArray(filters)) throw new Error("Filters must be an object.");
    const normalized = {};
    for (const [column, values] of Object.entries(filters)) {
        if (!ALLOWED_FILTER_COLUMNS.has(column)) throw new Error(`Unsupported filter dimension '${column}'.`);
        if (!Array.isArray(values) || values.length > 8) throw new Error(`Filter '${column}' must contain at most 8 values.`);
        const clean = [...new Set(values.map((value) => String(value)))];
        if (clean.some((value) => !value || value.length > 256)) {
            throw new Error(`Filter '${column}' values must be 1-256 characters.`);
        }
        if (clean.length) normalized[column] = clean;
    }
    return normalized;
}

export function buildFilterWhere(filters) {
    const clauses = Object.entries(validateFilters(filters))
        .map(([col, vals]) => {
            const quoted = vals.map((value) => JSON.stringify(value)).join(", ");
            return `| where ${col} in (${quoted})`;
        });
    return clauses.length > 0 ? "\n" + clauses.join("\n") : "";
}

function normalizeCapacityValue(value) {
    return String(value ?? "").trim().toLowerCase();
}

function finiteNumber(value) {
    if (value === null || value === undefined || value === "") return null;
    const number = Number(value);
    return Number.isFinite(number) ? number : null;
}

export function normalizeCapacityClassId(value) {
    const normalized = normalizeCapacityValue(value);
    if (normalized === "home") return "home";
    if (CAPACITY_CLASS_REGISTRY[normalized]) return normalized;
    const sourceMatch = CAPACITY_CLASS_BY_SOURCE.get(normalized);
    if (sourceMatch) return sourceMatch.id;
    throw new Error(`Unsupported capacity class '${value}'.`);
}

export function resolveCapacityMetric(row = {}) {
    const sourceType = String(row.x_SourceType ?? "").trim();
    const sourceVersion = String(row.x_SourceVersion ?? "").trim();
    const resourceName = String(row.ResourceName ?? "").trim();
    const unit = String(row.unit ?? "").trim();
    const classContract = CAPACITY_CLASS_BY_SOURCE.get(sourceType.toLowerCase());

    if (!sourceType || !sourceVersion || !classContract) {
        return {
            capability: "disabled",
            reasonCode: classContract ? "invalid-identity" : "unsupported-source",
            evidenceLabel: "Required source identity is missing or unsupported",
            classId: classContract?.id ?? null,
        };
    }
    if (!classContract.sourceVersions.some((version) => version.toLowerCase() === sourceVersion.toLowerCase())) {
        return {
            capability: "descriptive-only",
            reasonCode: "source-version-mismatch",
            evidenceLabel: "Source version changed — registry review required",
            classId: classContract.id,
        };
    }
    if (classContract.evidenceClass === "inventory") {
        if (!resourceName || !String(row.ResourceId ?? "").trim()) {
            return {
                capability: "disabled",
                reasonCode: "invalid-identity",
                evidenceLabel: "Inventory identity is incomplete",
                classId: classContract.id,
            };
        }
        return {
            capability: "enabled",
            reasonCode: "inventory-source-contract",
            evidenceLabel: classContract.evidenceLabel,
            classId: classContract.id,
            evidenceClass: "inventory",
        };
    }
    if (!resourceName || !unit) {
        return {
            capability: "disabled",
            reasonCode: "invalid-identity",
            evidenceLabel: "Quota metric identity is incomplete",
            classId: classContract.id,
        };
    }

    const metricKey = [sourceType, resourceName, unit].map(normalizeCapacityValue).join("|");
    const metric = CAPACITY_METRIC_REGISTRY[metricKey];
    if (!metric) {
        const negativeSqlLimit =
            classContract.id === "azure-sql" && finiteNumber(row.limit) !== null && finiteNumber(row.limit) < 0;
        return {
            capability: "descriptive-only",
            reasonCode: "unclassified-metric",
            evidenceLabel: negativeSqlLimit
                ? "Negative provider limit — interpretation unverified"
                : "Registry review required",
            classId: classContract.id,
            metricKey,
        };
    }
    return {
        capability: "enabled",
        reasonCode: "registered-metric",
        evidenceLabel: metric.evidenceLabel,
        classId: classContract.id,
        metricKey,
        ...metric,
    };
}

export function classifyCapacityObservation(row = {}, now = new Date(), freshnessHours = CAPACITY_FRESHNESS_HOURS) {
    const semantic = resolveCapacityMetric(row);
    const classContract = semantic.classId ? CAPACITY_CLASS_REGISTRY[semantic.classId] : null;
    const currentValue = finiteNumber(row.currentValue);
    const limit = finiteNumber(row.limit);
    const observedAt = Date.parse(String(row.x_IngestionTime ?? ""));
    const nowMs = now instanceof Date ? now.getTime() : Date.parse(String(now));
    if (!Number.isFinite(observedAt) || !Number.isFinite(nowMs)) {
        return {
            ...semantic,
            capability: "disabled",
            state: "invalid",
            reasonCode: "invalid-ingestion-time",
            evidenceLabel: "Observation time is missing or invalid",
            ageHours: null,
        };
    }

    const ageHours = Math.max(0, (nowMs - observedAt) / 3600000);
    if (semantic.capability === "disabled") {
        return { ...semantic, state: "invalid", ageHours };
    }
    if (
        (classContract?.evidenceClass !== "inventory" && (currentValue === null || currentValue < 0 || limit === null)) ||
        (semantic.classId === "premium-ssd-v2" && (currentValue === null || currentValue < 0))
    ) {
        return {
            ...semantic,
            capability: "disabled",
            state: "invalid",
            reasonCode: classContract?.evidenceClass === "inventory" ? "invalid-inventory-value" : "invalid-provider-values",
            evidenceLabel: classContract?.evidenceClass === "inventory"
                ? "Premium SSD v2 size is missing or invalid"
                : "Provider values are missing or invalid",
            ageHours,
        };
    }
    if (ageHours > freshnessHours) {
        return {
            ...semantic,
            capability: "disabled",
            state: "stale",
            reasonCode: "stale-observation",
            evidenceLabel: `Stale observation — older than ${freshnessHours} hours`,
            ageHours,
        };
    }
    if (semantic.capability === "descriptive-only") {
        return { ...semantic, state: "unclassified", ageHours };
    }

    if (classContract.evidenceClass === "inventory") {
        return {
            ...semantic,
            state: "inventory",
            ageHours,
            currentValue,
            limit: null,
            utilizationPercent: null,
            headroom: null,
        };
    }

    if (limit === 0) {
        return {
            ...semantic,
            state: currentValue > 0 ? "invalid" : "no-entitlement",
            reasonCode: currentValue > 0 ? "conflicting-provider-values" : "no-entitlement",
            evidenceLabel: currentValue > 0
                ? "Conflicting provider values"
                : "No quota reported or no entitlement",
            ageHours,
            currentValue,
            limit,
            utilizationPercent: null,
            headroom: null,
        };
    }
    if (limit < 0) {
        return {
            ...semantic,
            capability: "disabled",
            state: "invalid",
            reasonCode: "unexpected-negative-limit",
            evidenceLabel: "Negative provider limit — interpretation unverified",
            ageHours,
        };
    }

    const utilizationPercent = 100 * currentValue / limit;
    const state =
        utilizationPercent >= 100 ? "exhausted" :
        utilizationPercent >= 90 ? "action" :
        utilizationPercent >= 80 ? "watch" :
        "healthy";
    return {
        ...semantic,
        state,
        ageHours,
        currentValue,
        limit,
        utilizationPercent,
        headroom: limit - currentValue,
    };
}

export function resolveCapacityHistoryCapability(snapshotCount, options = {}) {
    const count = Number(snapshotCount);
    const inventory = options.evidenceClass === "inventory";
    if (!Number.isInteger(count) || count < 1) {
        return { mode: "unavailable", reasonCode: "no-compatible-snapshots", confidence: null };
    }
    if (count === 1) {
        return { mode: "current-only", reasonCode: "collecting-history", confidence: null };
    }
    if (inventory) {
        return { mode: "observed-history", reasonCode: "inventory-runway-disabled", confidence: null };
    }
    if (count === 2) {
        return { mode: "observed-delta", reasonCode: "insufficient-trend-points", confidence: null };
    }
    if (count < 7) {
        return { mode: "provisional-runway", reasonCode: "low-confidence", confidence: "low" };
    }
    return { mode: "trend-runway", reasonCode: "compatible-daily-history", confidence: "normal" };
}

function capacityClass(value) {
    const classId = normalizeCapacityClassId(value);
    if (classId === "home") throw new Error("A source class is required for this query.");
    return CAPACITY_CLASS_REGISTRY[classId];
}

function kqlString(value, fieldName) {
    const string = String(value ?? "").trim();
    if (!string || string.length > 512 || /[\u0000-\u001f\u007f]/.test(string)) {
        throw new Error(`${fieldName} must be 1-512 printable characters.`);
    }
    return JSON.stringify(string);
}

function validateCapacityFilters(filters = {}) {
    if (!filters || typeof filters !== "object" || Array.isArray(filters)) {
        throw new Error("Capacity filters must be an object.");
    }
    const normalized = {};
    for (const column of ["SubAccountId", "location"]) {
        const values = filters[column];
        if (values === undefined) continue;
        if (!Array.isArray(values) || values.length > 8) {
            throw new Error(`Capacity filter '${column}' must contain at most 8 values.`);
        }
        const clean = [...new Set(values.map((value) => String(value).trim()))];
        if (clean.some((value) => !value || value.length > 256)) {
            throw new Error(`Capacity filter '${column}' values must be 1-256 characters.`);
        }
        if (clean.length) normalized[column] = clean;
    }
    const unsupported = Object.keys(filters).filter((key) => !["SubAccountId", "location"].includes(key));
    if (unsupported.length) throw new Error(`Unsupported capacity filter '${unsupported[0]}'.`);
    return normalized;
}

function buildCapacityWhere(filters, target = "quota") {
    return Object.entries(validateCapacityFilters(filters))
        .map(([column, values]) => {
            const targetColumn = target === "cost" && column === "location" ? "RegionId" : column;
            return `| where ${targetColumn} in~ (${values.map((value) => kqlString(value, column)).join(", ")})`;
        })
        .join("\n");
}

function demandPredicate(predicateId) {
    switch (predicateId) {
        case "app-service-cost":
            return `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where x_ResourceType in~ ('microsoft.web/hostingenvironments','microsoft.web/serverfarms','microsoft.web/sites','microsoft.web/sites/slots')
| where ConsumedUnit in~ ('Hours','GiB Hours','GB','Units/Hour')`;
        case "azure-ai-cost":
            return `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where x_ResourceType in~ ('microsoft.cognitiveservices/accounts','microsoft.cognitiveservices/accounts/projects')
| where ConsumedUnit in~ ('Units','Seconds','Minutes','Hours')`;
        case "compute-cost":
            return `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where x_ResourceType in~ ('microsoft.compute/virtualmachines','microsoft.compute/virtualmachinescalesets','microsoft.compute/virtualmachinescalesets/virtualmachines')
| where ConsumedUnit in~ ('Hours','Units/Hour','GB','Units/Month','Units','GB/Month')`;
        case "azure-sql-cost":
            return `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where x_ResourceType startswith 'microsoft.sql/'
| where ConsumedUnit in~ ('Units/Day','Hours','GB/Month','Units/Hour','Units/Month')`;
        case "storage-cost":
            return `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where x_ResourceType =~ 'microsoft.storage/storageaccounts'
| where ConsumedUnit in~ ('Units','Units/Hour','GB','GB/Month','Units/Month')`;
        case "capacity-reservation-cost":
            return `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where isnotempty(CapacityReservationId)
| where CapacityReservationStatus in~ ('Used','Unused')
| where ConsumedUnit =~ 'Hours'`;
        case "premium-ssd-cost":
            return `| where ProviderName =~ 'Microsoft' and ChargeCategory =~ 'Usage'
| where x_ResourceType =~ 'microsoft.compute/disks'`;
        default:
            throw new Error(`Unsupported capacity demand predicate '${predicateId}'.`);
    }
}

function exactWhere(selection, fields) {
    if (!selection || typeof selection !== "object" || Array.isArray(selection)) {
        throw new Error("A structured capacity selection is required.");
    }
    return fields.map(([selectionName, column]) => {
        const value = selection[selectionName];
        return `| where ${column} =~ ${kqlString(value, selectionName)}`;
    }).join("\n");
}

export function buildCapacityHomeQuery() {
    return `Quota()
| where x_SourceType in~ (${CAPACITY_SOURCE_TYPES.map((value) => JSON.stringify(value)).join(", ")})
| summarize
    Observations=count(),
    Resources=dcount(ResourceId),
    DistinctDays=dcount(startofday(x_IngestionTime)),
    LatestObservation=max(x_IngestionTime)
    by x_SourceType
| order by x_SourceType asc
| take 7`;
}

export function buildCapacitySchemaQuery(source) {
    if (source === "Quota") {
        return `Quota() | getschema | project ColumnName, ColumnType | order by ColumnName asc | take 200`;
    }
    if (source === "Costs") {
        return `Costs() | getschema | project ColumnName, ColumnType | order by ColumnName asc | take 500`;
    }
    throw new Error(`Unsupported schema source '${source}'.`);
}

export function buildCapacityCoverageQuery(classId, filters = {}) {
    const contract = capacityClass(classId);
    const where = buildCapacityWhere(filters);
    return `Quota()
| where x_SourceType =~ ${JSON.stringify(contract.sourceType)}
${where}
| summarize
    Observations=count(),
    Resources=dcount(ResourceId),
    DistinctDays=dcount(startofday(x_IngestionTime)),
    FirstObservation=min(x_IngestionTime),
    LastObservation=max(x_IngestionTime),
    Units=make_set(unit, 64)`;
}

export function buildCapacityDemandCoverageQuery(classId, filters = {}) {
    const contract = capacityClass(classId);
    const costWhere = buildCapacityWhere(filters, "cost");
    return `Costs()
| where ChargePeriodStart >= startofday(now()-430d)
${demandPredicate(contract.demandPredicateId)}
${costWhere}
| summarize
    Observations=count(),
    DistinctDays=dcount(startofday(ChargePeriodStart)),
    FirstObservation=min(ChargePeriodStart),
    LastObservation=max(ChargePeriodStart),
    Units=make_set(ConsumedUnit, 64)`;
}

export function buildCapacityCurrentQuery(classId, filters = {}) {
    const contract = capacityClass(classId);
    const where = buildCapacityWhere(filters);
    return `Quota()
| where x_SourceType =~ ${JSON.stringify(contract.sourceType)}
${where}
| summarize arg_max(x_IngestionTime, *) by ResourceId
| project ProviderName, ResourceId, ResourceName, ResourceType, SubAccountId, displayName, location, currentValue, limit, unit, x_SourceType, x_SourceVersion, x_IngestionTime
| order by SubAccountId asc, location asc, ResourceName asc
| take ${CAPACITY_LIMITS.primaryRows + 1}`;
}

export function buildCapacitySelectorQuery(classId, filters = {}) {
    const contract = capacityClass(classId);
    const where = buildCapacityWhere(filters);
    return `Quota()
| where x_SourceType =~ ${JSON.stringify(contract.sourceType)}
${where}
| summarize arg_max(x_IngestionTime, *) by ResourceId
| project SubAccountId, location, ResourceId, ResourceName, displayName, unit, x_SourceType, x_SourceVersion, x_IngestionTime
| order by SubAccountId asc, location asc, ResourceName asc
| take ${CAPACITY_LIMITS.selectorKeys + 1}`;
}

export function buildCapacityHistoryQuery(classId, selection) {
    const contract = capacityClass(classId);
    const identity = contract.evidenceClass === "inventory"
        ? exactWhere(selection, [["resourceId", "ResourceId"]])
        : exactWhere(selection, [
            ["subAccountId", "SubAccountId"],
            ["location", "location"],
            ["resourceName", "ResourceName"],
            ["unit", "unit"],
            ["sourceVersion", "x_SourceVersion"],
        ]);
    return `Quota()
| where x_SourceType =~ ${JSON.stringify(contract.sourceType)}
${identity}
| extend Day=startofday(x_IngestionTime)
| summarize arg_max(x_IngestionTime, *) by Day, ResourceId
| project Day, ResourceId, ResourceName, displayName, SubAccountId, location, currentValue, limit, unit, x_SourceType, x_SourceVersion, x_IngestionTime
| order by Day asc
| take ${CAPACITY_LIMITS.dailyPoints + 1}`;
}

export function buildCapacityHeatmapQuery(classId, selection, filters = {}) {
    const contract = capacityClass(classId);
    const where = buildCapacityWhere(filters);
    if (contract.evidenceClass === "inventory") {
        return `Quota()
| where x_SourceType =~ ${JSON.stringify(contract.sourceType)}
${where}
| summarize arg_max(x_IngestionTime, *) by ResourceId
| summarize
    ObservedObjects=count(),
    ObservedGiB=sum(currentValue),
    x_IngestionTime=max(x_IngestionTime)
    by SubAccountId, location, x_SourceType, x_SourceVersion
| order by SubAccountId asc, location asc
| take ${CAPACITY_LIMITS.heatmapCells + 1}`;
    }
    const metric = exactWhere(selection, [
        ["resourceName", "ResourceName"],
        ["unit", "unit"],
        ["sourceVersion", "x_SourceVersion"],
    ]);
    return `Quota()
| where x_SourceType =~ ${JSON.stringify(contract.sourceType)}
${metric}
${where}
| summarize arg_max(x_IngestionTime, *) by ResourceId
| project SubAccountId, location, ResourceId, ResourceName, currentValue, limit, unit, x_SourceType, x_SourceVersion, x_IngestionTime
| order by SubAccountId asc, location asc
| take ${CAPACITY_LIMITS.heatmapCells + 1}`;
}

export function buildCapacityDemandSelectorQuery(classId, filters = {}) {
    const contract = capacityClass(classId);
    const costWhere = buildCapacityWhere(filters, "cost");
    if (contract.id === "premium-ssd-v2") {
        return `let disks = Quota()
| where x_SourceType =~ 'PremiumSSDv2Disk'
${buildCapacityWhere(filters)}
| summarize arg_max(x_IngestionTime, *) by ResourceId
| extend JoinResourceId=tolower(ResourceId)
| project JoinResourceId, InventoryResourceId=ResourceId, DiskName=ResourceName, SubAccountId, location, SizeGiB=currentValue, x_IngestionTime;
let diskCost = Costs()
| where ChargePeriodStart >= startofday(now()-430d)
${demandPredicate(contract.demandPredicateId)}
${costWhere}
| extend JoinResourceId=tolower(ResourceId)
| summarize FirstDay=min(startofday(ChargePeriodStart)), LastDay=max(startofday(ChargePeriodStart)), EffectiveCost=sum(EffectiveCost), Rows=count()
    by JoinResourceId, ResourceId, x_SkuMeterCategory, x_SkuMeterSubcategory, SkuMeter, SkuPriceId, BillingCurrency;
disks
| join kind=leftouter diskCost on JoinResourceId
| project InventoryResourceId, DiskName, SubAccountId, location, SizeGiB, ResourceId, x_SkuMeterCategory, x_SkuMeterSubcategory, SkuMeter, SkuPriceId, BillingCurrency, FirstDay, LastDay, EffectiveCost, Rows, x_IngestionTime
| order by InventoryResourceId asc, BillingCurrency asc
| take ${CAPACITY_LIMITS.selectorKeys + 1}`;
    }

    const extraDimensions = contract.id === "capacity-reservations"
        ? ", CapacityReservationId, CapacityReservationStatus"
        : "";
    return `Costs()
| where ChargePeriodStart >= startofday(now()-430d)
${demandPredicate(contract.demandPredicateId)}
${costWhere}
| summarize
    FirstDay=min(startofday(ChargePeriodStart)),
    LastDay=max(startofday(ChargePeriodStart)),
    BilledQuantity=sum(ConsumedQuantity),
    EffectiveCost=sum(EffectiveCost),
    Rows=count()
    by x_SkuMeterCategory, x_SkuMeterSubcategory, SkuMeter, SkuPriceId, ConsumedUnit, BillingCurrency${extraDimensions}
| order by ConsumedUnit asc, x_SkuMeterSubcategory asc, SkuMeter asc
| take ${CAPACITY_LIMITS.selectorKeys + 1}`;
}

export function buildCapacityDemandHistoryQuery(classId, selection, filters = {}) {
    const contract = capacityClass(classId);
    const costWhere = buildCapacityWhere(filters, "cost");
    const commonSelection = exactWhere(selection, [
        ["meterCategory", "x_SkuMeterCategory"],
        ["meterSubcategory", "x_SkuMeterSubcategory"],
        ["meter", "SkuMeter"],
        ["priceId", "SkuPriceId"],
        ["currency", "BillingCurrency"],
    ]);
    if (contract.id === "premium-ssd-v2") {
        const disk = exactWhere(selection, [["resourceId", "ResourceId"]]);
        return `Costs()
| where ChargePeriodStart >= startofday(now()-430d)
${demandPredicate(contract.demandPredicateId)}
${costWhere}
${disk}
${commonSelection}
| summarize EffectiveCost=sum(EffectiveCost), Rows=count()
    by Day=startofday(ChargePeriodStart), ResourceId, x_SkuMeterCategory, x_SkuMeterSubcategory, SkuMeter, SkuPriceId, BillingCurrency
| order by Day asc
| take ${CAPACITY_LIMITS.dailyPoints + 1}`;
    }
    const quantitySelection = exactWhere(selection, [["unit", "ConsumedUnit"]]);
    const reservationSelection = contract.id === "capacity-reservations"
        ? exactWhere(selection, [
            ["capacityReservationId", "CapacityReservationId"],
            ["capacityReservationStatus", "CapacityReservationStatus"],
        ])
        : "";
    return `Costs()
| where ChargePeriodStart >= startofday(now()-430d)
${demandPredicate(contract.demandPredicateId)}
${costWhere}
${commonSelection}
${quantitySelection}
${reservationSelection}
| summarize BilledQuantity=sum(ConsumedQuantity), EffectiveCost=sum(EffectiveCost), Rows=count()
    by Day=startofday(ChargePeriodStart), x_SkuMeterCategory, x_SkuMeterSubcategory, SkuMeter, SkuPriceId, ConsumedUnit, BillingCurrency
| order by Day asc
| take ${CAPACITY_LIMITS.dailyPoints + 1}`;
}

export function buildCapacityReservationReconciliationQuery(filters = {}) {
    const quotaWhere = buildCapacityWhere(filters);
    const costWhere = buildCapacityWhere(filters, "cost");
    return `let inventory = Quota()
| where x_SourceType =~ 'CapacityReservation'
${quotaWhere}
| summarize arg_max(x_IngestionTime, *) by ResourceId
| extend GroupKey=tolower(ResourceId)
| project GroupKey, GroupResourceId=ResourceId, GroupName=ResourceName, SubAccountId, location, x_SourceVersion, x_IngestionTime;
let billed = Costs()
| where ChargePeriodStart >= startofday(now()-430d)
${demandPredicate("capacity-reservation-cost")}
${costWhere}
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
inventory
| join kind=fullouter billed on GroupKey
| extend ReconciliationState=case(
    isnotempty(GroupResourceId) and isnotempty(CostGroupResourceId), 'matched',
    isnotempty(GroupResourceId), 'inventory-only',
    'cost-only')
| project GroupResourceId=coalesce(GroupResourceId, CostGroupResourceId), GroupName, SubAccountId, location, BillingCurrency, UsedHours, UnusedHours, ReservationCount, LinkedResources, FirstDay, LastDay, x_SourceVersion, x_IngestionTime, ReconciliationState
| order by GroupResourceId asc, BillingCurrency asc
| take ${CAPACITY_LIMITS.primaryRows + 1}`;
}

function boundedCollection(rows, limit, overflowMode = "truncate") {
    const overflow = rows.length > limit;
    if (overflow && overflowMode === "disable") {
        return { status: "disabled", rows: [], limit, totalReturned: rows.length, truncated: false, reasonCode: "refine-filters" };
    }
    return {
        status: overflow ? "bounded" : "ready",
        rows: rows.slice(0, limit),
        limit,
        totalReturned: rows.length,
        truncated: overflow,
        reasonCode: overflow ? "result-cap-reached" : null,
    };
}

function annotateCapacityRows(rows, now) {
    return rows.map((row) => ({ ...row, semantic: classifyCapacityObservation(row, now) }));
}

const QUOTA_REQUIRED_FIELDS = Object.freeze([
    "ResourceId",
    "ResourceName",
    "SubAccountId",
    "location",
    "currentValue",
    "limit",
    "unit",
    "x_SourceType",
    "x_SourceVersion",
    "x_IngestionTime",
]);

const COST_REQUIRED_FIELDS = Object.freeze([
    "ChargePeriodStart",
    "ProviderName",
    "ChargeCategory",
    "ResourceId",
    "SubAccountId",
    "RegionId",
    "x_ResourceType",
    "x_SkuMeterCategory",
    "x_SkuMeterSubcategory",
    "SkuMeter",
    "SkuPriceId",
    "EffectiveCost",
    "BillingCurrency",
]);

function requiredCostFields(classId) {
    if (classId === "premium-ssd-v2") return COST_REQUIRED_FIELDS;
    const fields = [...COST_REQUIRED_FIELDS, "ConsumedQuantity", "ConsumedUnit"];
    if (classId === "capacity-reservations") {
        fields.push("CapacityReservationId", "CapacityReservationStatus");
    }
    return fields;
}

function assessSchema(rows, requiredFields, source) {
    const availableNames = new Set(rows.map((row) => normalizeCapacityValue(row.ColumnName)));
    const missingFields = requiredFields.filter((field) => !availableNames.has(field.toLowerCase()));
    return {
        source,
        available: missingFields.length === 0,
        fields: rows.map((row) => ({ name: row.ColumnName, type: row.ColumnType })),
        requiredFields,
        missingFields,
        reasonCode: missingFields.length ? "required-source-field-unavailable" : null,
    };
}

function selectorMatches(row, selection, mapping) {
    return mapping.every(([selectionName, rowName]) =>
        normalizeCapacityValue(row[rowName]) === normalizeCapacityValue(selection?.[selectionName])
    );
}

function validateQuotaSelection(contract, selectors, selection, mode) {
    if (!selection) return;
    const mapping = contract.evidenceClass === "inventory"
        ? [["resourceId", "ResourceId"]]
        : mode === "metric"
            ? [["resourceName", "ResourceName"], ["unit", "unit"], ["sourceVersion", "x_SourceVersion"]]
            : [
                ["subAccountId", "SubAccountId"],
                ["location", "location"],
                ["resourceName", "ResourceName"],
                ["unit", "unit"],
                ["sourceVersion", "x_SourceVersion"],
            ];
    if (!selectors.some((row) => selectorMatches(row, selection, mapping))) {
        throw new Error("The selected quota key is not present in the bounded selector catalog.");
    }
}

function validateDemandSelection(classId, selectors, selection) {
    if (!selection) return;
    const common = [
        ["meterCategory", "x_SkuMeterCategory"],
        ["meterSubcategory", "x_SkuMeterSubcategory"],
        ["meter", "SkuMeter"],
        ["priceId", "SkuPriceId"],
        ["currency", "BillingCurrency"],
    ];
    const mapping = classId === "premium-ssd-v2"
        ? [["resourceId", "InventoryResourceId"], ...common]
        : classId === "capacity-reservations"
            ? [
                ...common,
                ["unit", "ConsumedUnit"],
                ["capacityReservationId", "CapacityReservationId"],
                ["capacityReservationStatus", "CapacityReservationStatus"],
            ]
            : [...common, ["unit", "ConsumedUnit"]];
    if (!selectors.some((row) => selectorMatches(row, selection, mapping))) {
        throw new Error("The selected demand key is not present in the bounded selector catalog.");
    }
}

export async function getCapacity(clusterUri, database, classId = "home", options = {}) {
    const normalizedClassId = normalizeCapacityClassId(classId);
    const generatedAt = new Date();
    const quotaSchemaRows = await runQuery(clusterUri, database, buildCapacitySchemaQuery("Quota"));
    const quotaSchema = assessSchema(quotaSchemaRows, QUOTA_REQUIRED_FIELDS, "Quota");

    if (normalizedClassId === "home") {
        const rows = quotaSchema.available
            ? await runQuery(clusterUri, database, buildCapacityHomeQuery())
            : [];
        const bySource = new Map(rows.map((row) => [normalizeCapacityValue(row.x_SourceType), row]));
        return {
            classId: "home",
            classes: Object.values(CAPACITY_CLASS_REGISTRY).map((contract) => ({
                ...contract,
                capability: quotaSchema.available
                    ? { mode: "descriptive-only", reasonCode: "class-evidence-index", evidenceLabel: contract.evidenceLabel }
                    : { mode: "disabled", reasonCode: quotaSchema.reasonCode, evidenceLabel: "Quota source fields are unavailable" },
                summary: bySource.get(contract.sourceType.toLowerCase()) ?? {
                    x_SourceType: contract.sourceType,
                    Observations: 0,
                    Resources: 0,
                    DistinctDays: 0,
                    LatestObservation: null,
                },
            })),
            schema: { quota: quotaSchema },
            generatedAt: generatedAt.toISOString(),
        };
    }

    const contract = capacityClass(normalizedClassId);
    const filters = options.filters ?? {};
    const costSchemaRows = await runQuery(clusterUri, database, buildCapacitySchemaQuery("Costs"));
    const costSchema = assessSchema(costSchemaRows, requiredCostFields(normalizedClassId), "Costs");
    const baseQueries = {};
    if (quotaSchema.available) {
        baseQueries.current = buildCapacityCurrentQuery(normalizedClassId, filters);
        baseQueries.selectors = buildCapacitySelectorQuery(normalizedClassId, filters);
        baseQueries.coverage = buildCapacityCoverageQuery(normalizedClassId, filters);
    }
    if (costSchema.available && (normalizedClassId !== "premium-ssd-v2" || quotaSchema.available)) {
        baseQueries.demandSelectors = buildCapacityDemandSelectorQuery(normalizedClassId, filters);
        baseQueries.demandCoverage = buildCapacityDemandCoverageQuery(normalizedClassId, filters);
    }

    const baseEntries = Object.entries(baseQueries);
    const baseResults = await Promise.all(baseEntries.map(([, query]) => runQuery(clusterUri, database, query)));
    const data = Object.fromEntries(baseEntries.map(([key], index) => [key, baseResults[index]]));
    data.current ??= [];
    data.selectors ??= [];
    data.demandSelectors ??= [];

    validateQuotaSelection(contract, data.selectors, options.quotaSelection, "series");
    validateQuotaSelection(contract, data.selectors, options.metricSelection, "metric");
    validateDemandSelection(normalizedClassId, data.demandSelectors, options.demandSelection);

    const selectedQueries = {};
    if (quotaSchema.available && options.quotaSelection) {
        selectedQueries.history = buildCapacityHistoryQuery(normalizedClassId, options.quotaSelection);
    }
    if (quotaSchema.available && (contract.evidenceClass === "inventory" || options.metricSelection)) {
        selectedQueries.heatmap = buildCapacityHeatmapQuery(normalizedClassId, options.metricSelection, filters);
    }
    if (costSchema.available && options.demandSelection) {
        selectedQueries.demandHistory = buildCapacityDemandHistoryQuery(normalizedClassId, options.demandSelection, filters);
    }
    if (quotaSchema.available && costSchema.available && normalizedClassId === "capacity-reservations") {
        selectedQueries.reconciliation = buildCapacityReservationReconciliationQuery(filters);
    }

    const selectedEntries = Object.entries(selectedQueries);
    const selectedResults = await Promise.all(selectedEntries.map(([, query]) => runQuery(clusterUri, database, query)));
    Object.assign(data, Object.fromEntries(selectedEntries.map(([key], index) => [key, selectedResults[index]])));

    const currentRows = annotateCapacityRows(data.current, generatedAt);
    const heatmapRows = data.heatmap
        ? (contract.evidenceClass === "inventory" ? data.heatmap : annotateCapacityRows(data.heatmap, generatedAt))
        : [];
    const distinctHistoryDays = new Set((data.history ?? []).map((row) => String(row.Day))).size;
    const historyBounds = data.history
        ? boundedCollection(data.history, CAPACITY_LIMITS.dailyPoints, "disable")
        : null;
    const table = boundedCollection(currentRows, CAPACITY_LIMITS.primaryRows);
    const selectorBounds = boundedCollection(data.selectors, CAPACITY_LIMITS.selectorKeys);
    const demandSelectorBounds = boundedCollection(data.demandSelectors, CAPACITY_LIMITS.selectorKeys);
    const seriesBounds = data.demandHistory
        ? boundedCollection(data.demandHistory, CAPACITY_LIMITS.dailyPoints, "disable")
        : null;
    const heatmapBounds = data.heatmap
        ? boundedCollection(heatmapRows, CAPACITY_LIMITS.heatmapCells, "disable")
        : null;
    if (heatmapBounds?.status === "disabled") heatmapBounds.status = "heatmap-disabled";
    const coverageRow = data.coverage?.[0] ?? {};
    const demandCoverageRow = data.demandCoverage?.[0] ?? {};
    const enabledRows = currentRows.filter((row) => row.semantic.capability === "enabled").length;
    const classCapability = !quotaSchema.available
        ? { mode: "disabled", reasonCode: quotaSchema.reasonCode, evidenceLabel: "Quota source fields are unavailable" }
        : enabledRows > 0 && normalizedClassId === "compute"
            ? { mode: "enabled", reasonCode: "registered-metrics-present", evidenceLabel: contract.evidenceLabel }
            : { mode: "descriptive-only", reasonCode: "fail-closed-class-view", evidenceLabel: contract.evidenceLabel };
    const firstHistory = data.history?.[0]?.Day ?? null;
    const lastHistory = data.history?.at(-1)?.Day ?? null;
    const meterKey = options.demandSelection
        ? [
            options.demandSelection.meterCategory,
            options.demandSelection.meterSubcategory,
            options.demandSelection.meter,
            options.demandSelection.priceId,
            options.demandSelection.unit,
            options.demandSelection.currency,
        ].map((value) => String(value ?? "").trim()).join("|")
        : null;

    return {
        classId: normalizedClassId,
        contract,
        capability: classCapability,
        coverage: {
            state: Number(coverageRow.Observations ?? 0) > 0 ? "observed" : "no-evidence",
            reasonCode: Number(coverageRow.Observations ?? 0) > 0 ? null : "collection-outcome-unknown",
            observations: Number(coverageRow.Observations ?? 0),
            resources: Number(coverageRow.Resources ?? 0),
            distinctDays: Number(coverageRow.DistinctDays ?? 0),
            firstObservation: coverageRow.FirstObservation ?? null,
            lastObservation: coverageRow.LastObservation ?? null,
            units: coverageRow.Units ?? [],
        },
        schema: { quota: quotaSchema, costs: costSchema },
        table: { ...table, rowLimit: CAPACITY_LIMITS.primaryRows },
        current: table,
        selectors: { ...selectorBounds, items: selectorBounds.rows, itemLimit: CAPACITY_LIMITS.selectorKeys },
        history: historyBounds
            ? {
                ...historyBounds,
                points: historyBounds.rows,
                pointLimit: CAPACITY_LIMITS.dailyPoints,
                ...resolveCapacityHistoryCapability(distinctHistoryDays, contract),
                distinctDays: distinctHistoryDays,
                firstDate: firstHistory,
                lastDate: lastHistory,
            }
            : {
                status: quotaSchema.available ? "no-selection" : "disabled",
                mode: "unavailable",
                reasonCode: quotaSchema.available ? "select-exact-series" : quotaSchema.reasonCode,
                rows: [],
                points: [],
                pointLimit: CAPACITY_LIMITS.dailyPoints,
                distinctDays: 0,
                firstDate: null,
                lastDate: null,
            },
        heatmap: heatmapBounds ?? {
            status: quotaSchema.available ? "no-selection" : "heatmap-disabled",
            rows: [],
            limit: CAPACITY_LIMITS.heatmapCells,
            reasonCode: quotaSchema.available ? "select-exact-metric" : quotaSchema.reasonCode,
        },
        series: seriesBounds
            ? {
                ...seriesBounds,
                points: seriesBounds.rows,
                pointLimit: CAPACITY_LIMITS.dailyPoints,
                unit: options.demandSelection?.unit ?? null,
                meterKey,
            }
            : {
                status: costSchema.available ? "no-selection" : "disabled",
                rows: [],
                points: [],
                pointLimit: CAPACITY_LIMITS.dailyPoints,
                unit: null,
                meterKey: null,
                reasonCode: costSchema.available ? "select-exact-series" : costSchema.reasonCode,
            },
        demand: {
            contract: CAPACITY_DEMAND_REGISTRY[normalizedClassId],
            capability: costSchema.available
                ? { mode: "parallel", reasonCode: "billed-demand-evidence", evidenceLabel: CAPACITY_DEMAND_REGISTRY[normalizedClassId].label }
                : { mode: "disabled", reasonCode: costSchema.reasonCode, evidenceLabel: "Required cost source fields are unavailable" },
            coverage: {
                state: Number(demandCoverageRow.Observations ?? 0) > 0 ? "observed" : "no-evidence",
                reasonCode: Number(demandCoverageRow.Observations ?? 0) > 0 ? null : "no-billed-demand-evidence",
                observations: Number(demandCoverageRow.Observations ?? 0),
                distinctDays: Number(demandCoverageRow.DistinctDays ?? 0),
                firstObservation: demandCoverageRow.FirstObservation ?? null,
                lastObservation: demandCoverageRow.LastObservation ?? null,
                units: demandCoverageRow.Units ?? [],
            },
            selectors: { ...demandSelectorBounds, items: demandSelectorBounds.rows, itemLimit: CAPACITY_LIMITS.selectorKeys },
            history: seriesBounds ?? { status: "no-selection", rows: [], reasonCode: "select-exact-series" },
        },
        reconciliation: data.reconciliation
            ? boundedCollection(data.reconciliation, CAPACITY_LIMITS.primaryRows)
            : null,
        generatedAt: generatedAt.toISOString(),
    };
}



/**
 * Run all dashboard queries in parallel for the resolved window and shape the
 * result into a single payload the renderer consumes.
 */
export async function getDashboard(clusterUri, database, preset = "all", filters = {}) {
    const win = await resolveWindow(clusterUri, database, preset);
    if (win.empty) {
        return { window: win, empty: true, generatedAt: new Date().toISOString() };
    }

    const filterWhere = buildFilterWhere(filters);
    const period = `| where ChargePeriodStart >= datetime(${win.start}) and ChargePeriodStart < datetime(${win.end})${filterWhere}`;

    const queries = {
        // KPI totals — Understand Usage & Cost + Quantify Business Value
        summary: `Costs() ${period} | summarize Billed=sum(BilledCost), Effective=sum(EffectiveCost), List=sum(ListCost), Contracted=sum(ContractedCost), Resources=dcount(ResourceId), Services=dcount(ServiceName), Subscriptions=dcount(SubAccountId), Regions=dcount(RegionId), Rows=count()`,
        // Allocation KPI — percentage-untagged-costs
        tagged: `Costs() ${period} | extend _t=iff(isnull(Tags) or array_length(bag_keys(Tags))==0,'Untagged','Tagged') | summarize Cost=sum(EffectiveCost) by _t`,
        // Rate Optimization — commitment coverage (Committed vs Standard pricing)
        pricing: `Costs() ${period} | summarize Cost=sum(EffectiveCost) by PricingCategory`,
        // Reporting & Analytics — monthly-cost-trend (Billed vs Effective)
        trend: `Costs() ${period} | summarize Billed=sum(BilledCost), Effective=sum(EffectiveCost) by Month=format_datetime(startofmonth(ChargePeriodStart),'yyyy-MM') | order by Month asc`,
        // Understand Usage & Cost — cost by service category
        serviceCategory: `Costs() ${period} | summarize Cost=sum(EffectiveCost) by ServiceCategory | where Cost > 0 | order by Cost desc`,
        // top-services-by-cost
        topServices: `Costs() ${period} | summarize Cost=sum(EffectiveCost) by ServiceName | top 10 by Cost desc`,
        // top-resource-groups-by-cost
        topResourceGroups: `Costs() ${period} | where isnotempty(x_ResourceGroupName) | summarize Cost=sum(EffectiveCost) by x_ResourceGroupName | top 10 by Cost desc`,
        // cost-by-region-trend (top regions by cost)
        topRegions: `Costs() ${period} | where isnotempty(RegionId) | summarize Cost=sum(EffectiveCost) by RegionId | top 12 by Cost desc`,
        // Charge category mix (Usage / Purchase / Adjustment)
        chargeCategory: `Costs() ${period} | summarize Cost=sum(EffectiveCost) by ChargeCategory | where Cost != 0 | order by Cost desc`,
        // macc-consumption-vs-commitment — MACC burn rate (graceful: returns CommitmentAmount=0 if no MACC data)
        macc: `let con = toscalar(Costs() ${period} | where not(ChargeCategory == 'Purchase' and isnotempty(CommitmentDiscountCategory)) | summarize sum(EffectiveCost));
let com = toscalar(Transactions() | where isnotnull(x_MonetaryCommitment) | summarize sum(x_MonetaryCommitment));
let com0 = coalesce(todouble(com), 0.0);
print ConsumptionAmount=con, CommitmentAmount=com0, CommitmentBurnPercent=iff(com0 > 0, con / com0 * 100.0, 0.0)`,
    };

    const entries = Object.entries(queries);
    const results = await Promise.all(
        entries.map(([, csl]) => runQuery(clusterUri, database, csl))
    );
    const data = Object.fromEntries(entries.map(([key], i) => [key, results[i]]));

    return {
        window: win,
        empty: false,
        data,
        generatedAt: new Date().toISOString(),
    };
}

// --- tokenomics (AI / Azure OpenAI token economics) ---------------------------
//
// Grounded in the FinOps toolkit AI query catalog (ai-token-usage-breakdown,
// ai-model-cost-comparison, ai-daily-trend) and the FinOps Foundation
// "Token Consumption Metrics" KPI (Cost per Token = Total Cost / Tokens Used).
//
// Token meters are scoped to Azure OpenAI subcategories whose SKU description
// is denominated in tokens, which excludes non-token AI meters (image/media,
// Cognitive Search). ConsumedQuantity is the token count per the catalog.
const AI_SCOPE = `| where x_SkuMeterSubcategory has 'OpenAI' and x_SkuDescription contains 'Token'`;

// Direction: descriptions use abbreviations (Inp / Outp / cached Inp), so the
// canonical contains "Input"/"Output" test is replaced with term/substring
// matching that also splits cached input out as its own (cheaper) bucket.
const DIRECTION = `extend Direction = case(
    x_SkuDescription has 'Outp' or x_SkuDescription contains 'Output', 'Output',
    x_SkuDescription contains 'cached', 'Cached input',
    x_SkuDescription has 'Inp' or x_SkuDescription contains 'Input', 'Input',
    'Other')`;

// Collapse verbose SKU descriptions to a clean model family, e.g.
// "Azure OpenAI - gpt 4.1 cached Inp glbl Tokens - US East 2" -> "GPT 4.1".
const MODEL_FAMILY = `extend Model = x_SkuDescription
| extend Model = replace_regex(Model, @'^Azure OpenAI(?: GPT5)?\\s*-\\s*', '')
| extend Model = replace_regex(Model, @'(?i)[\\s-]+(cached[\\s-]+)?(inp|inpt|outp|out|chat|media)([\\s-].*)?$', '')
| extend Model = replace_regex(trim(@'[\\s-]+', Model), @'(?i)^gpt', 'GPT')`;

export async function getTokenomics(clusterUri, database, preset = "all", filters = {}) {
    const win = await resolveWindow(clusterUri, database, preset);
    if (win.empty) {
        return { window: win, empty: true, generatedAt: new Date().toISOString() };
    }
    const filterWhere = buildFilterWhere(filters);
    const period = `| where ChargePeriodStart >= datetime(${win.start}) and ChargePeriodStart < datetime(${win.end})${filterWhere}`;

    const queries = {
        // Token KPI totals — Token Consumption Metrics. Models is collapsed
        // through the same MODEL_FAMILY normalization as the "models" query
        // below, so "Models in use" counts distinct model families, not raw
        // (and often duplicated) billing-SKU description strings.
        summary: `Costs() ${period} ${AI_SCOPE} | ${MODEL_FAMILY} | summarize Tokens=sum(ConsumedQuantity), Effective=sum(EffectiveCost), List=sum(ListCost), Models=dcount(Model), Resources=dcount(ResourceId), Rows=count()`,
        // Total cloud effective cost in the window — for AI share-of-spend
        totalCloud: `Costs() ${period} | summarize Effective=sum(EffectiveCost)`,
        // ai-token-usage-breakdown — direction mix (input/cached/output)
        direction: `Costs() ${period} ${AI_SCOPE} | ${DIRECTION} | summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost) by Direction`,
        // ai-model-cost-comparison — by model family with cost per 1K tokens
        models: `Costs() ${period} ${AI_SCOPE} | ${MODEL_FAMILY} | summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost), List=sum(ListCost) by Model | extend CostPer1K=iff(Tokens==0, 0.0, Cost/Tokens*1000) | top 12 by Cost desc`,
        // ai-daily-trend (monthly variant) — token volume + AI cost over time
        trend: `Costs() ${period} ${AI_SCOPE} | summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost) by Month=format_datetime(startofmonth(ChargePeriodStart),'yyyy-MM') | order by Month asc`,
        // ai-cost-by-application — AI cost showback by app/team/env/cost-center
        byApplication: `Costs() ${period} ${AI_SCOPE}
| extend Application = tostring(Tags['application']), Team = tostring(Tags['team'])
| extend CostCenter = coalesce(tostring(Tags['cost-center']), tostring(Tags['CostCenter']), '')
| extend Environment = tostring(Tags['environment'])
| summarize TokenCount=sum(ConsumedQuantity), EffectiveCost=sum(EffectiveCost)
    by Application, Team, CostCenter, Environment
| extend CostPer1KTokens = iff(TokenCount == 0, 0.0, EffectiveCost / TokenCount * 1000)
| top 12 by EffectiveCost desc`,
    };

    const entries = Object.entries(queries);
    const results = await Promise.all(entries.map(([, csl]) => runQuery(clusterUri, database, csl)));
    const data = Object.fromEntries(entries.map(([key], i) => [key, results[i]]));

    const tokenRows = data.summary?.[0]?.Rows ?? 0;
    return {
        window: win,
        empty: tokenRows === 0,
        data,
        generatedAt: new Date().toISOString(),
    };
}

// --- shared page runner -------------------------------------------------------
// Resolves the window, builds a named map of KQL queries from the period clause,
// runs them in parallel, and returns { window, empty, data, generatedAt }.
async function runPage(clusterUri, database, preset, buildQueries, filters = {}) {
    const win = await resolveWindow(clusterUri, database, preset);
    if (win.empty) return { window: win, empty: true, generatedAt: new Date().toISOString() };
    const filterWhere = buildFilterWhere(filters);
    const period = `| where ChargePeriodStart >= datetime(${win.start}) and ChargePeriodStart < datetime(${win.end})${filterWhere}`;
    const queries = buildQueries(period, win);
    const entries = Object.entries(queries);
    const results = await Promise.all(entries.map(([, csl]) => runQuery(clusterUri, database, csl)));
    const data = Object.fromEntries(entries.map(([key], i) => [key, results[i]]));
    return { window: win, empty: false, data, generatedAt: new Date().toISOString() };
}

// --- Allocation page ----------------------------------------------------------
// FinOps "Allocation" capability. Grounded in catalog queries:
// percentage-untagged-costs, percentage-unallocated-costs, tagging-policy-compliance,
// allocation-accuracy-index, cost-by-financial-hierarchy. Tag policy keys are tuned
// to this estate's taxonomy (CostCenter/env/org); allocation evidence also honours
// the enriched x_CostCenter / x_CostAllocationRuleName columns.
const NON_PURCHASE = `| where not(ChargeCategory == 'Purchase' and isnotempty(CommitmentDiscountCategory))`;

export async function getAllocation(clusterUri, database, preset = "all", filters = {}) {
    return runPage(clusterUri, database, preset, (period) => ({
        // Single-pass core: total, untagged, attributed (AAI), compliant
        core: `let req=dynamic(['CostCenter','env','org']);
let ev=dynamic(['cost-center','team','owner','application','product','CostCenter','org','env','Project']);
Costs() ${period} ${NON_PURCHASE}
| extend tk=coalesce(bag_keys(Tags), dynamic([]))
| extend isUntagged = array_length(tk)==0
| extend hasEvidence = isnotempty(x_CostAllocationRuleName) or isnotempty(x_CostCenter) or array_length(set_intersect(tk,ev))>0
| extend isCompliant = array_length(set_intersect(tk,req))==array_length(req)
| summarize Total=sum(EffectiveCost), Untagged=sumif(EffectiveCost,isUntagged), Attributed=sumif(EffectiveCost,hasEvidence), Compliant=sumif(EffectiveCost,isCompliant), Subs=dcount(SubAccountId)`,
        // cost-by-financial-hierarchy (tuned to org/Project/env taxonomy)
        hierarchy: `Costs() ${period}
| extend Org=tostring(Tags['org']), Project=tostring(Tags['Project']), Env=tostring(Tags['env'])
| summarize Cost=sum(EffectiveCost) by Org, Project, Env
| where Cost > 0 | top 12 by Cost desc`,
        // Tag-key coverage — cost touched by each tag key. Excludes Azure/FTK
        // auto-injected tags (ftk-*, cm-*, costanalysis-parent, aks-managed-*)
        // so governance-relevant keys aren't crowded out by system noise.
        tagKeys: `Costs() ${period}
| mv-expand k=bag_keys(Tags) to typeof(string)
| where isnotempty(k) and k !in ('ftk-tool','ftk-version','cm-resource-parent','costanalysis-parent') and not(k startswith 'aks-managed-')
| summarize Cost=sum(EffectiveCost) by k
| top 12 by Cost desc`,
        // Cost by subscription (SubAccountName)
        bySubscription: `Costs() ${period} | where isnotempty(SubAccountName) | summarize Cost=sum(EffectiveCost) by SubAccountName | top 10 by Cost desc`,
    }), filters);
}

// --- Rate optimization page ---------------------------------------------------
// FinOps "Rate Optimization" capability. Grounded in catalog queries:
// savings-summary-report, commitment-discount-waste, compute-spend-commitment-coverage,
// commitment-discount-utilization. (cost-optimization-index/COIN is omitted because it
// depends on Recommendations(), which is empty in this estate, so it would always read 100.)
// Commitment utilization is derived as the effective-cost complement of waste, the cleanest
// single-basis definition for a grand-total KPI.
export async function getRate(clusterUri, database, preset = "all", filters = {}) {
    return runPage(clusterUri, database, preset, (period) => ({
        // savings-summary-report — ESR + negotiated/commitment/total savings
        savings: `Costs() ${period} ${NON_PURCHASE}
| extend neg=iff(ListCost<ContractedCost,real(0),ListCost-ContractedCost)
| extend com=iff(ContractedCost<EffectiveCost,real(0),ContractedCost-EffectiveCost)
| extend tot=iff(ListCost<EffectiveCost,real(0),ListCost-EffectiveCost)
| summarize List=sum(ListCost), Effective=sum(EffectiveCost), Negotiated=sum(neg), Commitment=sum(com), Total=sum(tot)`,
        // commitment-discount-waste (grand total, effective-cost basis)
        commitment: `Costs() ${period} | where isnotempty(CommitmentDiscountId) ${NON_PURCHASE}
| summarize Unused=sumif(EffectiveCost,CommitmentDiscountStatus=='Unused'), Total=sum(EffectiveCost)`,
        // compute-spend-commitment-coverage
        computeCoverage: `Costs() ${period} ${NON_PURCHASE} | where ServiceCategory=='Compute'
| summarize Committed=sumif(EffectiveCost,isnotempty(CommitmentDiscountCategory)), Contracted=sum(ContractedCost)`,
        // commitment-discount-utilization — consumed core-hours by commitment type
        coreHours: `Costs() ${period}
| extend cores=toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores, 0))
| extend ch=iff(cores>0, cores*ConsumedQuantity, toreal(''))
| extend t=iff(isempty(CommitmentDiscountType),'On Demand',CommitmentDiscountType)
| summarize CoreHours=sum(ch) by t | where CoreHours > 0 | order by CoreHours desc`,
        // Per-commitment waste — which reservations/plans are underutilized
        byCommitment: `Costs() ${period} | where isnotempty(CommitmentDiscountName) ${NON_PURCHASE}
| summarize Unused=sumif(EffectiveCost,CommitmentDiscountStatus=='Unused'), Total=sum(EffectiveCost) by CommitmentDiscountName
| where Unused > 0 | top 10 by Unused desc`,
        // commitment-utilization-score (formal KPI) — per-commitment and grand-total utilization score
        commitmentUtilScore: `let rows = materialize(Costs() ${period} | where isnotempty(CommitmentDiscountId)
| extend Potential = case(ChargeCategory == 'Purchase', toreal(0), isnotempty(CommitmentDiscountCategory), toreal(EffectiveCost), toreal(0))
| extend Amount = iff(CommitmentDiscountStatus == 'Used', Potential, toreal(0)));
let byCommit = rows | summarize Amount=sum(Amount), Potential=sum(Potential) by CommitmentDiscountName, CommitmentDiscountCategory, CommitmentDiscountType
| extend Score = iff(Potential > 0, Amount / Potential * 100.0, 0.0);
union byCommit, (byCommit | summarize Amount=sum(Amount), Potential=sum(Potential)
| extend CommitmentDiscountName='(Grand Total)', CommitmentDiscountCategory='', CommitmentDiscountType='', Score=iff(Potential>0, Amount/Potential*100.0, 0.0))
| project CommitmentDiscountName, CommitmentDiscountCategory, CommitmentDiscountType, Amount, Potential, Score | order by Potential desc`,
        // top-commitment-transactions — largest RI/SP purchases
        topCommitmentTxns: `Costs() ${period} | where ChargeCategory != 'Usage' and isnotempty(CommitmentDiscountType) and BilledCost > 0
| summarize BilledCost=sum(BilledCost), EffectiveCost=sum(EffectiveCost)
    by CommitmentDiscountName, CommitmentDiscountType, CommitmentDiscountCategory
| top 10 by BilledCost desc`,
    }), filters);
}

// --- Usage & unit economics page ----------------------------------------------
// FinOps "Usage Optimization" + "Unit Economics". Grounded in catalog queries:
// compute-cost-per-core, cost-per-gb-stored, storage-tier-distribution, top-resource-types-by-cost.
export async function getUsage(clusterUri, database, preset = "all", filters = {}) {
    return runPage(clusterUri, database, preset, (period) => ({
        // compute-cost-per-core
        compute: `Costs() ${period} ${NON_PURCHASE}
| extend vm = x_SkuMeterCategory in ('Virtual Machines','Virtual Machine Licenses') and ChargeCategory=='Usage'
| extend isComputeCommit = x_SkuMeterCategory in ('Virtual Machines','Virtual Machine Licenses')
| extend cores = iff(vm, toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores)), toint(''))
| extend ch = iff(vm and isnotempty(cores), toreal(cores*ConsumedQuantity), toreal(''))
| summarize ComputeEff=sumif(EffectiveCost,vm), UnusedCommit=sumif(EffectiveCost, CommitmentDiscountStatus=='Unused' and isnotempty(CommitmentDiscountCategory) and isComputeCommit), CoreHours=sum(ch)`,
        // cost-per-gb-stored
        storage: `Costs() ${period} | where ServiceCategory=='Storage' and ChargeCategory=='Usage'
| extend gb = case(ConsumedUnit endswith 'PB', toreal(ConsumedQuantity)*1048576.0, ConsumedUnit endswith 'TB', toreal(ConsumedQuantity)*1024.0, ConsumedUnit endswith 'MB', toreal(ConsumedQuantity)/1024.0, toreal(ConsumedQuantity))
| summarize Cost=sum(EffectiveCost), GBMonths=sum(gb)`,
        // storage-tier-distribution
        storageTiers: `Costs() ${period} | where ServiceCategory=='Storage' and ChargeCategory=='Usage'
| extend Tier = case(
    x_SkuTier in ('Hot','Standard','Premium'), 'Frequent',
    x_SkuTier in ('Cool','Cold','Archive'), 'Infrequent',
    x_SkuMeterSubcategory has_any ('Hot','Standard','Premium','Frequent'), 'Frequent',
    x_SkuMeterSubcategory has_any ('Cool','Cold','Archive'), 'Infrequent',
    'Unclassified')
| summarize Cost=sum(EffectiveCost) by Tier | where Cost > 0 | order by Cost desc`,
        // top-resource-types-by-cost — Resources is a distinct-resource count
        // (dcount(ResourceId)), matching the same "Resources" label semantics
        // used by the Overview summary KPI, not a row count.
        topResourceTypes: `Costs() ${period} | where isnotempty(ResourceType) | summarize Resources=dcount(ResourceId), Cost=sum(EffectiveCost) by ResourceType | top 10 by Cost desc`,
        // compute-cost-per-core grouped by VM series — where the expensive cores are
        perCoreSeries: `Costs() ${period} | where x_SkuMeterCategory in ('Virtual Machines','Virtual Machine Licenses') and ChargeCategory=='Usage'
| extend cores=toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores))
| extend ch=iff(isnotempty(cores), toreal(cores*ConsumedQuantity), toreal(''))
| summarize Eff=sum(EffectiveCost), CH=sum(ch) by x_SkuMeterSubcategory
| where CH > 100 | extend PerCore=Eff/CH | top 10 by Eff desc`,
        // grand total for share-of-cost on the resource-type table
        total: `Costs() ${period} | summarize Total=sum(EffectiveCost)`,
    }), filters);
}

// --- Anomalies & forecast page ------------------------------------------------
// FinOps "Anomaly Management" + "Forecasting" + data-freshness (Data Ingestion).
// Grounded in catalog queries: cost-anomaly-detection, anomaly-detection-rate,
// anomaly-variance-total, monthly-cost-change-percentage, cost-forecasting-model,
// data-update-frequency, cost-visibility-delay. Time-series array outputs are
// flattened with mv-expand so the renderer can chart them.
export async function getAnomaly(clusterUri, database, preset = "all", filters = {}) {
    return runPage(clusterUri, database, preset, (period, win) => {
        // forecast uses full history for accuracy; horizon = 4 months past the last data month
        const dmax = new Date(win.dataMax);
        const monthStart = new Date(Date.UTC(dmax.getUTCFullYear(), dmax.getUTCMonth(), 1));
        const horizon = new Date(Date.UTC(dmax.getUTCFullYear(), dmax.getUTCMonth() + 4, 1));
        const isoH = horizon.toISOString().slice(0, 10);
        const fcDays = Math.round((horizon - monthStart) / 86400000);
        return {
            // cost-anomaly-detection + anomaly-variance-total (flattened daily series)
            daily: `let s=datetime(${win.start}); let e=datetime(${win.end});
Costs() | where ChargePeriodStart>=s and ChargePeriodStart<e ${NON_PURCHASE}
| summarize DC=sum(EffectiveCost) by bin(ChargePeriodStart,1d)
| make-series Cost=sum(DC) default=0.0 on ChargePeriodStart from s to e step 1d
| extend (flag,score,baseline)=series_decompose_anomalies(Cost,1.5)
| mv-expand Day=ChargePeriodStart to typeof(datetime), Cost to typeof(real), flag to typeof(real), baseline to typeof(real)
| project Day, Cost=toreal(Cost), Flag=toint(flag), Baseline=toreal(baseline)`,
            // monthly-cost-change-percentage
            monthlyChange: `Costs() ${period} | summarize Eff=sum(EffectiveCost) by M=startofmonth(ChargePeriodStart)
| order by M asc | extend PrevEff=prev(Eff)
| project Month=format_datetime(M,'yyyy-MM'), EffChangePct=iff(isempty(PrevEff),0.0,(Eff-PrevEff)*100.0/PrevEff), Eff`,
            // cost-forecasting-model (monthly, forecasts past the last data month)
            forecast: `let s=datetime(${win.dataMin}); Costs() | where ChargePeriodStart>=s
| summarize Eff=sum(EffectiveCost) by bin(ChargePeriodStart,1d)
| make-series Actual=sum(Eff) default=0.0 on ChargePeriodStart from s to datetime(${isoH}) step 1d
| extend Fc=series_decompose_forecast(Actual,${fcDays})
| mv-expand Day=ChargePeriodStart to typeof(datetime), Actual to typeof(real), Fc to typeof(real)
| extend M=startofmonth(Day)
| summarize Actual=sum(toreal(Actual)), Forecast=sum(toreal(Fc)) by M
| order by M asc | project Month=format_datetime(M,'yyyy-MM'), Actual, Forecast`,
            // data-update-frequency + cost-visibility-delay
            freshness: `Costs() ${period} | where isnotnull(x_IngestionTime)
| summarize LastUpdate=max(x_IngestionTime), Rows=count(), P50=percentile(todouble((x_IngestionTime-ChargePeriodEnd)/1h),50), P90=percentile(todouble((x_IngestionTime-ChargePeriodEnd)/1h),90)`,
        };
    }, filters);
}

// --- AI & emerging workloads page ---------------------------------------------
// The 2026 FinOps "AI as a Technology Scope" view: the whole AI/ML estate, not
// just tokens. Tokenomics (above) drills into Azure OpenAI token unit economics;
// this page covers foundation models, cognitive services, the ML platform, AI
// Search / retrieval, and GPU-accelerated compute together.
//
// GPU detection is a case-insensitive regex over the concatenated service and
// SKU text, so N-series capacity billed through Virtual Machines or Virtual
// Machine Scale Sets is attributed to the AI estate even though its
// ServiceCategory is Compute. The regex replaces the equivalent toupper()
// form to keep case handling out of comparison position.
const AI_GPU = `strcat(' ', ServiceName, ' ', x_SkuMeterCategory, ' ', x_SkuMeterSubcategory, ' ', x_SkuInstanceType, ' ', tostring(SkuMeter), ' ') matches regex @'(?i)(^|[^a-z0-9])(nc|nd|nv|ng)[a-z0-9_\\-]*'`;

// The AI/ML estate: the declared FOCUS service category, plus two services that
// sit outside it but are unambiguously AI workloads, plus GPU compute.
const AI_ESTATE = `| where ServiceCategory == 'AI and Machine Learning' or ServiceName in ('Azure AI Search', 'Azure Databricks') or (${AI_GPU})`;

// Token meters on this page are scoped by meter category rather than the
// tokenomics page's SKU-description test, so Foundry-billed models beyond
// Azure OpenAI (Deepseek, Phi, and later additions) are counted too.
const AI_TOKENS = `x_SkuMeterCategory == 'Foundry Models' and PricingUnit == 'Units'`;

// Capability taxonomy, ordered most specific first: GPU wins over service name
// because N-series capacity bills through generic Compute services.
const AI_CAPABILITY = `extend Capability = case(
    _gpu, 'GPU / accelerated compute',
    x_SkuMeterCategory == 'Foundry Models' or x_SkuMeterSubcategory has_any ('OpenAI', 'Deepseek', 'GPT'), 'Foundation models (LLM)',
    ServiceName == 'Azure AI Search', 'AI Search / retrieval',
    ServiceName == 'Azure Machine Learning', 'ML platform & compute',
    ServiceName == 'Azure Databricks', 'ML / analytics platform',
    ServiceName == 'Azure AI Video Indexer' or x_SkuMeterSubcategory has_any ('Vision', 'Speech', 'Translator', 'Content Understanding', 'Video Indexer', 'Bing', 'Content Safety', 'Phi'), 'Cognitive services',
    ServiceName == 'Azure AI Bot Service', 'Bot & agents',
    'Other AI/ML')`;

// Tag keys that evidence an owning application or team. Allocation coverage is
// reported per dimension rather than as one blended score, so a gap in tagging
// stays distinguishable from a gap in cost-center enrichment.
const AI_APP_TAGS = `dynamic(['application', 'app', 'workload', 'product', 'service'])`;
const AI_OWNER_TAGS = `dynamic(['owner', 'team', 'createdby'])`;

/**
 * First day of the most recent *complete* month in the data.
 *
 * Ingestion usually stops mid-month, so the newest month in the window is
 * partial. Comparing it against a full prior month reports a collapse that is
 * an artifact of the ingestion cut-off, not a change in spend, so
 * month-over-month evidence is anchored to the last closed month instead.
 */
export function lastClosedMonthStart(dataMax) {
    if (!dataMax) return null;
    const max = new Date(dataMax);
    if (Number.isNaN(max.getTime())) return null;
    const monthStart = startOfMonthUTC(max);
    const lastDayOfMonth = new Date(addMonthsUTC(monthStart, 1).getTime() - 86400000);
    return isoDay(max) === isoDay(lastDayOfMonth) ? monthStart : addMonthsUTC(monthStart, -1);
}

export async function getAi(clusterUri, database, preset = "all", filters = {}) {
    let closedMonth = null;
    let built = null;
    const page = await runPage(clusterUri, database, preset, (period, win) => {
        closedMonth = lastClosedMonthStart(win.dataMax);
        // Fall back to the window start when the data is too short to contain a
        // closed month, so the driver comparison stays inside the window.
        const closedDay = isoDay(closedMonth ?? new Date(win.start));
        built = {
        // Single monthly rollup that powers both trend charts and every
        // month-over-month KPI, so the page costs one scan instead of the
        // five scalar round-trips the source dashboard used.
        monthly: `Costs() ${period}
| extend _gpu = ${AI_GPU}
| extend _ai = ServiceCategory == 'AI and Machine Learning' or ServiceName in ('Azure AI Search', 'Azure Databricks') or _gpu
| extend _tok = ${AI_TOKENS}
| summarize Cloud=sum(EffectiveCost), Estate=sumif(EffectiveCost, _ai), MlGpu=sumif(EffectiveCost, ServiceName == 'Azure Machine Learning' or _gpu),
    Tokens=sumif(ConsumedQuantity, _tok), TokenCost=sumif(EffectiveCost, _tok)
    by Month=format_datetime(startofmonth(ChargePeriodStart), 'yyyy-MM')
| order by Month asc`,
        // AI/ML estate by capability over time — stacked column source.
        capabilityTrend: `Costs() ${period} ${AI_ESTATE}
| extend _gpu = ${AI_GPU}
| ${AI_CAPABILITY}
| summarize Cost=sum(EffectiveCost) by Month=format_datetime(startofmonth(ChargePeriodStart), 'yyyy-MM'), Capability
| order by Month asc`,
        // Estate composition: cost, distinct services, and share per capability.
        capability: `Costs() ${period} ${AI_ESTATE}
| extend _gpu = ${AI_GPU}
| ${AI_CAPABILITY}
| summarize Cost=sum(EffectiveCost), Services=dcount(ServiceName) by Capability
| where Cost > 0
| order by Cost desc`,
        // Estate spend by billing service.
        byService: `Costs() ${period} ${AI_ESTATE}
| summarize Cost=sum(EffectiveCost), Meters=dcount(x_SkuMeterSubcategory) by Service=ServiceName, Category=ServiceCategory
| where Cost > 0
| top 15 by Cost desc`,
        // AI Search / retrieval meters.
        search: `Costs() ${period}
| where ServiceName == 'Azure AI Search'
| summarize Cost=sum(EffectiveCost), Quantity=sum(ConsumedQuantity) by Meter=tostring(SkuMeter), Unit=PricingUnit
| where Cost > 0
| top 10 by Cost desc`,
        // ML platform and GPU compute components.
        mlGpu: `Costs() ${period}
| extend _gpu = ${AI_GPU}
| where ServiceName == 'Azure Machine Learning' or _gpu
| summarize Cost=sum(EffectiveCost), Quantity=sum(PricingQuantity) by Component=x_SkuMeterSubcategory, Unit=PricingUnit
| where Cost > 0
| top 12 by Cost desc`,
        // ML compute unit economics — $/VM-hour and $/1K core-hours by series.
        mlUnit: `Costs() ${period}
| where ServiceName == 'Azure Machine Learning' and x_SkuMeterCategory == 'Virtual Machines'
| extend CoreHours = todouble(coalesce(x_SkuCoreCount, 0)) * PricingQuantity
| summarize Cost=sum(EffectiveCost), VmHours=sum(PricingQuantity), CoreHours=sum(CoreHours) by Series=x_SkuMeterSubcategory
| where VmHours > 0
| extend PerVmHour=Cost/VmHours, Per1KCoreHours=iff(CoreHours > 0, Cost/CoreHours*1000.0, real(null))
| top 10 by Cost desc`,
        // Foundation model benchmark — cost per 1M tokens by model family.
        // 'embed' is a genuine substring test: the token appears fused inside
        // meter names such as 'text-embedding-3-large'.
        modelBench: `Costs() ${period}
| where ${AI_TOKENS}
| extend Family = iff(SkuMeter contains 'embed', 'Embeddings', x_SkuMeterSubcategory)
| summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost) by Family
| where Tokens > 0
| extend Cpmt=Cost/Tokens*1000000.0
| order by Cost desc`,
        // Token direction mix by meter name. Meter names fuse the direction
        // into abbreviations ("Inpt", "Outp", "cchd", "cd inp"), so the tests
        // anchor to a word boundary rather than a bare substring: a plain
        // `contains 'out'` would also classify a future "Throughput" meter as
        // output. Verified against the live meter catalog with zero rows
        // falling through to 'Other'.
        direction: `Costs() ${period}
| where ${AI_TOKENS}
| extend Direction = case(
    SkuMeter contains 'embed', 'Embedding',
    SkuMeter matches regex @'(?i)\\bcd\\s+wr', 'Cached write',
    SkuMeter has_any ('cchd', 'cached') or SkuMeter matches regex @'(?i)\\bcd\\s+inp', 'Cached input',
    SkuMeter matches regex @'(?i)\\b(out|opt)', 'Output',
    SkuMeter matches regex @'(?i)\\binp', 'Input',
    'Other')
| summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost) by Direction
| where Tokens > 0
| extend Cpmt=Cost/Tokens*1000000.0
| order by Tokens desc`,
        // Cognitive and specialized AI services, excluding token meters.
        cognitive: `Costs() ${period}
| where ServiceName in ('Azure AI Services', 'Azure AI Video Indexer') and x_SkuMeterCategory != 'Foundry Models'
| summarize Cost=sum(EffectiveCost), Units=sum(ConsumedQuantity) by Service=x_SkuMeterSubcategory
| where Cost > 0
| top 12 by Cost desc`,
        // Allocation coverage per dimension, plus the estate total that every
        // coverage percentage is measured against.
        allocation: `Costs() ${period} ${AI_ESTATE}
| extend tk = coalesce(bag_keys(Tags), dynamic([]))
| summarize Total=sum(EffectiveCost),
    App=sumif(EffectiveCost, array_length(set_intersect(tk, ${AI_APP_TAGS})) > 0),
    Owner=sumif(EffectiveCost, array_length(set_intersect(tk, ${AI_OWNER_TAGS})) > 0),
    CostCenter=sumif(EffectiveCost, isnotempty(x_CostCenter)),
    ResourceGroup=sumif(EffectiveCost, isnotempty(x_ResourceGroupName))`,
        // Estate spend by owning team or cost center.
        // Tag values are free text, so the same owner arrives in several
        // casings ("ACM9000" / "acm9000"). Splitting them into separate rows
        // understates the real owner and reads as broken data on screen, so
        // group case-insensitively and keep the most expensive casing as the
        // display label. tolower() is the grouping key here, not a comparison —
        // KQL's comparison operators are already case-insensitive.
        byOwner: `Costs() ${period} ${AI_ESTATE}
| extend Owner = coalesce(tostring(Tags['owner']), tostring(Tags['team']), x_CostCenter, x_ResourceGroupName, '(unassigned)')
| summarize Cost=sum(EffectiveCost) by Owner
| where Cost > 0
| summarize Cost=sum(Cost), Variants=dcount(Owner), (TopCost, Owner)=arg_max(Cost, Owner) by OwnerKey=tolower(Owner)
| project Owner, Cost, Variants
| top 12 by Cost desc`,
        // Commitment posture across the estate.
        posture: `Costs() ${period} ${AI_ESTATE}
| summarize Total=sum(EffectiveCost), Committed=sumif(EffectiveCost, isnotempty(CommitmentDiscountCategory))`,
        // AI-scoped rate recommendations and commitment transactions. Both
        // render as descriptive counts; an empty result means no AI-scoped
        // evidence was ingested, not that no opportunity exists.
        recommendations: `Recommendations()
| where ResourceType has_any ('MachineLearning', 'CognitiveServices', 'Search/search', 'Databricks', 'BotService', 'VideoIndexer')
    or x_RecommendationDescription has_any ('AI', 'OpenAI', 'GPU', 'machine learning', 'cognitive')
| summarize Count=count()`,
        transactions: `Transactions()
| where ChargeDescription has_any ('NC', 'ND', 'NV', 'NG', 'GPU', 'Machine Learning', 'Cognitive', 'OpenAI', 'Databricks', 'AI Search')
| summarize Count=count()`,
        // Top movers: the last closed month against the month before it, so a
        // partial ingestion month can't read as a collapse in spend. A single
        // conditional aggregation replaces the source dashboard's self-join.
        drivers: `let _last = datetime(${closedDay});
let _prev = datetime_add('month', -1, _last);
Costs() ${period} ${AI_ESTATE}
| where ChargePeriodStart >= _prev and ChargePeriodStart < datetime_add('month', 1, _last)
| summarize Cost=sumif(EffectiveCost, ChargePeriodStart >= _last), Prev=sumif(EffectiveCost, ChargePeriodStart < _last)
    by Service=ServiceName, Meter=x_SkuMeterSubcategory
| where Cost > 0 or Prev > 0
| extend Change=Cost-Prev
| top 12 by Cost desc`,
    };
    return built;
    }, filters);
    if (!page.empty) {
        page.lastClosedMonth = closedMonth ? isoDay(closedMonth).slice(0, 7) : null;
        // Ship the queries that actually ran, so the panel "KQL" dialog shows
        // executed text rather than a hand-maintained copy that can drift.
        page.kql = built;
    }
    return page;
}
