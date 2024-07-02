# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Build-PsModule
{
    [CmdletBinding()]
    param
    ()

    # Get version
    $version = & "$PSScriptRoot/../../src/scripts/Get-Version.ps1"
    $baseVersion = $version.Split('-') | Select-Object -First 1
    $prereleaseTag = $null
    if ($version -contains '-')
    {
        $prereleaseTag = $version.Split('-') | Select-Object -Last 1
    }

    $rootPath = (Get-Item -Path $PSScriptRoot).Parent.Parent.FullName
    $moduleName = 'FinOpsToolkit'
    $moduleFullName = "$moduleName.psm1"
    $modulePath = Join-Path -Path $rootPath -ChildPath "src/powershell/$moduleFullName"
    $privatePath = Join-Path -Path $rootPath -ChildPath "src/powershell/private"
    $publicPath = Join-Path -Path $rootPath -ChildPath "src/powershell/public"
    $stringsPath = Join-Path -Path $rootPath -ChildPath 'src/powershell/en-US'
    $releasePath = Join-Path -Path $rootPath -ChildPath "release/$moduleName/$baseVersion"
    $manifestPath = Join-Path -Path $releasePath -ChildPath "$moduleName.psd1"

    # Make sure we can import module properly. Capture exported functions.
    try
    {
        Import-Module -FullyQualifiedName $modulePath -ErrorAction 'Stop'
        $exportedCommands = Get-Command -Module $moduleName
        Remove-Module -Name $moduleName -Force -ErrorAction 'SilentlyContinue'
    }
    catch
    {
        throw ("Error importing module at path: '{0}', {1}" -f $modulePath, $_.Exception.Message)
    }

    # Create release directory
    New-Directory -Path $releasePath

    $manifestProperties = @{
        ModuleVersion     = $baseVersion
        Path              = $manifestPath
        Guid              = '00f120b5-2007-6120-0000-b03e1254e770'
        Author            = 'Microsoft Corporation'
        CompanyName       = 'Microsoft Corporation'
        Description       = 'FinOps toolkit - Commands to deploy and manage resusable FinOps solutions in the Microsoft Cloud. This module is compatible with PowerShell and Windows PowerShell. For more information about the FinOps toolkit, please visit https://aka.ms/finops/toolkit'
        RootModule        = $moduleFullName
        FunctionsToExport = $exportedCommands.Name
        CmdletsToExport   = @()
        VariablesToExport = @()
        AliasesToExport   = @()
        Copyright         = "(c) $((Get-Date).Year) Microsoft Corporation. All rights reserved."
        PowerShellVersion = '7.0'
        RequiredModules   = @(
            @{
                ModuleName    = 'Az.Accounts'
                ModuleVersion = '2.11.1'
            },
            @{
                ModuleName    = 'Az.Resources'
                ModuleVersion = '6.5.1'
            }
        )
        IconUri           = 'https://raw.githubusercontent.com/microsoft/finops-toolkit/4747859b1c800f49d5b0c3cd7894a40fe8641c3a/src/images/FinOpsToolkit.svg'
        LicenseUri        = 'https://github.com/microsoft/finops-toolkit/blob/main/LICENSE'
        ProjectUri        = 'https://github.com/microsoft/finops-toolkit'
        Tags              = @('FinOps', 'Cost', 'CostManagement', 'Azure', 'MicrosoftCloud')
    }

    if ($prereleaseTag)
    {
        $manifestProperties.Add('Prerelease', $prereleaseTag)
    }

    # Create manifest and copy supporting files
    New-ModuleManifest @manifestProperties
    Copy-Item -Path $modulePath -Destination $releasePath
    Copy-Item -Path $stringsPath -Destination $releasePath -Container -Recurse
    Copy-Item -Path $privatePath -Destination $releasePath -Container -Recurse
    Copy-Item -Path $publicPath -Destination $releasePath -Container -Recurse
    Add-CopyrightHeader -Path $manifestPath
}
