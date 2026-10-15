Describe 'FinOps multitool packaged integration' -Tag 'MultitoolLocal' {
    BeforeAll {
        $previousResults = Get-Variable -Name FinOpsResults -Scope Global -ErrorAction SilentlyContinue
        $script:HadFinOpsResults = $null -ne $previousResults
        $script:PreviousFinOpsResultsValue = $null
        if ($script:HadFinOpsResults) { $script:PreviousFinOpsResultsValue = $previousResults.Value }
        $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
        $script:BuildRoot = Join-Path $TestDrive 'package-source'
        foreach ($relativePath in @('.build', 'src/scripts', 'src/powershell')) {
            $null = New-Item -ItemType Directory -Path (Join-Path $script:BuildRoot $relativePath) -Force
        }
        Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot '.build/BuildHelper') -Destination (Join-Path $script:BuildRoot '.build') -Recurse
        Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot '.build/BuildHelper.psm1') -Destination (Join-Path $script:BuildRoot '.build')
        Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'src/scripts/Get-Version.ps1') -Destination (Join-Path $script:BuildRoot 'src/scripts')
        Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'package.json') -Destination $script:BuildRoot
        foreach ($name in @('FinOpsToolkit.psm1', 'Private', 'Public', 'en-US')) {
            Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot "src/powershell/$name") -Destination (Join-Path $script:BuildRoot 'src/powershell') -Recurse
        }
        Import-Module (Join-Path $script:BuildRoot '.build/BuildHelper.psm1') -Force
        Build-PsModule
        $version = (& (Join-Path $script:BuildRoot 'src/scripts/Get-Version.ps1')).Split('-')[0]
        $script:PackageRoot = Join-Path $script:BuildRoot "release/FinOpsToolkit/$version"
        $script:PackageManifest = Join-Path $script:PackageRoot 'FinOpsToolkit.psd1'
        Import-Module $script:PackageManifest -Force -ErrorAction Stop
        Import-Module (Join-Path $script:PackageRoot 'Private/FinOpsMultitool/FinOpsMultitool.psm1') -Force -Global -ErrorAction Stop
    }

    AfterAll {
        Remove-Module FinOpsToolkit, FinOpsMultitool, BuildHelper -ErrorAction SilentlyContinue
        if ($script:HadFinOpsResults) {
            Set-Variable -Name FinOpsResults -Scope Global -Value $script:PreviousFinOpsResultsValue
        }
        else { Remove-Variable -Name FinOpsResults -Scope Global -ErrorAction SilentlyContinue }
    }

    It 'Imports the built manifest and exports the real public launcher' {
        $builder = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:BuildRoot '.build/BuildHelper/Build-PsModule.ps1'), [ref]$null, [ref]$null)
        $directoryLiterals = @($builder.FindAll({
                    $args[0] -is [Management.Automation.Language.StringConstantExpressionAst] -and
                    $args[0].Value -match '^src/powershell/(private|public|en-US)$'
                }, $true).Value)
        $directoryLiterals.Count | Should -Be 3
        foreach ($relativePath in $directoryLiterals) {
            $leafName = Split-Path $relativePath -Leaf
            $parentPath = Join-Path $script:BuildRoot (Split-Path $relativePath -Parent)
            @(Get-ChildItem -LiteralPath $parentPath -Directory | Where-Object { $_.Name -ceq $leafName }).Count | Should -Be 1
        }
        $module = Test-ModuleManifest -Path $script:PackageManifest -ErrorAction Stop
        $module.ExportedFunctions.Keys | Should -Contain 'Start-FinOpsMultitool'
        $command = Get-Command Start-FinOpsMultitool -Module FinOpsToolkit -ErrorAction Stop
        $command.ScriptBlock.File | Should -Be (Join-Path $script:PackageRoot 'Public/Start-FinOpsMultitool.ps1')
        $module.Path | Should -Be $script:PackageManifest
    }

    It 'Packages the nested scanner, Parquet reader, and KPI catalog' {
        foreach ($relativePath in @(
                'Private/FinOpsMultitool/FinOpsMultitool.psm1'
                'Private/FinOpsMultitool/Invoke-FinOpsMultitool.ps1'
                'Private/FinOpsMultitool/modules/helpers/Read-FinOpsHubData.ps1'
                'Private/FinOpsMultitool/kpi/kpi-catalog.json'
            )) {
            Test-Path -LiteralPath (Join-Path $script:PackageRoot $relativePath) -PathType Leaf | Should -BeTrue
        }
        $catalog = Get-Content -LiteralPath (Join-Path $script:PackageRoot 'Private/FinOpsMultitool/kpi/kpi-catalog.json') -Raw | ConvertFrom-Json
        $catalog.kpis.Count | Should -BeGreaterThan 0
    }

    It 'Runs the packaged public launcher and writes CSV, HTML, and text reports without Azure access' {
        (Get-Module FinOpsMultitool).Path | Should -Be (Join-Path $script:PackageRoot 'Private/FinOpsMultitool/FinOpsMultitool.psm1')
        Mock Import-Module -ModuleName FinOpsToolkit { }
        Mock Clear-Host -ModuleName FinOpsToolkit { }
        Mock Write-Host -ModuleName FinOpsToolkit { }
        Mock Read-Host -ModuleName FinOpsToolkit { throw 'The packaged noninteractive launcher must not prompt.' }
        Mock Connect-AzAccount -ModuleName FinOpsToolkit { throw 'The packaged smoke test must not authenticate.' }
        Mock Get-AzTenant -ModuleName FinOpsToolkit { throw 'The packaged smoke test must not enumerate tenants.' }
        Mock Get-AzContext -ModuleName FinOpsToolkit {
            [pscustomobject]@{ Account = @{ Id = 'test@example.test' }; Tenant = @{ Id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' } }
        }
        Mock Get-AzSubscription -ModuleName FinOpsToolkit {
            [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; Name = 'Synthetic subscription'; TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; State = 'Enabled' }
        }
        Mock Set-AzContext -ModuleName FinOpsToolkit { }
        Mock Search-AzGraph -ModuleName FinOpsToolkit { throw 'Explicit API mode must not discover a hub.' }
        Mock Resolve-CostMgId -ModuleName FinOpsMultitool { $null }
        foreach ($moduleName in @('FinOpsToolkit', 'FinOpsMultitool')) {
            Mock Invoke-RestMethod -ModuleName $moduleName { throw 'Unexpected external HTTP request.' }
            Mock Invoke-WebRequest -ModuleName $moduleName { throw 'Unexpected external HTTP request.' }
            Mock Get-AzAccessToken -ModuleName $moduleName { throw 'The packaged smoke test must not request a token.' }
        }
        Mock Invoke-AzRestMethod -ModuleName FinOpsMultitool { throw 'Unexpected direct Azure REST request.' }
        Mock Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool {
            if ($Path -notmatch '^/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft\.CostManagement/(query|forecast)\?') {
                throw 'Unexpected API path in the packaged smoke test.'
            }
            $amount = if ($Path -match '/forecast\?') { 150.0 } else { 100.0 }
            $content = @{ properties = @{ columns = @(@{ name = 'Cost' }, @{ name = 'Currency' }); rows = @(, @($amount, 'EUR')) } } | ConvertTo-Json -Depth 8
            [pscustomobject]@{ StatusCode = 200; Content = $content }
        }

        $reportRoot = Join-Path $TestDrive 'packaged reports'
        Start-FinOpsMultitool -SubscriptionId '11111111-1111-1111-1111-111111111111' -Scans Get-CostData -DataSource API -OutputPath $reportRoot -NonInteractive -ErrorAction Stop

        $scanResults = Get-Variable -Name FinOpsResults -Scope Global -ValueOnly
        $scanResults.ContainsKey('_error_Get-CostData') | Should -BeFalse -Because ($scanResults | ConvertTo-Json -Depth 8 -Compress)
        $runs = @(Get-ChildItem -LiteralPath $reportRoot -Directory)
        $runs.Count | Should -Be 1
        $csvFiles = @(Get-ChildItem -LiteralPath $runs[0].FullName -Filter '*.csv')
        $csvFiles.Count | Should -Be 1
        $rows = @(Import-Csv -LiteralPath $csvFiles[0].FullName)
        $rows.Count | Should -Be 1
        $rows[0].SubscriptionId | Should -Be '11111111-1111-1111-1111-111111111111'
        $rows[0].Actual | Should -Be '100'
        $rows[0].Forecast | Should -Be '150'
        $rows[0].Currency | Should -Be 'EUR'
        $html = Get-Content -LiteralPath (Join-Path $runs[0].FullName 'FinOpsReport.html') -Raw
        $html | Should -Match 'Scans Run</div><div class="value">1</div>'
        $html | Should -Match 'EUR'
        $summary = Get-Content -LiteralPath (Join-Path $runs[0].FullName 'ScanSummary.txt') -Raw
        $summary | Should -Match 'Cost Data'
        $summary | Should -Not -Match 'ERROR:'
        Should -Invoke Invoke-AzRestMethodWithRetry -ModuleName FinOpsMultitool -Times 2 -Exactly
        Should -Invoke Invoke-AzRestMethod -ModuleName FinOpsMultitool -Times 0 -Exactly
        Should -Invoke Connect-AzAccount -ModuleName FinOpsToolkit -Times 0 -Exactly
        Should -Invoke Get-AzTenant -ModuleName FinOpsToolkit -Times 0 -Exactly
        Should -Invoke Get-AzSubscription -ModuleName FinOpsToolkit -Times 1 -Exactly -ParameterFilter {
            $SubscriptionId -eq '11111111-1111-1111-1111-111111111111' -and $TenantId -eq 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        }
    }
}