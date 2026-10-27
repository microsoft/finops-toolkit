---
title: Configure row-level security for FinOps hubs
description: Optionally limit which subscriptions each team can see in a FinOps hub by using row-level security in Azure Data Explorer, so KQL queries, dashboards, and AI agents only return the rows a user is allowed to see.
author: keerthimath
ms.author: keerthimath
ms.date: 10/26/2026
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps hub admin, I want each team to see only the cost of their own subscriptions so that I can share hub data broadly without exposing other teams' spend.
---

<!-- markdownlint-disable MD024 -->
# Configure row-level security for FinOps hubs

Row-level security for FinOps hubs is an optional, opt-in pattern for hubs that use Azure Data Explorer. Nothing in the FinOps hub template changes: you add it to an existing hub, and you can remove it at any time. By default, anyone with the Viewer role on the hub databases can see all cost data in the hub. When several teams share one hub, you might want each team to see only the cost of the subscriptions they own.

Azure Data Explorer [row-level security](/kusto/management/row-level-security-policy) (RLS) filters the rows of a table for every query, based on who runs it. Because it runs in the database, it applies everywhere users query the hub with their own identity: KQL in the Data Explorer web UI, Data Explorer dashboards, and AI agents that query the hub as the signed-in user.

This article walks you through scoping FinOps hub data by subscription with row-level security.

<br>

## Limitations

Review these limitations before you start:

- **Azure Data Explorer only**: This article covers hubs that use Azure Data Explorer. Microsoft Fabric eventhouses are out of scope.
- **Raw tables**: Row-level security can't be enabled on the raw tables in the **Ingestion** database, like `Costs_raw`, because they feed update policies. They're only safe when the hub's raw retention (`dataExplorerRawRetentionInDays`) is `0`, the default, because they then keep no data. With raw retention above 0, team members could read the retained raw rows, so you also need the [restricted view access policy](/kusto/management/restricted-view-access-policy) on the raw tables.
- **Service identities**: Row-level security applies to every principal. Every service identity that queries the hub, like the Data Factory managed identity used for ingestion and any identity that refreshes reports or runs alerts, must be in the allow-all list, or it silently sees no rows.
- **Rows without a subscription**: Rows with an empty `SubAccountId`, like billing account level purchases and shared reservations, match no team. Only principals in the allow-all list see them.
- **Hub upgrades**: Row-level security is bound to table names. A hub upgrade can add or change tables, for example a new table version, which then has no policy. Re-check row-level security after every hub upgrade.
- **Shared identities**: Reports and dashboards that query the hub with a shared identity, like a Power BI dataset that refreshes with a service account, see what that identity sees, not what each viewer may see.
- **Rows only**: Row-level security filters rows, not metadata. Users with Viewer access can still list the database's principals and see table and function definitions, and can query every table you don't protect, so keep the hub databases limited to FinOps data.

<br>

## Prerequisites

