---
description: Review other authors' PRs and update your own PRs in a milestone
argument-hint: [milestone]
allowed-tools: Read, Edit, Write, Glob, Grep, Agent, Skill, AskUserQuestion, Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr checkout:*), Bash(gh pr comment:*), Bash(gh pr edit:*), Bash(gh api:*), Bash(git fetch:*), Bash(git show:*), Bash(git status:*), Bash(git branch:*), Bash(git worktree:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(bicep build:*), Bash(pwsh:*), Bash(npm run:*)
---

# Sweep milestone PRs

Runs one pass over every open, non-draft PR in a milestone: `/pr-review --auto` on other authors' PRs and `/pr-update --auto` on your own. Each PR gets exactly one review or one update. No loop: never re-review after an update, never run `/pr-loop`. Never merges.

**Input:** `$MILESTONE` (title, e.g., `v16`). If omitted, use the current milestone: run `git fetch origin dev`, then read the version with `git show origin/dev:package.json` (not the working tree, which depends on the checked-out branch). The `vN` milestone matches its major version (for example, `16.0.0-dev.0` is `v16`). Ask only if that can't be determined.

## Process

1. **List.** Current user: `gh api user --jq .login`. Then (oldest first, per `ftk-agents-shared.md`):

   ```bash
   gh pr list --state open --milestone "$MILESTONE" --limit 1000 --json number,title,author,isDraft,headRefName --jq 'sort_by(.number)'
   ```

   Skip drafts (list them as `skipped: draft`). Zero PRs: report that and exit.

2. **Review other authors' PRs** in subagents, up to 4 at a time. If you have no Agent tool, return the briefs for the main session; never fake delegation.
   - One throwaway worktree per PR (`git worktree add --detach ../pr-{n}-review origin/dev`) so parallel reviews never share a checkout; remove it afterward.
   - Brief: `/pr-review {n} --auto` inside that worktree. `/pr-review` checks out with `--detach`, so a branch open in another worktree doesn't block it. No commits, no pushes. Nothing is posted; return findings for a maintainer to relay.
3. **Update your own PRs** (author = current user) in the main session, one at a time, in the main checkout: `/pr-update {n} --auto`. Not in a subagent: `/pr-update` needs approval before it commits and pushes, and only the main session can ask for it. Worktree isolation also fails here because `gh pr checkout` refuses a branch already checked out elsewhere.
4. Don't merge, push to `dev`, force-push, or rebase. Brief format per `ftk-agents-shared.md`.
5. **Collect** each PR's one-line result and escalations. A failed review subagent or a blocked update is `🚧 blocked` with its reason.
6. **Report** (and nothing else):

```
| PR | Title | Mode | Result | Posted | Pushed |
| -- | ----- | ---- | ------ | ------ | ------ |
| #N | ...   | update/review | ✅/🚧 | n | sha/no |

Escalations (need you):
- #N file:line: {what's unsure, lean}
```

End with "awaiting your call on escalations" or "no escalations".

## Done when

- [ ] Every open, non-draft PR in the milestone has a result row
- [ ] Other authors' PRs reviewed once; your own PRs updated once in the main session; no loop
- [ ] Nothing merged; escalations listed once
