---
name: yaml-to-deck
description: Build, edit, rebuild, and verify the V8 FinOps Toolkit SRE Agent release training deck — 94 slides, 4 .pptx outputs (unified + part 1/2/3), MS Voice speaker notes, MCAPS-ask grounding, ElevenLabs-ready narration. Use this skill whenever the user mentions the V8 deck, release training deck, slides/*.yaml, build_yaml.py, build.py (the deck builder), rubric.py, the unified or part 1/2/3 .pptx files, MCAPS asks, ASK_A/ASK_B/ASK_C clusters, the cover banner, speaker notes for this deck, or any edit to slides under src/templates/sre-agent/training/release-deck/. Also trigger on "rebuild the deck", "rerender slides", "edit slide P1.x.A/B/C", "fix the cover", "split into parts", or asks about ASK / SHOW / TELL cluster pattern.
---

# yaml-to-deck

A pre-built pipeline for the **FinOps Toolkit SRE Agent V8 release training deck** — 94 slides, branded Microsoft template, MS Voice speaker notes, MCAPS-ask-grounded content, three split decks (deal motion / operate motion / honest+close), ElevenLabs-ready narration.

**Project root:** `/Users/brett/src/ftk/finops-toolkit/src/templates/sre-agent/training/release-deck/`

`cd` to that directory before any of the commands below.

---

## Layout

```
slides/                  # ★ EDIT THESE — 94 per-slide YAML files (canonical)
deck-outline-v8.md       # Escape hatch — original markdown table, kept in sync
build_yaml.py            # ★ Primary build:  slides/*.yaml → .pptx
build.py                 # Escape hatch build: deck-outline-v8.md → .pptx
rubric.py                # Pixel-perfect linter — must pass 0/0 after every build
source-template.pptx     # Branded Microsoft template (read-only input)
AGENTS.md                # Local rules (cardinal + voice). READ FIRST every session.
finops-toolkit-sre-agent-release-training.pptx                       # 94 slides
finops-toolkit-sre-agent-release-training-part1-deal-motion.pptx     # 36 slides
finops-toolkit-sre-agent-release-training-part2-operate-motion.pptx  # 48 slides
finops-toolkit-sre-agent-release-training-part3-honest-and-close.pptx #  8 slides
finops-toolkit-sre-agent-release-training-v8-frozen.pptx             # frozen reference
charts/  evidence/  assets/  renders/    # active subdirs
archive/  backups/                       # don't touch — historical safety nets
```

---

## The four things you do

### 1. Edit a slide

Find by ID in `slides/` (zero-padded order prefix + slide id):

- Cover slides — `000-0.1-...yaml`, `038-2.0.1-...yaml`
- Index — `001-0.2-...yaml`, `002-0.3-...yaml`, `003-0.4-...yaml`, `039-2.0.2-...yaml`
- Cluster slides — `004-P1.1.A-ask.yaml`, `005-P1.1.B-implementation.yaml`, `006-P1.1.C-details.yaml`, …
- Honest cluster — `086-H.1-...yaml` … `090-H.5-...yaml`
- Close — `091-Z.1-...yaml`, `092-Z.2-...yaml`, `093-Z.3-...yaml`

Edit the YAML directly with the `edit` tool. Schema is small — open the file and follow it (`id`, `order`, `cluster`, `asks_verbatim`, `title`, `content`, `notes`, `layout`, `screens`).

### 2. Rebuild the .pptx files

```bash
python3 build_yaml.py             # unified (94 slides)
python3 build_yaml.py --part 1    # deal motion only (36)
python3 build_yaml.py --part 2    # operate motion only (48)
python3 build_yaml.py --part 3    # honest + close only (8)
```

If PowerPoint has the .pptx open, the script writes a sibling `*.rebuild-{epoch}.pptx`. Tell the user, ask them to close PowerPoint, delete the sibling, rebuild.

### 3. Verify

```bash
python3 rubric.py                                                    # unified
python3 rubric.py --deck finops-toolkit-...-part1-deal-motion.pptx
python3 rubric.py --deck finops-toolkit-...-part2-operate-motion.pptx
python3 rubric.py --deck finops-toolkit-...-part3-honest-and-close.pptx
```

**Required: 0/0 violations on every deck before claiming done.**

### 4. Open for visual review

```bash
open finops-toolkit-sre-agent-release-training.pptx
```

For headless PNG/PDF renders, see `renders/` workflow already documented in the project `AGENTS.md`.

---

## Speaker notes — the rules that bite

The `notes:` field in each YAML **is the actual ElevenLabs voiceover.** Not a presenter prompt. Read the project `AGENTS.md` "VOICE RULES" section in full before editing any `notes:`. Summary:

- **Microsoft Voice** — warm + relaxed, crisp + clear, ready to lend a hand. Official guide: `https://learn.microsoft.com/en-us/style-guide/brand-voice-above-all-simple-human` and `https://learn.microsoft.com/en-us/style-guide/top-10-tips-style-voice`. Lead with verbs. Edit out "you can" and "there is/are".
- **Add context, don't narrate the slide.** The viewer can read the slide. The narration explains why it matters in customer conversations.
- **Cite MCAPS asks.** Every claim about what customers want or ask must trace to a numbered ask in `memory://work/mcaps/mcaps-internal-asks-finops-toolkit-azure-capacity-ai-cost-may-2026`. The `asks_verbatim:` field in each YAML carries the verbatim themes for that slide — work from those.
- **Humility.** Never "this solves X" / "the entire answer". Use "this gives you" / "this surfaces" / "this lands the verdict in Teams".
- **No prescription.** Inform; don't tell the field rep what to do on Monday.
- **Lowercase `srectl` in `content:`** (CLI literal); **uppercase `SRECTL` in `notes:`** (spoken aloud).
- **Don't invent.** No customer quotes, no deal-stage framing, no research jargon ("corpus", "evidence pack", "MCAPS ask #N"). If it's not in the canonical memory note, the voiceover doesn't claim it.

---

## Cardinal rules (project AGENTS.md, copied for safety)

1. `slides/*.yaml` is canonical. The .pptx is a build artifact. Never edit .pptx directly.
2. Edit YAML directly with the `edit` tool. No JSON side-channels, no merge scripts.
3. No new helper scripts. `build_yaml.py`, `build.py`, `rubric.py` exist. One-shot transforms go inline in bash.
4. **Local commits only. Never `git push`.**
5. Run `rubric.py` after every build. 0/0 required.
6. View the rendered slide before claiming "fixed".
7. Read this file and the project `AGENTS.md` when starting a new editing session.

---

## When you start fresh

Read these in order before any non-trivial edit:

1. This file
2. `src/templates/sre-agent/training/release-deck/AGENTS.md` — full rules + voice rules + recurring screw-ups
3. The YAML file you're about to edit (full content, including the `asks_verbatim:` block)
4. If rewriting `notes:`: also read `memory://work/mcaps/mcaps-internal-asks-finops-toolkit-azure-capacity-ai-cost-may-2026` for verbatim ask themes

---

## Boundary with `doc-to-yaml`

The sibling `doc-to-yaml` skill turns Microsoft Learn docs into yaml-to-deck-compatible YAML. This skill (`yaml-to-deck`) owns the schema, build pipeline, voice rules, and rendering. Don't reimplement either side.
