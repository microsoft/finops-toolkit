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
        Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' -Times 1
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
        Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 `
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
            StartDate = Get-Date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0 -AsUTC
        }

        # Act
        $success = Start-FinOpsCostExport @params

        # Assert
        Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 `
            -ParameterFilter { $body.timePeriod.from -eq $params.StartDate.ToUniversalTime().ToString("yyyy-01-01'T'00:00:00'Z'") -and $body.timePeriod.to -eq $params.StartDate.ToUniversalTime().ToString("yyyy-01-31'T'00:00:00'Z'") }
        $success | Should -Be $true
    }

    It 'Should call /run with start/end dates' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $mockExport }
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { @{ Success = $true } }
        $params = @{
            Name      = $exportName
            Scope     = $scope
            StartDate = (Get-Date).AddDays(-7)
            EndDate   = (Get-Date).AddDays(-2)
        }

        # Act
        $success = Start-FinOpsCostExport @params

        # Assert
        Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 `
            -ParameterFilter { $body.timePeriod.from -eq $params.StartDate.ToUniversalTime().Date.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") -and $body.timePeriod.to -eq $params.EndDate.ToUniversalTime().Date.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") }
        $success | Should -Be $true
    }

    It 'Should call /run for backfill' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $mockExport }
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { @{ Success = $true } }
        $today = (Get-Date).ToUniversalTime().Date
        $startOfMonth = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0 -AsUTC)
        $params = @{
            Name     = $exportName
            Scope    = $scope
            Backfill = 3
        }

        # Act
        $success = Start-FinOpsCostExport @params

        # Assert
        Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times ($params.Backfill + 1)
        Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
            $startDate = $startOfMonth.ToUniversalTime().Date
            $body.timePeriod.from -eq $startDate.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") `
                -and $body.timePeriod.to -eq $today.AddDays(-1).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
        }
        foreach ($i in 1..($params.Backfill))
        {
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 -ParameterFilter {
                $startDate = $startOfMonth.AddMonths($i * -1).ToUniversalTime().Date
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
        Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Write-Progress' -Times 4
        $success | Should -Be $true
    }

    It 'Should adjust end date if it would be in the future' {
        # Arrange
        Mock -ModuleName FinOpsToolkit -CommandName 'Get-FinOpsCostExport' { $mockExport }
        Mock -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' { @{ Success = $true } }

        # Set up dates for current month
        $today = (Get-Date).ToUniversalTime().Date
        $firstDayOfCurrentMonth = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0).ToUniversalTime().Date
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
            Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 1 `
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
        Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Invoke-Rest' -Times 2
        Assert-MockCalled -ModuleName FinOpsToolkit -CommandName 'Start-Sleep' -Times 1
        $success | Should -Be $true
    }
}
