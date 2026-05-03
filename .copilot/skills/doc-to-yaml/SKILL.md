---
name: doc-to-yaml
description: Convert FinOps Toolkit Microsoft Learn documentation into per-slide YAML files that the narrated-deck and release-deck builders consume. Use this skill whenever the user wants to turn one or more docs-mslearn/**.md files into TTS-ready slide source, prep documentation for narrated training videos, generate slide YAML from product documentation, normalize doc prose into Microsoft spoken-voice form, or scaffold deck content from existing markdown. Fans out one subagent per source doc; each subagent applies the canonical Microsoft Style Guide spoken-voice rules (anaphora, article insertion, sentence splitting, source-citation removal) without paraphrasing. Output is per-slide YAML in the same schema release-deck/build_yaml.py uses, so files can be consumed by either narrated-deck or the SRE release deck builder. Pair with narrated-deck to produce the actual PPTX + transcripts + audio.
---

# doc-to-yaml

Convert MS Learn markdown into a directory of per-slide YAML files that the deck builders consume.

| Input | Output |
|---|---|
| `docs-mslearn/**/*.md` (one or many) | `slides/NNN-<slug>.yaml` (one file per slide) |

The YAML schema matches `src/templates/sre-agent/training/release-deck/slides/*.yaml` field-for-field (`id`, `order`, `cluster`, `asks_verbatim`, `title`, `content`, `notes`, `layout {kind, addresses, verdict}`, `screens`). Files emitted here are consumed by `narrated-deck`.

**Note on release-deck compatibility:** release-deck's `build_yaml.py` knows a custom set of layout kinds (`TITLE`, `BULLETS`, `ASK_A`, `ASK_B`, `ASK_C`, `INDEX`) tuned for the SRE training deck. doc-to-yaml emits a different set (`TITLE`, `BULLETS`, `TABLE`, `CODE`, `CALLOUT`, `OUTRO`) sized for general MS Learn docs. The field schema is identical, but the `layout.kind` values differ — so files from doc-to-yaml are consumed by `narrated-deck`, not `build_yaml.py`. Hand-curated SRE deck slides remain release-deck's responsibility.

## When this skill triggers

Any of:
- "Turn this doc into slide YAML / per-slide YAML / deck source"
- "Convert [doc] into TTS-ready slides"
- "Prep [doc] for narrated-deck"
- "Generate slide YAML from [doc-path]"
- "Apply Microsoft spoken voice to [doc]"
- "Make YAML slides from `docs-mslearn/...`"

## Pipeline

For each source doc, the skill spawns one subagent. Each subagent runs the per-doc pipeline:

```
extract scenes → normalize voice (mechanical, preserve-strict) →
emit per-slide YAML files in slides/
```

The orchestrator collates results and reports per-doc completion.

### Per-doc pipeline

1. **Extract scenes** (`scripts/extract_scenes.py`)
   - Parse the .md into one scene per H2 (and per H3 in reference docs with 3+ H3 children)
   - Drop `Give feedback` / `Related content` / `Next steps` / `Learn more` sections — they are navigation, not training
   - Classify each scene's layout: `TITLE` / `BULLETS` / `TABLE` / `CODE` / `CALLOUT` / `OUTRO`

2. **Normalize voice** (`scripts/normalize_text.py`) — strict, mechanical only
   - First-mention article: `FinOps toolkit SRE Agent` → `the FinOps toolkit SRE Agent` when used as sentence subject
   - Anaphora: subsequent mentions → `the agent` / `It`
   - Split semicolon run-ons into separate sentences
   - Strip inline source-citation parentheticals like `([source YAML](path))`
   - **Never paraphrase**, **never invent facts**, **never reorder content**
   - Read `references/voice-spec.md` for the full rule set with Microsoft Style Guide references

3. **Emit per-slide YAML** (`scripts/emit_yaml.py`)
   - One file per scene at `slides/NNN-<id>-<slug>.yaml`
   - Schema documented in `references/yaml-schema.md`
   - Filename pattern matches release-deck's so build_yaml.py consumes them as-is

## Subagent fan-out

For multi-doc batches, one subagent per source doc — high parallelism, each subagent's context stays small. The orchestrator (this skill's calling agent) is responsible for:

- Spawning the subagents
- Collecting their output paths
- Optionally merging/renumbering slide files if the user wants one combined deck

For a single doc, the calling agent runs the pipeline inline (no subagent overhead).

## Output layout

```
<out-dir>/
└── <doc-slug>/
    └── slides/
        ├── 000-Intro-finops-toolkit-sre-agent.yaml
        ├── 001-What-you-get.yaml
        ├── 002-Architecture-overview.yaml
        ├── ...
        └── 005-Closing.yaml
```

The `slides/` subdirectory mirrors release-deck's layout. To run downstream builds:

```
narrated-deck consume <out-dir>/<doc-slug>/slides/   # → PPTX + transcripts
# OR
cd src/templates/sre-agent/training/release-deck
SLIDES_DIR=<out-dir>/<doc-slug>/slides python build_yaml.py
```

## YAML schema (release-deck-compatible)

Every emitted file has these top-level keys:

```yaml
id: '0.1'                      # scene id (stringified — matches release-deck convention)
order: 0                       # zero-based scene order
cluster: Intro                 # doc slug or section group; used as chyron label
asks_verbatim: []              # always empty for doc-derived slides (release-deck uses for MCAPS asks)
title: 'Heading text here'     # the scene heading (becomes slide title)
content: '• Bullet 1<br/>• Bullet 2'  # slide body bullets, <br/>-separated
notes: 'Spoken narration here.<br/><br/>Second paragraph.'  # TTS-ready prose
layout:
  kind: BULLETS                # TITLE | BULLETS | TABLE | CODE | CALLOUT | OUTRO
  addresses: []                # release-deck-specific (MCAPS ask numbers); empty here
  verdict: null                # release-deck-specific (green/yellow/red); null here
screens: null                  # asset directives or null
```

Read `references/yaml-schema.md` for the full per-field semantics and `references/output-formats.md` for downstream consumption.

## Voice rules

The normalizer applies mechanical Microsoft Style Guide rules. It does not invent, paraphrase, or rewrite.

Read `references/voice-spec.md` for the full rule list with Microsoft Learn references. Core rules:

- **Anaphora** ([learn.microsoft.com/graph/onenote-branding](https://learn.microsoft.com/graph/onenote-branding)): first mention full name, subsequent uses short form
- **Brevity** ([style-guide top 10 #5](https://learn.microsoft.com/style-guide/top-10-tips-style-voice)): split semicolon run-ons
- **Sentence-style headings** ([style-guide capitalization](https://learn.microsoft.com/style-guide/capitalization))
- **Include the small words** ([Microsoft Learn quick start](https://learn.microsoft.com/contribute/content/style-quick-start)): keep articles for machine-translation friendliness

## Constraints

- **Read-only on source docs.** Never edits `docs-mslearn/`.
- **No paraphrasing.** The normalizer makes only mechanical, rule-based changes. If the source claims wrong numbers, the YAML carries wrong numbers.
- **No section reordering.** Scene order matches H2 order (then H3 within H2).
- **No new fields.** YAML schema matches release-deck exactly; downstream tools depend on it.
