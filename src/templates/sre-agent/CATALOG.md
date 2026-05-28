# FinOps toolkit SRE Agent - framework alignment catalog

This catalog is the controlling reference for aligning the `recipes/finops-hub/` SRE Agent template to the FinOps Framework. Azure capacity-management content is included as implementation guidance under the relevant FinOps capabilities, not as a separate operating model. Framework names were checked against the FinOps Foundation references below on 2026-05-26. Keep the recipe content aligned to this file:

- Agent defaults: `recipes/finops-hub/agent.json`
- Expected inventory: `recipes/finops-hub/expected-config.json`
- Custom agents: `recipes/finops-hub/config/subagents/*.yaml`
- Skills: `recipes/finops-hub/config/skills/*/`
- Tools: `recipes/finops-hub/config/tools/*.yaml`
- Scheduled tasks: `recipes/finops-hub/automations/scheduled-tasks/*.yaml`
- Output style knowledge: `../claude-plugin/output-styles/ftk-output-style.md`

## Implemented inventory

| Component | Count | Source |
|-----------|------:|--------|
| Custom agents | 5 | Practitioner orchestrator plus four delegated subagents in `config/subagents/*.yaml` |
| Skills | 3 | `config/skills/*/` |
| Tools | 34 | `config/tools/*.yaml` |
| Tool overrides | 9 | `config/built-in-tools.json` |
| Scheduled tasks | 19 | All set `spec.agent: finops-practitioner` in `automations/scheduled-tasks/*.yaml` |
| Connectors | 1 | `connectors.json`: FinOps Hub Kusto |
| Knowledge docs | 6 | Five recipe knowledge files plus `../claude-plugin/output-styles/ftk-output-style.md` |

Tool mix:

| Tool type | Count |
|-----------|------:|
| KustoTool | 21 |
| PythonTool | 13 |
| MCP tool namespaces | 0 |

## Framework anchors

The recipe maps to these external operating models:

- FinOps Framework domains: Understand Usage & Cost, Quantify Business Value, Optimize Usage & Cost, and Manage the FinOps Practice.
- FinOps Framework capabilities: Data Ingestion, Allocation, Reporting & Analytics, Anomaly Management, Planning & Estimating, Forecasting, Budgeting, KPIs & Benchmarking, Unit Economics, Architecting & Workload Placement, Rate Optimization, Usage Optimization, Sustainability, Licensing & SaaS, FinOps Practice Operations, Governance, Policy & Risk, FinOps Assessment, Automation, Tools, & Services, FinOps Education & Enablement, Invoicing & Chargeback, and Intersecting Disciplines.
- Capabilities directly automated by this recipe: Data Ingestion, Allocation, Reporting & Analytics, Anomaly Management, Planning & Estimating, Forecasting, Budgeting, KPIs & Benchmarking, Unit Economics, Architecting & Workload Placement, Usage Optimization, Rate Optimization, FinOps Practice Operations, Governance, Policy & Risk, Automation, Tools, & Services, and Invoicing & Chargeback.
- Capabilities present as guidance or consultative context only: Sustainability, Licensing & SaaS, FinOps Assessment, FinOps Education & Enablement, and Intersecting Disciplines. The recipe does not ship scheduled tasks or specialist tools that directly implement these capabilities.
- Executive strategy alignment is treated as a leadership reporting outcome, not as a FinOps Framework capability.
- FinOps Framework principles: Teams need to collaborate, Business value drives technology decisions, Everyone takes ownership for their technology usage, FinOps data should be accessible, timely, and accurate, FinOps should be enabled centrally, and Take advantage of the variable cost model of the cloud.
- FinOps Framework personas: FinOps Practitioner coordinates the practice; Engineering owns technical usage and implementation; Finance and Leadership provide planning, decision rights, and business context; Product and Procurement contribute demand, value, and commitment context.
- FinOps Framework phases: Inform, Optimize, and Operate are iterative lenses applied to capabilities. They are not a replacement taxonomy and not a serial deployment order.
- Azure capacity management: capacity tooling is mapped into Planning & Estimating, Forecasting, Architecting & Workload Placement, Usage Optimization, Rate Optimization, Governance, Policy & Risk, and Automation, Tools, & Services. Capacity reservations guarantee supply; reservations and savings plans reduce rate. These are coordinated but not interchangeable.

Primary references:

