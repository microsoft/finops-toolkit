---
title: Manage FinOps toolkit SRE Agent knowledge and memory
description: Learn how knowledge grounds FinOps toolkit SRE Agent responses in your team's context and how memory keeps operational learnings available across sessions and redeployments.
author: msbrett
ms.author: brettwil
ms.date: 04/29/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to manage SRE agent knowledge and memory so that the agent can answer with my team's operational context.
---

# Manage FinOps toolkit SRE Agent knowledge and memory

Knowledge grounds your FinOps toolkit SRE Agent in your team's context. It helps the agent answer with your runbooks, known issues, notification patterns, and deployment details instead of relying on general guidance alone.

Use knowledge and memory together:

- **Knowledge** gives the agent trusted reference material, such as runbooks, architecture notes, and connector setup guidance.
- **Memory** keeps useful learnings from investigations, user instructions, and recurring operational patterns.
- **Session insights** help the agent learn from previous work, including what fixed an issue and what did not.

<br>

## Shipped knowledge docs

The [SRE agent template](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent) includes three knowledge documents under `sre-config/knowledge/`. They are uploaded during post-provisioning so the agent can use them during onboarding and investigations.

| Knowledge doc | What it provides |
|---|---|
| `onboarding-recommendations.md` | First-run guidance for team onboarding, `/learn`, and "What should I do next?" prompts. It reminds the agent to validate Azure access, enable visualization tools, configure FinOps hub data sources, and recommend Outlook and Microsoft Teams connectors when needed. |
| `teams-notification-guide.md` | Delivery guidance for scheduled reports and notifications. It tells the agent to use the built-in `PostTeamsMessage` and `ReplyToTeamsThread` tools, format Teams messages as HTML, and avoid unsupported direct calls to Microsoft Graph or connector endpoints. |
| `known-issues-and-workarounds.md` | Operational workarounds found during scheduled task validation. It covers stale data detection, Resource Graph fallbacks, quota command issues, JMESPath escaping, memory write conflicts, Kusto query errors, and the split between financial data in Teams and operational learnings in memory. |

> [!TIP]
> Keep these docs short and practical. The agent uses them best when each file gives clear instructions, constraints, and examples.

<br>

## Memory system

Azure SRE Agent uses memory to carry context forward between threads. The FinOps toolkit SRE Agent uses these memory layers to improve recommendations over time.

### Session insights

Session insights are extracted automatically after a thread goes quiet. They capture useful details from the conversation, such as:

- Symptoms observed
- Resolution steps
- Root cause
- Pitfalls to avoid

For FinOps operations, this helps the agent remember patterns like stale export data, commands that failed, fallbacks that worked, and report delivery issues. Session insights are most useful when users correct or rate responses after an investigation.

### User memories

User memories are explicit facts that you ask the agent to save. Use them for stable details the agent should remember, such as team preferences, environment constraints, or recurring operational notes.

Use these commands in chat:

- `#remember` to save a fact
- `#retrieve` to find saved facts
- `#forget` to delete a saved fact

> [!IMPORTANT]
> Save operational context, not sensitive financial figures. Send costs, savings, forecasts, and grade results to Teams reports instead of persisting them in memory.

### Proactive knowledge persistence

The agent also maintains synthesized knowledge files under `memories/synthesizedKnowledge/`.

- `overview.md` is loaded when a conversation starts and acts as an at-a-glance summary.
- Topic files store deeper notes, such as team context, architecture, deployment patterns, logs, auth, debugging notes, and reusable queries.

The agent updates these files by merging new information and removing outdated details. This gives the agent a durable, compact summary of what your team has learned.

<br>

## Knowledge sources in the portal

You can add more knowledge in [sre.azure.com](https://sre.azure.com) from **Builder** > **Knowledge sources**.

Knowledge sources can include:

- **Files**: Upload runbooks, architecture docs, escalation guides, API docs, and team procedures.
- **Web pages**: Connect stable documentation pages that the agent should cite.
- **Repositories**: Connect source repositories when code, configuration, or markdown docs should ground agent responses.

Use uploaded files for stable content. Use connected sources for content that changes often, such as a wiki, repository, or live documentation site.

<br>

## Knowledge across redeployments

Knowledge from the template persists across redeployments through the post-provision step.

When you run `azd up`, the template provisions Azure resources and then runs `scripts/post-provision.sh` or `scripts/post-provision.ps1`. The post-provision script initializes `srectl` with the SRE Agent endpoint and uploads everything under `sre-config/knowledge/`:

```bash
srectl doc upload --file "$REPO_ROOT/sre-config/knowledge"
```

This keeps the shipped onboarding, Teams notification, and known-issues guidance available after the agent is redeployed. If you add your own files to `sre-config/knowledge/`, they are uploaded by the same step.

<br>

## Best practices

Use knowledge for information the agent should trust and cite.

- Upload runbooks, architecture guides, escalation paths, known issues, connector setup notes, and service-specific troubleshooting guides.
- Name files by task or topic, such as `aks-scale-out-runbook.md`, `finops-hub-kusto-queries.md`, or `teams-report-delivery.md`.
- Keep one purpose per file so the agent can retrieve the right source quickly.
- Include owner, date, scope, prerequisites, and last review notes in operational docs.
- Avoid secrets, credentials, personal data, and raw financial figures.
- Review knowledge quarterly to remove stale workarounds, retire old commands, and add new operational learnings.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/SREAgent)
<!-- prettier-ignore-end -->

<br>

## Vote on or suggest ideas

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20SRE%20Agent%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Anomaly management](../../framework/understand/anomalies.md)
- [Workload management](../../framework/optimize/workloads.md)

Related products:

- [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview)
- [Azure Data Explorer](https://learn.microsoft.com/azure/data-explorer/)
- [Microsoft Teams](https://learn.microsoft.com/microsoftteams/)

Related solutions:

- [FinOps toolkit SRE Agent](overview.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)

<br>
