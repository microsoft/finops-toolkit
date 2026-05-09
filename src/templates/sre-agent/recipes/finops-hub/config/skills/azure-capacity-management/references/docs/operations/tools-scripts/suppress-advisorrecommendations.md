---
title: Suppress-AdvisorRecommendations.ps1
parent: Tools & scripts
nav_order: 10
---

# Suppress-AdvisorRecommendations.ps1

Suppress specific Azure Advisor recommendation types across all subscriptions in a management group for up to 90 days.

## Overview

Azure Policy can't disable Advisor recommendations. Advisor exposes a [suppression API](https://learn.microsoft.com/en-us/azure/advisor/suppress-recommendations?tabs=rest) with a TTL of up to 90 days. This script iterates over a management group's subscriptions and calls that API for each specified recommendation type, so FinOps or platform teams can bulk-suppress noise without navigating the portal subscription by subscription.

### Key capabilities

- **Management group scope**: Suppress across all subscriptions in a hierarchy
- **Recommendation type targeting**: Suppress by recommendation type GUID
- **TTL control**: Configurable suppression duration up to 90 days
- **What-if mode**: Preview scope without writing suppressions

### When to use this script

- Suppressing recommendations that your team manages centrally (e.g., reserved instance purchases handled by a FinOps team, not individual subscription owners)
- Quieting noise for known workload patterns that Advisor doesn't understand
- Temporary suppression during migrations or planned outages
- Weekly automation to maintain suppression across a large subscription estate

> **Note**: Suppression TTL is capped at 90 days per the [Advisor suppressions API](https://learn.microsoft.com/en-us/rest/api/advisor/suppressions/create?tabs=HTTP). Run the script on a weekly or bi-weekly schedule to maintain coverage.

## Prerequisites

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Repository PSGallery -Force

# Authenticate to Azure
Connect-AzAccount

# Verify management group access
Get-AzManagementGroup | Select-Object Name, DisplayName
```

**Permissions**: Advisor Contributor or higher on the management group and its subscriptions. See [Advisor permissions](https://learn.microsoft.com/en-us/azure/advisor/permissions).

## Parameters

| Parameter | Type | Description | Required |
|-----------|------|-------------|----------|
| **ManagementGroupId** | String | Management group name to target | Yes |
| **RecommendationTypeIds** | String[] | Array of recommendation type GUIDs to suppress | Yes |
| **Days** | Int | Suppression duration in days (1–90) | Yes |
| **WhatIf** | Switch | Preview scope without writing suppressions | No |

## Usage examples

### Dry run — preview scope

```powershell
.\Suppress-AdvisorRecommendations.ps1 `
    -ManagementGroupId "your-mg" `
    -RecommendationTypeIds @(
        "89515250-1243-43d1-b4e7-f9437cedffd8",
        "84b1a508-fc21-49da-979e-96894f1665df",
        "48eda464-1485-4dcf-a674-d0905df5054a"
    ) `
    -Days 30 `
    -WhatIf
```

### Execute suppression

```powershell
.\Suppress-AdvisorRecommendations.ps1 `
    -ManagementGroupId "your-mg" `
    -RecommendationTypeIds @(
        "89515250-1243-43d1-b4e7-f9437cedffd8",
        "84b1a508-fc21-49da-979e-96894f1665df",
        "48eda464-1485-4dcf-a674-d0905df5054a"
    ) `
    -Days 30
```

## Finding recommendation type GUIDs

Advisor recommendation type GUIDs aren't displayed in the portal. Retrieve them via the [Advisor REST API](https://learn.microsoft.com/en-us/rest/api/advisor/recommendations/list?tabs=HTTP):

```bash
# List recommendations with their type GUIDs for a subscription
az rest --method GET \
  --url "https://management.azure.com/subscriptions/{subscriptionId}/providers/Microsoft.Advisor/recommendations?api-version=2023-01-01"
```

Look for the `recommendationTypeId` field in the response.

## Scheduling

Suppression TTL tops out at 90 days. To maintain continuous suppression, schedule this script on a weekly cadence via Azure Automation or a CI/CD pipeline:

```powershell
# Azure Automation runbook pattern (using managed identity)
Connect-AzAccount -Identity

.\Suppress-AdvisorRecommendations.ps1 `
    -ManagementGroupId $env:MANAGEMENT_GROUP_ID `
    -RecommendationTypeIds ($env:RECOMMENDATION_TYPE_IDS -split ',') `
    -Days 30
```

**Source**: [Suppressions API reference](https://learn.microsoft.com/en-us/rest/api/advisor/suppressions/create?tabs=HTTP)

## Troubleshooting

### Permission errors

```powershell
# Check current role assignments
Get-AzRoleAssignment -SignInName (Get-AzContext).Account.Id |
    Where-Object { $_.Scope -like "*/managementGroups/*" }
```

You need Advisor Contributor or higher. Reader alone isn't sufficient—write access to the suppression resource is required.

### No subscriptions found

```powershell
# Verify management group access and name
Get-AzManagementGroup -GroupName "your-mg" -Expand -Recurse |
    Select-Object -ExpandProperty Children
```

### Suppression not persisting

Verify the TTL hasn't expired. Suppressions older than `Days` are automatically cleared by Advisor. Check the [Advisor portal](https://portal.azure.com/#blade/Microsoft_Azure_Expert/AdvisorMenuBlade/overview) > Settings > Suppressions to confirm active suppression records.

## Script source

[View full script source →](https://github.com/MSBrett/azcapman/tree/main/scripts/advisor)

## Related documentation

- [Suppress Azure Advisor recommendations](https://learn.microsoft.com/en-us/azure/advisor/suppress-recommendations?tabs=rest)
- [Advisor suppressions API](https://learn.microsoft.com/en-us/rest/api/advisor/suppressions/create?tabs=HTTP)
- [Advisor permissions](https://learn.microsoft.com/en-us/azure/advisor/permissions)
