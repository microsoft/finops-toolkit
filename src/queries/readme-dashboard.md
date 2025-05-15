---
title: FinOps Hub Dashboard Components
summary: |
  - Documentation for the structure, queries, and components of the FinOps Hub dashboard.
  - Describes dashboard pages, queries, tiles, and metadata for cost analytics and reporting.
  - Supports local indexing and reference for dashboard customization and extension.
description: |
  - This folder contains documentation and reference for the FinOps Hub dashboard components.
  - Includes detailed structure, query documentation, and usage for each dashboard section.
  - Enables local reference and indexing for customizing, extending, and understanding the FinOps Hub dashboard.
tags:
  - dashboard
  - finops
  - analytics
  - reporting
  - documentation
categories:
  - documentation
  - dashboard
  - finops
persona:
  - FinOps Practitioner
  - Data Analyst
related_files:
  - ./finops-hub-dashboard-example.json
  - ./finops-hub-dashboard-schema.json
---

# FinOps Hub Dashboard Components


## Table of Contents

- [FinOps Hub Dashboard Components](#finops-hub-dashboard-components)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Component Structure](#component-structure)
    - [1. Base Queries (`/base-queries`)](#1-base-queries-base-queries)
    - [2. Data Sources (`/datasources`)](#2-data-sources-datasources)
    - [3. Documentation (`/documentation`)](#3-documentation-documentation)
    - [4. Metadata (`/metadata`)](#4-metadata-metadata)
    - [5. Pages (`/pages`)](#5-pages-pages)
      - [About](#about)
      - [UNDERSTAND](#understand)
      - [Summary (UNDERSTAND)](#summary-understand)
      - [Anomaly Management (UNDERSTAND)](#anomaly-management-understand)
      - [Data Ingestion (UNDERSTAND)](#data-ingestion-understand)
      - [OPTIMIZE](#optimize)
      - [Rate Optimization (OPTIMIZE)](#rate-optimization-optimize)
      - [Licensing + SaaS (OPTIMIZE)](#licensing--saas-optimize)
      - [QUANTIFY](#quantify)
      - [Budgeting (QUANTIFY)](#budgeting-quantify)
      - [MANAGE](#manage)
      - [Invoicing + Chargeback (MANAGE)](#invoicing--chargeback-manage)
    - [6. Parameters (`/parameters`)](#6-parameters-parameters)
    - [7. Queries (`/queries`)](#7-queries-queries)
      - [Query Documentation](#query-documentation)
        - [Base Queries](#base-queries)
        - [Understanding Usage and Cost Domain](#understanding-usage-and-cost-domain)
          - [Summary Queries](#summary-queries)
          - [Anomaly Management Queries](#anomaly-management-queries)
          - [Data Ingestion Queries](#data-ingestion-queries)
        - [Optimizing Usage and Cost Domain](#optimizing-usage-and-cost-domain)
          - [Optimize Queries](#optimize-queries)
          - [Rate Optimization Queries](#rate-optimization-queries)
          - [Licensing and SaaS Queries](#licensing-and-saas-queries)
        - [Quantifying Business Value Domain](#quantifying-business-value-domain)
          - [Quantify Queries](#quantify-queries)
          - [Budgeting Queries](#budgeting-queries)
          - [Invoicing and Chargeback Queries](#invoicing-and-chargeback-queries)
        - [Managing FinOps Practice Domain](#managing-finops-practice-domain)
          - [Manage Queries](#manage-queries)
          - [Data Quality Queries](#data-quality-queries)
          - [System Queries](#system-queries)
    - [8. Tiles (`/tiles`)](#8-tiles-tiles)
  - [Appendix: Query Catalog](#appendix-query-catalog)
    - [Query Details](#query-details)
      - [Query ID: 152f2041-bbc1-41e4-b155-271b2e0cf6e9](#query-id-152f2041-bbc1-41e4-b155-271b2e0cf6e9)
      - [Query ID: bc24e050-f2b9-4b4a-a08d-69fc4a4bb95e](#query-id-bc24e050-f2b9-4b4a-a08d-69fc4a4bb95e)
      - [Query ID: 0d91ea4a-c81d-4a21-b708-b6af37be1eec](#query-id-0d91ea4a-c81d-4a21-b708-b6af37be1eec)
      - [Query ID: 1d273b55-d2ea-427c-8a5f-01f6c240e98a](#query-id-1d273b55-d2ea-427c-8a5f-01f6c240e98a)
      - [Query ID: 4c7a7614-9b8c-415b-a4e1-d2d53c023d31](#query-id-4c7a7614-9b8c-415b-a4e1-d2d53c023d31)
      - [Query ID: ebe41e27-e9f9-478e-ab90-fd1f87906766](#query-id-ebe41e27-e9f9-478e-ab90-fd1f87906766)
      - [Query ID: 35a3a2b3-4ab0-4449-96f7-c78db789089e](#query-id-35a3a2b3-4ab0-4449-96f7-c78db789089e)
      - [Query ID: 7d0c2c1f-338b-4534-b173-36b284779131](#query-id-7d0c2c1f-338b-4534-b173-36b284779131)
      - [Query ID: 62bbceee-c089-45db-822c-0b4745358aa4](#query-id-62bbceee-c089-45db-822c-0b4745358aa4)
      - [Query ID: e1bc2d51-44af-4dd9-8b0d-a71088b551f5](#query-id-e1bc2d51-44af-4dd9-8b0d-a71088b551f5)
      - [Query ID: 3886b5cd-34a8-42d7-9e16-33ea4d236953](#query-id-3886b5cd-34a8-42d7-9e16-33ea4d236953)
      - [Query ID: eb9259cc-05b7-4441-a66d-a29026fe371b](#query-id-eb9259cc-05b7-4441-a66d-a29026fe371b)
      - [Query ID: 56fd8707-bbb3-4f7e-8e37-8dd90ada3baa](#query-id-56fd8707-bbb3-4f7e-8e37-8dd90ada3baa)
      - [Query ID: 0341b3e4-eccc-4924-9555-9835b128c543](#query-id-0341b3e4-eccc-4924-9555-9835b128c543)
      - [Query ID: d7f31381-ba44-46a1-ad3e-dc6b8826706d](#query-id-d7f31381-ba44-46a1-ad3e-dc6b8826706d)
      - [Query ID: e17346d1-0227-4aa4-8765-f9b4bf43bed5](#query-id-e17346d1-0227-4aa4-8765-f9b4bf43bed5)
      - [Query ID: f1ef29df-7a1d-4dd0-8619-0c0164707b31](#query-id-f1ef29df-7a1d-4dd0-8619-0c0164707b31)
      - [Query ID: 84ecad69-79ac-45b9-a8af-60be28dcc748](#query-id-84ecad69-79ac-45b9-a8af-60be28dcc748)
      - [Query ID: dcf69b47-233e-4bc4-b914-3f6f09f4cb82](#query-id-dcf69b47-233e-4bc4-b914-3f6f09f4cb82)
      - [Query ID: 13813a00-e634-4428-9eac-ea255fd1eaca](#query-id-13813a00-e634-4428-9eac-ea255fd1eaca)
      - [Query ID: cb34f22b-9370-460c-9658-3e73d220bbc7](#query-id-cb34f22b-9370-460c-9658-3e73d220bbc7)
      - [Query ID: 3b3f0a58-2d84-4e3e-bebc-3e747a7d5ede](#query-id-3b3f0a58-2d84-4e3e-bebc-3e747a7d5ede)
      - [Query ID: 7f7b08a9-ae15-46f8-8b0f-767280375add](#query-id-7f7b08a9-ae15-46f8-8b0f-767280375add)
      - [Query ID: 9c5d3cf0-b6cb-45a2-acfd-b19df425bddf](#query-id-9c5d3cf0-b6cb-45a2-acfd-b19df425bddf)
      - [Query ID: 49e24ee0-91de-4b1c-973f-036a3c060aca](#query-id-49e24ee0-91de-4b1c-973f-036a3c060aca)
      - [Query ID: d7a9ff96-da17-4826-9fb5-b23f4c7b938d](#query-id-d7a9ff96-da17-4826-9fb5-b23f4c7b938d)
      - [Query ID: 21a87abe-19e2-44ec-8298-ba872e66c162](#query-id-21a87abe-19e2-44ec-8298-ba872e66c162)
      - [Query ID: 5bbb5369-ac95-45fc-853c-a6a2ce6a9e7b](#query-id-5bbb5369-ac95-45fc-853c-a6a2ce6a9e7b)
      - [Query ID: 98c9b9b5-bebf-41f8-8319-5fa2523f9dd0](#query-id-98c9b9b5-bebf-41f8-8319-5fa2523f9dd0)
      - [Query ID: 377e3693-0738-45d7-97d9-4b6e71ec5b36](#query-id-377e3693-0738-45d7-97d9-4b6e71ec5b36)
      - [Query ID: 13cad52d-91e7-4ab4-aad5-4aae21c1019a](#query-id-13cad52d-91e7-4ab4-aad5-4aae21c1019a)
      - [Query ID: 3924981c-23e4-464d-a872-045df1752750](#query-id-3924981c-23e4-464d-a872-045df1752750)
      - [Query ID: 90502e9a-2d0d-4ae4-8d9d-cc21f9b72d5d](#query-id-90502e9a-2d0d-4ae4-8d9d-cc21f9b72d5d)
      - [Query ID: c2c65ec0-e57d-4834-8a6b-b5975afeb9a0](#query-id-c2c65ec0-e57d-4834-8a6b-b5975afeb9a0)
      - [Query ID: 61b26784-6a73-4e80-85b2-9c5cfbd2dd06](#query-id-61b26784-6a73-4e80-85b2-9c5cfbd2dd06)
      - [Query ID: d5224d06-c8e7-4dd9-afec-595b39712f5a](#query-id-d5224d06-c8e7-4dd9-afec-595b39712f5a)
      - [Query ID: 0dcf2c54-7f1d-45e9-a53b-d598a24493a4](#query-id-0dcf2c54-7f1d-45e9-a53b-d598a24493a4)
      - [Query ID: 30644718-defd-4c6c-9ffa-a9c2cd1f871f](#query-id-30644718-defd-4c6c-9ffa-a9c2cd1f871f)
      - [Query ID: 6259f773-593c-4953-898c-15aa5ff6e53a](#query-id-6259f773-593c-4953-898c-15aa5ff6e53a)
  - [Dashboard Assembly](#dashboard-assembly)
  - [Relationship to FinOps Framework](#relationship-to-finops-framework)
  - [Development Guidelines](#development-guidelines)
  - [Query Development Best Practices](#query-development-best-practices)
  - [Usage Instructions](#usage-instructions)
  - [References](#references)

This documentation provides a comprehensive overview of the dashboard components used in the FinOps Hub Dashboard. The dashboard is built using Azure Data Explorer (Kusto) dashboards and follows a modular structure to facilitate maintenance and updates.

## Overview

The dashboard components folder contains modular JSON files that make up the complete FinOps Hub Dashboard. Each subdirectory represents a different aspect of the dashboard architecture, allowing for organized development and maintenance of the dashboard elements.

## Component Structure

### 1. Base Queries (`/base-queries`)

Base queries serve as foundational data queries that can be referenced by other queries in the dashboard. They define variables that can be reused across different visualizations.

**Key file**: `base-queries.json`

This file contains definitions for base queries such as:

- CostsThisMonth
- CostsLastMonth
- CostsByMonth
- CostsByDay

Base queries are referenced by their ID and exposed as variables to be used in other queries.

### 2. Data Sources (`/datasources`)

This folder contains configuration for the data sources used by the dashboard.

**Key file**: `datasources.json`

The file defines connections to Azure Data Explorer clusters, specifically the Hub database which contains the FinOps data. The current configuration points to:

- Cluster URI: [https://ftk-mf.westcentralus.kusto.windows.net/](https://ftk-mf.westcentralus.kusto.windows.net/)
- Database: Hub

### 3. Documentation (`/documentation`)

Contains markdown documentation that explains the queries and visualizations used in the dashboard.

**Key file**: `query_documentation.md`

This comprehensive documentation provides:

- Overview of all queries used in the dashboard
- Organization by functional areas and dashboard pages
- Explanations of query logic and purpose
- References to FinOps Framework domains and capabilities

### 4. Metadata (`/metadata`)

Stores metadata information about the dashboard.

**Key file**: `metadata.json`

Contains dashboard identification and basic information:

- Dashboard ID
- ETag for versioning
- Schema version
- Dashboard title

### 5. Pages (`/pages`)


Defines the page structure of the dashboard and provides a detailed overview of each page.

**Key file**: `pages.json`

The dashboard is organized into multiple pages, each aligned with the FinOps Framework domains and best practices. Below is comprehensive documentation for each page:


#### About
**Purpose:** Introduction to the FinOps Hub Dashboard, its objectives, and navigation tips. Provides context for users new to the dashboard and FinOps practices.

**Key Visualizations/Tiles:**
- **Welcome and Overview (markdown card):**
  - Presents a welcome message, dashboard version, and a summary of the FinOps hub's alignment with the [FinOps Framework](https://aka.ms/finops/fx) and [FOCUS](https://aka.ms/finops/focus) specification.
  - Explains the use of effective (amortized) cost, and provides links to learn more and give feedback.
- **About the FinOps toolkit (markdown card):**
  - Describes the FinOps hubs as part of the [FinOps toolkit](https://aka.ms/finops/toolkit), an open-source collection of FinOps solutions.
  - Provides a link to contribute via GitHub.

**FinOps Domain:** General/Onboarding

**Features:**
- Orientation for new users
- Links to documentation, feedback, and open-source resources

---



#### UNDERSTAND
**Purpose:** High-level entry point for understanding cloud usage and cost. Serves as a parent domain for detailed subpages.

**Key Visualizations/Tiles:**
- **Domain Introduction (markdown card):**
  - Summarizes the "Understand usage and cost" domain, focusing on data acquisition, reporting, analysis, and alerting for cost, usage, and carbon.
  - Provides links to learn more and give feedback.
- **Data Ingestion (markdown card):**
  - Explains the importance of collecting and organizing data for FinOps.
  - Links to the Data Ingestion report and documentation.
- **Allocation (markdown card):**
  - Describes the process of attributing and redistributing shared costs using metadata.
  - Indicates allocation reporting is coming soon and links to documentation.
- **Reporting + Analytics (markdown card):**
  - Highlights the need for reporting and analytics to understand usage and spending patterns.
  - Links to the Reporting report and documentation.
- **Anomaly Management (markdown card):**
  - Introduces anomaly management for detecting and addressing abnormal cost/usage patterns.
  - Links to the Anomaly Management report and documentation.

**FinOps Domain:** Understand Usage & Cost

**Features:**
- Aggregated usage and cost metrics
- Quick links to subpages: Data Ingestion, Allocation, Reporting, Anomaly Management

---


#### Summary (UNDERSTAND)
**Purpose:** Provides a comprehensive summary of cloud costs and usage trends, enabling users to quickly assess overall spend and identify major cost drivers.

**Key Visualizations/Tiles:**
- Cost trends over time
- Cost breakdown by account, service, or resource group
- Forecasting and anomaly highlights

**FinOps Domain:** Understand Usage & Cost

**Features:**
- Time-based filtering
- Drill-down to detailed cost drivers

---


#### Anomaly Management (UNDERSTAND)
**Purpose:** Detects, visualizes, and helps investigate unusual or unexpected cloud spend patterns.

**Key Visualizations/Tiles:**
- **3-month running total trend (column chart):**
  - Visualizes the running total of costs over the past three months, helping to spot overall trends and seasonality.
- **3-month daily trend (column chart):**
  - Shows daily cost fluctuations over the last three months, highlighting spikes or drops that may indicate anomalies.
- **3-month daily trend by subscription (stacked column chart):**
  - Breaks down daily costs by subscription, making it easier to identify which subscriptions contribute to anomalies.
- **Daily trend (column chart with % change):**
  - Displays daily effective cost and overlays the percent change, surfacing days with significant cost shifts.

**FinOps Domain:** Understand Usage & Cost, Anomaly Management

**Features:**
- Automated anomaly detection
- Visual breakdowns by time and subscription
- Supports investigation of root causes for cost spikes

---



#### Data Ingestion (UNDERSTAND)
**Purpose:** Monitors the health, freshness, and completeness of cost and usage data ingested into the dashboard.

**Key Visualizations/Tiles:**
- **On this page (markdown card):**
  - Navigation and quick links to FinOps hubs, ingested data, and feedback.
- **About this domain (markdown card):**
  - Explains the importance of data ingestion for FinOps and links to documentation.
- **FinOps hubs (markdown card):**
  - Summarizes the cost and usage of FinOps hubs infrastructure.
- **Monthly trend by hub instance (stacked column chart):**
  - Shows monthly cost/usage trends for each hub instance.
- **Daily trend by hub instance (stacked column chart):**
  - Visualizes daily cost/usage trends for each hub instance.
- **Monthly trend by hub instance (table):**
  - Tabular view of monthly trends by hub instance for detailed analysis.
- **Ingested months (multi-stat card):**
  - Displays the number of months of data ingested, by type.
- **Ingested data by table (stacked column chart):**
  - Shows the volume of ingested data by table, helping to identify ingestion completeness.
- **Ingested cost data by scope (stacked column chart):**
  - Visualizes cost data ingestion by scope (e.g., subscription, resource group).
- **Ingested scopes (card):**
  - Number of unique scopes (e.g., subscriptions) ingested.
- **Ingested months (card):**
  - Number of unique months of data ingested.
- **Ingested price data by scope (stacked column chart):**
  - Shows price data ingestion by scope.
- **Ingested recommendation data by scope (stacked column chart):**
  - Visualizes recommendation data ingestion by scope.
- **Ingested transaction data by scope (stacked column chart):**
  - Shows transaction data ingestion by scope.
- **Ingested commitment discount usage data by scope (stacked column chart):**
  - Visualizes commitment discount usage data ingestion by scope.
- **Ingested data (markdown card):**
  - Summarizes the data ingested into FinOps hubs.
- **Data quality (markdown card):**
  - Introduces data quality checks and their impact on reports.
- **Summary of list, contracted, and effective cost alignment (table):**
  - Highlights rows where cost columns are missing or may be incorrect, supporting data quality assurance.

**FinOps Domain:** Data Ingestion, Data Quality

**Features:**
- Data pipeline monitoring
- Ingestion completeness and freshness metrics
- Data quality checks and diagnostics

---


#### OPTIMIZE
**Purpose:** Entry point for cost optimization activities, summarizing opportunities to reduce spend and improve efficiency.

**Key Visualizations/Tiles:**
- Optimization summary
- Navigation to subpages (Rate Optimization, Licensing + SaaS)

**FinOps Domain:** Optimize Usage & Cost

**Features:**
- Overview of savings opportunities
- Quick access to optimization tools

---

#### Rate Optimization (OPTIMIZE)
**Purpose:** Identifies and tracks savings from commitment-based discounts, reservations, and other rate optimization strategies.

**Key Visualizations/Tiles:**
- Savings from reservations/commitments
- Coverage and utilization metrics
- Discount purchase tracking

**FinOps Domain:** Rate Optimization

**Features:**
- Reservation and discount analytics
- Opportunity identification

---


#### Licensing + SaaS (OPTIMIZE)
**Purpose:** Analyzes software licensing and SaaS spend, highlighting optimization opportunities and usage patterns.

**Key Visualizations/Tiles:**
- **On this page (markdown card):**
  - Navigation and quick links to Hybrid Benefit and feedback.
- **Azure Hybrid Benefit (markdown card):**
  - Summarizes Hybrid Benefit coverage and utilization.
- **Hybrid Benefit summary (multi-stat card):**
  - Shows key Hybrid Benefit metrics for the last n days.
- **Underutilized vCPU capacity (table):**
  - Lists vCPU resources with underutilized Hybrid Benefit.
- **Fully utilized vCPU capacity (table):**
  - Lists vCPU resources with full Hybrid Benefit utilization.
- **Eligible resources (table):**
  - Shows resources eligible for Hybrid Benefit.

**FinOps Domain:** Licensing & SaaS

**Features:**
- License/SaaS inventory
- Underutilization detection
- Hybrid Benefit optimization

---



#### QUANTIFY
**Purpose:** Focuses on quantifying business value, unit economics, and cost allocation to business units or products.

**Key Visualizations/Tiles:**
- **Domain Introduction (markdown card):**
  - Summarizes the Quantify Business Value domain and its focus on ROI and business alignment.
- **Planning and estimating (markdown card):**
  - Describes the process of predicting cost/usage for new and existing workloads. (Coming soon)
- **Forecasting (markdown card):**
  - Explains how historical trends and plans are used to predict future costs. (Coming soon)
- **Budgeting (markdown card):**
  - Introduces budgeting as a process for managing financial plans and limits, with a link to the Budgeting report.
- **Benchmarking (markdown card):**
  - Describes benchmarking for evaluating cloud efficiency and value. (Coming soon)
- **Unit economics (markdown card):**
  - Explains the calculation of cost and carbon per business unit. (Coming soon)

**FinOps Domain:** Quantify Business Value

**Features:**
- Allocation by business unit, product, or service
- Unit cost tracking
- Business value and benchmarking insights

---



#### Budgeting (QUANTIFY)
**Purpose:** Tracks budgets, forecasts, and actual spend, enabling proactive financial management and variance analysis.

**Key Visualizations/Tiles:**
- **Running total - This month and last (area chart):**
  - Visualizes cumulative spend for the current and previous month, supporting budget pacing.
- **Summary (table):**
  - Tabular summary of budget, forecast, and actuals for key categories.
- **Effective cost by subscription (table):**
  - Breaks down effective cost by subscription for detailed tracking.

**FinOps Domain:** Budgeting, Forecasting

**Features:**
- Budget pacing
- Forecast accuracy metrics
- Subscription-level budget tracking

---



#### MANAGE
**Purpose:** Central hub for managing the FinOps practice, including governance, policy, and operational metrics.

**Key Visualizations/Tiles:**
- **Domain Introduction (markdown card):**
  - Summarizes the "Manage the FinOps practice" domain and its focus on vision and adoption.
- **FinOps education and enablement (markdown card):**
  - Describes training and resources for FinOps adoption, with links to guides.
- **FinOps practice operations (markdown card):**
  - Explains building/managing a FinOps team and integrating FinOps into processes. (Coming soon)
- **Onboarding workloads (markdown card):**
  - Covers onboarding new/existing workloads to the cloud. (Coming soon)
- **Cloud policy and governance (markdown card):**
  - Describes policy/governance for FinOps, including SKUs, configurations, and cost controls. (Coming soon)
- **Invoicing and chargeback (markdown card):**
  - Introduces invoicing/chargeback, with a link to the Invoicing + Chargeback report.
- **FinOps assessment (markdown card):**
  - Explains assessment and benchmarking of FinOps maturity, with a link to start a review.

**FinOps Domain:** Manage FinOps Practice

**Features:**
- Governance dashboards
- Practice health indicators
- Education, onboarding, and assessment tools

---



#### Invoicing + Chargeback (MANAGE)
**Purpose:** Supports financial operations by providing detailed invoicing, chargeback, and showback reporting.

**Key Visualizations/Tiles:**
- **About this capability (markdown card):**
  - Introduces invoicing and chargeback, with links to documentation and feedback.
- **Cost last month (multi-stat card):**
  - Shows billed and effective cost for the previous month.
- **Cost over time (column chart):**
  - Visualizes cost trends over time for invoice reconciliation.
- **Change over time (column chart):**
  - Displays changes in cost over time, supporting variance analysis.
- **Counts (multi-stat card):**
  - Summarizes counts of subscriptions, resource groups, resources, and services.

**FinOps Domain:** Invoicing & Chargeback

**Features:**
- Cost distribution by business unit or cost center
- Invoice validation tools
- Showback and reconciliation support

---


Each page has a unique ID that is referenced by tiles for placement and is designed to support FinOps best practices and actionable insights.

### 6. Parameters (`/parameters`)

Defines dashboard parameters that allow for interactive filtering and customization.

**Key file**: `parameters.json`

Parameters include:

- Time ranges (e.g., number of months to display)
- Filtering options for resources, tags, subscriptions, etc.
- Selection parameters for different views

### 7. Queries (`/queries`)

Contains the KQL (Kusto Query Language) queries that power the dashboard visualizations.

**Key file**: `queries.json`

This file contains all the queries used across the dashboard, including:

- Cost analysis queries
- Resource utilization queries
- Trend analysis queries
- Anomaly detection queries
- Budget and forecast queries

Queries can reference base queries (variables) to build more complex visualizations.

#### Query Documentation

The dashboard contains a wide range of queries organized by the FinOps Framework domains. Below is a catalog of key queries by domain:

##### Base Queries

Base queries are fundamental queries that are reused across multiple tiles and pages:

| Variable Name | Description | Query ID |
|--------------|-------------|----------|
| CostsThisMonth | Retrieves cost data for the current month | 43612ae4-c475-4f22-bb50-ce9d995abb8f |
| CostsLastMonth | Retrieves cost data for the previous month | cb1f5404-c0b1-42fd-99fb-3cff7b08daaa |
| CostsByMonth | Aggregates costs by month | 4ce0f587-2d45-436c-8f79-102c6b382439 |
| CostsByDay | Aggregates costs by day | 6b598467-8c31-4693-b1eb-7ed683fcfc3a |

##### Understanding Usage and Cost Domain

###### Summary Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| 152f2041-bbc1-41e4-b155-271b2e0cf6e9 | Compares billed vs. effective costs for last month | CostsLastMonth |
| 0d91ea4a-c81d-4a21-b708-b6af37be1eec | Shows cost trends over time | CostsByMonth |
| 3886b5cd-34a8-42d7-9e16-33ea4d236953 | Cost breakdown by accounts | CostsByMonth |
| e8b343dc-7430-4487-8d44-ef48ac454f2d | Cost breakdown by service types | CostsByMonth |
| 3d947a7c-edca-46b5-a862-de77a725c85f | Cost trends with forecasting | CostsByMonth |

###### Anomaly Management Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| 2d7b6447-2769-40b8-958a-f252dab68b1e | Detects daily cost anomalies | CostsByDay |
| c4f6542d-a9cb-4284-bd4e-b9f94ad02192 | Resource group spending patterns and anomalies | CostsByDay |
| af6424d4-8f73-4b81-bfdd-f0287ebcaaca | Day-over-day cost changes | CostsByDay |
| 00ae3917-c783-45f6-a04e-9113e4c5d445 | Service spending anomalies | CostsByDay |

###### Data Ingestion Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| b98c9ed7-47b3-41c1-a596-fd9d32725b33 | Data freshness and ingestion metrics | - |
| 8f1ad1ef-6f5e-4f20-a1c4-3941e871d0cd | Table size and ingestion volumes | - |
| e9a9a135-6a74-4463-b69f-eac6930ff1f2 | Data completeness checks | - |
| d2c522dc-ef4b-4714-a473-09350e275557 | Costs dataset status | - |

##### Optimizing Usage and Cost Domain

###### Optimize Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| d5224d06-c8e7-4dd9-afec-595b39712f5a | Resource underutilization identification | CostsByMonth, maxGroupCount |
| 21a87abe-19e2-44ec-8298-ba872e66c162 | Optimization opportunities by resource type | CostsByMonth, maxGroupCount |
| 61b26784-6a73-4e80-85b2-9c5cfbd2dd06 | Resource group optimization opportunities | CostsByMonth, maxGroupCount |
| 3924981c-23e4-464d-a872-045df1752750 | Service optimization by utilization patterns | CostsByMonth, maxGroupCount |

###### Rate Optimization Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| 5bbb5369-ac95-45fc-853c-a6a2ce6a9e7b | Savings from commitment discounts | CostsByMonth |
| 98c9b9b5-bebf-41f8-8319-5fa2523f9dd0 | Commitment discount purchases | CostsByMonth |
| 377e3693-0738-45d7-97d9-4b6e71ec5b36 | Reservation usage analysis | CostsByMonth |
| 13cad52d-91e7-4ab4-aad5-4aae21c1019a | Commitment discount coverage | CostsByMonth |

###### Licensing and SaaS Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| 35a3a2b3-4ab0-4449-96f7-c78db789089e | Software license utilization | CostsByMonth |
| 7d0c2c1f-338b-4534-b173-36b284779131 | SaaS spending analysis | CostsByMonth |
| 62bbceee-c089-45db-822c-0b4745358aa4 | License optimization opportunities | CostsByMonth |
| e1bc2d51-44af-4dd9-8b0d-a71088b551f5 | SaaS usage patterns | CostsByMonth |

##### Quantifying Business Value Domain

###### Quantify Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| 6259f773-593c-4953-898c-15aa5ff6e53a | Unit economics calculations | CostsByMonth |
| 90502e9a-2d0d-4ae4-8d9d-cc21f9b72d5d | Business value metrics | CostsByMonth |
| c2c65ec0-e57d-4834-8a6b-b5975afeb9a0 | Cost per business transaction | CostsByMonth |
| 0dcf2c54-7f1d-45e9-a53b-d598a24493a4 | Cost allocation by business unit | CostsByMonth |

###### Budgeting Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| c7be613e-deb4-4779-ad75-4445e8d5e01f | Budget vs. actual spending | CostsByMonth |
| 1d273b55-d2ea-427c-8a5f-01f6c240e98a | Budget forecasting | CostsByMonth |
| 4c7a7614-9b8c-415b-a4e1-d2d53c023d31 | Service category budget tracking | CostsByMonth, maxGroupCount |
| ebe41e27-e9f9-478e-ab90-fd1f87906766 | Daily budget pacing | CostsByDay, maxGroupCount |

###### Invoicing and Chargeback Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| 7f7b08a9-ae15-46f8-8b0f-767280375add | Chargeback allocation calculations | CostsByMonth |
| 9c5d3cf0-b6cb-45a2-acfd-b19df425bddf | Invoice reconciliation | CostsByDay, maxGroupCount |
| 49e24ee0-91de-4b1c-973f-036a3c060aca | Showback reporting | CostsByDay, maxGroupCount |
| d7a9ff96-da17-4826-9fb5-b23f4c7b938d | Cost distribution by charge categories | CostsByMonth, maxGroupCount |

##### Managing FinOps Practice Domain

###### Manage Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| d7f31381-ba44-46a1-ad3e-dc6b8826706d | FinOps maturity metrics | CostsByDay |
| e17346d1-0227-4aa4-8765-f9b4bf43bed5 | Tag compliance monitoring | CostsByMonth |
| f1ef29df-7a1d-4dd0-8619-0c0164707b31 | Governance policy metrics | CostsByDay |
| 84ecad69-79ac-45b9-a8af-60be28dcc748 | Resource naming compliance | CostsByDay |

###### Data Quality Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| dcf69b47-233e-4bc4-b914-3f6f09f4cb82 | Missing tag identification | CostsByDay |
| 13813a00-e634-4428-9eac-ea255fd1eaca | Data completeness by dimension | CostsByDay, maxGroupCount |
| cb34f22b-9370-460c-9658-3e73d220bbc7 | Data quality trends | CostsByDay |
| 3b3f0a58-2d84-4e3e-bebc-3e747a7d5ede | Resource metadata consistency | CostsByMonth |

###### System Queries

| Query ID | Description | Key Variable References |
|----------|-------------|-------------------------|
| 8de47213-8327-44da-9d1b-8ba5de74c44a | Hub settings and configuration | - |
| eb9259cc-05b7-4441-a66d-a29026fe371b | Available time ranges | numberOfMonths |
| 56fd8707-bbb3-4f7e-8e37-8dd90ada3baa | Data model diagnostics | - |
| 0341b3e4-eccc-4924-9555-9835b128c543 | Data quality validation | CostsByMonth |

### 8. Tiles (`/tiles`)

---

## Appendix: Query Catalog

This section provides comprehensive documentation for each query defined in `queries.json`. For each query, you will find:

- **Query ID**
- **Description** (if available or inferred)
- **Used Variables**
- **KQL Query**

---

### Query Details

#### Query ID: 152f2041-bbc1-41e4-b155-271b2e0cf6e9
**Description:** Compares billed vs. effective costs for last month, formatted for visualization by month.
**Used Variables:** `CostsLastMonth`
**KQL:**
```kusto
let monthname = dynamic(['(ignore)', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']);
let costs = materialize(
    CostsLastMonth
    | summarize BilledCost = round(sum(BilledCost), 2), EffectiveCost = round(sum(EffectiveCost), 2) by BillingPeriodStart = startofmonth(BillingPeriodStart)
    | extend json = todynamic(strcat('[{"type":"Billed cost", "Cost":', BilledCost, '}, {"type":"Effective cost", "Cost":', EffectiveCost, '}]'))
    | mv-expand json
    | project Type = strcat(json.type, ' (', monthname[monthofyear(BillingPeriodStart)], ' ', format_datetime(BillingPeriodStart, 'yyyy'), ')'), Cost = todouble(json.Cost)
);
costs
```

#### Query ID: bc24e050-f2b9-4b4a-a08d-69fc4a4bb95e
**Description:** Summarizes billed and effective costs by month for timechart visualization.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize BilledCost = round(sum(BilledCost), 2), EffectiveCost = round(sum(EffectiveCost), 2) by BillingPeriodStart = startofmonth(BillingPeriodStart)
| render timechart
```

#### Query ID: 0d91ea4a-c81d-4a21-b708-b6af37be1eec
**Description:** Shows cost trends over time, including percent change from previous month.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
// | summarize BilledCost = round(sum(BilledCost), 2), EffectiveCost = round(sum(EffectiveCost), 2) by BillingPeriodStart = startofmonth(BillingPeriodStart)
// | render timechart
| summarize BilledCost = sum(BilledCost), EffectiveCost = sum(EffectiveCost) by BillingPeriodStart = startofmonth(BillingPeriodStart)
| order by BillingPeriodStart asc

#### Query ID: c7be613e-deb4-4779-ad75-4445e8d5e01f
**Description:** Compares budget vs. actual spending by month.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize Budget = sum(Budget), Actual = sum(EffectiveCost) by BillingPeriodStart = startofmonth(BillingPeriodStart)
| order by BillingPeriodStart asc
```

#### Query ID: 1d273b55-d2ea-427c-8a5f-01f6c240e98a
**Description:** Forecasts budget for future months.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize Forecast = sum(BudgetForecast) by BillingPeriodStart = startofmonth(BillingPeriodStart)
| order by BillingPeriodStart asc
```

#### Query ID: 4c7a7614-9b8c-415b-a4e1-d2d53c023d31
**Description:** Tracks service category budget by month, grouping minor categories as "others".
**Used Variables:** `CostsByMonth`, `maxGroupCount`
**KQL:**
```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(ServiceCategory) | summarize sum(EffectiveCost) by ServiceCategory;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = ServiceCategory in (topX)
| extend ServiceCategory = iff(inTopX, ServiceCategory, strcat('(', (count - maxGroupCount), ' others)'))
| summarize
    Budget = sum(Budget),
    Actual = sum(EffectiveCost)
    by BillingPeriodStart = startofmonth(BillingPeriodStart), ServiceCategory
| order by BillingPeriodStart asc
```

#### Query ID: ebe41e27-e9f9-478e-ab90-fd1f87906766
**Description:** Shows daily budget pacing, grouping minor categories as "others".
**Used Variables:** `CostsByDay`, `maxGroupCount`
**KQL:**
```kusto
let costs = CostsByDay;
let all = costs | where isnotempty(ServiceCategory) | summarize sum(EffectiveCost) by ServiceCategory;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = ServiceCategory in (topX)
| extend ServiceCategory = iff(inTopX, ServiceCategory, strcat('(', (count - maxGroupCount), ' others)'))
| summarize
    Budget = sum(Budget),
    Actual = sum(EffectiveCost)
    by UsageDate, ServiceCategory
| order by UsageDate asc
```

#### Query ID: 35a3a2b3-4ab0-4449-96f7-c78db789089e
**Description:** Summarizes software license utilization by month.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize LicenseUtilization = sum(LicenseUtilization) by BillingPeriodStart = startofmonth(BillingPeriodStart)
| order by BillingPeriodStart asc
```

#### Query ID: 7d0c2c1f-338b-4534-b173-36b284779131
**Description:** Analyzes SaaS spending by month.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize SaaSCost = sum(SaaSCost) by BillingPeriodStart = startofmonth(BillingPeriodStart)
| order by BillingPeriodStart asc
```

#### Query ID: 62bbceee-c089-45db-822c-0b4745358aa4
**Description:** Identifies license optimization opportunities by month.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize LicenseOptimizationOpportunity = sum(LicenseOptimizationOpportunity) by BillingPeriodStart = startofmonth(BillingPeriodStart)
| order by BillingPeriodStart asc
```

#### Query ID: e1bc2d51-44af-4dd9-8b0d-a71088b551f5
**Description:** Shows SaaS usage patterns by month.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize SaaSUsage = sum(SaaSUsage) by BillingPeriodStart = startofmonth(BillingPeriodStart)
| order by BillingPeriodStart asc
```
| extend PreviousBilledCost = prev(BilledCost)
| extend PreviousEffectiveCost = prev(EffectiveCost)
| project BillingPeriodStart
    , BilledCost = iif(isempty(PreviousBilledCost), todouble(0), todouble((BilledCost - PreviousBilledCost) * 100.0 / PreviousBilledCost))
    , EffectiveCost = iif(isempty(PreviousEffectiveCost), todouble(0), todouble((EffectiveCost - PreviousEffectiveCost) * 100.0 / PreviousEffectiveCost))
```

#### Query ID: f2cecbb0-13f8-4642-afa4-bbcc0558f777
**Description:** Counts subscriptions, resource groups, resources, and services for last month.
**Used Variables:** `CostsLastMonth`
**KQL:**
```kusto
let data = materialize(
    CostsLastMonth
    | summarize
        Subscriptions = dcount(SubAccountId),
        ResourceGroups = dcount(strcat(SubAccountId, x_ResourceGroupName)),
        Resources = dcount(ResourceId),
        Services = dcount(ServiceName)
    | project json = todynamic(strcat('[{ "Type":"Subscriptions", "Count":', Subscriptions, ' }, { "Type":"Resource groups", "Count":', ResourceGroups, ' }, { "Type":"Resources", "Count":', Resources, ' }, { "Type":"Services", "Count":', Services, ' }]'))
    | mv-expand json
    | project Label = tostring(json.Type), Count = tolong(json.Count)
);
data
```

#### Query ID: 3886b5cd-34a8-42d7-9e16-33ea4d236953
**Description:** Pivoted effective cost by month and sub-account, including totals. Useful for comparing sub-account costs across months and in aggregate.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
let data = (
    CostsByMonth
    | summarize 
        BilledCost     = sum(BilledCost),
        EffectiveCost  = sum(EffectiveCost),
        ContractedCost = sum(ContractedCost),
        ListCost       = sum(ListCost),
        SubAccountName = take_any(SubAccountName)
        by
        ChargePeriodStart = startofmonth(ChargePeriodStart),
        SubAccountId
    | as per
    | union (
        per
        | summarize 
            BilledCost     = sum(BilledCost),
            EffectiveCost  = sum(EffectiveCost),
            ContractedCost = sum(ContractedCost),
            ListCost       = sum(ListCost),
            SubAccountName = take_any(SubAccountName)
            by
            SubAccountId
    )
    | order by ChargePeriodStart asc
    | extend BilledCost                = todouble(round(BilledCost, 2))
    | extend EffectiveCost             = todouble(round(EffectiveCost, 2))
    | extend ContractedCost            = todouble(round(ContractedCost, 2))
    | extend ListCost                  = todouble(round(ListCost, 2))
    | extend CommitmentDiscountSavings = todouble(round(ContractedCost - EffectiveCost, 2))
    | extend NegotiatedDiscountSavings = todouble(round(ListCost - ContractedCost, 2))
    | extend ChargePeriod = iff(isempty(ChargePeriodStart), strcat('Total'), strcat(format_datetime(ChargePeriodStart, 'yyyy-MM - '), monthname[monthofyear(ChargePeriodStart)]))
);
data | evaluate pivot(ChargePeriod, sum(EffectiveCost), SubAccountName)
| order by Total desc

#### Query ID: 8de47213-8327-44da-9d1b-8ba5de74c44a
**Description:** Retrieves hub settings and configuration.
**Used Variables:** None
**KQL:**
```kusto
HubSettings
| project SettingName, SettingValue
```

#### Query ID: eb9259cc-05b7-4441-a66d-a29026fe371b
**Description:** Lists available time ranges for reporting.
**Used Variables:** `numberOfMonths`
**KQL:**
```kusto
range Month from 1 to numberOfMonths step 1
| project AvailableMonth = Month
```

#### Query ID: 56fd8707-bbb3-4f7e-8e37-8dd90ada3baa
**Description:** Provides data model diagnostics for the hub.
**Used Variables:** None
**KQL:**
```kusto
HubDiagnostics
| summarize Count = count() by TableName, Status
```

#### Query ID: 0341b3e4-eccc-4924-9555-9835b128c543
**Description:** Validates data quality for cost records by month.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize ValidRecords = countif(IsValid), InvalidRecords = countif(not(IsValid)) by ChargePeriodStart = startofmonth(ChargePeriodStart)
| order by ChargePeriodStart asc
```

#### Query ID: d7f31381-ba44-46a1-ad3e-dc6b8826706d
**Description:** Calculates FinOps maturity metrics by day.
**Used Variables:** `CostsByDay`
**KQL:**
```kusto
CostsByDay
| summarize MaturityScore = avg(MaturityScore) by UsageDate
| order by UsageDate asc
```

#### Query ID: e17346d1-0227-4aa4-8765-f9b4bf43bed5
**Description:** Monitors tag compliance by month.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize TagCompliancePercent = 100.0 * sum(TaggedCost) / sum(EffectiveCost) by ChargePeriodStart = startofmonth(ChargePeriodStart)
| order by ChargePeriodStart asc
```

#### Query ID: f1ef29df-7a1d-4dd0-8619-0c0164707b31
**Description:** Calculates governance policy metrics by day.
**Used Variables:** `CostsByDay`
**KQL:**
```kusto
CostsByDay
| summarize PolicyCompliancePercent = 100.0 * sum(CompliantCost) / sum(EffectiveCost) by UsageDate
| order by UsageDate asc
```

#### Query ID: 84ecad69-79ac-45b9-a8af-60be28dcc748
**Description:** Monitors resource naming compliance by day.
**Used Variables:** `CostsByDay`
**KQL:**
```kusto
CostsByDay
| summarize NamingCompliancePercent = 100.0 * sum(NamingCompliantCost) / sum(EffectiveCost) by UsageDate
| order by UsageDate asc
```

#### Query ID: dcf69b47-233e-4bc4-b914-3f6f09f4cb82
**Description:** Identifies missing tags by day.
**Used Variables:** `CostsByDay`
**KQL:**
```kusto
CostsByDay
| summarize MissingTagCount = sum(MissingTagCount) by UsageDate
| order by UsageDate asc
```

#### Query ID: 13813a00-e634-4428-9eac-ea255fd1eaca
**Description:** Shows data completeness by dimension, grouping minor categories as "others".
**Used Variables:** `CostsByDay`, `maxGroupCount`
**KQL:**
```kusto
let costs = CostsByDay;
let all = costs | where isnotempty(Dimension) | summarize sum(EffectiveCost) by Dimension;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = Dimension in (topX)
| extend Dimension = iff(inTopX, Dimension, strcat('(', (count - maxGroupCount), ' others)'))
| summarize CompletenessPercent = 100.0 * sum(CompleteCost) / sum(EffectiveCost) by UsageDate, Dimension
| order by UsageDate asc
```

#### Query ID: cb34f22b-9370-460c-9658-3e73d220bbc7
**Description:** Tracks data quality trends by day.
**Used Variables:** `CostsByDay`
**KQL:**
```kusto
CostsByDay
| summarize DataQualityScore = avg(DataQualityScore) by UsageDate
| order by UsageDate asc
```

#### Query ID: 3b3f0a58-2d84-4e3e-bebc-3e747a7d5ede
**Description:** Checks resource metadata consistency by month.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize MetadataConsistencyPercent = 100.0 * sum(ConsistentCost) / sum(EffectiveCost) by ChargePeriodStart = startofmonth(ChargePeriodStart)
| order by ChargePeriodStart asc
```

#### Query ID: 7f7b08a9-ae15-46f8-8b0f-767280375add
**Description:** Calculates chargeback allocation by distributing costs to business units or cost centers.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize ChargebackAmount = sum(EffectiveCost) by BusinessUnit, ChargePeriodStart = startofmonth(ChargePeriodStart)
| order by ChargePeriodStart asc
```

#### Query ID: 9c5d3cf0-b6cb-45a2-acfd-b19df425bddf
**Description:** Reconciles invoice amounts with daily costs, grouping minor categories as "others".
**Used Variables:** `CostsByDay`, `maxGroupCount`
**KQL:**
```kusto
let costs = CostsByDay;
let all = costs | where isnotempty(ServiceCategory) | summarize sum(EffectiveCost) by ServiceCategory;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = ServiceCategory in (topX)
| extend ServiceCategory = iff(inTopX, ServiceCategory, strcat('(', (count - maxGroupCount), ' others)'))
| summarize InvoiceAmount = sum(InvoiceAmount), Actual = sum(EffectiveCost) by UsageDate, ServiceCategory
| order by UsageDate asc
```

#### Query ID: 49e24ee0-91de-4b1c-973f-036a3c060aca
**Description:** Provides showback reporting by distributing costs to consumers, grouping minor categories as "others".
**Used Variables:** `CostsByDay`, `maxGroupCount`
**KQL:**
```kusto
let costs = CostsByDay;
let all = costs | where isnotempty(ServiceCategory) | summarize sum(EffectiveCost) by ServiceCategory;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = ServiceCategory in (topX)
| extend ServiceCategory = iff(inTopX, ServiceCategory, strcat('(', (count - maxGroupCount), ' others)'))
| summarize ShowbackAmount = sum(EffectiveCost) by UsageDate, ServiceCategory
| order by UsageDate asc
```

#### Query ID: d7a9ff96-da17-4826-9fb5-b23f4c7b938d
**Description:** Distributes costs by charge categories for each month, grouping minor categories as "others".
**Used Variables:** `CostsByMonth`, `maxGroupCount`
**KQL:**
```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(ChargeCategory) | summarize sum(EffectiveCost) by ChargeCategory;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = ChargeCategory in (topX)
| extend ChargeCategory = iff(inTopX, ChargeCategory, strcat('(', (count - maxGroupCount), ' others)'))
| summarize EffectiveCost = sum(EffectiveCost) by ChargePeriodStart = startofmonth(ChargePeriodStart), ChargeCategory
| order by ChargePeriodStart asc
```

#### Query ID: 21a87abe-19e2-44ec-8298-ba872e66c162
**Description:** Cost breakdown by resource type for each month, grouping minor types as "others". Useful for visualizing top resource types and aggregating the rest.
**Used Variables:** `CostsByMonth`, `maxGroupCount`
**KQL:**
```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(ResourceType) | summarize sum(EffectiveCost) by ResourceType;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
//
// Group rows after max count
| extend inTopX = ResourceType in (topX)
| extend ResourceType = iff(inTopX, ResourceType, strcat('(', (count - maxGroupCount), ' others)'))
//
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2)
    by
    ChargePeriodStart = startofmonth(ChargePeriodStart),
    ResourceType
| project ChargePeriodStart, EffectiveCost, Type = ResourceType
| order by EffectiveCost desc
| render columnchart
```

#### Query ID: 5bbb5369-ac95-45fc-853c-a6a2ce6a9e7b
**Description:** Calculates savings from commitment discounts by comparing effective and contracted costs.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize
    CommitmentDiscountSavings = sum(ContractedCost - EffectiveCost),
    EffectiveCost = sum(EffectiveCost)
    by BillingPeriodStart = startofmonth(BillingPeriodStart)
| project BillingPeriodStart, CommitmentDiscountSavings, EffectiveCost
| order by BillingPeriodStart asc
```

#### Query ID: 98c9b9b5-bebf-41f8-8319-5fa2523f9dd0
**Description:** Shows total commitment discount purchases by month.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize CommitmentDiscountPurchases = sum(CommitmentDiscountPurchase) by BillingPeriodStart = startofmonth(BillingPeriodStart)
| order by BillingPeriodStart asc
```

#### Query ID: 377e3693-0738-45d7-97d9-4b6e71ec5b36
**Description:** Analyzes reservation usage and savings by month.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize
    ReservationUsage = sum(ReservationUsage),
    ReservationSavings = sum(ReservationSavings)
    by BillingPeriodStart = startofmonth(BillingPeriodStart)
| order by BillingPeriodStart asc
```

#### Query ID: 13cad52d-91e7-4ab4-aad5-4aae21c1019a
**Description:** Calculates commitment discount coverage as a percentage of total cost.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
CostsByMonth
| summarize
    TotalCost = sum(EffectiveCost),
    CoveredCost = sum(CommitmentDiscountCoveredCost)
    by BillingPeriodStart = startofmonth(BillingPeriodStart)
| extend CoveragePercent = 100.0 * CoveredCost / TotalCost
| project BillingPeriodStart, CoveragePercent
| order by BillingPeriodStart asc
```

#### Query ID: 3924981c-23e4-464d-a872-045df1752750
**Description:** Cost breakdown by service category for each month, grouping minor categories as "others". Useful for visualizing top service categories and aggregating the rest.
**Used Variables:** `CostsByMonth`, `maxGroupCount`
**KQL:**
```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(ServiceCategory) | summarize sum(EffectiveCost) by ServiceCategory;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
//
// Group rows after max count
| extend inTopX = ServiceCategory in (topX)
| extend ServiceCategory = iff(inTopX, ServiceCategory, strcat('(', (count - maxGroupCount), ' others)'))
//
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2)
    by
    ChargePeriodStart,
    ServiceCategory
| project ChargePeriodStart, EffectiveCost, Category = ServiceCategory
| order by EffectiveCost desc
| render columnchart
```

#### Query ID: 90502e9a-2d0d-4ae4-8d9d-cc21f9b72d5d
**Description:** Pivoted effective cost by month and sub-account, including totals. Useful for business value metrics and unit economics.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
let data = (
    CostsByMonth
    | summarize 
        BilledCost     = sum(BilledCost),
        EffectiveCost  = sum(EffectiveCost),
        ContractedCost = sum(ContractedCost),
        ListCost       = sum(ListCost),
        SubAccountName = take_any(SubAccountName)
        by
        ChargePeriodStart,
        SubAccountId
    | as per
    | union (
        per
        | summarize 
            BilledCost     = sum(BilledCost),
            EffectiveCost  = sum(EffectiveCost),
            ContractedCost = sum(ContractedCost),
            ListCost       = sum(ListCost),
            SubAccountName = take_any(SubAccountName)
            by
            SubAccountId
    )
    | order by ChargePeriodStart asc
    | extend BilledCost                = todouble(round(BilledCost, 2))
    | extend EffectiveCost             = todouble(round(EffectiveCost, 2))
    | extend ContractedCost            = todouble(round(ContractedCost, 2))
    | extend ListCost                  = todouble(round(ListCost, 2))
    | extend CommitmentDiscountSavings = todouble(round(ContractedCost - EffectiveCost, 2))
    | extend NegotiatedDiscountSavings = todouble(round(ListCost - ContractedCost, 2))
    | extend ChargePeriod = iff(isempty(ChargePeriodStart), strcat('Total'), strcat(format_datetime(ChargePeriodStart, 'yyyy-MM - '), monthname[monthofyear(ChargePeriodStart)]))
);
data | evaluate pivot(ChargePeriod, sum(EffectiveCost), SubAccountName)
| order by Total desc
```

#### Query ID: c2c65ec0-e57d-4834-8a6b-b5975afeb9a0
**Description:** Pivoted effective cost by month, sub-account, and resource group, including totals. Useful for cost allocation and business unit reporting.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
let data = (
    CostsByMonth
    | extend x_ResourceGroupId = strcat(SubAccountId, '/resourcegroups/', x_ResourceGroupName)
    | summarize 
        EffectiveCost  = sum(EffectiveCost),
        SubAccountName = take_any(SubAccountName),
        x_ResourceGroupName = take_any(x_ResourceGroupName)
        by
        ChargePeriodStart,
        x_ResourceGroupId
    | as per
    | union (
        per
        | summarize 
            EffectiveCost  = sum(EffectiveCost),
            SubAccountName = take_any(SubAccountName),
            x_ResourceGroupName = take_any(x_ResourceGroupName)
            by
            x_ResourceGroupId
    )
    | order by ChargePeriodStart asc
    | extend EffectiveCost = todouble(round(EffectiveCost, 2))
    | extend ChargePeriod = iff(isempty(ChargePeriodStart), strcat('Total'), strcat(format_datetime(ChargePeriodStart, 'yyyy-MM - '), monthname[monthofyear(ChargePeriodStart)]))
);
data | evaluate pivot(ChargePeriod, sum(EffectiveCost), x_ResourceGroupName, SubAccountName)
| order by Total desc
```

#### Query ID: 61b26784-6a73-4e80-85b2-9c5cfbd2dd06
**Description:** Cost breakdown by resource group for each month, grouping minor groups as "others". Useful for visualizing top resource groups and aggregating the rest.
**Used Variables:** `CostsByMonth`, `maxGroupCount`
**KQL:**
```kusto
let costs = CostsByMonth | extend x_ResourceGroupId = strcat(SubAccountId, '/resourcegroups/', x_ResourceGroupName);
let all = costs | where isnotempty(x_ResourceGroupId) | summarize sum(EffectiveCost) by x_ResourceGroupId;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
//
// Group rows after max count
| extend inTopX = x_ResourceGroupId in (topX)
| extend x_ResourceGroupId = iff(inTopX, x_ResourceGroupId, otherId)
| extend x_ResourceGroupName = iff(inTopX, x_ResourceGroupName, strcat('(', (count - maxGroupCount), ' others)'))
//
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2),
    SubAccountName = take_any(SubAccountName),
    x_ResourceGroupName = take_any(x_ResourceGroupName)
    by
    ChargePeriodStart,
    x_ResourceGroupId
| project ChargePeriodStart, EffectiveCost, RG = iff(x_ResourceGroupId == otherId, x_ResourceGroupName, strcat(x_ResourceGroupName, ' (', SubAccountName, ')'))
| order by EffectiveCost desc
| render columnchart
```

#### Query ID: d5224d06-c8e7-4dd9-afec-595b39712f5a
**Description:** Cost breakdown by region for each month, grouping minor regions as "others". Useful for visualizing top regions and aggregating the rest.
**Used Variables:** `CostsByMonth`, `maxGroupCount`
**KQL:**
```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(RegionName) | summarize sum(EffectiveCost) by RegionName;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit iff(count - maxGroupCount > 1, maxGroupCount, count);
let otherId = '(others)';
costs
//
// Group rows after max count
| extend inTopX = RegionName in (topX)
| extend RegionName = iff(inTopX, RegionName, strcat('(', count - maxGroupCount, ' others)'))
//
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2)
    by
    ChargePeriodStart = startofmonth(ChargePeriodStart),
    RegionName
| project ChargePeriodStart, EffectiveCost, Region = RegionName
| order by EffectiveCost desc
```

#### Query ID: 0dcf2c54-7f1d-45e9-a53b-d598a24493a4
**Description:** Pivoted effective cost by month and region, including totals. Useful for comparing regional costs across months and in aggregate.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
let data = (
    CostsByMonth
    | summarize 
        EffectiveCost  = sum(EffectiveCost)
        by
        ChargePeriodStart = startofmonth(ChargePeriodStart),
        RegionName
    | as per
    | union (
        per
        | summarize 
            EffectiveCost  = sum(EffectiveCost)
            by
            RegionName
    )
    | order by ChargePeriodStart asc
    | extend EffectiveCost = todouble(round(EffectiveCost, 2))
    | extend ChargePeriod = iff(isempty(ChargePeriodStart), strcat('Total'), strcat(format_datetime(ChargePeriodStart, 'yyyy-MM - '), monthname[monthofyear(ChargePeriodStart)]))
);
data | evaluate pivot(ChargePeriod, sum(EffectiveCost), RegionName)
| order by Total desc
```

#### Query ID: 30644718-defd-4c6c-9ffa-a9c2cd1f871f
**Description:** Cost breakdown by service for each month, grouping minor services as "others". Useful for visualizing top services and aggregating the rest.
**Used Variables:** `CostsByMonth`, `maxGroupCount`
**KQL:**
```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(ServiceName) | summarize sum(EffectiveCost) by ServiceName;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
//
// Group rows after max count
| extend inTopX = ServiceName in (topX)
| extend ServiceName = iff(inTopX, ServiceName, otherId)
//
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2)
    by
    ChargePeriodStart,
    ServiceName
| project ChargePeriodStart, EffectiveCost, Category = ServiceName
| order by EffectiveCost desc
| render columnchart
```

#### Query ID: 6259f773-593c-4953-898c-15aa5ff6e53a
**Description:** Pivoted effective cost by month, service category, and service name, including totals. Useful for comparing service costs across months and in aggregate.
**Used Variables:** `CostsByMonth`
**KQL:**
```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
let data = (
    CostsByMonth
    | summarize 
        EffectiveCost  = sum(EffectiveCost)
        by
        ChargePeriodStart,
        ServiceCategory,
        ServiceName
    | as per
    | union (
        per
        | summarize 
            EffectiveCost  = sum(EffectiveCost)
            by
            ServiceCategory,
            ServiceName
    )
    | order by ChargePeriodStart asc
    | extend EffectiveCost = todouble(round(EffectiveCost, 2))
    | extend ChargePeriod = iff(isempty(ChargePeriodStart), strcat('Total'), strcat(format_datetime(ChargePeriodStart, 'yyyy-MM - '), monthname[monthofyear(ChargePeriodStart)]))
);
data | evaluate pivot(ChargePeriod, sum(EffectiveCost), ServiceName, ServiceCategory)
| order by Total desc
```

Contains definitions for the visual elements (tiles) that make up each dashboard page.

**Key files**:

- `about-tiles.json` - Introduction and documentation tiles
- `summary-tiles.json` - Overview cost and usage tiles
- `understand-tiles.json` - Tiles for the UNDERSTAND domain
- `optimize-tiles.json` - Tiles for the OPTIMIZE domain
- `quantify-tiles.json` - Tiles for the QUANTIFY domain
- `manage-tiles.json` - Tiles for the MANAGE domain
- `anomaly-management-tiles.json` - Anomaly detection and management tiles
- `budgeting-tiles.json` - Budget tracking and forecast tiles
- `data-ingestion-tiles.json` - Data quality and ingestion metrics tiles
- `invoicing-chargeback-tiles.json` - Invoicing and chargeback tiles
- `licensing-saas-tiles.json` - Software licensing and SaaS cost tiles
- `rate-optimization-tiles.json` - Rate optimization and savings tiles

Each tile file defines:

- Visual layout (position, size)
- Query references
- Visualization type (chart, table, card, etc.)
- Visual styling options
- Interactivity options

## Dashboard Assembly

The individual component files are assembled into the full `dashboard.json` file in the parent directory. This modular approach allows for:

1. Easier version control of individual components
2. Parallel development of different dashboard sections
3. Reuse of common elements across multiple dashboards
4. Simplified maintenance and updates

## Relationship to FinOps Framework

The dashboard components align with the FinOps Framework domains and capabilities:

1. **UNDERSTAND** domain:
   - Data ingestion and quality
   - Anomaly detection
   - Usage visualization

2. **OPTIMIZE** domain:
   - Rate optimization
   - Resource utilization
   - Licensing and SaaS optimization

3. **QUANTIFY** domain:
   - Business value metrics
   - Unit economics
   - Cost allocation

4. **MANAGE** domain:
   - Budgeting and forecasting
   - Invoicing and chargeback
   - Policy governance

## Development Guidelines

When extending or modifying the dashboard components:

1. **Queries**:
   - Use standard KQL practices
   - Reference base queries where appropriate
   - Document complex logic
   - Follow the FOCUS specification for cost data

2. **Visualization**:
   - Maintain consistent styling across similar tiles
   - Use appropriate visualization types for the data
   - Consider user interactivity needs

3. **Organization**:
   - Keep related tiles in the same tile file
   - Organize new capabilities in the appropriate domain page
   - Update documentation when adding new components

## Query Development Best Practices

When developing new queries for the dashboard:

1. **Performance Optimization**:
   - Use `materialize()` for frequently referenced subqueries
   - Apply filters early in the query pipeline
   - Limit the time range appropriately using parameters
   - Use summarization to reduce data volume before visualization

2. **Variable References**:
   - Reference base queries (e.g., `CostsByMonth`) instead of writing repetitive query logic
   - Declare query variables at the top for better readability
   - Use the `let` statement for intermediate calculations
   - Document complex variable transformations

3. **Reusability and Maintenance**:
   - Break complex queries into logical components
   - Use consistent naming conventions
   - Document the purpose and assumptions of the query
   - Follow the FOCUS data model for consistent field references

4. **Visualization Considerations**:
   - Structure query results to match the intended visualization type
   - Include appropriate sort orders for better presentation
   - Use explicit column aliases for clearer visualization mapping
   - Include formatting functions when appropriate (e.g., `round()`, `format_datetime()`)

## Usage Instructions

To modify or extend the dashboard:

1. Edit the relevant component files
2. Reassemble the dashboard using the appropriate build process
3. Deploy the updated dashboard to the Azure Data Explorer environment

For visualization testing, you can directly use the queries in the Azure Data Explorer interface before adding them to the dashboard.

## References

- [FinOps Framework Documentation](../FinOps_Framework/README.md)
- [FOCUS Specification](../../FOCUS_v1.1/README.md)
- [Azure Data Explorer Dashboard Documentation](https://docs.microsoft.com/en-us/azure/data-explorer/dashboard-overview)
- [Kusto Query Language Documentation](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)
