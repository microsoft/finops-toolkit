# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for #1751: Azure Backup and Azure Site Recovery share the
    microsoft.recoveryservices/vaults resource type. Services.csv splits them by meter category
    (x_SkuMeterCategory); the Costs_transform lookup is covered by ServicesMeterCategory.Tests.ps1.
#>

Describe 'Azure Backup service mapping (#1751)' {
    BeforeAll {
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/Services.csv"
        $vaults = $csv | Where-Object ResourceType -eq 'microsoft.recoveryservices/vaults'
    }

    It 'Maps vaults to Azure Site Recovery when no meter category matches' {
        ($vaults | Where-Object { -not $_.x_SkuMeterCategory }).ServiceName | Should -Be 'Azure Site Recovery'
    }

    It 'Maps the Backup meter category on vaults to Azure Backup' {
        $row = $vaults | Where-Object x_SkuMeterCategory -eq 'Backup'
        $row.ServiceName | Should -Be 'Azure Backup'
        $row.ServiceCategory | Should -Be 'Storage'
        $row.ServiceSubcategory | Should -Be 'Backup Storage'
    }

    It 'Does not hard-code the Backup override in Costs_transform' -ForEach @('IngestionSetup_v1_0.kql', 'IngestionSetup_v1_2.kql') {
        $path = Join-Path (Resolve-Path "$PSScriptRoot/../../../..").Path "src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/$_"
        (Get-Content $path -Raw) | Should -Not -Match 'tmp_IsVaultBackup' -Because 'the Services lookup covers it'
    }
}
