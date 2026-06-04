###########################################################################
# GET-VMCOSTBREAKDOWN.PS1
# AZURE FINOPS MULTITOOL - Full VM Cost Decomposition
###########################################################################
# Purpose: Decompose a single virtual machine's total solution cost into
#          its meter components - compute, OS/data disks, network egress,
#          network infrastructure (public IP / NIC), backup/recovery,
#          security (Defender), monitoring/extension agents, and licensing
#          - instead of a single rolled-up number.
#
# Approach: A VM's billed cost is spread across several resource IDs (the
#           VM, its managed disks, its public IPs, and bandwidth meters).
#           We resolve the VM and its associated resources from Azure
#           Resource Graph, then read cost grouped by ResourceId + meter
#           and bucket each line item into a human-readable category.
#
# Sources:  Live Cost Management API (default) OR the FinOps Hub / export
#           when -HubData is injected by the MCP dispatcher (fast path,
#           also carries consumed quantity so egress GB is exact).
#
# Notes:
# - RBAC: Cost Management Reader (sub scope) + Reader (ARG).
# - Bandwidth that Azure bills at subscription scope (no resource ID)
#   cannot be attributed to one VM; it is reported as a caveat, not folded
#   into the VM total.
###########################################################################

# -- Meter -> category classifier -----------------------------------------
# Buckets a billed line item into a VM-solution cost category using the
# meter category/subcategory (and resource type as a fallback for Hub rows
# where the meter category may be sparse).
function Get-VmMeterBucket {
    param(
        [string]$MeterCategory,
        [string]$MeterSubCategory,
        [string]$MeterName,
        [string]$ResourceType
    )

    $cat = "$MeterCategory".Trim()
    $sub = "$MeterSubCategory".Trim()
    $mtr = "$MeterName".Trim()
    $rt = "$ResourceType".Trim().ToLowerInvariant()
    $blob = "$cat $sub $mtr"

    switch -Regex ($cat) {
        '^(Bandwidth|Inter-Region|Content Delivery Network|Routing Preference)' { return 'Network egress' }
        '^(Virtual Network|Load Balancer|VPN Gateway|ExpressRoute|IP Addresses|NAT Gateway|Application Gateway|Azure Firewall|Azure DNS)' { return 'Network infra' }
        '^Storage' { return 'Disk / storage' }
        '^(Backup|Azure Site Recovery|Recovery Services)' { return 'Backup / recovery' }
        '(Defender|Security Center)' { return 'Security (Defender)' }
        '^(Log Analytics|Azure Monitor|Application Insights)' { return 'Monitoring / agents' }
        '^Virtual Machines Licenses' { return 'Licensing' }
        '^Virtual Machines' {
            if ($blob -match '(?i)\b(Windows|SQL|RHEL|SUSE|License)\b') { return 'Licensing' }
            return 'Compute'
        }
    }

    # Fallback on resource type (Hub rows sometimes lack a meter category)
    switch -Regex ($rt) {
        'microsoft\.compute/virtualmachines$' { return 'Compute' }
        'microsoft\.compute/disks$' { return 'Disk / storage' }
        'microsoft\.network/publicipaddresses$' { return 'Network infra' }
        'microsoft\.network/networkinterfaces$' { return 'Network infra' }
        'microsoft\.recoveryservices/' { return 'Backup / recovery' }
    }

    if ($blob -match '(?i)data transfer|egress|bandwidth') { return 'Network egress' }
    return 'Other'
}

