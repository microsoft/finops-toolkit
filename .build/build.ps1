# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[CmdletBinding()]
param
(
    # Using a single parameter to pass all task parameters to each task and avoid re-defining every parameter multiple times
    [Parameter()]
    [hashtable]
    $TaskParams
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
    if (-not (Get-Module BuildHelper)) {
        Import-Module -FullyQualifiedName $helperPath
    }
}

task Build.PsModule PreRequisites, Clean, {
    Build-PsModule
}

task Publish.PsModule Build.PsModule, {
    if (-not $TaskParams.ApiKey) {
        throw 'Missing required parameter "ApiKey".'
    }

    try {
        Remove-Module -Name $moduleName -Force -ErrorAction 'SilentlyContinue'
        Import-Module -Name $modulePath -ErrorAction 'Stop'
        $moduleInfo = Get-Module -Name $moduleName -ErrorAction 'Stop'
    } catch {
        throw $_
    }

    $parameters = @{}
    foreach ($key in @('Tags', 'IconUri', 'ProjectUri', 'LicenseUri', 'ReleaseNotes')) {
        if ($moduleInfo.$key) {
            $parameters.Add($key, $moduleInfo.$key)
        }
    }

    Publish-Module -Path $modulePath -Repository 'PSGallery' -NuGetApiKey $TaskParams.ApiKey -Confirm:$false -Force @parameters
}

task Test.PowerShell.Unit PreRequisites, {
    Start-PesterTest -Type 'Unit'
}

task Test.PowerShell.Lint PreRequisites, {
    Start-PesterTest -Type 'Lint'
}

task Test.PowerShell.All Test.PowerShell.Lint, Test.PowerShell.Unit, {}

task Version PreRequisites, {
    return (& "$PSScriptRoot/../src/scripts/Update-Version" -Major:$TaskParams.Major -Minor:$TaskParams.Minor -Patch:$TaskParams.Patch -Prerelease:$TaskParams.Prerelease -Label $TaskParams.Label -Version $TaskParams.Version -Verbose:$VerbosePreference)
}
