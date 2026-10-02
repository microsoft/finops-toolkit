# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'HubsQuotaTelemetry' {

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $quotaPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Quota'
        $templatePath = Join-Path ([System.IO.Path]::GetTempPath()) "finops-hub-quota-telemetry-$([guid]::NewGuid()).json"

        if (-not (Get-Command 'bicep' -ErrorAction SilentlyContinue))
        {
            throw 'bicep CLI is required to validate the quota telemetry deployment.'
        }
        bicep build (Join-Path $quotaPath 'app.bicep') --outfile $templatePath
        if ($LASTEXITCODE -ne 0)
        {
            throw 'Failed to compile the quota Function template.'
        }
        $template = Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json -Depth 100
        $settings = @{}
        foreach ($setting in $template.resources.functionApp.properties.siteConfig.appSettings)
        {
            $settings[$setting.name] = $setting.value
        }
        $packageConfigs = @{}
        foreach ($file in @('host.json', 'CollectQuota/function.json'))
        {
            $reference = [regex]::Match($template.variables.packageFiles.$file, "^\[variables\('([^']+)'\)\]$")
            if (-not $reference.Success)
            {
                throw "The packaged $file must reference its compiled file content."
            }
            $packageConfigs[$file] = $template.variables.PSObject.Properties[$reference.Groups[1].Value].Value | ConvertFrom-Json
        }
        $hostConfig = $packageConfigs['host.json']
    }

    AfterAll {
        if (Test-Path -LiteralPath $templatePath)
        {
            Remove-Item -LiteralPath $templatePath -Force
        }
    }

    It 'Should use hub service names with the existing unique suffix and publisher tags' {
        $template.variables.workspaceName | Should -Match "parameters\('app'\)\.hub\.name"
        $template.variables.workspaceName | Should -Match '-logs'
        $template.variables.workspaceName | Should -Match "parameters\('app'\)\.suffix"
        $template.variables.applicationInsightsName | Should -Match "parameters\('app'\)\.hub\.name"
        $template.variables.applicationInsightsName | Should -Match '-insights'
        $template.variables.applicationInsightsName | Should -Match "parameters\('app'\)\.suffix"
        $template.resources.workspace.location | Should -Be "[parameters('app').hub.location]"
        $template.resources.applicationInsights.location | Should -Be "[parameters('app').hub.location]"
        $template.resources.workspace.tags | Should -Match 'getAppPublisherTags'
        $template.resources.applicationInsights.tags | Should -Match 'getAppPublisherTags'
    }

    It 'Should deploy workspace-based Application Insights with a pay-as-you-go workspace' {
        $template.resources.workspace.type | Should -Be 'Microsoft.OperationalInsights/workspaces'
        $template.resources.workspace.properties.sku.name | Should -Be 'PerGB2018'
        $template.resources.workspace.properties.retentionInDays | Should -Be 30
        $template.resources.applicationInsights.type | Should -Be 'Microsoft.Insights/components'
        $template.resources.applicationInsights.properties.WorkspaceResourceId | Should -Match 'Microsoft.OperationalInsights/workspaces'
        $template.resources.applicationInsights.properties.IngestionMode | Should -Be 'LogAnalytics'
        $template.resources.applicationInsights.dependsOn | Should -Contain 'workspace'
    }

    It 'Should authenticate telemetry with the existing recommendations identity' {
        $template.resources.applicationInsights.properties.DisableLocalAuth | Should -BeTrue
        $template.resources.workspace.properties.features.disableLocalAuth | Should -BeTrue
        $template.resources.applicationInsightsRole.properties.principalId | Should -Be "[parameters('core').recommendationsIdentity.principalId]"
        $template.resources.applicationInsightsRole.scope | Should -Match 'Microsoft.Insights/components'
        $template.resources.applicationInsightsRole.properties.roleDefinitionId | Should -Match '3913510d-42f4-4e42-8a64-420c390055eb'
        $settings.APPLICATIONINSIGHTS_AUTHENTICATION_STRING | Should -Match "parameters\('core'\)\.recommendationsIdentity\.id"
        $settings.APPLICATIONINSIGHTS_AUTHENTICATION_STRING | Should -Match 'ClientId=.*Authorization=AAD'
        $template.resources.functionApp.dependsOn | Should -Contain 'applicationInsightsRole'
    }

    It 'Should wire the Function to the deployed Application Insights without replacing its identity' {
        $settings.APPLICATIONINSIGHTS_CONNECTION_STRING | Should -Be "[reference('applicationInsights').ConnectionString]"
        $template.resources.functionApp.identity.type | Should -Be 'UserAssigned'
        @($template.resources.functionApp.identity.userAssignedIdentities.PSObject.Properties).Count | Should -Be 1
        $template.resources.functionApp.identity.userAssignedIdentities.PSObject.Properties.Name |
            Should -Match "parameters\('core'\)\.recommendationsIdentity\.id"
        $template.resources.functionApp.properties.functionAppConfig.scaleAndConcurrency.instanceMemoryMB | Should -Be 4096
        $template.resources.functionApp.properties.functionAppConfig.scaleAndConcurrency.maximumInstanceCount | Should -Be 1
        $packageConfigs['CollectQuota/function.json'].bindings | Select-Object -ExpandProperty schedule |
            Should -Be '0 1 1 * * *'
    }

    It 'Should retain execution results, metrics, collector logs and unsampled exceptions in the Function package' {
        $hostConfig.logging.logLevel.default | Should -Be 'Warning'
        $hostConfig.logging.logLevel.'Host.Aggregator' | Should -Be 'Information'
        $hostConfig.logging.logLevel.'Host.Results' | Should -Be 'Information'
        $hostConfig.logging.logLevel.Function | Should -Be 'Information'
        $hostConfig.logging.logLevel.Worker | Should -Be 'Information'
        $hostConfig.logging.applicationInsights.samplingSettings.isEnabled | Should -BeTrue
        $hostConfig.logging.applicationInsights.samplingSettings.excludedTypes.Split(';') | Should -Contain 'Request'
        $hostConfig.logging.applicationInsights.samplingSettings.excludedTypes.Split(';') | Should -Contain 'Exception'
        $hostConfig.functionTimeout | Should -Be '-1'
    }
}
