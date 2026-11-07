---
title: Configure row-level security for FinOps hubs
description: Scope FinOps hub data by team with row-level security in Azure Data Explorer, so KQL queries, dashboards, and AI agents return only the rows a user may see.
author: keerthimath
ms.author: micflan
ms.date: 11/06/2026
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps hub admin, I want each team to see only the cost of their own subscriptions so that I can share hub data broadly without exposing other teams' spend.
---

<!-- markdownlint-disable MD024 -->
# Configure row-level security for FinOps hubs

Row-level security for FinOps hubs is an optional, opt-in pattern for hubs that use Azure Data Explorer or Microsoft Fabric. Nothing in the FinOps hub template changes: you add it to an existing hub, and you can remove it at any time. By default, anyone with the Viewer role on the hub databases can see all cost data in the hub. When several teams share one hub, you might want each team to see only the cost of the scopes they own.

Azure Data Explorer [row-level security](/kusto/management/row-level-security-policy) filters the rows of a table for every query, based on who runs it. Because it runs in the database, it applies everywhere users query the hub with their own identity: Kusto Query Language (KQL) queries in the Data Explorer web UI, Data Explorer dashboards, and AI agents that query the hub as the signed-in user.

This article walks you through scoping FinOps hub data by subscription with row-level security.

> [!IMPORTANT]
> Row-level security is a customization you add on top of a deployed FinOps hub, not a feature of the hub. The hub template doesn't deploy, upgrade, or remove the functions and policies described here. You own them: keep your own copy of the function, recheck the policies after every hub upgrade, and expect to maintain them as table versions change.

<br>

## Limitations

