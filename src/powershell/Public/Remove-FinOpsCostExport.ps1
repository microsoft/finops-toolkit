# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Delete a Cost Management export and optionally data associated with the export.

    .DESCRIPTION
    The Remove-FinOpsCostExport command deletes a Cost Management export and optionally deletes all data associated with the export from the related storage account.

    This command has been tested with the following API versions:
    - 2025-03-01 (default) – GA version for FocusCost and other datasets.
    - 2023-07-01-preview
    - 2023-08-01
    - 2023-03-01

    .PARAMETER Name
    Name of the Cost Management export.

    .PARAMETER Scope
    Required. Resource ID of the scope to export data for.

    .PARAMETER RemoveData
    Optional. Indicates that all cost data associated with the Export scope should be deleted.

    .PARAMETER APIVersion
    Optional. API version to use when calling the Cost Management Exports API. Default = 2025-03-01.

    .EXAMPLE
    Remove-FinOpsCostExport -Name MyExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -RemoveData

    Deletes a Cost Management export named MyExport scoped to /subscriptions/00000000-0000-0000-0000-000000000000, and deletes all exported data from the related storage account.
#>

function Remove-FinOpsCostExport
{
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Scope,

        [Parameter()]
        [switch]
        $RemoveData,

        [Parameter()]
        [string]
        $ApiVersion = '2025-03-01'
    )

    $context = Get-AzContext
    if (-not $context)
    {
        throw $script:LocalizedData.Common_ContextNotFound
    }

    try
    {
        $export = Get-FinOpsCostExport -Name $Name -Scope $Scope -ApiVersion $ApiVersion
        if ($export)
        {
            # Delete associated data from storage account
            if ($RemoveData)
            {
                # Export details retreived
                $storageAccountId = $export.properties.deliveryInfo.destination.resourceId
                $resourceGroupName = $storageAccountId.Split('/')[4]
                $storageAccountName = $storageAccountId.Split('/')[8]
                $path = $export.properties.deliveryInfo.destination.rootFolderPath + "/" + $Name

                if ($PSCmdlet.ShouldProcess($path, 'DeleteExportedData'))
                {
                    Write-Verbose "Resource group: $resourceGroupName"
                    Write-Verbose "Storage account: $storageAccountName"
                    Write-Verbose "Scope: $scope"

                    $getSta = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
                    if ($getSta -and $getSta.EnableHierarchicalNamespace)
                    {
                        $getSta | Remove-AzDataLakeGen2Item -FileSystem $export.properties.deliveryInfo.destination.container -Path $path -Force
                    }
                }
            }
        }
        else
        {
            Write-Warning ($script:localizedData.CostExport_Common_NotFoundFormat -f $Name, $Scope)
            return $true
        }

        if ($PSCmdlet.ShouldProcess($Name, 'DeleteExport'))
        {
            $response = Invoke-Rest -Method "DELETE" -Uri "$($export.Id)?api-version=$ApiVersion" -CommandName "Remove-FinOpsCostExport"
            if ($response.Failure)
            {
                Write-Error ($script:localizedData.CostExport_Remove_DeleteFailedFormat -f $Name, $response.Content.error.message, $response.Content.error.code) -ErrorAction Stop
            }
            return $response.Success
        }
    }
    catch
    {
        throw $_.Exception
    }
}
