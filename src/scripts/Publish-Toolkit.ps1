# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Publishes a toolkit template, module, or documentation to its destination repo.

    .PARAMETER Template
    Optional. Name of the template or module to publish. Default = * (all templates).

    .PARAMETER QuickstartRepo
    Optional. Name of the folder where the Azure Quickstart Templates repo is cloned. Default = azure-quickstart-templates.

    .PARAMETER RegistryRepo
    Optional. Name of the folder where the Bicep Registry repo is cloned. Default = bicep-registry-modules.

    .PARAMETER AppInsightsRepo
    Optional. Name of the folder where the Application Insights Workbooks repo is cloned. Default = Application-Insights-Workbooks.

    .PARAMETER DocsRepo
    Optional. Name of the folder where the Partner Center documentation repo is cloned. Default = partner-center-pr.

    .PARAMETER Build
    Optional. Indicates whether the Build-Toolkit command should be executed first. Default = false.

    .PARAMETER Branch
    Optional. Indicates whether the changes should be committed to a new branch in the Git repo. Alias: Commit. Default = false.

    .EXAMPLE
    ./Publish-Toolkit "finops-hub"

    Publishes the FinOps hub template to the Azure Quickstart Templates repo.

    .EXAMPLE
    ./Publish-Toolkit "resourcegroup-scheduled-action" -Build

    Publishes the resource group scheduled action module to the Bicep Registry repo.

    .EXAMPLE
    ./Publish-Toolkit "docs"

    Publishes documentation to the Microsoft Learn repo.
#>
Param(
    [Parameter(Position = 0)]
    [ValidateSet("*", "docs", "finops-hub", "finops-workbooks", "governance-workbook", "optimization-workbook")]
    [string]$Template = "*",
    [string]$QuickstartRepo = "azure-quickstart-templates",
    [string]$RegistryRepo = "bicep-registry-modules",
    [string]$AppInsightsRepo = "Application-Insights-Workbooks",
    [string]$DocsRepo = "partner-center-pr",
    [switch]$Build,
    [Alias("Commit")][switch]$Branch
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

# Repo config
$repoConfig = @{
    aqt         = @{
        org           = 'Azure'
        mainBranch    = 'master'
        possibleNames = @($QuickstartRepo, 'azure-quickstart-templates', 'aqt')
        relativePath  = "quickstarts/microsoft.costmanagement"
        requiredFiles = @("main.bicep", "metadata.json", "README.md", "azuredeploy.parameters.json")
    }
    brm         = @{
        org           = 'Azure'
        mainBranch    = 'main'
        possibleNames = @($RegistryRepo, 'bicep-registry-modules', 'brm', 'br')
        relativePath  = "modules/cost"
        requiredFiles = @("main.bicep", "main.json", "metadata.json", "README.md", "version.json")
    }
    appInsights = @{
        org           = 'Azure'
        mainBranch    = 'master'
        possibleNames = @($AppInsightsRepo, 'Application-Insights-Workbooks')
        relativePath  = "Workbooks/Azure Advisor/Cost Optimization"
        requiredFiles = @("CostOptimization.workbook", "Storage.workbook", "Networking.workbook", "Compute.workbook", "AHB.workbook", "Reservations.workbook")
    }
    pc          = @{
        org           = 'MicrosoftDocs'
        mainBranch    = 'main'
        possibleNames = @($DocsRepo, 'partner-center-pr', 'pc')
        relativePath  = "finops/finops"
        requiredFiles = @()
    }
}

# Build toolkit if requested
if ($Build)
{
    ./Build-Toolkit $Template
}

$rootDir = "$PSScriptRoot/../.."
$relDir = "$rootDir/release"

# Find the local repo folder
function Find-Repo($config, [string]$templateName)
{
    Write-Debug "Verifying repo..."
    return $config.possibleNames | ForEach-Object {
        $repoRootDir = "$rootDir/../$_"
        if (Test-Path "$repoRootDir/$($config.relativePath)")
        {
            Write-Debug "  Found @ $repoRootDir"
            $config | Add-Member path "$repoRootDir/$($config.relativePath)/$templateName" -Force
            return $config
        }
        Write-Debug "  Not @ $repoRootDir"
    }
}

# Create a new branch in the repo
function New-RepoBranch($repo, [string]$branchPrefix)
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

    # Switch to main branch
    if ((git rev-parse --abbrev-ref HEAD) -ne $repo.mainBranch)
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
    $branchName = "$($branchPrefix)-$($ver)_$(Get-Date -Format yyMMdd)"
    Write-Host "  Creating new $branchName branch..."
    git checkout -b $branchName --quiet
    git branch --set-upstream-to="origin/$($repo.mainBranch)" --quiet
    git pull --rebase --quiet

    Pop-Location
}

