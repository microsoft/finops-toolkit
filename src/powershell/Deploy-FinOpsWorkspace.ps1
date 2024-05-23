# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Deploys a Microsoft Fabric workspace for FinOps.

    .DESCRIPTION
    The Deploy-FinOpsWorkspace command either creates a new or updates an existing Microsoft Fabric workspace for FinOps. This includes creating exports and deploying preconfigured reports from the FinOps toolkit. The FinOps toolkit reports are downloaded from GitHub.

    .PARAMETER Name
    Required. Name of the workspace.

    .PARAMETER Type
    Required. Type of the workbook to deploy. Allowed values = Governance, Optimization.

    .PARAMETER ResourceGroupName
    Required. Name of the resource group to deploy to. Will be created if it doesn't exist.

    .PARAMETER Location
    Required. Azure location to execute the deployment from.

    .PARAMETER Version
    Optional. Version of the FinOps toolkit to use. Default = "latest".

    .PARAMETER Preview
    Optional. Indicates that preview releases should also be included. Default = false.

    .PARAMETER Tags
    Optional. Tags for all resources.

    .EXAMPLE
    Deploy-FinOpsWorkspace -Name MyWorkbook -Type Optimization -ResourceGroupName MyNewResourceGroup -Location westus

    Deploys the FinOps toolkit Cost optimization workbook to the MyNewResourceGroup resource group and names it MyWorkbook. If the resource group does not exist, it will be created. If the workbook already exists, it will be updated to the latest version.

    .EXAMPLE
    Deploy-FinOpsWorkspace -Name MyWorkbook -Type Governance -ResourceGroupName MyExistingResourceGroup -Location westus -Version 0.2

    Deploys the FinOps toolkit Governance workbook to the MyExistingResourceGroup resource group and names it MyWorkbook using version 0.1.1 of the template. This version is required in order to deploy to Azure Gov or Azure China as of February 2024 since FOCUS exports are not available from Cost Management in those environments. If the resource group does not exist, it will be created. If the workbook already exists, it will be updated to version 0.2.

    .LINK
    https://aka.ms/ftk/Deploy-FinOpsWorkspace
#>
#function Deploy-FinOpsWorkspace
#{
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "")]
[CmdletBinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]
    $Name,

    [Parameter(Position = 1)]
    [string]
    $Lakehouse = 'FinOpsHubData',

    # [Parameter(Mandatory = $true)]
    # [ValidateSet('Governance', 'Optimization')]
    # [string]
    # $Type,

    # [Parameter(Mandatory = $true)]
    # [string]
    # $ResourceGroupName,

    # [Parameter(Mandatory = $true)]
    # [string]
    # $Location,

    # [Parameter()]
    # [string]
    # $Scope,

    # [Parameter()]
    # [string]
    # $Version = 'latest',

    [Parameter()]
    [switch]
    $TryFabricCapacity,

    [Parameter()]
    [string]
    $StorageAccount,

    [Parameter()]
    [switch]
    $Preview
)

# TODO: Remove when adding to the module
$script:localizedData = @{ Common_ErrorResponse = 'Error: {0} (Code: {1})' }
. ./Private/Test-ShouldProcess.ps1
. ./Private/Invoke-Rest.ps1

# User needs to:
# Install-Module -Name MicrosoftPowerBIMgmt
# Login-PowerBIServiceAccount

# Init return object
$fw = @{
    Id          = $null
    Name        = $null
    Description = $null
    Capacity    = @{
        Id    = $null
        Name  = $null
        Sku   = $null
        State = $null
    }
    Lakehouse   = @{
        Id          = $null
        Name        = $null
        Description = $null
    }
    Tables      = @{
        CostDetails = $null
    }
    Shortcuts   = @{
        CostDetails = $null
    }
}

# try
# {
    
