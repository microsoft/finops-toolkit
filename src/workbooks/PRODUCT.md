# Product

<!-- impeccable:product-schema 1 -->

Scope: the 12 FinOps toolkit Grafana dashboards in this folder (`ftk-*.json`) and the
Bicep module that deploys them. This record does not cover the Azure Monitor workbooks
in `governance/` and `optimization/`.

Facts marked **[inferred]** come from repository evidence and the stated brief. The
interview step did not run, because the question tool is disabled in this environment.
Confirm or correct each inferred fact before later work depends on it.

## Platform

web

## Users

**[inferred]** Two groups read these dashboards:

- FinOps practitioners, who run the cost review rhythm and act on what they find.
- Finance, procurement, and executive stakeholders, who read the result and decide.

The second group does not read Azure resource schemas. They read money, trend, and
exception. A dashboard that shows raw column names fails this group.

## Product Purpose

The dashboards report cloud and AI spend from a deployed FinOps hub. They answer four
recurring questions: what did we spend, where did it go, what is wrong, and what do we
change.

Eight dashboards report Azure spend from the hub database:

| Dashboard | Subject |
| --- | --- |
| `ftk-hub-summary` | Entry point across the hub |
| `ftk-hub-overview` | Cost, savings, and forecast |
| `ftk-hub-rate-optimization` | Commitment discounts and hybrid benefit |
| `ftk-hub-anomaly-management` | Unexpected cost change |
| `ftk-hub-budgeting` | Budget position |
| `ftk-hub-invoicing-chargeback` | Allocation and chargeback |
| `ftk-hub-licensing-saas` | Licensing and SaaS |
| `ftk-hub-data-ingestion` | Hub data health |

Four dashboards report AI cost and token use:

| Dashboard | Data source |
| --- | --- |
| `ftk-codex` | Application Insights |
| `ftk-agent-framework` | Application Insights |
| `ftk-github-copilot` | Application Insights |
| `ftk-ai-foundry` | Azure Monitor metrics |

Success means a reader reaches a decision without exporting the data to a spreadsheet.

## Positioning

The dashboards read a FinOps hub. The hub normalizes cost data to FOCUS, so one
dashboard works across billing accounts, subscriptions, and providers without per
customer rework. The AI dashboards join per call telemetry to the same hub price sheet,
so token use and Azure cost carry one set of rates.

## Operating Context

- Readers open the dashboards in the Azure portal, under **Dashboard with Grafana** on
  the dashboard resource. Azure Managed Grafana can import the same JSON.
- Azure deploys each dashboard as `Microsoft.Dashboard/dashboards`. The content lives in
  the child resource `dashboardDefinitions/default`, in `properties.serializedData`.
- Azure overwrites `title` and `uid` in that content with the resource name. The portal
  heading follows the resource name, not the JSON.
- `src/templates/finops-workbooks/modules/dashboards.bicep` deploys all 12. It injects
  the `cluster` and `database` variables, and the `sub`, `rg`, and `res` variables when
  the caller passes `appInsightsResourceId`.
- The module reads the dashboards through symlinks in `modules/dashboards/`, because
  `Build-Toolkit` stages templates into `release/` and relative paths change there.
- Readers run the dashboards on a recurring cadence, not once. **[inferred]**

## Capabilities and Constraints

- An ARM template cannot exceed 4 MB. The built workbooks template is 3,199,152 bytes
  (3.051 MiB) with all 12 dashboards. This limit governs how much dashboard JSON can
  ship in one template.
- An ARM string expression cannot exceed 131,072 characters. The module patches the
  loaded object, not the serialized text, because the largest dashboards exceed it.
- The hub dashboards call `database('Ingestion').parse_resourceid` 78 times and
  `database('Ingestion').HubSettings` 17 times. The reader therefore needs permission on
  the internal ingestion database. This is a pre-existing toolkit pattern, not a
  dashboard defect.
