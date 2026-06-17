# FinOps toolkit SRE Agent

Deploy and configure an Azure SRE Agent with the FinOps toolkit recipe under `recipes/finops-hub/`.

The deployment flow is copied from the Microsoft SRE Agent starter lab and updated for the FinOps toolkit:

- Azure CLI + Bicep deploy the SRE Agent infrastructure.
- `bin/apply-extras.sh` applies recipe assets that are not deployed by Bicep: connectors, KnowledgeFile sources, built-in tool configuration, tools, skills, subagents, and scheduled tasks.
- `azd` is not used.

## What you get

| Component | Count | Description |
|-----------|-------|-------------|
| SRE Agent | 1 | `Microsoft.App/agents` resource |
| Model provider | 1 | Azure OpenAI provider-level routing (`MicrosoftFoundry` ARM value, `Automatic` model routing) |
| Managed identity | 1 | Agent system-assigned managed identity |
| Log Analytics | 1 | Workspace for agent telemetry |
| Application Insights | 1 | Linked to Log Analytics |
| Custom agents | 5 | FinOps practitioner orchestrator plus CFO, capacity, database-query, and hubs specialists |
| Skills | 3 | Azure capacity management, Azure cost management, and FinOps Toolkit |
| Tools | 50 | Kusto, capacity, and Hub infrastructure tools |
| Tool overrides | 9 | Enables SRE Agent Log Query and Visualization tools |
| Scheduled tasks | 19 | Recurring FinOps, capacity, governance, and reporting tasks, all owned by `finops-practitioner` |
| Connectors | 1 | Optional FinOps Hub Kusto connector when `--cluster-uri` is provided |
| Knowledge docs | 6 | Five recipe knowledge docs plus the FinOps Toolkit output style |

## Current recipe inventory

The current implementation is the `recipes/finops-hub/` recipe. [CATALOG.md](CATALOG.md) is the authoritative inventory and FinOps Framework alignment reference, including the subagent-to-capability, tool, and scheduled-task matrix; this section summarizes what ships.

| Agent | Scheduled tasks owned | Focus |
|-------|----------------------:|-------|
| `finops-practitioner` | 19 | Sole scheduled-task owner. Runs the operating rhythm, delegates specialist evidence collection, applies the output style, assembles reports, and delivers results. |
| `azure-capacity-manager` | 0 | Tool-bearing delegated subagent for quota, capacity reservation groups, region and zone access, AKS capacity, and capacity evidence. Owns the capacity Python tools; does not own Kusto, Resource Graph, Hub freshness, CLI, or remediation deployment tools. |
| `chief-financial-officer` | 0 | Consultative subagent with no tools. Provides finance and leadership framing for budgeting, forecasting, AI unit economics, commitment risk, and executive decisions from evidence supplied by the practitioner. |
| `ftk-database-query` | 0 | Tool-bearing delegated subagent for schema-aware FinOps Hub KQL and database evidence. Owns the Kusto tools; does not own Python, Azure CLI, Resource Graph, Hub freshness, or remediation deployment tools. |
| `ftk-hubs-agent` | 0 | Tool-bearing delegated subagent for Hub health, data freshness, monitoring scope validation, deployment, upgrade, connector readiness, Resource Graph inventory, and explicit remediation deployment tooling. |

| Tool type | Count | Examples |
|-----------|------:|----------|
| KustoTool | 37 | `cost-anomaly-detection`, `allocation-accuracy-index`, `cost-optimization-index`, `reservation-recommendation-breakdown` |
| PythonTool | 13 | `vm-quota-usage`, `data-freshness-check`, `db-service-quotas`, `sku-availability` |

The infrastructure deploys `Microsoft.App/agents@2026-01-01` on the `Preview` upgrade channel with `EnableSandboxGroup` and `EnableWorkspaceTools` enabled. This matches the upstream SRE Agent template default and enables the extended-agent skill, tool, subagent, and schedule APIs used by the recipe. The recipe defaults the parent SRE Agent to Azure OpenAI provider-level routing (`defaultModel.provider = MicrosoftFoundry`, `defaultModel.name = Automatic`). Azure SRE Agent selects the model within the configured provider; this template does not pin different models per custom agent or scheduled task. `bin/apply-extras.sh` enables the SRE Agent built-in Log Query and Visualization tools. It uploads the recipe knowledge files and the shared FinOps Toolkit output style from `../claude-plugin/output-styles/ftk-output-style.md` as portal-visible `KnowledgeFile` sources, then verifies the expected sources are indexed before tools, subagents, and scheduled tasks are applied. Scheduled tasks reference `ftk-output-style.md` so recurring reports use the same evidence, formatting, FinOps capability, confidence, and disclaimer conventions.

Skills are applied with their `SKILL.md` content and tool references. The FinOps Toolkit query references resolve through the canonical `src/queries` catalog so the SRE Agent recipe does not carry a stale copy. Supporting reference material that must be available to the agent should be uploaded as KnowledgeFile sources; the current SRE Agent data plane rejects skill payloads with non-empty `additionalFiles`.

