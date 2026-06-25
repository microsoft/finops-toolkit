/* FinOps hub local dashboard — client renderer.
   Dependency-free: KPIs + SVG charts (line, horizontal bar, donut).
   Data comes from the extension's loopback /api endpoints. */

"use strict";

const PALETTE = [
  "#3b82f6", "#10b981", "#8b5cf6", "#f59e0b", "#ef4444", "#06b6d4",
  "#ec4899", "#84cc16", "#f97316", "#6366f1", "#14b8a6", "#a855f7",
];

const state = { preset: "all", tab: "overview", loading: false, cache: {}, filters: {} };
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
  "usage-top-types": ["Costs()", PERIOD, "| where isnotempty(ResourceType)", "| summarize Count=count(), Cost=sum(EffectiveCost) by ResourceType", "| top 10 by Cost desc"].join("\n"),
  "usage-per-core-series": ["Costs()", PERIOD, "| where x_SkuMeterCategory in ('Virtual Machines','Virtual Machine Licenses') and ChargeCategory=='Usage'", "| extend cores=toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores))", "| extend ch=iff(isnotempty(cores), toreal(cores*ConsumedQuantity), toreal(''))", "| summarize Eff=sum(EffectiveCost), CH=sum(ch) by x_SkuMeterSubcategory", "| where CH > 100 | extend PerCore=Eff/CH | top 10 by Eff desc"].join("\n"),
  "usage-storage-tiers": ["Costs()", PERIOD, "| where ServiceCategory=='Storage' and ChargeCategory=='Usage'", "| extend Tier=case(x_SkuTier has_any('Hot','Standard','Premium'),'Frequent',x_SkuTier has_any('Cool','Cold','Archive'),'Infrequent','Unclassified')", "| summarize Cost=sum(EffectiveCost) by Tier", "| where Cost > 0 | order by Cost desc"].join("\n"),
  "rate-savings": ["Costs()", PERIOD, NON_PURCH, "| extend neg=iff(ListCost<ContractedCost,real(0),ListCost-ContractedCost)", "| extend com=iff(ContractedCost<EffectiveCost,real(0),ContractedCost-EffectiveCost)", "| extend tot=iff(ListCost<EffectiveCost,real(0),ListCost-EffectiveCost)", "| summarize List=sum(ListCost), Effective=sum(EffectiveCost), Negotiated=sum(neg), Commitment=sum(com), Total=sum(tot)"].join("\n"),
  "rate-commit-util": ["Costs()", PERIOD, "| where isnotempty(CommitmentDiscountId)", NON_PURCH, "| summarize Unused=sumif(EffectiveCost,CommitmentDiscountStatus=='Unused'), Total=sum(EffectiveCost)"].join("\n"),
  "rate-core-hours": ["Costs()", PERIOD, "| extend cores=toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores, 0))", "| extend ch=iff(cores>0, cores*ConsumedQuantity, toreal(''))", "| extend t=iff(isempty(CommitmentDiscountType),'On Demand',CommitmentDiscountType)", "| summarize CoreHours=sum(ch) by t", "| where CoreHours > 0 | order by CoreHours desc"].join("\n"),
  "rate-underutil": ["Costs()", PERIOD, "| where isnotempty(CommitmentDiscountName)", NON_PURCH, "| summarize Unused=sumif(EffectiveCost,CommitmentDiscountStatus=='Unused'), Total=sum(EffectiveCost) by CommitmentDiscountName", "| where Unused > 0 | top 10 by Unused desc"].join("\n"),
  "alloc-hierarchy": ["Costs()", PERIOD, "| extend Org=tostring(Tags['org']), Project=tostring(Tags['Project']), Env=tostring(Tags['env'])", "| summarize Cost=sum(EffectiveCost) by Org, Project, Env", "| where Cost > 0 | top 12 by Cost desc"].join("\n"),
  "alloc-tagging": ["Costs()", PERIOD, "| extend _t=iff(isnull(Tags) or array_length(bag_keys(Tags))==0,'Untagged','Tagged')", "| summarize Cost=sum(EffectiveCost) by _t"].join("\n"),
  "alloc-tag-keys": ["Costs()", PERIOD, "| mv-expand k=bag_keys(Tags) to typeof(string)", "| where isnotempty(k) and k !in ('ftk-tool','ftk-version','cm-resource-parent','costanalysis-parent')", "| summarize Cost=sum(EffectiveCost) by k", "| top 12 by Cost desc"].join("\n"),
  "alloc-by-subscription": ["Costs()", PERIOD, "| where isnotempty(SubAccountName)", "| summarize Cost=sum(EffectiveCost) by SubAccountName", "| top 10 by Cost desc"].join("\n"),
};
/* eslint-enable max-len */

let _kqlPanelId = null;

/* ------------------------------------------------------------------ filter management */

function filterKey() {
  const entries = Object.entries(state.filters)
    .filter(([, arr]) => arr && arr.length > 0)
    .sort(([a], [b]) => a.localeCompare(b));
  return entries.length > 0 ? "|" + JSON.stringify(entries) : "";
}

function cacheKey() {
  return state.preset + filterKey();
}

function filterParam() {
  const entries = Object.entries(state.filters)
    .filter(([, arr]) => arr && arr.length > 0);
  if (entries.length === 0) return "";
  return "&filters=" + encodeURIComponent(JSON.stringify(Object.fromEntries(entries)));
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
  load();
}

function clearFilters() {
  state.filters = {};
  renderFilterBar();
  load();
}

