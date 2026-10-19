---
name: support-report
description: Generate the FinOps toolkit support status report (customers waiting on us, triage queue, S0/S1, customer replies since the last report) and a short draft for the contributor sync Teams chat. Use when asked for a support status, support report, or the scheduled Sun/Tue support check.
---

# FTK support status report

Produce a TLDR support status for maintainers. Read-only: never comment, label, or post anywhere.

## Steps

1. Run the metrics script from the repo root (needs `gh` signed in):

   ```bash
   node .claude/skills/support-report/report.mjs
   ```

   - It compares against the last saved report in `~/.claude/ftk-reports/` (or the last 7 days if none) and saves `support-YYYY-MM-DD.md` and `.json` there.
   - "Waiting on us" means a non-maintainer spoke last, the thread isn't an answered discussion, and it isn't a maintainer-filed issue with no outside reply. Feature requests are counted separately.

2. Add judgment the script can't (keep each to one line, `#N` refs only):
   - **Needs a maintainer:** up to 3 threads where a reply needs a decision, not just an answer. Say what the decision is.
   - **v15/release risk:** any waiting S0/S1 or data-loss thread. Note it for 🧰 Release Manager.
   - **Wins:** threads resolved or answered since the last report (optional, one line).

3. Write the Teams draft (max 6 lines, plain text, no tables) to `~/.claude/ftk-reports/support-YYYY-MM-DD.teams.txt`:

   ```text
   🤖 [AI] FTK support · <date>
   <N> customers waiting on us (<issues> issues, <discussions> discussions) · oldest <X>d · triage <N>
   Since <last date>: <N> team replies, <N> customer replies
   Needs a maintainer: #A (<decision>), #B (<decision>)
   Release risk: <#N or "none">
   Details: <link to the support sweep page, if one exists>
   ```

4. Reply to whoever asked with the TLDR line plus the "Needs a maintainer" line. Nothing else.

## Rules

- Accuracy first: only state counts the script produced; never guess a thread's state.
- Don't post the Teams draft. A maintainer must approve the posting method (see `teams-posting.md`).
- Public text starts with "🤖 [AI]". Plain language, sentence case.
