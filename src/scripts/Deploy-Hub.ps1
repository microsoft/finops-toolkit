# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Deploys a FinOps hub instance for local testing.

    .DESCRIPTION
    Wrapper around Deploy-Toolkit that simplifies FinOps hub deployments by providing scenario-based flags instead of requiring you to remember all the Bicep parameter names.

    By default, deploys with Azure Data Explorer (dev SKU). Use -StorageOnly for storage-only or -Fabric for Fabric-based deployments.

    All resources use an "{initials}-{name}" naming convention where initials are pulled from git config user.name and name defaults to "adx". Pass a name as the first positional parameter to use a custom value (e.g., "216" for Feb 16).

    .EXAMPLE
    Deploy-Hub

    Deploys a hub with ADX (e.g., RG "aa-adx", ADX "aa-adx").

    .EXAMPLE
    Deploy-Hub 216

    Deploys to a named environment (e.g., RG "aa-216", ADX "aa-216").

    .EXAMPLE
    Deploy-Hub -StorageOnly

    Deploys a storage-only hub (no ADX, no Fabric).

    .EXAMPLE
    Deploy-Hub -Fabric "https://my-eventhouse.kusto.data.microsoft.com"

    Deploys a hub connected to a Microsoft Fabric eventhouse.

    .EXAMPLE
    Deploy-Hub -Remove 210

    Deletes the resource group for the specified name (e.g., "aa-210").

    .EXAMPLE
    Deploy-Hub -Remove

    Lists all resource groups matching the "{initials}-*" naming convention.

    .EXAMPLE
    Deploy-Hub -Build

    Builds the template first, then deploys with ADX.

    .EXAMPLE
    Deploy-Hub -WhatIf

    Validates the deployment without making changes.

    .PARAMETER Name
    Optional. First positional parameter. Suffix for the "{initials}-{name}" naming convention used for resource group and ADX cluster. Default: "adx".

    .PARAMETER PR
    Optional. PR number for CI deployments. Resources are named "pr-{number}" or "pr-{number}-{name}" when -Name is also specified.

    .PARAMETER HubName
    Optional. Name of the hub instance. Default: "hub", or "{name}{initials}" when -PR or -Name is specified.

    .PARAMETER ADX
    Optional. Name of the Azure Data Explorer cluster. Overrides the "{initials}-{name}" convention. Only used when not using -StorageOnly or -Fabric.

    .PARAMETER ResourceGroup
    Optional. Name of the resource group. Overrides the "{initials}-{name}" convention.

    .PARAMETER Fabric
    Deploy with Microsoft Fabric. Provide the eventhouse query URI.

    .PARAMETER StorageOnly
    Deploy a storage-only hub (no Azure Data Explorer or Fabric).

    .PARAMETER Recommendations
    Enable recommendations with all noisy recommendation types (AHB, Spot). Requires the hub template to have recommendation parameters.

    .PARAMETER Remove
    Remove test environments. With a name, deletes the target resource group. Alone, lists all resource groups matching "{initials}-*".

    .PARAMETER Location
    Optional. Azure location. Default: westus.

    .PARAMETER Scope
    Optional. Azure scope ID for cost data exports (e.g., "/subscriptions/{id}"). When specified with -ManagedExports, enables managed exports and grants the hub identity access. When specified without -ManagedExports, creates exports manually via New-FinOpsCostExport after deployment.

    .PARAMETER ManagedExports
    Optional. Use managed exports instead of manual exports. Requires -Scope. Grants the hub managed identity the required roles on the scope and passes scopesToMonitor to the template.

    .PARAMETER Private
    Optional. Deploy with private networking (VNet and private endpoints). Default: false.

    .PARAMETER VirtualNetworkAddressPrefix
    Optional. Virtual network address prefix for private networking. Requires a /26 CIDR block. When set, also sets -Private. Default: "10.20.30.0/26".

    .PARAMETER Build
    Optional. Build the template before deploying.

    .PARAMETER WhatIf
    Optional. Validate the deployment without making changes.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md
