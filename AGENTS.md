# Agent Instructions

This file provides guidance to AI Agents when working with code in this repository.

> [!IMPORTANT]
> `AGENTS.md` is the single source of truth for agent guidance. `CLAUDE.md` and `.github/copilot-instructions.md` are git symlinks (mode `120000`) pointing here. Never replace those symlinks with real files — edit this file instead.

## Repository Overview

The FinOps Toolkit is an open-source collection of tools for adopting and implementing FinOps capabilities in the Microsoft Cloud. It contains templates, PowerShell modules, workbooks, optimization engines, and supporting documentation organized in a modular architecture.

## Common Commands

### First-time setup

`src/scripts/Init-Repo.ps1` installs the required tooling (Az PowerShell, Bicep CLI) and optional tooling (VS Code, Bicep module, NPM, Pester):

```powershell
./src/scripts/Init-Repo -All          # required + optional tooling
./src/scripts/Init-Repo -Pester       # required + Pester only
./src/scripts/Init-Repo -All -WhatIf  # preview
```

**Pester 6.0.0 or later is required.** The suite uses `-AllowNullOrEmptyForEach`, which Pester 5 rejects during discovery — the affected file is silently skipped. `Test-PowerShell.ps1` resolves the module version explicitly and fails with an actionable message if only an older Pester is present. CI pins the same floor (`.github/workflows/dev.yml`).

### Building and Development

```bash
# Build entire toolkit
npm run build
# or
pwsh -Command ./src/scripts/Build-Toolkit

# Build FinOps hubs
pwsh -Command ./src/scripts/Build-Toolkit finops-hub

# Build a single workbook
pwsh -Command ./src/scripts/Build-Toolkit "<workbook-name>-workbook"

# Build specific components
npm run build-ps                                        # PowerShell module (Invoke-Task Build.PsModule)
pwsh -Command ./src/scripts/Build-PowerShell            # PowerShell module (wraps the Invoke-Build task)
pwsh -Command ./src/scripts/Build-Bicep ../bicep-registry/<module>  # single Bicep Registry module
pwsh -Command ./src/scripts/Build-Workbook              # Azure Monitor workbooks
pwsh -Command ./src/scripts/Build-OpenData              # Open data files (check in generated files manually)
pwsh -Command ./src/scripts/Invoke-Task -Task <TaskName>  # Invoke-Build tasks (e.g. Build.PsModule)

# Load the locally built module
pwsh -Command 'Remove-Module FinOpsToolkit -EA SilentlyContinue; Import-Module -FullyQualifiedName ./src/powershell/FinOpsToolkit.psm1'

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

`src/scripts/Test-PowerShell.ps1` is the entry point for all Pester runs. It runs unit tests by default; naming any test type runs only those types.

```bash
# Run PowerShell unit tests
pwsh -Command ./src/scripts/Test-PowerShell
# or
npm run pester

# Run lint / integration / everything
pwsh -Command ./src/scripts/Test-PowerShell -Lint
pwsh -Command ./src/scripts/Test-PowerShell -Integration
pwsh -Command ./src/scripts/Test-PowerShell -AllTests

# Run specific test categories (combine freely)
# Cost, Data, Docs, Exports, FOCUS, Hubs, Toolkit, Workbooks, Actions, Private
pwsh -Command ./src/scripts/Test-PowerShell -Hubs -Exports

# Re-run only the tests that failed in the previous run
pwsh -Command ./src/scripts/Test-PowerShell -RunFailed
```

Run a **single test file** or a **single test case** with Pester directly (import Pester 6 explicitly so a side-by-side Pester 3/5 install cannot win):

```bash
# One file
pwsh -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester -Output Detailed -Path ./src/powershell/Tests/Unit/Get-FinOpsRegion.Tests.ps1'

# One Describe/Context/It by name
pwsh -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester -Output Detailed -Path ./src/powershell/Tests/Unit/Get-FinOpsRegion.Tests.ps1 -FullNameFilter "*returns all regions*"'
```

After a `Test-PowerShell` run, inspect these globals to debug:

- `$global:ftk_TestPowerShell_Results` — full result object from the last run
- `$global:ftk_TestPowerShell_Summary` — failed tests only
- `$global:ftk_TestPowerShell_FailedTests` — the Pester config used by `-RunFailed`

### Bicep Development

```bash
# Validate Bicep templates
bicep build path/to/template.bicep --stdout

