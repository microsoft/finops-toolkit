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

    .PARAMETER ValidationLevel
    Optional. Validation level (Strict or Lenient). Default = Strict.
    - Strict: All validation rules are enforced (default)
    - Lenient: Skip certain validation rules that might fail for experimental features
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
    [switch] $SkipAzValidate,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Strict', 'Lenient')]
    [string] $ValidationLevel = 'Strict'
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

# Define rules to skip in lenient mode
$lenientSkipRules = @(
    'Azure.Template.UseParameters',  # Allow hardcoded values for experimental features
    'Azure.Template.DefineParameters', # Allow missing parameters for prototypes
    'Azure.Template.DebugDeployment', # Allow debug settings in experimental templates
    'Azure.ARM.MaxParameterFile',    # Allow larger parameter files for complex scenarios
    'Azure.Template.LocationType'    # Allow flexible location handling
)

# Validate with PSRule.Rules.Azure
if (-not $SkipPSRule) {
    Write-Host "Running PSRule.Rules.Azure validation (Mode: $ValidationLevel)..." -ForegroundColor Cyan

    Ensure-ModuleInstalled "PSRule.Rules.Azure"

    foreach ($template in $templates) {
        Write-Host "Validating $($template.FullName)..." -ForegroundColor Green
        
        $results = $template.FullName | Invoke-PSRule -Module PSRule.Rules.Azure -WarningAction SilentlyContinue
        
        # Check for failures
        $failures = $results | Where-Object { $_.Outcome -eq 'Fail' }
        
        # In lenient mode, filter out rules that should be skipped
        if ($ValidationLevel -eq 'Lenient' -and $failures) {
            $originalFailureCount = $failures.Count
            $failures = $failures | Where-Object { $_.RuleName -notin $lenientSkipRules }
            
            if ($originalFailureCount -gt $failures.Count) {
                $skippedCount = $originalFailureCount - $failures.Count
                Write-Host "Skipped $skippedCount validation rule(s) in lenient mode" -ForegroundColor Yellow
            }
        }
        
        if ($failures) {
            $hasErrors = $true
            Write-Host "PSRule validation failed for $($template.Name):" -ForegroundColor Red
            $failures | Format-Table -Property RuleName, TargetName, Message -AutoSize
        }
    }
}

# Define ARM-TTK tests to skip in lenient mode
$lenientSkipArmTtkTests = @(
    'Parameters Should Be Derived From DeploymentTemplate',
    'Parameters Must Be Referenced',
    'Secure String Parameters Cannot Have Default',
    'Min And Max Value Are Numbers',
    'DeploymentTemplate Must Not Contain Hardcoded Uri'
)

# Validate with ARM-TTK
if (-not $SkipArmTtk) {
    Write-Host "Running ARM-TTK validation (Mode: $ValidationLevel)..." -ForegroundColor Cyan

    # Check if ARM-TTK is installed
    if (-not (Test-ModuleInstalled "arm-ttk")) {
        Write-Host "ARM-TTK not found. Installing..." -ForegroundColor Yellow
        
        # ARM-TTK version pinning - using stable release 0.26 (20250401)
        # Update this version when newer stable releases are available
        $armTtkVersion = "20250401"
        $armTtkPath = "$repoRoot/release/.tools/arm-ttk"
        
        if (-not (Test-Path $armTtkPath)) {
            New-Item -Path $armTtkPath -ItemType Directory -Force | Out-Null
            
            $armTtkZip = "$armTtkPath/arm-ttk-$armTtkVersion.zip"
            Write-Host "Downloading ARM-TTK version $armTtkVersion..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri "https://github.com/Azure/arm-ttk/archive/refs/tags/$armTtkVersion.zip" -OutFile $armTtkZip
            
            # Extract to a versioned subfolder
            $extractPath = "$armTtkPath/arm-ttk-$armTtkVersion"
            Expand-Archive -Path $armTtkZip -DestinationPath $extractPath -Force
            
            # Clean up the zip file
            Remove-Item -Path $armTtkZip -Force
        }
        
        Import-Module "$armTtkPath/arm-ttk-$armTtkVersion/arm-ttk-$armTtkVersion/arm-ttk/arm-ttk.psd1" -Force
    }

    foreach ($template in $templates) {
        Write-Host "Validating $($template.FullName) with ARM-TTK..." -ForegroundColor Green
        
        try {
            $testResults = Test-AzTemplate -TemplatePath $template.FullName
            
            # Check for failures
            $failures = $testResults | Where-Object { -not $_.Passed }
            
            # In lenient mode, filter out tests that should be skipped
            if ($ValidationLevel -eq 'Lenient' -and $failures) {
                $originalFailureCount = $failures.Count
                $failures = $failures | Where-Object { $_.Name -notin $lenientSkipArmTtkTests }
                
                if ($originalFailureCount -gt $failures.Count) {
                    $skippedCount = $originalFailureCount - $failures.Count
                    Write-Host "Skipped $skippedCount ARM-TTK test(s) in lenient mode" -ForegroundColor Yellow
                }
            }
            
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
    Write-Host "Running Azure CLI validation (Mode: $ValidationLevel)..." -ForegroundColor Cyan
    
    if ($ValidationLevel -eq 'Lenient') {
        Write-Host "Note: Azure CLI validation warnings will be ignored in lenient mode" -ForegroundColor Yellow
    }

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