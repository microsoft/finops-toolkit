# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Generates automated documentation for applicable tools.

    .PARAMETER Command
    Optional. PowerShell command to generate documentation for. Default = * (all).

    .EXAMPLE
    ./Build-Documentation

    ### Generate documentation
    Generates documentation for all applicable tools.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-build-documentation
#>
[CmdletBinding()]
Param(
    [string]
    $Command = '*'
)

$Debug = $DebugPreference -eq "Continue"

$srcDir = "$PSScriptRoot/../"
$docDir = "$PSScriptRoot/../../docs/"
$psDocs = "$docDir/_automation/powershell/"

# Generate PowerShell docs
Write-Host "Generating PowerShell documentation..."
Get-ChildItem -Path "$srcDir/powershell/Public/$Command*.ps1" `
| ForEach-Object {
    $file = $_
    $commandName = $_.BaseName
    $noun = $commandName.Split('-FinOps')[1]

    Write-Host "- $commandName"

    # TODO: Validate PowerShell commands have required help content
    # TODO: Validated the relatedLinks.navigationLink.uri is set and resolves correctly
    
    # Map commands to folders
    if ($noun.StartsWith('Cost'))
    {
        $navParent = 'Cost Management'
        $folder = 'cost'
        $tools = 'aoe="1" data="0" hubs="1" pbi="1"'
    }
    elseif ($noun.StartsWith('Hub'))
    {
        $navParent = 'FinOps hubs'
        $folder = 'hubs'
        $tools = 'aoe="1" data="0" hubs="1" pbi="1"'
    }
    elseif (@('PricingUnit', 'Region', 'ResourceType', 'Service') -contains $noun)
    {
        $navParent = 'Open data'
        $folder = 'data'
        $tools = 'aoe="0" data="1" hubs="1" pbi="1"'
    }
    else
    {
        $navParent = 'Toolkit'
        $folder = 'toolkit'
        $tools = 'aoe="1" hubs="1" wb="1" pbi="1"'
    }

    # Load the script inline to get help content (since they are functions in each file)
    # TODO: Would it be better to just load the latest module version and use that?
    $script:help = $null
    & {
        . $file
        $script:help = Get-Help $commandName -Full
    }

    # Collect file contents via string builder for perf
    $sb = [System.Text.StringBuilder]::new()
    function append([string] $Text, [switch] $NoNewLine)
    {
        if ($NoNewLine) { [void]$sb.Append($Text) } else { [void]$sb.AppendLine($Text) }
    }

    append '---'
    append "layout: default"
    append "grand_parent: PowerShell"
    append "parent: $navParent"
    append "title: $commandName"
    append "nav_order: 10" # All commands are 10 to save room for any higher priority content
    append "description: $($script:help.Synopsis)"
    append "permalink: /powershell/$folder/$commandName"
    append '---'
    append ''
    append "<span class=""fs-9 d-block mb-4"">$commandName</span>"
    append $script:help.Synopsis
    append '{: .fs-6 .fw-300 }'
    append ''
    append '[Syntax](#-syntax){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }'
    append '[Examples](#-examples){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }'
    append ''
    append '<details open markdown="1">'
    append '   <summary class="fs-2 text-uppercase">On this page</summary>'
    append ''
    append '- [🧮 Syntax](#-syntax)'
    append '- [📥 Parameters](#-parameters)'
    append '- [🌟 Examples](#-examples)'
    append '- [🧰 Related tools](#-related-tools)'
    append ''
    append '</details>'
    append ''
    append '---'
    append ''
    $commandDesc = ($script:help.Description.Text | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "<br><br>"
    if ($commandDesc)
    {
        append ([regex]::Replace($commandDesc, $commandName, "**$commandName**", 1))
        append ''
        append '<br>'
        append ''
    }
    append '## 🧮 Syntax'
    append ''
    append '```powershell'
    append "$($script:help.Syntax.SyntaxItem.Name) ``"
    $script:help.Syntax.SyntaxItem.Parameter `
    | ForEach-Object {
        $parameter = $_
        append '    ' -NoNewLine
        if ($parameter.Required -ne $true) { append '[' -NoNewLine }
        if ($parameter.Position -ne 'named') { append '[' -NoNewLine }
        append "‑$($parameter.Name)" -NoNewLine
        if ($parameter.Position -ne 'named') { append ']' -NoNewLine }
        if ($parameter.ParameterValue.Length -gt 0) { append " <$($parameter.ParameterValue)>" -NoNewLine }
        if ($parameter.Required -ne $true) { append ']' -NoNewLine }
        if ($Debug) { append " -- REQ: $($parameter.Required), POS: $($parameter.Position)" -NoNewLine }
        append ' `'
        # TODO: defaultValue?, globbing, pipelineInput
    }
    append '    [<CommonParameters>]'
    append '```'
    append ''
    append '<br>'
    append ''
    append '## 📥 Parameters'
    append ''
    append '| Name | Description |'
    append '| ---- | ----------- |'
    $script:help.Parameters.Parameter `
    | ForEach-Object {
        $parameter = $_
        $desc = ($parameter.Description.Text | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "<br><br>"
        append "| ``‑$($parameter.Name)`` | $desc |"
    }
    append ''
    if ($Debug) { append ($script:help.Parameters | ConvertTo-Json -Depth 20) }
    append '<br>'
    append ''
    append '## 🌟 Examples'
    append ''
    $script:help.Examples.Example `
    | ForEach-Object {
        $example = $_
        $desc = ($example.Remarks.Text | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join '<br><br>'
        if ($desc.StartsWith("### "))
        {
            $title = $desc.Substring(0, $desc.IndexOf("`n"))
            $desc = $desc.Substring($title.Length + 1)
        }
        else
        {
            $title = $example.Title.Replace('-', '').Trim(' ').Replace('EXAMPLE', '### Example')
        }
        append $title
        append ''
        append '```powershell'
        append $example.Code
        append '```'
        append ''
        append $desc
        append ''
    }
    append '<br>'
    append ''
    append '---'
    append ''
    append "## 🧰 Related tools"
    append ''
    append "{% include tools.md $tools %}"
    append ''
    append '<br>'
    if ($Debug) { append ($script:help | ConvertTo-Json -Depth 100) }

    $sb.Tostring() | Out-File "$psDocs/$folder/$commandName.md" -Force -Encoding 'UTF8'
    $sb.Clear() | Out-Null
}
