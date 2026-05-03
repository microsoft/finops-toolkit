---
name: yaml-to-deck
description: Build a branded FinOps Toolkit PowerPoint deck plus TTS-ready transcripts from per-slide YAML files. Use this skill whenever you have a directory of slide YAML and want to render a narrated training deck, generate transcripts for downstream text-to-speech, build a PPTX from a YAML scene plan, lint slide YAML for schema or voice violations, scaffold new slide YAML from a layout template, rebuild the FinOps Toolkit SRE Agent V8 release training deck (94 slides, parts 1/2/3), edit slides under src/templates/sre-agent/training/release-deck/, work with build_yaml.py / build.py / rubric.py, or apply MCAPS-ask grounded speaker notes. Pairs upstream with doc-to-yaml (which produces YAML from MS Learn docs) and downstream with text-to-speech and azure-video-pipeline. Trigger on yaml-to-deck, narrated deck, slide YAML, slides.pptx, build_yaml.py, build.py, rubric.py, V8 deck, release training deck, ASK_A/ASK_B/ASK_C, MCAPS asks, scenes.json, transcripts/scene_NN_*.txt, source-template.pptx, FinOps Toolkit deck.
---

# yaml-to-deck

Take per-slide YAML files and produce a branded FinOps Toolkit PowerPoint deck plus TTS-ready transcripts.

| Input | Output |
|---|---|
| `slides/*.yaml` (release-deck schema) | `slides.pptx` (FinOps Toolkit branded) |
| | `transcripts/scene_NN_<slug>.txt` (TTS-ready, SSML break tags) |
| | `scenes.json` (combined scene index for downstream skills) |

**Two operating modes**, pick the one that matches the input:

| Mode | When | Renderer |
|---|---|---|
| **General** (most common) | YAML produced by `doc-to-yaml`, hand-authored from a template, or any YAML using `TITLE/BULLETS/TABLE/CODE/CALLOUT/OUTRO` layouts | `scripts/consume.py` (bundled in this skill) |
| **V8 SRE deck** (specialized) | The 94-slide V8 SRE Agent release training deck under `src/templates/sre-agent/training/release-deck/`, which uses additional `ASK_A/ASK_B/ASK_C/INDEX` layouts with MCAPS-ask grounding | `build_yaml.py` in the project root (this skill points to it) |

Both modes share the same YAML schema. `layout.kind` decides the renderer. See `references/layout-kinds.md` for the full kind table.

---

## Pipeline position

```
docs-mslearn/*.md                              ← source
   ↓ doc-to-yaml      (extract scenes, normalize voice)
slides/*.yaml                                  ← canonical (this skill's input)
   ↓ yaml-to-deck     (this skill: lint → render → transcripts)
slides.pptx + transcripts/*.txt + scenes.json  ← this skill's output
   ↓ text-to-speech   (each .txt → .mp3 via ElevenLabs / Azure)
   ↓ azure-video-pipeline (composes slides + audio → final video)
final video
```

Skip downstream steps if you only need the deck and transcripts.

---

## Quick start (general mode)

```bash
SKILL=/Users/brett/src/ftk/finops-toolkit/.copilot/skills/yaml-to-deck

# 1. Lint a YAML directory before building (optional but recommended)
python3 "$SKILL/scripts/lint.py" path/to/slides/

# 2. Render PPTX + transcripts + scenes.json
python3 "$SKILL/scripts/consume.py" path/to/slides/ \
        --output path/to/out/ \
        --next "Coming up: module 2"

# 3. Inspect outputs
ls path/to/out/
#   slides.pptx
#   scenes.json
#   transcripts/scene_01_*.txt
#   transcripts/scene_02_*.txt …
```

`--next` text appears on the OUTRO slide. Omit if there is no follow-up module.

---

## V8 SRE deck mode

The V8 deck is the 94-slide FinOps Toolkit SRE Agent release training deck. It lives at:

`src/templates/sre-agent/training/release-deck/`

It uses additional layout kinds (`INDEX`, `ASK_A`, `ASK_B`, `ASK_C`) tied to its MCAPS-ask cluster pattern. Its renderer is the project-local `build_yaml.py` (which imports the project-local `build.py`). This skill does not duplicate that renderer — it points at it.

