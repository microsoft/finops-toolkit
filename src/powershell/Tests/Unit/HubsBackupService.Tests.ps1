# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for #1751: Azure Backup and Azure Site Recovery share the
    microsoft.recoveryservices/vaults resource type, so Services.csv alone cannot tell them apart,
    and Cost Management labels Backup charges as Azure Site Recovery in FOCUS exports too.
    Costs_transform overrides the service by meter category. Actual and Amortized ingestion write
    to Costs_raw with x_SkuMeterCategory = MeterCategory, so one override covers all three paths.
#>

Describe 'Azure Backup service mapping (#1751)' {
    BeforeDiscovery {
        $scripts = Join-Path (Resolve-Path "$PSScriptRoot/../../../..").Path 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts'
        $cases = @(
            @{ File = 'IngestionSetup_v1_0.kql'; Function = 'Costs_transform_v1_0'; Subcategory = $false }
            @{ File = 'IngestionSetup_v1_2.kql'; Function = 'Costs_transform_v1_2'; Subcategory = $true }
        ) | ForEach-Object { $_.Path = Join-Path $scripts $_.File; $_ }
    }

    It 'Services.csv keeps vaults as Site Recovery and has an Azure Backup service' {
        $csv = Import-Csv "$PSScriptRoot/../../../open-data/Services.csv"
        ($csv | Where-Object ResourceType -eq 'microsoft.recoveryservices/vaults').ServiceName | Should -Be 'Azure Site Recovery'
        ($csv | Where-Object ServiceName -eq 'Azure Backup') | Should -Not -BeNullOrEmpty
    }

    It '<Function> overrides Backup meter charges on vaults to Azure Backup' -ForEach $cases {
        $text = Get-Content $Path -Raw
        $start = $text.IndexOf("`n$Function()")
        $start | Should -BeGreaterThan 0
        $end = $text.IndexOf('.create-or-alter function', $start)
        $body = $text.Substring($start, $end - $start)

        $body | Should -Match "tmp_IsVaultBackup = x_ResourceType =~ 'microsoft\.recoveryservices/vaults' and x_SkuMeterCategory =~ 'Backup'"
        $body | Should -Match "ServiceName = iff\(tmp_IsVaultBackup, 'Azure Backup', ServiceName\)"
        $body | Should -Match "ServiceCategory = iff\(tmp_IsVaultBackup, 'Storage', ServiceCategory\)"
        if ($Subcategory) {
            $body | Should -Match "ServiceSubcategory = iff\(tmp_IsVaultBackup, 'Backup Storage', ServiceSubcategory\)"
            $body | Should -Match "checkString\('ServiceName',\s+old_ServiceName,\s+ServiceName\)" -Because 'the original label is kept in x_SourceValues'
        }
    }

    It '<File> does not duplicate the override in the Actual and Amortized transforms' -ForEach $cases {
        (Get-Content $Path -Raw) | Should -Not -Match "(?<!x_Sku)MeterCategory =~ 'Backup'" -Because 'Costs_transform covers every path; per-transform copies drift'
    }
}
