---
description: Review other authors' PRs and update your own PRs in a milestone
argument-hint: [milestone]
allowed-tools: Read, Edit, Write, Glob, Grep, Agent, Skill, AskUserQuestion, Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr checkout:*), Bash(gh pr comment:*), Bash(gh pr edit:*), Bash(gh api:*), Bash(git fetch:*), Bash(git show:*), Bash(git status:*), Bash(git branch:*), Bash(git worktree:*), Bash(git diff:*), Bash(git rebase:*), Bash(git merge:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(bicep build:*), Bash(pwsh:*), Bash(npm run:*)
---

# Sweep milestone PRs

Runs one pass over every open, authored PR and open, non-draft, non-authored PR in a milestone: `/pr-review --auto` on other authors' non-draft PRs and `/pr-update --auto` on your own. Each PR gets exactly one review or one update. No loop: Never re-review after an update, never run `/pr-loop`. Never merges.

**Input:** `$MILESTONE` (title, e.g., `v16`). If omitted, use the current milestone: Run `git fetch origin dev`, then read the version with `git show origin/dev:package.json` (not the working tree, which depends on the checked-out branch). The `vN` milestone matches its major version (for example, `16.0.0-dev.0` is `v16`). Ask only if that can't be determined.

## Process

The main session only orchestrates: It dispatches subagents, tracks progress, and keeps going until every PR has a result and only items that need the user remain. It never reviews, edits, commits, or pushes itself. Subagents can't spawn subagents, so run this in the main session. If you have no Agent tool, return every brief to the parent session to dispatch; never fake delegation.

1. **List.** Current user: `gh api user --jq .login`. Then (oldest first, per `ftk-agents-shared.md`):

   ```bash
   gh pr list --state open --milestone "$MILESTONE" --limit 1000 --json number,title,author,isDraft,headRefName --jq 'sort_by(.number)'
   ```

   Skip other authors' drafts (list them as `Skipped: Draft`). Zero PRs: Report that and exit.

2. **Approve once.** If you have any PRs of your own, ask once (AskUserQuestion) for approval to commit, push, and sync those PR branches with `dev` per `AGENTS.md`. Never ask again per PR. Without approval, update subagents stop before committing and report `🚧 Blocked`.
3. **Dispatch** one subagent per PR, at most 4 running at a time across reviews and updates. Brief format per `ftk-agents-shared.md`. `/pr-review` and `/pr-update` each create and remove their own throwaway worktree, so parallel subagents never share a checkout.
   - Other authors' PRs: `/pr-review {n} --auto`. No commits, no pushes. Nothing is posted; return findings for a maintainer to relay.
   - Your own PRs: `/pr-update {n} --auto`, with the approval from step 2 in the brief. Update subagents sync with `dev` per `AGENTS.md` (Conflict resolution) when the branch conflicts: Rebase a personal branch and push with lease. This is expected.
4. The orchestrator never merges, pushes to `dev`, rebases, or force-pushes.
5. **Collect** each PR's one-line result and escalations. A failed review subagent or a blocked update is `🚧 Blocked` with its reason.
6. **Report** (and nothing else):

```
| PR | Title | Mode | Result | Posted | Pushed |
| -- | ----- | ---- | ------ | ------ | ------ |
| #N | ...   | update/review | ✅/🚧 | n | sha/no |

Escalations (need you):
- #N file:line: {what's unsure, lean}
```

End with "Awaiting your call on escalations" or "No escalations".

## Done when

- [ ] Every open PR you authored and every open, non-draft PR by others in the milestone has a result row
- [ ] Every PR handled in a subagent (at most 4 at a time); other authors' PRs reviewed once, your own updated once; no loop
- [ ] Nothing merged; escalations listed once
