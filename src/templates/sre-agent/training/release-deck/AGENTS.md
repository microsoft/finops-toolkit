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
python3 build.py --part 1   # part 1 only
python3 build.py --part 2   # part 2 only
python3 build.py --part 3   # part 3 only
python3 build.py            # unified deck (default)
```

The unified `finops-toolkit-sre-agent-release-training.pptx` and the three split files all parse the SAME canonical `deck-outline-v8.md`. Edit the table; rebuild the parts.

---

## LAST UPDATED
2026-05-02 — initial creation after multiple "table is canonical" violations.

## VOICE RULES (added 2026-05-02)

This is OFFICIAL MICROSOFT TRAINING. Speaker notes are rendered in PowerPoint and read by ElevenLabs for video voiceover.

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

### Required
- Sentence case for ALL headings
- Active voice, second person ("you")
- Plain language, explain terms on first use
- Concrete numbers and tool names from evidence packs
- Read like Microsoft Learn or Microsoft Docs
