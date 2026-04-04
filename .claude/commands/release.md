---
description: Walk through the release checklist interactively
allowed-tools: Read, Grep, Bash(pwsh -Command ./src/scripts/Start-Release*), Bash(gh issue view *)
---

# Release

Assists in the FinOps toolkit release process.

## Process

### Phase 1: Setup

Run `pwsh -Command ./src/scripts/Start-Release.ps1` and report the result to the user.

### Future phases

Additional phases will be added incrementally as we work through the release process:

- **Phase 2: Monthly updates** — Open data, Bicep CLI
- **Phase 3: Core features** — Branch merges, build, test, version references
- **Phase 4: Finalize** — Changelog, version bump, packaging
- **Phase 5: Publish** — PowerShell, Bicep Registry, AQT, docs, GitHub release
- **Phase 6: Post-release** — Dev version bump, branch cleanup
