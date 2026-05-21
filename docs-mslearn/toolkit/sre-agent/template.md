---
title: Azure SRE Agent template reference (FinOps toolkit)
description: Review the FinOps toolkit's Azure SRE Agent deployment template, parameters, outputs, script flags, and Bicep module structure.
author: msbrett
ms.author: brettwil
ms.date: 05/06/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps hub admin, I want to understand the FinOps toolkit's Azure SRE Agent template so that I can deploy and customize it safely.
---

# Azure SRE Agent template reference (FinOps toolkit)

This reference summarizes the [FinOps toolkit's Azure SRE Agent template](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent). Use it to review deployment prerequisites, Bicep parameters, Azure Developer CLI (`azd`) outputs, script options, and module structure before you deploy or customize the template.

<br>

## Prerequisites

Ensure the following prerequisites are met before you deploy the template:

<!-- prettier-ignore-start -->
- You must have permissions to create the deployed resources and assign roles.

  | Task | Minimum permission |
  | ---- | ------------------ |
  | Deploy the subscription-scoped Bicep template and create the target resource group | [Contributor](/azure/role-based-access-control/built-in-roles#contributor) on the subscription |
  | Assign subscription roles to the agent managed identity | [Role Based Access Control Administrator](/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator), [User Access Administrator](/azure/role-based-access-control/built-in-roles#user-access-administrator), or [Owner](/azure/role-based-access-control/built-in-roles#owner) on the subscription |
  | Create or update the custom zone peers role in post-provision | Permission to create role definitions and role assignments on the subscription |
  | Assign Azure Data Explorer access when cluster parameters are set | Permission to create `Microsoft.Kusto/clusters/principalAssignments` on the target cluster |
  | Apply Azure SRE Agent objects with `srectl` | Access to the deployed Azure SRE Agent endpoint |

- The `Microsoft.App` resource provider must be registered in the subscription.
- The [Azure Developer CLI (`azd`)](/azure/developer/azure-developer-cli/install-azd), [Azure CLI](/cli/azure/install-azure-cli), .NET SDK, and `python3` must be available locally.
- A FinOps hub with Azure Data Explorer is required when you want the agent to query hub data.
<!-- prettier-ignore-end -->

<br>

## Parameters

Here are the parameters you can use to customize the deployment:

| Parameter | Type | Default value | Allowed values | Description |
| --------- | ---- | ------------- | -------------- | ----------- |
| **environmentName** | String | None | Any string | Required. Name of the `azd` environment. |
| **location** | String | `eastus2` | `swedencentral`, `eastus2`, `australiaeast` | Optional. Primary location for all resources. |
| **resourceGroupName** | String | `rg-${environmentName}` | Any string | Optional. Resource group name override. |
| **adxClusterName** | String | `""` | Any string | Optional. Azure Data Explorer cluster name for the FinOps hub role assignment. |
| **adxClusterResourceGroupName** | String | `""` | Any string | Optional. Resource group that contains the Azure Data Explorer cluster. |
| **deployerPrincipalType** | String | `User` | `User`, `ServicePrincipal` | Optional. Principal type for the deploying identity. Use `ServicePrincipal` for CI/CD pipelines. |
| **finopsHubClusterUri** | String | `""` | Any valid Kusto cluster URI with database name | Optional. FinOps hub Azure Data Explorer cluster URI, such as `https://cluster.region.kusto.windows.net/hub`. |

<br>

## Environment values

The deployment wrapper sets these `azd` environment values before it runs `azd up`:

| Environment value | Source | Description |
| ----------------- | ------ | ----------- |
| **AZURE_ENV_NAME** | `--environment` or `-Environment` | Target `azd` environment name. |
| **AZURE_LOCATION** | `--location` or `-Location` | Azure location for the deployment. Defaults to `eastus2`. |
| **AZURE_PRINCIPAL_TYPE** | `--principal-type` or `-PrincipalType` | Deployer principal type. Defaults to `User`. |
| **AZURE_RESOURCE_GROUP** | `--resource-group` or `-ResourceGroup` | Target resource group. Defaults to the environment name in the wrapper script. |
| **AZURE_SUBSCRIPTION_ID** | `--subscription` or `-Subscription` | Azure subscription ID. Defaults to the current Azure CLI account. |
| **FINOPS_HUB_CLUSTER_URI** | `--finops-hub-cluster-uri` or `-FinopsHubClusterUri` | Required FinOps hub Azure Data Explorer cluster URI. |
| **FINOPS_HUB_CLUSTER_NAME** | `--finops-hub-cluster-name` or `-FinopsHubClusterName` | Optional cluster name used to assign `AllDatabasesViewer`. |
| **FINOPS_HUB_CLUSTER_RESOURCE_GROUP** | `--finops-hub-cluster-resource-group` or `-FinopsHubClusterResourceGroup` | Optional cluster resource group used to assign `AllDatabasesViewer`. |

<br>

## Outputs

Here are the `azd` environment outputs generated by the deployment:

| Output | Type | Description |
| ------ | ---- | ----------- |
| **AZURE_RESOURCE_GROUP** | String | Name of the Azure resource group that contains the SRE Agent resources. |
| **AZURE_LOCATION** | String | Azure location used for the SRE Agent resources. |
| **SRE_AGENT_NAME** | String | Name of the deployed Azure SRE Agent resource. |
| **SRE_AGENT_ENDPOINT** | String | Endpoint of the deployed Azure SRE Agent resource. |

<br>

## Script flags

The template includes Bash and PowerShell scripts for one-shot deployment and post-provision configuration.

### Deployment wrapper

Use `deploy.sh` or `deploy.ps1` to create or select an `azd` environment, set environment values, deploy the template, and refresh outputs.

| Bash flag | PowerShell parameter | Required | Description |
| --------- | -------------------- | -------- | ----------- |
| `--environment <name>` | `-Environment <name>` | Yes | Target `azd` environment name. |
| `--location <region>` | `-Location <region>` | No | Azure location. Defaults to `eastus2`. |
| `--subscription <subscription-id>` | `-Subscription <subscription-id>` | No | Azure subscription ID. Defaults to the current Azure CLI account. |
| `--resource-group <name>` | `-ResourceGroup <name>` | No | Azure resource group. Defaults to the environment name in the wrapper script. |
| `--principal-type <type>` | `-PrincipalType <type>` | No | Deployer principal type. Defaults to `User`. |
| `--finops-hub-cluster-uri <uri>` | `-FinopsHubClusterUri <uri>` | Yes, unless `--destroy` or `-Destroy` is used | FinOps hub Kusto cluster URI. |
| `--finops-hub-cluster-name <name>` | `-FinopsHubClusterName <name>` | No | Azure Data Explorer cluster name for `AllDatabasesViewer` assignment. |
| `--finops-hub-cluster-resource-group <name>` | `-FinopsHubClusterResourceGroup <name>` | No | Azure Data Explorer cluster resource group. |
| `--env-file <path>` | `-EnvFile <path>` | No | Load `azd`-style values from a `.env` file before applying overrides. |
| `--clone-env <name>` | `-CloneEnv <name>` | No | Load values from `.azure/<name>/.env` before applying overrides. Can't be used with `--env-file` or `-EnvFile`. |
| `--replace` | `-Replace` | No | Delete Azure resources for the target environment first, remove the local `azd` environment, and then recreate it. |
| `--destroy` | `-Destroy` | No | Tear down the target environment and remove it without deploying. |
| `-h`, `--help` | `-Help` | No | Show script help. |

### Post-provision

Use `post-provision.sh` or `post-provision.ps1` to install `srectl`, initialize the deployed agent endpoint, apply agents, skills, tools, knowledge documents, scheduled tasks, and create custom Azure permissions.

| Bash flag | PowerShell parameter | Required | Description |
| --------- | -------------------- | -------- | ----------- |
| `--dry-run` | `-DryRun` | No | Log the changes that would be applied without validating the endpoint, installing `srectl`, initializing the workspace, creating custom permissions, or applying configuration. |

<br>

## Module structure

The template uses a subscription-scoped entry point and resource group modules:

| File | Scope | Deploys or configures |
| ---- | ----- | --------------------- |
| `infra/bicep/main.bicep` | Subscription | Creates the target resource group, calls the resource group deployment, assigns subscription RBAC, and optionally assigns Azure Data Explorer roles. |
| `infra/bicep/resources.bicep` | Resource group | Orchestrates identity, monitoring, and Azure SRE Agent modules, then surfaces outputs to the subscription deployment. |
| `infra/bicep/modules/identity.bicep` | Resource group | Creates the user-assigned managed identity used by the agent. |
| `infra/bicep/modules/monitoring.bicep` | Resource group | Creates the Log Analytics workspace and workspace-based Application Insights component for telemetry. |
| `infra/bicep/modules/sre-agent.bicep` | Resource group | Creates the `Microsoft.App/agents` resource, enables workspace tools, configures autonomous actions, assigns SRE Agent Administrator to the deployer, and creates the optional FinOps hub Kusto connector. |
| `infra/bicep/modules/subscription-rbac.bicep` | Subscription | Assigns Reader and Monitoring Contributor to the agent user-assigned managed identity. |
| `infra/bicep/modules/adx-role.bicep` | Resource group | Assigns `AllDatabasesViewer` on an existing Azure Data Explorer cluster to the user-assigned and system-assigned managed identities when cluster parameters are provided. |

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
- [Azure Developer CLI](/azure/developer/azure-developer-cli/overview)

Related solutions:

- [Deploy Azure SRE Agent with the FinOps toolkit](deploy.md)
- [Azure SRE Agent in the FinOps toolkit](overview.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
