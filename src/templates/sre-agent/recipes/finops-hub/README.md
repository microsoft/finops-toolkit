# FinOps Hub SRE Agent recipe

Deploys the FinOps Toolkit SRE Agent using the canonical Microsoft SRE Agent recipe layout.

## Contents

- 5 subagents in `config/subagents/`
- 3 skills in `config/skills/`
- 34 tools in `config/tools/`
- 19 scheduled tasks in `automations/scheduled-tasks/`
- 1 FinOps Hub Kusto connector in `connectors.json`
- Knowledge documents in `knowledge/`

## Deploy

```bash
bash ../../bin/deploy.sh \
  --recipe . \
  --subscription <subscription-id> \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<cluster>.<region>.kusto.windows.net/Hub \
  --cluster-resource-id /subscriptions/.../providers/Microsoft.Kusto/clusters/<name>
```

The deployment uses the explicit subscription passed with `--subscription`.
