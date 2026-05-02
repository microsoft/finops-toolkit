# FinOps toolkit SRE Agent UAT plan

## Problem statement

Productize the FinOps toolkit SRE Agent as a trustworthy new FinOps Toolkit feature without relying on ad hoc live deployments. UAT must prove that the repo-defined feature surface is coherent, testable, and complete enough to ship as product: agents, tools, scheduled tasks, connector wiring, and lab-backed scenarios must all line up.

## Current baseline

Grounded from the main repo README, `src/templates/sre-agent/README.md`, `src/templates/sre-agent/CATALOG.md`, current SRE config, and domain-agent briefs.

- **Current shipped SRE surface**
  - 5 agents: `finops-practitioner`, `azure-capacity-manager`, `chief-financial-officer`, `ftk-database-query`, `ftk-hubs-agent`
  - 21 tool YAMLs under `src/templates/sre-agent/tools/`
  - 9 scheduled task YAMLs under `src/templates/sre-agent/sre-config/scheduled-tasks/`
  - 1 connector YAML: `sre-config/connectors/finops-hub-kusto.yaml`
  - 4 azcapman labs in `src/templates/sre-agent/submodules/azcapman/labs/`

- **Target operating model**
  - Repo-first product feature
  - No direct/manual deployment as the delivery mechanism
  - Living documentation in `src/templates/sre-agent/README.md`
  - Scheduled-task catalog in `CATALOG.md` is broader than the currently shipped task set

- **Known gaps already visible**
  - `CATALOG.md` identifies multiple **NEW TOOL NEEDED** items that are not yet productized
  - Missing quota-generalized tool path (`Get-AzQuota.ps1` or equivalent wrapper) even though quota/capacity is a core scenario
  - ~~`post-provision.sh` currently applies skills, agents, tools, scheduled tasks, and repo connector, but does **not** currently upload knowledge docs or apply the FinOps Hub connector despite README claims~~ **FIXED** — knowledge upload and Kusto connector now automated
  - README/catalog/current YAMLs are not yet fully synchronized
  - UAT coverage must distinguish **currently shipped** capabilities from **catalog target** capabilities

## UAT goals

1. Evaluate what has been built so far against the repo-defined feature surface.
2. Validate that every checked-in scheduled task is correct, runnable, and mapped to real tools and agents.
3. Verify that all shipped tools are actually used by at least one scenario, task, or lab-backed workflow.
4. Add critical missing tools, starting with quota/capacity gaps such as `Get-AzQuota.ps1`.
5. Map the azcapman labs into SRE Agent scenarios so the feature can exercise the same capabilities through the agent experience.
6. Keep `src/templates/sre-agent/README.md` updated as the living feature doc while work progresses.

## UAT workstreams

### 1. Baseline evaluation

Establish the authoritative inventory and identify drift between:

- `src/templates/sre-agent/README.md`
- `src/templates/sre-agent/CATALOG.md`
- `src/templates/sre-agent/sre-config/**`
- `src/templates/sre-agent/tools/**`
- `src/templates/sre-agent/scripts/post-provision.sh`
- `src/templates/sre-agent/submodules/azcapman/labs/**`

Deliverable:

- A traceability matrix covering agent -> skill/tool -> scheduled task -> connector -> lab/use case

### 2. Scheduled task validation

UAT every checked-in scheduled task as product content, not just YAML presence:

- Schema validity
- `agent` exists
- referenced tools exist
- prompt assumptions are repo-compatible
- cron fields align with the automation script contract
- expected outputs and failure modes are documented

Priority task set:

- `HubsHealthCheck`
- `CostOptimization`
- `CapacityDailyMonitor`
- `CapacityWeeklySupplyReview`
- `CapacityMonthlyPlanning`
- `CapacityQuarterlyStrategy`
- `MomReport`
- `YtdReport`
- `AiWorkloadCostAnalysis`

Deliverable:

- A scheduled-task UAT matrix with pass criteria, dependencies, and missing-tool blockers

### 3. Tool coverage and gap closure

Validate the 21 currently shipped tools first, then close critical catalog gaps.