```bash
cd src/templates/sre-agent/training/release-deck

# Find slides by ID under slides/
ls slides/ | head
#   000-0.1-finops-toolkit-sre-agent-part-1-of-2.yaml
#   001-0.2-toc.yaml
#   002-0.3-toc.yaml
#   003-0.4-toc.yaml
#   004-P1.1.A-ask.yaml
#   005-P1.1.B-implementation.yaml
#   006-P1.1.C-details.yaml ...

# Edit a slide YAML directly (with the `edit` tool — schema is small)

# Rebuild
python3 build_yaml.py             # unified  (94 slides)
python3 build_yaml.py --part 1    # deal motion       (36 slides)
python3 build_yaml.py --part 2    # operate motion    (48 slides)
python3 build_yaml.py --part 3    # honest + close    ( 8 slides)

# Verify (must be 0/0 violations)
python3 rubric.py
python3 rubric.py --deck finops-toolkit-...-part1-deal-motion.pptx
python3 rubric.py --deck finops-toolkit-...-part2-operate-motion.pptx
python3 rubric.py --deck finops-toolkit-...-part3-honest-and-close.pptx
```

Project-local rules live in `src/templates/sre-agent/training/release-deck/AGENTS.md` — read it when starting a fresh editing session.

---

## YAML schema (required reading)

Every slide is one YAML file. Filename pattern: `NNN-<id>-<slug>.yaml` (zero-padded order prefix → file sort = render order).

```yaml
id: '1'                        # slide id (string — release-deck uses 'P1.1.A' etc.)
order: 0                       # zero-based scene order
cluster: overview              # doc slug or section group; chyron label
asks_verbatim: []              # MCAPS asks for V8 SRE deck; empty for general
title: 'Heading text'          # slide title (becomes <h1> on the slide)
content: '• Bullet 1<br/>• Bullet 2'
                               # slide body bullets, <br/>-separated. Each bullet
                               # starts with • U+2022. For TABLE/CODE this can be
                               # summary text — the slide renders the raw block.
notes: 'Spoken narration.<br/><br/>Second paragraph.'
                               # ★ This is the actual TTS voiceover. Not a presenter
                               # prompt. <br/><br/> separates paragraphs (becomes
                               # SSML <break> in transcripts). Microsoft Voice rules
                               # apply — see references/voice-spec.md.
layout:
  kind: BULLETS                # ★ Drives the renderer. See references/layout-kinds.md.
                               # General: TITLE | BULLETS | TABLE | CODE | CALLOUT | OUTRO
                               # V8 SRE: + ASK_A | ASK_B | ASK_C | INDEX
  addresses: []                # MCAPS ask numbers cited (V8 SRE deck only). Empty otherwise.
  verdict: null                # green/yellow/red (V8 SRE honest cluster only). Null otherwise.
screens: null                  # asset directives (e.g. `image=foo.svg`) or null.
```

Full per-field semantics: `references/yaml-schema.md`.

---

## Layout kinds at a glance

| Kind | Purpose | Bullet count | Notes carry narration? |
|---|---|---|---|
| `TITLE` | Hero / cover slide | 0–3 (subtitle) | Yes, short |
| `BULLETS` | Heading + body bullets (most common) | 3–7 | Yes |
| `TABLE` | Heading + actual PPTX table | 0 (table is the body) | Slide-only OK |
| `CODE` | Heading + monospace code block | 0 (code is the body) | Slide-only OK |
| `CALLOUT` | Section header + pull quote | 0 (quote is the body) | Yes |
| `OUTRO` | Closing slide ("Coming up next: …") | 0 | Optional |
| `INDEX` (V8 SRE only) | Multi-column table of contents | varies | No |
| `ASK_A` (V8 SRE only) | MCAPS ASK pull-quote slide | 0 | Yes |
| `ASK_B` (V8 SRE only) | SHOW: chart + bullets | 3–6 | Yes |
| `ASK_C` (V8 SRE only) | TELL: bullets + Monday-move callout | 3–6 | Yes |

For each kind: when to use, what fields drive it, sizing rules, and example YAML — see `references/layout-kinds.md`.

For copy-paste starter YAML for each general layout — see `assets/templates/`.

---

## Voice rules — the rules that bite

The `notes:` field IS the TTS voiceover. Not a presenter prompt. Read `references/voice-spec.md` for the full Microsoft Style Guide rules. Summary:

1. **Microsoft Voice** — warm + relaxed, crisp + clear, ready to lend a hand. Lead with verbs. Edit out "you can" and "there is/are".
2. **Add context, don't narrate the slide.** The viewer can read the slide. The narration explains why it matters.
3. **Anaphora.** First mention: full product name. Subsequent: "the agent" / "It". Plural products (`FinOps hubs`) skip the article.
4. **Brevity.** Split semicolon run-ons into separate sentences.
5. **No source-citation parentheticals.** `([source YAML](path))` → strip.
6. **Humility.** Never "this solves X" or "the entire answer". Use "this gives you" / "this surfaces".
7. **No prescription.** Inform; don't tell the field rep what to do on Monday.
8. **For V8 SRE deck only:** Cite MCAPS asks. Lowercase `srectl` in `content:` (CLI literal); uppercase `SRECTL` in `notes:` (spoken).
9. **Don't invent.** If a fact isn't in the source, the narration doesn't claim it.

