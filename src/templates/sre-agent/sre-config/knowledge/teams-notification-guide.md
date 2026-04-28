# Teams notification guide for FinOps SRE Agent

Use this guidance whenever a subagent or scheduled task needs to post results to the Teams channel.

## Correct approach: use the built-in PostTeamsMessage tool

Always use the built-in **PostTeamsMessage** tool to post messages to the Teams channel. This tool handles authentication automatically through the pre-configured Teams connector. You do not need to call the Microsoft Graph API or the connection's dynamicInvoke endpoint directly.

### What works

- Call `PostTeamsMessage` with your message content formatted as HTML.
- The Teams connector handles OAuth and managed identity automatically.
- Updates about the same topic stay in the same thread — use `ReplyToTeamsThread` to continue a conversation.
- Messages include a "Sent by Azure SRE Agent" footer with a UTC timestamp and a link back to the portal thread.

### What does NOT work

- Do NOT attempt to call the Microsoft Graph API directly using the managed identity — the managed identity lacks RBAC permissions on the `Microsoft.Web/connections` resource.
- Do NOT call the connection's `dynamicInvoke` endpoint directly — this will return a 403 Forbidden error.
- Do NOT use raw HTTP requests to Teams webhooks — the connector abstraction is the supported path.

## Scheduled task delivery pattern

All scheduled tasks in this FinOps SRE Agent include a final `## Deliver` section that instructs the agent to post the completed report to the Teams channel. The key rules are:

1. Complete all analysis and report formatting first.
2. Post only the **final completed report** to Teams — not intermediate results.
3. Use `PostTeamsMessage` for the initial post.
4. Use `ReplyToTeamsThread` if you need to add follow-up context to the same report.

## Message formatting

Teams messages must be formatted as **HTML**, not Markdown. The agent handles this formatting automatically when composing messages through the PostTeamsMessage tool.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| 403 Forbidden on Teams post | Calling Graph API or dynamicInvoke directly | Use PostTeamsMessage tool instead |
| Message not appearing in channel | Teams connector not configured | Configure via Builder > Connectors in sre.azure.com |
| Duplicate messages | Posting in a loop or per-step | Post only the final report, not intermediate steps |

## Microsoft Learn references

- https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications
- https://learn.microsoft.com/en-us/azure/sre-agent/set-up-teams-connector
- https://learn.microsoft.com/en-us/azure/sre-agent/tools
