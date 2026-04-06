---
description: Walk through the release checklist interactively
allowed-tools: Read, Grep, Bash(gh issue view *), Bash(pwsh -Command ./src/scripts/*), Bash(pwsh -Command "./src/scripts/*)
---

# Release

## Phase 1: Setup

```bash
pwsh -Command "./src/scripts/Start-Release.ps1 -OutputFile (Join-Path ([System.IO.Path]::GetTempPath()) 'ftk-release.json')"
```

Read the JSON file from the temp path printed in the output. Report the release issue URL and milestone summary to the user.

## Phase 2: Core features

Do the following in parallel:

1. **Launch background build/test agents.** Use the Task tool for each. Only return output on failure; on success return a one-line confirmation.

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

### Next actions

After all triage and build/test results are reported, analyze the kept milestone items and suggest concrete next actions:

- PRs from others awaiting the user's review
- The user's PRs that have reviewer feedback to address
- Issues with no open PRs and no one actively working them

Present as a prioritized list — no AUQ needed, just a summary the user can act on.
