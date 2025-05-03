# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Merges the dev branch into the specified branch.

    .EXAMPLE
    ./Merge-DevBranch
	
	Merges the dev branch into the current branch.

    .EXAMPLE
    ./Merge-DevBranch features/foo -TortoiseGit
	
	Merges the dev branch into the features/foo branch and uses TortoiseGit to resolve conflicts.

    .EXAMPLE
    ./Merge-DevBranch *

	Merges the dev branch into main and all feature branches. Does not resolve conflicts.

    .PARAMETER Branch
    Optional. Name of the branch to merge into. Default = "." (current branch).

    .PARAMETER TortoiseGit
    Optional. Indicates whether to use TortoiseGit to resolve conflicts. Default = false.

    .PARAMETER Silent
    Optional. Indicates whether to hide informational output. Will abort merge if there are any conflicts. Use $LASTEXITCODE to determine status (0 = successful, 1 = error, 2 = conflicts). Default = false.
#>
Param (
    [Parameter(Position = 0)]
    [string]
    $Branch = ".",

    [switch]
    $TortoiseGit,

    [switch]
    $Silent
)

# If all feature branches, loop thru feature branches
if ($Branch -eq "*") {
    $featureBranches = git branch --remotes --list origin/features/* | ForEach-Object { $_.Trim().Substring(7) }  # trim "origin/";
    Write-Host ''
    Write-Host "Merging dev into main and $($featureBranches.Count) feature " -NoNewline
    if ($featureBranches.Count -eq 1) {
        Write-Host "branch..."
    } else {
        Write-Host "branches..."
    }
    Write-Host ''
    $success = @()
    $failure = @()
    $longestBranchName = ($featureBranches | Measure-Object -Maximum -Property Length).Maximum
    @($featureBranches) | ForEach-Object {
        $branchName = $_
        Write-Host "  $branchName".PadRight($longestBranchName + 5, ".") -NoNewline
        ./Merge-DevBranch $branchName -Silent
        if ($LASTEXITCODE -eq 0) {
            $success += $branchName
            Write-Host "done"
        } else {
            $failure += ($branchName + " (Code: $LASTEXITCODE)")
            Write-Host "skipped"
        }
    }
    Write-Host ''
    if ($success.Count -eq $featureBranches.Count + 1) {
        Write-Host "All branches merged successfully!"
    } else {
        Write-Host "$($success.Count) merged successfully."
        Write-Host "$($failure.Count) skipped:"
        $failure | ForEach-Object { Write-Host "  $_" }
    }
    Write-Host ''
    exit 0
}

# If current branch, get branch name
if ($Branch -eq ".") {
    $Branch = git rev-parse --abbrev-ref HEAD
}

if ($Branch -eq "dev") {
    Write-Error "Cannot merge dev branch into itself. Please specify the target branch."
    exit 1
}

if (-not $Silent) {
    Write-Host ''
    Write-Host "Merging dev and $Branch..."
    Write-Host ''
}

# Fetch latest changes from remote
if ($Silent)
{
    git fetch --all --quiet
}
else
{
    git fetch --all
}

# Check to see if a remote branch exists
$branchExists = git branch --remotes --list origin/$Branch
if ($branchExists.Length -eq 0) {
    Write-Host '  ' -NoNewline
    if ($Silent)
    {
        Write-Host "branch not found..." -NoNewline
    }
    else
    {
        Write-Error "Remote branch not found: $Branch"
    }
    exit 1
}

function Merge-BranchAtoB($source, $target) {
    # Start on target branch
    if ((git rev-parse --abbrev-ref HEAD) -ne $target) {
        if ($Silent) {
            git checkout $target --quiet *> $null
        } else {
            Write-Host "  Switching to $target branch..."
            git checkout $target --quiet
        }
    }

    # Validate the branch is clean
    $gitStatus = git status
    if (($gitStatus | Select-String 'Changes not staged for commit:') -or ($gitStatus | Select-String 'Changes to be committed:')) {
        if ($Silent)
        {
            Write-Host 'uncommitted changes...' -NoNewline
        }
        else
        {
            Write-Host '  ' -NoNewline
            Write-Error 'Your branch has uncommitted changes. Please commit or stash changes and try again.'
        }
        exit 1
    }
    if (($gitStatus | Select-String "Your branch is ahead of 'origin/$target' by") -or ($gitStatus | Select-String "Your branch and 'origin/$target' have diverged")) {
        if ($Silent)
        {
            Write-Host 'unpushed local commits...' -NoNewline
        }
        else
        {
            Write-Host '  ' -NoNewline
            Write-Error 'Your branch has unpushed local commits. Please push or move to another branch and try again.'
        }
        exit 1
    }

    # Pull latest changes
    if ($gitStatus | Select-String "Your branch is behind 'origin/$target' by") {
        if ($Silent) {
            git pull --quiet *> $null
        } else {
            Write-Host '  Pulling latest changes...'
            git pull --quiet
        }
    } else {
        if (-not $Silent) {
            Write-Host '  Your branch is up to date'
        }
    }

    if ($Silent) {
        git merge $source --no-commit --quiet *> $null
    } else {
        Write-Host "  Merging $source into $target..."
        Write-Host '-----------------------------'
        git merge $source --no-commit
        Write-Host '-----------------------------'
    }

    # Check for conflicts
    if ((git diff --name-only).Length -gt 0) {
        if ($Silent) {
            Write-Host "resolve conflicts..." -NoNewline
            git merge --abort
            exit 2
        } else {
            # If TortoiseGit switch is set, open the conflict resolution tool
            if ($TortoiseGit) {
                Push-Location
                Set-Location (git rev-parse --show-toplevel)
                . TortoiseGitProc.exe /command:resolve
                Write-Host '  Please resovle conflicts and press Enter to continue. Type "q" to quit.'
                $response = (Read-Host).ToLower()
                if (($response -eq "q") -or ($response -eq "quit")) {
                    if ((git diff --name-only).Length -gt 0) {
                        Write-Host '  ' -NoNewline
                        Write-Warning "Please resolve conflicts, then run: git commit; git push origin $target"
                        Write-Host '  To cancel the merge, run: git merge --abort'
                        exit 2
                    } else {
                        Write-Host '  All conflicts were resolved'
                        Write-Host "  To continue the merge, run: git commit; git push origin $target"
                        Write-Host '  To cancel the merge, run: git merge --abort'
                        exit 2
                    }
                }
            } else {
                Write-Host '  ' -NoNewline
                Write-Warning "Please resolve conflicts, then run: git commit; git push origin $target"
                if ($Silent) {
                    git merge --abort
                }
                exit 2
            }
        }
    }

    # Check status
    $gitStatus = git status
    if (($gitStatus | Select-String 'All conflicts fixed but you are still merging.') -or ($gitStatus | Select-String "Your branch is ahead of 'origin/$target' by")) {
        if ($Silent) {
            git commit --no-edit --quiet *> $null
            git push origin $target --quiet *> $null
        } else {
            Write-Host '  Pushing merge to remote...'
            git commit --no-edit
            git push origin $target
        }
    } elseif ($gitStatus | Select-String "Your branch is up to date with 'origin/$target'.") {
        if (-not $Silent) {
            Write-Host '  No changes to merge'
        }
    } else {
        # TODO: Identify and resolve conflicts
        if ($Silent)
        {
            Write-Host 'unsupported merge state...' -NoNewline
        }
        else
        {
            Write-Host '  ' -NoNewline
            Write-Error 'Merge state not supported. Please check for conflicts.'
            Write-Host "  If there are conflicts, resolve and run: git commit; git push origin $target"
            Write-Host '  To cancel the merge, run: git merge --abort'
        }
        exit 1
    }
    if (-not $Silent) {
        Write-Host ''
    }
}

# If merging to main, first merge main into dev and resolve conflicts
if ($Branch -eq "main") {
    Merge-BranchAtoB main dev
}

# Merge dev into target branch
Merge-BranchAtoB dev $Branch

# Switch back to dev branch
if (-not $Silent) {
    git checkout dev
} else {
    git checkout dev --quiet *> $null
}

if (-not $Silent) {
    Write-Host ''
}
