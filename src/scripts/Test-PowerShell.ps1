# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Runs Pester tests.

    .DESCRIPTION
    The Test-PowerShell command runs Pester tests for the FinOps toolkit. By default, only unit tests are run. If only one test type is specified, only that test type will be run. If multiple are specified, each of them will be run. Other options will apply to all test types that are selected. Select -AllTests to run all test types.

    To investigate the previous test run, use $global:ftk_TestPowerShell_Results.

    To view a summary of only the failed tests, use $global:ftk_TestPowerShell_Summary.

    To view the configuration used to re-run previously failed tests, use $global:ftk_TestPowerShell_FailedTests.

    .PARAMETER Cost
    Optional. Indicates whether to run Cost Management tests.

    .PARAMETER Data
    Optional. Indicates whether to run open data tests.

    .PARAMETER Exports
    Optional. Indicates whether to run Cost Management export tests.

    .PARAMETER FOCUS
    Optional. Indicates whether to run FOCUS tests.

    .PARAMETER Hubs
    Optional. Indicates whether to run FinOps hubs tests.

    .PARAMETER Toolkit
    Optional. Indicates whether to run FinOps toolkit tests.

    .PARAMETER Private
    Optional. Indicates whether to run private tests. Default = false.

    .PARAMETER Integration
    Optional. Indicates whether to run integration tests, which take more time than unit tests by testing external dependencies. Default = false.

    .PARAMETER Lint
    Optional. Indicates whether to run lint tests, which validate local files are meeting dev standards. Default = false.

    .PARAMETER Unit
    Optional. Indicates whether to run unit tests. Default = true.

    .PARAMETER AllTests
    Optional. Indicates whether to run all lint, unit, and integration tests. If set, this overrides Lint, Unit, and Integration options. Default = false.

    .PARAMETER Markdown
    Optional. Indicates whether to run markdown broken link tests. Default = false.

    .PARAMETER RunFailed
    Optional. Indicates whether to re-run previously failed tests. This can only be run after a run fails. Only the failed tests will be re-run. If there a no previous run details, nothing will run. Default = false.
#>
[CmdletBinding()]
param (
    [switch]
    $Cost,

    [switch]
    $Data,

    [switch]
    $Exports,

    [switch]
    $FOCUS,

    [switch]
    $Hubs,

    [switch]
    $Toolkit,

    [switch]
    $Private,

    [switch]
    $Integration,

    [switch]
    $Lint,

    [switch]
    $Unit,

    [switch]
    $AllTests,

    [switch]
    $Markdown,

    [switch]
    $RunFailed
)

