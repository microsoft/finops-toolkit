# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[CmdletBinding()]
param
(
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

task Build.PsModule PreRequisites, Clean, {
    Build-PsModule
}

task Publish.PsModule Build.PsModule, {
    if (-not $ApiKey)
    {
        throw 'Missing required parameter "ApiKey".'
    }

    try
    {
        Remove-Module -Name $moduleName -Force -ErrorAction 'SilentlyContinue'
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

task Test.PowerShell.Unit PreRequisites, {
    Start-PesterTest -Type 'Unit'
}

task Test.PowerShell.Lint PreRequisites, {
    Start-PesterTest -Type 'Lint'
}

task Test.PowerShell.All Test.PowerShell.Lint, Test.PowerShell.Unit, {}
