# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Get-TemplateFolder' {
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
                $node.Name -eq 'Get-TemplateFolder'
            },
            $true
        ) | Select-Object -First 1

        if (-not $functionAst)
        {
            throw "Get-TemplateFolder not found in $scriptPath"
        }

        . ([scriptblock]::Create($functionAst.Extent.Text))
    }

    BeforeEach {
        $releaseDir = Join-Path $TestDrive ([guid]::NewGuid())
        'finops-hub', 'finops-hub-copilot', 'finops-hub-copilot-studio', 'governance-workbook' `
        | ForEach-Object { New-Item (Join-Path $releaseDir $_) -ItemType Directory -Force | Out-Null }
    }

    It 'Should match templates by prefix by default' {
        # Act
        $dirs = Get-TemplateFolder $releaseDir 'finops-hub'

        # Assert
        $dirs.Name | Sort-Object | Should -Be @('finops-hub', 'finops-hub-copilot', 'finops-hub-copilot-studio')
    }

    It 'Should return only the named template when -Exact is set' {
        # Act
        $dirs = Get-TemplateFolder $releaseDir 'finops-hub' -Exact

        # Assert
        $dirs.Count | Should -Be 1
        $dirs[0].Name | Should -Be 'finops-hub'
    }

    It 'Should return nothing when the named template is missing and -Exact is set' {
        # Act
        $dirs = Get-TemplateFolder $releaseDir 'optimization-workbook' -Exact

        # Assert
        $dirs.Count | Should -Be 0
    }

    It 'Should return all templates for *' {
        # Act
        $dirs = Get-TemplateFolder $releaseDir '*'

        # Assert
        $dirs.Count | Should -Be 4
    }
}
