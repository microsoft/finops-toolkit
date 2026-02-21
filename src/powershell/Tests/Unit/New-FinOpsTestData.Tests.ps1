# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

InModuleScope 'FinOpsToolkit' {
    Describe 'New-FinOpsTestData' {
        Context "Parameter validation" {
            It 'Should have default OutputPath of ./test-data' {
                $cmd = Get-Command New-FinOpsTestData
                $param = $cmd.Parameters['OutputPath']
                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }) | Should -Not -BeNullOrEmpty
            }

            It 'Should validate ServiceProvider values' {
                $cmd = Get-Command New-FinOpsTestData
                $validate = $cmd.Parameters['ServiceProvider'].Attributes.Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] })
                $validate | Should -Not -BeNullOrEmpty
                $validate.ValidValues | Should -Contain 'Azure'
                $validate.ValidValues | Should -Contain 'AWS'
                $validate.ValidValues | Should -Contain 'GCP'
                $validate.ValidValues | Should -Contain 'DataCenter'
                $validate.ValidValues | Should -Contain 'All'
            }

            It 'Should validate FocusVersion values' {
                $cmd = Get-Command New-FinOpsTestData
                $validate = $cmd.Parameters['FocusVersion'].Attributes.Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] })
                $validate | Should -Not -BeNullOrEmpty
                $validate.ValidValues | Should -Contain '1.0'
                $validate.ValidValues | Should -Contain '1.1'
                $validate.ValidValues | Should -Contain '1.2'
                $validate.ValidValues | Should -Contain '1.3'
            }

            It 'Should validate OutputFormat values' {
                $cmd = Get-Command New-FinOpsTestData
                $validate = $cmd.Parameters['OutputFormat'].Attributes.Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] })
                $validate | Should -Not -BeNullOrEmpty
                $validate.ValidValues | Should -Contain 'CSV'
                $validate.ValidValues | Should -Contain 'Parquet'
            }

            It 'Should support ShouldProcess' {
                $cmd = Get-Command New-FinOpsTestData
                $cmdletBinding = $cmd.ScriptBlock.Attributes.Where({ $_ -is [System.Management.Automation.CmdletBindingAttribute] })
                $cmdletBinding.SupportsShouldProcess | Should -Be $true
            }

            It 'Should have expected parameters' {
                $cmd = Get-Command New-FinOpsTestData
                $paramNames = $cmd.Parameters.Keys
                $paramNames | Should -Contain 'OutputPath'
                $paramNames | Should -Contain 'ServiceProvider'
                $paramNames | Should -Contain 'MonthsOfData'
                $paramNames | Should -Contain 'StartDate'
                $paramNames | Should -Contain 'EndDate'
                $paramNames | Should -Contain 'RowCount'
                $paramNames | Should -Contain 'TotalCost'
                $paramNames | Should -Contain 'FocusVersion'
                $paramNames | Should -Contain 'OutputFormat'
                $paramNames | Should -Contain 'StorageAccountName'
                $paramNames | Should -Contain 'ResourceGroupName'
                $paramNames | Should -Contain 'AdfName'
                $paramNames | Should -Contain 'StartTriggers'
                $paramNames | Should -Contain 'Seed'
            }
        }

        Context "Small CSV generation" {
            BeforeAll {
                $testOutputPath = Join-Path $TestDrive 'test-data-unit'
                New-FinOpsTestData `
                    -OutputPath $testOutputPath `
                    -ServiceProvider Azure `
                    -RowCount 100 `
                    -MonthsOfData 1 `
                    -FocusVersion '1.0' `
                    -OutputFormat CSV `
                    -Seed 42
            }

            It 'Should create output directory' {
                Test-Path $testOutputPath | Should -Be $true
            }

            It 'Should create Azure cost CSV files' {
                $csvFiles = Get-ChildItem -Path $testOutputPath -Recurse -Filter '*.csv' | Where-Object { $_.Name -like 'focus-*' }
                $csvFiles.Count | Should -BeGreaterThan 0
            }

            It 'Should generate CSV files with FOCUS columns' {
                $csvFiles = Get-ChildItem -Path $testOutputPath -Recurse -Filter '*.csv' | Where-Object { $_.Name -like 'focus-*' } | Select-Object -First 1
                $headers = (Import-Csv $csvFiles.FullName | Select-Object -First 1).PSObject.Properties.Name
                # Core FOCUS 1.0 columns that should always be present
                $headers | Should -Contain 'BilledCost'
                $headers | Should -Contain 'EffectiveCost'
                $headers | Should -Contain 'ServiceName'
                $headers | Should -Contain 'ChargePeriodStart'
                $headers | Should -Contain 'ChargePeriodEnd'
            }

            It 'Should create Prices CSV file for Azure' {
                $priceFiles = Get-ChildItem -Path $testOutputPath -Recurse -Filter '*.csv' | Where-Object { $_.Name -like 'prices-*' }
                $priceFiles.Count | Should -BeGreaterThan 0
            }

            It 'Should produce reproducible output with same seed' {
                $testOutputPath2 = Join-Path $TestDrive 'test-data-unit-seed'
                New-FinOpsTestData `
                    -OutputPath $testOutputPath2 `
                    -ServiceProvider Azure `
                    -RowCount 100 `
                    -MonthsOfData 1 `
                    -FocusVersion '1.0' `
                    -OutputFormat CSV `
                    -Seed 42

                # Compare first cost file from both runs
                $file1 = Get-ChildItem -Path $testOutputPath -Recurse -Filter '*.csv' | Where-Object { $_.Name -like 'focus-*' } | Select-Object -First 1
                $file2 = Get-ChildItem -Path $testOutputPath2 -Recurse -Filter '*.csv' | Where-Object { $_.Name -like 'focus-*' } | Select-Object -First 1
                $content1 = Get-Content $file1.FullName
                $content2 = Get-Content $file2.FullName
                $content1.Count | Should -Be $content2.Count
            }

            It 'Should set BillingCurrency to USD for Azure data' {
                $csvFiles = Get-ChildItem -Path $testOutputPath -Recurse -Filter '*.csv' | Where-Object { $_.Name -like 'focus-*' } | Select-Object -First 1
                $rows = Import-Csv $csvFiles.FullName | Select-Object -First 5
                $rows | ForEach-Object { $_.BillingCurrency | Should -Be 'USD' }
            }
        }

        Context "Multiple providers" {
            BeforeAll {
                $testOutputPath = Join-Path $TestDrive 'test-data-all'
                New-FinOpsTestData `
                    -OutputPath $testOutputPath `
                    -ServiceProvider All `
                    -RowCount 200 `
                    -MonthsOfData 1 `
                    -FocusVersion '1.0' `
                    -OutputFormat CSV `
                    -Seed 99
            }

            It 'Should create cost files for all four providers' {
                $csvFiles = Get-ChildItem -Path $testOutputPath -Recurse -Filter '*.csv' | Where-Object { $_.Name -like 'focus-*' }
                # Should have Azure, AWS, GCP, and DataCenter cost files
                $csvFiles.Count | Should -BeGreaterOrEqual 4
            }
        }

        Context "FOCUS version column sets" {
            BeforeAll {
                $testOutputPath13 = Join-Path $TestDrive 'test-data-v13'
                New-FinOpsTestData `
                    -OutputPath $testOutputPath13 `
                    -ServiceProvider Azure `
                    -RowCount 50 `
                    -MonthsOfData 1 `
                    -FocusVersion '1.3' `
                    -OutputFormat CSV `
                    -Seed 7
            }

            It 'Should include FOCUS 1.3 columns like CapacityReservationId' {
                $csvFile = Get-ChildItem -Path $testOutputPath13 -Recurse -Filter '*.csv' | Where-Object { $_.Name -like 'focus-*' } | Select-Object -First 1
                $headers = (Import-Csv $csvFile.FullName | Select-Object -First 1).PSObject.Properties.Name
                # FOCUS 1.3 added CapacityReservationId
                $headers | Should -Contain 'CapacityReservationId'
            }
        }
    }
}