- FinOps Framework domains: <https://www.finops.org/framework/domains/>
- FinOps Framework capabilities: <https://www.finops.org/framework/capabilities/>
- FinOps Framework principles: <https://www.finops.org/framework/principles/>
- FinOps Framework personas: <https://www.finops.org/framework/personas/>
- FinOps Framework phases: <https://www.finops.org/framework/phases/>
- Azure SRE Agent workflow automation: <https://learn.microsoft.com/azure/sre-agent/automate-workflows>
- Azure SRE Agent scheduled tasks: <https://learn.microsoft.com/azure/sre-agent/scheduled-tasks>
- Azure SRE Agent custom agents: <https://learn.microsoft.com/azure/sre-agent/sub-agents>
- Azure SRE Agent connectors: <https://learn.microsoft.com/azure/sre-agent/connectors>
- Microsoft SRE Agent repository and templates: <https://github.com/microsoft/sre-agent/>
- Azure capacity governance for ISVs: <https://microsoft.github.io/azcapman/>

## Agent operating model

Azure SRE Agent automation is modeled as connector-provided tools, custom agents with scoped tool access, and scheduled tasks that trigger the selected custom agent. Knowledge files are reference material; they do not grant tools. This recipe follows that model by assigning custom tools to the specialist that owns the capability, then routing every scheduled task to `finops-practitioner` so the practitioner owns the operating rhythm and delegates evidence collection.

All tool-bearing specialist agents include `SearchMemory` so they can read uploaded Knowledge Sources, including `ftk-output-style.md`, known issues, and prior operational notes. Specialist ownership still controls action scope: Kusto, capacity, and hubs responsibilities remain separated. The practitioner has no direct tools and delegates all evidence, visualization, delivery, and remediation work. `chief-financial-officer` has no tools and receives packaged evidence through practitioner handoff.

Scheduled reports must classify gaps before recommending action: product or deployment defects, data sufficiency limits, or customer-owned delegation. Sparse UAT Hub history, empty transaction diagnostics, or missing multi-period trigger evidence reduce confidence and should not be reported as product failure by themselves. Broader management group, billing, quota, or subscription access is customer-owned delegation unless this template explicitly owns that role assignment.

| Custom agent | Role in the operating model | Direct tool policy | FinOps / capacity alignment |
|----------|-----------------------------|--------------------|----------------------------|
| `finops-practitioner` | Practice lead and scheduled-report orchestrator. Owns the FinOps operating rhythm, applies the output style, frames business questions, routes evidence requests, and turns specialist outputs into actions. | No direct tools. Delegates Kusto evidence to `ftk-database-query`, capacity evidence to `azure-capacity-manager`, Hub platform and infrastructure checks to `ftk-hubs-agent`, and executive decision framing to `chief-financial-officer`. | FinOps Practitioner persona; central enablement; collaboration; Reporting & Analytics, Governance, Policy & Risk, Usage Optimization, Rate Optimization, and leadership strategy alignment. |
| `ftk-database-query` | FinOps Hub evidence specialist. Owns all Kusto/FOCUS query execution, Kusto result interpretation, schema guidance, and query diagnostics. | Owns every `KustoTool`. Does not own Azure CLI, Python capacity, infrastructure health, or remediation tools. No scheduled-task ownership. | Understand Usage & Cost; Data Ingestion, Allocation, Reporting & Analytics, Anomaly Management, pricing, recommendation, and commitment evidence. |
| `azure-capacity-manager` | Engineering and platform capacity specialist. Owns quota, region, zone, SKU, CRG, non-compute quota, database quota, AKS readiness, and capacity-to-rate coordination. | Owns capacity Python tools only. Does not own Kusto, Resource Graph, Hub freshness, Azure CLI, or remediation deployment tools. | Planning & Estimating, Forecasting, Architecting & Workload Placement, Usage Optimization, Rate Optimization support, Governance, Policy & Risk, and Automation, Tools, & Services. |
| `chief-financial-officer` | Consultative finance and leadership persona. Frames budget, forecast, commitment, risk, and investment tradeoffs for executive audiences. | Should not own scheduled tasks or raw data collection. Consumes evidence packages from `finops-practitioner` and specialists. | Finance and Leadership personas; Quantify Business Value; leadership strategy alignment; Budgeting, Forecasting, Unit Economics, investment decisions. |
| `ftk-hubs-agent` | FinOps Hub platform specialist. Owns hub health, deployment, upgrade, connector, export freshness, monitoring scope, and analytics-backend readiness. | Owns platform discovery, Resource Graph inventory, `data-freshness-check`, ADX SKU preflight, hub troubleshooting tools, and explicit remediation deployment tools. Does not own business cost-analysis reports. | Data Ingestion and Reporting & Analytics foundation; Automation, Tools, & Services; Governance, Policy & Risk. |

Hard boundaries:

