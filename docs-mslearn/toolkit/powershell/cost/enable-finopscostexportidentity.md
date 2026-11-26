---
title: Enable-FinOpsCostExportIdentity command
description: Switch existing Cost Management exports to a system-assigned managed identity using the Enable-FinOpsCostExportIdentity command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 11/26/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Enable-FinOpsCostExportIdentity command in the FinOpsToolkit module.
---

# Enable-FinOpsCostExportIdentity command

The **Enable-FinOpsCostExportIdentity** command adds a system-assigned managed identity to existing Cost Management exports and assigns the [Storage Blob Data Contributor](/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor) role to the identity on the destination storage container.

Exports without a managed identity write to storage with the permissions of the person who created or last updated the export. Cost Management checks those permissions on every run, so scheduled runs fail with [AccessToStorageAccountDenied](../../help/errors.md#accesstostorageaccountdenied) once that access is removed or expires. For example, runs fail when the person's access comes from an eligible Privileged Identity Management (PIM) role that isn't active. With a managed identity, runs no longer depend on the permissions of a person. To learn more, see [Use a managed identity for exports](../../hubs/configure-scopes.md#use-a-managed-identity-for-exports).

The command updates each export in place. The schedule, run history, and all other settings are kept. Exports that already use a system-assigned managed identity aren't changed, but the command still checks the role assignment.

The command returns the updated exports as [FinOpsCostExport objects](get-finopscostexport.md#finopscostexport-object). The `IdentityType` and `PrincipalId` properties show the managed identity.

To run this command, you need:

- Permission to update the export at its scope. For example, **Cost Management Contributor** on a subscription, or billing profile owner or contributor on a Microsoft Customer Agreement billing profile.
- Permission to assign roles on the destination storage account. For example, **Owner**, **User Access Administrator**, or **Role Based Access Control Administrator**. Skip this permission with `-SkipRoleAssignment` if someone else assigns the role.

This command was tested with the following API versions:

- 2025-03-01 (default)

<br>

## Syntax

```powershell
Enable-FinOpsCostExportIdentity `
    [-Name] <string> `
    [-Scope] <string> `
    [[-Location] <string>] `
    [-SkipRoleAssignment] `
    [[-ApiVersion] <string>] `
    [-WhatIf] `
    [<CommonParameters>]
```

<br>

## Parameters

| Name                  | Description                                                                                                                                               |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑Name`               | Required. Name of the export. Supports wildcards.                                                                                                         |
| `‑Scope`              | Required. Resource ID of the scope the export was created for.                                                                                            |
| `‑Location`           | Optional. Azure location to use for the managed identity. Default = the location of the export, if set; otherwise, "global".                              |
| `‑SkipRoleAssignment` | Optional. Indicates that the Storage Blob Data Contributor role shouldn't be assigned. Use this option if someone else assigns the role. Default = false. |
| `‑ApiVersion`         | Optional. API version to use when calling the Cost Management Exports API. Default = 2025-03-01.                                                          |
| `‑WhatIf`             | Optional. Shows what would happen if the command runs without actually running it.                                                                        |

<br>

## Examples

### Switch one export to a managed identity

```powershell
Enable-FinOpsCostExportIdentity `
    -Name 'ftk-FinOpsHub-costs' `
    -Scope '/providers/Microsoft.Billing/billingAccounts/00000000/billingProfiles/0000-0000-000-000'
```

Adds a system-assigned managed identity to the **ftk-FinOpsHub-costs** export and assigns the Storage Blob Data Contributor role to it on the destination container.

### Preview the change for all exports in a scope

```powershell
Enable-FinOpsCostExportIdentity `
    -Name '*' `
    -Scope '/providers/Microsoft.Billing/billingAccounts/00000000' `
    -WhatIf
```

Shows which exports in the billing account would be switched to a managed identity without changing them. Remove `-WhatIf` to apply the change.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/CostManagement.EnableExportIdentity)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")
<!-- prettier-ignore-end -->

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
