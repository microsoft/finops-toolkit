---
description: Start the next release dev cycle after a release ships
allowed-tools: Read, Grep, Write, Edit, Bash(git fetch *), Bash(git checkout *), Bash(git switch *), Bash(git pull *), Bash(git push *), Bash(git status*), Bash(git diff*), Bash(git log*), Bash(git branch *), Bash(gh api user*), Bash(gh issue view *), Bash(gh issue list *), Bash(gh issue edit *), Bash(gh release view *), Bash(pwsh -Command ./src/scripts/*), Bash(pwsh -Command "./src/scripts/*"), Bash(pwsh -Command ./src/scripts/Test-PowerShell.ps1 -Toolkit -Integration *)
---

# Update version

## Phase 1: Setup

Run the following to get the current version:

```bash
pwsh -Command "./src/scripts/Get-Version.ps1"
```

Parse the output to derive:

- **Released major:** strip any `-dev` or prerelease label, take the major number (e.g., `14.0-dev` → `14`)
- **Released tag:** `v{released major}` (e.g., `v14`)
- **Next major:** released major + 1 (e.g., `15`)
- **Next tag:** `v{next major}` (e.g., `v15`)
- **Changelog month:** today's date + 1 calendar month, formatted as `Mmm yyyy` (e.g., May 2026 → `Jun 2026`)

Get the GitHub username:

```bash
gh api user --jq .login
```

Create and push a new branch from `origin/dev`:

```bash
git fetch origin
git checkout -b {username}/v{next major}-start origin/dev
git push -u origin {username}/v{next major}-start
```

## Phase 2: Automated changes

First, update and validate the integration test:

**Update integration test** — Edit `src/powershell/Tests/Integration/Toolkit.Tests.ps1`:

1. Change `$plannedRelease = '{released major}'` to `$plannedRelease = '{next major}'`
2. Prepend `'{released major}'` to the front of the `$expected` array
   - Example: `$expected = @('13', '12', ...)` → `$expected = @('14', '13', '12', ...)`
3. Fetch the actual file list from the just-released GitHub release:

   ```bash
   gh release view v{released major} --json assets --jq '[.assets[].name] | sort[]'
   ```

   Compare against the `CheckFile` calls in the test. For any file in the release that has no matching `CheckFile` entry, add one with `'{released major}.0'` as both `$minVer` and `$maxVer`. Place new entries near the end of their logical group (Templates, Power BI, Open data, etc.).

Then run the test to confirm:

```bash
pwsh -Command "./src/scripts/Test-PowerShell.ps1 -Toolkit -Integration"
```

If the test still fails, show the error and stop before proceeding.

Then run the following in parallel as background tasks:

1. **Bump version:**

   ```bash
   pwsh -Command "./src/scripts/Update-Version.ps1 -Major -Label dev"
   ```

2. **Add changelog placeholder** — In `docs-mslearn/toolkit/changelog.md`:

   a. Find the `## Unreleased` section and extract any `###` tool sections present there. Then clear the Unreleased section so only the heading and description line remain (no tool sections).

   b. Insert the following block immediately before the `<br><a name="latest"></a>` line, including any extracted content between the navigation links and the closing `<br>`:

   ```markdown
   ## v{next major}

   _Released {Mmm yyyy}_

   {extracted tool sections, if any}

   <!-- prettier-ignore-start -->
   > [!div class="nextstepaction"] > [Download](https://github.com/microsoft/finops-toolkit/releases/tag/v{next major})
   > [!div class="nextstepaction"] > [Full changelog](https://github.com/microsoft/finops-toolkit/compare/v{released major}...v{next major})
   <!-- prettier-ignore-end -->

   <br>
   ```

   Use the computed changelog month for `{Mmm yyyy}`. Use the actual version numbers for `v{released major}` and `v{next major}`.

   **Changelog section format rules:**

   - Each `###` section must be a **tool** (e.g., FinOps hubs, Power BI reports, PowerShell module), not a sub-page, doc page, or feature area.
   - Valid tool sections mirror those used in previous releases: `[Implementing FinOps guide]`, `[FinOps hubs]`, `[Power BI reports]`, `[FinOps workbooks]`, `[Optimization engine]`, `[PowerShell module]`, `[Open data]`, `[Bicep Registry modules]`, and new tools like `Claude Code plugin`.
   - If Unreleased content refers to a **sub-page** (e.g., Configure scopes, Data dictionary), merge it as a bullet under its parent tool section: Configure scopes → FinOps hubs; Data dictionary → Implementing FinOps guide.
   - Use `### [Tool name](link) v{next major}` format for existing tools with docs; use `### Tool name v{next major}` (no link) for new tools whose doc page doesn't exist yet.
   - The `Update-Version.ps1` script automatically creates the `## v{next major}` block after `<br><a name="latest"></a>`. If the script runs first, you only need to move the extracted Unreleased tool sections into the existing block (before the download links), applying the format rules above. Do not create a duplicate block.

3. **Merge dev into feature branches** — Run as a background task:

   ```bash
   pwsh -Command "./src/scripts/Merge-DevBranch.ps1 *"
   ```

   The script always completes and prints a summary like `N merged successfully. N skipped`. Report that summary line to the user. Individual branch errors in the output are expected for branches that require JIT access — they do not indicate a failure.

## Phase 3: Review and commit

After all background tasks complete, show a `git diff` summary of all changed files. Then ask via AskUserQuestion:

- **Header:** "Review changes"
- **Question:** Summarize the changes: version bumped to `{next major}.0.0-dev`, integration test updated, changelog placeholder added for `v{next major}` targeting `{Mmm yyyy}` (and if Unreleased content was moved, note which sections). End with "Ready to commit and push to `{username}/v{next major}-start`?"
- **Options:** "Commit and push", "Make changes first", "Abort"

**On "Commit and push":** Stage and commit all changes, then push:

```bash
git add -A
git commit -m "chore: start v{next major} dev cycle"
git push
```

**On "Make changes first":** Tell the user to make their edits, then commit and push manually to `{username}/v{next major}-start`.

**On "Abort":** Stop without committing.

## Phase 4: Update release tracking issue

Find the current release tracking issue (the one for the release just completed, i.e., `v{released major}`):

```bash
gh issue list --label "Type: Release 🚀" --state open --json number,title
```

If found, mark the `update-version:post` checkbox complete using the same label-based process as `/release`:

1. Run `gh issue view {number} --json body` and capture the output. Parse the JSON to extract the `body` field, then write it to `/tmp/release-issue-body.md` using the Write tool.
2. Read the file with the Read tool. Find the line containing `<!-- update-version:post -->` and change its `- [ ]` to `- [x]`. Use the Edit tool to write the updated body back to the file.
3. Run `gh issue edit {number} --body-file /tmp/release-issue-body.md`.

If no open release issue is found, skip this step and note it to the user.

Report completion with a brief summary: version bumped, integration test updated, changelog placeholder added, branch updates attempted, and issue updated (or skipped).