- `finops-practitioner` must never query Kusto directly. Any prompt that needs `Costs()`, `Prices()`, `Recommendations()`, `Transactions()`, or a Kusto tool must delegate that evidence request to `ftk-database-query`.
- `finops-practitioner` has no direct tools. It must use handoffs for Kusto, capacity Python, Resource Graph, Hub infrastructure checks, visualization, delivery, and remediation.
- Every scheduled task must set `spec.agent: finops-practitioner`. Specialist agents are delegated subagents, not scheduled-task entrypoints.
- `chief-financial-officer` must not run autonomous scheduled tasks. Finance is a consulted persona for decisions and executive packaging, not the worker that gathers evidence.
- Capacity tasks must keep pricing commitments and capacity guarantees distinct. Use `azure-capacity-manager` for quota/CRG/access/SKU evidence and `ftk-database-query` for Kusto-backed rate and cost evidence.
- Remediation tools such as budget deployment, anomaly alert deployment, and Advisor suppression are interactive or explicitly approved remediation actions. Scheduled audits may recommend them but must not silently execute them.

## Source lineage

The SRE Agent recipe is an orchestration layer over the toolkit and azcapman assets, not a separate FinOps model.

| Source | Role in this recipe |
|--------|---------------------|
| `src/templates/claude-plugin/agents/*.md` and `src/templates/copilot-plugin/agents/*.agent.md` | Canonical toolkit agent personas for FinOps practitioner, FinOps Hub database, CFO, capacity, and hubs specialists. |
| `src/templates/agent-skills/finops-toolkit/` | Canonical FinOps Toolkit skill content and query catalog guidance used by the SRE recipe. |
| `src/templates/agent-skills/azure-cost-management/` | Canonical Azure Cost Management skill content for Advisor, budgets, anomaly alerts, savings plans, reservations, and related cost workflows. |
| `src/templates/sre-agent/submodules/azcapman/agents/azure-capacity-manager.md` | Canonical azcapman capacity specialist persona. |
| `src/templates/sre-agent/submodules/azcapman/skills/azure-capacity-management/` | Canonical azcapman capacity skill and references. The recipe uses symlinks; do not duplicate this content. |
| `src/queries/` | Canonical FinOps Hub Kusto query catalog. Custom Kusto tools must come from here first when a new query is needed. |
| `src/templates/claude-plugin/output-styles/ftk-output-style.md` | Shared FinOps Toolkit report style uploaded as SRE Agent knowledge and referenced by every scheduled task. |

## Custom agent capability matrix

This matrix is the reference for which custom agent owns each FinOps capability surface, which tools it can call directly, and which scheduled tasks it owns. It is derived from `src/templates/claude-plugin/agents/*.md`, `src/templates/copilot-plugin/agents/*.agent.md`, `src/templates/agent-skills/`, `src/templates/sre-agent/recipes/finops-hub/config/subagents/*.yaml`, `src/templates/sre-agent/submodules/azcapman/agents/azure-capacity-manager.md`, `src/templates/sre-agent/submodules/azcapman/skills/azure-capacity-management/SKILL.md`, and `src/queries/`.

