# Teams notification guide for FinOps toolkit SRE Agent

Use this guidance whenever a subagent or scheduled task needs to post results to the Teams channel.

## Correct approach: use the built-in PostTeamsMessage tool

Always use the built-in **PostTeamsMessage** tool to post messages to the Teams channel. This tool handles authentication automatically through the pre-configured Teams connector. You do not need to call the Microsoft Graph API or the connection's dynamicInvoke endpoint directly.

## Teams delivery guard

At the start of each scheduled-task run, inspect the tools available in the current run exactly once per run and remember the result for the rest of that run. Treat Teams delivery as available only when `PostTeamsMessage` is present. Do not call `PostTeamsMessage`, Microsoft Graph, `dynamicInvoke`, raw webhooks, or connector APIs just to test availability.

If no Teams connector/channel is configured and the once-per-run check does not find `PostTeamsMessage`, complete the analysis and return the completed report in the run output with a clear note that Teams delivery was unavailable. This local-output degradation is allowed only when no Teams connector/channel is configured.

When a Teams connector/channel is configured, Teams delivery is mandatory. Complete the analysis first and make one final delivery attempt through `PostTeamsMessage` to the configured Teams channel. If configured Teams delivery fails, the scheduled task/run fails; do not retry, do not degrade to local output, do not mark the report as delivered, and do not probe alternate delivery paths.

### What works

- Call `PostTeamsMessage` with your message content formatted as HTML.
- The Teams connector handles OAuth and managed identity automatically.
- Updates about the same topic stay in the same thread — use `ReplyToTeamsMessage` when that tool is available to continue a conversation.
- Messages include a "Sent by Azure SRE Agent" footer with a UTC timestamp and a link back to the portal thread.

### What does NOT work

- Do NOT attempt to call the Microsoft Graph API directly using the managed identity — the managed identity lacks RBAC permissions on the `Microsoft.Web/connections` resource.
- Do NOT call the connection's `dynamicInvoke` endpoint directly — this will return a 403 Forbidden error.
- Do NOT use raw HTTP requests to Teams webhooks — the connector abstraction is the supported path.

## Scheduled task delivery pattern

All scheduled tasks in this FinOps toolkit SRE Agent include a final `## Deliver` section that instructs the agent to post the completed report to the Teams channel. The key rules are:

1. Complete all analysis and report formatting first.
2. Post only the **final completed report** to Teams — not intermediate results.
3. Apply the Teams delivery guard once per run before attempting delivery.
4. Use `PostTeamsMessage` for the initial post when a Teams connector/channel is configured.
5. Use `ReplyToTeamsMessage` if you need to add follow-up context to the same report and that tool is available.
6. Treat configured Teams delivery failure as a scheduled-task/run failure.

## Message formatting

Teams messages must be formatted as **HTML**, not Markdown. The agent handles this formatting automatically when composing messages through the PostTeamsMessage tool.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| 403 Forbidden on Teams post | Calling Graph API or dynamicInvoke directly | Use PostTeamsMessage tool instead |
| Message not appearing in channel | Teams connector/channel not configured, or configured delivery failed | If no Teams connector/channel is configured, use local run output only. If a Teams connector/channel is configured, treat the delivery failure as a task/run failure. In both cases, apply the Teams delivery guard once and skip repeated probes. |
| Duplicate messages | Posting in a loop or per-step | Post only the final report, not intermediate steps |

## Microsoft Learn references

- https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications
- https://learn.microsoft.com/en-us/azure/sre-agent/set-up-teams-connector
- https://learn.microsoft.com/en-us/azure/sre-agent/tools
