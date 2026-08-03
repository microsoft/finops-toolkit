# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    Regression coverage for FinOps hub private networking (#2156).

    The hub VNet must never declare its subnets through the virtual network's `subnets` property.
    A PUT that carries that property is authoritative for the whole subnet collection, so ARM
    deletes every subnet the template doesn't list -- which destroyed customer-added subnets on
    upgrade and failed with InUseSubnetCannotBeDeleted when those subnets had service association
    links. The hub now declares only the three subnets it owns, as child resources, leaving any
    other subnet in the VNet untouched.

    Assertions run against the COMPILED ARM JSON, not the Bicep source text, so a reformat or
    rewrite that preserves behavior passes and one that changes behavior fails.

    API versions are asserted as a MINIMUM, never as an exact value. Omitting `subnets` from a
    VNet PUT only preserves existing subnets from api-version 2023-09-01 onward, so that floor is
    the real requirement. Pinning an exact version here would block routine version upgrades.

    Limitation: no static test can prove Azure's runtime behavior. Validating that an upgrade
    preserves a customer-added subnet requires a live deployment against a real subscription.
#>

Describe 'HubsPrivateNetworking' {

    BeforeDiscovery {
        $script:bicepAvailable = [bool](Get-Command 'bicep' -ErrorAction SilentlyContinue)
    }

    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $bicepFile = Join-Path $repoRoot 'src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Core/infrastructure.bicep'

        # Behavior floor: VNet PUT without the subnets property preserves existing subnets.
        # https://learn.microsoft.com/azure/azure-resource-manager/bicep/scenarios-virtual-networks
        $script:minApiVersion = [datetime]::ParseExact('2023-09-01', 'yyyy-MM-dd', $null)

        $script:finopsHubSubnetName = 'private-endpoint-subnet'
        $script:scriptSubnetName = 'script-subnet'
        $script:dataExplorerSubnetName = 'dataExplorer-subnet'

        # The NAT gateway is applied through a conditional spread, which compiles to
        # if(<enabled>, createObject('natGateway', ...), createObject()). Asserting only that
        # "natGateways" appears somewhere would also pass if the branches were swapped, so match
        # the natGateway object in the position the true branch occupies.
        $script:natGatewayTrueBranch = "if\(parameters\('hub'\)\.options\.natGateway,\s*createObject\('natGateway'"

        if (Get-Command 'bicep' -ErrorAction SilentlyContinue)
        {
            $outFile = Join-Path ([System.IO.Path]::GetTempPath()) "ftk-infra-$([guid]::NewGuid()).json"
            $buildOutput = bicep build $bicepFile --outfile $outFile 2>&1
            if ($LASTEXITCODE -ne 0)
            {
                throw "Bicep compilation failed: $($buildOutput | Out-String)"
            }

            $script:template = Get-Content -Path $outFile -Raw | ConvertFrom-Json
            Remove-Item $outFile -Force -ErrorAction SilentlyContinue

            $script:vNet = $script:template.resources.'vNet'
            $script:subnets = @(
                $script:template.resources.PSObject.Properties `
                | Where-Object { $_.Value.type -eq 'Microsoft.Network/virtualNetworks/subnets' } `
                | ForEach-Object { $_.Value }
            )
        }

        function Get-SubnetByName([string] $Name)
        {
            # The compiled name is an ARM expression referencing the variable that holds the literal.
            $variableName = switch ($Name)
            {
                $script:finopsHubSubnetName { 'finopsHubSubnetName' }
                $script:scriptSubnetName { 'scriptSubnetName' }
                $script:dataExplorerSubnetName { 'dataExplorerSubnetName' }
            }
            return $script:subnets | Where-Object { $_.name -match [regex]::Escape($variableName) }
        }

        # Subnets whose properties are built with a conditional spread compile to a single
        # shallowMerge() expression string instead of an inspectable object, so those are matched
        # as text. The literal below is what the compiler emits for the property value.
        function Get-SubnetPropertyText($Subnet)
        {
            return ($Subnet.properties | ConvertTo-Json -Depth 20 -Compress)
        }
    }

    Context 'Virtual network' -Skip:(-not $bicepAvailable) {

        It 'Should not declare subnets on the virtual network (#2156)' {
            $propertyNames = $script:vNet.properties.PSObject.Properties.Name
            $propertyNames | Should -Not -Contain 'subnets' -Because 'a VNet PUT carrying the subnets property is authoritative for the whole collection and deletes customer-added subnets on upgrade'
        }

        It 'Should not set subnets to an empty or null value' {
            # Azure treats "subnets": [] and "subnets": null as "delete every subnet".
            $json = $script:vNet.properties | ConvertTo-Json -Depth 20 -Compress
            $json | Should -Not -Match '"subnets"\s*:\s*(\[\]|null)'
        }

        It 'Should still declare the address space' {
            $script:vNet.properties.addressSpace | Should -Not -BeNullOrEmpty
        }

        It 'Should use an api-version that preserves subnets when the property is omitted' {
            $actual = [datetime]::ParseExact($script:vNet.apiVersion, 'yyyy-MM-dd', $null)
            $actual | Should -BeGreaterOrEqual $script:minApiVersion -Because "omitting subnets only preserves them from 2023-09-01 onward (found $($script:vNet.apiVersion))"
        }
    }

    Context 'Hub-owned subnets' -Skip:(-not $bicepAvailable) {

        It 'Should declare exactly three subnets as child resources' {
            $script:subnets.Count | Should -Be 3
        }

        It 'Should deploy every subnet rather than only reference it' {
            foreach ($subnet in $script:subnets)
            {
                [bool]$subnet.existing | Should -BeFalse -Because "subnet '$($subnet.name)' must be deployed so the hub owns its configuration"
            }
        }

        It 'Should use an api-version at or above the floor for every subnet' {
            foreach ($subnet in $script:subnets)
            {
                $actual = [datetime]::ParseExact($subnet.apiVersion, 'yyyy-MM-dd', $null)
                $actual | Should -BeGreaterOrEqual $script:minApiVersion
            }
        }

        It 'Should attach the network security group to every subnet' {
            foreach ($subnet in $script:subnets)
            {
                # Match the property key, not the resource type name in resourceId().
                Get-SubnetPropertyText $subnet | Should -Match 'networkSecurityGroup[''"]' -Because "subnet '$($subnet.name)' must stay behind the hub NSG"
            }
        }

        It 'Should serialize subnet deployment to avoid AnotherOperationInProgress' {
            # Concurrent writes to subnets of the same VNet fail, so each subnet after the first
            # must wait on the previous one.
            $scriptSubnet = Get-SubnetByName $script:scriptSubnetName
            $dataExplorerSubnet = Get-SubnetByName $script:dataExplorerSubnetName

            $scriptSubnet.dependsOn | Should -Contain 'vNet::finopsHubSubnet'
            $dataExplorerSubnet.dependsOn | Should -Contain 'vNet::scriptSubnet'
        }

        It 'Should give the private endpoint subnet a storage service endpoint' {
            $subnet = Get-SubnetByName $script:finopsHubSubnetName
            $subnet.properties.serviceEndpoints.service | Should -Contain 'Microsoft.Storage'
        }

        It 'Should delegate the script subnet to Azure Container Instances' {
            $subnet = Get-SubnetByName $script:scriptSubnetName
            Get-SubnetPropertyText $subnet | Should -Match 'Microsoft.ContainerInstance/containerGroups'
        }

        It 'Should give the script subnet a storage service endpoint' {
            $subnet = Get-SubnetByName $script:scriptSubnetName
            Get-SubnetPropertyText $subnet | Should -Match 'Microsoft.Storage'
        }

        It 'Should route the script subnet through the NAT gateway when enabled' {
            $subnet = Get-SubnetByName $script:scriptSubnetName
            Get-SubnetPropertyText $subnet | Should -Match $script:natGatewayTrueBranch -Because 'the NAT gateway must be attached in the enabled branch, not the disabled one'
        }

        It 'Should route the Data Explorer subnet through the NAT gateway when enabled' {
            $subnet = Get-SubnetByName $script:dataExplorerSubnetName
            Get-SubnetPropertyText $subnet | Should -Match $script:natGatewayTrueBranch -Because 'the NAT gateway must be attached in the enabled branch, not the disabled one'
        }

        It 'Should keep subnet creation ordered after the NAT gateway' {
            # natGateway is referenced through resourceId(), which creates no implicit dependency,
            # so subnets can only be ordered after it via the VNet's explicit dependsOn.
            $script:vNet.dependsOn | Should -Contain 'natGateway' -Because 'subnets attach the NAT gateway and must not be created before it exists'
        }
    }

    Context 'Private endpoint placement' -Skip:(-not $bicepAvailable) {

        It 'Should wait on the subnet the script private endpoint is created in' {
            # scriptEndpoint lands in hub.routing.subnets.storage, which resolves to
            # private-endpoint-subnet -- not script-subnet.
            $endpoint = $script:template.resources.'scriptEndpoint'
            $endpoint.dependsOn | Should -Contain 'vNet::finopsHubSubnet'
        }
    }
}
