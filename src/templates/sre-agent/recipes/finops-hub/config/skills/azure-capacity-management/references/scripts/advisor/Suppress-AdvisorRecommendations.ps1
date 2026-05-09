<#
.SYNOPSIS
    Suppress Azure Advisor recommendations across a management group.

.EXAMPLE
    .\Suppress-AdvisorRecommendations.ps1 -ManagementGroupId "ALZ" -Days 30 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ManagementGroupId,

    [string[]]$RecommendationTypeIds = @(
        "89515250-1243-43d1-b4e7-f9437cedffd8",
        "84b1a508-fc21-49da-979e-96894f1665df",
        "48eda464-1485-4dcf-a674-d0905df5054a"
    ),

    [ValidateRange(1,90)]
    [int]$Days = 30
)

$ErrorActionPreference = 'Stop'

# Advisor suppression TTL uses ISO 8601 duration and max 90 days.
function Get-TtlString([int]$days) {
    return "P{0}D" -f $days
}

# Get all subscriptions under management group
$mg = Get-AzManagementGroup -GroupId $ManagementGroupId -Expand -Recurse
$subs = @()
function Get-Subs($node) {
    if ($node.Children) {
        foreach ($c in $node.Children) {
            if ($c.Type -eq '/subscriptions') { $script:subs += @{Id=$c.Name; Name=$c.DisplayName} }
            else { Get-Subs $c }
        }
    }
}
Get-Subs $mg

Write-Host "Processing $($subs.Count) subscription(s)..." -ForegroundColor Cyan

$total = @{Found=0; Suppressed=0; Failed=0}
$ttl = Get-TtlString -days $Days

foreach ($sub in $subs) {
    Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue | Out-Null

    $recs = Get-AzAdvisorRecommendation -ErrorAction SilentlyContinue |
        Where-Object { $_.RecommendationTypeId -in $RecommendationTypeIds }

    if (-not $recs) { continue }

    $total.Found += $recs.Count
    Write-Host "[$($sub.Name)] Found $($recs.Count)" -ForegroundColor Yellow

    foreach ($rec in $recs) {
        if ($WhatIfPreference) {
            Write-Host "  WhatIf: $($rec.ShortDescriptionProblem)" -ForegroundColor Gray
            continue
        }

        $resourceUri = $rec.Id.Substring(0, $rec.Id.IndexOf("/providers/Microsoft.Advisor"))
        $recId = ($rec.Id -split '/recommendations/')[-1]
        $suppressionId = [Guid]::NewGuid()
        $uri = "https://management.azure.com$resourceUri/providers/Microsoft.Advisor/recommendations/$recId/suppressions/$suppressionId?api-version=2023-01-01"

        $body = @{properties=@{ttl=$ttl}} | ConvertTo-Json
        $resp = Invoke-AzRestMethod -Method PUT -Uri $uri -Payload $body

        if ($resp.StatusCode -in 200,201) { $total.Suppressed++ }
        else { $total.Failed++; Write-Warning "Failed ($($resp.StatusCode)): $($rec.ShortDescriptionProblem)" }
    }
}

Write-Host "`nFound: $($total.Found) | Suppressed: $($total.Suppressed) | Failed: $($total.Failed)" -ForegroundColor Cyan
