/* FinOps hub dashboard — client renderer.
   Dependency-free: KPIs + SVG charts (line, horizontal bar, donut).
   Data comes from the extension's loopback /api endpoints. */

"use strict";

const PALETTE = [
  "#3b82f6", "#10b981", "#8b5cf6", "#f59e0b", "#ef4444", "#06b6d4",
  "#ec4899", "#84cc16", "#f97316", "#6366f1", "#14b8a6", "#a855f7",
];

// Shared "missing data" color: muted, never a rotating palette hue, so
// Untagged/Unclassified/blank slices read as "no data" consistently across
// every tab instead of looking like an ordinary category.
const UNKNOWN_COLOR = "var(--muted)";

export const CAPACITY_TABS = Object.freeze([
  { id: "home", label: "Home" },
  { id: "app-service", label: "App Service" },
  { id: "azure-ai", label: "Azure AI" },
  { id: "compute", label: "Compute" },
  { id: "azure-sql", label: "Azure SQL" },
  { id: "storage", label: "Storage" },
  { id: "capacity-reservations", label: "Capacity reservations" },
  { id: "premium-ssd-v2", label: "Premium SSD v2" },
]);

const state = {
  preset: "all",
  tab: "overview",
  loading: false,
  cache: {},
  filters: {},
  capacityClass: "home",
  capacitySelections: {},
  familyFilter: { status: "in-use", search: "", regions: [], mark: 70 },
  capacityDetailTab: "families",
  capacityFamilyPage: 1,
  capacitySubscriptionSearch: "",
  capacitySubscriptionPage: 1,
  capacitySubscriptionData: null,
  capacitySubscriptionLoading: false,
  capacitySubscriptionError: null,
  revision: 0,
};
const queryState = { rows: 0, health: "ok", refreshedAt: null, dataset: "Hub database" };

/** Human-readable labels for filter dimensions (used in chips). */
const FILTER_LABELS = {
  ServiceName: "Service",
  ServiceCategory: "Category",
  RegionId: "Region",
  x_ResourceGroupName: "Resource group",
  SubAccountName: "Subscription",
  CommitmentDiscountName: "Commitment",
  x_SkuMeterSubcategory: "Meter",
};

/* ----------------------------------------------------------------- KQL templates */

const PERIOD = "| where ChargePeriodStart >= datetime({start}) and ChargePeriodStart < datetime({end})";
const NON_PURCH = "| where not(ChargeCategory == 'Purchase' and isnotempty(CommitmentDiscountCategory))";
const AI_SCOPE = "| where x_SkuMeterSubcategory has 'OpenAI' and x_SkuDescription contains 'Token'";

/* eslint-disable max-len */
const PANEL_KQL = {
  "overview-trend": ["Costs()", PERIOD, "| summarize Billed=sum(BilledCost), Effective=sum(EffectiveCost)", "    by Month=format_datetime(startofmonth(ChargePeriodStart),'yyyy-MM')", "| order by Month asc"].join("\n"),
  "overview-top-services": ["Costs()", PERIOD, "| summarize Cost=sum(EffectiveCost) by ServiceName", "| top 10 by Cost desc"].join("\n"),
  "overview-service-category": ["Costs()", PERIOD, "| summarize Cost=sum(EffectiveCost) by ServiceCategory", "| where Cost > 0 | order by Cost desc"].join("\n"),
  "overview-top-rgs": ["Costs()", PERIOD, "| where isnotempty(x_ResourceGroupName)", "| summarize Cost=sum(EffectiveCost) by x_ResourceGroupName", "| top 10 by Cost desc"].join("\n"),
  "overview-top-regions": ["Costs()", PERIOD, "| where isnotempty(RegionId)", "| summarize Cost=sum(EffectiveCost) by RegionId", "| top 12 by Cost desc"].join("\n"),
  "overview-rate-coverage": ["Costs()", PERIOD, "| summarize Cost=sum(EffectiveCost) by PricingCategory"].join("\n"),
  "overview-savings": ["Costs()", PERIOD, NON_PURCH, "| extend neg=iff(ListCost<ContractedCost,real(0),ListCost-ContractedCost)", "| extend com=iff(ContractedCost<EffectiveCost,real(0),ContractedCost-EffectiveCost)", "| summarize List=sum(ListCost), Effective=sum(EffectiveCost), Negotiated=sum(neg), Commitment=sum(com)"].join("\n"),
  "overview-cost-allocation": ["Costs()", PERIOD, "| extend _t=iff(isnull(Tags) or array_length(bag_keys(Tags))==0,'Untagged','Tagged')", "| summarize Cost=sum(EffectiveCost) by _t"].join("\n"),
  "token-trend": ["Costs()", PERIOD, AI_SCOPE, "| summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost)", "    by Month=format_datetime(startofmonth(ChargePeriodStart),'yyyy-MM')", "| order by Month asc"].join("\n"),
  "token-by-model": ["Costs()", PERIOD, AI_SCOPE, "| extend Model=replace_regex(x_SkuDescription,@'^Azure OpenAI[^-]+-\\s*','')", "| extend Model=replace_regex(Model,@'(?i)[\\s-]+(inp|outp|chat|media).*$','')", "| summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost) by Model", "| top 12 by Cost desc"].join("\n"),
  "token-direction": ["Costs()", PERIOD, AI_SCOPE, "| extend Direction=case(x_SkuDescription has 'Outp','Output',x_SkuDescription contains 'cached','Cached input',x_SkuDescription has 'Inp','Input','Other')", "| summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost) by Direction"].join("\n"),
  "token-model-table": ["Costs()", PERIOD, AI_SCOPE, "| extend Model=replace_regex(x_SkuDescription,@'^Azure OpenAI[^-]+-\\s*','')", "| extend Model=replace_regex(Model,@'(?i)[\\s-]+(inp|outp|chat|media).*$','')", "| summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost) by Model", "| extend CostPer1K=iff(Tokens==0,0.0,Cost/Tokens*1000)", "| top 12 by Cost desc"].join("\n"),
  "anomaly-daily": ["let s=datetime({start}); let e=datetime({end});", "Costs()", "| where ChargePeriodStart>=s and ChargePeriodStart<e", "| summarize DC=sum(EffectiveCost) by bin(ChargePeriodStart,1d)", "| make-series Cost=sum(DC) default=0.0 on ChargePeriodStart from s to e step 1d", "| extend (flag,score,baseline)=series_decompose_anomalies(Cost,1.5)", "| mv-expand Day=ChargePeriodStart to typeof(datetime), Cost to typeof(real), flag to typeof(real), baseline to typeof(real)", "| project Day, Cost=toreal(Cost), Flag=toint(flag), Baseline=toreal(baseline)"].join("\n"),
  "anomaly-mom": ["Costs()", PERIOD, "| summarize Eff=sum(EffectiveCost) by M=startofmonth(ChargePeriodStart)", "| order by M asc | extend PrevEff=prev(Eff)", "| project Month=format_datetime(M,'yyyy-MM'), EffChangePct=iff(isempty(PrevEff),0.0,(Eff-PrevEff)*100.0/PrevEff), Eff"].join("\n"),
  "anomaly-forecast": ["Costs()", PERIOD, "| summarize Eff=sum(EffectiveCost) by bin(ChargePeriodStart,1d)", "| make-series Actual=sum(Eff) default=0.0 on ChargePeriodStart step 1d", "| extend Fc=series_decompose_forecast(Actual,90)", "| mv-expand Day=ChargePeriodStart to typeof(datetime), Actual to typeof(real), Fc to typeof(real)", "| summarize Actual=sum(toreal(Actual)), Forecast=sum(toreal(Fc)) by M=startofmonth(Day)", "| order by M asc | project Month=format_datetime(M,'yyyy-MM'), Actual, Forecast"].join("\n"),
  "usage-top-types": ["Costs()", PERIOD, "| where isnotempty(ResourceType)", "| summarize Resources=dcount(ResourceId), Cost=sum(EffectiveCost) by ResourceType", "| top 10 by Cost desc"].join("\n"),
  "usage-per-core-series": ["Costs()", PERIOD, "| where x_SkuMeterCategory in ('Virtual Machines','Virtual Machine Licenses') and ChargeCategory=='Usage'", "| extend cores=toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores))", "| extend ch=iff(isnotempty(cores), toreal(cores*ConsumedQuantity), toreal(''))", "| summarize Eff=sum(EffectiveCost), CH=sum(ch) by x_SkuMeterSubcategory", "| where CH > 100 | extend PerCore=Eff/CH | top 10 by Eff desc"].join("\n"),
  "usage-storage-tiers": ["Costs()", PERIOD, "| where ServiceCategory=='Storage' and ChargeCategory=='Usage'", "| extend Tier=case(x_SkuTier has_any('Hot','Standard','Premium'),'Frequent',x_SkuTier has_any('Cool','Cold','Archive'),'Infrequent','Unclassified')", "| summarize Cost=sum(EffectiveCost) by Tier", "| where Cost > 0 | order by Cost desc"].join("\n"),
  "rate-savings": ["Costs()", PERIOD, NON_PURCH, "| extend neg=iff(ListCost<ContractedCost,real(0),ListCost-ContractedCost)", "| extend com=iff(ContractedCost<EffectiveCost,real(0),ContractedCost-EffectiveCost)", "| extend tot=iff(ListCost<EffectiveCost,real(0),ListCost-EffectiveCost)", "| summarize List=sum(ListCost), Effective=sum(EffectiveCost), Negotiated=sum(neg), Commitment=sum(com), Total=sum(tot)"].join("\n"),
  "rate-commit-util": ["Costs()", PERIOD, "| where isnotempty(CommitmentDiscountId)", NON_PURCH, "| summarize Unused=sumif(EffectiveCost,CommitmentDiscountStatus=='Unused'), Total=sum(EffectiveCost)"].join("\n"),
  "rate-core-hours": ["Costs()", PERIOD, "| extend cores=toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores, 0))", "| extend ch=iff(cores>0, cores*ConsumedQuantity, toreal(''))", "| extend t=iff(isempty(CommitmentDiscountType),'On Demand',CommitmentDiscountType)", "| summarize CoreHours=sum(ch) by t", "| where CoreHours > 0 | order by CoreHours desc"].join("\n"),
  "rate-underutil": ["Costs()", PERIOD, "| where isnotempty(CommitmentDiscountName)", NON_PURCH, "| summarize Unused=sumif(EffectiveCost,CommitmentDiscountStatus=='Unused'), Total=sum(EffectiveCost) by CommitmentDiscountName", "| where Unused > 0 | top 10 by Unused desc"].join("\n"),
  "alloc-hierarchy": ["Costs()", PERIOD, "| extend Org=tostring(Tags['org']), Project=tostring(Tags['Project']), Env=tostring(Tags['env'])", "| summarize Cost=sum(EffectiveCost) by Org, Project, Env", "| where Cost > 0 | top 12 by Cost desc"].join("\n"),
  "alloc-tagging": ["Costs()", PERIOD, "| extend _t=iff(isnull(Tags) or array_length(bag_keys(Tags))==0,'Untagged','Tagged')", "| summarize Cost=sum(EffectiveCost) by _t"].join("\n"),
  "alloc-tag-keys": ["Costs()", PERIOD, "| mv-expand k=bag_keys(Tags) to typeof(string)", "| where isnotempty(k) and k !in ('ftk-tool','ftk-version','cm-resource-parent','costanalysis-parent') and not(k startswith 'aks-managed-')", "| summarize Cost=sum(EffectiveCost) by k", "| top 12 by Cost desc"].join("\n"),
  "alloc-by-subscription": ["Costs()", PERIOD, "| where isnotempty(SubAccountName)", "| summarize Cost=sum(EffectiveCost) by SubAccountName", "| top 10 by Cost desc"].join("\n"),
};
/* eslint-enable max-len */

// Panel id -> the name of the query that produced it. Used to look up the KQL
// the server actually executed, which keeps the panel "KQL" dialog honest
// without a second hand-maintained copy of every query.
const PANEL_QUERY = {
  "ai-capability-trend": "capabilityTrend",
  "ai-capability": "capability",
  "ai-by-service": "byService",
  "ai-token-demand": "monthly",
  "ai-cpmt-trend": "monthly",
  "ai-model-bench": "modelBench",
  "ai-direction": "direction",
  "ai-ml-gpu": "mlGpu",
  "ai-ml-unit": "mlUnit",
  "ai-search": "search",
  "ai-cognitive": "cognitive",
  "ai-allocation": "allocation",
  "ai-by-owner": "byOwner",
  "ai-posture": "posture",
  "ai-drivers": "drivers",
};

let _kqlPanelId = null;
let _loadAbort = null;
let _capacitySubscriptionAbort = null;
let _capacitySubscriptionFocusResults = false;

/* ------------------------------------------------------------------ filter management */

function filterKey() {
  const entries = Object.entries(state.filters)
    .filter(([, arr]) => arr && arr.length > 0)
    .sort(([a], [b]) => a.localeCompare(b));
  return entries.length > 0 ? "|" + JSON.stringify(entries) : "";
}

function cacheKey() {
  if (state.tab === "capacity") {
    return `${state.capacityClass}|${JSON.stringify(state.capacitySelections || {})}`;
  }
  return state.preset + filterKey();
}

function toggleFilter(dim, val) {
  const arr = state.filters[dim] || [];
  const idx = arr.indexOf(val);
  if (idx >= 0) {
    const next = arr.filter((v) => v !== val);
    if (next.length === 0) delete state.filters[dim];
    else state.filters[dim] = next;
  } else {
    state.filters[dim] = [...arr, val];
  }
  renderFilterBar();
  void publishCanvasState({ filters: state.filters });
  load();
}

function clearFilters() {
  state.filters = {};
  renderFilterBar();
  void publishCanvasState({ filters: state.filters });
  load();
}

// The tab strip scrolls horizontally below ~1000px and never moved on its own,
// so deep-linking to a tab late in the strip left the nav looking like the first
// tab was still selected. Called from every path that marks a tab active.
function revealActiveTab() {
  const active = el("tabs")?.querySelector("button[data-tab].active");
  if (active && active.scrollIntoView) active.scrollIntoView({ inline: "nearest", block: "nearest" });
}

function syncCanvasControls() {
  [...el("preset").querySelectorAll("button[data-preset]")].forEach((button) => {
    button.classList.toggle("active", button.dataset.preset === state.preset);
  });
  [...el("tabs").querySelectorAll("button[data-tab]")].forEach((button) => {
    const active = button.dataset.tab === state.tab;
    button.classList.toggle("active", active);
    button.setAttribute("aria-selected", active ? "true" : "false");
  });
  revealActiveTab();
  const isTool = TOOL_TABS.has(state.tab);
  const isCapacity = state.tab === "capacity";
  el("preset").hidden = isTool || isCapacity;
  el("refresh").hidden = isTool;
  el("app-footer").hidden = isTool;
  renderFilterBar();
}

function applySharedCanvasState(next, options = {}) {
  if (!next || !Number.isInteger(next.revision) || next.revision < state.revision) return;
  const previousTab = state.tab;
  const previousCapacityClass = state.capacityClass;
  const changed = next.tab !== state.tab || next.preset !== state.preset ||
    next.capacityClass !== state.capacityClass ||
    JSON.stringify(next.capacitySelections || {}) !== JSON.stringify(state.capacitySelections) ||
    JSON.stringify(next.filters || {}) !== JSON.stringify(state.filters);
  state.tab = next.tab;
  state.preset = next.preset;
  state.filters = next.filters || {};
  state.capacityClass = next.capacityClass || "home";
  state.capacitySelections = next.capacitySelections || {};
  state.revision = next.revision;
  if (previousCapacityClass !== state.capacityClass) resetCapacityDetail();
  syncCanvasControls();
  if (previousTab === "monaco" && state.tab !== "monaco") disposeMonacoEditor();
  if (changed || options.forceReload) {
    if (options.forceReload) {
      state.cache = {};
      invalidateCapacitySubscriptions();
    }
    const hash = state.tab === "capacity"
      ? `#tab=capacity&capacity=${state.capacityClass}`
      : `#tab=${state.tab}`;
    history.replaceState({ tab: state.tab, capacityClass: state.capacityClass }, "", hash);
    load();
  }
}

async function publishCanvasState(patch) {
  const send = async (expectedRevision) => {
    const response = await fetch("/api/session-state", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ...patch, expectedRevision }),
    });
    return { response, body: await response.json() };
  };

  try {
    let result = await send(state.revision);
    if (result.response.status === 409 && result.body.state) {
      const merged = { ...result.body.state, ...patch, revision: result.body.state.revision };
      applySharedCanvasState(merged);
      result = await send(result.body.state.revision);
    }
    if (!result.response.ok || result.body.error) throw new Error(result.body.error || "Could not share canvas state.");
    applySharedCanvasState(result.body);
  } catch (err) {
    console.error("[ftk-dashboard] state synchronization failed:", err);
  }
}

async function pollCanvasState() {
  try {
    const next = await fetch("/api/session-state").then((response) => response.json());
    if (!Number.isInteger(next.revision) || next.revision <= state.revision) return;
    const previous = window.__cfg || {};
    const config = await fetch("/api/config").then((response) => response.json());
    const connectionChanged = config.clusterUri !== previous.clusterUri || config.database !== previous.database;
    window.__cfg = config;
    applySharedCanvasState(next, { forceReload: connectionChanged });
  } catch {
    // The extension may be restarting; the next poll will reconnect.
  }
}

function renderFilterBar() {
  const bar = document.getElementById("filter-bar");
  const chips = document.getElementById("filter-chips");
  if (!bar || !chips) return;
  const entries = state.tab === "capacity"
    ? []
    : Object.entries(state.filters).filter(([, arr]) => arr && arr.length > 0);
  if (entries.length === 0) {
    bar.hidden = true;
    chips.innerHTML = "";
    return;
  }
  bar.hidden = false;
  chips.innerHTML = entries.flatMap(([dim, vals]) =>
    vals.map((val) => {
      const label = FILTER_LABELS[dim] || dim;
      return `<span class="filter-chip" data-dim="${esc(dim)}" data-val="${esc(val)}">` +
        `<span class="chip-label"><strong>${esc(label)}</strong> ${esc(val)}</span>` +
        `<button class="chip-remove" data-dim="${esc(dim)}" data-val="${esc(val)}" ` +
        `aria-label="Remove filter ${esc(label)}: ${esc(val)}" type="button">×</button>` +
        `</span>`;
    })
  ).join("");
}

/* ------------------------------------------------------------------ utils */

