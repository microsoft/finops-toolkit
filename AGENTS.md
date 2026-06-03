# Agent Instructions

## P0 Git Safety Rule

AI agents must never directly mutate `main` or `dev` in this repository or in any submodule. This includes direct commits, pushes, merges, reverts, cherry-picks, resets, branch updates, or any refspec that targets `main` or `dev`.

AI agents must never run `git push origin HEAD:main`, `git push origin HEAD:dev`, `git push origin <anything>:main`, `git push origin <anything>:dev`, or equivalent commands against any remote.

AI agents must never use privileged credentials, maintainer permissions, administrator permissions, branch-protection bypass permissions, ruleset bypass permissions, or GitHub's "bypass rule violations" path to update a protected branch.

If GitHub reports that a push would "bypass rule violations" or that "changes must be made through a pull request", the agent must stop immediately and report a P0 policy violation. Do not continue with the push, and do not attempt a workaround.

The only allowed path for changes intended for `main` or `dev` is: create or update a feature branch, push only that feature branch after explicit approval, and open a pull request. Humans and required repository automation own protected-branch integration.

Reverting, remediating, or "cleaning up" an unauthorized protected-branch change is also a protected-branch mutation. AI agents must not do it without explicit user approval for the exact branch, commit, and command.

This file provides guidance to AI Agents when working with code in this repository.

## Repository Overview

The FinOps Toolkit is an open-source collection of tools for adopting and implementing FinOps capabilities in the Microsoft Cloud. It contains templates, PowerShell modules, workbooks, optimization engines, and supporting documentation organized in a modular architecture.

## Common Commands

### Building and Development

```bash
# Build entire toolkit
npm run build
# or
pwsh -Command ./src/scripts/Build-Toolkit

# Build FinOps hubs
pwsh -Command ./src/scripts/Build-Toolkit finops-hub

# Build specific components
npm run build-ps                               # PowerShell module only
pwsh -Command ./src/scripts/Build-Bicep        # Bicep templates
pwsh -Command ./src/scripts/Build-Workbook     # Azure Monitor workbooks
pwsh -Command ./src/scripts/Build-OpenData     # Open data files

# Deploy for testing
npm run deploy-test
# or
pwsh -Command ./src/scripts/Deploy-Toolkit -Build -Test

# Package for release
npm run package
# or
pwsh -Command ./src/scripts/Package-Toolkit -Build
```

### Testing

```bash
# Run PowerShell unit tests
npm run pester
# or
pwsh -Command Invoke-Pester -Output Detailed -Path ./src/powershell/Tests/Unit/*

# Run integration tests
pwsh -Command ./src/scripts/Test-PowerShell -Integration

# Run specific test categories
pwsh -Command ./src/scripts/Test-PowerShell -Hubs -Exports

# Lint PowerShell code
pwsh -Command ./src/scripts/Test-PowerShell -Lint
```

### Bicep Development

```bash
# Validate Bicep templates
bicep build path/to/template.bicep --stdout

# Test template deployment
az deployment group what-if --resource-group myRG --template-file template.bicep
```

## Architecture and Code Organization

### High-Level Structure

- **`/src/templates/`** - ARM/Bicep infrastructure templates with modular namespace organization
- **`/src/powershell/`** - PowerShell module with public/private functions and comprehensive tests
- **`/src/optimization-engine/`** - Azure Optimization Engine for cost recommendations
- **`/src/workbooks/`** - Azure Monitor workbooks for governance and optimization
- **`/src/open-data/`** - Reference data (pricing, regions, services) with utilities
- **`/src/scripts/`** - Build automation and development tools
- **`/docs/`** - Jekyll documentation website
- **`/docs-mslearn/`** - Microsoft Learn documentation website
- **`/docs-wiki/`** - GitHub wiki documentation

### Current Architectural Reorganization

The FinOps hubs solution is actively migrating to a namespace-based modular structure:

- **`Microsoft.FinOpsHubs/`** - Core FinOps Hub infrastructure modules
- **`Microsoft.CostManagement/`** - Cost management exports and schemas
- **`fx/`** - Shared foundation components (hub-types, scripts, utilities)

### Template Architecture

Templates use a multi-target build system that generates:

- Azure Quickstart Templates (ARM JSON)
- Bicep Registry modules
- Standalone deployments
- Azure portal UI definitions

Key patterns:

- **`.build.config`** files control build behavior per template
- **`settings.json`** contains component-specific configuration
- **`ftkver.txt`** files maintain version synchronization
- **Conditional resource deployment** based on parameters

### PowerShell Module Structure

- **`Public/`** - User-facing cmdlets (Get-_, Set-_, New-\*, etc.)
- **`Private/`** - Internal utilities and helpers
- **`Tests/Unit/`** - Pester unit tests with mocking
- **`Tests/Integration/`** - End-to-end Azure integration tests
- **Module manifest** defines exports and dependencies

### Data Flow and Integration

- **Open data** provides reference information consumed by templates and PowerShell
- **Build scripts** orchestrate compilation across all components
- **Version management** is centralized through `Update-Version.ps1`
- **Templates reference** shared schemas and types from `fx/` namespace

## Key Development Patterns

### Template Development