| Custom agent | Persona / function | FinOps capabilities owned or directly implemented | Direct custom tools | Scheduled tasks owned | Required handoffs and consults |
|----------|--------------------|----------------------------------------------------|---------------------|---------------------|-------------------------------|
| `finops-practitioner` | FinOps Practitioner and operating-rhythm orchestrator. Leads practice cadence, report assembly, output style, and remediation approval flow. | Allocation, Reporting & Analytics orchestration, Anomaly Management orchestration, Budgeting, KPIs & Benchmarking, Unit Economics, Usage Optimization orchestration, Rate Optimization orchestration, FinOps Practice Operations, Governance, Policy & Risk, Automation, Tools, & Services, and Invoicing & Chargeback orchestration. | None. | All 19 scheduled tasks. | Must delegate all Kusto/FOCUS evidence to `ftk-database-query`; capacity, quota, SKU, zone, region, and CRG evidence to `azure-capacity-manager`; executive finance framing to `chief-financial-officer`; FinOps Hub platform readiness, Resource Graph, visualization, delivery, and infrastructure/remediation tooling to `ftk-hubs-agent`. |
| `ftk-database-query` | FinOps Hub evidence specialist. Owns Kusto, FOCUS, `Costs()`, `Prices()`, `Recommendations()`, and `Transactions()` evidence packages. | Data Ingestion evidence, Allocation evidence, Reporting & Analytics evidence, Anomaly Management evidence, Forecasting evidence, KPIs & Benchmarking evidence, Unit Economics evidence, Rate Optimization evidence, Usage Optimization evidence, Invoicing & Chargeback evidence. | `ai-cost-by-application`, `ai-daily-trend`, `ai-model-cost-comparison`, `ai-token-usage-breakdown`, `commitment-discount-utilization`, `cost-anomaly-detection`, `cost-by-financial-hierarchy`, `cost-by-region-trend`, `cost-forecasting-model`, `costs-enriched-base`, `monthly-cost-change-percentage`, `monthly-cost-trend`, `quarterly-cost-by-resource-group`, `reservation-recommendation-breakdown`, `savings-summary-report`, `service-price-benchmarking`, `top-commitment-transactions`, `top-other-transactions`, `top-resource-groups-by-cost`, `top-resource-types-by-cost`, `top-services-by-cost`. | None. This specialist is invoked by other scheduled tasks for evidence collection. | Returns evidence packages to `finops-practitioner`; does not own business recommendations, infrastructure checks, capacity evidence, or remediation decisions. |
| `azure-capacity-manager` | Engineering and platform capacity specialist sourced from the toolkit and azcapman. Owns Azure capacity, quota, SKU, region, zone, CRG, AKS, and non-compute limit evidence. | Planning & Estimating, Forecasting, Architecting & Workload Placement, Usage Optimization, Rate Optimization support, Governance, Policy & Risk, Automation, Tools, & Services. | `benefit-recommendations`, `sku-availability`, `vm-quota-usage`, `non-compute-quotas`, `db-service-quotas`, `capacity-reservation-groups`. | None. Invoked by `finops-practitioner` scheduled tasks for capacity evidence. | Returns capacity evidence to `finops-practitioner`. It does not query Kusto, run Resource Graph, check Hub freshness, or hand off to other agents. |
| `chief-financial-officer` | Finance and Leadership consultative persona. Frames budget, forecast, capital allocation, commitment risk, and executive tradeoffs. | Budgeting, Forecasting, KPIs & Benchmarking, Unit Economics, Rate Optimization decision framing, Invoicing & Chargeback framing, and leadership strategy alignment. | None. | None. Finance is consulted; it does not run autonomous scheduled tasks. | Consumes packaged evidence from `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager`, and `ftk-hubs-agent`. Must not query Kusto, collect raw telemetry, investigate capacity directly, or deliver reports. |
| `ftk-hubs-agent` | FinOps Hub platform specialist. Owns hub deployment, upgrade, health, connector, export, monitoring scope, analytics-backend readiness, Resource Graph inventory, and explicit remediation deployment tooling. | Data Ingestion platform readiness, Reporting & Analytics platform readiness, Automation, Tools, & Services, Governance, Policy & Risk. | `data-freshness-check`, `resource-graph-query`, `sku-availability`, `deploy-anomaly-alert`, `deploy-budget`, `deploy-bulk-anomaly-alerts`, `deploy-bulk-budgets`, `suppress-advisor-recommendations`. | None. Invoked by `finops-practitioner` scheduled tasks for Hub platform and infrastructure evidence. | Returns infrastructure evidence to `finops-practitioner`. It does not own business cost analysis, capacity evidence, or executive framing. |

## Capability coverage matrix

The phase column is a primary operating lens, not a workflow gate. Scheduled tasks can produce Inform evidence, Optimize recommendations, and Operate actions in a single run when that matches the task intent.