#>
param(
    [Parameter(Position = 0)]
    [string]$Name,
    [int]$PR,
    [string]$HubName,
    [string]$ADX,
    [string]$ResourceGroup,
    [string]$Fabric,
    [switch]$StorageOnly,
    [switch]$Recommendations,
    [switch]$Remove,
    [string]$Scope,
    [switch]$ManagedExports,
    [switch]$Private,
    [string]$VirtualNetworkAddressPrefix,
    [string]$Location,
    [switch]$Build,
    [switch]$WhatIf
)

# Get user initials from git config user.name (first letter of each word, lowercased)
function Get-Initials()
{
    $name = (git config user.name 2>$null)
    if ($name)
    {
        $parts = $name.Trim() -split '\s+'
        if ($parts.Count -ge 2)
        {
            return (($parts | ForEach-Object { $_[0] }) -join '').ToLower()
        }
        return $name.Substring(0, [Math]::Min(2, $name.Length)).ToLower()
    }

    # Fall back to OS username
    $u = ($env:USERNAME ?? $env:USER ?? "xx").ToLower()
    $parts = $u -split '[\.\-_\s]'
    if ($parts.Count -ge 2)
    {
        return ($parts | ForEach-Object { $_[0] }) -join ''
    }
    return $u.Substring(0, [Math]::Min(2, $u.Length))
}

if ($PR)
{
    $initials = "pr-$PR"
}
else
{
    $initials = Get-Initials
}

# Default name to "adx" when not specified
if (-not $Name)
{
    $Name = "adx"
}

# Build the full name: {initials}-{name}
$fullName = "$initials-$Name"

#------------------------------------------------------------------------------
# Remove mode
#------------------------------------------------------------------------------

if ($Remove)
{
    if ($PSBoundParameters.ContainsKey('Name'))
    {
        # Delete the specific resource group
        $rgName = if ($ResourceGroup) { $ResourceGroup } else { $fullName }
        $rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
        if ($null -eq $rg)
        {
            Write-Host "Resource group '$rgName' not found."
            return
        }

        Write-Host "Deleting resource group '$rgName'..."
        Remove-AzResourceGroup -Name $rgName -Force -WhatIf:$WhatIf
        if (-not $WhatIf) { Write-Host "Deleted '$rgName'." }
    }
    else
    {
        # List all resource groups matching the initials-* pattern
        $pattern = "$initials-*"
        $groups = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like $pattern }
        if (-not $groups)
        {
            Write-Host "No resource groups found matching '$pattern'."
        }
        else
        {
            Write-Host "Resource groups matching '$pattern':"
            $groups | ForEach-Object {
                Write-Host "  $($_.ResourceGroupName) ($($_.Location))"
            }
            Write-Host ""
            Write-Host "Use -Remove <name> to delete a specific one."
        }
    }
    return
}

#------------------------------------------------------------------------------
# Deploy mode
#------------------------------------------------------------------------------

# Validate mutually exclusive options
if ($StorageOnly -and $Fabric)
{
    Write-Error "Cannot specify both -StorageOnly and -Fabric. Please choose one analytics backend."
    return
}

if ($ManagedExports -and -not $Scope)
{
    Write-Error "-ManagedExports requires -Scope. Provide an Azure scope ID (e.g., '/subscriptions/{id}')."
    return
}

# Build parameters
$params = @{}

# Hub name — use "{name}{initials}" when -PR or -Name is specified, otherwise "hub"
if ($HubName) { $params.hubName = $HubName }
elseif ($PR -or $PSBoundParameters.ContainsKey('Name'))
{
    $explicitName = if ($PSBoundParameters.ContainsKey('Name')) { $Name } else { $null }
    $hubParts = @($explicitName, $initials) | Where-Object { $_ }
    $params.hubName = (($hubParts -join '') -replace '[^a-zA-Z0-9]', '').ToLower()
}
else { $params.hubName = "hub" }

# Recommendations (requires enableRecommendations param in hub template)
if ($Recommendations)
{
    $params.enableRecommendations = $true
    $params.enableAHBRecommendations = $true
    $params.enableSpotRecommendations = $true
}