function renderFilterBar() {
  const bar = document.getElementById("filter-bar");
  const chips = document.getElementById("filter-chips");
  if (!bar || !chips) return;
  const entries = Object.entries(state.filters).filter(([, arr]) => arr && arr.length > 0);
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
function fmtMonth(ym) {
  // "2025-04" -> "Apr ’25"
  const [y, m] = ym.split("-");
  const names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${names[+m - 1]} ’${y.slice(2)}`;
}
function fmtDayRange(min, max) {
  const f = (s) => {
    const d = new Date(s);
    return d.toLocaleDateString("en-US", { month: "short", year: "numeric", timeZone: "UTC" });
  };
  return `${f(min)} – ${f(max)}`;
}
function esc(s) {
  return String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}
function trunc(s, n) {
  s = String(s ?? "");
  return s.length > n ? s.slice(0, n - 1) + "…" : s;
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
function svgEl(w, h, body) {
  return `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="xMidYMid meet" role="img">${body}</svg>`;
}

/* ----------------------------------------------------------------- charts */

function lineChart(rows) {
  // rows: [{Month, Billed, Effective}]
  const W = 760, H = 280;
  const m = { l: 56, r: 18, t: 16, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  if (!rows || rows.length === 0) return emptyChart(W, H);
  const max = Math.max(...rows.map((r) => Math.max(r.Billed || 0, r.Effective || 0)), 1);
  const yMax = max * 1.12;
  const n = rows.length;
  const x = (i) => m.l + (n === 1 ? iw / 2 : (i / (n - 1)) * iw);
  const y = (v) => m.t + ih - (v / yMax) * ih;

  let g = "";
  // gridlines + y ticks
  const ticks = 4;
  for (let t = 0; t <= ticks; t++) {
    const val = (yMax / ticks) * t;
    const yy = y(val);
    g += `<line class="grid-line" x1="${m.l}" y1="${yy}" x2="${W - m.r}" y2="${yy}"/>`;
    g += `<text class="tick" x="${m.l - 8}" y="${yy + 4}" text-anchor="end">${fmtMoney(val)}</text>`;
  }
  // x labels (thin out if crowded)
  const step = Math.ceil(n / 12);
  rows.forEach((r, i) => {
    if (i % step === 0 || i === n - 1) {
      g += `<text class="tick" x="${x(i)}" y="${H - 12}" text-anchor="middle">${esc(fmtMonth(r.Month))}</text>`;
    }
  });
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
    g += `<circle class="bar" cx="${x(i)}" cy="${y(r.Effective || 0)}" r="3.2" fill="${PALETTE[0]}"><title>${esc(fmtMonth(r.Month))}\nEffective ${fmtMoneyFull(r.Effective)}\nBilled ${fmtMoneyFull(r.Billed)}</title></circle>`;
  });
  const legend = legendHtml([
    { label: "Effective cost", color: PALETTE[0] },
    { label: "Billed cost", color: "var(--muted)" },
  ]);
  return svgEl(W, H, g) + legend;
}

function hbar(rows, nameKey, valKey, opts = {}) {
  const data = (rows || []).map((r) => ({ name: String(r[nameKey] ?? "—"), val: +r[valKey] || 0 }))
    .filter((r) => r.val > 0);
  if (data.length === 0) return `<p class="muted" style="font-size:12px">No data in range.</p>`;
  const max = Math.max(...data.map((d) => d.val), 1);
  const total = data.reduce((s, d) => s + d.val, 0);
  const rowH = 30, padR = 64, nameW = opts.nameW ?? 142;
  const W = 540, H = data.length * rowH + 6;
  const barX = nameW + 8, barW = W - barX - padR;
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
    const dimAttr = filterDim ? ` data-filter-dim="${esc(filterDim)}" data-filter-val="${esc(d.name)}"` : "";
    g += `<g class="${cls}"${dimAttr}>`;
    g += `<text class="name" x="0" y="${cy + 4}">${esc(trunc(d.name, 20))}<title>${esc(d.name)}</title></text>`;
    g += `<rect class="hbar" x="${barX}" y="${cy - 9}" width="${w}" height="18" rx="4" fill="${color}"><title>${esc(d.name)}\n${fmtMoneyFull(d.val)} · ${fmtPct(pct)}</title></rect>`;
    g += `<text class="val" x="${W}" y="${cy + 4}" text-anchor="end">${fmtMoney(d.val)}</text>`;
    g += `</g>`;
  });
  return svgEl(W, H, g);
}

function donut(slices, opts = {}) {
  const data = (slices || []).filter((s) => (+s.value || 0) > 0);
  const total = data.reduce((s, d) => s + (+d.value || 0), 0);
  if (total <= 0) return `<p class="muted" style="font-size:12px">No data in range.</p>`;
  const size = 180, cx = size / 2, cy = size / 2, R = 80, r = 50;
  let a0 = 0, g = "";
  if (data.length === 1) {
    g += `<circle class="arc" cx="${cx}" cy="${cy}" r="${(R + r) / 2}" fill="none" stroke="${data[0].color}" stroke-width="${R - r}"><title>${esc(data[0].label)}\n${fmtMoneyFull(data[0].value)} · 100%</title></circle>`;
  } else {
    data.forEach((d) => {
      const frac = d.value / total;
      const a1 = a0 + frac * 360;
      g += `<path class="arc" d="${donutSeg(cx, cy, R, r, a0, a1)}" fill="${d.color}"><title>${esc(d.label)}\n${fmtMoneyFull(d.value)} · ${fmtPct(frac)}</title></path>`;
      a0 = a1;
    });
  }
  const centerBig = opts.centerBig ?? fmtMoney(total);
  const centerSmall = opts.centerSmall ?? "total";
  g += `<text class="donut-center" x="${cx}" y="${cy - 2}" text-anchor="middle"><tspan class="big" x="${cx}">${esc(centerBig)}</tspan></text>`;
  g += `<text x="${cx}" y="${cy + 16}" text-anchor="middle" class="small">${esc(centerSmall)}</text>`;
  const legend = legendHtml(data.map((d) => ({
    label: d.label, color: d.color,
    value: opts.valueFmt ? opts.valueFmt(d) : `${fmtMoney(d.value)} · ${fmtPct(d.value / total)}`,
  })));
  return `<div class="donut-wrap">${svgEl(size, size, g)}<div style="flex:1;min-width:140px">${legend}</div></div>`;
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
    `<span class="item"><span class="swatch" style="background:${it.color}"></span>${esc(it.label)}${
      it.value ? `<span class="lv">${esc(it.value)}</span>` : ""}</span>`).join("")}</div>`;
}

// Generic data table. cols: [{label, align?, get:(row,i)=>htmlString}]. rows: any[].
function tableHtml(cols, rows, emptyMsg = "No data in range.") {
  if (!rows || rows.length === 0) return `<p class="muted" style="font-size:12px">${esc(emptyMsg)}</p>`;
  const head = cols.map((c) => `<th${c.align === "left" ? ' style="text-align:left"' : ""}>${esc(c.label)}</th>`).join("");
  const body = rows.map((r, i) => `<tr>${cols.map((c) => `<td${c.align === "left" ? ' style="text-align:left"' : ""}>${c.get(r, i)}</td>`).join("")}</tr>`).join("");
  return `<table class="dtable"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
}

function emptyChart(W, H) {
  return svgEl(W, H, `<text x="${W / 2}" y="${H / 2}" text-anchor="middle" class="muted">No data</text>`);
}

function tokenTrendChart(rows) {
  // rows: [{Month, Tokens, Cost}] — bars = token volume (left axis), line = AI cost (right axis)
  const W = 760, H = 280;
  const m = { l: 56, r: 58, t: 16, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  if (!rows || rows.length === 0) return emptyChart(W, H);
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
    g += `<circle cx="${cx(i)}" cy="${yCost(r.Cost || 0)}" r="3" fill="${PALETTE[3]}"><title>${esc(fmtMonth(r.Month))}\n${fmtMoneyFull(r.Cost)}</title></circle>`;
  });
  // x labels
  const step = Math.ceil(n / 12);
  rows.forEach((r, i) => {
    if (i % step === 0 || i === n - 1) {
      g += `<text class="tick" x="${cx(i)}" y="${H - 12}" text-anchor="middle">${esc(fmtMonth(r.Month))}</text>`;
    }
  });
  const legend = legendHtml([
    { label: "Token volume", color: PALETTE[2] },
    { label: "AI effective cost", color: PALETTE[3] },
  ]);
  return svgEl(W, H, g) + legend;
}

function anomalyChart(rows) {
  // rows: [{Day, Cost, Flag, Baseline}]
  const W = 760, H = 280;
  const m = { l: 56, r: 18, t: 16, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  if (!rows || rows.length === 0) return emptyChart(W, H);
  const max = Math.max(...rows.map((r) => Math.max(r.Cost || 0, r.Baseline || 0)), 1) * 1.12;
  const n = rows.length;
  const x = (i) => m.l + (n === 1 ? iw / 2 : (i / (n - 1)) * iw);
  const y = (v) => m.t + ih - (v / max) * ih;
  let g = "";
  const ticks = 4;
  for (let t = 0; t <= ticks; t++) {
    const yy = m.t + ih - (ih / ticks) * t;
    g += `<line class="grid-line" x1="${m.l}" y1="${yy}" x2="${W - m.r}" y2="${yy}"/>`;
    g += `<text class="tick" x="${m.l - 8}" y="${yy + 4}" text-anchor="end">${fmtMoney((max / ticks) * t)}</text>`;
  }
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
      g += `<circle cx="${x(i)}" cy="${y(r.Cost || 0)}" r="4" fill="${up ? PALETTE[4] : PALETTE[5]}" stroke="var(--card-bg)" stroke-width="1"><title>${esc(String(r.Day).slice(0, 10))}\n${fmtMoneyFull(r.Cost)} (${up ? "spike" : "drop"})\nbaseline ${fmtMoneyFull(r.Baseline)}</title></circle>`;
    }
  });
  const legend = legendHtml([
    { label: "Daily effective cost", color: PALETTE[0] },
    { label: "Expected baseline", color: "var(--muted)" },
    { label: "Spike", color: PALETTE[4] },
    { label: "Drop", color: PALETTE[5] },
  ]);
  return svgEl(W, H, g) + legend;
}

function momBars(rows) {
  // rows: [{Month, EffChangePct}] — diverging bars (cost up = red, down = green)
  const W = 760, H = 240;
  const m = { l: 44, r: 14, t: 14, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  const data = (rows || []).filter((r) => isFinite(r.EffChangePct));
  if (data.length === 0) return emptyChart(W, H);
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
    g += `<rect class="bar" x="${cx(i) - bw / 2}" y="${yTop}" width="${bw}" height="${Math.max(1, h)}" rx="2" fill="${color}"><title>${esc(fmtMonth(r.Month))}\n${v > 0 ? "+" : ""}${v.toFixed(1)}%</title></rect>`;
    const step = Math.ceil(n / 12);
    if (i % step === 0 || i === n - 1) {
      g += `<text class="tick" x="${cx(i)}" y="${H - 12}" text-anchor="middle">${esc(fmtMonth(r.Month))}</text>`;
    }
  });
  return svgEl(W, H, g);
}

function forecastChart(rows, splitMonth) {
  // rows: [{Month, Actual, Forecast}] — actual solid up to splitMonth, forecast dashed onward
  const W = 760, H = 280;
  const m = { l: 56, r: 18, t: 16, b: 34 };
  const iw = W - m.l - m.r, ih = H - m.t - m.b;
  if (!rows || rows.length === 0) return emptyChart(W, H);
  const max = Math.max(...rows.map((r) => Math.max(r.Actual || 0, r.Forecast || 0)), 1) * 1.12;
  const n = rows.length;
  const x = (i) => m.l + (n === 1 ? iw / 2 : (i / (n - 1)) * iw);
  const y = (v) => m.t + ih - (v / max) * ih;
  let g = "";
  const ticks = 4;
  for (let t = 0; t <= ticks; t++) {
    const yy = m.t + ih - (ih / ticks) * t;
    g += `<line class="grid-line" x1="${m.l}" y1="${yy}" x2="${W - m.r}" y2="${yy}"/>`;
    g += `<text class="tick" x="${m.l - 8}" y="${yy + 4}" text-anchor="end">${fmtMoney((max / ticks) * t)}</text>`;
  }
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
  const step = Math.ceil(n / 12);
  rows.forEach((r, i) => {
    if (i % step === 0 || i === n - 1) {
      g += `<text class="tick" x="${x(i)}" y="${H - 12}" text-anchor="middle">${esc(fmtMonth(r.Month))}</text>`;
    }
  });
  rows.forEach((r, i) => {
    const isFc = i >= sIdx;
    g += `<circle cx="${x(i)}" cy="${y(isFc ? (r.Forecast || 0) : (r.Actual || 0))}" r="2.6" fill="${isFc ? PALETTE[3] : PALETTE[0]}"><title>${esc(fmtMonth(r.Month))}\n${isFc ? "forecast " + fmtMoneyFull(r.Forecast) : "actual " + fmtMoneyFull(r.Actual)}</title></circle>`;
  });
  const legend = legendHtml([
    { label: "Actual", color: PALETTE[0] },
    { label: "Forecast", color: PALETTE[3] },
  ]);
  return svgEl(W, H, g) + legend;
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

function switchTab(tabId) {
  if (state.loading || tabId === state.tab) return;
  state.tab = tabId;
  [...el("tabs").querySelectorAll("button")].forEach((b) => {
    b.classList.toggle("active", b.dataset.tab === tabId);
    b.setAttribute("aria-selected", b.dataset.tab === tabId ? "true" : "false");
  });
  load();
}

/* --------------------------------------------------------- triage strip */

function buildTriageTile(title, count, cue, tabId) {
  const cls = count === null ? "" : count === 0 ? "threshold-green" : count <= 4 ? "threshold-amber" : "threshold-red";
  const badge = count === null ? "Unknown" : count === 0 ? "Good" : count <= 4 ? "Review" : "Urgent";
  const display = count === null ? "—" : count === 0 ? "None" : fmtInt(count);
  return `<button class="triage-tile${cls ? ` ${cls}` : ""}" onclick="switchTab('${tabId}')" type="button">
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

function kpiCard(label, value, meta, accent, thresholdClass) {
  // Determine hierarchy class based on label
  const primaryLabels = ["Untagged cost", "Commitment waste", "Effective savings rate"];
  const referenceLabels = ["Commitment coverage", "Compute coverage", "Total tokens", "Anomaly days"];
  
  let hierarchyClass = "";
  if (primaryLabels.includes(label)) {
    hierarchyClass = "kpi--primary";
  } else if (referenceLabels.includes(label)) {
    hierarchyClass = "kpi--reference";
  }
  
  // Combine threshold and hierarchy classes
  const classArray = [thresholdClass, hierarchyClass].filter(Boolean);
  const cls = classArray.length > 0 ? ` ${classArray.join(" ")}` : "";
  
  return `<div class="kpi${cls}">
    <div class="label">${esc(label)}</div>
    <div class="value">${value}</div>
    <div class="meta">${meta}</div>
  </div>`;
}

/* ---------------------------------------------------------------- render */

function panelHtml(id, span, title, sub, body) {
  const subHtml = sub ? `<p class="panel-sub">${sub}</p>` : "";
  return `<div class="panel col-${span}" data-panel-id="${esc(id)}">
    <div class="panel-header"><div><h3>${title}</h3>${subHtml}</div><button class="kql-btn" type="button" title="View KQL query" aria-label="View KQL query" data-panel-id="${esc(id)}">&lt;/&gt;</button></div>
    <div class="panel-body">${body}</div>
  </div>`;
}

function openKqlDialog(panelId) {
  _kqlPanelId = panelId;
  el("kql-text").value = PANEL_KQL[panelId] || "";
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
  const head = cols.map((c) => `<th>${esc(c)}</th>`).join("");
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
  const maccRow = p.data.macc?.[0] || { ConsumptionAmount: 0, CommitmentAmount: 0, CommitmentBurnPercent: 0 };

  const kpis = [
    // primary KPIs first
    kpiCard("Untagged cost", fmtPct(k.untaggedPct),
      `${fmtMoney(k.untagged)} on untagged resources`, PALETTE[3],
      kpiThreshold(k.untaggedPct, 0.10, 0.25)),
    // supporting KPIs
    kpiCard("Effective cost", fmtMoney(k.eff), `Billed ${fmtMoney(k.billed)}`, PALETTE[0]),
    kpiCard("Total savings", fmtMoney(k.savings),
      `<span class="pos">${fmtPct(k.esr)}</span> effective savings rate`, PALETTE[1]),
    // reference KPIs
    kpiCard("Commitment coverage", fmtPct(k.coverage),
      `${fmtMoney(k.committed)} of compute spend`, PALETTE[5]),
    // supporting KPIs
    kpiCard("Tracked resources", fmtInt(k.resources),
      `${fmtInt(k.services)} services · ${fmtInt(k.subscriptions)} subs · ${fmtInt(k.regions)} regions`, PALETTE[2]),
    kpiCard("Latest month", k.lastMonthVal == null ? "—" : fmtMoney(k.lastMonthVal),
      k.mom == null ? (k.lastMonthLabel ? `${esc(k.lastMonthLabel)}${partialHtml}` : (isPartialMonth() ? `<span class="warn">partial month</span>` : "")) : `<span class="${momClass}">${momTxt}</span> vs prior · ${esc(k.lastMonthLabel)}${partialHtml}`, PALETTE[4]),
    // macc-consumption-vs-commitment — MACC burn rate
    kpiCard("MACC burn rate",
      maccRow.CommitmentAmount > 0 ? fmtPct(maccRow.CommitmentBurnPercent / 100) : "N/A",
      maccRow.CommitmentAmount > 0
        ? `${fmtMoney(maccRow.ConsumptionAmount)} of ${fmtMoney(maccRow.CommitmentAmount)} committed`
        : "No Microsoft Azure Consumption Commitment data",
      PALETTE[7]),
  ].join("");

  const d = p.data;
  const html = `
    ${renderTriageStrip(d)}
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>Understand usage &amp; cost</h2><span class="domain">FinOps Framework</span></div>
    <div class="panel-grid">
      ${panelHtml("overview-trend", 12, "Monthly cost trend", "Billed vs effective cost by month — executive run-rate view.", lineChart(d.trend))}
      ${panelHtml("overview-top-services", 6, "Top services by cost", "Effective cost by Azure service.", hbar(d.topServices, "ServiceName", "Cost"))}
      ${panelHtml("overview-service-category", 6, "Cost by service category", "Where spend concentrates across categories.", hbar(d.serviceCategory, "ServiceCategory", "Cost"))}
    </div>

    <div class="section-title"><h2>Optimize usage &amp; cost</h2><span class="domain">FinOps Framework</span></div>
    <div class="panel-grid">
      ${panelHtml("overview-top-rgs", 6, "Top resource groups", "Largest cost owners for allocation &amp; accountability.", hbar(d.topResourceGroups, "x_ResourceGroupName", "Cost"))}
      ${panelHtml("overview-top-regions", 6, "Cost by region", "Regional spend for placement &amp; sustainability review.", hbar(d.topRegions, "RegionId", "Cost"))}
    </div>

    <div class="section-title"><h2>Quantify business value</h2><span class="domain">FinOps Framework</span></div>
    <div class="panel-grid">
      ${panelHtml("overview-rate-coverage", 4, "Rate coverage", "Committed vs on-demand (standard) effective cost.", donut([
        { label: "Committed", value: k.committed, color: PALETTE[1] },
        { label: "On-demand", value: Math.max(0, k.eff - k.committed), color: PALETTE[0] },
      ], { centerBig: fmtPct(k.coverage), centerSmall: "covered" }))}
      ${panelHtml("overview-savings", 4, "Savings breakdown", "List → effective, by discount type.", savingsTable(k))}
      ${panelHtml("overview-cost-allocation", 4, "Cost allocation", "Tagged vs untagged effective cost.", donut([
        { label: "Tagged", value: k.tagged, color: PALETTE[1] },
        { label: "Untagged", value: k.untagged, color: PALETTE[3] },
      ], { centerBig: fmtPct(1 - k.untaggedPct), centerSmall: "tagged" }))}
    </div>
  `;
  content.innerHTML = html;
}

function savingsTable(k) {
  const row = (label, val, accent) =>
    `<div style="display:flex;justify-content:space-between;align-items:center;padding:9px 0;border-bottom:1px solid var(--grid);font-variant-numeric:tabular-nums">
      <span style="display:inline-flex;align-items:center;gap:8px">${
        accent ? `<span class="swatch" style="width:9px;height:9px;border-radius:3px;display:inline-block;background:${accent}"></span>` : ""}${esc(label)}</span>
      <strong>${fmtMoney(val)}</strong></div>`;
  return `<div>
    ${row("List cost", k.list, "var(--muted)")}
    ${row("Negotiated savings", k.negotiated, PALETTE[8])}
    ${row("Commitment savings", k.commitment, PALETTE[1])}
    ${row("Effective cost", k.eff, PALETTE[0])}
    <div style="display:flex;justify-content:space-between;margin-top:12px;padding-top:4px">
      <span class="muted" style="font-size:12px">Effective savings rate</span>
      <strong style="color:var(--pos)">${fmtPct(k.esr)}</strong>
    </div>
  </div>`;
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
    kpiCard("Total tokens", fmtTokens(k.tokens), `across ${fmtInt(k.models)} model SKUs`, PALETTE[0]),
    // supporting KPIs
    kpiCard("AI token cost", fmtMoney(k.eff), `${fmtPct(k.aiShare, 2)} of all cloud cost`, PALETTE[2]),
    kpiCard("Blended rate", fmtPerM(k.blendedPer1K), `per 1M tokens (effective)`, PALETTE[5]),
    kpiCard("Cached input", fmtPct(k.cachedShare),
      `<span class="pos">${fmtPct(k.cachedShare)}</span> of input tokens cached`, PALETTE[1]),
    kpiCard("AI resources", fmtInt(k.resources), `Azure OpenAI deployments`, PALETTE[4]),
    kpiCard("Models in use", fmtInt(k.models), `distinct token SKUs`, PALETTE[8]),
  ].join("");

  content.innerHTML = `
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>AI token economics</h2><span class="domain">Token Consumption Metrics KPI</span></div>
    <div class="panel-grid">
      ${panelHtml("token-trend", 12, "Token volume &amp; AI cost trend", "Monthly token consumption (bars) and effective AI cost (line).", tokenTrendChart(d.trend))}
      ${panelHtml("token-by-model", 6, "AI cost by model", "Effective cost per model family.",
        hbar((d.models || []).map((m) => ({ Model: m.Model, Cost: m.Cost })), "Model", "Cost"))}
      ${panelHtml("token-direction", 6, "Token direction mix", "Input vs cached input vs output — by token volume.",
        donut(dirSlices, {
          centerBig: fmtTokens(k.tokens), centerSmall: "tokens",
          valueFmt: (s) => `${fmtTokens(s.value)} · ${fmtMoney(s.cost)}`,
        }))}
    </div>

    <div class="section-title"><h2>Model efficiency</h2><span class="domain">Rate &amp; usage optimization</span></div>
    <div class="panel-grid">
      ${panelHtml("token-model-table", 12, "Cost per 1M tokens by model", "Unit economics for model selection — sorted by effective cost.", tokenModelTable(d.models, k.eff))}
    </div>

    <div class="section-title"><h2>AI cost allocation</h2><span class="domain">Showback &amp; chargeback · ai-cost-by-application</span></div>
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
      <td><span class="model"><span class="swatch" style="background:${color}"></span>${esc(m.Model)}</span></td>
      <td>${fmtTokens(m.Tokens)}</td>
      <td>${fmtMoneyFull(m.Cost)}</td>
      <td class="barcell">${fmtPerM(m.CostPer1K)}<span class="minibar" style="width:${barW}px;background:${color}"></span></td>
      <td>${fmtPct(share)}</td>
    </tr>`;
  }).join("");
  return `<table class="dtable">
    <thead><tr><th>Model</th><th>Tokens</th><th>Effective cost</th><th>$ / 1M tokens</th><th>% of AI cost</th></tr></thead>
    <tbody>${body}</tbody>
  </table>`;
}

