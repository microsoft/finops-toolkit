###########################################################################
# GET-TAGRECOMMENDATIONS.PS1
# AZURE FINOPS MULTITOOL - Tag Recommendations (MS Best Practices)
###########################################################################
# Purpose: Compare the customer's actual tags against Microsoft's
#          recommended tagging strategy from the Cloud Adoption Framework.
#
# Reference:
#   https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging
#   https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/govern/guides/standard/prescriptive-guidance#resource-tagging
###########################################################################

function Get-TagRecommendations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ExistingTags,   # Keys = tag names currently in use

        [hashtable]$TagLocations = @{}  # Keys = tag names, Values = list of "Sub / RG" strings
    )

    # Microsoft Cloud Adoption Framework recommended tags for FinOps allocation
    # These 7 tags map directly to CAF categories and FinOps allocation needs
    $recommendedTags = @(
        [PSCustomObject]@{
            TagName     = 'CostCenter'
            Category    = 'Accounting'
            Purpose     = 'Financial allocation - maps resources to internal cost centers for chargeback/showback'
            Pillar      = 'Understand'
            Priority    = 'Required'
            Weight      = 3
            Example     = 'CostCenter: CC-12345'
            Reference   = 'https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging#minimum-suggested-tags'
        }
        [PSCustomObject]@{
            TagName     = 'BusinessUnit'
            Category    = 'Ownership'
            Purpose     = 'Org-level chargeback - enables showback/chargeback at department level'
            Pillar      = 'Understand'
            Priority    = 'Required'
            Weight      = 3
            Example     = 'BusinessUnit: Finance | Engineering | Marketing'
            Reference   = 'https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging#minimum-suggested-tags'
        }
        [PSCustomObject]@{
            TagName     = 'ApplicationName'
            Category    = 'Functional'
            Purpose     = 'Product/service cost mapping - groups resources by the application they support'
            Pillar      = 'Understand'
            Priority    = 'Required'
            Weight      = 2
            Example     = 'ApplicationName: HRPortal | ERP | WebFrontend'
            Reference   = 'https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging#minimum-suggested-tags'
        }
        [PSCustomObject]@{
            TagName     = 'WorkloadName'
            Category    = 'Functional'
            Purpose     = 'Workload attribution - identifies the workload a resource belongs to'
            Pillar      = 'Understand'
            Priority    = 'Required'
            Weight      = 1
            Example     = 'WorkloadName: PaymentProcessing | DataPipeline'
            Reference   = 'https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging#minimum-suggested-tags'
        }
        [PSCustomObject]@{
            TagName     = 'OpsTeam'
            Category    = 'Ownership'
            Purpose     = 'Accountability for spend - which team owns and operates the resource'
            Pillar      = 'Understand'
            Priority    = 'Required'
            Weight      = 1
            Example     = 'OpsTeam: Platform-Infra | App-TeamA | SRE'
            Reference   = 'https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging#minimum-suggested-tags'
        }
        [PSCustomObject]@{
            TagName     = 'Criticality'
            Category    = 'Classification'
            Purpose     = 'Prioritization of spend - business impact level drives optimization boundaries'
            Pillar      = 'Optimize'
            Priority    = 'Required'
            Weight      = 1
            Example     = 'Criticality: Mission-Critical | Business-Critical | Low'
            Reference   = 'https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging#minimum-suggested-tags'
        }
        [PSCustomObject]@{
            TagName     = 'DataClassification'
            Category    = 'Classification'
            Purpose     = 'Compliance-driven allocation - data sensitivity determines governance requirements'
            Pillar      = 'Understand'
            Priority    = 'Required'
            Weight      = 1
            Example     = 'DataClassification: Confidential | Public | Internal'
            Reference   = 'https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging#minimum-suggested-tags'
        }
    )

    # Check which recommended tags are present / missing
    $existingNames = $ExistingTags.Keys | ForEach-Object { $_.ToLower() }

    $analysis = foreach ($rec in $recommendedTags) {
        $found = $existingNames -contains $rec.TagName.ToLower()

        # Also check common variations
        $variations = switch ($rec.TagName) {
            'CostCenter'          { @('cost-center', 'costcenter', 'cost_center', 'cc') }
            'BusinessUnit'        { @('bu', 'businessunit', 'business-unit', 'department', 'dept') }
            'ApplicationName'     { @('applicationname', 'application', 'app', 'appname', 'app-name', 'workload') }
            'WorkloadName'        { @('workloadname', 'workload', 'workload-name', 'workload_name') }
            'OpsTeam'             { @('opsteam', 'ops-team', 'ops_team', 'operationsteam', 'team', 'owner', 'technicalowner') }
            'Criticality'         { @('criticality', 'sla', 'tier', 'importance') }
            'DataClassification'  { @('dataclassification', 'data-classification', 'data_classification', 'classification') }
            default               { @() }
        }
        $foundVariation = $existingNames | Where-Object { $_ -in $variations } | Select-Object -First 1

        $status = if ($found) { 'Present' }
                  elseif ($foundVariation) { "Variation found: $foundVariation" }
                  else { 'Missing' }

        # Build location string from TagLocations
        $matchedName = if ($found) { $rec.TagName }
                       elseif ($foundVariation) { $foundVariation }
                       else { $null }

        # Resolve original-case tag name from ExistingTags for accurate removal
        $actualTagName = $null
        if ($matchedName) {
            $actualTagName = $ExistingTags.Keys | Where-Object { $_.ToLower() -eq $matchedName.ToLower() } | Select-Object -First 1
            if (-not $actualTagName) { $actualTagName = $matchedName }
        }

        $locationStr = ''
        if ($matchedName) {
            # Case-insensitive lookup in TagLocations hashtable
            $locKey = $TagLocations.Keys | Where-Object { $_.ToLower() -eq $matchedName.ToLower() } | Select-Object -First 1
            if ($locKey -and $TagLocations[$locKey]) {
                $locs = @($TagLocations[$locKey])
                if ($locs.Count -le 3) {
                    $locationStr = $locs -join '; '
                } else {
                    $locationStr = ($locs[0..2] -join '; ') + " (+$($locs.Count - 3) more)"
                }
            }
        }

        [PSCustomObject]@{
            TagName       = $rec.TagName
            ActualTagName = $actualTagName
            Status        = $status
            Priority      = $rec.Priority
            Pillar    = $rec.Pillar
            Purpose   = $rec.Purpose
            Location  = $locationStr
            Example   = $rec.Example
            Reference = $rec.Reference
        }
    }

    $missingRequired    = @($analysis | Where-Object { $_.Status -eq 'Missing' -and $_.Priority -eq 'Required' })
    $missingRecommended = @($analysis | Where-Object { $_.Status -eq 'Missing' -and $_.Priority -eq 'Recommended' })
    $present            = @($analysis | Where-Object { $_.Status -ne 'Missing' })

    return [PSCustomObject]@{
        Analysis            = $analysis
        MissingRequired     = $missingRequired
        MissingRecommended  = $missingRecommended
        Present             = $present
        CompliancePercent   = [math]::Round(($present.Count / $analysis.Count) * 100, 0)
    }
}
