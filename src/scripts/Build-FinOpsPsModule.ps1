param
(
    [Parameter(Mandatory = $true)]
    [string]
    [ValidateScript({$_ -match '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'})]
    $Version,

    [Parameter()]
    [ValidateSet('alpha', 'preview')]
    [string]
    $PrereleaseTag
)

$rootPath = (Get-Item -Path $PSScriptRoot).Parent.Parent.FullName
$moduleName = 'FinOpsToolkit'
$moduleFullName = "$moduleName.psm1"
$modulePath = Join-Path -Path $rootPath -ChildPath "src\powershell\$moduleFullName"
$stringsPath = Join-Path -Path $rootPath -ChildPath 'src\powershell\en-US'
$releasePath = Join-Path -Path $rootPath -ChildPath "release\FinOpsToolkit\$Version"
$scriptPath = Join-Path -Path $rootPath -ChildPath 'src\scripts'
$manifestPath = Join-Path -Path $releasePath -ChildPath 'FinOpsToolkit.psd1'

# Make sure we can import module properly. Capture exported functions.
try
{
    Import-Module -FullyQualifiedName $modulePath -ErrorAction 'Stop'
    $exportedCommands = Get-Command -Module $moduleName
    Remove-Module -Name $moduleName
}
catch
{
    throw ("Error importing module at path: '{0}', {1}" -f $modulePath, $_.Exception.Message)
}

# Create release directory
Push-Location -Path $scriptPath
.\New-Directory $releasePath
Pop-Location

$manifestProperties = @{
    ModuleVersion     = $Version
    Path              = $manifestPath
    Guid              = '00f120b5-2007-6120-0000-b03e1254e770'
    Author            = 'Microsoft Corporation'
    CompanyName       = 'Microsoft Corporation'
    Description       = 'FinOps toolkit - Cmdlets to deploy and manage resusable FinOps solutions in Azure. This module is compatible with PowerShell and Windows PowerShell. For more information about the FinOps toolkit, please visit https://aka.ms/finops/toolkit'
    RootModule        = $moduleFullName
    FunctionsToExport = $exportedCommands.Name
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    Copyright         = '(c) 2023 Microsoft Corporation. All rights reserved.'
    PowerShellVersion = '5.1'
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
    IconUri           = 'https://raw.githubusercontent.com/microsoft/cloud-hubs/4747859b1c800f49d5b0c3cd7894a40fe8641c3a/src/images/FinOpsHubs.svg'
    LicenseUri        = 'https://github.com/microsoft/cloud-hubs/blob/dev/LICENSE'
    ProjectUri        = 'https://github.com/microsoft/cloud-hubs'
    Tags              = @('FinOps', 'Cost', 'CostManagement', 'Azure', 'MicrosoftCloud')
}

if ($PrereleaseTag)
{
    $manifestProperties.Add('Prerelease', $PrereleaseTag)
}

# Create manifest and copy supporting files
New-ModuleManifest @manifestProperties
Copy-Item -Path $modulePath -Destination $releasePath
Copy-Item -Path $stringsPath -Destination $releasePath -Container -Recurse
