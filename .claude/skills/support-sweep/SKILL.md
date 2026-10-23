---
name: support-sweep
description: Build the FinOps toolkit support sweep, a prioritized queue of open GitHub issues and discussions waiting on maintainers, each with context, a recommended action, confidence, evidence, and a draft reply, published as a review page. Then post only the replies a maintainer approves. Use when asked for a support sweep, reply queue, "what's waiting on us", to refresh or republish the sweep page, or to post approved sweep replies.
---

# FTK support sweep

Build a prioritized reply queue, publish it for review, and post only maintainer-approved replies.

Scripts live in `.claude/skills/support-sweep/`. Run them from the repo root with Node.js (needs `gh` signed in). Never use Python.

Each step writes to `~/.claude/ftk-sweeps/<date>/`, so you can stop and resume at any step:

| File | Written by | What it holds |
|---|---|---|
| `threads.json` | gather | Every open thread, with who spoke last and its snapshot time |
| `threads/<i\|d><n>.md` | gather | Full text of each candidate thread, as triage input |
| `batches.json` | gather | Triage batches of about 15 threads, each with an output file |
| `triage/*.md` | subagents | One triage block per thread (`00-carried.md` holds unchanged blocks from the last sweep) |
| `context.json` | optional | Discussion context `[{n, problem, sofar, open}]` if it isn't inline in the triage blocks |
| `rows.json`, `drafts/`, `support-sweep.html` | build | Bucketed rows, one reply file per draft, and the review page |
| `posted.json` | post | Replies actually posted |

## 1. Gather

```bash
git fetch origin dev
node .claude/skills/support-sweep/gather.mjs
```