function fmtMoney(n) {
  if (n == null || isNaN(n)) return "$0";
  const sign = n < 0 ? "-" : "";
  const a = Math.abs(n);
  if (a >= 1e6) return `${sign}$${(a / 1e6).toFixed(2)}M`;
  if (a >= 1e3) return `${sign}$${(a / 1e3).toFixed(1)}K`;
  return `${sign}$${a.toFixed(a < 100 ? 2 : 0)}`;
}
function fmtMoneyFull(n) {
  if (n == null || isNaN(n)) return "$0";
  return n.toLocaleString("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 });
}
function fmtPct(x, d = 1) {
  if (x == null || isNaN(x)) return "—";
  return `${(x * 100).toFixed(d)}%`;
}
function fmtInt(n) {
  return (n ?? 0).toLocaleString("en-US");
}
function fmtTokens(n) {
  if (n == null || isNaN(n)) return "0";
  const a = Math.abs(n);
  if (a >= 1e9) return `${(n / 1e9).toFixed(2)}B`;
  if (a >= 1e6) return `${(n / 1e6).toFixed(1)}M`;
  if (a >= 1e3) return `${(n / 1e3).toFixed(1)}K`;
  return `${Math.round(n)}`;
}
function fmtPerM(costPer1K) {
  // costPer1K is $ per 1,000 tokens -> show $ per 1,000,000 tokens
  const v = (costPer1K || 0) * 1000;
  return `$${v.toFixed(2)}`;
}
// Unit rates span many orders of magnitude ($75 per 1K core-hours down to
// $0.00015 per VM-hour), so scale precision to the value. fmtMoneyFull rounds
// to whole dollars and would collapse every sub-dollar rate to "$0".
export function fmtRate(n) {
  if (n == null || isNaN(n)) return "—";
  if (n === 0) return "$0.00";
  const abs = Math.abs(n);
  if (abs >= 1) return `$${n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  if (abs >= 0.01) return `$${n.toFixed(3)}`;
  return `$${Number(n.toPrecision(2))}`;
}
// Consumed quantities are not integers (VM-hours, request units), and
// toLocaleString's 3-decimal default renders "22.033" one row above "22,247" —
// two numbers three orders of magnitude apart distinguished only by the
// separator glyph. Abbreviate above 1K so the magnitude is unambiguous.
export function fmtQty(n) {
  if (n == null || isNaN(n)) return "—";
  const a = Math.abs(n);
  if (a >= 1e6) return `${(n / 1e6).toFixed(2)}M`;
  if (a >= 1e3) return `${(n / 1e3).toFixed(1)}K`;
  if (a === 0) return "0";
  return `${Number(n.toFixed(2))}`;
}
// A money column is read as a right-aligned stack, so every cell in it must
// share one precision. Pick that precision once from the column's own maximum:
// large columns drop cents (nobody reads cents next to $178,528), small columns
// keep them. A nonzero value too small for the chosen precision renders as a
// floor marker rather than "$0.00", which would read as missing data.
export function moneyColumn(rows, ...keys) {
  const vals = [];
  for (const r of rows || []) for (const k of keys) {
    const v = Math.abs(+r[k]); if (v > 0 && isFinite(v)) vals.push(v);
  }
  const dp = vals.length && Math.max(...vals) >= 1000 ? 0 : 2;
  return fixedDollars(dp);
}

// Rates span far more orders of magnitude than money ($0.0004 to $74 in one
// table), so they need their own ladder — but still one precision per column,
// because a reader compares cells down a column, not against their magnitude.
export function rateColumn(rows, ...keys) {
  const vals = [];
  for (const r of rows || []) for (const k of keys) {
    const v = Math.abs(+r[k]); if (v > 0 && isFinite(v)) vals.push(v);
  }
  const max = vals.length ? Math.max(...vals) : 1;
  const dp = max >= 1 ? 2 : max >= 0.01 ? 3 : 4;
  return fixedDollars(dp);
}

// Values below half a unit would round to "$0.00" and read as free, so they get
// a floor marker instead.
function fixedDollars(dp) {
  const unit = Math.pow(10, -dp);
  return (n) => {
    if (n == null || isNaN(n)) return "—";
    if (n === 0) return `$${(0).toFixed(dp)}`;
    if (Math.abs(n) < unit / 2) return `<$${unit.toFixed(dp)}`;
    const body = Math.abs(n).toLocaleString("en-US", { minimumFractionDigits: dp, maximumFractionDigits: dp });
    return `${n < 0 ? "-" : ""}$${body}`;
  };
}
// Axis ticks share one scale, so they need one precision — unlike a cell, where
// fmtRate scales precision to the individual value. Mixing them puts "$0.500"
// directly above "$1.00" on the same axis.
function axisRate(n) {
  if (n == null || isNaN(n)) return "—";
  return `$${Number(n).toFixed(2)}`;
}

export function fmtShare(x, d = 1) {
  // A row with visible nonzero cost must never report "0.0%" — that reads as a
  // broken calculation and makes the column visibly fail to sum to 100%.
  if (x == null || isNaN(x)) return "—";
  const floor = 1 / Math.pow(10, d + 2);
  if (x > 0 && x < floor) return `<${(floor * 100).toFixed(d)}%`;
  return `${(x * 100).toFixed(d)}%`;
}
function fmtMonth(ym) {
  // "2025-04" -> "Apr ’25"
  if (!ym || typeof ym !== "string") return String(ym ?? "—");
  const [y, m] = ym.split("-");
  if (!y || !m) return ym;
  const names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${names[+m - 1] || m} '${y.slice(2)}`;
}
function fmtDayRange(min, max) {
  if (!min || !max) return "—";
  const f = (s) => {
    const d = new Date(s);
    if (isNaN(d)) return String(s);
    return d.toLocaleDateString("en-US", { month: "short", year: "numeric", timeZone: "UTC" });
  };
  return `${f(min)} – ${f(max)}`;
}
function esc(s) {
  return String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}
function trunc(s, n) {
  s = String(s ?? "");
  if (s.length <= n) return s;
  // Middle-ellipsis: keep a short tail visible so structurally similar long
  // identifiers (e.g. two reservation IDs differing only in their suffix)
  // don't collide into the same truncated string.
  const keepEnd = Math.min(8, Math.floor(n * 0.35));
  const keepStart = Math.max(1, n - keepEnd - 1);
  return `${s.slice(0, keepStart)}…${s.slice(-keepEnd)}`;
}
function el(id) { return document.getElementById(id); }
function fmtRelativeTime(date) {
  if (!date) return "—";
  const rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
  const diffSec = (date - Date.now()) / 1000;
  const abs = Math.abs(diffSec);
  if (abs < 60) return rtf.format(Math.round(diffSec), "second");
  if (abs < 3600) return rtf.format(Math.round(diffSec / 60), "minute");
  if (abs < 86400) return rtf.format(Math.round(diffSec / 3600), "hour");
  return rtf.format(Math.round(diffSec / 86400), "day");
}
function svgEl(w, h, body, label = "") {
  const ariaAttr = label ? ` aria-label="${esc(label)}"` : "";
  return `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="xMidYMid meet" role="img"${ariaAttr}>${body}</svg>`;
}

/* ----------------------------------------------------------------- charts */

// Shared single-left-axis gridline + y-tick-label renderer, used by every
// chart with one money-scaled y-axis (lineChart, anomalyChart, forecastChart).
// tokenTrendChart keeps its own dual-axis (token + cost) tick renderer — a
// different concept (two scales, two tick labels per line), not merged here.
function yAxisGrid(m, W, ih, yMax, ticks, valFmt) {
  let g = "";
  for (let t = 0; t <= ticks; t++) {
    const val = (yMax / ticks) * t;
    const yy = m.t + ih - (ih / ticks) * t;
    g += `<line class="grid-line" x1="${m.l}" y1="${yy}" x2="${W - m.r}" y2="${yy}"/>`;
    // The zero tick otherwise takes a different branch of the money/token
    // formatters ("$0.00" beneath "$4.3K"), leaving one tick in a format the
    // rest of the axis doesn't share.
    const label = t === 0 ? valFmt(0).replace(/\.0+\b/, "") : valFmt(val);
    g += `<text class="tick" x="${m.l - 8}" y="${yy + 4}" text-anchor="end">${label}</text>`;
  }
  return g;
}

// Round an axis ceiling up to a 1 / 2 / 2.5 / 5 x 10^n step so gridlines land on
// values a reader can actually use. Always rounds up, so a series can never
// exceed the plotted maximum.
export function niceMax(v, ticks = 4) {
  if (!(v > 0) || !isFinite(v)) return 1;
  const raw = v / ticks;
  const mag = Math.pow(10, Math.floor(Math.log10(raw)));
  const norm = raw / mag;
  const step = (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 2.5 ? 2.5 : norm <= 5 ? 5 : 10) * mag;
  return step * ticks;
}

// Shared index-thinned x-axis month-label renderer: shows a label at evenly
// spaced indices (max ~12) plus always the last row, for any chart whose rows
// run left-to-right one-per-month. anomalyChart uses a different, month-
// change-detection variant over daily rows and keeps its own logic.
function xAxisMonthLabels(rows, xFn, H, monthField = "Month") {
  let g = "";
  const n = rows.length;
  const step = Math.ceil(n / 12);
  // Emit the evenly-stepped indices, then append the final month only when it
  // isn't already on the grid *and* it clears the previous label by a full step.
  // Otherwise the last two ticks crowd at half the spacing of every other pair.
  const idx = [];
  for (let i = 0; i < n; i += step) idx.push(i);
  const last = n - 1;
  if (last >= 0 && idx[idx.length - 1] !== last) {
    if (last - idx[idx.length - 1] >= step) idx.push(last);
    else idx[idx.length - 1] = last;
  }
  idx.forEach((i) => {
    g += `<text class="tick" x="${xFn(i)}" y="${H - 12}" text-anchor="middle">${esc(fmtMonth(rows[i][monthField]))}</text>`;
  });
  return g;
}

function lineChart(rows) {
  // rows: [{Month, Billed, Effective}]
  // Flatter aspect ratio (vs. 280 previously): a ~15-point monthly line has
  // low vertical information density, so a wide-but-short viewBox avoids the
  // chart dominating the tab when rendered at panel width.
  const W = 760, H = 200;
  const m = { l: 56, r: 18, t: 16, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  if (!rows || rows.length === 0) return emptyChart(W, H, "Monthly cost trend — no data");
  const max = Math.max(...rows.map((r) => Math.max(r.Billed || 0, r.Effective || 0)), 1);
  const yMax = max * 1.12;
  const n = rows.length;
  const x = (i) => m.l + (n === 1 ? iw / 2 : (i / (n - 1)) * iw);
  const y = (v) => m.t + ih - (v / yMax) * ih;

  let g = "";
  // gridlines + y ticks
  g += yAxisGrid(m, W, ih, yMax, 4, fmtMoney);
  // x labels (thin out if crowded)
  g += xAxisMonthLabels(rows, x, H);
  // area under effective
  const ptsE = rows.map((r, i) => `${x(i)},${y(r.Effective || 0)}`);
  const area = `M${m.l},${y(0)} L${ptsE.join(" L")} L${x(n - 1)},${y(0)} Z`;
  g += `<path d="${area}" fill="${PALETTE[0]}" fill-opacity="0.10"/>`;
  // billed line (muted, dashed)
  const ptsB = rows.map((r, i) => `${x(i)},${y(r.Billed || 0)}`).join(" L");
  g += `<path d="M${ptsB}" fill="none" stroke="var(--muted)" stroke-width="1.5" stroke-dasharray="4 3" opacity="0.7"/>`;
  // effective line
  g += `<path d="M${ptsE.join(" L")}" fill="none" stroke="${PALETTE[0]}" stroke-width="2.5"/>`;
  // dots + hover titles
  rows.forEach((r, i) => {
    g += `<circle class="bar" tabindex="0" cx="${x(i)}" cy="${y(r.Effective || 0)}" r="3.2" fill="${PALETTE[0]}"><title>${esc(fmtMonth(r.Month))}\nEffective ${fmtMoneyFull(r.Effective)}\nBilled ${fmtMoneyFull(r.Billed)}</title></circle>`;
  });
  const legend = legendHtml([
    { label: "Effective cost", color: PALETTE[0] },
    { label: "Billed cost", color: "var(--muted)" },
  ]);
  return svgEl(W, H, g, "Monthly cost trend — billed vs effective cost") + legend;
}

function hbar(rows, nameKey, valKey, opts = {}) {
  const data = (rows || []).map((r) => ({ name: String(r[nameKey] ?? "—"), val: +r[valKey] || 0 }))
    .filter((r) => r.val > 0);
  if (data.length === 0) return `<p class="muted" style="font-size:12px">No data in range.</p>`;
  const max = Math.max(...data.map((d) => d.val), 1);
  const total = data.reduce((s, d) => s + d.val, 0);
  const rowH = 30, padR = 64, nameW = opts.nameW ?? 142;
  // The name budget is a character count, so it has to track nameW or wide
  // panels truncate names that had ~100 viewBox units of free gutter beside them.
  const nameChars = opts.nameChars ?? Math.max(12, Math.floor(nameW / 7.1));
  const W = 540, H = data.length * rowH + 6;
  const barX = nameW + 8, barW = W - barX - padR;
  const valFmt = opts.valFmt || fmtMoney;
  // filterDim: by default use nameKey; pass null to opt-out of filtering
  const filterDim = "filterDim" in opts ? opts.filterDim : nameKey;
  const activeVals = filterDim && state.filters[filterDim];
  const hasFilter = activeVals && activeVals.length > 0;
  let g = "";
  data.forEach((d, i) => {
    const yy = i * rowH + 4;
    const cy = yy + rowH / 2;
    const w = Math.max(2, (d.val / max) * barW);
    const color = opts.color || PALETTE[i % PALETTE.length];
    const pct = total > 0 ? (d.val / total) : 0;
    const isSelected = hasFilter && activeVals.includes(d.name);
    const isDimmed = hasFilter && !isSelected;
    let cls = "hbar-row";
    if (filterDim) cls += " hbar-filterable";
    if (isSelected) cls += " hbar-selected";
    if (isDimmed) cls += " hbar-dimmed";
    const isTruncated = d.name.length > nameChars;
    const dimAttr = filterDim ? ` data-filter-dim="${esc(filterDim)}" data-filter-val="${esc(d.name)}"` : "";
    const interactiveAttrs = filterDim
      ? ` tabindex="0" role="button" aria-pressed="${isSelected ? 'true' : 'false'}" aria-label="Filter by ${esc(d.name)}, ${valFmt(d.val)}"`
      : ` tabindex="0" aria-label="${esc(d.name)}, ${valFmt(d.val)}"`;
    g += `<g class="${cls}"${dimAttr}${interactiveAttrs}>`;
    g += `<text class="name${isTruncated ? " name--truncated" : ""}" x="0" y="${cy + 4}">${esc(trunc(d.name, nameChars))}<title>${esc(d.name)}</title></text>`;
    g += `<rect class="hbar" x="${barX}" y="${cy - 9}" width="${w}" height="18" rx="4" fill="${color}"><title>${esc(d.name)}\n${fmtMoneyFull(d.val)} · ${fmtPct(pct)}</title></rect>`;
    g += `<text class="val" x="${W}" y="${cy + 4}" text-anchor="end">${valFmt(d.val)}</text>`;
    g += `</g>`;
  });
  return svgEl(W, H, g, opts.label || "");
}

function donut(slices, opts = {}) {
  const data = (slices || []).filter((s) => (+s.value || 0) > 0);
  const total = data.reduce((s, d) => s + (+d.value || 0), 0);
  if (total <= 0) return `<p class="muted" style="font-size:12px">No data in range.</p>`;
  const size = 180, cx = size / 2, cy = size / 2, R = 80, r = 50;
  let a0 = 0, g = "";
  if (data.length === 1) {
    g += `<circle class="arc" tabindex="0" cx="${cx}" cy="${cy}" r="${(R + r) / 2}" fill="none" stroke="${data[0].color}" stroke-width="${R - r}"><title>${esc(data[0].label)}\n${fmtMoneyFull(data[0].value)} · 100%</title></circle>`;
  } else {
    // Give near-zero slices a minimum visible arc so they aren't rendered as
    // an invisible sliver, mirroring hbar()'s Math.max(2, ...) width floor.
    // The angle deficit is subtracted from the single largest slice so the
    // total stays exactly 360°.
    const minAngle = 4;
    const angles = data.map((d) => (d.value / total) * 360);
    let deficit = 0;
    const boosted = angles.map((a) => {
      if (a < minAngle) { deficit += minAngle - a; return minAngle; }
      return a;
    });
    if (deficit > 0) {
      const maxIdx = boosted.reduce((best, a, i) => (a > boosted[best] ? i : best), 0);
      boosted[maxIdx] = Math.max(minAngle, boosted[maxIdx] - deficit);
    }
    data.forEach((d, i) => {
      const frac = d.value / total;
      const a1 = a0 + boosted[i];
      g += `<path class="arc" tabindex="0" d="${donutSeg(cx, cy, R, r, a0, a1)}" fill="${d.color}"><title>${esc(d.label)}\n${fmtMoneyFull(d.value)} · ${fmtPct(frac)}</title></path>`;
      a0 = a1;
    });
  }
  const centerBig = opts.centerBig ?? fmtMoney(total);
  const centerSmall = opts.centerSmall ?? "total";
  g += `<text class="donut-center" x="${cx}" y="${cy - 2}" text-anchor="middle"><tspan class="big" x="${cx}">${esc(centerBig)}</tspan></text>`;
  g += `<text x="${cx}" y="${cy + 16}" text-anchor="middle" class="small">${esc(centerSmall)}</text>`;
  const legend = legendHtml(data.map((d) => ({
    label: d.label, color: d.color, isUnknown: d.isUnknown,
    value: opts.valueFmt ? opts.valueFmt(d) : `${fmtMoney(d.value)} · ${fmtPct(d.value / total)}`,
  })));
  return `<div class="donut-wrap">${svgEl(size, size, g, opts.label || "")}<div style="flex:1;min-width:140px">${legend}</div></div>`;
}

function donutSeg(cx, cy, R, r, a0, a1) {
  const polar = (rad, ang) => {
    const a = ((ang - 90) * Math.PI) / 180;
    return [cx + rad * Math.cos(a), cy + rad * Math.sin(a)];
  };
  const large = a1 - a0 > 180 ? 1 : 0;
  const [x0, y0] = polar(R, a0), [x1, y1] = polar(R, a1);
  const [x2, y2] = polar(r, a1), [x3, y3] = polar(r, a0);
  return `M${x0} ${y0} A${R} ${R} 0 ${large} 1 ${x1} ${y1} L${x2} ${y2} A${r} ${r} 0 ${large} 0 ${x3} ${y3} Z`;
}

function legendHtml(items) {
  return `<div class="legend">${items.map((it) =>
    `<span class="item"><span class="swatch${it.isUnknown ? " swatch--unknown" : ""}" style="background:${it.isUnknown ? "transparent" : it.color}"></span>${esc(it.label)}${
      it.value ? `<span class="lv">${esc(it.value)}</span>` : ""}</span>`).join("")}</div>`;
}

// Inline swatch for raw table cells (outside donut/hbar). isUnknown renders
// the shared dashed/muted "no data" treatment instead of a rotating palette
// color, matching legendHtml's isUnknown handling.
function swatchHtml(color, isUnknown = false) {
  return `<span class="swatch${isUnknown ? " swatch--unknown" : ""}" style="background:${isUnknown ? "transparent" : color}"></span>`;
}

// Generic data table. cols: [{label, align?, get:(row,i)=>htmlString}]. rows: any[].
function tableHtml(cols, rows, emptyMsg = "No data in range.") {
  if (!rows || rows.length === 0) return `<p class="muted" style="font-size:12px">${esc(emptyMsg)}</p>`;
  const head = cols.map((c) => `<th scope="col"${c.align === "left" ? ' style="text-align:left"' : ""}>${esc(c.label)}</th>`).join("");
  const body = rows.map((r, i) => `<tr>${cols.map((c) => `<td${c.align === "left" ? ' style="text-align:left"' : ""}>${c.get(r, i)}</td>`).join("")}</tr>`).join("");
  return `<table class="dtable"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
}

// Shared "cost breakdown" list row: an optional color swatch, a label, and a
// money value. Used by the Overview and Rate tabs' savings-breakdown panels —
// same concept, same markup, previously implemented twice independently.
function costBreakdownRow(label, val, accent) {
  return `<div style="display:flex;justify-content:space-between;align-items:center;padding:9px 0;border-bottom:1px solid var(--grid);font-variant-numeric:tabular-nums">
    <span style="display:inline-flex;align-items:center;gap:8px">${
      accent ? `<span class="swatch" style="width:9px;height:9px;border-radius:3px;display:inline-block;background:${accent}"></span>` : ""}${esc(label)}</span>
    <strong>${fmtMoney(val)}</strong></div>`;
}

// rows: [{label, val, accent?}]. footerLabel/footerValue render an optional
// trailing summary stat (e.g. "Effective savings rate — 42%") below the rows.
function costBreakdownTable(rows, footerLabel, footerValue) {
  const footer = footerLabel
    ? `<div style="display:flex;justify-content:space-between;margin-top:12px;padding-top:4px">
      <span class="muted" style="font-size:12px">${esc(footerLabel)}</span>
      <strong style="color:var(--pos)">${footerValue}</strong>
    </div>`
    : "";
  return `<div>${rows.map((r) => costBreakdownRow(r.label, r.val, r.accent)).join("")}${footer}</div>`;
}

function emptyChart(W, H, label = "No data") {
  return svgEl(W, H, `<text x="${W / 2}" y="${H / 2}" text-anchor="middle" class="muted">No data</text>`, label);
}


function tokenTrendChart(rows) {
  // rows: [{Month, Tokens, Cost}] — bars = token volume (left axis), line = AI cost (right axis)
  // Flatter aspect ratio (vs. 280 previously) — same rationale as lineChart:
  // ~15 monthly points don't need 280 units of vertical resolution.
  const W = 760, H = 200;
  const m = { l: 56, r: 58, t: 16, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  if (!rows || rows.length === 0) return emptyChart(W, H, "AI token volume and cost trend — no data");
  const tokMax = Math.max(...rows.map((r) => r.Tokens || 0), 1) * 1.14;
  const costMax = Math.max(...rows.map((r) => r.Cost || 0), 1) * 1.14;
  const n = rows.length;
  const cx = (i) => m.l + ((i + 0.5) / n) * iw;
  const yTok = (v) => m.t + ih - (v / tokMax) * ih;
  const yCost = (v) => m.t + ih - (v / costMax) * ih;
  const bw = Math.max(4, (iw / n) * 0.62);

  let g = "";
  const ticks = 4;
  for (let t = 0; t <= ticks; t++) {
    const yy = m.t + ih - (ih / ticks) * t;
    g += `<line class="grid-line" x1="${m.l}" y1="${yy}" x2="${W - m.r}" y2="${yy}"/>`;
    g += `<text class="tick" x="${m.l - 8}" y="${yy + 4}" text-anchor="end">${fmtTokens((tokMax / ticks) * t)}</text>`;
    g += `<text class="tick" x="${W - m.r + 8}" y="${yy + 4}" text-anchor="start">${fmtMoney((costMax / ticks) * t)}</text>`;
  }
  // token bars (left axis)
  rows.forEach((r, i) => {
    const top = yTok(r.Tokens || 0);
    const h = Math.max(0, m.t + ih - top);
    g += `<rect class="bar" x="${cx(i) - bw / 2}" y="${top}" width="${bw}" height="${h}" rx="3" fill="${PALETTE[2]}" fill-opacity="0.42"><title>${esc(fmtMonth(r.Month))}\n${fmtTokens(r.Tokens)} tokens\n${fmtMoneyFull(r.Cost)}</title></rect>`;
  });
  // cost line (right axis)
  const pts = rows.map((r, i) => `${cx(i)},${yCost(r.Cost || 0)}`);
  g += `<path d="M${pts.join(" L")}" fill="none" stroke="${PALETTE[3]}" stroke-width="2.5"/>`;
  rows.forEach((r, i) => {
    g += `<circle tabindex="0" cx="${cx(i)}" cy="${yCost(r.Cost || 0)}" r="3" fill="${PALETTE[3]}"><title>${esc(fmtMonth(r.Month))}\n${fmtMoneyFull(r.Cost)}</title></circle>`;
  });
  // x labels
  g += xAxisMonthLabels(rows, cx, H);
  const legend = legendHtml([
    { label: "Token volume", color: PALETTE[2] },
    { label: "AI effective cost", color: PALETTE[3] },
  ]);
  return svgEl(W, H, g, "AI token volume and cost trend") + legend;
}

// Fixed capability colors so the stacked chart, its legend, and the capability
// table all agree on which hue means which workload. A rotating index would
// re-colour a capability whenever the estate mix changes month to month.
const AI_CAPABILITY_COLORS = {
  "GPU / accelerated compute": PALETTE[9],
  "Foundation models (LLM)": PALETTE[2],
  "AI Search / retrieval": PALETTE[5],
  "ML platform & compute": PALETTE[0],
  "ML / analytics platform": PALETTE[1],
  "Cognitive services": PALETTE[3],
  "Bot & agents": PALETTE[6],
  "Other AI/ML": PALETTE[7],
};
const aiColor = (capability) => AI_CAPABILITY_COLORS[capability] ?? UNKNOWN_COLOR;

function aiCapabilityChart(rows) {
  // rows: [{Month, Capability, Cost}] — stacked columns, one stack per month.
  const W = 760, H = 200;
  const m = { l: 56, r: 18, t: 16, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  if (!rows || rows.length === 0) return emptyChart(W, H, "AI spend by capability over time — no data");

  const months = [...new Set(rows.map((r) => r.Month))].sort();
  // Order the stack by total spend so the dominant capability sits at the base
  // and the thin slices stay adjacent to the axis labels.
  const totals = new Map();
  rows.forEach((r) => totals.set(r.Capability, (totals.get(r.Capability) ?? 0) + (r.Cost || 0)));
  const caps = [...totals.entries()].sort((a, b) => b[1] - a[1]).map(([c]) => c);
  const at = new Map(rows.map((r) => [`${r.Month}|${r.Capability}`, r.Cost || 0]));

  const monthTotals = months.map((mo) => caps.reduce((s, c) => s + (at.get(`${mo}|${c}`) ?? 0), 0));
  const yMax = niceMax(Math.max(...monthTotals, 1) * 1.02, 4);
  const n = months.length;
  const cx = (i) => m.l + ((i + 0.5) / n) * iw;
  const bw = Math.max(4, (iw / n) * 0.62);

  let g = yAxisGrid(m, W, ih, yMax, 4, fmtMoney);
  months.forEach((mo, i) => {
    let acc = 0;
    caps.forEach((c) => {
      const v = at.get(`${mo}|${c}`) ?? 0;
      if (v <= 0) return;
      const h = (v / yMax) * ih;
      const yTop = m.t + ih - ((acc + v) / yMax) * ih;
      acc += v;
      g += `<rect class="bar" tabindex="0" x="${cx(i) - bw / 2}" y="${yTop}" width="${bw}" height="${Math.max(1, h)}" fill="${aiColor(c)}"><title>${esc(fmtMonth(mo))}\n${esc(c)}\n${fmtMoneyFull(v)}</title></rect>`;
    });
  });
  g += xAxisMonthLabels(months.map((mo) => ({ Month: mo })), cx, H);
  const legend = legendHtml(caps.map((c) => ({ label: c, color: aiColor(c) })));
  return svgEl(W, H, g, "AI spend by capability over time") + legend;
}

function monthAreaChart(rows, opts) {
  // rows: [{Month, <valueKey>}] — filled area with a stroked top edge.
  const { valueKey, color = PALETTE[0], valFmt = fmtMoney, tipFmt = valFmt, label = "Trend" } = opts;
  const W = 760, H = 200;
  const m = { l: 56, r: 18, t: 16, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  const data = (rows || []).filter((r) => isFinite(r[valueKey]));
  if (data.length === 0) return emptyChart(W, H, `${label} — no data`);

  const yMax = niceMax(Math.max(...data.map((r) => r[valueKey]), 1) * 1.02, 4);
  const n = data.length;
  const cx = (i) => m.l + ((i + 0.5) / n) * iw;
  const y = (v) => m.t + ih - (v / yMax) * ih;

  let g = yAxisGrid(m, W, ih, yMax, 4, valFmt);
  const pts = data.map((r, i) => `${cx(i)},${y(r[valueKey])}`);
  const base = m.t + ih;
  g += `<path d="M${cx(0)},${base} L${pts.join(" L")} L${cx(n - 1)},${base} Z" fill="${color}" fill-opacity="0.18"/>`;
  g += `<path d="M${pts.join(" L")}" fill="none" stroke="${color}" stroke-width="2.5"/>`;
  data.forEach((r, i) => {
    g += `<circle tabindex="0" cx="${cx(i)}" cy="${y(r[valueKey])}" r="3" fill="${color}"><title>${esc(fmtMonth(r.Month))}\n${tipFmt(r[valueKey])}</title></circle>`;
  });
  g += xAxisMonthLabels(data, cx, H);
  return svgEl(W, H, g, label);
}

function anomalyChart(rows) {
  // rows: [{Day, Cost, Flag, Baseline}]
  // Flattened to match lineChart/tokenTrendChart's aspect ratio (was 280) so
  // this full-width daily chart doesn't read as taller/heavier than the other
  // trend charts across tabs — daily granularity needs horizontal, not
  // vertical, resolution.
  const W = 760, H = 200;
  const m = { l: 56, r: 18, t: 16, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  if (!rows || rows.length === 0) return emptyChart(W, H, "Daily anomaly detection — no data");
  const max = Math.max(...rows.map((r) => Math.max(r.Cost || 0, r.Baseline || 0)), 1) * 1.12;
  const n = rows.length;
  const x = (i) => m.l + (n === 1 ? iw / 2 : (i / (n - 1)) * iw);
  const y = (v) => m.t + ih - (v / max) * ih;
  let g = "";
  g += yAxisGrid(m, W, ih, max, 4, fmtMoney);
  // month x labels
  let lastMonth = "";
  rows.forEach((r, i) => {
    const mo = String(r.Day).slice(0, 7);
    if (mo !== lastMonth) {
      lastMonth = mo;
      g += `<text class="tick" x="${x(i)}" y="${H - 12}" text-anchor="middle">${esc(fmtMonth(mo))}</text>`;
    }
  });
  // baseline (dashed) + cost line
  const base = rows.map((r, i) => `${x(i)},${y(r.Baseline || 0)}`).join(" L");
  g += `<path d="M${base}" fill="none" stroke="var(--muted)" stroke-width="1.2" stroke-dasharray="3 3" opacity="0.6"/>`;
  const cost = rows.map((r, i) => `${x(i)},${y(r.Cost || 0)}`).join(" L");
  g += `<path d="M${cost}" fill="none" stroke="${PALETTE[0]}" stroke-width="1.6"/>`;
  // anomaly markers
  rows.forEach((r, i) => {
    if (r.Flag !== 0) {
      const up = r.Flag > 0;
      g += `<circle tabindex="0" cx="${x(i)}" cy="${y(r.Cost || 0)}" r="4" fill="${up ? PALETTE[4] : PALETTE[1]}" stroke="var(--card-bg)" stroke-width="1"><title>${esc(String(r.Day).slice(0, 10))}\n${fmtMoneyFull(r.Cost)} (${up ? "spike" : "drop"})\nbaseline ${fmtMoneyFull(r.Baseline)}</title></circle>`;
    }
  });
  const legend = legendHtml([
    { label: "Daily effective cost", color: PALETTE[0] },
    { label: "Expected baseline", color: "var(--muted)" },
    { label: "Spike", color: PALETTE[4] },
    { label: "Drop", color: PALETTE[1] },
  ]);
  return svgEl(W, H, g, "Daily anomaly detection — cost vs expected baseline") + legend;
}

function momBars(rows) {
  // rows: [{Month, EffChangePct}] — diverging bars (cost up = red, down = green)
  const W = 760, H = 240;
  const m = { l: 44, r: 14, t: 14, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  const data = (rows || []).filter((r) => isFinite(r.EffChangePct));
  if (data.length === 0) return emptyChart(W, H, "Month-over-month effective cost change — no data");
  const maxAbs = Math.max(...data.map((r) => Math.abs(r.EffChangePct)), 5);
  const n = data.length;
  const y0 = m.t + ih / 2; // zero line
  const cx = (i) => m.l + ((i + 0.5) / n) * iw;
  const bw = Math.max(5, (iw / n) * 0.6);
  const yScale = (v) => (v / maxAbs) * (ih / 2);
  let g = `<line class="grid-line" x1="${m.l}" y1="${y0}" x2="${W - m.r}" y2="${y0}"/>`;
  data.forEach((r, i) => {
    const v = r.EffChangePct;
    const h = Math.abs(yScale(v));
    const yTop = v >= 0 ? y0 - h : y0;
    const color = v > 0 ? PALETTE[4] : PALETTE[1];
    g += `<rect class="bar" tabindex="0" x="${cx(i) - bw / 2}" y="${yTop}" width="${bw}" height="${Math.max(1, h)}" rx="2" fill="${color}"><title>${esc(fmtMonth(r.Month))}\n${v > 0 ? "+" : ""}${v.toFixed(1)}%</title></rect>`;
  });
  g += xAxisMonthLabels(data, cx, H);
  return svgEl(W, H, g, "Month-over-month effective cost change");
}

function forecastChart(rows, splitMonth) {
  // rows: [{Month, Actual, Forecast}] — actual solid up to splitMonth, forecast dashed onward
  const W = 760, H = 280;
  const m = { l: 56, r: 18, t: 16, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  if (!rows || rows.length === 0) return emptyChart(W, H, "Cost forecast — no data");
  const max = Math.max(...rows.map((r) => Math.max(r.Actual || 0, r.Forecast || 0)), 1) * 1.12;
  const n = rows.length;
  const x = (i) => m.l + (n === 1 ? iw / 2 : (i / (n - 1)) * iw);
  const y = (v) => m.t + ih - (v / max) * ih;
  let g = "";
  g += yAxisGrid(m, W, ih, max, 4, fmtMoney);
  const splitIdx = rows.findIndex((r) => r.Month >= splitMonth);
  const sIdx = splitIdx < 0 ? n - 1 : splitIdx;
  // shaded forecast region
  g += `<rect x="${x(sIdx)}" y="${m.t}" width="${W - m.r - x(sIdx)}" height="${ih}" fill="var(--muted)" opacity="0.06"/>`;
  // actual line up to split
  const actualPts = rows.slice(0, sIdx + 1).map((r, i) => `${x(i)},${y(r.Actual || 0)}`);
  if (actualPts.length > 1) g += `<path d="M${actualPts.join(" L")}" fill="none" stroke="${PALETTE[0]}" stroke-width="2.5"/>`;
  // forecast line from split onward
  const fcPts = rows.slice(sIdx).map((r, i) => `${x(sIdx + i)},${y(r.Forecast || 0)}`);
  if (fcPts.length > 1) g += `<path d="M${fcPts.join(" L")}" fill="none" stroke="${PALETTE[3]}" stroke-width="2.5" stroke-dasharray="5 4"/>`;
  // x labels
  g += xAxisMonthLabels(rows, x, H);
  rows.forEach((r, i) => {
    const isFc = i >= sIdx;
    g += `<circle tabindex="0" cx="${x(i)}" cy="${y(isFc ? (r.Forecast || 0) : (r.Actual || 0))}" r="2.6" fill="${isFc ? PALETTE[3] : PALETTE[0]}"><title>${esc(fmtMonth(r.Month))}\n${isFc ? "forecast " + fmtMoneyFull(r.Forecast) : "actual " + fmtMoneyFull(r.Actual)}</title></circle>`;
  });
  const legend = legendHtml([
    { label: "Actual", color: PALETTE[0] },
    { label: "Forecast", color: PALETTE[3] },
  ]);
  return svgEl(W, H, g, "Cost forecast — actual vs projected") + legend;
}

/* --------------------------------------------------------------- KPI calc */

function deriveKpis(d) {
  const s = d.summary?.[0] || {};
  const list = s.List || 0, eff = s.Effective || 0, contracted = s.Contracted || 0, billed = s.Billed || 0;
  const savings = list - eff;
  const esr = list > 0 ? savings / list : 0;
  const negotiated = list - contracted;
  const commitment = contracted - eff;

  const tagMap = Object.fromEntries((d.tagged || []).map((r) => [r._t, r.Cost || 0]));
  const tagged = tagMap.Tagged || 0, untagged = tagMap.Untagged || 0;
  const tagTotal = tagged + untagged;
  const untaggedPct = tagTotal > 0 ? untagged / tagTotal : 0;

  const priceMap = Object.fromEntries((d.pricing || []).map((r) => [r.PricingCategory, r.Cost || 0]));
  const committed = priceMap.Committed || 0;
  const priceTotal = Object.values(priceMap).reduce((a, b) => a + b, 0);
  const coverage = priceTotal > 0 ? committed / priceTotal : 0;

  const trend = d.trend || [];
  let mom = null, lastMonthVal = null, lastMonthLabel = null;
  if (trend.length >= 1) {
    const last = trend[trend.length - 1];
    lastMonthVal = last.Effective || 0;
    lastMonthLabel = fmtMonth(last.Month);
    if (trend.length >= 2) {
      const prev = trend[trend.length - 2].Effective || 0;
      mom = prev > 0 ? (lastMonthVal - prev) / prev : null;
    }
  }

  return {
    billed, eff, list, contracted, savings, esr, negotiated, commitment,
    tagged, untagged, untaggedPct, committed, coverage,
    resources: s.Resources || 0, services: s.Services || 0,
    subscriptions: s.Subscriptions || 0, regions: s.Regions || 0,
    mom, lastMonthVal, lastMonthLabel,
  };
}

function kpiThreshold(pct, greenMax, amberMax) {
  if (pct < greenMax) return "threshold-green";
  if (pct < amberMax) return "threshold-amber";
  return "threshold-red";
}

const VALID_TABS = ["overview", "allocation", "rate", "usage", "anomaly", "tokenomics", "ai", "capacity", "monaco"];

// "Tool" tabs are experiments that don't follow the KPI dashboard pipeline
// (no preset/filter-driven queries, no response caching) — they render their
// own surface and manage their own state.
const TOOL_TABS = new Set(["monaco"]);

function switchTab(tabId, opts = {}) {
  if (!VALID_TABS.includes(tabId) || (!opts.force && state.loading) || tabId === state.tab) return;
  const leavingMonaco = state.tab === "monaco";
  state.tab = tabId;
  [...el("tabs").querySelectorAll("button")].forEach((b) => {
    const active = b.dataset.tab === tabId;
    b.classList.toggle("active", active);
    b.setAttribute("aria-selected", active ? "true" : "false");
  });
  revealActiveTab();
  const isTool = TOOL_TABS.has(tabId);
  el("preset").hidden = isTool || tabId === "capacity";
  el("refresh").hidden = isTool;
  el("app-footer").hidden = isTool;
  if (isTool) el("filter-bar").hidden = true;
  if (leavingMonaco && tabId !== "monaco") disposeMonacoEditor();
  if (!opts.skipHash) {
    const url = new URL(location.href);
    url.hash = tabId === "capacity"
      ? `tab=capacity&capacity=${state.capacityClass}`
      : `tab=${tabId}`;
    history.pushState({ tab: tabId }, "", url);
  }
  if (!opts.skipPublish) void publishCanvasState({ tab: tabId });
  load();
}

function tabFromHash() {
  const m = /tab=([a-z]+)/.exec(location.hash);
  return m && VALID_TABS.includes(m[1]) ? m[1] : null;
}

function capacityClassFromHash() {
  const match = /(?:^|&)capacity=([a-z0-9-]+)/.exec(location.hash.replace(/^#/, ""));
  return match && CAPACITY_TABS.some((item) => item.id === match[1]) ? match[1] : null;
}

export function nextCapacityTabIndex(currentIndex, key, count = CAPACITY_TABS.length) {
  if (!Number.isInteger(currentIndex) || currentIndex < 0 || currentIndex >= count || count < 1) return -1;
  if (key === "Home") return 0;
  if (key === "End") return count - 1;
  if (key === "ArrowRight" || key === "ArrowDown") return (currentIndex + 1) % count;
  if (key === "ArrowLeft" || key === "ArrowUp") return (currentIndex - 1 + count) % count;
  return currentIndex;
}

function selectCapacityClass(classId, options = {}) {
  if (!CAPACITY_TABS.some((item) => item.id === classId) || state.loading) return;
  const changed = classId !== state.capacityClass;
  state.capacityClass = classId;
  if (changed) {
    state.capacitySelections = {};
    resetCapacityDetail();
  }
  if (!options.skipHash) {
    history.pushState({ tab: "capacity", capacityClass: classId }, "", `#tab=capacity&capacity=${classId}`);
  }
  if (!options.skipPublish) {
    void publishCanvasState({ capacityClass: classId, capacitySelections: state.capacitySelections });
  }
  if (changed || options.force) load();
}

function resetCapacityDetail() {
  invalidateCapacitySubscriptions();
  state.capacityDetailTab = "families";
  state.capacityFamilyPage = 1;
  state.capacitySubscriptionSearch = "";
}

function invalidateCapacitySubscriptions() {
  if (_capacitySubscriptionAbort) _capacitySubscriptionAbort.abort();
  _capacitySubscriptionAbort = null;
  _capacitySubscriptionFocusResults = false;
  state.capacitySubscriptionPage = 1;
  state.capacitySubscriptionData = null;
  state.capacitySubscriptionLoading = false;
  state.capacitySubscriptionError = null;
}

// The family matrix filters run against the payload already in memory, so they
// re-render without a round trip. Re-rendering replaces the search input, so its
// focus and caret are restored by hand.
function setFamilyFilter(patch) {
  state.familyFilter = { ...state.familyFilter, ...patch };
  state.capacityFamilyPage = 1;
  state.capacitySubscriptionPage = 1;
  state.capacitySubscriptionData = null;
  const active = document.activeElement;
  const search = document.getElementById("family-search");
  const hadSearchFocus = search && active === search;
  const caret = hadSearchFocus ? search.selectionStart : null;
  const lensFocus = !hadSearchFocus && active?.dataset?.familyStatus ? state.familyFilter.status : null;
  const regionFocus = !hadSearchFocus && active?.dataset?.familyRegion ? active.dataset.familyRegion : null;
  const markFocus = !hadSearchFocus && active?.dataset?.familyMark ? String(state.familyFilter.mark) : null;
  render();
  if (state.capacityDetailTab === "subscriptions") {
    queueMicrotask(() => void loadCapacitySubscriptions());
  }
  if (hadSearchFocus) {
    const next = document.getElementById("family-search");
    if (!next) return;
    next.focus();
    if (caret !== null) next.setSelectionRange(caret, caret);
    return;
  }
  const selector = lensFocus
    ? `[data-family-status="${CSS.escape(lensFocus)}"]`
    : regionFocus ? `[data-family-region="${CSS.escape(regionFocus)}"]`
    : markFocus ? `[data-family-mark="${CSS.escape(markFocus)}"]` : null;
  if (selector) document.querySelector(selector)?.focus();
}

function applyCapacitySelection(kind, value) {
  if (!["quota", "metric", "demand"].includes(kind) || state.loading) return;
  const next = { ...state.capacitySelections };
  const selectionName = `${kind}Selection`;
  if (!value) {
    delete next[selectionName];
    if (kind === "quota") delete next.metricSelection;
  } else {
    const payload = currentPayload();
    const rows = kind === "demand"
      ? payload?.demand?.selectors?.items
      : payload?.selectors?.items;
    const row = rows?.[Number(value)];
    const selection = capacitySelectionFromRow(kind, state.capacityClass, row);
    if (!selection) return;
    next[selectionName] = selection;
    if (kind === "quota") {
      const metric = capacitySelectionFromRow("metric", state.capacityClass, row);
      if (metric && Object.values(metric).every(Boolean)) next.metricSelection = metric;
      else delete next.metricSelection;
    }
  }
  state.capacitySelections = next;
  void publishCanvasState({ capacitySelections: next });
  load();
}

function setCapacityDetailTab(tab) {
  if (!["families", "subscriptions"].includes(tab) || tab === state.capacityDetailTab) return;
  state.capacityDetailTab = tab;
  render();
  document.querySelector(`[data-capacity-detail-tab="${CSS.escape(tab)}"]`)?.focus();
  if (tab === "subscriptions" && !state.capacitySubscriptionData) {
    void loadCapacitySubscriptions();
  }
}

function renderPreservingSubscriptionSearchFocus() {
  const search = document.querySelector("[data-capacity-subscription-search]");
  const focused = search && document.activeElement === search;
  const detailTab = document.activeElement?.dataset?.capacityDetailTab;
  const caret = focused ? search.selectionStart : null;
  render();
  if (focused) {
    const next = document.querySelector("[data-capacity-subscription-search]");
    next?.focus();
    if (caret !== null) next?.setSelectionRange(caret, caret);
  } else if (detailTab) {
    document.querySelector(`[data-capacity-detail-tab="${CSS.escape(detailTab)}"]`)?.focus();
  } else if (_capacitySubscriptionFocusResults) {
    const results = document.querySelector("#capacity-subscription-summary, #capacity-detail-panel [role=alert]");
    if (results) {
      results.focus();
      _capacitySubscriptionFocusResults = false;
    }
  }
}

async function loadCapacitySubscriptions() {
  if (state.capacityClass !== "compute" || state.capacityDetailTab !== "subscriptions") return;
  if (_capacitySubscriptionAbort) _capacitySubscriptionAbort.abort();
  const controller = new AbortController();
  _capacitySubscriptionAbort = controller;
  state.capacitySubscriptionLoading = true;
  state.capacitySubscriptionError = null;
  renderPreservingSubscriptionSearchFocus();
  try {
    const response = await fetch("/api/capacity-subscriptions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        status: state.familyFilter.status,
        familySearch: state.familyFilter.search,
        regions: state.familyFilter.regions,
        subscriptionSearch: state.capacitySubscriptionSearch,
        page: state.capacitySubscriptionPage,
        pageSize: 50,
      }),
      signal: controller.signal,
    });
    const body = await response.json();
    if (!response.ok || body.error) throw new Error(body.error || "Could not load subscriptions.");
    state.capacitySubscriptionData = body;
  } catch (err) {
    if (err.name === "AbortError") return;
    state.capacitySubscriptionError = err.message || "Could not load subscriptions.";
  } finally {
    if (_capacitySubscriptionAbort === controller) {
      state.capacitySubscriptionLoading = false;
      renderPreservingSubscriptionSearchFocus();
    }
  }
}