| FinOps capability | Domain | Primary phase lens | Recipe owner | Scheduled tasks | Primary tool families |
|-------------------|--------|--------------------|--------------|-----------------|-----------------------|
| Data Ingestion | Understand Usage & Cost | Inform | `ftk-hubs-agent`, `ftk-database-query` | `HubsHealthCheck`, `MonitoringScopeValidation`; evidence support for `Monthly` and `Semiannual` | `data-freshness-check`, FinOps Hub Kusto tools, Hub platform checks |
| Allocation | Understand Usage & Cost | Inform | `finops-practitioner`, `ftk-database-query` | `Monthly`, `Semiannual`, `AIWorkloadCostAnalysis` | `cost-by-financial-hierarchy`, `ai-cost-by-application`, resource inventory evidence |
| Reporting & Analytics | Understand Usage & Cost | Inform | `finops-practitioner`, `ftk-database-query` | `Monthly`, `Semiannual`, `CostOptimization`, `AIWorkloadCostAnalysis` | Cost trend, top-N, savings, pricing, AI, FinOps Hub Kusto evidence, visualization, and notification tools |
| Anomaly Management | Understand Usage & Cost | Inform / Operate | `finops-practitioner`, `ftk-database-query` | `AlertCoverageAudit`, `CostOptimization`, `Monthly`, `Semiannual` | `cost-anomaly-detection`, `deploy-anomaly-alert`, `deploy-bulk-anomaly-alerts`, `resource-graph-query` |
| Planning & Estimating | Quantify Business Value | Inform | `azure-capacity-manager`, `finops-practitioner` | `CapacityMonthlyPlanning`, `CapacityQuarterlyStrategy`, `StoragePaasGrowthForecast`, `Semiannual` | `vm-quota-usage`, `non-compute-quotas`, `capacity-reservation-groups`, `cost-forecasting-model` |
| Forecasting | Quantify Business Value | Inform | `azure-capacity-manager`, `ftk-database-query`, `finops-practitioner` | `CapacityMonthlyPlanning`, `StoragePaasGrowthForecast`, `Monthly`, `Semiannual` | `cost-forecasting-model`, `monthly-cost-trend`, quota and capacity trend tools |
| Budgeting | Quantify Business Value | Inform / Operate | `finops-practitioner`, `chief-financial-officer` | `BudgetCoverageAudit`, `Monthly`, `Semiannual` | `deploy-budget`, `deploy-bulk-budgets`, `monthly-cost-trend`, `cost-forecasting-model` |
| KPIs & Benchmarking | Quantify Business Value | Inform | `finops-practitioner`, `ftk-database-query`, `chief-financial-officer` | `Monthly`, `Semiannual`, `AIWorkloadCostAnalysis` | `service-price-benchmarking`, `savings-summary-report`, `ai-model-cost-comparison`, visualization tools |
| Unit Economics | Quantify Business Value | Inform | `finops-practitioner`, `ftk-database-query`, `chief-financial-officer` | `AIWorkloadCostAnalysis`, `Monthly`, `Semiannual` | AI token and model cost tools, `cost-by-financial-hierarchy`, `service-price-benchmarking` |
| Architecting & Workload Placement | Optimize Usage & Cost | Optimize | `azure-capacity-manager`, `finops-practitioner` | `CapacityWeeklySupplyReview`, `SkuAvailabilityAudit`, `ComputeUtilizationTrend`, `CapacityQuarterlyStrategy` | `sku-availability`, `resource-graph-query`, `vm-quota-usage`, `capacity-reservation-groups` |
| Rate Optimization | Optimize Usage & Cost | Optimize | `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager`, `chief-financial-officer` | `BenefitRecommendationReview`, `CapacityMonthlyPlanning`, `CapacityQuarterlyStrategy`, `Monthly`, `Semiannual` | `benefit-recommendations`, `commitment-discount-utilization`, `reservation-recommendation-breakdown`, `savings-summary-report`, `service-price-benchmarking` |
| Usage Optimization | Optimize Usage & Cost | Optimize | `finops-practitioner`, `azure-capacity-manager`, `ftk-database-query` | `CostOptimization`, `ComputeUtilizationTrend`, `CapacityDailyMonitor`, `CapacityWeeklySupplyReview` | `top-services-by-cost`, `top-resource-types-by-cost`, `resource-graph-query`, quota and CRG tools |
| Sustainability | Optimize Usage & Cost | Optimize | Guidance only through `finops-practitioner` | None | No direct recipe tool. Consider only when optimization decisions materially affect sustainability goals. |
| Licensing & SaaS | Optimize Usage & Cost | Optimize | Guidance only through `finops-practitioner` and `chief-financial-officer` | None | No direct recipe tool. Azure Hybrid Benefit evidence can appear in FinOps Hub cost data, but this recipe does not ship a Licensing & SaaS workflow. |
| FinOps Practice Operations | Manage the FinOps Practice | Operate | `finops-practitioner` | `Monthly`, `Semiannual`, all governance review tasks | Scheduled task cadence, output style, memory, Teams/Outlook delivery pattern |
| Governance, Policy & Risk | Manage the FinOps Practice | Operate | `finops-practitioner`, `azure-capacity-manager`, `ftk-hubs-agent` | `AdvisorSuppressionReview`, `AlertCoverageAudit`, `BudgetCoverageAudit`, `CapacityDailyMonitor`, `MonitoringScopeValidation` | `resource-graph-query`, budget/anomaly deployment tools, suppression tools, quota tools |
| FinOps Assessment | Manage the FinOps Practice | Operate | Guidance only through `finops-practitioner` | None | No direct recipe tool. Assessment is advisory unless a future task is added. |
| Automation, Tools, & Services | Manage the FinOps Practice | Operate | `finops-practitioner`, `azure-capacity-manager`, `ftk-hubs-agent` | All scheduled tasks | Scheduled tasks, custom tools, built-in visualization tools, Teams and Outlook connector tools |
| FinOps Education & Enablement | Manage the FinOps Practice | Operate | Guidance only through `finops-practitioner` | None | No direct recipe tool. Knowledge files support agent context but are not a training workflow. |
| Invoicing & Chargeback | Manage the FinOps Practice | Operate | `finops-practitioner`, `ftk-database-query`, `chief-financial-officer` | `Monthly`, `Semiannual` | `cost-by-financial-hierarchy`, transaction tools, monthly trend and allocation evidence |
| Intersecting Disciplines | Manage the FinOps Practice | Operate | Guidance only through `finops-practitioner` | None | No direct recipe tool. Security, ITSM, ITFM, ITAM, and sustainability intersections are consultative context. |

