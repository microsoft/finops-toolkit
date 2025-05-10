<!-- filepath: context/FinOps_Framework/capabilities/forecasting.md -->
# Forecasting

Creating a model of the anticipated future cost and value of cloud systems leveraging statistical methods, historical spend patterns, planned changes, and related metrics.

## Definition

Forecasting defines a model of future spending for a particular scope (system, service, application, etc.), usually based on Estimating, historical spending, and future plans. Forecasts provide input to Budgeting and serve as a baseline for allocating funding. Forecasting involves Product, Engineering, Finance, and Leadership personas to build models and KPIs aligned with business goals. Accurate forecasting depends on robust data and allocation practices. Forecasts inform investment, operational, and sustainability decisions.

Forecasting, Estimating, and Budgeting are tightly integrated but distinct capabilities. The Forecasting Strategy is developed collaboratively, and forecast models are maintained and updated as systems evolve. Owners must take action if actual costs exceed forecasts.

## Maturity Assessment
- **Crawl**: Manual/ad-hoc models, based on historical spend, manual variance analysis, limited visibility, engineering not involved.
- **Walk**: Forecasts tracked against actuals, include rate optimization, rolling/trend-based, regular updates, stakeholder access, supplement accounting data, regular review cadence.
- **Run**: Global allocation policy, discount-adjusted forecasts, rolling/trend/driver-based models, granular visibility, real-time reporting, automated data flow with accounting systems.

## Functional Activities
- Develop Forecasting Strategy (FinOps, Product, Finance, Leadership, Engineering)
- Establish requirements and frequency for forecasting
- Generate granular forecasts and KPIs
- Explore optimization for forecasted overspend
- Provide forecast data for budgeting and reporting
- Monitor for forecast variances (Procurement, Engineering, Leadership)
- Approve changes impacting spend projections

## Measures of Success & KPIs
- Forecasts use discount-adjusted, amortized data
- Forecast vs. actual cost trends within variance thresholds (20% Crawl, 15% Walk, 12% Run)
- Stakeholder notifications for forecast variance/overspend
- Forecast frequency and updates
- Teams manage budgets based on forecast data

## Inputs & Outputs
**Inputs:**
- Cost/usage info from Reporting & Analytics
- Estimates from Planning & Estimating
- Requirements from Architecting for Cloud, Onboarding Workloads, Policy & Governance

**Outputs:**
- Forecast model expectations to Budgeting
- Updated forecasting models

## Related Assets
- [Accurate Cloud Forecasts](https://www.finops.org/wg/forecasting-cloud-costs/)
- [Exploring Cloud Cost Forecasting](https://www.finops.org/wg/cloud-cost-forecasting/)
- [How to Forecast AI Services Costs in Cloud](https://www.finops.org/wg/how-to-forecast-ai-services-costs-in-cloud/)
- [Cloud Forecasting Insights from Chevron](https://www.finops.org/assets/cloud-forecasting-insights-from-chevron/)
- [Cloud Budget & Forecast Process - Atlassian Use Case](https://www.finops.org/assets/cloud-budget-forecast-process-atlassian-use-case/)
- [Rolling Forecast: Benefits, Challenges, Best practice, and Implementation (Mastercard)](https://www.finops.org/assets/rolling-forecast-benefits-challenges-best-practice-and-implementation-mastercard/)

---

Attribution: Content adapted from [FinOps Foundation](https://www.finops.org/framework/capabilities/forecasting/) under [CC BY 4.0](https://www.finops.org/introduction/how-to-use/).
