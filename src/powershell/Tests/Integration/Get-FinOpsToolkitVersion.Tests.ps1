# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Get-FinOpsToolkitVersion' {
    It 'Should return all known releases' {
        # Arrange
        $expected = @('0.1.1', '0.1', '0.0.1')

        # Act
        $result = Get-FinOpsToolkitVersion

        # Assert
        $result.Count | Should -Be $expected.Count
        $expected | ForEach-Object {
            $result.Version | Should -Contain $_
                
            # All versions
            $result.Files.Name | Should -Contain "finops-hub-v$_.zip"
            $result.Files.Name | Should -Contain "optimization-workbook-v$_.zip"
            $result.Files.Name | Should -Contain "CostSummary.pbix"
            $result.Files.Name | Should -Contain "CommitmentDiscounts.pbix"

            # 0.1 and above
            if ([version]$_ -ge [version]'0.1')
            {
                $result.Files.Name | Should -Contain "governance-workbook-v$_.zip"
                $result.Files.Name | Should -Contain "FOCUS.pbix"
                $result.Files.Name | Should -Contain "PricingUnits.csv"
                $result.Files.Name | Should -Contain "Regions.csv"
                $result.Files.Name | Should -Contain "Services.csv"
            }
        }
    }
}
