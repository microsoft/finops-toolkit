---
name: narrated-deck
description: Consume per-slide YAML files (output of doc-to-yaml or release-deck) and produce a branded FinOps Toolkit PowerPoint deck plus TTS-ready transcript files. Use this skill whenever you have a directory of slide YAML files and want to turn them into a narrated training video deck, generate transcripts for downstream text-to-speech, build the PPTX from a YAML scene plan, or produce the final slide assets in the FinOps Toolkit visual style. Typically chained after doc-to-yaml, which produces the YAML from MS Learn docs. Outputs feed text-to-speech (per-scene .txt → .mp3), gpt-image-2 (optional alternate slide backgrounds), music, sound-effects, and ffmpeg for full video assembly.
---

# narrated-deck

Consume a directory of per-slide YAML files and produce the narrated-video asset set.

| Input | Output |
|---|---|
| `slides/*.yaml` (release-deck schema) | `slides.pptx` (FinOps Toolkit branded) |
| | `transcripts/scene_NN_<slug>.txt` (TTS-ready, one per scene) |
| | `scenes.json` (combined scene index for downstream skills) |

This skill is the second half of the doc-to-video pipeline:

```
docs-mslearn/*.md
   ↓ doc-to-yaml          (extract scenes, normalize voice, emit YAML)
slides/*.yaml
   ↓ narrated-deck        (this skill: build PPTX + write TTS transcripts)
slides.pptx + transcripts/
   ↓ text-to-speech       (each .txt → .mp3 via ElevenLabs / Azure)
   ↓ gpt-image-2          (optional: replace slide backgrounds with brand art)
   ↓ music + sound-effects (background bed + transitions)
   ↓ ffmpeg               (compose PPTX-rendered PNGs + audio → MP4)
final video
```

## When this skill triggers

Any of:
- "Build the deck from this YAML"
- "Consume the YAML slides into a PPTX"
- "Make the PowerPoint from `slides/`"
- "Generate transcripts and PPTX from doc-to-yaml output"
- "Render the narrated deck"

## Usage

```
narrated-deck consume <slides_dir> --output <out_dir> [--next "Next module title"]
```

`<slides_dir>` is a directory containing `*.yaml` files in release-deck per-slide format. `<out_dir>` will receive `slides.pptx`, `transcripts/`, and `scenes.json`.

## YAML schema (release-deck-compatible)

Every input file has these keys:

```yaml
id: '1'
order: 0
cluster: overview
asks_verbatim: []
title: 'Heading text'
content: '• Bullet 1<br/>• Bullet 2'
notes: 'Spoken narration. Already normalized by upstream.<br/><br/>Second paragraph.'
layout:
  kind: BULLETS    # TITLE | BULLETS | TABLE | CODE | CALLOUT | OUTRO
  addresses: []    # release-deck-only (MCAPS asks); ignored here
  verdict: null    # release-deck-only; ignored here
screens: null      # asset directives or null
```

The skill reads files in filename order. Each becomes one slide. Layout choice drives the renderer:

| Layout | Renderer |
|---|---|
| `TITLE` | Hero slide with H1 (from `title`) + subtitle (first sentence of `notes`) |
| `BULLETS` | Standard slide with `title` + `content` bullets |
| `TABLE` | Standard slide with `title` + bullets (TABLE layouts work best when paired with hand-edited YAML carrying actual table data) |
| `CODE` | Standard slide with `title` + monospace block |
| `CALLOUT` | Section header with pull-quote |
| `OUTRO` | Closing slide (uses `--next` flag for "Coming up next" copy) |

Speaker notes pane is populated from the `notes` field verbatim — assumes upstream (doc-to-yaml) already applied the Microsoft spoken-voice rules.

## Brand identity

Slides inherit the FinOps Toolkit master template bundled at `assets/source-template-clean.pptx`:
- Purple gradient (`#7B33C0` → `#4E2E7A`)
- FinOps Toolkit hexagon logo
- Microsoft Learn typography

The clean template is generated from the original release-deck `source-template.pptx` by `scripts/prepare_template.py`, which strips orphan slide parts that would otherwise corrupt the output PPTX (causing PowerPoint's "found a problem with content" repair prompt).

## Output layout

```
<out_dir>/
├── slides.pptx                    ← branded editable deck
├── scenes.json                    ← combined scene index
└── transcripts/
    ├── scene_01_intro.txt         ← TTS-ready, with <break time="1300ms" /> tags
    ├── scene_02_what_you_get.txt  ← (slide-only marker if narration_only=true)
    └── ...
```

## Transcripts

One file per scene at `transcripts/scene_NN_<slug>.txt`. Format:

- Prose-bearing scenes: the YAML `notes` field with `<break time="1300ms" />` between paragraphs
- Slide-only scenes (table/code-dominated, no narration): a marker file starting with `# slide-only`

The break tag is SSML — interpreted natively by ElevenLabs and Azure Speech Service. For consumers that don't speak SSML, run `transcript.py --no-breaks` to omit the tags.

## Constraints

- **No paraphrasing.** Speaker notes are written verbatim from the YAML. Voice rules are doc-to-yaml's responsibility, not this skill's.
- **No source-doc access.** This skill only reads YAML; it doesn't touch the original `.md`.
- **Brand-template-bound.** Output uses the bundled `assets/source-template-clean.pptx`. To use a different brand template, replace that file (or run `prepare_template.py` on a new master).

## Constraints on YAML input

- File extension must be `.yaml` (not `.yml`)
- `layout.kind` must be one of: `TITLE`, `BULLETS`, `TABLE`, `CODE`, `CALLOUT`, `OUTRO`
- `notes` should be in spoken voice (anaphora, articles, no source citations) — this skill does NOT re-normalize
- For `TABLE` and `CODE` slides, the visual will currently render as a bullet list. Hand-edit the YAML or use release-deck/build_yaml.py for richer rendering of those layouts.

