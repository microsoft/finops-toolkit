---
description: Loop review then update on one PR until diminishing returns (max 3 rounds)
argument-hint: [pr-number] [max-rounds]
allowed-tools: Read, Edit, Write, Glob, Grep, Agent, Bash(gh safe *), Bash(git status:*), Bash(git branch:*), Bash(git diff:*), Bash(git fetch:*), Bash(git merge:*), Bash(bicep build:*), Bash(pwsh:*), Bash(npm run:*)
---

# Loop pull request

Repo-scoped version of the `catalyst:pr-loop` skill (same round/exit model; if it's available, its summary format applies). Runs `/pr-review --auto` then `/pr-update --auto` on ONE PR until returns diminish. Unsupervised: it never merges, and anything unsure is escalated, not applied.

**Input:** `$PR_NUMBER`; optional `max-rounds` (default 3, never more).

## Process

1. **Setup.** Verify the PR is open. Check out its branch (stop if the tree is dirty; follow `AGENTS.md` git policy). Create a round ledger: findings, changes, tests, escalations per round.
2. **Title gate.** PR title must be conventional (`type(scope): summary`). Fix it now if not (`gh safe pr-edit` if available; else escalate).
3. **Round (repeat):**
   - **A. Review:** run `/pr-review $PR_NUMBER --auto` in a fresh subagent so it judges the PR as it stands. If you can't spawn subagents (you are one), run it inline and re-read the code, not your earlier reasoning.
   - **B. Update:** run `/pr-update $PR_NUMBER --auto` in the primary agent. Skip if A reported no blockers and no material should-fix.
   - **Bug-fix rule:** every bug fix must come with a test that fails before the fix and passes after (show both runs). No such test, no fix: escalate it.
   - **Tests must pass** before a round closes.
4. **Exit** after each round, first match wins:
   - ✅ **Resolved:** review found no blockers or material should-fix.
   - 📉 **Diminishing returns:** only polish left, or two rounds in a row produced only newly invented should-fix items.
   - 🔁 **No progress:** round changed nothing and resolved nothing.
   - 🚧 **Blocked:** conflict not trivially resolvable, unfixable test failure, or dirty tree. Never force-push or rebase.
   - ⏱️ **Round limit:** `max-rounds` reached.
   Polish, suggestions, and escalations never extend the loop.
5. **Re-check the title** (conventional) before finishing.

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
- [ ] Nothing merged, rebased, or force-pushed; escalations listed
