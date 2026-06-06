###########################################################################
# GET-AHBVMSAVINGSRATIO.PS1
# AZURE FINOPS MULTITOOL - Per-SKU Azure Hybrid Benefit Savings Ratio
###########################################################################
# Purpose: Compute the real Azure Hybrid Benefit savings for a VM size by
#          comparing the Windows and Linux pay-as-you-go rates from the
#          Azure Retail Prices API. AHB removes the Windows Server license
#          premium, so the post-AHB cost is the Linux-equivalent rate.
#
# Description:
# 1. Queries the public Retail Prices API for the SKU + region
# 2. Picks the Windows and Linux Consumption meters (skips Spot / Low Priority)
# 3. Get-AhbVmRates returns Windows/Linux rates, the remaining-cost ratio,
#    and the hourly Windows license premium (Windows rate - Linux rate)
# 4. Get-AhbVmSavingsRatio returns just the ratio (falls back to 0.6 / ~40% off)
# 5. Caches per SKU+region
#
# The values are size-specific: small / burstable SKUs carry a different Windows
# license premium than a flat 40% assumption.
#
# -- Parameters ----------------------------------------------------
# VmSize             ARM SKU name, e.g. Standard_D4as_v6
# Region             ARM region name, e.g. eastus
#
# Prerequisites:
# - Outbound HTTPS to prices.azure.com (no auth required)
#
# Usage: Get-AhbVmRates -VmSize 'Standard_D4as_v6' -Region 'eastus'
###########################################################################

function Get-AhbVmRates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VmSize,
        [Parameter(Mandatory)][string]$Region
    )

    if (-not $script:AhbRateCache) { $script:AhbRateCache = @{} }
    if ([string]::IsNullOrWhiteSpace($VmSize) -or [string]::IsNullOrWhiteSpace($Region)) { return $null }

    $key = "$VmSize|$Region".ToLowerInvariant()
    if ($script:AhbRateCache.ContainsKey($key)) { return $script:AhbRateCache[$key] }

    $result = $null
    try {
        $filter = "armRegionName eq '$Region' and armSkuName eq '$VmSize' and priceType eq 'Consumption' and serviceName eq 'Virtual Machines'"
        $url = "https://prices.azure.com/api/retail/prices?`$filter=$([uri]::EscapeDataString($filter))"
        $resp = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 20
        $items = @($resp.Items) | Where-Object {
            $_.unitPrice -gt 0 -and
            $_.skuName -notmatch 'Spot|Low Priority' -and
            $_.meterName -notmatch 'Spot|Low Priority'
        }
        $win = $items | Where-Object { $_.productName -match 'Windows' } | Select-Object -First 1
        $lin = $items | Where-Object { $_.productName -notmatch 'Windows' } | Select-Object -First 1
        if ($win -and $lin -and [double]$win.unitPrice -gt 0) {
            $w = [double]$win.unitPrice
            $l = [double]$lin.unitPrice
            if ($l -gt 0 -and $l -lt $w) {
                $result = [PSCustomObject]@{
                    WindowsRate   = $w
                    LinuxRate     = $l
                    Ratio         = [math]::Round($l / $w, 4)
                    HourlyPremium = [math]::Round($w - $l, 5)
                }
            }
        }
    } catch {
        Write-Warning "  AHB rate lookup failed for ${VmSize}/${Region}: $($_.Exception.Message)"
    }

    $script:AhbRateCache[$key] = $result
    return $result
}

function Get-AhbVmSavingsRatio {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VmSize,
        [Parameter(Mandatory)][string]$Region
    )

    $rates = Get-AhbVmRates -VmSize $VmSize -Region $Region
    if ($rates) { return $rates.Ratio }
    return 0.6  # ~40% off fallback when live rates are unavailable
}
