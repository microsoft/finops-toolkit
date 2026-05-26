# FinOps toolkit SRE Agent - framework alignment catalog

This catalog is the controlling reference for aligning the `recipes/finops-hub/` SRE Agent template to the FinOps Framework. Azure capacity-management content is included as implementation guidance under the relevant FinOps capabilities, not as a separate operating model. Keep the recipe content aligned to this file:

- Agent defaults: `recipes/finops-hub/agent.json`
- Expected inventory: `recipes/finops-hub/expected-config.json`
- Subagents: `recipes/finops-hub/config/subagents/*.yaml`
- Skills: `recipes/finops-hub/config/skills/*/`
- Tools: `recipes/finops-hub/config/tools/*.yaml`
- Scheduled tasks: `recipes/finops-hub/automations/scheduled-tasks/*.yaml`
- Output style knowledge: `../claude-plugin/output-styles/ftk-output-style.md`

## Implemented inventory

| Component | Count | Source |
|-----------|------:|--------|
| Subagents | 5 | `config/subagents/*.yaml` |
| Skills | 3 | `config/skills/*/` |
| Tools | 34 | `config/tools/*.yaml` |
| Tool overrides | 9 | `config/built-in-tools.json` |
| Scheduled tasks | 19 | `automations/scheduled-tasks/*.yaml` |
| Connectors | 1 | `connectors.json` |
| Knowledge docs | 6 | Five recipe knowledge files plus `../claude-plugin/output-styles/ftk-output-style.md` |

Tool mix:

| Tool type | Count |
|-----------|------:|
| KustoTool | 21 |
| PythonTool | 13 |

## Framework anchors

The recipe maps to these external operating models:

- FinOps Framework domains: Understand Usage & Cost, Quantify Business Value, Optimize Usage & Cost, and Manage the FinOps Practice.
- FinOps Framework capabilities used by this recipe: Data Ingestion, Allocation, Reporting & Analytics, Anomaly Management, Planning & Estimating, Forecasting, Budgeting, KPIs & Benchmarking, Unit Economics, Architecting & Workload Placement, Usage Optimization, Rate Optimization, Governance, Policy & Risk, Automation, Tools & Services, FinOps Education & Enablement, and Executive Strategy Alignment.
- FinOps Framework principles: Teams need to collaborate, Business value drives technology decisions, Everyone takes ownership for their technology usage, FinOps data should be accessible, timely, and accurate, FinOps should be enabled centrally, and Take advantage of the variable cost model of the cloud.
- FinOps Framework personas: FinOps Practitioner coordinates the practice; Engineering owns technical usage and implementation; Finance and Leadership provide planning, decision rights, and business context; Product and Procurement contribute demand, value, and commitment context.
- Azure capacity management: capacity tooling is mapped into Planning & Estimating, Forecasting, Architecting & Workload Placement, Usage Optimization, Rate Optimization, Governance, Policy & Risk, and Automation, Tools & Services. Capacity reservations guarantee supply; reservations and savings plans reduce rate. These are coordinated but not interchangeable.

Primary references:

- FinOps Framework domains: <https://www.finops.org/framework/domains/>
- FinOps Framework capabilities: <https://www.finops.org/framework/capabilities/>
- FinOps Framework principles: <https://www.finops.org/framework/principles/>
- FinOps Framework personas: <https://www.finops.org/framework/personas/>
- Azure capacity governance for ISVs: <https://microsoft.github.io/azcapman/>

## Agent operating model

All subagents include `SearchMemory` so each agent can read uploaded Knowledge Sources, including `ftk-output-style.md`, known issues, and prior operational notes. Specialist ownership still controls action scope: memory access is shared, but Kusto, capacity, hubs, and finance responsibilities remain separated.

