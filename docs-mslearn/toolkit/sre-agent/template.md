---
title: Azure SRE Agent template reference (FinOps toolkit)
description: Review the FinOps toolkit's Azure SRE Agent deployment template, parameters, outputs, script flags, and Bicep module structure.
author: msbrett
ms.author: brettwil
ms.date: 06/03/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps hub admin, I want to understand the FinOps toolkit's Azure SRE Agent template so that I can deploy and customize it safely.
---

# Azure SRE Agent template reference (FinOps toolkit)

This reference summarizes the [FinOps toolkit's Azure SRE Agent template](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent). Use it to review deployment prerequisites, Bicep parameters, script options, and module structure before you deploy or customize the template.

<br>

## Prerequisites

Ensure the following prerequisites are met before you deploy the template:

<!-- prettier-ignore-start -->
- You must have permissions to create the deployed resources and assign roles.

  | Task | Minimum permission |
  | ---- | ------------------ |
  | Deploy the subscription-scoped Bicep template and create the target resource group | [Contributor](/azure/role-based-access-control/built-in-roles#contributor) on the subscription |
  | Assign subscription and target resource group roles to the agent managed identity | [Role Based Access Control Administrator](/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator), [User Access Administrator](/azure/role-based-access-control/built-in-roles#user-access-administrator), or [Owner](/azure/role-based-access-control/built-in-roles#owner) on the assignment scopes |
  | Assign Azure Data Explorer access when cluster parameters are set | Permission to create `Microsoft.Kusto/clusters/principalAssignments` on the target cluster |
  | Apply Azure SRE Agent objects with the portal deployment script or `bin/apply-extras.sh` | SRE Agent Administrator on the deployed Azure SRE Agent resource |

- The `Microsoft.App` resource provider must be registered in the subscription.
- For local CLI deployments only: [Azure CLI](/cli/azure/install-azure-cli), `curl`, `jq`, Bash 3.2 or newer, and `python3` with PyYAML must be available locally.
- A FinOps hub with Azure Data Explorer is required when you want the agent to query hub data.
<!-- prettier-ignore-end -->

<br>

## Parameters

Here are the parameters you can use to customize the deployment:

| Parameter | Type | Default value | Allowed values | Description |
| --------- | ---- | ------------- | -------------- | ----------- |
| **resourceGroupName** | String | None | Any string | Required. Resource group that contains the SRE Agent resources. |
| **agentName** | String | None | Any string | Required. Azure SRE Agent name. |
| **location** | String | `eastus2` | `australiaeast`, `canadacentral`, `eastus2`, `francecentral`, `koreacentral`, `swedencentral`, `uksouth` | Optional. Primary location for all resources. |
| **targetResourceGroups** | Array | `[]` | Resource group names | Optional. Resource groups the agent can observe or act on. Defaults to the agent resource group. |
| **targetResourceGroupNames** | String | `""` | Comma-separated resource group names | Optional. Portal form input for target resource groups. Defaults to the agent resource group. |
| **accessLevel** | String | `High` | `Low`, `High` | Optional. Agent access level. |
| **actionMode** | String | `autonomous` | `review`, `autonomous`, `readOnly` | Optional. Agent action mode. |
| **upgradeChannel** | String | `Preview` | `Stable`, `Preview` | Optional. Agent upgrade channel. |
| **defaultModelProvider** | String | `MicrosoftFoundry` | `MicrosoftFoundry`, `Anthropic` | Optional. Parent SRE Agent model provider. `MicrosoftFoundry` maps to Azure OpenAI in the SRE Agent portal. |
| **defaultModelName** | String | `Automatic` | Any supported model name | Optional. Parent SRE Agent model name. Use `Automatic` so SRE Agent routes to the appropriate model inside the selected provider. |
| **monthlyAgentUnitLimit** | Int | `10000` | 1 or higher | Optional. Monthly agent unit limit. |
| **experimentalSettings** | Object | `{ "EnableSandboxGroup": true, "EnableWorkspaceTools": true }` | Object | Optional. Agent sandbox and workspace tool settings for the stable SRE Agent runtime. |
| **finopsHubKustoConnectorUri** | String | `""` | Database-qualified Kusto URI | Optional. Kusto connector URI for the FinOps hub database, such as `https://cluster.region.kusto.windows.net/Hub`. |
| **finopsHubKustoClusterResourceId** | String | `""` | Azure resource ID | Optional. Azure Data Explorer cluster resource ID for the FinOps hub role assignment. |
| **enableSubscriptionReaderRole** | Boolean | `true` | `true`, `false` | Optional. Assigns Reader at subscription scope to the agent managed identity. |
| **recipePackageUri** | String | Derived from the template URI | Public URI | Optional. URI for the packaged recipe assets used by the portal deployment script. |
| **forceUpdateTag** | String | Current deployment timestamp | Any string | Optional. Forces the portal deployment script to rerun during redeployment. |

<br>

## Deployment values

The portal template receives values from `createUiDefinition.json`, then runs a subscription-scoped ARM deployment directly from the published toolkit deploy artifacts. `bin/deploy.sh` writes a deployment parameter file under the local SRE Agent deployment cache, then runs `az deployment sub create` directly. Neither path uses Azure Developer CLI environments.

| Value | Source | Description |
| ----- | ------ | ----------- |
| **subscription** | `--subscription` | Azure subscription ID. |
| **resourceGroupName** | `--resource-group` | Resource group that contains the SRE Agent resources. |
| **agentName** | `--name` | Azure SRE Agent name. |
| **location** | `--location` | Azure location for the deployment. |
| **targetResourceGroups** | `--target-resource-group` | Target resource group names. Defaults to the agent resource group. |
| **enableSubscriptionReaderRole** | Default, unless `--no-subscription-reader` is passed | Whether the deployment assigns subscription-scope Reader to the agent managed identity. |
| **defaultModelProvider** | `agent.json` | Parent SRE Agent model provider. The FinOps hub recipe defaults to Azure OpenAI provider-level routing with `MicrosoftFoundry`. |
| **defaultModelName** | `agent.json` | Parent SRE Agent model name. The FinOps hub recipe defaults to `Automatic` model routing. |
| **finopsHubKustoClusterResourceId** | `--cluster-resource-id` | Optional cluster resource ID used to assign `AllDatabasesViewer`. |
| **FinOps Hub Kusto connector URI** | `--cluster-uri` | Database-qualified Kusto URI, such as `https://cluster.region.kusto.windows.net/Hub`. |

<br>

## Portal recipe configuration

The Deploy to Azure path packages `azuredeploy.json`, `createUiDefinition.json`, and `sre-agent-recipe.zip` under `docs/deploy/sre-agent/<version>/`. The `recipePackageUri` parameter defaults to a file beside the linked template by using the ARM deployment template-link URI. The deployment script downloads that package, reads `extras.json`, and applies the same recipe objects as `bin/apply-extras.sh`.

The deployment script uses a user-assigned managed identity. Bicep grants that identity SRE Agent Administrator on the agent resource before the script runs, then the script uses ARM for connectors and the SRE Agent data plane for built-in tools, knowledge, tools, skills, subagents, and scheduled tasks.

<br>

## Azure Data Explorer network access

When `--cluster-uri` points to an Azure Data Explorer cluster, the deployment inspects the cluster's network access setting before creating the agent. If `publicNetworkAccess` is `Disabled`, the deployment doesn't stop. It still deploys all resources, assigns the agent managed identity `AllDatabasesViewer`, and creates the `finops-hub-kusto` connector.

The deployment prints a warning with the [Azure SRE Agent VNET known limitations](https://sre.azure.com/docs/capabilities/azure-observability-vnet#known-limitations) because hosted Azure SRE Agent can't run direct KQL queries against private endpoint ADX clusters. The customer must decide whether to enable public query access for the cluster. Until public query access is enabled or Azure SRE Agent adds private endpoint ADX query support, the connector is expected to remain unhealthy.

<br>

## Outputs

Here are the outputs generated by the deployment:

| Output | Type | Description |
| ------ | ---- | ----------- |
| **AZURE_RESOURCE_GROUP** | String | Name of the Azure resource group that contains the SRE Agent resources. |
| **AZURE_LOCATION** | String | Azure location used for the SRE Agent resources. |
| **SRE_AGENT_NAME** | String | Name of the deployed Azure SRE Agent resource. |
| **SRE_AGENT_ENDPOINT** | String | Endpoint of the deployed Azure SRE Agent resource. |

<br>

## Script flags

The template includes Bash scripts for one-shot deployment and extras configuration.

### Deployment wrapper

Use `bin/deploy.sh` to write deterministic ARM parameters, deploy `infra/main.bicep` with Azure CLI, and run `bin/apply-extras.sh`.

Supporting resource names are deterministic for the subscription ID, agent resource group ID, and agent name. Rerunning the script with the same tuple updates the same Log Analytics workspace, Application Insights component, system-assigned managed identity RBAC assignments, and SRE Agent instead of creating timestamped duplicates. The optional `--deploy-name` only names the ARM deployment record and local build directory.

| Bash flag | Required | Description |
| --------- | -------- | ----------- |
| `--recipe <dir>` | Yes | Recipe directory. Use `recipes/finops-hub`. |
| `--subscription <subscription-id>` | Yes | Azure subscription ID. |
| `--resource-group <name>` | Yes | Resource group for SRE Agent resources. |
| `--name <name>` | Yes | Azure SRE Agent name. |
| `--location <region>` | Yes | Azure region. |
| `--target-resource-group <name>` | No | Repeatable target resource group. Defaults to `--resource-group`. |
| `--cluster-uri <uri>` | No | Database-qualified FinOps hub Kusto URI, such as `https://cluster.region.kusto.windows.net/Hub`. |
| `--cluster-resource-id <id>` | Optional with `--cluster-uri` for real deployments; required for `--dry-run` | Kusto cluster ARM resource ID for `AllDatabasesViewer`. Real deployments resolve it from `--cluster-uri` when the cluster is in the target subscription. |
| `--no-subscription-reader` | No | Skips the default subscription-scope Reader assignment. Use only when equivalent read access is granted another way. |
| `--deploy-name <name>` | No | Deployment name override. Defaults to a deterministic name from subscription ID, resource group, and agent name. |
| `--dry-run` | No | Validate inputs and write parameters without Azure calls. |
| `--force`, `--no-telemetry` | No | Compatibility flags accepted by the wrapper. |
| `-h`, `--help` | No | Show script help. |

### Extras configuration

Use `bin/apply-extras.sh` to configure the Kusto connector through ARM when requested, upload KnowledgeFile sources, and apply custom agents, skills, tools, and scheduled tasks through the SRE Agent data plane. `bin/post-provision.sh` remains as a deprecated compatibility wrapper that forwards to `bin/apply-extras.sh`.

| Bash flag | Required | Description |
| --------- | -------- | ----------- |
| `--endpoint <url>` | Yes | SRE Agent endpoint returned by deployment. |
| `--recipe <dir>` | Yes | Recipe directory. |
| `--subscription <id>` | Yes | Azure subscription that contains the SRE Agent. |
| `--resource-group <name>` | Yes | Resource group that contains the SRE Agent. |
| `--name <name>` | Yes | SRE Agent name. |
| `--build-dir <dir>` | Yes | Working directory for generated extras request and response files. |
| `--kusto-connector-uri <uri>` | No | Database-qualified Kusto connector URI. |

<br>

## Module structure

The template uses a subscription-scoped entry point and resource group modules:

| File | Scope | Deploys or configures |
| ---- | ----- | --------------------- |
| `infra/main.bicep` | Subscription | Creates the target resource group, calls the resource group deployment, assigns subscription and target resource group RBAC, and optionally assigns Azure Data Explorer roles. |
| `infra/resources.bicep` | Resource group | Orchestrates identity, monitoring, and Azure SRE Agent modules, then surfaces outputs to the subscription deployment. |
| `infra/modules/monitoring.bicep` | Resource group | Creates the Log Analytics workspace and workspace-based Application Insights component for telemetry. |
| `infra/modules/sre-agent.bicep` | Resource group | Creates the `Microsoft.App/agents@2026-01-01` resource, configures action mode, model provider, sandbox, and workspace tool settings, assigns SRE Agent Administrator to the deployer, and exposes the agent endpoint for `bin/apply-extras.sh`. |
| `infra/modules/resource-group-rbac.bicep` | Resource group | Assigns Reader, Monitoring Reader, Log Analytics Reader, and optionally Contributor to the agent system-assigned managed identity. |
| `infra/modules/kusto-all-databases-viewer-rbac.bicep` | Resource group | Assigns `AllDatabasesViewer` on an existing Azure Data Explorer cluster to the system-assigned managed identity when cluster parameters are provided. |

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

Related products:

- [Azure SRE Agent](/azure/sre-agent/overview)
- [Azure Data Explorer](/azure/data-explorer/)

Related solutions:

- [Deploy Azure SRE Agent with the FinOps toolkit](deploy.md)
- [Azure SRE Agent in the FinOps toolkit](overview.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
