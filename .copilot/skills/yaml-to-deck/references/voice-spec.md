# Voice rubric — FinOps Toolkit SRE Agent training narration

This is the rubric the V8 release training deck must pass. It applies to the `notes:` field of every slide YAML — that field is the actual ElevenLabs voiceover heard in the final video, not a presenter prompt.

The rubric is built from two sources:
1. **Microsoft Writing Style Guide** — official brand voice guidance (links below)
2. **Audience-fit rules for this deck** — specific to the FinOps Toolkit SRE Agent V8 deck and its real audience

Cite this file by URI when grounding rewrites:
`memory://work/training/v8-deck-voice-rubric` (sync after edits)

---

## Audience (read this first — every other rule serves this one)

The audience is **Microsoft Solution Architects, Customer Success Architects, and FastTrack Engineers — 20+ years of field experience.** Not new hires. Not partners. Not customers.

These people:
- Have already deployed Azure to enterprises larger than most listeners' companies
- Can reverse-engineer a screenshot to find the underlying API in 30 seconds
- Have a calibrated bullshit detector and will dismiss the entire deck after one bad claim
- Don't need the architecture explained — they need the conversation it unlocks
- Will run `cat capacity-daily-monitor.yaml` after the talk and laugh at any cron string that isn't real
- Won't repeat anything they think makes them sound junior

If a sentence reads like it could appear in a partner enablement deck, it's wrong for this audience.

---

## Brand voice — the three Microsoft principles

