# FinOps SRE Agent

Deploy and configure an Azure SRE Agent with FinOps and capacity management capabilities. `azd up` provisions the Azure infrastructure, creates the SRE Agent in Autonomous mode, assigns the required permissions, and runs the post-provision hook to apply agents, skills, knowledge, and the FinOps Hub Kusto connector. Outlook and Teams notification connectors are supported, but Microsoft Learn currently documents them as portal-based OAuth setup after deployment rather than `azd`/`srectl` automation.

## What you get

| Component | Count | Description |
|-----------|-------|-------------|
| SRE Agent | 1 | `Microsoft.App/agents` resource (Autonomous mode) |
| Managed identity | 1 | User-assigned managed identity for the agent |
| Log Analytics | 1 | Workspace for agent telemetry |
| Application Insights | 1 | Linked to Log Analytics for monitoring |
| Subscription RBAC | 2 | Reader + Monitoring Contributor role assignments |
| Custom role (post-provision) | 1 | `FinOps SRE Zone Peers Reader` for cross-subscription zone mapping; created by `post-provision.sh` so the assignable scope can be elevated to management group level for multi-subscription capacity management |
| ADX role (optional) | 1 | `AllDatabasesViewer` when ADX params provided |
| Subagents | 5 | `azure-capacity-manager`, `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `ftk-hubs-agent` |
| Skills | 3 | `azure-capacity-management`, `azure-cost-management`, `finops-toolkit` |
| Tools | 33 | 21 Kusto (KQL queries against FinOps Hub) + 12 Python (ARM REST API via UAMI) |
| Scheduled tasks | 18 | 9 core (daily/weekly/monthly/quarterly reporting) + 9 capacity/governance audits |
| Connector | 1 | Kusto MCP connector to FinOps Hub ADX cluster |
| Notification connectors (optional) | 0 by default | Outlook and Teams can be added after deployment in the portal; not provisioned by `azd up` because setup requires interactive OAuth |

## Deployment options

### Recommended: deploy with the packaged script

The redistribution-safe entrypoint for this template is a single wrapper script that creates or selects the `azd` environment, sets required values, and runs `azd up` for you.

#### Bash

```bash
bash ./scripts/deploy.sh \
  --environment ftk-sre-test3 \
  --finops-hub-cluster-uri https://<your-finops-hub-cluster>.kusto.windows.net
```

#### PowerShell

```powershell
pwsh ./scripts/deploy.ps1 `
  -Environment ftk-sre-test3 `
  -FinopsHubClusterUri https://<your-finops-hub-cluster>.kusto.windows.net
```

Helpful options:

- `--clone-env <name>` / `-CloneEnv <name>` to copy values from an existing local `azd` environment.
- `--replace` / `-Replace` to tear down the target environment and recreate it before deployment.
- `--finops-hub-cluster-name` and `--finops-hub-cluster-resource-group` when you also want the optional ADX `AllDatabasesViewer` role assignment.

Example for a clean evaluation rollout derived from an existing local environment:

```bash
bash ./scripts/deploy.sh \
  --environment ftk-sre-test3 \
  --clone-env ftk-sre-test2 \
  --replace
```

The wrapper uses the Azure Developer CLI environment flow documented by Microsoft Learn and follows the same `azure.yaml` + `post-provision.sh` packaging pattern used by the official `microsoft/sre-agent` examples.

### Advanced/manual: deploy with `azd up`

```bash
azd env new <environment-name>

# Required for post-provision connector configuration
azd env set FINOPS_HUB_CLUSTER_URI https://<your-finops-hub-cluster>.kusto.windows.net

# Optional: enable ADX AllDatabasesViewer role assignment
azd env set FINOPS_HUB_CLUSTER_NAME <your-adx-cluster-name>
azd env set FINOPS_HUB_CLUSTER_RESOURCE_GROUP <adx-cluster-resource-group>

