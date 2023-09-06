# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeDiscovery {
    $moduleRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.FullName
    $moduleName = Split-Path -Path ($PSCommandPath.Replace('.Tests.ps1', '.psm1')) -Leaf
    $modulePath = Get-ChildItem -Path $moduleRoot -Recurse -Include $moduleName
    if (-not $modulePath)
    {
        throw "Cannot find associated function for test: '$PSCommandPath'."
    }
    elseif ($modulePath.Count -gt 1)
    {
        throw "Found multiple files matching module $moduleName."
    }

    $allFunctions = @()
    $publicFunctions = Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath 'public') -Filter '*.ps1'
    $privateFunctions = Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath 'private') -Filter '*.ps1'

    Import-Module -FullyQualifiedName $modulePath.FullName
}
    Describe 'Public function - <_>' -ForEach $publicFunctions.FullName {        
        It "Should import '$_' public function" {
            $functionName = [System.IO.Path]::GetFileNameWithoutExtension($_)
            $commands = Get-Command -Name $functionName -Module 'FinOpsToolkit'
            $commands.Name | Should -Be $functionName
        }

        <#It 'Should import FinOpsToolKit.strings.psd1' {
            $script:localizedData | Should -Not -BeNullOrEmpty
        }#>
    }

    Describe 'Private function - <_>' -ForEach $publicFunctions.FullName {        
        It "Should not export '$_' private function" {
            $functionName = [System.IO.Path]::GetFileNameWithoutExtension($_)
            $commands = Get-Command -Name $functionName -Module 'FinOpsToolkit'
            $commands | Should -Be $null
        }

        <#It 'Should import FinOpsToolKit.strings.psd1' {
            $script:localizedData | Should -Not -BeNullOrEmpty
        }#>
    }

