# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Updates the current version.

    .PARAMETER Major
    Optional. Increments the major version number (x.0).

    .PARAMETER Minor
    Optional. Increments the minor version number (0.x).

    .PARAMETER Patch
    Optional. Increments the patch version number (0.0.x).

    .PARAMETER Prerelease
    Optional. Increments the prerelease version number (0.0.0-ooo.x).

    .PARAMETER Label
    Optional. Indicates the label to use for prerelease versions. Allowed: dev, rc, alpha, preview. Default = "dev".

    .PARAMETER Version
    Optional. Sets the version number to an explicit value.

    .EXAMPLE
    ./Update-Version -Major

    Increments the major version number.

    .EXAMPLE
    ./Update-Version -Prerelease -Label "alpha"

    Increments the prerelease version number with an "alpha" preview label.
#>
param
(
    [Parameter()]
    [switch]
    $Major,

    [Parameter()]
    [switch]
    $Minor,

    [Parameter()]
    [switch]
    $Patch,

    [Parameter()]
    [switch]
    $Prerelease,

    [Parameter()]
    [AllowEmptyString()]
    [AllowNull()]
    [ValidateSet($null, '', 'dev', 'alpha', 'rc', 'preview')]
    [string]
    $Label,

    [string]
    $Version
)

# Calculate new version number
$update = if ($Major) { "major" } elseif ($Minor) { "minor" } elseif ($Patch) { "patch" } elseif ($Prerelease) { "prerelease" }
if ($update)
{
    Write-Verbose "Updating $update version."
}
elseif ($Version)
{
    $update = $Version
    Write-Verbose "Updating to version $update."
}

# Only update version if requested
if ($update -or $Version)
{
    # Update version in NPM
    Write-Verbose "Updating NPM version..."
    $null = npm --no-git-tag-version version $update

    # Update label, if needed
    if ($Label)
    {
        $newLabel = $Label.ToLower() -replace '[^a-z]', ''
        Write-Verbose "Using label '$newLabel'."
        $null = npm --no-git-tag-version --preid $newLabel version preminor
    }
}

$ver = & "$PSScriptRoot/Get-Version"

if ($update -or $Version)
{
    Write-Verbose "Updated to version $ver."
}

