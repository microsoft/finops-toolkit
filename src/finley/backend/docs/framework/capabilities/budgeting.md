<!-- filepath: context/FinOps_Framework/capabilities/budgeting.md -->
# Budgeting

Strategic and ongoing process for setting limits, monitoring, and managing cloud spending, aligned with business objectives, to ensure accountability and predictable financial outcomes for cloud-based systems.

## Definition

FinOps Budgeting establishes approved funding to support an organization’s planned activities in the cloud, tracks spending and value within that funding, makes transparent adjustments as appropriate, and ensures accountability from each budgeted cost center through a consistent set of budgeting strategies.

Budgeting typically begins as part of broader IT budgeting and matures as cloud use grows. The fast pace and nearly unlimited capacity of public cloud require shorter, more flexible budgeting cycles, with holdbacks and out-of-cycle adjustments. The FinOps team collaborates with Finance to establish and adjust budgeting and holdback strategies over time.

Budgeting is closely related to Forecasting and Planning & Estimating, and is tied to allocation and invoicing/chargeback strategies. Budgets are commitments to fund engineering/product owners at a certain level, providing support and healthy constraints.

Budgets are allocated to budget owners, who are responsible for specific scopes of work. System owners estimate costs and maintain forecasts. When forecasts exceed budgets, collaboration is needed to resolve overages, possibly using holdbacks or requesting additional funding.

Being unfavorable to budget (overspending) requires prompt action. Being strongly favorable (underspending) is also not ideal, as unused funds could be better allocated. Budgeting cycles and holdbacks should be adjusted as cloud use stabilizes or grows.

Budgeting is driven by Finance, but responsibility is distributed to budget owners throughout the organization, empowering autonomy and efficiency.

## Maturity Assessment
- **Crawl**: Simple/stable environment, manual tools, annual cycles, central holdback, limited granularity, engineering not involved.
- **Walk**: More complex/dynamic environment, structured tracking, regular cadence, stakeholder access, BU-level holdback, hybrid cycles.
- **Run**: Complex/distributed tracking, global allocation metadata, granular visibility, real-time reporting, automated processes, rolling/quarterly cycles, distributed holdback management.

## Functional Activities
- Collaborate to establish budgeting and holdback strategies (FinOps, Finance, Leadership)
- Establish budgeting KPIs
- Collect estimates and forecasts
- Provide granular reporting on actual vs. budgeted spending
- Monitor for budget threshold variances (Product, Engineering)
- Approve/adjust budgets and manage priorities (Leadership)
- Monitor budgets vs. actuals for commitments (Procurement)

## Measures of Success & KPIs
- Budgeting uses discount-adjusted, amortized data
- Budget vs. actual cost trends within variance thresholds (20% Crawl, 15% Walk, 12% Run)
- Stakeholder notifications for budget variance/overspend
- Rolling forecasts and budget cadence
- Teams/units manage budgets based on forecast and actuals

## Inputs & Outputs
**Inputs:**
- Forecasting models
- Budgeting strategy from Leadership/Finance
- P&L and cost center strategy from Allocation
- Reporting & Analytics data

**Outputs:**
- Budget strategy for P&L and budget owners
- Budget allocations by owner/system
- Budget adjustment and holdback strategies
- Allocations to cost centers for invoicing/chargeback

## Related Assets
- [Budgeting in the Cloud: From Confusion to Clarity (PointClickCare)](https://www.finops.org/assets/budgeting-in-the-cloud-from-confusion-to-clarity-pointclickcare/)
- [Cloud Budget & Forecast Process - Atlassian Use Case](https://www.finops.org/assets/cloud-budget-forecast-process-atlassian-use-case/)
- [Creating "AutoMagic" App Budgets for FinOps (Ally Financial)](https://www.finops.org/assets/creating-automagic-app-budgets-for-finops-ally-financial/)
- [How to Bridge the Gap between Finance and Tech Teams](https://www.finops.org/assets/finops-stories-how-to-bridge-the-gap-between-finance-and-tech-teams-with-pedro-veloso-of-olx-group/)

---

Attribution: Content adapted from [FinOps Foundation](https://www.finops.org/framework/capabilities/budgeting/) under [CC BY 4.0](https://www.finops.org/introduction/how-to-use/).
