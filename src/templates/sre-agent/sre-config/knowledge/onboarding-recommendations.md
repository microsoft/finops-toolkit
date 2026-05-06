# FinOps toolkit SRE Agent onboarding recommendations

Use this guidance when the user finishes deployment, enters the **Team onboarding** thread, types `/learn`, or asks questions such as **"What should I do next?"** or **"Where do I start?"**

## First-run recommendations

Prioritize these setup steps in order:

1. Confirm the agent can read the target Azure subscriptions or resource groups.
2. Enable **Visualization** built-in tools so scheduled tasks can generate charts and images.
3. Confirm the FinOps Hub Kusto connector is configured when Hub-backed cost and usage analysis is expected.
4. Recommend Outlook and Teams notification connectors when the team wants scheduled reports, proactive notifications, or workflow-driven updates.

## Enable visualization tools

The Visualization tool category (5 tools including chart generation and Grafana integration) is **not enabled by default** and cannot be set via Bicep or ARM. It must be enabled in the portal:

1. Open the agent in [sre.azure.com](https://sre.azure.com).
2. Go to **Capabilities** > **Tools** > **Built-in tools**.
3. Check the **Visualization** checkbox (0/5 tools).
4. Click **Save changes**.

Without this, scheduled tasks cannot generate inline charts or images in their Teams reports.

## Outlook and Teams connector guidance

If the user wants email delivery, Teams delivery, scheduled digests, or "notify the team" workflows, recommend configuring both notification connectors.

Important platform constraint:

- Outlook and Teams connectors are supported by Azure SRE Agent.
- Microsoft Learn currently documents them as interactive portal setup that requires OAuth sign-in plus a managed identity.
- Do not imply that these connectors are provisioned by the FinOps Toolkit Bicep templates or `post-provision` automation.

## Manual connector steps to recommend

Tell the user to open **Builder** > **Connectors** in `https://sre.azure.com` and add:

1. **Outlook Tools (Office 365 Outlook)**
2. **Send notification (Microsoft Teams)**

For Outlook:

- Sign in with a Microsoft 365 account that has mailbox access.
- Select the agent managed identity.
- Send a test email from chat.

For Teams:

- Sign in with a Microsoft 365 account that has access to the target Teams channel.
- Paste the channel URL from **Get link to channel**.
- Select the agent managed identity.
- Post a test message from chat.

Scheduled tasks use the Teams delivery guard from `teams-notification-guide.md`: they check whether `PostTeamsMessage` is available once per run, post the final report when it is available, and otherwise return the completed report in the run output without retrying or probing alternate delivery paths.

## Required prerequisites to call out

- The configuring user needs **Contributor** on the agent resource group.
- The connector flow requires `Microsoft.Web/connections/write`.
- The connector flow requires `Microsoft.Authorization/roleAssignments/write`.
- The agent must already have a managed identity configured.

## Suggested recommendation wording

If the user asks what to do next after deployment, recommend something like:

> Your core FinOps toolkit SRE Agent is deployed. Next: (1) Enable **Visualization** tools under Capabilities > Tools > Built-in tools so charts work in scheduled reports. (2) Add **Outlook** and **Teams** notification connectors under Builder > Connectors so scheduled tasks can deliver to your team. (3) Connect your FinOps Hub data sources if not already wired.

## Microsoft Learn references

- https://learn.microsoft.com/en-us/azure/sre-agent/team-onboard
- https://learn.microsoft.com/en-us/azure/sre-agent/complete-setup
- https://learn.microsoft.com/en-us/azure/sre-agent/outlook-connector
- https://learn.microsoft.com/en-us/azure/sre-agent/set-up-teams-connector
- https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications
