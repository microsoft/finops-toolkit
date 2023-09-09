# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$functionPath = Join-Path -Path $PSScriptRoot -ChildPath 'BuildHelper/*.ps1'
$functions = Get-ChildItem -Path $functionPath -Filter '*.ps1'
foreach ($function in $functions)
{
    . $function.FullName
}