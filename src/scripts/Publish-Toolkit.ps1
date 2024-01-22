# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Publishes a toolkit template or module to its destination repo.

    .DESCRIPTION
    Run this from the /src/scripts folder.

    .PARAMETER Template
    Name of the template or module to publish. Default = * (all templates).

    .PARAMETER QuickstartRepo
    Optional. Name of the folder where the Azure Quickstart Templates repo is cloned. Default = azure-quickstart-templates.

    .PARAMETER RegistryRepo
    Optional. Name of the folder where the Bicep Registry repo is cloned. Default = bicep-registry-modules.

    .PARAMETER Build
    Optional. Indicates whether the the Build-Toolkit command should be executed first. Default = false.

    .PARAMETER Branch
    Optional. Indicates whether the changes should be committed to a new branch in the Git repo. Default = false.

    .EXAMPLE
    ./Publish-Toolkit "finops-hub"

    Publishes the FinOps hub template to the Azure Quickstart Templates repo.

    .EXAMPLE
    ./Publish-Toolkit "resourcegroup-scheduled-action" -Build

    Publishes the resource group scheduled action module to the Bicep Registry repo.
#>
Param(
    [Parameter(Position = 0)][string]$Template = "*",
    [string]$QuickstartRepo = "azure-quickstart-templates",
    [string]$RegistryRepo = "bicep-registry-modules",
    [string]$appInsightsRepo = "Application-Insights-Workbooks",
    [switch]$Build,
    [Alias("Commit")][switch]$Branch
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

# Repo config
$repoConfig = @{
    aqt         = @{
        mainBranch    = 'master'
        possibleNames = @($QuickstartRepo, 'azure-quickstart-templates', 'aqt')
        relativePath  = "quickstarts/microsoft.costmanagement"
        requiredFiles = @("main.bicep", "metadata.json", "README.md", "azuredeploy.parameters.json")
    }
    brm         = @{
        mainBranch    = 'main'
        possibleNames = @($RegistryRepo, 'bicep-registry-modules', 'brm', 'br')
        relativePath  = "modules/cost"
        requiredFiles = @("main.bicep", "main.json", "metadata.json", "README.md", "version.json")
    }
    appInsights = @{
        mainBranch    = 'master'
        possibleNames = @($appInsightsRepo, 'Application-Insights-Workbooks')
        relativePath  = "Workbooks/Azure Advisor/Cost Optimization"
        requiredFiles = @("CostOptimization.workbook", "Storage.workbook", "Networking.workbook", "Compute.workbook", "AHB.workbook", "Reservations.workbook")
    }
}

# Build toolkit if requested
if ($Build)
{
    ./Build-Toolkit $Template
}

$relDir = "../../release"

# Find the local repo folder
function Find-Repo($config, [string]$templateName)
{
    Write-Debug "Verifying repo..."
    return $config.possibleNames | ForEach-Object {
        $path = "../../../$_"
        if (Test-Path "$path/$($config.relativePath)")
        {
            Write-Debug "  Found @ $path"
            $config | Add-Member path "$path/$($config.relativePath)/$templateName" -Force
            return $config
        }
        Write-Debug "  Not @ $path"
    }
}

# Get version for branch name and commit message
$ver = & "$PSScriptRoot/Get-Version.ps1"

# Loop thru templates
Get-ChildItem "$relDir/$Template*" -Directory `
| ForEach-Object {
    $templateDir = $_
    $templateName = $templateDir.Name
    $repo = $null # Placeholder for later

    Write-Host "Publishing template $templateName..."

    # Confirm metadata.json exists
    if (-not (Test-Path "$templateDir/metadata.json"))
    {
        Write-Error "Template folder invalid. metadata.json required. Please ensure all required files are present. See src/<type>/README.md for details."
        return
    }

    # Find target repo
    $schema = (Get-Content "$templateDir/metadata.json" -Raw | ConvertFrom-Json).PSObject.Properties['$schema'].Value
    if ($schema.Contains('azure-quickstart-templates'))
    {
        $repo = Find-Repo $repoConfig.aqt $templateName
        if (-not $repo)
        {
            Write-Error "Azure Quickstart Templates repo not found. Please close the repo locally or specify the QuickstartRepo parameter."
            return
        }
    }
    elseif ($schema.Contains('bicep-registry-module'))
    {
        $repo = Find-Repo $repoConfig.brm $templateName
        if (-not $repo)
        {
            Write-Error "Bicep Registry repo not found. Please close the repo locally or specify the RegistryRepo parameter."
            return
        }
    }
    else
    {
        Write-Error "Template schema not recognized: $schema"
        return
    }
    Write-Host "  Repo = $($repo.path)"

    # Validate release requirements
    Write-Debug "Verifying required files..."
    $repo.requiredFiles | ForEach-Object {
        if (-not (Test-Path "$relDir/$templateName/$_"))
        {
            Write-Error "$_ required. Please add $_ to the template folder."
            return
        }
    }

    # Switch to main branch in local fork
    if ($Branch)
    {
        Push-Location
        if (-not (Test-Path ($repo.path)))
        {
            ./New-Directory $repo.path
        }
        Set-Location $repo.path

        # Validate local repo is clean
        if (-not (git status | Select-String 'working tree clean'))
        {
            Write-Error 'Local repo has uncommitted changes. Please commit or stash changes and try again.'
            Pop-Location
            return
        }

        # Switch to master branch
        if (-not (git rev-parse --abbrev-ref HEAD) -eq 'master')
        {
            Write-Host "  Switching to $($repo.mainBranch) branch..."
            git checkout $repo.mainBranch --quiet
        }

        # Pull latest changes
        if (-not (git status | Select-String 'Your branch is behind'))
        {
            Write-Host '  Pulling latest changes...'
            git pull --rebase --quiet
        }

        # Create new branch
        $branchName = "$($templateName)-$($ver)_$(Get-Date -Format yyMMdd)"
        Write-Host "  Creating new $branchName branch..."
        git checkout -b $branchName --quiet
        git branch --set-upstream-to="origin/$($repo.mainBranch)" --quiet
        git pull --rebase --quiet

        Pop-Location
    }

    # Copy files
    Write-Host '  Copying release files...'
    if (Test-Path $repo.path)
    {
        Remove-Item $repo.path -Recurse -Force
    }
    ./New-Directory $repo.path
    Get-ChildItem "$relDir/$templateName" -Exclude .buildignore | Copy-Item -Destination $repo.path -Recurse

    # Commit changes
    if ($Branch)
    {
        Push-Location
        Set-Location $repo.path
        Write-Host '  Committing updates...'
        git add .
        $isNew = ((git status) | Select-String "new file: +$($repo.relativePath)/$templateName/main.bicep").length -eq 1
        if ($isNew)
        {
            $commitMessage = "New FinOps toolkit template - $templateName"
        }
        else
        {
            $commitMessage = "FinOps toolkit $ver - $templateName update"
        }
        git commit --message $commitMessage --quiet
        $branchName = git rev-parse --abbrev-ref HEAD
        git push origin $branchName --quiet
        $fork = git remote get-url origin | Select-String "github.com/([^/]+/[^/\.]+)" | % { $_.Matches[0].Groups[1].Value.Replace('/', ':') }
        Write-Host "  Create PR @ https://github.com/Azure/$($repo.possibleNames[1])/compare/$($repo.mainBranch)...$($fork + ':' + $branchName)?expand=1"
        Pop-Location
    }

    Write-Host '  Done!'
    Write-Host ''
}
