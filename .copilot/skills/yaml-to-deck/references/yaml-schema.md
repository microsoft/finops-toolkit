# YAML schema

Every slide is one YAML file. Filename pattern: `NNN-<id>-<slug>.yaml` where `NNN` is a zero-padded order prefix that controls render order (file sort = slide order).

## The 9 fields

```yaml
id: '1'
order: 0
cluster: overview
asks_verbatim: []
title: 'Heading text'
content: '• Bullet 1<br/>• Bullet 2'
notes: 'Spoken narration.<br/><br/>Second paragraph.'
layout:
  kind: BULLETS
  addresses: []
  verdict: null
screens: null
```

| Field | Type | Required | Purpose |
|---|---|---|---|
| `id` | string | yes | Slide identifier. Quote it (so `P1.1.A`, `0.1`, `H.1` stay strings). |
| `order` | int | yes | Zero-based render order. Should match the filename's `NNN` prefix. |
| `cluster` | string | yes | Doc slug or section group. Used as a chyron / cluster label. |
| `asks_verbatim` | list | yes (may be `[]`) | MCAPS asks the slide addresses (V8 SRE deck only). General docs use `[]`. |
| `title` | string | yes | Slide title — becomes the slide's H1. Sentence case (Microsoft Style). |
| `content` | string | yes (may be `''`) | Slide body bullets, `<br/>`-separated, each prefixed with `• ` (U+2022). |
| `notes` | string | yes (may be `''`) | TTS voiceover prose. `<br/><br/>` between paragraphs. |
| `layout` | dict | yes | See "Layout block" below. |
| `screens` | string \| null | yes (may be `null`) | Asset directives (e.g. `image=foo.svg`) or `null`. Most slides are `null`. |

## Field details

### `id`

