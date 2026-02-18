---
name: Azure Advisor
description: Azure Advisor provides personalized recommendations for optimizing Azure resources across cost, security, reliability, operational excellence, and performance. This skill focuses on **cost recommendations** and recommendation management.
---

**Key Features:**
- Cost optimization recommendations (right-sizing, shutdown, reservations)
- Recommendation suppression with TTL (up to 90 days)
- Bulk suppression across management groups
- Integration with FinOps workflows

---

## Querying Cost Recommendations

### Azure CLI

```bash
# List all cost recommendations for a subscription
az advisor recommendation list \
    --category Cost \
    --output table

# List with details
az advisor recommendation list \
    --category Cost \
    --query "[].{Resource:resourceGroup, Impact:impact, Description:shortDescription.problem}"

# Filter by impact
az advisor recommendation list \
    --category Cost \
    --query "[?impact=='High']"
```

### PowerShell

```powershell
# Get all cost recommendations
Get-AzAdvisorRecommendation |
    Where-Object { $_.Category -eq 'Cost' }

# Get high-impact recommendations
Get-AzAdvisorRecommendation |
    Where-Object { $_.Category -eq 'Cost' -and $_.Impact -eq 'High' }

# Export to CSV
Get-AzAdvisorRecommendation |
    Where-Object { $_.Category -eq 'Cost' } |
    Select-Object ResourceId, Impact, ShortDescriptionProblem |
    Export-Csv -Path "advisor-recommendations.csv"
```

### REST API

```http
GET https://management.azure.com/subscriptions/{subscriptionId}/providers/Microsoft.Advisor/recommendations?api-version=2023-01-01&$filter=Category eq 'Cost'
Authorization: Bearer {token}
```

---

## Common Cost Recommendation Types

| Recommendation Type | ID | Description |
|--------------------|-----|-------------|
| Right-size VMs | `e10b1381-5f0a-47ff-8c7b-37bd13d7c974` | Resize underutilized VMs |
| Shutdown idle VMs | `89515250-1243-43d1-b4e7-f9437cedffd8` | Stop VMs with low utilization |
| Reserved instances | `84b1a508-fc21-49da-979e-96894f1665df` | Purchase RIs for consistent workloads |
| Delete unused disks | `48eda464-1485-4dcf-a674-d0905df5054a` | Remove unattached managed disks |

---

## Suppressing Recommendations

Azure Policy cannot disable Advisor recommendations. Instead, use the Advisor suppression API with TTL up to 90 days.

### PowerShell Suppression Script

```powershell
# Suppress specific recommendation types across a management group
.\Suppress-AdvisorRecommendations.ps1 -ManagementGroupId "your-mg" `
    -RecommendationTypeIds @(
        "89515250-1243-43d1-b4e7-f9437cedffd8",  # Shutdown idle VMs
        "84b1a508-fc21-49da-979e-96894f1665df",  # Reserved instances
        "48eda464-1485-4dcf-a674-d0905df5054a"   # Delete unused disks
    ) -Days 30 -WhatIf

# Execute suppression
.\Suppress-AdvisorRecommendations.ps1 -ManagementGroupId "your-mg" `
    -RecommendationTypeIds @(...) -Days 30
```

### REST API Suppression

```http
PUT https://management.azure.com/{resourceUri}/providers/Microsoft.Advisor/recommendations/{recommendationId}/suppressions/{suppressionName}?api-version=2023-01-01
Content-Type: application/json
Authorization: Bearer {token}

{
  "properties": {
    "ttl": "30:00:00:00"
  }
}
```

**TTL Format:** `days:hours:minutes:seconds` (max 90 days)

