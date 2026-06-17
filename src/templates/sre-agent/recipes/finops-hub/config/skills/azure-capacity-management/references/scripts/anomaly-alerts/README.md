# Anomaly alert deployment

Deploy cost anomaly alerts across your Azure subscriptions at enterprise scale.

## Table of contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deployment scripts](#deployment-scripts)
  - [Individual subscription deployment](#deploy-anomalyalertps1-individual-subscriptions)
  - [Enterprise bulk deployment](#deploy-bulkalzps1-enterprise-bulk-deployment)
- [Quick start guide](#quick-start-guide)
  - [Single subscription](#single-subscription-deployment)
  - [Enterprise bulk deployment](#enterprise-bulk-deployment)
- [Parameters reference](#parameters-reference)
  - [Deploy-AnomalyAlert.ps1 parameters](#deploy-anomalyalertps1-parameters)
  - [Deploy-BulkALZ.ps1 parameters](#deploy-bulkalzps1-parameters)
- [Enterprise-scale features](#enterprise-scale-features)
  - [Pagination system](#pagination-system)
  - [Performance optimization](#performance-optimization)
- [Advanced usage](#advanced-usage)
  - [Azure CLI deployment](#azure-cli-deployment)
  - [Validation and what-if](#validation-and-what-if)
  - [Custom bulk deployment examples](#custom-bulk-deployment-examples)
- [Troubleshooting](#troubleshooting)
- [Security considerations](#security-considerations)
- [Technical notes](#technical-notes)

## Overview

### What's included

- `anomaly-alert.bicep` - Bicep template that creates subscription-level scheduled actions for anomaly detection
- `Deploy-AnomalyAlert.ps1` - PowerShell script for individual subscription deployments
- `Deploy-BulkALZ.ps1` - Enterprise-scale bulk deployment script with intelligent pagination
- `anomaly-alert.parameters.json` - Sample parameters file for deployment
- `README.md` - This documentation

### What gets deployed

This deployment creates:
- **Cost management scheduled action** - Named "AnomalyAlert" 
- **Anomaly detection** - Monitors cost anomalies at the subscription level
- **Email notifications** - Sends alerts to your specified email addresses when anomalies are detected

## Prerequisites

1. **Azure PowerShell module** - Install the Az PowerShell module:
   ```powershell
   Install-Module -Name Az -Force -AllowClobber
   ```

2. **Azure Resource Graph module** (for bulk operations) - Required for querying multiple subscriptions:
   ```powershell
   Install-Module -Name Az.ResourceGraph -Force -AllowClobber
   ```

3. **Azure authentication** - Sign in to Azure:
   ```powershell
   Connect-AzAccount
   ```

4. **Permissions** - You'll need Contributor or Owner role on target subscriptions.

## Deployment scripts

Choose the right script for your deployment scenario:

### Deploy-AnomalyAlert.ps1 (individual subscriptions)

**Best for**: Single subscription deployments, CI/CD pipelines, testing environments

**Key features**:
- Interactive subscription selection
- Parameter validation and error handling  
- Email address format validation
- What-if deployment support
- Color-coded logging with timestamps
- Force deployment option for automation
- Quiet mode for clean output
- Detailed help documentation

### Deploy-BulkALZ.ps1 (enterprise bulk deployment)

**Best for**: Large-scale enterprise deployments, management group-wide rollouts

**Key features**:
- Automated deployment across thousands of subscriptions
- Azure Resource Graph integration for subscription discovery
- Management group targeting with intelligent filtering
- **Enterprise-grade pagination** for handling massive subscription sets
- **Automatic page size optimization** (1000 subscriptions per query)
- **Progressive discovery** with real-time progress reporting
- Performance optimization with quiet deployment mode
- Built-in error handling and rollback safety
- Confirmation prompts for enterprise safety

## Quick start guide

### Single subscription deployment

#### Option 1: interactive subscription selection
```powershell
./Deploy-AnomalyAlert.ps1 -EmailRecipients @("admin@company.com", "finance@company.com") -NotificationEmail "alerts@company.com"
```

#### Option 2: specify target subscription
```powershell
./Deploy-AnomalyAlert.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -EmailRecipients @("admin@company.com") -NotificationEmail "alerts@company.com"
```

#### Option 3: what-if preview
```powershell
./Deploy-AnomalyAlert.ps1 -EmailRecipients @("admin@company.com") -NotificationEmail "alerts@company.com" -WhatIf
```

#### Option 4: automated/silent deployment
```powershell
./Deploy-AnomalyAlert.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -EmailRecipients @("admin@company.com") -NotificationEmail "alerts@company.com" -Force -Quiet
```

### Enterprise bulk deployment

#### Option 1: deploy to management group
```powershell
./Deploy-BulkALZ.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -ManagementGroup "ALZ" -EmailRecipients @("finops@company.com", "alerts@company.com") -NotificationEmail "alerts@company.com"
```

#### Option 2: bulk what-if preview
```powershell
./Deploy-BulkALZ.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -ManagementGroup "ALZ" -EmailRecipients @("finops@company.com") -NotificationEmail "alerts@company.com" -WhatIf
```

#### Option 3: quiet enterprise deployment
```powershell
./Deploy-BulkALZ.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -ManagementGroup "ALZ" -EmailRecipients @("finops@company.com") -NotificationEmail "alerts@company.com" -Quiet
```

## Parameters reference

### Deploy-AnomalyAlert.ps1 parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `EmailRecipients` | Yes | Array of email addresses that'll receive anomaly notifications |
| `NotificationEmail` | Yes | Primary email address for the anomaly alert system |
| `SubscriptionId` | No | Target subscription ID (if not provided, script prompts for selection) |
| `DeploymentName` | No | Custom deployment name (auto-generated if not provided) |
| `Location` | No | Azure region for deployment metadata (defaults to 'West US') |
| `Force` | No | Skip confirmation prompts |
| `Quiet` | No | Suppress verbose output and enable quiet deployment mode |
| `WhatIf` | No | Preview deployment without making changes |

### Deploy-BulkALZ.ps1 parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `TenantId` | Yes | Azure tenant ID for authentication |
| `ManagementGroup` | Yes | Management group name to query for subscriptions |
| `EmailRecipients` | Yes | Array of email addresses that'll receive anomaly notifications |
| `NotificationEmail` | Yes | Primary email address for the anomaly alert system |
| `WhatIf` | No | Preview deployment without making changes |
| `Quiet` | No | Suppress Azure PowerShell warnings and enable quiet deployment mode |

## Enterprise-scale features

### Pagination system

The `Deploy-BulkALZ.ps1` script includes intelligent pagination designed for large enterprise environments with thousands of subscriptions.

#### How pagination works

The script uses Azure Resource Graph's pagination features to automatically discover and process subscriptions in optimized batches:

1. **Automatic page size optimization** - Queries subscriptions in batches of 1,000 per page (optimal for Azure Resource Graph performance)
2. **Progressive discovery** - Automatically detects when more subscriptions exist and continues querying  
3. **Real-time progress reporting** - Shows current page number and running totals as subscriptions are discovered
4. **Memory efficient** - Processes large subscription sets without overwhelming system memory

#### Implementation details

```powershell
# The script automatically handles pagination like this:
$allSubscriptions = @()
$skip = 0
$pageSize = 1000

do {
    Write-Host "Querying subscriptions (page $([math]::Floor($skip / $pageSize) + 1))..." -ForegroundColor Gray
    
    $query = "ResourceContainers | where type =~ 'microsoft.resources/subscriptions' | where properties.state == 'Enabled' | project subscriptionId, name"
    
    if ($skip -eq 0) {
        $pageResults = Search-AzGraph -Query $query -ManagementGroup $managementGroup -First $pageSize
    } else {
        $pageResults = Search-AzGraph -Query $query -ManagementGroup $managementGroup -First $pageSize -Skip $skip
    }
    
    if ($pageResults) {
        $allSubscriptions += $pageResults
        $skip += $pageResults.Count
        Write-Host "Found $($pageResults.Count) subscriptions in this page (total: $($allSubscriptions.Count))" -ForegroundColor Gray
    }
    
# Continue if we got a full page (indicating there might be more)
} while ($pageResults -and $pageResults.Count -eq $pageSize)
```

### Performance optimization

#### Sample output for large environments

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

#### Enterprise environment benefits

- **Scalability** - Handles environments with 5,000+ subscriptions without performance degradation
- **Reliability** - Prevents timeout issues that can occur when querying large datasets
- **Visibility** - Provides clear progress reporting during the discovery phase
- **Efficiency** - Optimizes network requests by using maximum practical page sizes

## Advanced usage

### Azure CLI deployment

Deploy using Azure CLI with the parameters file:

```bash
az deployment sub create \
  --name "anomaly-alert-deployment" \
  --location "West US" \
  --template-file "anomaly-alert.bicep" \
  --parameters "@anomaly-alert.parameters.json"
```

Or using Azure PowerShell with parameters file:

```powershell
New-AzSubscriptionDeployment -Name "anomaly-alert-deployment" -Location "West US" -TemplateFile "anomaly-alert.bicep" -TemplateParameterFile "anomaly-alert.parameters.json"
```

### Validation and what-if

Before deploying, validate your template using these commands:

#### Azure CLI validation
```bash
az deployment sub validate \
  --location "West US" \
  --template-file "anomaly-alert.bicep" \
  --parameters "@anomaly-alert.parameters.json"
```

#### Azure PowerShell validation
```powershell
Test-AzSubscriptionDeployment -Location "West US" -TemplateFile "anomaly-alert.bicep" -TemplateParameterFile "anomaly-alert.parameters.json"
```

#### What-if analysis (Azure CLI)
```bash
az deployment sub what-if \
  --location "West US" \
  --template-file "anomaly-alert.bicep" \
  --parameters "@anomaly-alert.parameters.json"
```

#### What-if analysis (Azure PowerShell)
```powershell
New-AzSubscriptionDeployment -Name "anomaly-alert-whatif" -Location "West US" -TemplateFile "anomaly-alert.bicep" -TemplateParameterFile "anomaly-alert.parameters.json" -WhatIf
```

### Custom bulk deployment examples

#### Example 1: deploy to all subscriptions in a management group

```powershell
# Set your management group name
$managementGroupName = "Production"
$emailRecipients = @("finops@company.com", "alerts@company.com")
$notificationEmail = "alerts@company.com"

# Query subscriptions in the management group
$subscriptions = Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions' | project subscriptionId, name" -ManagementGroup $managementGroupName

Write-Host "Found $($subscriptions.Count) subscriptions in management group '$managementGroupName'"

# Deploy to each subscription
foreach ($sub in $subscriptions) {
    try {
        Write-Host "Deploying anomaly alert to: $($sub.name) ($($sub.subscriptionId))" -ForegroundColor Cyan
        ./Deploy-AnomalyAlert.ps1 -SubscriptionId $sub.subscriptionId -EmailRecipients $emailRecipients -NotificationEmail $notificationEmail -Force
        Write-Host "✅ Successfully deployed to $($sub.name)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to deploy to $($sub.name): $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

#### Example 2: deploy to filtered subscriptions

```powershell
# Deploy only to production subscriptions (filtering by name pattern)
$emailRecipients = @("finops@company.com")
$notificationEmail = "alerts@company.com"

# Query subscriptions with name filtering
$subscriptions = Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions' | where name contains 'Prod' or name contains 'Production' | project subscriptionId, name"

Write-Host "Found $($subscriptions.Count) production subscriptions"

foreach ($sub in $subscriptions) {
    Write-Host "Deploying to production subscription: $($sub.name)" -ForegroundColor Yellow
    ./Deploy-AnomalyAlert.ps1 -SubscriptionId $sub.subscriptionId -EmailRecipients $emailRecipients -NotificationEmail $notificationEmail -Force
}
```

#### Example 3: deploy with what-if validation first

```powershell
# Validate deployments across multiple subscriptions before actual deployment
$managementGroupName = "Development"
$subscriptions = Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions' | project subscriptionId, name" -ManagementGroup $managementGroupName

# First pass: What-if validation
Write-Host "=== VALIDATION PHASE ===" -ForegroundColor Magenta
foreach ($sub in $subscriptions) {
    Write-Host "Validating deployment for: $($sub.name)" -ForegroundColor Cyan
    ./Deploy-AnomalyAlert.ps1 -SubscriptionId $sub.subscriptionId -EmailRecipients @("test@company.com") -NotificationEmail "test@company.com" -WhatIf
}

# Prompt for confirmation
$confirm = Read-Host "Do you want to proceed with actual deployment? (y/N)"
if ($confirm -eq 'y' -or $confirm -eq 'Y') {
    Write-Host "=== DEPLOYMENT PHASE ===" -ForegroundColor Magenta
    foreach ($sub in $subscriptions) {
        ./Deploy-AnomalyAlert.ps1 -SubscriptionId $sub.subscriptionId -EmailRecipients @("alerts@company.com") -NotificationEmail "alerts@company.com" -Force
    }
}
```

#### Azure Resource Graph query reference

Here are useful Azure Resource Graph queries for subscription discovery:

| Query purpose | KQL query |
|---------------|-----------|
| All accessible subscriptions | `ResourceContainers \| where type =~ 'microsoft.resources/subscriptions' \| project subscriptionId, name` |
| Subscriptions in a management group | Use `-ManagementGroup` parameter with the above query |
| Subscriptions with name filter | `ResourceContainers \| where type =~ 'microsoft.resources/subscriptions' \| where name contains 'keyword' \| project subscriptionId, name` |
| Enabled subscriptions only | `ResourceContainers \| where type =~ 'microsoft.resources/subscriptions' \| where properties.state == 'Enabled' \| project subscriptionId, name` |

**Pagination note**: Azure Resource Graph returns a maximum of 1,000 results per query. The `Deploy-BulkALZ.ps1` script automatically handles this by implementing pagination with the `-First` and `-Skip` parameters. Manual queries may need pagination for large result sets:

```powershell
# Example of manual pagination
$allResults = @()
$skip = 0
$pageSize = 1000

do {
    $pageResults = Search-AzGraph -Query $query -First $pageSize -Skip $skip
    $allResults += $pageResults
    $skip += $pageResults.Count
} while ($pageResults.Count -eq $pageSize)
```

## Troubleshooting

### Common issues and solutions

1. **Permission errors** - Ensure you have Contributor or Owner role on the target subscription
2. **Authentication issues** - Run `Connect-AzAccount` and verify you're signed into the correct tenant
3. **Module not found** - Install the Azure PowerShell module: `Install-Module -Name Az`
4. **Location conflicts** - If you get an "Invalid deployment location" error, the subscription may already have an anomaly alert in a different region. The scripts default to "West US" which works for most cases.
5. **Template validation errors** - Ensure the Bicep template includes `targetScope = 'subscription'` for subscription-level deployments
6. **Resource Graph module missing** - For bulk operations, install: `Install-Module -Name Az.ResourceGraph`
7. **Management group access** - Ensure you have Reader role or higher on management groups when using `-ManagementGroup` parameter
8. **Query timeout** - Large management groups may cause query timeouts; the pagination system automatically handles this by processing subscriptions in batches of 1,000
9. **Memory usage** - The pagination system efficiently manages memory when processing thousands of subscriptions
10. **Azure Resource Graph limits** - The script respects Azure Resource Graph's rate limits and pagination requirements automatically
11. **Rate limiting** - Azure Resource Manager may throttle requests during bulk deployments; add delays between deployments if needed
12. **Existing anomaly alerts** - Subscriptions may already have anomaly alerts configured; the script will update existing ones
13. **Verbose output issues** - Use the `-Quiet` parameter to suppress verbose Azure PowerShell warnings and deployment monitoring delays

### Best practices for enterprise deployment

1. **Test first** - Always use what-if validation or deploy to a test subscription first
2. **Error handling** - Wrap deployments in try-catch blocks to handle failures gracefully  
3. **Logging** - Log successful and failed deployments for audit purposes
4. **Use enterprise script for scale** - For deployments involving 100+ subscriptions, use `Deploy-BulkALZ.ps1` which includes automatic pagination
5. **Monitor progress** - The pagination system provides real-time progress updates during subscription discovery
6. **Permissions** - Verify you have appropriate permissions before starting bulk operations
7. **Resource Graph optimization** - The built-in pagination handles Azure Resource Graph's 1,000 result limit automatically
8. **Performance** - Use `-Quiet` parameter for faster deployments without verbose progress output

### Getting help

The PowerShell script includes detailed help documentation:

```powershell
Get-Help ./Deploy-AnomalyAlert.ps1 -Full
```

For the bulk script, basic usage is shown with:

```powershell
Get-Help ./Deploy-BulkALZ.ps1
```

## Security considerations

- Email addresses are validated for proper format before deployment
- The script uses Azure PowerShell's built-in authentication mechanisms
- No credentials are stored or logged in the script
- All Azure interactions use the authenticated user's permissions

## Technical notes

- The Bicep template includes `targetScope = 'subscription'` for proper subscription-level deployment
- The anomaly alert uses the public Bicep registry module `br/public:cost/subscription-scheduled-action:1.0.2`
- Alerts are configured for "InsightAlert" type, which specifically monitors for cost anomalies
- The display name is set to "My anomaly check" but can be customized by modifying the Bicep template
- The scheduled action operates at the subscription level
- Default deployment location is "West US" to avoid conflicts with existing deployments
- Both scripts support email address validation and proper error handling
