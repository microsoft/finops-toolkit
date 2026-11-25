<#
.SYNOPSIS
    Compares the retail cost and the billed cost of virtual machines, using Cost Management cost details.

.DESCRIPTION
    Read-only. Azure Advisor estimates the savings of right-sizing and shutdown recommendations
    from retail prices and its own look-back period. This script returns, for each virtual
    machine, what was actually billed in a period: compute hours, retail cost, price sheet cost,
    billed cost, the discount against retail and the billed hourly rate. Use the output to
    restate the Advisor estimates at the rates and hours the customer is billed.

    The script requests a cost details report for each subscription (Cost Details API,
    generateCostDetailsReport), downloads the files and keeps the rows of the virtual machines.
    The request only generates a report file. It does not change anything in the environment.

    To work offline, pass files that were already downloaded or exported with -CostDetailsPath.

.PARAMETER SubscriptionIds
    Subscriptions to request cost details for. Required unless -CostDetailsPath is used.

.PARAMETER TenantId
    Optional. Tenant to connect to when there is no session for it.

.PARAMETER StartDate
    First day of the period. Default: 30 days ago.

.PARAMETER EndDate
    Last day of the period. Default: yesterday. The Cost Details API accepts up to one month per request.

.PARAMETER Metric
    ActualCost (default) or AmortizedCost. With ActualCost, usage covered by a reservation or a
    savings plan shows a cost of zero. Use AmortizedCost to see the commitment cost spread over the usage.

.PARAMETER VmListPath
    Optional. Text file with one resource ID per line (for example the resources in the Advisor
    right-sizing recommendations). If omitted, all virtual machines in the cost details are included.

.PARAMETER CostDetailsPath
    Optional. A cost details CSV file, or a folder with CSV files, to process instead of calling the API.

.PARAMETER OutputPath
    Folder for the output files. Default: current folder.

.PARAMETER TimeoutMinutes
    How long to wait for each cost details report. Default: 20.

.EXAMPLE
    ./Get-VmBilledRates.ps1 -SubscriptionIds '00000000-0000-0000-0000-000000000000' -VmListPath ./rightsizing-vms.txt

.EXAMPLE
    ./Get-VmBilledRates.ps1 -CostDetailsPath ./exports -Metric AmortizedCost

.NOTES
    Requires Az.Accounts, an active Connect-AzAccount session and access to cost data on each
    subscription (for example Cost Management Reader).
    Outputs:
      vm-billed-rates.csv       one row per virtual machine
      vm-billed-rates-raw.csv   the cost detail rows behind each virtual machine
      vm-billed-rates-log.txt   what happened, per subscription
    Downloaded files are kept in Temp/costdetails under the output folder and can be deleted afterwards.
#>
[CmdletBinding()]
param(
    [string[]]$SubscriptionIds,
    [string]$TenantId,
    [datetime]$StartDate = (Get-Date).Date.AddDays(-30),
    [datetime]$EndDate = (Get-Date).Date.AddDays(-1),
    [ValidateSet('ActualCost', 'AmortizedCost')]
    [string]$Metric = 'ActualCost',
    [string]$VmListPath,
    [string]$CostDetailsPath,
    [string]$OutputPath = (Get-Location).Path,
    [int]$TimeoutMinutes = 20
)

$ErrorActionPreference = 'Stop'
$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$log = New-Object System.Collections.Generic.List[string]

function Write-Status([string]$Message) {
    $line = "$(Get-Date -Format s)  $Message"
    Write-Host $line
    $log.Add($line)
}

# Cost details column names differ between agreement types, so each value is read from the first column that has it.
function Get-FirstNumber($Row, [string[]]$Names) {
    foreach ($n in $Names) {
        $v = $Row.$n
        if ($null -ne $v -and "$v" -ne '') {
            $d = 0.0
            if ([double]::TryParse("$v", [System.Globalization.NumberStyles]::Float, $invariant, [ref]$d)) { return $d }
        }
    }
    return $null
}

function Get-FirstString($Row, [string[]]$Names) {
    foreach ($n in $Names) { $v = $Row.$n; if ($null -ne $v -and "$v" -ne '') { return "$v" } }
    return ''
}

# "1 Hour" -> 1, "10 Hours" -> 10, "100 Hours" -> 100. Anything that is not hours returns $null.
function Get-HoursPerUnit([string]$UnitOfMeasure) {
    if ($UnitOfMeasure -match '^\s*([\d\.,]+)\s*Hours?\b') {
        return [double]::Parse(($Matches[1] -replace ',', ''), $invariant)
    }
    return $null
}

