---
description: Loop review then update on one PR until diminishing returns (max 3 rounds)
argument-hint: [pr-number] [max-rounds]
allowed-tools: Read, Edit, Write, Glob, Grep, Agent, AskUserQuestion, Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr checkout:*), Bash(gh pr comment:*), Bash(gh pr edit:*), Bash(gh api:*), Bash(git status:*), Bash(git branch:*), Bash(git diff:*), Bash(git fetch:*), Bash(git worktree:*), Bash(git rebase:*), Bash(git merge:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(bicep build:*), Bash(pwsh:*), Bash(npm run:*)
---

# Loop pull request

Runs `/pr-review --auto` then `/pr-update --auto` on ONE PR until returns diminish. Unsupervised: It never merges, gets approval for git writes once up front (per `AGENTS.md`), and escalates anything unsure instead of applying it.

**Input:** `$PR_NUMBER`; optional `max-rounds` (default 3, never more).

## Process

1. **Setup.** Verify the PR is open. Ask once for approval to commit, push, and sync this PR's branch with `dev` (per `AGENTS.md`) for the whole loop, and pass it to each `/pr-update`. If a caller's brief already carries that approval, don't ask again. Create a round ledger: Findings, changes, tests, and escalations per round. `/pr-review` and `/pr-update` each work in their own throwaway worktree, so your checkout stays untouched.
2. **Title gate.** The PR title must use conventional commits (`type(scope): Summary`), with a clear, sentence-cased summary an end user can understand (Simplified Technical English) and no AI prefix. It becomes the squash commit title. Fix it now if not (`gh pr edit $PR_NUMBER --title`).
3. **Round (repeat):**
   - **A. Review:** Run `/pr-review $PR_NUMBER --auto` in a fresh subagent so it judges the PR as it stands, not your earlier reasoning. If you can't spawn subagents (you are one), don't review inline: Return the review brief to the parent session and stop. The parent runs the review in a fresh subagent and resumes you with its report.
   - **B. Update:** Run `/pr-update $PR_NUMBER --auto` in this session. Skip only if A reported no findings.
   - **Bug-fix rule:** Every bug fix must come with a test that fails before the fix and passes after (show both runs). No such test, no fix: Escalate it.
   - **Tests must pass** before a round closes.
4. **Exit** after each round, first match wins:
   - ✅ **Resolved:** Review found no blockers or material should-fix.
   - 📉 **Diminishing returns:** Only polish left, or two rounds in a row produced only newly invented should-fix items.
   - 🔁 **No progress:** Round changed nothing and resolved nothing.
   - 🚧 **Blocked:** Sync with `dev` failed, unfixable test failure, pending review awaiting the user, or approval denied. Never force-push except as `/pr-update` allows.
   - ⏱️ **Round limit:** `max-rounds` reached.
     Polish, suggestions, and escalations never extend the loop.

## Report

```
PR {n} {✅|📉|🔁|🚧|⏱️} {reason}: {rounds}/{max} rounds
R1: 🚫{a}→{r} ⚠️{b}→{r} 💡{c} | R2: ...
Applied {x} (bugs {y}, tests added {z}); title {ok|fixed}
Escalate: {item, why unsure, lean} ...
```

## Done when

- [ ] Ran at most `max-rounds`; exit reason stated
- [ ] Each bug fix has a fail-before/pass-after test (or is escalated)
- [ ] Tests pass; branch pushed; PR title is conventional
- [ ] Nothing merged; no rebase or force-push outside `/pr-update`'s `AGENTS.md` sync; escalations listed