Scheduled reports must distinguish product or deployment defects from expected evaluation-data limits and customer-owned delegation. Limited Hub history, empty transaction diagnostics, and missing multi-period trigger evidence reduce confidence; they are not by themselves deployment failures. Broader management group, billing, quota, or subscription visibility should be reported as a required customer delegation step unless this template explicitly owns the role assignment.

The recipe is aligned to the FinOps Framework references listed in [CATALOG.md](CATALOG.md). `finops-practitioner` owns all scheduled tasks, has no direct tools, and orchestrates four delegated subagents. Three delegated subagents have tools: `ftk-database-query` owns Kusto and FOCUS evidence collection, `azure-capacity-manager` owns capacity Python evidence, and `ftk-hubs-agent` owns Hub platform and infrastructure health tooling. `chief-financial-officer` is consulted for finance and leadership framing and has no tools or scheduled tasks. Capacity and quota management is mapped into the canonical domains, capabilities, personas, principles, and phases, not a separate azcapman operating model.

The phase model is iterative:

| Phase | How the recipe uses it |
|-------|------------------------|
| Inform | Build trusted cost, usage, allocation, forecast, unit-economics, data freshness, and capacity-headroom evidence. |
| Optimize | Identify rate, usage, workload placement, SKU, quota, CRG, and architecture opportunities with business-value tradeoffs. |
| Operate | Run scheduled governance, budget, alert, reporting, connector, and continuous-improvement workflows. |

| Scheduled task | Owning agent | Schedule |
|----------------|-------|----------|
| `CapacityDailyMonitor` | `finops-practitioner` | `30 6 * * *` |
| `HubsHealthCheck` | `finops-practitioner` | `0 6 * * *` |
| `Monthly` | `finops-practitioner` | `15 17 5 * *` |
| `CapacityWeeklySupplyReview` | `finops-practitioner` | `0 8 * * 1` |
| `ComputeUtilizationTrend` | `finops-practitioner` | `0 7 * * 1` |
| `CostOptimization` | `finops-practitioner` | `0 8 * * 1` |
| `NonComputeQuotaAudit` | `finops-practitioner` | `0 7 * * 2` |
| `DbQuotaAudit` | `finops-practitioner` | `0 7 * * 3` |
| `SkuAvailabilityAudit` | `finops-practitioner` | `30 7 * * 3` |
| `MonitoringScopeValidation` | `finops-practitioner` | `0 9 * * 4` |
| `BenefitRecommendationReview` | `finops-practitioner` | `0 8 * * 5` |
| `AdvisorSuppressionReview` | `finops-practitioner` | `0 9 1 * *` |
| `AIWorkloadCostAnalysis` | `finops-practitioner` | `0 10 1 * *` |
| `CapacityMonthlyPlanning` | `finops-practitioner` | `0 9 1 * *` |
| `StoragePaasGrowthForecast` | `finops-practitioner` | `0 8 1 * *` |
| `Semiannual` | `finops-practitioner` | `0 9 5 1,7 *` |
| `BudgetCoverageAudit` | `finops-practitioner` | `0 8 15 * *` |
| `AlertCoverageAudit` | `finops-practitioner` | `0 8 16 * *` |
| `CapacityQuarterlyStrategy` | `finops-practitioner` | `0 9 1 1,4,7,10 *` |

## Prerequisites

- Azure CLI (`az`)
- `curl`
- `jq`
- `python3` with PyYAML
- Bash 3.2 or newer
- `Microsoft.App` registered in the target subscription

Run:

```bash
bash bin/check-prerequisites.sh --subscription <subscription-id>
```

## Deploy

Run one script with explicit parameters:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --subscription <subscription-id> \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/Hub \
  [--cluster-resource-id /subscriptions/.../providers/Microsoft.Kusto/clusters/<name>] \
  [--target-resource-group <target-rg> ...] \
  [--dry-run] \
  [--force]
```

`bin/deploy.sh --help` is the CLI contract:

```text
Usage: bash bin/deploy.sh --recipe <dir> [options]

Required:
  --recipe <dir>                      Recipe directory
  --subscription <id>                 Azure subscription
  -g, --resource-group <name>         Resource group for the agent
  -n, --name <name>                   Agent name
  -l, --location <region>             Azure region

Optional:
  --target-resource-group <name>      Repeatable target resource group. The agent resource group is always included.
  --cluster-uri <uri>                 Kusto connector URI, including database name.
                                      Example: https://<cluster>.<region>.kusto.windows.net/Hub
  --cluster-resource-id <id>          Optional Kusto cluster ARM resource ID. Real deployments resolve this from --cluster-uri when possible; dry-run requires it.
  --no-subscription-reader            Do not assign Reader at subscription scope. Default: assign Reader.
  --deployer-principal-type <type>    Principal type of the deployer (User or ServicePrincipal). Default: User.
  --deploy-name <name>                Deployment name override. Defaults to a deterministic name.
  --dry-run                           Validate inputs and write parameters without Azure calls.
  --force                             Accepted for compatibility.
  -h, --help                          Show this help.
