# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.


[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateSet('PreRequisites', 'Build.Module', 'Publish.Module', 'Test.Unit', 'Test.Meta', 'Test.All')]
    [string[]]
    $Task,

    [Parameter()]
    [string]
    $Version,

    [Parameter()]
    [int]
    $BuildNumber,

    [Parameter()]
    [ValidateSet('alpha', 'preview')]
    [string]
    $PrereleaseTag,

    [Parameter()]
    [string]
    $ApiKey
)

if (-not (Get-Module -Name 'PsDepend' -ListAvailable))
{
    $repository = Get-PSRepository -Name 'PSGallery'
    if ($repository.InstallationPolicy -ne 'Trusted')
    {
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    }

    try
    {
        Install-Module -Name 'PsDepend' -Force -AllowClobber -ErrorAction 'Stop'
    }
    catch
    {
        throw $_
    }
}

$buildPath = Join-Path -Path $PSScriptRoot -ChildPath 'build.ps1'
$dependencyPath = Get-ChildItem -Path $PSScriptRoot -Filter '*.depends.psd1'
Invoke-PSDepend -Path $dependencyPath.FullName -Install -Import -Force

$buildPath
Invoke-Build -File $buildPath @PSBoundParameters