function moveCapacityTabFocus(target, key) {
  const tabs = [...document.querySelectorAll("[data-capacity-class]")];
  const currentIndex = tabs.indexOf(target);
  const nextIndex = nextCapacityTabIndex(currentIndex, key, tabs.length);
  tabs.forEach((tab, index) => {
    tab.tabIndex = index === nextIndex ? 0 : -1;
  });
  tabs[nextIndex]?.focus();
}

/* --------------------------------------------------------- triage strip */

function buildTriageTile(title, count, cue, tabId) {
  const isTeaser = count === null;
  const cls = isTeaser ? "is-teaser" : count === 0 ? "threshold-green" : count <= 4 ? "threshold-amber" : "threshold-red";
  const badge = isTeaser ? "Not loaded" : count === 0 ? "Good" : count <= 4 ? "Review" : "Urgent";
  const display = isTeaser ? "—" : count === 0 ? "None" : fmtInt(count);
  return `<button class="triage-tile${cls ? ` ${cls}` : ""}" data-switch-tab="${esc(tabId)}" type="button">
    <div class="triage-title">${esc(title)}</div>
    <div class="triage-count">${display}</div>
    <div class="triage-badge">${badge}</div>
    <div class="triage-cue">${esc(cue)}</div>
  </button>`;
}

function renderTriageStrip(d) {
  // Anomalies: reuse anomaly tab cache when loaded (use same cache key for consistency)
  const anomPayload = state.cache["anomaly"]?.[cacheKey()];
  const daily = anomPayload?.data?.daily || [];
  const anomCount = anomPayload ? daily.filter((r) => r.Flag !== 0).length : null;
  const anomCue = anomCount === null ? "Visit Anomalies & forecast tab to load"
    : anomCount === 0 ? "No anomalies detected"
    : "Review flagged cost days";

  // Overspend: months in trend where effective cost rose >20% vs prior month
  const trend = d.trend || [];
  let overspendCount = 0;
  for (let i = 1; i < trend.length; i++) {
    const prev = trend[i - 1].Effective || 0;
    const curr = trend[i].Effective || 0;
    if (prev > 0 && curr > prev * 1.20) overspendCount++;
  }
  const overspendCue = overspendCount === 0
    ? "Spend within expected range"
    : `${overspendCount} month${overspendCount === 1 ? "" : "s"} with >20% spike`;

  // Savings opportunities: underutilized commitments from rate tab cache when loaded
  const ratePayload = state.cache["rate"]?.[cacheKey()];
  const byCommitment = ratePayload?.data?.byCommitment || [];
  const savingsCount = ratePayload ? byCommitment.filter((r) => (r.Unused || 0) > 0).length : null;
  const savingsCue = savingsCount === null ? "Visit Rate optimization tab to load"
    : savingsCount === 0 ? "Commitments fully utilized"
    : "Underutilized commitments found";

  return `<div class="triage-strip">
    ${buildTriageTile("Anomalies", anomCount, anomCue, "anomaly")}
    ${buildTriageTile("Overspend", overspendCount, overspendCue, "usage")}
    ${buildTriageTile("Savings Opportunities", savingsCount, savingsCue, "rate")}
  </div>`;
}

function isPartialMonth() {
  const now = new Date();
  return now.getDate() < new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
}

const KPI_TIPS = {
  "Untagged cost": "% of spend on resources missing tags. Target: <10% · Review: <25% · Urgent: ≥25%. Tagging enables accurate showback and chargeback.",
  "Commitment waste": "% of RI/savings-plan spend on unused capacity. Target: <10% · Review: <20% · Urgent: ≥20%. Idle commitments erode net savings.",
  "Effective savings rate": "Negotiated + commitment savings as % of list price. Higher = better. Enterprise customers typically target ≥15–20%.",
  "Commitment coverage": "Compute spend covered by RIs or savings plans. Target: ≥60% for steady workloads. Higher coverage → lower effective rate.",
  "Compute coverage": "On-demand core-hours offset by commitments. Target: ≥60%. Tracks whether savings plan scope is sufficient.",
  "Anomaly days": "Days where daily cost deviated significantly from the expected baseline (STL decomposition). Review flagged dates for unexpected spend.",
  "Hourly cost / core": "Compute effective cost per core-hour actually consumed this period — the real, paid-for unit rate.",
  "Effective cost / core": "Compute effective cost per core-hour, including unused commitment waste spread across usage — the fully-loaded unit cost if that waste is charged back.",
  "Unpredicted variance": "Net effective cost variance between actual spend and the anomaly baseline on flagged days (FinOps KPI: Total Unpredicted Variance of Spend). Positive = spent more than expected.",
  "Anomaly detection rate": "Effective cost on anomaly-flagged days as % of total effective spend (FinOps KPI: Anomaly Cost %). The day-count ratio shown alongside is a separate reference stat, not the derivation of this percentage.",
  "Last month change": "Month-over-month % change in effective cost vs. the prior month. Watch for spikes or drops that don't match expected seasonality.",
  "Forecast next month": "Projected effective cost for next month using time-series decomposition (FinOps KPI: Cost Forecasting). Based on historical trend + seasonality, not a guarantee.",
  "Visibility delay": "Median (P50) delay between when cost was incurred and when it appeared in the FinOps hub (FinOps KPI: Cost Visibility Delay). On local/demo data without a live Cost Management connector, a large delay is expected.",
  "Tag policy compliance": "% of effective cost on resources with all required tag keys present and non-empty (FinOps KPI: Tagging Policy Compliance).",
  "Subscriptions": "Distinct subscriptions (billing accounts) with cost activity in the selected period.",
  "Allocated cost": "Effective cost with ownership attribution — a cost center, owner, or ownership tag — the complement of Unallocated cost.",
};

function kpiCard(label, value, meta, accent, thresholdClass, tier) {
  // Hierarchy tier is now explicitly assigned by each tab's render*() call
  // site (via the 6th `tier` argument) rather than an incomplete global
  // label allow-list, so every tab consciously designates its own hero
  // metric. `accent` is kept for call-site compatibility but unused.
  const hierarchyClass = tier === "primary" ? "kpi--primary" : tier === "reference" ? "kpi--reference" : "";

  // Combine threshold and hierarchy classes
  const classArray = [thresholdClass, hierarchyClass].filter(Boolean);
  const cls = classArray.length > 0 ? ` ${classArray.join(" ")}` : "";

  const tip = KPI_TIPS[label];
  const tipHtml = tip ? ` <button class="kpi-tip" type="button" tabindex="0" title="${esc(tip)}" aria-label="Threshold guidance: ${esc(label)}">?</button>` : "";

  return `<div class="kpi${cls}">
    <div class="label">${esc(label)}${tipHtml}</div>
    <div class="value">${value}</div>
    <div class="meta">${meta}</div>
  </div>`;
}