## Skills

| Skill | Path |
|-------|------|
| `azure-capacity-management` | `config/skills/azure-capacity-management/` |
| `azure-cost-management` | `config/skills/azure-cost-management/` |
| `finops-toolkit` | `config/skills/finops-toolkit/` |

## Scheduled task ownership map

| Task | Owning agent | Schedule | Framework alignment | Required delegates and consults |
|------|------------|----------|---------------------|----------------------------------|
| `HubsHealthCheck` | `finops-practitioner` | `0 6 * * *` | Understand Usage & Cost: Data Ingestion; Manage the FinOps Practice: Automation, Tools, & Services | Delegates Hub platform evidence to `ftk-hubs-agent`. |
| `CapacityDailyMonitor` | `finops-practitioner` | `30 6 * * *` | Automation, Tools, & Services; Usage Optimization; Governance, Policy & Risk | Delegates capacity evidence to `azure-capacity-manager`; no CFO consult. |
| `ComputeUtilizationTrend` | `finops-practitioner` | `0 7 * * 1` | Usage Optimization; Planning & Estimating; Forecasting | Delegates capacity and inventory evidence to `azure-capacity-manager`. |
| `CostOptimization` | `finops-practitioner` | `0 8 * * 1` | Optimize Usage & Cost: Usage Optimization and Rate Optimization; Manage the FinOps Practice: Governance, Policy & Risk | Delegates Kusto evidence to `ftk-database-query`; delegates quota/capacity feasibility to `azure-capacity-manager`; consults `chief-financial-officer` for commitment and priority framing when decisions are material. |
| `CapacityWeeklySupplyReview` | `finops-practitioner` | `0 8 * * 1` | Planning & Estimating; Forecasting; Architecting & Workload Placement; Usage Optimization; Rate Optimization support | Delegates capacity evidence to `azure-capacity-manager`; asks `ftk-database-query` for Kusto-backed commitment, savings, and forecast evidence. |
| `NonComputeQuotaAudit` | `finops-practitioner` | `0 7 * * 2` | Automation, Tools, & Services; Governance, Policy & Risk | Delegates non-compute quota evidence to `azure-capacity-manager`. |
| `DbQuotaAudit` | `finops-practitioner` | `0 7 * * 3` | Automation, Tools, & Services; Governance, Policy & Risk | Delegates database quota evidence to `azure-capacity-manager`. |
| `SkuAvailabilityAudit` | `finops-practitioner` | `30 7 * * 3` | Planning & Estimating; Architecting & Workload Placement; region and SKU readiness | Delegates SKU availability evidence to `azure-capacity-manager`; consults `ftk-hubs-agent` only for FinOps Hub ADX backend deployment readiness. |
| `MonitoringScopeValidation` | `finops-practitioner` | `0 9 * * 4` | Understand Usage & Cost: Data Ingestion and Reporting & Analytics foundation | Delegates Hub platform and inventory evidence to `ftk-hubs-agent`. |
| `BenefitRecommendationReview` | `finops-practitioner` | `0 8 * * 5` | Optimize Usage & Cost: Rate Optimization; Quantify Business Value | Delegates Kusto recommendation/utilization evidence to `ftk-database-query`; consults `chief-financial-officer` for approval framing and commitment risk. |
| `AdvisorSuppressionReview` | `finops-practitioner` | `0 9 1 * *` | Optimize Usage & Cost; Governance, Policy & Risk | Uses inventory/governance evidence; remediation requires explicit approval. |
| `AIWorkloadCostAnalysis` | `finops-practitioner` | `0 10 1 * *` | Quantify Business Value: Unit Economics; Understand Usage & Cost: Reporting & Analytics; leadership strategy alignment for AI | Delegates AI cost Kusto evidence to `ftk-database-query`; delegates GPU/capacity evidence to `azure-capacity-manager`; consults `chief-financial-officer` for investment and unit-economics framing. |
| `CapacityMonthlyPlanning` | `finops-practitioner` | `0 9 1 * *` | Planning & Estimating; Forecasting; Budgeting support; Architecting & Workload Placement | Delegates capacity evidence to `azure-capacity-manager`; asks `ftk-database-query` for Kusto-backed forecast/rate context; may consult `chief-financial-officer` for budget guardrails. |
| `StoragePaasGrowthForecast` | `finops-practitioner` | `0 8 1 * *` | Planning & Estimating; Forecasting; Automation, Tools, & Services | Delegates non-compute and inventory evidence to `azure-capacity-manager`. |
| `Monthly` | `finops-practitioner` | `15 17 5 * *` | Understand Usage & Cost: Reporting & Analytics and Anomaly Management; Optimize Usage & Cost: Usage Optimization and Rate Optimization | Delegates all Kusto evidence to `ftk-database-query`; delegates capacity risk evidence to `azure-capacity-manager`; consults `chief-financial-officer` for material commitment or forecast decisions. |
| `Semiannual` | `finops-practitioner` | `0 9 5 1,7 *` | Quantify Business Value: Forecasting, Budgeting, KPIs & Benchmarking; Manage the FinOps Practice leadership reporting | Delegates fiscal Kusto evidence to `ftk-database-query`; delegates capacity risk evidence to `azure-capacity-manager` where needed; consults `chief-financial-officer` for executive report framing. |
| `BudgetCoverageAudit` | `finops-practitioner` | `0 8 15 * *` | Quantify Business Value: Budgeting; Manage the FinOps Practice: Governance, Policy & Risk | Uses governance inventory; budget deployment requires explicit approval. |
| `AlertCoverageAudit` | `finops-practitioner` | `0 8 16 * *` | Understand Usage & Cost: Anomaly Management; Manage the FinOps Practice: Governance, Policy & Risk and Automation, Tools, & Services | Uses governance inventory; anomaly alert deployment requires explicit approval. |
| `CapacityQuarterlyStrategy` | `finops-practitioner` | `0 9 1 1,4,7,10 *` | Leadership strategy alignment; Planning & Estimating; Forecasting; Architecting & Workload Placement; Rate Optimization support | Delegates strategic capacity evidence to `azure-capacity-manager`; asks `ftk-database-query` for Kusto-backed cost/rate evidence; consults `chief-financial-officer` for portfolio tradeoff framing. |

