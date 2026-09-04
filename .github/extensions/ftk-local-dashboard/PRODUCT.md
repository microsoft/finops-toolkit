# Product

## Register

product

## Users

FinOps practitioners, cloud engineers, and consultants who need to analyze Azure cost data locally without deploying Azure resources. They run this dashboard as a GitHub Copilot canvas while they explore the data model, validate large datasets, or analyze data in disconnected or on-premises environments. They are data-fluent, comfortable with KQL and Azure concepts, and expect density and precision over decoration. They want numbers fast.

## Product Purpose

A FinOps hub dashboard that connects to a local Kusto emulator or a remote Azure Data Explorer cluster. It provides cost, allocation, rate optimization, usage, anomaly, AI token, AI Foundry platform, agent operations, and supply views. The AI Foundry view reproduces the canonical Azure Managed Grafana platform dashboard across every accessible Cognitive Services account. It uses Azure Monitor platform metrics, supports account and deployment drill-down, and replaces fixed prices with FinOps Hub rates. The Supply workspace keeps quota, billed demand, inventory, physical supply, and pricing commitments separate. Success means that a practitioner can load hub data, select a view, and answer a FinOps question in one session.

The separate Foundry agents view shows Microsoft Foundry agent activity from application dependencies and traces. It shares the Foundry account and time controls. Every panel derives from one cached query of the workspaces that are connected to accessible Microsoft Foundry projects. Selecting a Foundry account scopes the result by Foundry project.

Both Microsoft Foundry operations views show estimated cost beside the token usage that produced it. The Foundry infrastructure view supports deployment and time-bucket estimates from platform metrics. The Foundry agents view supports uncached input, cached input, output, model, agent, and individual-run estimates from traces. Agent run cost isn't a `Costs()` join. Exact `Costs()` matches for separately billed agent resources appear as a distinct authoritative billed-cost field. Partial price coverage and telemetry gaps stay visible.

## Brand Personality

Precise. Grounded. Efficient. The interface should feel like a well-calibrated instrument, not a product pitch. Numbers are the focus, and the chrome disappears.

The canvas is a desktop-only workspace with a minimum width of 1280 pixels. Do not add mobile layouts or narrow-screen reflow.

## Anti-references

- Consumer personal finance dashboards (Mint, Copilot Money) — too soft, too colorful
- SaaS marketing dashboards (hero metric templates, gradient text, glassmorphism cards)
- Over-designed BI tools with heavy chrome, deep sidebars, and modal-heavy workflows
- Any interface that prioritizes looking impressive over being immediately useful

## Design Principles

1. **Numbers first**: KPIs and data are the primary visual elements. Supporting chrome, such as headers, tabs, and labels, recedes.
2. **GitHub-native**: Use GitHub design tokens (`--background-color-default`, `--text-color-default`, and others) so the panel feels like an extension of Copilot.
3. **Dense by design**: FinOps data is multidimensional. Don't sacrifice information density for whitespace.
4. **Explicit state**: Treat loading, error, empty, and no-data states as primary states. Every panel handles each state.
5. **Zero ceremony**: Don't add animated introductions or onboarding tours. Open the panel and see the data.

## Accessibility & Inclusion

WCAG AA minimum. SVG charts include `<title>` elements for screen-reader context. Interactive controls have ARIA roles and labels. Capacity heatmaps include values and states as text. Users can operate the tabs with a keyboard. The interface respects reduced-motion preferences.
