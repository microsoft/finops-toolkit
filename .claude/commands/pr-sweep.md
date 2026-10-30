---
description: Run pr-loop over all open PRs in a milestone (own PRs updated, others review-only)
argument-hint: [milestone]
allowed-tools: Read, Glob, Grep, Agent, Bash(gh safe *), Bash(gh pr list:*), Bash(gh api user:*), Bash(git status:*), Bash(git branch:*)
---

# Sweep milestone PRs

Runs `/pr-loop` autonomously across every open PR in a milestone. Never merges.

**Input:** `$MILESTONE` (title, e.g., `v15`). If omitted, stop and ask.

## Process

1. **List.** Current user: `gh api user --jq .login`. Then (oldest first, per `ftk-agents-shared.md`):

   ```bash
   gh pr list --state open --milestone "$MILESTONE" --limit 1000 --json number,title,author,isDraft,headRefName --jq 'sort_by(.number)'
   ```

   Skip drafts (list them as `skipped: draft`). Zero PRs: report that and exit.

2. **Dispatch** one subagent per PR (up to 4 at a time). Subagents can't spawn subagents, so each runs the loop inline. If you have no Agent tool, return the briefs for the main session; never fake delegation.
   - **Own PR** (author = current user): `isolation: "worktree"`; run `/pr-loop {n}` (review, update, push, reply).
   - **Other author's PR:** review-only. Run `/pr-review {n} --auto` in a clean checkout/worktree; no commits, no pushes, no update. Their findings are for the author.
   - Brief format per `ftk-agents-shared.md`. Don't merge, push to `dev`, force-push, or rebase.
3. **Collect** each subagent's one-line result and escalations. A failed subagent is `🚧 blocked` with its error.
4. **Report** (and nothing else):

```
| PR | Title | Mode | Result | Rounds | Posted | Pushed |
| -- | ----- | ---- | ------ | ------ | ------ | ------ |
| #N | ...   | loop/review | ✅/📉/🔁/🚧/⏱️ | n | n | sha/no |

Escalations (need you):
- #N file:line: {what's unsure, lean}
```

End with "awaiting your call on escalations" or "no escalations".

## Done when

- [ ] Every open, non-draft PR in the milestone has a result row
- [ ] Own PRs looped; others review-only
- [ ] Nothing merged; escalations listed once
