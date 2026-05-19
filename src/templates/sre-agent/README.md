# FinOps toolkit SRE Agent

Deploy and configure an Azure SRE Agent with the FinOps toolkit recipe under `recipes/finops-hub/`.

## What you get

| Component | Count | Description |
|-----------|-------|-------------|
| SRE Agent | 1 | `Microsoft.App/agents` resource |
| Managed identity | 1 | User-assigned identity plus system-assigned identity |
| Log Analytics | 1 | Workspace for agent telemetry |
| Application Insights | 1 | Linked to Log Analytics |
| Subagents | 5 | FinOps, CFO, capacity, database-query, and hubs specialists |
| Skills | 3 | Azure capacity management, Azure cost management, and FinOps Toolkit |
| Tools | 34 | Kusto and Python tools for FinOps and capacity analysis |
| Scheduled tasks | 19 | Recurring FinOps, capacity, governance, and reporting tasks |
| Connector | 1 | Optional FinOps Hub Kusto connector when `--cluster-uri` is provided |

## Prerequisites

- Azure CLI (`az`)
- `jq`
- `python3` with PyYAML
- `curl`
- Bash 3.2 or newer
- `Microsoft.App` registered in the target subscription
- `srectl` only when using `--fallback-srectl`

Run:

```bash
bash bin/check-prerequisites.sh --subscription <subscription-id>
```

## Deploy

Run one script with explicit parameters:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/hub \
  [--subscription <subscription-id>] \
  [--target-resource-group <target-rg> ...] \
  [--cluster-resource-id /subscriptions/.../providers/Microsoft.Kusto/clusters/<name>] \
  [--dry-run | --what-if] \
  [--force] \
  [--fallback-srectl] \
  [--no-telemetry]
```

`bin/deploy.sh --help` is the CLI contract:

```text
Usage: bash bin/deploy.sh --recipe <dir> [options]
       bash bin/deploy.sh <legacy.parameters.json> [options]

Required for recipe directories:
  --recipe <dir>                        Recipe directory to assemble
  -g, --resource-group <name>          Resource group (portal field: "Resource group")
  -n, --name <name>                    Agent name (portal field: "Agent name")
  -l, --location <region>              Region (portal field: "Region"; currently documented: swedencentral, eastus2, australiaeast)
      --cluster-uri <uri>              Kusto connector URI when the recipe declares one

Optional:
      --subscription <id>              Subscription (portal field: "Subscription")
      --target-resource-group <name>   Repeatable target resource group
      --cluster-resource-id <id>       Kusto cluster ARM resource ID
      --deploy-name <name>             Deployment name override
      --dry-run                        Assemble and validate inputs without Azure calls
      --what-if                        Run live ARM what-if validation
      --force                          Continue when diff/discovery would otherwise stop
      --fallback-srectl                Deploy ARM core, then hydrate extensions with srectl
      --no-telemetry                   Disable anonymous telemetry for this run
  -h, --help                           Show this help

Legacy input:
  A pre-assembled .parameters.json file is accepted only as a positional argument.
  When using a legacy parameters file, identity and cluster flags are ignored.
```

### Modes

Dry-run is hermetic and does not call Azure:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  -g <your-rg> \
  -n <your-agent-name> \
  -l <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/hub \
  --dry-run
```

What-if is a live ARM validation:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  -g <your-rg> \
  -n <your-agent-name> \
  -l <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/hub \
  --what-if
```

Constrained mode keeps the ARM deployment for the core agent and hydrates extensions with `srectl`:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  -g <your-rg> \
  -n <your-agent-name> \
  -l <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/hub \
  --fallback-srectl
```

## Recipe identity policy

- Shipped recipes in this repo omit the `identity` block.
- Customer-authored recipes may include `identity` defaults for reproducible deployments.
- CLI flags always win over recipe defaults.

If you omit `--target-resource-group`, the deploy flow uses the recipe default when present; otherwise it defaults to the agent resource group.

## Verify

```bash
bash bin/verify-agent.sh \
  $(az account show --query id -o tsv) \
  <your-rg> \
  <your-agent-name> \
  --expected recipes/finops-hub
```

If you passed `--cluster-uri`, confirm the `finops-hub-kusto` connector is healthy in `https://sre.azure.com`.

## CI/CD example

The GitHub Actions example passes the cluster URI as a script flag while keeping secrets such as `GITHUB_PAT` or `ADO_PAT` in the environment.

## Migrating from env-var-driven deploys

The old deploy path accepted config through environment variables such as `FINOPS_HUB_CLUSTER_URI`, `FINOPS_HUB_CLUSTER_RESOURCE_ID`, `SRE_AGENT_NO_TELEMETRY`, and `connectors.secrets.env`. Those inputs are no longer supported for config or identity.

Before:

```bash
export FINOPS_HUB_CLUSTER_URI="https://<your-cluster>.<your-region>.kusto.windows.net/hub"
export FINOPS_HUB_CLUSTER_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster>"
export SRE_AGENT_NO_TELEMETRY=1
bash bin/deploy.sh recipes/finops-hub
```

After:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/hub \
  --cluster-resource-id /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster> \
  --no-telemetry
```

The only supported environment-variable inputs are secrets:

- `GITHUB_PAT`
- `ADO_PAT`
- `ADO_USE_AAD`
- `ADO_USE_MI`
- `ADO_ORG`
