# V8 Deck — Operating Instructions

**Read this BEFORE every action on this project. Update when you learn something new.**

---

## CARDINAL RULES (violation = stop and apologize)

1. **The TABLE is canonical.** `deck-outline-v8.md` is the only source of truth for slide content. The `.pptx` is a build artifact. The `build.py` script reads the table → generates the .pptx. Never edit the .pptx directly. Never write side-channel JSON files. Never write merge scripts.

2. **Edit the table directly.** Use `edit` tool with surgical `old_str`/`new_str` swaps on the row in `deck-outline-v8.md`. No intermediate formats.

3. **No new scripts without explicit ask.** `build.py` and `rubric.py` exist. Don't invent `merge_notes.py`, `update_titles.py`, etc. If a transformation is one-shot, do it in a one-shot bash inline (no file).

4. **Confidential = LOCAL ONLY.** Never push to remote. Local commits OK. Will be squashed/cleaned later. Lock-file detection in `build.py` writes a sibling rebuild file when PowerPoint is open.

5. **Pixel-perfect = enforced by `rubric.py`.** Run after every build. 0 violations required. No vibes, no eyeballing thumbnails. Inspect individual full-res slides at 4001×2250.

6. **Look before claiming.** Don't say "fixed" until I've actually viewed the rendered slide AND run the rubric.

7. **Pre-action alignment.** Restate user's literal request before acting. Don't broaden scope. Don't substitute approach.

---

## FILE LAYOUT

```
src/templates/sre-agent/training/release-deck/
├── deck-outline-v8.md         # CANONICAL source of truth
├── build.py                   # parser + renderer (94 slides → .pptx)
├── rubric.py                  # automated pixel-perfect checker
├── source-template.pptx       # branded Microsoft template (read-only input)
├── finops-toolkit-sre-agent-release-training.pptx  # build artifact
├── finops-toolkit-sre-agent-release-training.rebuild-*.pptx  # written when PPT open
├── evidence/
│   ├── INVENTORY.md
│   ├── ASKS-COVERAGE.md
│   └── tasks/                 # 18 task evidence packs (.md)
├── charts/
│   ├── MANIFEST.md
│   └── svg/                   # 51 chart SVGs (rasterized to .png on demand)
└── renders/                   # full-res PNG renders (gitignored)
```

---

## TABLE ROW FORMAT (deck-outline-v8.md)

Each slide row has **7 pipe-delimited cells**:

```
| num | stage | title | content | notes | layout | screens |
```

- **Cell 0**: `| ` (leading pipe, empty marker)
- **Cell 1**: `num` — slide ID (`0.1`, `P1.1.A`, `H.1`, `Z.1`, `1.99`)
- **Cell 2**: `stage` — cluster name (e.g., `Quota ≠ Capacity`) or `Intro`/`Honest`/`Close`/`End of Part 1`
- **Cell 3**: `title` — what shows in the slide title placeholder (e.g., `Ask`, `Implementation`, `Details`)
- **Cell 4**: `content` — bullets, separated by `<br/>`
- **Cell 5**: `notes` — speaker notes, separated by `<br/>` for line breaks, `<br/><br/>` for paragraph breaks
- **Cell 6**: `layout` — `kind=ASK_A · addresses=8,13 verdict=green` style directive
- **Cell 7**: `screens` — `assets: image=foo.svg` or `None`

**Pipes inside cells**: not allowed (parser uses ` | ` as delimiter). If you need to express alternatives, use ` or ` or `·` (middot).

---

## BUILD PROCESS

```bash
cd /Users/brett/src/ftk/finops-toolkit/src/templates/sre-agent/training/release-deck

# 1. Restore template (in case soffice consumed it from a prior run)
cp "/Users/brett/.copilot/session-state/0e189977-66ef-4fc4-b1bc-632852bdca4c/files/finops-toolkit-sre-agent-release-training-v6.pptx" source-template.pptx

# 2. Build the .pptx from the table
python3 build.py

# 3. Run the pixel-perfect audit (must be 0/0)
python3 rubric.py

# 4. Render to PDF + PNGs for visual verification
soffice --headless --convert-to pdf --outdir renders finops-toolkit-sre-agent-release-training.pptx
cd renders && pdftoppm -png -r 300 finops-toolkit-sre-agent-release-training.pdf slide
```

**ALL FOUR STEPS REQUIRED before claiming any slide is "fixed".**

---

## RECURRING SCREW-UPS I MUST AVOID

| Screw-up | Don't | Do |
|---|---|---|
| Writing JSON output for a non-existent merge script | Tell drafter to write JSON | Have drafter edit table rows directly with `edit` tool |
| Writing a new helper script | Create `update_xxx.py` | Use bash inline or edit the canonical file |
| Patching content in `build.py` | Add `_resolve_title` overrides | Edit the title cell in `deck-outline-v8.md` |
| Pushing confidential material | `git push` | `git commit` only, locally |
| Eyeballing thumbnails | Look at 600×450 grids | Run `rubric.py` + view individual 4001×2250 PNGs |
| "Looks great" without running rubric | Declare done from vibes | Always run `python3 rubric.py` first |
| Overwriting open .pptx | `prs.save(OUT)` blindly | Lock-file detection (already in build.py) |

---

## WHEN A USER GIVES NEW DIRECTION

1. **Stop.** Don't continue current path on autopilot.
2. **Read this file.** Re-check cardinal rules.
3. **Restate the literal request.** Don't broaden.
4. **Update this file.** If a new rule emerged, write it down here.
5. **Then act.**

---

## CURRENT WORK (update as scope changes)

**Active scope:** V8 deck FROZEN as of 2026-05-02. Three split decks built from the canonical outline.

