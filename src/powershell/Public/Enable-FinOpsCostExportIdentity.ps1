# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Switches existing Cost Management exports to a system-assigned managed identity.

    .DESCRIPTION
    The Enable-FinOpsCostExportIdentity command adds a system-assigned managed identity to existing Cost Management exports and assigns the Storage Blob Data Contributor role to the identity on the destination storage container.

    Exports without a managed identity write to storage with the permissions of the person who created or last updated the export. Those permissions are checked on every run, so scheduled runs fail with AccessToStorageAccountDenied once that access is removed or expires, for example, when an eligible Privileged Identity Management (PIM) role isn't active. With a managed identity, runs no longer depend on the permissions of a person.

    The export is updated in place. Its schedule, run history, and all other settings are kept. Exports that already use a system-assigned managed identity aren't changed, but the role assignment is still checked.

    To assign the role, you need permission to assign roles on the storage account (for example, Owner, User Access Administrator, or Role Based Access Control Administrator).

    This command has been tested with the following API versions:
    - 2025-03-01 (default)

    .PARAMETER Name
    Required. Name of the export. Supports wildcards.

    .PARAMETER Scope
    Required. Resource ID of the scope the export was created for.

    .PARAMETER Location
    Optional. Azure location to use for the managed identity. Default = the location of the export, if set; otherwise, "global".

    .PARAMETER SkipRoleAssignment
    Optional. Indicates that the Storage Blob Data Contributor role shouldn't be assigned. Use this option if someone else assigns the role. Default = false.

    .PARAMETER ApiVersion
    Optional. API version to use when calling the Cost Management Exports API. Default = 2025-03-01.

    .EXAMPLE
    Enable-FinOpsCostExportIdentity -Name 'ftk-FinOpsHub-costs' -Scope '/providers/Microsoft.Billing/billingAccounts/00000000/billingProfiles/0000-0000-000-000'

    Adds a system-assigned managed identity to the specified export and assigns the Storage Blob Data Contributor role to it on the destination container.

    .EXAMPLE
    Enable-FinOpsCostExportIdentity -Name '*' -Scope '/providers/Microsoft.Billing/billingAccounts/00000000' -WhatIf

    Shows which exports in the billing account would be switched to a managed identity without changing them.

    .LINK
    https://aka.ms/ftk/Enable-FinOpsCostExportIdentity
#>
function Enable-FinOpsCostExportIdentity
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [SupportsWildcards()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Scope,

        [Parameter()]
        [string]
        $Location,

        [Parameter()]
        [switch]
        $SkipRoleAssignment,

        [Parameter()]
        [string]
        $ApiVersion = '2025-03-01'
    )

    $context = Get-AzContext
    if (-not $context)
    {
        throw $script:LocalizedData.Common_ContextNotFound
    }

    $commandDetails = @{
        CommandName      = "Enable-FinOpsCostExportIdentity"
        ParameterSetName = $PSCmdlet.ParameterSetName
    }

    $exports = Get-FinOpsCostExport -Name $Name -Scope $Scope -ApiVersion $ApiVersion
    if (-not $exports)
    {
        Write-Error ($script:LocalizedData.CostExport_Common_NotFoundFormat -f $Name, $Scope.TrimEnd('/')) -ErrorAction Stop
        return
    }

    foreach ($summary in $exports)
    {
        $exportUri = "$($summary.Id.Trim('/'))?api-version=$ApiVersion"
        $principalId = $summary.PrincipalId

        if ($summary.IdentityType -like '*SystemAssigned*' -and $principalId)
        {
            Write-Verbose "Export $($summary.Name) already uses system-assigned managed identity $principalId."
        }
        elseif ($PSCmdlet.ShouldProcess($summary.Name, 'Enable system-assigned managed identity'))
        {
            # Read the full export so the update keeps every setting, including ones this module doesn't manage
            $getResponse = Invoke-Rest -Method GET -Uri $exportUri @commandDetails
            if (-not $getResponse.Success)
            {
                Write-Error ($script:LocalizedData.CostExport_Identity_UpdateFailedFormat -f $summary.Name, $getResponse.Content.error.message, $getResponse.Content.error.code)
                continue
            }
            $export = $getResponse.Content

            # Remove read-only properties before sending the export back
            $properties = $export.properties | Select-Object -Property * -ExcludeProperty runHistory, nextRunTimeEstimate, systemSuppliedData

            $identityLocation = $Location
            if (-not $identityLocation) { $identityLocation = $export.location }
            if (-not $identityLocation) { $identityLocation = 'global' }

            $body = [PSCustomObject]@{
                eTag       = $export.eTag
                location   = $identityLocation
                identity   = @{ type = 'SystemAssigned' }
                properties = $properties
            }

            # Update in place. The eTag prevents overwriting a change made since the export was read.
            $putResponse = Invoke-Rest -Method PUT -Uri $exportUri -Body $body @commandDetails
            if (-not $putResponse.Success)
            {
                Write-Error ($script:LocalizedData.CostExport_Identity_UpdateFailedFormat -f $summary.Name, $putResponse.Content.error.message, $putResponse.Content.error.code)
                continue
            }

            $principalId = $putResponse.Content.identity.principalId
            Write-Verbose "Export $($summary.Name) now uses system-assigned managed identity $principalId."
        }
        else
        {
            # -WhatIf or declined
            continue
        }

        if ($SkipRoleAssignment)
        {
            continue
        }
        if (-not $principalId)
        {
            Write-Warning ($script:LocalizedData.CostExport_Identity_NoPrincipalFormat -f $summary.Name)
            continue
        }

        $null = Grant-FinOpsCostExportStorageAccess `
            -PrincipalId $principalId `
            -StorageAccountId $summary.StorageAccountId `
            -StorageContainer $summary.StorageContainer `
            -CommandName $commandDetails.CommandName
    }

    return (Get-FinOpsCostExport -Name $Name -Scope $Scope -ApiVersion $ApiVersion)
}
