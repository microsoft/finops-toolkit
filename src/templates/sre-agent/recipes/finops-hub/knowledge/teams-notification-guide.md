# Teams and Outlook notification guide for FinOps toolkit SRE Agent

Use this guidance whenever a subagent or scheduled task needs to deliver report results through the configured Teams and Outlook connectors.

## Correct approach: use the built-in connector tools

Always use the built-in **PostTeamsMessage** tool for Teams channel delivery and **SendOutlookEmail** for Outlook email delivery. These tools handle authentication through the configured connectors. You do not need to call the Microsoft Graph API or a connection dynamicInvoke endpoint directly.

## Delivery guard

At the start of each scheduled-task run, inspect the tools available in the current run exactly once per run and remember the result for the rest of that run. Treat Teams delivery as available only when `PostTeamsMessage` is present. Treat Outlook delivery as available only when `SendOutlookEmail` is present. Do not call `PostTeamsMessage`, `SendOutlookEmail`, Microsoft Graph, `dynamicInvoke`, raw webhooks, or connector APIs just to test availability.

If neither connector is configured and the once-per-run check does not find either delivery tool, complete the analysis and return the completed report in the run output with a clear note that connector delivery was unavailable. This local-output degradation is allowed only when no Teams or Outlook connector is configured.

When Teams or Outlook is configured, configured delivery is mandatory. Complete the analysis first, then make one final delivery attempt through each configured channel whose tool is available. If configured delivery fails, the scheduled task/run fails; do not retry, do not degrade to local output, do not mark the report as delivered, and do not probe alternate delivery paths.

### What works

- Call `PostTeamsMessage` with your message content formatted as HTML.
- Call `SendOutlookEmail` with the final report and generated chart artifacts when Outlook delivery is configured.
- The Teams connector handles OAuth and managed identity automatically.
- The Outlook connector handles OAuth and managed identity automatically.
- Updates about the same topic stay in the same thread — use `ReplyToTeamsMessage` when that tool is available to continue a conversation.
- Messages include a "Sent by Azure SRE Agent" footer with a UTC timestamp and a link back to the portal thread.

### What does NOT work

- Do NOT attempt to call the Microsoft Graph API directly using the managed identity — the managed identity lacks RBAC permissions on the `Microsoft.Web/connections` resource.
- Do NOT call the connection's `dynamicInvoke` endpoint directly — this will return a 403 Forbidden error.
- Do NOT use raw HTTP requests to Teams webhooks — the connector abstraction is the supported path.
- Do NOT send partial or intermediate report fragments through Teams or Outlook.

## Scheduled task delivery pattern

All scheduled tasks in this FinOps toolkit SRE Agent include a final `## Deliver` section that instructs the agent to render charts, return the completed report in the run output, and deliver the final report through configured Teams and Outlook connectors. The key rules are:

1. Complete all analysis and report formatting first.
2. Render required charts with `PlotBarChart`, `PlotPieChart`, `PlotAreaChartWithCorrelation`, or `ExecutePythonCode` before delivery.
3. Post or email only the **final completed report** — not intermediate results.
4. Use `PostTeamsMessage` for the initial post when a Teams connector/channel is configured.
5. Use `SendOutlookEmail` when Outlook delivery is configured.
6. Use `ReplyToTeamsMessage` if you need to add follow-up context to the same report and that tool is available.
7. Treat configured connector delivery failure as a scheduled-task/run failure.

## Message formatting

Teams messages must be formatted as **HTML**, not Markdown. Outlook messages should use readable HTML with the same report structure. The agent handles this formatting when composing messages through the connector tools.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| 403 Forbidden on Teams post | Calling Graph API or dynamicInvoke directly | Use PostTeamsMessage tool instead |
| Email not sent | Outlook connector not configured, or configured delivery failed | If no Outlook connector is configured, use local run output and Teams when available. If Outlook is configured, treat the delivery failure as a task/run failure. |
| Message not appearing in channel | Teams connector/channel not configured, or configured delivery failed | If no Teams connector/channel is configured, use local run output and Outlook when available. If a Teams connector/channel is configured, treat the delivery failure as a task/run failure. In both cases, apply the delivery guard once and skip repeated probes. |
| Duplicate messages | Posting in a loop or per-step | Deliver only the final report, not intermediate steps |

## Microsoft Learn references

- https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications
- https://learn.microsoft.com/en-us/azure/sre-agent/outlook-connector
- https://learn.microsoft.com/en-us/azure/sre-agent/set-up-teams-connector
- https://learn.microsoft.com/en-us/azure/sre-agent/tools
