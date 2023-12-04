# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

. "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Invoke-FinOpsSchemaTransform' {
    BeforeAll {
        $actualCostPath = Get-Item "$PSScriptRoot/../assets/EA_ActualCost_Small.csv"
        $amortizedCostPath = Get-Item "$PSScriptRoot/../assets/EA_AmortizedCost_Small.csv"
        $actualCostPathLarge = Get-Item "$PSScriptRoot/../../../sample-data/EA_ActualCost.csv"
        $amortizedCostPathLarge = Get-Item "$PSScriptRoot/../../../sample-data/EA_AmortizedCost.csv"

        $actualPath = New-TemporaryFile
        $amortizedPath = New-TemporaryFile
        $outputPath = New-TemporaryFile

        $minSecondsPerRow = 0.01  # Decrease the max if you lower this number
        $maxSecondsPerRow = 0.08  # DO NOT INCREASE THIS NUMBER!!!

        $rowsToTest = 200
        Import-Csv $actualCostPathLarge | Select-Object -First ($rowsToTest / 2) | Export-Csv $actualPath
        Import-Csv $amortizedCostPathLarge | Select-Object -First ($rowsToTest / 2) | Export-Csv $amortizedPath
    }

    It 'Should complete in expected time for small files' {
        # Arrange
        $rowCount = (Import-Csv $actualCostPath).Count + (Import-Csv $amortizedCostPath).Count

        # Act
        $time = Measure-Command -Expression {
            Invoke-FinOpsSchemaTransform -ActualCostPath $actualCostPath -AmortizedCostPath $amortizedCostPath -OutputFile $outputPath
        }

        # Assert
        $time.TotalSeconds / $rowCount | Should -BeLessThan $maxSecondsPerRow -Because "it should not get any slower than $maxSecondsPerRow per row"
        $time.TotalSeconds / $rowCount | Should -BeGreaterThan $minSecondsPerRow -Because "if faster than $minSecondsPerRow, lower both min and max in test"
    }

    It 'Should complete in expected time for large files' {
        # Arrange
        $rowCount = $rowsToTest

        # Act
        $time = Measure-Command -Expression {
            Invoke-FinOpsSchemaTransform -ActualCostPath $actualPath -AmortizedCostPath $amortizedPath -OutputFile $outputPath
        }

        # Assert
        $time.TotalSeconds / $rowCount | Should -BeLessThan $maxSecondsPerRow -Because "Do not let this get any slower than $maxSecondsPerRow per row"
        $time.TotalSeconds / $rowCount | Should -BeGreaterThan $minSecondsPerRow -Because "If faster than $minSecondsPerRow, lower both min and max in test"
    }

    AfterAll {
        Remove-Item $outputPath -ErrorAction SilentlyContinue
        Remove-Item $actualPath -ErrorAction SilentlyContinue
        Remove-Item $amortizedPath -ErrorAction SilentlyContinue
    }
}
