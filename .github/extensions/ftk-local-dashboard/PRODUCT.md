# Product

## Register

product

## Users

FinOps practitioners, cloud engineers, and consultants who need to analyze Azure cost data locally — without deploying Azure resources. They run this inside GitHub Copilot as a canvas panel while they work: exploring the data model, validating large datasets, or doing FinOps analysis in disconnected / on-premises environments. They are data-fluent, comfortable with KQL and Azure concepts, and expect density and precision over decoration. They are in a task when they open this — they want numbers fast.

## Product Purpose

A FinOps hub dashboard that connects to a local Kusto emulator or a remote Azure Data Explorer cluster. It provides cost, allocation, rate optimization, usage, anomaly, AI token, and capacity views. The Capacity workspace keeps quota, billed demand, inventory, physical supply, and pricing commitments as separate quota areas. Success means that a practitioner can load hub data, select a view, and find the quota answer they need in one session.

## Brand Personality

Precise. Grounded. Efficient. The interface should feel like a well-calibrated instrument, not a product pitch. Numbers are the hero; the chrome disappears.

## Anti-references

- Consumer personal finance dashboards (Mint, Copilot Money) — too soft, too colorful
- SaaS marketing dashboards (hero metric templates, gradient text, glassmorphism cards)
- Over-designed BI tools with heavy chrome, deep sidebars, and modal-heavy workflows
- Any interface that prioritizes looking impressive over being immediately useful

## Design Principles

1. **Numbers first** — KPIs and data are the primary visual element. Supporting chrome (headers, tabs, labels) recedes.
2. **GitHub-native** — Use GitHub design tokens (`--background-color-default`, `--text-color-default`, etc.) so the panel feels like an extension of Copilot, not a foreign app.
3. **Density is a virtue** — FinOps data is inherently multi-dimensional. Don't sacrifice information density for whitespace.
4. **State is explicit** — Loading, error, empty, and no-data states are real states, not afterthoughts. Every panel handles all of them.
5. **Zero ceremony** — No animated intros, no onboarding tours. Open panel → see data.

## Accessibility & Inclusion

WCAG AA minimum. SVG charts include `<title>` elements for screen-reader context. Interactive controls have ARIA roles and labels. Capacity heatmaps include values and states as text. Users can operate the tabs with a keyboard. The interface respects reduced-motion preferences.
