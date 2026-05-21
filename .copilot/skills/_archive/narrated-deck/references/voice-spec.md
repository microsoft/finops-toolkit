# Voice and tone spec

This document captures the Microsoft Style Guide rules the skill applies when generating narration. The normalizer in `scripts/normalize_text.py` enforces these mechanically — but understanding the *why* helps when you tune the rules or add support for new product names.

## Why these rules exist

Microsoft Learn docs are written for the page. They follow Microsoft style: sentence-case headings, second-person voice, plain language. When read aloud, two patterns cause friction that doesn't show up on the page:

1. **Naked product names at sentence start.** "FinOps toolkit SRE Agent is AI-powered..." reads fine in a paragraph but sounds like marketing-deck staccato when spoken. Adding the article ("The FinOps toolkit SRE Agent is...") restores natural rhythm.

2. **Repeated full product name within a paragraph.** "FinOps toolkit SRE Agent uses X. FinOps toolkit SRE Agent helps Y. FinOps toolkit SRE Agent runs Z." A reader's eye glides over the repetition. A listener doesn't have that option — it sounds like a sales pitch on loop.

The fix is **anaphora**: name the product on first mention, then refer to it as "the agent" / "It" / "the template" depending on context. This is documented in the Microsoft branding guide for OneNote (and applies to all singular products):

> The first mention in a communication should use the full name. Subsequent references can use the short name.

— [learn.microsoft.com/graph/onenote-branding](https://learn.microsoft.com/graph/onenote-branding)

## Rules the normalizer applies

### R1. Article on first sentence-subject mention

Singular product names take the definite article when used as a sentence subject:

| Before | After |
|---|---|
| `FinOps toolkit SRE Agent is...` | `The FinOps toolkit SRE Agent is...` |
| `FinOps toolkit SRE Agent uses Azure CLI.` | `The FinOps toolkit SRE Agent uses Azure CLI.` |

This matches how Microsoft writes about Azure Optimization Engine in the corpus:

> The Azure Optimization Engine (AOE) is an extensible solution designed to generate optimization recommendations for your Azure environment.

— `docs-mslearn/toolkit/optimization-engine/overview.md`

The article is **not** added when:
- The product name appears inside a markdown link (`[FinOps toolkit SRE Agent](...)`) — that's title text, not prose
- The product name is in a code span (`` `FinOps toolkit SRE Agent` ``) — that's an identifier
- The product name is part of a heading or title — those use proper-noun form

Plural product names (`FinOps hubs`, `FinOps alerts`) **don't** take an article — they're already grammatical without one. The normalizer leaves them alone.

### R2. Anaphora on subsequent mentions

After the first mention is introduced, subsequent occurrences in the same scene get replaced:

| Position | Replacement |
|---|---|
| Sentence subject | `It` |
| Mid-sentence | `the agent` (default) or context-specific noun (`the template`, `the deployment`) |

| Before | After |
|---|---|
| `FinOps toolkit SRE Agent helps teams move from dashboards...` | `The agent helps teams move from dashboards...` (paragraph start) |
| `... so the FinOps toolkit SRE Agent can run...` | `... so the agent can run...` (mid-sentence) |

### R3. Split semicolon run-ons

Sentences joined by `; ` are split into two sentences. This applies the Microsoft Style Guide top-10 rule "Be brief":

| Before | After |
|---|---|
| `Use specialist names; for example, ask...` | `Use specialist names. For example, ask...` |
| `The agent responds to natural language; the tool catalog describes...` | `The agent responds to natural language. The tool catalog describes...` |

The normalizer is conservative: it only splits when both clauses can stand alone, detected by the second clause starting with a lowercase verb-bearing word.

### R4. Strip source-citation parentheticals

Inline citations like `([source YAML](path))` are visible noise in TTS output. Pattern matched and removed:

| Before | After |
|---|---|
| `Queries cost trends ([source YAML](.../monthly-cost-trend.yaml)).` | `Queries cost trends.` |
| `Use it for budget reviews ([source YAML](path)).` | `Use it for budget reviews.` |

The link is preserved at the section level via the `Source YAML:` opener line that already heads each tool subsection.

### R5. Paragraph breaks

Between paragraphs, the normalizer inserts an SSML break tag:

```
First paragraph text. <break time="1300ms" /> Second paragraph text.
```

The 1300ms duration is the sum of "0.5s before + 0.8s after" — a brief pause that lets the listener catch up after a topic shift. Within a paragraph, soft-wrap newlines (from bullet lines) are folded together with `. ` joiners so each unit ends with sentence punctuation.

## What the normalizer does NOT do

- **Doesn't paraphrase.** Author voice is preserved verbatim. Mechanical changes only.
- **Doesn't fix grammar.** If the source says "datas" it stays "datas".
- **Doesn't fact-check.** If the source claims wrong numbers, the narration says wrong numbers.
- **Doesn't re-order content.** Scene order matches the doc's H2 order.
- **Doesn't drop content.** It does drop entire `Give feedback` / `Related content` / `Next steps` / `Learn more` sections (they're navigation, not training), but never fragments within a section.

## Adding new product names

To extend anaphora to a new singular product, edit `SINGULAR_PRODUCTS` in `scripts/normalize_text.py`:

```python
SINGULAR_PRODUCTS = [
    ("FinOps toolkit SRE Agent", "the agent"),
    ("Azure Optimization Engine", "the engine"),
    ("Your New Product Name", "the <short noun>"),
]
```

The first tuple element is the full name as it appears in source docs. The second is the short-form noun phrase used for mid-sentence anaphora.

For plural products (already grammatical without "the"), no entry is needed — the normalizer leaves them alone.

## References

- [Microsoft Writing Style Guide](https://learn.microsoft.com/style-guide/welcome) — top-level entry
- [Top 10 tips for Microsoft style and voice](https://learn.microsoft.com/style-guide/top-10-tips-style-voice) — brevity, scannability, voice
- [Capitalization](https://learn.microsoft.com/style-guide/capitalization) — sentence-style headings, proper nouns
- [Nouns and pronouns](https://learn.microsoft.com/style-guide/grammar/nouns-pronouns) — proper noun handling
- [Headings](https://learn.microsoft.com/style-guide/scannable-content/headings) — task-focused headings, not product-focused
- [Microsoft Learn quick start](https://learn.microsoft.com/contribute/content/style-quick-start) — "Include the small words" rule for machine translation
- [OneNote branding](https://learn.microsoft.com/graph/onenote-branding) — first-mention vs subsequent-mention anaphora pattern