Current shipped tools should be grouped and tested by scenario:

- FinOps core: anomaly, trend, hierarchy, forecasting, savings, commitments
- CFO: budget/forecast/showback/AI economics
- Capacity: quota, reservations, CRGs, zone mapping, forecasting
- Data: Hub DB queries, freshness, FOCUS correctness

Critical missing tool backlog starts with:

- `Get-AzQuota.ps1` or canonical quota wrapper/tooling path
- `data-freshness-monitor`
- `focus-compliance-check`
- `budget-vs-actual-comparison`
- `tag-compliance-report`
- `quota-usage-analysis`
- `zone-mapping-analysis`
- `crg-utilization-trend`
- `crg-billing-waste`

Deliverable:

- Tool coverage matrix showing shipped tools, used-by scenarios, and missing-tool backlog

### 4. Lab enablement through the SRE Agent

Convert existing azcapman lab capabilities into SRE Agent scenarios:

- `lab-02-forecasting.md`
- `lab-03-allocation.md`
- `lab-04-procurement.md`
- `lab-05-monitoring-governance.md`

Priority mapping:

1. Monitoring/governance -> `ftk-hubs-agent`, `finops-practitioner`, `chief-financial-officer`
2. Forecasting -> `chief-financial-officer`, `ftk-database-query`
3. Procurement -> `azure-capacity-manager`, `chief-financial-officer`
4. Allocation -> `finops-practitioner`, `ftk-database-query`

Deliverable:

- Repo scenarios/tasks/prompts that reproduce the lab outcomes through the SRE agent surface

### 5. Connector and post-provision wiring

Validate and close the gap between documentation and automation for:

- `finops-hub-kusto` connector application
- knowledge/reference content upload
- B2B tenant guidance for `srectl`
- task/tool/connector preconditions

Deliverable:

- README-aligned automation behavior and explicit prerequisites/failure-mode documentation

### 6. Living documentation

Update `src/templates/sre-agent/README.md` as milestones land:

- current shipped surface
- UAT scope
- known prerequisites
- B2B auth guidance
- lab-to-agent coverage
- scheduled-task/tool coverage status

Deliverable:

- README stays aligned with the actual repo state, not aspirational behavior

## Agent-specific UAT focus

### FinOps practitioner

- Cost anomaly investigation
- showback/chargeback
- rightsizing and waste detection
- savings and optimization workflows
- FinOps practice maturity/reporting scenarios

### Azure capacity manager

- quota usage and headroom
- quota groups
- CRG utilization and waste
- zone mapping
- region access and procurement readiness
- commitment/capacity alignment

### Chief financial officer

- budget burn-rate
- forecast drift
- savings summary
- executive/QBR narratives
- unit economics and AI cost reporting

### FTK database query

- KQL correctness
- Hub vs Ingestion usage
- function selection (`Costs`, `Prices`, `Recommendations`, `Transactions`)
- freshness and FOCUS validation

### FTK hubs agent

- hub version checks
- export freshness
- connector readiness
- deployment/connectivity troubleshooting guidance

## Proposed backlog / sequencing

### Phase 1 — inventory and contract

1. Build the SRE UAT traceability matrix.
2. Reconcile README, catalog, current config, and post-provision behavior.
3. Define acceptance criteria per agent, per tool family, and per scheduled task.

### Phase 2 — shipped content validation

4. Validate all 9 checked-in scheduled tasks.
5. Build the tool-usage coverage map for the 21 shipped tools.
6. Validate current connector and hub preconditions from the repo perspective.

### Phase 3 — close priority product gaps

7. Productize quota coverage, starting with `Get-AzQuota.ps1` or equivalent quota wrapper.
8. Add the high-priority missing tools from `CATALOG.md`.
9. Close transaction/query correctness and data-freshness validation gaps.

### Phase 4 — lab enablement

10. Map each azcapman lab into one or more SRE-agent-backed scenarios.
11. Add prompts/tasks/tests/docs for those lab-derived scenarios.

### Phase 5 — documentation and exit

12. Keep `src/templates/sre-agent/README.md` synchronized as work lands.
13. Define UAT exit criteria for “repo-complete, ready for validation”.

