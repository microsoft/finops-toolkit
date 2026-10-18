# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Start-FinOpsCostExport' {
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

    It 'Should fail if export does not exist' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $null }
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { $null }
        $params = @{
            Name  = $exportName
            Scope = $scope
        }

        # Act
        { Start-FinOpsCostExport @params } | Should -Throw

        # Assert
        Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' -Times 1
    }

    It 'Should call /run with default dates' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $mockExport }
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { @{ Success = $true } }
        $params = @{
            Name  = $exportName
            Scope = $scope
        }

        # Act
        $success = Start-FinOpsCostExport @params

        # Assert
        Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 `
            -ParameterFilter { return $body -eq $null }
        $success | Should -Be $true
    }

    It 'Should call /run with default end date' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $mockExport }
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { @{ Success = $true } }
        $params = @{
            Name      = $exportName
            Scope     = $scope
            StartDate = [datetime]'2024-01-01'
        }

        # Act
        $success = Start-FinOpsCostExport @params

        # Assert
        Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -Exactly `
            -ParameterFilter { $body.timePeriod.from -eq '2024-01-01T00:00:00Z' -and $body.timePeriod.to -eq '2024-01-31T00:00:00Z' }
        $success | Should -Be $true
    }

    It 'Should call /run with start/end dates' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $mockExport }
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { @{ Success = $true } }
        $params = @{
            Name      = $exportName
            Scope     = $scope
            StartDate = Get-Date -Year 2024 -Month 6 -Day 10 -Hour 0 -Minute 0 -Second 0 -Millisecond 0
            EndDate   = Get-Date -Year 2024 -Month 6 -Day 20 -Hour 0 -Minute 0 -Second 0 -Millisecond 0
        }

        # Act
        $success = Start-FinOpsCostExport @params

        # Assert
        Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -Exactly `
            -ParameterFilter { $body.timePeriod.from -eq '2024-06-10T00:00:00Z' -and $body.timePeriod.to -eq '2024-06-20T00:00:00Z' }
        $success | Should -Be $true
    }

    It 'Should use the requested calendar dates regardless of the local time zone' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $mockExport }
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { @{ Success = $true } }

        # Local midnight converts to the previous day in UTC for any positive offset, which used
        # to shift the exported period back a day for callers east of UTC. Cover every DateTimeKind
        # the parameter binder can produce so the dates are never time zone converted.
        $params = @{
            Name      = $exportName
            Scope     = $scope
            StartDate = [datetime]::SpecifyKind([datetime]'2024-03-01', [DateTimeKind]::Local)
            EndDate   = [datetime]::SpecifyKind([datetime]'2024-03-31', [DateTimeKind]::Unspecified)
        }

        # Act
        $success = Start-FinOpsCostExport @params

        # Assert
        Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -Exactly `
            -ParameterFilter { $body.timePeriod.from -eq '2024-03-01T00:00:00Z' -and $body.timePeriod.to -eq '2024-03-31T00:00:00Z' }
        $success | Should -Be $true
    }

    It 'Should call /run for backfill' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $mockExport }
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { @{ Success = $true } }
        $today = (Get-Date).ToUniversalTime().Date
        $startOfMonth = $today.AddDays(1 - $today.Day)
        $params = @{
            Name     = $exportName
            Scope    = $scope
            Backfill = 3
        }

        # Act
        $success = Start-FinOpsCostExport @params

        # Assert
        Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times ($params.Backfill + 1) -Exactly
        Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -Exactly -ParameterFilter {
            $body.timePeriod.from -eq $startOfMonth.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") `
                -and $body.timePeriod.to -eq $today.AddDays(-1).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
        }
        foreach ($i in 1..($params.Backfill))
        {
            Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -Exactly -ParameterFilter {
                $startDate = $startOfMonth.AddMonths($i * -1)
                $body.timePeriod.from -eq $startDate.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") `
                    -and $body.timePeriod.to -eq $startDate.AddMonths(1).AddMilliseconds(-1).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
            }
        }
        $success | Should -Be $true
    }

    It 'Should report status when exporting multiple months' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $mockExport }
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { @{ Success = $true } }
        Mock -ModuleName FinOpsToolkit -CommandName 'Write-Progress' {}

        # Act
        $success = Start-FinOpsCostExport `
            -Name $exportName `
            -Scope $scope `
            -Backfill 3

        # Assert
        Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Write-Progress' -Times 4
        $success | Should -Be $true
    }

    It 'Should adjust end date if it would be in the future' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $mockExport }
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { @{ Success = $true } }

        # Set up dates for current month
        $today = (Get-Date).ToUniversalTime().Date
        $firstDayOfCurrentMonth = $today.AddDays(1 - $today.Day)
        $lastDayOfCurrentMonth = $firstDayOfCurrentMonth.AddMonths(1).AddDays(-1)

        # If testing in the last day of the month, this test might not be relevant
        # So we'll only run it if the last day of month is in the future
        if ($lastDayOfCurrentMonth -gt $today)
        {
            $params = @{
                Name      = $exportName
                Scope     = $scope
                StartDate = $firstDayOfCurrentMonth
                EndDate   = $lastDayOfCurrentMonth
            }

            # Act
            $success = Start-FinOpsCostExport @params

            # Assert
            Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 `
                -ParameterFilter {
                $body.timePeriod.from -eq $firstDayOfCurrentMonth.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") -and
                $body.timePeriod.to -eq $today.AddDays(-1).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
            }
            $success | Should -Be $true
        }
    }

    It 'Should retry the same month when throttled' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $mockExport }
        Mock -ModuleName FinOpsToolkit -CommandName 'Write-Progress' {}

        # Mock Invoke-Rest to return throttled on first call, then success on second call
        $script:callCounter = 0
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' {
            $script:callCounter++
            if ($script:callCounter -eq 1)
            {
                return @{
                    Success   = $false
                    Throttled = $true
                }
            }
            else
            {
                return @{
                    Success   = $true
                    Throttled = $false
                }
            }
        }

        # Force sleep to return immediately to speed up test
        Mock -ModuleName FinOpsToolkit -CommandName 'Start-Sleep' {}

        $params = @{
            Name     = $exportName
            Scope    = $scope
            Backfill = 1  # Just one month to simplify testing
        }

        # Act
        $success = Start-FinOpsCostExport @params

        # Assert
        Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 2
        Should -Invoke -ModuleName FinOpsToolkit -CommandName 'Start-Sleep' -Times 1
        $success | Should -Be $true
    }
}
