# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'CostExports' {
    It 'Create-Read-Update-Delete exports' -Skip {
        # Arrange
        $context = Get-AzContext
        $scope = "/subscriptions/$($context.Subscription.Id)"
        $storage = New-AzStorageAccount `
            -ResourceGroupName "ftk-integration-tests" `
            -Name "ftkintcostexports$($context.Subscription.Id.Replace("-", ""))" `
            -Location "East US" `
            -SkuName Standard_LRS
        $name = "ftk-int-CostExports"
    
        # Act -- create
        $newResult = New-FinOpsCostExport -Name $name -Scope $scope -StorageAccountId $storage.Id
    
        # Assert
        $newResult | Should -Not -BeNull

        # Act -- read
        $getResult = Get-FinOpsCostExport -Name $name -Scope $scope
        
        # Assert
        $getResult.Count | Should -Be 1
        $getResult.Name | Should -Be $name
        
        # Act -- run now
        $runResult = Start-FinOpsCostExport -Name $name -Scope $scope
        
        # Assert
        $runResult | Should -Not -BeNull
        
        # Act -- delete
        $deleteResult = Remove-FinOpsCostExport -Name $name -Scope $scope
        $confirmDeleteResult = Get-FinOpsCostExport -Name $name -Scope $scope
        
        # Assert
        $deleteResult | Should -Not -BeNull
        $confirmDeleteResult | Should -BeNull
    }
}