# Test template deployment
az deployment group what-if --resource-group myRG --template-file template.bicep
```

## Architecture and Code Organization

### High-Level Structure

- **`/src/templates/`** - ARM/Bicep infrastructure templates (`finops-hub`, `finops-alerts`, `finops-workbooks`, `agent-plugin`, `finops-hub-copilot*`)
- **`/src/powershell/`** - PowerShell module with public/private functions and comprehensive tests
- **`/src/queries/`** - KQL query catalog (`catalog/`, `INDEX.md`, `KPI.md`, `finops-hub-database-guide.md`)
- **`/src/bicep-registry/`** - Bicep Registry modules (multi-scope build)
- **`/src/optimization-engine/`** - Azure Optimization Engine for cost recommendations
- **`/src/workbooks/`** - Azure Monitor workbooks for governance and optimization
- **`/src/open-data/`** - Reference data (pricing, regions, services) with utilities
- **`/src/power-bi/`** - Power BI reports (built manually, not by the build scripts)
- **`/src/scripts/`** - Build automation and development tools (see `src/scripts/README.md`)
- **`/plugins/`**, **`/.claude-plugin/`** - Agent plugin packaging (`plugins/microsoft-finops-toolkit`)
- **`/docs/`** - Jekyll documentation website
- **`/docs-mslearn/`** - Microsoft Learn documentation website (includes `toolkit/changelog.md`)
- **`/docs-wiki/`** - GitHub wiki documentation (authoritative dev process + coding guidelines)

### Current Architectural Reorganization

The FinOps hubs solution is actively migrating to a namespace-based modular structure under `src/templates/finops-hub/modules/`:

- **`Microsoft.FinOpsHubs/`** - Core FinOps Hub infrastructure modules, split into `Core`, `Analytics`, `IngestionQueries`, `Recommendations`, `AzureResourceGraph`, and `RemoteHub`
- **`Microsoft.CostManagement/`** - Cost management exports and schemas
- **`fx/`** - Shared foundation components: `hub-types.bicep`, `hub-app.bicep`, `hub-storage.bicep`, `hub-database.bicep`, `hub-identity.bicep`, `hub-vault.bicep`, `hub-deploymentScript.bicep`, `hub-eventTrigger.bicep`, plus `scripts/` and version/tag files

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
- **`en-US/`** - Localized strings (validated by `Tests/Unit/LocalizedData.Tests.ps1`)
- **`Tests/Lint/`** - Repo-wide standards tests (`Lint.Tests.ps1`, `KqlJoinKinds.Tests.ps1`, `MsLearnDocs.Tests.ps1`)
- **`Tests/Unit/`** - Pester unit tests with mocking. Note these cover far more than cmdlets — hub Bicep/KQL guards (`HubsKqlOperators`, `HubsIngestionQueries`, `HubsPrivateNetworking`, `HubsContractedCostGuard`, `HubsAdfTriggerTimeZones`), GitHub Actions parity, and docs links all live here
- **`Tests/Integration/`** - End-to-end Azure integration tests
- **`Tests/Initialize-Tests.ps1`** - Reimports `FinOpsToolkit.psm1` and dot-sources `src/scripts/Monitor.ps1`; test files reference it rather than importing the module themselves
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

- Central version in `package.json` (source of truth; prerelease format is `<major>.0.0-dev.0`)
- Synchronized across all components via `src/scripts/Update-Version.ps1`; read the current value with `src/scripts/Get-Version`
- Individual `ftkver.txt` files distributed to modules
- Git tags correspond to release versions

## Repository Conventions

### Branch Strategy

- **`dev`** - Main integration branch
- Feature branches merge into `dev`
- Releases are tagged from `dev`
- Branch names must be prefixed with the GitHub username (e.g., `{username}/my-feature`)

### Git Operations Policy

This repository supports production infrastructure managing significant revenue. All git operations must be non-destructive and preserve full commit history.

**Permitted operations:**

- `git add`, `git commit`, `git push` (standard push only)
- `git merge` (merge commits to integrate branches — the only permitted way to sync with `dev` or resolve conflicts)
- `git checkout`, `git switch`, `git branch` (branch creation and switching)
- `git worktree add`, `git worktree remove`, `git worktree prune` (worktree lifecycle)
- `git fetch`, `git pull` (with merge, not rebase)
- `git stash`, `git stash pop` (temporary local state management)
- `git status`, `git log`, `git diff`, `git show` (read-only inspection)

**Prohibited operations:**

- `git rebase` — rewrites commit history. Never permitted on shared branches. Not permitted as a conflict resolution strategy.
- `git push --force` / `git push --force-with-lease` — destructive remote update. Never permitted.
- `git reset --hard` to a state behind the remote (discarding pushed commits)
- `git filter-branch`, `git reflog`-based history manipulation
- Any operation that rewrites, reorders, squashes, or deletes commits that have been pushed to the remote

**Conflict resolution:** When a branch has merge conflicts with `dev`, the only permitted approach is `git merge origin/dev` into the feature branch. This creates a merge commit and preserves all history.

**Common conflict patterns in this repository:**

- **`ms.date` fields in `docs-mslearn/` files** — Microsoft Learn docs use `ms.date` in YAML front matter. A CI workflow (`.github/workflows/update-mslearn-dates.yml`) automatically updates `ms.date` to today's date for `docs-mslearn/**/*.md` files that have **body content changes** (changes outside YAML frontmatter). Metadata-only changes (e.g., updating only `ms.author` or other frontmatter fields) do not trigger `ms.date` updates. On protected branches where the bot cannot push, you must update `ms.date` to today's date (`MM/DD/YYYY` format) manually when you modify the body content of any `docs-mslearn/` markdown file. When resolving merge conflicts on `ms.date`, always set the date to today — not either side's value.
- **`.gitignore` additions** — Both sides may add new ignore entries to the end of the file. Keep entries from both sides; they are additive and independent.
- **`src/scripts/Update-Version.ps1`** — This script has multiple independent version-update blocks (PowerShell, Bicep, plugin.json, survey IDs, etc.). When both sides add new blocks, keep both — they operate on different file sets and do not conflict logically.
- **`docs-mslearn/toolkit/changelog.md`** — Both sides may add entries under the same version heading. Keep entries from both sides in logical order (plugin entries, then component entries).

**AI agents must ask for explicit approval** before executing any git write operation (`commit`, `push`, `merge`). Read-only git commands (`status`, `log`, `diff`, `branch --list`, `worktree list`) do not require approval.

### File Organization

- Templates follow namespace/module/component structure
- PowerShell follows standard module layout
- Documentation uses Jekyll conventions
- Build artifacts are generated, not checked in

### Changelog

User-facing changes must be added to `docs-mslearn/toolkit/changelog.md`. Full rules are in the "Changelog" section of `docs-wiki/Coding-guidelines.md`. Key points:

- All changes for the upcoming release go in **one** version section — never create a duplicate `## v{version}` heading
- Group by tool with an H3 heading linking to the tool's doc page plus its version (e.g. `### [FinOps hubs](...) v14`), matching the tool order used in previous releases
- Category order: Added, Changed, Fixed, Deprecated, Removed. Omit empty categories
- One past-tense sentence per entry, ending with a period, linking the issue as `([#{number}]({url}))` when one exists
- Write for users, not developers — no implementation details, no filler entries
- Prefix breaking changes with `**Breaking:**` and list them first in their category

