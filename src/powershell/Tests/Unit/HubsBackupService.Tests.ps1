# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for #1751: Azure Backup and Azure Site Recovery share the
    microsoft.recoveryservices/vaults resource type, so Services.csv alone cannot tell them apart.
    Hub ingestion must override the service by meter category for Backup charges.
#>

Describe 'Azure Backup service mapping (#1751)' {
    BeforeDiscovery {
        $scripts = Join-Path (Resolve-Path "$PSScriptRoot/../../../..").Path 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'
        $cases = @(
            @{ File = 'IngestionSetup_v1_0.kql'; Count = 2; Subcategory = $false }
            @{ File = 'IngestionSetup_v1_2.kql'; Count = 2; Subcategory = $true }
        ) | ForEach-Object { $_.Path = Join-Path $scripts $_.File; $_ }
    }

    It 'Services.csv keeps vaults as Site Recovery and has an Azure Backup service' {
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/Services.csv"
        ($csv | Where-Object ResourceType -eq 'microsoft.recoveryservices/vaults').ServiceName | Should -Be 'Azure Site Recovery'
        ($csv | Where-Object ServiceName -eq 'Azure Backup') | Should -Not -BeNullOrEmpty
    }

    It '<File> overrides Backup meter charges on vaults to Azure Backup' -ForEach $cases {
        $text = Get-Content $Path -Raw
        ([regex]::Matches($text, "ServiceName = iff\(x_ResourceType =~ 'microsoft\.recoveryservices/vaults' and MeterCategory =~ 'Backup', 'Azure Backup', ServiceName\)")).Count | Should -Be $Count
        ([regex]::Matches($text, "ServiceCategory = iff\(x_ResourceType =~ 'microsoft\.recoveryservices/vaults' and MeterCategory =~ 'Backup', 'Storage', ServiceCategory\)")).Count | Should -Be $Count
        if ($Subcategory) {
            ([regex]::Matches($text, "ServiceSubcategory = iff\(x_ResourceType =~ 'microsoft\.recoveryservices/vaults' and MeterCategory =~ 'Backup', 'Backup Storage', ServiceSubcategory\)")).Count | Should -Be $Count
        }
    }
}
