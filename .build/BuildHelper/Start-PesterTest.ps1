# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Start-PesterTest
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Unit', 'Lint')]
        [string]
        $Type
    )

    $rootPath = ((Get-Item -Path $PSScriptRoot).Parent.Parent).FullName
    $pesterArgs = [PesterConfiguration]::Default
    $pesterArgs.Output.Verbosity = 'Detailed'

    switch ($Type)
    {
        'Lint'
        {
            $testPath = Join-Path -Path $rootPath -ChildPath 'src/powershell/Tests/Lint'
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
}
