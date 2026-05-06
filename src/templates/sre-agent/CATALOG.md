# FinOps toolkit SRE Agent — Scheduled Task Catalog

> The definitive reference implementation for autonomous FinOps and capacity management automation.
> Aligned with the [FinOps Framework](https://finops.org/framework) and [FOCUS specification](https://focus.finops.org).

## Overview

This catalog consolidates the scheduled FinOps and Azure capacity-management automation proposed across the research set into one deduplicated reference implementation for the SRE Agent template. It defines the recurring operating rhythm for cost visibility, anomaly investigation, allocation, forecasting, commitment management, workload optimization, FinOps for AI, practice governance, and capacity supply-chain readiness.

The catalog exists to move FinOps automation beyond static reports and alert-only tooling. Scheduled tasks should use existing FinOps Toolkit Kusto tools where possible, trigger deeper investigation when evidence warrants it, and compound institutional knowledge across runs. Microsoft is a FinOps Foundation member and participates in FOCUS steering through Microsoft representation; this catalog should therefore model FOCUS-first analytics, conformance monitoring, and practical FinOps Framework alignment.

## Agent Roster

| Agent | Domain | Scheduled Tasks |
|-------|--------|----------------|
| `finops-practitioner` | FinOps operating model, allocation, optimization, anomaly response, AI cost management, governance, practice health | 28 |
| `azure-capacity-manager` | Azure quota, capacity reservations, region/zone access, AKS capacity, commitment/capacity alignment | 23 |
| `chief-financial-officer` | Executive finance, budgeting, forecasting, AI unit economics, board/QBR narratives, contract economics | 19 |
| `ftk-database-query` | FOCUS-aligned KQL execution, schema validation, query-focused diagnostics | 3 |
| `ftk-hubs-agent` | FinOps Hub health, export freshness, deployment and connectivity readiness | 1 |

## Task Catalog

### Daily Tasks

Cron for all daily tasks: `0 6 * * *`

| Task | Agent | FinOps Capability | Tools | Deep Inv. | Maturity | Cron |
|------|-------|-------------------|-------|-----------|----------|------|
| Cost anomaly investigation | `finops-practitioner` | Anomaly Management | `cost-anomaly-detection`, `costs-enriched-base`, `top-resource-groups-by-cost` | Yes | Walk | `0 6 * * *` |
| FinOps Hub data freshness monitor | `ftk-hubs-agent` | Data Ingestion | `costs-enriched-base`; NEW TOOL NEEDED: `data-freshness-monitor` | No | Crawl | `0 6 * * *` |
| Budget burn-rate monitor | `chief-financial-officer` | Budgeting | `cost-forecasting-model`, `cost-by-financial-hierarchy`; NEW TOOL NEEDED: `budget-vs-actual-comparison` | No | Walk | `0 6 * * *` |
| Forecast drift check | `chief-financial-officer` | Forecasting | `cost-forecasting-model`, `monthly-cost-trend`, `costs-enriched-base` | No | Walk | `0 6 * * *` |
| Daily cost-driver briefing | `finops-practitioner` | Reporting & Analytics | `top-services-by-cost`, `top-resource-groups-by-cost`, `top-resource-types-by-cost`, `cost-by-region-trend` | No | Crawl | `0 6 * * *` |
| Commitment utilization health | `azure-capacity-manager` | Rate Optimization | `commitment-discount-utilization`, `savings-summary-report`, `top-commitment-transactions` | No | Walk | `0 6 * * *` |
| Non-usage charge monitor | `ftk-database-query` | Anomaly Management | `top-other-transactions`, `costs-enriched-base` | No | Walk | `0 6 * * *` |
| Idle and waste scan | `finops-practitioner` | Workload Optimization | `costs-enriched-base`, `top-resource-types-by-cost`; NEW TOOL NEEDED: `idle-resource-detector` | Yes | Walk | `0 6 * * *` |
| Reservation recommendation triage | `azure-capacity-manager` | Rate Optimization | `reservation-recommendation-breakdown`, `commitment-discount-utilization` | Yes | Walk | `0 6 * * *` |
| FOCUS schema smoke check | `ftk-database-query` | Data Ingestion & Normalization | `costs-enriched-base`; NEW TOOL NEEDED: `focus-compliance-check` | No | Walk | `0 6 * * *` |

### Weekly Tasks

Cron for all weekly tasks: `0 8 * * 1`

| Task | Agent | FinOps Capability | Tools | Deep Inv. | Maturity | Cron |
|------|-------|-------------------|-------|-----------|----------|------|
| Weekly anomaly triage | `finops-practitioner` | Anomaly Management | `cost-anomaly-detection`, `costs-enriched-base`, `top-resource-groups-by-cost` | Yes | Walk | `0 8 * * 1` |
| Commitment coverage and utilization review | `azure-capacity-manager` | Rate Optimization | `commitment-discount-utilization`, `reservation-recommendation-breakdown`, `savings-summary-report` | Yes | Walk | `0 8 * * 1` |
| Budget variance review | `chief-financial-officer` | Budgeting | `monthly-cost-trend`, `monthly-cost-change-percentage`, `cost-by-financial-hierarchy`, `cost-forecasting-model` | Yes | Walk | `0 8 * * 1` |
| Rightsizing opportunity scan | `finops-practitioner` | Workload Optimization | `costs-enriched-base`, `top-resource-types-by-cost`; NEW TOOL NEEDED: `advisor-rightsizing-report` | Yes | Walk | `0 8 * * 1` |
| Idle resource cleanup report | `finops-practitioner` | Workload Optimization | `costs-enriched-base`, `top-resource-types-by-cost`; NEW TOOL NEEDED: `idle-resource-detector` | Yes | Walk | `0 8 * * 1` |
| Forecast validation | `chief-financial-officer` | Forecasting | `cost-forecasting-model`, `monthly-cost-trend` | No | Run | `0 8 * * 1` |
| Savings and ESR summary | `chief-financial-officer` | Rate Optimization | `savings-summary-report`, `service-price-benchmarking` | No | Walk | `0 8 * * 1` |
| Tagging and allocation audit | `finops-practitioner` | Cost Allocation | `costs-enriched-base`, `top-resource-groups-by-cost`; NEW TOOL NEEDED: `tag-compliance-report` | No | Walk | `0 8 * * 1` |
| Top cost movers analysis | `ftk-database-query` | Reporting & Analytics | `monthly-cost-change-percentage`, `top-services-by-cost`, `top-resource-groups-by-cost`, `costs-enriched-base` | Yes | Crawl | `0 8 * * 1` |
| Departmental showback report | `finops-practitioner` | Invoicing & Chargeback | `cost-by-financial-hierarchy`, `costs-enriched-base` | No | Walk | `0 8 * * 1` |
| FinOps practice health scorecard | `finops-practitioner` | FinOps Practice Operations | All current Kusto tools as KPI inputs | No | Run | `0 8 * * 1` |
| Price and regional benchmarking | `finops-practitioner` | Benchmarking | `service-price-benchmarking`, `cost-by-region-trend`, `top-services-by-cost` | No | Walk | `0 8 * * 1` |

### Monthly Tasks

Cron for all monthly tasks: `0 9 1 * *`

| Task | Agent | FinOps Capability | Tools | Deep Inv. | Maturity | Cron |
|------|-------|-------------------|-------|-----------|----------|------|
| Month-over-month report | `finops-practitioner` | Reporting & Analytics | Existing `mom-report.yaml`; `monthly-cost-trend`, `monthly-cost-change-percentage`, `cost-anomaly-detection`, `cost-forecasting-model` | Yes | Walk | `0 9 1 * *` |
| Budget variance analysis | `chief-financial-officer` | Budgeting | `cost-by-financial-hierarchy`, `costs-enriched-base`; NEW TOOL NEEDED: `budget-vs-actual-comparison` | Yes | Crawl/Walk | `0 9 1 * *` |
| Chargeback/showback report | `chief-financial-officer` | Invoicing & Chargeback | `cost-by-financial-hierarchy`, `costs-enriched-base`, `top-commitment-transactions` | Conditional | Walk | `0 9 1 * *` |
| Commitment discount utilization review | `azure-capacity-manager` | Rate Optimization | `commitment-discount-utilization`, `savings-summary-report`, `reservation-recommendation-breakdown`, `top-commitment-transactions` | Yes | Walk/Run | `0 9 1 * *` |
| Savings realization tracking | `finops-practitioner` | Rate Optimization & Benchmarking | `savings-summary-report`, `service-price-benchmarking`, `commitment-discount-utilization` | Yes | Walk | `0 9 1 * *` |
| Tag compliance scorecard | `finops-practitioner` | Cost Allocation | `costs-enriched-base`, `cost-by-financial-hierarchy`; NEW TOOL NEEDED: `tag-compliance-report` | No | Walk | `0 9 1 * *` |
| FinOps maturity self-assessment | `finops-practitioner` | FinOps Assessment | Aggregates task outputs; current Kusto KPI inputs | Yes | Walk/Run | `0 9 1 * *` |
| Forecast accuracy review | `chief-financial-officer` | Forecasting | `cost-forecasting-model`, `monthly-cost-trend` | Yes | Walk/Run | `0 9 1 * *` |
| Orphaned resource review | `finops-practitioner` | Workload Optimization | `costs-enriched-base`; NEW TOOL NEEDED: `idle-resource-detector` | Yes | Crawl/Walk | `0 9 1 * *` |

### Quarterly Tasks

Cron for all quarterly tasks: `0 9 1 1,4,7,10 *`

| Task | Agent | FinOps Capability | Tools | Deep Inv. | Maturity | Cron |
|------|-------|-------------------|-------|-----------|----------|------|
| Quarterly Business Review executive report | `chief-financial-officer` | Reporting & Analytics, Budgeting, Forecasting | `monthly-cost-trend`, `savings-summary-report`, `cost-forecasting-model`, `top-services-by-cost`, `cost-by-financial-hierarchy` | Yes | Walk/Run | `0 9 1 1,4,7,10 *` |
| Rate optimization and RI/SP purchase review | `azure-capacity-manager` | Rate Optimization | `commitment-discount-utilization`, `reservation-recommendation-breakdown`, `top-commitment-transactions`, `savings-summary-report` | Yes | Walk/Run | `0 9 1 1,4,7,10 *` |
| FinOps maturity assessment | `finops-practitioner` | FinOps Practice Operations | `costs-enriched-base`, `savings-summary-report`, `commitment-discount-utilization`, `cost-by-financial-hierarchy` | Yes | Walk | `0 9 1 1,4,7,10 *` |
| Forecast and budget variance analysis | `chief-financial-officer` | Forecasting, Budgeting | `cost-forecasting-model`, `monthly-cost-change-percentage`, `cost-anomaly-detection` | Yes | Walk/Run | `0 9 1 1,4,7,10 *` |
| Allocation and showback health check | `finops-practitioner` | Cost Allocation, Invoicing & Chargeback | `cost-by-financial-hierarchy`, `costs-enriched-base`; NEW TOOL NEEDED: `tag-compliance-report` | No | Crawl/Walk | `0 9 1 1,4,7,10 *` |
| Usage optimization assessment | `finops-practitioner` | Workload Optimization | `top-resource-groups-by-cost`, `top-resource-types-by-cost`, `cost-by-region-trend`; NEW TOOL NEEDED: `idle-resource-detector` | Yes | Walk | `0 9 1 1,4,7,10 *` |
| Anomaly retrospective | `finops-practitioner` | Anomaly Management | `cost-anomaly-detection`, `monthly-cost-change-percentage` | Yes | Walk/Run | `0 9 1 1,4,7,10 *` |
| EA/MCA contract health check | `chief-financial-officer` | Rate Optimization, Budgeting | `savings-summary-report`, `service-price-benchmarking`, `monthly-cost-trend`; NEW TOOL NEEDED: `contract-status-summary` | Yes | Walk | `0 9 1 1,4,7,10 *` |
| Sustainability and carbon impact review | `finops-practitioner` | Sustainability | `cost-by-region-trend`, `top-resource-types-by-cost`; NEW TOOL NEEDED: `carbon-footprint-report` | No | Crawl/Walk | `0 9 1 1,4,7,10 *` |
| Internal benchmarking and team scorecard | `finops-practitioner` | KPIs & Benchmarking | `cost-by-financial-hierarchy`, `savings-summary-report`, `commitment-discount-utilization` | No | Walk/Run | `0 9 1 1,4,7,10 *` |
| Unit economics analysis | `chief-financial-officer` | Unit Economics | `costs-enriched-base`, `monthly-cost-trend`; NEW TOOL NEEDED: `unit-economics-calculator` | Yes | Walk/Run | `0 9 1 1,4,7,10 *` |
| Next-quarter planning setup | `chief-financial-officer` | Budgeting, Planning & Estimating | `cost-forecasting-model`, `monthly-cost-trend`; NEW TOOL NEEDED: `budget-alert-setup` | No | Walk | `0 9 1 1,4,7,10 *` |

### Annual Tasks

Cron for all annual tasks: `0 9 1 7 *`

| Task | Agent | FinOps Capability | Tools | Deep Inv. | Maturity | Cron |
|------|-------|-------------------|-------|-----------|----------|------|
| Annual cloud budget planning | `chief-financial-officer` | Budgeting | `cost-forecasting-model`, `monthly-cost-trend`, `cost-by-financial-hierarchy`, `quarterly-cost-by-resource-group` | Yes | Walk | `0 9 1 7 *` |
| Commitment renewal strategy | `azure-capacity-manager` | Rate Optimization | `commitment-discount-utilization`, `reservation-recommendation-breakdown`, `savings-summary-report`, `top-commitment-transactions` | Yes | Run | `0 9 1 7 *` |
| Year-over-year benchmarking report | `chief-financial-officer` | Benchmarking | `monthly-cost-change-percentage`, `service-price-benchmarking`, `savings-summary-report`, `top-services-by-cost` | Yes | Walk/Run | `0 9 1 7 *` |
| Annual sustainability/carbon report | `finops-practitioner` | Sustainability | `cost-by-region-trend`, `top-resource-types-by-cost`; NEW TOOL NEEDED: `carbon-footprint-report` | Yes | Crawl/Walk | `0 9 1 7 *` |
| EA/MCA contract renewal analysis | `chief-financial-officer` | Rate Optimization, Benchmarking | `savings-summary-report`, `service-price-benchmarking`, `cost-forecasting-model`, `top-services-by-cost`; NEW TOOL NEEDED: `contract-status-summary` | Yes | Run | `0 9 1 7 *` |
| Annual FinOps maturity assessment | `finops-practitioner` | FinOps Practice Operations | All current Kusto tools as evidence inputs | Yes | Crawl/Walk/Run | `0 9 1 7 *` |
| Board-level cloud economics report | `chief-financial-officer` | Reporting & Analytics, Quantifying Business Value | `monthly-cost-trend`, `savings-summary-report`, `cost-forecasting-model`, `cost-by-financial-hierarchy` | Yes | Walk/Run | `0 9 1 7 *` |
| Fiscal year-end optimization sprint | `finops-practitioner` | Workload Optimization, Rate Optimization | `reservation-recommendation-breakdown`, `top-resource-groups-by-cost`, `cost-anomaly-detection`, `commitment-discount-utilization` | Yes | Walk | `0 9 1 7 *` |

### Capacity Management Tasks

These tasks are owned by `azure-capacity-manager` because they address Azure capacity supply-chain operations: quota, capacity reservation groups, quota groups, regional access, zone mapping, AKS scaling, and capacity-to-rate alignment.

#### Daily Capacity Tasks

Cron for all daily capacity tasks: `0 6 * * *`

| Task | Agent | Capacity Capability | Tools | Deep Inv. | Maturity | Cron |
|------|-------|---------------------|-------|-----------|----------|------|
| Quota usage scan | `azure-capacity-manager` | Quota monitoring | NEW TOOL NEEDED: `quota-usage-analysis` PythonTool; Azure CLI `az quota usage list` | No | Ready | `0 6 * * *` |
| CRG utilization check | `azure-capacity-manager` | Capacity reservation monitoring | NEW TOOL NEEDED: `crg-utilization-trend`; Azure CLI capacity reservation APIs | No | Ready | `0 6 * * *` |
| AKS autoscaler health | `azure-capacity-manager` | AKS capacity readiness | NEW TOOL NEEDED: `aks-node-pool-scaling-events`; Azure Activity Log | Conditional | Ready | `0 6 * * *` |
| Zone capacity check | `azure-capacity-manager` | Zone/SKU availability | NEW TOOL NEEDED: `zone-mapping-analysis`; Compute SKU API | No | Ready | `0 6 * * *` |

#### Weekly Capacity Tasks

Cron for all weekly capacity tasks: `0 8 * * 1`

| Task | Agent | Capacity Capability | Tools | Deep Inv. | Maturity | Cron |
|------|-------|---------------------|-------|-----------|----------|------|
| Quota headroom report | `azure-capacity-manager` | Quota reporting | NEW TOOL NEEDED: `quota-usage-analysis`, `quota-usage-trend` | No | Ready | `0 8 * * 1` |
| CRG cost waste audit | `azure-capacity-manager` | Capacity cost optimization | NEW TOOL NEEDED: `crg-billing-waste` | No | Needs Kusto tool | `0 8 * * 1` |
| Reservation utilization review | `azure-capacity-manager` | Rate optimization | `commitment-discount-utilization`; Reservation Utilization Alerts API | No | Ready | `0 8 * * 1` |
| Quota group balance check | `azure-capacity-manager` | Quota group governance | NEW TOOL NEEDED: Quota Group REST wrapper | No | Ready | `0 8 * * 1` |
| Dev/test scale-down audit | `azure-capacity-manager` | Scheduled shutdown optimization | NEW TOOL NEEDED: `vm-shutdown-savings-potential`; Start/Stop VMs v2 APIs | No | Ready | `0 8 * * 1` |
| Advisor capacity recommendations | `azure-capacity-manager` | Rightsizing and quota impact | Azure Advisor API; NEW TOOL NEEDED: `advisor-capacity-recommendations` | No | Ready | `0 8 * * 1` |

#### Monthly Capacity Tasks

Cron for all monthly capacity tasks: `0 9 1 * *`

| Task | Agent | Capacity Capability | Tools | Deep Inv. | Maturity | Cron |
|------|-------|---------------------|-------|-----------|----------|------|
| Capacity forecast update | `azure-capacity-manager` | Capacity planning | `cost-forecasting-model`; NEW TOOL NEEDED: `capacity-forecast-demand` | Yes | Needs Kusto tool | `0 9 1 * *` |
| Quota increase pipeline | `azure-capacity-manager` | Quota procurement | NEW TOOL NEEDED: `quota-usage-analysis`; Azure quota create API | Yes | Ready | `0 9 1 * *` |
| CRG rightsizing review | `azure-capacity-manager` | Capacity reservation rightsizing | NEW TOOL NEEDED: `crg-utilization-trend` | Yes | Needs Kusto tool | `0 9 1 * *` |
| Zone mapping validation | `azure-capacity-manager` | Multi-subscription zone alignment | NEW TOOL NEEDED: `zone-mapping-analysis` | No | Ready | `0 9 1 * *` |
| Region access audit | `azure-capacity-manager` | Region access governance | NEW TOOL NEEDED: `region-access-audit`; Compute SKU API | No | Ready | `0 9 1 * *` |
| Reservation purchase alignment | `azure-capacity-manager` | Capacity-to-rate alignment | `reservation-recommendation-breakdown`, `commitment-discount-utilization`; CRG inventory gap | No | Ready | `0 9 1 * *` |
| Stamp capacity review | `azure-capacity-manager` | Stamp management | NEW TOOL NEEDED: `stamp-capacity-utilization` | Yes | Needs Kusto tool | `0 9 1 * *` |

## FinOps for AI

FinOps for AI is a top FinOps Foundation priority because AI spend behaves differently from traditional infrastructure spend: token volume, model choice, prompt design, context-window size, and application adoption can change unit economics quickly. These tasks give the SRE Agent a dedicated operating rhythm for Azure OpenAI cost visibility, anomaly detection, allocation, forecasting, and model-efficiency optimization.

### Daily AI Tasks

Cron for all daily AI tasks: `0 6 * * *`

| Task | Agent | FinOps Capability | Tools | Deep Inv. | Maturity | Cron |
|------|-------|-------------------|-------|-----------|----------|------|
| `daily-ai-token-usage` | `finops-practitioner` | Reporting & Analytics, Unit Economics | `costs-enriched-base` filtered by `x_SkuMeterCategory == 'Azure OpenAI'`; NEW TOOL NEEDED: `ai-token-usage-breakdown` | No | Crawl | `0 6 * * *` |
| `daily-ai-anomaly-detection` | `finops-practitioner` | Anomaly Management | `cost-anomaly-detection` filtered to AI services; `costs-enriched-base` for drill-down | Yes | Walk | `0 6 * * *` |

### Weekly AI Tasks

Cron for all weekly AI tasks: `0 8 * * 1`

| Task | Agent | FinOps Capability | Tools | Deep Inv. | Maturity | Cron |
|------|-------|-------------------|-------|-----------|----------|------|
| `weekly-ai-unit-economics` | `chief-financial-officer` | Unit Economics, Benchmarking | `costs-enriched-base`, `service-price-benchmarking`; NEW TOOL NEEDED: `ai-token-usage-breakdown`, `ai-cost-by-application` | Yes | Walk | `0 8 * * 1` |
| `weekly-ai-model-comparison` | `finops-practitioner` | Usage Optimization, Unit Economics | `costs-enriched-base`; NEW TOOL NEEDED: `ai-model-cost-comparison` | Yes | Walk | `0 8 * * 1` |

### Monthly AI Tasks

Cron for all monthly AI tasks: `0 9 1 * *`

| Task | Agent | FinOps Capability | Tools | Deep Inv. | Maturity | Cron |
|------|-------|-------------------|-------|-----------|----------|------|
| `monthly-ai-cost-report` | `chief-financial-officer` | Reporting & Analytics, Forecasting, Cost Allocation | `costs-enriched-base`, `cost-forecasting-model`, `cost-by-financial-hierarchy`; NEW TOOL NEEDED: `ai-token-usage-breakdown`, `ai-cost-by-application` | Yes | Walk | `0 9 1 * *` |
| `monthly-ai-optimization-review` | `finops-practitioner` | Workload Optimization, Unit Economics | `costs-enriched-base`, `service-price-benchmarking`; NEW TOOL NEEDED: `ai-model-cost-comparison` | Yes | Run | `0 9 1 * *` |

### AI Measurement Requirements

| Metric | Definition | Primary Source |
|--------|------------|----------------|
| Token consumption by model | Total `ConsumedQuantity` grouped by model/version | `x_SkuMeterSubcategory` |
| Input vs. output token split | Separate token counts and costs by prompt/completion direction | `x_SkuMeterSubcategory` |
| Unit cost per token | `EffectiveCost / ConsumedQuantity` | `Costs()` |
| Cost per 1K tokens | `(EffectiveCost / ConsumedQuantity) * 1000` | `Costs()` |
| AI allocation | AI spend by `CostCenter`, `Application`, `Environment`, team, and owner tags | `Tags` |
| Model efficiency | Cost per token and cost per business outcome by model version | `EffectiveCost`, `ConsumedQuantity`, business metric inputs |

## FOCUS Alignment

All existing Kusto tools are already grounded in the FinOps Hub `Costs()` function and its FOCUS-aligned columns. The scheduled task design should consistently prefer:

- `EffectiveCost` for normalized economic analysis.
- `BilledCost` for invoice and cash-impact analysis.
- `ListCost`, `ContractedCost`, and `EffectiveCost` for savings and discount realization.
- `ChargePeriodStart` and `ChargePeriodEnd` for scoped recurring runs.
- `ServiceName`, `ResourceType`, `RegionName`, `SubAccountName`, and `Tags` for drill-downs.
- `CommitmentDiscountId`, `CommitmentDiscountType`, `CommitmentDiscountStatus`, and commitment-related enrichment columns for RI/SP monitoring.

The definitive implementation should add `focus-compliance-check` and `data-freshness-monitor` scheduled validations. These close the largest current governance gaps: schema conformance, non-null required fields, valid FOCUS enums, stale or incomplete exports, and transition readiness for FOCUS 1.3 features such as contract commitments, split allocation columns, service/host provider separation, and recency metadata.

### FOCUS Alignment for AI

AI cost reporting should use standard FOCUS measures first, with FinOps Hub enrichment columns only where needed to distinguish Azure OpenAI model and token direction.

| AI Concept | FOCUS / Hub Field | Usage |
|------------|-------------------|-------|
| Token count | `ConsumedQuantity` | Denominator for token unit economics. |
| Token unit | `ConsumedUnit` = tokens | Confirms the usage quantity is measured in tokens. |
| AI service category | `x_SkuMeterCategory` = `Azure OpenAI` | Primary filter for Azure OpenAI cost rows. |
| Model and direction | `x_SkuMeterSubcategory` | Breaks usage down by model/version and input/output token direction. |
| Normalized cost | `EffectiveCost` | Numerator for AI unit-cost calculations. |
| Unit economics | `EffectiveCost / ConsumedQuantity` | Cost per token; multiply by 1,000 for cost per 1K tokens. |
| Allocation | `Tags['CostCenter']`, `Tags['Application']`, `Tags['Environment']` | Chargeback/showback and AI cost accountability. |

## Maturity Progression

| Category | Crawl | Walk | Run |
|----------|-------|------|-----|
| Anomaly management | Threshold reports and daily alerts | Automated triage with service/resource attribution | Hypothesis-driven root cause analysis with remediation proposals |
| Allocation | Basic tag and owner coverage, 70% target | Automated scorecards, 85% allocation target | Policy-backed remediation, 90%+ allocation target |
| Forecasting | Historical trend forecasts, ±20% variance | Weekly/monthly validation, ±10% variance | Driver-based scenario forecasting, ±5% variance |
| Commitment management | Utilization reports and manual decisions | Regular portfolio reviews with purchase recommendations | Autonomous recommendations with approval workflow |
| Workload optimization | Manual Advisor review | Scheduled rightsizing and idle-resource reports | Approved auto-remediation and continuous optimization |
| Reporting | Static scheduled reports | Role-specific reports with KPIs and variance analysis | Persistent memory, executive narratives, and predictive alerts |
| Capacity management | Daily quota and CRG visibility | Forecast-driven quota requests and headroom management | Automated capacity supply-chain planning with what-if controls |

## Tool Gap Analysis

| Gap | Needed Tool | Type | Priority | Notes |
|-----|-------------|------|----------|-------|
| Budget vs actual comparison | `budget-vs-actual-comparison` | KustoTool/PythonTool | High | Required for daily, weekly, monthly, quarterly, and annual finance controls. |
| Tag compliance | `tag-compliance-report` | KustoTool | High | Should score required tag coverage by spend and owner. |
| Idle/orphaned resources | `idle-resource-detector` | KustoTool/PythonTool | High | Needs Resource Graph/Azure Advisor correlation beyond cost rows. |
| Unit economics | `unit-economics-calculator` | KustoTool/PythonTool | High | Requires business metrics integration. |
| AI token usage | `ai-token-usage-breakdown` | KustoTool | High | Query `Costs()` filtered to `x_SkuMeterCategory == 'Azure OpenAI'`, break down by `x_SkuMeterSubcategory`, and calculate unit cost per token. |
| AI model comparison | `ai-model-cost-comparison` | KustoTool | High | Compare cost per 1K tokens across AI model versions and input/output directions. |
| AI application allocation | `ai-cost-by-application` | KustoTool | High | Break down Azure OpenAI costs by `Application`, `CostCenter`, and `Environment` tags. |
| FOCUS conformance | `focus-compliance-check` | KustoTool | High | Validates required FOCUS fields and enum rules. |
| Data freshness | `data-freshness-monitor` | KustoTool | High | Detects stale or incomplete cost exports. |
| Commitment expiry | `commitment-expiry-forecast` / `contract-status-summary` | KustoTool/PythonTool | Medium | Needed for FOCUS 1.3 contract commitment readiness. |
| Carbon reporting | `carbon-footprint-report` | PythonTool/HttpClientTool | Medium | Requires Azure Carbon Optimization API integration. |
| Quota analysis | `quota-usage-analysis`, `quota-usage-report` | PythonTool | High | Converts azcapman PowerShell logic to ARM REST calls. |
| Zone mapping | `zone-mapping-analysis` | PythonTool | High | Converts `Get-AzAvailabilityZoneMapping.ps1`. |
| CRG utilization | `crg-utilization-trend`, `crg-billing-waste` | KustoTool/PythonTool | High | Requires CRG inventory plus instance-view utilization. |
| Capacity forecasting | `capacity-forecast-demand` | KustoTool | High | Projects VM core demand by region/SKU family. |
| AKS scaling health | `aks-node-pool-scaling-events` | KustoTool | Medium | Requires Activity Log/diagnostic log data. |
| Dev/test shutdown savings | `vm-shutdown-savings-potential` | KustoTool/PythonTool | Medium | Supports Start/Stop VMs v2 recommendations. |
| Stamp capacity | `stamp-capacity-utilization` | KustoTool | Medium | Requires stamp metadata and usage correlation. |
| Approval workflow | `remediation-approval-workflow` | Platform capability | Medium | Needed before any autonomous write/remediation action. |
| Shift-left cost gates | `iac-cost-estimation` | External integration | Medium | Competitive gap versus Infracost-style PR checks. |

## Competitive Positioning

This catalog positions the FinOps toolkit SRE Agent as the reference layer above cost data, not another dashboard.

What cloud-native and commercial platforms already do well:

- Daily/weekly cost reports and budget alerts.
- Anomaly alerts.
- Rightsizing and commitment recommendations.
- Scheduled showback and allocation dashboards.
- Policy-based or approval-based remediation in some products.

What this reference implementation should uniquely deliver:

- **Autonomous multi-step investigation:** scheduled tasks do not stop at alerts; they investigate root causes and produce evidence-backed recommendations.
- **Persistent memory across runs:** prior findings, known patterns, remediations, and false positives inform future runs.
- **FOCUS-first conformance:** every report uses normalized FOCUS semantics and explicitly validates data quality.
- **Agent specialization:** finance, FinOps practice, capacity management, KQL, and hub operations each have clear ownership.
- **Capacity + FinOps convergence:** quota, region access, CRG utilization, reservation coverage, and cost optimization are managed together.
- **Open Azure-native reference:** the implementation is reproducible, grounded in FinOps Toolkit queries, and extensible with Python/HTTP tools where Kusto alone is insufficient.

The competitive bar is no longer "scheduled reports." The bar is an intelligent, memory-backed operating system for cloud financial and capacity management. This catalog is the task backbone for that system.
