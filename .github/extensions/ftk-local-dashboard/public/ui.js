"use strict";

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[char]);
}

function controlName(value) {
  const name = String(value ?? "");
  if (!/^[a-z][a-z0-9-]*$/.test(name)) throw new Error(`Invalid UI control name '${name}'.`);
  return name;
}

export function uiSegmentedControl({ name, label, labelId, items = [], selected }) {
  const control = controlName(name);
  return `<div class="ui-control-group">
    <span class="ui-control-label" id="${escapeHtml(labelId)}">${escapeHtml(label)}</span>
    <div class="ui-segments" role="radiogroup" aria-labelledby="${escapeHtml(labelId)}">
      ${items.map((item) => {
        const active = String(item.value) === String(selected);
        return `<button type="button" class="ui-segment" role="radio"
          data-ui-segment="${control}" data-ui-value="${escapeHtml(item.value)}"
          aria-checked="${active}" tabindex="${active ? "0" : "-1"}">${escapeHtml(item.label)}
          ${item.count == null ? "" : `<span class="ui-segment-count">${escapeHtml(item.count)}</span>`}</button>`;
      }).join("")}
    </div>
  </div>`;
}

export function uiToggleList({ name, label, labelId, items = [], selected = [] }) {
  const control = controlName(name);
  const selectedValues = new Set(selected.map(String));
  return `<div class="ui-control-group">
    <span class="ui-control-label" id="${escapeHtml(labelId)}">${escapeHtml(label)}</span>
    <div class="ui-segments ui-segments--scroll" role="group" aria-labelledby="${escapeHtml(labelId)}">
      ${items.map((item) => `<button type="button" class="ui-segment"
        data-ui-toggle="${control}" data-ui-value="${escapeHtml(item.value)}"
        aria-pressed="${selectedValues.has(String(item.value))}">${escapeHtml(item.label)}</button>`).join("")}
    </div>
  </div>`;
}

export function uiSearchField({ name, id, label, value = "", placeholder = "" }) {
  const control = controlName(name);
  return `<label class="ui-control-group" for="${escapeHtml(id)}">
    <span class="ui-control-label">${escapeHtml(label)}</span>
    <input id="${escapeHtml(id)}" class="ui-search" type="search" data-ui-search="${control}"
      value="${escapeHtml(value)}" placeholder="${escapeHtml(placeholder)}"
      autocomplete="off" spellcheck="false">
  </label>`;
}

export function uiFilterBar({ ariaLabel, controls, summary, resetLabel = null, resetAction = "reset" }) {
  const action = controlName(resetAction);
  return `<div class="ui-filter-bar" role="group" aria-label="${escapeHtml(ariaLabel)}">
    ${controls}
    <p class="ui-filter-summary" role="status">${escapeHtml(summary)}
      ${resetLabel ? `<button type="button" class="ui-button" data-ui-action="${action}">${escapeHtml(resetLabel)}</button>` : ""}
    </p>
  </div>`;
}

export function uiTabList({ name, label, tabs = [], active, panelId, panel }) {
  const control = controlName(name);
  return `<div class="ui-tabs" role="tablist" aria-label="${escapeHtml(label)}">
      ${tabs.map((tab) => {
        const selected = tab.id === active;
        return `<button id="${escapeHtml(control)}-tab-${escapeHtml(tab.id)}" type="button" class="ui-segment"
          role="tab" data-ui-tab="${control}" data-ui-value="${escapeHtml(tab.id)}"
          aria-selected="${selected}" aria-controls="${escapeHtml(panelId)}"
          tabindex="${selected ? "0" : "-1"}">${escapeHtml(tab.label)}</button>`;
      }).join("")}
    </div>
    <div id="${escapeHtml(panelId)}" role="tabpanel"
      aria-labelledby="${escapeHtml(control)}-tab-${escapeHtml(active)}">${panel}</div>`;
}

export function uiPagination({ name, page, totalPages, label }) {
  if (totalPages <= 1) return "";
  const control = controlName(name);
  return `<div class="ui-pagination" aria-label="${escapeHtml(label)}">
    <button type="button" class="ui-button" data-ui-page="${control}" data-ui-value="${page - 1}"${page <= 1 ? " disabled" : ""}>Previous</button>
    <span>Page ${escapeHtml(page)} of ${escapeHtml(totalPages)}</span>
    <button type="button" class="ui-button" data-ui-page="${control}" data-ui-value="${page + 1}"${page >= totalPages ? " disabled" : ""}>Next</button>
  </div>`;
}

export function uiDataMatrix({
  ariaLabel,
  descriptionId,
  rowHeader,
  rows = [],
  columns = [],
  renderCell,
  missingText = "Not reported",
}) {
  return `<div class="ui-matrix-viewport" tabindex="0" role="region" aria-label="${escapeHtml(ariaLabel)}">
    <table class="ui-matrix" aria-describedby="${escapeHtml(descriptionId)}">
      <thead><tr><th scope="col">${escapeHtml(rowHeader)}</th>${columns.map((column) => `<th scope="col">${escapeHtml(column)}</th>`).join("")}</tr></thead>
      <tbody>${rows.map((row) => `<tr>
        <th scope="row" title="${escapeHtml(row.title || row.label)}">${escapeHtml(row.label)}</th>
        ${columns.map((column) => renderCell(row, column) || `<td class="ui-matrix-cell ui-matrix-cell--missing">${escapeHtml(missingText)}</td>`).join("")}
      </tr>`).join("")}</tbody>
    </table>
  </div>`;
}
