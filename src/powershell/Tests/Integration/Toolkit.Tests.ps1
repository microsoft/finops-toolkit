# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Get-FinOpsToolkitVersion' {
    It 'Should return all known releases' {
        # Arrange
        $plannedRelease = '0.5'
        $expected = @('0.6', '0.5', '0.4', '0.3', '0.2', '0.1.1', '0.1', '0.0.1')

        # Act
        $result = Get-FinOpsToolkitVersion

        # Assert
        Monitor "Version checks for $($result.Count) releases" -Indent "  " {
            $result.Count | Should -BeGreaterOrEqual $expected.Count
            $result.Count | Should -BeLessOrEqual ($expected.Count + 1)
            $result | ForEach-Object {
                $verStr = $_.Version
                $verObj = [version]$verStr
                $fileCount = 0

                function CheckFile($file, $minVer, $maxVer)
                {
                    if ($null -eq $minVer) { $minVer = '0.0.1' }
                    if ($null -eq $maxVer) { $maxVer = '999.999' }
                    if ($verObj -ge [version]$minVer -and $verObj -le [version]$maxVer)
                    {
                        Set-Variable -Scope 1 -Name "fileCount" -Value ($fileCount + 1)
                        $_.Files.Name | Should -Contain $file -Because "version $verStr should contain $file ($minVer - $maxVer)"
                    }
                }

                $verStr | Should -BeIn (@($plannedRelease) + $expected) -Because "version '$verStr' should be added to the verification test"

                # Templates
                CheckFile "finops-hub-v$verStr.zip"             $null $null
                CheckFile "finops-workbooks-v$verStr.zip"       '0.6' $null
                CheckFile "governance-workbook-v$verStr.zip"    '0.1' $null
                CheckFile "optimization-engine-v$verStr.zip"    '0.4' $null
                CheckFile "optimization-workbook-v$verStr.zip"  $null $null
            
                # Power BI
                CheckFile "CostManagementConnector.pbix"        '0.2' $null
                CheckFile "CostManagementTemplateApp.pbix"      '0.2' $null
                CheckFile "CostSummary.pbit"                    '0.2' $null
                CheckFile "CostSummary.pbix"                    $null $null
                CheckFile "DataIngestion.pbit"                  '0.3' $null
                CheckFile "DataIngestion.pbix"                  '0.3' $null
                CheckFile "Governance.pbit"                     '0.6' $null
                CheckFile "Governance.pbix"                     '0.6' $null
                CheckFile "RateOptimization.pbit"               '0.4' $null
                CheckFile "RateOptimization.pbix"               '0.4' $null
                CheckFile "WorkloadOptimization.pbit"           '0.6' $null
                CheckFile "WorkloadOptimization.pbix"           '0.6' $null
            
                # Open data
                CheckFile "dataset-examples.zip"                '0.4' $null
                CheckFile "dataset-metadata.zip"                '0.4' $null
                CheckFile "PricingUnits.csv"                    '0.1' $null
                CheckFile "Regions.csv"                         '0.1' $null
                CheckFile "ResourceTypes.csv"                   '0.2' $null
                CheckFile "ResourceTypes.json"                  '0.2' $null
                CheckFile "Services.csv"                        '0.1' $null

                # Deprecated / renamed
                CheckFile "CommitmentDiscounts.pbit"            '0.2' '0.3'
                CheckFile "CommitmentDiscounts.pbix"            $null '0.3'
                CheckFile "FOCUS.pbix"                          '0.1' '0.1.1'
                CheckFile "sample-data.zip"                     '0.3' '0.3'
                CheckFile "sample-exports.zip"                  '0.2' '0.2'

                $_.Files.Count | Should -Be $fileCount
                Report "$($_.Version) checks passed – $fileCount files"
            }
        }
    }
}