# Select tests to run
if ($RunFailed)
{
    if ($null -eq $global:ftk_TestPowerShell_FailedTests)
    {
        Write-Host 'No failed tests to re-run'
        return
    }
    else
    {
        Write-Host "Re-running $($global:ftk_TestPowerShell_FailedTests.Filter.FullName.Value.Count) failed test(s)..."
        $config = $global:ftk_TestPowerShell_FailedTests
    }
}
else
{
    # Handle special case for Markdown tests - only run broken links test
    if ($Markdown -and -not ($Cost -or $Data -or $Exports -or $FOCUS -or $Hubs -or $Toolkit -or $Private -or $AllTests -or $Lint -or $Unit -or $Integration))
    {
        Write-Host ''
        Write-Host "Finding broken links test..." -NoNewline
        
        $testsToRun = @("$PSScriptRoot/../powershell/Tests/Lint/BrokenLinks.Tests.ps1")
        Write-Host "1 found"
        Write-Host ''
        
        if (-not (Test-Path $testsToRun[0]))
        {
            Write-Host "Broken links test not found at $($testsToRun[0])" -ForegroundColor Red
            return
        }
        
        $config = New-PesterConfiguration
        $config.Run.Path = $testsToRun
    }
    else
    {
        $typesToRun = @(
            if ($AllTests -or $Lint) { 'Lint' }
            if ($AllTests -or $Integration) { 'Integration' }
            if ($AllTests -or $Unit -or (-not $Lint -and -not $Integration -and -not $Markdown)) { 'Unit' }
        )
        if ($typesToRun.Count -eq 3) { $typesToRun = '*' }

        $testsToRun = @()
        if ($Cost) { $testsToRun += '*-FinOpsCost*', 'Cost*' }
        if ($Data) { $testsToRun += '*-OpenData*', '*-FinOpsPricingUnit*', '*-FinOpsRegion*', '*-FinOpsResourceType*', '*-FinOpsService*' }
        if ($Exports) { $testsToRun += '*-FinOpsCostExport*', 'CostExports.Tests.ps1' }
        if ($FOCUS) { $testsToRun += '*-FinOpsSchema*', 'FOCUS.Tests.ps1' }
        if ($Hubs) { $testsToRun += '*-FinOpsHub*', '*-Hub*', 'Hubs.Tests.ps1' }
        if ($Toolkit) { $testsToRun += 'Toolkit.Tests.ps1', '*-FinOpsToolkit*' }
        if ($Markdown) { $testsToRun += 'BrokenLinks.Tests.ps1' }
        if ($Private) { $testsToRun += (Get-ChildItem -Path "$PSScriptRoot/../powershell/Tests/$testType/Unit" -Exclude *-FinOps*, *-Hub*, *-OpenData* -Name *.Tests.ps1) }
        if (-not $testsToRun) { $testsToRun = "*" }

        Write-Host ''
        Write-Host ("Finding <$($typesToRun -join '|')>/<$($testsToRun -join '|')> tests..." -replace '<\*>/', '' -replace '<([^\|>]+)>', '$1' -replace '\*\-?', '' -replace '/ tests', ' tests') -NoNewline

        $testsToRun = $typesToRun `
        | ForEach-Object {
            $testType = $_
            $testsToRun | ForEach-Object {
                $path = "$PSScriptRoot/../powershell/Tests/$testType/$_"
                if ((Get-ChildItem $path -ErrorAction SilentlyContinue).Count -gt 0)
                {
                    return $path
                }
            }
        }

        Write-Host "$($testsToRun.Count) found"
        Write-Host ''
        if (-not $testsToRun)
        {
            return
        }

        $config = New-PesterConfiguration
        $config.Run.Path = $testsToRun | Select-Object -Unique
    }
}

Write-Host '--------------------------------------------------'
Write-Host ''
#$relativePath = ($_ -replace '\\', '/' -split '/')[-2..-1] -join '/' -replace '.Tests.ps1', ''
#if ((Get-ChildItem $_).Count -eq 0)
#{
#    Write-Host "No tests found: $relativePath"
#}
#else
#{
#    Write-Host "Running $relativePath tests..."
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$results = $global:ftk_TestPowerShell_Results = Invoke-Pester -Configuration $config
#}
#
# DEBUG: Write output to debug -- $results.FailedBlocks.Blocks.Blocks.Tests | Select-Object -Property * -ExcludeProperty Block, Root, Parent, ScriptBlock, *Duration | ConvertTo-Json -Depth 4 | Out-File "results.json"

function sum($property)
{
    $results | ForEach-Object { $_.$property } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
}

$script:testSummary = @()
function summarize($info)
{
    $info | ForEach-Object {
        if ($_.Parent.Name -ne 'Root')
        {
            $parent = $_.Block ?? $_.Parent
            $level = summarize $parent
        }
        else
        {
            $level = 0
        }

        $script:testSummary += [PSCustomObject]@{
            Id    = $_.ExpandedPath
            Name  = $_.ExpandedName
            Type  = $_.ItemType
            File  = $_.BlockContainer.Item.FullName
            Level = ++$level
            Error = $_.ErrorRecord.Exception | Where-Object { -not [string]::IsNullOrEmpty($_.Message) }
        }
    }

    return $level
}

if ($null -eq $results)
{
    Write-Host 'No tests found'
    return
}

Write-Host ''
Write-Host '=================================================='
Write-Host ''
Write-Host $results.Result.ToUpper() -ForegroundColor (@{ Passed = 'Green'; Failed = 'Red' }.($results.Result) ?? 'Yellow')
Write-Host ''

# Summarize skipped, pending, and not run tests
if ($results.SkippedCount -gt 0 -or $results.PendingCount -gt 0 -or $results.NotRunCount -gt 0)
{
    Write-Host "$(sum SkippedCount) skipped, $(sum PendingCount) pending, and $(sum NotRunCount) not run" -ForegroundColor DarkGray
}

if ($results.PassedCount -gt 0)
{
    Write-Host "$(sum PassedCount) of $(sum TotalCount) tests passed" -ForegroundColor Green
}

# Summarize failed tests
if ($results.FailedCount -gt 0 -or $results.FailedContainerCount -gt 0 -or $results.Failed)
{
    Write-Host "$(sum FailedCount) failed tests and $(sum FailedContainerCount) failed containers" -ForegroundColor Red

    # Generate test summary
    $null = summarize $results.Failed
    $global:ftk_TestPowerShell_Summary = $script:testSummary = $script:testSummary `
    | Select-Object -Property * -Unique `
    | Sort-Object -Property Path
    $script:testSummary `
    | ForEach-Object {
        # Determine how much spacing to give for nesting
        $spaces = $('  ' * $_.Level)

        if ($_.Error.Count -gt 0)
        {
            $x = '⚠️ '
            $color = 'Red'
        }
        else
        {
            $x = '   '
            $color = 'DarkGray'
        }

        if ($_.Level -eq 1) { Write-Host '' }
        Write-Host "$spaces$x$($_.Name)" -ForegroundColor $color
        $_.Error | ForEach-Object {
            Write-Host "$spaces   └╴" -ForegroundColor DarkGray -NoNewline
            Write-Host "$($_.Message)" -ForegroundColor Yellow
            if ($_.StackTrace)
            {
                $_.StackTrace -replace '   at', '     ├╴at' -replace '├([^├]+)$', '└$1' -split '\r\n' `
                | ForEach-Object {
                    $segments = $_ -split '╴'
                    Write-Host "$spaces$($segments[0])╴" -ForegroundColor DarkGray -NoNewline
                    Write-Host "$($segments[1])" -ForegroundColor Yellow
                }
            }
        }
    }

    # Save failed tests
    $global:ftk_TestPowerShell_FailedTests = New-PesterConfiguration
    $global:ftk_TestPowerShell_FailedTests.Run.Path = $script:testSummary.File | Where-Object { $_ } | Select-Object -Unique
    $global:ftk_TestPowerShell_FailedTests.Filter.FullName = $script:testSummary | Where-Object { $_.Type -eq 'Test' } | ForEach-Object { "*$($_.Id -replace '([\\:\[\]])', '?')" }
    if ($null -ne $global:ftk_TestPowerShell_FailedTests)
    {
        Write-Host ''
        Write-Host "To re-run the $($global:ftk_TestPowerShell_FailedTests.Filter.FullName.Value.Count) failed test(s), use: " -NoNewline -ForegroundColor White
        Write-Host "& '$("$PSScriptRoot/Test-PowerShell.ps1" | Resolve-Path -Relative)' -RunFailed" -ForegroundColor Cyan
    }
}
else
{
    # Reset failed tests array
    $global:ftk_TestPowerShell_FailedTests = $null
}

Write-Host ''
Write-Host 'For details, see $global:ftk_TestPowerShell_Results' -ForegroundColor DarkGray
Write-Host ''
Write-Host '--------------------------------------------------'
Write-Host ''
