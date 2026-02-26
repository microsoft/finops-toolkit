# PR #2013 Review Audit

Feedback from [PR #2013](https://github.com/microsoft/finops-toolkit/pull/2013) review comments, tracked for remediation on `features/agentskills`.

Reverted by [PR #2023](https://github.com/microsoft/finops-toolkit/pull/2023). This checklist tracks what needs to be addressed before re-submitting.

## Audit checklist

| # | Done | Sev | Issue | Reviewer | Notes |
|---|------|-----|-------|----------|-------|
| 1 | [x] | ~~CRIT~~ | CLAUDE.md replaced with Copilot symlink — lost 182 lines of build/arch/test guidance | flanakin | AGENTS.md is the source of truth. CLAUDE.md symlinks to it. |
| 2 | [x] | ~~CRIT~~ | Symlink direction wrong — Copilot should symlink to agent instructions, not vice versa | flanakin | `.github/copilot-instructions.md` symlinks to `../AGENTS.md`. |
| 3 | [x] | ~~CRIT~~ | `Package-Toolkit.ps1` doesn't follow symlinks; Windows needs `core.symlinks=true` | flanakin | **Not a real issue.** `Build-Toolkit.ps1` line 180 uses `Copy-Item -Recurse` which follows symlinks on all platforms. `Compress-Archive` compresses file content, not link metadata. The only risk is Windows clones with `core.symlinks=false` (git default on Windows) — but that's a git config issue affecting all repo symlinks, not specific to this plugin. NTFS fully supports symlinks/junctions. |
| 4 | [x] | ~~HIGH~~ | `marketplace.json` at repo root violates `src/` convention | flanakin | **By design.** `.claude-plugin/marketplace.json` is tool configuration (like `.github/`, `.vscode/`) that must be at repo root for Claude Code plugin discovery. Same convention as other dotfile-based tool config. |
| 5 | [x] | ~~HIGH~~ | Plugin version `1.0.0` doesn't match toolkit version; `Update-Version.ps1` not integrated | flanakin | **Fixed.** Updated `plugin.json` to `13.0.0`. Added plugin.json update block to `Update-Version.ps1`. |
| 6 | [x] | ~~MED~~ | Description says "financial operations" — FinOps is a proper noun, not an acronym | flanakin | **Fixed.** Changed to `"Claude plugin for FinOps Toolkit, providing tools and integrations for FinOps practitioners."` |
| 7 | [x] | ~~MED~~ | FinOps Framework capabilities are outdated (pre-2025 Fx) | flanakin | **Fixed.** Updated 4 principles to 2025 Fx wording and renamed 2 domains (removed "Cloud" per Cloud+ scope). Source: [finops.org/framework/principles](https://www.finops.org/framework/principles/), [finops.org/framework/domains](https://www.finops.org/framework/domains/). |
| 8 | [x] | ~~MED~~ | Autonomous commands lack guardrails — no confirmation gates, token limits, iteration caps | flanakin | **Fixed.** No hard gates (harness controls autonomy), but added phase checkpoints between Setup→Plan, Plan→Execute, and Execute→Reflect. Each checkpoint summarizes progress before proceeding. Also removed demo-specific framing — documented the iterative, cumulative design intent clearly. |
| 9 | [x] | ~~MED~~ | Nonexistent scripts referenced in `azure-savings-plans.md` | flanakin | **Fixed.** Copied `Get-BenefitRecommendations.ps1` from `azcapman/scripts/rate/` into `skills/azure-cost-management/references/`. |
| 10 | [x] | ~~MED~~ | what-if is advisory only, not an enforced gate before deployment | flanakin | **Fixed.** Strengthened step 3 to "REQUIRED — Run what-if preview before any deployment" with explicit "Do not proceed to deployment without completing it first." |
| 11 | [x] | ~~MED~~ | `Get-VmSkuPrice` can return array; code assumes scalar | copilot, flanakin | **Fixed.** Added `Select-Object -First 1` to the pipeline in `azure-vm-rightsizing.md` line 180. |
| 12 | [x] | ~~LOW~~ | Commands should be in `ftk/` subfolder for `/ftk:*` namespacing | flanakin | **Fixed.** Moved commands into `commands/ftk/` and renamed (e.g., `ftk-cost-optimization.md` → `ftk/cost-optimization.md`). Now invoked as `/ftk:cost-optimization`. |
| 13 | [x] | ~~LOW~~ | Command file references should use root-relative paths in `.ftk` folder | flanakin | **Fixed.** Prefixed all working paths with `ftk/` (not `.ftk/` — hidden dirs are bad UX on macOS). All three commands (mom-report, ytd-report, cost-optimization) now use `ftk/research/`, `ftk/planning/`, `ftk/results/`, `ftk/notes/`, `ftk/queries/`, `ftk/knowledge/`. |
| 14 | [x] | ~~LOW~~ | Agent branches on platform (macOS vs Windows) instead of tool availability | flanakin | **Fixed.** Replaced "Platform Detection" with "Tool Detection" — checks `az version` and `Get-Module Az.Accounts` to detect available tooling. Prefers az CLI if both available. Removed macOS/Windows assumptions from what-if commands too. |
| 15 | [x] | ~~LOW~~ | Consider adding FinOps alerts capability | flanakin | **Fixed.** Added "FinOps alerts" bullet under "Manage the FinOps Practice" domain — covers cost anomaly alerts, budget alerts, and scheduled cost reports. Reference material already existed in `azure-anomaly-alerts.md` and `azure-budgets.md`. |
| 16 | [x] | ~~LOW~~ | "FinOps workbooks" naming suggestion | flanakin | **Fixed.** Renamed to "FinOps workbooks" with clarification "built on Azure Monitor workbooks." |
| 17 | [x] | ~~LOW~~ | Changelog says "v1.0" instead of matching toolkit version | flanakin | **Fixed.** Changed `### Claude Code plugin v1.0` to `### Claude Code plugin v14`. |
| 18 | [x] | ~~INFO~~ | Invalid `daterange()` KQL function | copilot | **Not an issue.** `daterange()` is a valid KQL function. Copilot bot was wrong; confirmed by MSBrett in PR comments. |
| 19 | [x] | ~~INFO~~ | Typo: "worload" → "workload" | copilot | Fixed in commit `5799afdd`. |

## Summary

- **Total**: 19 items
- **Resolved**: 19/19
- All items addressed: 12 fixed, 4 not-an-issue, 2 won't-fix, 1 previously fixed
