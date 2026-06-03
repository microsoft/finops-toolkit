---
title: Security and permissions for Azure SRE Agent in the FinOps toolkit
description: Review the permissions, identities, run modes, and data flows the FinOps toolkit configures on Azure SRE Agent before you deploy it in your environment.
author: msbrett
ms.author: brettwil
ms.date: 06/01/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps hub admin, I want to understand the security and permissions the FinOps toolkit configures on Azure SRE Agent so that I can deploy it with least privilege.
---

# Security and permissions for Azure SRE Agent in the FinOps toolkit

The FinOps toolkit deployment configures Azure SRE Agent with managed identity, Azure RBAC, Azure Data Explorer permissions, and optional Microsoft Teams or Outlook connectors to run FinOps and capacity workflows. Review these permissions before deployment so you can keep the agent scoped to the data and actions it needs.

> [!IMPORTANT]
> The agent is designed for least privilege. The template grants read, monitoring, Kusto viewer, and zone mapping permissions. It doesn't grant broad write access to Azure resources.

<br>

## Deployment permissions

To deploy the template, the deploying user or service principal needs one of these permission sets on the target subscription:

- **Owner**
- **User Access Administrator** and **Contributor**

These permissions are needed because deployment creates a resource group, creates Azure resources, assigns Azure RBAC roles, and assigns the deploying principal the Azure SRE Agent Administrator role on the agent resource.

> [!TIP]
> Use a dedicated deployment identity for production environments. After deployment, review role assignments and remove any temporary permissions the deployment identity no longer needs.

<br>

## Managed identity permissions

The template creates an Azure SRE Agent with a system-assigned managed identity.

The system-assigned managed identity is the primary identity the template manages. The template uses it for Azure resource operations, action execution, the knowledge graph configuration, and connector setup. The deployment grants the system-assigned managed identity these permissions:

| Role | Scope | What it grants | Why it's needed |
|------|-------|----------------|-----------------|
| Reader | Subscription | Read access to Azure resources and metadata | Lets the agent inspect resource configuration, cost scopes, quota context, and related Azure inventory |
| Reader | Target resource groups | Read access to scoped resource groups | Lets the agent inspect explicitly targeted resources |
| Monitoring Reader | Target resource groups | Read access to Azure Monitor settings and telemetry | Lets the agent use monitoring context for investigations and health checks |
| Log Analytics Reader | Target resource groups | Read access to Log Analytics resources | Lets the agent query scoped workspace telemetry when configured |
| Contributor | Target resource groups when `accessLevel` is `High` | Resource-group write access | Lets remediation tools create or update approved alerts and budgets in targeted scopes |
| AllDatabasesViewer | Azure Data Explorer cluster | Viewer access across databases in the cluster | Lets the Kusto connector query FinOps hub cost data |
| SRE Agent Administrator | Agent resource | Administer the Azure SRE Agent resource | Lets the deploying principal manage the agent after deployment |

With this default scope, the managed identity can read Azure resource metadata, monitoring context, and FinOps hub data. It can write approved remediation resources only in explicitly targeted resource groups when `accessLevel` is `High`, and it can send messages or email only through connectors you configure.

<br>

## Data Explorer permissions

The agent reads FinOps hub data through an Azure Data Explorer connector. When you provide the optional cluster name and cluster resource group parameters, the deployment assigns `AllDatabasesViewer` on the target Azure Data Explorer cluster to the system-assigned managed identity.

This permission lets the agent query hub data, including cost, usage, commitment, allocation, anomaly, and forecast datasets exposed through the FinOps toolkit Kusto tools. It doesn't grant database administration permissions.

> [!NOTE]
> If you don't grant `AllDatabasesViewer` during deployment, a cluster administrator can grant the equivalent viewer permission later. The Kusto connector won't return FinOps hub results until the managed identity has permission on the cluster.

<br>

## Connector permissions

The agent doesn't create Teams or Outlook notification connectors during deployment. You add them interactively in [sre.azure.com](https://sre.azure.com) after deployment.

To configure a Teams or Outlook connector, the configuring user needs **Contributor** on the agent resource group, including these actions:

| Permission | Why it's needed |
|------------|-----------------|
| `Microsoft.Web/connections/write` | Creates or updates the connector resource that stores the connection configuration |
| `Microsoft.Authorization/roleAssignments/write` | Assigns the selected managed identity permission to use the connector resource |

Communication connectors use both OAuth and managed identity:

1. You sign in with a Microsoft 365 account through OAuth.
2. You select the agent's managed identity.
3. The connector stores the OAuth token securely in the connector resource.
4. The agent uses the managed identity at runtime to access the connector resource and send messages or email.

For Teams, the account that signs in must have access to the target channel and the channel's **Get link to channel** URL. The connector can post messages to the configured channel, reply to threads, and read channel messages for context.

<br>

## Run modes

Azure SRE Agent supports two run modes:

| Mode | Security behavior | Use with the FinOps toolkit deployment |
|------|-------------------|---------------------------|
| Review | The agent proposes Azure infrastructure write actions, and an SRE Agent Administrator approves or denies them | Best for production response plans and any workflow that might change resources |
| Autonomous | The agent runs allowed actions without waiting for approval | Best for trusted recurring reports, health checks, and scheduled FinOps summaries |

The template sets the agent action configuration to **Autonomous** so scheduled cost and capacity reports can run and post results without manual approval.

> [!IMPORTANT]
> Run mode doesn't replace permissions. The agent can act only when its managed identity, connector, and data source permissions allow the action. Review mode adds an approval step for Azure infrastructure write actions, but other actions, such as querying data or posting to Teams, run based on available tools and permissions.

Start with Review for workflows that could affect production resources. Use Autonomous for read-only reporting tasks after you confirm the prompts, tools, and destination channels are correct.

<br>

## B2B tenant considerations

In B2B environments, the Azure subscription and Azure SRE Agent resource can be in a different Microsoft Entra tenant than your Microsoft 365 home tenant.

Use these checks when deployment, Azure MCP Server, or connector configuration fails:

1. Confirm the active Azure CLI context points to the subscription that owns the SRE Agent resource.
2. Re-authenticate against the tenant that owns the subscription.
3. When using Azure MCP Server `sreagent` tools, pass the resource tenant, subscription, resource group, and agent name explicitly.
4. If Azure MCP Server returns `403` from its SRE Agent path, verify the same identity can read the ARM resource and data-plane endpoint before changing agent permissions.

Browser access can succeed while a local tool returns `401`, `403`, or `Forbidden` if the token was issued for the wrong tenant. The deployment script sets the active subscription before deployment to reduce this risk.

Connector setup can also cross identity boundaries. The Azure resource permissions come from the resource tenant, while Teams or Outlook OAuth uses the Microsoft 365 account that signs in to the connector.

<br>

## Data flow

The agent reads operational and cost data from these sources:

- FinOps hub cost and usage data in Azure Data Explorer.
- Azure resource metadata through Reader permissions.
- Azure Monitor and Log Analytics context through target resource group reader permissions.
- Uploaded knowledge documents that describe FinOps toolkit tools, Teams notification patterns, report output style, and known issues.

Scheduled reports and investigation summaries can be sent to:

- The Azure SRE Agent chat experience.
- A configured Microsoft Teams channel.
- Outlook, if you add the Outlook connector.

Don't save financial data to agent memory. Save only operational notes, such as tool errors, workarounds, and repeatable patterns.

Data residency follows the Azure resources and Microsoft 365 services you connect. FinOps hub data stays in your Azure Data Explorer cluster until queried. Agent telemetry is written to the deployed Log Analytics and Application Insights resources. Teams or Outlook reports are delivered to the channel or mailbox you configure, and OAuth tokens are stored in the connector resource rather than in the agent prompt or knowledge files.

<br>

## Least privilege checklist

Use this checklist before you move from test to production:

- Grant the deployment identity only the permissions needed for deployment.
- Keep the agent managed identity scoped to subscription Reader, target resource group reader/remediation permissions, and Azure Data Explorer viewer permissions unless your own workflows require more.
- Use Review mode for production workflows that can change Azure resources.
- Use Autonomous mode only for trusted reports, health checks, and read-only tasks.
- Configure Teams and Outlook connectors with accounts that are allowed to send to the target audience.
- Send reports only to channels or mailboxes approved for cost and capacity information.
- Review Data Explorer access when hub databases or clusters change.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/SREAgent)
<!-- prettier-ignore-end -->

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
- [Rate optimization](../../framework/optimize/rates.md)
- [Usage optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure SRE Agent](/azure/sre-agent/overview)
- [Run modes in Azure SRE Agent](/azure/sre-agent/run-modes)
- [Azure Data Explorer](/azure/data-explorer/)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [Deploy Azure SRE Agent with the FinOps toolkit](deploy.md)
- [Azure SRE Agent in the FinOps toolkit](overview.md)
- [Azure SRE Agent template reference (FinOps toolkit)](template.md)

<br>