## Tool inventory

### Kusto tools

All Kusto tools are owned by `ftk-database-query`. Other agents request Kusto evidence from that specialist instead of calling these tools directly.

| Tool | Purpose |
|------|---------|
| `ai-cost-by-application` | Breaks down Azure OpenAI costs by application, team, and environment tags. |
| `ai-daily-trend` | Reports daily Azure OpenAI cost and token consumption trends. |
| `ai-model-cost-comparison` | Compares cost per 1K tokens across Azure OpenAI model versions. |
| `ai-token-usage-breakdown` | Breaks Azure OpenAI token consumption down by model version and input/output direction. |
| `commitment-discount-utilization` | Analyzes consumed core hours by commitment discount type. |
| `cost-anomaly-detection` | Detects cost spikes and drops over a configurable history window. |
| `cost-by-financial-hierarchy` | Summarizes costs across billing profile, invoice section, team, product, application, and environment. |
| `cost-by-region-trend` | Summarizes effective cost by Azure region. |
| `cost-forecasting-model` | Forecasts future effective cost from historical cost data. |
| `costs-enriched-base` | Returns enriched row-level cost and usage samples for drill-down analysis. |
| `monthly-cost-change-percentage` | Calculates month-over-month billed and effective cost change. |
| `monthly-cost-trend` | Returns billed and effective cost totals by month. |
| `quarterly-cost-by-resource-group` | Returns top resource-group cost rows by subscription and month. |
| `reservation-recommendation-breakdown` | Analyzes Microsoft reservation recommendations from `Recommendations()`. |
| `savings-summary-report` | Summarizes list cost, effective cost, negotiated discount savings, commitment savings, and effective savings rate. |
| `service-price-benchmarking` | Benchmarks services by list, contracted, and effective cost. |
| `top-commitment-transactions` | Returns top non-usage commitment discount purchase transactions. |
| `top-other-transactions` | Returns top non-usage, non-commitment purchase transactions. |
| `top-resource-groups-by-cost` | Returns top resource groups by effective cost. |
| `top-resource-types-by-cost` | Returns top resource types by count and effective cost. |
| `top-services-by-cost` | Returns top Azure services by effective cost. |

