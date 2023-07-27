# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

param
(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Unit', 'Meta')]
    [string]
    $Type,

    [Parameter()]
    [switch]
    $InstallPreReqs
)

$requiredModules = @(
    @{
        Name    = 'Pester'
        Version = '5.4.1'
    },
    @{
        Name    = 'PSScriptAnalyzer'
        Version = '1.21.0'
    }
)

if ($InstallPreReqs)
{
    $repository = Get-PSRepository -Name 'PsGallery'
    if ($repository.InstallationPolicy -ne 'Trusted')
    {
        Set-PSRepository PSGallery -InstallationPolicy 'Trusted'
    }

    foreach ($module in $requiredModules)
    {
        $foundModule = Get-Module -Name $module.Name -ListAvailable
        if (-not $foundModule -or $foundModule.Version.ToString() -ne $module.Version)
        {
            Install-Module -Name $module.Name -RequiredVersion $module.Version -Force -AllowClobber
        }
    }
}

Import-Module -Name $requiredModules.Name
$rootPath = ((Get-Item -Path $PSScriptRoot).Parent.Parent).FullName

$pesterArgs = [PesterConfiguration]::Default
$pesterArgs.Output.Verbosity = 'Detailed'

switch ($Type)
{
    'Meta'
    {
        $testPath = Join-Path -Path $rootPath -ChildPath 'src/powershell/Tests/Meta'
    }

    'Unit'
    {
        $powerShellPath = Join-Path -Path $rootPath -ChildPath 'src/powershell'
        $testPath = Join-Path -Path $rootPath -ChildPath 'src/powershell/Tests/Unit'
        $pesterArgs.CodeCoverage.Enabled = $true
        $pesterArgs.CodeCoverage.Path = "$powerShellPath/*.ps*1"
        $pesterArgs.CodeCoverage.OutputFormat = 'JaCoCo'
        $pesterArgs.CodeCoverage.OutputPath = "$rootPath/coverage.xml"
    }
}

$pesterArgs.Run.Path = $testPath

Invoke-Pester -Configuration $pesterArgs
