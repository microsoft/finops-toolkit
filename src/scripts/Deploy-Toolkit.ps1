# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Deploys a toolkit template or module for local testing purposes.

    .EXAMPLE
    Deploy-Toolkit "finops-hub"

    Deploys a new FinOps hub instance.

    .EXAMPLE
    Deploy-Toolkit -WhatIf

    Validates the deployment template or module without changing resources.

    .PARAMETER Template
    Name of the template or module to deploy. Default = finops-hub.

    .PARAMETER ResourceGroup
    Optional. Name of the resource group to deploy to. Will be created if it doesn't exist. Default = ftk-<username>-<computername>.

    .PARAMETER Location
    Optional. Azure location to execute the deployment from. Default = westus.

    .PARAMETER Parameters
    Optional. Parameters to pass thru to the deployment.

    .PARAMETER Build
    Optional. Indicates whether the the Build-Toolkit command should be executed first. Default = false.

    .PARAMETER Test
    Optional. Indicates whether to run the template or module test instead of the template or module itself. Default = false.

    .PARAMETER Demo
    Optional. Indicates whether to deploy the template to the FinOps-Toolkit-Demo resource group. Default = false.

    .PARAMETER WhatIf
    Optional. Displays a message that describes the effect of the command, instead of executing the command.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-deploy-toolkit
