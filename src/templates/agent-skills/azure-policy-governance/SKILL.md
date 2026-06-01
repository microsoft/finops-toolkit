---
name: azure-policy-governance
description: Use when the user wants to enforce cost governance with Azure Policy — require or inherit tags, restrict regions/SKUs/resource types, audit untagged resources, or generate Bicep/ARM policy assignments. Pairs with the finops-multitool policy scans to close governance gaps.
license: MIT
compatibility: Requires Azure CLI authentication and Resource Policy Contributor (or equivalent) to assign policy. Read-only auditing needs only Reader. Verify built-in policy definition IDs against Microsoft Learn before generating templates.
metadata:
  author: microsoft
  version: "1.0"
allowed-tools: az pwsh
---

# Azure Policy for cost governance

Enforce the guardrails that make FinOps allocation and waste-control durable: tag requirements, tag inheritance, region/SKU restrictions, and audit policies. This skill turns governance gaps into deployable policy.

## When to use this skill

Use it when the user wants to enforce or audit tagging, restrict what can be deployed, or asks for "a policy" to back up a FinOps recommendation. Run `scan_policy_inventory` and `scan_policy_recommendations` from the `finops-multitool` MCP server first to see what's already assigned and where the gaps are, then generate policy here.

## Workflow

1. **Inventory** — `scan_policy_inventory` (existing assignments, scopes, effects, compliance).
2. **Gap analysis** — `scan_policy_recommendations` (missing tagging/region/SKU guardrails).
3. **Verify definition IDs** — built-in policy IDs change rarely but must be confirmed. Use the Microsoft Learn MCP / docs before emitting any ID into a template. Do not ship an ID from memory.
4. **Generate** — produce Bicep or ARM for the assignment(s), parameterized and scoped.
5. **Stage effects** — deploy as `Audit`/`AuditIfNotExists` first, review compliance, then escalate to `Deny`/`Modify`. Never lead with `Deny` on an existing environment.

## Core cost-governance policies

| Goal | Built-in policy (verify ID before use) | Effect |
|------|----------------------------------------|--------|
| Require a tag on resource groups | "Require a tag on resource groups" | Deny |
| Require a tag on resources | "Require a tag on resources" | Deny |
| Inherit a tag from the resource group | "Inherit a tag from the resource group" | Modify |
| Audit missing tag | "Require a tag and its value on resources" (audit variant) | Audit |
| Allowed locations | "Allowed locations" | Deny |
| Allowed resource types | "Allowed resource types" | Deny |
| Allowed VM SKUs | "Allowed virtual machine size SKUs" | Deny |

`Modify` and `DeployIfNotExists` policies require a managed identity on the assignment with rights to remediate. Generate a remediation task after assignment so existing resources are brought into compliance, not just new ones.

## Effect sequencing (safe rollout)

```
Audit  →  review compliance  →  Modify/Append (auto-fix)  →  remediate existing  →  Deny (block new violations)
```

Apply the same tag key across all three layers (require on RG, inherit to resources, deny new untagged) so the allocation model from the `cost-allocation` skill is enforced end to end.

## Generating templates

When asked for Bicep:
- Parameterize the tag name, allowed values/locations/SKUs, scope, and effect.
- Set `enforcementMode` to `DoNotEnforce` for a dry run when the user wants to preview impact.
- Use the Bicep MCP tools to validate the `Microsoft.Authorization/policyAssignments` schema and run diagnostics before presenting the file.
- Output one assignment per concern; don't bundle unrelated guardrails into a single assignment.

## Hand-offs

- Decide which tags to enforce → `cost-allocation` skill.
- See current gaps → `finops-multitool` policy scans.
- Report compliance trend visually → `power-bi-finops` (governance report) or `azure-workbooks-finops`.