# -- Resolve a VM and its associated billable resources from ARG ----------
# Returns $null when the VM cannot be located. Otherwise an object with the
# VM identity plus a lowercased HashSet of every resource ID whose cost
# rolls up into this VM's solution (VM, disks, NICs, public IPs).
function Resolve-VmAssociation {
    param(
        [string[]]$SubscriptionIds,
        [string]$VmName,
        [string]$ResourceId,
        [string]$ResourceGroup
    )

    $where = if ($ResourceId) {
        "id =~ '$ResourceId'"
    }
    elseif ($ResourceGroup) {
        "name =~ '$VmName' and resourceGroup =~ '$ResourceGroup'"
    }
    else {
        "name =~ '$VmName'"
    }

    $vmQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| where $where
| extend osDiskId = tostring(properties.storageProfile.osDisk.managedDisk.id)
| project id, name, resourceGroup, location, subscriptionId,
          vmSize = tostring(properties.hardwareProfile.vmSize),
          osDiskId,
          dataDisks = properties.storageProfile.dataDisks,
          nics = properties.networkProfile.networkInterfaces
"@

    $res = Search-AzGraphSafe -Query $vmQuery -Subscription $SubscriptionIds -First 50
    $rows = if ($res) { @($res.Data) } else { @() }
    if ($rows.Count -eq 0) { return $null }

    $ambiguous = $rows.Count -gt 1
    $vm = $rows[0]

    $assoc = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    [void]$assoc.Add([string]$vm.id)
    if ($vm.osDiskId) { [void]$assoc.Add([string]$vm.osDiskId) }

    $nicIds = @()
    foreach ($d in @($vm.dataDisks)) {
        $did = [string]$d.managedDisk.id
        if ($did) { [void]$assoc.Add($did) }
    }
    foreach ($n in @($vm.nics)) {
        $nid = [string]$n.id
        if ($nid) { $nicIds += $nid; [void]$assoc.Add($nid) }
    }

    # Resolve public IPs attached to the VM's NICs
    if ($nicIds.Count -gt 0) {
        $nicList = ($nicIds | ForEach-Object { "'$_'" }) -join ','
        $pipQuery = @"
resources
| where type =~ 'microsoft.network/networkinterfaces'
| where id in~ ($nicList)
| mv-expand ipc = properties.ipConfigurations
| extend pip = tostring(ipc.properties.publicIPAddress.id)
| where isnotempty(pip)
| project pip
"@
        try {
            $pipRes = Search-AzGraphSafe -Query $pipQuery -Subscription $SubscriptionIds -First 100
            foreach ($p in @($pipRes.Data)) { if ($p.pip) { [void]$assoc.Add([string]$p.pip) } }
        }
        catch { Write-Warning "  Public IP resolution failed: $($_.Exception.Message)" }
    }

    return [PSCustomObject]@{
        Id             = [string]$vm.id
        Name           = [string]$vm.name
        ResourceGroup  = [string]$vm.resourceGroup
        Location       = [string]$vm.location
        SubscriptionId = [string]$vm.subscriptionId
        VmSize         = [string]$vm.vmSize
        Associated     = $assoc
        Ambiguous      = $ambiguous
        MatchCount     = $rows.Count
    }
}