#>
param(
    [Parameter(Position = 0)][string]$Template = "finops-hub",
    [string]$ResourceGroup,
    [string]$Location = "westus",
    [object]$Parameters,
    [switch]$Build,
    [switch]$Test,
    [switch]$Demo,
    [switch]$WhatIf
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

function iff([bool]$Condition, $IfTrue, $IfFalse)
{
    if ($Condition) { $IfTrue } else { $IfFalse }
}

# Build toolkit if requested
if ($Build)
{
    Write-Verbose "Building $Template template..."
    & "$PSScriptRoot/Build-Toolkit" -Template $Template
}

# Don't run test and demo deployment at the same time
if ($Test -and $Demo)
{
    Write-Error "Cannot specify both -Test and -Demo. Please try again."
    return
}

# Generates a unique name based on the signed in username and computer name for local testing
function Get-UniqueName()
{
    # NOTE: For some reason, using variables directly does not get the value until we write them
    $c = $env:ComputerName
    $u = $env:USERNAME
    $c | Out-Null
    $u | Out-Null
    return "ftk-$u-$c".ToLower()
}

# Local dev parameters
$defaultParameters = @{
    "finops-hub"      = @{ hubName = Get-UniqueName }
    "finops-hub/demo" = @{ hubName = "FinOpsHubDemo" }
    "finops-hub/test" = @{ uniqueName = Get-UniqueName }
}

# Reset global debug variable
$global:ftkDeployment = $null

# If deploying a workbook, switch to the release folder name
if (Test-Path "$PSScriptRoot/../workbooks/$Template")
{
    $Template = "$Template-workbook"
}

# Find bicep file
# NOTE: Include templates after release to account for test templates, which are not included in release builds
@("$PSScriptRoot/../../release") `
| ForEach-Object { Get-Item (Join-Path $_ $Template (iff $Test test/main.test.bicep main.bicep)) -ErrorAction SilentlyContinue } `
| ForEach-Object {
    $templateFile = $_
    $templateName = iff $Test ($templateFile.Directory.Parent.Name + "/test") $templateFile.Directory.Name
    $parentFolder = iff $Test $templateFile.Directory.Parent.Parent.Name $templateFile.Directory.Parent.Name
    $targetScope = (Get-Content $templateFile | Select-String "targetScope = '([^']+)'").Matches[0].Captures[0].Groups[1].Value

    # Fall back to default parameters if none were provided
    $Parameters = iff ($null -eq $Parameters) $defaultParameters["$templateName$(iff $Demo '/demo' '')"] $Parameters
    $Parameters = iff ($null -eq $Parameters) @{} $Parameters

    Write-Host "Deploying $templateName (from $parentFolder)..."
    switch ($targetScope)
    {
        "resourceGroup"
        {
            Write-Verbose 'Starting resource group deployment...'

            # Set default RG name
            if ($Demo)
            {
                # Use "FinOps-Toolkit-Demo" for the demo
                $ResourceGroup = "FinOps-Toolkit-Demo"
            }
            elseif ([string]::IsNullOrEmpty($ResourceGroup))
            {
                # Use "ftk-<username>-<computername>" for local testing
                $ResourceGroup = Get-UniqueName
            }

            Write-Host "  → [rg] $ResourceGroup..."
            $Parameters.Keys | ForEach-Object { Write-Host "         $($_) = $($Parameters[$_])" }

            if ($Debug)
            {
                Write-Host "         $templateFile"
            }
            else
            {
                # Create resource group if it doesn't exist
                Write-Verbose 'Checking resource group $ResourceGroup...'
                $rg = Get-AzResourceGroup $ResourceGroup -ErrorAction SilentlyContinue
                if ($null -eq $rg)
                {
                    Write-Verbose 'Creating resource group $ResourceGroup...'
                    New-AzResourceGroup `
                        -Name $ResourceGroup `
                        -Location $Location `
                    | Out-Null
                }

                # Start deployment
                Write-Verbose "Deploying $templateFile..."
                $global:ftkDeployment = New-AzResourceGroupDeployment `
                    -DeploymentName "ftk-$templateName".Replace('/', '-') `
                    -TemplateFile $templateFile `
                    -TemplateParameterObject $Parameters `
                    -ResourceGroupName $ResourceGroup `
                    -WhatIf:$WhatIf
                $global:ftkDeployment
            }

            return "https://portal.azure.com/#resource/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroup/deployments"

        }
        "subscription"
        {
            Write-Verbose 'Starting subscription deployment...'

            Write-Host "  → [sub] $((Get-AzContext).Subscription.Name)..."
            $Parameters.Keys | ForEach-Object { Write-Host "          $($_) = $($Parameters[$_])" }

            if ($Debug)
            {
                Write-Host "          $templateFile"
            }
            else
            {
                Write-Verbose "Deploying $templateFile..."
                $global:ftkDeployment = New-AzSubscriptionDeployment `
                    -DeploymentName "ftk-$templateName".Replace('/', '-') `
                    -TemplateFile $templateFile `
                    -TemplateParameterObject $Parameters `
                    -Location $Location `
                    -WhatIf:$WhatIf
                $global:ftkDeployment
            }

            return "https://portal.azure.com/#resource/subscriptions/$((Get-AzContext).Subscription.Id)"

        }
        "managementGroup"
        {
            Write-Error "Management group deployments have not been implemented yet"
        }
        "tenant"
        {
            Write-Verbose 'Starting tenant deployment...'

            $azContext = (Get-AzContext).Tenant
            Write-Host "  → [tenant] $(iff ([string]::IsNullOrWhitespace($azContext.Name)) $azContext.Id $azContext.Name)..."
            $Parameters.Keys | ForEach-Object { Write-Host "             $($_) = $($Parameters[$_])" }

            if ($Debug)
            {
                Write-Host "             $templateFile"
            }
            else
            {
                Write-Verbose "Deploying $templateFile..."
                $global:ftkDeployment = New-AzTenantDeployment `
                    -DeploymentName "ftk-$templateName".Replace('/', '-') `
                    -TemplateFile $templateFile `
                    -TemplateParameterObject $Parameters `
                    -Location $Location `
                    -WhatIf:$WhatIf
                $global:ftkDeployment
            }

            return "https://portal.azure.com/$((Get-AzContext).Tenant.Id)"

        }
        default { Write-Error "Unsupported target scope: $targetScope"; return }
    }

    Write-Host ''
}
