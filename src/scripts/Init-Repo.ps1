# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Installs apps and modules for use during FinOps toolkit development.

    .DESCRIPTION
    The Init-Repo command installs:
    - Az PowerShell
    - Bicep CLI

    The following optional apps/modules can be installed with the corresponding parameters or with the -All parameter:
    - VS Code
    - Bicep PowerShell
    - NodeJS and configured modules (-NPM parameter)
    - Pester

    If an app or module is already installed, it will be skipped. To see which apps would be installed, use the -WhatIf parameter.

    .PARAMETER VSCode
    Installs Visual Studio Code via winget.

    .PARAMETER BicepPowerShell
    Installs the Bicep PowerShell module.

    .PARAMETER NPM
    Installs NodeJS via winget, then installs configured NPM modules. NPM is used for local dev build tasks.

    .PARAMETER Pester
    Installs Pester PowerShell module for testing PowerShell commands.

    .PARAMETER All
    Installs optional apps and modules.

    .PARAMETER Upgrade
    Indicates whether specified components should be upgraded, if already installed.
#>
[CmdletBinding(SupportsShouldProcess)]
Param(
    [switch] $VSCode,
    [switch] $BicepPowerShell,
    [switch] $NPM,
    [switch] $Pester,
    [switch] $All,
    [switch] $Upgrade
)

# winget (check only)
Write-Verbose "Checking for winget..."
$winget = if ($IsWindows) { Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue } else { $null }
Write-Verbose "...$(if (-not $winget) { 'not ' })installed"

# VS Code
if ($VSCode -or $All)
{
    Write-Verbose "Checking for VS Code..."
    if ((pwsh -NoProfile -Command 'code --version' | Join-String).Contains('not recognized') -eq $false -and -not $Upgrade)
    {
        Write-Verbose "...already installed"
    }
    else
    {
        Write-Verbose "...not installed"
        if ($PSCmdlet.ShouldProcess("VS Code", 'Install'))
        {
            if ($winget)
            {
                Write-Host 'Installing VS Code...'
                winget install -e --id Microsoft.VisualStudioCode
            }
            else
            {
                Write-Host 'Please install VS Code from https://code.visualstudio.com/Download'
            }
        }
    }
}

# Az -- required for testing
Write-Verbose "Checking for Az PowerShell..."
if ((Get-Module -Name Az -ListAvailable) -and -not $Upgrade)
{
    Write-Verbose "...installed"
}
else
{
    Write-Verbose "...not installed"
    if ($PSCmdlet.ShouldProcess("Az PowerShell module", 'Install'))
    {
        Write-Host 'Installing Az PowerShell...'
        Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
    }
}

# Bicep PowerShell
if ($BicepPowerShell -or $All)
{
    Write-Verbose "Checking for Bicep PowerShell..."
    if ((Get-Module -Name Bicep -ListAvailable) -and -not $Upgrade)
    {
        Write-Verbose "...installed"
    }
    else
    {
        Write-Verbose "...not installed"
        if ($PSCmdlet.ShouldProcess("Bicep PowerShell", 'Install'))
        {
            Write-Host 'Installing Bicep PowerShell...'
            Install-Module -Name Bicep -Scope CurrentUser -Repository PSGallery -Force
        }
    }
}

# Bicep CLI -- required for testing
Write-Verbose "Checking for bicep..."
if ((pwsh -NoProfile -Command 'bicep --version' | Join-String).Contains('not recognized') -eq $false -and -not $Upgrade)
{
    Write-Verbose "...already installed"
}
else
{
    Write-Verbose "...not installed"
    if ($PSCmdlet.ShouldProcess("Bicep CLI", 'Install'))
    {
        if ($winget)
        {
            Write-Host 'Installing Bicep CLI...'
            winget install -e --id Microsoft.Bicep
        }
        elseif ($IsWindows)
        {
            Write-Host 'Installing Bicep CLI...'
            # Copied from https://learn.microsoft.com/azure/azure-resource-manager/bicep/install#manual-with-powershell
            # Create the install folder
            $installPath = "$($env:USERPROFILE)\.bicep"
            $installDir = New-Item -ItemType Directory -Path $installPath -Force
            $installDir.Attributes += 'Hidden'
            # Fetch the latest Bicep CLI binary
            (New-Object Net.WebClient).DownloadFile("https://github.com/Azure/bicep/releases/latest/download/bicep-win-x64.exe", "$installPath\bicep.exe")
            # Add bicep to your PATH
            $currentPath = (Get-Item -Path "HKCU:\Environment" ).GetValue('Path', '', 'DoNotExpandEnvironmentNames')
            if (-not $currentPath.Contains("%USERPROFILE%\.bicep")) { setx PATH ($currentPath + ";%USERPROFILE%\.bicep") }
            if (-not $env:path.Contains($installPath)) { $env:path += ";$installPath" }
            # Verify you can now access the 'bicep' command.
            bicep --version
        }
        else
        {
            Write-Host 'Please install Bicep from https://github.com/Azure/bicep/releases/latest/download'
        }
    }
}

# NodeJS -- used for local dev scripts
$npmVer = (pwsh -NoProfile -Command 'npm -v' | Join-String).Contains('not recognized') -eq $false
if ($NPM -or $All)
{
    Write-Verbose "Checking for npm..."
    if ($npmVer)
    {
        Write-Verbose "...already installed"
    }
    else
    {
        Write-Verbose "...not installed"
        if ($PSCmdlet.ShouldProcess("NodeJS", 'Install'))
        {
            if ($winget)
            {
                Write-Host 'Installing NodeJS...'
                winget install OpenJS.NodeJS.LTS
                $npmVer = $? -eq 0
            }
            if (-not $npmVer)
            {
                Write-Host 'Please install NPM from https://nodejs.org/en/download'
            }
        }
    }

    # NPM modules
    if ($npmVer -and $PSCmdlet.ShouldProcess("NPM modules", 'Install'))
    {
        Write-Host 'Updating NPM modules...'
        npm install
    }
}
elseif (-not $npmVer)
{
    Write-Host "⚠️ Skipping NPM. You will not be able to run scripts from any directory or update versions."
}

# Pester -- Used for testing PowerShell commands
if ($Pester -or $All)
{
    Install-Module -Name Pester -Force
}
elseif (-not (Get-Module Pester))
{
    Write-Host "⚠️ Skipping Pester. You will not be able to run tests."
}
