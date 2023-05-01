<#
    .SYNOPSIS
        Publishes a toolkit template or module to its destination repo.
    .DESCRIPTION
        Run this from the /src/scripts folder.
    .PARAMETER Template
        Name of the template or module to publish. Default = finops-hub.
    .PARAMETER Destination
        Path to the local folder where the target repo is cloned.
    .PARAMETER Commit
        Indicates whether the changes should be committed to the Git repo. Default = false.
    .PARAMETER Build
        Optional. Indicates whether the the Build-Toolkit command should be executed first. Default = false.
    .EXAMPLE
        ./Publish-Toolkit "finops-hub"

        Publishes the FinOps hub template to the Azure Quickstart Templates repo.
#>
Param(
    [Parameter(Position = 0)][string]$Template = "finops-hub",
    [Parameter(Position = 1)][string]$Destination,
    [switch]$Build,
    [switch]$Commit
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

# Build toolkit if requested
if ($Build) {
    ./Build-Toolkit
}

$srcDir = "../../release/$Template"

# Validate template folder
if (-not (Test-Path $srcDir)) {
    Write-Error "$Template template not found. Please confirm template name."
    return
}
@("main.bicep", "metadata.json", "README.md", "azuredeploy.parameters.json") `
| ForEach-Object {
    if (-not (Test-Path "$srcDir/$_")) {
        Write-Error "$_ required. Please add $_ to the template folder."
        return
    }
}

# Validate destination is Azure Quickstart Templates repo
if (-not $Destination) {
    Write-Error "Destination required. Please specify root path to Azure Quickstart Templates repo."
    return
}
if (-not (Test-Path "$Destination/quickstarts")) {
    Write-Error 'Destination must be the root of the Azure Quickstart Templates repo.'
    return
}

Write-Host "Publishing $Template template..."

# Switch to master branch in local fork
if ($Commit) {
    Push-Location
    Set-Location $Destination

    # Validate local repo is clean
    if (-not (git status | Select-String 'working tree clean')) {
        Write-Error 'Local AQT repo has uncommitted changes. Please commit or stash changes and try again.'
        Pop-Location
        return
    }

    # Switch to master branch
    if (-not (git rev-parse --abbrev-ref HEAD) -eq 'master') {
        Write-Host '    Switching to AQT master branch...'
        git checkout master --quiet
    }
    
    # Pull latest changes
    if (-not (git status | Select-String 'Your branch is behind')) {
        Write-Host '    Pulling latest changes...'
        git pull --rebase --quiet
    }

    # Create new branch if needed
    if (-not (git status | Select-String 'Your branch is up to date')) {
        $branch = "$Template_$(Get-Date -Format yyMMddHHmm)"
        Write-Host "    Creating new $branch..."
        git checkout -b $branch --quiet
        git branch --set-upstream-to=origin/master --quiet
        git pull --rebase --quiet
    }

    Pop-Location
}

# Copy files
Write-Host '    Copying release files...'
$destDir = "$Destination//quickstarts/microsoft.costmanagement/$Template"
Remove-Item $destDir -Recurse -Force
./New-Directory $destDir
Copy-Item "$srcDir/*" $destDir

# Commit changes
if ($Commit) {
    Push-Location
    Set-Location $Destination
    Write-Host '    Committing updates...'
    git add .
    $isNew = ((git status) | Select-String "new file: +quickstarts/microsoft.costmanagement/$Template/main.bicep").length -eq 1
    if ($isNew) {
        $commitMessage = "New Cost Management $Template template"
    } else {
        $commitMessage = "Cost Management $Template template update"
    }
    git commit --message $commitMessage --quiet
    $branch = git rev-parse --abbrev-ref HEAD
    git push origin $branch --quiet
    $fork = git remote get-url origin | Select-String "github.com/([^/]+/[^/\.]+)" | % { $_.Matches[0].Groups[1].Value.Replace('/', ':') }
    Write-Host "    Create PR @ https://github.com/Azure/azure-quickstart-templates/compare/master...$($fork + ':' + $branch)?expand=1"
    Pop-Location
}

Write-Host ''