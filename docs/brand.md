---
layout: default
title: Brand and naming
nav_order: 90
description: 'Brand colors, typography, naming, voice, and product-relationship rules for FinOps toolkit contributors and partners.'
permalink: /brand
---

<span class="fs-9 d-block mb-4">Brand and naming</span>
How the FinOps toolkit looks, sounds, and refers to other Microsoft products.
{: .fs-6 .fw-300 }

This page is the source of truth for FinOps toolkit visual identity, naming conventions, and product-relationship language. It applies to anything the FinOps toolkit ships or publishes — Microsoft Learn modules, training decks, GitHub README files, Power BI reports, blog posts, demo videos, and partner submissions to the toolkit.

When this page conflicts with another internal Microsoft brand asset, the other asset wins. When it conflicts with [Microsoft Trademark and Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/), Microsoft's guidelines win.

<details open markdown="block">
  <summary>
    On this page
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

---

## Visual identity

### Color palette

The FinOps toolkit uses the Microsoft FinOps light theme already shipped with every Power BI report under `src/power-bi/**/StaticResources/RegisteredResources/Microsoft_FinOps_light_theme*.json`. Use the same hex values in any new asset.

**Primary data colors** (use these for charts, accents, and category fills, in this order for the first 8 categories):

| # | Hex | Where to use |
|---|---|---|
| 1 | `#6F4BB2` | Primary accent — first category, hero highlights |
| 2 | `#0078D4` | Microsoft blue — links, secondary accent |
| 3 | `#EF6950` | Warm accent — anomalies, attention markers |
| 4 | `#3449AA` | Deep blue — supporting category |
| 5 | `#00A2AD` | Teal — supporting category |
| 6 | `#733569` | Plum — supporting category |
| 7 | `#E3008C` | Magenta — supporting category |
| 8 | `#335C50` | Forest — supporting category |

The full 200+ color sequence in `Microsoft_FinOps_light_theme*.json` is meant for very high-cardinality Power BI visuals. For decks and Learn pages, stick to the eight above.

**Neutrals** (text, backgrounds, surfaces):

| Token | Hex | Use |
|---|---|---|
| Ink | `#1B1B1F` | Primary body text |
| Ink subdued | `#424242` | Secondary text, captions |
| Ink quiet | `#595959` | Tertiary text, footnotes, disabled |
| Surface | `#FFFFFF` | Default page and slide background |
| Surface subdued | `#F2F4FA` | Table stripes, callout backgrounds |
| Surface deep | `#10183A` | Hero panels, chyrons, title bars (use white text on top) |

### Typography

Inherit Microsoft's standard product fonts. The Power BI theme already specifies these.

| Role | Font | Fallback chain |
|---|---|---|
| Headings, titles | Segoe UI Semibold | `'Segoe UI Semibold', wf_segoe-ui_semibold, helvetica, arial, sans-serif` |
| Body, captions | Segoe UI | `'Segoe UI', wf_segoe-ui_normal, helvetica, arial, sans-serif` |
| Code, identifiers | Cascadia Mono | `'Cascadia Mono', Consolas, 'Courier New', monospace` |

Do not introduce display fonts, script fonts, or non-Microsoft typefaces. Microsoft Learn handles its own font rendering — do not specify fonts in `.md` source.

### Logos and lockups

The FinOps toolkit does not ship a standalone logo. Use the Microsoft master brand or the Microsoft Azure brand mark, per [Microsoft Trademark and Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/).

Do not create custom logo lockups that combine "FinOps toolkit" with another Microsoft product mark. Do not adapt the official Azure or Microsoft logos.

### Slide and report templates

