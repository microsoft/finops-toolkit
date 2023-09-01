# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[CmdletBinding()]
param
(
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

$moduleName = 'FinOpsToolkit'
$root = (Get-Item -Path $PSScriptRoot).Parent.FullName
$releaseDirectory = Join-Path -Path $root -ChildPath 'release'
$modulePath = Join-Path -Path $releaseDirectory -ChildPath $moduleName

task Clean {
    Remove-Item -Path $releaseDirectory -Recurse -Force -ErrorAction 'SilentlyContinue'
}

task PreRequisites {
    $helperPath = Join-Path -Path $PSScriptRoot -ChildPath 'BuildHelper.psm1'
    Import-Module -FullyQualifiedName $helperPath
}

task Build.Module PreRequisites, Clean, {
    if ([string]::IsNullOrEmpty($Version))
    {
        throw 'Missing required parameter "Version".'
    }

    $buildParameters = @{
        Version = $Version
    }

    if ($BuildNumber)
    {
        $buildParameters.Add('BuildNumber', $BuildNumber)
    }

    if (-not [string]::IsNullOrEmpty($PrereleaseTag))
    {
        $buildParameters.Add('PrereleaseTag', $PrereleaseTag)
    }

    Build-FinOpsModule @buildParameters
}

task Publish.Module Build.Module, {
    if ([string]::IsNullOrEmpty($Version))
    {
        throw 'Missing required parameter "Version".'
    }

    if (-not $ApiKey)
    {
        throw 'Missing required parameter "ApiKey".'
    }

    try
    {
        Import-Module -Name $modulePath -ErrorAction 'Stop'
        $moduleInfo = Get-Module -Name $moduleName -ErrorAction 'Stop'
    }
    catch
    {
        throw $_
    }

    $parameters = @{}
    foreach ($key in @('Tags', 'IconUri', 'ProjectUri', 'LicenseUri', 'ReleaseNotes'))
    {
        if ($moduleInfo.$key)
        {
            $parameters.Add($key, $moduleInfo.$key)
        }
    }

    Publish-Module -Name $moduleName -Repository 'PSGallery' -NuGetApiKey $ApiKey -Force -AllowPrerelease @parameters
}

task Test.Unit PreRequisites, {
    Start-PesterTest -Type 'Unit'
}

task Test.Meta PreRequisites, {
    Start-PesterTest -Type 'Meta'
}

task Test.All Test.Meta, Test.Unit, {}
