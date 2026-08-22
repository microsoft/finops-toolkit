---
description: Use when writing, rewriting, or reviewing Microsoft-branded or customer-facing content, or resolving Microsoft terminology. Covers voice, grammar, punctuation, capitalization, UI text, procedures, accessibility, bias-free and global-ready language, developer content, and the complete Microsoft A-Z word list.
metadata:
    github-path: plugins/microsoft-writing-style/skills/microsoft-writing-style-guide
    github-pinned: d9227efa6c984c13260e3bf869f4b6132cfb3c19
    github-ref: d9227efa6c984c13260e3bf869f4b6132cfb3c19
    github-repo: https://github.com/msbrettorg/microsoft-writing-style
    github-tree-sha: 73d4edd9337016a22a9918497b1ba377449894fb
name: microsoft-writing-style-guide
---
# Microsoft Writing Style Guide

## Purpose

Apply the Microsoft Writing Style Guide to documentation, UI text, error
messages, notifications, marketing copy, emails, slides, procedures, developer
content, and conversational experiences.

Microsoft voice is **warm and relaxed, crisp and clear, and ready to lend a
hand**. Use bigger ideas and fewer words. Write with less head and more heart.

This skill is a pinned, offline reference snapshot. See
`references/source-manifest.md` for its authoritative source commit, coverage,
and synchronization date.

## When to use

Use this skill to:

* Draft content in Microsoft voice.
* Rewrite content for clarity, brevity, accessibility, or global readiness.
* Review content for Microsoft style violations.
* Resolve a specific term, spelling, capitalization, or UI-language question.
* Check procedures, developer documentation, bot content, or error messages.

Don't use it to:

* Rewrite legal or contractual text without legal review.
* Change code identifiers, API syntax, commands, URLs, or literal UI text.
* Replace a product's documented naming conventions.
* Impose Microsoft voice on content for another brand.

## Choose a mode

| Mode | Use when | Result |
|---|---|---|
| **Term lookup** | The user asks which word, spelling, capitalization, or interaction verb to use | Preferred form, concise guidance, example, and source heading |
| **Write** | The user needs new Microsoft-style content | Publication-ready content that follows the relevant rules |
| **Rewrite** | The user provides content to improve | Revised content plus a brief list of material changes |
| **Review** | The user asks for an audit, critique, or compliance check | Severity-ranked findings with exact fixes; no invented issues |

If the user requests more than one mode, do them in this order: **review,
rewrite, write**. Use term lookup whenever another mode encounters a
questionable term.

## Source precedence

Use the most specific applicable guidance:

1. Exact A-Z term entry.
2. Relevant term collection.
3. Topic guidance and content-type rules.
4. Checklist.
5. Quick-reference guidance in this file.

Match literal UI, code, and product names when the task requires it. If two
rules appear to conflict, prefer the more specific rule and explain the
exception only when it affects the result.

For a rule that may have changed after the synchronization date, verify the
live [Microsoft Writing Style Guide](https://learn.microsoft.com/style-guide/)
when live access is available. Otherwise, disclose the snapshot date if
freshness is material to the answer.

## Load only what you need

Never load the full corpus by default.

### Term lookup

1. Search `references/term-index.tsv` for the canonical term.
2. Load the routed A-Z file and read the complete matching `###` section.
3. If the term isn't indexed, search the applicable term collection.
4. Return the preferred form, rule, example, and reference heading.

Example search:

```bash
rg -i '^plugin\t|^plug-in\t' references/term-index.tsv
```

### Topic routing

| Content or question | Load |
|---|---|
| Fast pre-publication scan | `references/checklists.md` |
| Grammar, voice, person, or sentence structure | `references/grammar-and-parts-of-speech.md`, `references/word-choice.md` |
| Punctuation | `references/punctuation.md` |
| Capitalization, acronyms, or numbers | `references/numbers-acronyms-capitalization.md` |
| Typography or text treatment | `references/text-formatting.md` |
| Accessibility or inclusive language | `references/accessibility-and-bias-free-communication.md` |
| Localization or worldwide audiences | `references/global-communications.md` |
| Content strategy, search, responsive content, or URLs | `references/content-planning-and-process.md` |
| Headings, lists, tables, procedures, or UI interactions | `references/scannable-content-and-procedures.md` |
| APIs, code examples, reference docs, bots, or virtual agents | `references/developer-and-bot-content.md` |
| Category terminology or symbols | `references/term-collections-numbers-symbols.md` |
| Keys and shortcuts | `references/keys-and-keyboard-shortcuts.md` |
| Exact word choice | `references/term-index.tsv`, then the routed `references/a-z-term-list-*.md` file |

## Apply the selected mode

### Term lookup

Return:

* **Use:** the preferred form.
* **Guidance:** the rule and important exceptions.
* **Example:** one correct example when useful.
* **Source:** the reference file and heading.

Don't infer a rule from spelling alone. Read the complete term entry.

### Write

1. Identify the audience, content type, intended action, and space constraints
   from the request.
2. Load the smallest relevant reference set.
3. Draft the content with the important information first.
4. Check terminology, accessibility, global readiness, and the applicable
   checklist.
5. Return the finished content. Mention assumptions only when they materially
   affect the result.

### Rewrite

1. Preserve facts, intent, required terminology, placeholders, code, and
   literal UI strings.
2. Fix explicit Microsoft-style violations.
3. Improve structure, clarity, brevity, and scanability without flattening the
   meaning.
4. Return the revised content first.
5. Follow with a short **Material changes** list. Omit it when the user asks
   for only the revised text.

### Review

Review the content type and audience before applying rules. Run the applicable
checklist, look up questionable terms, and deepen the review only in areas
that the quick scan flags.

Use these severities:

| Severity | Use for |
|---|---|
| **Blocker** | Accessibility or inclusive-language failures that exclude readers, or wording that changes required meaning |
| **High** | Explicit terminology, UI, procedure, voice, or capitalization violations that materially affect usability |
| **Medium** | Grammar, punctuation, formatting, consistency, or global-readiness issues |
| **Low** | Optional concision or polish that doesn't correct a clear violation |

For each finding, provide:

```markdown
### [Severity] Short finding

**Text:** "Exact problematic text"
**Fix:** "Exact replacement text"
**Rule:** Category and reference heading
**Why:** One concise explanation
```

Group repeated instances of the same issue. Omit empty severity sections. If
the content has no material issues, say so—don't invent findings.

## Quick reference

| Rule | Guidance |
|---|---|
| Bigger ideas, fewer words | Cut every word that doesn't earn its place |
| Write conversationally | Use familiar words, contractions, and natural phrasing |
| Get to the point | Lead with the information or action customers need |
| Use sentence-style capitalization | Capitalize only the first word and proper nouns unless an exact name requires otherwise |
| Limit end punctuation | Omit periods and colons from most titles, headings, and short UI text |
| Use the serial comma | Write *Android, iOS, and Windows* |
| Use one space | Use one space after periods and colons; don't add spaces around em dashes |
| Prefer active, direct writing | Start with a verb; remove weak *you can* and *there is/are* constructions |
| Write for everyone | Use accessible, bias-free, people-first or preference-aware language |
| Write for the world | Avoid idioms, cultural assumptions, and ambiguous dates or measurements |

## Guardrails

* Don't alter technical meaning to satisfy a style preference.
* Don't replace exact UI text with the preferred generic term.
* Don't flag an exception as a violation.
* Don't claim factual, legal, security, or product accuracy from a style review.
* Don't load or quote large reference sections when a concise answer is enough.
* Cite the reference file and heading when explaining a disputed rule.