| Subagent | Role in the operating model | Direct tool policy | FinOps / capacity alignment |
|----------|-----------------------------|--------------------|----------------------------|
| `finops-practitioner` | Practice lead and scheduled-report orchestrator. Owns the FinOps operating rhythm, applies the output style, frames business questions, routes evidence requests, and turns specialist outputs into actions. | Must not call Kusto tools. May use non-Kusto governance/remediation tools only when the prompt is explicitly about that workflow and remediation has approval. Delegates evidence gathering to `ftk-database-query` and `azure-capacity-manager`; consults `chief-financial-officer` for executive decision framing. | FinOps Practitioner persona; central enablement; collaboration; Reporting & Analytics, Governance, Policy & Risk, Usage Optimization, Rate Optimization, and Executive Strategy Alignment. |
| `ftk-database-query` | FinOps Hub evidence specialist. Owns all Kusto/FOCUS query execution, Kusto result interpretation, schema guidance, freshness caveats, and query diagnostics. | Owns every `KustoTool` plus `data-freshness-check` for Hub freshness. No scheduled-task ownership. | Understand Usage & Cost; Data Ingestion, Allocation, Reporting & Analytics, Anomaly Management, pricing, recommendation, and commitment evidence. |
| `azure-capacity-manager` | Engineering and platform capacity specialist. Owns quota, region, zone, SKU, CRG, non-compute quota, database quota, AKS readiness, and capacity-to-rate coordination. | Owns capacity Python tools and Azure inventory tools. Uses `ftk-database-query` for Kusto-backed cost, commitment, and forecast evidence. | Planning & Estimating, Forecasting, Architecting & Workload Placement, Usage Optimization, Rate Optimization support, Governance, Policy & Risk, and Automation, Tools & Services. |
| `chief-financial-officer` | Consultative finance and leadership persona. Frames budget, forecast, commitment, risk, and investment tradeoffs for executive audiences. | Should not own scheduled tasks or raw data collection. Consumes evidence packages from `finops-practitioner` and specialists. | Finance and Leadership personas; Quantify Business Value; Executive Strategy Alignment; Budgeting, Forecasting, Unit Economics, investment decisions. |
| `ftk-hubs-agent` | FinOps Hub platform specialist. Owns hub health, deployment, upgrade, connector, export freshness, monitoring scope, and analytics-backend readiness. | Owns platform discovery, `data-freshness-check`, ADX SKU preflight, and hub troubleshooting tools. Does not own business cost-analysis reports. | Data Ingestion and Reporting & Analytics foundation; Automation, Tools & Services; Governance, Policy & Risk. |

Hard boundaries:

- `finops-practitioner` must never query Kusto directly. Any prompt that needs `Costs()`, `Prices()`, `Recommendations()`, `Transactions()`, or a Kusto tool must delegate that evidence request to `ftk-database-query`.
- `chief-financial-officer` must not run autonomous scheduled tasks. Finance is a consulted persona for decisions and executive packaging, not the worker that gathers evidence.
- Capacity tasks must keep pricing commitments and capacity guarantees distinct. Use `azure-capacity-manager` for quota/CRG/access/SKU evidence and `ftk-database-query` for Kusto-backed rate and cost evidence.
- Remediation tools such as budget deployment, anomaly alert deployment, and Advisor suppression are interactive or explicitly approved remediation actions. Scheduled audits may recommend them but must not silently execute them.

## Skills

| Skill | Path |
|-------|------|
| `azure-capacity-management` | `config/skills/azure-capacity-management/` |
| `azure-cost-management` | `config/skills/azure-cost-management/` |
| `finops-toolkit` | `config/skills/finops-toolkit/` |

## Scheduled task ownership map