# Update version in secondary files, if needed
if ($update -or $Version)
{
    # Update version files: ftkver.txt (major.minor) and ftktag.txt (git tag, e.g., "v13")
    $repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $tag = & "$PSScriptRoot/Get-Version" -AsTag
    foreach ($entry in @{ 'ftkver.txt' = $ver; 'ftktag.txt' = $tag }.GetEnumerator())
    {
        Write-Verbose "Updating $($entry.Key) files..."
        Get-ChildItem $repoRoot -Include $entry.Key -Recurse -Force `
        | ForEach-Object {
            Write-Verbose "- $($_.FullName.Replace($repoRoot + [IO.Path]::DirectorySeparatorChar, ''))"
            $entry.Value | Out-File $_ -NoNewline
        }
    }

    # Update FTK survey IDs in feedback links (e.g., surveyId/FTK0.11 -> surveyId/FTK14.0)
    Write-Verbose "Updating FTK survey IDs..."
    Get-ChildItem $repoRoot -Include '*.md' -Recurse -Force `
    | Select-String -Pattern 'surveyId/FTK[\d.]+' -List `
    | ForEach-Object {
        $content = Get-Content $_.Path -Raw
        $updated = $content -replace 'surveyId/FTK[\d.]+', "surveyId/FTK$ver"
        if ($content -ne $updated)
        {
            $updated | Out-File $_.Path -NoNewline -Encoding utf8
            Write-Verbose "- $($_.Path.Replace($repoRoot + [IO.Path]::DirectorySeparatorChar, ''))"
        }
    }

    # Update version in PowerShell
    Write-Verbose "Updating PowerShell Get-VersionNumber..."
    & {
        Write-Output "# Copyright (c) Microsoft Corporation."
        Write-Output "# Licensed under the MIT License."
        Write-Output ""
        Write-Output "function Get-VersionNumber"
        Write-Output "{"
        Write-Output "    param()"
        Write-Output "    return '$ver'"
        Write-Output "}"
    } | Out-File "$PSScriptRoot/../PowerShell/Private/Get-VersionNumber.ps1" -Encoding ascii -Append:$false

    # Release tag strips prerelease labels and trailing .0 (e.g., "14.0-dev" -> "v14")
    $releaseTag = 'v' + (($ver -replace '-.*$', '') -replace '\.0$', '')

    # Update changelog with new version section
    Write-Verbose "Updating changelog..."
    $changelogPath = Join-Path $repoRoot 'docs-mslearn/toolkit/changelog.md'
    if (Test-Path $changelogPath)
    {
        $changelogLines = Get-Content $changelogPath
        $anchorIndex = $changelogLines.IndexOf('<br><a name="latest"></a>')
        if ($anchorIndex -ge 0)
        {
            # Find the first ## v heading after the anchor to get the previous version tag
            $prevTag = 'v0.0.1'
            for ($i = $anchorIndex + 1; $i -lt $changelogLines.Count; $i++)
            {
                if ($changelogLines[$i] -match '^## (v\S+)')
                {
                    $prevTag = $Matches[1]
                    break
                }
            }

            # Skip if this version section already exists
            if ($prevTag -eq $releaseTag)
            {
                Write-Verbose "- Changelog already has $releaseTag section"
            }
            else
            {
                $releaseDate = (Get-Date).AddMonths(1).ToString('MMMM yyyy')
                $newSection = @(
                    ''
                    "## $releaseTag"
                    ''
                    "_Released ${releaseDate}_"
                    ''
                    '<!-- prettier-ignore-start -->'
                    '> [!div class="nextstepaction"]'
                    "> [Download](https://github.com/microsoft/finops-toolkit/releases/tag/$releaseTag)"
                    '> [!div class="nextstepaction"]'
                    "> [Full changelog](https://github.com/microsoft/finops-toolkit/compare/$prevTag...$releaseTag)"
                    '<!-- prettier-ignore-end -->'
                    ''
                    '<br>'
                )

                $changelogLines = $changelogLines[0..$anchorIndex] + $newSection + $changelogLines[($anchorIndex + 1)..($changelogLines.Count - 1)]
                $changelogLines | Out-File $changelogPath -Encoding utf8
                Write-Verbose "- Added $releaseTag section to changelog"
            }
        }
    }

    # Update integration test version variables
    Write-Verbose "Updating integration test versions..."
    $testPath = Join-Path $repoRoot 'src/powershell/Tests/Integration/Toolkit.Tests.ps1'
    if (Test-Path $testPath)
    {
        $testContent = Get-Content $testPath -Raw
        $releaseTagName = $releaseTag.TrimStart('v')

        # Extract current planned release and skip if already up to date
        if ($testContent -match '\$plannedRelease = ''([^'']+)''')
        {
            $oldPlanned = $Matches[1]

            if ($oldPlanned -eq $releaseTagName)
            {
                Write-Verbose "- Integration test already has planned release '$releaseTagName'"
            }
            else
            {
                # Update $plannedRelease to the new version
                $testContent = $testContent -replace '\$plannedRelease = ''[^'']+''', ('$plannedRelease = ''{0}''' -f $releaseTagName)

                # Prepend old planned release to $expected array
                $testContent = $testContent -replace '\$expected = @\(', ('$expected = @(''{0}'', ' -f $oldPlanned)

                $testContent | Out-File $testPath -NoNewline -Encoding utf8
                Write-Verbose "- Updated planned release from '$oldPlanned' to '$releaseTagName'"
            }
        }
    }
}

return $ver
