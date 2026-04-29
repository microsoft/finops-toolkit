---
title: Troubleshoot the FinOps SRE Agent
description: Resolve common FinOps SRE Agent deployment, tenant, connector, data, and query issues.
author: msbrett
ms.author: brettwil
ms.date: 04/29/2026
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to troubleshoot FinOps SRE Agent issues so that I can restore scheduled cost, capacity, and operations workflows.
---

# Troubleshoot the FinOps SRE Agent

Use this guide when the FinOps SRE Agent deploys, but `srectl`, scheduled tasks, connectors, or data queries don't behave as expected. Start with tenant and deployment checks, then use the known issue sections to match the symptom, cause, and workaround.

<br>

## Troubleshoot B2B tenant environments

In B2B environments, the Azure subscription and Azure SRE Agent resource can live in a different Microsoft Entra tenant than your Microsoft 365 home tenant. If [sre.azure.com](https://sre.azure.com) shows the agent correctly but [`srectl`](/azure/sre-agent/tools) returns `401`, `403`, or `Forbidden: Access denied by PDP`, treat the issue as tenant selection first.

**Symptom:** Browser access works, but `srectl status`, `srectl agent list`, or other `srectl` API calls fail with `401`, `403`, or `Forbidden`.

**Cause:** The CLI token was issued for the wrong tenant. The browser session can use your Microsoft 365 home tenant, while the Azure SRE Agent resource belongs to a different tenant.

**Workaround:**

1. Confirm the active Azure CLI context points at the subscription that owns the Azure SRE Agent resource.
1. Re-authenticate Azure CLI against the tenant that owns the subscription and resource.
1. Re-run `srectl init --resource-url <SRE_AGENT_ENDPOINT>`.
1. Retry `srectl status`, `srectl agent list`, or the failing `srectl` command.

> [!TIP]
> Browser success with CLI failure usually means the agent is healthy and the CLI token was issued for the wrong tenant.

<br>

## Fix common deployment failures

Use these checks after `azd up` or the post-provision hook fails.

### Unsupported region

**Symptom:** The Bicep deployment fails during validation or resource creation.

**Cause:** The template only supports `australiaeast`, `eastus2`, and `swedencentral`.

**Workaround:** Redeploy in a supported region.

### Resource provider not registered

**Symptom:** Azure Resource Manager fails to create the Azure SRE Agent resource.

**Cause:** The `Microsoft.App` resource provider isn't registered on the target subscription.

**Workaround:** Register the provider, wait for registration to complete, and rerun deployment.

```bash
az provider register --namespace Microsoft.App
```

### Missing deployment permissions

**Symptom:** Deployment or role assignment steps fail with authorization errors.

**Cause:** The deploying user doesn't have enough permissions to create resources or assign roles.

**Workaround:** Use an account with Owner or User Access Administrator on the target subscription. If you configure notification connectors later, make sure the configuring user can write connections and role assignments in the agent resource group.

### Zone mapping API returns 404

**Symptom:** Capacity or zone-mapping checks fail when the agent calls `checkZonePeers`.

**Cause:** The `AvailabilityZonePeering` feature isn't registered for the subscription or management group scope.

**Workaround:** Register the feature and re-register the resource provider.

```bash
az feature register --namespace Microsoft.Resources --name AvailabilityZonePeering
az provider register --namespace Microsoft.Resources
```

### Post-provision hook fails

**Symptom:** Azure resources deploy, but skills, agents, tools, scheduled tasks, knowledge documents, or the Kusto connector don't appear in [sre.azure.com](https://sre.azure.com).

**Cause:** The post-provision hook couldn't install or run `srectl`, initialize the endpoint, or apply the SRE configuration.

**Workaround:** Check that `.NET 9.0 SDK`, Azure CLI, `python3`, and `bash` are available locally. Then rerun the post-provision script from `src/templates/sre-agent`.

### Connector setup is missing

**Symptom:** Scheduled tasks run, but Teams or Outlook delivery doesn't work.

**Cause:** `azd up` doesn't create notification connectors because Teams and Outlook require interactive OAuth setup.

**Workaround:** Add the Teams or Outlook connector in [sre.azure.com](https://sre.azure.com), select the agent managed identity, and send a test message.

<br>

## Review known issues

The following issues were observed during scheduled task testing. They don't always indicate a broken deployment.

### Teams tool discovery

**Symptom:** A subagent reports that `PostTeamsChannelMessage` isn't available or that it couldn't find the Teams posting function.

**Cause:** Subagents invoked with `srectl thread new --agent <subagent>` don't inherit Teams connector tools. Connector tools are available to the base agent or when the platform triggers a scheduled task.

**Workaround:**

- Use the platform cron schedule for production scheduled tasks.
- For manual testing, invoke the base agent without the `--agent` flag, then delegate with `@subagent` in the prompt.
- Use the built-in `PostTeamsMessage` tool. Don't call Microsoft Graph or dynamic invoke endpoints directly because that path can return `403`.

### Data pipeline staleness

**Symptom:** Reports show incomplete or missing recent cost data, and forecasts look distorted.

**Cause:** The FinOps hub data pipeline or Cost Management export is stale, so the Azure Data Explorer cluster doesn't have current data.

**Workaround:**

- Let reports call out stale data clearly.
- Run the hubs health check task to confirm freshness.
- Check Cost Management exports in the Azure portal and pipeline runs in Azure Data Factory.

### Resource Graph failures

**Symptom:** `az graph query` returns an unknown error, and Resource Graph-based analysis fails.

**Cause:** The managed identity may not have Reader permissions at the right scope, or complex query expressions may fail in the code interpreter shell environment.

**Workaround:**

- Fall back to scoped `az resource list` queries against specific subscriptions.
- Confirm the agent managed identity has Reader at the management group or subscription scope.
- Simplify query expressions.

### Quota CLI failures

**Symptom:** `az quota usage list` or `az vm list-usage` fails in the agent execution environment.

**Cause:** The `az quota` extension might be missing, or the managed identity might not have permission to read quota data.

**Workaround:**

- Use `az vm list-usage --location <region>` as a compute quota fallback.
- For broader quota checks, use Azure Resource Manager REST calls from code interpreter.
- Track persistent CLI failures so the quota tool can be updated.

### JMESPath escaping

**Symptom:** Azure CLI commands fail when `--query` uses backticks, brackets, or property names with dots.

**Cause:** Shell escaping conflicts with JMESPath syntax in the code interpreter environment.

**Workaround:**

- Prefer `--output json`, then parse the result with Python.
- Use only simple JMESPath selections when you need `--query`.
- Avoid nested expressions that rely on backtick-escaped property names.

### Memory file conflicts

**Symptom:** A scheduled task returns `File write failed` and says a memory file already exists.

**Cause:** A repeated task run tried to create the same memory file again. The memory system requires an edit operation for existing files.

**Workaround:**

- Use an edit operation for subsequent writes to the same memory file.
- Treat the first failure as recoverable. Agents can usually switch from create to edit and continue.

### Kusto query errors

**Symptom:** A tool returns `Error executing query on cluster`.

**Cause:** A Kusto tool may reference a function, table, or column that doesn't exist in your FinOps hub version, or the query syntax may need a version-specific update.

**Workaround:**

- Try a simpler query.
- Check the FinOps hub version.
- Capture the failing tool name and query so the tool YAML can be fixed.

<br>

## Get support

If the workaround doesn't resolve the issue, [open a GitHub issue](https://github.com/microsoft/finops-toolkit/issues/new/choose) and include:

- The deployment region and target subscription tenant
- The failing command, task, or tool name
- The exact error message
- Whether [sre.azure.com](https://sre.azure.com) can open the agent successfully
- Whether the issue affects deployment, `srectl`, scheduled tasks, connectors, or FinOps hub data

For product ideas or known gaps, [vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20SRE%20Agent%22%20sort%3Areactions-%2B1-desc).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/SREAgentTroubleshooting)
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

Related products:

- [Azure SRE Agent](/azure/sre-agent/overview)
- [Azure Data Explorer](/azure/data-explorer/)
- [Azure Developer CLI](/azure/developer/azure-developer-cli/overview)

Related solutions:

- [Deploy FinOps SRE Agent](deploy.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps SRE Agent template reference](template.md)

<br>
