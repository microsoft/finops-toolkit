# FinOps Hub SRE Agent recipe

Deploys the FinOps Toolkit SRE Agent using the canonical Microsoft SRE Agent recipe layout.

## Contents

- 5 custom agents in `config/subagents/`: `finops-practitioner` plus four delegated subagents
- 3 tool-bearing delegated subagents: `azure-capacity-manager`, `ftk-database-query`, and `ftk-hubs-agent`; `chief-financial-officer` has no tools
- 3 skills in `config/skills/`
- 34 tools in `config/tools/`
- 9 platform tool overrides in `config/built-in-tools.json`
- 19 scheduled tasks in `automations/scheduled-tasks/`, all owned by `finops-practitioner`
- 1 connector in `connectors.json`: FinOps Hub Kusto
- 6 uploaded KnowledgeFile sources: files in `knowledge/` plus `../../../claude-plugin/output-styles/ftk-output-style.md`

## Framework mapping

The authoritative FinOps Framework mapping for this recipe is [../../CATALOG.md](../../CATALOG.md). It maps the toolkit and SRE Agent to FinOps domains, capabilities, personas, principles, phases, agent ownership, tool ownership, scheduled-task ownership, and required handoffs. Keep this recipe aligned to that catalog when changing subagents, tools, skills, knowledge sources, or scheduled tasks.

## Deploy

```bash
bash ../../bin/deploy.sh \
  --recipe . \
  --subscription <subscription-id> \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<cluster>.<region>.kusto.windows.net/Hub \
  [--cluster-resource-id /subscriptions/.../providers/Microsoft.Kusto/clusters/<name>]
```

The deployment uses the explicit subscription passed with `--subscription`. Real deployments resolve the Kusto cluster resource ID from `--cluster-uri` when possible. Pass `--cluster-resource-id` when the cluster cannot be resolved automatically or when running `--dry-run`.