function Add-MatchingRows([string]$File, [string]$Subscription) {
    Import-Csv $File | ForEach-Object {
        $rid = (Get-FirstString $_ @('ResourceId', 'InstanceName', 'InstanceId')).ToLowerInvariant()
        $include = if ($vmSet) { $vmSet.Contains($rid) } else { $rid -match '/providers/microsoft\.compute/virtualmachines/[^/]+$' }
        if ($include) {
            $unit = Get-FirstString $_ @('UnitOfMeasure')
            $quantity = Get-FirstNumber $_ @('Quantity')
            $category = Get-FirstString $_ @('MeterCategory')
            $hoursPerUnit = Get-HoursPerUnit $unit
            $matched.Add([pscustomobject]@{
                SubscriptionId   = if ($Subscription) { $Subscription } else { Get-FirstString $_ @('SubscriptionId', 'SubscriptionGuid') }
                ResourceId       = $rid
                Date             = Get-FirstString $_ @('Date', 'UsageDate')
                MeterCategory    = $category
                MeterSubCategory = Get-FirstString $_ @('MeterSubCategory')
                MeterName        = Get-FirstString $_ @('MeterName')
                UnitOfMeasure    = $unit
                ChargeType       = Get-FirstString $_ @('ChargeType')
                PricingModel     = Get-FirstString $_ @('PricingModel')
                Quantity         = $quantity
                ComputeHours     = if ($category -eq 'Virtual Machines' -and $null -ne $hoursPerUnit -and $null -ne $quantity) { $quantity * $hoursPerUnit } else { $null }
                PayGPrice        = Get-FirstNumber $_ @('PayGPrice')
                UnitPrice        = Get-FirstNumber $_ @('UnitPrice')
                EffectivePrice   = Get-FirstNumber $_ @('EffectivePrice')
                Cost             = Get-FirstNumber $_ @('CostInBillingCurrency', 'Cost', 'CostInUsd')
                Currency         = Get-FirstString $_ @('BillingCurrency', 'BillingCurrencyCode')
            })
        }
    }
}

function Get-Sum($Rows, [scriptblock]$Value) {
    $sum = ($Rows | ForEach-Object { & $Value $_ } | Where-Object { $null -ne $_ } | Measure-Object -Sum).Sum
    if ($null -eq $sum) { return 0.0 }
    return [double]$sum
}

# --- Validation ----------------------------------------------------------------------------
if (-not $CostDetailsPath -and -not $SubscriptionIds) { throw 'Provide -SubscriptionIds, or -CostDetailsPath to process files that were already downloaded.' }
if (-not $CostDetailsPath) {
    if ($EndDate -lt $StartDate) { throw 'EndDate is before StartDate.' }
    if (($EndDate - $StartDate).TotalDays -gt 31) { throw 'The Cost Details API accepts up to one month per request. Use a shorter period or run the script once per month.' }
}
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null }

$vmSet = $null
if ($VmListPath) {
    $vmSet = New-Object 'System.Collections.Generic.HashSet[string]'
    Get-Content $VmListPath | Where-Object { $_.Trim() } | ForEach-Object { [void]$vmSet.Add($_.Trim().ToLowerInvariant()) }
    Write-Status "Resources in the list: $($vmSet.Count)"
} else {
    Write-Status 'No list provided. Including all virtual machines found in the cost details.'
}

$matched = New-Object System.Collections.Generic.List[object]

# --- Collect -------------------------------------------------------------------------------
if ($CostDetailsPath) {
    $files = if (Test-Path $CostDetailsPath -PathType Container) { Get-ChildItem $CostDetailsPath -Filter *.csv -File } else { Get-Item $CostDetailsPath }
    foreach ($f in @($files)) {
        Write-Status "Reading $($f.Name)"
        Add-MatchingRows -File $f.FullName -Subscription ''
    }
} else {
    $context = Get-AzContext
    if (-not $context -or ($TenantId -and $context.Tenant.Id -ne $TenantId)) {
        if (-not $TenantId) { throw 'No Azure session. Run Connect-AzAccount first, or pass -TenantId.' }
        Write-Status "Connecting to tenant $TenantId"
        Connect-AzAccount -Tenant $TenantId | Out-Null
    }

    $tempDir = Join-Path $OutputPath 'Temp/costdetails'
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    $start = $StartDate.ToString('yyyy-MM-dd')
    $end = $EndDate.ToString('yyyy-MM-dd')

    foreach ($sub in $SubscriptionIds) {
        Write-Status "[$sub] Requesting cost details report ($start to $end, $Metric)"
        $body = @{ metric = $Metric; timePeriod = @{ start = $start; end = $end } } | ConvertTo-Json
        $path = "/subscriptions/$sub/providers/Microsoft.CostManagement/generateCostDetailsReport?api-version=2023-11-01"
        try {
            $r = Invoke-AzRestMethod -Method POST -Path $path -Payload $body
        } catch {
            Write-Status "[$sub] ERROR on request: $($_.Exception.Message)"; continue
        }

        $result = $null
        if ($r.StatusCode -eq 200) {
            $result = $r.Content | ConvertFrom-Json
        } elseif ($r.StatusCode -eq 202) {
            $location = $r.Headers.Location
            if ($location -is [array]) { $location = $location[0] }
            if ($location -is [uri]) { $location = $location.AbsoluteUri }
            if (-not $location) { Write-Status "[$sub] ERROR: 202 without Location header"; continue }
            $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
            do {
                Start-Sleep -Seconds 20
                $p = Invoke-AzRestMethod -Method GET -Uri $location
                $status = $null
                if ($p.Content) { $status = ($p.Content | ConvertFrom-Json).status }
                Write-Status "[$sub] Report status: HTTP $($p.StatusCode) $status"
            } while (($p.StatusCode -eq 202 -or $status -in @('InProgress', 'Queued')) -and (Get-Date) -lt $deadline)
            if ($p.StatusCode -ne 200) { Write-Status "[$sub] ERROR: report not ready. HTTP $($p.StatusCode) $($p.Content)"; continue }
            $result = $p.Content | ConvertFrom-Json
        } elseif ($r.StatusCode -eq 204) {
            Write-Status "[$sub] No cost data for the period"; continue
        } else {
            Write-Status "[$sub] ERROR: HTTP $($r.StatusCode) $($r.Content)"; continue
        }

        $blobs = @($result.manifest.blobs)
        if ($blobs.Count -eq 0) { Write-Status "[$sub] No data files returned (status: $($result.status))"; continue }
        Write-Status "[$sub] Files: $($blobs.Count)"

        $i = 0
        foreach ($b in $blobs) {
            $i++
            $file = Join-Path $tempDir "$sub-$i.csv"
            Invoke-WebRequest -Uri $b.blobLink -OutFile $file -UseBasicParsing
            Add-MatchingRows -File $file -Subscription $sub
        }
        Write-Status "[$sub] Matching rows so far: $($matched.Count)"
    }
}