- Use `newApp()` and `newHub()` functions from `fx/hub-types.bicep` for consistent resource naming
- Follow the conditional deployment pattern: `resource foo 'type' = if (condition) { ... }`
- Implement proper parameter validation with `@allowed`, `@minValue`, `@maxValue`
- Include telemetry tracking via `defaultTelemetry` parameter

### PowerShell Development

- All public functions must have comment-based help
- Use approved verbs from `Get-Verb`
- Implement comprehensive parameter validation
- Support `-WhatIf` and `-Confirm` for destructive operations
- Include Pester tests for all functions

### Testing Strategy

- **Lint tests** validate syntax and coding standards
- **Unit tests** test isolated function behavior with mocks
- **Integration tests** perform end-to-end validation against Azure
- **Template validation** uses `bicep build` and ARM what-if deployments

### Build System Integration

The PowerShell-based build system:

- Compiles templates to multiple target formats
- Validates all code before packaging
- Maintains version consistency across components
- Generates release artifacts automatically

### Version Management

- Central version in `package.json` (currently 12.0.0)
- Synchronized across all components via build scripts
- Individual `ftkver.txt` files distributed to modules
- Git tags correspond to release versions

## Repository Conventions

### Branch Strategy

- **`dev`** - Main integration branch
- Feature branches merge into `dev`
- Releases are tagged from `dev`

### Git Operations Policy

This repository supports production infrastructure managing significant revenue. All git operations must be non-destructive and preserve full commit history.

The P0 Git Safety Rule at the top of this file is authoritative and overrides every permitted operation listed below.

**Permitted operations:**

- `git add`, `git commit`, `git push` on non-protected feature branches only (standard push only, after explicit approval)
- `git merge` into non-protected feature branches only (merge commits to integrate from `dev` — the only permitted way to sync with `dev` or resolve conflicts, after explicit approval)
- `git checkout`, `git switch`, `git branch` (branch creation and switching)
- `git worktree add`, `git worktree remove`, `git worktree prune` (worktree lifecycle)
- `git fetch`, `git pull` (with merge, not rebase)
- `git stash`, `git stash pop` (temporary local state management)
- `git status`, `git log`, `git diff`, `git show` (read-only inspection)

**Prohibited operations:**

- Any direct mutation of `main` or `dev`, including direct pushes, commits, merges, reverts, or branch ref updates.
- Any use of protected branch, ruleset, or administrator bypass capabilities to update `main` or `dev`.
- Any attempt to land changes on `main` or `dev` without a pull request.
- `git rebase` — rewrites commit history. Never permitted on shared branches. Not permitted as a conflict resolution strategy.
- `git push --force` / `git push --force-with-lease` — destructive remote update. Never permitted.
- `git reset --hard` to a state behind the remote (discarding pushed commits)
- `git filter-branch`, `git reflog`-based history manipulation
- Any operation that rewrites, reorders, squashes, or deletes commits that have been pushed to the remote

**Conflict resolution:** When a branch has merge conflicts with `dev`, the only permitted approach is `git merge origin/dev` into the feature branch. This creates a merge commit and preserves all history.

**Common conflict patterns in this repository:**

- **`ms.date` fields in `docs-mslearn/` files** — Microsoft Learn docs use `ms.date` in YAML front matter. A CI workflow (`.github/workflows/update-mslearn-dates.yml`) automatically updates `ms.date` to today's date for any changed `docs-mslearn/**/*.md` files. On protected branches where the bot cannot push, you must update `ms.date` to today's date (`MM/DD/YYYY` format) manually in every `docs-mslearn/` markdown file you modify. When resolving merge conflicts on `ms.date`, always set the date to today — not either side's value.
- **`.gitignore` additions** — Both sides may add new ignore entries to the end of the file. Keep entries from both sides; they are additive and independent.
- **`src/scripts/Update-Version.ps1`** — This script has multiple independent version-update blocks (PowerShell, Bicep, plugin.json, survey IDs, etc.). When both sides add new blocks, keep both — they operate on different file sets and do not conflict logically.
- **`docs-mslearn/toolkit/changelog.md`** — Both sides may add entries under the same version heading. Keep entries from both sides in logical order (plugin entries, then component entries).

**AI agents must ask for explicit approval** before executing any git write operation (`commit`, `push`, `merge`, `revert`, `cherry-pick`, branch deletion, tag creation, or worktree state mutation). Read-only git commands (`status`, `log`, `diff`, `show`, `branch --list`, `worktree list`, `ls-remote`, `fetch`) do not require approval. Approval to perform a task, deploy, unblock a test, or fix an incident is not approval to write to git; approval must name the git action.

### File Organization

- Templates follow namespace/module/component structure
- PowerShell follows standard module layout
- Documentation uses Jekyll conventions
- Build artifacts are generated, not checked in

### Coding Standards

- Always follow the content and coding standards defined in `docs-wiki/Coding-guidelines.md`
- Content (text strings): Follow the Microsoft style guide and always use sentence casing except for proper nouns
- Bicep: Follow Azure Bicep style guide
- PowerShell: Use PowerShell best practices and approved verbs
- Documentation: Use markdown with consistent formatting
- Commit messages: Use conventional commit format