From [Brand voice — above all, simple human](https://learn.microsoft.com/en-us/style-guide/brand-voice-above-all-simple-human):

1. **Warm and relaxed** — natural, less formal, grounded in real conversations. Contractions. The way an experienced peer talks to another experienced peer over coffee.
2. **Crisp and clear** — to the point. Bigger ideas, fewer words. Make it simple above all.
3. **Ready to lend a hand** — on the listener's side. Anticipate the real need.

For this deck, "warm and relaxed" + "audience is a 20-year SA" together mean: **peer-to-peer, not training-to-junior.** Never explain what they already know. Always respect their time.

---

## Top-10 Microsoft Style Guide rules — applied here

From [Top 10 tips for Microsoft style and voice](https://learn.microsoft.com/en-us/style-guide/top-10-tips-style-voice):

1. **Bigger ideas, fewer words** — *"Ready to buy? Contact us."* not *"If you're ready to purchase Office 365 for your organization, contact your Microsoft account representative."*
2. **Write like you speak** — read it aloud. If it doesn't sound like a friendly conversation, rewrite.
3. **Project friendliness** — contractions: *it's, you'll, you're, we're, let's*. Always.
4. **Get to the point fast** — lead with what's most important. Front-load the keyword.
5. **Be brief** — prune every excess word.
6. **When in doubt, don't capitalize** — sentence case for headings. Proper nouns only.
7. **Skip periods on short list items** — three words or fewer = no period.
8. **Oxford comma** — *Android, iOS, and Windows* not *Android, iOS and Windows*.
9. **Don't be spacey** — one space after periods. No spaces around em-dashes.
10. **Revise weak writing** — start with a verb. Edit out *you can*, *there is*, *there are*, *there were*.

The rule that bites hardest in spoken narration is #10. Read the V8 lint output for examples: `'There are' — passive opener — Microsoft Voice leads with verbs`.

---

## Spoken-voice additions (beyond the written-content guide)

### Sentence shape

- **Lead with verbs.** "Run the daily monitor and the agent posts a verdict to Teams" — not "What the daily monitor does is post a verdict..."
- **Full sentences, not noun fragments.** Banned: *"Quota by region. SKU restrictions by subscription. Capacity reservation allocation versus reserved supply."* — that's slide-narration shorthand, not speech.
- **Vary sentence length.** Two short, one longer, one short again. Avoid metronome rhythm.
- **No bullet-list cadence in prose.** If the YAML `content:` already has the bullets, the `notes:` doesn't repeat them.

### What `notes:` is for

- **Add what the slide can't carry.** Context, why-it-matters-now, the conversational pivot.
- **Never narrate the slide.** The viewer reads it faster than you can speak it.
- **One paragraph per turn of thought.** Use `<br/><br/>` between paragraphs (renders as SSML break in TTS).

### Anaphora (Microsoft branding rule)

From [OneNote branding](https://learn.microsoft.com/graph/onenote-branding) — "first mention uses the full name; subsequent references can use the short name":

| First mention | Subsequent |
|---|---|
| `the FinOps toolkit SRE Agent` | `the agent`, `it` |
| `the Azure Optimization Engine` | `the engine` |
| `Cost Management exports` | `the exports` |

Plural products (`FinOps hubs`) take no article and need no anaphora — they're already grammatical.

### CLI naming (deck-specific)

- **Lowercase `srectl` in `content:`** — that's the literal CLI command.
- **Uppercase `SRECTL` in `notes:`** — that's how it's spoken aloud (avoids "sret-cull" mispronunciations).

---

## What this audience hears as a credibility kill

Every one of these lands as "this person doesn't know what they're talking about" to a 20-year SA:

| Tell | Why it kills |
|---|---|
| Treating a Contoso screenshot as a customer finding | Demo data dressed as evidence — the SA spotted it on the slide |
| Inventing customer percentages or counts | "Customers typically run at 73% of forecast" — first listener with field data laughs |
| Inventing tool names, cron strings, or API surfaces | One `git grep` away from being caught |
| Marketing fluff (`world-class`, `best-in-class`, `revolutionary`, `game-changer`) | This audience uses these words ironically |
| Prescriptive verbs to a peer (`you should`, `you must`, `Monday move`) | They've forgotten more about Monday moves than the deck author has |
| Re-explaining ARM, RBAC, scheduled tasks, managed identity | Wastes their time, signals you think they're junior |
| Research jargon in narration (`MCAPS ask #N`, `corpus`, `evidence pack`, `field research`, `ICM-XX-NNNNN`) | These are metadata for the deck, not part of the spoken voice |
| Passive openers (`There is`, `There are`, `What we have here is`) | Microsoft Voice rule #10 |
| `you can` constructions | Microsoft Voice rule #10 — verb-first instead |
| Restating the architecture diagram in words | Slide already showed it |

If any of those appear in `notes:`, the rewrite isn't done.

---

## What this audience needs from `notes:`

Three categories of value the slide can't carry on its own:

1. **The pivot in the customer conversation that this unlocks.**
   Example: "Walking in with the routing path means the question moves from 'who owns this?' to 'which of these three numbers do you want fixed first?'"

2. **The credibility line — what we ship and what we explicitly don't.**
   Example: "Standard-region SKU evidence is real. Sovereign attestation isn't in this release. Don't blur that boundary in front of finance."

3. **The thing they wouldn't notice from the slide alone.**
   Example: "The card lands in Teams whether the agent ran on schedule or you invoked it on demand — same payload, same routing, no re-explaining."

Pick one of these for each slide's `notes:`. Not all three. Pick the one the audience needs most for THIS slide.

---

## Citation rule — non-negotiable

Every claim about what customers ask for, want, escalate, or care about must trace to one of:

- A numbered MCAPS ask in `memory://work/mcaps/mcaps-internal-asks-finops-toolkit-azure-capacity-ai-cost-may-2026` — referenced via the `asks_verbatim:` field on the slide
- A specific named WorkIQ engagement with a case identifier — referenced via the `memory_refs:` field on the slide (see schema doc)
- The product team's documented design intent — referenced via `memory_refs:`

If a sentence in `notes:` says "customers want X", "we see X", "this typically Ys" — and there's no traceable source — delete it or replace it with a verifiable statement.

The `addresses:` field on `ASK_A`/`B`/`C` slides must be a subset of the `num` values in `asks_verbatim:`. Lint flags mismatches.

---

## Anti-Contoso-confabulation rule

The charts in this deck are **rendered from a Contoso test tenant.** They are illustrations of chart shape and routing logic, not field evidence.

The narration must:
- Describe **what the chart structure shows you** (the columns, the dots, the routing path) — never the specific values
- Say "the screenshot is sample output — your customer's numbers will look different" when the chart is being discussed (the `P1.1.B` baseline does this — match it)
- Never extrapolate Contoso values into customer claims ("customers typically run at..." starting from a Contoso percentage = automatic fail)

This is the rule the SAs will catch first if violated.

---

## Self-check before committing a `notes:` rewrite

Read the `notes:` aloud. Ask each question. Any "no" or "uncertain" = rewrite.

- [ ] If you stripped the slide and just heard this audio, would a 20-year SA pick up something they didn't already know?
- [ ] Does it lead with a verb?
- [ ] Are there contractions where speech would have them?
- [ ] Is any sentence a noun-only fragment? (If yes — that's slide-narration, not speech)
- [ ] Are the paragraphs short enough to breathe between (`<br/><br/>` between them)?
- [ ] Is every claim about customers traceable to `asks_verbatim:` or `memory_refs:`?
- [ ] Are there any banned phrases from the credibility-kill table above?
- [ ] If the chart is being discussed, is it framed as illustration not evidence?
- [ ] Would you say this to a senior peer over coffee, or would you feel embarrassed?

The last one is the one that matters most.

---

## References

- [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/welcome) — top-level entry
- [Brand voice — above all, simple human](https://learn.microsoft.com/en-us/style-guide/brand-voice-above-all-simple-human) — three principles
- [Top 10 tips for Microsoft style and voice](https://learn.microsoft.com/en-us/style-guide/top-10-tips-style-voice) — practical rules
- [Verbs](https://learn.microsoft.com/en-us/style-guide/grammar/verbs) — verb-first construction
- [Word choice](https://learn.microsoft.com/en-us/style-guide/word-choice/) — concision and clarity
- [Use contractions](https://learn.microsoft.com/en-us/style-guide/word-choice/use-contractions) — friendliness
- [Avoid jargon](https://learn.microsoft.com/en-us/style-guide/word-choice/avoid-jargon) — speak human
- [Capitalization](https://learn.microsoft.com/en-us/style-guide/capitalization) — sentence-style
- [Headings](https://learn.microsoft.com/en-us/style-guide/scannable-content/headings) — task-focused
- [OneNote branding](https://learn.microsoft.com/graph/onenote-branding) — first-mention vs. subsequent-mention pattern
