#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Manage the local ftklocal settings.json (hub fidelity layer).

.DESCRIPTION
    settings.json mirrors the shape written by the deployed FinOps Hub to the
    Azure Storage `config` container (schema https://aka.ms/finops/hubs/settings-schema).
    It is data-like and gitignored so that scope / billing-account identifiers
    are never committed.  settings.example.json is the sanitized template.

    Subcommands (default: show):
      show    Print the resolved settings (from settings.json or built-in defaults).
      init    Copy settings.example.json → settings.json if the file is absent.
      get     Return a single dot-path value, e.g. 'retention.raw.days'.

.EXAMPLE
    pwsh scripts/settings.ps1 init

.EXAMPLE
    pwsh scripts/settings.ps1 show

.EXAMPLE
    pwsh scripts/settings.ps1 get retention.raw.days
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('show', 'init', 'get')]
    [string] $Subcommand = 'show',

    [Parameter(Position = 1)]
    [string] $DotPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:FtkLocalHome  = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$script:SettingsPath  = Join-Path $script:FtkLocalHome 'settings.json'
$script:ExamplePath   = Join-Path $script:FtkLocalHome 'settings.example.json'

# Default settings (matches Copy-FileToAzureBlob.ps1 defaults, lines 66-86)
$script:Defaults = [ordered]@{
    '$schema'  = 'https://aka.ms/finops/hubs/settings-schema'
    type       = 'HubInstance'
    version    = '0.0.0'
    learnMore  = 'https://aka.ms/finops/hubs'
    scopes     = @()
    retention  = [ordered]@{
        msexports = @{ days   = 0  }
        ingestion = @{ months = 13 }
        raw       = @{ days   = 3650 }
        final     = @{ months = 13 }
    }
}

function Read-Settings {
    if (Test-Path $script:SettingsPath) {
        return Get-Content -Raw -Path $script:SettingsPath | ConvertFrom-Json
    }
    Write-Warning "settings.json not found — using built-in defaults.  Run 'pwsh scripts/settings.ps1 init' to create it."
    return $script:Defaults | ConvertTo-Json -Depth 10 | ConvertFrom-Json
}

switch ($Subcommand) {
    'init' {
        if (Test-Path $script:SettingsPath) {
            Write-Host "settings.json already exists at: $script:SettingsPath"
            Write-Host "Edit it to add your billing-account scopes and adjust retention values."
        }
        else {
            if (-not (Test-Path $script:ExamplePath)) {
                throw "settings.example.json not found at: $script:ExamplePath"
            }
            Copy-Item -Path $script:ExamplePath -Destination $script:SettingsPath
            Write-Host "Created settings.json from settings.example.json."
            Write-Host "Edit $script:SettingsPath to add real billing-account scopes if needed."
            Write-Host "Note: settings.json is gitignored — it will not be committed."
        }
    }

    'show' {
        $s = Read-Settings
        $s | ConvertTo-Json -Depth 10
    }

    'get' {
        if (-not $DotPath) { throw "Usage: settings.ps1 get <dot.path>  e.g. 'retention.raw.days'" }
        $s = Read-Settings
        $parts = $DotPath -split '\.'
        $value = $s
        foreach ($part in $parts) {
            if ($null -eq $value) { throw "Path '$DotPath' not found in settings (null at '$part')" }
            $value = $value.$part
        }
        Write-Output $value
    }
}
