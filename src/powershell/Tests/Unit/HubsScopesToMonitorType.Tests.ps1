# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for issue #2443: scopesToMonitor must be string[] so that passing the
    settings.json object shape ({ scope: ... }) fails early with a validation error instead of at
    join(scopesToMonitor, '|') in the Core module.
#>

Describe 'HubsScopesToMonitorType' {
    BeforeDiscovery {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $files = @(
            'src/templates/finops-hub/main.bicep'
            'src/templates/finops-hub/modules/hub.bicep'
            'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Core/app.bicep'
        ) | ForEach-Object { @{ Path = Join-Path $repoRoot $_; Name = $_ } }
    }

    It 'Declares scopesToMonitor as string[] in <Name>' -ForEach $files {
        $content = Get-Content -Path $Path -Raw
        $content | Should -Match '(?m)^param scopesToMonitor string\[\]'
        $content | Should -Not -Match '(?m)^param scopesToMonitor array'
    }

    It 'Describes the string format and settings.json difference in <Name>' -ForEach $files {
        $content = Get-Content -Path $Path -Raw
        $content | Should -Match "(?m)^@description\('[^\n]*scope ID strings[^\n]*settings\.json[^\n]*'\)\r?\nparam scopesToMonitor"
    }

    It 'Compiles to an ARM array parameter with string items' -Skip:(-not (Get-Command bicep -ErrorAction SilentlyContinue)) {
        $main = Join-Path (Resolve-Path "$PSScriptRoot/../../../..").Path 'src/templates/finops-hub/main.bicep'
        $arm = (& bicep build $main --stdout 2>$null) -join "`n" | ConvertFrom-Json
        $param = $arm.parameters.scopesToMonitor
        $param.type | Should -Be 'array'
        $param.items.type | Should -Be 'string'
        @($param.defaultValue).Count | Should -Be 0
    }
}