# Analytics backend
if ($StorageOnly)
{
    Write-Host "Scenario: Storage-only (no analytics engine)"
}
elseif ($Fabric)
{
    $params.fabricQueryUri = $Fabric
    Write-Host "Scenario: Microsoft Fabric ($Fabric)"
}
else
{
    # Default: Azure Data Explorer (dev SKU)
    if ($ADX) { $params.dataExplorerName = $ADX }
    else { $params.dataExplorerName = $fullName }
    Write-Host "Scenario: Azure Data Explorer ($($params.dataExplorerName))"
}

Write-Host "  Hub: $($params.hubName)"

# Managed exports via template parameters
if ($ManagedExports -and $Scope)
{
    $params.enableManagedExports = $true
    $params.scopesToMonitor = @($Scope)
    Write-Host "  Managed exports: $Scope"
}
elseif ($Scope)
{
    $params.enableManagedExports = $false
    Write-Host "  Manual exports: $Scope"
}
else
{
    $params.enableManagedExports = $false
}

# Private networking (infer from VNet prefix if provided)
if ($VirtualNetworkAddressPrefix) { $Private = $true }
if ($Private)
{
    $params.enablePublicAccess = $false
    if ($VirtualNetworkAddressPrefix)
    {
        $params.virtualNetworkAddressPrefix = $VirtualNetworkAddressPrefix
    }
    Write-Host "  Private networking: enabled (VNet $($VirtualNetworkAddressPrefix ?? '10.20.30.0/26'))"
}

# Resource group
if (-not $ResourceGroup)
{
    $ResourceGroup = $fullName
}

# Forward to Deploy-Toolkit
$deployArgs = @{
    Template      = "finops-hub"
    Parameters    = $params
    ResourceGroup = $ResourceGroup
}
if ($Location) { $deployArgs.Location = $Location }
$deployArgs.Build = $Build
$deployArgs.WhatIf = $WhatIf

& "$PSScriptRoot/Deploy-Toolkit" @deployArgs

#------------------------------------------------------------------------------
# Post-deployment: configure exports
#------------------------------------------------------------------------------

if ($Scope -and -not $WhatIf -and $global:ftkDeployment)
{
    $outputs = $global:ftkDeployment.Outputs

    if ($ManagedExports)
    {
        # Grant hub managed identity the required roles on the scope
        $managedIdentityId = $outputs["managedIdentityId"].Value
        if ($managedIdentityId)
        {
            Write-Host "Granting hub identity access to $Scope..."
            $roles = @("Cost Management Contributor")
            foreach ($role in $roles)
            {
                $existing = Get-AzRoleAssignment -ObjectId $managedIdentityId -RoleDefinitionName $role -Scope $Scope -ErrorAction SilentlyContinue
                if (-not $existing)
                {
                    $result = New-AzRoleAssignment -ObjectId $managedIdentityId -RoleDefinitionName $role -Scope $Scope -ErrorAction SilentlyContinue
                    if ($result)
                    {
                        Write-Host "  Granted: $role"
                    }
                    else
                    {
                        Write-Warning "Failed to grant $role. You may need to assign it manually."
                    }
                }
            }
        }
        else
        {
            Write-Warning "Could not retrieve managedIdentityId from deployment outputs. Grant access manually."
        }
    }
    else
    {
        # Create exports manually via New-FinOpsCostExport
        $storageAccountId = $outputs["storageAccountId"].Value
        if ($storageAccountId)
        {
            Write-Host "Creating manual exports for $Scope..."

            # Import the FinOps toolkit PowerShell module if not already loaded
            if (-not (Get-Command New-FinOpsCostExport -ErrorAction SilentlyContinue))
            {
                Import-Module "$PSScriptRoot/../powershell/FinOpsToolkit.psm1" -Force
            }

            New-FinOpsCostExport -Name "ftk-focuscost" `
                -Scope $Scope `
                -Dataset "FocusCost" `
                -StorageAccountId $storageAccountId `
                -StorageContainer "msexports" `
                -DoNotOverwrite `
                -Execute
            Write-Host "  Created FocusCost export and triggered initial run."
        }
        else
        {
            Write-Warning "Could not retrieve storageAccountId from deployment outputs. Create exports manually."
        }
    }
}
