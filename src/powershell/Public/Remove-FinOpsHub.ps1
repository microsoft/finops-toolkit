# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Delete a FinOps hub instance and optionally keep the storage account hosting cost data.

    .DESCRIPTION
    The Remove-FinOpsHub command deletes a FinOps Hub instance and optionally deletes the storage account hosting cost data.

    The command returns a boolean value indicating whether all resources were successfully deleted.

    .PARAMETER Name
    Required when specifying Name. Name of the FinOps Hub.

    .PARAMETER ResourceGroupName
    Optional when specifying Name. Resource Group Name for the FinOps Hub.

    .PARAMETER InputObject
    Required when specifying InputObject. Expected object is the output of Get-FinOpsHub.

    .PARAMETER KeepStorageAccount
    Optional. Indicates that the storage account associated with the FinOps Hub should be retained.

    .PARAMETER Force
    Optional. Deletes specified resources without asking for a confirmation.

    .EXAMPLE
    Remove-FinOpsHub -Name MyHub -ResourceGroupName MyRG -KeepStorageAccount

    Deletes a FinOps Hub named MyHub and deletes all associated resources except the storage account.
#>

function Remove-FinOpsHub
{
    [OutputType([bool])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'Name')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Object')]
        [ValidateNotNullOrEmpty()]
        [psobject]$InputObject,

        [Parameter(ParameterSetName = 'Name')]
        [Parameter(ParameterSetName = 'Object')]
        [switch]$KeepStorageAccount,

        [Parameter(ParameterSetName = 'Name')]
        [Parameter(ParameterSetName = 'Object')]
        [switch]$Force
    )

    $context = Get-AzContext
    if (-not $context)
    {
        throw $script:LocalizedData.Common_ContextNotFound
    }

    try
    {
        if ($PSCmdlet.ParameterSetName -eq 'Name')
        {
            if (-not [string]::IsNullOrEmpty($ResourceGroupName))
            {
                $hub = Get-FinOpsHub -Name $Name -ResourceGroupName $ResourceGroupName
            }
            else
            {
                $hub = Get-FinOpsHub -Name $Name
                $ResourceGroupName = $hub.Resources[0].ResourceGroupName
            }
        }
        else
        {
            $hub = $InputObject
            $Name = $hub.Name
            $ResourceGroupName = $hub.Resources[0].ResourceGroupName
        }

        if (-not $hub)
        {
            throw $script:LocalizedData.Hub_Remove_NotFound -f $Name
        }

        Write-Verbose -Message "Found FinOps Hub: $Name in resource group $ResourceGroupName"

        $uniqueId = Get-HubIdentifier -Collection $hub.Resources.Name

        $resources = Get-AzResource -ResourceGroupName $ResourceGroupName |
        Where-Object -FilterScript { $_.Name -like "*$uniqueId*" -and ((-not $KeepStorageAccount) -or $_.ResourceType -ne "Microsoft.Storage/storageAccounts") }
        Write-Verbose -Message "Filtered Resources: $($resources | ForEach-Object { $_.Name })"

        if ($null -eq $resources)
        {
            Write-Warning "No resources found to delete."
            return $false
        }

        # List all resources to be deleted
        Write-Information "The following resources will be deleted:"
        $resources | ForEach-Object { Write-Information "- $($_.ResourceId)" }

        # Prompt the user for confirmation
        if ($PSCmdlet.ShouldProcess($Name, 'DeleteFinOpsHub'))
        {
            # Initialize a flag to track if "Yes to All" was selected
            $yesToAll = $Force

            # Loop through each resource
            $success = $true
            foreach ($resource in $resources)
            {
                try
                {
                    # Skip confirmation if "Yes to All" was selected
                    if (-not $yesToAll)
                    {
                        $confirmation = $Host.UI.PromptForChoice(
                            "Confirm",
                            "Are you sure you want to delete the following resource:`n$($resource.ResourceId)",
                            @("&Yes", "Yes to &All", "&No", "No to A&ll", "&Suspend"),
                            0
                        )

                        # Handle the user's choice
                        switch ($confirmation)
                        {
                            0
                            {
                                # Yes
                                # Continue with deletion
                            }
                            1
                            {
                                # Yes to All
                                $yesToAll = $true
                            }
                            2
                            {
                                # No
                                Write-Verbose -Message "Skipping resource: $($resource.Name)"
                                continue
                            }
                            3
                            {
                                # No to All
                                Write-Verbose -Message "Skipping all resources."
                                return $false
                            }
                            4
                            {
                                # Suspend
                                Write-Verbose -Message "Operation suspended."
                                return $false
                            }
                        }
                    }

                    # Delete the resource
                    Write-Verbose -Message "Deleting resource: $($resource.Name)"
                    Remove-AzResource -ResourceId $resource.ResourceId -Force -ErrorAction Stop
                    Write-Information "Deleted resource: $($resource.Name)"
                }
                catch
                {
                    Write-Error -Message "Failed to delete resource: $($resource.Name). Error: $_"
                    $success = $false
                }
            }

            return $success
        }
    }
    catch
    {
        Write-Error -Message "Failed to remove FinOps hub. Error: $_"
        if ($_.Exception.InnerException)
        {
            throw "Detailed Error: $($_.Exception.InnerException.Message)"
        }
        else
        {
            throw "Detailed Error: $($_.Exception.Message)"
        }
    }
}
