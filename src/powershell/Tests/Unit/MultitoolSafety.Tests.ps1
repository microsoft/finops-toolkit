# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

& "$PSScriptRoot/../Initialize-Tests.ps1"

Describe 'FinOps Multitool safety' {

    # Scoped to this Describe: Initialize-Tests.ps1 already declares a root-level
    # BeforeAll, and Pester 6 rejects a second one during discovery.
    BeforeAll {
        $script:ModuleRoot = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool'
        $script:MultitoolModule = Join-Path $script:ModuleRoot 'FinOpsMultitool.psm1'
        Import-Module $script:MultitoolModule -Force
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    Context 'Every command the module calls actually resolves' {

        # A cleanup commit once deleted a helper and left its caller behind, so
        # the scan threw CommandNotFoundException on its normal success path.
        It 'Has no calls to undefined internal commands' {
            $files = Get-ChildItem -Path $script:ModuleRoot -Recurse -Include *.ps1, *.psm1 -File

            # Sibling private functions live one level up and are legitimate callees.
            $defFiles = Get-ChildItem -Path (Join-Path $script:ModuleRoot '..') -Recurse -Include *.ps1, *.psm1 -File

            $defined = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase)
            $optional = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase)
            $called = @{}

            foreach ($file in $defFiles) {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $file.FullName, [ref]$null, [ref]$null)
                foreach ($fn in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
                    [void]$defined.Add($fn.Name)
                }
            }

            foreach ($file in $files) {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $file.FullName, [ref]$null, [ref]$null)

                foreach ($cmd in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                    $name = $cmd.GetCommandName()
                    if (-not $name) { continue }

                    # A name probed through Get-Command is an optional callback,
                    # so its absence is deliberate rather than a broken call.
                    if ($name -eq 'Get-Command') {
                        foreach ($el in $cmd.CommandElements) {
                            if ($el -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                                [void]$optional.Add($el.Value)
                            }
                        }
                        continue
                    }

                    if (-not $called.ContainsKey($name)) {
                        $called[$name] = '{0}:{1}' -f $file.Name, $cmd.Extent.StartLineNumber
                    }
                }
            }

            # Az cmdlets are excluded so the assertion does not depend on which
            # Az modules happen to be installed on the runner.
            $unresolved = foreach ($name in $called.Keys) {
                if ($defined.Contains($name)) { continue }
                if ($optional.Contains($name)) { continue }
                if ($name -match '^(Az|AzureRm)' -or $name -match '-Az') { continue }
                if (Get-Command -Name $name -ErrorAction SilentlyContinue) { continue }
                '{0}  (called at {1})' -f $name, $called[$name]
            }

            @($unresolved) -join "`n" | Should -BeNullOrEmpty
        }
    }

    Context 'Allocation percentages' {

        It 'Normalizes uneven shares to exactly 100' {
            $r = ConvertTo-AllocationPercentage -Targets @(
                @{ subscriptionId = 'a'; allocatedShared = 33.333 }
                @{ subscriptionId = 'b'; allocatedShared = 33.333 }
                @{ subscriptionId = 'c'; allocatedShared = 33.334 }
            )

            $r.Ok | Should -BeTrue
            ($r.Values | ForEach-Object { $_.percentage } | Measure-Object -Sum).Sum | Should -Be 100
        }

        It 'Reports failure instead of inventing percentages' {
            (ConvertTo-AllocationPercentage -Targets @()).Ok | Should -BeFalse
            (ConvertTo-AllocationPercentage -Targets @(
                    @{ subscriptionId = 'a'; allocatedShared = 0 }
                )).Ok | Should -BeFalse
        }
    }

    Context 'Export amounts parse invariantly' {

        It 'Reads a decimal point as a decimal point regardless of culture' {
            $original = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try {
                # In de-DE '.' is the thousands separator, so a culture-sensitive
                # parse turns 123.45 into 12345.
                [System.Threading.Thread]::CurrentThread.CurrentCulture =
                [System.Globalization.CultureInfo]::new('de-DE')

                ConvertTo-ExportAmount '123.45' | Should -Be 123.45
                ConvertTo-ExportAmount '1,234.56' | Should -Be 1234.56
            }
            finally {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $original
            }
        }

        It 'Returns zero for values that are not numbers' {
            ConvertTo-ExportAmount 'not-a-number' | Should -Be 0
            ConvertTo-ExportAmount '' | Should -Be 0
        }
    }

    Context 'KQL literal escaping' {

        It 'Leaves no quote that could terminate the enclosing literal' {
            $escaped = ConvertTo-KqlLiteral "Subscription Id']) | extend injected = true //"
            [regex]::Matches($escaped, "(?<!\\)'").Count | Should -Be 0
        }

        It 'Escapes the backslash before the quote so evasion fails' {
            # Escaping in the other order would leave \' exploitable.
            $escaped = ConvertTo-KqlLiteral "abc\' or 1==1 //"
            [regex]::Matches($escaped, "(?<!\\)'").Count | Should -Be 0
            $escaped | Should -BeExactly "abc\\\' or 1==1 //"
        }
    }

    Context 'Hub subscription scope clause' {

        It 'Returns no clause only when no subscription was requested' {
            Get-FOHubScopeClause -SubscriptionIds @() | Should -BeNullOrEmpty
        }

        It 'Scopes the query to the requested subscriptions' {
            $clause = Get-FOHubScopeClause -SubscriptionIds @('00000000-0000-0000-0000-00000000000a')
            $clause | Should -Match 'SubAccountId has_any'
            $clause | Should -Match '00000000-0000-0000-0000-00000000000a'
        }

        It 'Fails rather than dropping the filter for an unparseable id' {
            # The old character-class check passed 36 hyphens, then an empty
            # clause returned every subscription in the hub.
            { Get-FOHubScopeClause -SubscriptionIds @('------------------------------------') } |
            Should -Throw -ExpectedMessage '*not a subscription GUID*'
            { Get-FOHubScopeClause -SubscriptionIds @('/subscriptions/00000000-0000-0000-0000-00000000000a') } |
            Should -Throw
        }
    }

    Context 'Gzip expansion is bounded' {

        It 'Round-trips content that fits the budget' {
            $text = 'hello world'
            $raw = [System.Text.Encoding]::UTF8.GetBytes($text)
            $ms = [System.IO.MemoryStream]::new()
            $gz = [System.IO.Compression.GZipStream]::new($ms, [System.IO.Compression.CompressionMode]::Compress)
            $gz.Write($raw, 0, $raw.Length)
            $gz.Dispose()

            Expand-GzipText -Content $ms.ToArray() | Should -Be $text
        }

        It 'Refuses to expand past the byte ceiling' {
            # Highly compressible input stands in for a hostile blob in the
            # export container.
            $raw = [byte[]]::new(1MB)
            $ms = [System.IO.MemoryStream]::new()
            $gz = [System.IO.Compression.GZipStream]::new($ms, [System.IO.Compression.CompressionMode]::Compress)
            $gz.Write($raw, 0, $raw.Length)
            $gz.Dispose()

            Expand-GzipText -Content $ms.ToArray() -MaxBytes 1024 -WarningAction SilentlyContinue |
            Should -BeNullOrEmpty
        }
    }
}
