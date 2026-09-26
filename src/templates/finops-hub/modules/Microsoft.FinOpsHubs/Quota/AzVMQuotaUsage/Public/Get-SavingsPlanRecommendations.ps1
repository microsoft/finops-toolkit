# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

<#
.SYNOPSIS
    Writes Cost Management savings plan recommendations to CSV files.

.DESCRIPTION
    Gets the 60-day savings plan recommendations for the 1-year and 3-year terms of each billing scope.
    Writes one CSV file for each billing scope, recommendation scope, and term.
    Writes a warning when no billing scope is supplied, and when a request fails, skips only that billing scope and term.

.PARAMETER AccessToken
    ARM bearer token with read access to the billing scopes.

.PARAMETER TenantId
    Entra tenant ID written to each recommendation.

.PARAMETER BillingScope
    Billing account or billing profile resource IDs.

.PARAMETER SettingsHash
    SHA256 of the settings file from which the caller read BillingScope.

.PARAMETER SettingsETag
    ETag of that settings file.

.PARAMETER RunId
    Run ID written to each recommendation and used in the blob names.

.PARAMETER OutputDirectory
    Local directory for the savings-plan/<RunId>/<Partition>/SavingsPlan.csv files.

.OUTPUTS
    One object for each file with CsvPath, BlobName, Partition, Rows, and Scope.
#>
function Get-SavingsPlanRecommendations {
    param (
        [Parameter(Mandatory)]
        [securestring]$AccessToken,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [ValidatePattern('^/providers/Microsoft\.Billing/billingAccounts/[^/]+(/billingProfiles/[^/]+)?$')]
        [string[]]$BillingScope,

        [Parameter(Mandatory)]
        [string]$SettingsHash,

        [Parameter(Mandatory)]
        [string]$SettingsETag,

        [Parameter(Mandatory)]
        [string]$RunId,

        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )

    $ErrorActionPreference = 'Stop'
    if (-not $BillingScope) {
        Write-Warning 'No billing account or billing profile scope was supplied.'
        return
    }
    $started = [datetime]::UtcNow
    $columns = @(
        'ProviderName', 'ResourceId', 'ResourceName', 'ResourceType', 'SubAccountId', 'SubAccountName',
        'x_EffectiveCostBefore', 'x_EffectiveCostAfter', 'x_EffectiveCostSavings',
        'x_RecommendationId', 'x_RecommendationCategory', 'x_RecommendationDate', 'x_RecommendationDetails',
        'x_SourceName', 'x_SourceProvider', 'x_SourceType', 'x_SourceVersion'
    )
    $stringColumns = @($columns | Where-Object { $_ -notin @('x_EffectiveCostBefore', 'x_EffectiveCostAfter', 'x_EffectiveCostSavings') })

    foreach ($term in 'P1Y', 'P3Y') {
        foreach ($scope in $BillingScope | Select-Object -Unique) {
            try {
                $filter = [uri]::EscapeDataString("properties/lookBackPeriod eq 'Last60Days' and properties/term eq '$term'")
                $path = "$scope/providers/Microsoft.CostManagement/benefitRecommendations?api-version=2026-06-01&`$filter=$filter&`$expand=properties/usage,properties/allRecommendationDetails"
                $data = @(Get-ArmCollection -Path $path -AccessToken $AccessToken)
                foreach ($group in $data | Group-Object { $_.properties.scope }) {
                    if (-not $group.Name) { throw "Savings plan recommendation has no scope: $path" }
                    $partition = (Get-SnapshotHash $scope.ToLowerInvariant()) + "-$($group.Name.ToLowerInvariant())-60d-$($term.ToLowerInvariant())"
                    $idHashes = @($group.Group | ForEach-Object { Get-SnapshotHash $_.id.ToLowerInvariant() } | Sort-Object)
                    $snapshotHash = Get-SnapshotHash ($idHashes -join "`n")
                    $recommendations = @(foreach ($raw in $group.Group) {
                            $properties = $raw.properties
                            $subAccountId = ''
                            if ($properties.scope -eq 'Single') {
                                if (-not $properties.subscriptionId) { throw "Single-scope recommendation $($raw.id) has no subscription ID." }
                                $subAccountId = "/subscriptions/$($properties.subscriptionId)"
                            }
                            $details = [ordered]@{
                                x_ArmSkuName               = $properties.armSkuName
                                x_Term                     = $properties.term
                                x_Scope                    = $properties.scope
                                x_LookBackPeriod           = $properties.lookBackPeriod
                                x_CurrencyCode             = $properties.currencyCode
                                x_CommitmentGranularity    = $properties.commitmentGranularity
                                x_FirstConsumptionDate     = $properties.firstConsumptionDate
                                x_LastConsumptionDate      = $properties.lastConsumptionDate
                                x_TotalHours               = $properties.totalHours
                                x_RecommendationDetails    = $properties.recommendationDetails
                                x_AllRecommendationDetails = $properties.allRecommendationDetails.value
                                x_Usage                    = $properties.usage
                                x_Raw                      = $raw
                                x_CollectionScope          = $scope
                                x_SettingsHash             = $SettingsHash
                                x_SettingsETag             = $SettingsETag
                                x_TenantId                 = $TenantId
                                x_RunId                    = $RunId
                                x_Partition                = $partition
                                x_SnapshotRowCount         = $group.Count
                                x_SnapshotIdHash           = $snapshotHash
                            }
                            [pscustomobject]@{
                                ProviderName            = 'Microsoft'
                                ResourceId              = if ($subAccountId) { $subAccountId } else { $scope }
                                ResourceName            = ''; ResourceType = ''; SubAccountId = $subAccountId; SubAccountName = ''
                                x_EffectiveCostBefore   = $properties.costWithoutBenefit
                                x_EffectiveCostAfter    = $properties.recommendationDetails.totalCost
                                x_EffectiveCostSavings  = $properties.recommendationDetails.savingsAmount
                                x_RecommendationId      = $raw.id; x_RecommendationCategory = 'Cost'
                                x_RecommendationDate    = $started.ToString('o')
                                x_RecommendationDetails = ConvertTo-Json -InputObject $details -Depth 100 -Compress
                                x_SourceName            = 'Cost Management'; x_SourceProvider = 'Microsoft'
                                x_SourceType            = 'SavingsPlan'; x_SourceVersion = '2026-06-01'
                            }
                        })
                    $blobName = "savings-plan/$RunId/$partition/SavingsPlan.csv"
                    $csvPath = Join-Path $OutputDirectory $blobName
                    $null = New-Item -ItemType Directory -Path (Split-Path $csvPath) -Force
                    $recommendations | Select-Object $columns | ConvertTo-Csv -NoTypeInformation -QuoteFields $stringColumns |
                        Set-Content -LiteralPath $csvPath -Encoding utf8NoBOM
                    [pscustomobject]@{ CsvPath = $csvPath; BlobName = $blobName; Partition = $partition; Rows = $recommendations.Count; Scope = $scope }
                }
            }
            catch {
                Write-Warning "Failed Querying: $scope - $term - $($_.Exception.Message)"
            }
        }
    }
}