| Task | Lead agent | Schedule | Framework alignment | Required delegates and consults |
|------|------------|----------|---------------------|----------------------------------|
| `HubsHealthCheck` | `ftk-hubs-agent` | `0 6 * * *` | Understand Usage & Cost: Data Ingestion; Manage the FinOps Practice: Automation, Tools & Services | Uses hub platform tools directly. |
| `CapacityDailyMonitor` | `azure-capacity-manager` | `30 6 * * *` | Automation, Tools & Services; Usage Optimization; Governance, Policy & Risk | Uses capacity tools directly; no CFO consult. |
| `ComputeUtilizationTrend` | `azure-capacity-manager` | `0 7 * * 1` | Usage Optimization; Planning & Estimating; Forecasting | Uses capacity and inventory tools directly. |
| `CostOptimization` | `finops-practitioner` | `0 8 * * 1` | Optimize Usage & Cost: Usage Optimization and Rate Optimization; Manage the FinOps Practice: Governance, Policy & Risk | Delegates Kusto evidence to `ftk-database-query`; delegates quota/capacity feasibility to `azure-capacity-manager`; consults `chief-financial-officer` for commitment and priority framing when decisions are material. |
| `CapacityWeeklySupplyReview` | `azure-capacity-manager` | `0 8 * * 1` | Planning & Estimating; Forecasting; Architecting & Workload Placement; Usage Optimization; Rate Optimization support | Uses capacity tools directly; asks `ftk-database-query` for Kusto-backed commitment, savings, and forecast evidence. |
| `NonComputeQuotaAudit` | `azure-capacity-manager` | `0 7 * * 2` | Automation, Tools & Services; Governance, Policy & Risk | Uses capacity tools directly. |
| `DbQuotaAudit` | `azure-capacity-manager` | `0 7 * * 3` | Automation, Tools & Services; Governance, Policy & Risk | Uses database quota tool directly. |
| `SkuAvailabilityAudit` | `azure-capacity-manager` | `30 7 * * 3` | Planning & Estimating; Architecting & Workload Placement; region and SKU readiness | Uses SKU availability directly; consults `ftk-hubs-agent` only for FinOps Hub ADX backend deployment readiness. |
| `MonitoringScopeValidation` | `ftk-hubs-agent` | `0 9 * * 4` | Understand Usage & Cost: Data Ingestion and Reporting & Analytics foundation | Uses hub platform and inventory tools directly. |
| `BenefitRecommendationReview` | `finops-practitioner` | `0 8 * * 5` | Optimize Usage & Cost: Rate Optimization; Quantify Business Value | Delegates Kusto recommendation/utilization evidence to `ftk-database-query`; consults `chief-financial-officer` for approval framing and commitment risk. |
| `AdvisorSuppressionReview` | `finops-practitioner` | `0 9 1 * *` | Optimize Usage & Cost; Governance, Policy & Risk | Uses inventory/governance evidence; remediation requires explicit approval. |
| `AIWorkloadCostAnalysis` | `finops-practitioner` | `0 10 1 * *` | Quantify Business Value: Unit Economics; Understand Usage & Cost: Reporting & Analytics; Executive Strategy Alignment for AI | Delegates AI cost Kusto evidence to `ftk-database-query`; delegates GPU/capacity evidence to `azure-capacity-manager`; consults `chief-financial-officer` for investment and unit-economics framing. |
| `CapacityMonthlyPlanning` | `azure-capacity-manager` | `0 9 1 * *` | Planning & Estimating; Forecasting; Budgeting support; Architecting & Workload Placement | Uses capacity tools directly; asks `ftk-database-query` for Kusto-backed forecast/rate context; may consult `chief-financial-officer` for budget guardrails. |
| `StoragePaasGrowthForecast` | `azure-capacity-manager` | `0 8 1 * *` | Planning & Estimating; Forecasting; Automation, Tools & Services | Uses non-compute and inventory tools directly. |
| `Monthly` | `finops-practitioner` | `15 17 5 * *` | Understand Usage & Cost: Reporting & Analytics and Anomaly Management; Optimize Usage & Cost: Usage Optimization and Rate Optimization | Delegates all Kusto evidence to `ftk-database-query`; delegates capacity risk evidence to `azure-capacity-manager`; consults `chief-financial-officer` for material commitment or forecast decisions. |
| `Semiannual` | `finops-practitioner` | `0 9 5 1,7 *` | Quantify Business Value: Forecasting, Budgeting, KPIs & Benchmarking; Manage the FinOps Practice: Executive Strategy Alignment | Delegates fiscal Kusto evidence to `ftk-database-query`; delegates capacity risk evidence to `azure-capacity-manager` where needed; consults `chief-financial-officer` for executive report framing. |
| `BudgetCoverageAudit` | `finops-practitioner` | `0 8 15 * *` | Quantify Business Value: Budgeting; Manage the FinOps Practice: Governance, Policy & Risk | Uses governance inventory; budget deployment requires explicit approval. |
| `AlertCoverageAudit` | `finops-practitioner` | `0 8 16 * *` | Understand Usage & Cost: Anomaly Management; Manage the FinOps Practice: Governance, Policy & Risk and Automation, Tools & Services | Uses governance inventory; anomaly alert deployment requires explicit approval. |
| `CapacityQuarterlyStrategy` | `azure-capacity-manager` | `0 9 1 1,4,7,10 *` | Executive Strategy Alignment; Planning & Estimating; Forecasting; Architecting & Workload Placement; Rate Optimization support | Uses capacity tools directly; asks `ftk-database-query` for Kusto-backed cost/rate evidence; consults `chief-financial-officer` for portfolio tradeoff framing. |

## Tool inventory

### Kusto tools

All Kusto tools are owned by `ftk-database-query`. Other agents request Kusto evidence from that specialist instead of calling these tools directly.

