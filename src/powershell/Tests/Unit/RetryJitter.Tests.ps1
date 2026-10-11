# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'Retry backoff jitter' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:MultitoolModule = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool/FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    Context 'Computed backoff' {
        It 'Stays within the equal-jitter band for <Base>s' -ForEach @(
            @{ Base = 2 }
            @{ Base = 10 }
            @{ Base = 30 }
            @{ Base = 60 }
        ) {
            foreach ($i in 1..200) {
                $d = Get-JitteredDelay -BaseSeconds $Base
                $d | Should -BeGreaterOrEqual ($Base / 2)
                $d | Should -BeLessOrEqual $Base
            }
        }

        It 'Never returns a negative delay' {
            Get-JitteredDelay -BaseSeconds 0 | Should -Be 0
            Get-JitteredDelay -BaseSeconds -5 | Should -Be 0
        }

        It 'Actually decorrelates - repeated calls are not all identical' {
            $seen = 1..50 | ForEach-Object { Get-JitteredDelay -BaseSeconds 10 }
            (@($seen | Select-Object -Unique)).Count | Should -BeGreaterThan 1
        }
    }

    Context 'Server-supplied Retry-After' {
        It 'Treats Retry-After as a floor and never sleeps less' {
            foreach ($i in 1..200) {
                $d = Get-JitteredDelay -RetryAfterSeconds 5
                $d | Should -BeGreaterOrEqual 5
                $d | Should -BeLessOrEqual 6
            }
        }

        It 'Clamps a nonsensical negative Retry-After to zero' {
            $d = Get-JitteredDelay -RetryAfterSeconds -10
            $d | Should -BeGreaterOrEqual 0
            $d | Should -BeLessOrEqual 1
        }
    }

    Context 'REST response backoff' {
        It 'Stops before a retry exceeds the wait budget (<Scenario>)' -ForEach @(
            @{ Scenario = 'hour-long throttle'; Delay = '3600'; Status = 429; Budget = 120; ExpectedCalls = 1; ExpectedWaits = 0 }
            @{ Scenario = 'millisecond overflow'; Delay = '2147484'; Status = 429; Budget = 120; ExpectedCalls = 1; ExpectedWaits = 0 }
            @{ Scenario = 'cumulative waits'; Delay = '70'; Status = 429; Budget = 120; ExpectedCalls = 2; ExpectedWaits = 1 }
            @{ Scenario = 'disabled waits'; Delay = '30'; Status = 429; Budget = 0; ExpectedCalls = 1; ExpectedWaits = 0 }
            @{ Scenario = 'service unavailable'; Delay = '3600'; Status = 503; Budget = 120; ExpectedCalls = 1; ExpectedWaits = 0 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Delay = $Delay; Status = $Status; Budget = $Budget; ExpectedCalls = $ExpectedCalls; ExpectedWaits = $ExpectedWaits } {
                param($Delay, $Status, $Budget, $ExpectedCalls, $ExpectedWaits)
                $httpResponse = [Net.Http.HttpResponseMessage]::new([Net.HttpStatusCode]$Status)
                $headerName = if ($Status -eq 429) { 'x-ms-ratelimit-microsoft.costmanagement-qpu-retry-after' } else { 'Retry-After' }
                $null = $httpResponse.Headers.TryAddWithoutValidation($headerName, $Delay)
                $fixture = [hashtable]::Synchronized(@{ Status = $Status; Headers = $httpResponse.Headers; Calls = 0 })
                $sessionState = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
                $sessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('Fixture', $fixture, 'Synthetic retry budget'))
                $sessionState.Commands.Add([Management.Automation.Runspaces.SessionStateFunctionEntry]::new('Invoke-AzRestMethod', @'
param($Path, $Method, $Payload)
$Fixture.Calls++
[pscustomobject]@{ StatusCode = $Fixture.Status; Content = '{}'; Headers = $Fixture.Headers }
'@))
                $pool = [runspacefactory]::CreateRunspacePool(1, 1, $sessionState, $Host)
                $previousPool = $script:RunspacePool
                Mock Get-JitteredDelay { if ($RetryAfterSeconds -gt 0) { $RetryAfterSeconds } else { $BaseSeconds } }
                Mock Wait-WithDispatcher { }
                Mock Write-Host { }
                Mock Write-Warning { }
                try {
                    $pool.Open()
                    $script:RunspacePool = $pool
                    $response = Invoke-AzRestMethodWithRetry -Path '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.CostManagement/query?api-version=2023-11-01' -Payload '{}' -MaxRetryWaitSeconds $Budget

                    $response.StatusCode | Should -Be $Status
                    $response.Headers[$headerName] | Should -Contain $Delay
                    $fixture.Calls | Should -Be $ExpectedCalls
                    Should -Invoke Wait-WithDispatcher -Times $ExpectedWaits -Exactly
                    Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "*retry requires $Delay seconds*No early retry*" }
                }
                finally {
                    $script:RunspacePool = $previousPool
                    $pool.Dispose()
                    $httpResponse.Dispose()
                }
            }
        }

        It 'Honors <Scenario> without increasing the retry count' -ForEach @(
            @{ Scenario = 'Cost Management QPU delay'; Status = 429; Headers = @{ 'x-ms-ratelimit-microsoft.costmanagement-qpu-retry-after' = '70' }; ExpectedDelay = 70 }
            @{ Scenario = 'Consumption delay'; Status = 429; Headers = @{ 'x-ms-ratelimit-microsoft.consumption-retry-after' = '45' }; ExpectedDelay = 45 }
            @{ Scenario = 'longest applicable delay'; Status = 429; Headers = @{ 'Retry-After' = '5'; 'x-ms-ratelimit-microsoft.costmanagement-qpu-retry-after' = '70' }; ExpectedDelay = 70 }
            @{ Scenario = 'multiple header values'; Status = 429; Headers = @{ 'x-ms-ratelimit-microsoft.costmanagement-qpu-retry-after' = @('20', '35') }; ExpectedDelay = 35 }
            @{ Scenario = 'standard delay'; Status = 429; Headers = @{ 'Retry-After' = '30' }; ExpectedDelay = 30 }
            @{ Scenario = 'invalid standard header with valid QPU delay'; Status = 429; Headers = @{ 'Retry-After' = 'invalid'; 'x-ms-ratelimit-microsoft.costmanagement-qpu-retry-after' = '20' }; ExpectedDelay = 20 }
            @{ Scenario = 'invalid delays use computed backoff'; Status = 429; Headers = @{ 'Retry-After' = 'invalid'; 'x-ms-ratelimit-microsoft.costmanagement-qpu-retry-after' = '-1' }; ExpectedDelay = 10 }
            @{ Scenario = 'service-unavailable standard delay'; Status = 503; Headers = @{ 'Retry-After' = '30' }; ExpectedDelay = 30 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Status = $Status; Headers = $Headers; ExpectedDelay = $ExpectedDelay } {
                param($Status, $Headers, $ExpectedDelay)
                $httpResponse = [Net.Http.HttpResponseMessage]::new([Net.HttpStatusCode]$Status)
                foreach ($header in $Headers.GetEnumerator()) {
                    $null = $httpResponse.Headers.TryAddWithoutValidation($header.Key, [string[]]@($header.Value))
                }
                $fixture = [hashtable]::Synchronized(@{ Status = $Status; Headers = $httpResponse.Headers; Calls = 0 })
                $sessionState = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
                $sessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('Fixture', $fixture, 'Synthetic throttle response'))
                $sessionState.Commands.Add([Management.Automation.Runspaces.SessionStateFunctionEntry]::new('Invoke-AzRestMethod', @'
param($Path, $Method, $Payload)
$Fixture.Calls++
[pscustomobject]@{ StatusCode = $Fixture.Status; Content = '{}'; Headers = $Fixture.Headers }
'@))
                $pool = [runspacefactory]::CreateRunspacePool(1, 1, $sessionState, $Host)
                $previousPool = $script:RunspacePool
                Mock Get-JitteredDelay { if ($RetryAfterSeconds -gt 0) { $RetryAfterSeconds } else { $BaseSeconds } }
                Mock Wait-WithDispatcher { }
                Mock Write-Host { }
                try {
                    $pool.Open()
                    $script:RunspacePool = $pool
                    $response = Invoke-AzRestMethodWithRetry -Path '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.CostManagement/query?api-version=2023-11-01' -Payload '{}' -MaxRetries 1

                    $response.StatusCode | Should -Be $Status
                    $fixture.Calls | Should -Be 2
                    Should -Invoke Wait-WithDispatcher -Times 1 -Exactly
                    Should -Invoke Wait-WithDispatcher -Times 1 -Exactly -ParameterFilter { $Milliseconds -eq $ExpectedDelay * 1000 }
                }
                finally {
                    $script:RunspacePool = $previousPool
                    $pool.Dispose()
                    $httpResponse.Dispose()
                }
            }
        }
    }
}