# Get capacities to verify Fabric capacity
# TODO: Move to localized data
Write-Verbose 'Getting capacities...'
$capacitiesResponse = Invoke-Rest -Method GET -Service Fabric -Uri 'capacities' -CommandName 'Deploy-FinOpsWorkspace'
if ($capacitiesResponse.Success)
{
    $capacities = $capacitiesResponse.Content.value `
    | Where-Object { $_.state -eq 'Active' -and $null -ne $_.sku } `
    | Sort-Object {
        $index = [int]($_.sku -replace '[^\d]', '') / 1000
        if ($_.sku -match '^FT')
        {
            $index += 0 # Group "FT" SKUs first
        }
        elseif ($_.sku -match '^F')
        {
            $index += 1 # Group "F" SKUs next
        }
        else
        {
            $index += 2 # Other SKUs last (keep for lookup purposes only)
        }
        return $index
    } `
    | ForEach-Object {
        Write-Verbose "- $($_.state) / $($_.sku) / $($_.displayName) ($($_.id))"
        return $_
    }
}

# Check for existing workspace
# TODO: Move to localized data
Write-Verbose 'Getting workspaces...'
$getWorkspacesResponse = Invoke-Rest -Method GET -Service Fabric -Uri 'workspaces' -CommandName 'Deploy-FinOpsWorkspace'
if ($getWorkspacesResponse.Success)
{
    $workspace = $getWorkspacesResponse.Content.value | Where-Object { $_.displayName -eq $Name }
    $fw.Id = $workspace.id
    $fw.Name = $workspace.displayName
    $fw.Description = $workspace.description
    $fw.Capacity.Id = $workspace.capacityId
}
if ($workspace)
{
    # TODO: Move to localized data
    Write-Verbose -Message ('Workspace {0} already exists: {1}' -f $Name, ($workspace | ConvertTo-Json -Depth 10))
    
    if ($workspace.capacityId)
    {
        # Lookup current capacity details
        $capacityDetails = $capacities | Where-Object { $_.id -eq $workspace.capacityId }
        $fw.Capacity.Name = $capacityDetails.displayName
        $fw.Capacity.Sku = $capacityDetails.sku
        $fw.Capacity.State = $capacityDetails.state
        if ($null -eq $capacityDetails)
        {
            # TODO: Move to localized data
            Write-Verbose "Cannot verify capacity SKU. Account does not have access to capacity $($workspace.capacityId)."
        }
        else
        {
            # TODO: Move to localized data
            Write-Verbose "Workspace assigned to $($capacityDetails.state) $($capacityDetails.sku) capacity $($capacityDetails.displayName) ($($capacityDetails.id))"
            
            # TODO: Should we reset the capacity if it's not Fabric?
            if ($TryFabricCapacity -and $capacityDetails.state -ne 'Active' -or $capacityDetails.sku[0] -ne 'F')
            {
                # TODO: Move to localized data
                Write-Verbose "Workspace capacity does not support Fabric resources - Will try available capacity options"
                $workspace.capacityId = $null
            }
        }
    }
    else
    {
        # TODO: Move to localized data
        Write-Verbose "Workspace does not have capacity assigned"
    }
}

# Create workspace without capacity
if (-not $workspace -and (Test-ShouldProcess $PSCmdlet $Name 'CreateWorkspace'))
{
    $workspace = @{
        displayName = $Name
        description = 'FinOps workspace'
    }
    Write-Verbose "Creating workspace $Name with capacity $defaultCapacityId..."
    $createResponse = Invoke-Rest -Service Fabric -Method POST -Uri 'workspaces' -Body $workspace -CommandName 'Deploy-FinOpsWorkspace'
    if ($createResponse.Success)
    {
        $workspace = $createResponse.Content
        $fw.Id = $workspace.id
        $fw.Name = $workspace.displayName
        $fw.Description = $workspace.description
        $fw.Capacity.Id = $workspace.capacityId
    }
    else
    {
        # TODO: Move to localized data
        Write-Error "Failed to create workspace $Name"
    }
}

# Assign capacity
if ($TryFabricCapacity -and $workspace -and (-not $workspace.capacityId) -and (Test-ShouldProcess $PSCmdlet $Name 'AssignCapacity'))
{
    $attemptSuccess = $false
    $capacities `
    | Where-Object { $_.state -eq 'Active' -and $_.sku[0] -eq 'F' } `
    | ForEach-Object {
        # Stop if capacity is already assigned
        if ($attemptSuccess)
        {
            return $fw
        }

        $attemptCapacity = $_

        # TODO: Move to localized data
        Write-Verbose "Updating workspace $Name with $($attemptCapacity.sku) capacity $($attemptCapacity.id)..."
        $assignResponse = Invoke-Rest -Service Fabric -Method POST -Uri "workspaces/$($workspace.Id)/assignToCapacity" -Body @{ capacityId = $attemptCapacity.id } -CommandName 'Deploy-FinOpsWorkspace' -ErrorAction SilentlyContinue
        if ($assignResponse.Success)
        {
            if (($tmp.Keys | Where-Object { $_ -eq 'capacityId' }).Count -eq 0)
            {
                $workspace.capacityId = $attemptCapacity.id
            }
            else
            {
                $workspace | Add-Member -MemberType NoteProperty -Name 'capacityId' -Value $attemptCapacity.id
            }
            $fw.Capacity.Id = $attemptCapacity.id
            $fw.Capacity.Name = $attemptCapacity.displayName
            $fw.Capacity.Sku = $attemptCapacity.sku
            $fw.Capacity.State = $attemptCapacity.state
            $attemptSuccess = $true
        }
        else
        {
            # TODO: Move to localized data
            Write-Error "X - Failed to assign capacity $($attemptCapacity.id) to workspace $Name"
        }
    }
}

# Confirm capacity is set
if (-not $workspace.capacityId)
{
    if (-not $capacities)
    {
        # TODO: Move to localized data
        Write-Error 'No available capacity to assign. Capacity must be created manually.'
    }
    else
    {
        # TODO: Move to localized data
        Write-Error 'Failed to assign valid capacity ID. Capacity must be configured manually.'
    }
    return $fw
}

# # Create a folder
# $folderParams = @{
#     Method = "Post" 
#     Url    = "workspaces/$($workspace.Id)/folders" 
#     Body   = @{
#         displayName = 'FinOps toolkit'
#         description = 'FinOps toolkit resources'
#     }
# }
# Invoke-Rest -Service Fabric @folderParams

# Check for existing lakehouse
# TODO: Move to localized data
Write-Verbose 'Getting lakehouses...'
$getLakehousesResponse = Invoke-Rest -Method GET -Service Fabric -Uri "workspaces/$($fw.Id)/lakehouses" -CommandName 'Deploy-FinOpsWorkspace'
if ($getLakehousesResponse.Success)
{
    $lh = $getLakehousesResponse.Content.value | Where-Object { $_.displayName -eq $Lakehouse }
    $fw.Lakehouse.Id = $lh.id
    $fw.Lakehouse.Name = $lh.displayName
    $fw.Lakehouse.Description = $lh.description
}
if ($lh)
{
    # TODO: Move to localized data
    Write-Verbose -Message ('Lakehouse {0} already exists: {1}' -f $Lakehouse, ($lh | ConvertTo-Json -Depth 10))
}

# Create lakehouse
if (-not $lh -and (Test-ShouldProcess $PSCmdlet $Lakehouse 'CreateLakehouse'))
{
    $lakehouseParams = @{
        Method = "POST" 
        Uri    = "workspaces/$($fw.Id)/lakehouses" 
        Body   = @{
            displayName = $Lakehouse
            description = 'Lakehouse for FinOps datasets'
        }
    }
    $lakehouseResponse = Invoke-Rest -Service Fabric @lakehouseParams -CommandName 'Deploy-FinOpsWorkspace'
    if ($lakehouseResponse.Success)
    {
        $lakehouse = $lakehouseResponse.Content
        $fw.Lakehouse.Id = $lakehouse.id
        $fw.Lakehouse.Name = $lakehouse.displayName
        $fw.Lakehouse.Description = $lakehouse.description
    }
    else
    {
        Write-Error "Failed to create lakehouse $Lakehouse"
        return $fw
    }
}

# Create shortcuts
$costDetailsName = 'CostDetails'
if (Test-ShouldProcess $PSCmdlet $costDetailsName 'CreateCostDetailsShortcut')
{
    $shortcutParams = @{
        Method = "POST" 
        Uri    = "workspaces/$($fw.Id)/lakehouses/$($fw.Lakehouse.Id)/shortcuts?shortcutConflictPolicy=Abort" 
        Body   = @{
            name   = $costDetailsName
            path   = 'Files'
            target = @{
                connectionId = '' # TODO: Set the target path
                location     = "https://$StorageAccount.dfs.core.windows.net"
                subpath      = 'msexports'
            }
        }
    }
    $shortcutResponse = Invoke-Rest -Service Fabric @shortcutParams -CommandName 'Deploy-FinOpsWorkspace'
    if ($shortcutResponse.Success)
    {
        $fw.Shortcuts.CostDetails = $shortcutResponse.Content.path
    }
    else
    {
        Write-Error "Failed to create shortcut $costDetailsName"
    }
}

# # Check for existing table
# # TODO: Move to localized data
# Write-Verbose 'Getting tables...'
# $getTablesResponse = Invoke-Rest -Method GET -Service Fabric -Uri "workspaces/$($fw.Id)/lakehouses/$($fw.Lakehouse.Id)/tables" -CommandName 'Deploy-FinOpsWorkspace'
# if ($getTablesResponse.Success)
# {
#     $cd = $getTablesResponse.Content.data | Where-Object { $_.name -eq $costDetailsName }
#     $fw.Tables.CostDetails = $cd.location
# }

# # Create table
# if (-not $cd -and (Test-ShouldProcess $PSCmdlet $costDetailsName 'CreateCostDetailsTable'))
# {
#     $tableParams = @{
#         Method = "POST" 
#         Uri    = "workspaces/$($fw.Id)/items/$($fw.Lakehouse.Id)/tables" 
#         Body   = @{
#             name   = $costDetailsName
#             type   = 'Managed' # TODO: Confirm
#             format = 'Delta' # TODO: Confirm
#         }
#     }
#     $tableResponse = Invoke-Rest -Service Fabric @tableParams -CommandName 'Deploy-FinOpsWorkspace'
#     if ($tableResponse.Success)
#     {
#         $fw.Tables.CostDetails = $tableResponse.Content.location
#     }
#     else
#     {
#         Write-Error "Failed to create table $costDetailsName"
#     }
# }
    
return $fw
# }
# catch
# {
#     throw $_.Exception.Message
# }
# finally
# {
#     Remove-Item -Path $toolkitPath -Recurse -Force -ErrorAction 'SilentlyContinue'
# }
#}
