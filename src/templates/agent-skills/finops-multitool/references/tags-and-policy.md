# Tags and policy

Tag hygiene and Azure Policy coverage — the governance foundation that cost allocation depends on.

Queries run read-only against Azure Resource Graph via `az graph query`, an Azure MCP Resource Graph tool, or `Search-AzGraph`.

## Tag inventory

What tags exist, on how many resources, with what values:

```kusto
resources
| union resourcecontainers
| mvexpand tags
| extend tagName = tostring(bag_keys(tags)[0])
| extend tagValue = tostring(tags[tagName])
| where isnotempty(tagName)
| summarize ResourceCount = count(), ResourceTypes = make_set(type) by tagName, tagValue
| order by tagName asc, ResourceCount desc
```

The `union resourcecontainers` matters — it includes subscriptions and resource groups, which carry the tags that inherited allocation models depend on. Omitting it undercounts coverage badly.

What carries no tags at all:

```kusto
resources
| where isnull(tags) or tags == '{}'
| project name, type, resourceGroup, subscriptionId, location
| order by type asc, name asc
```

Where a given tag is applied, by scope:

```kusto
resources
| union resourcecontainers
| mvexpand tags
| extend tagName = tostring(bag_keys(tags)[0])
| where isnotempty(tagName)
| summarize ResourceCount = count() by tagName, subscriptionId, resourceGroup
| order by tagName asc, ResourceCount desc
```

## Reading tag coverage

**Check for naming variants before reporting a coverage percentage.** The most common finding in a real estate isn't missing tags — it's the same tag spelled several ways:

```text
managed_by   ManagedBy   managedBy   Managed-By
costcenter   CostCenter   cost_center   CC
```

Each variant appears as a distinct tag in the inventory. Coverage looks like 30% across four tags when it's really 85% of one tag with inconsistent naming. Group case-insensitively and normalize separators before computing coverage, then report the variants as the finding.

Other things worth flagging:

- **Tag values that should be an enum but aren't.** Twelve spellings of one team name breaks any groupby.
- **Tags on resources but not on resource groups.** Inherited allocation models silently fail.
- **Reserved prefixes.** Tags beginning `hidden-` or `microsoft` are platform-managed; exclude them from coverage math.

A tag is only useful for cost allocation if it's also enabled as a **cost-allocation dimension** in Cost Management settings. High tag coverage with no cost-by-tag data almost always means that setting was never turned on. See `cost-analysis.md`.

## Policy inventory

Assignments in scope:

```kusto
policyresources
| where type =~ 'microsoft.authorization/policyassignments'
| project id, name, properties, subscriptionId, type
```

Compliance rollup:

```kusto
policyresources
| where type =~ 'microsoft.policyinsights/policystates'
| extend complianceState = tostring(properties.complianceState)
| summarize
    Compliant    = countif(complianceState =~ 'Compliant'),
    NonCompliant = countif(complianceState =~ 'NonCompliant'),
    Total        = count()
    by subscriptionId
```

**A subscription with no policy state records is not compliant — it's unevaluated.** Report those separately. Rolling "no data" into a compliance percentage is the fastest way to produce a governance report that's wrong in the reassuring direction.

## Policy coverage gaps

The useful output isn't the list of assignments — it's what's missing. Compare assigned policies against the guardrails a cost-governed environment normally has:

| Guardrail                                 | Typical built-in                                   |
| ----------------------------------------- | -------------------------------------------------- |
| Require a tag on resources                | `Require a tag on resources`                       |
| Inherit a tag from the resource group     | `Inherit a tag from the resource group if missing` |
| Restrict deployment regions               | `Allowed locations`                                |
| Restrict VM SKUs                          | `Allowed virtual machine size SKUs`                |
| Audit resources without a cost center tag | Custom, usually                                    |

Tag inheritance is the highest-leverage one and the most often missing. `Inherit a tag from the resource group if missing` (definition ID `ea3f2387-9b95-492a-a190-fcdc54f7b070`) is a `modify` effect — it fixes allocation gaps going forward without touching existing resources, and it needs a managed identity on the assignment.

When recommending policy, distinguish the effects:

- **Audit** — reports, changes nothing. Safe to assign broadly, and the right first step.
- **Modify** — fixes resources as they're created or remediated. Needs a managed identity.
- **Deny** — blocks deployments. Real breakage risk; assign only after an audit period shows the impact.

Recommending `deny` on a live subscription without an audit period first is how a governance rollout gets rolled back.

## Sequencing

1. Tag inventory first — you can't recommend tag policy without knowing what's there.
2. Normalize variants and report real coverage.
3. Policy inventory, separating unevaluated from non-compliant.
4. Gap analysis against the guardrail list.
5. Recommend `audit` effects first, `modify` for inheritance, `deny` only with evidence.

## Related

- `azure-policy-governance` for authoring the policy definitions and assignments as Bicep or ARM
- `cost-allocation` for turning tag coverage into a showback or chargeback model
- `cost-analysis.md` for why tagged resources may still not appear in cost data
