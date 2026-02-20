---
name: Azure Cost Anomaly Alerts
description: Deploy cost anomaly detection alerts across Azure subscriptions at enterprise scale. These alerts automatically notify stakeholders when Cost Management detects unusual spending patterns.
---

**Resource Type:** `Microsoft.CostManagement/scheduledActions` (InsightAlert type)

**Key Features:**
- Automated cost anomaly detection
- Email notifications when anomalies detected
- Enterprise-scale bulk deployment with pagination
- Management group targeting

---

## What Gets Deployed

- **Cost Management scheduled action** named "AnomalyAlert"
- **Anomaly detection** monitoring at subscription level
- **Email notifications** to specified recipients when anomalies are detected

---

## PowerShell Deployment

### Prerequisites

```powershell
# Install required modules
Install-Module -Name Az -Force -AllowClobber
Install-Module -Name Az.ResourceGraph -Force -AllowClobber  # For bulk deployments

# Authenticate
Connect-AzAccount
```

### Single Subscription Deployment

```powershell
# Interactive subscription selection
./Deploy-AnomalyAlert.ps1 `
    -EmailRecipients @("admin@company.com", "finance@company.com") `
    -NotificationEmail "alerts@company.com"

# Specific subscription
./Deploy-AnomalyAlert.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789012" `
    -EmailRecipients @("admin@company.com") `
    -NotificationEmail "alerts@company.com"

# Preview without deploying
./Deploy-AnomalyAlert.ps1 `
    -EmailRecipients @("admin@company.com") `
    -NotificationEmail "alerts@company.com" `
    -WhatIf

# Automated/silent deployment
./Deploy-AnomalyAlert.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789012" `
    -EmailRecipients @("admin@company.com") `
    -NotificationEmail "alerts@company.com" `
    -Force -Quiet
```

### Enterprise Bulk Deployment

```powershell
# Deploy to all subscriptions in management group
./Deploy-BulkALZ.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ManagementGroup "ALZ" `
    -EmailRecipients @("finops@company.com", "alerts@company.com") `
    -NotificationEmail "alerts@company.com"

# Preview deployment
./Deploy-BulkALZ.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ManagementGroup "ALZ" `
    -EmailRecipients @("finops@company.com") `
    -NotificationEmail "alerts@company.com" `
    -WhatIf

# Quiet enterprise deployment
./Deploy-BulkALZ.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ManagementGroup "ALZ" `
    -EmailRecipients @("finops@company.com") `
    -NotificationEmail "alerts@company.com" `
    -Quiet
```

### Parameters

**Deploy-AnomalyAlert.ps1:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `EmailRecipients` | Yes | Array of email addresses for notifications |
| `NotificationEmail` | Yes | Primary email for the alert system |
| `SubscriptionId` | No | Target subscription (interactive if not provided) |
| `DeploymentName` | No | Custom deployment name |
| `Location` | No | Azure region (default: West US) |
| `Force` | No | Skip confirmation prompts |
| `Quiet` | No | Suppress verbose output |
| `WhatIf` | No | Preview without deploying |

**Deploy-BulkALZ.ps1:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `TenantId` | Yes | Azure tenant ID |
| `ManagementGroup` | Yes | Management group name |
| `EmailRecipients` | Yes | Array of email addresses |
| `NotificationEmail` | Yes | Primary email for alerts |
| `WhatIf` | No | Preview without deploying |
| `Quiet` | No | Suppress warnings |

---

## Enterprise Pagination

The bulk deployment script handles large environments with automatic pagination:

```
Connecting to tenant...
Finding subscriptions in ALZ management group...
Querying subscriptions (page 1)...
Found 1000 subscriptions in this page (total: 1000)
Querying subscriptions (page 2)...
Found 1000 subscriptions in this page (total: 2000)
Querying subscriptions (page 3)...
Found 847 subscriptions in this page (total: 2847)
Total subscriptions found: 2847
```

**Key Features:**
- Processes 1,000 subscriptions per query page
- Automatic pagination for 5,000+ subscription environments
- Real-time progress reporting
- Memory-efficient processing

---

## Bicep Template

```bicep
targetScope = 'subscription'

@description('Email recipients for anomaly notifications')
param emailRecipients array

@description('Primary notification email')
param notificationEmail string

