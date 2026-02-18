---
name: Azure storage cost analysis
description: Analyze storage account costs and usage across an Enterprise Agreement billing account. Generates formatted reports showing costs by subscription, top storage accounts, and detailed per-account metrics with storage quantities in GiB.
---

**Key Features:**
- Storage account cost aggregation across EA billing account
- Usage quantity tracking across all storage meter types (Hot/Cool/Archive, LRS/GRS/ZRS)
- Summary by subscription with account counts and storage totals
- Top 20 storage accounts ranked by cost
- Complete storage account listing sorted by cost

---

## Important context

Storage costs are NOT eligible for savings plan or reservation discounts -- those apply only to compute. This report helps identify storage cost optimization opportunities through:

- Tier optimization (Hot to Cool to Archive based on access patterns)
- Redundancy right-sizing (GRS to LRS where geo-redundancy is not required)
- Lifecycle management policies for automatic tiering
- Identifying orphaned or oversized storage accounts

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `BillingAccountId` | No | (configured) | EA billing account ID |
| `Timeframe` | No | MonthToDate | Query period: MonthToDate, BillingMonthToDate, TheLastMonth |

---

## EA storage report script

```powershell
<#
.SYNOPSIS
    Generates a storage account cost report for an Enterprise Agreement billing account.

.DESCRIPTION
    Queries Azure Cost Management API for storage account costs and usage across an
    Enterprise Agreement. Outputs a formatted report showing costs by subscription,
    top storage accounts, and detailed per-account metrics.

.PARAMETER BillingAccountId
    The EA billing account ID. Defaults to the configured value.

.PARAMETER Timeframe
    The time period to query. Valid values: MonthToDate, BillingMonthToDate, TheLastMonth.
    Defaults to MonthToDate.

.EXAMPLE
    .\Get-EAStorageReport.ps1

.EXAMPLE
    .\Get-EAStorageReport.ps1 -BillingAccountId "1234567" -Timeframe "TheLastMonth"

.NOTES
    Requires Azure CLI (az) with an authenticated session that has Cost Management
    Reader or Billing Reader access to the EA billing account.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$BillingAccountId = "8611537",

    [Parameter()]
    [ValidateSet("MonthToDate", "BillingMonthToDate", "TheLastMonth")]
    [string]$Timeframe = "MonthToDate"
)

$ErrorActionPreference = "Stop"

# Configuration
$EAName = "Trey Research Demo (DO NOT USE)"
$ApiVersion = "2023-11-01"

# Subscription name mapping
$SubNames = @{
    "018ff1c8-0bf8-4026-80e7-ce4a6f977f11" = "VLA-CMD-Demo"
    "1caaa5a3-2b66-438e-8ab4-bce37d518c5d" = "ACM-Demo"
    "586f1d47-9dd9-43d5-b196-6e28f8405ff8" = "CPX-FinOps"
    "64e355d7-997c-491d-b0c1-8414dccfcf42" = "Trey-Research-Dev"
    "6c3cfdf5-688d-4259-9ef6-c3bbfb355c57" = "FTK-Dev"
    "710625ca-2ae6-40da-90b9-2aa1eedd32d1" = "Auto-Cost-Report"
    "73c0021f-a37d-433f-8baa-7450cb54eea6" = "Fiscal-Insights"
    "9ec51cfd-5ca7-4d76-8101-dd0a4abc5674" = "Analytics-Engine"
    "ed570627-0265-4620-bb42-bae06bcfa914" = "Microlab"
}

function Invoke-CostManagementQuery {
    <#
    .SYNOPSIS
        Executes a Cost Management query via Azure REST API.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$QueryBody
    )

    $url = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$BillingAccountId/providers/Microsoft.CostManagement/query?api-version=$ApiVersion"
    $bodyJson = $QueryBody | ConvertTo-Json -Depth 10 -Compress

    try {
        $result = az rest --method post --url $url --body $bodyJson --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Cost Management query failed: $result"
            return $null
        }
        return $result | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to execute Cost Management query: $_"
        return $null
    }
}

function Get-StorageCosts {
    <#
    .SYNOPSIS
        Queries storage account costs from Cost Management.
    #>
    [CmdletBinding()]
    param()

    $query = @{
        type      = "ActualCost"
        timeframe = $Timeframe
        dataset   = @{
            granularity = "None"
            aggregation = @{
                totalCost = @{ name = "Cost"; function = "Sum" }
            }
            grouping    = @(
                @{ type = "Dimension"; name = "ResourceId" }
            )
            filter      = @{
                and = @(
                    @{ dimensions = @{ name = "ServiceName"; operator = "In"; values = @("Storage") } }
                    @{ dimensions = @{ name = "ResourceType"; operator = "In"; values = @("microsoft.storage/storageaccounts") } }
                )
            }
        }
    }

    $result = Invoke-CostManagementQuery -QueryBody $query
    if ($result -and $result.properties) {
        return $result.properties.rows
    }
    return @()
}

function Get-StorageUsage {
    <#
    .SYNOPSIS
        Queries storage data quantities by meter type.
    #>
    [CmdletBinding()]
    param()

    $dataMeters = @(
        "Hot LRS Data Stored", "Hot ZRS Data Stored", "Hot GRS Data Stored", "Hot RA-GRS Data Stored",
        "Cool LRS Data Stored", "Cool ZRS Data Stored", "Cool GRS Data Stored",
        "Archive LRS Data Stored", "Archive GRS Data Stored",
        "Premium LRS Data Stored", "Premium ZRS Data Stored",
        "Standard LRS Data Stored", "Standard GRS Data Stored", "Standard ZRS Data Stored",
        "LRS Data Stored", "GRS Data Stored", "ZRS Data Stored", "RA-GRS Data Stored",
        "Data Stored", "Hot LRS Blob Inventory", "Hot ZRS Blob Inventory"
    )

    $query = @{
        type      = "ActualCost"
        timeframe = $Timeframe
        dataset   = @{
            granularity = "None"
            aggregation = @{
                totalCost  = @{ name = "Cost"; function = "Sum" }
                totalUsage = @{ name = "UsageQuantity"; function = "Sum" }
            }
            grouping    = @(
                @{ type = "Dimension"; name = "ResourceId" }
                @{ type = "Dimension"; name = "Meter" }
            )
            filter      = @{
                and = @(
                    @{ dimensions = @{ name = "ServiceName"; operator = "In"; values = @("Storage") } }
                    @{ dimensions = @{ name = "ResourceType"; operator = "In"; values = @("microsoft.storage/storageaccounts") } }
                    @{ dimensions = @{ name = "Meter"; operator = "In"; values = $dataMeters } }
                )
            }
        }
    }

    $result = Invoke-CostManagementQuery -QueryBody $query
    $usageByResource = @{}

    if ($result -and $result.properties -and $result.properties.rows) {
        foreach ($row in $result.properties.rows) {
            # Columns: Cost, UsageQuantity, ResourceId, Meter, Currency
            $usageQty = $row[1]
            $resourceId = $row[2].ToLower()
            $meter = $row[3]

            $parts = $resourceId -split '/'
            if ($parts.Count -ge 9) {
                $accountName = $parts[-1]
                if (-not $usageByResource.ContainsKey($accountName)) {
                    $usageByResource[$accountName] = @{ GB = 0.0; Meters = @() }
                }
                $usageByResource[$accountName].GB += $usageQty
                $usageByResource[$accountName].Meters += $meter
            }
        }
    }

    return $usageByResource
}

function ConvertFrom-ResourceId {
    <#
    .SYNOPSIS
        Extracts subscription ID, resource group, and storage account name from a resource ID.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceId
    )

    $parts = $ResourceId.ToLower() -split '/'
    if ($parts.Count -ge 9) {
        return @{
            SubscriptionId = $parts[2]
            ResourceGroup  = $parts[4]
            AccountName    = $parts[-1]
        }
    }
    return $null
}

function Format-StorageReport {
    <#
    .SYNOPSIS
        Formats and outputs the storage cost report.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$CostData,

        [Parameter(Mandatory)]
        [hashtable]$UsageData
    )

    $separator = "=" * 140
    $dashLine = "-" * 82
    $longDashLine = "-" * 140

    Write-Output $separator
    Write-Output "STORAGE COSTS REPORT - $Timeframe"
    Write-Output "Enterprise Agreement: $BillingAccountId - $EAName"
    Write-Output $separator
    Write-Output ""

    # Aggregate by subscription
    $subCosts = @{}
    $subAccounts = @{}
    $allAccounts = @()

    foreach ($row in $CostData) {
        $cost = [double]$row[0]
        $resourceId = $row[1]

        $parsed = ConvertFrom-ResourceId -ResourceId $resourceId
        if (-not $parsed) { continue }

        $subId = $parsed.SubscriptionId
        $rg = $parsed.ResourceGroup
        $name = $parsed.AccountName

        if (-not $subCosts.ContainsKey($subId)) {
            $subCosts[$subId] = 0.0
            $subAccounts[$subId] = @()
        }

        $subCosts[$subId] += $cost
        $storageGB = if ($UsageData.ContainsKey($name)) { $UsageData[$name].GB } else { 0.0 }
        $subAccounts[$subId] += @{ Name = $name; RG = $rg; Cost = $cost; StorageGB = $storageGB }

        $subName = if ($SubNames.ContainsKey($subId)) { $SubNames[$subId] } else { $subId.Substring(0, [Math]::Min(20, $subId.Length)) }
        $allAccounts += [PSCustomObject]@{
            Name         = $name
            ResourceGroup = $rg
            Subscription = $subName
            Cost         = $cost
            StorageGB    = $storageGB
        }
    }

    # Summary by subscription
    Write-Output "## SUMMARY BY SUBSCRIPTION"
    Write-Output ""
    Write-Output ("{0,-40} {1,-12} {2,-15} {3,-15}" -f "Subscription", "Accounts", "Cost (USD)", "Storage (GiB)")
    Write-Output $dashLine

    $totalCost = 0.0
    $totalAccounts = 0
    $totalStorage = 0.0

    $sortedSubs = $subCosts.GetEnumerator() | Sort-Object { $_.Value } -Descending

    foreach ($entry in $sortedSubs) {
        $subId = $entry.Key
        $subName = if ($SubNames.ContainsKey($subId)) { $SubNames[$subId] } else { $subId.Substring(0, [Math]::Min(20, $subId.Length)) }
        $accountCount = $subAccounts[$subId].Count
        $subStorage = ($subAccounts[$subId] | Measure-Object -Property StorageGB -Sum).Sum

        Write-Output ("{0,-40} {1,-12} `${2,-14:N2} {3,-15:N2}" -f $subName, $accountCount, $subCosts[$subId], $subStorage)
        $totalCost += $subCosts[$subId]
        $totalAccounts += $accountCount
        $totalStorage += $subStorage
    }

    Write-Output $dashLine
    Write-Output ("{0,-40} {1,-12} `${2,-14:N2} {3,-15:N2}" -f "TOTAL", $totalAccounts, $totalCost, $totalStorage)
    Write-Output ""

    # Top 20 storage accounts
    Write-Output $separator
    Write-Output "## TOP 20 STORAGE ACCOUNTS BY COST"
    Write-Output ""
    Write-Output ("{0,-35} {1,-30} {2,-18} {3,-12} {4,-12}" -f "Storage Account Name", "Resource Group", "Subscription", "Cost (USD)", "Storage (GiB)")
    Write-Output $longDashLine

    $sortedAccounts = $allAccounts | Sort-Object -Property Cost -Descending

    foreach ($account in ($sortedAccounts | Select-Object -First 20)) {
        $displayName = if ($account.Name.Length -gt 35) { $account.Name.Substring(0, 35) } else { $account.Name }
        $displayRG = if ($account.ResourceGroup.Length -gt 30) { $account.ResourceGroup.Substring(0, 30) } else { $account.ResourceGroup }
        $displaySub = if ($account.Subscription.Length -gt 18) { $account.Subscription.Substring(0, 18) } else { $account.Subscription }
        Write-Output ("{0,-35} {1,-30} {2,-18} `${3,-11:N2} {4,-12:N2}" -f $displayName, $displayRG, $displaySub, $account.Cost, $account.StorageGB)
    }

    Write-Output ""
    Write-Output $separator
    Write-Output "## ALL STORAGE ACCOUNTS (sorted by cost)"
    Write-Output ""
    Write-Output ("{0,-35} {1,-30} {2,-18} {3,-12} {4,-12}" -f "Storage Account Name", "Resource Group", "Subscription", "Cost (USD)", "Storage (GiB)")
    Write-Output $longDashLine

    foreach ($account in $sortedAccounts) {
        $displayName = if ($account.Name.Length -gt 35) { $account.Name.Substring(0, 35) } else { $account.Name }
        $displayRG = if ($account.ResourceGroup.Length -gt 30) { $account.ResourceGroup.Substring(0, 30) } else { $account.ResourceGroup }
        $displaySub = if ($account.Subscription.Length -gt 18) { $account.Subscription.Substring(0, 18) } else { $account.Subscription }
        Write-Output ("{0,-35} {1,-30} {2,-18} `${3,-11:N2} {4,-12:N2}" -f $displayName, $displayRG, $displaySub, $account.Cost, $account.StorageGB)
    }

    Write-Output ""
    Write-Output $separator
    Write-Output "Notes:"
    Write-Output "- Costs and storage from Azure Cost Management API for billing account $BillingAccountId"
    Write-Output "- Storage quantities are in GiB (gibibytes, base-2) as reported by Azure billing meters"
    Write-Output "- Costs include all storage operations (data stored, transactions, operations)"
    Write-Output $separator
}