/* ---------------------------------------------------------------- render */

function panelHtml(id, span, title, sub, body) {
  const subHtml = sub ? `<p class="panel-sub">${sub}</p>` : "";
  return `<div class="panel col-${span}" data-panel-id="${esc(id)}">
    <div class="panel-header"><div><h3>${title}</h3>${subHtml}</div><button class="kql-btn" type="button" title="View KQL query" aria-label="View KQL query" data-panel-id="${esc(id)}">KQL</button></div>
    <div class="panel-body">${body}</div>
  </div>`;
}

function openKqlDialog(panelId) {
  _kqlPanelId = panelId;
  // Prefer the query the server actually executed for this panel; fall back to
  // the static map for tabs that don't publish their queries yet.
  const served = currentPayload()?.kql?.[PANEL_QUERY[panelId]];
  el("kql-text").value = served || PANEL_KQL[panelId] || "";
  el("kql-error").textContent = "";
  const prev = document.getElementById("kql-result");
  if (prev) prev.remove();
  el("kql-dialog").showModal();
}

async function executeKql() {
  const kql = el("kql-text").value.trim();
  const errEl = el("kql-error");
  const runBtn = el("kql-run");
  if (!kql) return;
  errEl.textContent = "";
  const prev = document.getElementById("kql-result");
  if (prev) prev.remove();
  runBtn.disabled = true;
  runBtn.textContent = "Running…";
  try {
    const res = await fetch("/api/kql", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ kql }),
    });
    if (!res.ok) { errEl.textContent = `Server error ${res.status}`; return; }
    const data = await res.json();
    if (data.error) {
      errEl.textContent = data.error;
    } else {
      const rows = data.rows || [];
      if (!rows.length) {
        errEl.textContent = "Query returned no rows.";
      } else {
        el("kql-dialog").close();
        renderKqlResultInPanel(_kqlPanelId, rows);
      }
    }
  } catch (err) {
    errEl.textContent = "Request failed: " + err.message;
  } finally {
    runBtn.disabled = false;
    runBtn.textContent = "Run";
  }
}

