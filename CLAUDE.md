# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
