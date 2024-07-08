# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Get-FinOpsToolkitVersion' {
    It 'Should return all known releases' {
        # Arrange
        $plannedRelease = '0.4'
        $expected = @('0.3', '0.2', '0.1.1', '0.1', '0.0.1')

        # Act
        $result = Get-FinOpsToolkitVersion

        # Assert
        $result.Count | Should -BeGreaterOrEqual $expected.Count
        $result.Count | Should -BeLessOrEqual ($expected.Count + 1)
        $result | ForEach-Object {
            $verStr = $_.Version
            $verObj = [version]$verStr

            function CheckFile($file, $minVer, $maxVer)
            {
                if ($null -eq $minVer) { $minVer = '0.0.1' }
                if ($null -eq $maxVer) { $maxVer = '999.999' }
                if ($verObj -ge [version]$minVer -and $verObj -le [version]$maxVer)
                {
                    $_.Files.Name | Should -Contain $file -Because "version $verStr should contain $file ($minVer - $maxVer)"
                }
            }

            $verStr | Should -BeIn (@($plannedRelease) + $expected) -Because "version '$verStr' should be added to the verification test"

            # Templates
            CheckFile "finops-hub-v$verStr.zip"             $null $null
            CheckFile "governance-workbook-v$verStr.zip"    '0.1' $null
            CheckFile "optimization-workbook-v$verStr.zip"  $null $null
            
            # Power BI
            CheckFile "CostSummary.pbit"                    '0.2' $null
            CheckFile "CostSummary.pbix"                    $null $null
            CheckFile "CommitmentDiscounts.pbit"            '0.2' '0.3'
            CheckFile "CommitmentDiscounts.pbix"            $null '0.3'
            CheckFile "DataIngestion.pbit"                  '0.3' $null
            CheckFile "DataIngestion.pbix"                  '0.3' $null
            CheckFile "CostManagementConnector.pbix"        '0.2' $null
            CheckFile "CostManagementTemplateApp.pbix"      '0.2' $null
            CheckFile "FOCUS.pbix"                          '0.1' '0.1.1'
            CheckFile "RateOptimization.pbit"               '0.4' $null
            CheckFile "RateOptimization.pbix"               '0.4' $null
            
            # Open data
            CheckFile "PricingUnits.csv"                    '0.1' $null
            CheckFile "Regions.csv"                         '0.1' $null
            CheckFile "Services.csv"                        '0.1' $null
            CheckFile "ResourceTypes.csv"                   '0.2' $null
            CheckFile "ResourceTypes.json"                  '0.2' $null
            CheckFile "sample-data.zip"                     '0.3' '0.3'
            CheckFile "sample-exports.zip"                  '0.2' '0.2'
            CheckFile "dataset-samples.zip"                 '0.4' $null
            CheckFile "dataset-metadata.zip"                '0.4' $null
        }
    }
}
