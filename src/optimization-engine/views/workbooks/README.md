# 📒 Azure Optimization Engine workbooks

This folder contains the several AOE workbooks reports that leverage the collected data and generated recommendations. Each Workbook is made of a JSON file, where the actual Workbook code is specified, and a Bicep file, which encapsulates the Workbook definition for deployment purposes:

- Cost optimization
    - [Benefits Simulation](./benefits-simulation.json): allows for simulations of Savings Plans and Reservations commitments savings and coverage based on on-demand Virtual Machines usage history.
    - [Benefits Usage](./benefits-usage.json): reports on the distribution of the different pricing models usage (Savings Plans, Reservations, Spot, and On-Demand) and on the savings each pricing model is achieving compared to others.
    - [Block Blob Storage Usage](./blockblobstorage-usage.json): reports on the distribution of Block Blob Storage usage across different types of Storage Accounts, file structure, replication options, and tiering; allows for simulations of hot to cool tiering savings.
    - [Costs Growing](./costs-growing.json): reports on usage growth anomalies detected across multiple perspectives: subscription, meter category, meter sub-category, meter name, resource group, or individual resources.
    - [Reservations Potential](./reservations-potential.json): reports on On-Demand Virtual Machines usage and its potential for Reservations commitments, with historical analysis and details of resources potentially consuming those reservations.
    - [Reservations Usage](./reservations-usage.json): reports on Reservations usage and allows for usage aggregation by resource tags and deeper insights about real savings (including unused reservations).
    - [Savings Plans Usage](./savingsplans-usage.json): reports on Savings Plans usage and allows for usage aggregation by resource tags and deeper insights about real savings (including unused savings plans).
- Governance
    - [Identities and Roles](./identities-roles.json): reports on Microsoft Entra ID objects (users, groups and applications) and their respective roles across the Entra ID tenant and Azure resources.
    - [Policy Compliance](./policy-compliance.json): reports on Azure Policy compliance across the whole tenant, with an historical perspective and also the ability to filter and group by resource tags.
    - [Recommendations](./recommendations.json): reports on the optimization recommendations generated every week by both AOE and Azure Advisor, across the five pillars of the Well Architected Framework - Cost, Operational Excellence, Performance, Reliability, and Security.
    - [Resources Inventory](./resources-inventory.json): reports on the distribution of the most relevant Azure resource types (mostly IaaS) across different perspectives, including its historical evolution.