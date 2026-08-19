# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'HubsPrivateNetworking' {

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $bicepPath = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Core/infrastructure.bicep'
        $templatePath = Join-Path ([System.IO.Path]::GetTempPath()) "finops-hub-infrastructure-$([guid]::NewGuid()).json"
    }

    AfterAll {
        Remove-Item -Path $templatePath -Force -ErrorAction SilentlyContinue
    }

    It 'Should keep private subnets and use the supported deployment-script network path' {
        if (-not (Get-Command 'bicep' -ErrorAction SilentlyContinue))
        {
            Set-ItResult -Skipped -Because 'bicep CLI not found'
            return
        }

        bicep build $bicepPath --outfile $templatePath
        if ($LASTEXITCODE -ne 0)
        {
            throw 'Failed to compile the FinOps hub infrastructure template.'
        }

        $templateText = Get-Content -Path $templatePath -Raw
        $template = $templateText | ConvertFrom-Json -Depth 100

        ([regex]::Matches($template.variables.subnets, "'defaultOutboundAccess', not\(parameters\('hub'\)\.options\.natGateway\)")).Count | Should -Be 3
        ([regex]::Matches($template.variables.subnets, "'natGateway'")).Count | Should -Be 2

        $template.resources.scriptStorageAccount.properties.publicNetworkAccess | Should -Be 'Disabled'
        $template.resources.scriptStorageAccount.properties.networkAcls.PSObject.Properties.Name | Should -Not -Contain 'virtualNetworkRules'

        $template.resources.scriptEndpoint.properties.privateLinkServiceConnections[0].properties.groupIds | Should -Contain 'file'
        $template.resources.'scriptEndpoint::scriptPrivateDnsZoneGroup'.properties.privateDnsZoneConfigs[0].properties.privateDnsZoneId | Should -Match "dnsZones\.file\.name"
        $template.resources.filePrivateDnsZone.name | Should -Match "dnsZones\.file\.name"
    }
}
