---
description: Walk through the release checklist interactively
allowed-tools: Read, Grep, Bash(git fetch *), Bash(git checkout *), Bash(git switch *), Bash(git pull *), Bash(git add *), Bash(git commit *), Bash(git push *), Bash(git status*), Bash(git branch *), Bash(gh issue view *), Bash(pwsh -Command ./src/scripts/*), Bash(pwsh -Command "./src/scripts/*)
---

# Release

## Phase 1: Setup

Fetch origin and create a release prep branch (`{username}/{versionTag}-prep`, e.g., `flanakin/v14-prep`) from `origin/dev`. If the branch already exists locally, switch to it and pull. Push the release prep branch. DO NOT push to origin/dev directly!

```bash
pwsh -Command "./src/scripts/Start-Release.ps1 -OutputFile (Join-Path ([System.IO.Path]::GetTempPath()) 'ftk-release.json')"
```

Read the JSON file from the temp path printed in the output. Report the release issue URL and milestone summary to the user.

## Phase 2: Core features

Do the following in parallel:

1. **Launch background build/test commands.** Use Bash with `run_in_background` for each:

   - `pwsh -Command ./src/scripts/Build-Toolkit.ps1`
   - `pwsh -Command "./src/scripts/Test-PowerShell.ps1 -Unit"`
   - `pwsh -Command "./src/scripts/Test-PowerShell.ps1 -Lint"`
   - `pwsh -Command "./src/scripts/Test-PowerShell.ps1 -Integration"`

2. **Triage milestone items** using the layered approach below.

### Milestone triage

Analyze all milestone items and recommend keep vs push for each. The release is expected within ~7 days, so push anything complex unless it's a bug fix or a feature explicitly targeting this release. Use labels, titles, and summaries to judge — don't over-explain your reasoning in questions.

Group items by topic, then present via AskUserQuestion. Use the version tag from the JSON (e.g., "v14") and the next milestone title (e.g., "v15") in option labels.

**Round 1: Bulk triage by group** (up to 4 groups per AskUserQuestion call).

- **Header:** 1-3 word group name
- **Question:** Plain text, no formatting. "{count} items: #{number} {short title}, #{number} {short title}, ..." Titles 3-5 words each.
- **Options:** Recommendation first with "(Recommended)". Always include: "Keep all", "Push all", "Review individually".

**Round 2: Individual review** (only for groups where user chose "Review individually").

- **Header:** "#{number}: {1-3 word title}"
- **Question:** Plain text summary from JSON data, up to 100 words. State your recommendation and why.
- **Options:** "Keep in {version} (Recommended)" or "Push to {next version} (Recommended)" (whichever you recommend first), the other option, and "Investigate further".
- If "Investigate further" is chosen, fetch details via `gh issue view {number}`, provide deeper analysis, and re-present.

**After triage:** Report which items are staying and which are being pushed. Do NOT move milestones — just report for the user to act on.

### Untriaged issues

If `NeedsReview` in the JSON contains any issues, present them for quick triage using the same Round 1/Round 2 pattern. These are issues with the "Needs: Review 👀" label that haven't been triaged yet.

### Build/test results

After triage, check on the background agents. If all passed, report a brief summary. For each failure, show the error output and present via AskUserQuestion with options: "Investigate and fix", "Skip for now".

### Changelog review

Read @docs-mslearn/toolkit/changelog.md and review the current version section against the changelog standard in @docs-wiki/Coding-guidelines.md. Apply fixes directly — no AUQ needed. Specific checks:

- Only one version section for this release (no duplicates).
- Unreleased section should be empty (we release from dev). Flag any content there.
- Tool sections match the order from the previous release. Flag any new tools or reordering.
- Categories in order: Added, Changed, Fixed, Deprecated, Removed. Empty categories omitted.
- Every entry starts with a past-tense verb, ends with a period, follows content guidelines.
- Entries are concise. Trim verbose or implementation-detail-heavy text.
- Issue links present where applicable, formatted as `([#{number}](url))`.
- Breaking changes prefixed with `**Breaking:**` and listed first in their category.
- No filler entries ("various bug fixes", "minor improvements").
- Entries placed in the correct category (e.g., new things under Added, not Changed).

After applying fixes, show a summary of what was changed so the user can review.

### What's new blurbs

Find all `<div id="whats-new">` blocks in `/docs/`. For each: if the tool has a section in the changelog, uncomment the block (if needed) and update the month, year, version tag, and paragraph with a 1-2 sentence summary. If the tool has no changelog section, comment out the block.

Show a summary of all changelog and what's new changes for the user to review, then ask via AskUserQuestion whether to commit and push to the prep branch.

### Next actions

After all triage and build/test results are reported, analyze the kept milestone items and suggest concrete next actions:

- PRs from others awaiting the user's review
- The user's PRs that have reviewer feedback to address
- Issues with no open PRs and no one actively working them

Present as a prioritized list — no AUQ needed, just a summary the user can act on.

### New tool check

If `NewTools` in the JSON lists any new tools (tool sections in this release's changelog that weren't in the previous release), present via AskUserQuestion:

- **Header:** "New tools"
- **Question:** "{count} new tool(s) in this release: {names}. These may need marketing pages, MS Learn docs, TOC entries, and an advisory council update. Are all set up?"
- **Options:** "Yes, all done", "No, help me set them up", "Skip for now"

If the user chooses "No, help me set them up":

1. For each new tool, ask via AskUserQuestion what type it is (new standalone tool, new open data file, new sub-tool like a PBI report or workbook or hub add-on).
2. Based on the type, check if MS Learn and marketing pages exist. Report what's missing.
3. Enter plan mode to create missing pages and update TOC/advisory council. After plan mode executes, commit only the files changed during that phase to the prep branch.
4. After committing, summarize what was added and say "Review changes and say 'done' when ready to proceed."

If the user chooses "Skip for now", note it in the release readiness summary as an outstanding item so it isn't forgotten.

---

## Release readiness

Update the release tracking issue checkboxes:

1. Run `gh issue view {number} --json body --jq .body > /tmp/release-issue-body.md` to save the issue body.
2. Read the file with the Read tool. Replace `- [ ]` with `- [x]` for completed items (match on a unique substring of the checkbox text). Write the updated body back to the file.
3. Run `gh issue edit {number} --body-file /tmp/release-issue-body.md` to push the updates.

Then present a summary and next action via AskUserQuestion:

- **Header:** "Next step"
- **Question:** Summary of release status: triage results, build/test results, changelog and docs updates, items still outstanding (including any skipped new tool setup). End with "What would you like to do next?"
- **Options:** "Continue to finalize release", "Work on outstanding items", "Done for now"

If there are outstanding items (build/test failures not resolved, skipped new tool setup, etc.), recommend "Work on outstanding items" or "Done for now" and explain what needs to be completed before finalizing.

---

## Phase 3: Finalize release

This phase ONLY runs if ALL prerequisites are met (build passes, tests pass, changelog reviewed, docs updated) and the user chooses "Continue to finalize release".

### Package release

Run the packaging command:

```bash
pwsh -Command "./src/scripts/Package-Toolkit.ps1 -Build -CopyFiles"
```

If it fails, show the error and ask whether to investigate or skip.

### Manual steps reminder

After packaging succeeds, inform the user of remaining manual steps documented in the release checklist issue (include a link):

1. Power BI packaging
2. Publish release
3. Publish announcements

### Final issue update

Update the release tracking issue checkboxes for all finalize-phase items using the same process as Release readiness (save body, update checkboxes, push). Then report completion and wish the user well.
