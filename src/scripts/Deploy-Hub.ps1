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

    .PARAMETER HubName
    Optional. Name of the hub instance. Default: "hub".

    .PARAMETER ADX
    Optional. Name of the Azure Data Explorer cluster. Overrides the "{initials}-{name}" convention. Only used when not using -StorageOnly or -Fabric.

    .PARAMETER ResourceGroup
    Optional. Name of the resource group. Overrides the "{initials}-{name}" convention.

    .PARAMETER Fabric
    Deploy with Microsoft Fabric. Provide the eventhouse query URI.

    .PARAMETER StorageOnly
    Deploy a storage-only hub (no Azure Data Explorer or Fabric).

    .PARAMETER Remove
    Remove test environments. With a name, deletes the target resource group. Alone, lists all resource groups matching "{initials}-*".

    .PARAMETER Location
    Optional. Azure location. Default: westus.

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
    [string]$HubName,
    [string]$ADX,
    [string]$ResourceGroup,
    [string]$Fabric,
    [switch]$StorageOnly,
    [switch]$Remove,
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

$initials = Get-Initials

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
        Remove-AzResourceGroup -Name $rgName -Force
        Write-Host "Deleted '$rgName'."
    }
    else
    {
        # List all resource groups matching the initials-* pattern
        $pattern = "$initials-*"
        $groups = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like $pattern }
        if ($groups.Count -eq 0)
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

# Build parameters
$params = @{}

# Hub name
if ($HubName) { $params.hubName = $HubName }
else { $params.hubName = "hub" }

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
