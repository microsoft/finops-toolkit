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

Group the milestone issues and PRs into logical categories based on their titles and labels. Then present them to the user in a layered AskUserQuestion flow:

**Round 1: Bulk triage by group.**

For each logical group of issues/PRs (e.g., "DevOps improvements", "Documentation updates", "Feature X"):

- Write a concise question (max 100 words) summarizing what the group is about. Include issue/PR numbers, short titles, and their Summary field from the JSON data to give the user enough context to decide without reading each issue.
- Options: "Keep all in this release (Recommended)", "Push all to next release", "Review individually"
- Do NOT do deep analysis of each issue. Use the title, labels, and summary excerpt from the data.
- Present up to 4 groups per AskUserQuestion call.

**Round 2: Individual review (only for groups where user chose "Review individually").**

For each issue/PR in that group:

- Summarize in one line what the issue is about.
- Options: "Keep in this release", "Push to next release", "Investigate further"
- If "Investigate further" is chosen, read the issue body and comments via `gh issue view {number}`, then provide a deeper analysis and re-present the decision.

**After triage:**

Report which items are staying and which are being pushed. Do NOT move milestones automatically — just report the recommendations for the user to act on.

#### Build/test results

After triage is complete (or if triage finishes quickly), check on the background agents. Report results:

- If all passed, report a brief summary.
- If any failed, show the failure output and ask the user how to proceed.