function aiByAppTable(rows) {
  const data = (rows || []).filter((r) => (r.EffectiveCost || 0) > 0);
  if (data.length === 0) return `<p class="muted" style="font-size:12px">No tagged AI cost data. Tag Azure OpenAI resources with <code>application</code>, <code>team</code>, or <code>environment</code> tags.</p>`;
  const totalCost = data.reduce((a, r) => a + (r.EffectiveCost || 0), 0);
  return `<table class="dtable">
    <thead><tr><th>Application</th><th>Team</th><th>Environment</th><th>Cost center</th><th>Tokens</th><th>Effective cost</th><th>$/1M tokens</th><th>% of AI</th></tr></thead>
    <tbody>${data.map((r, i) => {
      const share = totalCost > 0 ? (r.EffectiveCost || 0) / totalCost : 0;
      const color = PALETTE[i % PALETTE.length];
      return `<tr>
        <td><span class="swatch" style="background:${color}"></span>${esc(r.Application || "(untagged)")}</td>
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

  const kpis = [
    // reference KPIs first (no primaries in this tab)
    kpiCard("Anomaly days", fmtInt(anomDays.length),
      `${fmtMoney(anomCost)} on flagged days`, PALETTE[5]),
    // supporting KPIs
    kpiCard("Anomaly detection rate", fmtPct(rate, 2),
      `${anomDays.length} flagged of ${daily.length} days`, PALETTE[4]),
    kpiCard("Unpredicted variance", fmtMoney(variance),
      `net spend vs baseline on anomaly days`, PALETTE[3]),
    kpiCard("Last month change", lastMc ? `${lastMc.EffChangePct > 0 ? "+" : ""}${lastMc.EffChangePct.toFixed(1)}%` : "—",
      lastMc ? `effective cost · ${esc(fmtMonth(lastMc.Month))}` : "", PALETTE[lastMc && lastMc.EffChangePct > 0 ? 4 : 1]),
    kpiCard("Forecast next month", nextFc ? fmtMoney(nextFc.Forecast) : "—",
      nextFc ? `projected · ${esc(fmtMonth(nextFc.Month))}` : "", PALETTE[0]),
    kpiCard("Visibility delay", p50Days != null ? `${p50Days.toFixed(0)}d` : "—",
      `median ingestion lag (P50)`, PALETTE[2]),
  ].join("");

  content.innerHTML = `
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>Cost anomalies</h2><span class="domain">Anomaly Management capability</span></div>
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
      `per consumed vCPU-hour`, PALETTE[0]),
    kpiCard("Effective cost / core", `$${effPerCore.toFixed(3)}`,
      `incl. unused commitment`, PALETTE[2]),
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
    type: r.ResourceType, count: r.Count || 0, cost: r.Cost || 0,
    pct: total > 0 ? (r.Cost || 0) / total : 0,
  }));
  const typeTable = tableHtml([
    { label: "Resource type", align: "left", get: (r, i) => `<span class="model"><span class="swatch" style="background:${PALETTE[i % PALETTE.length]}"></span>${esc(r.type)}</span>` },
    { label: "Resources", get: (r) => fmtInt(r.count) },
    { label: "Effective cost", get: (r) => fmtMoneyFull(r.cost) },
    { label: "% of total", get: (r) => fmtPct(r.pct) },
  ], typeRows);

  const tierColors = { "Frequent": PALETTE[1], "Infrequent": PALETTE[5], "Unclassified": PALETTE[6] };
  const tierSlices = (d.storageTiers || []).map((r) => ({ label: r.Tier, value: r.Cost || 0, color: tierColors[r.Tier] || PALETTE[6] }));
  const freqShare = (() => {
    const t = tierSlices.reduce((a, x) => a + x.value, 0);
    const f = (d.storageTiers || []).find((r) => r.Tier === "Frequent");
    return t > 0 ? (f?.Cost || 0) / t : 0;
  })();

  content.innerHTML = `
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>Usage &amp; unit economics</h2><span class="domain">Usage Optimization · Unit Economics</span></div>
    <div class="panel-grid">
      ${panelHtml("usage-top-types", 12, "Top resource types by cost", "Resource count and effective spend per resource type.", typeTable)}
      ${panelHtml("usage-per-core-series", 6, "Compute cost per core by VM series", "Effective cost per vCPU-hour — highlights expensive (e.g. GPU) cores.",
        hbar(d.perCoreSeries, "x_SkuMeterSubcategory", "PerCore"))}
      ${panelHtml("usage-storage-tiers", 6, `Storage tier distribution`, `Effective storage cost by access tier (${fmtPct(freqShare)} classified frequent).`,
        donut(tierSlices, { centerBig: fmtMoney(s.Cost), centerSmall: "storage" }))}
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

  const kpis = [
    // primary KPIs first
    kpiCard("Effective savings rate", fmtPct(esr),
      `<span class="pos">${fmtMoney(s.Total)}</span> total savings · vs. list price`, PALETTE[1]),
    kpiCard("Commitment waste", fmtPct(waste),
      `<span class="${waste > 0.1 ? "warn" : "pos"}">${fmtMoney(cm.Unused)}</span> unused · of commitment spend`, PALETTE[3],
      kpiThreshold(waste, 0.10, 0.20)),
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
      `compute spend on commitments`, PALETTE[5]),
    // supporting KPIs
    kpiCard("Committed core-hours", fmtPct(coreShare),
      `RI + savings plan vs on-demand`, PALETTE[8]),
  ].join("");

  const savingsBreak = `<div>
    ${rateRow("List cost", s.List, "var(--muted)")}
    ${rateRow("Negotiated savings", s.Negotiated, PALETTE[8])}
    ${rateRow("Commitment savings", s.Commitment, PALETTE[1])}
    ${rateRow("Effective cost", s.Effective, PALETTE[0])}
    <div style="display:flex;justify-content:space-between;margin-top:12px;padding-top:4px">
      <span class="muted" style="font-size:12px">Effective savings rate</span>
      <strong style="color:var(--pos)">${fmtPct(esr)}</strong>
    </div>
  </div>`;

  const coreColors = { "On Demand": PALETTE[0], "Reservation": PALETTE[1], "Savings Plan": PALETTE[4] };
  const coreSlices = (d.coreHours || []).map((r) => ({ label: r.t, value: r.CoreHours || 0, color: coreColors[r.t] || PALETTE[6] }));

  content.innerHTML = `
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>Rate optimization</h2><span class="domain">Rate Optimization capability</span></div>
    <div class="panel-grid">
      ${panelHtml("rate-savings", 7, "Savings breakdown", "List → effective cost by discount type (effective savings rate).", savingsBreak)}
      ${panelHtml("rate-commit-util", 5, "Commitment utilization", "Used vs unused commitment effective cost.",
        donut([
          { label: "Used", value: cmTotal - (cm.Unused || 0), color: PALETTE[1] },
          { label: "Unused (waste)", value: cm.Unused || 0, color: PALETTE[3] },
        ], { centerBig: fmtPct(util), centerSmall: "utilized" }))}
      ${panelHtml("rate-core-hours", 6, "Core-hour coverage", "Consumed core-hours by commitment type.",
        donut(coreSlices, {
          centerBig: fmtPct(coreShare), centerSmall: "committed",
          valueFmt: (s) => `${fmtTokens(s.value)} core-hrs`,
        }))}
      ${panelHtml("rate-underutil", 6, "Underutilized commitments", "Reservations &amp; plans with the most unused cost.",
        hbar(d.byCommitment, "CommitmentDiscountName", "Unused"))}
    </div>

    <div class="section-title"><h2>Commitment transactions</h2><span class="domain">Rate optimization · Commitment purchasing</span></div>
    <div class="panel-grid">
      ${panelHtml("rate-commit-score", 6, "Commitment utilization score", "Per-commitment utilization (used vs potential) from the formal CUS KPI.", commitUtilTable(d.commitmentUtilScore))}
      ${panelHtml("rate-top-txns", 6, "Top commitment transactions", "Largest RI and savings plan purchases by billed cost.", topCommitTxnTable(d.topCommitmentTxns))}
    </div>
  `;
}

