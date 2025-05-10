# Conducting a FinOps Iteration

FinOps is an iterative, hierarchical process that requires cross-functional collaboration across business, technology, and finance teams. When considering the 18 different capabilities across four domains, adopting FinOps can seem like a daunting task. This guide will help you take an iterative approach to FinOps adoption.

## What is a FinOps Iteration?

A FinOps iteration is a focused period where you:
1. Define the right scope for your next FinOps investments
2. Identify measurable goals to achieve over the coming weeks or months
3. Select the right actions to get to the next maturity level
4. Review progress at the end of the iteration and identify goals for the next

This approach allows you to make continuous, incremental progress rather than trying to implement everything at once.

## Before You Begin

Consider the stakeholders involved in your iteration. Since FinOps requires collaboration across business, technology, and finance teams, approaching this holistically and evaluating each step with everyone in mind is recommended. 

Even if you only have a subset of stakeholders (such as a single engineering team or one FinOps practitioner), keep all stakeholders' experiences in mind as you plan your iteration.

## Step 1: Define the Scope

Start by identifying 3-5 capabilities that make the most sense for your organization to focus on. Consider:

- Which capabilities align with your organization's current goals?
- Which areas are causing the most pain or represent the greatest opportunity?
- What is your current level of maturity in each area?

Some examples of capability combinations that work well together:
- **Cost Visibility Focus**: Data ingestion, Allocation, and Reporting & analytics
- **Cost Optimization Focus**: Workload optimization, Rate optimization, and Cloud sustainability
- **Financial Planning Focus**: Planning & estimating, Forecasting, and Budgeting
- **Governance Focus**: Policy & governance, FinOps education, and FinOps practice operations

## Step 2: Set Measurable Goals

For each capability you selected, define specific, measurable goals. These should:
- Be achievable within your iteration timeframe (typically 30-90 days)
- Have clear metrics to track progress
- Be aligned with business outcomes

Example goals:
- Implement tagging across 80% of resources for better allocation
- Reduce idle resources by 15% through workload optimization
- Establish a forecast with less than 10% variance for the next quarter
- Train 100% of cloud engineers on FinOps fundamentals

## Step 3: Plan Your Actions

For each capability, determine the specific actions needed to achieve your goals:

1. **Understand the capability** - What does success look like for this capability?
2. **Assess your current state** - Where are you today relative to your goals?
3. **Identify the gap** - What needs to change to reach your goal?
4. **Create an action plan** - What specific steps will you take?
5. **Assign ownership** - Who is responsible for each action?
6. **Set timelines** - When should each action be completed?

Use the [Microsoft FinOps Review assessment](https://learn.microsoft.com/en-us/assessments/ad1c0f6b-396b-44a4-924b-7a4c778a13d3) to help identify your current maturity level and get recommendations.

## Step 4: Execute

During the iteration:
- Hold regular check-ins to track progress
- Address blockers and challenges as they arise
- Adjust plans as needed based on what you learn
- Document lessons learned
- Celebrate small wins to maintain momentum

## Step 5: Review Progress

At the end of the iteration:
- Measure progress against your goals
- Document what went well and what didn't
- Identify lessons learned and best practices
- Share successes with stakeholders
- Plan for the next iteration

Ask yourself:
- Were you able to achieve what you set out to do?
- What went well? What didn't go well?
- How could you improve the next iteration?

## Example Iteration Plan

Here's an example of a first FinOps iteration plan:

**Duration**: 60 days

**Selected Capabilities**:
1. Data ingestion
2. Allocation (tagging)
3. Reporting & analytics

**Goals**:
1. Implement FOCUS-formatted cost exports for all subscriptions
2. Define and implement a tagging strategy with 80% compliance
3. Create basic Power BI dashboards for cost visibility

**Key Actions**:
1. Data ingestion
   - Set up Cost Management exports with FOCUS format
   - Deploy a FinOps hub for data consolidation
   - Validate data quality and completeness

2. Allocation
   - Define required tags and policies
   - Implement enforcement through Azure Policy
   - Remediate existing resources

3. Reporting
   - Identify key metrics and KPIs
   - Create Power BI dashboards
   - Schedule automated reports

## Microsoft Resources for FinOps Iterations

- [Conduct a FinOps iteration tutorial](https://learn.microsoft.com/en-us/cloud-computing/finops/conduct-iteration) - Detailed guidance on conducting your own FinOps iterations
- [FinOps Review assessment](https://learn.microsoft.com/en-us/assessments/ad1c0f6b-396b-44a4-924b-7a4c778a13d3) - Self-guided assessment to identify key areas for improvement
- [Adopt FinOps on Azure](https://learn.microsoft.com/en-us/training/modules/adopt-finops-on-azure) - Interactive training module that includes guidance on conducting FinOps iterations

---

_Source: [Microsoft Learn - Conduct a FinOps iteration](https://learn.microsoft.com/en-us/cloud-computing/finops/conduct-iteration)_