```

### Modes

Dry-run is hermetic and does not call Azure:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --subscription <subscription-id> \
  -g <your-rg> \
  -n <your-agent-name> \
  -l <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/Hub \
  [--cluster-resource-id /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster>] \
  --dry-run
```

You can also validate the local extras assembly without Azure calls:

```bash
bash bin/apply-extras.sh \
  --endpoint https://example.sre.azure.com \
  --subscription <subscription-id> \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --recipe recipes/finops-hub \
  --build-dir /tmp/ftk-sre-agent-extras \
  --kusto-connector-uri https://<your-cluster>.<your-region>.kusto.windows.net/Hub \
  --dry-run
```

When deploying, `deploy.sh` runs a subscription-scoped ARM deployment and then runs `bin/apply-extras.sh` to apply the recipe extras. The helper follows the upstream SRE Agent template pattern: connectors and KnowledgeFile sources use ARM child resources, while built-in tool configuration, custom tools, skills, subagents, and scheduled tasks use the SRE Agent data plane.

Supporting resource names are deterministic for the subscription ID, agent resource group ID, and agent name. Rerunning the script with the same values updates the same Log Analytics workspace, Application Insights component, system-managed identity RBAC assignments, and SRE Agent. The apply-extras step deletes existing scheduled tasks with the recipe's task names before applying manifests so redeployments don't create duplicate automations. `--deploy-name` only changes the ARM deployment record and local build directory.

The deployment intentionally keeps the SRE Agent onboarding wizard in the portal. The wizard uses the agent managed identity first to discover managed Azure resources and may show a **Grant permissions** OBO prompt if the identity cannot read a scope yet. Do not bypass that flow. Instead, confirm the agent has the expected managed-resource scopes and RBAC:

- The deployment assigns `Reader` at subscription scope by default so subscription inventory, Resource Graph, capacity, quota, and coverage tools can inspect the deployment subscription. Pass `--no-subscription-reader` only when you grant equivalent read access another way.
- The agent resource group is always added to `knowledgeGraphConfiguration.managedResources` and receives the recipe's target-scope RBAC.
- Each `--target-resource-group` value is added to managed resources and receives the same target-scope RBAC.
- When `--cluster-uri` resolves to a same-subscription FinOps Hub Kusto cluster, the cluster's resource group is also added to managed resources and receives target-scope RBAC.
- With the default `High` recipe, target-scope RBAC is `Reader`, `Monitoring Reader`, `Log Analytics Reader`, and `Contributor`. `Low` omits `Contributor`.

If `--cluster-uri` points to an Azure Data Explorer cluster with `publicNetworkAccess` set to `Disabled`, the script still deploys all resources, assigns the agent identity `AllDatabasesViewer` on the cluster, and creates the `finops-hub-kusto` connector. It also prints a warning with the SRE Agent known-limitations URL because private endpoint ADX blocks direct KQL queries from the hosted agent. The customer can decide whether to enable public query access for the connector after reviewing <https://sre.azure.com/docs/capabilities/azure-observability-vnet#known-limitations>.

## Recipe identity policy

- Shipped recipes in this repo omit the `identity` block.
- Customer-authored recipes may include `identity` defaults for reproducible deployments.
- CLI flags always win over recipe defaults.

If you omit `--target-resource-group`, the deploy flow still scopes the agent to its own resource group. If a same-subscription `--cluster-uri` is provided, the FinOps Hub resource group is also included automatically.

## Verify

```bash
bash bin/verify-agent.sh \
  $(az account show --query id -o tsv) \
  <your-rg> \
  <your-agent-name> \
  --expected recipes/finops-hub
```

If you passed `--cluster-uri`, confirm the `finops-hub-kusto` connector in `https://sre.azure.com`. If the deployment warned that the cluster denies public query access, the connector is expected to remain unhealthy until the customer enables public query access or Microsoft adds private endpoint ADX query support for SRE Agent.

## CI/CD example

The GitHub Actions example passes the cluster URI as a script flag while keeping secrets such as `GITHUB_PAT` or `ADO_PAT` in the environment.

## Migrating from env-var-driven deploys

The old deploy path accepted config through environment variables such as `FINOPS_HUB_CLUSTER_URI`, `FINOPS_HUB_CLUSTER_RESOURCE_ID`, and `connectors.secrets.env`. Those inputs are no longer supported for config or identity.

Before:

```bash
export FINOPS_HUB_CLUSTER_URI="https://<your-cluster>.<your-region>.kusto.windows.net/hub"
export FINOPS_HUB_CLUSTER_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster>"
bash bin/deploy.sh recipes/finops-hub
```

After:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --subscription <subscription-id> \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/Hub \
  --cluster-resource-id /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster>
```

The only supported environment-variable inputs are secrets:

- `GITHUB_PAT`
- `ADO_PAT`
- `ADO_USE_AAD`
- `ADO_USE_MI`
- `ADO_ORG`
