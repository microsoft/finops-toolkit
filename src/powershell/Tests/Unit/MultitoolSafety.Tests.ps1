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

    Context 'Automatic report storage' {
        BeforeAll {
            $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
            foreach ($definition in $launcherAst.FindAll({
                        $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                        $args[0].Name -in @('Get-FinOpsReportRoot', 'Assert-FinOpsReportPath', 'New-FinOpsReportDirectory', 'Write-FinOpsReportFile',
                            'Show-ResultsSummary', 'Show-Banner', 'Write-SectionHeader', 'Write-ColorizedLine', 'Write-FinOpsConsole', 'Protect-FinOpsExportText', 'ConvertTo-FinOpsExportCell', 'ConvertTo-FinOpsExportRows')
                    }, $true)) { . ([scriptblock]::Create($definition.Extent.Text)) }
        }

        It 'Escapes terminal control sequences while preserving host colors' {
            $captured = [Collections.Generic.List[string]]::new()
            Mock Write-Host { [void]$captured.Add([string]$Object) }
            $payload = "$([char]27)[2J$([char]27)]52;c;synthetic$([char]7)$([char]0x202E)"

            Write-FinOpsConsole -Object $payload -ForegroundColor Yellow -NoNewline

            $captured[0] | Should -Not -Match '[\p{Cc}\p{Cf}]'
            $captured[0] | Should -Match '\\u001B\[2J'
            $captured[0] | Should -Match '\\u0007\\u202E'
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $ForegroundColor -eq 'Yellow' -and $NoNewline }
        }

        It 'Preserves the banner line layout through safe console output' {
            $captured = [Collections.Generic.List[string]]::new()
            function Get-VersionNumber { '0.0.0' }
            Mock Clear-Host { }
            Mock Write-Host { [void]$captured.Add([string]$Object) }

            Show-Banner

            $captured.Count | Should -BeGreaterThan 15
            ($captured -join '') | Should -Not -Match '\\u000[AD]|[\p{Cc}\p{Cf}]'
        }

        It 'Keeps hostile tag controls out of terminal output without changing scan data' {
            $reportRoot = Join-Path $TestDrive 'terminal-controls'
            $captured = [Collections.Generic.List[string]]::new()
            Mock Write-Host { [void]$captured.Add([string]$Object) }
            $payload = "$([char]27)[2Jsynthetic <script>example</script>"
            $inventory = ConvertTo-TagInventoryFromHub -HubData @([pscustomobject]@{
                ResourceId = '/resources/fixture'; ResourceType = 'Fixture'; Tags = (@{ CostCenter = $payload } | ConvertTo-Json -Compress)
            })
            $modules = @(@{ Fn = 'Get-TagInventory'; Name = 'Tag Inventory'; Selected = $true; Category = 'Governance' })

            $null = Show-ResultsSummary -Results @{ 'Get-TagInventory' = $inventory } -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            ($captured -join '') | Should -Not -Match '[\p{Cc}\p{Cf}]'
            ($captured -join '') | Should -Match '\\u001B\[2J'
            $inventory.TagNames.CostCenter.Values[0].Value | Should -BeExactly $payload
            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $html | Should -Match '&lt;script&gt;example&lt;/script&gt;'
            $html | Should -Not -Match '<script>example</script>'
        }

        It 'Creates distinct run folders without changing existing reports' {
            $root = Join-Path $TestDrive 'reports'

            $first = New-FinOpsReportDirectory -OutputPath $root
            Write-FinOpsReportFile -Directory $first -Name 'ScanSummary.txt' -Lines @('First run')
            $second = New-FinOpsReportDirectory -OutputPath $root

            $first | Should -Not -Be $second
            Split-Path $first -Parent | Should -Be $root
            Split-Path $second -Parent | Should -Be $root
            Get-Content -LiteralPath (Join-Path $first 'ScanSummary.txt') | Should -Be 'First run'
            { Write-FinOpsReportFile -Directory $first -Name 'ScanSummary.txt' -Lines @('Replacement') } | Should -Throw
            Get-Content -LiteralPath (Join-Path $first 'ScanSummary.txt') | Should -Be 'First run'
        }

        It 'Rejects a <Marker> Git worktree before creating a report folder' -ForEach @(
            @{ Marker = 'directory' }
            @{ Marker = 'file' }
        ) {
            $repository = Join-Path $TestDrive "repository-$Marker"
            [void](New-Item -ItemType Directory -Path $repository)
            $gitMarker = Join-Path $repository '.git'
            if ($Marker -eq 'directory') { [void](New-Item -ItemType Directory -Path $gitMarker) }
            else { Set-Content -LiteralPath $gitMarker -Value 'gitdir: elsewhere' }
            $target = Join-Path $repository 'nested/reports'

            { New-FinOpsReportDirectory -OutputPath $target } | Should -Throw '*Git*'

            Test-Path -LiteralPath $target | Should -BeFalse
        }

        It 'Rejects network and provider paths before writing data (<Destination>)' -ForEach @(
            @{ Destination = '\\server\share\reports' }
            @{ Destination = 'https://example.test/reports' }
            @{ Destination = 'Env:reports' }
        ) {
            { New-FinOpsReportDirectory -OutputPath $Destination } | Should -Throw '*local*'
        }

        It 'Uses per-user local application data rather than the working directory' {
            $base = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData, [Environment+SpecialFolderOption]::DoNotVerify)

            Get-FinOpsReportRoot | Should -Be (Join-Path $base 'FinOpsToolkit/Multitool/Reports')
        }

        It 'Creates the default reports folder for a fresh Linux application-data path' -Skip:(-not $IsLinux) {
            $applicationData = Join-Path $TestDrive 'fresh-application-data'
            $definitions = @('Get-FinOpsReportRoot', 'Assert-FinOpsReportPath', 'New-FinOpsReportDirectory', 'Write-FinOpsReportFile') |
                ForEach-Object { "function $_ { $((Get-Command $_).Definition) }" }
            $scriptText = "`$ErrorActionPreference = 'Stop'`n" + ($definitions -join "`n") + "`nNew-FinOpsReportDirectory"
            $startInfo = [System.Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true
            foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand', [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptText)))) {
                $startInfo.ArgumentList.Add($argument)
            }
            $startInfo.Environment['XDG_DATA_HOME'] = $applicationData
            $process = [System.Diagnostics.Process]::new()
            try {
                $process.StartInfo = $startInfo
                [void]$process.Start()
                $standardOutput = $process.StandardOutput.ReadToEndAsync()
                $standardError = $process.StandardError.ReadToEndAsync()
                $process.WaitForExit()
                $process.ExitCode | Should -Be 0 -Because $standardError.GetAwaiter().GetResult()
                $run = $standardOutput.GetAwaiter().GetResult().Trim()
                Split-Path $run -Parent | Should -Be (Join-Path $applicationData 'FinOpsToolkit/Multitool/Reports')
                Test-Path -LiteralPath (Join-Path $run '.gitignore') | Should -BeTrue
            }
            finally { $process.Dispose() }
        }

        It 'Automatically saves all formats without OutputPath or a key press' {
            $localRoot = Join-Path $TestDrive 'automatic-local'
            Mock Get-FinOpsReportRoot { $localRoot }
            Mock Read-Host { throw 'Saving reports must not prompt.' }
            Mock Write-Host { }
            $subscription = [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' }
            $results = @{ 'Get-CostData' = @{ $subscription.Id = @{ Actual = 10; Currency = 'USD'; Name = 'Fixture'; ForecastSource = 'Unavailable' } } }
            $modules = @(@{ Fn = 'Get-CostData'; Name = 'Cost Data'; Selected = $true; Category = 'Cost Analysis' })

            $returned = Show-ResultsSummary -Results $results -Modules $modules -Subscriptions @($subscription) -ErrorAction Stop

            $runs = @(Get-ChildItem -LiteralPath $localRoot -Directory)
            $runs.Count | Should -Be 1
            foreach ($name in @('Get-CostData.csv', 'FinOpsReport.html', 'ScanSummary.txt', '.gitignore')) {
                Test-Path -LiteralPath (Join-Path $runs[0].FullName $name) | Should -BeTrue
            }
            (Import-Csv -LiteralPath (Join-Path $runs[0].FullName 'Get-CostData.csv')).Actual | Should -Be '10'
            $returned['Get-CostData'][$subscription.Id].Actual | Should -Be 10
            Get-Content -LiteralPath (Join-Path $runs[0].FullName '.gitignore') | Should -Be '*'
            Should -Invoke Read-Host -Times 0 -Exactly
        }

        It 'Starts the HTML story with scoped spend and visible evidence gaps' {
            $reportRoot = Join-Path $TestDrive 'finops-story'
            Mock Write-Host { }
            $permissionInfo = @{ 'Get-CostTrend' = @{ Role = 'Cost Management Reader'; Scope = 'Subscription'; API = 'Cost Management Query' } }
            $subscriptions = @(
                [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Production <east>'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
                [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Development'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
            )
            $results = @{
                'Get-CostData' = @{
                    $subscriptions[0].Id = @{ Actual = 100; Currency = 'EUR'; Name = $subscriptions[0].Name; ActualPeriod = '2026-08-01 to 2026-08-31'; Forecast = $null; ForecastSource = 'Unavailable' }
                    $subscriptions[1].Id = @{ Actual = 200; Currency = 'USD'; Name = $subscriptions[1].Name; ActualPeriod = '2026-09-01 to 2026-09-18'; Forecast = 300; ForecastSource = 'Forecast' }
                }
                'Get-CostTrend' = @()
                '_error_Get-CostTrend' = '429 Too Many Requests: retry later <script>not markup</script>'
            }
            $modules = @(
                @{ Fn = 'Get-CostData'; Name = 'Cost Data'; Selected = $true; Category = 'Cost Analysis' }
                @{ Fn = 'Get-CostTrend'; Name = 'Cost Trend'; Selected = $true; Category = 'Cost Analysis' }
            )

            $null = Show-ResultsSummary -Results $results -Modules $modules -Subscriptions $subscriptions -ExportPath $reportRoot -DataSourceLabel 'FinOps Hub (fixture)' -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $story = [regex]::Match($html, '(?s)<section id="tab-FinOpsStory"[^>]*>.*?</section>').Value
            $story | Should -Not -BeNullOrEmpty
            $story | Should -Match 'Observed spend'
            $story | Should -Match '2026-08-01 to 2026-08-31'
            $story | Should -Match '2026-09-01 to 2026-09-18'
            $story | Should -Match 'EUR 100.00'
            $story | Should -Match 'USD 200.00'
            $story | Should -Match 'Production &lt;east&gt;'
            $story | Should -Match 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            $story | Should -Match 'FinOps Hub \(fixture\)'
            $story | Should -Match 'Scan status'
            $story | Should -Match '429 Too Many Requests'
            $story | Should -Match '&lt;script&gt;not markup&lt;/script&gt;'
            $story | Should -Match 'href="#scan-Get-CostTrend"'
            $html | Should -Match ([regex]::Escape($permissionInfo['Get-CostTrend'].Role))
            $story | Should -Match 'Full-month forecast unavailable'
            $html | Should -Not -Match 'Total Findings|Every measure below is a FinOps Foundation KPI'
            $html | Should -Not -Match 'Current period spend:'
            $story | Should -Not -Match '<script>|Total savings'
        }

        It 'Keeps zero, credits, unavailable amounts, and budget comparison gaps distinct without a KPI catalog' {
            $reportRoot = Join-Path $TestDrive 'story-unknowns'
            Mock Write-Host { }
            Mock Get-KpiCatalog { $null }
            $results = @{
                'Get-CostData' = @{
                    'zero' = @{ Actual = 0; Currency = 'USD'; Forecast = 0; ForecastSource = 'Actual'; ActualPeriod = '2026-09-01 to 2026-09-18' }
                    'credit' = @{ Actual = -5.25; Currency = 'EUR'; ForecastSource = 'Unavailable'; ActualPeriod = '2026-08-01 to 2026-08-31' }
                    'unknown' = @{ Actual = $null; Currency = $null; Forecast = $null; ForecastSource = 'Unavailable' }
                }
                'Get-BudgetHistory' = @([pscustomobject]@{
                    BudgetName = 'Filtered budget'; SubscriptionId = 'zero'; Month = '2026-08'; Budget = 500; ActualSpend = $null
                    PctUsed = $null; Status = 'Unavailable'; Currency = 'USD'; Note = 'Filtered budget history requires costs for the same filter.'
                })
            }
            $modules = @(
                @{ Fn = 'Get-CostData'; Name = 'Cost Data'; Selected = $true; Category = 'Cost Analysis' }
                @{ Fn = 'Get-BudgetHistory'; Name = 'Budget History'; Selected = $true; Category = 'Cost Analysis' }
            )

            $null = Show-ResultsSummary -Results $results -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $story = [regex]::Match($html, '(?s)<section id="tab-FinOpsStory"[^>]*>.*?</section>').Value
            $story | Should -Match '<td>zero</td><td>USD 0.00</td>.*?<td>Unavailable</td>'
            $story | Should -Match '<td>credit</td><td>EUR -5.25</td>'
            $story | Should -Match '<td>unknown</td><td>Unavailable</td><td>Not recorded</td><td>Unavailable</td>'
            $story | Should -Match 'Filtered budget history requires costs for the same filter'
            $story | Should -Match 'Limited data'
            $html | Should -Match '<div class="label">Scans with gaps</div><div class="value">2</div>'
            $story | Should -Not -Match 'Every measure|No budget overruns'
        }

        It 'Shows the largest resource costs by currency and period with links to every underlying row' {
            $reportRoot = Join-Path $TestDrive 'story-drivers'
            Mock Write-Host { }
            $resources = @(foreach ($index in 1..57) {
                [pscustomobject]@{
                    Subscription = 'Fixture'; ResourcePath = "/subscriptions/fixture/resources/resource-$index"; ResourceGroup = 'Compute'
                    ResourceType = 'Virtual Machine'; Actual = $index * 10; Currency = 'USD'; ActualPeriod = '2026-09-01 to 2026-09-18'
                }
            })
            $resources += [pscustomobject]@{
                Subscription = 'Fixture'; ResourcePath = '/subscriptions/fixture/resources/euro-storage'; ResourceGroup = 'Storage'
                ResourceType = 'Storage Account'; Actual = 2; Currency = 'EUR'; ActualPeriod = '2026-08-01 to 2026-08-31'
            }
            $resources += [pscustomobject]@{
                Subscription = 'Fixture'; ResourcePath = '/subscriptions/fixture/resources/credit'; ResourceGroup = 'Compute'
                ResourceType = 'Virtual Machine'; Actual = -5; Currency = 'USD'; ActualPeriod = '2026-09-01 to 2026-09-18'
            }
            $resources += @(foreach ($index in 1..6) {
                [pscustomobject]@{
                    Subscription = 'Fixture'; ResourcePath = "/subscriptions/other/resources/other-$index"; ResourceGroup = 'Compute'
                    ResourceType = 'Virtual Machine'; Actual = $index; Currency = 'USD'; ActualPeriod = '2026-09-01 to 2026-09-18'
                }
            })
            $modules = @(@{ Fn = 'Get-ResourceCosts'; Name = 'Resource Costs'; Selected = $true; Category = 'Cost Analysis' })

            $null = Show-ResultsSummary -Results @{ 'Get-ResourceCosts' = $resources } -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            $drivers = [regex]::Match($html, '(?s)<div id="story-cost-drivers">.*?</div><!-- cost-drivers -->').Value
            $drivers | Should -Not -BeNullOrEmpty
            $drivers | Should -Match 'EUR 2.00|2026-08-01 to 2026-08-31'
            $drivers | Should -Match 'USD 570.00|2026-09-01 to 2026-09-18'
            $drivers | Should -Not -Match 'resource-1</td>|resource-2</td>|/resources/credit'
            $drivers | Should -Match '/subscriptions/other/resources/other-2</td>'
            $drivers | Should -Not -Match '/subscriptions/other/resources/other-1</td>'
            [regex]::Matches($drivers, '<tr><td>Fixture</td>').Count | Should -Be 11
            $drivers | Should -Match 'href="#scan-Get-ResourceCosts"'
            $html | Should -Match 'href="#scan-Get-ResourceCosts">Resource Costs</a></td><td class="evidence-state ">Data returned</td>'
            $html | Should -Match '<div class="label">Scans with gaps</div><div class="value">0</div>'
            @((Import-Csv -LiteralPath (Join-Path $run 'Get-ResourceCosts.csv'))).Count | Should -Be 65
            $detail = [regex]::Match($html, '(?s)<h2 id="scan-Get-ResourceCosts".*?</table>').Value
            [regex]::Matches($detail, '<tr><td>Fixture</td>').Count | Should -Be 65
            $detail | Should -Match '/resources/credit</td>|USD -5.00'
            $detail | Should -Match '/resources/resource-1</td>'
            $detail | Should -Match '/resources/euro-storage</td>.*?2026-08-01 to 2026-08-31'
        }

        It 'Exports every Hub tag and its full encoded values in HTML and CSV' {
            $reportRoot = Join-Path $TestDrive 'complete-tag-values'
            Mock Write-Host { }
            $longValue = ('long-value-' * 10) + '<script>example</script>'
            $tags = @{}
            foreach ($index in 1..20) { $tags[('Tag{0:D2}' -f $index)] = 'Fixture' }
            $tags.Tag20 = $longValue
            $hubRows = @([pscustomobject]@{ ResourceId = '/resources/one'; ResourceType = 'fixture'; Tags = ($tags | ConvertTo-Json -Compress) })
            foreach ($index in 1..6) {
                $hubRows += [pscustomobject]@{ ResourceId = "/resources/extra-$index"; ResourceType = 'fixture'; Tags = (@{ Tag20 = "Other-$index" } | ConvertTo-Json -Compress) }
            }
            $inventory = ConvertTo-TagInventoryFromHub -HubData $hubRows
            $modules = @(@{ Fn = 'Get-TagInventory'; Name = 'Tag Inventory'; Selected = $true; Category = 'Governance' })

            $null = Show-ResultsSummary -Results @{ 'Get-TagInventory' = $inventory } -Modules $modules -ExportPath $reportRoot -ErrorAction Stop

            $run = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0].FullName
            $html = Get-Content -LiteralPath (Join-Path $run 'FinOpsReport.html') -Raw
            [regex]::Matches($html, '<tr><td>Tag\d{2}</td>').Count | Should -Be 20
            $tagRow = [regex]::Match($html, '(?s)<tr><td>Tag20</td>.*?</tr>').Value
            $tagRow | Should -Match ([regex]::Escape([System.Net.WebUtility]::HtmlEncode($longValue)))
            foreach ($index in 1..6) { $tagRow | Should -Match "Other-$index" }
            $tagRow | Should -Not -Match '&hellip;|<script>|\+\d+ more'
            $csvRows = @(Import-Csv -LiteralPath (Join-Path $run 'Get-TagInventory.csv') | Where-Object RecordType -EQ 'TagNames')
            $csvRows.Count | Should -Be 20
            $values = @((($csvRows | Where-Object TagKey -EQ 'Tag20').Values) | ConvertFrom-Json)
            $values.Count | Should -Be 7
            $values.Value | Should -Contain $longValue
        }

        It 'Creates private directories and report files' {
            $run = New-FinOpsReportDirectory -OutputPath (Join-Path $TestDrive 'private')
            $path = Join-Path $run 'ScanSummary.txt'
            Write-FinOpsReportFile -Directory $run -Name 'ScanSummary.txt' -Lines @('Fixture')

            if ($IsWindows) {
                $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                try {
                    $directoryAcl = Get-Acl -LiteralPath $run
                    $directoryAcl.AreAccessRulesProtected | Should -BeTrue
                    foreach ($acl in @($directoryAcl, (Get-Acl -LiteralPath $path))) {
                        $rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
                        $rules.Count | Should -BeGreaterThan 0
                        foreach ($rule in $rules) { $rule.IdentityReference.Value | Should -Be $identity.User.Value }
                    }
                }
                finally { $identity.Dispose() }
            }
            elseif ('System.IO.UnixFileMode' -as [type]) {
                [int][System.IO.File]::GetUnixFileMode($run) | Should -Be 448
                [int][System.IO.File]::GetUnixFileMode($path) | Should -Be 384
            }
        }

        It 'Rejects a bare Git repository' {
            $repository = Join-Path $TestDrive 'bare'
            [void](New-Item -ItemType Directory -Path (Join-Path $repository 'objects') -Force)
            Set-Content -LiteralPath (Join-Path $repository 'HEAD') -Value 'ref: refs/heads/main'

            { New-FinOpsReportDirectory -OutputPath (Join-Path $repository 'reports') } | Should -Throw '*Git*'

            Test-Path -LiteralPath (Join-Path $repository 'reports') | Should -BeFalse
        }

        It 'Does not create Git metadata from a report destination' {
            $parent = Join-Path $TestDrive 'not-a-repository'
            [void](New-Item -ItemType Directory -Path $parent)

            { New-FinOpsReportDirectory -OutputPath (Join-Path $parent '.git/reports') } | Should -Throw '*Git*'

            Test-Path -LiteralPath (Join-Path $parent '.git') | Should -BeFalse
        }

        It 'Refuses links and junctions in the destination path' {
            $target = Join-Path $TestDrive 'link-target'
            $link = Join-Path $TestDrive 'report-link'
            [void](New-Item -ItemType Directory -Path $target)
            $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
            [void](New-Item -ItemType $linkType -Path $link -Target $target)
            try {
                { New-FinOpsReportDirectory -OutputPath (Join-Path $link 'reports') } | Should -Throw '*links or junctions*'
                Test-Path -LiteralPath (Join-Path $target 'reports') | Should -BeFalse
            }
            finally { Remove-Item -LiteralPath $link -Force }
        }

        It 'Rechecks Git ancestry before writing report content' {
            $run = New-FinOpsReportDirectory -OutputPath (Join-Path $TestDrive 'became-repository')
            [void](New-Item -ItemType Directory -Path (Join-Path $run '.git'))

            { Write-FinOpsReportFile -Directory $run -Name 'ScanSummary.txt' -Lines @('Sensitive fixture') } | Should -Throw '*Git*'

            Test-Path -LiteralPath (Join-Path $run 'ScanSummary.txt') | Should -BeFalse
        }

        It 'Rejects path traversal in report file names' {
            $run = New-FinOpsReportDirectory -OutputPath (Join-Path $TestDrive 'file-names')

            { Write-FinOpsReportFile -Directory $run -Name '../escaped.txt' -Lines @('Fixture') } | Should -Throw '*file name*'
            { Write-FinOpsReportFile -Directory $run -Name 'ScanSummary.txt:stream' -Lines @('Fixture') } | Should -Throw '*file name*'
        }
    }

    Context 'CSV export projections' {
        BeforeAll {
            $launcher = Join-Path $script:ModuleRoot 'Invoke-FinOpsMultitool.ps1'
            $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$null, [ref]$null)
            foreach ($definition in $launcherAst.FindAll({
                        $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                        $args[0].Name -in @('Protect-FinOpsExportText', 'ConvertTo-FinOpsExportCell', 'ConvertTo-FinOpsExportRows')
                    }, $true)) {
                . ([scriptblock]::Create($definition.Extent.Text))
            }
        }

        It 'Uses invariant amounts and ISO dates under <Culture>' -ForEach @(
            @{ Culture = 'en-US' }
            @{ Culture = 'de-DE' }
        ) {
            $originalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [cultureinfo]::GetCultureInfo($Culture)
                $data = @{ 'sub-a' = @{
                        Actual = [decimal]100.25; Credit = -20.5; Currency = 'EUR'; Name = '-formula'
                        ActualPeriodStart = [datetime]::new(2026, 9, 1, 0, 0, 0, [DateTimeKind]::Utc)
                        CapturedAt = [datetimeoffset]::new(2026, 9, 2, 3, 4, 5, [timespan]::FromHours(2))
                    }
                }

                $row = @(ConvertTo-FinOpsExportRows -Fn 'Get-CostData' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)[0]

                $row.Actual | Should -Be '100.25'
                $row.Credit | Should -Be '-20.5'
                $row.ActualPeriodStart | Should -Be '2026-09-01T00:00:00.0000000Z'
                $row.CapturedAt | Should -Be '2026-09-02T03:04:05.0000000+02:00'
                $row.Name | Should -Be "'-formula"
                $generic = @(ConvertTo-FinOpsExportRows -Fn 'Unknown' -Data @{ Credit = -20.5 } | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)[0]
                $generic.Value | Should -Be '-20.5'
            }
            finally { [System.Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture }
        }

        It 'Exports tag values, amounts, and currencies from scanner row objects' {
            $data = [pscustomobject]@{
                CostByTag        = @{
                    CostCenter = @(
                        [pscustomobject]@{ TagValue = 'team-a'; Cost = 100.25; Currency = 'EUR' }
                        [pscustomobject]@{ TagValue = 'team-b'; Cost = -20; Currency = 'EUR' }
                    )
                }
                TagsQueried      = @('CostCenter')
                NoTagsFound      = $false
                Source           = 'Kusto'
                ResourceCostSeen = 80.25
            }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-CostByTag' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $rows.Count | Should -Be 3
            $tagRows = @($rows | Where-Object RecordType -EQ 'CostByTag')
            $tagRows.TagValue | Should -Be @('team-a', 'team-b')
            $tagRows.Cost | Should -Be @('100.25', '-20')
            $tagRows.Currency | Should -Be @('EUR', 'EUR')
            foreach ($row in $tagRows) {
                $row.RecordType | Should -Be 'CostByTag'
                $row.'Summary.Source' | Should -Be 'Kusto'
                $row.'Summary.ResourceCostSeen' | Should -Be '80.25'
            }
            ($rows | Where-Object RecordType -EQ 'Summary.TagsQueried').Value | Should -Be 'CostCenter'
        }

        It 'Retains metadata for dictionary-backed scan wrappers' {
            $data = @{
                Reservations = @([pscustomobject]@{ ReservationId = 'ri-1'; AvgUtilization = 90 })
                SavingsPlans = @()
                HasData      = $true
                Note         = 'Validated billing scope'
            }

            $row = @(ConvertTo-FinOpsExportRows -Fn 'Get-CommitmentUtilization' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)[0]

            $row.ReservationId | Should -Be 'ri-1'
            $row.'Summary.Note' | Should -Be 'Validated billing scope'
            $row.'Summary.HasData' | Should -Be 'True'
            $row.PSObject.Properties.Name | Should -Not -Contain 'Summary.Keys'
        }

        It 'Retains tag diagnostics when no tag rows exist' {
            $data = [pscustomobject]@{ CostByTag = @{}; NoTagsFound = $true; Source = 'Kusto'; Note = 'No tag keys in the selected cost data' }

            $row = @(ConvertTo-FinOpsExportRows -Fn 'Get-CostByTag' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)[0]

            $row.RecordType | Should -Be 'Status'
            $row.Status | Should -Be 'No data'
            $row.'Summary.NoTagsFound' | Should -Be 'True'
            $row.'Summary.Source' | Should -Be 'Kusto'
            $row.'Summary.Note' | Should -Be $data.Note
        }

        It 'Exports both commitment families and the underutilized view once' {
            $reservation = [pscustomobject]@{ ReservationId = 'ri-1'; SkuName = 'Standard_D2s_v5'; AvgUtilization = 50 }
            $data = [pscustomobject]@{
                Reservations     = @($reservation)
                SavingsPlans     = @([pscustomobject]@{ BenefitId = 'sp-1'; BenefitOrderId = 'order-1'; AvgUtilization = 75 })
                UnderutilizedRIs = @($reservation)
                RICount          = 1
                SPCount          = 1
                HasData          = $true
            }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-CommitmentUtilization' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $rows.Count | Should -Be 3
            ($rows | Where-Object RecordType -EQ 'Reservations').ReservationId | Should -Be 'ri-1'
            ($rows | Where-Object RecordType -EQ 'SavingsPlans').BenefitId | Should -Be 'sp-1'
            ($rows | Where-Object RecordType -EQ 'SavingsPlans').BenefitOrderId | Should -Be 'order-1'
            @($rows | Where-Object RecordType -EQ 'Summary.UnderutilizedRIs').Count | Should -Be 1
            $rows[0].PSObject.Properties.Name | Should -Not -Contain 'Summary.UnderutilizedRIs'
        }

        It 'Keeps nested summary exports linear in collection size' {
            $sizes = @()
            foreach ($count in @(100, 200)) {
                $reservations = @(foreach ($index in 1..$count) {
                        [pscustomobject]@{ ReservationId = "reservation-$index"; AvgUtilization = 50; SkuName = 'Standard_D2s_v5' }
                    })
                $data = [pscustomobject]@{ Reservations = $reservations; SavingsPlans = @(); UnderutilizedRIs = $reservations; RICount = $count; HasData = $true }

                $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-CommitmentUtilization' -Data $data)
                $csv = ($rows | ConvertTo-Csv -NoTypeInformation) -join "`n"

                @($rows | Where-Object RecordType -EQ 'Reservations').Count | Should -Be $count
                @($rows | Where-Object RecordType -EQ 'Summary.UnderutilizedRIs').Count | Should -Be $count
                $rows[0].PSObject.Properties.Name | Should -Not -Contain 'Summary.UnderutilizedRIs'
                $sizes += $csv.Length
            }
            $sizes[1] | Should -BeLessThan ($sizes[0] * 2.2)
        }

        It 'Exports raw tag records and tag locations once as distinct views' {
            $data = [pscustomobject]@{
                TagNames = @{ CostCenter = @{ TotalResources = 2; Values = @('team') } }
                CaseVariants = @(); UntaggedResources = @(); TagCount = 1
                RawResults = @([pscustomobject]@{ tagName = 'CostCenter'; tagValue = 'team'; ResourceCount = 2 })
                TagLocations = @{ CostCenter = @('sub-a / rg-a', 'sub-b / rg-b') }
            }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-TagInventory' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            @($rows | Where-Object RecordType -EQ 'TagNames').Count | Should -Be 1
            @($rows | Where-Object RecordType -EQ 'Summary.RawResults').Count | Should -Be 1
            ($rows | Where-Object RecordType -EQ 'Summary.TagLocations').Value | Should -Be @('sub-a / rg-a', 'sub-b / rg-b')
            $rows[0].PSObject.Properties.Name | Should -Not -Contain 'Summary.RawResults'
        }

        It 'Preserves all primary collections for <Scan>' -ForEach @(
            @{ Scan = 'Get-AHBOpportunities'; Collections = @('WindowsVMs', 'SQLVMs', 'SQLDatabases') }
            @{ Scan = 'Get-AIWorkloadMetrics'; Collections = @('ByModel', 'ByAccount') }
            @{ Scan = 'Get-AnomalyAlerts'; Collections = @('TriggeredAlerts', 'ConfiguredRules') }
            @{ Scan = 'Get-BillingStructure'; Collections = @('BillingAccounts', 'BillingProfiles', 'InvoiceSections', 'EADepartments', 'CostAllocationRules') }
            @{ Scan = 'Get-CarbonMetrics'; Collections = @('MonthlyTrend', 'BySubscription') }
            @{ Scan = 'Get-ReservationAdvice'; Collections = @('AdvisorRecommendations', 'ReservationRecommendations') }
        ) {
            $payload = [ordered]@{ HasData = $true; Note = 'Known scope only' }
            foreach ($collection in $Collections) { $payload[$collection] = @([pscustomobject]@{ Id = $collection; Amount = 12.5 }) }

            $rows = @(ConvertTo-FinOpsExportRows -Fn $Scan -Data ([pscustomobject]$payload) | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $rows.Count | Should -Be $Collections.Count
            $rows.RecordType | Should -Be $Collections
            $rows.Id | Should -Be $Collections
            foreach ($row in $rows) { $row.'Summary.Note' | Should -Be 'Known scope only' }
        }

        It 'Keeps per-subscription monthly trends alongside aggregate months' {
            $data = [pscustomobject]@{
                HasData        = $true
                Months         = @([pscustomobject]@{ Month = 'Aug 2026'; Cost = 30; Currency = 'USD' })
                BySubscription = @{
                    'sub-a' = @([pscustomobject]@{ Month = 'Aug 2026'; Cost = 10; Currency = 'USD' })
                    'sub-b' = @([pscustomobject]@{ Month = 'Aug 2026'; Cost = 20; Currency = 'USD' })
                }
            }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-CostTrend' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $rows.Count | Should -Be 3
            ($rows | Where-Object SubscriptionId -EQ 'sub-a').Cost | Should -Be '10'
            ($rows | Where-Object SubscriptionId -EQ 'sub-b').Cost | Should -Be '20'
            ($rows | Where-Object RecordType -EQ 'Months').Cost | Should -Be '30'
        }

        It 'Preserves nested values as JSON and retains zero-result diagnostics' {
            $nested = @{ Owner = @{ Name = 'team'; Contacts = @('one@example.test', 'two@example.test') } }
            $cell = ConvertTo-FinOpsExportCell $nested
            ($cell | ConvertFrom-Json).Owner.Contacts.Count | Should -Be 2
            $cell | Should -Not -Match 'System\.Collections|System\.Object'
            $data = [pscustomobject]@{ Reservations = @(); SavingsPlans = @(); HasData = $false; AccessDenied = $true; Note = 'Missing billing access' }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-CommitmentUtilization' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $rows.Count | Should -Be 1
            $rows[0].RecordType | Should -Be 'Status'
            $rows[0].Status | Should -Be 'Error'
            $rows[0].Error | Should -Be 'Missing billing access'
            $rows[0].'Summary.AccessDenied' | Should -Be 'True'
            $rows[0].'Summary.Note' | Should -Be 'Missing billing access'
        }

        It 'Labels empty wrapper results while preserving summary collections' {
            $data = [pscustomobject]@{
                Orphans = @(); HasData = $false; TotalCount = 0; Note = 'No orphaned resources found'
                CheckedScopes = @('sub-a', 'sub-b')
            }

            $rows = @(ConvertTo-FinOpsExportRows -Fn 'Get-OrphanedResources' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)

            $statusRows = @($rows | Where-Object RecordType -EQ 'Status')
            $statusRows.Count | Should -Be 1
            $statusRows[0].Status | Should -Be 'No data'
            $statusRows[0].Scan | Should -Be 'Get-OrphanedResources'
            $statusRows[0].'Summary.HasData' | Should -Be 'False'
            $statusRows[0].'Summary.Note' | Should -Be $data.Note
            ($rows | Where-Object RecordType -EQ 'Summary.CheckedScopes').Value | Should -Be @('sub-a', 'sub-b')
        }

        It 'Preserves cost source and period while protecting formula text' {
            $data = @{ 'sub-a' = @{ Actual = -25; Forecast = $null; Currency = 'EUR'; ActualPeriod = '2026-08'; ForecastSource = 'Unavailable'; Name = '=1+1' } }

            $row = @(ConvertTo-FinOpsExportRows -Fn 'Get-CostData' -Data $data | ConvertTo-Csv -NoTypeInformation | ConvertFrom-Csv)[0]

            $row.Actual | Should -Be '-25'
            $row.ActualPeriod | Should -Be '2026-08'
            $row.ForecastSource | Should -Be 'Unavailable'
            $row.Forecast | Should -Be ''
            $row.Name | Should -Be "'=1+1"
        }
    }

    Context 'Tag cost presentation' {
        It 'Uses aggregate tag rows for guidance when <Case>' -ForEach @(
            @{ Case = 'cost is untagged'; Tagged = 100.0; Untagged = 20.0; Expected = 'Some untagged spend'; HasRows = $true }
            @{ Case = 'an untagged credit exists'; Tagged = 125.0; Untagged = -5.0; Expected = 'credits|negative'; HasRows = $true }
            @{ Case = 'tagged costs include a credit'; Tagged = -5.0; Untagged = 125.0; Expected = 'credits|negative'; HasRows = $true }
            @{ Case = 'net cost is zero'; Tagged = 0.0; Untagged = 0.0; Expected = 'no positive net cost'; HasRows = $true }
            @{ Case = 'no rows are available'; Tagged = 0.0; Untagged = 0.0; Expected = 'No cost data was returned'; HasRows = $false }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ModuleRoot = $script:ModuleRoot; Tagged = $Tagged; Untagged = $Untagged; Expected = $Expected; HasRows = $HasRows } {
                param($ModuleRoot, $Tagged, $Untagged, $Expected, $HasRows)
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $switches = $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
                $branch = @($switches.Clauses | Where-Object {
                        $_.Item1.Value -eq 'Get-CostByTag' -and $_.Item2.Extent.Text.Contains('No cost data was returned')
                    })
                $branch.Count | Should -Be 1
                $data = [pscustomobject]@{
                    CostByTag = @{ CostCenter = @(if ($HasRows) {
                                [pscustomobject]@{ TagValue = 'team'; Cost = $Tagged; Currency = 'USD' }
                                [pscustomobject]@{ TagValue = '(untagged)'; Cost = $Untagged; Currency = 'USD' }
                            })
                    }
                }
                $guidanceItems = @()
                $body = ($branch[0].Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"
                . ([scriptblock]::Create("param(`$data)`n$body")) $data

                ($guidanceItems.Message -join ' ') | Should -Match $Expected
                $guidanceItems.Severity | Should -Not -Contain 'Green'
                if ($HasRows) { ($guidanceItems.Message -join ' ') | Should -Not -Match 'No cost data was returned|No CAF allocation tag' }
            }
        }

        It 'Does not score invalid allocation percentages for <Case>' -ForEach @(
            @{ Case = 'negative aggregate untagged cost'; ResourceTotals = $false; Tagged = 125.0; Untagged = -5.0 }
            @{ Case = 'aggregate untagged cost above the total'; ResourceTotals = $false; Tagged = -5.0; Untagged = 125.0 }
            @{ Case = 'zero aggregate cost'; ResourceTotals = $false; Tagged = 0.0; Untagged = 0.0 }
            @{ Case = 'negative per-resource unallocated cost'; ResourceTotals = $true; Tagged = 125.0; Untagged = -5.0 }
            @{ Case = 'per-resource unallocated cost above the total'; ResourceTotals = $true; Tagged = -5.0; Untagged = 125.0 }
            @{ Case = 'zero per-resource cost'; ResourceTotals = $true; Tagged = 0.0; Untagged = 0.0 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ResourceTotals = $ResourceTotals; Tagged = $Tagged; Untagged = $Untagged } {
                param($ResourceTotals, $Tagged, $Untagged)
                $data = if ($ResourceTotals) {
                    [pscustomobject]@{ ResourceCostSeen = $Tagged + $Untagged; UnallocatedCost = $Untagged }
                }
                else {
                    [pscustomobject]@{ CostByTag = @{ CostCenter = @(
                                [pscustomobject]@{ TagValue = 'team'; Cost = $Tagged }
                                [pscustomobject]@{ TagValue = '(untagged)'; Cost = $Untagged }
                            )
                        }
                    }
                }
                $result = Add-KpiInsights -Result @{ tool = 'scan_cost_by_tag'; data = $data }
                foreach ($insight in $result.kpiInsights | Where-Object kpiId -In @('pct-costs-untagged', 'pct-costs-unallocated', 'tagging-policy-compliant')) {
                    $insight.status | Should -Be 'unavailable'
                    $insight.numericValue | Should -BeNullOrEmpty
                    $insight.yourValue | Should -Match 'Unavailable'
                }
            }
        }

        It 'Keeps valid allocation percentages for <Case>' -ForEach @(
            @{ Case = 'aggregate rows'; ResourceTotals = $false }
            @{ Case = 'resource totals'; ResourceTotals = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ResourceTotals = $ResourceTotals } {
                param($ResourceTotals)
                $data = if ($ResourceTotals) {
                    [pscustomobject]@{ ResourceCostSeen = 100.0; UnallocatedCost = 20.0 }
                }
                else {
                    [pscustomobject]@{ CostByTag = @{ CostCenter = @(
                                [pscustomobject]@{ TagValue = 'team'; Cost = 80.0 }
                                [pscustomobject]@{ TagValue = '(untagged)'; Cost = 20.0 }
                            )
                        }
                    }
                }
                (Get-KpiComputedValue -KpiId 'pct-costs-untagged' -Data $data).Value | Should -Be 20
                (Get-KpiComputedValue -KpiId 'tagging-policy-compliant' -Data $data).Value | Should -Be 80
            }
        }
    }

    Context 'Savings estimate contract' {
        BeforeEach {
            Mock Write-Host -ModuleName FinOpsMultitool { }
            Mock Get-Date -ModuleName FinOpsMultitool { [datetime]::new(2026, 9, 16, 12, 0, 0, [DateTimeKind]::Utc) }
            Mock Resolve-CostMgId -ModuleName FinOpsMultitool { $null }
            Mock Search-AzGraphSafe -ModuleName FinOpsMultitool {
                @{ Data = @([pscustomobject]@{ vmSize = 'Standard_D2s_v5'; location = 'eastus' }) }
            }
            Mock Get-AhbVmRates -ModuleName FinOpsMultitool { [pscustomobject]@{ HourlyPremium = 0.1 } }
            Mock Invoke-RestMethod -ModuleName FinOpsMultitool { throw 'Savings tests must not access the network.' }
        }

        It 'Separates <BillingCurrency> month-to-date commitments from the USD AHB run rate' -ForEach @(
            @{ BillingCurrency = 'EUR' }
            @{ BillingCurrency = 'USD' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ BillingCurrency = $BillingCurrency } {
                param($BillingCurrency)
                $fixtureCurrency = $BillingCurrency
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $dimension = if ($request.type -eq 'ActualCost') { 'ChargeType' } else { 'PricingModel' }
                    $category = if ($request.type -eq 'ActualCost') { 'UnusedReservation' } else { 'Reservation' }
                    $properties = @{
                        columns = @(@{ name = 'Currency' }, @{ name = $dimension }, @{ name = 'Cost' })
                        rows    = @(, @($fixtureCurrency, $category, 100.0))
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result = Get-SavingsRealized -Subscriptions $subscriptions

                $result.Currency | Should -Be $fixtureCurrency
                $result.RISavingsMonthToDate | Should -Be 66.67
                $result.CommitmentSavingsMonthToDate | Should -Be 66.67
                $result.AHBSavingsMonthly | Should -Be 73
                $result.AHBCurrency | Should -Be 'USD'
                $result.AHBPeriod | Should -Match '730'
                $result.TotalMonthly | Should -BeNullOrEmpty
                $result.TotalAnnual | Should -BeNullOrEmpty
                $result.RISavingsMonthly | Should -BeNullOrEmpty
                $result.Period | Should -Be '2026-09-01T00:00:00Z to 2026-09-16T12:00:00Z'
                @($result.Details | Where-Object Type -NE 'AHB').Currency | Select-Object -Unique | Should -Be $fixtureCurrency
                ($result.Details | Where-Object Type -EQ 'AHB').Currency | Should -Be 'USD'
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 2 -Exactly -ParameterFilter {
                    $request = $Payload | ConvertFrom-Json
                    $request.timeframe -eq 'Custom' -and
                    ([datetime]$request.timePeriod.from).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') -eq '2026-09-01T00:00:00Z' -and
                    ([datetime]$request.timePeriod.to).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') -eq '2026-09-16T12:00:00Z'
                }
                $kpi = Get-KpiComputedValue -KpiId 'effective-savings-rate' -Data $result
                $kpi.Display | Should -Match "$fixtureCurrency 66.67"
                $kpi.Display | Should -Not -Match '/ month|annual'
            }
        }

        It 'Rejects <Case> rather than guessing or combining currencies' -ForEach @(
            @{ Case = 'missing currency'; First = ''; Second = ''; IncludeColumn = $true }
            @{ Case = 'missing currency column'; First = 'EUR'; Second = 'EUR'; IncludeColumn = $false }
            @{ Case = 'mixed billing currencies'; First = 'EUR'; Second = 'USD'; IncludeColumn = $true }
            @{ Case = 'no-currency code'; First = 'XXX'; Second = 'XXX'; IncludeColumn = $true }
            @{ Case = 'test currency code'; First = 'XTS'; Second = 'XTS'; IncludeColumn = $true }
            @{ Case = 'unsupported currency code'; First = 'ABC'; Second = 'ABC'; IncludeColumn = $true }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ First = $First; Second = $Second; IncludeColumn = $IncludeColumn } {
                param($First, $Second, $IncludeColumn)
                $firstCurrency = $First
                $secondCurrency = $Second
                $hasCurrencyColumn = $IncludeColumn
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $dimension = if ($request.type -eq 'ActualCost') { 'ChargeType' } else { 'PricingModel' }
                    $category = if ($request.type -eq 'ActualCost') { 'UnusedReservation' } else { 'Reservation' }
                    $currency = if ($Path -like '/subscriptions/11111111-*') { $firstCurrency } else { $secondCurrency }
                    $properties = @{ columns = @(@{ name = $dimension }, @{ name = 'Cost' }); rows = @(, @($category, 100.0)) }
                    if ($hasCurrencyColumn) {
                        $properties.columns += @{ name = 'Currency' }
                        $properties.rows = @(, @($category, 100.0, $currency))
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' }
                )

                { Get-SavingsRealized -Subscriptions $subscriptions } | Should -Throw '*currenc*'
            }
        }

        It 'Excludes purchases, refunds, and unused commitments before aggregation' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    if ($request.type -eq 'ActualCost') {
                        $properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'ChargeType' }, @{ name = 'Currency' }); rows = @() }
                    }
                    else {
                        $charges = @(
                            @{ ChargeType = 'Usage'; Cost = 100.0 }
                            @{ ChargeType = 'Refund'; Cost = -90.0 }
                            @{ ChargeType = 'Purchase'; Cost = 1000.0 }
                            @{ ChargeType = 'UnusedReservation'; Cost = 30.0 }
                        )
                        $filter = $request.dataset.filter.dimensions
                        if ($filter.name -eq 'ChargeType' -and $filter.operator -eq 'In') {
                            $charges = @($charges | Where-Object { $_.ChargeType -in $filter.values })
                        }
                        $amount = ($charges | Measure-Object Cost -Sum).Sum
                        $properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'PricingModel' }, @{ name = 'Currency' }); rows = @(, @($amount, 'Reservation', 'EUR')) }
                    }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }

                $result = Get-SavingsRealized -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result.CommitmentSavingsMonthToDate | Should -Be 66.67
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 1 -Exactly -ParameterFilter {
                    $request = $Payload | ConvertFrom-Json
                    $request.type -eq 'AmortizedCost' -and $request.dataset.filter.dimensions.name -eq 'ChargeType' -and
                    $request.dataset.filter.dimensions.operator -eq 'In' -and (@($request.dataset.filter.dimensions.values) -join ',') -eq 'Usage'
                }
            }
        }

        It 'Rejects negative usage adjustments of <Amount> without partial savings' -ForEach @(
            @{ Amount = -100.0 }
            @{ Amount = -0.001 }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Adjustment = $Amount } {
                param($Adjustment)
                $fixtureAdjustment = $Adjustment
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $dimension = if ($request.type -eq 'ActualCost') { 'ChargeType' } else { 'PricingModel' }
                    $properties = @{ columns = @(@{ name = 'Cost' }, @{ name = $dimension }, @{ name = 'Currency' }); rows = @() }
                    if ($request.type -eq 'AmortizedCost') { $properties.rows = @(, @($fixtureAdjustment, 'Reservation', 'USD')) }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $received = [System.Collections.Generic.List[object]]::new()

                { Get-SavingsRealized -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' }) |
                    ForEach-Object { $received.Add($_) } } | Should -Throw '*negative adjustments*'

                $received.Count | Should -Be 0
            }
        }

        It 'Rejects a currency change on a later page without emitting partial savings' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    $isNext = $Path -like '*page=2'
                    $currency = if ($isNext) { 'USD' } else { 'EUR' }
                    $properties = @{
                        columns = @(@{ name = 'Cost' }, @{ name = 'ChargeType' }, @{ name = 'Currency' })
                        rows    = @(, @(100.0, 'UnusedReservation', $currency))
                    }
                    if (-not $isNext) { $properties.nextLink = "$Path&page=2" }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = $properties } | ConvertTo-Json -Depth 8) }
                }
                $received = [System.Collections.Generic.List[object]]::new()

                { Get-SavingsRealized -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' }) |
                    ForEach-Object { $received.Add($_) } } | Should -Throw '*multiple billing currencies*'

                $received.Count | Should -Be 0
            }
        }

        It 'Discards a failed management-group attempt including its currency' {
            InModuleScope FinOpsMultitool {
                Mock Resolve-CostMgId { 'test-management-group' }
                Mock Search-AzGraphSafe { @{ Data = @() } }
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $isManagementGroup = $Path -like '/providers/Microsoft.Management/*'
                    if ($isManagementGroup -and $request.type -eq 'AmortizedCost') { return [pscustomobject]@{ StatusCode = 503; Content = '{}' } }
                    $currency = if ($isManagementGroup) { 'GBP' } else { 'EUR' }
                    $dimension = if ($request.type -eq 'ActualCost') { 'ChargeType' } else { 'PricingModel' }
                    $category = if ($request.type -eq 'ActualCost') { 'UnusedReservation' } else { 'Reservation' }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{
                                    columns = @(@{ name = $dimension }, @{ name = 'Currency' }, @{ name = 'Cost' })
                                    rows    = @(, @($category, $currency, 100.0))
                                }
                            } | ConvertTo-Json -Depth 8)
                    }
                }
                $subscriptions = @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'First' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'Second' }
                )

                $result = Get-SavingsRealized -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -WarningAction SilentlyContinue

                $result.Currency | Should -Be 'EUR'
                $result.CommitmentSavingsMonthToDate | Should -Be 133.33
                $result.Details.Currency | Select-Object -Unique | Should -Be 'EUR'
                @($result.Details | Where-Object Type -EQ 'Waste').Count | Should -Be 2
            }
        }

        It 'Retains an AHB read failure without inventing zero or a commitment currency' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe { throw '403: inventory unavailable' }
                Mock Invoke-AzRestMethodWithRetry { throw 'A confirmed empty commitment inventory should skip cost queries.' }

                $result = Get-SavingsRealized -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' }) -CommitmentData ([pscustomobject]@{ HasData = $false }) -WarningAction SilentlyContinue

                $result.AHBSavingsMonthly | Should -BeNullOrEmpty
                $result.AHBIssue | Should -Match '403'
                $result.Currency | Should -BeNullOrEmpty
                $result.CommitmentSavingsMonthToDate | Should -BeNullOrEmpty
                $result.HasData | Should -BeFalse
            }
        }

        It 'Does not substitute USD for an unknown savings currency in the KPI' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ CommitmentSavingsMonthToDate = 66.67; Period = 'Month to date'; TotalMonthly = 66.67 }

                $result = Get-KpiComputedValue -KpiId 'effective-savings-rate' -Data $data

                $result.Value | Should -BeNullOrEmpty
                $result.Display | Should -Match 'Unavailable.*currency'
            }
        }
    }

    Context 'Savings estimate presentation' {
        It 'Labels terminal, guidance, HTML, and KPI output as estimates' {
            InModuleScope FinOpsMultitool -Parameters @{ ModuleRoot = $script:ModuleRoot } {
                param($ModuleRoot)
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $console = $launcherAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-FinOpsConsole' }, $true)
                . ([scriptblock]::Create($console.Extent.Text))
                $formatter = $launcherAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-ColorizedLine' }, $true)
                . ([scriptblock]::Create($formatter.Extent.Text))
                $captured = [System.Collections.Generic.List[string]]::new()
                Mock Write-Host { [void]$captured.Add([string]$Object) }
                Mock Write-ColorizedLine { [void]$captured.Add($Text) }
                Mock Get-Date { [datetime]::new(2026, 9, 16, 12, 0, 0, [DateTimeKind]::Utc) }
                Mock Invoke-AzRestMethodWithRetry {
                    $request = $Payload | ConvertFrom-Json
                    $dimension = if ($request.type -eq 'ActualCost') { 'ChargeType' } else { 'PricingModel' }
                    $category = if ($request.type -eq 'ActualCost') { 'Usage' } else { 'Reservation' }
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ properties = @{
                                    columns = @(@{ name = 'Cost' }, @{ name = $dimension }, @{ name = 'Currency' })
                                    rows    = @(, @(100.0, $category, 'EUR'))
                                }
                            } | ConvertTo-Json -Depth 8)
                    }
                }
                Mock Search-AzGraphSafe { @{ Data = @([pscustomobject]@{ vmSize = 'Standard_D2s_v5'; location = 'eastus' }) } }
                Mock Get-AhbVmRates { [pscustomobject]@{ HourlyPremium = 0.1 } }
                $data = Get-SavingsRealized -Subscriptions @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })
                $htmlSb = [System.Text.StringBuilder]::new()
                $guidanceItems = @()
                $tableNote = $null
                $switches = $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
                $branches = @($switches.Clauses | Where-Object { $_.Item1.Value -eq 'Get-SavingsRealized' })
                $branches.Count | Should -Be 3
                foreach ($branch in $branches) {
                    $body = ($branch.Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"
                    . ([scriptblock]::Create("param(`$data, `$htmlSb)`n$body")) $data $htmlSb
                }

                ($captured -join ' ') | Should -Match 'Estimated savings'
                ($captured -join ' ') | Should -Match 'EUR 66.67'
                ($captured -join ' ') | Should -Match 'USD 73.00'
                ($captured -join ' ') | Should -Not -Match 'Total monthly:|Annual:'
                ($guidanceItems.Message -join ' ') | Should -Match 'Estimated savings'
                ($guidanceItems.Message -join ' ') | Should -Not -Match 'Realizing|Run-level'
                $htmlSb.ToString() | Should -Match 'Estimated commitment savings'
                $htmlSb.ToString() | Should -Match 'EUR 66.67'
                $htmlSb.ToString() | Should -Match 'USD 73.00'
                $htmlSb.ToString() | Should -Match '730-hour'
                $tableNote | Should -Be $data.EstimateBasis
                $kpi = Get-KpiComputedValue -KpiId 'effective-savings-rate' -Data $data
                $kpi.Display | Should -Match 'estimated savings'
                $kpi.Display | Should -Not -Match 'realized'
                $catalog = Get-Content -LiteralPath (Join-Path $ModuleRoot 'kpi/kpi-catalog.json') -Raw | ConvertFrom-Json
                $definition = $catalog.kpis | Where-Object id -EQ 'effective-savings-rate'
                $definition.unit | Should -Be 'currency/period'
                $definition.plainLanguage | Should -Match 'estimates'
            }
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

        It 'Rejects unreadable values and malformed numeric grouping' {
            { ConvertTo-ExportAmount 'not-a-number' } | Should -Throw '*cost*'
            { ConvertTo-ExportAmount '' } | Should -Throw '*cost*'
            { ConvertTo-ExportAmount '123,45' } | Should -Throw '*grouping*'
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

Describe 'FinOps Multitool cost math' {

    BeforeAll {
        $script:ModuleRoot = Join-Path $PSScriptRoot '../../Private/FinOpsMultitool'
        Import-Module (Join-Path $script:ModuleRoot 'FinOpsMultitool.psm1') -Force
    }

    AfterAll {
        Remove-Module FinOpsMultitool -ErrorAction SilentlyContinue
    }

    Context 'Cost column resolution' {

        # 'CostStatus' contains 'cost'. A substring match picked it up and, because
        # the loop kept going, the later match won -- so the cost index pointed at
        # a column holding the text 'Actual' or 'Forecast'.
        It 'Resolves Cost and not CostStatus when both are present' {
            InModuleScope FinOpsMultitool {
                $columns = @(
                    [pscustomobject]@{ name = 'Cost' }
                    [pscustomobject]@{ name = 'SubscriptionId' }
                    [pscustomobject]@{ name = 'CostStatus' }
                )
                Get-CostColumnIndex -Columns $columns -Names @('cost', 'pretaxcost', 'costusd') |
                Should -Be 0
            }
        }

        It 'Reports -1 rather than guessing when the column is absent' {
            InModuleScope FinOpsMultitool {
                $columns = @([pscustomobject]@{ name = 'CostStatus' })
                Get-CostColumnIndex -Columns $columns -Names @('cost') | Should -Be -1
            }
        }
    }

    Context 'Forecast requests' {

        It 'Requests the full month before summing actual and forecast rows (<QueryPath>)' -ForEach @(
            @{ QueryPath = 'PerSubscription' }
            @{ QueryPath = 'ManagementGroup' }
            @{ QueryPath = 'ManagementGroupFallback' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ QueryPath = $QueryPath } {
                param($QueryPath)

                Mock Get-Date { [datetime]'2026-09-16T12:00:00Z' }
                Mock Get-Date { [datetime]'2026-09-01T00:00:00' } -ParameterFilter { $Day -eq 1 }
                Mock Resolve-CostMgId { 'mock-management-group' }
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*forecast*') {
                        if ($QueryPath -eq 'ManagementGroupFallback' -and $Path -like '/providers/Microsoft.Management/*') {
                            return [pscustomobject]@{ StatusCode = 503; Content = '{}' }
                        }
                        $forecastRequest = $Payload | ConvertFrom-Json
                        $forecastRows = @(, @(250.0, 'Forecast', '11111111-1111-1111-1111-111111111111', 'USD'))
                        if ($forecastRequest.timePeriod.from -eq '2026-09-01') {
                            $forecastRows = @(
                                @(100.0, 'Actual', '11111111-1111-1111-1111-111111111111', 'USD'),
                                @(250.0, 'Forecast', '11111111-1111-1111-1111-111111111111', 'USD')
                            )
                        }
                        $body = @{
                            properties = @{
                                columns = @(@{ name = 'Cost' }, @{ name = 'CostStatus' }, @{ name = 'SubscriptionId' }, @{ name = 'Currency' })
                                rows    = $forecastRows
                            }
                        }
                    }
                    else {
                        $body = @{
                            properties = @{
                                columns = @(@{ name = 'Cost' }, @{ name = 'Currency' }, @{ name = 'SubscriptionId' })
                                rows    = @(, @(100.0, 'USD', '11111111-1111-1111-1111-111111111111'))
                            }
                        }
                    }
                    [pscustomobject]@{
                        StatusCode = 200
                        Content    = ($body | ConvertTo-Json -Depth 10)
                    }
                }

                $subs = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'test' })
                $result = if ($QueryPath -eq 'PerSubscription') {
                    Get-CostDataPerSubscription -Subscriptions $subs
                }
                else {
                    Get-CostData -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subs
                }

                $entry = $result['11111111-1111-1111-1111-111111111111']
                $entry.Actual | Should -Be 100
                $entry.Forecast | Should -Be 350
                $entry.ForecastSource | Should -Be 'Forecast'
                $forecastCalls = if ($QueryPath -eq 'ManagementGroupFallback') { 2 } else { 1 }
                Should -Invoke Invoke-AzRestMethodWithRetry -Times $forecastCalls -Exactly -ParameterFilter {
                    $request = $Payload | ConvertFrom-Json
                    $Path -like '*forecast*' -and $Method -eq 'POST' -and
                    $request.timePeriod.from -eq '2026-09-01' -and
                    $request.timePeriod.to -eq '2026-09-30' -and
                    $request.includeActualCost -eq $true
                }
            }
        }

        # Month-to-date spend presented as a forecast understates the full month,
        # so callers need to be able to tell the two apart.
        It 'Rejects an unavailable forecast instead of returning actual spend as a projection' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    if ($Path -like '*forecast*') {
                        return [pscustomobject]@{ StatusCode = 404; Content = '{}' }
                    }
                    $body = @{
                        properties = @{
                            columns = @(@{ name = 'Cost' }, @{ name = 'Currency' })
                            rows    = @(, @(100.0, 'USD'))
                        }
                    }
                    [pscustomobject]@{
                        StatusCode = 200
                        Content    = ($body | ConvertTo-Json -Depth 10)
                    }
                }

                $subs = @([pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222'; Name = 'test' })
                { Get-CostDataPerSubscription -Subscriptions $subs } | Should -Throw '*Forecast*404*incomplete*'
            }
        }
    }

    Context 'Budget spend source' {

        # An annual budget compared against one month of subscription spend reads as
        # roughly a twelfth of its real consumption, so an exhausted budget reports
        # On Track. Azure already computes currentSpend for the budget's own scope,
        # filter and time grain.
        It 'Prefers the budget currentSpend over subscription month-to-date' {
            InModuleScope FinOpsMultitool {
                $budget = [pscustomobject]@{
                    name       = 'annual-budget'
                    properties = [pscustomobject]@{
                        amount        = 12000
                        timeGrain     = 'Annually'
                        category      = 'Cost'
                        currentSpend  = [pscustomobject]@{ amount = 11400; unit = 'USD' }
                        forecastSpend = [pscustomobject]@{ amount = 13000; unit = 'USD' }
                    }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{
                        StatusCode = 200
                        Content    = (@{ value = @($budget) } | ConvertTo-Json -Depth 10)
                    }
                }

                $subs = @([pscustomobject]@{ Id = '33333333-3333-3333-3333-333333333333'; Name = 'test' })
                # Subscription month-to-date is a small fraction of the annual budget.
                $costData = @{ '33333333-3333-3333-3333-333333333333' = @{ Actual = 900; Forecast = 1000 } }

                $res = Get-BudgetStatus -Subscriptions $subs -CostData $costData
                $b = @($res.Budgets)[0]

                $b.SpendSource | Should -Be 'Budget'
                $b.ActualSpend | Should -Be 11400
                # 11400/12000 = 95%, and the forecast exceeds the budget.
                $b.Risk | Should -Be 'Forecast Over'
            }
        }
    }

    Context 'Export scope' {
        It 'Keeps unattributed resource charges in the selected subscription total' {
            InModuleScope FinOpsMultitool {
                $subscriptionId = '44444444-4444-4444-4444-444444444444'
                $data = [pscustomobject]@{ CostBasis = 'ActualCost'; Rows = @(
                        [pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = 10; Currency = 'USD'; ResourceId = "/subscriptions/$subscriptionId/resourceGroups/test/providers/Microsoft.Compute/disks/test" }
                        [pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = 20; Currency = 'USD'; ResourceId = '' }
                        [pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = -5; Currency = 'USD'; ResourceId = $null }
                    )
                }
                $subscriptions = @([pscustomobject]@{ Id = $subscriptionId; Name = 'test' })

                $rows = @(ConvertTo-ResourceCostsFromExport -ExportData $data -Subscriptions $subscriptions)

                ($rows | Measure-Object Actual -Sum).Sum | Should -Be 25
                ($rows | Where-Object ResourcePath -EQ '(non-resource charges)').Actual | Should -Be 15
                ($rows | Where-Object ResourcePath -EQ '(non-resource charges)').Subscription | Should -Be 'test'
            }
        }

        It 'Retains each subscription period in <Source> summaries' -ForEach @(
            @{ Source = 'Hub' }
            @{ Source = 'Export' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Source = $Source } {
                param($Source)
                $currentId = '44444444-4444-4444-4444-444444444444'
                $staleId = '55555555-5555-5555-5555-555555555555'
                $rows = @(
                    [pscustomobject]@{ SubAccountId = $currentId; BilledCost = 10; BillingCurrency = 'USD'; ChargePeriodStart = '2026-09-16' }
                    [pscustomobject]@{ SubAccountId = $staleId; BilledCost = 20; BillingCurrency = 'USD'; ChargePeriodStart = '2026-08-31' }
                )
                $result = if ($Source -eq 'Hub') { ConvertTo-CostDataFromHub -HubData $rows }
                else { ConvertTo-CostDataFromExport -ExportData ([pscustomobject]@{ Rows = $rows }) -Subscriptions @([pscustomobject]@{ Id = $currentId }, [pscustomobject]@{ Id = $staleId }) }

                $result[$currentId].ActualPeriod | Should -Be '2026-09-16 to 2026-09-16'
                $result[$staleId].ActualPeriod | Should -Be '2026-08-31 to 2026-08-31'
                $result[$currentId].Actual | Should -Be 10
                $result[$staleId].Actual | Should -Be 20
            }
        }

        It 'Reports historical actuals without synthesizing a current-month forecast' {
            InModuleScope FinOpsMultitool {
                $subscriptionId = '44444444-4444-4444-4444-444444444444'
                $data = [pscustomobject]@{
                    CostBasis = 'ActualCost'
                    Rows      = @([pscustomobject]@{
                            SubscriptionId = $subscriptionId; Cost = 100; Currency = 'EUR'; Date = '2026-08-31'
                            ResourceId = "/subscriptions/$subscriptionId/resourceGroups/test/providers/Microsoft.Compute/disks/test"
                        })
                }
                $subscriptions = @([pscustomobject]@{ Id = $subscriptionId; Name = 'test' })

                $summary = (ConvertTo-CostDataFromExport -ExportData $data -Subscriptions $subscriptions)[$subscriptionId]
                $resource = @(ConvertTo-ResourceCostsFromExport -ExportData $data -Subscriptions $subscriptions)[0]

                foreach ($entry in @($summary, $resource)) {
                    $entry.Actual | Should -Be 100
                    $entry.Forecast | Should -BeNullOrEmpty
                    $entry.ForecastSource | Should -Be 'Unavailable'
                    $entry.ActualPeriod | Should -Be '2026-08-31 to 2026-08-31'
                }
            }
        }

        It 'Requires a verified basis for a classic export (<Basis>)' -ForEach @(
            @{ Basis = $null }
            @{ Basis = 'Usage' }
            @{ Basis = 'AmortizedCost' }
            @{ Basis = 'ActualCost' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Basis = $Basis } {
                param($Basis)
                $data = [pscustomobject]@{
                    CostBasis = $Basis; Currency = 'USD'
                    Rows = @([pscustomobject]@{ SubscriptionId = '44444444-4444-4444-4444-444444444444'; CostInBillingCurrency = 100 })
                }
                if ($Basis -eq 'ActualCost') {
                    (Select-CostExportData -ExportData $data).Rows[0].Cost | Should -Be 100
                }
                else { { Select-CostExportData -ExportData $data } | Should -Throw '*actual cost*' }
            }
        }

        # An export is written at its own scope, usually the whole billing account.
        # Treating an unrecognised subscription as a new entry reported cost for
        # every subscription in the file, not the ones the user asked to scan.
        It 'Ignores rows for subscriptions that were not selected' {
            InModuleScope FinOpsMultitool {
                $selected = '44444444-4444-4444-4444-444444444444'
                $other = '55555555-5555-5555-5555-555555555555'

                $exportData = [pscustomobject]@{
                    CostBasis = 'ActualCost'
                    Currency  = 'USD'
                    ColMap    = [pscustomobject]@{ Cost = 'Cost'; SubscriptionId = 'SubscriptionId'; ResourceId = $null }
                    Rows      = @(
                        [pscustomobject]@{ SubscriptionId = $selected; Cost = '10.00' }
                        [pscustomobject]@{ SubscriptionId = $other; Cost = '999.00' }
                    )
                }
                $subs = @([pscustomobject]@{ Id = $selected; Name = 'selected' })

                $map = ConvertTo-CostDataFromExport -ExportData $exportData -Subscriptions $subs

                $map.Keys | Should -Not -Contain $other
                @($map.Keys).Count | Should -Be 1
                $map[$selected].Actual | Should -Be 10
            }
        }

        It 'Uses the same selected billed-cost rows for <View>' -ForEach @(
            @{ View = 'Summary' }
            @{ View = 'Resources' }
            @{ View = 'Tags' }
            @{ View = 'Trend' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ View = $View } {
                param($View)
                $selected = '44444444-4444-4444-4444-444444444444'
                $other = '55555555-5555-5555-5555-555555555555'
                $rows = @(
                    [pscustomobject]@{ SubscriptionId = $selected; BilledCost = 10; EffectiveCost = 1; BillingCurrency = 'USD'; Date = '2026-09-01'; ResourceId = "/subscriptions/$selected/resourceGroups/test/providers/Microsoft.Compute/disks/one"; Tags = '{"CostCenter":"test"}' }
                    [pscustomobject]@{ SubscriptionId = $other; BilledCost = 990; EffectiveCost = 99; BillingCurrency = 'EUR'; Date = '2026-09-01'; ResourceId = "/subscriptions/$other/resourceGroups/test/providers/Microsoft.Compute/disks/two"; Tags = '{"CostCenter":"other"}' }
                )
                $data = [pscustomobject]@{ Rows = $rows; ColMap = (Resolve-ExportColumns -Header $rows[0].PSObject.Properties.Name); Currency = 'USD' }
                $subscriptions = @([pscustomobject]@{ Id = $selected; Name = 'selected' })
                $total = switch ($View) {
                    'Summary' { (ConvertTo-CostDataFromExport -ExportData $data -Subscriptions $subscriptions)[$selected].Actual }
                    'Resources' { (ConvertTo-ResourceCostsFromExport -ExportData $data -Subscriptions $subscriptions | Measure-Object Actual -Sum).Sum }
                    'Tags' { ((ConvertTo-CostByTagFromExport -ExportData $data -Subscriptions $subscriptions).CostByTag.CostCenter | Measure-Object Cost -Sum).Sum }
                    'Trend' { ((ConvertTo-CostTrendFromExport -ExportData $data -Subscriptions $subscriptions).Months | Measure-Object Cost -Sum).Sum }
                }
                $total | Should -Be 10
            }
        }

        It 'Does not report an uncovered selected subscription as zero spend' {
            InModuleScope FinOpsMultitool {
                $selected = '44444444-4444-4444-4444-444444444444'
                $missing = '55555555-5555-5555-5555-555555555555'
                $data = [pscustomobject]@{
                    CostBasis = 'ActualCost'
                    Currency = 'USD'; ColMap = @{ Cost = 'Cost'; SubscriptionId = 'SubscriptionId' }
                    Rows = @([pscustomobject]@{ Cost = 10; SubscriptionId = $selected })
                }
                $subscriptions = @([pscustomobject]@{ Id = $selected }, [pscustomobject]@{ Id = $missing })
                { ConvertTo-CostDataFromExport -ExportData $data -Subscriptions $subscriptions } | Should -Throw '*coverage*'
            }
        }

        It 'Rejects unreadable export costs instead of using zero' -ForEach @(
            @{ Value = '' }
            @{ Value = 'bad' }
            @{ Value = 'NaN' }
            @{ Value = 'Infinity' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Value = $Value } {
                param($Value)
                $rawValue = $Value
                { ConvertTo-ExportAmount -Value $rawValue } | Should -Throw '*cost*'
            }
        }

        It 'Merges resource and date aliases using row subscription IDs instead of storage ownership' {
            InModuleScope FinOpsMultitool {
                $selected = '44444444-4444-4444-4444-444444444444'
                $other = '55555555-5555-5555-5555-555555555555'
                Mock Get-CostExportData {
                    $row = if ($Export.Name -eq 'first') {
                        [pscustomobject]@{ SubscriptionId = $selected; BilledCost = 10; Currency = 'USD'; ResourceId = "/subscriptions/$selected/resourceGroups/test/providers/Microsoft.Compute/disks/one"; Date = '2026-09-01' }
                    }
                    else {
                        [pscustomobject]@{ SubAccountId = "/subscriptions/$other"; BilledCost = 20; BillingCurrency = 'USD'; x_ResourceId = "/subscriptions/$other/resourceGroups/test/providers/Microsoft.Compute/disks/two"; ChargePeriodStart = '2026-09-01' }
                    }
                    [pscustomobject]@{ Rows = @($row); ColMap = (Resolve-ExportColumns -Header $row.PSObject.Properties.Name); DataDate = [datetime]'2026-09-15'; Currency = 'USD' }
                }
                $exports = @([pscustomobject]@{ Name = 'first'; SubId = 'storage-owner'; ScopeKind = 'Storage' }, [pscustomobject]@{ Name = 'second'; SubId = 'storage-owner'; ScopeKind = 'Storage' })
                $subscriptions = @([pscustomobject]@{ Id = $selected; Name = 'first' }, [pscustomobject]@{ Id = $other; Name = 'second' })

                $merged = Get-MergedCostExportData -Exports $exports -Subscriptions $subscriptions

                $merged.ExportCount | Should -Be 2
                @($merged.CoveredSubscriptionIds).Count | Should -Be 2
                (ConvertTo-ResourceCostsFromExport -ExportData $merged -Subscriptions $subscriptions | Measure-Object Actual -Sum).Sum | Should -Be 30
                ((ConvertTo-CostTrendFromExport -ExportData $merged).Months | Measure-Object Cost -Sum).Sum | Should -Be 30
            }
        }

        It 'Rejects an unreadable or incompatible export rather than omitting it (<Case>)' -ForEach @(
            @{ Case = 'unreadable'; Currency = $null }
            @{ Case = 'different currency'; Currency = 'EUR' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Currency = $Currency } {
                param($Currency)
                $secondCurrency = $Currency
                Mock Get-CostExportData {
                    if ($Export.Name -eq 'second' -and -not $secondCurrency) { return [pscustomobject]@{ Rows = @(); NoData = $true; AccessDenied = $true } }
                    $subscriptionId = if ($Export.Name -eq 'first') { '44444444-4444-4444-4444-444444444444' } else { '55555555-5555-5555-5555-555555555555' }
                    $rowCurrency = if ($Export.Name -eq 'first') { 'USD' } else { $secondCurrency }
                    [pscustomobject]@{ CostBasis = 'ActualCost'; Rows = @([pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = 10; Currency = $rowCurrency }); ColMap = @{ SubscriptionId = 'SubscriptionId'; Cost = 'Cost'; Currency = 'Currency' } }
                }
                { Get-MergedCostExportData -Exports @([pscustomobject]@{ Name = 'first' }, [pscustomobject]@{ Name = 'second' }) } | Should -Throw
            }
        }

        It 'Rejects a failed CSV partition instead of returning the readable part' {
            InModuleScope FinOpsMultitool {
                Mock Get-PlainAccessToken { 'test-token' }
                Mock Get-StorageBlobList {
                    @{ Listed = $true; Blobs = @(
                            [pscustomobject]@{ Name = 'export/run/part1.csv'; LastModified = [datetime]'2026-09-15' }
                            [pscustomobject]@{ Name = 'export/run/part2.csv'; LastModified = [datetime]'2026-09-15' }
                        )
                    }
                }
                Mock Get-StorageBlobBytes {
                    if ($Uri -like '*part2.csv') { return $null }
                    [System.Text.Encoding]::UTF8.GetBytes("SubscriptionId,Cost,Currency`n44444444-4444-4444-4444-444444444444,10,USD")
                }
                $export = [pscustomobject]@{ Name = 'export'; Format = 'Csv'; RootFolder = ''; Container = 'exports'; StorageResourceId = '/subscriptions/test/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/test' }
                { Get-CostExportData -Export $export } | Should -Throw '*part2*incomplete*'
            }
        }

        It 'Keeps untagged charges and escaped JSON values in the selected tag total' {
            InModuleScope FinOpsMultitool {
                $subscriptionId = '44444444-4444-4444-4444-444444444444'
                $rows = @(
                    [pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = 10; Currency = 'USD'; Tags = '{"CostCenter":"A\"B"}' }
                    [pscustomobject]@{ SubscriptionId = $subscriptionId; Cost = 20; Currency = 'USD'; Tags = '' }
                )
                $data = [pscustomobject]@{ CostBasis = 'ActualCost'; Rows = $rows; ColMap = (Resolve-ExportColumns -Header $rows[0].PSObject.Properties.Name) }
                $result = ConvertTo-CostByTagFromExport -ExportData $data -ExistingTags @{ CostCenter = @{} }
                ($result.CostByTag.CostCenter | Measure-Object Cost -Sum).Sum | Should -Be 30
                ($result.CostByTag.CostCenter | Where-Object TagValue -EQ '(untagged)').Cost | Should -Be 20
                ($result.CostByTag.CostCenter | Where-Object TagValue -EQ 'A"B').Cost | Should -Be 10
            }
        }

        It 'Does not present missing date or tag columns as complete empty breakdowns' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ CostBasis = 'ActualCost'; Rows = @([pscustomobject]@{ SubscriptionId = '44444444-4444-4444-4444-444444444444'; Cost = 10; Currency = 'USD' }) }
                { ConvertTo-CostByTagFromExport -ExportData $data } | Should -Throw '*coverage*'
                { ConvertTo-CostTrendFromExport -ExportData $data } | Should -Throw '*coverage*'
            }
        }
    }

    Context 'Commitment cost basis' {

        # FOCUS records a reservation twice on purpose: once as BilledCost on the
        # Purchase row, and again amortized across the Usage rows it covers, which
        # EC9.1 requires to sum to the same amount. Choosing the cost column per row
        # picked BilledCost on the purchase and EffectiveCost on the usage, so every
        # commitment landed in the total twice.
        It 'Counts a commitment once rather than twice' {
            InModuleScope FinOpsMultitool {
                $sub = '66666666-6666-6666-6666-666666666666'
                $hubData = @(
                    # Reservation purchase: billed in full, zero amortized (EC6).
                    [pscustomobject]@{
                        SubAccountId = $sub; SubAccountName = 'test'
                        BilledCost = 12000; EffectiveCost = 0; BillingCurrency = 'USD'
                    }
                    # Usage the reservation covers: nothing billed, amortized share only.
                    [pscustomobject]@{
                        SubAccountId = $sub; SubAccountName = 'test'
                        BilledCost = 0; EffectiveCost = 9000; BillingCurrency = 'USD'
                    }
                    [pscustomobject]@{
                        SubAccountId = $sub; SubAccountName = 'test'
                        BilledCost = 0; EffectiveCost = 3000; BillingCurrency = 'USD'
                    }
                )

                $map = ConvertTo-CostDataFromHub -HubData $hubData

                # 12000 amortized, not 12000 purchase + 12000 amortized.
                $map[$sub].Actual | Should -Be 12000
            }
        }

        It 'Resolves one cost column for the whole dataset' {
            InModuleScope FinOpsMultitool {
                Resolve-HubCostColumn -Props @('BilledCost', 'EffectiveCost') | Should -Be 'BilledCost'
                Resolve-HubCostColumn -Props @('BilledCost', 'EffectiveCost') -CostBasis 'AmortizedCost' | Should -Be 'EffectiveCost'
                Resolve-HubCostColumn -Props @('CostInBillingCurrency') | Should -Be 'CostInBillingCurrency'
                { Resolve-HubCostColumn -Props @('ResourceId') } | Should -Throw '*cost*'
            }
        }

        It 'Uses billed cost for actual spend even when amortization differs' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; BilledCost = 12000; EffectiveCost = 0; BillingCurrency = 'USD' }
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; BilledCost = 0; EffectiveCost = 1000; BillingCurrency = 'USD' }
                )

                $result = ConvertTo-CostDataFromHub -HubData $rows

                $result['66666666-6666-6666-6666-666666666666'].Actual | Should -Be 12000
            }
        }

        It 'Rejects an unreadable selected cost without switching bases (<Case>)' -ForEach @(
            @{ Case = 'null'; Amount = $null }
            @{ Case = 'blank'; Amount = '' }
            @{ Case = 'invalid'; Amount = 'invalid' }
            @{ Case = 'NaN'; Amount = 'NaN' }
            @{ Case = 'infinity'; Amount = 'Infinity' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Amount = $Amount } {
                param($Amount)
                $row = [pscustomobject]@{ EffectiveCost = $Amount; BilledCost = 500 }
                { Get-HubCostValue -Row $row -Column 'EffectiveCost' } | Should -Throw '*cost*'
            }
        }

        It 'Rejects a missing selected column on a later row' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; BilledCost = 10; BillingCurrency = 'USD' }
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; CostInBillingCurrency = 20; BillingCurrency = 'USD' }
                )
                { ConvertTo-CostDataFromHub -HubData $rows } | Should -Throw '*cost*'
            }
        }

        It 'Preserves a measured zero and negative credit in the selected basis' {
            InModuleScope FinOpsMultitool {
                Get-HubCostValue -Row ([pscustomobject]@{ BilledCost = 0; EffectiveCost = 500 }) -Column 'BilledCost' | Should -Be 0
                Get-HubCostValue -Row ([pscustomobject]@{ BilledCost = -25 }) -Column 'BilledCost' | Should -Be -25
            }
        }

        It 'Keeps billed reporting separate from amortized allocation and unit costs' {
            InModuleScope FinOpsMultitool {
                $subscriptionId = '66666666-6666-6666-6666-666666666666'
                $targetResourceId = "/subscriptions/$subscriptionId/resourceGroups/test/providers/Microsoft.CognitiveServices/accounts/test"
                $rows = @([pscustomobject]@{
                        SubAccountId = $subscriptionId; SubAccountName = 'test'; BilledCost = 12000; EffectiveCost = 1000
                        BillingCurrency = 'USD'; ResourceId = $targetResourceId; ResourceType = 'microsoft.cognitiveservices/accounts'
                        Tags = '{"CostCenter":"test"}'; ConsumedQuantity = 0
                        ChargePeriodStart = '2026-08-31T00:00:00Z'
                    })
                Mock Resolve-VmAssociation {
                    $associated = [System.Collections.Generic.HashSet[string]]::new()
                    [void]$associated.Add($targetResourceId)
                    [pscustomobject]@{ Id = $targetResourceId; Name = 'test'; Associated = $associated; SubscriptionId = $subscriptionId }
                }

                @((ConvertTo-ResourceCostsFromHub -HubData $rows))[0].Actual | Should -Be 12000
                (ConvertTo-CostByTagFromHub -HubData $rows).CostByTag.CostCenter[0].Cost | Should -Be 12000
                (Get-AllocationCostMaps -SubscriptionIds @($subscriptionId) -HubData $rows).BySub[$subscriptionId] | Should -Be 1000
                (Get-AllocationCostMaps -SubscriptionIds @($subscriptionId) -HubData $rows).Period | Should -Be '2026-08-31 to 2026-08-31'
                (Get-VmCostBreakdown -VmName 'test' -HubData $rows).TotalCost | Should -Be 1000
                (Get-VmCostBreakdown -VmName 'test' -HubData $rows).Period | Should -Be '2026-08-31 to 2026-08-31'
                (ConvertTo-AIHubAggregates -HubData $rows).AICost | Should -Be 1000
                (ConvertTo-AIHubAggregates -HubData $rows).Period | Should -Be '2026-08-31 to 2026-08-31'
                { Resolve-HubCostColumn -Props @('BilledCost') -CostBasis 'AmortizedCost' } | Should -Throw '*AmortizedCost*EffectiveCost*FOCUS*API*'
                { Resolve-HubCostColumn -Props @('EffectiveCost') -CostBasis 'ActualCost' } | Should -Throw '*ActualCost*'
            }
        }

        It 'Rejects inconsistent currency instead of returning a labeled cost total (<Currency>)' -ForEach @(
            @{ Currency = 'EUR' }
            @{ Currency = '' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Currency = $Currency } {
                param($Currency)
                $rows = @(
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; BilledCost = 10; BillingCurrency = 'USD' }
                    [pscustomobject]@{ SubAccountId = '66666666-6666-6666-6666-666666666666'; BilledCost = 20; BillingCurrency = $Currency }
                )
                { ConvertTo-CostDataFromHub -HubData $rows } | Should -Throw '*currenc*'
                { ConvertTo-CostByTagFromHub -HubData $rows -ExistingTags @{ CostCenter = @{} } } | Should -Throw '*currenc*'
            }
        }

        It 'Rejects resource column drift even when the cost column is unchanged' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD'; ResourceId = 'resource-a' }
                    [pscustomobject]@{ BilledCost = 20; BillingCurrency = 'USD'; x_ResourceId = 'resource-b' }
                )
                { ConvertTo-ResourceCostsFromHub -HubData $rows } | Should -Throw '*schemas differ*'
            }
        }

        It 'Discovers all hub tag keys and keeps case-distinct values' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD'; Tags = '{"env":"Prod"}' }
                    [pscustomobject]@{ BilledCost = 20; BillingCurrency = 'USD'; Tags = '{"env":"prod","Project":"test"}' }
                    [pscustomobject]@{ BilledCost = -5; BillingCurrency = 'USD'; Tags = '' }
                )

                $result = ConvertTo-CostByTagFromHub -HubData $rows

                $result.TagsQueried | Should -Contain 'Project'
                ($result.CostByTag.env | Where-Object { $_.TagValue -ceq 'Prod' }).Cost | Should -Be 10
                ($result.CostByTag.env | Where-Object { $_.TagValue -ceq 'prod' }).Cost | Should -Be 20
                ($result.CostByTag.Project | Measure-Object Cost -Sum).Sum | Should -Be 25
                ($result.CostByTag.env | Measure-Object Cost -Sum).Sum | Should -Be 25
            }
        }

        It 'Handles case-variant tag keys within the same hub record without double counting' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD'; ResourceId = '/subscriptions/test/resources/one'; Tags = '{"project":"shared","Project":"shared","Environment":"Prod"}' }
                    [pscustomobject]@{ BilledCost = 20; BillingCurrency = 'USD'; ResourceId = '/subscriptions/test/resources/two'; Tags = '{"PROJECT":"shared","Environment":"prod"}' }
                    [pscustomobject]@{ BilledCost = -5; BillingCurrency = 'USD'; ResourceId = ''; Tags = '' }
                )

                $result = ConvertTo-CostByTagFromHub -HubData $rows
                $inventory = ConvertTo-TagInventoryFromHub -HubData $rows

                @($result.TagsQueried | Where-Object { $_ -ieq 'Project' }).Count | Should -Be 1
                ($result.CostByTag.Project | Where-Object TagValue -EQ 'shared').Cost | Should -Be 30
                ($result.CostByTag.Project | Measure-Object Cost -Sum).Sum | Should -Be 25
                ($result.CostByTag.Environment | Where-Object { $_.TagValue -ceq 'Prod' }).Cost | Should -Be 10
                ($result.CostByTag.Environment | Where-Object { $_.TagValue -ceq 'prod' }).Cost | Should -Be 20
                $inventory.TaggedCount | Should -Be 2
                $inventory.TagNames.Project.TotalResources | Should -Be 2
                @($inventory.TagNames.Environment.Values).Count | Should -Be 2
            }
        }

        It 'Reports conflicting case-variant tag values once instead of choosing one' {
            InModuleScope FinOpsMultitool {
                $rows = @(
                    [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD'; ResourceId = '/subscriptions/test/resources/one'; Tags = '{"project":"team-a","Project":"team-b"}' }
                    [pscustomobject]@{ BilledCost = 20; BillingCurrency = 'USD'; ResourceId = '/subscriptions/test/resources/two'; Tags = '"project":"team-a"' }
                )

                $result = ConvertTo-CostByTagFromHub -HubData $rows
                $inventory = ConvertTo-TagInventoryFromHub -HubData $rows

                ($result.CostByTag.Project | Where-Object TagValue -EQ '(conflicting tag values)').Cost | Should -Be 10
                ($result.CostByTag.Project | Where-Object TagValue -EQ 'team-a').Cost | Should -Be 20
                ($result.CostByTag.Project | Measure-Object Cost -Sum).Sum | Should -Be 30
                $inventory.TagNames.Project.TotalResources | Should -Be 2
                ($inventory.TagNames.Project.Values | Where-Object Value -EQ '(conflicting tag values)').ResourceCount | Should -Be 1
            }
        }

        It 'Renders Hub tag values in terminal and HTML using the live-inventory contract' {
            InModuleScope FinOpsMultitool -Parameters @{ ModuleRoot = $script:ModuleRoot } {
                param($ModuleRoot)
                $hubRows = @(
                    [pscustomobject]@{ ResourceId = '/subscriptions/test/resources/one'; ResourceType = 'fixture'; Tags = '{"Environment":"Prod","CostCenter":"team-a"}' }
                    [pscustomobject]@{ ResourceId = '/subscriptions/test/resources/two'; ResourceType = 'fixture'; Tags = '{"environment":"prod","CostCenter":"team-a"}' }
                )
                $data = ConvertTo-TagInventoryFromHub -HubData $hubRows
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $console = $launcherAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-FinOpsConsole' }, $true)
                . ([scriptblock]::Create($console.Extent.Text))
                $switches = $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
                $branches = @($switches.Clauses | Where-Object { $_.Item1.Value -eq 'Get-TagInventory' -and $_.Item2.Extent.Text.Contains('Top values') })
                $branches.Count | Should -Be 2
                $htmlSb = [System.Text.StringBuilder]::new()
                $rows = $null
                $htmlRows = $null
                Mock Write-Host { }

                foreach ($branch in $branches) {
                    $body = ($branch.Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"
                    . ([scriptblock]::Create("param(`$data, `$htmlSb)`n$body")) $data $htmlSb
                }

                foreach ($projection in @(@{ Rows = $rows }, @{ Rows = $htmlRows })) {
                    ($projection.Rows | Where-Object Tag -EQ 'CostCenter').'Top values' | Should -Be 'team-a (2)'
                    $environment = ($projection.Rows | Where-Object Tag -EQ 'Environment').'Top values'
                    $environment | Should -Match 'Prod \(1\)'
                    $environment | Should -Match 'prod \(1\)'
                    $environment | Should -Not -Match '^\s*\('
                }
                @($data.TagNames.Environment.Values | Where-Object { $_.Value -ceq 'Prod' }).Count | Should -Be 1
                @($data.TagNames.Environment.Values | Where-Object { $_.Value -ceq 'prod' }).Count | Should -Be 1
            }
        }
    }

    Context 'Amortized query currency' {
        It 'Refuses missing or mixed live currencies (<Case>)' -ForEach @(
            @{ Case = 'blank'; Currency = '' }
            @{ Case = 'mixed'; Currency = 'EUR' }
            @{ Case = 'missing column'; Currency = $null }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Currency = $Currency } {
                param($Currency)
                $targetId = '/subscriptions/44444444-4444-4444-4444-444444444444/resourceGroups/test/providers/Microsoft.Compute/virtualMachines/test'
                $columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' }, @{ name = 'Currency' })
                $rows = @(@(100.0, $targetId, 'USD'), @(100.0, $targetId, $Currency))
                if ($null -eq $Currency) {
                    $columns = @(@{ name = 'Cost' }, @{ name = 'ResourceId' })
                    $rows = @(, @(100.0, $targetId))
                }
                $responseContent = @{ properties = @{ columns = $columns; rows = $rows } } | ConvertTo-Json -Depth 10
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 200; Content = $responseContent } }
                Mock Resolve-VmAssociation {
                    $associated = [System.Collections.Generic.HashSet[string]]::new()
                    [void]$associated.Add($targetId)
                    [pscustomobject]@{ Id = $targetId; Name = 'test'; SubscriptionId = '44444444-4444-4444-4444-444444444444'; ResourceGroup = 'test'; Associated = $associated }
                }

                { Get-AllocationCostMaps -SubscriptionIds @('44444444-4444-4444-4444-444444444444') } | Should -Throw '*currency*incomplete*'
                $vm = Get-VmCostBreakdown -VmName 'test'
                $vm.HasData | Should -BeFalse
                $vm.TotalCost | Should -BeNullOrEmpty
                $vm.Note | Should -BeLike '*currency*incomplete*'
            }
        }
    }

    Context 'Hub storage completeness' {
        It 'Labels the actual <Format> reader instead of inferring it from the cost columns' -ForEach @(
            @{ Format = 'CSV' }
            @{ Format = 'Parquet' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ExpectedFormat = $Format } {
                param($ExpectedFormat)
                $useParquet = $ExpectedFormat -eq 'Parquet'
                Mock Write-Host { }
                Mock New-AzStorageContext { $null }
                Mock Install-ParquetReader { $true }
                Mock Get-AzDataLakeGen2ChildItem {
                    if ($FileSystem -eq 'ingestion') {
                        if ($useParquet) { [pscustomobject]@{ Name = 'part.parquet'; Path = 'Costs/2026/09/part.parquet'; IsDirectory = $false } }
                    }
                    else { [pscustomobject]@{ Name = 'part.csv'; Path = 'export/20260901-20260930/202609180001/run/part.csv'; IsDirectory = $false } }
                }
                Mock Get-AzDataLakeGen2ItemContent { }
                Mock Read-ParquetFile { [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD'; x_SkuTier = 'Premium' } }
                Mock Import-Csv { [pscustomobject]@{ BilledCost = 10; BillingCurrency = 'USD' } }

                $rows = @(Read-FinOpsHubData -StorageAccountName 'fixture' -ResourceGroupName 'fixture' -Months 1)

                $rows.Count | Should -Be 1
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                    "$Object" -match "Total rows from Hub \($ExpectedFormat\): 1"
                }
                $csvReads = if ($useParquet) { 0 } else { 1 }
                Should -Invoke Import-Csv -Times $csvReads -Exactly
            }
        }

        It 'Propagates a Parquet parsing failure instead of returning an empty dataset' {
            $missingFile = Join-Path $TestDrive 'unreadable.parquet'
            { Read-ParquetFile -Path $missingFile } | Should -Throw '*Parquet*incomplete*'
        }

        It 'Only attaches a forecast to current-month hub actuals (<Period>)' -ForEach @(
            @{ Period = 'Current'; ChargeDate = '2026-09-16T00:00:00Z' }
            @{ Period = 'Mixed'; ChargeDate = '2026-09-16T00:00:00Z' }
            @{ Period = 'Stale'; ChargeDate = '2026-08-31T00:00:00Z' }
            @{ Period = 'Unknown'; ChargeDate = $null }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Period = $Period; ChargeDate = $ChargeDate; ModuleRoot = $script:ModuleRoot } {
                param($Period, $ChargeDate, $ModuleRoot)
                $fixtureDate = $ChargeDate
                $mixedPeriods = $Period -eq 'Mixed'
                $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                foreach ($definition in $scriptAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -in @('Invoke-SelectedScans', 'Write-SectionHeader', 'Write-FinOpsConsole') }, $true)) {
                    . ([scriptblock]::Create($definition.Extent.Text))
                }
                Mock Get-Date { [datetime]::new(2026, 9, 17, 12, 0, 0, [DateTimeKind]::Utc) }
                Mock Resolve-FOHubProvider { @{ Found = $false } }
                Mock Read-FinOpsHubData {
                    [pscustomobject]@{ BilledCost = 310; BillingCurrency = 'USD'; SubAccountId = '44444444-4444-4444-4444-444444444444'; ChargePeriodStart = $fixtureDate; Tags = '' }
                    if ($mixedPeriods) {
                        [pscustomobject]@{ BilledCost = 50; BillingCurrency = 'USD'; SubAccountId = '55555555-5555-5555-5555-555555555555'; ChargePeriodStart = '2026-08-31T00:00:00Z'; Tags = '' }
                    }
                }
                Mock ConvertTo-TagInventoryFromHub { [pscustomobject]@{ TagCount = 0; TagCoverage = 0 } }
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 403; Content = '{}' } }
                Mock Get-CostData { @{ '44444444-4444-4444-4444-444444444444' = @{ Actual = 100; Forecast = 180; ForecastSource = 'Forecast'; Currency = 'USD' } } }
                $modules = @([pscustomobject]@{ Name = 'Costs'; Fn = 'Get-CostData'; Selected = $true })
                $subscriptions = @([pscustomobject]@{ Id = '44444444-4444-4444-4444-444444444444'; Name = 'test' })
                if ($mixedPeriods) { $subscriptions += [pscustomobject]@{ Id = '55555555-5555-5555-5555-555555555555'; Name = 'older' } }

                $result = Invoke-SelectedScans -Modules $modules -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -DataSource @{ Source = 'Hub'; HubStorage = @{ name = 'test'; resourceGroup = 'test' } }

                $entry = $result['Get-CostData'][$subscriptions[0].Id]
                $entry.Actual | Should -Be 310
                if ($Period -in @('Current', 'Mixed')) {
                    $entry.Forecast | Should -Be 180
                    $entry.ActualPeriod | Should -Match '2026-09'
                    Should -Invoke Get-CostData -Times 1 -Exactly
                    Should -Invoke Get-CostData -Times 1 -Exactly -ParameterFilter {
                        $Subscriptions.Count -eq 1 -and $Subscriptions[0].Id -eq '44444444-4444-4444-4444-444444444444'
                    }
                    if ($mixedPeriods) {
                        $older = $result['Get-CostData']['55555555-5555-5555-5555-555555555555']
                        $older.ActualPeriod | Should -Be '2026-08-31 to 2026-08-31'
                        $older.Forecast | Should -BeNullOrEmpty
                    }
                }
                else {
                    $entry.Forecast | Should -BeNullOrEmpty
                    $entry.ActualPeriod | Should -Be $(if ($Period -eq 'Stale') { '2026-08-31 to 2026-08-31' } else { 'Unknown' })
                    Should -Invoke Get-CostData -Times 0 -Exactly
                }
            }
        }

        It 'Does not return partial hub data after a <Source> file fails' -ForEach @(
            @{ Source = 'Parquet' }
            @{ Source = 'CSV' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Source = $Source } {
                param($Source)
                $useCsv = $Source -eq 'CSV'
                Mock New-AzStorageContext { $null }
                Mock Install-ParquetReader { $true }
                Mock Get-AzDataLakeGen2ChildItem {
                    if ($FileSystem -eq 'ingestion' -and $useCsv) { return @() }
                    if ($FileSystem -eq 'msexports' -and -not $useCsv) { throw 'Unexpected CSV fallback.' }
                    $extension = if ($useCsv) { 'csv' } else { 'parquet' }
                    @(
                        [pscustomobject]@{ Name = "part1.$extension"; Path = "export/20260901-20260930/202609170001/run/part1.$extension"; IsDirectory = $false }
                        [pscustomobject]@{ Name = "part2.$extension"; Path = "export/20260901-20260930/202609170001/run/part2.$extension"; IsDirectory = $false }
                    )
                }
                Mock Get-AzDataLakeGen2ItemContent { if ($Path -like '*part2*') { throw 'Simulated download failure.' } }
                Mock Read-ParquetFile { [pscustomobject]@{ BilledCost = 100; BillingCurrency = 'USD'; SubAccountId = '44444444-4444-4444-4444-444444444444' } }
                Mock Import-Csv { [pscustomobject]@{ BilledCost = 100; BillingCurrency = 'USD'; SubAccountId = '44444444-4444-4444-4444-444444444444' } }

                { Read-FinOpsHubData -StorageAccountName 'test' -ResourceGroupName 'test' -SubscriptionIds @('44444444-4444-4444-4444-444444444444') } |
                Should -Throw '*incomplete*'
            }
        }

        It 'Does not accept missing selected subscriptions as complete hub coverage' {
            InModuleScope FinOpsMultitool {
                Mock New-AzStorageContext { $null }
                Mock Install-ParquetReader { $true }
                Mock Get-AzDataLakeGen2ChildItem { [pscustomobject]@{ Name = 'one.parquet'; Path = 'one.parquet'; IsDirectory = $false } }
                Mock Get-AzDataLakeGen2ItemContent { }
                Mock Read-ParquetFile { [pscustomobject]@{ BilledCost = 100; BillingCurrency = 'USD'; SubAccountId = '44444444-4444-4444-4444-444444444444' } }

                { Read-FinOpsHubData -StorageAccountName 'test' -ResourceGroupName 'test' -SubscriptionIds @('44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555') } |
                Should -Throw '*coverage*'
            }
        }

        It 'Keeps a <Source> hub failure visible to the scan runner without an API fallback' -ForEach @(
            @{ Source = 'Storage' }
            @{ Source = 'Kusto' }
            @{ Source = 'KustoAI' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Source = $Source; ModuleRoot = $script:ModuleRoot } {
                param($Source, $ModuleRoot)
                $sourceName = $Source
                $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $console = $scriptAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-FinOpsConsole' }, $true)
                . ([scriptblock]::Create($console.Extent.Text))
                $runner = $scriptAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Invoke-SelectedScans' }, $true)
                . ([scriptblock]::Create($runner.Extent.Text))
                $sectionHeader = $scriptAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-SectionHeader' }, $true)
                . ([scriptblock]::Create($sectionHeader.Extent.Text))
                Mock Resolve-FOHubProvider { @{ Found = ($sourceName -in @('Kusto', 'KustoAI')); Mode = 'Kusto' } }
                Mock Read-FinOpsHubData { throw 'Hub coverage incomplete.' }
                Mock Get-FOHubCostSummary { @{ Error = 'Hub coverage incomplete.' } }
                Mock Get-FOHubResourceCosts { @{ Error = 'Hub coverage incomplete.' } }
                Mock Get-FOHubCostByTag { @{ Error = 'Hub coverage incomplete.' } }
                Mock Get-CostData { @{ unexpected = @{ Actual = 100; Currency = 'USD' } } }
                Mock Get-AIWorkloadMetrics { [pscustomobject]@{ HasData = $true; TotalAICost = 100; Source = 'API' } }
                $scanName = if ($Source -eq 'KustoAI') { 'Get-AIWorkloadMetrics' } else { 'Get-CostData' }
                $modules = @([pscustomobject]@{ Name = 'Costs'; Fn = $scanName; Selected = $true })
                $subscriptions = @([pscustomobject]@{ Id = '44444444-4444-4444-4444-444444444444'; Name = 'test' })
                $dataSource = @{ Source = 'Hub'; HubStorage = @{ name = 'test'; resourceGroup = 'test' } }

                $result = Invoke-SelectedScans -Modules $modules -Subscriptions $subscriptions -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -DataSource $dataSource

                $expectedError = if ($Source -eq 'KustoAI') { '*unavailable*selected Kusto hub source*' } else { '*coverage incomplete*' }
                $result["_error_$scanName"] | Should -BeLike $expectedError
                @($result[$scanName]).Count | Should -Be 0
                Should -Invoke Get-CostData -Times 0 -Exactly
                Should -Invoke Get-AIWorkloadMetrics -Times 0 -Exactly
            }
        }

        It 'Keeps a measured zero AI hub result on the selected source' {
            InModuleScope FinOpsMultitool {
                Mock Search-AzGraphSafe {
                    @{ Data = @([pscustomobject]@{ type = 'microsoft.cognitiveservices/accounts'; lkind = 'OpenAI'; id = '/subscriptions/test/providers/Microsoft.CognitiveServices/accounts/ai'; name = 'ai' }) }
                }
                Mock Invoke-AzRestMethodWithRetry { throw 'A hub result must not call the live cost API.' }
                Mock Get-PlainAccessToken { throw 'A hub result must not call live metrics.' }
                $hubRows = @([pscustomobject]@{ EffectiveCost = 0; BillingCurrency = 'USD'; ResourceId = '/subscriptions/test/providers/Microsoft.CognitiveServices/accounts/ai'; ResourceType = 'microsoft.cognitiveservices/accounts'; ChargePeriodStart = '2026-08-31'; ConsumedQuantity = 0 })

                $result = Get-AIWorkloadMetrics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -HubData $hubRows

                $result.Source | Should -Be 'FinOpsHub'
                $result.TotalAICost | Should -Be 0
                $result.Period | Should -Be '2026-08-31 to 2026-08-31'
                Should -Invoke Invoke-AzRestMethodWithRetry -Times 0 -Exactly
                Should -Invoke Get-PlainAccessToken -Times 0 -Exactly
            }
        }
    }

    Context 'Commitment utilization' {

        # Get-CommitmentUtilization seeds both averages to 0 and only fills the ones
        # it found. Treating that 0 as a measurement halves the score for anyone who
        # owns reservations but no savings plans, and reports 100% waste when the
        # utilization read was denied.
        It 'Ignores a family that has no commitments' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ RICount = 10; RIAvgUtilization = 100; SPCount = 0; SPAvgUtilization = 0 }
                @(Get-CommitmentUtilizationValue -Data $data) | Should -Be @(100)
            }
        }

        It 'Keeps a real 0% when commitments exist' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ RICount = 3; RIAvgUtilization = 0; SPCount = 0; SPAvgUtilization = 0 }
                @(Get-CommitmentUtilizationValue -Data $data) | Should -Be @(0)
            }
        }

        It 'Reports nothing when no commitments were found at all' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ RICount = 0; RIAvgUtilization = 0; SPCount = 0; SPAvgUtilization = 0 }
                @(Get-CommitmentUtilizationValue -Data $data).Count | Should -Be 0
            }
        }
    }

    Context 'Cost trend guidance' {
        It 'Uses comparable completed months for <Case>' -ForEach @(
            @{ Case = 'the reported September data'; Now = '2026-09-18T12:00:00Z'; Dates = @('2026-05-01', '2026-07-01', '2026-08-01', '2026-09-01'); Costs = @(1359.56, 1205.47, 751.48, 441.78); Currencies = @('USD', 'USD', 'USD', 'USD'); Expected = 'decreased 37.7% from Jul 2026 to Aug 2026' }
            @{ Case = 'a year boundary'; Now = '2026-02-18T12:00:00Z'; Dates = @('2025-12-01', '2026-01-01', '2026-02-01'); Costs = @(100, 110, 10); Currencies = @('EUR', 'EUR', 'EUR'); Expected = 'increased 10% from Dec 2025 to Jan 2026' }
            @{ Case = 'only one completed month'; Now = '2026-09-18T12:00:00Z'; Dates = @('2026-08-01', '2026-09-01'); Costs = @(100, 10); Currencies = @('USD', 'USD'); Expected = 'needs two completed months' }
            @{ Case = 'a missing calendar month'; Now = '2026-09-18T12:00:00Z'; Dates = @('2026-05-01', '2026-08-01'); Costs = @(100, 10); Currencies = @('USD', 'USD'); Expected = 'two consecutive completed months' }
            @{ Case = 'different billing currencies'; Now = '2026-09-18T12:00:00Z'; Dates = @('2026-07-01', '2026-08-01'); Costs = @(100, 10); Currencies = @('EUR', 'USD'); Expected = 'unknown or different currencies' }
            @{ Case = 'a zero baseline'; Now = '2026-09-18T12:00:00Z'; Dates = @('2026-07-01', '2026-08-01'); Costs = @(0, 10); Currencies = @('USD', 'USD'); Expected = 'no positive net cost' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ ModuleRoot = $script:ModuleRoot; Now = $Now; Dates = $Dates; Costs = $Costs; Currencies = $Currencies; Expected = $Expected } {
                param($ModuleRoot, $Now, $Dates, $Costs, $Currencies, $Expected)
                $fixtureNow = [datetime]::Parse($Now, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                Mock Get-Date { $fixtureNow }
                $months = @(for ($index = 0; $index -lt $Dates.Count; $index++) {
                        $monthDate = [datetime]::ParseExact($Dates[$index], 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
                        [pscustomobject]@{ Month = $monthDate.ToString('MMM yyyy'); MonthDate = $monthDate; Cost = $Costs[$index]; Currency = $Currencies[$index] }
                    })
                $data = [pscustomobject]@{ Months = $months }
                $launcherAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $switches = $launcherAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
                $branch = @($switches.Clauses | Where-Object { $_.Item1.Value -eq 'Get-CostTrend' -and $_.Item2.Extent.Text.Contains('$guidanceItems') })
                $branch.Count | Should -Be 1
                $guidanceItems = @()
                $body = ($branch[0].Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"

                . ([scriptblock]::Create("param(`$data)`n$body")) $data

                ($guidanceItems.Message -join ' ') | Should -Match ([regex]::Escape($Expected))
                ($guidanceItems.Message -join ' ') | Should -Not -Match '67.5%|Optimization efforts are working|Good cost discipline'
                $guidanceItems.Severity | Should -Not -Contain 'Green'
            }
        }
    }

    Context 'Hourly cost reporting' {
        It 'Keeps small unit costs and hourly rates above zero' {
            InModuleScope FinOpsMultitool {
                Mock Write-Host { }
                Mock Get-Date { [datetime]::new(2026, 9, 17, 0, 0, 0, [DateTimeKind]::Utc) }
                Mock Search-AzGraphSafe {
                    if ($Query -match 'virtualmachines') {
                        @{ Data = @([pscustomobject]@{ cnt = 4; vmSize = 'Standard_D2s_v5'; loc = 'eastus'; subId = '11111111-1111-1111-1111-111111111111' }) }
                    }
                    else { @{ Data = @([pscustomobject]@{ totalGb = 0 }) } }
                }
                Mock Get-VmSizeCapability { @{ VCpu = 2; MemGb = 8 } }
                Mock Get-StorageAccountUsedGb { 0.9 }
                Mock Resolve-CostMgId { $null }
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = '{"properties":{"columns":[{"name":"Cost"},{"name":"MeterCategory"},{"name":"Currency"}],"rows":[[0.12,"Virtual Machines","USD"],[9.08,"Storage","USD"]]}}' }
                }
                $subscriptions = @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Fixture' })

                $result = Get-UnitEconomics -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -Subscriptions $subscriptions
                $hourly = Get-KpiComputedValue -KpiId 'hourly-cost-per-cpu-core' -Data $result

                $result.CostPerVCpu | Should -Be 0.015
                $result.CostPerGbRam | Should -Be 0.00375
                $result.CostPerVm | Should -Be 0.03
                (Format-FinOpsUnitRate -Value $result.CostPerGbRam -Currency $result.Currency) | Should -Be 'USD 0.00375'
                $hourly.Value | Should -Be 0.0000390625
                $hourly.Display | Should -Be 'USD 0.00003906 per vCPU / hour'
                (Format-FinOpsUnitRate -Value 0.000000000001 -Currency 'USD') | Should -Be 'USD 1E-12'
                (Format-FinOpsUnitRate -Value 0 -Currency 'USD') | Should -Be 'USD 0'
            }
        }

        It 'Uses the UTC month instead of a local calendar that is still in August' {
            InModuleScope FinOpsMultitool {
                Mock Get-Date { [datetime]::new(2026, 9, 1, 2, 0, 0, [DateTimeKind]::Utc) }
                Mock Get-Date { [datetime]::new(2026, 8, 1) } -ParameterFilter { $Day -eq 1 }
                $data = [pscustomobject]@{ CostPerVCpu = 2.0; Currency = 'USD' }

                $result = Get-KpiComputedValue -KpiId 'hourly-cost-per-cpu-core' -Data $data

                $result.Value | Should -Be 1.0
            }
        }

        It 'Uses the captured cost window when the report is rendered later' {
            InModuleScope FinOpsMultitool {
                Mock Get-Date { [datetime]::new(2026, 10, 2, 0, 0, 0, [DateTimeKind]::Utc) }
                Mock Get-Date { [datetime]::new(2026, 10, 1) } -ParameterFilter { $Day -eq 1 }
                $data = [pscustomobject]@{
                    CostPerVCpu        = 384.0
                    Currency           = 'USD'
                    CostPeriodStartUtc = [datetime]::new(2026, 9, 1, 0, 0, 0, [DateTimeKind]::Utc)
                    CostPeriodEndUtc   = [datetime]::new(2026, 9, 17, 0, 0, 0, [DateTimeKind]::Utc)
                }

                $result = Get-KpiComputedValue -KpiId 'hourly-cost-per-cpu-core' -Data $data

                $result.Value | Should -Be 1.0
                Should -Invoke Get-Date -Times 0 -Exactly
            }
        }
    }

    Context 'Budget KPI completeness' {
        It 'Does not label an unavailable budget KPI as computed' {
            InModuleScope FinOpsMultitool {
                Mock Get-KpiCatalog {
                    @{ kpis = @([pscustomobject]@{ id = 'variance-budget-vs-actual'; sourceTool = 'scan_budget_status'; compute = $true }) }
                }
                $result = Add-KpiInsights -Result @{ tool = 'scan_budget_status'; data = @{ CoverageIncomplete = $true; Budgets = @() } }

                $result.kpiInsights[0].status | Should -Be 'unavailable'
                $result.kpiInsights[0].numericValue | Should -BeNullOrEmpty
                $result.kpiInsights[0].yourValue | Should -BeLike '*Unavailable*'
            }
        }

        It 'Leaves combined KPIs unscored for <Case>' -ForEach @(
            @{ Case = 'unknown spend'; Change = 'Unknown' }
            @{ Case = 'mixed currencies'; Change = 'Currency' }
            @{ Case = 'different periods'; Change = 'Period' }
            @{ Case = 'overlapping scopes'; Change = 'Scope' }
            @{ Case = 'incomplete inventory'; Change = 'Coverage' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Change = $Change } {
                param($Change)
                $first = [pscustomobject]@{ Amount = 1000; ActualSpend = 500; PctUsed = 50; Currency = 'EUR'; TimeGrain = 'Monthly'; Category = 'Cost'; SubscriptionId = 'one'; SpendSource = 'Budget' }
                $second = [pscustomobject]@{ Amount = 9000; ActualSpend = 4500; PctUsed = 50; Currency = 'EUR'; TimeGrain = 'Monthly'; Category = 'Cost'; SubscriptionId = 'two'; SpendSource = 'Budget' }
                $first | Add-Member -NotePropertyName TimePeriod -NotePropertyValue @{ startDate = (Get-Date).ToUniversalTime().Date.AddYears(-1) }
                $second | Add-Member -NotePropertyName TimePeriod -NotePropertyValue @{ startDate = (Get-Date).ToUniversalTime().Date.AddYears(-1) }
                switch ($Change) {
                    'Unknown' { $second.ActualSpend = $null; $second.PctUsed = $null; $second.SpendSource = 'Unavailable' }
                    'Currency' { $second.Currency = 'USD' }
                    'Period' { $second.TimeGrain = 'Annually' }
                    'Scope' { $second.SubscriptionId = 'one' }
                }
                $data = [pscustomobject]@{ Budgets = @($first, $second); CoverageIncomplete = ($Change -eq 'Coverage') }

                $variance = Get-KpiComputedValue -KpiId 'variance-budget-vs-actual' -Data $data
                $burn = Get-KpiComputedValue -KpiId 'budget-burn-rate' -Data $data

                $variance.Value | Should -BeNullOrEmpty
                $burn.Value | Should -BeNullOrEmpty
                $variance.Display | Should -Match 'Unavailable'
            }
        }

        It 'Reports comparable known budgets using their currency' {
            InModuleScope FinOpsMultitool {
                $data = [pscustomobject]@{ Budgets = @(
                        [pscustomobject]@{ Amount = 1000; ActualSpend = 500; Currency = 'EUR'; TimeGrain = 'Monthly'; Category = 'Cost'; SubscriptionId = 'one'; TimePeriod = @{ startDate = (Get-Date).ToUniversalTime().Date.AddYears(-1) } }
                        [pscustomobject]@{ Amount = 1000; ActualSpend = 1500; Currency = 'EUR'; TimeGrain = 'Monthly'; Category = 'Cost'; SubscriptionId = 'two'; TimePeriod = @{ startDate = (Get-Date).ToUniversalTime().Date.AddYears(-1) } }
                    )
                }
                $variance = Get-KpiComputedValue -KpiId 'variance-budget-vs-actual' -Data $data
                $burn = Get-KpiComputedValue -KpiId 'budget-burn-rate' -Data $data

                $variance.Value | Should -Be 0
                $variance.Display | Should -Match 'EUR'
                $variance.Display | Should -Not -Match 'USD'
                $burn.Value | Should -Be 100
            }
        }
    }

    Context 'Observed-period reporting' {
        It 'Uses the AI result period in terminal, HTML, guidance, and KPI text' {
            InModuleScope FinOpsMultitool -Parameters @{ ModuleRoot = $script:ModuleRoot } {
                param($ModuleRoot)
                $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
                $formatter = $scriptAst.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Write-ColorizedLine' }, $true)
                if ($formatter) { . ([scriptblock]::Create($formatter.Extent.Text)) }
                $switches = $scriptAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
                $branches = @($switches.Clauses | Where-Object { $_.Item1.Value -eq 'Get-AIWorkloadMetrics' -and $_.Item2.Extent.Text.Contains('$data.HasData') })
                $branches.Count | Should -Be 3
                $captured = [System.Collections.Generic.List[string]]::new()
                Mock Write-ColorizedLine { [void]$captured.Add($Text) }
                $data = [pscustomobject]@{
                    HasData = $true; Period = '2026-08-01 to 2026-08-31'; Currency = 'EUR'; TotalTokens = 1000; TotalAICost = 25; CostPer1KTokens = 25
                    TotalPromptTokens = 800; TotalGeneratedTokens = 200; TotalRequests = 0; CostPerRequest = $null
                    AIFootprint = @{ OpenAIAccounts = 1; AIServices = 0; MLWorkspaces = 0; SearchServices = 0; GpuVmCount = 0 }
                }
                $htmlSb = [System.Text.StringBuilder]::new()
                $guidanceItems = @()
                foreach ($branch in $branches) {
                    $body = ($branch.Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"
                    . ([scriptblock]::Create("param(`$data, `$htmlSb)`n$body")) $data $htmlSb
                }

                ($captured -join ' ') | Should -Match '2026-08-01 to 2026-08-31'
                ($captured -join ' ') | Should -Not -Match 'MTD'
                $htmlSb.ToString() | Should -Match '2026-08-01 to 2026-08-31'
                $htmlSb.ToString() | Should -Not -Match 'MTD'
                ($guidanceItems.Message -join ' ') | Should -Match '2026-08-01 to 2026-08-31'
                $kpi = Get-KpiComputedValue -KpiId 'token-consumption-metrics' -Data $data
                $kpi.Display | Should -Match '2026-08-01 to 2026-08-31'
                $kpi.Display | Should -Not -Match 'MTD'
            }
        }
    }

    Context 'Budget reporting' {

        It 'Does not call budgets healthy when forecasts are unavailable' {
            $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:ModuleRoot 'Invoke-FinOpsMultitool.ps1'), [ref]$null, [ref]$null)
            $switches = $scriptAst.FindAll({ $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
            $branch = @($switches.Clauses | Where-Object { $_.Item1.Value -eq 'Get-BudgetStatus' -and $_.Item2.Extent.Text.Contains('$bCoverage') })
            $branch.Count | Should -Be 1
            $data = [pscustomobject]@{
                AtRiskCount = 0; OverBudgetCount = 0; BudgetCoverage = 100; CoverageIncomplete = $false
                Budgets = @([pscustomobject]@{ Amount = 1000; ActualSpend = 500; Forecast = $null; Risk = 'Forecast unavailable' })
            }
            $guidanceItems = @()
            $body = ($branch[0].Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"

            . ([scriptblock]::Create("param(`$data)`n$body")) $data

            $guidanceItems.Count | Should -BeGreaterThan 0
            @($guidanceItems | Where-Object Severity -EQ 'Green').Count | Should -Be 0
            $guidanceItems[0].Message | Should -Match 'unavailable'
        }

        It 'Displays unknown amounts explicitly while preserving known currency and zero' {
            InModuleScope FinOpsMultitool {
                Format-BudgetAmount -Value $null -Currency 'USD' | Should -Be 'Unavailable'
                Format-BudgetAmount -Value 500 -Currency '' | Should -Be 'Unavailable'
                Format-BudgetAmount -Value 'NaN' -Currency 'USD' | Should -Be 'Unavailable'
                Format-BudgetAmount -Value 0 -Currency 'EUR' | Should -Match '^EUR 0[.,]00$'
                Format-BudgetAmount -Value 500 -Currency 'EUR' | Should -Match '^EUR '
            }
        }

        It 'Keeps an unavailable forecast separate from known current spend' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"name":"monthly","properties":{"amount":1000,"timeGrain":"Monthly","category":"Cost","currentSpend":{"amount":500,"unit":"EUR"}}}]}' }
                }
                $subscriptions = @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888'; Name = 'test' })

                $budget = (Get-BudgetStatus -Subscriptions $subscriptions).Budgets[0]

                $budget.ActualSpend | Should -Be 500
                $budget.PctUsed | Should -Be 50
                $budget.Forecast | Should -BeNullOrEmpty
                $budget.PctForecast | Should -BeNullOrEmpty
                $budget.ForecastSource | Should -Be 'Unavailable'
                $budget.Risk | Should -Not -Be 'On Track'
                $budget.Currency | Should -Be 'EUR'
            }
        }

        It 'Does not turn an invalid budget denominator into an on-track budget (<Case>)' -ForEach @(
            @{ Case = 'missing'; Amount = $null }
            @{ Case = 'zero'; Amount = 0 }
            @{ Case = 'negative'; Amount = -1 }
            @{ Case = 'NaN'; Amount = 'NaN' }
        ) {
            InModuleScope FinOpsMultitool -Parameters @{ Amount = $Amount } {
                param($Amount)
                $properties = @{ amount = $Amount; timeGrain = 'Monthly'; category = 'Cost'; currentSpend = @{ amount = 500; unit = 'USD' } }
                $content = @{ value = @(@{ name = 'test'; properties = $properties }) } | ConvertTo-Json -Depth 8
                Mock Invoke-AzRestMethodWithRetry { [pscustomobject]@{ StatusCode = 200; Content = $content } }
                $budget = (Get-BudgetStatus -Subscriptions @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888' })).Budgets[0]

                $budget.Amount | Should -BeNullOrEmpty
                $budget.PctUsed | Should -BeNullOrEmpty
                $budget.Risk | Should -Be 'Unknown'
                $budget.Note | Should -BeLike '*amount*'
            }
        }

        It 'Does not compare a forecast denominated in another unit to the budget' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"name":"monthly","properties":{"amount":1000,"timeGrain":"Monthly","category":"Cost","currentSpend":{"amount":500,"unit":"USD"},"forecastSpend":{"amount":1500,"unit":"EUR"}}}]}' }
                }
                $budget = (Get-BudgetStatus -Subscriptions @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888' })).Budgets[0]

                $budget.Currency | Should -Be 'USD'
                $budget.Forecast | Should -BeNullOrEmpty
                $budget.Risk | Should -Not -Be 'Forecast Over'
                $budget.Note | Should -BeLike '*unit*'
            }
        }

        It 'Preserves the budget filter and leaves unknown spend null' {
            InModuleScope FinOpsMultitool {
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"name":"filtered","properties":{"amount":1000,"timeGrain":"Monthly","category":"Cost","filter":{"tags":{"name":"CostCenter","operator":"In","values":["team"]}},"timePeriod":{"startDate":"2026-01-01T00:00:00Z","endDate":"2026-12-31T00:00:00Z"}}}]}' }
                }
                $budget = (Get-BudgetStatus -Subscriptions @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888' })).Budgets[0]

                $budget.ActualSpend | Should -BeNullOrEmpty
                $budget.Forecast | Should -BeNullOrEmpty
                $budget.Filter.tags.name | Should -Be 'CostCenter'
                $budget.TimePeriod.startDate | Should -Not -BeNullOrEmpty
                $budget.Currency | Should -BeNullOrEmpty
            }
        }

        # A budget whose spend could not be read must not average into burn-rate KPIs
        # as though it were untouched.
        It 'Leaves percentages null when spend is unknown' {
            InModuleScope FinOpsMultitool {
                $budget = [pscustomobject]@{
                    name       = 'quarterly-filtered'
                    properties = [pscustomobject]@{
                        amount = 5000; timeGrain = 'Quarterly'; category = 'Cost'
                        filter = [pscustomobject]@{ tags = @{} }
                    }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($budget) } | ConvertTo-Json -Depth 10) }
                }

                $subs = @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888'; Name = 'test' })
                $costData = @{ '88888888-8888-8888-8888-888888888888' = @{ Actual = 900; Forecast = 1000; Currency = 'USD' } }

                $b = @((Get-BudgetStatus -Subscriptions $subs -CostData $costData).Budgets)[0]
                $b.SpendSource | Should -Be 'Unavailable'
                $b.Risk | Should -Be 'Unknown'
                $b.PctUsed | Should -BeNullOrEmpty
            }
        }

        # currentSpend carries its own unit; the subscription's currency may differ.
        It 'Reports the currency that belongs to the budget amount' {
            InModuleScope FinOpsMultitool {
                $budget = [pscustomobject]@{
                    name       = 'eur-budget'
                    properties = [pscustomobject]@{
                        amount = 1000; timeGrain = 'Monthly'; category = 'Cost'
                        currentSpend = [pscustomobject]@{ amount = 500; unit = 'EUR' }
                    }
                }
                Mock Invoke-AzRestMethodWithRetry {
                    [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @($budget) } | ConvertTo-Json -Depth 10) }
                }

                $subs = @([pscustomobject]@{ Id = '99999999-9999-9999-9999-999999999999'; Name = 'test' })
                $b = @((Get-BudgetStatus -Subscriptions $subs -CostData @{}).Budgets)[0]
                $b.Currency | Should -Be 'EUR'
            }
        }
    }
}
