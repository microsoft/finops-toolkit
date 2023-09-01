[CmdletBinding()]
param
(
    [Parameter()]
    [string]
    $Version,

    [Parameter()]
    [ValidateSet('alpha', 'preview')]
    [string]
    $PrereleaseTag
)

task PreRequisites {
    $helperPath = Join-Path -Path $PSScriptRoot -ChildPath 'BuildHelper.psm1'
    Import-Module -FullyQualifiedName $helperPath
}

task Build.Module PreRequisites, {
    if ([string]::IsNullOrEmpty($Version))
    {
        throw 'Missing required parameter "Version".'
    }

    $buildParameters = @{
        Version = $Version
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
}

task Test.Unit PreRequisites, {
    Start-PesterTest -Type 'Unit'
}

task Test.Meta PreRequisites, {
    Start-PesterTest -Type 'Meta'
}

task Test.All Test.Meta, Test.Unit, {}
