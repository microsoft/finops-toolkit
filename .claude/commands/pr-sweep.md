---
description: Review other authors' PRs and update your own PRs in a milestone
argument-hint: [milestone]
allowed-tools: Read, Glob, Grep, Agent, Bash(gh pr list:*), Bash(gh api user:*), Bash(git status:*), Bash(git branch:*), Bash(git worktree:*)
---

# Sweep milestone PRs

Runs one pass over every open, non-draft PR in a milestone: `/pr-review --auto` on other authors' PRs and `/pr-update --auto` on your own. No loop. Never merges.

**Input:** `$MILESTONE` (title, e.g., `v16`). If omitted, use the current milestone: the `vN` milestone whose number matches the major version in `package.json` (for example, `16.0.0-dev.0` is `v16`). Ask only if that can't be determined.

## Process

1. **List.** Current user: `gh api user --jq .login`. Then (oldest first, per `ftk-agents-shared.md`):

   ```bash
   gh pr list --state open --milestone "$MILESTONE" --limit 1000 --json number,title,author,isDraft,headRefName --jq 'sort_by(.number)'
   ```

   Skip drafts (list them as `skipped: draft`). Zero PRs: report that and exit.

2. **Dispatch** one subagent per PR (review up to 4 at a time; updates one at a time). Subagents can't spawn subagents. If you have no Agent tool, return the briefs for the main session; never fake delegation.
   - **Other author's PR:** `/pr-review {n} --auto`. Create a throwaway worktree per PR (`git worktree add --detach ../pr-{n}-review origin/dev`) so parallel reviews never share a checkout; remove it afterward. No commits, no pushes. Nothing is posted; return findings for a maintainer to relay.
   - **Your PR** (author = current user): `/pr-update {n} --auto` in the main checkout, one at a time. Worktree isolation fails because `pr-checkout` refuses a branch already checked out elsewhere, and the main checkout is often on it.
   - Brief format per `ftk-agents-shared.md`. Don't merge, push to `dev`, force-push, or rebase.
3. **Collect** each subagent's one-line result and escalations. A failed subagent is `🚧 blocked` with its error.
4. **Report** (and nothing else):

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
- [ ] Other authors' PRs reviewed; your own PRs updated; no loop
- [ ] Nothing merged; escalations listed once
