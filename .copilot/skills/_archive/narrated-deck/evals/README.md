# narrated-deck — evals

This directory contains test cases and reference inputs for the `narrated-deck` skill.

## Test inputs

`inputs/` contains three SRE agent docs of varying complexity, used as fixtures across the eval set:

| Doc | Size | Why it's in the eval set |
|---|---|---|
| `overview.md` | ~1.1k words, 5 scenes | Smallest — exercises the basic pipeline + table-driven scene detection |
| `get-started.md` | ~1.1k words, 7 scenes | Medium — exercises the normalizer (run-on splitting on prose with semicolons) |
| `kusto-tools.md` | ~2.7k words, 25 scenes | Largest — stress-tests the per-doc subagent throughput and confirms source-citation parenthetical removal at scale |

These fixtures are snapshots of `docs-mslearn/toolkit/sre-agent/*.md` taken after the Microsoft Style Guide cleanup commit `ed295c3d`. They're committed alongside the skill so eval results stay reproducible even if the source docs evolve.

## Running the evals

The recommended path is per-doc subagent fan-out — spawn one subagent per eval, each invoking the skill on its assigned input. The orchestrator collates results.

For a quick local check (single doc, no subagents):

```bash
python3 .copilot/skills/narrated-deck/scripts/convert.py \
    .copilot/skills/narrated-deck/evals/inputs/overview.md \
    --output .copilot/skills/narrated-deck/evals/outputs/eval-1
```

For the full batch (still single-process — subagent fan-out is the calling agent's responsibility):

```bash
python3 .copilot/skills/narrated-deck/scripts/convert.py \
    .copilot/skills/narrated-deck/evals/inputs/overview.md \
    .copilot/skills/narrated-deck/evals/inputs/get-started.md \
    .copilot/skills/narrated-deck/evals/inputs/kusto-tools.md \
    --output .copilot/skills/narrated-deck/evals/outputs/batch
```

## What to verify in the outputs

For each eval directory, check:

1. **`scenes.json`** — scene count matches the doc's H2 count (minus dropped sections). `narration_only: true` flags appear on table/code-dominated scenes.
2. **`transcripts/scene_NN_*.txt`** — prose scenes carry natural-sounding narration with `<break time="1300ms" />` between paragraphs. Slide-only scenes are marker files starting with `# slide-only`.
3. **`deck-outline.md`** — 7-cell table parses cleanly (no broken pipes from unescaped `|` in cell content). Speaker notes reproduce the transcript content with `<br/>` instead of `<break>`.
4. **`slides.pptx`** — opens in PowerPoint. First slide is the title. Last is the outro. Each H2 from the source is a slide. Speaker notes pane shows the narration.

## Expected qualitative observations

- `overview.md` → 5 prose-bearing scenes + 1 slide-only ("What you get") + outro
- `get-started.md` → 6 prose-bearing scenes + 1 slide-only ("Automation map") + outro
- `kusto-tools.md` → ~25 scenes; "Source validation" is table-only; each tool subsection is a separate `BULLETS` scene