`scripts/lint.py` flags violations of rules 1–7 with line numbers.

---

## Lint before you build

`scripts/lint.py` checks YAML files for:

- **Schema** — required keys present, types match, `layout.kind` is valid
- **Filename** — `NNN-<id>-<slug>.yaml` pattern
- **Voice** — flags banned phrases (`Monday move`, `corpus`, `evidence pack`, `MCAPS ask #N` if outside `addresses`), passive openers (`there is`, `there are`), prescriptive verbs (`you should`, `you must`), source-citation parentheticals
- **Citations** — for V8 SRE deck (cluster starts with `P1` / `P2` / `H` / `Z`), every `notes:` claim must trace to an `asks_verbatim:` theme; lint warns when `asks_verbatim` is empty for those clusters
- **Layout fit** — bullet count vs layout kind (e.g. `TITLE` should not have 7 bullets)
- **Rendering hazards** — overlong titles (>60 chars on `TITLE`/`INDEX` will wrap), too-many bullets, missing `<br/>` separators

```bash
python3 scripts/lint.py path/to/slides/                # whole dir
python3 scripts/lint.py path/to/slides/004-P1.1.A-ask.yaml  # single file
python3 scripts/lint.py path/to/slides/ --strict        # warnings → errors
python3 scripts/lint.py path/to/slides/ --voice-only    # just the voice checks
```

Exit codes: `0` clean, `1` errors, `2` warnings only.

---

## Scaffold a new slide

Copy a template from `assets/templates/` to your `slides/` directory and edit:

```bash
SKILL=/Users/brett/src/ftk/finops-toolkit/.copilot/skills/yaml-to-deck
ORDER=$(printf "%03d" 5)

# Pick the layout you want
cp "$SKILL/assets/templates/bullets.yaml" "slides/${ORDER}-myslide-id-my-slug.yaml"
# → edit id, order, title, content, notes
```

Templates exist for: `title.yaml`, `bullets.yaml`, `table.yaml`, `code.yaml`, `callout.yaml`, `outro.yaml`. Each is annotated with required fields and a placeholder example.

V8 SRE-specific kinds (`ASK_A/B/C`, `INDEX`) are not templated here — copy from a sibling slide in `src/templates/sre-agent/training/release-deck/slides/` and edit.

---

## Constraints

- **No paraphrasing in `notes:`.** This skill renders verbatim what's in the YAML. Voice rules are doc-to-yaml's responsibility for doc-derived YAML, and the editor's responsibility for hand-authored YAML.
- **No source-doc access.** This skill only reads YAML; it doesn't touch original `.md`.
- **Brand-template-bound.** Output uses the bundled `assets/source-template-clean.pptx`. To use a different brand template: replace that file (or run `scripts/prepare_template.py` on a new master).
- **Local commits only on this repo.** `features/sre` branch. No `git push`.
- **No new helper scripts in the V8 deck project.** That project has `build_yaml.py`, `build.py`, `rubric.py` — use them. Don't add more.

---

## Constraints on YAML input

- File extension `.yaml` (not `.yml`)
- `layout.kind` must be one of the kinds in the table above
- `notes:` should be in spoken voice — this skill does not re-normalize
- `content:` bullets are `<br/>`-separated, each starts with `• ` (U+2022)
- Multi-paragraph `notes:` use `<br/><br/>` between paragraphs

---

## Reference files

- `references/yaml-schema.md` — full per-field semantics + edge cases
- `references/layout-kinds.md` — every layout kind, when to use, fields it consumes
- `references/voice-spec.md` — Microsoft Style Guide rules with citations (anaphora, articles, brevity, source-citation stripping)
- `references/output-formats.md` — `scenes.json`, transcripts, PPTX schema definitions
- `assets/templates/*.yaml` — copy-paste starter YAML for each general layout
- `evals/` — sample MS Learn docs and expected behavior for regression testing

---

## Boundary with sibling skills

| Skill | Owns |
|---|---|
| `doc-to-yaml` | MS Learn `.md` → per-slide `.yaml`. Voice normalization happens here. |
| **`yaml-to-deck`** (this skill) | `.yaml` → `.pptx` + transcripts. Schema, layouts, branded rendering. |
| `text-to-speech` | transcript `.txt` → `.mp3` |
| `azure-video-pipeline` | slides + audio → final video |

Don't reimplement either side. Don't normalize voice here (it's already done upstream). Don't render audio here (downstream skill).