# Copy files to the new repo
function Set-RepoContent($repo, [string]$branchPrefix, [string]$sourceDir)
{
    # Switch to main branch in local fork
    if ($Branch)
    {
        New-RepoBranch $repo $branchPrefix
    }

    # Copy files
    Write-Host '  Copying release files...'
    if (Test-Path $repo.path)
    {
        Remove-Item $repo.path -Recurse -Force
    }
    ./New-Directory $repo.path
    Get-ChildItem $sourceDir -Exclude .buildignore | Copy-Item -Destination $repo.path -Recurse

    # Commit changes
    if ($Branch)
    {
        Push-Location
        Set-Location $repo.path
        Write-Host '  Committing updates...'
        git add .
        $isNew = ((git status) | Select-String "new file: +$($repo.relativePath)/$templateName/main.bicep").length -eq 1
        if ($Template -eq "docs")
        {
            $commitMessage = "FinOps $ver documentation updates"
        }
        elseif ($isNew)
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
        Write-Host "  Create PR @ https://github.com/$($repo.org)/$($repo.possibleNames[1])/compare/$($repo.mainBranch)...$($fork + ':' + $branchName)?expand=1"
        Pop-Location
    }

    Write-Host '  Done!'
    Write-Host ''
}

# Get version for branch name and commit message
$ver = & "$PSScriptRoot/Get-Version.ps1"

if ($Template -eq "docs")
{
    $docsDir = "$rootDir/docs-mslearn"
    $templateName = "finops-docs"

    Write-Host "Publishing documentation updates..."

    # Find target repo
    $repo = Find-Repo $repoConfig.pc ""
    if (-not $repo)
    {
        Write-Error "Partner Center docs repo not found. Please clone the repo locally or specify the DocsRepo parameter to indicate the folder name to use."
        return
    }
    Write-Host "  Repo = $($repo.path)"

    Set-RepoContent $repo "finops" $docsDir
}
else
{
    # Loop thru templates
    Write-Verbose "Checking release directory: $relDir/$Template*"
    Get-ChildItem "$relDir/$Template*" -Directory `
    | ForEach-Object {
        $templateDir = $_
        $templateName = $templateDir.Name
        $repo = $null # Placeholder for later

        # Ignore AOE
        # TODO: Remove the optimization-engine exclusion once we determine how we are going to publish it to other repos
        if ($templateName -eq "optimization-engine")
        {
            Write-Verbose "Ignoring AOE"
            return
        }

        Write-Host "Publishing template $templateName..."
        Write-Verbose "Directory: $templateDir"

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
                Write-Error "Azure Quickstart Templates repo not found. Please clone the repo locally or specify the QuickstartRepo parameter to indicate the folder name to use."
                return
            }
        }
        elseif ($schema.Contains('bicep-registry-module'))
        {
            $repo = Find-Repo $repoConfig.brm $templateName
            if (-not $repo)
            {
                Write-Error "Bicep Registry repo not found. Please clone the repo locally or specify the RegistryRepo parameter to indicate the folder name to use."
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

        Set-RepoContent $repo $templateName "$relDir/$templateName"
    }
}
