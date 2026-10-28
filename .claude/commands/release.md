---
description: Walk through the release checklist interactively
allowed-tools: Read, Grep, Write, Edit, Bash(git fetch *), Bash(git checkout *), Bash(git switch *), Bash(git pull *), Bash(git add *), Bash(git commit *), Bash(git push *), Bash(git status*), Bash(git diff*), Bash(git log*), Bash(git branch *), Bash(gh issue view *), Bash(gh issue edit *), Bash(gh issue comment *), Bash(gh issue close *), Bash(gh pr view *), Bash(gh pr list *), Bash(pwsh -Command ./src/scripts/*), Bash(pwsh -Command "./src/scripts/*")
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

**After triage:** Report which items are staying, pushed, or skipped. Apply changes via `gh issue edit {number} --milestone {version}` — this works for BOTH issues and PRs. Do NOT use `gh pr edit` (not in allowed-tools). Run one command per item, not chained with `&&`.

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

Use Grep to find all `<div id="whats-new">` blocks in `/docs/`, then use the Read tool to inspect each match. Do NOT use `sed`, `cat`, `head`, or `tail` — they are not in allowed-tools. For each block: if the tool has a section in the changelog, uncomment the block (if needed) and update the month, year, version tag, and paragraph with a 1-2 sentence summary. If the tool has no changelog section, comment out the block.

### FinOps hubs documentation

Review the changelog's FinOps hubs section and update the following files for any applicable changes. Hub schema version changes (e.g., v1_0 → v1_2) are the primary trigger — update the upgrade guide (steps 7 and 8), data model, data processing, and compatibility chart. Also review for other changelog-driven updates like new datasets, renamed columns, or deprecated functions.

- @docs-mslearn/toolkit/hubs/upgrade.md
- @docs-mslearn/toolkit/hubs/data-model.md
- @docs-mslearn/toolkit/hubs/data-processing.md
- @docs-mslearn/toolkit/hubs/compatibility.md

### New tool check

If `NewTools` in the JSON lists any new tools (tool sections in this release's changelog that weren't in the previous release), present via AskUserQuestion:

- **Header:** "New tools"
- **Question:** "{count} new tool(s) in this release: {names}. These may need marketing pages, MS Learn docs, TOC entries, and an advisory council update. Are all set up?"
- **Options:** "Yes, all done", "No, help me set them up", "Skip for now"

If the user chooses "No, help me set them up":

1. For each new tool, ask via AskUserQuestion what type it is (new standalone tool, new open data file, new sub-tool like a PBI report or workbook or hub add-on).
2. Based on the type, check if MS Learn and marketing pages exist. Report what's missing.
3. Enter plan mode to create missing pages and update TOC/advisory council. Stage these changes for the upcoming Commit and push step (don't commit separately).
4. After plan mode executes, summarize what was added and say "Review changes and say 'done' when ready to proceed."

If the user chooses "Skip for now", note it in the release readiness summary as an outstanding item so it isn't forgotten.

### Commit and push

Show a summary of all changelog, what's new, hubs docs, and any new tool page changes for the user to review, then ask via AskUserQuestion whether to commit and push to the prep branch. This must happen AFTER the new tool check so any plan-mode-created files land in the same commit.

### Next actions

After commit and push, analyze the kept milestone items and suggest concrete next actions:

- PRs from others awaiting the user's review
- The user's PRs that have reviewer feedback to address
- Issues with no open PRs and no one actively working them

Present as a prioritized list — no AUQ needed, just a summary the user can act on.

---

## Release readiness

Update the release tracking issue checkboxes:

1. Run `gh issue view {number} --json body` and capture the output. Parse the JSON to extract the `body` field, then write it to `/tmp/release-issue-body.md` using the Write tool (not shell redirection).
2. Read the file with the Read tool. Each `/release`-managed checkbox in the template has an HTML comment label like `<!-- release:core -->`, `<!-- release:finalize -->`, `<!-- release:package -->`, or `<!-- release:powerbi -->`. To mark a step complete, find the line containing the matching label and change its `- [ ]` to `- [x]`. Use the Edit tool to write the updated body back to the file. In Phase 2 Release readiness, mark `release:core` complete.
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

### Package Power BI

Power BI packaging reports its own state and saves demo reports with Power BI Desktop, which only runs on Windows.

Package from the release prep branch. Don't wait for the merge to main: the checklist merges to main after the Azure Quickstart Templates review, which can take days. The prep PR stays open until the release is published, so late changes go there. After packaging, commit and push the generated `docs/deploy` files to the prep branch.

Package everything, not only the toolkit zips, and delete `release/` first so no files from an earlier release are left behind. Create the draft GitHub release as soon as `Package-Toolkit` finishes (see "Draft the GitHub release" below) so the files are ready while the rest of the checklist closes.

Before packaging, two things have to be done:

1. The demo hub (`ftk-demo` in the FTK Prod subscription, which holds demo resources and isn't real production) is on this release and has current data, because the demo reports are saved with its data. Run `pwsh -Command "./src/scripts/Deploy-Demo.ps1"` in the background, because it takes 15 to 45 minutes, which is longer than a foreground command can run. It deploys or updates the hub and waits until data is ingested. It fails if the hub still isn't ready after 30 minutes; run it again to keep waiting. Show its warnings verbatim.
2. Someone has signed in to Power BI Desktop on the Windows machine and refreshed one demo project from `release/pbix` by hand, once. That stores the data source credentials and makes the Public sensitivity label available (the label is only needed, and only checked, when sensitivity labels are enabled for the tenant), and the packaging command can't answer a credential prompt. Ask the user to confirm with "done".

On Windows, tell the user not to use the mouse or keyboard until it finishes, then run it in the background, because it takes about an hour:

```bash
pwsh -Command "./src/scripts/Package-PowerBI.ps1 -Unattended"
```

On other platforms, tell the user to run `Package-PowerBI.ps1 -Unattended` on a Windows machine with Power BI Desktop, then paste the final output of that run (the "Power BI release files" block, or `Package-PowerBI.ps1 -Status` from that machine) and say "done". Don't check with `-Status` on this machine: the files are on the Windows machine, and `Package-Toolkit -Build` clears this machine's build.

It takes about an hour (roughly 10 minutes per demo report). If it stops because the reports were built from a test open data URL ("isn't permanent"), rerun it once with `-Build` to rebuild against the main branch; don't use `-Build` otherwise, because it discards reports that are already saved.

Relay its status output verbatim — it says exactly which step is next. If a report can't be saved automatically, relay the failed step and screenshot path, tell the user to run `Package-PowerBI.ps1 -Open` and save that project as PBIX (refresh, Save as PBIX in `release/pbix`, sensitivity "Public" if sensitivity labels are enabled), then say "done" so you can rerun the command to validate and package.

If validation fails, show the reported issues verbatim. Each one names the file and the fix; don't guess at causes.

If this step ran, do not proceed until all three files are complete: PowerBI-kql.zip, PowerBI-storage.zip, and PowerBI-demo.zip. On Windows, `Package-PowerBI.ps1 -Status` exits 0 only when they are; check the exit code and relay its text. On another platform, the pasted output from the Windows machine has to show the final "Power BI release files" block. File existence alone is not enough, because files from a previous release can still be in `release/`.

### Draft the GitHub release

A draft is only visible to maintainers and doesn't create the tag, so it is safe to create early. Create it after `Package-Toolkit` finishes and update it again after Power BI packaging.

1. Create the draft with the files in `release/` (files only, not folders). Skip the agent plugin zips (`agent-plugin.zip`, `claude-plugin-*.zip`, `agent-skills-*.zip`) unless something in `docs/` or `docs-mslearn/` links to them, because the plugins install from the marketplace JSON.

   ```powershell
   $files = Get-ChildItem release -File | Where-Object Name -notmatch '^(agent-plugin|claude-plugin|agent-skills)' | ForEach-Object FullName
   gh release create v{N} --repo microsoft/finops-toolkit --draft --target main --title "{Mmm yyyy} (v{N})" --notes "DRAFT" @files
   ```

2. Write the body from the previous release's body (`gh release view v{N-1} --json body --jq .body`) and this version's changelog section:
   - **New in {Month yyyy}**: one line per tool for new features, each with the tool emoji and a link to its page (don't link individual features).
   - **Updated**: one line per tool for changes and fixes, in the same tool order as the previous release. Keep it to the notable items; don't list every change.
   - **Contributors**: code contributors come from `gh api --paginate repos/microsoft/finops-toolkit/compare/v{N-1}...dev --jq '.commits[].author.login'` (drop bots). List external contributors first, then the regular team members (`@RolandKrummenacher`, then `@MSBrett` and `@flanakin` last), so one-time and occasional contributors stand out. Cross-check against merged PR authors (`gh pr list --state merged --search "milestone:v{N}" --json author`), because a few commits have no GitHub login. Supporters are issue reporters from the milestone (`gh issue list --milestone v{N} --state all --json author`) who aren't contributors, sorted alphabetically. Everyone named in either list must also be in `.all-contributorsrc` with the right contribution types, so check each login and credit what they did, treating every type equally (see "Recognizing contributors" in `CONTRIBUTING.md`): `code` for code PRs, `doc` for documentation PRs, `bug` for issue reporters, `ideas` for feature requesters, `review` for reviewers, `question` for people who answered questions, and any other type that fits. Find missing credits with `./src/scripts/Update-Contributors.ps1 -Milestone v{N}` (a dry run that infers `code`, `doc`, `review`, `bug`, and `ideas` from merged PRs, reviews, and issues), then run `npm ci --ignore-scripts` once and rerun it with `-Apply`, which also keeps the `.all-contributorsrc` diff to the added entries. Commit the changed `.all-contributorsrc`, `README.md`, and `docs/README.md`. The weekly `update-contributors` workflow opens a PR with the same changes, so check for `automation/update-contributors` first. For types the script can't infer, or issue authors it lists as needing a human, add them with `npm run contrib -- {login} {type} [{type}...]` and put the arrays in `.all-contributorsrc` back on multiple lines. Don't skip someone because their type is unclear; credit `code` or `doc` for a merged PR and ask the user about the rest. Tell the user these lists miss reviewers and discussion participants, so they need a final review.
   - **Footer**: copy the previous footer with the version updated. Keep the blog and download links commented out until the release is published.
3. Set the body with `gh api --method PATCH repos/microsoft/finops-toolkit/releases/{id} -F body=@{file}`. Find `{id}` with `gh api repos/microsoft/finops-toolkit/releases --jq '.[] | select(.draft and .tag_name=="v{N}") | .id'`.
4. After Power BI packaging, upload the remaining files with `gh release upload`. `gh` can't find a draft by its `v{N}` tag, so use the `untagged-…` name from the draft's URL: `gh release upload untagged-{hash} release/PowerBI-demo.zip --repo microsoft/finops-toolkit`.

Don't publish the draft. Publishing creates the tag and is done from the checklist.

### Manual steps reminder

After packaging succeeds, inform the user of remaining manual steps documented in the release checklist issue (include a link):

1. Publish release
2. Publish announcements

### Final issue update

Update the release tracking issue checkboxes for finalize-phase items using the same label-based process as Release readiness. Mark `release:finalize` and `release:package` complete. Mark `release:powerbi` complete only when the Power BI gate above is met. Then report completion and wish the user well.