module anomalyAlert 'br/public:cost/subscription-scheduled-action:1.0.2' = {
  name: 'anomaly-alert-deployment'
  params: {
    name: 'AnomalyAlert'
    displayName: 'Cost Anomaly Alert'
    kind: 'InsightAlert'
    notification: {
      to: emailRecipients
      subject: 'Cost Anomaly Detected'
    }
    notificationEmail: notificationEmail
  }
}
```

---

## Azure CLI Deployment

```bash
az deployment sub create \
    --name "anomaly-alert-deployment" \
    --location "West US" \
    --template-file "anomaly-alert.bicep" \
    --parameters emailRecipients='["admin@company.com"]' \
                 notificationEmail="alerts@company.com"
```

### Validation

```bash
# Validate template
az deployment sub validate \
    --location "West US" \
    --template-file "anomaly-alert.bicep" \
    --parameters "@anomaly-alert.parameters.json"

# What-if analysis
az deployment sub what-if \
    --location "West US" \
    --template-file "anomaly-alert.bicep" \
    --parameters "@anomaly-alert.parameters.json"
```

---

## Custom Bulk Deployment

### Deploy to Filtered Subscriptions

```powershell
# Deploy only to production subscriptions
$emailRecipients = @("finops@company.com")
$notificationEmail = "alerts@company.com"

$subscriptions = Search-AzGraph -Query @"
ResourceContainers
| where type =~ 'microsoft.resources/subscriptions'
| where name contains 'Prod' or name contains 'Production'
| project subscriptionId, name
"@

Write-Host "Found $($subscriptions.Count) production subscriptions"

foreach ($sub in $subscriptions) {
    Write-Host "Deploying to: $($sub.name)" -ForegroundColor Yellow
    ./Deploy-AnomalyAlert.ps1 `
        -SubscriptionId $sub.subscriptionId `
        -EmailRecipients $emailRecipients `
        -NotificationEmail $notificationEmail `
        -Force
}
```

### Deploy with Validation First

```powershell
$managementGroupName = "Development"
$subscriptions = Search-AzGraph -Query @"
ResourceContainers
| where type =~ 'microsoft.resources/subscriptions'
| project subscriptionId, name
"@ -ManagementGroup $managementGroupName

# Validation phase
Write-Host "=== VALIDATION PHASE ===" -ForegroundColor Magenta
foreach ($sub in $subscriptions) {
    Write-Host "Validating: $($sub.name)" -ForegroundColor Cyan
    ./Deploy-AnomalyAlert.ps1 `
        -SubscriptionId $sub.subscriptionId `
        -EmailRecipients @("test@company.com") `
        -NotificationEmail "test@company.com" `
        -WhatIf
}

# Confirmation
$confirm = Read-Host "Proceed with deployment? (y/N)"
if ($confirm -eq 'y') {
    Write-Host "=== DEPLOYMENT PHASE ===" -ForegroundColor Magenta
    foreach ($sub in $subscriptions) {
        ./Deploy-AnomalyAlert.ps1 `
            -SubscriptionId $sub.subscriptionId `
            -EmailRecipients @("alerts@company.com") `
            -NotificationEmail "alerts@company.com" `
            -Force
    }
}
```

---

## Azure Resource Graph Queries

| Purpose | Query |
|---------|-------|
| All subscriptions | `ResourceContainers \| where type =~ 'microsoft.resources/subscriptions' \| project subscriptionId, name` |
| Enabled only | `ResourceContainers \| where type =~ 'microsoft.resources/subscriptions' \| where properties.state == 'Enabled' \| project subscriptionId, name` |
| Name filter | `ResourceContainers \| where type =~ 'microsoft.resources/subscriptions' \| where name contains 'keyword' \| project subscriptionId, name` |

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Permission errors | Missing Contributor/Owner role | Verify role assignment on subscription |
| Authentication issues | Not signed in | Run `Connect-AzAccount` |
| Location conflicts | Existing alert in different region | Default West US usually works |
| Rate limiting | Too many concurrent requests | Add delays or reduce parallelism |
| Query timeout | Large management group | Pagination handles automatically |

---

## References

- [Cost anomaly alerts](https://learn.microsoft.com/azure/cost-management-billing/understand/analyze-unexpected-charges)
- [Scheduled actions API](https://learn.microsoft.com/rest/api/cost-management/scheduled-actions)
- [Source scripts (azcapman)](https://github.com/msbrettorg/azcapman/tree/main/scripts/anomaly-alerts)