function renderKqlResultInPanel(panelId, rows) {
  const panelBody = document.querySelector(`[data-panel-id="${panelId}"] .panel-body`);
  if (!panelBody) return;
  const cols = Object.keys(rows[0]);
  const head = cols.map((c) => `<th scope="col">${esc(c)}</th>`).join("");
  const body = rows.slice(0, 200).map((r) =>
    `<tr>${cols.map((c) => `<td>${esc(String(r[c] ?? ""))}</td>`).join("")}</tr>`
  ).join("");
  panelBody.innerHTML = `<p class="kql-result-meta">${rows.length} rows${rows.length > 200 ? " (showing first 200)" : ""}</p><div class="kql-result-scroll"><table class="dtable"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function renderOverview(p) {
  const content = el("content");
  if (!p) return;
  if (p.error) return renderError(p);
  if (p.empty) {
    content.innerHTML = `<div class="error"><h2>No cost data</h2><p>The <code>Hub</code> database has no rows yet. Ingest cost data, then refresh.</p></div>`;
    return;
  }
  const k = deriveKpis(p.data);

  const momClass = k.mom == null ? "" : k.mom > 0 ? "neg" : "pos"; // cost up = bad
  const momTxt = k.mom == null ? "—" : `${k.mom > 0 ? "▲" : "▼"} ${fmtPct(Math.abs(k.mom))}`;

  const partialHtml = isPartialMonth() ? ` · <span class="warn">partial month</span>` : "";
  const kpis = [
    // primary KPIs first
    kpiCard("Untagged cost", fmtPct(k.untaggedPct),
      `${fmtMoney(k.untagged)} on untagged resources`, PALETTE[3],
      kpiThreshold(k.untaggedPct, 0.10, 0.25), "primary"),
    // supporting KPIs
    kpiCard("Effective cost", fmtMoney(k.eff), `Billed ${fmtMoney(k.billed)}`, PALETTE[0]),
    kpiCard("Total savings", fmtMoney(k.savings),
      `<span class="pos">${fmtPct(k.esr)}</span> effective savings rate`, PALETTE[1]),
    // reference KPIs
    kpiCard("Commitment coverage", fmtPct(k.coverage),
      `${fmtMoney(k.committed)} of compute spend`, PALETTE[5], undefined, "reference"),
    // supporting KPIs
    kpiCard("Tracked resources", fmtInt(k.resources),
      `${fmtInt(k.services)} services · ${fmtInt(k.subscriptions)} subs · ${fmtInt(k.regions)} regions`, PALETTE[2]),
    kpiCard("Latest month", k.lastMonthVal == null ? "—" : fmtMoney(k.lastMonthVal),
      k.mom == null ? (k.lastMonthLabel ? `${esc(k.lastMonthLabel)}${partialHtml}` : (isPartialMonth() ? `<span class="warn">partial month</span>` : "")) : `<span class="${momClass}">${momTxt}</span> vs prior · ${esc(k.lastMonthLabel)}${partialHtml}`, PALETTE[4]),
  ].join("");

  const d = p.data;
  const html = `
    ${renderTriageStrip(d)}
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>Understand usage &amp; cost</h2><span class="domain">FinOps Framework</span></div>
    <div class="panel-grid">
      ${panelHtml("overview-trend", 12, "Monthly cost trend", "Billed vs effective cost by month — executive run-rate view.", lineChart(d.trend))}
      ${panelHtml("overview-top-services", 6, "Top services by cost", "Effective cost by Azure service.", hbar(d.topServices, "ServiceName", "Cost", { label: "Top services by cost" }))}
      ${panelHtml("overview-service-category", 6, "Cost by service category", "Where spend concentrates across categories.", hbar(d.serviceCategory, "ServiceCategory", "Cost", { label: "Cost by service category" }))}
    </div>

    <div class="section-title"><h2>Optimize usage &amp; cost</h2><span class="domain">FinOps Framework</span></div>
    <div class="panel-grid">
      ${panelHtml("overview-top-rgs", 6, "Top resource groups", "Largest cost owners for allocation &amp; accountability.", hbar(d.topResourceGroups, "x_ResourceGroupName", "Cost", { label: "Top resource groups" }))}
      ${panelHtml("overview-top-regions", 6, "Cost by region", "Regional spend for placement &amp; sustainability review.", hbar(d.topRegions, "RegionId", "Cost", { label: "Cost by region" }))}
    </div>

    <div class="section-title"><h2>Quantify business value</h2><span class="domain">FinOps Framework</span></div>
    <div class="panel-grid">
      ${panelHtml("overview-rate-coverage", 4, "Rate coverage", "Committed vs on-demand (standard) effective cost.", donut([
        { label: "Committed", value: k.committed, color: PALETTE[1] },
        { label: "On-demand", value: Math.max(0, k.eff - k.committed), color: PALETTE[0] },
      ], { centerBig: fmtPct(k.coverage), centerSmall: "covered", label: "Rate coverage" }))}
      ${panelHtml("overview-savings", 4, "Savings breakdown", "List → effective, by discount type.", savingsTable(k))}
      ${panelHtml("overview-cost-allocation", 4, "Cost allocation", "Tagged vs untagged effective cost.", donut([
        { label: "Tagged", value: k.tagged, color: PALETTE[1] },
        { label: "Untagged", value: k.untagged, color: UNKNOWN_COLOR, isUnknown: true },
      ], { centerBig: fmtPct(1 - k.untaggedPct), centerSmall: "tagged", label: "Cost allocation" }))}
    </div>
  `;
  content.innerHTML = html;
}

function savingsTable(k) {
  return costBreakdownTable([
    { label: "List cost", val: k.list, accent: "var(--muted)" },
    { label: "Negotiated savings", val: k.negotiated, accent: PALETTE[8] },
    { label: "Commitment savings", val: k.commitment, accent: PALETTE[1] },
    { label: "Effective cost", val: k.eff, accent: PALETTE[0] },
  ], "Effective savings rate", fmtPct(k.esr));
}

/* ----------------------------------------------------- tokenomics render */

function deriveTokenKpis(d) {
  const s = d.summary?.[0] || {};
  const tokens = s.Tokens || 0, eff = s.Effective || 0;
  const cloud = d.totalCloud?.[0]?.Effective || 0;
  const dir = Object.fromEntries((d.direction || []).map((r) => [r.Direction, r]));
  const inTok = dir["Input"]?.Tokens || 0;
  const cachedTok = dir["Cached input"]?.Tokens || 0;
  const cachedShare = inTok + cachedTok > 0 ? cachedTok / (inTok + cachedTok) : 0;
  return {
    tokens, eff, cloud,
    blendedPer1K: tokens > 0 ? eff / tokens * 1000 : 0,
    cachedShare,
    aiShare: cloud > 0 ? eff / cloud : 0,
    models: s.Models || 0,
    resources: s.Resources || 0,
  };
}

function renderTokenomics(p) {
  const content = el("content");
  if (!p) return;
  if (p.error) return renderError(p);
  if (p.empty) {
    content.innerHTML = `<div class="error"><h2>No AI token data</h2>
      <p>No Azure OpenAI token meters were found in the <code>Hub</code> database for this period.</p>
      <p class="muted">Tokenomics tracks meters where <code>x_SkuMeterSubcategory</code> contains “OpenAI” and the SKU is billed in tokens. Ingest Azure OpenAI usage, then refresh.</p></div>`;
    return;
  }
  const d = p.data;
  const k = deriveTokenKpis(d);

  const dirColors = { "Input": PALETTE[0], "Cached input": PALETTE[1], "Output": PALETTE[3], "Other": PALETTE[6] };
  const dirSlices = (d.direction || []).map((r) => ({
    label: r.Direction, value: r.Tokens || 0, cost: r.Cost || 0, color: dirColors[r.Direction] || PALETTE[6],
  }));

  const kpis = [
    // reference KPIs first (no primaries in this tab)
    kpiCard("Total tokens", fmtTokens(k.tokens), `across ${fmtInt(k.models)} model families`, PALETTE[0], undefined, "reference"),
    // supporting KPIs
    kpiCard("AI token cost", fmtMoney(k.eff), `${fmtPct(k.aiShare, 2)} of all cloud cost`, PALETTE[2], undefined, "primary"),
    kpiCard("Blended rate", fmtPerM(k.blendedPer1K), `per 1M tokens (effective)`, PALETTE[5]),
    kpiCard("Cached input", fmtPct(k.cachedShare),
      `<span class="pos">${fmtPct(k.cachedShare)}</span> of input tokens cached`, PALETTE[1]),
    kpiCard("AI resources", fmtInt(k.resources), `Azure OpenAI deployments`, PALETTE[4]),
    kpiCard("Models in use", fmtInt(k.models), `distinct model families`, PALETTE[8]),
  ].join("");

  content.innerHTML = `
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>AI token economics</h2><span class="domain">Token Consumption Metrics KPI</span></div>
    <div class="panel-grid">
      ${panelHtml("token-trend", 12, "Token volume &amp; AI cost trend", "Monthly token consumption (bars) and effective AI cost (line).", tokenTrendChart(d.trend))}
      ${panelHtml("token-by-model", 6, "AI cost by model", "Effective cost per model family.",
        hbar((d.models || []).map((m) => ({ Model: m.Model, Cost: m.Cost })), "Model", "Cost", { label: "AI cost by model" }))}
      ${panelHtml("token-direction", 6, "Token direction mix", "Input vs cached input vs output — by token volume.",
        donut(dirSlices, {
          centerBig: fmtTokens(k.tokens), centerSmall: "tokens",
          valueFmt: (s) => `${fmtTokens(s.value)} · ${fmtMoney(s.cost)}`,
          label: "Token direction mix",
        }))}
    </div>

    <div class="section-title"><h2>Model efficiency</h2><span class="domain">Rate &amp; usage optimization</span></div>
    <div class="panel-grid">
      ${panelHtml("token-model-table", 12, "Cost per 1M tokens by model", "Unit economics for model selection — sorted by effective cost.", tokenModelTable(d.models, k.eff))}
    </div>

    <div class="section-title"><h2>AI cost allocation</h2><span class="domain">Showback &amp; chargeback</span></div>
    <div class="panel-grid">
      ${panelHtml("token-by-app", 12, "AI cost by application", "Azure OpenAI effective cost and token volume by application, team, environment, and cost center.", aiByAppTable(d.byApplication))}
    </div>
  `;
}

function tokenModelTable(models, totalCost) {
  const rows = (models || []).filter((m) => (m.Tokens || 0) > 0);
  if (rows.length === 0) return `<p class="muted" style="font-size:12px">No token data in range.</p>`;
  const maxPer1K = Math.max(...rows.map((m) => m.CostPer1K || 0), 1e-9);
  const body = rows.map((m, i) => {
    const color = PALETTE[i % PALETTE.length];
    const share = totalCost > 0 ? (m.Cost || 0) / totalCost : 0;
    const barW = Math.max(2, ((m.CostPer1K || 0) / maxPer1K) * 90);
    return `<tr>
      <td><span class="model">${swatchHtml(color)}${esc(m.Model)}</span></td>
      <td>${fmtTokens(m.Tokens)}</td>
      <td>${fmtMoneyFull(m.Cost)}</td>
      <td class="barcell">${fmtPerM(m.CostPer1K)}<span class="minibar" style="width:${barW}px;background:${color}"></span></td>
      <td>${fmtPct(share)}</td>
    </tr>`;
  }).join("");
  return `<table class="dtable">
    <thead><tr><th scope="col">Model</th><th scope="col">Tokens</th><th scope="col">Effective cost</th><th scope="col">$ / 1M tokens</th><th scope="col">% of AI cost</th></tr></thead>
    <tbody>${body}</tbody>
  </table>`;
}

function aiByAppTable(rows) {
  const data = (rows || []).filter((r) => (r.EffectiveCost || 0) > 0);
  if (data.length === 0) return `<p class="muted" style="font-size:12px">No tagged AI cost data. Tag Azure OpenAI resources with <code>application</code>, <code>team</code>, or <code>environment</code> tags.</p>`;
  const totalCost = data.reduce((a, r) => a + (r.EffectiveCost || 0), 0);
  const untaggedCount = data.filter((r) => !r.Application).length;
  const callout = untaggedCount === data.length
    ? `<div class="triage-callout" role="status"><span class="triage-callout-icon" aria-hidden="true">⚠</span>100% of AI cost (${fmtMoney(totalCost)}) is untagged — no application-level chargeback is currently possible. Tag Azure OpenAI resources with an <code>application</code> tag to enable it.</div>`
    : "";
  return callout + `<table class="dtable">
    <thead><tr><th scope="col">Application</th><th scope="col">Team</th><th scope="col">Environment</th><th scope="col">Cost center</th><th scope="col">Tokens</th><th scope="col">Effective cost</th><th scope="col">$/1M tokens</th><th scope="col">% of AI</th></tr></thead>
    <tbody>${data.map((r, i) => {
      const share = totalCost > 0 ? (r.EffectiveCost || 0) / totalCost : 0;
      const isUnknown = !r.Application;
      const color = PALETTE[i % PALETTE.length];
      return `<tr>
        <td>${swatchHtml(color, isUnknown)}${esc(r.Application || "(untagged)")}</td>
        <td class="muted">${esc(r.Team || "—")}</td>
        <td class="muted">${esc(r.Environment || "—")}</td>
        <td class="muted">${esc(r.CostCenter || "—")}</td>
        <td>${fmtTokens(r.TokenCount)}</td>
        <td>${fmtMoney(r.EffectiveCost)}</td>
        <td>${fmtPerM(r.CostPer1KTokens)}</td>
        <td>${fmtPct(share)}</td>
      </tr>`;
    }).join("")}</tbody>
  </table>`;
}

/* --------------------------------------------- AI & emerging workloads render */

// Middle-ellipsis a cell value and expose the full string on hover, so long
// meter and series names shorten predictably instead of overflowing the
// `white-space: nowrap` table cells.
function nameCell(value, n) {
  // `??` alone lets an empty string through, which renders as a blank cell and
  // reads as a rendering failure rather than as absent data.
  const s = String(value ?? "").trim() || "—";
  const short = trunc(s, n);
  return short === s ? esc(s) : `<span class="truncate-hint" title="${esc(s)}">${esc(short)}</span>`;
}

// Wrap a table that can exceed its panel width. The first column stays pinned
// while the numeric columns scroll, so a row never loses its label.
function wideTable(html) {
  return `<div class="table-scroll">${html}</div>`;
}

function aiCapabilityTable(rows, estate) {
  const money = moneyColumn(rows, "Cost");
  return wideTable(tableHtml([
    { label: "Capability", align: "left", get: (r) =>
      `<span class="model">${swatchHtml(aiColor(r.Capability))}${nameCell(r.Capability, 26)}</span>` },
    { label: "Services", get: (r) => fmtInt(r.Services) },
    { label: "Cost", get: (r) => money(r.Cost) },
    { label: "Share", get: (r) => estate > 0 ? fmtShare(r.Cost / estate, 1) : "—" },
  ], rows, "No AI/ML estate cost in range."));
}

function aiModelBenchTable(rows) {
  const money = moneyColumn(rows, "Cost");
  const rate = rateColumn(rows, "Cpmt");
  return wideTable(tableHtml([
    { label: "Model family", align: "left", get: (r) => nameCell(r.Family, 26) },
    { label: "Tokens", get: (r) => fmtTokens(r.Tokens) },
    { label: "Cost", get: (r) => money(r.Cost) },
    { label: "$ / 1M tokens", get: (r) => rate(r.Cpmt) },
  ], rows, "No foundation model token meters in range."));
}

function aiDirectionTable(rows) {
  const rate = rateColumn(rows, "Cpmt");
  const total = (rows || []).reduce((s, r) => s + (r.Tokens || 0), 0);
  return wideTable(tableHtml([
    { label: "Direction", align: "left", get: (r) => nameCell(r.Direction, 26) },
    { label: "Tokens", get: (r) => fmtTokens(r.Tokens) },
    { label: "Share", get: (r) => total > 0 ? fmtShare(r.Tokens / total, 1) : "—" },
    { label: "$ / 1M tokens", get: (r) => rate(r.Cpmt) },
  ], rows, "No foundation model token meters in range."));
}

export function deriveAiKpis(d, lastClosedMonth) {
  const months = d.monthly || [];
  const sum = (key) => months.reduce((s, r) => s + (r[key] || 0), 0);
  const cloud = sum("Cloud"), estate = sum("Estate"), mlGpu = sum("MlGpu");
  const tokens = sum("Tokens"), tokenCost = sum("TokenCost");

  // Anchor month-over-month to the last *closed* month reported by the server.
  // The newest month in the window is normally a partial ingestion month, and
  // comparing it against a full month reports a collapse that isn't real.
  const closedIdx = lastClosedMonth ? months.findIndex((r) => r.Month === lastClosedMonth) : -1;
  const closed = closedIdx >= 0 ? months[closedIdx] : null;
  const prior = closedIdx > 0 ? months[closedIdx - 1] : null;
  const mom = closed && prior && prior.Estate > 0 ? (closed.Estate - prior.Estate) / prior.Estate : null;

  const a = (d.allocation || [])[0] || {};
  const allocTotal = a.Total || 0;
  const appCoverage = allocTotal > 0 ? (a.App || 0) / allocTotal : null;

  const posture = (d.posture || [])[0] || {};

  return {
    cloud, estate, mlGpu, tokens, tokenCost,
    estateShare: cloud > 0 ? estate / cloud : 0,
    mlGpuShare: estate > 0 ? mlGpu / estate : 0,
    cpmt: tokens > 0 ? (tokenCost / tokens) * 1000000 : null,
    mom, closedMonth: lastClosedMonth, hasClosedMonth: !!closed,
    partialMonth: months.length > 0 && months[months.length - 1].Month !== lastClosedMonth
      ? months[months.length - 1].Month : null,
    alloc: a, allocTotal, appCoverage,
    committedShare: posture.Total > 0 ? (posture.Committed || 0) / posture.Total : null,
    recommendations: ((d.recommendations || [])[0] || {}).Count ?? 0,
    transactions: ((d.transactions || [])[0] || {}).Count ?? 0,
  };
}

function aiAllocationTable(k) {
  const rows = [
    { Dimension: "Application tag", Covered: k.alloc.App || 0 },
    { Dimension: "Owner / team tag", Covered: k.alloc.Owner || 0 },
    { Dimension: "Cost center", Covered: k.alloc.CostCenter || 0 },
    { Dimension: "Resource group", Covered: k.alloc.ResourceGroup || 0 },
  ];
  if (k.allocTotal <= 0) return `<p class="muted" style="font-size:12px">No AI/ML estate cost in range.</p>`;
  const money = moneyColumn(rows, "Covered");
  return wideTable(tableHtml([
    { label: "Dimension", align: "left", get: (r) => esc(r.Dimension) },
    { label: "Covered cost", get: (r) => money(r.Covered) },
    { label: "Coverage", get: (r) => {
      const pct = r.Covered / k.allocTotal;
      const cls = pct >= 0.85 ? "pos" : pct >= 0.65 ? "warn" : "neg";
      return `<span class="${cls}">${fmtShare(pct)}</span>`;
    } },
  ], rows));
}

function aiPostureTable(k) {
  // Counts are descriptive: a zero means no AI-scoped records were ingested,
  // which is a different statement from "no opportunity exists".
  const rows = [
    {
      Signal: "Commitment coverage",
      Value: k.committedShare == null ? "—" : fmtPct(k.committedShare),
      Note: k.committedShare ? "AI/ML estate cost on a commitment discount" : "No AI/ML spend is on a commitment discount",
    },
    {
      Signal: "AI-scoped rate recommendations",
      Value: fmtInt(k.recommendations),
      Note: k.recommendations > 0 ? "Open recommendations touching AI/ML resource types" : "None ingested for AI/ML resource types",
    },
    {
      Signal: "AI-scoped commitment transactions",
      Value: fmtInt(k.transactions),
      Note: k.transactions > 0 ? "Purchase or refund events matching AI/GPU descriptions" : "None ingested matching AI/GPU descriptions",
    },
  ];
  return wideTable(tableHtml([
    { label: "Signal", align: "left", get: (r) => esc(r.Signal) },
    { label: "Value", get: (r) => r.Value },
    { label: "Detail", align: "left", get: (r) => `<span class="muted">${esc(r.Note)}</span>` },
  ], rows));
}

function aiDriversTable(rows, k) {
  const money = moneyColumn(rows, "Prev", "Cost");
  const delta = moneyColumn(rows, "Change");
  // Below half a cent the change is a rounding artefact, not a movement: format
  // it as a flat zero so it can't render as a signed "-$0.00 (-0.0%)" and can't
  // pick up a directional colour.
  const EPS = 0.005;
  return wideTable(tableHtml([
    { label: "Service", align: "left", get: (r) => nameCell(r.Service, 26) },
    { label: "Meter", align: "left", get: (r) => nameCell(r.Meter, 26) },
    { label: "Prior month", get: (r) => money(r.Prev) },
    { label: k.closedMonth ? fmtMonth(k.closedMonth) : "Latest month", get: (r) => money(r.Cost) },
    { label: "Change", get: (r) => {
      const chg = Math.abs(r.Change || 0) < EPS ? 0 : r.Change;
      const cls = chg > 0 ? "neg" : chg < 0 ? "pos" : "muted";
      if (chg === 0) return `<span class="muted">no change</span>`;
      // A zero baseline has no percentage; say so rather than leaving the
      // cell ragged against the rows that carry one.
      const pct = r.Prev > 0
        ? ` (${chg > 0 ? "+" : ""}${fmtShare(chg / r.Prev, 1)})`
        : ` (new)`;
      return `<span class="${cls}">${chg > 0 ? "+" : ""}${delta(chg)}${pct}</span>`;
    } },
  ], rows, "No month-over-month movement in range."));
}

function renderAi(p) {
  const content = el("content");
  if (!p) return;
  if (p.error) return renderError(p);
  if (p.empty) {
    content.innerHTML = `<div class="error"><h2>No AI or emerging workload data</h2>
      <p>No AI, machine learning, or GPU-accelerated spend was found in the <code>Hub</code> database for this period.</p>
      <p class="muted">This view scopes to the <code>AI and Machine Learning</code> service category, Azure AI Search, Azure Databricks, and GPU VM series (NC/ND/NV/NG). Ingest cost data covering those workloads, then refresh.</p></div>`;
    return;
  }
  const d = p.data;
  const k = deriveAiKpis(d, p.lastClosedMonth);

  const momTxt = k.mom == null ? null : `${k.mom > 0 ? "+" : ""}${fmtPct(k.mom, 1)}`;
  const momCls = k.mom == null ? "muted" : k.mom > 0 ? "neg" : "pos";
  const estateMeta = momTxt
    ? `<span class="${momCls}">${momTxt}</span> vs prior · ${esc(fmtMonth(k.closedMonth))}`
    : `${fmtPct(k.estateShare, 1)} of all cloud cost`;

  const covCls = k.appCoverage == null ? undefined
    : k.appCoverage >= 0.85 ? "threshold-green" : k.appCoverage >= 0.65 ? "threshold-amber" : "threshold-red";

  const cpmtTrend = (d.monthly || [])
    .filter((r) => (r.Tokens || 0) > 0)
    .map((r) => ({ Month: r.Month, Cpmt: (r.TokenCost / r.Tokens) * 1000000 }));

  const kpis = [
    kpiCard("AI/ML estate spend", fmtMoney(k.estate), estateMeta, PALETTE[2], undefined, "primary"),
    kpiCard("ML & GPU compute", fmtMoney(k.mlGpu), `${fmtPct(k.mlGpuShare, 1)} of AI/ML estate`, PALETTE[9]),
    kpiCard("Token volume", fmtTokens(k.tokens), `${fmtMoney(k.tokenCost)} in token meters`, PALETTE[0]),
    kpiCard("Cost per 1M tokens", k.cpmt == null ? "—" : fmtRate(k.cpmt),
      k.cpmt == null ? "No token meters in range" : "Blended across all model families", PALETTE[5]),
    kpiCard("AI allocation coverage", k.appCoverage == null ? "—" : fmtPct(k.appCoverage),
      k.appCoverage == null ? "No AI/ML estate cost in range" : "Carrying an application tag",
      PALETTE[3], covCls),
    kpiCard("AI share of cloud", fmtPct(k.estateShare, 1), `${fmtMoney(k.estate)} of ${fmtMoney(k.cloud)}`, PALETTE[1], undefined, "reference"),
  ].join("");

  // One money scale per detail table, derived from that table's own maximum.
  const mlGpuMoney = moneyColumn(d.mlGpu, "Cost");
  const mlUnitMoney = moneyColumn(d.mlUnit, "Cost");
  const mlUnitVmRate = rateColumn(d.mlUnit, "PerVmHour");
  const mlUnitCoreRate = rateColumn(d.mlUnit, "Per1KCoreHours");
  const searchMoney = moneyColumn(d.search, "Cost");
  const cognitiveMoney = moneyColumn(d.cognitive, "Cost");

  const partialNote = k.partialMonth
    ? ` Month-over-month figures compare ${esc(fmtMonth(k.closedMonth))} against the month before it; ${esc(fmtMonth(k.partialMonth))} is still ingesting and is excluded from those comparisons.`
    : "";

  content.innerHTML = `
    <div class="kpi-grid">${kpis}</div>

    <p class="scope-note">This view scopes to the <strong>AI and Machine Learning</strong> service category plus Azure AI Search, Azure Databricks, and GPU VM series (NC/ND/NV/NG). GPU capacity bought outside those services — or AI work running on general-purpose compute — will not appear here.${partialNote}</p>

    <div class="section-title"><h2>AI/ML estate</h2><span class="domain">Workload composition</span></div>
    <div class="panel-grid">
      ${panelHtml("ai-capability-trend", 12, "AI spend by capability over time", "Monthly effective cost split across AI capability groups.", aiCapabilityChart(d.capabilityTrend))}
      ${panelHtml("ai-capability", 6, "Estate composition", "Effective cost and distinct services per capability.", aiCapabilityTable(d.capability, k.estate))}
      ${panelHtml("ai-by-service", 6, "Estate spend by service", "Top billing services in the AI/ML estate.",
        hbar(d.byService, "Service", "Cost", { filterDim: "ServiceName", nameW: 210, color: PALETTE[2], label: "AI/ML estate spend by service" }))}
    </div>

    <div class="section-title"><h2>Token &amp; model economics</h2><span class="domain">Unit economics</span></div>
    <div class="panel-grid">
      ${panelHtml("ai-token-demand", 6, "Token demand", "Monthly token volume across all foundation model meters.",
        monthAreaChart(d.monthly, { valueKey: "Tokens", color: PALETTE[2], valFmt: fmtTokens, label: "Monthly token volume" }))}
      ${panelHtml("ai-cpmt-trend", 6, "Cost per 1M tokens", "Blended effective rate — the direction of travel matters more than the level.",
        monthAreaChart(cpmtTrend, { valueKey: "Cpmt", color: PALETTE[5], valFmt: axisRate, tipFmt: fmtRate, label: "Blended cost per 1M tokens" }))}
      ${panelHtml("ai-model-bench", 6, "Model family benchmark", "Cost per 1M tokens by model family — the input to model selection.", aiModelBenchTable(d.modelBench))}
      ${panelHtml("ai-direction", 6, "Token direction mix", "Input, cached input, output, and embedding meters.", aiDirectionTable(d.direction))}
    </div>

    <div class="section-title"><h2>Workload detail</h2><span class="domain">Compute, retrieval &amp; applied AI</span></div>
    <div class="panel-grid">
      ${panelHtml("ai-ml-gpu", 12, "ML platform &amp; GPU compute", "Components behind machine learning and accelerated compute spend.",
        wideTable(tableHtml([
          { label: "Component", align: "left", get: (r) => nameCell(r.Component, 28) },
          { label: "Unit", align: "left", get: (r) => nameCell(r.Unit, 16) },
          { label: "Quantity", get: (r) => fmtQty(r.Quantity) },
          { label: "Cost", get: (r) => mlGpuMoney(r.Cost) },
        ], d.mlGpu)))}
      ${panelHtml("ai-search", 12, "AI Search / retrieval", "Azure AI Search meters supporting retrieval-augmented generation.",
        wideTable(tableHtml([
          { label: "Meter", align: "left", get: (r) => nameCell(r.Meter, 28) },
          { label: "Unit", align: "left", get: (r) => nameCell(r.Unit, 16) },
          { label: "Quantity", get: (r) => fmtQty(r.Quantity) },
          { label: "Cost", get: (r) => searchMoney(r.Cost) },
        ], d.search, "No Azure AI Search meters in range.")))}
      ${panelHtml("ai-ml-unit", 6, "ML compute unit economics", "Effective rate per VM-hour and per 1K core-hours by VM series.",
        wideTable(tableHtml([
          { label: "Series", align: "left", get: (r) => nameCell(r.Series, 24) },
          { label: "VM hours", get: (r) => fmtQty(r.VmHours) },
          { label: "$ / VM-hour", get: (r) => mlUnitVmRate(r.PerVmHour) },
          { label: "$ / 1K core-hours", get: (r) => mlUnitCoreRate(r.Per1KCoreHours) },
          { label: "Cost", get: (r) => mlUnitMoney(r.Cost) },
        ], d.mlUnit, "No ML virtual machine meters in range.")))}
      ${panelHtml("ai-cognitive", 6, "Cognitive &amp; applied AI", "Speech, vision, language, and video services, excluding token meters.",
        wideTable(tableHtml([
          { label: "Service", align: "left", get: (r) => nameCell(r.Service, 30) },
          { label: "Quantity", get: (r) => fmtQty(r.Units) },
          { label: "Cost", get: (r) => cognitiveMoney(r.Cost) },
        ], d.cognitive, "No cognitive or applied AI meters in range.")))}
    </div>

    <div class="section-title"><h2>Allocation &amp; posture</h2><span class="domain">Accountability &amp; rate optimization</span></div>
    <div class="panel-grid">
      ${panelHtml("ai-allocation", 6, "Allocation coverage", "Share of AI/ML estate cost carrying each accountability dimension.", aiAllocationTable(k))}
      ${panelHtml("ai-by-owner", 6, "Estate spend by owner", "Owner or team tag, falling back to cost center then resource group. Tag values are folded case-insensitively.",
        hbar(d.byOwner, "Owner", "Cost", { filterDim: null, nameW: 210, color: PALETTE[2], label: "AI/ML estate spend by owner" }))}
      ${panelHtml("ai-posture", 12, "Commitment &amp; rate posture", "Whether AI/ML spend is on a commitment, and which AI-scoped rate signals were ingested.", aiPostureTable(k))}
      ${panelHtml("ai-drivers", 12, "Top movers", `Largest AI/ML meters, ${k.closedMonth ? `${esc(fmtMonth(k.closedMonth))} against the month before it` : "latest month against the month before it"}.`, aiDriversTable(d.drivers, k))}
    </div>
  `;
}

/* --------------------------------------------- anomalies & forecast render */

function renderAnomaly(p) {
  const content = el("content");
  if (!p) return;
  if (p.error) return renderError(p);
  if (p.empty) {
    content.innerHTML = `<div class="error"><h2>No cost data</h2><p>The <code>Hub</code> database has no rows yet.</p></div>`;
    return;
  }
  const d = p.data;
  const daily = d.daily || [];
  const anomDays = daily.filter((r) => r.Flag !== 0);
  const totalCost = daily.reduce((a, r) => a + (r.Cost || 0), 0);
  const anomCost = anomDays.reduce((a, r) => a + (r.Cost || 0), 0);
  const variance = Math.abs(anomDays.reduce((a, r) => a + ((r.Cost || 0) - (r.Baseline || 0)), 0));
  const rate = totalCost > 0 ? anomCost / totalCost : 0;

  const fc = d.forecast || [];
  const dataMaxMonth = (p.window?.dataMax || "").slice(0, 7);
  const nextFc = fc.find((r) => r.Month > dataMaxMonth);

  const mc = (d.monthlyChange || []).filter((r) => isFinite(r.EffChangePct));
  // last complete month (skip the partial dataMax month for the headline KPI)
  const completeMc = mc.filter((r) => r.Month < dataMaxMonth);
  const lastMc = completeMc[completeMc.length - 1] || mc[mc.length - 1];

  const fr = d.freshness?.[0] || {};
  const p50Days = fr.P50 != null ? fr.P50 / 24 : null;

  const mcClass = lastMc == null ? "" : lastMc.EffChangePct > 0 ? "neg" : "pos"; // cost up = bad
  const mcArrow = lastMc == null ? "" : lastMc.EffChangePct > 0 ? "▲" : "▼";
  const mcValue = lastMc == null ? "—" : `<span class="${mcClass}">${mcArrow} ${fmtPct(Math.abs(lastMc.EffChangePct) / 100)}</span>`;

  const kpis = [
    // reference KPIs first (no primaries in this tab)
    kpiCard("Anomaly days", fmtInt(anomDays.length),
      `${fmtMoney(anomCost)} on flagged days`, undefined, undefined, "reference"),
    // supporting KPIs
    kpiCard("Anomaly detection rate", fmtPct(rate, 2),
      `% of effective spend on flagged days · ${fmtInt(anomDays.length)} of ${fmtInt(daily.length)} days flagged`, undefined),
    kpiCard("Unpredicted variance", fmtMoney(variance),
      `net spend vs baseline on anomaly days`, undefined),
    kpiCard("Last month change", mcValue,
      lastMc ? `effective cost · ${esc(fmtMonth(lastMc.Month))}` : "", undefined),
    kpiCard("Forecast next month", nextFc ? fmtMoney(nextFc.Forecast) : "—",
      nextFc ? `projected · ${esc(fmtMonth(nextFc.Month))}` : "", undefined),
    kpiCard("Visibility delay", p50Days != null ? `${p50Days.toFixed(0)}d` : "—",
      `median ingestion lag (P50)`, undefined),
  ].join("");

  const triageCallout = anomDays.length > 0
    ? `<div class="triage-callout" role="status"><span class="triage-callout-icon" aria-hidden="true">⚠</span>${fmtInt(anomDays.length)} anomal${anomDays.length === 1 ? "y day" : "y days"} detected — ${fmtMoney(anomCost)} in flagged spend. Review the chart below.</div>`
    : "";

  content.innerHTML = `
    ${triageCallout}
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>Cost anomalies</h2><span class="domain">Anomaly management capability</span></div>
    <div class="panel-grid">
      ${panelHtml("anomaly-daily", 12, "Daily cost &amp; detected anomalies", "Daily effective cost vs the expected baseline (STL decomposition); markers flag spikes &amp; drops.", anomalyChart(daily))}
    </div>

    <div class="section-title"><h2>Trend &amp; forecast</h2><span class="domain">Forecasting · Data freshness</span></div>
    <div class="panel-grid">
      ${panelHtml("anomaly-mom", 6, "Month-over-month change", "Effective cost % change vs prior month (red = increase).", momBars(mc))}
      ${panelHtml("anomaly-forecast", 6, "Cost forecast", "Monthly effective cost, actual vs forecast (next 3 months).", forecastChart(fc, dataMaxMonth))}
    </div>
  `;
}

/* ----------------------------------------------- usage & unit economics render */

function renderUsage(p) {
  const content = el("content");
  if (!p) return;
  if (p.error) return renderError(p);
  if (p.empty) {
    content.innerHTML = `<div class="error"><h2>No cost data</h2><p>The <code>Hub</code> database has no rows yet.</p></div>`;
    return;
  }
  const d = p.data;
  const c = d.compute?.[0] || {};
  const s = d.storage?.[0] || {};
  const coreHours = c.CoreHours || 0;
  const hourlyPerCore = coreHours > 0 ? c.ComputeEff / coreHours : 0;
  const effPerCore = coreHours > 0 ? (c.ComputeEff + (c.UnusedCommit || 0)) / coreHours : 0;
  const gbMonths = s.GBMonths || 0;
  const perGB = gbMonths > 0 ? s.Cost / gbMonths : 0;
  const total = d.total?.[0]?.Total || 0;

  const kpis = [
    kpiCard("Hourly cost / core", `$${hourlyPerCore.toFixed(3)}`,
      `per consumed vCPU-hour`, PALETTE[0], undefined, "primary"),
    kpiCard("Effective cost / core", `$${effPerCore.toFixed(3)}`,
      `incl. unused commitment`, PALETTE[2], undefined, "reference"),
    kpiCard("Compute core-hours", fmtTokens(coreHours),
      `${fmtMoney(c.ComputeEff)} VM usage`, PALETTE[1]),
    kpiCard("Storage rate", `$${(perGB * 1024).toFixed(3)}`,
      `per TB-month (effective)`, PALETTE[5]),
    kpiCard("Storage volume", `${fmtTokens(gbMonths)}`,
      `GB-months stored`, PALETTE[8]),
    kpiCard("Storage cost", fmtMoney(s.Cost),
      `effective storage spend`, PALETTE[3]),
  ].join("");

  const typeRows = (d.topResourceTypes || []).map((r) => ({
    type: r.ResourceType, count: r.Resources || 0, cost: r.Cost || 0,
    pct: total > 0 ? (r.Cost || 0) / total : 0,
  }));
  const typeTable = tableHtml([
    { label: "Resource type", align: "left", get: (r, i) => `<span class="model">${swatchHtml(PALETTE[i % PALETTE.length])}${esc(r.type)}</span>` },
    { label: "Resources", get: (r) => fmtInt(r.count) },
    { label: "Effective cost", get: (r) => fmtMoneyFull(r.cost) },
    { label: "% of total", get: (r) => fmtPct(r.pct) },
  ], typeRows);

  const tierColors = { "Frequent": PALETTE[1], "Infrequent": PALETTE[5], "Unclassified": UNKNOWN_COLOR };
  const tierSlices = (d.storageTiers || []).map((r) => ({ label: r.Tier, value: r.Cost || 0, color: tierColors[r.Tier] || PALETTE[6], isUnknown: r.Tier === "Unclassified" }));
  const freqShare = (() => {
    const t = tierSlices.reduce((a, x) => a + x.value, 0);
    const f = (d.storageTiers || []).find((r) => r.Tier === "Frequent");
    return t > 0 ? (f?.Cost || 0) / t : 0;
  })();

  content.innerHTML = `
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>Usage &amp; unit economics</h2><span class="domain">Usage optimization · Unit economics</span></div>
    <div class="panel-grid">
      ${panelHtml("usage-top-types", 12, "Top resource types by cost", "Resource count and effective spend per resource type.", typeTable)}
      ${panelHtml("usage-per-core-series", 6, "Compute cost per core by VM series", "Effective cost per vCPU-hour — highlights expensive (e.g. GPU) cores.",
        hbar(d.perCoreSeries, "x_SkuMeterSubcategory", "PerCore", { valFmt: (v) => `$${v.toFixed(3)}`, label: "Compute cost per core by VM series" }))}
      ${panelHtml("usage-storage-tiers", 6, `Storage tier distribution`, `Effective storage cost by access tier (${fmtPct(freqShare)} classified frequent).`,
        donut(tierSlices, { centerBig: fmtMoney(s.Cost), centerSmall: "storage", label: "Storage tier distribution" }))}
    </div>
  `;
}

function renderRate(p) {
  const content = el("content");
  if (!p) return;
  if (p.error) return renderError(p);
  if (p.empty) {
    content.innerHTML = `<div class="error"><h2>No cost data</h2><p>The <code>Hub</code> database has no rows yet.</p></div>`;
    return;
  }
  const d = p.data;
  const s = d.savings?.[0] || {};
  const cm = d.commitment?.[0] || {};
  const cc = d.computeCoverage?.[0] || {};
  const esr = s.List > 0 ? s.Total / s.List : 0;
  const cmTotal = cm.Total || 0;
  const util = cmTotal > 0 ? (cmTotal - (cm.Unused || 0)) / cmTotal : 0;
  const waste = cmTotal > 0 ? (cm.Unused || 0) / cmTotal : 0;
  const coverage = cc.Contracted > 0 ? cc.Committed / cc.Contracted : 0;
  const coreTotal = (d.coreHours || []).reduce((a, r) => a + (r.CoreHours || 0), 0);
  const committedCore = (d.coreHours || []).filter((r) => r.t !== "On Demand").reduce((a, r) => a + (r.CoreHours || 0), 0);
  const coreShare = coreTotal > 0 ? committedCore / coreTotal : 0;
  // Single source of truth for "Commitment waste" coloring: derive the meta
  // text color from the same threshold the card border uses, instead of a
  // separately hardcoded 0.1 cutoff that could silently drift out of sync.
  const wasteThreshold = kpiThreshold(waste, 0.10, 0.20);
  const wasteMetaCls = wasteThreshold === "threshold-red" ? "neg" : wasteThreshold === "threshold-amber" ? "warn" : "pos";

  const kpis = [
    // primary KPIs first
    kpiCard("Effective savings rate", fmtPct(esr),
      `<span class="pos">${fmtMoney(s.Total)}</span> total savings · vs. list price`, PALETTE[1], undefined, "primary"),
    kpiCard("Commitment waste", fmtPct(waste),
      `<span class="${wasteMetaCls}">${fmtMoney(cm.Unused)}</span> unused · of commitment spend`, PALETTE[3],
      wasteThreshold, "primary"),
    // supporting KPIs
    kpiCard("Total savings", fmtMoney(s.Total),
      `of ${fmtMoney(s.List)} list cost`, PALETTE[2]),
    (() => {
      const cusRow = (d.commitmentUtilScore || []).find((r) => r.CommitmentDiscountName === '(Grand Total)');
      const cusScore = cusRow ? cusRow.Score / 100 : util;
      return kpiCard("Commitment utilization", fmtPct(cusScore),
        cusRow
          ? `${fmtMoney(cusRow.Amount)} utilized of ${fmtMoney(cusRow.Potential)} potential`
          : `${fmtMoney(cmTotal - (cm.Unused || 0))} of ${fmtMoney(cmTotal)} used`,
        PALETTE[0]);
    })(),
    // reference KPIs
    kpiCard("Compute coverage", fmtPct(coverage),
      `compute spend on commitments`, PALETTE[5], undefined, "reference"),
    // supporting KPIs
    kpiCard("Committed core-hours", fmtPct(coreShare),
      `RI + savings plan vs on-demand`, PALETTE[8], undefined, "reference"),
  ].join("");

  const savingsBreak = costBreakdownTable([
    { label: "List cost (excl. commitment purchases)", val: s.List, accent: "var(--muted)" },
    { label: "Negotiated savings", val: s.Negotiated, accent: PALETTE[8] },
    { label: "Commitment savings", val: s.Commitment, accent: PALETTE[1] },
    { label: "Effective cost", val: s.Effective, accent: PALETTE[0] },
  ], "Effective savings rate", fmtPct(esr));

  const coreColors = { "On Demand": PALETTE[0], "Reservation": PALETTE[1], "Savings Plan": PALETTE[4] };
  const coreSlices = (d.coreHours || []).map((r) => ({ label: r.t, value: r.CoreHours || 0, color: coreColors[r.t] || PALETTE[6] }));

  const underutilCount = (d.byCommitment || []).filter((r) => (r.Unused || 0) > 0).length;
  const rateCallout = underutilCount > 0
    ? `<div class="triage-callout" role="status"><span class="triage-callout-icon" aria-hidden="true">⚠</span>${fmtInt(underutilCount)} underutilized commitment${underutilCount === 1 ? "" : "s"} found — ${fmtMoney(cm.Unused)} in unused spend. See the commitments panel below.</div>`
    : "";

  content.innerHTML = `
    ${rateCallout}
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>Rate optimization</h2><span class="domain">Rate optimization capability</span></div>
    <div class="panel-grid">
      ${panelHtml("rate-savings", 6, "Savings breakdown", "List → effective cost by discount type (effective savings rate).", savingsBreak)}
      ${panelHtml("rate-commit-util", 6, "Commitment utilization", "Used vs unused commitment effective cost.",
        donut([
          { label: "Used", value: cmTotal - (cm.Unused || 0), color: PALETTE[1] },
          { label: "Unused (waste)", value: cm.Unused || 0, color: PALETTE[3] },
        ], { centerBig: fmtPct(util), centerSmall: "utilized", label: "Commitment utilization" }))}
      ${panelHtml("rate-core-hours", 6, "Core-hour coverage", "Consumed core-hours by commitment type.",
        donut(coreSlices, {
          centerBig: fmtPct(coreShare), centerSmall: "committed",
          valueFmt: (s) => `${fmtTokens(s.value)} core-hrs`,
          label: "Core-hour coverage",
        }))}
      ${panelHtml("rate-underutil", 6, "Underutilized commitments", "Reservations &amp; plans with the most unused cost.",
        hbar(d.byCommitment, "CommitmentDiscountName", "Unused", { label: "Underutilized commitments" }))}
    </div>

    <div class="section-title"><h2>Commitment transactions</h2><span class="domain">Rate optimization · Commitment purchasing</span></div>
    <div class="panel-grid">
      ${panelHtml("rate-commit-score", 6, "Commitment utilization score", "Per-commitment utilization (used vs potential) from the formal CUS KPI.", commitUtilTable(d.commitmentUtilScore))}
      ${panelHtml("rate-top-txns", 6, "Top commitment transactions", "Largest RI and savings plan purchases by billed cost. Effective cost is $0 by design — amortization credits the cost to the months the commitment is consumed, not the purchase month.", topCommitTxnTable(d.topCommitmentTxns))}
    </div>
  `;
}

function commitUtilTable(rows) {
  const data = (rows || []).filter((r) => r.CommitmentDiscountName !== '(Grand Total)' && (r.Potential || 0) > 0);
  if (data.length === 0) return `<p class="muted" style="font-size:12px">No commitment data in range.</p>`;
  return `<table class="dtable">
    <thead><tr><th scope="col">Commitment</th><th scope="col">Type</th><th scope="col">Score</th><th scope="col">Utilized</th><th scope="col">Potential</th></tr></thead>
    <tbody>${data.map((r) => {
      const score = r.Score || 0;
      const cls = score < 70 ? "neg" : score < 90 ? "warn" : "pos";
      const barW = Math.max(2, (score / 100) * 90);
      return `<tr>
        <td class="truncate-hint" style="max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${esc(r.CommitmentDiscountName)}">${esc(r.CommitmentDiscountName)}</td>
        <td class="muted">${esc(r.CommitmentDiscountType || r.CommitmentDiscountCategory || "")}</td>
        <td class="barcell"><span class="${cls}">${fmtPct(score / 100)}</span><span class="minibar" style="width:${barW}px;background:${score < 70 ? "var(--neg)" : score < 90 ? "var(--warn)" : "var(--pos)"}"></span></td>
        <td>${fmtMoney(r.Amount)}</td>
        <td>${fmtMoney(r.Potential)}</td>
      </tr>`;
    }).join("")}</tbody>
  </table>`;
}

function topCommitTxnTable(rows) {
  const data = rows || [];
  if (data.length === 0) return `<p class="muted" style="font-size:12px">No commitment transactions in range.</p>`;
  return `<table class="dtable">
    <thead><tr><th scope="col">Commitment</th><th scope="col">Type</th><th scope="col">Billed cost</th><th scope="col">Effective cost</th></tr></thead>
    <tbody>${data.map((r) => `<tr>
      <td class="truncate-hint" style="max-width:180px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${esc(r.CommitmentDiscountName || "(unknown)")}">${esc(r.CommitmentDiscountName || "(unknown)")}</td>
      <td class="muted">${esc(r.CommitmentDiscountType || "")}</td>
      <td>${fmtMoney(r.BilledCost)}</td>
      <td>${fmtMoney(r.EffectiveCost)}</td>
    </tr>`).join("")}</tbody>
  </table>`;
}

/* ----------------------------------------------------- allocation render */

function renderAllocation(p) {
  const content = el("content");
  if (!p) return;
  if (p.error) return renderError(p);
  if (p.empty) {
    content.innerHTML = `<div class="error"><h2>No cost data</h2><p>The <code>Hub</code> database has no rows yet.</p></div>`;
    return;
  }
  const d = p.data;
  const c = d.core?.[0] || {};
  const total = c.Total || 0;
  const aai = total > 0 ? c.Attributed / total : 0;
  const untaggedPct = total > 0 ? c.Untagged / total : 0;
  const unallocPct = total > 0 ? (total - c.Attributed) / total : 0;
  const compliancePct = total > 0 ? c.Compliant / total : 0;

  const kpis = [
    // primary KPIs first
    kpiCard("Untagged cost", fmtPct(untaggedPct),
      `${fmtMoney(c.Untagged)} with no tags`, PALETTE[3],
      kpiThreshold(untaggedPct, 0.10, 0.25), "primary"),
    // supporting KPIs
    kpiCard("Allocation accuracy", fmtPct(aai),
      `<span class="pos">directly attributed</span> effective cost`, PALETTE[1]),
    kpiCard("Unallocated cost", fmtPct(unallocPct),
      `${fmtMoney(total - c.Attributed)} lacks ownership attribution`, PALETTE[4]),
    kpiCard("Tag policy compliance", fmtPct(compliancePct),
      `keys: CostCenter · env · org`, PALETTE[5]),
    kpiCard("Subscriptions", fmtInt(c.Subs),
      `billing scopes in range`, PALETTE[0]),
    kpiCard("Allocated cost", fmtMoney(c.Attributed),
      `of ${fmtMoney(total)} total`, PALETTE[2]),
  ].join("");

  const hierRows = (d.hierarchy || []).map((r) => ({
    org: r.Org || "—", project: r.Project || "—", env: r.Env || "—", cost: r.Cost || 0,
    pct: total > 0 ? (r.Cost || 0) / total : 0,
  }));
  const hierTable = tableHtml([
    {
      label: "Org", align: "left", get: (r, i) => {
        const isUnknown = r.org === "—" && r.project === "—" && r.env === "—";
        return `<span class="model">${swatchHtml(PALETTE[i % PALETTE.length], isUnknown)}${esc(r.org)}</span>`;
      },
    },
    { label: "Project", align: "left", get: (r) => esc(r.project) },
    { label: "Environment", align: "left", get: (r) => esc(r.env) },
    { label: "Effective cost", get: (r) => fmtMoneyFull(r.cost) },
    { label: "% of total", get: (r) => fmtPct(r.pct) },
  ], hierRows);

  // Flag case-variant duplicate tag keys (e.g. "CostCenter" vs "costcenter")
  // so the governance issue is called out, not hidden by treating them as
  // separate keys.
  const tagKeyRows = d.tagKeys || [];
  const lowerCounts = {};
  tagKeyRows.forEach((r) => { const lk = String(r.k).toLowerCase(); lowerCounts[lk] = (lowerCounts[lk] || 0) + 1; });
  const dupKeys = tagKeyRows.filter((r) => lowerCounts[String(r.k).toLowerCase()] > 1).map((r) => r.k);
  const tagKeyNote = dupKeys.length > 0
    ? ` <strong>Note:</strong> ${dupKeys.map((k) => `<code>${esc(k)}</code>`).join(" vs ")} are case-variant duplicates of the same governance key — likely inconsistent tagging, not distinct keys.`
    : "";

  content.innerHTML = `
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>Cost allocation</h2><span class="domain">Allocation capability</span></div>
    <div class="panel-grid">
      ${panelHtml("alloc-hierarchy", 8, "Cost by financial hierarchy", "Org → project → environment (from resource tags), with share of total.", hierTable)}
      ${panelHtml("alloc-tagging", 4, "Tagging coverage", "Tagged vs untagged effective cost.",
        donut([
          { label: "Tagged", value: total - c.Untagged, color: PALETTE[1] },
          { label: "Untagged", value: c.Untagged, color: UNKNOWN_COLOR, isUnknown: true },
        ], { centerBig: fmtPct(1 - untaggedPct), centerSmall: "tagged", label: "Tagging coverage" }))}
      ${panelHtml("alloc-tag-keys", 6, "Cost by tag key", `Effective cost touched by each governance tag.${tagKeyNote}`, hbar(d.tagKeys, "k", "Cost", { filterDim: null, label: "Cost by tag key" }))}
      ${panelHtml("alloc-by-subscription", 6, "Cost by subscription", "Spend per billing scope for showback.", hbar(d.bySubscription, "SubAccountName", "Cost", { label: "Cost by subscription" }))}
    </div>
  `;
}

const CAPACITY_ACTIONS = Object.freeze({
  "app-service": "Validate region access and SKU availability separately before requesting an exact SKU quota increase.",
  "azure-ai": "Validate model availability, deployment scope, and actual capacity separately from the provider quota row.",
  compute: "Check both total regional and applicable VM-family vCPU quota, then validate SKU, zone, and physical capacity separately.",
  "azure-sql": "Use the exact SQL metric and service workflow. Do not treat countdown or negative-limit rows as generic utilization.",
  storage: "Validate ingestion and expected subscription-region coverage before drawing a Storage quota conclusion.",
  "capacity-reservations": "Inspect reservation quantity, SKU, zones, sharing, associations, and utilization in Azure; inventory count is not reserved capacity.",
  "premium-ssd-v2": "Inspect disk zone, attachment, IOPS, throughput, and service quota separately; observed GiB is inventory, not quota.",
});

const CAPACITY_STATE_LABELS = Object.freeze({
  healthy: "Healthy",
  watch: "Watch",
  action: "Action",
  exhausted: "Exhausted",
  restricted: "Region restricted",
  "zone-restricted": "All zones restricted",
  "no-entitlement": "No quota",
  inventory: "Observed inventory",
  unclassified: "Unknown or unclassified",
  stale: "Stale",
  invalid: "Invalid or conflict",
});

export function capacitySelectionFromRow(kind, classId, row) {
  if (!row || typeof row !== "object") return null;
  if (kind === "quota") {
    if (classId === "capacity-reservations" || classId === "premium-ssd-v2") {
      return { resourceId: String(row.ResourceId || "") };
    }
    return {
      subAccountId: String(row.SubAccountId || ""),
      location: String(row.location || ""),
      resourceName: String(row.ResourceName || ""),
      unit: String(row.unit || ""),
      sourceVersion: String(row.x_SourceVersion || ""),
    };
  }
  if (kind === "metric") {
    return {
      resourceName: String(row.ResourceName || ""),
      unit: String(row.unit || ""),
      sourceVersion: String(row.x_SourceVersion || ""),
    };
  }
  const selection = {
    meterCategory: String(row.x_SkuMeterCategory || ""),
    meterSubcategory: String(row.x_SkuMeterSubcategory || ""),
    meter: String(row.SkuMeter || ""),
    priceId: String(row.SkuPriceId || ""),
    currency: String(row.BillingCurrency || ""),
  };
  if (classId === "premium-ssd-v2") selection.resourceId = String(row.InventoryResourceId || "");
  else selection.unit = String(row.ConsumedUnit || "");
  if (classId === "capacity-reservations") {
    selection.capacityReservationId = String(row.CapacityReservationId || "");
    selection.capacityReservationStatus = String(row.CapacityReservationStatus || "");
  }
  return selection;
}

function sameCapacitySelection(left, right) {
  return JSON.stringify(left || null) === JSON.stringify(right || null);
}

function capacityNavigationHtml() {
  return `<nav class="capacity-tabs" role="tablist" aria-label="Quota types">
    ${CAPACITY_TABS.map((item) => {
      const active = item.id === state.capacityClass;
      return `<button id="capacity-tab-${esc(item.id)}" data-capacity-class="${esc(item.id)}" role="tab" aria-selected="${active}" aria-controls="capacity-panel" tabindex="${active ? "0" : "-1"}" class="${active ? "active" : ""}" type="button">${esc(item.label)}</button>`;
    }).join("")}
  </nav>`;
}

function capacityPanel(title, subtitle, body, wide = false) {
  return `<section class="capacity-panel${wide ? " capacity-panel--wide" : ""}">
    <header><h3>${esc(title)}</h3>${subtitle ? `<p>${esc(subtitle)}</p>` : ""}</header>
    <div class="capacity-panel-body">${body}</div>
  </section>`;
}

function capacityStateToken(semantic = {}) {
  const stateName = semantic.state || "unclassified";
  const label = CAPACITY_STATE_LABELS[stateName] || stateName;
  return `<span class="capacity-state capacity-state--${esc(stateName)}">${esc(label)}</span>`;
}

function capacityHomeTable(classes) {
  const rows = classes || [];
  return `<div class="capacity-table-scroll"><table class="dtable capacity-index">
    <thead><tr><th scope="col">Quota area</th><th scope="col">Type</th><th scope="col">Observations</th><th scope="col">Resources</th><th scope="col">Snapshot days</th><th scope="col">Last seen</th></tr></thead>
    <tbody>${rows.map((item) => {
      const summary = item.summary || {};
      const observed = Number(summary.Observations || 0) > 0;
      return `<tr>
        <td><button type="button" class="capacity-link" data-capacity-class="${esc(item.id)}">${esc(item.title)}</button><div class="capacity-source-note">${esc(item.sourceNote)}</div></td>
        <td>${esc(item.quotaType === "inventory" ? "Inventory" : "Provider metric")}</td>
        <td>${observed ? fmtInt(summary.Observations) : "Not reported"}</td>
        <td>${observed ? fmtInt(summary.Resources) : "—"}</td>
        <td>${observed ? fmtInt(summary.DistinctDays) : "—"}</td>
        <td>${summary.LatestObservation ? esc(fmtRelativeTime(new Date(summary.LatestObservation))) : "—"}</td>
      </tr>`;
    }).join("")}</tbody>
  </table></div>`;
}

function capacitySelectorHtml(kind, classId, items, currentSelection) {
  const isDemand = kind === "demand";
  const isMetric = kind === "metric";
  const label = isDemand ? "Billed demand series" : isMetric ? "Quota metric" : "Quota or inventory series";
  const options = (items || []).map((row, index) => {
    const selection = capacitySelectionFromRow(kind, classId, row);
    const selected = sameCapacitySelection(selection, currentSelection);
    const display = isDemand
      ? classId === "premium-ssd-v2"
        ? `${row.DiskName || row.InventoryResourceId} · ${row.SkuMeter || "No matched cost"} · ${row.BillingCurrency || "—"}`
        : `${row.SkuMeter || row.x_SkuMeterSubcategory || "Unknown meter"} · ${row.ConsumedUnit || "—"} · ${row.BillingCurrency || "—"}`
      : isMetric
        ? `${row.displayName || row.ResourceName || "Unknown metric"} · ${row.unit || "—"}`
        : `${row.ResourceName || row.displayName || "Unknown"} · ${row.SubAccountId || "—"} · ${row.location || "—"}`;
    const disabled = Object.values(selection || {}).some((value) => !value);
    return `<option value="${index}"${selected ? " selected" : ""}${disabled ? " disabled" : ""}>${esc(display)}</option>`;
  }).join("");
  return `<label class="capacity-selector">
    <span>${esc(label)}</span>
    <select data-capacity-selector="${esc(kind)}">
      <option value="">Select an exact ${isDemand ? "meter" : isMetric ? "metric" : "source"} key</option>
      ${options}
    </select>
  </label>`;
}

function formatCapacityValue(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return "—";
  return number.toLocaleString("en-US", { maximumFractionDigits: 2 });
}

function capacityCurrentTable(payload) {
  const inventory = payload.contract?.quotaType === "inventory";
  const rows = payload.table?.rows || [];
  const columns = [
    { label: "Subscription", align: "left", get: (row) => esc(trunc(row.SubAccountId || "—", 28)) },
    { label: "Region", align: "left", get: (row) => esc(row.location || "—") },
    { label: inventory ? "Resource" : "Metric", align: "left", get: (row) => `<span title="${esc(row.ResourceId || "")}">${esc(row.displayName || row.ResourceName || "—")}</span>` },
    { label: inventory && payload.classId === "premium-ssd-v2" ? "Size GiB" : "Current", get: (row) => inventory && payload.classId === "capacity-reservations" ? "Observed" : formatCapacityValue(row.currentValue) },
    { label: "Limit", get: (row) => inventory ? "Not applicable" : formatCapacityValue(row.limit) },
    { label: "Unit", get: (row) => inventory && payload.classId === "premium-ssd-v2" ? "GiB" : esc(row.unit || "—") },
    { label: "Quota status", align: "left", get: (row) => `${capacityStateToken(row.semantic)}<span class="capacity-reason">${esc(row.semantic?.sourceNote || "")}</span>` },
    { label: "Ingested", get: (row) => esc(fmtRelativeTime(new Date(row.x_IngestionTime))) },
  ];
  return `<div class="capacity-table-scroll">${tableHtml(columns, rows, payload.contract?.emptyLabel)}</div>`;
}

export function capacityHeatmapCell(row, classId) {
  if (classId === "capacity-reservations") {
    return { value: Number(row.ObservedObjects || 0), text: `${fmtInt(row.ObservedObjects)} groups`, state: "inventory" };
  }
  if (classId === "premium-ssd-v2") {
    return { value: Number(row.ObservedGiB || 0), text: `${formatCapacityValue(row.ObservedGiB)} GiB`, state: "inventory" };
  }
  const semantic = row.semantic || {};
  return {
    value: semantic.utilizationPercent,
    text: Number.isFinite(semantic.utilizationPercent) ? `${semantic.utilizationPercent.toFixed(1)}%` : (CAPACITY_STATE_LABELS[semantic.state] || "Not reported"),
    state: semantic.state || "unclassified",
  };
}

function capacityHeatmap(payload) {
  const heatmap = payload.heatmap || {};
  if (heatmap.status === "heatmap-disabled") {
    return `<div class="capacity-notice capacity-notice--warning"><strong>Heatmap disabled.</strong> More than ${fmtInt(heatmap.limit)} observed cells matched. Refine the filters; no partial matrix was rendered.</div>`;
  }
  if (heatmap.status === "no-selection") {
    return `<div class="capacity-notice">Select one exact quota metric to enable the subscription-by-region matrix.</div>`;
  }
  const rows = heatmap.rows || [];
  if (!rows.length) return `<div class="capacity-notice">No quota data is available for this selection.</div>`;
  if (payload.contract?.quotaType !== "inventory" && !rows.some((row) => row.semantic?.capability === "enabled")) {
    return `<div class="capacity-notice"><strong>Heatmap unavailable.</strong> The selected metric is descriptive-only and cannot receive quota-health color.</div>`;
  }
  const subscriptions = [...new Set(rows.map((row) => row.SubAccountId || "Unknown subscription"))].sort();
  const regions = [...new Set(rows.map((row) => row.location || "Unknown region"))].sort();
  const cells = new Map(rows.map((row) => [`${row.SubAccountId || "Unknown subscription"}|${row.location || "Unknown region"}`, row]));
  return `<div class="capacity-table-scroll"><table class="capacity-heatmap">
    <caption>Subscription by region. Every colored cell includes the same value and state in text.</caption>
    <thead><tr><th scope="col">Subscription</th>${regions.map((region) => `<th scope="col">${esc(region)}</th>`).join("")}</tr></thead>
    <tbody>${subscriptions.map((subscription) => `<tr>
      <th scope="row" title="${esc(subscription)}">${esc(trunc(subscription, 20))}</th>
      ${regions.map((region) => {
        const row = cells.get(`${subscription}|${region}`);
        if (!row) return `<td class="capacity-cell capacity-state--missing">Not reported</td>`;
        const cell = capacityHeatmapCell(row, payload.classId);
        return `<td class="capacity-cell capacity-state--${esc(cell.state)}"><strong>${esc(cell.text)}</strong><span>${esc(CAPACITY_STATE_LABELS[cell.state] || cell.state)}</span></td>`;
      }).join("")}
    </tr>`).join("")}</tbody>
  </table></div>`;
}

// A family and region pair is only meaningful to a capacity manager through one
// of these lenses. Counts are always computed over the unfiltered set so a lens
// can never become a dead end.
export const FAMILY_STATUS_FILTERS = [
  { id: "in-use", label: "In use", match: (row) => Number(row.CoresUsed || 0) > 0 },
  {
    id: "restricted",
    label: "Restricted",
    match: (row) => Boolean(row.semantic?.regionRestricted)
      || (Array.isArray(row.ZonesRestricted) && row.ZonesRestricted.length > 0),
  },
  { id: "no-quota", label: "No quota", match: (row) => Number(row.CoresTotal || 0) <= 0 },
  { id: "all", label: "All", match: () => true },
];

export const HIGH_WATER_MARKS = [60, 70, 80, 90];
export const DEFAULT_HIGH_WATER_MARK = 70;

// Demand is a separate channel from supply. The mark is where the operator wants
// to start reacting, so crossing it is the alarm and 100% stays visibly distinct.
export function familyDemandTier(utilizationPercent, mark = DEFAULT_HIGH_WATER_MARK) {
  if (!Number.isFinite(utilizationPercent)) return "none";
  if (utilizationPercent >= 100) return "exhausted";
  return utilizationPercent >= mark ? "over" : "under";
}

export function filterFamilyRows(rows, filter = {}) {
  const list = Array.isArray(rows) ? rows : [];
  const lens = FAMILY_STATUS_FILTERS.find((item) => item.id === filter.status) || FAMILY_STATUS_FILTERS[0];
  const needle = String(filter.search || "").trim().toLowerCase();
  const regions = Array.isArray(filter.regions) ? filter.regions : [];
  return list.filter((row) => {
    if (!lens.match(row)) return false;
    if (regions.length && !regions.includes(row.Location || "Unknown region")) return false;
    if (!needle) return true;
    return `${row.Family || ""} ${row.FamilyKey || ""}`.toLowerCase().includes(needle);
  });
}

function familyFilterBar(rows, filter, shownCells) {
  const counts = new Map(FAMILY_STATUS_FILTERS.map((lens) => [lens.id, rows.filter(lens.match).length]));
  const lensButtons = FAMILY_STATUS_FILTERS.map((lens) => `<button type="button" role="radio"
      class="capacity-segment" data-family-status="${esc(lens.id)}"
      aria-checked="${filter.status === lens.id ? "true" : "false"}"
      tabindex="${filter.status === lens.id ? "0" : "-1"}">${esc(lens.label)}
      <span class="capacity-segment-count">${fmtInt(counts.get(lens.id) || 0)}</span></button>`).join("");

  // Region chips list only the regions the active lens and search can still reach.
  const reachable = filterFamilyRows(rows, { ...filter, regions: [] });
  const regions = [...new Set(reachable.map((row) => row.Location || "Unknown region"))].sort();
  const regionButtons = regions.map((region) => `<button type="button"
      class="capacity-segment" data-family-region="${esc(region)}"
      aria-pressed="${filter.regions.includes(region) ? "true" : "false"}">${esc(region)}</button>`).join("");

  const mark = Number(filter.mark) || DEFAULT_HIGH_WATER_MARK;
  const markButtons = HIGH_WATER_MARKS.map((value) => {
    const over = rows.filter((row) => familyDemandTier(row.semantic?.utilizationPercent, value) !== "under"
      && Number.isFinite(row.semantic?.utilizationPercent)).length;
    return `<button type="button" role="radio"
      class="capacity-segment" data-family-mark="${value}"
      aria-checked="${mark === value ? "true" : "false"}"
      tabindex="${mark === value ? "0" : "-1"}">${value}%
      <span class="capacity-segment-count">${fmtInt(over)}</span></button>`;
  }).join("");

  const filtered = filter.status !== "all" || filter.search || filter.regions.length;
  return `<div class="capacity-filters" role="group" aria-label="Family matrix filters">
    <div class="capacity-filter-group">
      <span class="capacity-filter-label" id="family-lens-label">Show</span>
      <div class="capacity-segments" role="radiogroup" aria-labelledby="family-lens-label">${lensButtons}</div>
    </div>
    <div class="capacity-filter-group">
      <label class="capacity-filter-label" for="family-search">VM family</label>
      <input id="family-search" class="capacity-filter-search" type="search" data-family-search
        value="${esc(filter.search || "")}" placeholder="Filter by family, such as Dsv5"
        autocomplete="off" spellcheck="false">
    </div>
    ${regions.length > 1 ? `<div class="capacity-filter-group">
      <span class="capacity-filter-label" id="family-region-label">Region</span>
      <div class="capacity-segments capacity-segments--regions" role="group" aria-labelledby="family-region-label">${regionButtons}</div>
    </div>` : ""}
    <div class="capacity-filter-group">
      <span class="capacity-filter-label" id="family-mark-label">High-water mark</span>
      <div class="capacity-segments" role="radiogroup" aria-labelledby="family-mark-label">${markButtons}</div>
    </div>
    <p class="capacity-filter-summary" role="status">${fmtInt(shownCells)} of ${fmtInt(rows.length)} cells
      ${filtered ? `<button type="button" class="capacity-filter-reset" data-family-reset>Clear filters</button>` : ""}</p>
  </div>`;
}

function familyMatrixLegend(mark) {
  const supply = [
    ["open", "Open"],
    ["partial", "Some zones restricted"],
    ["blocked", "Region or all zones restricted"],
    ["none", "No quota"],
  ].map(([id, label]) => `<li><span class="capacity-legend-bar capacity-legend-bar--${id}" aria-hidden="true"></span>${esc(label)}</li>`).join("");
  const demand = [
    ["under", `Under ${mark}%`],
    ["over", `Over ${mark}% mark`],
    ["exhausted", "At or over 100%"],
  ].map(([id, label]) => `<li><span class="capacity-legend-ink capacity-demand--${id}" aria-hidden="true">00%</span>${esc(label)}</li>`).join("");
  return `<div class="capacity-legend">
    <div class="capacity-legend-group"><span class="capacity-legend-title">Supply, the left bar</span><ul>${supply}</ul></div>
    <div class="capacity-legend-group"><span class="capacity-legend-title">Demand, the percentage</span><ul>${demand}</ul></div>
  </div>`;
}

function computeFamilyHeatmap(payload) {
  const family = payload.familyHeatmap || {};
  if (family.status === "not-applicable") return "";
  if (family.status === "heatmap-disabled") {
    return `<div class="capacity-notice capacity-notice--warning"><strong>Family view disabled.</strong> More than ${fmtInt(family.limit)} family and region pairs matched. Narrow the subscription or region filter.</div>`;
  }
  const rows = family.rows || [];
  if (!rows.length) {
    return `<div class="capacity-notice">No Compute family quota was reported for this scope. Check ingestion for ComputeUsage and ComputeResourceSku.</div>`;
  }
  const filter = state.familyFilter;
  const visible = filterFamilyRows(rows, filter);
  const filterBar = familyFilterBar(rows, filter, visible.length);
  if (!visible.length) {
    return `${filterBar}<div class="capacity-notice">No family and region pair matches these filters. Clear them to see all ${fmtInt(rows.length)} cells.</div>`;
  }
  const families = [...new Map(visible.map((row) => [row.FamilyKey, row.Family || row.FamilyKey])).entries()]
    .sort((a, b) => String(a[1]).localeCompare(String(b[1])));
  const regions = [...new Set(visible.map((row) => row.Location || "Unknown region"))].sort();
  const cells = new Map(visible.map((row) => [`${row.FamilyKey}|${row.Location || "Unknown region"}`, row]));
  const mark = Number(filter.mark) || DEFAULT_HIGH_WATER_MARK;
  return `${filterBar}
  <p class="capacity-matrix-note" id="family-matrix-note">VM family by region across the estate. The left bar is supply, meaning whether a deployment can land at all. The percentage is demand against your own quota, and it turns red past the ${mark}% mark. Regional core quota is summed across subscriptions and is never duplicated across zones.</p>
  ${familyMatrixLegend(mark)}
  <div class="capacity-matrix" tabindex="0" role="region" aria-label="VM family by region matrix, scrollable">
  <table class="capacity-heatmap capacity-heatmap--family" aria-describedby="family-matrix-note">
    <thead><tr><th scope="col">VM family</th>${regions.map((region) => `<th scope="col">${esc(region)}</th>`).join("")}</tr></thead>
    <tbody>${families.map(([key, label]) => `<tr>
      <th scope="row" title="${esc(key)}">${esc(trunc(label, 28))}</th>
      ${regions.map((region) => {
        const row = cells.get(`${key}|${region}`);
        if (!row) return `<td class="capacity-cell capacity-state--missing">Not reported</td>`;
        const semantic = row.semantic || {};
        const restrictedZones = row.ZonesRestricted || [];
        const zonesPresent = Number(row.ZonesPresentCount || 0);
        const zoneNote = zonesPresent
          ? (restrictedZones.length
            ? `${restrictedZones.length} of ${zonesPresent} zones restricted`
            : `${zonesPresent} zones open`)
          : "No zone mapping";
        const detail = Number.isFinite(semantic.headroomCores)
          ? `${fmtInt(semantic.headroomCores)} cores free`
          : "";
        // A region restriction is supply news even when quota still exists.
        const supplyNote = semantic.regionRestricted && semantic.state !== "restricted"
          ? `<span class="capacity-cell-flag">Region restricted</span>`
          : "";
        const tier = familyDemandTier(semantic.utilizationPercent, mark);
        // Colour never carries the alarm alone, so crossing the mark is spelled out.
        const markNote = tier === "over" ? `<span class="capacity-cell-detail capacity-cell-mark">Over ${mark}% mark</span>`
          : tier === "exhausted" ? `<span class="capacity-cell-detail capacity-cell-mark">Quota exhausted</span>`
          : "";
        const title = `${label} · ${region} · ${fmtInt(row.CoresUsed)} of ${fmtInt(row.CoresTotal)} cores · ${zoneNote}`
          + (restrictedZones.length ? ` · restricted: ${restrictedZones.join(", ")}` : "")
          + (semantic.regionRestricted ? " · every SKU in this family is restricted for the subscription" : "");
        return `<td class="capacity-cell capacity-state--${esc(semantic.state || "unclassified")} capacity-supply--${esc(semantic.supply || "none")} capacity-demand--${esc(tier)}" title="${esc(title)}">
          <strong>${esc(semantic.text || "Not reported")}</strong>
          <span>${esc(CAPACITY_STATE_LABELS[semantic.state] || semantic.state || "Unknown")}</span>
          ${supplyNote}
          ${markNote}
          <span class="capacity-cell-detail">${esc(detail)}</span>
          <span class="capacity-cell-detail">${esc(zoneNote)}</span>
        </td>`;
      }).join("")}
    </tr>`).join("")}</tbody>
  </table></div>`;
}

function familySupplyLabel(row) {
  const supply = row.semantic?.supply;
  if (supply === "blocked") return row.semantic?.regionRestricted ? "Region restricted" : "All zones restricted";
  if (supply === "partial") return "Some zones restricted";
  if (supply === "open") return "Open";
  return "No quota";
}

function familyZoneLabel(row) {
  const present = Number(row.ZonesPresentCount || 0);
  const restricted = Array.isArray(row.ZonesRestricted) ? row.ZonesRestricted.length : 0;
  if (!present) return "Not mapped";
  return restricted ? `${restricted} of ${present} restricted` : `${present} open`;
}

function computeFamilyDetail(payload) {
  const rows = filterFamilyRows(payload.familyHeatmap?.rows || [], state.familyFilter);
  if (!rows.length) {
    return `<div class="capacity-notice">No family and region combination matches the filters above.</div>`;
  }
  const pageSize = 50;
  const totalPages = Math.ceil(rows.length / pageSize);
  const page = Math.min(state.capacityFamilyPage, totalPages);
  const pageRows = rows.slice((page - 1) * pageSize, page * pageSize);
  const table = `<div class="capacity-table-scroll">${tableHtml([
    { label: "VM family", align: "left", get: (row) => esc(row.Family || row.FamilyKey || "—") },
    { label: "Region", align: "left", get: (row) => esc(row.Location || "—") },
    { label: "Used cores", get: (row) => fmtInt(row.CoresUsed) },
    { label: "Quota", get: (row) => fmtInt(row.CoresTotal) },
    { label: "Headroom", get: (row) => Number.isFinite(row.semantic?.headroomCores) ? fmtInt(row.semantic.headroomCores) : "—" },
    { label: "Subscriptions", get: (row) => fmtInt(row.Subscriptions) },
    { label: "Supply", align: "left", get: (row) => esc(familySupplyLabel(row)) },
    { label: "Zones", align: "left", get: (row) => esc(familyZoneLabel(row)) },
  ], pageRows, "No family and region combination matches the filters above.")}</div>`;
  const pagination = totalPages > 1
    ? `<div class="capacity-detail-pagination" aria-label="Family and region pages">
        <button type="button" class="capacity-filter-reset" data-capacity-family-page="${page - 1}"${page <= 1 ? " disabled" : ""}>Previous</button>
        <span>Page ${fmtInt(page)} of ${fmtInt(totalPages)}</span>
        <button type="button" class="capacity-filter-reset" data-capacity-family-page="${page + 1}"${page >= totalPages ? " disabled" : ""}>Next</button>
      </div>`
    : "";
  return `<div id="capacity-family-summary" class="capacity-detail-summary" role="status" tabindex="-1">${fmtInt(rows.length)} matching family and region combinations</div>${table}${pagination}`;
}

function computeSubscriptionDetail() {
  const search = `<div class="capacity-detail-toolbar">
    <label class="capacity-filter-group" for="capacity-subscription-search">
      <span class="capacity-filter-label">Subscription</span>
      <input id="capacity-subscription-search" class="capacity-filter-search" type="search"
        data-capacity-subscription-search value="${esc(state.capacitySubscriptionSearch)}"
        placeholder="Search by subscription ID" autocomplete="off" spellcheck="false">
    </label>
    <span class="capacity-detail-hint">Matches the Show, VM family, and region filters above.</span>
  </div>`;
  if (state.capacitySubscriptionLoading) {
    return `${search}<div class="capacity-notice" role="status">Loading matching subscriptions…</div>`;
  }
  if (state.capacitySubscriptionError) {
    return `${search}<div class="capacity-notice capacity-notice--warning" role="alert" tabindex="-1"><strong>Subscriptions unavailable.</strong> ${esc(state.capacitySubscriptionError)}</div>`;
  }
  const data = state.capacitySubscriptionData;
  if (!data) return `${search}<div class="capacity-notice">Select this tab to load matching subscriptions.</div>`;
  const rows = data.rows || [];
  const totalPages = Number(data.totalPages || 0);
  const summary = `<div id="capacity-subscription-summary" class="capacity-detail-summary" role="status" tabindex="-1">${fmtInt(data.totalSubscriptions)} matching subscriptions</div>`;
  if (!rows.length) {
    return `${search}${summary}<div class="capacity-notice">No subscription matches these filters.</div>`;
  }
  const table = `<div class="capacity-table-scroll">${tableHtml([
    { label: "Subscription ID", align: "left", get: (row) => `<span title="${esc(row.SubscriptionId || "")}">${esc(row.SubscriptionId || "—")}</span>` },
    { label: "Families", get: (row) => fmtInt(row.Families) },
    { label: "Regions", get: (row) => fmtInt(row.Regions) },
    { label: "Used cores", get: (row) => fmtInt(row.CoresUsed) },
    { label: "Quota", get: (row) => fmtInt(row.CoresTotal) },
    { label: "Headroom", get: (row) => row.HeadroomCores != null && Number.isFinite(Number(row.HeadroomCores)) ? fmtInt(row.HeadroomCores) : "—" },
    { label: "Restrictions", get: (row) => fmtInt(row.RestrictedRows) },
    { label: "Last ingested", get: (row) => row.LastIngestion ? esc(fmtRelativeTime(new Date(row.LastIngestion))) : "—" },
  ], rows, "No subscription matches these filters.")}</div>`;
  const page = Number(data.page || 1);
  return `${search}
    ${summary}
    ${table}
    <div class="capacity-detail-pagination" aria-label="Subscription pages">
      <button type="button" class="capacity-filter-reset" data-capacity-subscription-page="${page - 1}"${page <= 1 ? " disabled" : ""}>Previous</button>
      <span>Page ${fmtInt(page)} of ${fmtInt(totalPages)}</span>
      <button type="button" class="capacity-filter-reset" data-capacity-subscription-page="${page + 1}"${page >= totalPages ? " disabled" : ""}>Next</button>
    </div>`;
}

function computeCapacityDetail(payload) {
  const tab = state.capacityDetailTab;
  return `<div class="capacity-detail-tabs" role="tablist" aria-label="Capacity detail">
      <button id="capacity-detail-tab-families" type="button" class="capacity-segment" role="tab"
        data-capacity-detail-tab="families" aria-selected="${tab === "families"}"
        aria-controls="capacity-detail-panel" tabindex="${tab === "families" ? "0" : "-1"}">Family and region</button>
      <button id="capacity-detail-tab-subscriptions" type="button" class="capacity-segment" role="tab"
        data-capacity-detail-tab="subscriptions" aria-selected="${tab === "subscriptions"}"
        aria-controls="capacity-detail-panel" tabindex="${tab === "subscriptions" ? "0" : "-1"}">Subscriptions</button>
    </div>
    <div id="capacity-detail-panel" role="tabpanel"
      aria-labelledby="capacity-detail-tab-${tab}">${tab === "subscriptions" ? computeSubscriptionDetail() : computeFamilyDetail(payload)}</div>`;
}

function capacityHistory(payload) {
  const history = payload.history || {};
  if (history.status === "no-selection") return `<div class="capacity-notice">Select one exact source row to view its observed history.</div>`;
  if (history.status === "disabled") return `<div class="capacity-notice capacity-notice--warning">History is disabled. ${esc(history.reasonCode || "")}</div>`;
  if (history.mode === "current-only") {
    return `<div class="capacity-notice"><strong>Collecting ${payload.contract?.quotaType === "inventory" ? "inventory" : "quota"} history — 1 day available.</strong> Trend, growth, forecast, runway, and breach dates remain disabled.</div>`;
  }
  return tableHtml([
    { label: "UTC day", align: "left", get: (row) => esc(String(row.Day || "").slice(0, 10)) },
    { label: "Current", get: (row) => formatCapacityValue(row.currentValue) },
    { label: "Limit", get: (row) => payload.contract?.quotaType === "inventory" ? "Not applicable" : formatCapacityValue(row.limit) },
    { label: "Unit", get: (row) => payload.classId === "premium-ssd-v2" ? "GiB" : esc(row.unit || "—") },
    { label: "Ingested", get: (row) => esc(String(row.x_IngestionTime || "")) },
  ], history.points || [], "No history is available for this exact source key.");
}

function capacityDemandHistory(payload) {
  const series = payload.series || {};
  if (series.status === "disabled") {
    return `<div class="capacity-notice capacity-notice--warning">Billed-demand series disabled. ${esc(series.reasonCode || "")}</div>`;
  }
  if (series.status === "no-selection") {
    return `<div class="capacity-notice">Select one exact meter, unit, price, and currency series. Different meters and currencies are never combined.</div>`;
  }
  const isDisk = payload.classId === "premium-ssd-v2";
  return tableHtml([
    { label: "UTC day", align: "left", get: (row) => esc(String(row.Day || "").slice(0, 10)) },
    ...(isDisk ? [] : [{ label: "Billed quantity", get: (row) => formatCapacityValue(row.BilledQuantity) }]),
    { label: "Unit", get: (row) => isDisk ? "Not classified" : esc(row.ConsumedUnit || series.unit || "—") },
    { label: "Effective cost", get: (row) => `${formatCapacityValue(row.EffectiveCost)} ${esc(row.BillingCurrency || "")}` },
    { label: "Rows", get: (row) => fmtInt(row.Rows) },
  ], series.points || [], "No billed usage matched this exact series.");
}

function capacityReconciliation(payload) {
  const rows = payload.reconciliation?.rows || [];
  return tableHtml([
    { label: "Capacity reservation group", align: "left", get: (row) => `<span title="${esc(row.GroupResourceId || "")}">${esc(row.GroupName || trunc(row.GroupResourceId, 36))}</span>` },
    { label: "Match", align: "left", get: (row) => esc(row.ReconciliationState || "unknown") },
    { label: "Used hours", get: (row) => formatCapacityValue(row.UsedHours) },
    { label: "Unused hours", get: (row) => formatCapacityValue(row.UnusedHours) },
    { label: "Reservations", get: (row) => fmtInt(row.ReservationCount) },
    { label: "Linked resources", get: (row) => fmtInt(row.LinkedResources) },
    { label: "Currency", get: (row) => esc(row.BillingCurrency || "—") },
  ], rows, "No capacity reservation inventory or linked billing data is available.");
}

function renderCapacity(payload) {
  const content = el("content");
  if (!payload) return;
  if (payload.error) return renderError(payload);
  const nav = capacityNavigationHtml();
  if (payload.classId === "home") {
    content.innerHTML = `${nav}<section id="capacity-panel" role="tabpanel" aria-labelledby="capacity-tab-home">
      <div class="capacity-header">
        <div><h2>Capacity workspace</h2></div>
        <p>Quota entitlement, billed demand, inventory, physical supply, and pricing commitments are separate data sources.</p>
      </div>
      ${capacityPanel("Quota coverage", "Seven independent quota areas; no combined health score or ranking.", capacityHomeTable(payload.classes))}
    </section>`;
    return;
  }

  const rows = payload.table?.rows || [];
  const statusCounts = rows.reduce((counts, row) => {
    const key = row.semantic?.state || "unclassified";
    counts[key] = (counts[key] || 0) + 1;
    return counts;
  }, {});
  const enabledCount = rows.filter((row) => row.semantic?.capability === "enabled").length;
  const coverage = payload.coverage || {};
  const notReported = coverage.state === "not-reported"
    ? `<div class="capacity-notice capacity-notice--warning"><strong>Not reported — collection outcome unknown.</strong> ${esc(payload.contract?.emptyLabel || "")}</div>`
    : "";
  const schemaWarnings = [payload.schema?.quota, payload.schema?.costs]
    .filter((schema) => schema && !schema.available)
    .map((schema) => `${schema.source}: ${schema.missingFields.join(", ")}`);
  const schemaNotice = schemaWarnings.length
    ? `<div class="capacity-notice capacity-notice--warning"><strong>Source fields unavailable.</strong> ${esc(schemaWarnings.join(" · "))}</div>`
    : "";
  const quotaSelectors = payload.selectors?.items || [];
  const demandSelectors = payload.demand?.selectors?.items || [];
  const familyRows = payload.familyHeatmap?.rows || [];
  const kpis = payload.classId === "compute"
    ? [
      kpiCard("Family-region pairs", fmtInt(familyRows.length), "Estate totals; subscriptions are aggregated before display"),
      kpiCard("In use", fmtInt(familyRows.filter(FAMILY_STATUS_FILTERS[0].match).length), "Family and region pairs using cores"),
      kpiCard("Restricted", fmtInt(familyRows.filter(FAMILY_STATUS_FILTERS[1].match).length), "Region or zone restrictions"),
      kpiCard("No quota", fmtInt(familyRows.filter(FAMILY_STATUS_FILTERS[2].match).length), "No regional family quota"),
    ].join("")
    : [
      kpiCard("Observations", fmtInt(coverage.observations), `${fmtInt(coverage.resources)} current resource keys`, undefined, undefined, "reference"),
      kpiCard("Snapshot days", fmtInt(coverage.distinctDays), coverage.distinctDays < 2 ? "No trend can be inferred" : "Compatible history is evaluated per exact key"),
      kpiCard("Latest ingestion", coverage.lastObservation ? esc(fmtRelativeTime(new Date(coverage.lastObservation))) : "—", "ADX arrival time, not provider observation time"),
      kpiCard("Enabled", fmtInt(enabledCount), "Rows with approved semantics"),
      kpiCard("Unclassified", fmtInt(statusCounts.unclassified), "Raw rows retained; registry review required"),
      kpiCard("Stale", fmtInt(statusCounts.stale), "Older than 48 hours; arithmetic disabled"),
    ].join("");

  content.innerHTML = `${nav}<section id="capacity-panel" role="tabpanel" aria-labelledby="capacity-tab-${esc(payload.classId)}">
    <div class="capacity-header">
      <div><h2>${esc(payload.contract?.title || payload.classId)}</h2></div>
      <p>${esc(payload.capability?.sourceNote || payload.contract?.sourceNote || "")}</p>
    </div>
    ${notReported}${schemaNotice}
    <div class="capacity-notice"><strong>Next action:</strong> ${esc(CAPACITY_ACTIONS[payload.classId] || "Review the source rows before taking action.")}</div>
    <div class="kpi-grid">${kpis}</div>
    <div class="capacity-selectors">
      ${capacitySelectorHtml(payload.classId === "compute" ? "metric" : "quota", payload.classId, quotaSelectors,
        payload.classId === "compute" ? state.capacitySelections.metricSelection : state.capacitySelections.quotaSelection)}
      ${capacitySelectorHtml("demand", payload.classId, demandSelectors, state.capacitySelections.demandSelection)}
    </div>
    <div class="capacity-layout">
      ${payload.classId === "compute"
        ? capacityPanel("Estate capacity by VM family and region", "Supply and demand at family grain. Zone restrictions are descriptive; they never change regional core quota.", computeFamilyHeatmap(payload), true)
        : ""}
      ${payload.classId === "compute"
        ? capacityPanel("Filtered capacity detail", "Every row matches the matrix controls above. Switch to Subscriptions for server-paged detail across the full estate.", computeCapacityDetail(payload), true)
        : capacityPanel("Current quota", `${payload.table?.rowLimit || 250}-row bound${payload.table?.truncated ? " reached" : ""}. Raw rows remain visible when calculations are disabled.`, capacityCurrentTable(payload))}
      ${payload.classId === "compute" ? "" : capacityPanel("Observed history", "Ingestion time is ADX arrival time. Missing days are not inferred.", capacityHistory(payload))}
      ${capacityPanel("Subscription × region", "Quota color is available only for exact enabled metrics. Inventory uses neutral density.", capacityHeatmap(payload))}
      ${capacityPanel("Parallel billed demand", payload.demand?.capability?.sourceNote || "Billed usage stays separate from quota.", capacityDemandHistory(payload))}
      ${payload.classId === "capacity-reservations"
        ? capacityPanel("Inventory and billing reconciliation", "Used and Unused are accounting statuses, not reserved-capacity utilization.", capacityReconciliation(payload))
        : ""}
    </div>
  </section>`;
}

function renderError(p) {
  el("content").innerHTML = `<div class="error">
    <h2>Can’t reach the FinOps hub</h2>
    <p>The dashboard queried <code>${esc(p.clusterUri || "")}</code> (database <code>${esc(p.database || "Hub")}</code>) but the request failed.</p>
    <div class="error-action">
      <p class="muted">Start the Kusto emulator, then run:</p>
      <div class="error-cmd">
        <code>Initialize-FinOpsHubLocal</code>
        <button class="btn btn-ghost" type="button" onclick="navigator.clipboard.writeText('Initialize-FinOpsHubLocal').then(()=>{this.textContent='Copied!';setTimeout(()=>{this.textContent='Copy'},1500)})">Copy</button>
      </div>
      <p class="muted">Then refresh this dashboard.</p>
    </div>
    <details class="error-detail">
      <summary class="muted" style="cursor:pointer;font-size:12px;">Show error detail</summary>
      <pre>${esc(p.error)}</pre>
    </details>
  </div>`;
}

/* ------------------------------------------------------- experimental tabs */

const KUSTO_MONACO_VERSION = "15.0.0";

let _monacoEditor = null;
let _monacoModel = null;
let _monacoApi = null;

/**
 * @kusto/monaco-kusto's jsdelivr `+esm` bundle imports its own pinned copy of
 * "monaco-editor" by exact CDN URL (version + subpath baked in at jsdelivr's
 * build time). Since browser ES module caching is keyed by exact URL string,
 * importing monaco-editor via any other URL -- even the "same" version --
 * yields a second, unrelated monaco instance, and `monaco.languages.kusto`
 * never registers on the one our own code holds. So instead of guessing a
 * monaco-editor version/path, discover the exact specifier kusto-monaco uses
 * and import through that.
 */
async function resolveSharedMonacoEditorUrl() {
  const kustoBundleUrl = `https://cdn.jsdelivr.net/npm/@kusto/monaco-kusto@${KUSTO_MONACO_VERSION}/+esm`;
  const kustoBundleSrc = await fetch(kustoBundleUrl).then((r) => r.text());
  const match = /from"(\/npm\/monaco-editor@[^"]+)"/.exec(kustoBundleSrc);
  if (!match) throw new Error("could not locate monaco-editor import in @kusto/monaco-kusto bundle");
  return { kustoBundleUrl, monacoEditorUrl: `https://cdn.jsdelivr.net${match[1]}` };
}