Review these limitations, and the [row-level security policy limitations](/kusto/management/row-level-security-policy#limitations) in the Kusto docs, before you start:

- **Microsoft Fabric**: This procedure was validated on hubs that use Azure Data Explorer. Fabric eventhouses support the same row-level security and restricted view access policies, but the steps haven't been tested there.
- **Raw tables**: Row-level security can't be enabled on the raw tables in the **Ingestion** database, like `Costs_raw`, because they feed update policies. This guide requires the hub's raw retention (`dataExplorerRawRetentionInDays`) to be `0`, the default, and the raw tables to be empty, so they hold no rows to expose. Hubs that retain raw data are out of scope: the [restricted view access policy](/kusto/management/restricted-view-access-policy) isn't an alternative, because the hub's update policies read the raw tables, and [update policies can't read tables that have restricted view access enabled](/kusto/management/update-policy#query-limitations).
- **Service identities**: Row-level security applies to every principal that queries the hub. Every service identity that reads hub data, like a service principal that refreshes a Power BI semantic model or an identity that runs alert queries, must be in the allow-all list, or it silently sees no rows. Hub ingestion doesn't need to be: the Azure Data Factory managed identity only runs management commands, like ingesting into the raw tables and dropping extents, and the update policies move the data into the final tables.
- **Rows without a subscription**: Rows with an empty `SubAccountId`, like billing account level purchases and shared reservations, match no team. Only principals in the allow-all list see them.
- **Hub upgrades**: Row-level security is bound to table names. A hub upgrade can add or change tables, for example a new table version, which then has no policy. Recheck row-level security after every hub upgrade.
- **Power BI and shared identities**: In the toolkit's KQL reports, the tables that read the cluster are DirectQuery. With **Use SSO via Microsoft Entra ID for DirectQuery queries** enabled on the semantic model's data source, each viewer's own identity runs the queries, so row-level security applies per viewer. Without single sign-on, and for any Import table, including summary tables built at refresh, the stored or refresh identity decides what every viewer sees, like a Power BI semantic model that refreshes with a service account. The same applies to any other report or dashboard that queries the hub with a shared identity.
- **Rows only**: Row-level security filters rows, not metadata. Users with Viewer access can still list the database's principals and see table and function definitions, and can query every table you don't protect, so keep the hub databases limited to FinOps data.

<br>

## Prerequisites

- [Deployed a FinOps hub instance](finops-hubs-overview.md#create-a-new-hub) with Azure Data Explorer or Microsoft Fabric, version 12 or later. This procedure was validated on version 14 with Azure Data Explorer.
- **Database Admin** on the **Ingestion** database, to create functions and enable policies, and on the **Hub** database, to grant access.
- A Microsoft Entra group for each team, and the subscriptions each team owns.
- The object IDs of the principals that must keep seeing all data: FinOps admins, the identity you use for this setup, and the service identities listed in [Limitations](#limitations).
- A test user who is a member of one team, and one who has Viewer access but isn't in any team.

<br>

## How it works

The functions in the **Hub** database, like `Costs()`, read the final tables in the **Ingestion** database. Each final table has a `v1_0` and a `v1_2` version, and the functions read both. To scope the hub by subscription, attach a row-level security policy to each final table that has a `SubAccountId` column:

| Table                           | Versions         |
| ------------------------------- | ---------------- |
| `Costs_final`                   | `_v1_0`, `_v1_2` |
| `CommitmentDiscountUsage_final` | `_v1_0`, `_v1_2` |
| `Recommendations_final`         | `_v1_0`, `_v1_2` |
| `Transactions_final`            | `_v1_0`, `_v1_2` |

All eight policies use one function that takes the table name as a parameter. It returns all rows for an allow-all list of admins and service identities, and for everyone else only the rows of the subscriptions mapped to the Microsoft Entra groups they belong to. A user in several teams sees the subscriptions of all of their teams. Price tables aren't subscription specific and aren't filtered.

<br>

## Configure row-level security

### Step 1: Check the raw tables and blockers

Confirm that the raw tables don't keep data and are empty. Run these in the **Ingestion** database. Every raw table must show a `SoftDeletePeriod` of `00:00:00` and a `TotalRowCount` of `0`:

```kusto
.show table * policy retention
| where EntityName contains '_raw'
```

```kusto
.show tables details
| where TableName endswith '_raw'
| project TableName, TotalRowCount
```

A retention of zero alone isn't enough: rows retained under an earlier setting are deleted asynchronously and can still be readable. If any raw table keeps data or has rows, stop: this guide doesn't apply to that hub, as described in [Limitations](#limitations).

Row-level security can't be enabled on a table that's read by an update policy that doesn't use a managed identity. Check every table's update policy in the **Ingestion** database for a source table or query that reads one of the final tables; the result should be empty:

```kusto
.show tables details
| where UpdatePolicy contains '_final_v'
| project TableName, UpdatePolicy
```

The hub's own update policies read the raw tables, not the final tables, so they aren't blockers. If you added update policies of your own, also check the functions their queries call. Also check these, for each table:

```kusto
.show table Costs_final_v1_2 policy restricted_view_access
.show materialized-views
```

- Row-level security and the restricted view access policy can't be combined on the same table.
- A materialized view over the table needs its own row-level security policy.

Then check the exact `SubAccountId` values, because the function matches them exactly. FinOps hubs store them as `/subscriptions/<subscription-id>`:

```kusto
Costs_final_v1_2
| summarize by SubAccountId
```

### Step 2: Create the row-level security function

Create one function in the **Ingestion** database. It takes the table name as a parameter and reads that table with `table()`, following the Kusto docs' pattern for [applying the same function to multiple tables](/kusto/management/row-level-security-policy#apply-the-same-rls-function-on-multiple-tables). This example maps two teams. Replace the principals, tenant ID, and subscriptions with your own. Use `aadgroup=<object-id>;<tenant-id>` for groups, `aaduser=<object-id>;<tenant-id>` for users, and `aadapp=<application-id>;<tenant-id>` for applications and managed identities.

```kusto
.create-or-alter function with (folder="security", docstring="Scope filter for FinOps hubs") FinOpsRls(TableName: string) {
    let allow_all = current_principal_is_member_of(
        'aadgroup=<finops-admins-group-id>;<tenant-id>');
    let team_a = iff(current_principal_is_member_of('aadgroup=<team-a-group-id>;<tenant-id>'),
        dynamic(['/subscriptions/<team-a-subscription-id>']), dynamic([]));
    let team_b = iff(current_principal_is_member_of('aadgroup=<team-b-group-id>;<tenant-id>'),
        dynamic(['/subscriptions/<team-b-subscription-id-1>', '/subscriptions/<team-b-subscription-id-2>']), dynamic([]));
    let allowed = array_concat(team_a, team_b);
    table(TableName)
    | where allow_all or set_has_element(allowed, tolower(SubAccountId))
}
```

Write the subscription IDs in lowercase, because the function compares them with the lowercased `SubAccountId`. The group mapping has to stay as string literals, because `current_principal_is_member_of()` doesn't accept non-literal values. To change teams without editing the function, use a mapping table keyed on the user instead, as shown in the Kusto docs.

### Step 3: Test before you enable

Creating the function doesn't change anything yet. Attach it to each final table as a **disabled** policy, passing the table's name. A disabled policy doesn't affect anyone, but it lets you apply it to your own queries:

```kusto
.alter table Costs_final_v1_2 policy row_level_security disable "FinOpsRls('Costs_final_v1_2')"
```

Repeat for the other seven tables. Then check, for each table, that you keep seeing all rows when the policy is applied to you. `set query_force_row_level_security` applies the table's policy to your query even while it's disabled. Both counts must match:

```kusto
Costs_final_v1_2
| summarize Rows = count()
```

```kusto
set query_force_row_level_security;
Costs_final_v1_2
| summarize Rows = count()
```

If the second count is lower, your identity isn't in the allow-all list. Fix the function before you continue.

### Step 4: Enable the policies

Enable the policy on each table in the **Ingestion** database:

```kusto
.alter table Costs_final_v1_2 policy row_level_security enable "FinOpsRls('Costs_final_v1_2')"
```

Run the row count again right away. If it dropped, [roll back](#roll-back) and check the allow-all list.

### Step 5: Grant access

Team members only need the [Viewer role](/kusto/management/manage-database-security-roles#database-level-security-roles), but on both databases. The **Hub** functions, like `Costs()`, read the **Ingestion** tables with the caller's identity, so with Viewer on **Hub** alone, queries fail with `Errors occurred while resolving remote entities. Database='Ingestion': Access denied`.

```kusto
.add database ['Hub'] viewers ('aadgroup=<team-a-group-id>;<tenant-id>') 'Team A'
.add database ['Ingestion'] viewers ('aadgroup=<team-a-group-id>;<tenant-id>') 'Team A'
```

Don't grant team members a higher role. Database admins and users can change or bypass the policy.

<br>

## Verify

Check the result with each test user:

- **A team member** sees only their team's subscriptions:

  ```kusto
  Costs()
  | summarize Cost = sum(EffectiveCost) by SubAccountId
  ```

- **A user in no team**, or in a team that doesn't own any of the data, gets an empty result, not an error.
- **An admin in the allow-all list** sees all subscriptions, with the same totals as before.

Then open the Data Explorer dashboard as a team member and confirm that only their spend appears.

After every hub upgrade, run this in the **Ingestion** database. It lists every final table, including tables that have no policy:

```kusto
.show tables details
| where TableName contains '_final_v'
| extend p = parse_json(RowLevelSecurityPolicy)
| project TableName, Enabled = iff(isempty(RowLevelSecurityPolicy) or isnull(p), 'missing', tostring(p.IsEnabled)), Query = tostring(p.Query)
| order by TableName asc
```

Every `Costs`, `CommitmentDiscountUsage`, `Recommendations`, and `Transactions` final table must show `true`. A table that shows `missing` or `false`, such as a new table version added by the upgrade, isn't protected: attach the function and enable the policy as described in [Configure row-level security](#configure-row-level-security). `Prices` tables aren't filtered and show `missing`.

<br>

## Roll back

To turn off scoping for a table, disable its policy. The function stays, and you can enable the policy again later:

```kusto
.alter table Costs_final_v1_2 policy row_level_security disable "FinOpsRls('Costs_final_v1_2')"
```

To add a team or change its subscriptions, edit the one function; all eight policies use it. Removing a team from the function doesn't remove its Viewer access; remove that separately with `.drop database ['Hub'] viewers (...)` and the same command for **Ingestion**.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK/bladeName/Hubs/featureName/RowLevelSecurity)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Allocation](../../framework/understand/allocation.md)

Related products:

- [Row-level security policy](/kusto/management/row-level-security-policy)
- [Update policy](/kusto/management/update-policy)
- [Database security roles](/kusto/management/manage-database-security-roles#database-level-security-roles)

Related solutions:

- [FinOps hubs](finops-hubs-overview.md)
- [Configure Data Explorer dashboards](configure-dashboards.md)
- [Configure AI agents](configure-ai.md)

<br>