**Frozen artifacts (do not edit):**
- `finops-toolkit-sre-agent-release-training-v8-frozen.pptx` — full 94-slide deck snapshot.

**Split decks (built from the canonical outline via `--part`):**
- `finops-toolkit-sre-agent-release-training-part1-deal-motion.pptx` — 36 slides (0.1, 0.2, P1.1-P1.11, 1.99).
- `finops-toolkit-sre-agent-release-training-part2-operate-motion.pptx` — 48 slides (2.0.1, 2.0.2, P2.1-P2.15, 2.99).
- `finops-toolkit-sre-agent-release-training-part3-honest-and-close.pptx` — 8 slides (H.1-H.5, Z.1-Z.3).

**To rebuild a part:**
```bash
python3 build_yaml.py --part 1     # YAML pipeline (PRIMARY)
python3 build_yaml.py --part 2
python3 build_yaml.py --part 3
python3 build_yaml.py              # unified deck (default)
```

## CANONICAL SOURCE (updated 2026-05-03)

**Primary canonical: `slides/*.yaml`** — one YAML file per slide (94 files, numbered `000-` through `093-`). Use `build_yaml.py` to render. This is now the source of truth for all editing.

**Escape hatch: `deck-outline-v8.md`** — the original 8-column markdown table. Still parseable by `build.py` and produces layout-identical output. Kept for diff/audit purposes. **Do not edit both** — edits should go into the YAML files; the .md is frozen as a reference snapshot.

**Migration history:**
- `deck-outline-v8.md.bak-pre-yaml-migration-20260503-102134` — canonical state immediately before YAML migration
- `slides/` — 94 YAML files generated 2026-05-03 from the .md

Both pipelines accept `--part 1|2|3` and produce identical structural output (visual diff verified). YAML pipeline is preferred because:
- One file per slide → diff-friendly, no pipe-delimiter drift risk
- Proper schema with typed fields (asks_verbatim is a list of dicts, not pipe-separated strings)
- Speaker notes live as multi-line YAML strings — easy to read and edit in isolation

---

## LAST UPDATED
2026-05-02 — initial creation after multiple "table is canonical" violations.

## VOICE RULES (added 2026-05-02)

This is OFFICIAL MICROSOFT TRAINING. Speaker notes are rendered in PowerPoint and read by ElevenLabs for video voiceover.

### Speaker note INTENT (added 2026-05-03)

Speaker notes (cell 5) are the actual voiceover the audience hears while looking at the slide. They MUST add context the slide cannot carry — they MUST NOT paraphrase what is already on screen.

The narration informs and helps. It does NOT prescribe. We are not telling the field rep what to do on Monday; we are explaining what they're looking at and why it matters in customer conversations.

### Citation requirement (added 2026-05-03 — MANDATORY)

Every speaker note MUST cite the specific MCAPS ask number(s) it addresses, drawn from `memory://work/mcaps/mcaps-internal-asks-finops-toolkit-azure-capacity-ai-cost-may-2026`.

Format: append a final line to the cell-5 narration:
```
<br/><br/>Source: MCAPS ask #N — "verbatim ask theme from canonical table".
```

For multi-ask slides, list each: `Source: MCAPS asks #8, #13, #14 — "Quota ≠ Capacity", "Zonal capacity / AZ stockouts", "SKU availability / offer restrictions".`

The citation is part of the rendered voiceover and ElevenLabs reads it aloud. This is non-negotiable: every claim about what customers ask, want, or care about must be traceable to a numbered ask in the canonical memory note.

NO INVENTED CUSTOMER CONTEXT. If the canonical note doesn't say it, the voiceover doesn't claim it.

### Three-paragraph shape (informational, not prescriptive)

1. **The customer reality** — the verbatim or paraphrased ask from the canonical memory note. Cite the ask number(s).
2. **What this gives you** — the operating insight the slide carries; how the artifact lands the answer in the customer's environment.
3. **Where the boundary is** — what this does NOT do, who else owns the rest, what stays honest.

Then the citation footer.

### Humility (added 2026-05-03)

NEVER overclaim. The agent does not "solve" or "answer" entire problem categories.

Banned overclaims:
- "This is the entire answer to X"
- "This one task solves Y"
- "All you need is..."
- "Everything is in this one place"

Use instead: "this gives you", "this surfaces", "this lands the verdict in...", "this becomes the evidence you walk into the conversation with".

### Cell-5 capitalization (added 2026-05-03)

When narrating an operator command in cell 5 (speaker notes / voiceover), capitalize the brand form because it's spoken aloud:
- Cell 4 (slide content): lowercase `srectl` (it's the CLI command literal)
- Cell 5 (voiceover narration): SRECTL (it's spoken)

### Headers (use these EXACTLY)
- `## Why this matters`
- `## Talk track`
- `## Anchors`
- `## References`

### Banned
- "GAF", "GAFA", or any acronym/slang headers
- Profanity, slang, internal jargon
- Hyperbole: "powerful", "seamless", "delightful", "just", "easy", "world-class", "best-in-class"
- Exclamation points (extremely rare)
- ALL CAPS (except established acronyms: AOAI, CRG, MCA, RI, SP, ESR, MACC, FOCUS, KQL, P&L)
- Marketing fluff: "unleash", "transform", "supercharge", "revolutionize"
- Cute or creative section names
- **Research jargon (added 2026-05-03):** "corpus", "evidence pack", "ask cluster", "verbatim quote", "MCAPS ask #N". The audience is the field; talk in field language ("what customers told us", "the question you hear", "the deal-blocker").

### Required
- Sentence case for ALL headings
- Active voice, second person ("you")
- Plain language, explain terms on first use
- Concrete numbers and tool names from evidence packs
- Read like Microsoft Learn or Microsoft Docs
