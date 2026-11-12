# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Update-QuickstartMetadata' {
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
                $node.Name -eq 'Update-QuickstartMetadata'
            },
            $true
        ) | Select-Object -First 1

        if (-not $functionAst)
        {
            throw "Update-QuickstartMetadata not found in $scriptPath"
        }

        . ([scriptblock]::Create($functionAst.Extent.Text))

        $correlationId = '11111111-2222-3333-4444-555555555555'
        $today = Get-Date -Format 'yyyy-MM-dd'
    }

    BeforeEach {
        $templateDir = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item $templateDir -ItemType Directory | Out-Null
        $metadataPath = Join-Path $templateDir 'metadata.json'
        @{ itemDisplayName = 'FinOps hub'; githubUsername = 'someone'; dateUpdated = '2025-04-04' } `
        | ConvertTo-Json | Out-File $metadataPath -Encoding utf8
    }

    It 'Sets dateUpdated to today and keeps the other properties' {
        Update-QuickstartMetadata $metadataPath $null $correlationId 'ftk-finops-hub' 6>$null

        $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
        $metadata.dateUpdated | Should -Be $today
        $metadata.itemDisplayName | Should -Be 'FinOps hub'
        $metadata.githubUsername | Should -Be 'someone'
    }

    It 'Writes the test deployment for the compiled template when it is published' {
        '{}' | Out-File (Join-Path $templateDir 'azuredeploy.json')

        Update-QuickstartMetadata $metadataPath $null $correlationId 'ftk-finops-hub' 6>$null

        $deployment = (Get-Content $metadataPath -Raw | ConvertFrom-Json).testResult.deployments
        $deployment.templateFileName | Should -Be 'azuredeploy.json'
        $deployment.correlationId | Should -Be $correlationId
        $deployment.deploymentName | Should -Be 'ftk-finops-hub'
    }

    It 'Points the test deployment at main.bicep when there is no compiled template' {
        Update-QuickstartMetadata $metadataPath $null $correlationId 'ftk-finops-hub' 6>$null

        (Get-Content $metadataPath -Raw | ConvertFrom-Json).testResult.deployments.templateFileName | Should -Be 'main.bicep'
    }

    It 'Replaces an earlier test deployment with the new one' {
        $previous = [PSCustomObject]@{ deployments = [PSCustomObject]@{ templateFileName = 'azuredeploy.json'; correlationId = 'old'; deploymentName = 'old-deployment' } }

        Update-QuickstartMetadata $metadataPath $previous $correlationId 'ftk-finops-hub' 6>$null

        (Get-Content $metadataPath -Raw | ConvertFrom-Json).testResult.deployments.deploymentName | Should -Be 'ftk-finops-hub'
    }

    It 'Keeps the earlier test deployment and warns when no new one is given' {
        $previous = [PSCustomObject]@{ deployments = [PSCustomObject]@{ templateFileName = 'azuredeploy.json'; correlationId = 'old'; deploymentName = 'old-deployment' } }

        $warnings = @(Update-QuickstartMetadata $metadataPath $previous '' '' 3>&1)

        $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
        $metadata.testResult.deployments.deploymentName | Should -Be 'old-deployment'
        $metadata.dateUpdated | Should -Be $today
        $warnings | Should -HaveCount 1
    }

    It 'Warns and writes no testResult when there is none at all' {
        $warnings = @(Update-QuickstartMetadata $metadataPath $null '' '' 3>&1)

        $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
        $metadata.PSObject.Properties['testResult'] | Should -BeNullOrEmpty
        $metadata.dateUpdated | Should -Be $today
        $warnings | Should -HaveCount 1
    }
}
