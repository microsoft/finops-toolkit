# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'PR workflow permissions and scripts' -Tag 'Actions' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $deploy = (Get-Content "$repoRoot/.github/workflows/ftk-pr-deploy.yml" -Raw).Replace("`r`n", "`n")
        $cleanup = (Get-Content "$repoRoot/.github/workflows/ftk-pr-cleanup.yml" -Raw).Replace("`r`n", "`n")
        $bash = if ($IsWindows) { Join-Path $env:ProgramFiles 'Git/bin/bash.exe' } else { (Get-Command bash -ErrorAction Stop).Source }

        function Get-WorkflowScript($Content, $StepName)
        {
            $pattern = '(?ms)^      - name: ' + [regex]::Escape($StepName) +
                '\r?\n.*?^        run: \|\r?\n(?<script>(?:^          [^\r\n]*(?:\r?\n|$)|^\r?\n)+)'
            $match = [regex]::Match($Content, $pattern)
            if (-not $match.Success)
            {
                throw "Cannot find the script for '$StepName'."
            }
            $match.Groups['script'].Value -replace '(?m)^          ', ''
        }

        function Invoke-WorkflowBash($Script, $Variables)
        {
            $start = [System.Diagnostics.ProcessStartInfo]::new($bash)
            $start.ArgumentList.Add('--noprofile')
            $start.ArgumentList.Add('--norc')
            $start.ArgumentList.Add('-e')
            $start.ArgumentList.Add('-o')
            $start.ArgumentList.Add('pipefail')
            $start.ArgumentList.Add('-c')
            $start.ArgumentList.Add($Script)
            $start.RedirectStandardOutput = $true
            $start.RedirectStandardError = $true
            $start.UseShellExecute = $false
            foreach ($key in $Variables.Keys)
            {
                $start.Environment[$key] = if ($key -eq 'GITHUB_OUTPUT') { $Variables[$key].Replace('\', '/') } else { $Variables[$key] }
            }
            $process = [System.Diagnostics.Process]::Start($start)
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            $exitCode = $process.ExitCode
            $process.Dispose()
            @{ ExitCode = $exitCode; Stdout = $stdout; Stderr = $stderr }
        }

        $fileCheck = Get-WorkflowScript $deploy 'Check for template file changes'
        $fileCheck = $fileCheck.Replace('${{ github.event.pull_request.number }}', '42').
            Replace('${{ github.repository }}', 'microsoft/finops-toolkit')
        $script:fakeGh = @'
gh() {
  if [ "$GH_TEST_FAILURE" = "true" ]; then
    echo "File request failed" >&2
    return 1
  fi
  printf '%s\n' "$GH_TEST_FILES"
}
'@
        $checkboxScript = Get-WorkflowScript $deploy 'Parse deployment checkboxes'
        # Test the checkbox function and its actual calls without the separate GNU grep URI extractor.
        $checkboxScript = ($checkboxScript -split '# Extract Fabric URI', 2)[0]
        $script:deleteScript = [scriptblock]::Create((Get-WorkflowScript $cleanup 'Delete resource groups'))

        function Get-AzResourceGroup { throw 'Tests must mock Azure reads.' }
        function Remove-AzResourceGroup
        {
            [CmdletBinding(SupportsShouldProcess)]
            param([string]$Name, [switch]$Force)
            if ($PSCmdlet.ShouldProcess($Name, 'Delete resource group'))
            {
                throw "Tests must mock Azure deletion (Force=$Force)."
            }
        }
    }

    It 'Uses only the unprivileged PR trigger for deployment' {
        $deploy | Should -Match '(?m)^  pull_request:$'
        $deploy | Should -Not -Match '(?m)^  (pull_request_target|workflow_run|issue_comment):'
        $deploy | Should -Not -Match 'Needs: Deployment'
    }

    It 'Rejects fork PRs in the options job and every deployment job' {
        $jobs = [regex]::Matches($deploy, '(?ms)^  (?<name>check-options|deploy-[a-z]+):\r?\n(?<body>.*?)(?=^  [a-z][a-z-]+:\r?$|\z)')
        $jobs.Count | Should -Be 7
        foreach ($job in $jobs)
        {
            $job.Groups['body'].Value | Should -Match '(?m)^    if: github\.event\.pull_request\.head\.repo\.full_name == github\.repository'
        }
    }

    It 'Checks out the exact commit without retaining credentials in all six deployment jobs' {
        ([regex]::Matches($deploy, 'ref: \$\{\{ github\.event\.pull_request\.head\.sha \}\}\r?\n          persist-credentials: false')).Count | Should -Be 6
        ([regex]::Matches($deploy, 'key: az-modules-reviewed-pr-v1-')).Count | Should -Be 6
        $deploy | Should -Not -Match 'restore-keys:'
    }

    It 'Runs cleanup only on closure, without checkout or PR code' {
        $cleanup | Should -Match 'pull_request_target:\r?\n    types: \[closed\]'
        $cleanup | Should -Not -Match 'actions/checkout|workflow_run|download-artifact'
        ([regex]::Matches($cleanup, '(?m)^\s+uses:')).Count | Should -Be 1
        $deploy | Should -Match '(?m)^permissions: \{\}'
        $cleanup | Should -Match '(?m)^permissions: \{\}'
        $cleanup | Should -Not -Match '(?m)^\s+contents:'
        foreach ($match in [regex]::Matches($cleanup, '(?ms)^        run: \|\r?\n(?<script>(?:^          [^\r\n]*(?:\r?\n|$)|^\r?\n)+)'))
        {
            $match.Groups['script'].Value | Should -Not -Match '\$\{\{'
        }
    }

    It 'Detects template changes: <Name>' -ForEach @(
        @{ Name = 'template'; Files = 'src/templates/finops-hub/main.bicep'; Changed = 'true' }
        @{ Name = 'non-template'; Files = 'src/scripts/Build-Toolkit.ps1'; Changed = 'false' }
        @{ Name = 'documentation'; Files = "src/templates/finops-hub/README.md`nsrc/templates/finops-hub/docs/setup.md"; Changed = 'false' }
        @{ Name = 'test'; Files = 'src/templates/finops-hub/test/main.bicep'; Changed = 'false' }
        @{ Name = 'empty diff'; Files = ''; Changed = 'false' }
        @{ Name = 'mixed diff'; Files = "src/templates/finops-hub/docs/setup.md`nsrc/templates/finops-hub/main.bicep"; Changed = 'true' }
    ) {
        $output = Join-Path $TestDrive 'files-output'
        Remove-Item $output -ErrorAction SilentlyContinue
        $result = Invoke-WorkflowBash "$fakeGh`n$fileCheck" @{
            GH_TEST_FILES = $Files; GH_TEST_FAILURE = 'false'; GITHUB_OUTPUT = $output
        }
        $result.ExitCode | Should -Be 0 -Because $result.Stderr
        (Get-Content $output -Raw).Trim() | Should -Be "changed=$Changed"
    }

    It 'Stops when the file-list request fails' {
        $output = Join-Path $TestDrive 'failed-files-output'
        $result = Invoke-WorkflowBash "$fakeGh`n$fileCheck" @{
            GH_TEST_FILES = ''; GH_TEST_FAILURE = 'true'; GITHUB_OUTPUT = $output
        }
        $result.ExitCode | Should -Not -Be 0
        $result.Stderr | Should -Match 'File request failed'
        Test-Path $output | Should -BeFalse
    }

    It 'Selects each deployment option without selecting the others: <Option>' -ForEach @(
        @{ Option = 'Hubs + ADX (managed)'; Output = 'deploy-adx' }
        @{ Option = 'Hubs + Fabric (manual)'; Output = 'deploy-fabric' }
        @{ Option = 'Hubs (manual)'; Output = 'deploy-manual' }
        @{ Option = 'Hubs (no data)'; Output = 'deploy-nodata' }
        @{ Option = 'Workbooks'; Output = 'deploy-workbooks' }
        @{ Option = 'Alerts'; Output = 'deploy-alerts' }
    ) {
        $outputPath = Join-Path $TestDrive 'checkbox-output'
        Remove-Item $outputPath -ErrorAction SilentlyContinue
        $result = Invoke-WorkflowBash $checkboxScript @{
            PR_BODY = "> - [x] $Option"; GITHUB_OUTPUT = $outputPath
        }
        $result.ExitCode | Should -Be 0 -Because $result.Stderr
        $lines = @(Get-Content $outputPath)
        $lines.Count | Should -Be 6
        $lines | Should -Contain "$Output=true"
        @($lines | Where-Object { $_ -like '*=true' }).Count | Should -Be 1
    }

    It 'Treats an empty body as six unchecked options' {
        $output = Join-Path $TestDrive 'empty-body-output'
        $result = Invoke-WorkflowBash $checkboxScript @{ PR_BODY = ''; GITHUB_OUTPUT = $output }
        $result.ExitCode | Should -Be 0 -Because $result.Stderr
        @(Get-Content $output | Where-Object { $_ -like '*=false' }).Count | Should -Be 6
    }

    Context 'Resource deletion with mocked Azure commands' {
        BeforeEach {
            $script:savedPrNumber = $env:PR_NUMBER
            $script:savedOutput = $env:GITHUB_OUTPUT
            $env:PR_NUMBER = '42'
            $env:GITHUB_OUTPUT = Join-Path $TestDrive 'cleanup-output'
            Remove-Item $env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
            Mock Get-AzResourceGroup { @() }
            Mock Remove-AzResourceGroup {}
        }

        AfterEach {
            $env:PR_NUMBER = $savedPrNumber
            $env:GITHUB_OUTPUT = $savedOutput
        }

        It 'Reports zero deletions when no matching group exists' {
            & $deleteScript
            Get-Content $env:GITHUB_OUTPUT | Should -Contain 'deleted=0'
            Get-Content $env:GITHUB_OUTPUT | Should -Contain 'failed='
            Should -Invoke Remove-AzResourceGroup -Times 0
        }

        It 'Deletes only groups belonging to the closed PR' {
            Mock Get-AzResourceGroup {
                'pr-42-adx', 'pr-42-workbooks', 'pr-420-adx', 'pr-4-adx', 'production' |
                    ForEach-Object { [pscustomobject]@{ ResourceGroupName = $_ } }
            }
            & $deleteScript
            Should -Invoke Remove-AzResourceGroup -Times 2 -Exactly
            Should -Invoke Remove-AzResourceGroup -Times 1 -Exactly -ParameterFilter { $Name -eq 'pr-42-adx' -and $Force }
            Should -Invoke Remove-AzResourceGroup -Times 1 -Exactly -ParameterFilter { $Name -eq 'pr-42-workbooks' -and $Force }
            Get-Content $env:GITHUB_OUTPUT | Should -Contain 'deleted=2'
        }

        It 'Reports failed deletion and continues with the remaining groups' {
            Mock Get-AzResourceGroup {
                'pr-42-adx', 'pr-42-workbooks' | ForEach-Object { [pscustomobject]@{ ResourceGroupName = $_ } }
            }
            Mock Remove-AzResourceGroup { throw 'Deletion denied' } -ParameterFilter { $Name -eq 'pr-42-adx' }
            $warnings = @(& $deleteScript 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $warnings.Count | Should -Be 1
            $warnings[0].Message | Should -Match 'Failed to delete pr-42-adx'
            Get-Content $env:GITHUB_OUTPUT | Should -Contain 'deleted=1'
            Get-Content $env:GITHUB_OUTPUT | Should -Contain 'failed=pr-42-adx'
            Should -Invoke Remove-AzResourceGroup -Times 2 -Exactly
        }

        It 'Stops on a failed resource-list request' {
            Mock Get-AzResourceGroup { throw 'Resource request failed' }
            { & $deleteScript } | Should -Throw '*Resource request failed*'
            Should -Invoke Remove-AzResourceGroup -Times 0
        }

        It 'Rejects a non-numeric PR number before requesting resources' {
            $env:PR_NUMBER = '42*'
            { & $deleteScript } | Should -Throw
            Should -Invoke Get-AzResourceGroup -Times 0
            Should -Invoke Remove-AzResourceGroup -Times 0
        }
    }
}