/**
 * Chromium refuses to construct a Worker (classic or module) from a
 * cross-origin script URL at all, even with permissive CORS headers -- so
 * `new Worker("https://cdn.jsdelivr.net/...")` throws a SecurityError
 * unconditionally. Work around this by fetching the script ourselves and
 * handing the browser a same-origin `blob:` URL instead. jsdelivr's `+esm`
 * bundles reference their own dependencies via root-relative specifiers
 * (e.g. `"/npm/..."`), which don't resolve against a `blob:` base, so those
 * are rewritten to fully-qualified jsdelivr URLs first.
 */
async function blobWorkerUrl(scriptUrl) {
  let src = await fetch(scriptUrl).then((r) => r.text());
  src = src.replace(/(["'])\/npm\//g, "$1https://cdn.jsdelivr.net/npm/");
  return URL.createObjectURL(new Blob([src], { type: "text/javascript" }));
}

function disposeMonacoEditor() {
  // editor.dispose() only tears down the view widget -- the text model is a
  // separate disposable and leaks (along with its worker) if not disposed
  // too, which matters here since renderMonacoTab() re-creates both every
  // time the tab is (re-)entered, e.g. after a cluster switch.
  if (_monacoEditor) {
    try { _monacoEditor.dispose(); } catch { /* best-effort cleanup */ }
    _monacoEditor = null;
  }
  if (_monacoModel) {
    try { _monacoModel.dispose(); } catch { /* best-effort cleanup */ }
    _monacoModel = null;
  }
}

async function renderMonacoTab() {
  const content = el("content");
  content.innerHTML = `
    <div class="tool-panel">
      <div class="tool-banner">
        <strong>Experimental</strong> — A KQL query editor with real autocomplete via
        <code>@kusto/monaco-kusto</code>, loaded from a CDN with no build step. Suggestions are
        grounded in this Hub database's live schema.
        <a href="https://learn.microsoft.com/en-us/kusto/api/monaco/monaco-kusto" target="_blank" rel="noopener">Docs ↗</a>
      </div>
      <div class="tool-toolbar">
        <button id="monaco-run" class="btn btn-primary" type="button">▶ Run (Ctrl/Cmd+Enter)</button>
        <span id="monaco-status" class="tool-status">Loading query editor…</span>
      </div>
      <div id="monaco-host" class="monaco-host"></div>
      <div id="monaco-result"></div>
    </div>
  `;

  const statusEl = el("monaco-status");
  const hostEl = el("monaco-host");

  try {
    if (!_monacoApi) {
      statusEl.textContent = "Loading query editor + KQL language support from CDN…";
      const { kustoBundleUrl, monacoEditorUrl } = await resolveSharedMonacoEditorUrl();
      const monacoBase = monacoEditorUrl.replace(/\/esm\/.*$/, "");
      // Import monaco-editor via the exact URL @kusto/monaco-kusto itself
      // imports it from, so both packages share one module instance
      // (required for monaco.languages.kusto to register on our copy).
      _monacoApi = await import(monacoEditorUrl);
      const [genericWorkerUrl, kustoWorkerUrl] = await Promise.all([
        blobWorkerUrl(`${monacoBase}/esm/vs/editor/editor.worker.js/+esm`),
        blobWorkerUrl(`https://cdn.jsdelivr.net/npm/@kusto/monaco-kusto@${KUSTO_MONACO_VERSION}/release/esm/kusto.worker.js/+esm`),
      ]);
      self.MonacoEnvironment = {
        getWorker(_moduleId, label) {
          return new Worker(label === "kusto" ? kustoWorkerUrl : genericWorkerUrl, { type: "module" });
        },
      };
      await import(kustoBundleUrl);
    }
    const monaco = _monacoApi;

    disposeMonacoEditor();
    // Seed from whatever was last saved server-side (survives page reloads,
    // including the host restarting this extension's server process), not a
    // hardcoded sample -- see saveQueryState() below for how it gets there.
    const initialQuery = (window.__cfg && window.__cfg.lastQuery) || "Costs\n| take 20";
    const model = monaco.editor.createModel(initialQuery, "kusto");
    _monacoModel = model;
    _monacoEditor = monaco.editor.create(hostEl, {
      model,
      theme: document.documentElement.getAttribute("data-color-mode") === "dark" ? "vs-dark" : "vs",
      automaticLayout: true,
      minimap: { enabled: false },
      fontSize: 13,
    });
    _monacoEditor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter, () => runMonacoQuery());
    _monacoEditor.onDidChangeModelContent(() => scheduleQueryStateSave(_monacoEditor.getValue()));

    statusEl.textContent = "Fetching database schema…";
    try {
      const cfg = window.__cfg || {};
      const schemaRes = await fetch("/api/schema").then((r) => r.json());
      const kustoLang = monaco.languages?.kusto;
      if (schemaRes.schema && kustoLang?.getKustoWorker) {
        const workerAccessor = await kustoLang.getKustoWorker();
        const worker = await workerAccessor(model.uri);
        await worker.setSchemaFromShowSchema(schemaRes.schema, cfg.clusterUri || "", cfg.database || "Hub");
        statusEl.textContent = `Ready — schema loaded from ${esc(cfg.database || "Hub")}.`;
      } else {
        statusEl.textContent = schemaRes.error
          ? `Ready — schema unavailable: ${esc(schemaRes.error)}`
          : "Ready — KQL language service didn't register (autocomplete may be limited).";
      }
    } catch (schemaErr) {
      statusEl.textContent = `Ready — schema load failed: ${esc(schemaErr.message || String(schemaErr))}`;
    }
  } catch (err) {
    // Graceful fallback: never leave the tab blank if the CDN load fails
    // (e.g. cross-origin module workers unsupported in this webview).
    const initialQuery = (window.__cfg && window.__cfg.lastQuery) || "Costs\n| take 20";
    hostEl.innerHTML = `<textarea id="monaco-fallback" class="monaco-fallback" rows="14" spellcheck="false" placeholder="Costs | take 20">${esc(initialQuery)}</textarea>`;
    el("monaco-fallback").addEventListener("input", (e) => scheduleQueryStateSave(e.target.value));
    statusEl.textContent = `Query editor failed to load here (${esc(err.message || String(err))}) — using a plain text editor instead.`;
  }
  el("monaco-run").addEventListener("click", () => runMonacoQuery());
}

// Debounced autosave of the query editor's text to the server (see
// /api/query-state in extension.mjs), so an in-progress, unrun query
// survives a page reload -- e.g. the host restarting this extension's server
// process, which reassigns its ephemeral port and forces a fresh load.
let _queryStateSaveTimer = null;
function scheduleQueryStateSave(query) {
  clearTimeout(_queryStateSaveTimer);
  _queryStateSaveTimer = setTimeout(() => {
    fetch("/api/query-state", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query }),
    }).catch(() => { /* best-effort; the next successful save will catch up */ });
  }, 600);
}

