# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Import the localized Data
$script:localizedData = Import-LocalizedData -FileName 'FinOpsToolkit.strings.psd1' -BaseDirectory (Join-Path -Path $PSScriptRoot -ChildPath 'en-US')

$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private/*.ps1'
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public/*.ps1'

$allFunctions = @()
$allFunctions += Get-ChildItem -Path $privatePath
$publicFunctions = Get-ChildItem -Path $publicPath
$allFunctions += $publicFunctions

foreach ($function in $allFunctions)
{
    . $function.FullName
}

$publicNames = @()
foreach ($function in $publicFunctions)
{
    $publicNames += [System.IO.Path]::GetFileNameWithoutExtension($function.Name)
}

Export-ModuleMember -Function $publicNames
