# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Start-PesterTest
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Unit', 'Lint', 'Integration')]
        [string]
        $Type
    )

    $rootPath = ((Get-Item -Path $PSScriptRoot).Parent.Parent).FullName
    $pesterArgs = New-PesterConfiguration
    $pesterArgs.Output.Verbosity = 'Detailed'
    $pesterArgs.Run.Exit = $true

    switch ($Type)
    {
        'Integration'
        {
            $testPath = Join-Path -Path $rootPath -ChildPath 'src/powershell/Tests/Integration'
        }

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