A short slide identifier. Always a string (use quotes in YAML so values like `0.1` and `P1.1.A` aren't parsed as floats or syntax errors).

| Convention | Example |
|---|---|
| Doc-derived (numeric scene) | `'1'`, `'2'`, `'3'` |
| V8 SRE deck cluster | `'P1.1.A'`, `'P1.1.B'`, `'P1.1.C'` |
| V8 SRE intro/index | `'0.1'`, `'0.2'`, `'0.3'`, `'0.4'` |
| V8 SRE honest cluster | `'H.1'`, `'H.2'` |
| V8 SRE close | `'Z.1'`, `'Z.2'`, `'Z.3'` |

### `order`

Zero-based scene order. The filename's `NNN` prefix should match (so file-sort order = render order).

```
slides/000-0.1-cover.yaml         → order: 0
slides/001-0.2-toc.yaml           → order: 1
slides/004-P1.1.A-ask.yaml        → order: 4
```

If `order` and the filename prefix disagree, the renderer trusts the filename prefix (file sort wins). The lint script flags the mismatch.

### `cluster`

A short label grouping related slides. Used:

- As a footer chyron on most layouts
- For per-cluster filtering when building partial decks (`build_yaml.py --part 1` selects clusters starting with `P1` etc.)
- To toggle V8 SRE-specific behaviors (e.g. honest-cluster slides skip the chyron)

Examples: `overview`, `get-started`, `P1.1`, `H`, `Z`.

### `asks_verbatim`

V8 SRE deck only. List of MCAPS-ask themes the slide is grounded in. Used for traceability — the `notes:` claims must trace to entries in this list.

Each entry is a dict with `num` (the ask number) and `theme` (verbatim text from the canonical asks memory note):

```yaml
asks_verbatim:
  - num: 7
    theme: "Customers want a single pane that shows quota, spend, and usage together."
  - num: 23
    theme: "Reps need a way to triage capacity issues without paging the platform team."
```

Empty `[]` for doc-derived slides and the V8 deck's intro/close slides.

Source of truth (V8 deck only):
`memory://work/mcaps/mcaps-internal-asks-finops-toolkit-azure-capacity-ai-cost-may-2026`

### `title`

The slide title. Sentence case. Plain text (no markdown). Should fit on one or two lines at the layout's title font size:

| Layout kind | Title char limit (rough) |
|---|---|
| `TITLE` | < 60 chars |
| `INDEX` | < 60 chars |
| `BULLETS`, `TABLE`, `CODE`, `CALLOUT` | < 80 chars |
| `OUTRO` | < 50 chars |

The lint script warns when titles exceed these limits (font auto-shrink kicks in around 50 chars but isn't enough for `INDEX`).

### `content`

Slide body. `<br/>`-separated bullets. Each bullet starts with `• ` (U+2022, not the ASCII `*` or `-`).

```yaml
content: '• First bullet<br/>• Second bullet<br/>• Third bullet'
```

Multi-line YAML (using `|` block scalar) works too:

```yaml
content: |-
  • First bullet<br/>• Second bullet<br/>• Third bullet
```

For `TABLE` and `CODE` layouts, `content` is summary text — the slide renders the actual table or code from the upstream markdown. For doc-to-yaml output, `content` is regenerated from the bullets in the source section.

### `notes`

★ This is the actual TTS voiceover, not a presenter prompt.

`<br/><br/>` between paragraphs (becomes SSML `<break time="1300ms" />` in the transcript file). Plain prose otherwise — no markdown, no inline citations, no source links.

Microsoft Voice rules apply — see `voice-spec.md`. Linter checks for the most common violations.

For V8 SRE deck slides, every claim should trace to an entry in `asks_verbatim:`.

A "slide-only" slide (table or code dominates, no spoken narration desired) should have `notes:` set to:

```yaml
notes: '(slide-only — no narration)'
```

The transcript writer detects this marker and produces a marker file instead of a transcript.

### `layout`

A dict with three keys:

```yaml
layout:
  kind: BULLETS         # required
  addresses: []         # required (V8 SRE deck uses; general empty)
  verdict: null         # required (V8 SRE honest cluster uses; general null)
```

#### `layout.kind`

Drives the renderer. See `layout-kinds.md` for the full kind table:

- General kinds (any deck): `TITLE`, `BULLETS`, `TABLE`, `CODE`, `CALLOUT`, `OUTRO`
- V8 SRE-specific kinds: `INDEX`, `ASK_A`, `ASK_B`, `ASK_C`

#### `layout.addresses`

V8 SRE deck only. List of MCAPS ask numbers (ints) the slide directly addresses. Renders as a pill chip on `ASK_A/B/C` slides:

```yaml
layout:
  kind: ASK_A
  addresses: [7, 23]
```

Empty for doc-derived slides.

#### `layout.verdict`

V8 SRE honest cluster only. One of `green` / `yellow` / `red`. Renders a colored chip on the slide:

| Verdict | Meaning | Chip color |
|---|---|---|
| `green` | We ship this; works as advertised | green |
| `yellow` | We ship this; caveats apply | amber |
| `red` | We don't ship this yet; gap | red |

`null` for non-honest slides.

### `screens`

Asset directives — typically `null`. When non-null, drives image / chart / screenshot embedding. Format:

```yaml
screens: 'image=foo.svg'
screens: 'chart=charts/cost-by-service.png'
```

The renderer maps the directive to a file under the project's `assets/` or `charts/` directory. Most general-mode slides leave this `null`.

## Edge cases and gotchas

### Quoting `id`

YAML by default parses `0.1` as a float. Always quote `id` values:

```yaml
id: '0.1'    # correct
id: 0.1      # WRONG — becomes float, breaks filename matching
```

### Bullet character

Use `• ` (U+2022 + space). The renderer expects this exact prefix.

```yaml
content: '• Right'             # correct
content: '* Wrong'             # ASCII asterisk — renderer treats as plain text
content: '- Wrong'             # ASCII dash — same
content: '•Right_no_space'     # WRONG — needs space after •
```

### Paragraph breaks in `notes:`

Use `<br/><br/>` (two `<br/>` tags). Single `<br/>` is treated as a soft wrap (joined with `. `).

```yaml
notes: 'Para one.<br/><br/>Para two.'         # correct: real paragraph break
notes: 'Para one.<br/>Para two.'              # WRONG: becomes "Para one. Para two."
```

### Empty fields

Required keys must exist with at least the empty value:

```yaml
asks_verbatim: []         # not omitted
content: ''               # not omitted (even if no body bullets)
notes: ''                 # not omitted (even for slide-only — use marker text)
screens: null             # not omitted
```

### Filename / `id` / `order` triplet

The lint script enforces:

- Filename starts with zero-padded `order`: `004-` for `order: 4`
- Filename contains `id` after the order: `004-P1.1.A-` for `id: 'P1.1.A'`
- The slug (the part after the id) is descriptive but free-form

Example: `004-P1.1.A-ask.yaml` is valid for `id: 'P1.1.A'` and `order: 4`.
