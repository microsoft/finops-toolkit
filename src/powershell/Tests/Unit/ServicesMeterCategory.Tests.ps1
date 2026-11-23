# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Some resource types host more than one service, like Recovery Services vaults (Azure Backup and Azure Site Recovery)
    and App Service sites (App Service, Functions, and Logic Apps Standard). Services.csv uses the optional
    x_SkuMeterCategory column to split them. Empty = applies to all meter categories.
#>

Describe 'Services open data meter category' {
    BeforeDiscovery {
        $scripts = Join-Path (Resolve-Path "$PSScriptRoot/../../../..").Path 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'
        $kqlFiles = @('IngestionSetup_v1_0.kql', 'IngestionSetup_v1_2.kql', 'HubSetup_v1_2.kql') | ForEach-Object { @{ File = $_; Path = Join-Path $scripts $_ } }
        $transforms = @(
            @{ File = 'IngestionSetup_v1_0.kql'; Function = 'Costs_transform_v1_0'; Subcategory = $false }
            @{ File = 'IngestionSetup_v1_2.kql'; Function = 'Costs_transform_v1_2'; Subcategory = $true }
        ) | ForEach-Object { $_.Path = Join-Path $scripts $_.File; $_ }
    }

    BeforeAll {
        $root = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $csvPath = Join-Path $root 'src/open-data/Services.csv'
        $csv = Import-Csv $csvPath
        $scripts = Join-Path $root 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'
    }

    Context 'Services.csv' {
        It 'Has x_SkuMeterCategory as the last column' {
            # Appended so positional CSV readers keep working
            (Get-Content $csvPath -TotalCount 1).Split(',')[-1] | Should -Be 'x_SkuMeterCategory'
        }

        It 'Maps <ResourceType> + <MeterCategory> to <Expected>' -ForEach @(
            @{ ResourceType = 'microsoft.recoveryservices/vaults'; MeterCategory = 'Backup'; Expected = 'Azure Backup'; Category = 'Storage'; Subcategory = 'Backup Storage' }
            @{ ResourceType = 'microsoft.web/sites'; MeterCategory = 'Functions'; Expected = 'Functions'; Category = 'Compute'; Subcategory = 'Serverless Compute' }
            @{ ResourceType = 'microsoft.web/sites'; MeterCategory = 'Logic Apps'; Expected = 'Logic Apps'; Category = 'Integration'; Subcategory = 'Workflow Orchestration' }
        ) {
            $rows = $csv | Where-Object { $_.ResourceType -eq $ResourceType -and $_.x_SkuMeterCategory -eq $MeterCategory }
            $rows | Should -Not -BeNullOrEmpty
            $rows | ForEach-Object {
                $_.ServiceName | Should -Be $Expected
                $_.ServiceCategory | Should -Be $Category
                $_.ServiceSubcategory | Should -Be $Subcategory
            }
        }

        It 'Keeps one generic service for <ResourceType>' -ForEach @(
            @{ ResourceType = 'microsoft.recoveryservices/vaults'; Expected = 'Azure Site Recovery' }
            @{ ResourceType = 'microsoft.web/sites'; Expected = 'Azure App Service' }
        ) {
            $rows = $csv | Where-Object { $_.ResourceType -eq $ResourceType -and -not $_.x_SkuMeterCategory }
            $rows | Should -Not -BeNullOrEmpty
            $rows.ServiceName | Select-Object -Unique | Should -Be $Expected
        }

        It 'Requires a resource type on meter category rows' {
            $csv | Where-Object { $_.x_SkuMeterCategory -and -not $_.ResourceType } | Should -BeNullOrEmpty
        }

        It 'Maps each resource type + meter category to a single service' {
            $csv | Where-Object { $_.x_SkuMeterCategory } `
            | Group-Object { "$($_.ResourceType)|$($_.x_SkuMeterCategory)".ToLower() } `
            | Where-Object { @($_.Group | Select-Object ServiceName, ServiceCategory, ServiceSubcategory -Unique).Count -gt 1 } `
            | Select-Object -ExpandProperty Name `
            | Should -BeNullOrEmpty
        }
    }

    Context 'FinOps hubs' {
        It 'Services table has x_SkuMeterCategory' {
            Get-Content (Join-Path $scripts 'IngestionSetup_HubInfra.kql') -Raw `
            | Should -Match 'create-merge table Services\([^)]*x_SkuMeterCategory:\s+string'
        }

        It 'Open data loaders read x_SkuMeterCategory from Services.csv' -ForEach @(
            @{ File = 'scripts/IngestionSetup_OpenDataExternal.kql' }
            @{ File = 'app.bicep' }
        ) {
            $text = Get-Content (Join-Path $scripts "../$File") -Raw
            $text | Should -Match 'Services <\| externaldata\([^)]*x_ServiceModel: string, x_SkuMeterCategory: string\)'
        }

        It '<File> generic Services lookups skip meter category rows' -ForEach $kqlFiles {
            $lines = Get-Content $Path | Where-Object { $_ -match 'lookup kind=leftouter \(Services \|' -and $_ -notmatch 'isnotempty\(x_SkuMeterCategory\)' }
            $lines | Should -Not -BeNullOrEmpty
            $lines | ForEach-Object { $_ | Should -Match '(?<!not)isempty\(x_SkuMeterCategory\)' -Because 'meter category rows would make take_any pick the wrong service' }
        }

        It '<Function> applies meter category-specific services' -ForEach $transforms {
            $text = Get-Content $Path -Raw
            $start = $text.IndexOf("`n$Function()")
            $start | Should -BeGreaterThan 0
            $end = $text.IndexOf('.create-or-alter function', $start)
            $body = $text.Substring($start, $end - $start)

            $body | Should -Match 'lookup kind=leftouter \(Services \| where isnotempty\(x_ResourceType\) and isnotempty\(x_SkuMeterCategory\)'
            $body | Should -Match 'ServiceName = coalesce\(tmp_ServiceName, ServiceName\)'
            $body | Should -Match 'ServiceCategory = coalesce\(tmp_ServiceCategory, ServiceCategory\)'
            if ($Subcategory)
            {
                $body | Should -Match 'ServiceSubcategory = coalesce\(tmp_ServiceSubcategory, ServiceSubcategory\)'
                $body | Should -Match "checkString\('ServiceName',\s+old_ServiceName,\s+ServiceName\)" -Because 'the original label is kept in x_SourceValues'
            }
        }
    }
}
