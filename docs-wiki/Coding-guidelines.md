<!-- markdownlint-disable MD041 -->

On this page:

- [ℹ️ General guidelines](#ℹ️-general-guidelines)
- [🔤 Content (strings and microcopy)](#-content-strings-and-microcopy)
- [⚡ KQL](#-kql)
- [📋 Changelog](#-changelog)

---

## ℹ️ General guidelines

We strive to auto-enforce coding standards as much as possible and follow common practices you'll find in other projects to simplify onboarding.

Here's a quick run-down of the main points:

- Install the recommended extensions in VS Code to apply guidelines and auto-format code on save.
- Document everything.
- Documentation should be inline, with the code.
- Every folder should have a README.
- Add inline comments to all major code blocks.
- Resolve all lint errors before submitting PRs.
- Follow standard language conventions:
  - [PowerShell guidelines](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
  - [Bicep lint rules](https://learn.microsoft.com/azure/azure-resource-manager/bicep/linter)
  - [KQL best practices](https://learn.microsoft.com/azure/data-explorer/kusto/query/best-practices) – see [KQL](#-kql) below for the project-specific rules

<br>

## 🔤 Content (strings and microcopy)

We adhere to the [Microsoft style guide](https://docs.microsoft.com/style-guide/welcome). There's a ton to keep in mind in this space, from capitalization to terms to specific phrasing and more. A few quick tips to be aware of:

- Use bigger ideas, fewer words
- Write like you speak
- Project friendliness
- Get to the point fast
- Be brief
- When in doubt, don't capitalize – Always use sentence casing, not Title Casing, unless it's a product name.
- Avoid end punctuation on titles, headings, subheads, UI titles, and items in a list that are three or fewer words.
- Remember the last comma – Always use a comma before "and" and "or" in a list of 3 or more items.
- Don't be spacey
- Revise weak writing

[Learn more](https://docs.microsoft.com/style-guide/welcome)

<br>

## ⚡ KQL

Hub KQL runs over every ingested row, so string matching and join choices show up directly in ingestion cost, query latency – and, if a join fans out or deduplicates unexpectedly, in the correctness of every downstream number. Three rules cover most of it: **never wrap a column in `tolower()` to compare it**, **pick `has` vs `contains` by matching intent**, and **never write a `join` without an explicit `kind`**.

### String matching

Two facts about the engine drive everything below:

1. **Case:** every plain string operator is already case-insensitive (`has`, `contains`, `startswith`, `endswith`, `=~`, `in~`). The `_cs` suffixed forms (and `==`, `in`) are the case-sensitive ones. `tolower()` on a column therefore adds a per-row allocation and blocks index use, with no behavioral benefit.
2. **Terms:** string columns are tokenized at ingestion – runs of alphanumeric characters become *terms*, and punctuation (`/`, `.`, `-`, space) separates them. `has` matches whole terms; `contains` scans for an arbitrary substring: `Col has 'Windows'` does not match `WindowsServer`, `Col contains 'Windows'` does. Both are case-insensitive.

That gives each operator its own set of valid cases:

- Use **`has`** when the needle is a whole term, or a separator-bounded phrase – `ResourceId has '/microsoft.capacity/reservationorders/'` respects the surrounding separators exactly like `contains` would, and still uses the term index. Needles that are pure punctuation (`has '/'`) or shorter than three characters fall back to a scan but keep term-bounded semantics; prefer `has` there anyway for consistency.
- Use **`contains`** only when the needle can be fused inside a larger token and you want to match anyway – `ConsumedUnit contains 'MB'` (which also matches `Mbps`), word stems (`'Trial'` inside `'Trials'`), and fragments that never form a whole term. It always scans.

| ❌ Avoid | ✅ Prefer | Why |
| --- | --- | --- |
| `tolower(Col) contains 'term'` | `Col has 'term'` *or* `Col contains 'term'` | Drop the `tolower()` unconditionally (fact 1); then pick the operator by intent (fact 2) – moving to `has` is a semantic change, so verify it |
| `tolower(Col) == 'value'` | `Col =~ 'value'` | `=~` compares case-insensitively without materializing a lowered copy per row – measured ~5× less CPU and ~4.5× lower latency than `tolower(Col) ==` over a 29.7M-row hub `Costs` table, and the [official best practices](https://learn.microsoft.com/kusto/query/best-practices) call this pair out verbatim. When the stored casing is known and fixed, plain `==` is the documented first choice (it measured the same as `=~` on that table) |
| `tolower(a) != tolower(b)` | `a !~ b` | One comparison instead of two per-row allocations |
| `Col =~ 'a' or Col =~ 'b'` | `Col in~ ('a', 'b')` | One predicate the optimizer can index instead of a disjunction chain |
| `Col has 'a' or Col has 'b'` | `Col has_any ('a', 'b')` | Same – and `has_all` for the `and` chain |
| `Col contains 'Windows'` | `Col has 'Windows'` – only after verifying | Whole-word needle, but this is a behavioral change: `contains` also matches fused tokens (`WindowsServer`). Swap only when term-bounded matching is what you mean, and verify as below |
| `indexof(Col, 'x') >= 0` | `Col has 'x'` *or* `Col contains 'x'` | Don't compute a position you don't need – but pick the operator by intent, not mechanically: `indexof()` is case-**sensitive** and substring-based, so it is equivalent to `contains_cs`, not to `has` |
| `tostring(Dyn.Field) =~ 'true'` | `Dyn.Field =~ 'true'` | These operators accept a *scalar* dynamic operand directly – see the note below |

> [!IMPORTANT]
> Only compare a dynamic field this way when it holds a **scalar** (string, bool, or number), as `x_SkuDetails.AHB` does. If the field can hold an object or an array, the comparison runs against its JSON serialization, which is rarely what you want: `has` matches a value nested anywhere inside the JSON text, so `{"nested":"true"} has 'true'` is `true` while `=~ 'true'` is `false`. Adding `tostring()` does not change this — it produces the same JSON text and the same result. Extract the value you actually mean instead (for example `Dyn.Field.nested`), or compare with `array_index_of()` / `set_has_element()` for arrays.

**Verify before you swap.** Switching `contains` to `has` changes matching semantics, so treat it as a behavioral change until proven otherwise. Cross-tabulate both directions on real data (`countif(old != new)` must be `0` – equal aggregate counts can hide offsetting false positives and negatives), and add fixtures to the executable harness at `src/powershell/Tests/assets/StringOperatorEquivalence.kql`, which runs on any Kusto database and returns zero rows when it passes.

These rules are enforced on every pull request by `src/powershell/Tests/Unit/HubsKqlOperators.Tests.ps1`: `tolower()` in comparison position fails the build, and each `contains` usage must be listed in that test's allowlist with a justification.

### Joins and lookups

Three facts about the engine drive everything below:

1. **The default join flavor is a trap.** A bare `| join (T) on Key` means `kind=innerunique`, which *deduplicates the left side on the join key* – one arbitrary row survives per key value. This has caused real, silent data loss in shipped queries (savings plan recommendations collapsing to one row per subscription; SQL VMs with duplicate names disappearing – see PR #2225). Azure Resource Graph uses the same default.
2. **`lookup` is the purpose-built form of the dimension join.** For enriching a large fact table from a small reference table, `lookup` assumes big-left/small-right (the *opposite* of `join`'s sizing assumption), broadcasts the right side (must fit in a few tens of MB), and does not emit duplicated key columns – no `Key1` to `project-away`. It only supports `kind=leftouter` (default) and `kind=inner`.
3. **Both `join` and `lookup` return every match.** Neither deduplicates the right side: a dimension table with more than one row per key multiplies your fact rows. The open-data `Services` table has 30 resource types with duplicate rows (up to ×31 for `microsoft.sql/locations`) – joining its raw projection multiplied cost for those types until PR #2225 added an explicit dedup.

That gives each operation a canonical form:

- **Enrichment** (add columns from a small, key-unique reference): `| lookup kind=leftouter (Dim | summarize take_any(Col1), take_any(Col2) by Key) on Key`. The `summarize ... by Key` guarantees one row per key; `distinct Key, Col1, Col2` does **not** (it deduplicates whole rows, not keys).
- **Filtering** (keep left rows that have a match): `join kind=inner` against a `distinct` right side – or `kind=leftsemi`, which adds no columns at all.
- **Exclusion** (keep left rows with *no* match): `join kind=leftanti`. Never emulate it with `kind=leftouter` + `where isempty(RightKey1)` – if two right rows match, `leftouter` duplicates the left row *before* the `isempty` filter runs, and every downstream `count()`/`sum()` inflates.
- **Comparison across two periods**: `kind=fullouter` is correct (and `lookup` cannot express it) – but coalesce the key columns afterwards (`| extend Key = coalesce(Key, Key1) | project-away Key1`), or rows that exist only on the right render with empty keys.

| ❌ Avoid | ✅ Prefer | Why |
| --- | --- | --- |
| `\| join (T) on Key` | `\| join kind=... (T) on Key` | Bare join = `innerunique`: left side deduplicated per key, rows silently dropped. State the intent, always |
| `\| join kind=leftouter (SmallDim) on Key` | `\| lookup kind=leftouter (SmallDim) on Key` | Fact-to-dimension enrichment is what `lookup` is for: broadcast, no duplicated key column. (ADX / Log Analytics only – ARG has no `lookup`) |
| `lookup (Dim \| distinct Key, Col1, Col2) on Key` | `lookup (Dim \| summarize take_any(Col1), take_any(Col2) by Key) on Key` | `distinct` over multiple columns still yields >1 row per key when the other columns differ – fact rows multiply |
| `join kind=leftouter (X) on K \| where isempty(K1)` | `join kind=leftanti (X) on K` | `leftanti` is duplicate-proof and never materializes right-side columns |
| `summarize Total=... \| join ... on 1 == 1` | `let Total = toscalar(...)` | `on 1 == 1` is not valid KQL (verified: fails with `General_BadRequest`); `toscalar()` also avoids a second full-table scan |
| `BigTable \| join kind=inner (OtherBigTable)` | smaller table on the **left**, or `hint.strategy=shuffle` / `hint.shufflekey` | `join` assumes the left side is the smaller one; large-to-large joins need the shuffle strategy. `hint.strategy=broadcast` is the manual spelling of what `lookup` does automatically |

> [!IMPORTANT]
> **Azure Resource Graph is not ADX.** ARG queries (workbooks, recommendation queries, the alerts logic app) support only a subset of join flavors (`inner`, `innerunique`, `leftouter` per the [ARG docs](https://learn.microsoft.com/azure/governance/resource-graph/concepts/query-language)), no `lookup`, no join hints, and a documented limit of 3 joins per query. The explicit-`kind` rule is therefore the *only* available defense there – and the `innerunique` default was verified live: a 40-row left side with one distinct key returns 1 row from a bare join and 40 from `kind=inner`.

**Verify before you swap.** Converting `join` to `lookup` drops the duplicated key columns (`Key1`) from the output – confirm nothing downstream references them. Adding a dimension dedup changes which row wins for duplicate keys – confirm the surviving values are equivalent (or pick deterministically with `arg_max()`). For conversions on hub transforms, run the old and new pipeline over the same data and compare row counts *and* values, not just execution success.

These rules are enforced on every pull request by `src/powershell/Tests/Lint/KqlJoinKinds.Tests.ps1`: any `join` without an explicit `kind=` fails the build, across every KQL-carrying surface (hub scripts, query catalog, workbooks, recommendation queries, the alerts logic app, optimization engine, and published docs). Pre-existing bare joins are baselined per file as a ratchet – counts can only go down, and lowering the baseline is enforced when a file is cleaned up (#2228 tracks the backlog).

<br>

## 📋 Changelog

The [changelog](../docs-mslearn/toolkit/changelog.md) documents user-facing changes for each release. It follows [Keep a Changelog](https://keepachangelog.com) conventions adapted for this project's multi-tool structure.

### Structure

```markdown
## v{version}

_Released {Month} {Year}_

### [{Tool name}]({doc-link}) v{version}

- **Added**
  - Entry text ([#{issue}](url)).
- **Changed**
  - Entry text ([#{issue}](url)).
- **Fixed**
  - Entry text ([#{issue}](url)).
- **Deprecated**
  - Entry text ([#{issue}](url)).
- **Removed**
  - Entry text ([#{issue}](url)).
```

### Rules

- **One version section.** All changes for the upcoming release go in a single version section. Do not create duplicate sections.
- **Unreleased section.** Only for changes merged to feature branches that are not yet in `dev`. Once in `dev`, move to the version section.
- **Category order.** Added, Changed, Fixed, Deprecated, Removed. Omit empty categories.
- **Tool sections.** Group by tool using H3 headings with a link to the tool's doc page and the version number (e.g., `### [FinOps hubs](...) v14`). Match the tool order from previous releases.
- **Entry format.** Start with a past-tense verb (Added, Changed, Fixed, Removed, Updated). End with a period. Follow the [content guidelines](#-content-strings-and-microcopy).
- **Issue links.** Link to the GitHub issue when one exists: `([#{number}]({url}))`. Omit when no issue applies (e.g., minor doc fixes).
- **One line per change.** Each entry should be a single concise sentence. Sub-bullets can provide context but keep the overall entry brief.
- **No filler.** Omit entries like "Various bug fixes and improvements" or "Minor code cleanup." Every entry should describe a specific, user-facing change.
- **No implementation details.** Write for users, not developers. "Fixed dashboard freezes during large report generation" not "Fixed async loop timing in render pipeline."
- **Breaking changes.** Prefix with `**Breaking:**` and list first within the category.
- **Within-category ordering.** Breaking changes first, then by importance to users.
- **Brevity over verbosity.** Aim for the minimum words that convey the change and its impact. A changelog is a summary, not documentation.

<br>
