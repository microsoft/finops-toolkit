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
            @{ Scenario = 'hour-long throttle'; Delay = '3600'; Status = 429; Budget = 120; ExpectedCalls = 1; ExpectedWaits = 0; Warning = '*asked for a wait of about 60 minutes*remaining query requests are skipped*' }
            @{ Scenario = 'millisecond overflow'; Delay = '2147484'; Status = 429; Budget = 120; ExpectedCalls = 1; ExpectedWaits = 0; Warning = '*asked for a wait of about 35792 minutes*remaining query requests are skipped*' }
            @{ Scenario = 'cumulative waits'; Delay = '70'; Status = 429; Budget = 120; ExpectedCalls = 2; ExpectedWaits = 1; Warning = '*retry requires 70 seconds*No early retry*' }
            @{ Scenario = 'disabled waits'; Delay = '30'; Status = 429; Budget = 0; ExpectedCalls = 1; ExpectedWaits = 0; Warning = '*retry requires 30 seconds*No early retry*' }
            @{ Scenario = 'service unavailable'; Delay = '3600'; Status = 503; Budget = 120; ExpectedCalls = 1; ExpectedWaits = 0; Warning = '*retry requires 3600 seconds*No early retry*' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Delay = $Delay; Status = $Status; Budget = $Budget; ExpectedCalls = $ExpectedCalls; ExpectedWaits = $ExpectedWaits; Warning = $Warning } {
                param($Delay, $Status, $Budget, $ExpectedCalls, $ExpectedWaits, $Warning)
                Reset-CostMgmtThrottle
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
                    Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like $Warning }
                }
                finally {
                    Reset-CostMgmtThrottle
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
                Reset-CostMgmtThrottle
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
                    Reset-CostMgmtThrottle
                    $script:RunspacePool = $previousPool
                    $pool.Dispose()
                    $httpResponse.Dispose()
                }
            }
        }
    }

    Context 'Cost Management throttle window' {
        BeforeAll {
            # Builds a runspace pool whose Invoke-AzRestMethod replays Fixture.Status with Fixture.Headers,
            # so the retry helper runs unchanged against a synthetic service.
            InModuleScope FinOpsMultitool {
                $script:NewThrottleFixture = {
                    param([int]$Status, [string]$HeaderName, [string]$Delay)
                    $httpResponse = [Net.Http.HttpResponseMessage]::new([Net.HttpStatusCode]$Status)
                    if ($HeaderName) { $null = $httpResponse.Headers.TryAddWithoutValidation($HeaderName, $Delay) }
                    $fixture = [hashtable]::Synchronized(@{ Status = $Status; Headers = $httpResponse.Headers; Calls = 0 })
                    $sessionState = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
                    $sessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('Fixture', $fixture, 'Synthetic throttle window'))
                    $sessionState.Commands.Add([Management.Automation.Runspaces.SessionStateFunctionEntry]::new('Invoke-AzRestMethod', @'
param($Path, $Method, $Payload)
$Fixture.Calls++
[pscustomobject]@{ StatusCode = $Fixture.Status; Content = '{}'; Headers = $Fixture.Headers }
'@))
                    $pool = [runspacefactory]::CreateRunspacePool(1, 1, $sessionState, $Host)
                    $pool.Open()
                    [pscustomobject]@{ Pool = $pool; Fixture = $fixture; Response = $httpResponse }
                }
            }
        }

        BeforeEach {
            InModuleScope FinOpsMultitool { Reset-CostMgmtThrottle }
        }

        AfterEach {
            InModuleScope FinOpsMultitool { Reset-CostMgmtThrottle }
        }

        It 'Skips later <Api> requests once the service asks for a long wait' -ForEach @(
            @{ Api = 'query'; HeaderName = 'x-ms-ratelimit-microsoft.costmanagement-qpu-retry-after'; RequestPath = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.CostManagement/query?api-version=2023-11-01' }
            @{ Api = 'forecast'; HeaderName = 'x-ms-ratelimit-microsoft.consumption-retry-after'; RequestPath = '/providers/Microsoft.Management/managementGroups/example/providers/Microsoft.CostManagement/forecast?api-version=2023-11-01' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Api = $Api; HeaderName = $HeaderName; RequestPath = $RequestPath } {
                param($Api, $HeaderName, $RequestPath)
                $service = & $script:NewThrottleFixture 429 $HeaderName '3600'
                $previousPool = $script:RunspacePool
                Mock Get-JitteredDelay { $RetryAfterSeconds }
                Mock Wait-WithDispatcher { }
                Mock Write-Host { }
                Mock Write-Warning { }
                try {
                    $script:RunspacePool = $service.Pool
                    $first = Invoke-AzRestMethodWithRetry -Path $RequestPath -Payload '{}'
                    $second = Invoke-AzRestMethodWithRetry -Path $RequestPath -Payload '{}'
                    $third = Invoke-AzRestMethodWithRetry -Path $RequestPath -Payload '{}'

                    $service.Fixture.Calls | Should -Be 1
                    $first.Headers[$HeaderName] | Should -Contain '3600'
                    foreach ($skipped in @($second, $third)) {
                        $skipped.StatusCode | Should -Be 429
                        $body = $skipped.Content | ConvertFrom-Json
                        $body.error.code | Should -Be 'TooManyRequests'
                        $body.error.message | Should -Match "limiting this tenant's $Api requests until about \d\d:\d\d UTC"
                        [int]$skipped.Headers['Retry-After'][0] | Should -BeGreaterThan 3500
                    }
                    $summary = @(Get-CostMgmtThrottleSummary)
                    $summary.Count | Should -Be 1
                    $summary[0].Api | Should -Be $Api
                    $summary[0].SkippedRequests | Should -Be 2
                    Should -Invoke Write-Warning -Times 1 -Exactly
                    Should -Invoke Wait-WithDispatcher -Times 0 -Exactly
                }
                finally {
                    $script:RunspacePool = $previousPool
                    $service.Pool.Dispose()
                    $service.Response.Dispose()
                }
            }
        }

        It 'Keeps waiting for a delay it can wait out instead of opening a window' {
            InModuleScope FinOpsMultitool {
                $service = & $script:NewThrottleFixture 429 'x-ms-ratelimit-microsoft.costmanagement-qpu-retry-after' '70'
                $previousPool = $script:RunspacePool
                Mock Get-JitteredDelay { $RetryAfterSeconds }
                Mock Wait-WithDispatcher { }
                Mock Write-Host { }
                Mock Write-Warning { }
                try {
                    $script:RunspacePool = $service.Pool
                    $null = Invoke-AzRestMethodWithRetry -Path '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.CostManagement/query?api-version=2023-11-01' -Payload '{}'

                    Get-CostMgmtThrottleRemaining -Key 'query' | Should -Be 0
                    @(Get-CostMgmtThrottleSummary).Count | Should -Be 0
                    Should -Invoke Write-Warning -Times 0 -Exactly -ParameterFilter { $Message -like '*skipped*' }
                }
                finally {
                    $script:RunspacePool = $previousPool
                    $service.Pool.Dispose()
                    $service.Response.Dispose()
                }
            }
        }

        It 'Skips a request while the window is open, whatever its wait budget (budget: <Budget>)' -ForEach @(
            @{ Budget = 300 }
            @{ Budget = 30 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Budget = $Budget } {
                param($Budget)
                $service = & $script:NewThrottleFixture 200 $null $null
                $previousPool = $script:RunspacePool
                Mock Wait-WithDispatcher { }
                Mock Write-Warning { }
                try {
                    $script:RunspacePool = $service.Pool
                    Register-CostMgmtThrottle -Key 'query' -Seconds 90
                    $response = Invoke-AzRestMethodWithRetry -Path '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.CostManagement/query?api-version=2023-11-01' -Payload '{}' -MaxRetryWaitSeconds $Budget

                    $service.Fixture.Calls | Should -Be 0
                    $response.StatusCode | Should -Be 429
                    Should -Invoke Wait-WithDispatcher -Times 0 -Exactly
                }
                finally {
                    $script:RunspacePool = $previousPool
                    $service.Pool.Dispose()
                    $service.Response.Dispose()
                }
            }
        }

        It 'Sends a request again once the window has ended' {
            InModuleScope FinOpsMultitool {
                $service = & $script:NewThrottleFixture 200 $null $null
                $previousPool = $script:RunspacePool
                Mock Write-Warning { }
                try {
                    $script:RunspacePool = $service.Pool
                    Register-CostMgmtThrottle -Key 'query' -Seconds 90
                    $script:CostMgmtThrottle['query'].Until = [datetime]::UtcNow.AddSeconds(-1)
                    $response = Invoke-AzRestMethodWithRetry -Path '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.CostManagement/query?api-version=2023-11-01' -Payload '{}'

                    $service.Fixture.Calls | Should -Be 1
                    $response.StatusCode | Should -Be 200
                }
                finally {
                    $script:RunspacePool = $previousPool
                    $service.Pool.Dispose()
                    $service.Response.Dispose()
                }
            }
        }

        It 'Leaves other requests alone while a window is open' -ForEach @(
            @{ RequestPath = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Compute/virtualMachines?api-version=2024-07-01'; Method = 'GET' }
            @{ RequestPath = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.CostManagement/exports?api-version=2023-11-01'; Method = 'GET' }
            @{ RequestPath = '/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.CostManagement/forecast?api-version=2023-11-01'; Method = 'POST' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ RequestPath = $RequestPath; Method = $Method } {
                param($RequestPath, $Method)
                $service = & $script:NewThrottleFixture 200 $null $null
                $previousPool = $script:RunspacePool
                Mock Write-Warning { }
                try {
                    $script:RunspacePool = $service.Pool
                    Register-CostMgmtThrottle -Key 'query' -Seconds 3600
                    $response = Invoke-AzRestMethodWithRetry -Path $RequestPath -Method $Method -Payload '{}'

                    $response.StatusCode | Should -Be 200
                    $service.Fixture.Calls | Should -Be 1
                    @(Get-CostMgmtThrottleSummary).Count | Should -Be 0
                }
                finally {
                    $script:RunspacePool = $previousPool
                    $service.Pool.Dispose()
                    $service.Response.Dispose()
                }
            }
        }

        It 'Extends an open window but never shortens it, and warns once' {
            InModuleScope FinOpsMultitool {
                Mock Write-Warning { }

                Register-CostMgmtThrottle -Key 'query' -Seconds 3600
                Register-CostMgmtThrottle -Key 'query' -Seconds 60
                Get-CostMgmtThrottleRemaining -Key 'query' | Should -BeGreaterThan 3500
                Register-CostMgmtThrottle -Key 'query' -Seconds 7200
                Get-CostMgmtThrottleRemaining -Key 'query' | Should -BeGreaterThan 7100

                Should -Invoke Write-Warning -Times 1 -Exactly
            }
        }

        It 'Forgets every window when reset' {
            InModuleScope FinOpsMultitool {
                Mock Write-Warning { }
                Register-CostMgmtThrottle -Key 'query' -Seconds 3600
                Register-CostMgmtThrottle -Key 'forecast' -Seconds 3600

                Reset-CostMgmtThrottle

                Get-CostMgmtThrottleRemaining -Key 'query' | Should -Be 0
                Get-CostMgmtThrottleRemaining -Key 'forecast' | Should -Be 0
                @(Get-CostMgmtThrottleSummary).Count | Should -Be 0
            }
        }
    }
}
