# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive console tool; the formatted console output is the user interface.')]
param()

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
    $readErrors = [Collections.Generic.List[string]]::new()

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
        $result = Search-AzGraphSafe -Query $tagQuery -Subscription $subIds -First 1000 -All
        if ($null -eq $result) { throw 'Tag values could not be read.' }
        $allResults = @($result.Data)

    }
    catch {
        $readErrors.Add("Tag values: $($_.Exception.Message)")
        Write-Warning "Tag inventory query failed: $($_.Exception.Message)"
        $allResults = @()
    }

    # -- Query 2: Untagged resource count (via REST to avoid runspace issues with single-row aggregates)
    $untaggedCount = $null
    try {
        $countBody = @{
            subscriptions = @($subIds)
            query         = "resources | where isnull(tags) or tags == '{}' | summarize UntaggedCount = count()"
            options       = @{ resultFormat = 'objectArray' }
        } | ConvertTo-Json -Depth 5
        $countResp = Invoke-AzRestMethodWithRetry -Path "/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" -Method POST -Payload $countBody
        if (-not $countResp -or $countResp.StatusCode -ne 200) { throw "HTTP $($countResp.StatusCode) while reading untagged count." }
        $countRows = @(($countResp.Content | ConvertFrom-Json -ErrorAction Stop).data)
        if ($countRows.Count -ne 1) { throw 'Untagged count response has no single measured count.' }
        $count = Get-HubCostValue -Row $countRows[0] -Column 'UntaggedCount'
        if ($count -lt 0 -or $count -ne [math]::Floor($count)) { throw 'Untagged resource count is invalid.' }
        $untaggedCount = [long]$count
    }
    catch {
        $readErrors.Add("Untagged count: $($_.Exception.Message)")
        Write-Warning "Untagged resource count failed: $($_.Exception.Message)"
    }

    # -- Query 4: Untagged resource details (paginate all) ----------------
    $untaggedResources = @()
    try {
        $untaggedDetailQuery = @"
resources
| where isnull(tags) or tags == '{}'
| project id, name, type, resourceGroup, subscriptionId, location
| order by type asc, name asc
"@
        $allUntagged = @()
        $udResult = Search-AzGraphSafe -Query $untaggedDetailQuery -Subscription $subIds -First 1000 -All
        if ($null -eq $udResult) { throw 'Untagged resource details could not be read.' }
        $allUntagged = @($udResult.Data)
        if ($null -eq $untaggedCount) { $untaggedCount = $allUntagged.Count }

        if ($allUntagged.Count -gt 0) {
            # Map subscription IDs to names
            $subNameMap = @{}
            foreach ($s in $Subscriptions) { $subNameMap[$s.Id] = $s.Name }
            $untaggedResources = @($allUntagged | ForEach-Object {
                    [PSCustomObject]@{
                        ResourceName  = $_.name
                        ResourceType  = $_.type
                        ResourceGroup = $_.resourceGroup
                        Subscription  = if ($subNameMap.ContainsKey($_.subscriptionId)) { $subNameMap[$_.subscriptionId] } else { $_.subscriptionId }
                        Location      = $_.location
                    }
                })
            Write-Host "    Total untagged resources loaded: $($untaggedResources.Count)" -ForegroundColor Cyan
        }
    }
    catch {
        $readErrors.Add("Untagged details: $($_.Exception.Message)")
        Write-Warning "Untagged resource detail query failed: $($_.Exception.Message)"
    }

    # -- Query 3: Total resource count (via REST to avoid runspace issues with single-row aggregates)
    $totalCount = $null
    try {
        $totalBody = @{
            subscriptions = @($subIds)
            query         = "resources | summarize TotalCount = count()"
            options       = @{ resultFormat = 'objectArray' }
        } | ConvertTo-Json -Depth 5
        $totalResp = Invoke-AzRestMethodWithRetry -Path "/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" -Method POST -Payload $totalBody
        if (-not $totalResp -or $totalResp.StatusCode -ne 200) { throw "HTTP $($totalResp.StatusCode) while reading total count." }
        $totalRows = @(($totalResp.Content | ConvertFrom-Json -ErrorAction Stop).data)
        if ($totalRows.Count -ne 1) { throw 'Total count response has no single measured count.' }
        $count = Get-HubCostValue -Row $totalRows[0] -Column 'TotalCount'
        if ($count -lt 0 -or $count -ne [math]::Floor($count)) { throw 'Total resource count is invalid.' }
        $totalCount = [long]$count
    }
    catch {
        $readErrors.Add("Total count: $($_.Exception.Message)")
        Write-Warning "Total resource count failed: $($_.Exception.Message)"
    }

    # Fallback: the REST count endpoint returns table-format results in some
    # tenants (no objectArray rows), leaving the count at 0. Re-derive via the
    # Resource Graph cmdlet path, which is reliable where the tag query works.
    if ($null -eq $totalCount) {
        try {
            $tcResult = Search-AzGraphSafe -Query "resources | summarize TotalCount = count()" -Subscription $subIds -First 1
            $tcRows = if ($tcResult) { @($tcResult.Data) } else { @() }
            if ($tcRows.Count -gt 0 -and $null -ne $tcRows[0].TotalCount) {
                $count = Get-HubCostValue -Row $tcRows[0] -Column 'TotalCount'
                if ($count -lt 0 -or $count -ne [math]::Floor($count)) { throw 'Fallback resource count is invalid.' }
                $totalCount = [long]$count
            }
        }
        catch {
            Write-Verbose "Non-fatal: $($_.Exception.Message)"
        }
    }

    # Fallback: derive counts from detail data if REST queries failed
    if ($null -eq $untaggedCount -and $untaggedResources.Count -gt 0) {
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
        # Case-variant keys fold into one hashtable entry, so the same value can
        # arrive twice. Merge on an exact match; a different casing is a different value.
        $existingValue = $tagNames[$name].Values | Where-Object { [string]$_.Value -ceq [string]$row.tagValue } | Select-Object -First 1
        if ($existingValue) {
            $existingValue.ResourceCount += $row.ResourceCount
        }
        else {
            $tagNames[$name].Values += [PSCustomObject]@{
                Value         = $row.tagValue
                ResourceCount = $row.ResourceCount
                ResourceTypes = $row.ResourceTypes
            }
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
        $locResult = Search-AzGraphSafe -Query $locQuery -Subscription $subIds -First 1000 -All
        if ($null -eq $locResult) { throw 'Tag locations could not be read.' }
        $locResults = @($locResult.Data)

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
    }
    catch {
        $readErrors.Add("Tag locations: $($_.Exception.Message)")
        Write-Warning "Tag location query failed: $($_.Exception.Message)"
    }

    # Last-resort fallback: when the dedicated total query is unavailable (the
    # REST endpoint returned no rows and the cmdlet path also came up empty),
    # derive the total from the tagged + untagged populations so coverage is
    # still meaningful instead of showing 0 tagged / 0 untagged.
    if ($null -eq $totalCount) {
        $taggedFromArg = $null
        try {
            $tagCountBody = @{
                subscriptions = @($subIds)
                query         = "resources | where isnotnull(tags) and tags != '{}' | summarize TaggedCount = count()"
                options       = @{ resultFormat = 'objectArray' }
            } | ConvertTo-Json -Depth 5
            $tagCountResp = Invoke-AzRestMethodWithRetry -Path "/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" -Method POST -Payload $tagCountBody
            if ($tagCountResp.StatusCode -eq 200) {
                $tagCountRows = @(($tagCountResp.Content | ConvertFrom-Json).data)
                if ($tagCountRows.Count -eq 1) {
                    $count = Get-HubCostValue -Row $tagCountRows[0] -Column 'TaggedCount'
                    if ($count -lt 0 -or $count -ne [math]::Floor($count)) { throw 'Tagged resource count is invalid.' }
                    $taggedFromArg = [long]$count
                }
            }
        }
        catch {
            Write-Verbose "Non-fatal: $($_.Exception.Message)"
        }
        if ($null -ne $taggedFromArg -and $null -ne $untaggedCount) {
            $totalCount = $taggedFromArg + $untaggedCount
        }
    }

    if ($null -ne $totalCount -and $null -ne $untaggedCount -and $untaggedCount -gt $totalCount) {
        $readErrors.Add('Resource counts disagree; tagging coverage cannot be calculated.')
    }
    $taggedCount = if ($null -ne $totalCount -and $null -ne $untaggedCount -and $untaggedCount -le $totalCount) { $totalCount - $untaggedCount } else { $null }
    $tagCoverage = if ($readErrors.Count -eq 0 -and $null -ne $taggedCount) {
        if ($totalCount -gt 0) { [math]::Round(($taggedCount / $totalCount) * 100, 1) } else { 0 }
    }
    else { $null }

    # -- Case-variant tag keys -------------------------------------------
    # Azure stores tag keys case-preserving but resolves them case-insensitively.
    # PowerShell hashtables fold case too, so $tagNames has already merged the
    # spellings; only the raw Resource Graph rows still carry them apart. Their
    # values stay on separate rows, which is why one value can appear twice.
    $caseVariants = @()
    $bySpelling = @($allResults) | Group-Object -Property tagName -CaseSensitive
    foreach ($fold in ($bySpelling | Group-Object { ([string]$_.Name).ToLowerInvariant() })) {
        if ($fold.Count -le 1) { continue }
        $variants = @($fold.Group | ForEach-Object {
                [PSCustomObject]@{
                    Spelling      = $_.Name
                    ResourceCount = (@($_.Group) | Measure-Object -Property ResourceCount -Sum).Sum
                }
            } | Sort-Object ResourceCount -Descending)
        $caseVariants += [PSCustomObject]@{
            TagKey        = $fold.Name
            VariantCount  = $fold.Count
            Spellings     = @($variants | ForEach-Object { $_.Spelling })
            Variants      = $variants
            ResourceCount = ($variants | Measure-Object -Property ResourceCount -Sum).Sum
            Detail        = (($variants | ForEach-Object { "$($_.Spelling) ($($_.ResourceCount))" }) -join ', ')
        }
    }
    $spellingCount = @($bySpelling).Count
    if ($caseVariants.Count -gt 0) {
        Write-Host "    Case-variant tag keys: $($caseVariants.Count) ($spellingCount spellings across $($tagNames.Count) keys)" -ForegroundColor Yellow
    }

    return [PSCustomObject]@{
        TagNames           = $tagNames
        CoverageIncomplete = ($readErrors.Count -gt 0)
        ReadErrors         = @($readErrors)
        Note               = if ($readErrors.Count -gt 0) { 'Tag inventory coverage is incomplete. ' + ($readErrors -join ' ') } else { $null }
        TagCount           = $tagNames.Count
        SpellingCount      = $spellingCount
        CaseVariants       = @($caseVariants)
        TagLocations       = $tagLocations
        TotalResources     = $totalCount
        TaggedCount        = $taggedCount
        UntaggedCount      = $untaggedCount
        TagCoverage        = $tagCoverage
        UntaggedResources  = $untaggedResources
        RawResults         = $allResults
    }
}
