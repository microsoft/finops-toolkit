###########################################################################
# NEW-POWERBITEMPLATE.PS1
# POWER BI TEMPLATE GENERATOR (GUI-FREE)
###########################################################################
# Purpose: Build a Power BI template (.pbit) from FinOps scan data.
# Author:  Zac Larsen
# Date:    Created for FinOps Toolkit integration
#
# Description:
# Headless, dependency-free generator shared by the GUI and the MCP
# server. Given a scan-data hashtable (the same shape the GUI keeps in
# $script:scanData) it:
# 1. Writes one curated CSV per scan section into the output folder.
# 2. Clones gui\skeleton.pbit and injects a generated DataModelSchema so
#    the report's pages bind to the exported tables.
# 3. Returns the full path to the generated FinOps-Report.pbit.
#
# This function performs NO UI work: no WPF, no MessageBox, no folder
# dialogs. Errors are thrown so callers can surface them however they
# like. The GUI wraps it with dialogs; the MCP server calls it directly.
#
# ── Parameters ──────────────────────────────────────────────────
# ScanData       Hashtable of scan results (Auth, Costs, ResourceCosts,
#                Tags, TagRecs, PolicyInv, PolicyRecs, Budgets, Orphans,
#                CostByTag, CostTrend, Commitments, AHB, Optimization,
#                Reservations, Savings).
# OutputDir      Folder to write CSVs and the .pbit into. Created if missing.
# SkeletonPath   Optional path to skeleton.pbit. Defaults to the gui folder
#                next to the module directory.
# ScorecardRows  Optional pre-computed scorecard rows (GUI supplies these).
#
# Prerequisites:
# - PowerShell 7+
# - gui\skeleton.pbit present alongside the module folder
#
# Usage: New-PowerBITemplate -ScanData $d -OutputDir 'C:\out\FinOps'
###########################################################################

