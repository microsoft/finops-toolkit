---
description: Draft a blog announcement for a release, tool, or feature
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, Bash(git status*), Bash(git diff*), Bash(git log*), Bash(ls*)
---

# Announce

Drafts a blog post in `announce/{year}/{yyyy-MM}_{slug}.md` for publishing to the [FinOps Tech Community blog](https://techcommunity.microsoft.com/tag/finops%20toolkit?nodeId=board%3AFinOpsBlog).

**Input:** Optional topic (e.g., `v14`, `commitment discount eligibility data`, `claude plugin`). If omitted, the command identifies candidates automatically.

## Phase 1: Pick a topic

If the user provided a topic, skip to **Phase 2**.

Otherwise:

1. Fetch the recent blog list from `https://techcommunity.microsoft.com/tag/finops%20toolkit?nodeId=board%3AFinOpsBlog` to see what was already announced.
2. Read [@docs-mslearn/toolkit/changelog.md](../../docs-mslearn/toolkit/changelog.md). Identify what's new since the last announced release.
3. Pick **up to 4 candidates**, prioritized in this order:
   1. **New version** — the latest `## v##` section if it hasn't been announced.
   2. **New tools** — H3 sections in this release that didn't exist in the previous release.
   3. **New/added features** — sub-bullets under "Added" that introduce notable capability.
   4. **Other notable changes** — sub-bullets under "Changed" or "Fixed" that address visible pain.
4. Present via AskUserQuestion as a single question with the candidates as options. Always include a "(Recommended)" tag on the highest-priority candidate. The default "Other" option lets the user type something custom.
5. If the user picks "Other" with no clear topic, ask one console question for clarity. Do **not** keep guessing.

## Phase 2: Research

Gather context for the topic:

1. Read the relevant section(s) of [@docs-mslearn/toolkit/changelog.md](../../docs-mslearn/toolkit/changelog.md).
2. Read related docs in `docs-mslearn/` and `docs/` (use Glob/Grep to find them by tool/feature name).
3. Only fall back to source code under `src/` if no docs cover the feature.
4. For release announcements, also read the **prior** release's announcement file in `announce/` for tone reference.

If gaps remain after research, batch up to 4 questions in a **single** AskUserQuestion call. Each question must offer a recommended option. Discovery questions should be about clarifying scope or filling factual gaps — not stylistic preferences.

Only use a second round of AskUserQuestion if the first round didn't give enough clarity. If you still can't get clarity, ask via the console rather than guessing further.

## Phase 3: Outline

Propose an outline.

### For release announcements

The outline is **fixed** — do not invent new sections. Use this structure (matches `announce/2025/2025-08_v12.md` and `announce/2026/2026-02_v13.md`):

1. **Title** — `What's new in FinOps toolkit {N} – {Month} {Year}`
2. **Preview snippet** — 1–2 sentences shown in blog list previews and search results. Lead with the most newsworthy item. No links, no markdown, under ~300 chars. Place under the title as a markdown blockquote (prefix the line with `>`) so it's clearly separable from the intro.
3. **Intro paragraph** — One paragraph: who this release is for, what it emphasizes (themes, not full list), and a "read on for details" hook.
4. **New to the FinOps toolkit?** — Boilerplate intro for new readers. Reuse from the prior release; update links if they changed.
5. **Featured sections** (3–5) — Themed deep-dives on the biggest changes from the changelog. Each gets its own H2 with a benefit-led title (not just the feature name). This is the only part that varies per release. Inline contributor thanks belong here when relevant (e.g., "Thanks to @username for contributing this feature.").
6. **Other new and noteworthy updates** — Bulleted list grouped by tool, covering everything else worth mentioning that didn't get a featured section. Extract from the changelog, rephrase to be user-friendly.
7. **What's next** — Forward-looking paragraph. Reuse and refresh from the prior release.
8. **Social media appendix** (see Phase 4).

The **only** thing to confirm with the user during scoping is **which featured sections to include and in what order**. Generate 3–4 concrete, terminal options up front so the user picks once and is done. Each option must fully describe the resulting outline — no follow-up question needed.

Build the options like this:

1. **Option 1 (Recommended):** the proposed order as a `→`-joined list of section titles.
2. **Option 2:** a meaningful alternative (e.g., reordered to lead with a different theme, or dropping the weakest section to keep it tight at 3).
3. **Option 3:** another meaningful alternative (e.g., swap one featured section for a candidate that didn't make the cut, or extend to 5 by promoting a notable item).
4. **Option 4 (only if relevant):** a third alternative if there's a clear close-call worth offering.

Each option's `description` field must include the full section list it represents — the user reads the full outline in the option, not just a label. The user-supplied "Other" fallback handles freeform changes. Do NOT use vague options like "Reorder them", "Swap one", "Approve", or "Edit" — they all require a follow-up question.

### For non-release posts

Propose an outline tailored to the topic. Aim for 3–6 H2 sections following news/blog best practices:

- **Hook** — Why this matters now (1–2 paragraphs).
- **Problem or context** — What pain or opportunity drives this.
- **The thing** — What's new, with concrete details.
- **How to use it / next steps** — Action-oriented.
- **Related reading** — Links.

Present the proposed outline via AskUserQuestion with options to approve, reorder, or rewrite a specific section. Same rule: no generic "Approve" options.

## Phase 4: Draft

1. Determine the publish month. Default to the current month unless context (release date, scheduled publish date) clearly implies a future month. Don't ask just to confirm — only ask if there's actual ambiguity.
2. Determine the slug. For release announcements, use `v{N}` (e.g., `v14`). Otherwise, use a short kebab-cased topic (e.g., `azure-openai-costs`).
3. Write the draft to `announce/{year}/{yyyy-MM}_{slug}.md` using `Write`.
4. **Tone:** active voice, benefit-led, friendly but not breathless. Match the voice of recent releases in `announce/`.
5. **Microsoft style:** sentence casing for headings (not Title Case), no end punctuation on short headings, follow [Coding-guidelines.md](../../docs-wiki/Coding-guidelines.md) content rules.
6. **Length:** release announcements run ~6–10 minute reads. Featured sections are 2–4 short paragraphs each. Don't pad.
7. **Links:** prefer `aka.ms` short links when they exist (check the changelog for examples). Use full Learn URLs for deep documentation.

### Social media appendix

Append a `## Social media` section at the end of the file with three short blurbs:

- **LinkedIn** — 2–3 sentences, professional tone, includes the blog URL placeholder `{{POST_URL}}` and 1–3 relevant hashtags (#FinOps, #Azure, #FOCUS).
- **Twitter/X** — Under 280 characters, includes `{{POST_URL}}` and 1–2 hashtags.
- **Internal** — One sentence + URL for posting in F2 Slack or similar internal channels.

The blog URL isn't known at draft time, so use `{{POST_URL}}` as a placeholder for the user to fill in after publishing.

## Phase 5: Wrap up

Report the file path and a one-line summary of what was written. Do not commit — the user reviews and commits manually.
