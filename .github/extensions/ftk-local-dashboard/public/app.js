/* FinOps hub local dashboard — client renderer.
   Dependency-free: KPIs + SVG charts (line, horizontal bar, donut).
   Data comes from the extension's loopback /api endpoints. */

"use strict";

const PALETTE = [
  "#3b82f6", "#10b981", "#8b5cf6", "#f59e0b", "#ef4444", "#06b6d4",
  "#ec4899", "#84cc16", "#f97316", "#6366f1", "#14b8a6", "#a855f7",
];

const state = { preset: "all", tab: "overview", loading: false, cache: {} };

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
  let g = "";
  data.forEach((d, i) => {
    const yy = i * rowH + 4;
    const cy = yy + rowH / 2;
    const w = Math.max(2, (d.val / max) * barW);
    const color = opts.color || PALETTE[i % PALETTE.length];
    const pct = total > 0 ? (d.val / total) : 0;
    g += `<g class="hbar-row">`;
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
  // Anomalies: reuse anomaly tab cache when loaded
  const anomPayload = state.cache["anomaly"]?.[state.preset];
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
  const ratePayload = state.cache["rate"]?.[state.preset];
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
  const cls = thresholdClass ? ` ${thresholdClass}` : "";
  return `<div class="kpi${cls}" style="--kpi-accent:${accent}">
    <div class="label">${esc(label)}</div>
    <div class="value">${value}</div>
    <div class="meta">${meta}</div>
  </div>`;
}

/* ---------------------------------------------------------------- render */

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
    kpiCard("Effective cost", fmtMoney(k.eff), `Billed ${fmtMoney(k.billed)}`, PALETTE[0]),
    kpiCard("Total savings", fmtMoney(k.savings),
      `<span class="pos">${fmtPct(k.esr)}</span> effective savings rate`, PALETTE[1]),
    kpiCard("Untagged cost", fmtPct(k.untaggedPct),
      `${fmtMoney(k.untagged)} on untagged resources`, PALETTE[3],
      kpiThreshold(k.untaggedPct, 0.10, 0.25)),
    kpiCard("Commitment coverage", fmtPct(k.coverage),
      `${fmtMoney(k.committed)} of compute spend`, PALETTE[5]),
    kpiCard("Tracked resources", fmtInt(k.resources),
      `${fmtInt(k.services)} services · ${fmtInt(k.subscriptions)} subs · ${fmtInt(k.regions)} regions`, PALETTE[2]),
    kpiCard("Latest month", k.lastMonthVal == null ? "—" : fmtMoney(k.lastMonthVal),
      k.mom == null ? `${esc(k.lastMonthLabel || "")}${partialHtml}` : `<span class="${momClass}">${momTxt}</span> vs prior · ${esc(k.lastMonthLabel)}${partialHtml}`, PALETTE[4]),
  ].join("");

  const d = p.data;
  const html = `
    ${renderTriageStrip(d)}
    <div class="kpi-grid">${kpis}</div>

    <div class="section-title"><h2>Understand usage &amp; cost</h2><span class="domain">FinOps Framework</span></div>
    <div class="panel-grid">
      <div class="panel col-12">
        <h3>Monthly cost trend</h3>
        <p class="panel-sub">Billed vs effective cost by month — executive run-rate view.</p>
        ${lineChart(d.trend)}
      </div>
      <div class="panel col-6">
        <h3>Top services by cost</h3>
        <p class="panel-sub">Effective cost by Azure service.</p>
        ${hbar(d.topServices, "ServiceName", "Cost")}
      </div>
      <div class="panel col-6">
        <h3>Cost by service category</h3>
        <p class="panel-sub">Where spend concentrates across categories.</p>
        ${hbar(d.serviceCategory, "ServiceCategory", "Cost")}
      </div>
    </div>

    <div class="section-title"><h2>Optimize usage &amp; cost</h2><span class="domain">FinOps Framework</span></div>
    <div class="panel-grid">
      <div class="panel col-6">
        <h3>Top resource groups</h3>
        <p class="panel-sub">Largest cost owners for allocation &amp; accountability.</p>
        ${hbar(d.topResourceGroups, "x_ResourceGroupName", "Cost")}
      </div>
      <div class="panel col-6">
        <h3>Cost by region</h3>
        <p class="panel-sub">Regional spend for placement &amp; sustainability review.</p>
        ${hbar(d.topRegions, "RegionId", "Cost")}
      </div>
    </div>

    <div class="section-title"><h2>Quantify business value</h2><span class="domain">FinOps Framework</span></div>
    <div class="panel-grid">
      <div class="panel col-4">
        <h3>Rate coverage</h3>
        <p class="panel-sub">Committed vs on-demand (standard) effective cost.</p>
        ${donut([
          { label: "Committed", value: k.committed, color: PALETTE[1] },
          { label: "On-demand", value: Math.max(0, k.eff - k.committed), color: PALETTE[0] },
        ], { centerBig: fmtPct(k.coverage), centerSmall: "covered" })}
      </div>
      <div class="panel col-4">
        <h3>Savings breakdown</h3>
        <p class="panel-sub">List → effective, by discount type.</p>
        ${savingsTable(k)}
      </div>
      <div class="panel col-4">
        <h3>Cost allocation</h3>
        <p class="panel-sub">Tagged vs untagged effective cost.</p>
        ${donut([
          { label: "Tagged", value: k.tagged, color: PALETTE[1] },
          { label: "Untagged", value: k.untagged, color: PALETTE[3] },
        ], { centerBig: fmtPct(1 - k.untaggedPct), centerSmall: "tagged" })}
      </div>
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
    kpiCard("AI token cost", fmtMoney(k.eff), `${fmtPct(k.aiShare, 2)} of all cloud cost`, PALETTE[2]),
    kpiCard("Total tokens", fmtTokens(k.tokens), `across ${fmtInt(k.models)} model SKUs`, PALETTE[0]),
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
      <div class="panel col-12">
        <h3>Token volume &amp; AI cost trend</h3>
        <p class="panel-sub">Monthly token consumption (bars) and effective AI cost (line).</p>
        ${tokenTrendChart(d.trend)}
      </div>
      <div class="panel col-6">
        <h3>AI cost by model</h3>
        <p class="panel-sub">Effective cost per model family.</p>
        ${hbar((d.models || []).map((m) => ({ Model: m.Model, Cost: m.Cost })), "Model", "Cost")}
      </div>
      <div class="panel col-6">
        <h3>Token direction mix</h3>
        <p class="panel-sub">Input vs cached input vs output — by token volume.</p>
        ${donut(dirSlices, {
          centerBig: fmtTokens(k.tokens), centerSmall: "tokens",
          valueFmt: (s) => `${fmtTokens(s.value)} · ${fmtMoney(s.cost)}`,
        })}
      </div>
    </div>

    <div class="section-title"><h2>Model efficiency</h2><span class="domain">Rate &amp; usage optimization</span></div>
    <div class="panel-grid">
      <div class="panel col-12">
        <h3>Cost per 1M tokens by model</h3>
        <p class="panel-sub">Unit economics for model selection — sorted by effective cost.</p>
        ${tokenModelTable(d.models, k.eff)}
      </div>
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
    kpiCard("Anomaly detection rate", fmtPct(rate, 2),
      `${anomDays.length} flagged of ${daily.length} days`, PALETTE[4]),
    kpiCard("Unpredicted variance", fmtMoney(variance),
      `net spend vs baseline on anomaly days`, PALETTE[3]),
    kpiCard("Anomaly days", fmtInt(anomDays.length),
      `${fmtMoney(anomCost)} on flagged days`, PALETTE[5]),
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
      <div class="panel col-12">
        <h3>Daily cost &amp; detected anomalies</h3>
        <p class="panel-sub">Daily effective cost vs the expected baseline (STL decomposition); markers flag spikes &amp; drops.</p>
        ${anomalyChart(daily)}
      </div>
    </div>

    <div class="section-title"><h2>Trend &amp; forecast</h2><span class="domain">Forecasting · Data freshness</span></div>
    <div class="panel-grid">
      <div class="panel col-6">
        <h3>Month-over-month change</h3>
        <p class="panel-sub">Effective cost % change vs prior month (red = increase).</p>
        ${momBars(mc)}
      </div>
      <div class="panel col-6">
        <h3>Cost forecast</h3>
        <p class="panel-sub">Monthly effective cost, actual vs forecast (next 3 months).</p>
        ${forecastChart(fc, dataMaxMonth)}
      </div>
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
      <div class="panel col-12">
        <h3>Top resource types by cost</h3>
        <p class="panel-sub">Resource count and effective spend per resource type.</p>
        ${typeTable}
      </div>
      <div class="panel col-6">
        <h3>Compute cost per core by VM series</h3>
        <p class="panel-sub">Effective cost per vCPU-hour — highlights expensive (e.g. GPU) cores.</p>
        ${hbar(d.perCoreSeries, "x_SkuMeterSubcategory", "PerCore")}
      </div>
      <div class="panel col-6">
        <h3>Storage tier distribution</h3>
        <p class="panel-sub">Effective storage cost by access tier (${fmtPct(freqShare)} classified frequent).</p>
        ${donut(tierSlices, { centerBig: fmtMoney(s.Cost), centerSmall: "storage" })}
      </div>
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
    kpiCard("Effective savings rate", fmtPct(esr),
      `<span class="pos">${fmtMoney(s.Total)}</span> total savings · vs. list price`, PALETTE[1]),
    kpiCard("Total savings", fmtMoney(s.Total),
      `of ${fmtMoney(s.List)} list cost`, PALETTE[2]),
    kpiCard("Commitment utilization", fmtPct(util),
      `${fmtMoney(cmTotal - (cm.Unused || 0))} of ${fmtMoney(cmTotal)} used`, PALETTE[0]),
    kpiCard("Commitment waste", fmtPct(waste),
      `<span class="${waste > 0.1 ? "warn" : "pos"}">${fmtMoney(cm.Unused)}</span> unused · of commitment spend`, PALETTE[3],
      kpiThreshold(waste, 0.10, 0.20)),
    kpiCard("Compute coverage", fmtPct(coverage),
      `compute spend on commitments`, PALETTE[5]),
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
      <div class="panel col-7">
        <h3>Savings breakdown</h3>
        <p class="panel-sub">List → effective cost by discount type (effective savings rate).</p>
        ${savingsBreak}
      </div>
      <div class="panel col-5">
        <h3>Commitment utilization</h3>
        <p class="panel-sub">Used vs unused commitment effective cost.</p>
        ${donut([
          { label: "Used", value: cmTotal - (cm.Unused || 0), color: PALETTE[1] },
          { label: "Unused (waste)", value: cm.Unused || 0, color: PALETTE[3] },
        ], { centerBig: fmtPct(util), centerSmall: "utilized" })}
      </div>
      <div class="panel col-6">
        <h3>Core-hour coverage</h3>
        <p class="panel-sub">Consumed core-hours by commitment type.</p>
        ${donut(coreSlices, {
          centerBig: fmtPct(coreShare), centerSmall: "committed",
          valueFmt: (s) => `${fmtTokens(s.value)} core-hrs`,
        })}
      </div>
      <div class="panel col-6">
        <h3>Underutilized commitments</h3>
        <p class="panel-sub">Reservations &amp; plans with the most unused cost.</p>
        ${hbar(d.byCommitment, "CommitmentDiscountName", "Unused")}
      </div>
    </div>
  `;
}