> **Dismiss vs postpone:** To permanently dismiss a recommendation instead of postponing it, omit the `ttl` property (send `"properties": {}` in the PUT body). The recommendation will remain hidden indefinitely with no automatic reappearance. Permanent dismissals can be reversed via the [Suppressions DELETE API](https://learn.microsoft.com/en-us/rest/api/advisor/suppressions/delete) or by clicking "Activate" under the Advisor portal's "Postponed & Dismissed" filter. Prefer postpone with TTL over permanent dismiss for cost recommendations, since dismissed recommendations silently stop surfacing even when resource conditions change. Reserve permanent dismissal for recommendations that are structurally irrelevant to your environment.

### List Suppressions

```http
GET https://management.azure.com/subscriptions/{subscriptionId}/providers/Microsoft.Advisor/suppressions?api-version=2023-01-01
```

### Delete Suppression

```http
DELETE https://management.azure.com/{resourceUri}/providers/Microsoft.Advisor/recommendations/{recommendationId}/suppressions/{suppressionName}?api-version=2023-01-01
```

---

## Scheduled Suppression Refresh

Since suppression TTL is capped at 90 days, schedule weekly refreshes via:

- **Azure Automation** - Runbook on schedule
- **CI/CD Pipeline** - GitHub Actions or Azure DevOps
- **Logic Apps** - Recurrence trigger

Example Azure Automation schedule:

```powershell
# Create automation schedule
New-AzAutomationSchedule -AutomationAccountName "MyAutomation" `
    -Name "WeeklyAdvisorSuppression" `
    -StartTime (Get-Date).AddDays(1) `
    -WeekInterval 1 `
    -DaysOfWeek "Monday" `
    -ResourceGroupName "automation-rg"
```

---

## Permissions

| Action | Required Role |
|--------|---------------|
| View recommendations | Reader |
| Suppress recommendations | Advisor Contributor |
| Bulk management group operations | Advisor Contributor on MG and subscriptions |

---

## Azure Resource Graph Queries

### All Cost Recommendations

```kusto
advisorresources
| where type == "microsoft.advisor/recommendations"
| where properties.category == "Cost"
| project
    subscriptionId,
    resourceGroup,
    impact = properties.impact,
    problem = properties.shortDescription.problem,
    solution = properties.shortDescription.solution,
    savings = properties.extendedProperties.savingsAmount
```

### High-Impact Recommendations with Savings

```kusto
advisorresources
| where type == "microsoft.advisor/recommendations"
| where properties.category == "Cost"
| where properties.impact == "High"
| extend savings = todouble(properties.extendedProperties.savingsAmount)
| summarize
    TotalSavings = sum(savings),
    Count = count()
    by subscriptionId
| order by TotalSavings desc
```

### Recommendations by Type

```kusto
advisorresources
| where type == "microsoft.advisor/recommendations"
| where properties.category == "Cost"
| summarize Count = count() by tostring(properties.recommendationTypeId)
| order by Count desc
```

---

## Integration with FinOps Workflows

### Export Recommendations for Analysis

```powershell
# Get all cost recommendations across subscriptions
$recommendations = Get-AzSubscription | ForEach-Object {
    Set-AzContext -Subscription $_.Id
    Get-AzAdvisorRecommendation |
        Where-Object { $_.Category -eq 'Cost' }
}

# Calculate total potential savings
$totalSavings = $recommendations |
    Where-Object { $_.ExtendedProperty["savingsAmount"] } |
    Measure-Object -Property { [double]$_.ExtendedProperty["savingsAmount"] } -Sum

Write-Host "Total potential monthly savings: $($totalSavings.Sum)"
```

### Prioritize by Impact and Savings

```powershell
$recommendations |
    Select-Object @{N='Resource';E={$_.ResourceId}},
                  Impact,
                  @{N='Savings';E={$_.ExtendedProperty["savingsAmount"]}},
                  @{N='Problem';E={$_.ShortDescriptionProblem}} |
    Sort-Object -Property @{E='Impact';D=$true}, @{E='Savings';D=$true} |
    Format-Table
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| No recommendations | New subscription | Wait 24-48 hours for analysis |
| Suppression fails | Missing permissions | Need Advisor Contributor role |
| Suppression expired | TTL exceeded | Re-run suppression script |
| Wrong savings estimate | Stale data | Refresh recommendations |

---

## References

- [Azure Advisor overview](https://learn.microsoft.com/azure/advisor/advisor-overview)
- [Cost recommendations](https://learn.microsoft.com/azure/advisor/advisor-cost-recommendations)
- [Suppress recommendations](https://learn.microsoft.com/azure/advisor/view-recommendations#dismissing-and-postponing-recommendations)
- [Advisor REST API](https://learn.microsoft.com/rest/api/advisor/)
- [Source scripts (azcapman)](https://github.com/msbrettorg/azcapman/tree/main/scripts/advisor)
