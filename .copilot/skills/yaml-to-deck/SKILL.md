---
name: yaml-to-deck
description: Render a directory of per-slide YAML files into a branded FinOps Toolkit PowerPoint deck using the canonical V8 SRE Agent training-deck renderer. Use this skill whenever you have slide YAML and want a PPTX, want to rebuild the V8 SRE Agent release training deck (94 slides + parts 1/2/3), edit slides under src/templates/sre-agent/training/release-deck/, work with build_yaml.py / build.py / rubric.py, lint slide YAML for schema or voice violations, or produce a deck from doc-to-yaml output. Pairs upstream with doc-to-yaml and downstream with text-to-speech + azure-video-pipeline. Trigger on yaml-to-deck, slide YAML, slides.pptx, build_yaml.py, build.py, rubric.py, V8 deck, release training deck, ASK_A/ASK_B/ASK_C, INDEX layout, MCAPS asks, source-template.pptx, FinOps Toolkit deck.
---

# yaml-to-deck

Renders per-slide YAML files into a branded FinOps Toolkit PowerPoint deck. Bundles the canonical V8 SRE Agent renderer (`build.py` + `build_yaml.py`), the branded template (`source-template.pptx`), and the brand labels (`labels.yaml`).

The renderer in this skill is **byte-identical** to the project copy at `src/templates/sre-agent/training/release-deck/`, except it takes all paths as required CLI arguments so the skill can render decks anywhere.

## Quick start

```bash
SKILL=/Users/brett/src/ftk/finops-toolkit/.copilot/skills/yaml-to-deck

python3 "$SKILL/scripts/build_yaml.py" \
    --slides-dir  /path/to/slides/ \
    --template    "$SKILL/assets/source-template.pptx" \
    --labels      "$SKILL/assets/labels.yaml" \
    --output      /path/to/out.pptx
```

For decks that reference charts or images via the YAML `screens:` directive, also pass:

```bash
    --charts /path/to/charts/svg \
    --assets /path/to/assets
```

For the V8 SRE deck split parts:

```bash
    --part 1   # P1.x slides only (deal motion, 36 slides)
    --part 2   # P2.x slides only (operate motion, 48 slides)
    --part 3   # H/Z slides only  (honest + close, 8 slides)
```

## Inputs

| Input | What | Required |
|---|---|---|
| `--slides-dir` | Directory containing per-slide `*.yaml` files | yes |
| `--template`   | Path to `source-template.pptx` (use bundled `assets/source-template.pptx`) | yes |
| `--labels`     | Path to `labels.yaml` (use bundled `assets/labels.yaml`) | yes |
| `--output`     | Path to write the rendered `.pptx` | yes |
| `--charts`     | Path to chart SVG/PNG dir | only if slides reference `screens: chart=...` |
| `--assets`     | Path to image-asset dir | only if slides reference `screens: image=...` |
| `--part`       | One of `1`/`2`/`3`/`all` (default `all`) | no |

No defaults, no fallbacks. Missing required args fail loudly with a clear message.

## YAML schema

One YAML file per slide. Filename pattern: `NNN-<id>-<slug>.yaml` (zero-padded order prefix; file sort = render order).

```yaml
id: '1'                     # slide identifier (string — quote it)
order: 0                    # zero-based render order
cluster: overview           # group / chyron label
asks_verbatim: []           # MCAPS asks (V8 deck only); [] otherwise
title: 'Heading text'       # slide title
content: '• Bullet 1<br/>• Bullet 2'   # bullets, <br/>-separated
notes: 'Spoken narration.<br/><br/>Second paragraph.'   # TTS voiceover prose
layout:
  kind: BULLETS             # see "Layout kinds" below
  addresses: []             # MCAPS ask numbers (V8 only); [] otherwise
  verdict: null             # green/yellow/red (V8 honest cluster only); null otherwise
screens: null               # 'chart=foo.png' or 'image=bar.svg' or null
```

`notes:` is the actual TTS voiceover, not a presenter prompt. Microsoft Voice rules apply — see `references/voice-spec.md`.

## Layout kinds (canonical V8 renderer)

The `kind:` value selects the renderer:

| Kind | Purpose |
|---|---|
| `TITLE` | Hero / cover slide |
| `INDEX` | Multi-column table of contents |
| `BULLETS` | Heading + body bullets |
| `ASK_A` | MCAPS ASK pull-quote slide (cluster opener) |
| `ASK_B` | SHOW: chart + bullets (middle of cluster) |
| `ASK_C` | TELL: bullets + Monday-move callout (cluster closer) |

Examples for every kind: `assets/examples/<KIND>.example.yaml` (copied from the V8 canonical deck).

## The pipeline

```
docs-mslearn/*.md
   ↓ doc-to-yaml         (extract scenes, normalize voice)
slides/*.yaml
   ↓ yaml-to-deck        (this skill: lint → render PPTX)
out.pptx
   ↓ text-to-speech      (each notes block → .mp3)
   ↓ azure-video-pipeline (compose PPTX + audio → MP4)
final video
```

## Lint before you build

```bash
python3 "$SKILL/scripts/lint.py" /path/to/slides/                 # whole dir
python3 "$SKILL/scripts/lint.py" /path/to/slides/000-foo.yaml     # one file
python3 "$SKILL/scripts/lint.py" /path/to/slides/ --strict        # warnings → errors
python3 "$SKILL/scripts/lint.py" /path/to/slides/ --voice-only    # voice rules only
```

Checks schema, filename pattern, layout-kind, MS Voice rule violations (`there are`, `you should`, `Monday move`, `corpus`, source-citation parentheticals, etc.), MCAPS citation gaps for V8 cluster slides, and rendering hazards (long titles, code overflow, markdown in notes).

Exit codes: `0` clean, `1` errors, `2` warnings only.

## Verify the rendered deck

```bash
python3 "$SKILL/scripts/rubric.py" --deck /path/to/out.pptx
```

Pixel-perfect linter — ovals are circles, images preserve aspect, etc. Required: `0/0 violations`.

## Files in this skill

```
yaml-to-deck/
├── SKILL.md                                # this file
├── scripts/
│   ├── build.py                            # canonical renderer (lib + script)
│   ├── build_yaml.py                       # ★ user-facing CLI: YAML → PPTX
│   ├── rubric.py                           # pixel-perfect linter
│   └── lint.py                             # YAML schema + voice + MCAPS-citation lint
├── references/
│   ├── voice-spec.md                       # Microsoft Voice rules with citations
│   └── mcaps-asks.md                       # MCAPS ask citation requirement (V8 only)
└── assets/
    ├── source-template.pptx                # branded master (bundled)
    ├── labels.yaml                         # FinOps Toolkit brand strings (bundled)
    └── examples/
        ├── TITLE.example.yaml
        ├── INDEX.example.yaml
        ├── BULLETS.example.yaml
        ├── ASK_A.example.yaml
        ├── ASK_B.example.yaml
        └── ASK_C.example.yaml
```

## Verified

The bundled `build_yaml.py` produces a deck **byte-identical** to the project's canonical build for the V8 SRE Agent training deck (94 slides, 26 MB) — same SHA256 hash over all PPTX zip entries except `docProps/core.xml` and `app.xml` (timestamps).

Verification command:

```bash
PROJ=/Users/brett/src/ftk/finops-toolkit/src/templates/sre-agent/training/release-deck
python3 "$SKILL/scripts/build_yaml.py" \
    --slides-dir "$PROJ/slides" \
    --template   "$SKILL/assets/source-template.pptx" \
    --labels     "$SKILL/assets/labels.yaml" \
    --charts     "$PROJ/charts/svg" \
    --assets     "$PROJ/assets" \
    --output     /tmp/v8-via-skill.pptx
```

## Boundary with sibling skills

| Skill | Owns |
|---|---|
| `doc-to-yaml` | MS Learn `.md` → per-slide `.yaml` (voice normalization) |
| **`yaml-to-deck`** (this skill) | `.yaml` → `.pptx` (this is the renderer) |
| `text-to-speech` | per-slide `notes:` → `.mp3` |
| `azure-video-pipeline` | slides + audio → final video |

Don't reimplement. Don't normalize voice here (upstream's job). Don't render audio here (downstream's job).
