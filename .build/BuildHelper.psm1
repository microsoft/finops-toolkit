$functionPath = Join-Path -Path $PSScriptRoot -ChildPath 'BuildHelper/*.ps1'
$functionPath
$functions = Get-ChildItem -Path $functionPath -Filter '*.ps1'
foreach ($function in $functions)
{
    . $function.FullName
}