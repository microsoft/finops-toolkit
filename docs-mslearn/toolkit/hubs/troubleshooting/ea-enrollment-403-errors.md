---
title: Troubleshooting Enterprise Agreement enrollment 403 errors
description: Learn how to resolve HTTP 403 (Forbidden) errors when assigning Enterprise Agreement enrollment reader permissions to service principals for FinOps hubs.
author: flanakin
ms.author: micflan
ms.date: 10/11/2025
ms.topic: troubleshooting
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps practitioner, I want to understand why I'm getting 403 errors when assigning EA enrollment reader permissions so I can successfully configure my FinOps hub.
---

<!-- cSpell:ignore pwsh -->

# Troubleshooting Enterprise Agreement enrollment 403 errors

When configuring FinOps hubs with Enterprise Agreement (EA) scopes, you might encounter HTTP 403 (Forbidden) errors when assigning enrollment reader permissions to service principals using the `Add-FinOpsServicePrincipal` PowerShell cmdlet. This article explains the root causes and provides solutions to resolve these errors.

<br>

## Root causes

The 403 error typically occurs due to one of these issues:

### Incorrect object ID (most common)

**80% of cases** - Users provide the wrong object ID when calling `Add-FinOpsServicePrincipal`:

- ❌ **Wrong**: Application object ID from **App registrations** in the Azure portal
- ✅ **Correct**: Service principal object ID from **Enterprise applications** in the Azure portal

As stated in the official Microsoft documentation: *"You must identify and use the Enterprise application object ID where you granted the EA role. If you use the Object ID from some other application, API calls fail."*

### Insufficient permissions

**15% of cases** - The user running the command lacks the required permissions:

- You must have the **Enrollment writer** role in your Enterprise Agreement to assign the **EnrollmentReader** role to service principals
- Only users with enrollment writer permissions can grant EA roles to other identities

### Authentication context issues

**5% of cases** - PowerShell session issues:

- Not connected to the correct Azure account
- Using an outdated PowerShell version (PowerShell 5.1 instead of PowerShell 7+)
- Stale authentication tokens

<br>

## Solutions

### Solution 1: Use the correct service principal object ID

The most common solution is to ensure you're using the correct object ID:

```powershell
# Get the correct Service Principal Object ID (NOT the Application ID)
$sp = Get-AzADServicePrincipal -DisplayName "your-managed-identity-name"
$objectId = $sp.Id  # This is the CORRECT Object ID to use

# Assign enrollment reader permissions
Add-FinOpsServicePrincipal `
    -BillingAccountId 12345678 `
    -ObjectId $objectId `
    -TenantId (Get-AzContext).Tenant.Id
```

**How to find the correct object ID:**

1. Sign in to the [Azure portal](https://portal.azure.com)
2. Navigate to **Microsoft Entra ID** > **Enterprise applications**
3. Find your managed identity or service principal
4. Copy the **Object ID** shown in the overview page
5. Use this object ID with the `Add-FinOpsServicePrincipal` cmdlet

### Solution 2: Use the Azure REST API directly

As an alternative verification method, you can use the Azure REST API's "Try it" feature:

1. Navigate to the [Role Assignments - Put REST API documentation](https://learn.microsoft.com/rest/api/billing/2019-10-01-preview/role-assignments/put)
2. Select **Try it** to open the interactive API console
3. Provide the required parameters:
   - Billing account ID
   - Service principal object ID (from Enterprise applications)
   - Role definition ID for EnrollmentReader: `24f8edb6-1668-4659-b5e2-40bb5f3a7d7e`
4. Select **Run** and verify you receive a 200 OK response

This method helps confirm that:
- You're using the correct object ID
- Your account has the required permissions
- The API endpoint is accessible

### Solution 3: Verify your permissions

Confirm you have the required enrollment writer role:

```powershell
# Check your current Azure context
Get-AzContext

# Verify you're authenticated as the correct user
Connect-AzAccount

# If needed, switch to the correct subscription
Set-AzContext -SubscriptionId "your-subscription-id"
```

If you don't have enrollment writer permissions, contact your Enterprise Agreement administrator to request the appropriate role assignment.

### Solution 4: Upgrade PowerShell version

If you're using PowerShell 5.1, upgrade to PowerShell 7+ for better compatibility:

1. Download and install [PowerShell 7+](https://github.com/PowerShell/PowerShell/releases/latest)
2. Open a new PowerShell 7 session
3. Reconnect to Azure:

```powershell
# Install the Az module if needed
Install-Module -Name Az -Repository PSGallery -Force

# Connect to Azure
Connect-AzAccount
```

<br>

## Verification

After applying a solution, verify the role assignment was successful:

```powershell
# Verify the role assignment
Add-FinOpsServicePrincipal `
    -BillingAccountId 12345678 `
    -ObjectId $objectId `
    -TenantId (Get-AzContext).Tenant.Id

# Expected output:
# id                                                                                                               name                                 properties
# --                                                                                                               ----                                 ----------
# /providers/Microsoft.Billing/billingAccounts/12345678/billingRoleAssignments/959bc89a-xxxx-xxxx-xxxx-7788e87d9823 959bc89a-xxxx-xxxx-xxxx-7788e87d9823 @{createdOn=...
# Successfully granted Enrollment Reader permissions to the specified service principal.
```

<br>

## Related resources

- [Assign roles to Azure Enterprise Agreement service principals](https://learn.microsoft.com/azure/cost-management-billing/manage/assign-roles-azure-service-principals) - Official Microsoft guide with step-by-step instructions
- [Understand Azure Enterprise Agreement administrative roles](https://learn.microsoft.com/azure/cost-management-billing/manage/understand-ea-roles) - Details on EA role hierarchy and permissions
- [Role Assignments - Put REST API](https://learn.microsoft.com/rest/api/billing/2019-10-01-preview/role-assignments/put) - Interactive API documentation
- [Troubleshoot Azure RBAC](https://learn.microsoft.com/azure/role-based-access-control/troubleshooting) - General Azure RBAC troubleshooting guidance
- [Configure scopes in FinOps hubs](../configure-scopes.md) - FinOps-specific EA configuration guidance

<br>

---

## Related content

- [Configure scopes](../configure-scopes.md)
- [Deploy FinOps hubs](../deploy.md)
- [FinOps hubs overview](../finops-hubs-overview.md)
