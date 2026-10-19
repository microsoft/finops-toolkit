# Sharing the report in the contributor sync Teams chat

Status: **proposal, not approved.** Until a maintainer approves an option, the report is draft-only (`*.teams.txt`), and a maintainer pastes it by hand.

| Option | How it works | Setup | Trade-offs |
|---|---|---|---|
| 1. Manual paste (today) | Maintainer copies `*.teams.txt` into the meeting chat | None | Always works; needs a person each time |
| 2. Teams Workflows webhook (recommended) | A meeting chat member creates a **Workflows** flow: "Post to a chat when a webhook request is received", picks the contrib sync meeting chat, and shares the webhook URL. The report step POSTs an Adaptive Card to it. | ~5 min by a chat member; store the URL as a secret (never in the repo) | Simple, no app registration; posts as "Workflows"; URL is a bearer secret, so rotate if leaked |
| 3. Microsoft Graph | Send `chatMessage` to the meeting chat via Graph with delegated `ChatMessage.Send` | Entra app or user token; tenant consent | Posts as a person; more setup and permission review |

Recommendation: option 2 once approved, with posting gated on a maintainer "ok" in chat for the first few runs.
