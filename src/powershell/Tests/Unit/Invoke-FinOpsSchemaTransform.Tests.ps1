# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Remove-Module FinOpsToolkit -ErrorAction SilentlyContinue
Import-Module -FullyQualifiedName "$PSScriptRoot/../../FinOpsToolkit.psm1"

Describe 'Invoke-FinOpsSchemaTransform' {
    BeforeAll {
        $actualCostPath = Get-Item "$PSScriptRoot/assets/EA_ActualCost_Small.csv"
        $amortizedCostPath = Get-Item "$PSScriptRoot/assets/EA_AmortizedCost_Small.csv"
        $actualCostPathLarge = Get-Item "$PSScriptRoot/../../../sample-data/EA_ActualCost.csv"
        $amortizedCostPathLarge = Get-Item "$PSScriptRoot/../../../sample-data/EA_AmortizedCost.csv"
        $emptyPath = Get-Item "$PSScriptRoot/assets/EA_NoRows.csv"
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

    # This test is skipped because it takes ~2 minutes to run
    It 'Should run for large files' -Skip {
        # Arrange
        #Mock -ModuleName FinOpsToolkit -CommandName ConvertTo-FinOpsSchema -MockWith { param($ActualCost, $AmortizedCost) return $ActualCost + $AmortizedCost }
        $actualRows = (Import-Csv $actualCostPath).Count
        $amortizedRows = (Import-Csv $amortizedCostPath).Count
        
        # Act
        Invoke-FinOpsSchemaTransform -ActualCostPath $actualCostPathLarge -AmortizedCostPath $amortizedCostPathLarge -OutputFile $outputPath
        
        # Assert
        #Should -Invoke -ModuleName FinOpsToolkit -CommandName ConvertTo-FinOpsSchema -Exactly -Times 1
        # DEBUG -- Write-Host "$actualRows actual + $amortizedRows amortized = $((Import-Csv $outputPath).Count) rows"
        #(Import-Csv $outputPath).Count | Should -Be ($actualRows + $amortizedRows)
    }

    AfterAll {
        Remove-Item $outputPath -ErrorAction SilentlyContinue
    }
}