### Coding Standards

- Always follow the content and coding standards defined in `docs-wiki/Coding-guidelines.md`
- Content (text strings): Follow the Microsoft style guide and always use sentence casing except for proper nouns
- Bicep: Follow Azure Bicep style guide
- PowerShell: Use PowerShell best practices and approved verbs
- KQL: Never use `tolower()`/`toupper()` in comparison position — KQL string operators are already case-insensitive (`_cs` variants are the case-sensitive ones). Use `has` for whole terms and path phrases, `=~`/`!~` for equality, `in~`/`has_any` for sets. Reserve `contains` for genuine substring matching (needle fused inside a larger token) and justify it in the allowlist in `src/powershell/Tests/Unit/HubsKqlOperators.Tests.ps1`, which enforces both rules on every PR. See the KQL section of `docs-wiki/Coding-guidelines.md`
- KQL joins: Never write a bare `| join` — always state `kind=` explicitly (the `innerunique` default deduplicates the left side and silently drops rows; enforced by `src/powershell/Tests/Lint/KqlJoinKinds.Tests.ps1`, added in PR #2225). Prefer `lookup` over `join` for enriching a fact table from a small dimension (ADX/Log Analytics only — not available in Azure Resource Graph), dedupe the dimension side with `summarize take_any(...) by <key>` (not `distinct`), and use `kind=leftanti` for exclusions instead of `kind=leftouter` + `where isempty(...)` — except in ARG, which rejects `lookup` and all semi/anti flavors (verified live), so exclusions there use the `leftouter` + `isempty()` emulation with a key-unique right side. See the "Joins and lookups" section of `docs-wiki/Coding-guidelines.md`
- Documentation: Use markdown with consistent formatting
- Commit messages: Use conventional commit format
