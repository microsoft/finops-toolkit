---
name: azure-policy-governance
description: Use when the user wants to enforce cost governance with Azure Policy — require or inherit tags, restrict regions/SKUs/resource types, audit untagged resources, or generate Bicep/ARM policy assignments. Pairs with the finops-explorer policy scans to close governance gaps.
license: MIT
compatibility: Requires Azure CLI authentication. Reader is enough to audit and to generate templates. The user assigns the generated policy, which requires Resource Policy Contributor or equivalent. Verify built-in policy definition IDs against Microsoft Learn before generating templates.
metadata:
  author: microsoft
  version: "1.0"
---

# Azure Policy for cost governance

Enforce the guardrails that make FinOps allocation and waste-control durable: tag requirements, tag inheritance, region/SKU restrictions, and audit policies. This skill turns governance gaps into deployable policy for the user to review and apply. Don't assign policy or start remediation yourself; the FinOps skills are read-only.

## When to use this skill

Use it when the user wants to enforce or audit tagging, restrict what can be deployed, or asks for "a policy" to back up a FinOps recommendation. Run policy inventory and policy recommendations from the `finops-explorer` skill first to see what's already assigned and where the gaps are, then generate policy here.

## Workflow

1. **Inventory** — policy inventory (existing assignments, scopes, effects, compliance).
2. **Gap analysis** — policy recommendations (missing tagging/region/SKU guardrails).
3. **Verify definition IDs** — built-in policy IDs change rarely but must be confirmed. Use the Microsoft Learn MCP / docs before emitting any ID into a template. Do not ship an ID from memory.
4. **Generate** — produce Bicep or ARM for the assignment(s), parameterized and scoped.
5. **Stage effects** — recommend that the user deploy `Audit`/`AuditIfNotExists` first, review compliance, then move to `Deny`/`Modify`. Some built-ins, such as the tag-requirement policies, only offer `Deny`. Assign those with `enforcementMode` set to `DoNotEnforce` first, which reports compliance without blocking anything. Never lead with `Deny` on an existing environment.

## Core cost-governance policies

| Goal | Built-in policy (verify ID before use) | Effect |
|------|----------------------------------------|--------|
| Require a tag on resource groups | "Require a tag on resource groups" | Deny |
| Require a tag on resources | "Require a tag on resources" | Deny |
| Inherit a tag from the resource group | "Inherit a tag from the resource group if missing" | Modify |
| Audit missing tag | "Require a tag on resources", assigned with `enforcementMode` `DoNotEnforce`, or a custom Audit definition | Deny (not enforced) |
| Allowed locations | "Allowed locations" | Deny |
| Allowed resource types | "Allowed resource types" | Deny |
| Allowed VM SKUs | "Allowed virtual machine size SKUs" | Deny |

`Modify` and `DeployIfNotExists` policies require a managed identity on the assignment with rights to remediate. Tell the user to create a remediation task after they assign the policy, so existing resources are brought into compliance, not just new ones.

## Effect sequencing (safe rollout)

```
Audit  →  review compliance  →  Modify/Append (auto-fix)  →  remediate existing  →  Deny (block new violations)
```

Apply the same tag key across all three layers (require on RG, inherit to resources, deny new untagged) so the allocation model from the `cost-allocation` skill is enforced end to end.

## Generating templates

When asked for Bicep:
- Parameterize the tag name, allowed values/locations/SKUs, scope, and effect.
- Set `enforcementMode` to `DoNotEnforce` for a dry run when the user wants to preview impact.
- Validate the file before presenting it. Use the Bicep MCP tools if they're available, or run `az bicep build --file <file>` and fix any diagnostics. Check it against the `Microsoft.Authorization/policyAssignments` schema.
- Output one assignment per concern; don't bundle unrelated guardrails into a single assignment.

## Hand-offs

- Decide which tags to enforce → `cost-allocation` skill.
- See current gaps → `finops-explorer` policy scans.
- Report compliance trend visually → `power-bi-finops` (governance report) or `azure-workbooks-finops`.
