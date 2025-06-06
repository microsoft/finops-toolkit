# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Validates ARM templates for deployment issues and best practices.

    .EXAMPLE
    Test-ArmTemplate

    Validates all ARM templates in the release directory.

    .EXAMPLE
    Test-ArmTemplate -TemplatePath "release/finops-hub/azuredeploy.json"

    Validates a specific ARM template.

    .PARAMETER TemplatePath
    Optional. Path to the ARM template to validate. If not specified, all templates in the release directory will be validated.

    .PARAMETER SkipPSRule
    Optional. Skip PSRule.Rules.Azure validation. Default = false.

    .PARAMETER SkipArmTtk
    Optional. Skip ARM-TTK validation. Default = false.

    .PARAMETER SkipAzValidate
    Optional. Skip Azure CLI validation. Default = false.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $TemplatePath,

    [Parameter(Mandatory = $false)]
    [switch] $SkipPSRule,

    [Parameter(Mandatory = $false)]
    [switch] $SkipArmTtk,

    [Parameter(Mandatory = $false)]
    [switch] $SkipAzValidate
)

# Get the root directory of the repo
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Function to check if a module is installed
function Test-ModuleInstalled($moduleName) {
    return (Get-Module -ListAvailable -Name $moduleName) -ne $null
}

# Function to ensure a module is installed
function Ensure-ModuleInstalled($moduleName) {
    if (-not (Test-ModuleInstalled $moduleName)) {
        Write-Host "Installing $moduleName module..." -ForegroundColor Yellow
        Install-Module -Name $moduleName -Force -Scope CurrentUser
    }
}

# Function to ensure Azure CLI is installed
function Ensure-AzureCliInstalled {
    try {
        $azVersion = az --version
        return $true
    }
    catch {
        Write-Host "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Red
        return $false
    }
}

# Get templates to validate
$templates = @()
if ($TemplatePath) {
    if (Test-Path $TemplatePath) {
        $templates = @(Get-Item $TemplatePath)
    }
    else {
        Write-Error "Template path not found: $TemplatePath"
        exit 1
    }
}
else {
    # Find all JSON templates (excluding UI definitions)
    $templates = @(Get-ChildItem -Path "$repoRoot/release" -Filter "*.json" -Recurse | Where-Object { $_.Name -notlike "*.ui.json" })
}

# Check if any templates were found
if ($templates.Count -eq 0) {
    Write-Host "No ARM templates found to validate. Run Build-Toolkit first to generate templates." -ForegroundColor Yellow
    exit 0
}

$hasErrors = $false

# Validate with PSRule.Rules.Azure
if (-not $SkipPSRule) {
    Write-Host "Running PSRule.Rules.Azure validation..." -ForegroundColor Cyan

    Ensure-ModuleInstalled "PSRule.Rules.Azure"

    foreach ($template in $templates) {
        Write-Host "Validating $($template.FullName)..." -ForegroundColor Green
        
        $results = $template.FullName | Invoke-PSRule -Module PSRule.Rules.Azure -WarningAction SilentlyContinue
        
        # Check for failures
        $failures = $results | Where-Object { $_.Outcome -eq 'Fail' }
        if ($failures) {
            $hasErrors = $true
            Write-Host "PSRule validation failed for $($template.Name):" -ForegroundColor Red
            $failures | Format-Table -Property RuleName, TargetName, Message -AutoSize
        }
    }
}

# Validate with ARM-TTK
if (-not $SkipArmTtk) {
    Write-Host "Running ARM-TTK validation..." -ForegroundColor Cyan

    # Check if ARM-TTK is installed
    if (-not (Test-ModuleInstalled "arm-ttk")) {
        Write-Host "ARM-TTK not found. Installing..." -ForegroundColor Yellow
        
        $armTtkPath = "$env:TEMP/arm-ttk"
        if (-not (Test-Path $armTtkPath)) {
            New-Item -Path $armTtkPath -ItemType Directory -Force | Out-Null
        }
        
        $armTtkZip = "$env:TEMP/arm-ttk.zip"
        Invoke-WebRequest -Uri "https://github.com/Azure/arm-ttk/archive/refs/heads/master.zip" -OutFile $armTtkZip
        Expand-Archive -Path $armTtkZip -DestinationPath $armTtkPath -Force
        
        Import-Module "$armTtkPath/arm-ttk-master/arm-ttk/arm-ttk.psd1" -Force
    }

    foreach ($template in $templates) {
        Write-Host "Validating $($template.FullName) with ARM-TTK..." -ForegroundColor Green
        
        try {
            $testResults = Test-AzTemplate -TemplatePath $template.FullName
            
            # Check for failures
            $failures = $testResults | Where-Object { -not $_.Passed }
            if ($failures) {
                $hasErrors = $true
                Write-Host "ARM-TTK validation failed for $($template.Name):" -ForegroundColor Red
                $failures | Format-Table -Property Name, Group, Errors -AutoSize
            }
        }
        catch {
            $hasErrors = $true
            Write-Host "Error running ARM-TTK on $($template.Name): $_" -ForegroundColor Red
        }
    }
}

# Validate with Azure CLI
if (-not $SkipAzValidate) {
    Write-Host "Running Azure CLI validation..." -ForegroundColor Cyan

    if (Ensure-AzureCliInstalled) {
        foreach ($template in $templates) {
            Write-Host "Validating $($template.FullName) with Azure CLI..." -ForegroundColor Green
            
            # Determine deployment scope based on template content
            $templateContent = Get-Content -Path $template.FullName -Raw | ConvertFrom-Json
            $deploymentScope = if ($templateContent.resources -and $templateContent.resources[0].type -eq "Microsoft.Resources/deployments") {
                "subscription"
            }
            else {
                "resourcegroup"
            }
            
            # Run appropriate az validate command based on scope
            try {
                if ($deploymentScope -eq "subscription") {
                    Write-Host "Running subscription-level validation" -ForegroundColor Gray
                    az deployment sub validate --location eastus --template-file $template.FullName --no-prompt
                }
                else {
                    Write-Host "Running resource-group level validation" -ForegroundColor Gray
                    az deployment group validate --resource-group "validation-rg" --template-file $template.FullName --no-prompt
                }
                
                if ($LASTEXITCODE -ne 0) {
                    $hasErrors = $true
                    Write-Host "Azure CLI validation failed for $($template.Name)" -ForegroundColor Red
                }
            }
            catch {
                $hasErrors = $true
                Write-Host "Exception during Azure CLI validation for $($template.Name): $_" -ForegroundColor Red
            }
        }
    }
}

# Report validation results
if ($hasErrors) {
    Write-Host "`nValidation failed! Please fix the issues before committing." -ForegroundColor Red
    exit 1
}
else {
    Write-Host "`nAll ARM templates validated successfully!" -ForegroundColor Green
}