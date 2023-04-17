<#
    .SYNOPSIS
        Creates a new feature branch.
    .EXAMPLE
        ./New-FeatureBranch foo
        Creates the "foo" feature branch (features/foo).
    .PARAMETER Name
        Name of the feature branch to create. Do not include the "features/" prefix.
#>
Param (
    [string] $Name
)

# Fetch latest changes from remote
git fetch

# Check to see if a remote branch already exists
$branchExists = git branch --remotes --list origin/features/$Name
if ($branchExists.Length -gt 0) {
    Write-Error "Remote branch already exists: features/$Name"
    exit 1
}

# Check to see if a local branch already exists
$branchExists = git branch --list origin/features/$Name
if ($branchExists.Length -gt 0) {
    Write-Error "Local branch already exists: features/$Name"
    exit 1
}

# Start on dev branch
git checkout dev

# Create new branch
git checkout -b features/$Name

# Push new branch to remote
git push --set-upstream origin features/$Name
