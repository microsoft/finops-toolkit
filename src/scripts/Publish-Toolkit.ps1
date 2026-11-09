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

    .PARAMETER CorrelationId
    Optional. Azure Quickstart Templates only. Correlation ID (GUID) of a successful Azure deployment of the published main.bicep. Written to testResult in metadata.json. Requires -DeploymentName.

    .PARAMETER DeploymentName
    Optional. Azure Quickstart Templates only. Name of the successful Azure deployment of the published main.bicep. Written to testResult in metadata.json. Requires -CorrelationId.

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
    [Alias("Commit")][switch]$Branch,
    [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')][string]$CorrelationId,
    [string]$DeploymentName
)

# Use the debug flag from common parameters to determine whether to run in debug mode
$Debug = $DebugPreference -eq "Continue"

# Repo config
$repoConfig = @{
    aqt         = @{
        org           = 'Azure'
        isAqt         = $true
        mainBranch    = 'master'
        possibleNames = @($QuickstartRepo, 'azure-quickstart-templates', 'aqt')
        relativePath  = "quickstarts/microsoft.costmanagement"
        requiredFiles = @("main.bicep", "metadata.json", "README.md", "azuredeploy.parameters.json")
        # Toolkit-only files that AQT does not accept. AQT compiles main.bicep to azuredeploy.json itself (during /validate and on merge) and
        # a committed copy skips that step, so it can go stale. See https://github.com/Azure/azure-quickstart-templates/tree/master/1-CONTRIBUTION-GUIDE#bicep-support
        excludedFiles = @("azuredeploy.json", "package-manifest.json")
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
    } | Select-Object -First 1
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

    # Base the new branch on the latest upstream main branch. Fall back to origin when there is no upstream remote (i.e., origin is not a fork).
    $baseRemote = if (git remote | Select-String -Pattern '^upstream$' -Quiet) { 'upstream' } else { 'origin' }
    Write-Host "  Fetching latest $($repo.mainBranch) from $baseRemote..."
    git fetch $baseRemote $repo.mainBranch --quiet

    # Create new branch (never rebase; the repo policy only allows merges)
    $branchName = "$($branchPrefix)-$($ver)_$(Get-Date -Format yyMMdd)"
    Write-Host "  Creating new $branchName branch from $baseRemote/$($repo.mainBranch)..."
    git checkout -b $branchName "$baseRemote/$($repo.mainBranch)" --no-track --quiet

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
    $previousTestResult = $null
    if ($repo.isAqt -and (Test-Path "$($repo.path)/metadata.json"))
    {
        # Remember testResult so re-publishing after a test deployment does not wipe it
        $previousTestResult = (Get-Content "$($repo.path)/metadata.json" -Raw | ConvertFrom-Json).PSObject.Properties['testResult'].Value
    }
    if (Test-Path $repo.path)
    {
        Remove-Item $repo.path -Recurse -Force
    }
    ./New-Directory $repo.path
    Get-ChildItem $sourceDir -Exclude .buildignore | Copy-Item -Destination $repo.path -Recurse
    if ($Template -eq "docs")
    {
        Remove-DocsMetadataOnlyChanges $repo.path
    }
    elseif ($repo.excludedFiles -and (Test-Path "$($repo.path)/main.bicep"))
    {
        # Remove files the destination repo generates itself or does not accept
        $repo.excludedFiles | ForEach-Object {
            if (Test-Path "$($repo.path)/$_")
            {
                Write-Host "  Excluding $_..."
                Remove-Item "$($repo.path)/$_" -Force
            }
        }
    }
    if ($repo.isAqt)
    {
        Update-AqtMetadata "$($repo.path)/metadata.json" $previousTestResult
    }

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

# Refresh metadata.json for Azure Quickstart Templates: dateUpdated and testResult
function Update-AqtMetadata([string]$metadataPath, $previousTestResult)
{
    $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json

    # AQT requires dateUpdated to be set to the date of the change
    $metadata | Add-Member -NotePropertyName dateUpdated -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd') -Force

    if ($CorrelationId -or $DeploymentName)
    {
        if (-not ($CorrelationId -and $DeploymentName))
        {
            Write-Error '-CorrelationId and -DeploymentName must be specified together.'
            return
        }

        $metadata | Add-Member -NotePropertyName testResult -Force -NotePropertyValue ([ordered]@{
                deployments = [ordered]@{
                    templateFileName = 'main.bicep'
                    correlationId    = $CorrelationId
                    deploymentName   = $DeploymentName
                }
            })
        Write-Host "  Updated metadata.json testResult (deployment $DeploymentName)."
    }
    elseif ($previousTestResult)
    {
        # Preserve the testResult already in the destination repo. It must come from a deployment of this exact main.bicep;
        # AQT checks the template hash on /validate, so a stale value fails there.
        $metadata | Add-Member -NotePropertyName testResult -NotePropertyValue $previousTestResult -Force
        Write-Warning "Preserved existing testResult in metadata.json. Make sure it comes from a deployment of this version, or pass -CorrelationId and -DeploymentName."
    }
    else
    {
        Write-Warning "metadata.json has no testResult. AQT requires it. Deploy main.bicep to Azure and re-run with -CorrelationId and -DeploymentName."
    }

    $metadata | ConvertTo-Json -Depth 10 | Out-File $metadataPath -Encoding utf8
}

function Get-DocsArticleBody([string]$content)
{
    # Body normalization rules. Keep this aligned with strip_frontmatter() in
    # .github/workflows/update-mslearn-dates.yml so both code paths classify the
    # same edits as metadata-only:
    #   1. Split on \r?\n (CRLF tolerance).
    #   2. Whitespace-tolerant --- fence detection. If line 1 trims to ---,
    #      drop everything through the next line that trims to ---. If no
    #      closing fence is found, treat the entire file as body (errs safe
    #      for malformed frontmatter; any byte change registers as a body
    #      change instead of silently being masked).
    #   3. Drop markdownlint-disable-next-line MD025 and prettier-ignore
    #      directive lines (whitespace-tolerant trim equality).
    #   4. Strip leading and trailing blank lines from the body.
    #
    # Whitespace preservation: Trailing whitespace, blank line runs, and all
    # content inside fenced/indented code blocks are preserved exactly. This
    # ensures real content changes (e.g., hard line breaks, code block
    # formatting) are not misclassified as metadata-only.

    $lines = $content -split "`r?`n"
    $start = 0

    if ($lines.Count -gt 0 -and $lines[0].Trim() -eq "---")
    {
        for ($i = 1; $i -lt $lines.Count; $i++)
        {
            if ($lines[$i].Trim() -eq "---")
            {
                $start = $i + 1
                break
            }
        }
    }

    if ($start -ge $lines.Count)
    {
        return ""
    }

    $ignoreLines = @(
        "<!-- markdownlint-disable-next-line MD025 -->",
        "<!-- prettier-ignore-start -->",
        "<!-- prettier-ignore-end -->"
    )

    $body = New-Object 'System.Collections.Generic.List[string]'
    for ($i = $start; $i -lt $lines.Count; $i++)
    {
        $line = $lines[$i]
        if ($ignoreLines -contains $line.Trim())
        {
            continue
        }
        $null = $body.Add($line)
    }

    $s = 0
    while ($s -lt $body.Count -and $body[$s] -eq "")
    {
        $s++
    }
    $e = $body.Count - 1
    while ($e -ge $s -and $body[$e] -eq "")
    {
        $e--
    }

    if ($s -gt $e)
    {
        return ""
    }

    return ($body[$s..$e] -join "`n")
}

function Remove-DocsMetadataOnlyChanges([string]$docsPath)
{
    Push-Location
    try
    {
        Set-Location $docsPath
        $repoRoot = git rev-parse --show-toplevel
        Set-Location $repoRoot

        Get-ChildItem $docsPath -Recurse -Filter "*.md" | ForEach-Object {
            $repoFile = [System.IO.Path]::GetRelativePath($repoRoot, $_.FullName).Replace("\", "/")
            git cat-file -e "HEAD:$repoFile" 2>$null

            # return in ForEach-Object skips the current pipeline item (per-iteration), not the enclosing function.
            if ($LASTEXITCODE -ne 0)
            {
                return
            }

            $previousContent = [string]::Join("`n", (git show "HEAD:$repoFile"))
            $currentContent = Get-Content $_.FullName -Raw

            if ((Get-DocsArticleBody $previousContent) -eq (Get-DocsArticleBody $currentContent))
            {
                git restore --source HEAD -- $repoFile
            }
        }
    }
    finally
    {
        Pop-Location
    }
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
