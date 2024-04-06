# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Get-FinOpsToolkitVersion' {
    It 'Should return all known releases' {
        # Arrange
        $expected = @('0.2', '0.1.1', '0.1', '0.0.1')

        # Act
        $result = Get-FinOpsToolkitVersion

        # Assert
        $result.Count | Should -Be $expected.Count
        $result | ForEach-Object {
            $ver = $_.Version
            $ver | Should -BeIn $expected -Because "version '$ver' should be added to the verification test"

            # All versions
            $_.Files.Name | Should -Contain "finops-hub-v$ver.zip"
            $_.Files.Name | Should -Contain "optimization-workbook-v$ver.zip"
            $_.Files.Name | Should -Contain "CostSummary.pbix"
            $_.Files.Name | Should -Contain "CommitmentDiscounts.pbix"
            
            # 0.1 and above
            if ([version]$_.Version -ge [version]'0.1')
            {
                $_.Files.Name | Should -Contain "governance-workbook-v$ver.zip"
                $_.Files.Name | Should -Contain "PricingUnits.csv"
                $_.Files.Name | Should -Contain "Regions.csv"
                $_.Files.Name | Should -Contain "Services.csv"

                # 0.1.*
                if ([version]$_.Version -lt [version]'0.2')
                {
                    $_.Files.Name | Should -Contain "FOCUS.pbix"
                }
            }

            # 0.2 and above
            if ([version]$_.Version -ge [version]'0.2')
            {
                $_.Files.Name | Should -Contain "CommitmentDiscounts.pbit"
                $_.Files.Name | Should -Contain "CostManagementConnector.pbix"
                $_.Files.Name | Should -Contain "CostManagementTemplateApp.pbix"
                $_.Files.Name | Should -Contain "CostSummary.pbit"
                $_.Files.Name | Should -Contain "ResourceTypes.csv"
                $_.Files.Name | Should -Contain "ResourceTypes.json"
                $_.Files.Name | Should -Contain "sample-exports.zip"
            }
        }
    }
}