- [Deployed a FinOps hub instance](finops-hubs-overview.md#create-a-new-hub) with Azure Data Explorer, version 12 or later.
- **Database Admin** on the **Ingestion** database, to create functions and enable policies, and on the **Hub** database, to grant access.
- A Microsoft Entra group for each team, and the subscriptions each team owns.
- The object IDs of the principals that must keep seeing all data: FinOps admins, the identity you use for this setup, and the service identities listed in [Limitations](#limitations).
- A test user who is a member of one team, and one who has Viewer access but isn't in any team.

<br>

## How it works

The functions in the **Hub** database, like `Costs()`, read the final tables in the **Ingestion** database. Each final table has a `v1_0` and a `v1_2` version, and the functions read both. To scope the hub by subscription, protect each final table that has a `SubAccountId` column with its own row-level security function:

| Table                           | Versions         |
| ------------------------------- | ---------------- |
| `Costs_final`                   | `_v1_0`, `_v1_2` |
| `CommitmentDiscountUsage_final` | `_v1_0`, `_v1_2` |
| `Recommendations_final`         | `_v1_0`, `_v1_2` |
| `Transactions_final`            | `_v1_0`, `_v1_2` |

Each function returns all rows for an allow-all list of admins and service identities, and for everyone else only the rows of the subscriptions mapped to the Entra groups they belong to. A user in several teams sees the subscriptions of all of their teams. Price tables aren't subscription specific and aren't filtered.

<br>

## Configure row-level security

### Step 1: Check the raw retention and blockers

Confirm that the raw tables don't keep data. Run this in the **Ingestion** database; every raw table should show a `SoftDeletePeriod` of `00:00:00`:

```kusto
.show table * policy retention
| where EntityName has '_raw'
```

If any raw table keeps data, protect the raw tables first, as described in [Limitations](#limitations).

Row-level security can't be enabled on a table in some cases. For each table, run these commands in the **Ingestion** database and resolve anything they report:

```kusto
.show table Costs_final_v1_2 policy update
.show table Costs_final_v1_2 policy restricted_view_access
.show materialized-views
```

- Row-level security can't be enabled on a table that an update policy references without a managed identity.
- Row-level security and the restricted view access policy can't be combined on the same table.
- A materialized view over the table needs its own row-level security policy.

Then check the exact `SubAccountId` values, because the function matches them exactly. FinOps hubs store them as `/subscriptions/<subscription-id>`:

```kusto
Costs_final_v1_2
| summarize by SubAccountId
```

### Step 2: Create the row-level security functions

Create one function per table in the **Ingestion** database. This example scopes `Costs_final_v1_2` for two teams. Replace the principals, tenant ID, and subscriptions with your own. Use `aadgroup=<object-id>;<tenant-id>` for groups, `aaduser=<object-id>;<tenant-id>` for users, and `aadapp=<application-id>;<tenant-id>` for applications and managed identities.

```kusto
.create-or-alter function with (folder="security", docstring="Subscription scoping for FinOps hubs") FinOpsRls_Costs_v1_2() {
    let allow_all = current_principal_is_member_of(
        'aadgroup=<finops-admins-group-id>;<tenant-id>',
        'aadapp=<data-factory-identity-id>;<tenant-id>');
    let team_a = iff(current_principal_is_member_of('aadgroup=<team-a-group-id>;<tenant-id>'),
        dynamic(['/subscriptions/<team-a-subscription-id>']), dynamic([]));
    let team_b = iff(current_principal_is_member_of('aadgroup=<team-b-group-id>;<tenant-id>'),
        dynamic(['/subscriptions/<team-b-subscription-id-1>', '/subscriptions/<team-b-subscription-id-2>']), dynamic([]));
    let allowed = array_concat(team_a, team_b);
    Costs_final_v1_2
    | where allow_all or set_has_element(allowed, tolower(SubAccountId))
}
```

Write the subscription IDs in lowercase, because the function compares them with the lowercased `SubAccountId`. Repeat for the other seven tables with the same principals and teams. Keep the lists identical in every function, or a team sees different data in different functions.

### Step 3: Test before you enable

Creating the function doesn't change anything yet. Before you enable the policy, check that you keep seeing all rows when the function is applied to you. Both counts must match:

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
.alter table Costs_final_v1_2 policy row_level_security enable "FinOpsRls_Costs_v1_2()"
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

Then open the Data Explorer dashboard as a team member and confirm that only their spend appears. After every hub upgrade, confirm that the policies are still enabled on all final tables:

```kusto
.show table * policy row_level_security
| where Policy != 'null'
```

<br>

## Roll back

To turn off scoping for a table, disable its policy. The function stays and can be enabled again later:

```kusto
.alter table Costs_final_v1_2 policy row_level_security disable "FinOpsRls_Costs_v1_2()"
```

To add a team or change its subscriptions, update all eight functions with the same lists. Removing a team from the functions doesn't remove its Viewer access; remove that separately with `.drop database ['Hub'] viewers (...)` and the same command for **Ingestion**.

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
- [Restricted view access policy](/kusto/management/restricted-view-access-policy)
- [Database security roles](/kusto/management/manage-database-security-roles#database-level-security-roles)

Related solutions:

- [FinOps hubs](finops-hubs-overview.md)
- [Configure Data Explorer dashboards](configure-dashboards.md)
- [Configure AI agents](configure-ai.md)

<br>