# --- Per-VM summary ------------------------------------------------------------------------
$summary = $matched | Group-Object ResourceId | ForEach-Object {
    $rows = $_.Group
    $compute = @($rows | Where-Object { $null -ne $_.ComputeHours })
    $retail = Get-Sum $rows { param($x) if ($null -ne $x.Quantity -and $null -ne $x.PayGPrice) { $x.Quantity * $x.PayGPrice } }
    $sheet = Get-Sum $rows { param($x) if ($null -ne $x.Quantity -and $null -ne $x.UnitPrice) { $x.Quantity * $x.UnitPrice } }
    $billed = Get-Sum $rows { param($x) $x.Cost }
    $hours = Get-Sum $compute { param($x) $x.ComputeHours }
    $computeRetail = Get-Sum $compute { param($x) if ($null -ne $x.PayGPrice) { $x.Quantity * $x.PayGPrice } }
    $computeBilled = Get-Sum $compute { param($x) $x.Cost }
    [pscustomobject]@{
        ResourceId              = $_.Name
        SubscriptionId          = $rows[0].SubscriptionId
        Rows                    = $rows.Count
        PricingModels           = (($rows.PricingModel | Where-Object { $_ } | Sort-Object -Unique) -join ';')
        ComputeHours            = [math]::Round($hours, 2)
        RetailCost              = [math]::Round($retail, 2)
        PriceSheetCost          = [math]::Round($sheet, 2)
        BilledCost              = [math]::Round($billed, 2)
        DiscountVsRetailPct     = if ($retail -gt 0) { [math]::Round((1 - $billed / $retail) * 100, 1) } else { $null }
        RetailComputeHourlyRate = if ($hours -gt 0) { [math]::Round($computeRetail / $hours, 5) } else { $null }
        BilledComputeHourlyRate = if ($hours -gt 0) { [math]::Round($computeBilled / $hours, 5) } else { $null }
        Currency                = (($rows.Currency | Where-Object { $_ } | Sort-Object -Unique) -join ';')
    }
}
$summary = @($summary | Sort-Object BilledCost -Descending)

$summaryFile = Join-Path $OutputPath 'vm-billed-rates.csv'
$rawFile = Join-Path $OutputPath 'vm-billed-rates-raw.csv'
$logFile = Join-Path $OutputPath 'vm-billed-rates-log.txt'
$summary | Export-Csv $summaryFile -NoTypeInformation -Encoding utf8
$matched | Export-Csv $rawFile -NoTypeInformation -Encoding utf8

Write-Status "Virtual machines with cost rows: $($summary.Count)"
if ($vmSet) {
    $found = New-Object 'System.Collections.Generic.HashSet[string]'
    $summary | ForEach-Object { [void]$found.Add($_.ResourceId) }
    $notFound = @($vmSet | Where-Object { -not $found.Contains($_) })
    if ($notFound.Count -gt 0) {
        Write-Status "Resources in the list without cost rows: $($notFound.Count)"
        $notFound | ForEach-Object { Write-Status "  $_" }
    }
}
$log | Set-Content $logFile
Write-Host "`nDone. Files: $summaryFile, $rawFile, $logFile"
