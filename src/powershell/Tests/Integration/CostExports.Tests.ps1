# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'CostExports' {
    BeforeAll {
        # Arrange
        $context = Get-AzContext
        $rg = "ftk-integration-tests"
        $baScope = "/providers/Microsoft.Billing/billingAccounts/8611537"
        $rgScope = "/subscriptions/$($context.Subscription.Id)/resourceGroups/$rg"
        $scope = $baScope
        $loc = "East US"
        $storageName = ([guid]::NewGuid().Guid.Replace('-', '').Substring(0, 24))
        $exportName = "ftk-int-CostExports"

        New-AzResourceGroup -Name $rg -Location $loc -Force
        $storage = New-AzStorageAccount `
            -ResourceGroupName $rg `
            -Name $storageName `
            -Location $loc `
            -SkuName Standard_LRS
    }

    It 'Should create-read-update-delete <_> export' -ForEach @('ActualCost', 'AmortizedCost', 'FocusCost', 'PriceSheet', 'ReservationTransactions', 'ReservationRecommendations', 'ReservationDetails') {
        $datasetType = $_
        $typedExportName = "$exportName-$datasetType"
        Monitor "Export $datasetType tests..." -Indent '  ' {
            Monitor "Creating $typedExportName export..." {
                # Act -- create
                $newResult = New-FinOpsCostExport -Name $typedExportName -Scope $scope -Dataset $datasetType -StorageAccountId $storage.Id
                # TODO: Run tests for all supported API versions: -ApiVersion '2023-08-01'

                # Assert
                Report -Object $newResult
                $newResult.Name | Should -Be $typedExportName
                $newResult.RunHistory | Should -BeNullOrEmpty -Because "the -RunHistory option was not specified"
            }

            Monitor "Getting $typedExportName..." {
                # Act -- read
                $getResult = Get-FinOpsCostExport -Name $typedExportName -Scope $scope -RunHistory

                # Assert
                Report "Found $($getResult.Count) export(s)"
                Report -Object $getResult
                $getResult.Count | Should -Be 1
                $getResult.Name | Should -Be $typedExportName
            }

            Monitor "Running $typedExportName..." {
                # Act -- run now
                $runResult = Start-FinOpsCostExport -Name $typedExportName -Scope $scope

                # Assert
                Report $runResult
                $runResult | Should -BeTrue
            }

            Monitor "Deleting $typedExportName..." {
                # Act -- delete
                $deleteResult = Remove-FinOpsCostExport -Name $typedExportName -Scope $scope
                $confirmDeleteResult = Get-FinOpsCostExport -Name $typedExportName -Scope $scope

                # Assert
                Report $deleteResult
                $deleteResult | Should -BeTrue
                Report "$($getResult.Count) export(s) remaining"
                $confirmDeleteResult | Should -BeNullOrEmpty
            }
        }
    }

    # TODO: Update this to check if older than 13 months
    It 'Should create one-time export' {
        # Arrange
        $historicalExportName = $exportName
        $startDate = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0).AddMonths(-12)

        Monitor "Export tests..." -Indent '  ' {
            Monitor "Creating $historicalExportName export..." {
                # Act -- create
                New-FinOpsCostExport -Name $exportName -Scope $scope -StorageAccountId $storage.Id
                $newResult = New-FinOpsCostExport `
                    -Name $historicalExportName `
                    -Scope $scope `
                    -StorageAccountId $storage.Id `
                    -Dataset AmortizedCost `
                    -OneTime `
                    -StartDate $startDate

                # Assert
                Report -Object $newResult
                $newResult.Name | Should -Be $historicalExportName
                $newResult.DatasetStartDate | Should -Be $startDate
            }

            Monitor "Getting $historicalExportName..." {
                # Act -- read
                $getResult = Get-FinOpsCostExport -Name $historicalExportName -Scope $scope -RunHistory

                # Assert
                Report "Found $($getResult.Count) export(s)"
                Report -Object $getResult
                $getResult.Count | Should -Be 1
                $getResult.Name | Should -Be $historicalExportName
                $getResult.RunHistory.Count | Should -BeGreaterThan 0 -Because "-Execute -Backfill 1 was specified during creation"
            }

            Monitor "Deleting $historicalExportName..." {
                # Act -- delete
                $deleteResult = Remove-FinOpsCostExport -Name $historicalExportName -Scope $scope
                $confirmDeleteResult = Get-FinOpsCostExport -Name $historicalExportName -Scope $scope

                # Assert
                Report $deleteResult
                $deleteResult | Should -BeTrue
                Report "$($getResult.Count) export(s) remaining"
                $confirmDeleteResult | Should -BeNullOrEmpty
            }
        }
    }

    It 'Should create an export for 13 months ago' {
        # Arrange
        $historicalExportName = $exportName
        $startDate = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0).AddMonths(-13)

        Monitor "Export tests..." -Indent '  ' {
            Monitor "Creating $historicalExportName export..." {
                # Act -- create
                $newResult = New-FinOpsCostExport `
                    -Name $historicalExportName `
                    -Scope $scope `
                    -StorageAccountId $storage.Id `
                    -Dataset AmortizedCost `
                    -OneTime `
                    -StartDate $startDate

                # Assert
                Report -Object $newResult
                $newResult.Name | Should -Be $historicalExportName
                $newResult.DatasetStartDate | Should -Be $startDate
            }

            Monitor "Getting $historicalExportName..." {
                # Act -- read
                $getResult = Get-FinOpsCostExport -Name $historicalExportName -Scope $scope -RunHistory

                # Assert
                Report "Found $($getResult.Count) export(s)"
                Report -Object $getResult
                $getResult.Count | Should -Be 1
                $getResult.Name | Should -Be $historicalExportName
                $getResult.RunHistory.Count | Should -BeGreaterThan 0 -Because "-Execute -Backfill 1 was specified during creation"
            }

            Monitor "Deleting $historicalExportName..." {
                # Act -- delete
                $deleteResult = Remove-FinOpsCostExport -Name $historicalExportName -Scope $scope
                $confirmDeleteResult = Get-FinOpsCostExport -Name $historicalExportName -Scope $scope

                # Assert
                Report $deleteResult
                $deleteResult | Should -BeTrue
                Report "$($getResult.Count) export(s) remaining"
                $confirmDeleteResult | Should -BeNullOrEmpty
            }
        }
    }

    It 'Should create an export starting under 7 years ago' {
        # Arrange
        $historicalExportName = $exportName
        # Exports tracks 7 years in days, not months, so we can only use 7y-2mo to get a full month accounting for time zones
        $startDate = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0).AddYears(-7).AddMonths(2)

        Monitor "Export tests..." -Indent '  ' {
            Monitor "Creating $historicalExportName export..." {
                # Arrange
                Report "Start: $startDate"

                # Act -- create
                $newResult = New-FinOpsCostExport `
                    -Name $historicalExportName `
                    -Scope $scope `
                    -StorageAccountId $storage.Id `
                    -Dataset AmortizedCost `
                    -OneTime `
                    -StartDate $startDate

                # Assert
                Report -Object $newResult
                $newResult.Name | Should -Be $historicalExportName
                $newResult.DatasetStartDate | Should -Be $startDate
            }

            Monitor "Getting $historicalExportName..." {
                # Act -- read
                $getResult = Get-FinOpsCostExport -Name $historicalExportName -Scope $scope -RunHistory

                # Assert
                Report "Found $($getResult.Count) export(s)"
                Report -Object $getResult
                $getResult.Count | Should -Be 1
                $getResult.Name | Should -Be $historicalExportName
                $getResult.RunHistory.Count | Should -BeGreaterThan 0 -Because "-Execute -Backfill 1 was specified during creation"
            }

            Monitor "Deleting $historicalExportName..." {
                # Act -- delete
                $deleteResult = Remove-FinOpsCostExport -Name $historicalExportName -Scope $scope
                $confirmDeleteResult = Get-FinOpsCostExport -Name $historicalExportName -Scope $scope

                # Assert
                Report $deleteResult
                $deleteResult | Should -BeTrue
                Report "$($getResult.Count) export(s) remaining"
                $confirmDeleteResult | Should -BeNullOrEmpty
            }
        }
    }

    It 'Should fail to create an export for 7 years ago (not accounting for start date)' {
        # Arrange
        $historicalExportName = $exportName
        $startDate = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0).AddYears(-7)

        Monitor "Export tests..." -Indent '  ' {
            Monitor "Creating $historicalExportName export..." {
                # Act -- create
                # Assert
                {
                    New-FinOpsCostExport `
                        -Name $historicalExportName `
                        -Scope $scope `
                        -StorageAccountId $storage.Id `
                        -Dataset AmortizedCost `
                        -OneTime `
                        -StartDate $startDate `
                } | Should -Throw
            }
        }
    }

    It 'Should handle progress and throttling for 12 month backfill' {
        # Arrange
        $startDate = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0)

        Monitor "Export throttling tests..." -Indent '  ' {
            Monitor "Creating $exportName export..." {
                # Act -- create
                $newResult = New-FinOpsCostExport -Name $exportName -Scope $scope -StorageAccountId $storage.Id -Execute -Backfill 12
                # TODO: Run tests for all supported API versions: -ApiVersion '2023-08-01'

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
                $getResult.RunHistory.Count | Should -BeGreaterThan 0 -Because "-Execute -Backfill was specified during creation"
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
        }
    }

    Context "Long-running unit tests" {
        BeforeAll {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $exportName = 'ftk-test-Start-FinOpsCostExport'

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $scope = "/subscriptions/$([Guid]::NewGuid())"

            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
            $mockExport = @{
                id   = "$scope/providers/Microsoft.CostManagement/exports/$exportName"
                name = $exportName
            }
        }

        It 'Should wait 60s when throttled' {
            # NOTE: This is a unit test that mocks dependencies. It's run with integration tests due to how long it takes to run.

            # Arrange
            $script:waited = $false
            $testStartTime = Get-Date
            function CheckDate($date)
            {
                $monthToThrottle = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0 -AsUTC).AddMonths(-3).ToUniversalTime().Date.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
                if ($date -eq $monthToThrottle -and -not $script:waited)
                {
                    $script:waited = $true
                    return $true
                }
                return $false
            }
            Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' -MockWith { $mockExport }
            Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest'          -MockWith {
                if (CheckDate($Body.timePeriod.from))
                {
                    @{ Success = $false; Throttled = $true }
                }
                else
                {
                    @{ Success = $true }
                }
            }
            Mock -ModuleName FinOpsToolkit -CommandName 'Write-Progress'       -MockWith {}

            # Act
            $success = Start-FinOpsCostExport `
                -Name $exportName `
                -Scope $scope `
                -Backfill 12

            # Assert
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Write-Progress' -Times 4
            $success | Should -Be $true
            ((Get-Date) - $testStartTime).TotalSeconds | Should -BeGreaterThan 60
        }
    }

    AfterAll {
        # Cleanup
        Remove-AzStorageAccount -ResourceGroupName $rg -Name $storageName -Force
    }
}