| Asset | Where it lives | When to use |
|---|---|---|
| Branded PowerPoint template | [`yaml-to-deck/assets/source-template.pptx`](https://github.com/microsoft/finops-toolkit/tree/main/.copilot/skills/yaml-to-deck/assets) | All training decks and customer-facing presentations |
| Power BI theme | `src/power-bi/**/Microsoft_FinOps_light_theme*.json` | All Power BI reports shipped with the toolkit |

If you need a layout the template doesn't have, extend it. Don't fork it into a new template.

---

## Naming

### What things are called

The FinOps toolkit is a Microsoft-owned collection of components. Each component has a stable name. Use these forms exactly:

| Concept | Correct name | Avoid |
|---|---|---|
| The whole project | FinOps toolkit | FinOps Toolkit (capital T), FTK in customer-facing prose |
| Hub data platform | FinOps hubs | FinOps Hub, FinOps hub (singular when you mean the product) |
| Power BI surface | FinOps toolkit Power BI reports | FinOps Power BI |
| PowerShell module | FinOps toolkit for PowerShell | FinOpsToolkit module |
| Open data | FinOps toolkit open data | FinOps open data |
| Bicep modules | FinOps toolkit Bicep modules | FinOps Bicep |
| The acronym | FTK (only in code, file names, internal short references — never in marketing or Learn body text) | — |

Use **title case** for proper nouns ("FinOps", "Microsoft", "Azure", "Kusto"). Use **sentence case** for everything else, including page titles and slide titles ("Get started with FinOps hubs", not "Get Started with FinOps Hubs"). This matches the [Microsoft Style Guide](https://learn.microsoft.com/style-guide/capitalization).

### What things are not called

Do not coin new product names by combining the FinOps toolkit name with another Microsoft product trademark. The FinOps toolkit configures, deploys, or extends other Microsoft products — it does not rebrand them.

| Don't write | Write instead |
|---|---|
| FinOps toolkit SRE Agent | Azure SRE Agent (when you mean the Microsoft product) — or describe the toolkit's role: "the FinOps toolkit deploys Azure SRE Agent…" |
| FinOps toolkit Cost Management | Microsoft Cost Management (the product) — or "the FinOps toolkit's Cost Management exports configuration" |
| FinOps toolkit Power BI service | Power BI service (the product) — or "FinOps toolkit Power BI reports" |

This is the most common branding mistake new contributors make. The rule: **you cannot put a Microsoft product trademark into the name of a FinOps toolkit component.** You can only describe what the toolkit does with that product.

### File and directory names

Use lowercase, hyphen-separated slugs for everything in the repo: `finops-hubs`, `sre-agent`, `cost-management-connector`. The toolkit name in slugs is `finops-toolkit`. Don't use camelCase or PascalCase except where required by the surrounding ecosystem (e.g., PowerShell cmdlet names, Bicep symbols).

### URLs and references

When linking to a Microsoft product page, use the bare product name as the link text: `[Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview)`. When linking to FinOps toolkit pages about that product, include "FinOps toolkit" in the link text to disambiguate: `[Azure SRE Agent in the FinOps toolkit](https://learn.microsoft.com/cloud-computing/finops/toolkit/sre-agent/overview)`.

Reusing identical link text for two different destinations confuses readers and screen readers. Always disambiguate.

---

## Voice

### Subject framing — most important rule

The FinOps toolkit is a configuration layer. The Microsoft products it deploys (Azure SRE Agent, Microsoft Cost Management, Azure Data Explorer, Power BI, etc.) are runtimes. **Keep the two distinct in every sentence.**

Use the toolkit, the deployment, or the template as the subject when describing toolkit-specific behavior:

| Don't write (over-attributes to the Microsoft product) | Write instead (anchors to the toolkit) |
|---|---|
| "Azure SRE Agent includes 21 Kusto tools." | "The FinOps toolkit deployment configures Azure SRE Agent with 21 Kusto tools." |
| "Azure SRE Agent uses scheduled tasks to run weekly cost reviews." | "The FinOps toolkit ships scheduled tasks that run weekly cost reviews on Azure SRE Agent." |
| "Microsoft Cost Management exports billing data to FinOps hubs." | "The FinOps toolkit configures Microsoft Cost Management exports and lands the data in FinOps hubs." |
| "Power BI shows cost anomalies." | "FinOps toolkit Power BI reports show cost anomalies on top of the Power BI service." |

The reverse direction matters too — don't attribute Microsoft product capabilities to the toolkit:

| Don't write | Write instead |
|---|---|
| "FinOps toolkit hubs run KQL queries." | "FinOps hubs use Azure Data Explorer to run KQL queries." (ADX is the runtime; the toolkit configures the schema, functions, and ingestion.) |
| "FinOps toolkit Power BI renders the dashboard." | "Power BI renders the FinOps toolkit reports." |

### Microsoft Voice basics

The toolkit follows the [Microsoft Style Guide](https://learn.microsoft.com/style-guide/welcome/). Critical rules:

- **Use sentence-style capitalization** for headings, titles, slide titles, table headers, and bullet labels. Reserve title case for proper nouns.
- **Lead with verbs.** Avoid "There is" / "There are" openers.
- **Include the small words.** "Use the agent to deploy" reads better than "Use agent to deploy" — keep articles for clarity and machine-translation friendliness.
- **Anaphora.** First mention spells out the full name; later references use a short form. After "Azure SRE Agent", subsequent references can use "the agent" if the antecedent is clear within the same paragraph or visible scope.
- **One sentence, one idea.** Split semicolon run-ons.
- **Don't prescribe action.** Say what something does, not what the reader must do. "The agent runs daily" is better than "You should run the agent daily."

### Forbidden phrases

The lint pipeline at [`yaml-to-deck/scripts/lint.py`](https://github.com/microsoft/finops-toolkit/blob/main/.copilot/skills/yaml-to-deck/scripts/lint.py) flags these in any deck source:

- Marketing fluff: "best-in-class", "world-class", "game-changer", "revolutionary"
- Marketing absolutes: "this solves", "the entire answer"
- Internal jargon in customer prose: "MCAPS ask #", case IDs, "FastTrack engagement", "field research", "evidence pack", "corpus"
- Prescriptive openers: "you should", "you must", "Monday move"
- URLs in spoken narration: "see https://…" — write the destination as a link, don't read the URL aloud

If the lint flags a sentence, fix the sentence — don't disable the lint.

---

## Product-relationship rules

This section covers the cases where a brand-aware reading would catch a problem the lint won't.

### Page titles for product reference docs

When a FinOps toolkit page documents a Microsoft product the toolkit deploys (Azure SRE Agent, Microsoft Cost Management, Azure Data Explorer), the H1 and frontmatter title MUST NOT duplicate the official Microsoft product page title on Microsoft Learn. Use one of these disambiguation patterns based on doc type:

| Doc type | Pattern | Example |
|---|---|---|
| Concept / overview | `<Product> in the FinOps toolkit` | `Azure SRE Agent in the FinOps toolkit` |
| How-to / tutorial | `<Verb> <Product> with the FinOps toolkit` | `Deploy Azure SRE Agent with the FinOps toolkit` |
| Quickstart / getting started | `Get started with the FinOps toolkit on <Product>` | `Get started with the FinOps toolkit on Azure SRE Agent` |
| Reference (template, parameters) | `<Topic> reference (FinOps toolkit)` or `<Topic> (Azure SRE Agent in the FinOps toolkit)` | `Azure SRE Agent template reference (FinOps toolkit)` |
| Troubleshooting | `Troubleshoot <Product> deployments from the FinOps toolkit` | `Troubleshoot Azure SRE Agent deployments from the FinOps toolkit` |
| Subtopic of a product reference | `<Subtopic> (Azure SRE Agent in the FinOps toolkit)` | `Scheduled tasks (Azure SRE Agent in the FinOps toolkit)` |

If the doc does not document a Microsoft product directly (e.g., generic Kusto or Python tool reference whose title is a class name), use the bare title and let the parent page disambiguate.

### Anaphora short form

After the first body mention of a Microsoft product, subsequent references in the same page can use a short form:

| First mention (full) | Short form (subsequent in same page) |
|---|---|
| Azure SRE Agent | the agent |
| Microsoft Cost Management | Cost Management |
| Azure Data Explorer | the cluster (when referring to the user's specific instance) or Azure Data Explorer |

The short form must be unambiguous in scope. If two competing antecedents exist (e.g., the agent product vs a subagent), spell out the full name.

### When the toolkit deploys a Microsoft product

Pattern: the FinOps toolkit ships an `azd up`-able template plus configuration for a Microsoft Azure product (Azure SRE Agent, Azure Data Explorer, Microsoft Cost Management exports).

Rules:

1. The first mention of the Microsoft product on each page links to the official Microsoft Learn page for that product.
2. The page title and H1 follow the disambiguation patterns above.
3. When listing components the toolkit ships (subagents, scheduled tasks, knowledge files, Bicep modules, Kusto functions), the subject of the sentence is the toolkit or the template — not the Microsoft product.
4. When listing platform capabilities the Microsoft product provides (managed identity, RBAC, scheduled task runtime, query engine), the subject is the Microsoft product.

### When the toolkit reads from or writes to a Microsoft product

Pattern: the toolkit pushes data into Power BI, queries Microsoft Cost Management, ingests from FOCUS exports.

Rules:

1. Name both sides of the integration in the first mention. "FinOps toolkit Power BI reports read from FinOps hubs" — both the toolkit-owned thing and the Microsoft-owned thing.
2. Don't anthropomorphize one side as "the toolkit" if it's really a Microsoft product doing the work.

### When the toolkit recommends a Microsoft FinOps Framework practice

Reference the practice by its official name from the [FinOps Framework](https://www.finops.org/framework/). The toolkit implements a subset; don't claim to ship the framework.

Use Crawl/Walk/Run when discussing maturity. Use the official capability names (e.g., "Managing commitment-based discounts", not "reservation management").

---

## Trademark notice

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark and Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.

External contributors: when in doubt, prefer descriptive language ("works with Azure SRE Agent") over derivative naming ("FinOps Azure SRE Agent"). The descriptive form is always brand-safe; the derivative form requires CELA review.

---

## Changelog

| Date | Change |
|---|---|
| 2026-05-04 | Initial publication. Codified naming, voice, and product-relationship rules. Color palette and typography pulled from existing Power BI theme and PowerPoint template. |
| 2026-05-04 | Added the page-title disambiguation pattern table and the anaphora short-form table. Both decisions came out of applying the brand to the `docs-mslearn/toolkit/sre-agent/` doc set. |
