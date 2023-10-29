# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Compiles CSV contents into a PowerShell function.
    
    .EXAMPLE
    ./Build-OpenData Services
    
    Generates a private Get-FinOpsServicesData PowerShell function from the contents of open-data/Services.csv.
    
    .PARAMETER Name
    Name of the CSV file to convert into a function. Default = *.
    
    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-build-opendata
#>
Param(
    [Parameter(Position = 0)]
    [string]
    $Name = "*"
)

# Some columns may have numbers and strings. Use the following list to force them to be handled as string.
$stringColumnNames = @('UnitOfMeasure')

function Write-Command($Command, $File) {
    $columns = (Get-Content $File -TotalCount 1).Split(",")
    $data = Import-Csv $File

    Write-Output "# Copyright (c) Microsoft Corporation."
    Write-Output "# Licensed under the MIT License."
    Write-Output ""
    Write-Output "function $Command {"
    Write-Output "    return [PSCustomObject]@("

    $first = $true
    $data | ForEach-Object {
        $row = $_
        $props = $columns | ForEach-Object {
            $column = $_
            $value = $row.$column
            if ($value -eq '') { $value = $null }
            $quote = if ($value -match '^[\d\.]+$' -and -not ($stringColumnNames -contains $column)) { "" } else { "'" }
            return "$column = $quote$value$quote;"
        }
        Write-Output "        $(if (-not $first) { ',' })[PSCustomObject]@{ $($props -join ' ') }"
        $first = $false
    }

    Write-Output "    )"
    Write-Output "}"
}

function Write-Test($DataType, $Command) {
    Write-Output "# Copyright (c) Microsoft Corporation."
    Write-Output "# Licensed under the MIT License."
    Write-Output ""
    Write-Output "Describe '$Command' {"
    Write-Output "    It 'Should return same rows as the CSV file' {"
    Write-Output "        # Arrange"
    Write-Output "        . `"`$PSScriptRoot/../../Private/$Command.ps1`""
    Write-Output "        `$csv = Import-Csv `"`$PSScriptRoot/../../../open-data/$DataType.csv`""
    Write-Output ""
    Write-Output "        # Act"
    Write-Output "        `$cmd = $Command"
    Write-Output ""
    Write-Output "        # Assert"
    Write-Output "        `$cmd.Count | Should -Be `$csv.Count"
    Write-Output "    }"
    Write-Output "}"
}

$outDir = "$PSScriptRoot/../powershell"
$srcDir = "$PSScriptRoot/../open-data"

# Loop thru all datasets
Get-ChildItem "$srcDir/*.csv" `
| Where-Object { $_.Name -like "$Name.csv" }
| ForEach-Object {
    $file = $_
    $dataType = $file.BaseName
    $command = "Get-OpenData$($dataType)"
    
    Write-Verbose "Generating $command from $dataType.csv..."
    Write-Command -Command $command -File $file  | Out-File "$outDir/Private/$command.ps1"          -Append:$false
    Write-Test -DataType $dataType -Command $command | Out-File "$outDir/Tests/Unit/$command.Tests.ps1" -Append:$false
}
