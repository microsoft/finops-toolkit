# Azure Advisor suppression

Azure Policy cannot disable Advisor recommendations; Advisor provides suppression APIs with TTL up to 90 days. Use this script to suppress specific recommendation types across a management group. [Source](https://learn.microsoft.com/en-us/azure/advisor/suppress-recommendations?tabs=rest)

## Usage

```powershell
# Dry run
.\Suppress-AdvisorRecommendations.ps1 -ManagementGroupId "your-mg" `
    -RecommendationTypeIds @(
        "89515250-1243-43d1-b4e7-f9437cedffd8",
        "84b1a508-fc21-49da-979e-96894f1665df",
        "48eda464-1485-4dcf-a674-d0905df5054a"
    ) -Days 30 -WhatIf

# Execute
.\Suppress-AdvisorRecommendations.ps1 -ManagementGroupId "your-mg" `
    -RecommendationTypeIds @(...) -Days 30
```

## Schedule

Run weekly via Azure Automation or CI/CD pipeline; suppression TTL is capped at 90 days. [Source](https://learn.microsoft.com/en-us/rest/api/advisor/suppressions/create?tabs=HTTP)

## Permissions

Advisor Contributor (or higher) on the management group and subscriptions. [Source](https://learn.microsoft.com/en-us/azure/advisor/permissions)