function New-PowerBITemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ScanData,

        [Parameter(Mandatory)]
        [string]$OutputDir,

        [string]$SkeletonPath,

        [object[]]$ScorecardRows
    )

    $d = $ScanData
    if (-not $d -or -not $d.Auth) {
        throw 'ScanData is empty or missing Auth/Subscriptions. Run a scan first.'
    }

    if (-not (Test-Path $OutputDir)) {
        New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
    }

    $fileCount = 0

    # Helper: safe CSV export (skips empty sets)
    $writeCsv = {
        param([string]$Name, [object[]]$Rows)
        if ($Rows -and $Rows.Count -gt 0) {
            $Rows | Export-Csv -Path (Join-Path $OutputDir "$Name.csv") -NoTypeInformation -Encoding UTF8
            $script:pbiFileCount++
        }
    }
    $script:pbiFileCount = 0

    # 1. Subscription Costs
    $subRows = @()
    foreach ($sub in $d.Auth.Subscriptions) {
        $c = if ($d.Costs -and $d.Costs.ContainsKey($sub.Id)) { $d.Costs[$sub.Id] } else { @{ Actual = 0; Forecast = 0; Currency = 'USD' } }
        $subRows += [PSCustomObject]@{
            Subscription   = $sub.Name
            SubscriptionId = $sub.Id
            ActualMTD      = [math]::Round($c.Actual, 2)
            Forecast       = [math]::Round($c.Forecast, 2)
            Currency       = $c.Currency
        }
    }
    & $writeCsv 'SubscriptionCosts' $subRows

    # 2. Resource Costs
    if ($d.ResourceCosts -and $d.ResourceCosts.Count -gt 0) {
        $rcRows = $d.ResourceCosts | ForEach-Object {
            [PSCustomObject]@{
                Subscription  = $_.Subscription
                ResourceGroup = $_.ResourceGroup
                ResourceType  = $_.ResourceType
                ResourcePath  = $_.ResourcePath
                ActualMTD     = [math]::Round($_.Actual, 2)
                Forecast      = [math]::Round($_.Forecast, 2)
                Currency      = $_.Currency
            }
        }
        & $writeCsv 'ResourceCosts' $rcRows
    }

    # 3. Tag Inventory
    if ($d.Tags -and $d.Tags.TagNames) {
        $tagRows = @()
        foreach ($tn in $d.Tags.TagNames.Keys) {
            $info = $d.Tags.TagNames[$tn]
            foreach ($v in $info.Values) {
                $tagRows += [PSCustomObject]@{
                    TagName       = $tn
                    TagValue      = $v.Value
                    ResourceCount = $v.ResourceCount
                }
            }
        }
        & $writeCsv 'TagInventory' $tagRows
    }

    # 4. Tag Recommendations
    if ($d.TagRecs -and $d.TagRecs.Analysis) {
        $trRows = $d.TagRecs.Analysis | ForEach-Object {
            [PSCustomObject]@{
                TagName  = $_.TagName
                Status   = $_.Status
                Priority = $_.Priority
                Pillar   = $_.Pillar
                Purpose  = $_.Purpose
            }
        }
        & $writeCsv 'TagRecommendations' $trRows
    }

    # 5. Policy Inventory
    if ($d.PolicyInv -and $d.PolicyInv.Assignments) {
        $piRows = $d.PolicyInv.Assignments | ForEach-Object {
            [PSCustomObject]@{
                AssignmentName  = $_.AssignmentName
                PolicyDefId     = $_.PolicyDefId
                Scope           = $_.Scope
                Effect          = $_.Effect
                EnforcementMode = $_.EnforcementMode
                Origin          = $_.Origin
                Subscription    = $_.Subscription
            }
        }
        & $writeCsv 'PolicyInventory' $piRows
    }

    # 6. Policy Recommendations
    if ($d.PolicyRecs -and $d.PolicyRecs.Analysis) {
        $prRows = $d.PolicyRecs.Analysis | ForEach-Object {
            [PSCustomObject]@{
                DisplayName   = $_.DisplayName
                Category      = $_.Category
                Pillar        = $_.Pillar
                Priority      = $_.Priority
                DefaultEffect = $_.DefaultEffect
                Purpose       = $_.Purpose
                Status        = if ($d.PolicyInv -and $d.PolicyInv.Assignments -and ($_.PolicyDefId -in ($d.PolicyInv.Assignments.PolicyDefId))) { 'Assigned' } else { 'Missing' }
            }
        }
        & $writeCsv 'PolicyRecommendations' $prRows
    }

    # 7. Budgets
    if ($d.Budgets -and $d.Budgets.Budgets) {
        $bRows = $d.Budgets.Budgets | ForEach-Object {
            [PSCustomObject]@{
                Subscription   = $_.Subscription
                SubscriptionId = $_.SubscriptionId
                BudgetName     = $_.BudgetName
                Amount         = $_.Amount
                TimeGrain      = $_.TimeGrain
                ActualSpend    = [math]::Round($_.ActualSpend, 2)
                Forecast       = [math]::Round($_.Forecast, 2)
                PercentUsed    = [math]::Round($_.PctUsed, 1)
                Risk           = $_.Risk
                Currency       = $_.Currency
            }
        }
        & $writeCsv 'Budgets' $bRows
    }

    # 8. Orphaned Resources
    if ($d.Orphans -and $d.Orphans.Orphans) {
        $oRows = $d.Orphans.Orphans | ForEach-Object {
            [PSCustomObject]@{
                Category       = $_.Category
                ResourceName   = $_.ResourceName
                ResourceGroup  = $_.ResourceGroup
                SubscriptionId = $_.SubscriptionId
                Location       = $_.Location
                Detail         = $_.Detail
                Impact         = $_.Impact
            }
        }
        & $writeCsv 'OrphanedResources' $oRows
    }

    # 9. Cost by Tag
    if ($d.CostByTag -and $d.CostByTag.CostByTag) {
        $ctRows = @()
        foreach ($tagKey in $d.CostByTag.CostByTag.Keys) {
            foreach ($entry in $d.CostByTag.CostByTag[$tagKey]) {
                $ctRows += [PSCustomObject]@{
                    TagName  = $tagKey
                    TagValue = $entry.TagValue
                    Cost     = [math]::Round($entry.Cost, 2)
                    Currency = $entry.Currency
                }
            }
        }
        & $writeCsv 'CostByTag' $ctRows
    }

    # 10. Cost Trend
    if ($d.CostTrend -and $d.CostTrend.HasData -and $d.CostTrend.Months) {
        $tRows = $d.CostTrend.Months | ForEach-Object {
            [PSCustomObject]@{
                Month    = $_.Month
                Cost     = [math]::Round($_.Cost, 2)
                Currency = $_.Currency
            }
        }
        & $writeCsv 'CostTrend' $tRows
    }

    # 11. Commitment Utilization
    if ($d.Commitments -and $d.Commitments.HasData) {
        $cmRows = @()
        if ($d.Commitments.Reservations) {
            $cmRows += $d.Commitments.Reservations | ForEach-Object {
                [PSCustomObject]@{
                    Type           = 'Reservation'
                    Id             = $_.ReservationId
                    SkuName        = $_.SkuName
                    AvgUtilization = [math]::Round($_.AvgUtilization, 1)
                    MinUtilization = [math]::Round($_.MinUtilization, 1)
                    MaxUtilization = [math]::Round($_.MaxUtilization, 1)
                    ReservedHours  = $_.ReservedHours
                    UsedHours      = $_.UsedHours
                }
            }
        }
        if ($d.Commitments.SavingsPlans) {
            $cmRows += $d.Commitments.SavingsPlans | ForEach-Object {
                [PSCustomObject]@{
                    Type           = 'SavingsPlan'
                    Id             = $_.BenefitId
                    SkuName        = ''
                    AvgUtilization = [math]::Round($_.AvgUtilization, 1)
                    MinUtilization = 0
                    MaxUtilization = 0
                    ReservedHours  = 0
                    UsedHours      = 0
                }
            }
        }
        & $writeCsv 'CommitmentUtilization' $cmRows
    }

    # 12. AHB Opportunities
    if ($d.AHB -and $d.AHB.TotalOpportunities -gt 0) {
        $ahbRows = @()
        foreach ($prop in @('WindowsVMs', 'SQLVMs', 'SQLDatabases')) {
            if ($d.AHB.$prop) {
                $ahbRows += $d.AHB.$prop | ForEach-Object {
                    [PSCustomObject]@{
                        Category       = $prop
                        ResourceName   = $_.name
                        ResourceGroup  = $_.resourceGroup
                        SubscriptionId = $_.subscriptionId
                        Location       = $_.location
                    }
                }
            }
        }
        & $writeCsv 'AHBOpportunities' $ahbRows
    }

    # 13. Optimization / Advisor Recommendations
    if ($d.Optimization -and $d.Optimization.Recommendations) {
        $optRows = $d.Optimization.Recommendations | ForEach-Object {
            [PSCustomObject]@{
                Subscription  = $_.Subscription
                Category      = $_.Category
                Impact        = $_.Impact
                Problem       = $_.Problem
                Solution      = $_.Solution
                ResourceType  = $_.ResourceType
                ResourceName  = $_.ResourceName
                AnnualSavings = if ($_.AnnualSavings) { [math]::Round($_.AnnualSavings, 2) } else { '' }
                Currency      = $_.Currency
            }
        }
        & $writeCsv 'OptimizationAdvice' $optRows
    }

    # 14. Reservation Recommendations
    if ($d.Reservations) {
        $resRows = @()
        if ($d.Reservations.AdvisorRecommendations) {
            $resRows += $d.Reservations.AdvisorRecommendations | ForEach-Object {
                [PSCustomObject]@{
                    Source        = 'Advisor'
                    Subscription  = $_.Subscription
                    ResourceType  = $_.ResourceType
                    Impact        = $_.Impact
                    Problem       = $_.Problem
                    AnnualSavings = if ($_.AnnualSavings) { [math]::Round($_.AnnualSavings, 2) } else { '' }
                    Term          = $_.Term
                    Currency      = $_.Currency
                }
            }
        }
        if ($d.Reservations.ReservationRecommendations) {
            $resRows += $d.Reservations.ReservationRecommendations | ForEach-Object {
                [PSCustomObject]@{
                    Source        = 'ReservationAPI'
                    Subscription  = ''
                    ResourceType  = $_.ResourceType
                    Impact        = ''
                    Problem       = "Buy $($_.RecommendedQty)x $($_.SKU) ($($_.Term))"
                    AnnualSavings = if ($_.NetSavings) { [math]::Round($_.NetSavings, 2) } else { '' }
                    Term          = $_.Term
                    Currency      = ''
                }
            }
        }
        & $writeCsv 'ReservationAdvice' $resRows
    }

    # 15. Savings Realized
    if ($d.Savings -and $d.Savings.HasData -and $d.Savings.Details) {
        $sRows = $d.Savings.Details | ForEach-Object {
            [PSCustomObject]@{
                Subscription = $_.Subscription
                Category     = $_.Category
                Amount       = [math]::Round($_.Amount, 2)
                Type         = $_.Type
            }
        }
        & $writeCsv 'SavingsRealized' $sRows
    }

    # 16. Scorecard (caller-supplied, GUI only)
    if ($ScorecardRows -and $ScorecardRows.Count -gt 0) {
        & $writeCsv 'Scorecard' @($ScorecardRows)
    }

    # ================================================================
    # Generate Power BI Template (.pbit)
    # ================================================================
    Add-Type -AssemblyName System.IO.Compression

    $csvFiles = Get-ChildItem -Path $OutputDir -Filter '*.csv'
    if ($csvFiles.Count -eq 0) {
        throw 'No data available to export. The scan produced no rows.'
    }
    $numericCols = @('ActualMTD', 'Forecast', 'Cost', 'Amount', 'ActualSpend', 'PercentUsed', 'AnnualSavings', 'AvgUtilization', 'MinUtilization', 'MaxUtilization', 'ReservedHours', 'UsedHours', 'ResourceCount')
    $exportDirEscaped = $OutputDir -replace '\\', '\\\\'

    # Build DataModelSchema JSON manually to avoid ConvertTo-Json issues
    $sb = [System.Text.StringBuilder]::new(8192)
    [void]$sb.Append('{"name":"Model","compatibilityLevel":1550,"model":{"culture":"en-US","dataAccessOptions":{"legacyRedirects":true,"returnErrorValuesAsNull":true},"defaultPowerBIDataSourceVersion":"powerBI_V3","sourceQueryCulture":"en-US","tables":[')

    # CsvFolderPath parameter table
    $paramGuid = [guid]::NewGuid().ToString()
    $paramColGuid = [guid]::NewGuid().ToString()
    [void]$sb.Append('{"name":"CsvFolderPath","lineageTag":"' + $paramGuid + '","columns":[{"name":"CsvFolderPath","dataType":"string","isHidden":true,"sourceColumn":"CsvFolderPath","lineageTag":"' + $paramColGuid + '"}],"partitions":[{"name":"CsvFolderPath","mode":"import","source":{"type":"m","expression":["\"' + $exportDirEscaped + '\" meta [IsParameterQuery=true, Type=\"Text\", IsParameterQueryRequired=true]"]}}],"annotations":[{"name":"PBI_ResultType","value":"Text"},{"name":"PBI_NavigationStepName","value":"Navigation"}]}')

    # Data tables from CSVs
    foreach ($csv in $csvFiles) {
        $tblName = [System.IO.Path]::GetFileNameWithoutExtension($csv.Name)
        $headerLine = Get-Content $csv.FullName -First 1
        $headers = ($headerLine -replace '"', '') -split ','
        $tblGuid = [guid]::NewGuid().ToString()

        [void]$sb.Append(',{"name":"' + $tblName + '","lineageTag":"' + $tblGuid + '","columns":[')
        $colFragments = @()
        $typeCasts = @()
        foreach ($h in $headers) {
            $cGuid = [guid]::NewGuid().ToString()
            $isNum = $h -in $numericCols
            $dt = if ($isNum) { 'double' } else { 'string' }
            $sum = if ($isNum) { 'sum' } else { 'none' }
            $colFragments += '{"name":"' + $h + '","dataType":"' + $dt + '","sourceColumn":"' + $h + '","summarizeBy":"' + $sum + '","lineageTag":"' + $cGuid + '"}'
            if ($isNum) { $typeCasts += '{\"' + $h + '\", type number}' }
        }
        [void]$sb.Append($colFragments -join ',')
        [void]$sb.Append('],')

        # Partition with M expression
        $mExpr = @()
        $mExpr += '"let"'
        if ($typeCasts.Count -gt 0) {
            $mExpr += '"    Source = Csv.Document(File.Contents(CsvFolderPath & \"\\\\' + $tblName + '.csv\"), [Delimiter=\",\", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),"'
            $mExpr += '"    Headers = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),"'
            $castStr = $typeCasts -join ', '
            $mExpr += '"    Typed = Table.TransformColumnTypes(Headers, {' + $castStr + '})"'
            $mExpr += '"in"'
            $mExpr += '"    Typed"'
        }
        else {
            $mExpr += '"    Source = Csv.Document(File.Contents(CsvFolderPath & \"\\\\' + $tblName + '.csv\"), [Delimiter=\",\", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),"'
            $mExpr += '"    Headers = Table.PromoteHeaders(Source, [PromoteAllScalars=true])"'
            $mExpr += '"in"'
            $mExpr += '"    Headers"'
        }

        [void]$sb.Append('"partitions":[{"name":"' + $tblName + '","mode":"import","source":{"type":"m","expression":[' + ($mExpr -join ',') + ']}}]}')
    }

    [void]$sb.Append('],') # end tables

    # Relationships
    $tblNames = @('CsvFolderPath') + @($csvFiles | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) })
    $relFragments = @()
    $subIdTables = @('Budgets', 'OrphanedResources', 'AHBOpportunities')
    foreach ($ft in $subIdTables) {
        if ($ft -in $tblNames -and 'SubscriptionCosts' -in $tblNames) {
            $rGuid = [guid]::NewGuid().ToString()
            $relFragments += '{"name":"' + $rGuid + '","fromTable":"' + $ft + '","fromColumn":"SubscriptionId","toTable":"SubscriptionCosts","toColumn":"SubscriptionId"}'
        }
    }
    [void]$sb.Append('"relationships":[' + ($relFragments -join ',') + '],')
    [void]$sb.Append('"annotations":[{"name":"PBI_QueryGroup","value":"{}"},{"name":"PBIDesktopVersion","value":"2.138.0.0"}]}}')

    $modelJson = $sb.ToString()

    # Resolve skeleton .pbit (default: gui folder next to this module dir)
    if (-not $SkeletonPath) {
        $SkeletonPath = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'gui') 'skeleton.pbit'
    }
    if (-not (Test-Path $SkeletonPath)) {
        throw "skeleton.pbit not found at: $SkeletonPath"
    }

    $pbitPath = Join-Path $OutputDir 'FinOps-Report.pbit'
    Copy-Item $SkeletonPath $pbitPath -Force
    if ((Get-Item $pbitPath).Length -lt 1000) {
        throw "skeleton.pbit copy failed - file too small. Source: $SkeletonPath"
    }

    $unicodeNoBom = [System.Text.UnicodeEncoding]::new($false, $false)
    $zip = [System.IO.Compression.ZipFile]::Open($pbitPath, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $dmEntry = $zip.Entries | Where-Object { $_.FullName -eq 'DataModelSchema' }
        if (-not $dmEntry) { throw 'DataModelSchema entry not found in skeleton' }
        $dmName = $dmEntry.FullName
        $dmEntry.Delete()
        $newDm = $zip.CreateEntry($dmName)
        $sw = [System.IO.StreamWriter]::new($newDm.Open(), $unicodeNoBom)
        $sw.Write($modelJson)
        $sw.Close()
    }
    finally {
        $zip.Dispose()
    }

    return [PSCustomObject]@{
        PbitPath = $pbitPath
        CsvCount = $csvFiles.Count
        OutputDir = $OutputDir
    }
}