- Lists every open issue and discussion. Skips bots and maintainer-authored polls, releases, and announcements.
- Maintainers are flanakin, MSBrett, RolandKrummenacher, and helderpinto, plus anyone with OWNER, MEMBER, or COLLABORATOR association.
- Candidates are threads waiting on us (a non-maintainer spoke last, the discussion isn't answered) plus open bugs where we spoke last 14+ days ago (nudge or close).
- Rerunning the same day only batches threads with no triage block yet. On a new day, triage for threads with no new activity carries over (`--fresh` turns that off).

## 2. Triage

For each batch in `batches.json` whose `out` file doesn't exist yet, start one subagent. Run up to 4 at a time. Give each subagent this brief, filled in:

```text
Triage these FinOps toolkit support threads: <refs>. Each thread's full text is in <sweep>/threads/<ref>.md.
Read .claude/skills/support-sweep/SKILL.md, sections "Triage format" and "Reply rules", and follow them exactly.
Verify claims against origin/dev (git show origin/dev:<path>, git grep -n <text> origin/dev), the changelog, open PRs (gh pr list --search), and docs-mslearn/.
Write one block per thread, in the batch's order, to <sweep>/<out>. Read-only: don't comment, label, close, or change anything on GitHub.
Reply with one line: the file path and the number of blocks.
```

When all batches are done, check that every ref has a block. `build.mjs` lists any threads not triaged yet.

### Triage format

One block per thread, separated by `---`:

```markdown
## #<n> <title> · <S0|S1|S2|S3|Q> · <action> · <HIGH|MED|LOW>
- **Your call:** <one line: the exact decision a maintainer must make> (only when a maintainer must decide)
- **Problem:** <one line: what they're asking> (discussions only)
- **So far:** <one line: who replied and what they said, or "No replies."> (discussions only)
- **Open:** <one line: what's still unanswered> (discussions only)
- **Evidence:** <facts with `path:line` on origin/dev, PR and issue numbers, versions, dates; mark anything unverified>
- **Fix/workaround:** <the fix, a PR that fixes it, or a workaround the customer can use now>
- **Draft reply:**
> 🤖 [AI] @<author> <reply>
```

- **Severity:** S0 data loss, wrong costs, or deploy fails · S1 broken feature with no workaround · S2 workaround exists · S3 cosmetic · Q question with no product defect (discussions).
- **Action:** short and concrete, for example "reply with workaround", "reply + point to PR #2263", "reply and close", "close as stale", "Needs maintainer (positioning call)". The build uses it: "Needs maintainer" or LOW confidence sends the thread to **Needs you**. "close" on a thread we spoke last on sends it to **Close as stale**.
- **Confidence:** HIGH (verified in code or docs), MED (likely, partly verified), LOW (guess, needs a maintainer).
- **Your call:** required when the action needs a maintainer. State the exact decision, for example "Approve v16 for #2014, or close as won't fix?". Not "needs review".
- **Draft reply:** `- **Draft reply:** none (internal)` when no reply is needed, for example maintainer-filed tracking issues.

### Reply rules

These come from maintainer feedback on past sweeps. Follow all of them.

- Start with "🤖 [AI]", then @mention who you're answering.
- Never confirm a bug you haven't tested or seen a contributor confirm. Say what you found and what would confirm it.
- Never cite internal or unreleased bugs, regressions, or tracking issues. Customers only care about a fix or a workaround.
- When a fix exists, point to the PR. Give timelines by milestone ("planned for v16"), never "soon" or "the next release".
- Don't mention close deadlines on old threads ("we'll close this in 14 days").
- If they waited a long time (over 60 days), apologize for the delay in the first sentence.
- For scale questions, position Data Explorer (or Fabric) over the storage reports.
- Plain language, Microsoft style, sentence case. Short paragraphs or bullets. Link Microsoft Learn docs (`https://learn.microsoft.com/cloud-computing/finops/toolkit/...`) over repo paths.
- Don't speculate about roadmaps or make commitments a maintainer hasn't made. If one is needed, add a "Your call" line instead.

## 3. Build and publish

```bash
node .claude/skills/support-sweep/build.mjs
```

- Rechecks each thread's live state (read-only; `--offline` skips it), then buckets and sorts the rows:
  - **Reply now:** a customer is waiting, and it's S0/S1 or they've waited 60 days or less.
  - **Needs you:** waiting on us, and it needs a maintainer decision or has LOW confidence.
  - **Old, reply and close:** waiting on us more than 60 days.
  - **Close as stale / Nudge:** we spoke last.
  - **Internal:** no reply needed. **Responded:** in `posted.json`, or a maintainer replied after the sweep. **Already closed:** closed or answered since.
- Sorts by severity, then wait time. Writes `drafts/<ref>.md` and `support-sweep.html`.
- Prints draft warnings (missing "🤖 [AI]", no apology after a long wait, close deadlines, confirmed bugs, unreleased work, vague timelines, missing "Your call"). Fix the triage block and rebuild before publishing.
- Flags threads with new activity since the sweep. Re-triage those before anyone approves them.

Publish `<sweep>/support-sweep.html` with the Artifact tool (`icon: "inbox"`):

- If `~/.claude/ftk-sweeps/artifact-url.txt` exists, read that artifact first, then publish with `url` set to it so the link stays the same.
- Otherwise publish a new artifact and save its URL to `~/.claude/ftk-sweeps/artifact-url.txt`.
- Reply with the link and one line: counts for Reply now, Needs you, and Old. Link every issue, PR, and discussion you mention as `[#N](https://github.com/microsoft/finops-toolkit/issues/N)`.

## 4. Post approved replies

Post only what a maintainer approves in chat, by number ("post #1769 and #2321"). Approval of one thread never covers another.

For each approved thread:

1. If the maintainer changed the text, save their version to `<sweep>/drafts/<ref>.md`. Keep the "🤖 [AI]" prefix.
2. Reread the whole thread on GitHub (`gh issue view <n> --comments`, or the discussion page). Confirm no maintainer (Michael, Roland, Brett, Helder, or anyone with a maintainer association) has already replied or covered it, even if the script check passes.
3. Dry run, then post:

   ```bash
   node .claude/skills/support-sweep/post.mjs <n> <issue|discussion> <sweep>/drafts/<ref>.md --dry-run
   node .claude/skills/support-sweep/post.mjs <n> <issue|discussion> <sweep>/drafts/<ref>.md
   ```

   - At post time, it refetches the thread and aborts if it's closed, answered, or locked, or if anyone (team or customer) commented or edited after that thread's snapshot. It prints what changed.
   - On abort, show the maintainer what changed, update the draft, and get approval again. Then rerun with `--reviewed-through <time>` using the time the abort message printed.
   - Issues post with `gh issue comment`. Discussions post with the `addDiscussionComment` mutation (`--reply-to <commentId>` for a threaded reply).
   - Each post is recorded in `posted.json`. It refuses to post twice to the same thread in one sweep.
4. After posting, rebuild and republish so the thread moves to **Responded**.

## Rules

- Read-only except posting maintainer-approved replies. No labels, closes, milestone changes, or other edits without explicit approval for that action.
- Accuracy first: only state facts you verified. Mark anything else as unverified, or lower the confidence.
- Node.js or PowerShell only. Never Python.
- Public text starts with "🤖 [AI]".