## Acceptance criteria for the plan

The UAT effort is credible only if:

- every shipped agent, scheduled task, tool, and connector is covered by a traceable test scenario
- every scheduled task references real, testable tools and valid repo content
- every shipped tool is exercised by at least one scenario or task
- critical missing tools are either implemented or explicitly tracked as blockers
- azcapman labs are represented as agent-driven product scenarios
- README and automation behavior do not drift

## Notes

- Treat the README as the living product contract and update it incrementally as work lands.
- Keep “currently shipped” and “catalog target” separated in all UAT materials.
- Browser-visible agent health and repo-defined product completeness are different validation dimensions; both matter.
## Progress log

### Completed — Workstream 5 (Connector and post-provision wiring)

- ✅ `post-provision.sh` and `.ps1` upload `sre-config/knowledge/` with `srectl doc upload`
- ✅ Kusto connector provisioned via Bicep (`finops-hub-kusto` dataConnector resource)
- ✅ B2B tenant guidance documented in README
- ✅ Outlook/Teams manual-setup limitation researched and documented in README
- ✅ Knowledge upload implemented — onboarding-recommendations.md steers onboarding

### Completed — Workstream 6 (Living documentation)

- ✅ README updated with: packaged deploy scripts, B2B tenant note, built-in capabilities, Outlook/Teams setup, knowledge upload, architecture diagram, repo structure
- ✅ `experimentalSettings` documented and enforced in Bicep + tests
- ✅ `execute_python` enabled on analytical subagents and enforced in tests

### Completed — Packaging and redistribution

- ✅ `scripts/deploy.sh` and `scripts/deploy.ps1` — single packaged entrypoint
- ✅ `--clone-env` mode
- ✅ B2B tenant fix: `az account set --subscription` before `azd up`
- ✅ Clone-env identity leak fixed
- ✅ Tests enforce packaged deploy scripts (TC-4.1a)

### Completed — test-3 deployment validation

- ✅ `ftk-sre-test3` deployed via `deploy.sh`
- ✅ Infra: agent + identity + Log Analytics + App Insights
- ✅ Post-provision: 3 skills, 5 agents, 21 tools, 1 knowledge doc, 9 scheduled tasks, 1 repo connector
- ✅ Agent: `sre-agent-dl4veickx4bpg`
- ✅ `ftk-sre-test2` Azure RG deleted

### Completed — Teams notification UAT

- ✅ Teams connector confirmed working via `PostTeamsMessage` built-in tool
- ✅ Critical finding: direct Graph API / dynamicInvoke calls fail with 403 — must use built-in PostTeamsMessage tool
- ✅ Critical finding: Review mode blocks all autonomous tool execution — switched to Autonomous mode in Bicep
- ✅ Knowledge docs added: `teams-notification-guide.md` with correct/incorrect patterns
- ✅ Duplicate scheduled task bug fixed: `post-provision.sh` now uses `srectl scheduledtask apply` (idempotent)
- ✅ **All 9/9 scheduled tasks executed and delivered final reports to Teams channel**
- ✅ 11 total Teams messages confirmed (test + 9 task reports + MOM cron-triggered)

### Remaining — Workstream 1 (Baseline evaluation)

- ⬜ Build the SRE UAT traceability matrix
- ⬜ Reconcile README, CATALOG.md, current config, and post-provision behavior

### Remaining — Workstream 2 (Scheduled task validation)

- ⬜ Validate all 9 scheduled tasks run correctly against live agent
- ⬜ Confirm each task's agent, tools, and prompt are correct in the live environment

### Remaining — Workstream 3 (Tool coverage and gap closure)

- ⬜ Build tool-usage coverage map for the 21 shipped tools
- ⬜ Productize `Get-AzQuota.ps1` or equivalent quota wrapper
- ⬜ Add high-priority missing tools from CATALOG.md

### Remaining — Workstream 4 (Lab enablement)

- ⬜ Map azcapman labs into SRE-agent-backed scenarios
- ⬜ Add prompts/tasks/tests for lab-derived scenarios