# Main execution
Write-Host "Fetching storage costs..." -ForegroundColor Cyan
$costData = Get-StorageCosts

if (-not $costData -or $costData.Count -eq 0) {
    Write-Error "No cost data retrieved. Check authentication and permissions."
    exit 1
}

Write-Host "Retrieved $($costData.Count) storage accounts" -ForegroundColor Cyan

Write-Host "Fetching storage usage quantities..." -ForegroundColor Cyan
$usageData = Get-StorageUsage
Write-Host "Retrieved usage data for $($usageData.Count) accounts" -ForegroundColor Cyan

Format-StorageReport -CostData $costData -UsageData $usageData
```

---

## Customization

The script contains values that must be customized for your environment:

1. **`$BillingAccountId`** (line 31): Replace the default value with your EA billing account ID. Find it with:

```bash
az billing account list --query "[].{Name:name, Id:id}" -o table
```

2. **`$EAName`** (line 41): Replace with your EA enrollment name (display only -- used in report header).

3. **`$SubNames`** (lines 45-55): Replace the subscription ID to friendly name mapping with your own subscriptions. This is optional -- unknown subscriptions display a truncated subscription ID instead.

---

## Output sections

The report produces three sections:

1. **Summary by subscription** -- Account count, total cost (USD), total storage (GiB) per subscription, sorted by cost descending
2. **Top 20 storage accounts by cost** -- Name, resource group, subscription, cost, storage for the 20 most expensive accounts
3. **All storage accounts** -- Complete listing of every storage account, sorted by cost descending

---

## Storage meter types tracked

The script aggregates usage across these Azure storage meter categories:

- **Access tiers**: Hot, Cool, Archive
- **Redundancy types**: LRS, ZRS, GRS, RA-GRS
- **Premium storage**: Premium LRS, Premium ZRS
- **Standard storage**: Standard LRS, Standard GRS, Standard ZRS
- **Generic meters**: Data Stored, Blob Inventory

Units are in GiB (gibibytes, base-2) as reported by Azure billing meters.

---

## Cost optimization actions

| Finding | Action | Potential savings |
|---------|--------|-------------------|
| Large Hot tier accounts with low access | Move to Cool or Archive tier | 40-80% on storage costs |
| GRS/RA-GRS accounts not needing geo-redundancy | Switch to LRS or ZRS | 50% on redundancy costs |
| Many small accounts with minimal data | Consolidate or decommission | Reduce per-account overhead |
| Accounts with no recent transactions | Evaluate for deletion | 100% of that account's cost |
| Archive-eligible data in Hot/Cool | Implement lifecycle management policies | 60-90% on eligible data |

---

## Prerequisites

- Azure CLI (`az`) with an authenticated session
- Cost Management Reader or Billing Reader on the EA billing account
- Enterprise Agreement (EA) billing account (this script uses EA-specific API scopes)

---

## References

- [Azure Blob Storage access tiers](https://learn.microsoft.com/azure/storage/blobs/access-tiers-overview)
- [Azure Storage redundancy](https://learn.microsoft.com/azure/storage/common/storage-redundancy)
- [Lifecycle management policies](https://learn.microsoft.com/azure/storage/blobs/lifecycle-management-overview)
- [Cost Management Query API](https://learn.microsoft.com/rest/api/cost-management/query)
- [Azure Storage pricing](https://azure.microsoft.com/pricing/details/storage/blobs/)
