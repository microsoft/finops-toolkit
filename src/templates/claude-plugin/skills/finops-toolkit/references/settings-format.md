# FinOps hubs environment settings

FinOps hubs environment settings are stored in `.ftk/environments.local.md` at the project root. This file is agent-agnostic and supports multiple named environments.

## File format

The settings file uses YAML frontmatter with an optional markdown body for notes:

```markdown
---
default: dev-hub
environments:
  dev-hub:
    cluster-uri: https://myhubdev.eastus.kusto.windows.net
    tenant: 00000000-0000-0000-0000-000000000000
    subscription: my-dev-subscription
    resource-group: rg-finops-dev
  prod-hub:
    cluster-uri: https://myhubprod.westus2.kusto.windows.net
    tenant: 00000000-0000-0000-0000-000000000000
    subscription: my-prod-subscription
    resource-group: rg-finops-prod
---

# Environment notes

Optional notes about your FinOps hub environments.
```

## Required fields

| Field | Required | Description |
|-------|----------|-------------|
| `default` | Yes | Name of the default environment to use |
| `environments` | Yes | Map of named environments |
| `cluster-uri` | Yes | Full Azure Data Explorer cluster URI |
| `tenant` | Yes | Azure AD tenant ID (required for B2B/cross-tenant) |
| `subscription` | No | Azure subscription name or ID |
| `resource-group` | No | Resource group containing the hub |

## Reading settings

To read settings from `.ftk/environments.local.md`:

1. Read the file at `.ftk/environments.local.md` relative to the project root
2. Parse the YAML frontmatter between the `---` delimiters
3. Use the `default` field to select the active environment unless the user specifies one
4. Extract `cluster-uri`, `tenant`, and other fields from the selected environment

## Writing settings

The `/ftk-hubs-connect` command discovers FinOps hub instances and writes their configuration to this file. When writing:

1. Read the existing file if it exists to preserve other environments
2. Add or update the environment entry with the discovered values
3. Set `default` to the newly connected environment if no default exists

## Using settings with MCP Kusto server

After reading the active environment, pass the values to the MCP Kusto server:

```json
{
  "cluster-uri": "<cluster-uri from active environment>",
  "database": "Hub",
  "tenant": "<tenant from active environment>",
  "query": "<KQL query>"
}
```

Always include the `tenant` parameter. Cross-tenant (B2B) scenarios fail with "Unauthorized" if tenant is omitted.
