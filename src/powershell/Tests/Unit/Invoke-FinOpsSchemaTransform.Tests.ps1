# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Invoke-FinOpsSchemaTransform' {
    BeforeAll {
        $actualCostPath = Get-Item "$PSScriptRoot/../assets/EA_ActualCost_Small.csv"
        $amortizedCostPath = Get-Item "$PSScriptRoot/../assets/EA_AmortizedCost_Small.csv"
        $emptyPath = Get-Item "$PSScriptRoot/../assets/EA_NoRows.csv"
        $outputPath = New-TemporaryFile
    }

    It 'Should pass all rows from each file to ConvertTo-FinOpsSchema' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName ConvertTo-FinOpsSchema -MockWith { param($ActualCost, $AmortizedCost) return $ActualCost + $AmortizedCost }
        $actualRows = (Import-Csv $actualCostPath).Count
        $amortizedRows = (Import-Csv $amortizedCostPath).Count

        # Act
        Invoke-FinOpsSchemaTransform -ActualCostPath $actualCostPath -AmortizedCostPath $amortizedCostPath -OutputFile $outputPath

        # Assert
        Should -Invoke -ModuleName FinOpsToolkit -CommandName ConvertTo-FinOpsSchema -Exactly -Times 1
        # DEBUG -- Write-Host "$actualRows actual + $amortizedRows amortized = $((Import-Csv $outputPath).Count) rows"
        (Import-Csv $outputPath).Count | Should -Be ($actualRows + $amortizedRows)
    }

    AfterAll {
        Remove-Item $outputPath -ErrorAction SilentlyContinue
    }
}
