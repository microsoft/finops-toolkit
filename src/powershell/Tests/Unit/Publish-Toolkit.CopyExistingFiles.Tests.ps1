# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Copy-ExistingFiles' {
    BeforeAll {
        # Publish-Toolkit.ps1 has top-level executable script logic, so dot-sourcing
        # it would trigger the publish flow. Extract the function definition via the
        # PowerShell AST and define it in the test scope instead.
        $scriptPath = Join-Path (Get-Item -Path $PSScriptRoot).Parent.Parent.Parent.FullName 'scripts/Publish-Toolkit.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $functionAst = $ast.FindAll(
            {
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq 'Copy-ExistingFiles'
            },
            $true
        ) | Select-Object -First 1

        if (-not $functionAst)
        {
            throw "Copy-ExistingFiles not found in $scriptPath"
        }

        . ([scriptblock]::Create($functionAst.Extent.Text))

        function New-TestFile([string]$path, [string]$content)
        {
            New-Item (Split-Path $path) -ItemType Directory -Force | Out-Null
            $content | Out-File $path -NoNewline
        }
    }

    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid())
        $source = Join-Path $root 'source'
        $target = Join-Path $root 'target folder'

        New-TestFile "$source/Main.workbook" 'new main'
        New-TestFile "$source/Storage/Storage.workbook" 'new storage'
        New-TestFile "$source/Compute/Extra.workbook" 'new extra'
        New-TestFile "$source/workbook.json" 'new json'

        New-TestFile "$target/Main.workbook" 'old main'
        New-TestFile "$target/Storage/Storage.workbook" 'old storage'
        New-TestFile "$target/Legacy/Legacy.workbook" 'old legacy'
        New-TestFile "$target/workbook.json" 'old json'
    }

    It 'Replaces matching files that the target already has, including in subfolders' {
        Copy-ExistingFiles $source $target '*.workbook' 3>$null

        Get-Content "$target/Main.workbook" -Raw | Should -Be 'new main'
        Get-Content "$target/Storage/Storage.workbook" -Raw | Should -Be 'new storage'
    }

    It 'Skips a file the target does not have and warns about it' {
        $warnings = @(Copy-ExistingFiles $source $target '*.workbook' 3>&1)

        Test-Path "$target/Compute/Extra.workbook" | Should -BeFalse
        $warnings | Should -HaveCount 1
        "$warnings" | Should -BeLike '*Compute/Extra.workbook*'
    }

    It 'Leaves files alone that do not match the filter or exist only in the target' {
        Copy-ExistingFiles $source $target '*.workbook' 3>$null

        Get-Content "$target/workbook.json" -Raw | Should -Be 'old json'
        Get-Content "$target/Legacy/Legacy.workbook" -Raw | Should -Be 'old legacy'
    }
}
