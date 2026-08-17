# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Runs the MCP protocol harness under Pester so it executes in CI
# (Test.PowerShell.All) instead of only when someone remembers to run it by hand.
# Protocol-only: -SkipLive means no Azure session or Az modules are needed.

Describe 'FinOps Multitool MCP server protocol' {

    BeforeAll {
        $script:harness = Join-Path -Path $PSScriptRoot -ChildPath '../../Private/FinOpsMultitool/Test-McpServer.ps1'
        $script:shell = (Get-Process -Id $PID).Path
    }

    It 'Should ship the protocol test harness' {
        Test-Path -LiteralPath $script:harness | Should -BeTrue
    }

    It 'Should pass every protocol assertion' {
        # Child process so the harness owns its own stdio for the JSON-RPC loop.
        $out = & $script:shell -NoProfile -NonInteractive -File $script:harness -SkipLive 2>&1
        $code = $LASTEXITCODE
        if ($code -ne 0) { Write-Host ($out | Out-String) }
        $code | Should -Be 0
        ($out | Out-String) | Should -Match '0 failed'
    }
}
