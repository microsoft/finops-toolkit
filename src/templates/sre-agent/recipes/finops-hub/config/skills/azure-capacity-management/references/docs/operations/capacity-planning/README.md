---
title: Capacity planning
parent: Capacity & quotas
nav_order: 1
---

# Capacity planning framework

Effective capacity planning combines historical usage analysis, forecasting, and scaling strategies so Azure workloads remain reliable without overspending. Use this framework to structure planning cycles and link outputs to quota and reservation decisions—you'll avoid surprises when demand spikes.

[Where this fits](../capacity-and-quotas/README.md): step 1 of the capacity journey. Forecast scale units or deployment stamps, then feed quota, region access, and reservation needs into the next steps. [Source](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning)

## Gather utilization data

- [Collect telemetry for CPU, memory, storage, network throughput, and request latency](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning#gather-capacity-data) from Azure Monitor logs or platform metrics.
- [Cleanse and normalize the data](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning#gather-capacity-data)—remove anomalies, fill gaps, and align timestamps—before generating visuals or forecasts.
- [Document business context](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning#gather-capacity-data) (seasonal events, marketing campaigns, product releases) to explain historical peaks and inform future scenarios.

## Analyze existing workloads

- [Identify peak utilization windows, transaction rates, and concurrency](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning#understand-an-existing-workload) to pinpoint components that approach their limits.
- [Visualize metrics to highlight trends and anomalies](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning#understand-an-existing-workload); charts help stakeholders understand where bottlenecks have occurred or may emerge.
- [Map performance thresholds](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning#understand-an-existing-workload) (SLA targets, response time goals) to resource utilization to determine safe operating ranges.

## Plan for new workloads

- When historical data is unavailable, [estimate resource demand by modeling expected user journeys, transaction volumes, and dependency behavior](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning#understand-a-new-workload).
- [Incorporate buffer capacity for uncertainty](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning#understand-a-new-workload) and explicitly track assumptions so forecasts can be revised once real usage arrives.

## Forecast demand

- [Produce short-term (weekly/monthly) and long-term (quarterly/annual) projections](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) using historical trends or scenario planning.
- [Include confidence ranges and plan for both normal and surge conditions](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) (for example, special events, regulatory deadlines).

## Align scaling strategies

- [Determine where horizontal scaling (additional instances) versus vertical scaling (larger SKUs) is appropriate](https://learn.microsoft.com/en-us/azure/well-architected/reliability/scaling), ensuring services remain stateless where possible to support scale-out.
- [Mix scheduling, autoscale, and manual interventions](https://learn.microsoft.com/en-us/azure/well-architected/reliability/scaling) to match predictable and unpredictable load patterns. Configure autoscale rules for sudden spikes while scheduling known seasonal adjustments.
- [Tie capacity plans to quota group management, capacity reservations, or savings plans](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) so infrastructure is ready when scaling triggers occur.

## Governance cadence

- **Monthly:** [Treat capacity planning as an iterative process](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning)—compare forecasts to actuals and adjust plans accordingly.
- **Quarterly:** [Revisit assumptions, incorporate new business initiatives, and adjust strategic investments](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) such as new regions or disaster recovery capacity.
- **Post-incident:** [When capacity shortfalls occur, update models with new data](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) and revise monitoring thresholds and escalation paths.

## Outputs and integration

- [Maintain a living capacity plan](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) that documents forecasts, scaling tactics, and required quota changes so adjustments can be made as conditions evolve.
- [Feed forecasted demand into budgeting and reservation purchasing cycles](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) to balance cost and performance.
- [Store charts, scripts, and assumptions in version control](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) to support knowledge sharing and future recalibration.

## Incorporate rate optimization into capacity forecasts

- Capacity planning must account for regional pricing differences—sourcing the same SKU in different regions has different cost implications for your COGS.
- The [FinOps Framework planning and estimating capability](https://learn.microsoft.com/en-us/cloud-computing/finops/framework/quantify/planning) provides guidance on integrating cost projections with capacity needs.
- Use the [Cost Optimization workbook](https://learn.microsoft.com/en-us/azure/advisor/advisor-workbook-cost-optimization) in Azure Advisor to identify reservation purchase recommendations aligned with your capacity forecasts.
- When forecasting capacity for new regions, query historical pricing via [FinOps Hubs](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/hubs/finops-hubs-overview) to project accurate unit costs.

