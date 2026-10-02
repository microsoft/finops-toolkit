# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$modulePath = Join-Path $PSScriptRoot '../../../../src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Quota/AzVMQuotaUsage/AzVMQuotaUsage.psm1'
Import-Module $modulePath -Force

AfterAll {
    Remove-Module AzVMQuotaUsage
}

Describe 'HubsQuotaCollection' {
    InModuleScope AzVMQuotaUsage {
        BeforeEach {
            $script:subscriptions = @(1..7 | ForEach-Object {
                [pscustomobject]@{ subscriptionId = "sub$_"; id = "/subscriptions/sub$_"; displayName = "Subscription $_" }
            })
            $script:locations = @('eastus', 'westus')
            $script:calls = [Collections.Generic.List[object]]::new()
            $script:failedSource = ''
            $script:throwSecondBatch = $false
            $script:emptyResponses = $false
            $script:token = ConvertTo-SecureString 'test-token' -AsPlainText -Force
            $script:output = Join-Path $TestDrive "Quota-$([guid]::NewGuid()).csv"
            Mock Get-Subscriptions { $script:subscriptions }
            Mock Get-Locations { $script:locations }
            Mock Get-ArmResponses {
                param($Requests, $Client, $ConcurrentSubscriptions, $ConcurrentRequests)
                $ids = @($Requests | ForEach-Object { $_.Subscription.subscriptionId } | Select-Object -Unique)
                $script:calls.Add([pscustomobject]@{
                    Subscriptions = $ids
                    Count = $Requests.Count
                    Client = $Client
                    SubscriptionLimit = $ConcurrentSubscriptions
                    RequestLimit = $ConcurrentRequests
                    IsZone = -not $Requests[0].SourceType
                })
                if ($script:throwSecondBatch -and $ids -contains 'sub4') { throw 'Simulated collection failure' }
                if ($script:emptyResponses) { return }
                foreach ($request in $Requests) {
                    $data = @()
                    if (-not $request.SourceType) {
                        $physical = ([int]$request.Subscription.subscriptionId.Substring(3) % 3) + 1
                        $data = @($script:locations | ForEach-Object {
                            [pscustomobject]@{
                                id = "$($request.Subscription.id)/locations/$_"
                                name = $_
                                type = 'Region'
                                availabilityZoneMappings = @([pscustomobject]@{logicalZone='1';physicalZone="$_-az$physical"})
                            }
                        })
                    }
                    elseif ($request.SourceType -eq 'ComputeResourceSku') {
                        $data = @([pscustomobject]@{
                            name='Standard_D2s_v5';resourceType='virtualMachines';family='standardDv5Family';tier='Standard';size='D2s_v5'
                            locationInfo=@([pscustomobject]@{location=$request.Location;zones=@('1')})
                            restrictions=@()
                        })
                    }
                    elseif ($request.IsResourceList) {
                        $data = @([pscustomobject]@{
                            id="$($request.Subscription.id)/resources/$($request.SourceType)"
                            name=$request.SourceType;type='Microsoft.Compute/disks';location='eastus'
                            properties=[pscustomobject]@{diskSizeGB=32}
                        })
                    }
                    else {
                        $data = @([pscustomobject]@{
                            name=[pscustomobject]@{value='standardDv5Family';localizedValue='Quota'}
                            currentValue=1;limit=10;unit='Count'
                        })
                    }
                    $errorMessage = if ($request.SourceType -eq $script:failedSource) { 'HTTP 400' } else { $null }
                    @{ Request=$request;Data=$data;Error=$errorMessage }
                }
            }
        }

        It 'Bounds each queue by the subscription limit and uses one HTTP client and output file' {
            Get-AzVMQuotaUsage -AccessToken $script:token -ConcurrentSubscriptions 3 -OutputFile $script:output
            $script:calls.Count | Should -Be 6
            @($script:calls | Where-Object { $_.Subscriptions.Count -gt 3 -or $_.Count -gt 72 }).Count | Should -Be 0
            @($script:calls | Where-Object IsZone | ForEach-Object { $_.Subscriptions.Count }) | Should -Be @(3,3,1)
            @($script:calls | Where-Object { $_.SubscriptionLimit -ne 3 -or $_.RequestLimit -ne 16 }).Count | Should -Be 0
            foreach ($call in $script:calls) { [object]::ReferenceEquals($call.Client, $script:calls[0].Client) | Should -BeTrue }
            @(Import-Csv $script:output).Count | Should -Be 182
            @(Get-Content $script:output | Where-Object { $_ -like 'ProviderName,*' }).Count | Should -Be 1
        }

        It 'Preserves every subscription, source type, and physical zone mapping across batch boundaries' {
            Get-AzVMQuotaUsage -AccessToken $script:token -ConcurrentSubscriptions 3 -OutputFile $script:output
            $rows = @(Import-Csv $script:output)
            @($rows.SubAccountId | Sort-Object -Unique).Count | Should -Be 7
            @($rows.x_SourceType | Sort-Object -Unique).Count | Should -Be 14
            foreach ($subscription in $script:subscriptions) {
                @($rows | Where-Object SubAccountId -eq $subscription.id).Count | Should -Be 26
                $expectedZone = [string](([int]$subscription.subscriptionId.Substring(3) % 3) + 1)
                foreach ($row in $rows | Where-Object { $_.SubAccountId -eq $subscription.id -and $_.x_SourceType -eq 'ComputeResourceSku' }) {
                    ($row.x_QuotaDetails | ConvertFrom-Json).ZonesPresent | Should -Be $expectedZone
                    $row.currentValue | Should -BeNullOrEmpty
                }
            }
        }

        It 'Keeps the 61-region request queue bounded when the tenant spans more than two default batches' {
            $script:subscriptions = @(1..129 | ForEach-Object {
                [pscustomobject]@{subscriptionId="sub$_";id="/subscriptions/sub$_";displayName="Subscription $_"}
            })
            $script:locations = @(1..61 | ForEach-Object { "region$_" })
            $script:emptyResponses = $true
            Get-AzVMQuotaUsage -AccessToken $script:token -OutputFile $script:output
            $script:calls.Count | Should -Be 6
            @($script:calls | Where-Object { $_.Subscriptions.Count -gt 64 -or $_.Count -gt 43072 }).Count | Should -Be 0
            @($script:calls | Where-Object { -not $_.IsZone } | ForEach-Object Count) | Should -Be @(43072,43072,673)
            @($script:calls | Where-Object { -not $_.IsZone } | ForEach-Object { $_.Subscriptions } | Sort-Object -Unique).Count | Should -Be 129
        }

        It 'Logs a failed provider response without losing the other sources or subscriptions' {
            $script:failedSource = 'StorageUsage'
            Get-AzVMQuotaUsage -AccessToken $script:token -ConcurrentSubscriptions 3 -OutputFile $script:output `
                -WarningAction SilentlyContinue -WarningVariable warnings
            $warnings.Count | Should -Be 14
            $warnings[0].Message | Should -Match 'StorageUsage.*HTTP 400'
            $rows = @(Import-Csv $script:output)
            $rows.Count | Should -Be 168
            @($rows | Where-Object x_SourceType -eq 'ComputeUsage').Count | Should -Be 14
            @($rows.SubAccountId | Sort-Object -Unique).Count | Should -Be 7
        }

        It 'Reports completed requests and rows rather than only host activity' {
            Get-AzVMQuotaUsage -AccessToken $script:token -ConcurrentSubscriptions 3 -OutputFile $script:output `
                -InformationVariable messages
            $progress = @($messages | ForEach-Object { "$($_.MessageData)" } | Where-Object { $_ -like 'Quota progress:*' })
            $progress.Count | Should -Be 4
            $progress[-1] | Should -Match 'subscriptions=7/7; requests=175/175; rows=182; bytes=[1-9]\d*'
        }

        It 'Propagates fatal collection failures and closes the partial CSV' {
            $script:throwSecondBatch = $true
            { Get-AzVMQuotaUsage -AccessToken $script:token -ConcurrentSubscriptions 3 -OutputFile $script:output } |
                Should -Throw '*Simulated collection failure*'
            $stream = [IO.File]::Open($script:output, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            $stream.Dispose()
            @(Import-Csv $script:output).Count | Should -Be 78
        }

        It 'Refreshes the ARM token once per batch and rejects invalid or failed token renewal' {
            $state = @{Calls=0}
            $provider = { $state.Calls++; ConvertTo-SecureString "batch-token-$($state.Calls)" -AsPlainText -Force }.GetNewClosure()
            Get-AzVMQuotaUsage -AccessToken $script:token -AccessTokenProvider $provider `
                -ConcurrentSubscriptions 3 -OutputFile $script:output
            $state.Calls | Should -Be 3
            @(Import-Csv $script:output).Count | Should -Be 182
            { Get-AzVMQuotaUsage -AccessToken $script:token -AccessTokenProvider { 'not-a-secure-token' } -OutputFile $script:output } |
                Should -Throw '*must return one secure string*'
            { Get-AzVMQuotaUsage -AccessToken $script:token -AccessTokenProvider { throw 'Token renewal failed' } -OutputFile $script:output } |
                Should -Throw '*Token renewal failed*'
        }

        It 'Rejects a zero subscription limit and an empty subscription list before creating a CSV' {
            { Get-AzVMQuotaUsage -AccessToken $script:token -ConcurrentSubscriptions 0 -OutputFile $script:output } | Should -Throw
            $script:subscriptions = @()
            { Get-AzVMQuotaUsage -AccessToken $script:token -OutputFile $script:output } | Should -Throw '*No accessible subscriptions*'
            Test-Path $script:output | Should -BeFalse
        }
    }
}