function rateRow(label, val, accent) {
  return `<div style="display:flex;justify-content:space-between;align-items:center;padding:9px 0;border-bottom:1px solid var(--grid);font-variant-numeric:tabular-nums">
    <span style="display:inline-flex;align-items:center;gap:8px">${
      accent ? `<span class="swatch" style="width:9px;height:9px;border-radius:3px;display:inline-block;background:${accent}"></span>` : ""}${esc(label)}</span>
    <strong>${fmtMoney(val)}</strong></div>`;
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
    kpiCard("Allocation accuracy", fmtPct(aai),
      `<span class="pos">directly attributed</span> effective cost`, PALETTE[1]),
    kpiCard("Untagged cost", fmtPct(untaggedPct),
      `${fmtMoney(c.Untagged)} with no tags`, PALETTE[3],
      kpiThreshold(untaggedPct, 0.10, 0.25)),
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
      <div class="panel col-8">
        <h3>Cost by financial hierarchy</h3>
        <p class="panel-sub">Org → project → environment (from resource tags), with share of total.</p>
        ${hierTable}
      </div>
      <div class="panel col-4">
        <h3>Tagging coverage</h3>
        <p class="panel-sub">Tagged vs untagged effective cost.</p>
        ${donut([
          { label: "Tagged", value: total - c.Untagged, color: PALETTE[1] },
          { label: "Untagged", value: c.Untagged, color: PALETTE[3] },
        ], { centerBig: fmtPct(1 - untaggedPct), centerSmall: "tagged" })}
      </div>
      <div class="panel col-6">
        <h3>Cost by tag key</h3>
        <p class="panel-sub">Effective cost touched by each governance tag.</p>
        ${hbar(d.tagKeys, "k", "Cost")}
      </div>
      <div class="panel col-6">
        <h3>Cost by subscription</h3>
        <p class="panel-sub">Spend per billing scope for showback.</p>
        ${hbar(d.bySubscription, "SubAccountName", "Cost")}
      </div>
    </div>
  `;
}

function renderError(p) {
  el("content").innerHTML = `<div class="error">
    <h2>Can’t reach the FinOps hub</h2>
    <p>The dashboard queried <code>${esc(p.clusterUri || "")}</code> (database <code>${esc(p.database || "Hub")}</code>) but the request failed.</p>
    <p class="muted">Start the Kusto emulator and run <code>Initialize-FinOpsHubLocal</code>, then refresh.</p>
    <pre>${esc(p.error)}</pre>
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
  return state.cache[state.tab]?.[state.preset];
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
  const tab = state.tab, preset = state.preset;
  if (state.cache[tab]?.[preset]) { updateChrome(); render(); return; }
  state.cache[tab] = state.cache[tab] || {};
  state.loading = true;
  setRefreshSpinning(true);
  el("content").innerHTML = `<div class="loading">Loading ${tab} data…</div>`;
  try {
    const res = await fetch(`${ENDPOINT[tab]}&preset=${encodeURIComponent(preset)}`);
    state.cache[tab][preset] = await res.json();
  } catch (err) {
    console.error("[ftk-dashboard] fetch failed:", err);
    state.cache[tab][preset] = { error: "Could not load data. Check that the Kusto emulator is running." };
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

function updateChrome() {
  const p = currentPayload();
  const w = p && p.window;
  if (w && w.dataMin) {
    el("source-line").innerHTML =
      `Hub database · <code>${esc(window.__cfg?.clusterUri || "localhost:8082")}</code> · ${esc(fmtDayRange(w.dataMin, w.dataMax))}`;
    let meta;
    if (state.tab === "tokenomics" && p.data) {
      const s = p.data.summary?.[0] || {};
      meta = `${fmtTokens(s.Tokens)} tokens · ${fmtMoney(s.Effective)} AI cost`;
    } else {
      meta = `${fmtInt(w.rows)} rows in range`;
    }
    el("footer-meta").textContent =
      `${meta} · window ${w.start} → ${w.end} · refreshed ${new Date(p.generatedAt).toLocaleTimeString()}`;
  } else if (p && p.error) {
    el("source-line").textContent = "Connection failed — see panel below.";
    el("footer-meta").textContent = "";
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
    if (state.cache[state.tab]) delete state.cache[state.tab][state.preset]; // force re-query
    load();
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
