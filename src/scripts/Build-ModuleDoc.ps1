# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Builds a README file in markdown for a specified module. Includes sytnax, description, required modules, parameters and examples.

    .PARAMETER Path
    Path to a .psm1 module file.

    .PARAMETER Name
    Name of a PowerShell module. (Must be discoverable by Get-Module -ListAvailable)

    .PARAMETER OutputPath
    Path to folder for resulting .md file. Defaults to $pwd.

    .PARAMETER OutputFileName
    Name for the resulting .md file. Defaults to README.md

    .EXAMPLE
    Build-ModuleDoc -Name Az

    This will create a README.md for the Az module in the current working directory.

    .EXAMPLE
    Build-ModuleDoc -Path 'C:\Program Files\WindowsPowerShell\Modules\Foo\Foo.psm1'

    This will create a README.md for the Foo.psm1 in the current working directory.

    .EXAMPLE
    Build-ModuleDoc -Name Foo -OutputPath 'C:\temp' -OutputFileName Bar.md
    
    This will create a Bar.md for the module Foo in the C:\temp directory.
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true, ParameterSetName = 'ByPath')]
    [string]
    [ValidateScript({Test-Path -Path $_})]
    [ValidateScript({[System.IO.Path]::GetExtension($_) -eq '.psm1'})]
    $Path,

    [Parameter( Mandatory = $true, ParameterSetName = 'ByName')]
    [string]
    $Name,

    [Parameter(ParameterSetName = 'ByName')]
    [Parameter(ParameterSetName = 'ByPath')]
    [ValidateScript({Test-Path -Path $_ -IsValid})]
    [string]
    $OutputPath = $pwd,

    [Parameter(ParameterSetName = 'ByName')]
    [Parameter(ParameterSetName = 'ByPath')]
    [ValidateScript({[System.IO.Path]::GetFileNameExtension($_) -eq '.md'})]
    [string]
    $OutputFileName = 'README.md'
)

<#
    .SYNOPSIS
    Parses Comment-based help for a function and returns pertinent information.

    .PARAMETER Function
    Name of the function to parse.

    .EXAMPLE
    Get-HelpContent -Function Get-Foo

    Returns an object representing the Get-Foo help content.
#>
function Get-HelpContent
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Function
    )

    $help = Get-Help -Name $Function -Full
    $excludeCommonParameters = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
    $examples = @()
    $parameters = @()
    foreach ($parameter in $help.parameters.parameter.Where({$excludeCommonParameters -notcontains $_.Name}))
    {
        $parameters += @{
            Name         = $parameter.name
            Description  = $parameter.description.text | Select-Object -First 1
            DefaultValue = $parameter.defaultValue
            Required     = $parameter.required
            Type         = $parameter.parameterValue
        }
    }

    foreach($example in $help.examples.example)
    {
        $examples += @{
            Id     = $example.title -replace '\D'
            Remark = $example.remarks.text | Select-Object -First 1
            Code   = $example.code
        }
    }

    return @{
        Description = $help.Description
        Syntax      = ($help.syntax | Out-String) -replace '^[\r\n]+|\.|[\r\n]+$'
        Synopsis    = $help.Synopsis
        Examples    = $examples
        Parameters  = $parameters
    }
}

switch ($PSCmdlet.ParameterSetName)
{
    'ByPath'
    {
        if (-not [System.IO.Path]::IsPathRooted($Path))
        {
            $Path = Resolve-Path -Path $Path
        }

        Import-Module -FullyQualifiedName $Path -WarningAction 'SilentlyContinue'
        $moduleName = [System.IO.Path]::GetFilenameWithoutExtension($Path)
        $modulePath = Split-Path -Path $Path -Parent
    }

    'ByName'
    {
        if (-not (Get-Module -Name $Name -ListAvailable))
        {
            throw ('Module {0} not found.' -f $Name)
        }

        Import-Module -Name $Name -WarningAction 'SilentlyContinue'
        $moduleName = $Name
        $modulePath = Split-Path -Path (Get-Module -Name $moduleName).Path -Parent
    }
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('# {0} PowerShell Module' -f $moduleName).AppendLine()

# Check for manifest, if it exists add Description and required modules
$manifestPath = Get-ChildItem -Path (Split-Path -Path $modulePath -Parent) -Filter '*.psd1'
if ($manifestPath)
{
    $manifest = Import-PowerShellDataFile -Path $manifestPath.FullName
    [void]$sb.AppendLine($manifest.Description).Appendline()

    if ($manifest.RequiredModules)
    {
        [void]$sb.AppendLine('## Required Modules').AppendLine()
        [void]$sb.AppendLine('Name | Version')
        [void]$sb.AppendLine('|:---:|:---:|')
    
        foreach ($requiredModule in $manifest.RequiredModules)
        {
            [void]$sb.AppendLine("$($requiredModule.ModuleName) | $($requiredModule.ModuleVersion)")
        }

        [void]$sb.AppendLine()
    }        
}

# Parse functions
[void]$sb.AppendLine('## Functions').AppendLine()
$functions = Get-Command -Module $moduleName -CommandType 'Function'
foreach ($function in $functions)
{
    $functionHelp = Get-HelpContent -Function $function.Name
    [void]$sb.AppendLine("### $($function.Name)").AppendLine()

    if (-not [String]::IsNullOrEmpty($functionHelp.syntax))
    {
        [void]$sb.AppendLine('#### Syntax').AppendLine()
        [void]$sb.AppendLine("``$($functionHelp.Syntax)``").AppendLine()
    }

    if ($functionHelp.Parameters.Count -gt 0)
    {
        [void]$sb.AppendLine('#### Parameters').AppendLine()
        [void]$sb.AppendLine('Name | Type | Description | Required? | Default Value')
        [void]$sb.AppendLine('|:---:|:---:|---|:---:|:---:|')
    }

    foreach ($parameter in $functionHelp.Parameters)
    {
        [void]$sb.AppendLine("$($parameter.Name) | $($parameter.Type) | $($parameter.Description) | $($parameter.Required) | $($parameter.DefaultValue)")
    }

    [void]$sb.AppendLine()

    foreach ($example in $functionHelp.Examples)
    {
        [void]$sb.AppendLine("#### Example $($example.Id)").AppendLine()
        [void]$sb.AppendLine("``$($example.Code)``").AppendLine()
        [void]$sb.Appendline($example.Remark).AppendLine()
    }
}

if (-not (Test-Path -Path $OutputPath))
{
    $null = New-Item -Path $OutputPath -ItemType 'Directory'
}

$outputFile = Join-Path -Path $OutputPath -ChildPath $OutputFileName
$sb.ToString() | Out-File -FilePath $outputFile
