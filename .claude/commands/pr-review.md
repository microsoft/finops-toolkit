---
description: Review a PR for quality, correctness, and project alignment
argument-hint: [pr-number] [--auto]
allowed-tools: Read, Glob, Grep, Bash(gh safe *), Bash(git status:*), Bash(git branch:*), Bash(bicep build:*), Bash(pwsh:*)
---

# Review pull request

Reviews a PR for quality, correctness, and fit with project goals, then posts one review. Never changes code, commits, or pushes.

**Input:** `$PR_NUMBER` (e.g., `123`); optional `--auto`.

- Default: present findings to the user, post what they approve.
- `--auto`: no user step. Post findings that are valid and match the PR's stated intent. Return the rest as an escalation list (never post them).

`{ai-platform}` = the AI platform name (e.g., `Claude`). Every posted comment starts with `🤖 [AI][{ai-platform}]`.

## Process

### 1. Setup

1. Verify the PR (also read prior discussion once; don't re-fetch):

   ```bash
   gh safe pr-view $PR_NUMBER --json number,title,body,state,baseRefName,headRefName,url,author,labels,reviews,comments
   ```

   Stop if the PR is closed or merged.

2. Read `CLAUDE.md` and `docs-wiki/Coding-guidelines.md`, plus READMEs in touched directories.
3. Check out the branch: `gh safe pr-checkout $PR_NUMBER`. Uncommitted changes: stop (ask the user; in `--auto`, return "blocked: dirty tree"). Use absolute paths afterward.
4. Pending review: if you already have a pending (draft) review on this PR, `pr-review-submit` will conflict. Stop and ask (in `--auto`, return as blocked).

### 2. Gather

```bash
gh safe pr-diff $PR_NUMBER
gh safe pr-diff $PR_NUMBER --name-only
```

Read every changed file in full from the working tree, not just the diff. For large PRs (>50 files), start with the highest-impact files and say in the review body what wasn't deeply reviewed.

### 3. Analyze

Review the current code, not the thread history. Reconcile with existing threads only where a finding lands on a commented line (add to it, don't duplicate). Don't re-verify old threads; `isResolved` is unreliable.

**Intent first.** Identify what the PR claims to do (title, body, linked issue/milestone). Findings must serve that intent; don't ask for unrelated work.

- **Quality:** code and content style (`Coding-guidelines.md`, Microsoft style guide, sentence case), lint, naming, comments/help docs, tests for new behavior and edge cases, security (secrets, injection, unsafe params).
- **Correctness:** logic vs. the PR description, null/edge cases, breaking changes to deployments or APIs, parameter validation, error handling. Completeness: if something is renamed/added/removed, grep for other consumers (build allowlists, docs, UI definitions, changelog). If the PR cites a command as proof (build, test), re-run it.
- **Alignment:** FinOps terminology, planned architecture, focused scope (no over-engineering), changelog entry in the next version section, docs updated, no stale references.
- **PR hygiene:** title follows conventional commits (`type(scope): summary`). Flag if not.

### 4. Classify

- 🚫 **Blocker:** bugs, security, breaking changes, data loss.
- ⚠️ **Should fix:** style violations, missing tests/docs, maintainability. Mark each **material** (real correctness, safety, maintainability, or coverage gap) or **polish** (nit, subjective).
- 💡 **Suggestion:** optional improvements.

Add a confidence tag to each: **sure** (verified in code or by running something) or **unsure** (depends on intent, context you can't see, or a judgment call).

### 5. Decide what to post

**Default mode:** consult the user with AskUserQuestion, one question per severity group that has items (plain text, ≤100 words, numbered short items). Options: "Post all (Recommended)", "Review individually", "Skip all". With 5+ items in a group, summarize by theme and offer "Review by category". Individual review options: "Post as-is (Recommended)", "Edit wording", "Downgrade severity", "Skip".

**`--auto`:** no questions. Post a finding only if it is **sure**, valid on the current code, and consistent with the PR's intent. Everything **unsure**, or that would change the PR's direction or scope, goes to the escalation list with one line on why. Never post a guess.

### 6. Post

1. Anchor comments to file lines: `line`/`start_line` are line numbers in the new version of the file (`side: "RIGHT"`) on lines inside the diff. Use the `+` side of the `@@` hunk header to locate them.
2. Verify every ` ```suggestion ` block by running the relevant validator on it in context (`bicep build`, PSScriptAnalyzer/parser, project linter). Suggestions are one-click applicable. If you can't verify it works, convert to prose with no `suggestion` block.
3. Submit one review (always `COMMENT`, never `APPROVE`/`REQUEST_CHANGES`):

   ```bash
   gh safe pr-review-submit $PR_NUMBER review.json
   ```

   ```json
   {
     "event": "COMMENT",
     "body": "🤖 [AI][{ai-platform}] **PR Review**\n\n**Summary:** {1-2 sentences}\n\n### 🚫 Blockers ({n})\n1. ...\n\n### ⚠️ Should fix ({n})\n1. ...\n\n### 💡 Suggestions ({n})\n1. ...",
     "comments": [
       { "path": "src/x.bicep", "line": 42, "side": "RIGHT", "body": "🤖 [AI][{ai-platform}] ⚠️ **Should fix**\n\n{issue}\n\n```suggestion\n{code}\n```" },
       { "path": "src/y.ps1", "start_line": 10, "line": 15, "side": "RIGHT", "body": "🤖 [AI][{ai-platform}] 🚫 **Blocker**\n\n{issue}" }
     ]
   }
   ```

   Omit empty severity sections. If nothing is worth posting, post nothing and say so.

### 7. Report

In `--auto`, return this (also the caller's input for `pr-loop`):

```
PR {n}: {blockers}/{material should-fix}/{polish should-fix}/{suggestions} posted; {k} escalated
Posted: {file:line, severity, material|polish, one line} ...
Escalate: {file:line, one line on what's unsure and your lean} ...
```

### 8. Retrospective (default mode only)

If you hit real friction, propose one concrete edit to this file via AskUserQuestion ("Apply change (Recommended)", "Skip"). Apply uncommitted. No friction: skip.

## CLI reference

Use `gh safe` where it applies; other tools only when it doesn't.

| Command                                     | Purpose                                  |
| ------------------------------------------- | ---------------------------------------- |
| `gh safe pr-view {pr} --json ...`           | PR details, reviews, comments            |
| `gh safe pr-checkout {pr}`                  | Check out the PR branch                  |
| `gh safe pr-diff {pr} [--name-only]`        | Diff or changed files                    |
| `gh safe pr-threads {pr}`                   | Review threads (only to dedupe a finding) |
| `gh safe pr-review-submit {pr} review.json` | Submit a review with line comments       |

## Done when

- [ ] Branch checked out; every changed file read in full
- [ ] Findings classified (severity, material/polish, confidence)
- [ ] Default: user approved posts. `--auto`: only sure, intent-aligned findings posted; the rest escalated
- [ ] Suggestion blocks execution-verified
- [ ] One review posted, `COMMENT` only, every body prefixed `🤖 [AI][{ai-platform}]`
- [ ] No code changes, commits, or pushes
