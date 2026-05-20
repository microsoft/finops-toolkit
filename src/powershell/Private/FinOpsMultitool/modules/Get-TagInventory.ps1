###########################################################################
# GET-TAGINVENTORY.PS1
# AZURE FINOPS MULTITOOL - Tag Inventory Across the Tenant
###########################################################################
# Purpose: Use Azure Resource Graph to discover every tag name and value
#          in use across all subscriptions, along with resource counts
#          and resource types per tag.
#
# This is the "Understand" FinOps pillar - you can't allocate costs you
# can't see, and untagged resources are invisible to chargeback.
###########################################################################

function Get-TagInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    $subIds = $Subscriptions | ForEach-Object { $_.Id }

    # -- Query 1: Tag names, values, and counts -------------------------
    try {
        Write-Host "  Scanning tag inventory via Resource Graph..." -ForegroundColor Cyan
        $tagQuery = @"
resources
| union resourcecontainers
| mvexpand tags
| extend tagName = tostring(bag_keys(tags)[0])
| extend tagValue = tostring(tags[tagName])
| where isnotempty(tagName)
| summarize ResourceCount = count(), ResourceTypes = make_set(type) by tagName, tagValue
| order by tagName asc, ResourceCount desc
"@

        $allResults = @()
        $skipToken = $null

        do {
            $result = Search-AzGraphSafe -Query $tagQuery -Subscription $subIds -First 1000 -SkipToken $skipToken
            if (-not $result) { break }
            $allResults += $result.Data
            $skipToken = $result.SkipToken
        } while ($skipToken)

    } catch {
        Write-Warning "Tag inventory query failed: $($_.Exception.Message)"
        $allResults = @()
    }

    # -- Query 2: Untagged resource count (via REST to avoid runspace issues with single-row aggregates)
    try {
        $countBody = @{
            subscriptions = @($subIds)
            query = "resources | where isnull(tags) or tags == '{}' | summarize UntaggedCount = count()"
        } | ConvertTo-Json -Depth 5
        $countResp = Invoke-AzRestMethodWithRetry -Path "/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" -Method POST -Payload $countBody
        if ($countResp.StatusCode -eq 200) {
            $countData = ($countResp.Content | ConvertFrom-Json)
            if ($countData.data -and $countData.data.Count -gt 0) {
                $untaggedCount = [int]$countData.data[0].UntaggedCount
            }
        }
    } catch {
        Write-Warning "Untagged resource count failed: $($_.Exception.Message)"
    }

    # -- Query 4: Untagged resource details (paginate all) ----------------
    $untaggedResources = @()
    try {
        $untaggedDetailQuery = @"
resources
| where isnull(tags) or tags == '{}'
| project name, type, resourceGroup, subscriptionId, location
| order by type asc, name asc
"@
        $allUntagged = @()
        $udSkipToken = $null
        do {
            $udResult = Search-AzGraphSafe -Query $untaggedDetailQuery -Subscription $subIds -First 1000 -SkipToken $udSkipToken
            if (-not $udResult -or -not $udResult.Data) { break }
            $allUntagged += $udResult.Data
            $udSkipToken = $udResult.SkipToken
            if ($allUntagged.Count % 2000 -eq 0) {
                Write-Host "    Loaded $($allUntagged.Count) untagged resources so far..." -ForegroundColor Gray
            }
        } while ($udSkipToken)

        if ($allUntagged.Count -gt 0) {
            # Map subscription IDs to names
            $subNameMap = @{}
            foreach ($s in $Subscriptions) { $subNameMap[$s.Id] = $s.Name }
            $untaggedResources = @($allUntagged | ForEach-Object {
                [PSCustomObject]@{
                    ResourceName   = $_.name
                    ResourceType   = $_.type
                    ResourceGroup  = $_.resourceGroup
                    Subscription   = if ($subNameMap.ContainsKey($_.subscriptionId)) { $subNameMap[$_.subscriptionId] } else { $_.subscriptionId }
                    Location       = $_.location
                }
            })
            Write-Host "    Total untagged resources loaded: $($untaggedResources.Count)" -ForegroundColor Cyan
        }
    } catch {
        Write-Warning "Untagged resource detail query failed: $($_.Exception.Message)"
    }

    # -- Query 3: Total resource count (via REST to avoid runspace issues with single-row aggregates)
    $totalCount = 0
    try {
        $totalBody = @{
            subscriptions = @($subIds)
            query = "resources | summarize TotalCount = count()"
        } | ConvertTo-Json -Depth 5
        $totalResp = Invoke-AzRestMethodWithRetry -Path "/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" -Method POST -Payload $totalBody
        if ($totalResp.StatusCode -eq 200) {
            $totalData = ($totalResp.Content | ConvertFrom-Json)
            if ($totalData.data -and $totalData.data.Count -gt 0) {
                $totalCount = [int]$totalData.data[0].TotalCount
            }
        }
    } catch {
        Write-Warning "Total resource count failed: $($_.Exception.Message)"
    }

    # Fallback: derive counts from detail data if REST queries failed
    if ($untaggedCount -eq 0 -and $untaggedResources.Count -gt 0) {
        $untaggedCount = $untaggedResources.Count
        Write-Host "    Using detail query count as fallback: $untaggedCount untagged" -ForegroundColor Yellow
    }

    # -- Build summary --------------------------------------------------
    $tagNames = @{}
    foreach ($row in $allResults) {
        $name = $row.tagName
        if (-not $tagNames.ContainsKey($name)) {
            $tagNames[$name] = @{ Values = @(); TotalResources = 0 }
        }
        $tagNames[$name].Values += [PSCustomObject]@{
            Value         = $row.tagValue
            ResourceCount = $row.ResourceCount
            ResourceTypes = $row.ResourceTypes
        }
        $tagNames[$name].TotalResources += $row.ResourceCount
    }

    # -- Query 5: Tag locations (which subscriptions + RGs each tag is on)
    $tagLocations = @{}
    try {
        $subNameMap = @{}
        foreach ($s in $Subscriptions) { $subNameMap[$s.Id] = $s.Name }

        $locQuery = @"
resources
| union resourcecontainers
| mvexpand tags
| extend tagName = tostring(bag_keys(tags)[0])
| where isnotempty(tagName)
| summarize ResourceCount = count() by tagName, subscriptionId, resourceGroup
| order by tagName asc, ResourceCount desc
"@
        $locResults = @()
        $locSkip = $null
        do {
            $locResult = Search-AzGraphSafe -Query $locQuery -Subscription $subIds -First 1000 -SkipToken $locSkip
            if (-not $locResult) { break }
            $locResults += $locResult.Data
            $locSkip = $locResult.SkipToken
        } while ($locSkip)

        foreach ($row in $locResults) {
            $name = $row.tagName
            if (-not $tagLocations.ContainsKey($name)) {
                $tagLocations[$name] = [System.Collections.Generic.List[string]]::new()
            }
            $subName = if ($subNameMap.ContainsKey($row.subscriptionId)) { $subNameMap[$row.subscriptionId] } else { $row.subscriptionId }
            $loc = "$subName / $($row.resourceGroup)"
            if ($loc -notin $tagLocations[$name]) {
                [void]$tagLocations[$name].Add($loc)
            }
        }
    } catch {
        Write-Warning "Tag location query failed: $($_.Exception.Message)"
    }

    $taggedCount = $totalCount - $untaggedCount
    $tagCoverage = if ($totalCount -gt 0) { [math]::Round(($taggedCount / $totalCount) * 100, 1) } else { 0 }

    return [PSCustomObject]@{
        TagNames           = $tagNames
        TagCount           = $tagNames.Count
        TagLocations       = $tagLocations
        TotalResources     = $totalCount
        TaggedCount        = $taggedCount
        UntaggedCount      = $untaggedCount
        TagCoverage        = $tagCoverage
        UntaggedResources  = $untaggedResources
        RawResults         = $allResults
    }
}
