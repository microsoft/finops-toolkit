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

**Active scope:** Speaker notes rewrite for all 94 slides.

**Required note structure (per slide, in cell 5 of the table):**
```
## Why you GAF
<1-2 sentences — the field reader's stake on Monday>

## Talk track
<2-4 sentences — what to say while slide is on screen>

## Anchors
<1-2 sentences — named tools/tasks/asks/evidence cited>

## References
- memory://uri/of/source (concept)
- Local: src/templates/sre-agent/training/release-deck/evidence/tasks/<task>.md
- Concepts: [[Wikilinked]], [[Concepts]]
```

Sections separated by `<br/><br/>` in the cell. Line breaks within sections use `<br/>`.

**Grounding contract:** Search `maenifold.memory` BEFORE writing each note. Read top hits via `ReadMemory`. If a fact isn't in memory or evidence, write "Unknown" — never fabricate.

**Status:**
- 0.1 ✅ done (committed in table)
- 0.2, 0.3, 0.4 — in progress
- All P1.x, P2.x, H.x, Z.x, 1.99, 2.0.1, 2.0.2, 2.99 — pending

---

## LAST UPDATED
2026-05-02 — initial creation after multiple "table is canonical" violations.
