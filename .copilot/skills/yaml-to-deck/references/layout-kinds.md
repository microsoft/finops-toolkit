# Layout kinds

`layout.kind` selects the renderer. Two kind families:

- **General** kinds — work in any deck. Rendered by `scripts/build_pptx.py` (this skill).
- **V8 SRE deck** kinds — work only with the V8 SRE Agent release training deck. Rendered by the project's `build_yaml.py` + `build.py`.

Both renderers share the YAML schema; only the layout kinds differ.

---

## General kinds

### `TITLE`

Hero / cover slide. Used for the deck cover and any module-opening slide.

| Field | What it carries |
|---|---|
| `title` | Big headline (H1) |
| `content` | Up to ~3 subtitle bullets (rendered smaller, below H1) |
| `notes` | Brief intro — 1-3 sentences |

Rendering:
- H1 in 44pt, brand purple (#4E2E7A)
- Subtitle bullets in 18pt, charcoal
- Background: brand purple gradient
- FinOps Toolkit hexagon logo bottom-right

When to use: Deck cover, module openers, section dividers that need impact.

Example: `assets/templates/title.yaml`.

---

### `BULLETS`

Standard heading + body bullets. The most common layout.

| Field | What it carries |
|---|---|
| `title` | Slide title |
| `content` | 3–7 bullets, `<br/>`-separated, each prefixed with `• ` |
| `notes` | TTS narration — explains why the bullets matter, adds context |

Rendering:
- Title in 32pt
- Bullets in 18pt, ~1.4 line spacing
- Cluster chyron in footer
- White background

Sizing rules:
- 3–5 bullets: comfortable
- 6–7 bullets: tight but legible
- 8+ bullets: split into two slides

Example: `assets/templates/bullets.yaml`.

---

### `TABLE`

Heading + rendered PPTX table. The table data comes from the source markdown (`raw_markdown` field synthesized by `scripts/consume.py`). When YAML is hand-authored without a markdown table source, the slide falls back to a heading-only layout.

| Field | What it carries |
|---|---|
| `title` | Slide title |
| `content` | Summary line for the table (what it shows) |
| `notes` | Often `(slide-only — no narration)` for table-dominated slides |

Rendering:
- Title in 28pt
- Table fills the body area
- Header row in brand purple, body rows alternating gray/white
- Cluster chyron in footer

When to use: Any time data is a real table (rows × columns). Examples: feature comparison, pricing tiers, workflow steps.

Example: `assets/templates/table.yaml`.

---

### `CODE`

Heading + monospace code block.

| Field | What it carries |
|---|---|
| `title` | Slide title |
| `content` | Summary line for the code (what it does) |
| `notes` | Brief explanation, or `(slide-only — no narration)` |

Rendering:
- Title in 28pt
- Code in Consolas / Cascadia Mono, 14pt, charcoal-on-light-gray
- Cluster chyron in footer

When to use: CLI examples, YAML / JSON snippets, short commands.

Long code (>20 lines) renders past slide bottom. Trim or split.

Example: `assets/templates/code.yaml`.

---

### `CALLOUT`

Section header with a large pull quote.

| Field | What it carries |
|---|---|
| `title` | Section title (small, top) |
| `content` | The pull quote (large, centered) — single line is best |
| `notes` | Brief setup for the quote |

Rendering:
- Title in 16pt, charcoal, top-left
- Pull quote in 36pt, brand purple, centered
- White background

When to use: Section transitions, customer quotes, key takeaways that deserve a slide of their own.

Example: `assets/templates/callout.yaml`.

---

### `OUTRO`

Closing slide. Renders the `--next` flag passed to `scripts/consume.py` as "Coming up next: …".

| Field | What it carries |
|---|---|
| `title` | "Thanks" or similar |
| `content` | Optional: contact / link |
| `notes` | Closing narration |

Rendering:
- Title in 44pt, brand purple
- "Coming up next: <next>" in 24pt, charcoal
- Background: brand purple gradient
- FinOps Toolkit hexagon logo

When to use: Last slide of any module.

Example: `assets/templates/outro.yaml`.

---

## V8 SRE-specific kinds

These kinds work only with the V8 SRE Agent release training deck under `src/templates/sre-agent/training/release-deck/`. The renderer is `build_yaml.py` (project-local).

To create a new slide using these kinds: copy a sibling slide from `src/templates/sre-agent/training/release-deck/slides/` and edit. Don't author from scratch — these layouts have project-specific conventions.

### `INDEX`

Multi-column table of contents.

- Used for slides `0.2`, `0.3`, `0.4`, `2.0.2`
- `content` is structured as a flat list of bullets representing the TOC entries
- Renderer column-wraps based on count
- Title should be < 60 chars (or it overlaps the body)

### `ASK_A` (ASK)

The ASK slide of an MCAPS cluster. Each cluster (`P1.1`, `P1.2`, … `H.1`–`H.5`) opens with one of these.

- `content` carries the verbatim ASK pull-quote
- `layout.addresses: [N1, N2, ...]` lists the MCAPS ask numbers covered
- Attribution line ("— ICM-25-08923, FastTrack engagement, May 2025") rendered below the quote
- Slide background tinted with cluster color

### `ASK_B` (SHOW)

The SHOW slide of an MCAPS cluster — the visual evidence.

- Left half: 3–6 bullets explaining the ask (from `content`)
- Right half: chart or screenshot (from `screens:` directive)
- `screens: 'chart=charts/foo.png'` is required
- Speaker notes explain what the chart shows and why it matters

### `ASK_C` (TELL)

The TELL slide of an MCAPS cluster — what we ship.

- Left half: 3–6 bullets describing the offer (from `content`)
- Right half: "Monday move" callout (Project rules NOTE: prescriptive language is banned in this deck — most ASK_C slides have an empty Monday-move section since the rule was tightened)
- `layout.addresses: [N1, N2]` carries forward from `ASK_A` of the same cluster

---

## Decision tree: which kind?

Start with the question: **what's the role of this slide?**

```
Is it a hero / cover / opener?               → TITLE
Does the body need a real table?             → TABLE
Does the body need a code / CLI block?       → CODE
Does the body need ONE big quote/statement?  → CALLOUT
Is it the last slide of the module?          → OUTRO
Anything else with bullet content?           → BULLETS
```

For V8 SRE deck slides, the kind is determined by the cluster pattern:

```
Cluster intro / TOC?               → INDEX
First slide of a P1.x or P2.x?     → ASK_A
Second slide of a P1.x or P2.x?    → ASK_B (SHOW)
Third slide of a P1.x or P2.x?     → ASK_C (TELL)
Honest cluster (H.1–H.5)?          → BULLETS with verdict: green/yellow/red
Close (Z.1–Z.3)?                   → BULLETS or OUTRO
```

---

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Wrong kind on a TOC slide | Bullets render too small | Use `INDEX` (or `BULLETS` with fewer items) |
| `TITLE` with 6 bullets | Subtitle area overflows | Move bullets to a follow-up `BULLETS` slide |
| `CODE` with > 20 lines | Code spills off bottom | Trim or split |
| `TABLE` with no `raw_markdown` | Renders heading-only | Hand-author table data into `raw_markdown`, or use `BULLETS` |
| `ASK_A` without `addresses:` | Lint warns; pill chip is empty | Add MCAPS ask numbers |
| `CALLOUT` with multi-line content | Quote wraps awkwardly | Trim to one strong line |

The lint script (`scripts/lint.py`) catches most of these.