azd up
```

`azd up` is the primary automation path. It deploys `infra/bicep/main.bicep`, publishes the SRE Agent endpoint as the `SRE_AGENT_ENDPOINT` output, and runs `bash ./scripts/post-provision.sh` as the `postprovision` hook.

The ADX role assignment is optional. Set `FINOPS_HUB_CLUSTER_NAME` and `FINOPS_HUB_CLUSTER_RESOURCE_GROUP` when you want the deployment to grant the agent managed identity `AllDatabasesViewer` on your FinOps Hub ADX cluster.

### Portal: Deploy to Azure button

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template)

The button above opens Azure Portal **Custom deployment**.

Use the portal flow when you want a portal-driven deployment of the ADX `AllDatabasesViewer` role assignment only:

1. Select the button above.
2. Choose **Build your own template in the editor**.
3. Paste or upload `infra/bicep/modules/adx-role.json` from this repo.
4. Select the ADX cluster's resource group as the deployment scope.
5. Supply `clusterName`, `principalId`, and (optionally) `principalTenantId`.
6. Review and create the deployment.

Unlike `azd up`, the portal button does **not** run the `postprovision` hook from `azure.yaml`, so it does **not** deploy the full SRE Agent stack or upload the 5 subagents, 3 skills, knowledge docs, or the `finops-hub-kusto` connector.

## Post-deploy verification

- After `azd up`, confirm the ARM deployment succeeds and the `postprovision` hook completes without errors.
- Open [sre.azure.com](https://sre.azure.com) and confirm the SRE Agent has the 5 subagents, 3 skills, and `finops-hub-kusto` connector.
- Confirm the base SRE Agent has workspace tools and visualization enabled so built-in code execution, chart generation, and PDF report creation are available by default. In the deployed ARM resource this is `properties.experimentalSettings.EnableWorkspaceTools = true` and `properties.experimentalSettings.EnableVisualization = true`.
- Confirm the default analytical subagents include `execute_python`: `azure-capacity-manager`, `finops-practitioner`, `chief-financial-officer`, and `ftk-database-query`.
- If you enabled the ADX role assignment, confirm the target ADX cluster shows an `AllDatabasesViewer` principal assignment for the agent managed identity.
- If you need notifications, add Outlook and Teams connectors manually in the portal and send one test email plus one test Teams post from the agent chat.
- After the portal-only flow, expect **only** the ADX role assignment to exist.

### B2B tenant note for `srectl`

In B2B environments, the Azure subscription and SRE Agent resource can live in a different Microsoft Entra tenant than your Microsoft 365 home tenant.

If [sre.azure.com](https://sre.azure.com) shows the agent and its configuration correctly but `srectl` returns `401`, `403`, or `Forbidden: Access denied by PDP`, treat that as a tenant-selection problem first, not immediate evidence that the deployment is broken.

Before troubleshooting the deployment itself:

1. Confirm the active Azure CLI context points at the subscription that owns the SRE Agent resource.
2. Re-authenticate Azure CLI against the tenant that owns the Azure subscription/resource.
3. Re-run `srectl init --resource-url <SRE_AGENT_ENDPOINT>`, then retry `srectl status`, `srectl agent list`, or other API calls.

Browser success with CLI failure usually means the agent is healthy and the CLI token was issued for the wrong tenant.

### Built-in DocsGuide, visualization, and code interpreter

Per Microsoft Learn, Azure SRE Agent already includes built-in documentation access (**DocsGuide**), built-in Azure visualization capabilities, and built-in code execution support. We rely on those platform capabilities rather than shipping custom repo tools for them:

- [Use DocsGuide in Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/use-docsguide)
- [Tools in Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/tools)
- [Use Code Interpreter in Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/use-code-interpreter)

For this template, "enabled by default" means:

1. The deployed `Microsoft.App/agents` resource turns on workspace tools and visualization in `experimentalSettings` (`EnableWorkspaceTools = true`, `EnableVisualization = true`).
2. The default analytical subagents ship with `execute_python` so they can turn Azure and FinOps data into charts, tables, and downloadable report artifacts without extra manual setup.
3. Built-in DocsGuide capabilities come from the SRE platform itself, so they don't require separate YAML tool definitions in this repo.

### Enable Outlook and Teams notifications

Per Microsoft Learn, Outlook and Teams notifications are supported by Azure SRE Agent, but their setup is an interactive portal flow that requires OAuth sign-in plus a managed identity. They are not currently provisioned through this repo's Bicep templates or `post-provision` scripts.

References:

- [Set up an Outlook connector in Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/outlook-connector)
- [Set up the Teams connector in Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/set-up-teams-connector)
- [Send notifications in Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/send-notifications)
- [Connectors in Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/connectors)
- [Agent identity in Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/agent-identity)

Prerequisites from Microsoft Learn:

- The agent must already exist.
- A system-assigned or user-assigned managed identity must be configured on the agent.
- The configuring user needs **Contributor** on the agent resource group, including `Microsoft.Web/connections/write` and `Microsoft.Authorization/roleAssignments/write`.
- Outlook requires a Microsoft 365 account with mailbox access.
- Teams requires access to the target channel and its **Get link to channel** URL.

Manual post-deployment steps:

1. Open [sre.azure.com](https://sre.azure.com), open the deployed agent, then go to **Builder** > **Connectors**.
2. Add **Outlook Tools (Office 365 Outlook)**, complete OAuth sign-in, select the agent managed identity, and save.
3. Add **Send notification (Microsoft Teams)**, complete OAuth sign-in, paste the Teams channel link, select the agent managed identity, and save.
4. Test the connectors from chat with:
   - `Send an email to <recipient> with subject "SRE Agent Test" and body "Outlook connector is working"`
   - `Post to our Teams channel: "SRE Agent is connected and ready for notifications"`

Current product limitation:

- Microsoft Learn does not document an ARM/Bicep resource, `srectl` command, or YAML schema for provisioning Outlook or Teams connectors.
- Because the setup requires interactive OAuth, `azd up` and `scripts/post-provision.*` intentionally do **not** attempt to automate these connectors.

## Architecture

```
azd up
  ├── Bicep: infra/bicep/main.bicep (subscription-scoped)
  │   ├── Resource group creation
  │   ├── resources.bicep (RG-scoped orchestrator)
  │   │   ├── identity.bicep → User-assigned managed identity
  │   │   ├── monitoring.bicep → Log Analytics + Application Insights
  │   │   └── sre-agent.bicep → SRE Agent (Autonomous mode)
  │   ├── subscription-rbac.bicep → Reader + Monitoring Contributor
  │   └── adx-role.bicep (conditional) → AllDatabasesViewer on ADX cluster
  └── postprovision hook (srectl)
       ├── srectl init --resource-url ${SRE_AGENT_ENDPOINT}
       ├── srectl skill apply (3 skills)
       ├── srectl agent apply (5 subagents)
       ├── srectl doc upload (knowledge docs)
       └── srectl connector apply (Kusto MCP → FinOps Hub)
