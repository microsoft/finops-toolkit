# FinOps hub local — product context

## What this is

A live cost-analytics dashboard embedded in GitHub Copilot CLI as a canvas extension.
It connects to a locally-running Kusto emulator (ftklocal) loaded with the FinOps hub
schema and renders interactive KPI cards, charts, and triage signals — all grounded in
the FinOps Framework and the finops-toolkit query catalog.

## Register

product — design serves the product, the dashboard is the tool, not the brand.

## Users

FinOps practitioners and cloud engineers who run `Initialize-FinOpsHubLocal` and want
to explore their Azure cost data locally without provisioning cloud infrastructure.
They are technical (comfortable with KQL, PowerShell, Azure), time-conscious, and
treat the dashboard as a professional diagnostic surface rather than a consumer app.

## Goals

- Show the six FinOps Framework capability areas (overview, allocation, rate, usage,
  anomaly, tokenomics) with actionable KPIs and charts.
- Let engineers drill down by clicking chart elements to slice the full dataset by
  service, category, region, resource group, or subscription.
- Surface triage signals (anomalies, overspend, savings gaps) at a glance.
- Stay snappy: all data is local, no network calls beyond the loopback emulator.

## Non-goals

- Not a production monitoring tool (no alerting, no SLAs).
- Not a multi-user shared dashboard (single-engineer local only).
- Not a replacement for Cost Management in the Azure portal.

## Design constraints

- Zero external dependencies: vanilla JS/CSS, no build step, no npm packages.
- Served by a Node.js HTTP server inside the Copilot extension process.
- Embeds in the Copilot CLI canvas panel (variable width, ~800–1400 px typical).
- Must respect GitHub's CSS custom properties for light/dark theming.
- All interactivity must be keyboard-accessible and meet WCAG 2.1 AA contrast.