### Built-in tools

The recipe enables SRE Agent platform tools through `config/built-in-tools.json` during post-provisioning. These are platform tools, not custom recipe tools. FinOps Hub database access remains owned by the custom Kusto tools assigned to `ftk-database-query`.

| Category | Enabled tools |
|----------|---------------|
| Log Query | `QueryLogAnalyticsByWorkspaceId`, `QueryAppInsightsByAppId`, `QueryAppInsightsByResourceId`, `QueryLogAnalyticsByResourceId` |
| Visualization | `PlotScatter`, `PlotHeatmap`, `PlotBarChart`, `PlotPieChart`, `PlotAreaChartWithCorrelation` |

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

### Python tools

| Tool | Assigned agents | Purpose |
|------|-----------------|---------|
| `benefit-recommendations` | `finops-practitioner`, `azure-capacity-manager` | Gets Cost Management benefit recommendations for savings plans and reserved instances. |
| `capacity-reservation-groups` | `azure-capacity-manager` | Lists capacity reservation groups and reports reserved versus allocated capacity. |
| `data-freshness-check` | `ftk-database-query`, `ftk-hubs-agent`, `azure-capacity-manager` | Checks FinOps Hub function data freshness through Azure Data Explorer REST queries. |
| `db-service-quotas` | `azure-capacity-manager` | Reports SQL DB, SQL MI, Cosmos DB, PostgreSQL Flex, and MySQL Flex quota and region access signals. |
| `deploy-anomaly-alert` | `finops-practitioner` | Creates or updates a Cost Management scheduled action for anomaly detection after explicit remediation approval. |
| `deploy-budget` | `finops-practitioner` | Creates or updates a subscription-level Cost Management budget after explicit remediation approval. |
| `deploy-bulk-anomaly-alerts` | `finops-practitioner` | Creates or updates anomaly alert scheduled actions across subscriptions discovered from a management group after explicit remediation approval. |
| `deploy-bulk-budgets` | `finops-practitioner` | Creates or updates Cost Management budgets across subscriptions discovered from a management group after explicit remediation approval. |
| `non-compute-quotas` | `azure-capacity-manager` | Checks non-compute Azure service quota utilization. |
| `resource-graph-query` | `finops-practitioner`, `azure-capacity-manager`, `ftk-hubs-agent` | Runs Azure Resource Graph KQL across one or more subscriptions. |
| `sku-availability` | `azure-capacity-manager`, `ftk-hubs-agent` | Lists regional SKU availability for Azure Compute or Azure Data Explorer. |
| `suppress-advisor-recommendations` | `finops-practitioner` | Suppresses selected Azure Advisor recommendations across subscriptions under a management group after explicit remediation approval. |
| `vm-quota-usage` | `azure-capacity-manager` | Reports Azure VM family quota usage and quota risk by subscription and region. |

## Operating notes

- The Kusto connector is applied outside the main Bicep deployment by `bin/post-provision.sh` using the SRE Agent data plane. `finops-hub-kusto` supports the recipe's custom query tools. Scheduled tasks are applied by the same helper using `srectl`.
- The portal Team onboarding wizard is part of the expected customer flow and must not be bypassed. The deployment supports it by adding the agent resource group, explicit target resource groups, and same-subscription FinOps Hub resource group to the agent managed-resource scope, then assigning the agent identity target-scope RBAC for Azure Resource Graph and Azure CLI discovery.
- When the target Azure Data Explorer cluster denies public query access, `bin/deploy.sh` still deploys all resources and creates the connector, then warns that private endpoint ADX blocks direct KQL queries from the hosted SRE Agent and links to the SRE Agent known limitations.
- The SRE Agent resource is deployed with `Microsoft.App/agents@2026-01-01`, `upgradeChannel: Stable`, `experimentalSettings.EnableSandboxGroup`, and `experimentalSettings.EnableWorkspaceTools`.
- `bin/post-provision.sh` uploads `ftk-output-style.md` from the Claude plugin output styles as a portal-visible Knowledge Source and verifies the expected KnowledgeFile sources are indexed. Every scheduled task explicitly applies that style for report and Teams-message output.
- `README.md` carries the deployment workflow; this file carries the detailed implemented recipe inventory.
- Add or remove scheduled task YAML, tool YAML, subagent YAML, or skill directories first, then update this catalog and `README.md` in the same change.
