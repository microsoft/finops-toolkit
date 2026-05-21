# MCAPS asks reference (V8 SRE deck only)

The V8 SRE Agent release training deck grounds every claim in numbered MCAPS field asks. This file is a pointer to the canonical source — DO NOT copy ask text into slide YAML; reference the canonical note instead.

## Source of truth

`memory://work/mcaps/mcaps-internal-asks-finops-toolkit-azure-capacity-ai-cost-may-2026`

73 deduped MCAPS asks from May 2026 field engagements (FastTrack, ICM, account-team interviews). Each ask has:

- `num` — the ask number (1–73)
- `theme` — verbatim text of the customer ask
- `cluster` — which deck cluster (P1.1, P1.2, … H.1–H.5) addresses it
- `addressed_in` — slides that cite it

## How asks appear in YAML

Two places:

### 1. `asks_verbatim:` on the slide

A list of dicts with `num` + `theme`. The `theme` text is verbatim — copy-paste from the canonical memory note. Do not paraphrase.

```yaml
asks_verbatim:
  - num: 7
    theme: "Customers want a single pane that shows quota, spend, and usage together."
  - num: 23
    theme: "Reps need a way to triage capacity issues without paging the platform team."
```

The `notes:` claims on this slide must trace to one of these themes. If the narration claims something not in `asks_verbatim`, either:

- Add the supporting ask to `asks_verbatim` (and verify it exists in the canonical memory)
- Rewrite the narration to remove the unsupported claim

### 2. `layout.addresses:` on ASK_A/B/C slides

For V8 SRE cluster slides (`P1.x.A/B/C`, `P2.x.A/B/C`, `H.1`–`H.5`), `layout.addresses:` is a list of ask numbers (ints) that render as a pill chip on the slide:

```yaml
layout:
  kind: ASK_A
  addresses: [7, 23]
  verdict: null
```

Both `asks_verbatim` and `layout.addresses` should agree — the `num` values in `asks_verbatim` should be a superset of `layout.addresses`. The lint script flags mismatches.

## Banned phrases

These tokens are research / metadata language. They should never appear in slide `notes:` (the spoken voiceover):

- `MCAPS ask #N` — narration says "what customers ask for" not "MCAPS ask number twenty-three"
- `corpus` — research jargon
- `evidence pack` — research jargon
- `ICM-XX-NNNNN` — case IDs are metadata, not narration
- `FastTrack engagement` — internal program name
- `field research` — internal terminology

The `attribution` slot on `ASK_A` slides DOES carry case IDs (rendered visually below the pull quote), but the `notes:` spoken script does not.

## Adding new asks

If a slide needs to claim something not in the canonical 73 asks:

1. Verify the claim is real (file evidence, customer quote, ICM reference)
2. Add the ask to the canonical memory note via maenifold (don't fork the source)
3. Use the new `num` in slide YAML
4. Run the lint script — it should pass

Don't invent ask numbers. Don't claim asks that aren't grounded.

## Lookup

For a quick lookup of which slide cites which ask:

```bash
cd src/templates/sre-agent/training/release-deck
grep -l 'num: 7' slides/   # all slides citing ask 7
```

For the full ask catalog: `ReadMemory memory://work/mcaps/mcaps-internal-asks-finops-toolkit-azure-capacity-ai-cost-may-2026`