function Get-VmCostBreakdown {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [object[]]$Subscriptions,

        [Parameter()]
        [string]$VmName,

        [Parameter()]
        [string]$ResourceId,

        [Parameter()]
        [string]$ResourceGroup,

        [Parameter()]
        [object[]]$HubData
    )

    if (-not $VmName -and -not $ResourceId) {
        return [PSCustomObject]@{
            HasData = $false
            Note    = 'Provide a vmName (optionally with resourceGroup) or a full resourceId to decompose.'
        }
    }

    $subIds = @($Subscriptions | ForEach-Object { $_.Id })

    Write-Host "  Resolving VM and associated resources..." -ForegroundColor Cyan
    $vm = Resolve-VmAssociation -SubscriptionIds $subIds -VmName $VmName -ResourceId $ResourceId -ResourceGroup $ResourceGroup
    if (-not $vm) {
        $target = if ($ResourceId) { $ResourceId } else { $VmName }
        return [PSCustomObject]@{
            HasData = $false
            Target  = $target
            Note    = "No virtual machine found matching '$target' in the scanned subscriptions."
        }
    }

    # Bucket accumulators: category -> @{ Cost; Qty; Meters(set) }
    $buckets = @{}
    $addLine = {
        param($Category, $Amount, $Qty, $MeterLabel)
        if (-not $buckets.ContainsKey($Category)) {
            $buckets[$Category] = @{ Cost = 0.0; Qty = 0.0; Meters = [System.Collections.Generic.HashSet[string]]::new() }
        }
        $buckets[$Category].Cost += [double]$Amount
        $buckets[$Category].Qty += [double]$Qty
        if ($MeterLabel) { [void]$buckets[$Category].Meters.Add([string]$MeterLabel) }
    }

    $currency = 'USD'
    $source = 'LiveApi'
    $subLevelEgress = 0.0   # bandwidth billed with no resource ID (cannot attribute)
    $fromHub = ($HubData -and @($HubData).Count -gt 0)

    if ($fromHub) {
        # ---- FinOps Hub / export fast path (richest: carries quantity) ---
        $source = 'FinOpsHub'
        Write-Host "  Decomposing from FinOps Hub export..." -ForegroundColor Cyan
        $props = $HubData[0].PSObject.Properties.Name

        foreach ($row in $HubData) {
            $rid = [string](Get-HubRowValue -Row $row -Names @('ResourceId', 'x_ResourceId', 'InstanceId') -Props $props)
            if (-not $rid -or -not $vm.Associated.Contains($rid)) { continue }

            $cost = [double](Get-HubRowValue -Row $row -Names @('CostInBillingCurrency', 'BilledCost', 'EffectiveCost', 'Cost') -Props $props)
            $qty = [double](Get-HubRowValue -Row $row -Names @('ConsumedQuantity', 'Quantity', 'UsageQuantity') -Props $props)
            $cur = [string](Get-HubRowValue -Row $row -Names @('BillingCurrency', 'BillingCurrencyCode', 'Currency') -Props $props)
            if ($cur) { $currency = $cur }

            $mc = [string](Get-HubRowValue -Row $row -Names @('MeterCategory', 'x_SkuMeterCategory', 'ServiceName') -Props $props)
            $ms = [string](Get-HubRowValue -Row $row -Names @('MeterSubCategory', 'x_SkuMeterSubcategory') -Props $props)
            $mn = [string](Get-HubRowValue -Row $row -Names @('MeterName', 'x_SkuMeterName', 'Meter') -Props $props)
            $rt = [string](Get-HubRowValue -Row $row -Names @('ResourceType', 'x_ResourceType', 'ConsumedService') -Props $props)

            $bucket = Get-VmMeterBucket -MeterCategory $mc -MeterSubCategory $ms -MeterName $mn -ResourceType $rt
            $label = if ($ms) { "$mc / $ms" } elseif ($mc) { $mc } else { $rt }
            & $addLine $bucket $cost $qty $label
        }
    }
    else {
        # ---- Live Cost Management API path -------------------------------
        Write-Host "  Querying cost (Cost Management, MonthToDate)..." -ForegroundColor Cyan
        $rgFilter = @{ dimensions = @{ name = 'ResourceGroupName'; operator = 'In'; values = @($vm.ResourceGroup) } }
        $body = @{
            type      = 'AmortizedCost'
            timeframe = 'MonthToDate'
            dataset   = @{
                granularity = 'None'
                aggregation = @{
                    totalCost = @{ name = 'Cost'; function = 'Sum' }
                    totalQty  = @{ name = 'UsageQuantity'; function = 'Sum' }
                }
                grouping    = @(
                    @{ type = 'Dimension'; name = 'ResourceId' }
                    @{ type = 'Dimension'; name = 'MeterCategory' }
                )
                filter      = $rgFilter
            }
        } | ConvertTo-Json -Depth 12

        $path = "/subscriptions/$($vm.SubscriptionId)/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
        try {
            $resp = Invoke-AzRestMethodWithRetry -Path $path -Method POST -Payload $body
            if ($resp -and $resp.StatusCode -eq 200 -and $resp.Content) {
                $data = $resp.Content | ConvertFrom-Json
                $cols = @($data.properties.columns.name)
                $iCost = [array]::IndexOf($cols, 'Cost')
                $iQty = [array]::IndexOf($cols, 'UsageQuantity')
                $iRes = [array]::IndexOf($cols, 'ResourceId')
                $iCat = [array]::IndexOf($cols, 'MeterCategory')
                $iCur = [array]::IndexOf($cols, 'Currency')

                foreach ($row in @($data.properties.rows)) {
                    $amount = if ($iCost -ge 0) { [double]$row[$iCost] } else { 0 }
                    $qty = if ($iQty -ge 0) { [double]$row[$iQty] }  else { 0 }
                    $rid = if ($iRes -ge 0) { [string]$row[$iRes] }  else { '' }
                    $mc = if ($iCat -ge 0) { [string]$row[$iCat] }  else { '' }
                    if ($iCur -ge 0 -and $row[$iCur]) { $currency = [string]$row[$iCur] }

                    # Bandwidth often bills with an empty resource ID at sub
                    # scope - record it as an unattributable caveat.
                    if (-not $rid) {
                        if ((Get-VmMeterBucket -MeterCategory $mc) -eq 'Network egress') { $subLevelEgress += $amount }
                        continue
                    }
                    if (-not $vm.Associated.Contains($rid)) { continue }

                    $bucket = Get-VmMeterBucket -MeterCategory $mc
                    & $addLine $bucket $amount $qty $mc
                }
            }
            else {
                $code = if ($resp) { $resp.StatusCode } else { 'no response' }
                return [PSCustomObject]@{
                    HasData = $false
                    VmName  = $vm.Name
                    Note    = "Cost Management query failed (HTTP $code). Need Cost Management Reader on the subscription."
                }
            }
        }
        catch {
            return [PSCustomObject]@{
                HasData = $false
                VmName  = $vm.Name
                Note    = "Cost Management query error: $($_.Exception.Message)"
            }
        }
    }

    # -- Assemble breakdown ------------------------------------------------
    $total = 0.0
    foreach ($b in $buckets.Values) { $total += $b.Cost }

    $breakdown = @(
        $buckets.GetEnumerator() | ForEach-Object {
            [PSCustomObject]@{
                Category   = $_.Key
                Cost       = [math]::Round($_.Value.Cost, 2)
                PctOfTotal = if ($total -gt 0) { [math]::Round(($_.Value.Cost / $total) * 100, 1) } else { 0 }
                Quantity   = [math]::Round($_.Value.Qty, 2)
                Meters     = @($_.Value.Meters)
            }
        } | Sort-Object Cost -Descending
    )

    $egressBucket = $buckets['Network egress']
    $egressQty = if ($egressBucket) { [math]::Round($egressBucket.Qty, 2) } else { 0 }

    $notes = @()
    if ($vm.Ambiguous) { $notes += "$($vm.MatchCount) VMs matched '$VmName'; showing the first. Pass resourceId or resourceGroup to disambiguate." }
    if ($subLevelEgress -gt 0) { $notes += "Excludes $([math]::Round($subLevelEgress,2)) $currency of bandwidth billed at subscription scope (no resource ID, not attributable to one VM)." }
    if (-not $fromHub) { $notes += 'Egress quantity (GB) is exact only on the FinOps Hub path; call with dataSource=hub when an export exists.' }

    return [PSCustomObject]@{
        HasData           = ($breakdown.Count -gt 0)
        VmName            = $vm.Name
        ResourceId        = $vm.Id
        ResourceGroup     = $vm.ResourceGroup
        SubscriptionId    = $vm.SubscriptionId
        Location          = $vm.Location
        VmSize            = $vm.VmSize
        Currency          = $currency
        Period            = 'MonthToDate'
        Source            = $source
        TotalCost         = [math]::Round($total, 2)
        EgressGb          = $egressQty
        Breakdown         = $breakdown
        ResourcesIncluded = @($vm.Associated)
        Note              = if ($notes.Count -gt 0) { $notes -join ' ' } else { 'Full VM solution cost: compute + disks + network + extensions, month-to-date.' }
    }
}
