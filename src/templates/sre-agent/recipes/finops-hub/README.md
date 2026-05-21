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
bash ../../bin/deploy.sh . --finops-hub-cluster-uri https://<cluster>.<region>.kusto.windows.net/hub
```

The deployment uses the currently selected Azure CLI subscription.
