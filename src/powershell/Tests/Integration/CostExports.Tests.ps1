# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'CostExports' {
    It 'Create-Read-Update-Delete exports' {
        # Arrange
        $context = Get-AzContext
        $rg = "ftk-integration-tests"
        $scope = "/subscriptions/$($context.Subscription.Id)/resourceGroups/$rg"
        $loc = "East US"
        $storageName = ([guid]::NewGuid().Guid.Replace('-', '').Substring(0, 24))
        $exportName = "ftk-int-CostExports"
        
        Monitor "Export tests..." -Indent '  ' {
            # Arrange
            Report "Creating $rg RG..."
            New-AzResourceGroup -Name $rg -Location $loc -Force
            Report "Creating $storageName storage account..."
            $storage = New-AzStorageAccount `
                -ResourceGroupName $rg `
                -Name $storageName `
                -Location $loc `
                -SkuName Standard_LRS

            Monitor "Creating $exportName export..." {
                # Act -- create
                $newResult = New-FinOpsCostExport -Name $exportName -Scope $scope -StorageAccountId $storage.Id -Execute -Backfill 1
                
                # Assert
                Report -Object $newResult
                $newResult.Name | Should -Be $exportName
                $newResult.RunHistory | Should -BeNullOrEmpty -Because "the -RunHistory option was not specified"
            }

            Monitor "Getting $exportName..." {
                # Act -- read
                $getResult = Get-FinOpsCostExport -Name $exportName -Scope $scope -RunHistory

                # Assert
                Report "Found $($getResult.Count) export(s)"
                Report -Object $getResult
                $getResult.Count | Should -Be 1
                $getResult.Name | Should -Be $exportName
                $getResult.RunHistory.Count | Should -BeGreaterThan 0 -Because "-Execute -Backfill 1 was specified during creation"
            }

            Monitor "Running $exportName..." {
                # Act -- run now
                $runResult = Start-FinOpsCostExport -Name $exportName -Scope $scope
                
                # Assert
                Report $runResult
                $runResult | Should -BeTrue
            }

            Monitor "Deleting $exportName..." {
                # Act -- delete
                $deleteResult = Remove-FinOpsCostExport -Name $exportName -Scope $scope
                $confirmDeleteResult = Get-FinOpsCostExport -Name $exportName -Scope $scope
                
                # Assert
                Report $deleteResult
                $deleteResult | Should -BeTrue
                Report "$($getResult.Count) export(s) remaining"
                $confirmDeleteResult | Should -BeNullOrEmpty
            }

            # Cleanup
            Remove-AzStorageAccount -ResourceGroupName $rg -Name $storageName -Force
            Report "Storage account deleted"
        }
    }
}
