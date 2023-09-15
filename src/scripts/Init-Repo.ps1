# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[CmdletBinding(SupportsShouldProcess)]
Param()

# Install Az
if ($PSCmdlet.ShouldProcess("Az PowerShell module", 'Install')) {
    Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
}

# Install Bicep
if ($PSCmdlet.ShouldProcess("Bicep CLI", 'Install')) {
    # Copied from https://learn.microsoft.com/azure/azure-resource-manager/bicep/install#manual-with-powershell
    # Create the install folder
    $installPath = "$($env:USERPROFILE)\.bicep"
    $installDir = New-Item -ItemType Directory -Path $installPath -Force
    $installDir.Attributes += 'Hidden'
    # Fetch the latest Bicep CLI binary
    (New-Object Net.WebClient).DownloadFile("https://github.com/Azure/bicep/releases/latest/download/bicep-win-x64.exe", "$installPath\bicep.exe")
    # Add bicep to your PATH
    $currentPath = (Get-Item -path "HKCU:\Environment" ).GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    if (-not $currentPath.Contains("%USERPROFILE%\.bicep")) { setx PATH ($currentPath + ";%USERPROFILE%\.bicep") }
    if (-not $env:path.Contains($installPath)) { $env:path += ";$installPath" }
    # Verify you can now access the 'bicep' command.
    bicep --version
}