```

## Repository structure

```
finops-sre-agent/
├── azure.yaml
├── infra/bicep/
│   ├── main.bicep                          # Subscription-scoped entry point
│   ├── resources.bicep                     # RG-scoped orchestrator
│   └── modules/
│       ├── identity.bicep                  # User-assigned managed identity
│       ├── monitoring.bicep                # Log Analytics + App Insights
│       ├── sre-agent.bicep                 # SRE Agent resource
│       ├── subscription-rbac.bicep         # Reader + Monitoring Contributor
│       ├── adx-role.bicep                  # ADX AllDatabasesViewer (conditional)
│       └── adx-role.json                   # ARM JSON for portal deployment
├── sre-config/
│   ├── agents/                             # 5 subagent YAMLs
│   ├── skills/                             # 3 skill directories
│   ├── connectors/                         # Kusto MCP connector YAML
│   └── knowledge/                          # Reference docs for upload
├── scripts/
│   ├── deploy.sh                          # Single packaged deployment entrypoint (Bash)
│   ├── deploy.ps1                         # Single packaged deployment entrypoint (PowerShell)
│   └── post-provision.sh                   # srectl automation
├── tests/
│   └── sprint1-artifacts.test.mjs          # Template validation tests
└── README.md
```

## Prerequisites

- Azure subscription with permissions to create resource groups and assign RBAC roles
- [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- A deployed [FinOps Hub](https://learn.microsoft.com/en-us/azure/cost-management-billing/finops/toolkit/hubs/finops-hubs-overview) with an ADX cluster
- [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0) for `srectl`
- `python3` and `bash` available locally for `scripts/post-provision.sh`
- **For zone-mapping:** The `AvailabilityZonePeering` feature must be registered on the subscription. The `checkZonePeers` API returns 404 without it. Register at the management group level if the agent manages capacity across multiple subscriptions:

  ```bash
  az feature register --namespace Microsoft.Resources --name AvailabilityZonePeering
  # Wait for registration to propagate (~5 min), then re-register the provider:
  az provider register --namespace Microsoft.Resources
  ```

## Supported regions

The SRE Agent deployment is supported in `swedencentral`, `eastus2`, and `australiaeast` only. The Bicep template enforces these regions with `@allowed`.

## How it works

1. **Bicep** creates the resource group, user-assigned managed identity, Log Analytics workspace, Application Insights resource, and SRE Agent.
2. **Bicep** assigns Reader and Monitoring Contributor at the subscription scope to the agent managed identity.
3. **Bicep** optionally assigns `AllDatabasesViewer` on the target ADX cluster when ADX parameters are provided.
4. **`post-provision.sh`** creates a custom role (`FinOps SRE Zone Peers Reader`) with `Microsoft.Resources/checkZonePeers/action` and assigns it to the managed identity. This enables the zone-mapping tool to check availability zone alignment across subscriptions. For multi-subscription capacity management, elevate the assignable scope to a management group so the agent can map zones across all child subscriptions.
5. **`post-provision.sh`** installs `srectl`, initializes it with the `SRE_AGENT_ENDPOINT` deployment output, and pushes all configuration:
   - 3 skills (capacity management, cost management, FinOps toolkit)
   - 5 subagents (capacity manager, CFO, FinOps practitioner, database query, hubs agent)
   - Knowledge documents under `sre-config/knowledge/`
   - Kusto MCP connector pointed at your FinOps Hub
5. **You optionally add** Outlook and Teams notification connectors in [sre.azure.com](https://sre.azure.com) when you want email or Teams delivery.
6. **You open** [sre.azure.com](https://sre.azure.com) and start asking questions.

The uploaded knowledge documents can steer post-deployment onboarding. In practice, this means the agent can recommend connector setup during **Team onboarding**, after `/learn`, or when the user asks **"What should I do next?"**

## Cost estimate

The template provisions an SRE Agent, a Log Analytics workspace, an Application Insights resource, and a user-assigned managed identity. Costs depend on the selected region, SRE Agent preview pricing, telemetry ingestion and retention in Log Analytics and Application Insights, and the existing FinOps Hub ADX footprint you connect to. The managed identity and RBAC assignments do not typically add direct cost.

## Attribution

Infrastructure adapted from [azure-sre-agent-sandbox](https://github.com/matthansen0/azure-sre-agent-sandbox) (MIT) and [sre-agent-lab](https://github.com/dm-chelupati/sre-agent-lab). Post-provision pattern follows the `azd` + `srectl` approach from `dm-chelupati/sre-agent-lab`.

## License

MIT
