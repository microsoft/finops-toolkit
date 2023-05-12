param
(
    [Parameter()]
    [string]
    $Version,

    [Parameter()]
    [ValidateSet('alpha', 'beta')]
    [string]
    $PrereleaseTag
)

$rootPath = (Get-Item -Path $PSScriptRoot).Parent.FullName
$moduleName = 'FinOpsToolkit.psm1'
$modulePath = Join-Path -Path $rootPath -ChildPath 'src\powershell'
$privatePath = Join-Path -Path $modulePath -ChildPath 'private'
$publicPath = Join-Path -Path $modulePath -ChildPath 'public'
$releasePath = Join-Path -Path $modulePath -ChildPath 'FinOpsToolkit'

if ($Version)
{
    if ($PrereleaseTag)
    {
        $versionString = "$Version-$PrereleaseTag"
    }
    else
    {
        $versionString = $Version
    }

    $releasePath = Join-Path -Path $releasePath -ChildPath $versionString
}
else
{
    $releasePath = Join-Path -Path $releasePath -ChildPath '0.0.1'
}

$psm1Path = Join-Path -Path $releasePath -ChildPath $moduleName
$manifestPath = Join-Path -Path $releasePath -ChildPath 'FinOpsToolkit.psd1'

$null = New-Item -Path $releasePath -ItemType 'Directory'

'#region Private' | Add-Content -Path $psm1Path
$privateFunctions = Get-ChildItem -Path $privatePath -Filter '*.ps1'
foreach ($privateFunction in $privateFunctions)
{
    Get-Content -Path $privateFunction.FullName | Add-Content -Path $psm1Path
    '' | Add-Content -Path $psm1Path
}

"#endregion Private`n" | Add-Content -Path $psm1Path
'#region Public' | Add-Content -Path $psm1Path
$publicFunctions = Get-ChildItem -Path $publicPath -Filter '*.ps1'
$publicFunctionNames = @()
foreach ($publicFunction in $publicFunctions)
{
    $publicFunctionNames += "'$([System.IO.Path]::GetFileNameWithoutExtension($publicFunction))'"
    Get-Content -Path $publicFunction.FullName | Add-Content -Path $psm1Path
    '' | Add-Content -Path $psm1Path
}

"#endregion Public`n" | Add-Content -Path $psm1Path
"Export-ModuleMember -Function $($publicFunctionNames -join ', ')" | Add-Content -Path $psm1Path

$manifestProperties = @{
    Path              = $manifestPath
    Guid              = '00f120b5-2007-6120-0000-b03e1254e770'
    Author            = 'Microsoft Corporation'
    CompanyName       = 'Microsoft Corporation'
    Description       = 'FinOps toolkit - Cmdlets to deploy and manage resusable FinOps solutions in Azure. This module is compatible with PowerShell and Windows PowerShell. For more information about the FinOps toolkit, please visit https://aka.ms/finops/toolkit'
    RootModule        = $moduleName
    FunctionsToExport = $publicFunctionNames.Replace("'", '')
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

if ($Version)
{
    $manifestProperties.Add('ModuleVersion', $Version)
}

if ($PrereleaseTag)
{
    $manifestProperties.Add('Prerelease', $PrereleaseTag)
}

New-ModuleManifest @manifestProperties