### Built-in tools

The recipe enables SRE Agent platform tools through `config/built-in-tools.json` during post-provisioning. These are platform tools, not custom recipe tools. FinOps Hub database access remains owned by the custom Kusto tools assigned to `ftk-database-query`.

| Category | Enabled tools |
|----------|---------------|
| Log Query | `QueryLogAnalyticsByWorkspaceId`, `QueryAppInsightsByAppId`, `QueryAppInsightsByResourceId`, `QueryLogAnalyticsByResourceId` |
| Visualization | `PlotScatter`, `PlotHeatmap`, `PlotBarChart`, `PlotPieChart`, `PlotAreaChartWithCorrelation` |

### Custom Azure and Hub tools

| Tool | Assigned agents | Purpose |
|------|-----------------|---------|
| `benefit-recommendations` | `azure-capacity-manager` | Gets Cost Management benefit recommendations for savings plans and reserved instances. |
| `capacity-reservation-groups` | `azure-capacity-manager` | Lists capacity reservation groups and reports reserved versus allocated capacity. |
| `data-freshness-check` | `ftk-hubs-agent` | Checks FinOps Hub function data freshness through Azure Data Explorer REST queries. |
| `db-service-quotas` | `azure-capacity-manager` | Reports SQL DB, SQL MI, Cosmos DB, PostgreSQL Flex, and MySQL Flex quota and region access signals. |
| `deploy-anomaly-alert` | `ftk-hubs-agent` | Creates or updates a Cost Management scheduled action for anomaly detection after explicit remediation approval. |
| `deploy-budget` | `ftk-hubs-agent` | Creates or updates a subscription-level Cost Management budget after explicit remediation approval. |
| `deploy-bulk-anomaly-alerts` | `ftk-hubs-agent` | Creates or updates anomaly alert scheduled actions across subscriptions discovered from a management group after explicit remediation approval. |
| `deploy-bulk-budgets` | `ftk-hubs-agent` | Creates or updates Cost Management budgets across subscriptions discovered from a management group after explicit remediation approval. |
| `non-compute-quotas` | `azure-capacity-manager` | Checks non-compute Azure service quota utilization. |
| `resource-graph-query` | `ftk-hubs-agent` | Runs Azure Resource Graph KQL across one or more subscriptions. |
| `sku-availability` | `azure-capacity-manager`, `ftk-hubs-agent` | Lists regional SKU availability for Azure Compute or Azure Data Explorer. |
| `suppress-advisor-recommendations` | `ftk-hubs-agent` | Suppresses selected Azure Advisor recommendations across subscriptions under a management group after explicit remediation approval. |
| `vm-quota-usage` | `azure-capacity-manager` | Reports Azure VM family quota usage and quota risk by subscription and region. |

## Operating notes

- The Kusto connector is applied by `bin/post-provision.sh` through the SRE Agent data plane when a Kusto URI is provided. The Bicep deployment grants the agent managed identity `AllDatabasesViewer` on the Azure Data Explorer cluster before the Kusto connector is created. This is required because the Hub functions can resolve cross-database references such as `Ingestion`. `finops-hub-kusto` supports the recipe's custom query tools. Scheduled tasks are applied by the same helper using `srectl`.
- The portal Team onboarding wizard is part of the expected customer flow and must not be bypassed. The deployment supports it by adding the agent resource group, explicit target resource groups, and same-subscription FinOps Hub resource group to the agent managed-resource scope, then assigning the agent identity target-scope RBAC for Azure Resource Graph and Azure CLI discovery.
- When the target Azure Data Explorer cluster denies public query access, `bin/deploy.sh` still deploys all resources, grants cluster `AllDatabasesViewer`, and creates the connector, then warns that private endpoint ADX blocks direct KQL queries from the hosted SRE Agent and links to the SRE Agent known limitations.
- The SRE Agent resource is deployed with `Microsoft.App/agents@2026-01-01`, `upgradeChannel: Stable`, `experimentalSettings.EnableSandboxGroup`, and `experimentalSettings.EnableWorkspaceTools`.
- `bin/post-provision.sh` uploads `ftk-output-style.md` from the Claude plugin output styles as a portal-visible `KnowledgeFile` source and verifies the expected KnowledgeFile sources are indexed. Every scheduled task explicitly applies that style for report, Teams-message, and Outlook-email output.
- `README.md` carries the deployment workflow; this file carries the detailed implemented recipe inventory.
- Add or remove scheduled task YAML, tool YAML, subagent YAML, or skill directories first, then update this catalog and `README.md` in the same change.
