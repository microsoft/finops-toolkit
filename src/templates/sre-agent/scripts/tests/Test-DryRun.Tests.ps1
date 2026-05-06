#requires -Version 7.0

$ErrorActionPreference = 'Stop'

Describe 'post-provision.ps1 -DryRun' {
    BeforeAll {
        function New-TestFile {
            param(
                [Parameter(Mandatory)]
                [string] $Path,

                [Parameter(Mandatory)]
                [string] $Content
            )

            $parent = Split-Path -Parent $Path
            if ($parent) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            Set-Content -Path $Path -Value $Content -NoNewline
        }

        $sourceScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'post-provision.ps1'
        $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sre-agent-dryrun-$([guid]::NewGuid().ToString('N'))"
        $script:TempRepo = Join-Path $script:TestRoot 'repo'
        $script:BinDir = Join-Path $script:TestRoot 'bin'
        $script:SrectlFailLog = Join-Path $script:TestRoot 'srectl.fail.log'
        $script:AzFailLog = Join-Path $script:TestRoot 'az.fail.log'
        $script:CopiedScript = Join-Path $script:TempRepo 'scripts/post-provision.ps1'
        $script:OriginalPath = $env:PATH
        $script:OriginalEndpoint = $env:SRE_AGENT_ENDPOINT

        New-Item -ItemType Directory -Path $script:BinDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TempRepo 'scripts') -Force | Out-Null
        Copy-Item -Path $sourceScript -Destination $script:CopiedScript -Force

        New-TestFile -Path (Join-Path $script:TempRepo 'sre-config/skills/example-skill/README.md') -Content @'
# Example skill
Dry-run fixture for post-provision.ps1.
'@
        New-TestFile -Path (Join-Path $script:TempRepo 'sre-config/agents/example-agent.yaml') -Content @'
name: example-agent
description: Dry-run fixture
'@
        New-TestFile -Path (Join-Path $script:TempRepo 'tools/example-tool.yaml') -Content @'
name: example-tool
description: Dry-run fixture
'@
        New-TestFile -Path (Join-Path $script:TempRepo 'sre-config/knowledge/example.md') -Content @'
# Example knowledge
Dry-run fixture for knowledge upload.
'@
        New-TestFile -Path (Join-Path $script:TempRepo 'sre-config/scheduled-tasks/example-task.yaml') -Content @'
name: example-task
prompt: Run the dry-run fixture.
'@

        New-Item -ItemType File -Path $script:SrectlFailLog -Force | Out-Null
        New-Item -ItemType File -Path $script:AzFailLog -Force | Out-Null

        New-TestFile -Path (Join-Path $script:BinDir 'srectl') -Content (@'
#!/usr/bin/env pwsh
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
Add-Content -Path '{0}' -Value ('srectl invoked during dry-run: ' + ($Args -join ' '))
[Console]::Error.WriteLine('mock srectl should not be invoked during dry-run')
exit 1
'@ -f $script:SrectlFailLog)
        New-TestFile -Path (Join-Path $script:BinDir 'az') -Content (@'
#!/usr/bin/env pwsh
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
Add-Content -Path '{0}' -Value ('az invoked during dry-run: ' + ($Args -join ' '))
[Console]::Error.WriteLine('mock az should not be invoked during dry-run')
exit 1
'@ -f $script:AzFailLog)

        if ($IsLinux -or $IsMacOS) {
            & chmod +x $script:CopiedScript (Join-Path $script:BinDir 'srectl') (Join-Path $script:BinDir 'az')
        }

        $separator = [System.IO.Path]::PathSeparator
        $env:PATH = "$($script:BinDir)$separator$($script:OriginalPath)"
        $env:SRE_AGENT_ENDPOINT = 'https://fake.azuresre.ai'

        $output = & pwsh -NoProfile -File $script:CopiedScript -DryRun *>&1
        $script:ExitCode = $LASTEXITCODE
        $script:OutputText = ($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    }

    AfterAll {
        $env:PATH = $script:OriginalPath

        if ($null -eq $script:OriginalEndpoint) {
            Remove-Item Env:SRE_AGENT_ENDPOINT -ErrorAction SilentlyContinue
        }
        else {
            $env:SRE_AGENT_ENDPOINT = $script:OriginalEndpoint
        }

        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Should exit with code 0 on dry-run' {
        $script:ExitCode | Should -Be 0
    }

    It 'Should output DRY-RUN prefixed lines' {
        $script:OutputText | Should -Match '\[DRY-RUN\]'
    }

    It 'Should log at least one line per category (skill, agent, tool, knowledge, scheduled task)' {
        $script:OutputText | Should -Match '(?i)\[DRY-RUN\].*skill'
        $script:OutputText | Should -Match '(?i)\[DRY-RUN\].*agent'
        $script:OutputText | Should -Match '(?i)\[DRY-RUN\].*tool'
        $script:OutputText | Should -Match '(?i)\[DRY-RUN\].*knowledge'
        $script:OutputText | Should -Match '(?i)\[DRY-RUN\].*scheduled task'
    }

    It 'Should NOT invoke srectl during dry-run' {
        (Get-Content -Path $script:SrectlFailLog -Raw) | Should -BeNullOrEmpty
    }

    It 'Should NOT invoke az CLI during dry-run' {
        (Get-Content -Path $script:AzFailLog -Raw) | Should -BeNullOrEmpty
    }
}