async function runMonacoQuery() {
  const runBtn = el("monaco-run");
  const statusEl = el("monaco-status");
  const resultEl = el("monaco-result");
  const kql = _monacoEditor ? _monacoEditor.getValue().trim() : (el("monaco-fallback")?.value || "").trim();
  if (!kql) return;
  runBtn.disabled = true;
  const prevStatus = statusEl.textContent;
  statusEl.textContent = "Running…";
  try {
    const res = await fetch("/api/kql", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ kql }),
    });
    const data = await res.json();
    if (data.error) {
      resultEl.innerHTML = `<p class="kql-dialog-error">${esc(data.error)}</p>`;
    } else {
      const rows = data.rows || [];
      if (!rows.length) {
        resultEl.innerHTML = `<p class="kql-result-meta">Query returned no rows.</p>`;
      } else {
        const cols = Object.keys(rows[0]);
        const head = cols.map((c) => `<th scope="col">${esc(c)}</th>`).join("");
        const body = rows.slice(0, 200).map((r) =>
          `<tr>${cols.map((c) => `<td>${esc(String(r[c] ?? ""))}</td>`).join("")}</tr>`
        ).join("");
        const note = rows.length > 200 ? ` (showing first 200)` : "";
        resultEl.innerHTML = `<p class="kql-result-meta">${rows.length} rows${note}</p><div class="kql-result-scroll"><table class="dtable"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
      }
    }
  } catch (err) {
    resultEl.innerHTML = `<p class="kql-dialog-error">Request failed: ${esc(err.message)}</p>`;
  } finally {
    runBtn.disabled = false;
    statusEl.textContent = prevStatus;
  }
}

/* ----------------------------------------------------------------- driver */

function currentPayload() {
  return state.cache[state.tab]?.[cacheKey()];
}

function render() {
  const p = currentPayload();
  if (!p) return;
  try {
    if (p.error) renderError(p);
    else if (state.tab === "tokenomics") renderTokenomics(p);
    else if (state.tab === "ai") renderAi(p);
    else if (state.tab === "allocation") renderAllocation(p);
    else if (state.tab === "rate") renderRate(p);
    else if (state.tab === "usage") renderUsage(p);
    else if (state.tab === "anomaly") renderAnomaly(p);
    else if (state.tab === "capacity") renderCapacity(p);
    else renderOverview(p);
  } catch (err) {
    console.error("[ftk-dashboard] render error:", err);
    renderError({ error: `Render error in ${state.tab}: ${err.message}` });
  }
}

async function load() {
  const tab = state.tab;
  if (TOOL_TABS.has(tab)) {
    el("source-line").textContent = "Experimental tab — not part of the FinOps KPI pipeline.";
    el("footer-meta").textContent = "";
    renderMonacoTab();
    return;
  }
  const key = cacheKey();
  if (state.cache[tab]?.[key]) { updateChrome(); render(); return; }

  // Cancel any in-flight request for a superseded tab/preset
  if (_loadAbort) _loadAbort.abort();
  _loadAbort = new AbortController();
  const { signal } = _loadAbort;

  state.cache[tab] = state.cache[tab] || {};
  state.loading = true;
  setRefreshSpinning(true);
  const contentEl = el("content");
  contentEl.setAttribute("aria-busy", "true");
  contentEl.innerHTML = `
    <div class="skeleton-kpi-grid">
      ${'<div class="skeleton-card"></div>'.repeat(6)}
    </div>
    <div class="skeleton-card skeleton-panel-lg"></div>
    <div class="skeleton-card skeleton-panel-sm"></div>
  `;
  try {
    const res = await fetch("/api/view", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: tab,
        preset: state.preset,
        filters: state.filters,
        ...(tab === "capacity"
          ? { capacityClass: state.capacityClass, capacitySelections: state.capacitySelections }
          : {}),
      }),
      signal,
    });
    state.cache[tab][key] = await res.json();
  } catch (err) {
    if (err.name === "AbortError") return; // superseded by a newer load(); discard silently
    console.error("[ftk-dashboard] fetch failed:", err);
    state.cache[tab][key] = { error: "Could not load data. Check the FinOps hub connection and authentication." };
  } finally {
    state.loading = false;
    setRefreshSpinning(false);
    el("content")?.setAttribute("aria-busy", "false");
  }
  updateChrome();
  render();
  if (tab === "capacity" && state.capacityClass === "compute" &&
    state.capacityDetailTab === "subscriptions" && !state.capacitySubscriptionData) {
    void loadCapacitySubscriptions();
  }
}

function setRefreshSpinning(on) {
  const b = el("refresh");
  if (b) b.innerHTML = on ? `<span class="spin">↻</span> Refresh` : `↻ Refresh`;
}

function renderDiagnosticRail() {
  const railEl = el("diagnostic-rail");
  if (!railEl) return;
  const { rows, health, refreshedAt, dataset } = queryState;
  const relTime = fmtRelativeTime(refreshedAt);
  const absTime = refreshedAt ? refreshedAt.toLocaleString() : "";
  const rowTxt = `${fmtInt(rows)} rows`;
  const healthLabel = health === "error" ? "● error" : health === "warn" ? "● warn" : "● ok";
  railEl.innerHTML =
    `<span class="rail-dataset">${esc(dataset)}</span>` +
    `<span class="rail-sep" aria-hidden="true">·</span>` +
    `<span class="rail-rows">${rowTxt}</span>` +
    `<span class="rail-sep" aria-hidden="true">·</span>` +
    `<span class="rail-health rail-health--${health}">${healthLabel}</span>` +
    `<span class="rail-sep" aria-hidden="true">·</span>` +
    `<span class="rail-time" title="${esc(absTime)}">${esc(relTime)}</span>`;
}

function updateChrome() {
  const p = currentPayload();
  const w = p && p.window;
  if (w && w.dataMin) {
    el("source-line").innerHTML =
      `Hub database · <code>${esc(window.__cfg?.clusterUri || "localhost:8082")}</code>`;
    queryState.dataset = `Hub database · ${fmtDayRange(w.dataMin, w.dataMax)}`;
    queryState.rows = w.rows || 0;
    queryState.health = queryState.rows === 0 ? "warn" : "ok";
    queryState.refreshedAt = p.generatedAt ? new Date(p.generatedAt) : new Date();
    el("footer-meta").textContent = `window ${w.start} → ${w.end}`;
    renderDiagnosticRail();
  } else if (p && p.error) {
    el("source-line").textContent = "Connection failed — see panel below.";
    el("footer-meta").textContent = "";
    queryState.rows = 0;
    queryState.health = "error";
    queryState.refreshedAt = new Date();
    queryState.dataset = "Hub database";
    renderDiagnosticRail();
  } else if (p && state.tab === "capacity") {
    const observations = p.classId === "home"
      ? (p.classes || []).reduce((sum, item) => sum + Number(item.summary?.Observations || 0), 0)
      : Number(p.coverage?.observations || 0);
    el("source-line").innerHTML =
      `Hub capacity · <code>${esc(window.__cfg?.clusterUri || "localhost:8082")}</code>`;
    el("footer-meta").textContent = p.classId === "home" ? "seven quota areas" : p.contract?.title || p.classId;
    queryState.rows = observations;
    queryState.health = p.error ? "error" : observations > 0 ? "ok" : "warn";
    queryState.refreshedAt = p.generatedAt ? new Date(p.generatedAt) : new Date();
    queryState.dataset = p.classId === "home" ? "Capacity overview" : p.contract?.title || "Capacity";
    renderDiagnosticRail();
  }
}

/** Open the connection-settings dialog, prefilled from the current config. */
function openSettingsDialog() {
  el("settings-cluster").value = window.__cfg?.clusterUri || "";
  el("settings-database").value = window.__cfg?.database || "";
  el("settings-error").textContent = "";
  el("settings-dialog").showModal();
  el("settings-cluster").focus();
}

/** POST the edited connection settings, then reconnect and re-query. */
async function saveSettings() {
  const clusterUri = el("settings-cluster").value.trim();
  const database = el("settings-database").value.trim();
  if (!clusterUri) {
    el("settings-error").textContent = "Cluster URI is required.";
    return;
  }
  const btn = el("settings-save");
  const original = btn.textContent;
  btn.disabled = true;
  btn.textContent = "Saving…";
  try {
    const res = await fetch("/api/config", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ clusterUri, database: database || "Hub" }),
    });
    const body = await res.json();
    if (!res.ok || body.error) throw new Error(body.error || "Save failed");
    window.__cfg = body;
    el("settings-dialog").close();
    state.cache = {}; // stale data belongs to the old connection
    invalidateCapacitySubscriptions();
    load();
  } catch (err) {
    el("settings-error").textContent = err.message || "Could not save settings.";
  } finally {
    btn.disabled = false;
    btn.textContent = original;
  }
}

function wireControls() {
  el("preset").addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-preset]");
    if (!btn || state.loading) return;
    state.preset = btn.dataset.preset;
    [...el("preset").querySelectorAll("button")].forEach((b) => b.classList.toggle("active", b === btn));
    void publishCanvasState({ preset: state.preset });
    load();
  });
  el("tabs").addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-tab]");
    if (btn) switchTab(btn.dataset.tab);
  });
  el("refresh").addEventListener("click", () => {
    if (state.loading) return;
    if (state.cache[state.tab]) delete state.cache[state.tab][cacheKey()]; // force re-query
    if (state.tab === "capacity" && state.capacityClass === "compute") invalidateCapacitySubscriptions();
    load();
  });

  // Settings dialog controls
  el("settings-open").addEventListener("click", openSettingsDialog);
  el("settings-close").addEventListener("click", () => el("settings-dialog").close());
  el("settings-save").addEventListener("click", saveSettings);

  // KQL dialog controls
  el("kql-close").addEventListener("click", () => el("kql-dialog").close());
  el("kql-copy").addEventListener("click", () => {
    const btn = el("kql-copy");
    navigator.clipboard.writeText(el("kql-text").value)
      .then(() => { btn.textContent = "Copied!"; setTimeout(() => { btn.textContent = "Copy"; }, 1500); })
      .catch(() => { btn.textContent = "Failed"; setTimeout(() => { btn.textContent = "Copy"; }, 1500); });
  });
  el("kql-run").addEventListener("click", executeKql);

  // KQL escape-hatch buttons (event delegation — buttons injected by panelHtml)
  document.addEventListener("click", (e) => {
    const capacityTab = e.target.closest("[data-capacity-class]");
    if (capacityTab) {
      selectCapacityClass(capacityTab.dataset.capacityClass);
      return;
    }
    const btn = e.target.closest(".kql-btn[data-panel-id]");
    if (btn) openKqlDialog(btn.dataset.panelId);
    // hbar click-to-filter
    const hbarRow = e.target.closest(".hbar-filterable[data-filter-dim]");
    if (hbarRow) {
      const dim = hbarRow.dataset.filterDim;
      const val = hbarRow.dataset.filterVal;
      if (dim && val) toggleFilter(dim, val);
    }
    // chip remove
    const chipRemove = e.target.closest(".chip-remove[data-dim]");
    if (chipRemove) {
      const dim = chipRemove.dataset.dim;
      const val = chipRemove.dataset.val;
      if (dim && val) toggleFilter(dim, val);
    }
    // reset all
    if (e.target.closest("#filter-reset")) clearFilters();

    const lens = e.target.closest("[data-family-status]");
    if (lens) {
      setFamilyFilter({ status: lens.dataset.familyStatus });
      return;
    }
    const regionChip = e.target.closest("[data-family-region]");
    if (regionChip) {
      const region = regionChip.dataset.familyRegion;
      const current = state.familyFilter.regions;
      setFamilyFilter({
        regions: current.includes(region) ? current.filter((item) => item !== region) : [...current, region],
      });
      return;
    }
    const markChip = e.target.closest("[data-family-mark]");
    if (markChip) {
      setFamilyFilter({ mark: Number(markChip.dataset.familyMark) });
      return;
    }
    if (e.target.closest("[data-family-reset]")) {
      setFamilyFilter({ status: "all", search: "", regions: [] });
      return;
    }
    const detailTab = e.target.closest("[data-capacity-detail-tab]");
    if (detailTab) {
      setCapacityDetailTab(detailTab.dataset.capacityDetailTab);
      return;
    }
    const subscriptionPage = e.target.closest("[data-capacity-subscription-page]");
    if (subscriptionPage && !subscriptionPage.disabled) {
      state.capacitySubscriptionPage = Number(subscriptionPage.dataset.capacitySubscriptionPage);
      _capacitySubscriptionFocusResults = true;
      void loadCapacitySubscriptions();
      return;
    }
    const familyPage = e.target.closest("[data-capacity-family-page]");
    if (familyPage && !familyPage.disabled) {
      state.capacityFamilyPage = Number(familyPage.dataset.capacityFamilyPage);
      render();
      document.querySelector("#capacity-family-summary")?.focus();
    }
  });

  document.addEventListener("change", (e) => {
    const selector = e.target.closest("select[data-capacity-selector]");
    if (selector) applyCapacitySelection(selector.dataset.capacitySelector, selector.value);
  });

  let familySearchTimer;
  let subscriptionSearchTimer;
  document.addEventListener("input", (e) => {
    const search = e.target.closest("[data-family-search]");
    if (search) {
      clearTimeout(familySearchTimer);
      const value = search.value;
      familySearchTimer = setTimeout(() => setFamilyFilter({ search: value }), 160);
      return;
    }
    const subscriptionSearch = e.target.closest("[data-capacity-subscription-search]");
    if (subscriptionSearch) {
      clearTimeout(subscriptionSearchTimer);
      const value = subscriptionSearch.value;
      subscriptionSearchTimer = setTimeout(() => {
        state.capacitySubscriptionSearch = value;
        state.capacitySubscriptionPage = 1;
        void loadCapacitySubscriptions();
      }, 250);
    }
  });

  // Keyboard activation and roving focus for interactive data controls.
  document.addEventListener("keydown", (e) => {
    const detailTab = e.target.closest("[data-capacity-detail-tab]");
    if (detailTab && ["ArrowLeft", "ArrowRight", "Home", "End"].includes(e.key)) {
      e.preventDefault();
      const tabs = ["families", "subscriptions"];
      const current = tabs.indexOf(detailTab.dataset.capacityDetailTab);
      const next = e.key === "Home" ? 0
        : e.key === "End" ? tabs.length - 1
          : e.key === "ArrowRight" ? (current + 1) % tabs.length
            : (current - 1 + tabs.length) % tabs.length;
      setCapacityDetailTab(tabs[next]);
      return;
    }
    const lens = e.target.closest("[data-family-status]");
    if (lens && ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"].includes(e.key)) {
      e.preventDefault();
      const order = FAMILY_STATUS_FILTERS.map((item) => item.id);
      const index = order.indexOf(lens.dataset.familyStatus);
      const next = nextCapacityTabIndex(index, e.key, order.length);
      if (next >= 0) setFamilyFilter({ status: order[next] });
      return;
    }
    const markKey = e.target.closest("[data-family-mark]");
    if (markKey && ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"].includes(e.key)) {
      e.preventDefault();
      const index = HIGH_WATER_MARKS.indexOf(Number(markKey.dataset.familyMark));
      const next = nextCapacityTabIndex(index, e.key, HIGH_WATER_MARKS.length);
      if (next >= 0) setFamilyFilter({ mark: HIGH_WATER_MARKS[next] });
      return;
    }
    const capacityTab = e.target.closest("[data-capacity-class]");
    if (capacityTab) {
      if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"].includes(e.key)) {
        e.preventDefault();
        moveCapacityTabFocus(capacityTab, e.key);
        return;
      }
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        selectCapacityClass(capacityTab.dataset.capacityClass);
        return;
      }
    }
    if (e.key !== "Enter" && e.key !== " ") return;
    const hbarRow = e.target.closest(".hbar-filterable[data-filter-dim]");
    if (hbarRow) {
      e.preventDefault();
      const dim = hbarRow.dataset.filterDim;
      const val = hbarRow.dataset.filterVal;
      if (dim && val) toggleFilter(dim, val);
    }
  });

  let t;
  window.addEventListener("resize", () => { clearTimeout(t); t = setTimeout(render, 180); });
}

async function init() {
  try {
    const [cfg, sharedState] = await Promise.all([
      fetch("/api/config").then((r) => r.json()),
      fetch("/api/session-state").then((r) => r.json()),
    ]);
    window.__cfg = cfg;
    if (Number.isInteger(sharedState.revision)) {
      state.tab = sharedState.tab;
      state.preset = sharedState.preset;
      state.filters = sharedState.filters || {};
      state.capacityClass = sharedState.capacityClass || "home";
      state.capacitySelections = sharedState.capacitySelections || {};
      state.revision = sharedState.revision;
    }
  } catch { window.__cfg = {}; }
  wireControls();
  syncCanvasControls();

  // Restore tab from URL hash (bookmarking / back-forward support), or
  // normalize the hash to reflect the default tab so the URL is always
  // shareable.
  const initialTab = tabFromHash();
  const initialCapacityClass = capacityClassFromHash();
  if (initialCapacityClass) state.capacityClass = initialCapacityClass;
  const initialHash = (initialTab || state.tab) === "capacity"
    ? `#tab=capacity&capacity=${state.capacityClass}`
    : `#tab=${initialTab || state.tab}`;
  if (initialTab && initialTab !== state.tab) {
    switchTab(initialTab, { skipHash: true });
    history.replaceState({ tab: initialTab, capacityClass: state.capacityClass }, "", initialHash);
  } else {
    history.replaceState({ tab: state.tab, capacityClass: state.capacityClass }, "", initialHash);
    revealActiveTab();
    load();
  }

  window.addEventListener("popstate", () => {
    const tab = tabFromHash() || "overview";
    const capacityClass = capacityClassFromHash() || "home";
    if (tab === "capacity") state.capacityClass = capacityClass;
    if (tab !== state.tab) switchTab(tab, { skipHash: true });
    else if (tab === "capacity") selectCapacityClass(capacityClass, { skipHash: true, skipPublish: true, force: true });
  });
  setInterval(pollCanvasState, 1000);
}

if (typeof window !== "undefined" && typeof document !== "undefined") init();