function rateRow(label, val, accent) {
  return `<div style="display:flex;justify-content:space-between;align-items:center;padding:9px 0;border-bottom:1px solid var(--grid);font-variant-numeric:tabular-nums">
    <span style="display:inline-flex;align-items:center;gap:8px">${
      accent ? `<span class="swatch" style="width:9px;height:9px;border-radius:3px;display:inline-block;background:${accent}"></span>` : ""}${esc(label)}</span>
    <strong>${fmtMoney(val)}</strong></div>`;
}

function commitUtilTable(rows) {
  const data = (rows || []).filter((r) => r.CommitmentDiscountName !== '(Grand Total)' && (r.Potential || 0) > 0);
  if (data.length === 0) return `<p class="muted" style="font-size:12px">No commitment data in range.</p>`;
  return `<table class="dtable">
    <thead><tr><th>Commitment</th><th>Type</th><th>Score</th><th>Utilized</th><th>Potential</th></tr></thead>
    <tbody>${data.map((r) => {
      const score = r.Score || 0;
      const cls = score < 70 ? "neg" : score < 90 ? "warn" : "pos";
      const barW = Math.max(2, (score / 100) * 90);
      return `<tr>
        <td style="max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(r.CommitmentDiscountName)}</td>
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
    <thead><tr><th>Commitment</th><th>Type</th><th>Billed cost</th><th>Effective cost</th></tr></thead>
    <tbody>${data.map((r) => `<tr>
      <td style="max-width:180px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(r.CommitmentDiscountName || "(unknown)")}</td>
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
      kpiThreshold(untaggedPct, 0.10, 0.25)),
    // supporting KPIs
    kpiCard("Allocation accuracy", fmtPct(aai),
      `<span class="pos">directly attributed</span> effective cost`, PALETTE[1]),
    kpiCard("Unallocated cost", fmtPct(unallocPct),
      `${fmtMoney(total - c.Attributed)} lacks allocation evidence`, PALETTE[4]),
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
    { label: "Org", align: "left", get: (r, i) => `<span class="model"><span class="swatch" style="background:${PALETTE[i % PALETTE.length]}"></span>${esc(r.org)}</span>` },
    { label: "Project", align: "left", get: (r) => esc(r.project) },
    { label: "Environment", align: "left", get: (r) => esc(r.env) },
    { label: "Effective cost", get: (r) => fmtMoneyFull(r.cost) },
    { label: "% of total", get: (r) => fmtPct(r.pct) },
  ], hierRows);

  content.innerHTML = `
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>Cost allocation</h2><span class="domain">Allocation capability</span></div>
    <div class="panel-grid">
      ${panelHtml("alloc-hierarchy", 8, "Cost by financial hierarchy", "Org → project → environment (from resource tags), with share of total.", hierTable)}
      ${panelHtml("alloc-tagging", 4, "Tagging coverage", "Tagged vs untagged effective cost.",
        donut([
          { label: "Tagged", value: total - c.Untagged, color: PALETTE[1] },
          { label: "Untagged", value: c.Untagged, color: PALETTE[3] },
        ], { centerBig: fmtPct(1 - untaggedPct), centerSmall: "tagged" }))}
      ${panelHtml("alloc-tag-keys", 6, "Cost by tag key", "Effective cost touched by each governance tag.", hbar(d.tagKeys, "k", "Cost", { filterDim: null }))}
      ${panelHtml("alloc-by-subscription", 6, "Cost by subscription", "Spend per billing scope for showback.", hbar(d.bySubscription, "SubAccountName", "Cost"))}
    </div>
  `;
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

/* ----------------------------------------------------------------- driver */

const ENDPOINT = {
  overview: "/api/view?name=overview",
  allocation: "/api/view?name=allocation",
  rate: "/api/view?name=rate",
  usage: "/api/view?name=usage",
  anomaly: "/api/view?name=anomaly",
  tokenomics: "/api/view?name=tokenomics",
};

function currentPayload() {
  return state.cache[state.tab]?.[cacheKey()];
}

function render() {
  const p = currentPayload();
  if (!p) return;
  if (state.tab === "tokenomics") renderTokenomics(p);
  else if (state.tab === "allocation") renderAllocation(p);
  else if (state.tab === "rate") renderRate(p);
  else if (state.tab === "usage") renderUsage(p);
  else if (state.tab === "anomaly") renderAnomaly(p);
  else renderOverview(p);
}

async function load() {
  const tab = state.tab, key = cacheKey();
  if (state.cache[tab]?.[key]) { updateChrome(); render(); return; }
  state.cache[tab] = state.cache[tab] || {};
  state.loading = true;
  setRefreshSpinning(true);
  el("content").innerHTML = `
    <div class="skeleton-kpi-grid">
      ${'<div class="skeleton-card"></div>'.repeat(6)}
    </div>
    <div class="skeleton-card skeleton-panel-lg"></div>
    <div class="skeleton-card skeleton-panel-sm"></div>
  `;
  try {
    const res = await fetch(`${ENDPOINT[tab]}&preset=${encodeURIComponent(state.preset)}${filterParam()}`);
    state.cache[tab][key] = await res.json();
  } catch (err) {
    console.error("[ftk-dashboard] fetch failed:", err);
    state.cache[tab][key] = { error: "Could not load data. Check that the Kusto emulator is running." };
  }
  state.loading = false;
  setRefreshSpinning(false);
  updateChrome();
  render();
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
  }
}

function wireControls() {
  el("preset").addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-preset]");
    if (!btn || state.loading) return;
    state.preset = btn.dataset.preset;
    [...el("preset").querySelectorAll("button")].forEach((b) => b.classList.toggle("active", b === btn));
    load();
  });
  el("tabs").addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-tab]");
    if (btn) switchTab(btn.dataset.tab);
  });
  el("refresh").addEventListener("click", () => {
    if (state.loading) return;
    if (state.cache[state.tab]) delete state.cache[state.tab][cacheKey()]; // force re-query
    load();
  });

  // KQL dialog controls
  el("kql-close").addEventListener("click", () => el("kql-dialog").close());
  el("kql-copy").addEventListener("click", () => navigator.clipboard.writeText(el("kql-text").value));
  el("kql-run").addEventListener("click", executeKql);

  // KQL escape-hatch buttons (event delegation — buttons injected by panelHtml)
  document.addEventListener("click", (e) => {
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
  });

  let t;
  window.addEventListener("resize", () => { clearTimeout(t); t = setTimeout(render, 180); });
}

async function init() {
  try {
    const cfg = await fetch("/api/config").then((r) => r.json());
    window.__cfg = cfg;
  } catch { window.__cfg = {}; }
  wireControls();
  load();
}

init();
