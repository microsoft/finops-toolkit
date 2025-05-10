<!-- filepath: context/FinOps_Framework/capabilities/rate-optimization.md -->
# Rate Optimization

Driving cloud rate efficiency through a combination of negotiated discounts, commitment discounts (RIs, Savings Plans, Committed Use Discounts), and other pricing mechanisms to meet the organization’s operational and budgetary objectives.

## Definition

Rate Optimization helps lower the rate paid for cloud resources. This is achieved through negotiated discounts, resource-based and spend-based commitment discounts (RIs, CUDs, Savings Plans), usage-based discounts, and special programs (e.g., Spot instances). The FinOps team coordinates discount purchases, provides usage data to Procurement, and manages the rate optimization strategy. Rate optimization is closely related to workload optimization and must be balanced to avoid double-counting savings or locking in unoptimized resources. Automation, reporting, and collaboration across personas are key.

## Maturity Assessment
- **Crawl**: Basic strategy, ad hoc purchases, minimal FinOps input, low coverage, situational Spot use.
- **Walk**: Robust strategy, coordinated purchasing, centralized analysis, regular cadence, alerting, evaluation of plans, Spot recommendations.
- **Run**: Automated, metrics-driven management, frequent purchase cycles, automated allocation, bi-directional connection with workload optimization, regular reporting, Spot use integrated, automation for pattern identification, guidance from Licensing/SaaS, Sustainability, and Architecture.

## Functional Activities
- Manage/oversee rate optimization and discount purchasing (FinOps)
- Support Procurement with usage data, collaborate on strategy
- Provide reporting/analysis for all personas
- Collaborate on resource use plans, incorporate discounts in reporting (Engineering)
- Set guidelines, support decision making, model prepayment/budget impacts (Finance)
- Negotiate agreements, understand usage/services, collaborate on strategy (Procurement)
- Identify impactful services, coordinate with Engineering, use pricing metrics (Product)
- Establish strategy/policies, support central purchasing, promote collaboration (Leadership)
- Coordinate ITAM impacts (Allied Personas)

## Measures of Success & KPIs
- Effective savings rate measurement
- >80% utilization for resource-based discounts
- >90% savings per dollar for spend-based discounts
- Timely identification of unused/expiring commitments
- >10% ROI on commitments, break-even within 9 months
- Centralized, holistic management
- Commitment purchases spread for flexibility
- Analysis in context of negotiated discounts
- Drives Effective Savings Rate (ESR)

## Inputs & Outputs
**Inputs:**
- Workload, rate, architecture, sustainability recommendations
**Outputs:**
- Rate Optimization Strategy
- Rate optimization recommendations

## Related Assets
- [Commitment Discounts Overview](https://www.finops.org/wg/commitment-based-discounts-overview/)
- [Cloud Service Provider Commitment Discounts Offerings Matrix](https://www.finops.org/assets/cloud-service-provider-commitment-based-discounts-offerings-matrix/)
- [How to Use a "Green/Red" Approach to RI Buying](https://www.finops.org/assets/the-green-red-zone-approach-to-ri-buying/)
- [Advanced Approach to Prepay Amortization and Rate Blending (Intuit)](https://www.finops.org/assets/advanced-approach-to-prepay-amortization-and-rate-blending-intuit/)
- [Centralizing Prepaid Cloud Discount Reservations (Koch Industries)](https://www.finops.org/assets/centralizing-prepaid-cloud-discount-reservations-an-it-finance-managers-story-by-koch-industries/)
- [How to Decipher Azure Amortized Cost (Shell)](https://www.finops.org/assets/how-to-decipher-azure-amortized-cost-shell/)

---

Attribution: Content adapted from [FinOps Foundation](https://www.finops.org/framework/capabilities/rate-optimization/) under [CC BY 4.0](https://www.finops.org/introduction/how-to-use/).