- `ftk-codex` and `ftk-agent-framework` read hub prices through a cross-service `adx()`
  call. That call fails on Gov cloud, across tenants, and against a cluster behind
  Private Link or IP restrictions. A customer can deploy a valid hub these dashboards
  cannot query.
- The dashboards must not carry hardcoded prices, models, meters, tiers, or connection
  defaults. A stale rate produces a confidently wrong number.
- `ftk-github-copilot` reports token volume only. No rate source is confirmed, so it
  computes no cost.
- `ftk-ai-foundry` reads Azure Monitor metrics only. It has no log query, so it cannot
  join hub prices.
- Terminology follows FOCUS: `BilledCost`, `EffectiveCost`, `SubAccountName`. Hub
  extensions use an `x_` prefix. These names belong in queries, not in what the reader
  sees.

## Brand Commitments

The toolkit already defines its design language. Later design work uses these sources
rather than inventing a palette.

- `src/power-bi/FinOpsToolkitLight.json`, "Microsoft FinOps light theme":
  - Categorical sequence starts `#6f4bb2` (purple), `#0078d4` (blue), `#ef6950` (coral),
    `#3449aa`, `#00a2ad`.
  - Semantic colors: good `#57a300`, neutral `#db7500`, bad `#e00b1c`.
  - Diverging scale: minimum `#efedf8`, center `#ffca8a`, maximum `#8970c3`.
  - Type: Segoe UI, and Segoe UI Semibold for titles.
- `src/web/FinOpsToolkitTheme.ts` defines the brand ramp as purple, from `#030205` to
  `#DDD1ED`, with the brand weight near `#6444A0`.

This gap is now closed. All 12 dashboards share one color system. `DESIGN.md` records
the system, the contrast measurements, and the verification gates.

The system has two layers. Five hex tokens carry the brand accent and fixed emphasis,
and every token comes from a source above. Named Grafana semantic colors carry
conditional state, mostly in threshold steps and field overrides. This matches the
toolkit's own ADX dashboard, which ties color to a data condition and uses named colors
rather than custom hex.

The gap is kept here as product history, because it explains why the dashboards changed:
before the change, the 8 hub dashboards used the Grafana default blue `#3274D9`, the 4 AI
dashboards filled 28 of 28 stat tiles with green, and the two families disagreed with
each other.

## Evidence on Hand

- A live hub in the `finops-hubs-demo` resource group returns real data. The Data
  Explorer cluster is `https://trey-finops-hub.westus.kusto.windows.net` and the
  database is `Hub`.
- Real Application Insights telemetry exists for the AI dashboards, in
  `finops-hubs-demo-projec-resource-appinsights`. `ftk-codex` renders real per model
  token volume, cost per million tokens, and cache share from it.
- `src/workbooks/grafana/` holds the unmodified upstream dashboards. They are the
  baseline for measuring what this project changed.
- No customer names, no benchmarks, and no pricing claims exist. Later work must not
  invent them.
- GitHub Copilot rates are not in the hub price sheet, and no source is confirmed.

## Product Principles

1. **The reader is not an engineer.** Show money, trend, and exception. Keep schema
   names in the query, not on the panel.
2. **A number must be right or absent.** Prefer a stated gap over a computed guess. Never
   substitute a hardcoded rate for a missing one.
3. **One product, one language.** A reader moves between 12 dashboards in one session.
   The same idea keeps the same color, the same name, and the same panel shape.
4. **Color carries meaning.** Reserve semantic color for a state the reader must act on.
   A tile that is always green tells the reader nothing.
5. **Every dashboard ships through the template.** A dashboard that only works as a
   manual import is not deployable.

## Accessibility & Inclusion

No product-specific standard is confirmed. **[inferred]** Two needs follow from the
evidence: the audience includes executives reading on projected screens, and color alone
must not carry state, because the palette must survive both the Grafana light and dark
themes.
