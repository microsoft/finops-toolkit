---
title: Add-FinOpsServicePrincipal command
description: Grants the specified service principal or managed identity access to an Enterprise Agreement billing account or department.
author: flanakin
ms.author: micflan
ms.date: 04/07/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps user, I want to understand how to use the Add-FinOpsServicePrincipal command in the FinOpsToolkit module.
---

# Add-FinOpsServicePrincipal command

The **Add-FinOpsServicePrincipal** command grants the specified service principal or managed identity access to an Enterprise Agreement billing account or department.  

For more information about granting roles to service principals, see [Assign Enterprise Agreement roles to service principals](/azure/cost-management-billing/manage/assign-roles-azure-service-principals). For more information about the permissions associated with each role, see [Usage and costs access by role](/azure/cost-management-billing/manage/understand-ea-roles#usage-and-costs-access-by-role).

<br>

## Syntax

```powershell
Add-FinOpsServicePrincipal `
    -ObjectId 00000000-0000-0000-0000-000000000000 `
    -TenantId 00000000-0000-0000-0000-000000000000 `
    -BillingAccountId 12345 `
    -DepartmentId 67890
```

<br>

## Parameters

| Name               | Description                                                                        |
| ------------------ | ---------------------------------------------------------------------------------- |
| `ObjectId`         | Required. The object ID of the service principal or managed identity.              |
| `TenantId`         | Required. The Azure Active Directory tenant which contains the identity.           |
| `BillingAccountId` | Required. The billing account ID (enrollment number) to grant permissions against. |
| `DepartmentId`     | Optional. The department ID to grant permissions against.                          |

<br>

## Examples

The following examples demonstrate how to use the Add-FinOpsServicePrincipal command to deploy or update a FinOps hub instance.

### Enterprise Administrator (read only)

```powershell
Add-FinOpsServicePrincipal `
    -ObjectId 00000000-0000-0000-0000-000000000000 `
    -TenantId 00000000-0000-0000-0000-000000000000 `
    -BillingAccountId 12345 
```

Grants Enterprise Administrator (read only) permissions to the specified service principal or managed identity.

### Department Administrator (read only)

```powershell
Add-FinOpsServicePrincipal `
    -ObjectId 00000000-0000-0000-0000-000000000000 `
    -TenantId 00000000-0000-0000-0000-000000000000 `
    -BillingAccountId 12345 `
    -DepartmentId 67890
```

Grants Department Administrator (read only) permissions to the specified service principal or managed identity.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/Hubs.DeployHub)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")
<!-- prettier-ignore-end -->

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
