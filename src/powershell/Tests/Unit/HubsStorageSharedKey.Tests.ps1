# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Structural coverage for the opt-in disableStorageSharedKeyAccess hub parameter (#2312):
    - hub storage accounts derive allowSharedKeyAccess from the option (default keeps Shared Key on)
    - the option is plumbed from main.bicep through hub.bicep into hub-types
    - the private-mode deployment script storage account always keeps Shared Key on
#>

Describe 'HubsStorageSharedKey' {
    BeforeAll {
        $root = (Resolve-Path "$PSScriptRoot/../../../templates/finops-hub").Path
        $hubApp = Get-Content "$root/modules/fx/hub-app.bicep" -Raw
        $infra = Get-Content "$root/modules/Microsoft.FinOpsHubs/Core/infrastructure.bicep" -Raw
        $main = Get-Content "$root/main.bicep" -Raw
        $hub = Get-Content "$root/modules/hub.bicep" -Raw
        $types = Get-Content "$root/modules/fx/hub-types.bicep" -Raw
    }

    It 'Hub storage accounts derive allowSharedKeyAccess from the option' {
        $hubApp | Should -Match 'allowSharedKeyAccess:\s*!app\.hub\.options\.disableStorageSharedKeyAccess'
    }

    It 'Option defaults to false (Shared Key stays enabled)' {
        $main | Should -Match 'param disableStorageSharedKeyAccess bool = false'
        $hub | Should -Match 'param disableStorageSharedKeyAccess bool = false'
    }

    It 'Option is plumbed through main, hub, and hub-types' {
        $main | Should -Match 'disableStorageSharedKeyAccess:\s*disableStorageSharedKeyAccess'
        $hub | Should -Match '(?m)^\s+disableStorageSharedKeyAccess,?\s*$'
        $types | Should -Match 'disableStorageSharedKeyAccess:\s*disableStorageSharedKeyAccess'
    }

    It 'Private-mode script storage account always allows Shared Key' {
        $m = [regex]::Match($infra, "resource scriptStorageAccount '[^']+' = [\s\S]*?\n}\n")
        $m.Success | Should -BeTrue
        $m.Value | Should -Match 'allowSharedKeyAccess:\s*true'
        $m.Value | Should -Not -Match 'disableStorageSharedKeyAccess'
    }
}
