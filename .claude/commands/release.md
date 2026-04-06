---
description: Walk through the release checklist interactively
allowed-tools: Read, Grep, Bash(gh issue view *), Bash(pwsh -Command ./src/scripts/*)
---

# Release

Assists in the FinOps toolkit release process.

## Process

### Phase 1: Setup

Run the setup script and capture its return object to a temp JSON file:

```bash
pwsh -Command "./src/scripts/Start-Release.ps1 | ConvertTo-Json -Depth 5 | Set-Content /tmp/ftk-release.json"
```

Then read `/tmp/ftk-release.json` with the Read tool to get the structured result. Report the release issue URL and milestone summary to the user.

### Phase 2: Core features

After setup completes, do the following in parallel:

1. **Launch background build/test agents.** Use the Task tool to spin up subagents that run these commands. Each agent should capture the full output but ONLY return text to you if there was a failure. On success, return a single short confirmation line (e.g., "Build succeeded" or "Unit tests passed: 342 tests").

   - **Build agent:** `pwsh -Command ./src/scripts/Build-Toolkit.ps1`
   - **Unit test agent:** `pwsh -Command "./src/scripts/Test-PowerShell.ps1 -Unit"`
   - **Lint test agent:** `pwsh -Command "./src/scripts/Test-PowerShell.ps1 -Lint"`
   - **Integration test agent:** `pwsh -Command "./src/scripts/Test-PowerShell.ps1 -Integration"`

2. **Triage milestone items** (while build/tests run). Use the milestone data from the JSON file to triage issues and PRs using the layered approach below.

#### Milestone triage

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

#### Build/test results

After triage is complete (or if triage finishes quickly), check on the background agents. Report results:

- If all passed, report a brief summary.
- If any failed, show the failure output and ask the user how to proceed.
