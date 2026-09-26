# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private/*.ps1'
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public/*.ps1'
$publicFunctions = Get-ChildItem -Path $publicPath

foreach ($function in @(Get-ChildItem -Path $privatePath) + $publicFunctions) {
    . $function.FullName
}

Export-ModuleMember -Function $publicFunctions.BaseName
