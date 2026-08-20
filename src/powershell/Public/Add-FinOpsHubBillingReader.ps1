# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Grants the Billing Reader role to a FinOps hub managed identity on a billing account.

    .DESCRIPTION
    The Add-FinOpsHubBillingReader command grants the Billing Reader role to the Data Factory managed identity of a FinOps hub instance at the billing account scope.

    This role is required to download Microsoft invoice files and cannot be granted during deployment because billing account scopes are outside of any Azure subscription.

    .PARAMETER BillingAccountId
    Required. ID of the billing account to grant access to. Find the ID in Cost Management + Billing > Properties.

    .PARAMETER HubName
    Optional. Name of the FinOps hub instance. Supports wildcards. Default: * (all hubs in the selected subscription).

    .PARAMETER ResourceGroupName
    Optional. Name of the resource group the FinOps hub was deployed to. Supports wildcards. Default: * (all resource groups).

    .EXAMPLE
    Add-FinOpsHubBillingReader -BillingAccountId '12345678-1234-1234-1234-123456789012:87654321-4321-4321-4321-210987654321_2019-05-31'

    Grants the Billing Reader role to the managed identity of the only FinOps hub in the selected subscription.

    .EXAMPLE
    Add-FinOpsHubBillingReader -BillingAccountId 1234567 -HubName foo -ResourceGroupName bar

    Grants the Billing Reader role to the managed identity of the 'foo' hub in the 'bar' resource group.

    .LINK
    https://aka.ms/ftk/Add-FinOpsHubBillingReader
#>
function Add-FinOpsHubBillingReader
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param
    (
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $BillingAccountId,

        [Parameter()]
        [string]
        $HubName,

        [Parameter()]
        [string]
        $ResourceGroupName
    )

    $ErrorActionPreference = 'Stop'

    $context = Get-AzContext
    if (-not $context)
    {
        throw $script:LocalizedData.Common_ContextNotFound
    }

    # Billing account IDs are used verbatim in the scope, but tolerate a full scope being passed in
    $accountId = $BillingAccountId.Trim('/')
    if ($accountId -like '*/billingAccounts/*')
    {
        $accountId = $accountId.Substring($accountId.LastIndexOf('/billingAccounts/') + '/billingAccounts/'.Length)
    }

    $scope = "/providers/Microsoft.Billing/billingAccounts/$accountId"

    # Find the Data Factory instances that belong to the hub
    $hubs = Get-FinOpsHub -Name $HubName -ResourceGroupName $ResourceGroupName
    $dataFactories = @($hubs.Resources | Where-Object { $_.ResourceType -eq 'Microsoft.DataFactory/factories' })

    if ($dataFactories.Count -eq 0)
    {
        throw ($script:LocalizedData.HubBillingReader_Add_DataFactoryNotFound -f $(if ($HubName) { $HubName } else { '*' }))
    }

    if ($dataFactories.Count -gt 1)
    {
        throw ($script:LocalizedData.HubBillingReader_Add_MultipleDataFactories -f $(if ($HubName) { $HubName } else { '*' }))
    }

    $dataFactory = Get-AzDataFactoryV2 -ResourceGroupName $dataFactories[0].ResourceGroupName -Name $dataFactories[0].Name
    $principalId = $dataFactory.Identity.PrincipalId
    if (-not $principalId)
    {
        throw ($script:LocalizedData.HubBillingReader_Add_IdentityNotFound -f $dataFactories[0].Name)
    }

    $existing = Get-AzRoleAssignment -ObjectId $principalId -Scope $scope -RoleDefinitionName 'Billing Reader' -ErrorAction SilentlyContinue `
    | Where-Object { $_.Scope -eq $scope }
    if ($existing)
    {
        Write-Verbose ($script:LocalizedData.HubBillingReader_Add_AlreadyAssigned -f $accountId)
        return $existing
    }

    if (-not $PSCmdlet.ShouldProcess($scope, 'Grant Billing Reader'))
    {
        return
    }

    try
    {
        $assignment = New-AzRoleAssignment -ObjectId $principalId -Scope $scope -RoleDefinitionName 'Billing Reader' -ObjectType 'ServicePrincipal'
    }
    catch
    {
        throw ($script:LocalizedData.HubBillingReader_Add_AssignFailed -f $accountId, $_.Exception.Message)
    }

    Write-Verbose ($script:LocalizedData.HubBillingReader_Add_Assigned -f $accountId)
    return $assignment
}
