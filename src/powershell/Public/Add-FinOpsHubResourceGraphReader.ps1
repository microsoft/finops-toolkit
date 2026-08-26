# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Grants the Reader role to a FinOps hub managed identity on Resource Graph scopes.

    .DESCRIPTION
    The Add-FinOpsHubResourceGraphReader command grants the Reader role to the Data Factory
    managed identity of a FinOps hub instance. The role is required for the hub to run
    Azure Resource Graph recommendation queries, including Azure Advisor cost recommendations.

    .PARAMETER Scope
    Required. Subscription ID, subscription resource ID, or management group resource ID
    where the hub managed identity should be granted Reader access. Multiple scopes are supported.

    .PARAMETER HubName
    Optional. Name of the FinOps hub instance. Supports wildcards. Default: * (all hubs in the selected subscription).

    .PARAMETER ResourceGroupName
    Optional. Name of the resource group the FinOps hub was deployed to. Supports wildcards.
    Default: * (all resource groups).

    .EXAMPLE
    Add-FinOpsHubResourceGraphReader -Scope '00000000-0000-0000-0000-000000000000' -HubName 'finops-hub14'

    Grants the Reader role at the subscription scope to the managed identity of the matching hub.

    .EXAMPLE
    Add-FinOpsHubResourceGraphReader -Scope '/providers/Microsoft.Management/managementGroups/contoso' -HubName 'finops-hub'

    Grants the Reader role at the management group scope.

    .LINK
    https://aka.ms/ftk/Add-FinOpsHubResourceGraphReader
#>
function Add-FinOpsHubResourceGraphReader
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param
    (
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Scope,

        [Parameter()]
        [string]
        $HubName,

        [Parameter()]
        [string]
        $ResourceGroupName
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Get-AzContext))
    {
        throw $script:LocalizedData.Common_ContextNotFound
    }

    $normalizedScopes = @(
        foreach ($scopeValue in $Scope)
        {
            $scopeValue = $scopeValue.Trim().TrimEnd('/')
            if ($scopeValue -match '^[0-9a-fA-F-]{36}$')
            {
                $scopeValue = "/subscriptions/$scopeValue"
            }
            elseif ($scopeValue -notmatch '^/subscriptions/[^/]+$' -and
                $scopeValue -notmatch '^/providers/Microsoft\.Management/managementGroups/[^/]+$')
            {
                throw ($script:LocalizedData.HubResourceGraphReader_InvalidScope -f $scopeValue)
            }

            $scopeValue
        }
    ) | Select-Object -Unique

    $hubs = @(Get-FinOpsHub -Name $HubName -ResourceGroupName $ResourceGroupName)
    $dataFactories = @(
        $hubs.Resources | Where-Object { $_.ResourceType -eq 'Microsoft.DataFactory/factories' }
    )

    if ($dataFactories.Count -eq 0)
    {
        throw ($script:LocalizedData.HubResourceGraphReader_DataFactoryNotFound -f $(if ($HubName) { $HubName } else { '*' }))
    }

    if ($dataFactories.Count -gt 1)
    {
        throw ($script:LocalizedData.HubResourceGraphReader_MultipleDataFactories -f $(if ($HubName) { $HubName } else { '*' }))
    }

    $dataFactory = Get-AzDataFactoryV2 -ResourceGroupName $dataFactories[0].ResourceGroupName -Name $dataFactories[0].Name
    $principalId = $dataFactory.Identity.PrincipalId
    if (-not $principalId)
    {
        throw ($script:LocalizedData.HubResourceGraphReader_IdentityNotFound -f $dataFactories[0].Name)
    }

    foreach ($scopeValue in $normalizedScopes)
    {
        $existing = @(Get-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName 'Reader' -Scope $scopeValue)
        if ($existing.Count -gt 0)
        {
            Write-Verbose ($script:LocalizedData.HubResourceGraphReader_AlreadyAssigned -f $scopeValue)
            $existing | Select-Object -First 1
            continue
        }

        if ($PSCmdlet.ShouldProcess($scopeValue, 'Grant Reader to the FinOps hub managed identity'))
        {
            try
            {
                $assignment = New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName 'Reader' -Scope $scopeValue
            }
            catch
            {
                throw ($script:LocalizedData.HubResourceGraphReader_AssignFailed -f $scopeValue, $_.Exception.Message)
            }

            Write-Verbose ($script:LocalizedData.HubResourceGraphReader_Assigned -f $scopeValue)
            $assignment
        }
    }
}
