---
title: Troubleshoot Azure SRE Agent deployments from the FinOps toolkit
description: Resolve common deployment, tenant, connector, data, and query issues for Azure SRE Agent deployments from the FinOps toolkit.
author: msbrett
ms.author: brettwil
ms.date: 06/17/2026
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to troubleshoot the FinOps toolkit's Azure SRE Agent deployment so that I can restore scheduled cost, capacity, and operations workflows.
---

# Troubleshoot Azure SRE Agent deployments from the FinOps toolkit

Use this guide when the agent deploys, but Azure MCP Server `sreagent` commands, scheduled tasks, connectors, or data queries don't behave as expected. Start with tenant and deployment checks, then use the known issue sections to match the symptom, cause, and workaround.

<br>

## Troubleshoot B2B tenant environments

In B2B environments, the Azure subscription and Azure SRE Agent resource can live in a different Microsoft Entra tenant than your Microsoft 365 home tenant. If [sre.azure.com](https://sre.azure.com) shows the agent correctly but Azure MCP Server `sreagent` commands return `401`, `403`, `AccessDenied`, or `Forbidden`, treat the issue as tenant selection first.

**Symptom:** Browser access works, but Azure MCP Server `sreagent_agents_list`, `sreagent_agents_get`, `sreagent_agents_tools_list`, or related SRE Agent commands fail with `401`, `403`, `AccessDenied`, or `Forbidden`.

**Cause:** The tool token can be issued for the wrong tenant or the tool can route the SRE Agent discovery call through a tenant-scoped Resource Graph path. The browser session can use your Microsoft 365 home tenant, while the Azure SRE Agent resource belongs to a different tenant.

**Workaround:**

1. Confirm the active Azure CLI context points at the subscription that owns the Azure SRE Agent resource.
1. Re-authenticate Azure CLI against the tenant that owns the subscription and resource.
1. Pass the resource tenant, subscription, resource group, and agent name explicitly to Azure MCP Server `sreagent` commands.
1. Verify the same identity can read the ARM resource with `az resource show` and can call the SRE Agent data-plane endpoint with a token for `https://azuresre.dev`.
1. If ARM and direct data-plane calls work but Azure MCP Server `sreagent` commands still return `AccessDenied`, capture the timestamp and correlation ID from the tool response and route it as an Azure MCP Server or Azure SRE Agent B2B access issue.

> [!TIP]
> Browser success with Azure MCP Server failure usually means the agent might be healthy, but the tool credential or SRE Agent discovery path needs tenant-specific verification.

<br>

## Fix common deployment failures

Use these checks after `bin/deploy.sh` or post-provisioning fails.

### Unsupported region

**Symptom:** The Bicep deployment fails during validation or resource creation.

**Cause:** The template only supports `australiaeast`, `canadacentral`, `eastus2`, `francecentral`, `koreacentral`, `swedencentral`, and `uksouth`.

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

**Workaround:** Use an account with permissions to create resources and assign roles at the affected scopes. Contributor can create the deployed resources; Role Based Access Control Administrator, User Access Administrator, or Owner can assign the required roles. If you configure notification connectors later, make sure the configuring user can write connections and role assignments in the agent resource group.

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

**Cause:** The post-provision step couldn't resolve the endpoint, get an SRE Agent data-plane token, configure the Kusto connector, or apply the SRE configuration through the supported ARM and data-plane APIs.

**Workaround:** Check that Azure CLI, `python3`, `jq`, `curl`, and `bash` are available locally. Then rerun `bin/apply-extras.sh` from `src/templates/sre-agent`.

### Connector setup is missing

**Symptom:** Scheduled tasks run, but Teams or Outlook delivery doesn't work.

**Cause:** `bin/deploy.sh` does not create notification connectors because Teams and Outlook require interactive OAuth setup.

**Workaround:** Add the Teams or Outlook connector in [sre.azure.com](https://sre.azure.com), select the agent managed identity, and send a test message.

### Kusto connector is unhealthy for a private endpoint cluster

**Symptom:** The SRE Agent deployment succeeds and the `finops-hub-kusto` connector is created, but the connector doesn't become healthy. The deployment output may warn that the Azure Data Explorer cluster denies public query access.

**Cause:** Hosted Azure SRE Agent runs outside your VNET. Azure SRE Agent can use ARM for resource discovery, health, metrics, and management operations, but direct KQL queries to private endpoint Azure Data Explorer clusters are a documented limitation when `publicNetworkAccess` is `Disabled`.

**Workaround:** Review the [Azure SRE Agent VNET known limitations](https://sre.azure.com/docs/capabilities/azure-observability-vnet#known-limitations), then decide whether to enable public query access for the Azure Data Explorer cluster. The FinOps toolkit deployment doesn't change customer cluster networking automatically. Until public query access is enabled or Azure SRE Agent adds private endpoint ADX query support, Kusto tools that depend on `finops-hub-kusto` are expected to fail while ARM-based health and metrics operations continue to work.

<br>

## Review known issues

The following issues were observed during scheduled task testing. They don't always indicate a broken deployment.

### Teams tool discovery

**Symptom:** A subagent reports that `PostTeamsChannelMessage` isn't available or that it couldn't find the Teams posting function.

**Cause:** Subagents invoked directly for manual testing might not inherit Teams connector tools. Connector tools are available to the base agent or when the platform triggers a scheduled task.

**Workaround:**

- Use the platform cron schedule for production scheduled tasks.
- For manual testing, invoke the base agent without the `--agent` flag, then delegate with `@subagent` in the prompt.
- Use the built-in `PostTeamsMessage` tool. Don't call Microsoft Graph or dynamic invoke endpoints directly because that path can return `403`.

### Data pipeline staleness

**Symptom:** Reports show incomplete or missing recent cost data, and forecasts look distorted.

**Cause:** The FinOps hub data pipeline or Cost Management export may be stale, so the Azure Data Explorer cluster might not have current data. Older memory notes, raw KQL checks, or ingestion timestamp checks can also report stale data incorrectly after the pipeline has recovered.

**Workaround:**

- Run `data-freshness-check` or the hubs health check task to confirm freshness before escalating. Treat the direct REST `Costs()` result as the source of truth.
- If `Costs()` is 3 days old or newer, mark conflicting stale-memory, raw-KQL, or ingestion timestamp conclusions as superseded and don't report the hub as stale.
- If `Costs()` has no rows, has a query error, or is more than 3 days old, let reports call out stale data clearly and check Cost Management exports in the Azure portal and pipeline runs in Azure Data Factory.

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
- Whether the issue affects deployment, Azure MCP Server `sreagent` commands, scheduled tasks, connectors, or FinOps hub data

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

Related solutions:

- [Deploy Azure SRE Agent with the FinOps toolkit](deploy.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [Azure SRE Agent template reference (FinOps toolkit)](template.md)

<br>
