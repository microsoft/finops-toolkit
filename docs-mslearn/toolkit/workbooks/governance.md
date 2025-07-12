---
title: Governance workbook
description: Azure Monitor workbook focused on governance, providing an overview of your Azure environment's governance posture and compliance.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: nteyan
#customer intent: As a FinOps user, I want to understand what the FinOps Governance workbook is and how it can help me implement the Cloud policy and governance capability.
---

<!-- markdownlint-disable-next-line MD025 -->
# Governance workbook

The governance workbook is an Azure Monitor workbook that provides a comprehensive overview of the governance posture of your Azure environment. It includes the standard metrics aligned with the Cloud Adoption Framework for all disciplines and has the capability to identify and apply recommendations to address noncompliant resources.

:::image type="content" source="./media/governance/overview-governance.png" border="true" alt-text="Screenshot showing the Governance workbook overview page." lightbox="./media/governance/overview-governance.png":::

This article details the tabs and information you find within the workbook.

> [!NOTE]
> Azure Resource Graph queries are limited to 10,000 results. If you receive an error for too many rows, try selecting a smaller management group or reducing the number of subscriptions.

<br>

## Overview

The **overview** tab provides general information about your environment, including:

- Number of resources
- Resource count by subscription (top 10)
- Resource Number by type (top 10)
- Resource count by Azure region

<br>

## Virtual machine

The **Virtual machine** tab is focused on Compute resources to get more information about the resource count and configuration:

- Virtual machine count by OS type
- Virtual machines by type/size (for example, D2ms, D2v3)
- Virtual machine scale set capacity and size
- Compute disks (OS & data disk attached, OS & data disk size, OS disk SKU)
- Compute networking (NIC, private IP, public IP attached)
- Managed disk utilization
- Compute optimization
  - Underused assets (identified by Azure Advisor)
  - Orphaned disks
  - Orphaned NICs
  - Current VM status (Creating, Starting, Running, Stopping, Stopped, Deallocating, Deallocated)
    - For more information about each power state, see [Azure VM states and billing status](/azure/virtual-machines/states-billing).
  - Virtual machine list filtered by power state

<br>

## Storage + backup

The **Storage + backup** tab is focused on storage and backup resources:

- Number of resource types
- Resource details
- Storage accounts details
  - Overview
  - Capacity
- Backup details
  > [!IMPORTANT]
  > Vault diagnostic setting needs configured in Log Analytics Workspaces in order to see backup details.

<br>

## Network

The **Network** tab is focusing on network resource configuration:

- Number of network resources by resource type
- **NSGs** shows all or orphaned network security groups
- **NSG rules** shows network security group rules for the selected NSG from the pervious list
- **Public IPs** shows all or orphaned public IPs
- **Application gateways** shows all or orphaned application gateways with or without any backend IP and backend addresses
- **Load balancers** shows all or orphaned load balancers with or without empty backend pools

<br>

## PaaS

The **PaaS** tab is focusing platform as a service resource configuration:

- **Automation** shows:
  - Azure Automation accounts, runbooks, and configurations
  - Logic App instances, APIs, and connectors
- **App services** shows:
  - App Service plans, apps, and certificates
  - Azure Functions
  - API Apps
  - App gateways
  - Front Door
  - API Management
  - App Config stores
- **Data** shows:
  - Cosmos DB accounts
  - SQL servers, databases
  - PostgreSQL servers (including flexible servers)
  - MySQL servers
  - MariaDB servers

<!--
  - **Storage** shows:
    - Azure File Sync
    - Azure Backup
    - Storage accounts
    - Key Vaults
-->

<br>

## Security

The **Security** tab is focusing on the security score for your subscriptions and controls

- Security scores by subscription
- Security scores by control
- Top 5 attacked resources (with high severity)
- Top alert types
- New alerts in last 24 hours
- MITRE ATT&CK tactics
- Active alerts

<br>

## Monitoring

The **Monitoring** tab shows Service Health information and main events impacting selected subscriptions:

- All Service Health active incident
- All changes performed on your resources for the past one day
- All deleted resources for the past 14 days

<br>

## Service retirement

The **Services retirement** tab shows Azure services that are being phased out in order to mitigate affected resources.

<br>

## Resource age

The **Resource age** tab shows information about the creation and last change dates for resources in the selected subscription to help you identify old resources and perform sanitization.

<br>

## Tag explorer

The **Tag explorer** tab helps you to filter/sort your resources by tag. You can list and identify resources with or without a specified tag name and with or without a value. You can filter each result by resource type.

You can also get general information on subscriptions and resource groups.

<br>

## Cost Management

The **Cost Management** tab shows high level information about your cost and can be filtered by tag.

<br>

## Usage + limits

Many Azure services have quotas, which are the assigned number of resources for your Azure subscription. Each quota represents a specific countable resource, such as:

- The number of virtual machines you can create
- The number of storage accounts you can use concurrently
- The number of networking resources you can consume
- The number of API calls to a particular service you can make

The **Usage & limits** tab shows resource this information about your subscriptions. To learn more about quotas, see [Quotas overview](/azure/quotas/quotas-overview).

<br>

## Compliance

The **Compliance** tab helps you monitor policy compliance, the number of failures by resource, operation, and category.

<br>

## Governance

Microsoft Defender for Cloud continuously assesses your hybrid and multicloud workloads and provides you with recommendations to harden your assets and enhance your security posture.

Central security teams often experience challenges when driving the personnel within their organizations to implement recommendations. The organizations' security posture can suffer as a result.

We're introducing a brand-new, built-in governance experience to set ownership and expected remediation timeframes to resolve recommendations.

Prerequisite: To use this governance report, you need to create security governance rules.

For more information, see [Driving your organization to remediate security issues with recommendation governance in Microsoft Defender for Cloud](/azure/defender-for-cloud/governance-rules).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20workbooks%3F/cvaQuestion/How%20valuable%20are%20FinOps%20workbooks%3F/surveyId/FTK0.12/bladeName/Workbooks.Governance/featureName/Overview)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20Workbooks%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related FinOps capabilities:

- [Cloud policy and governance](../../framework/manage/governance.md)

Related products:

- [Azure Policy](/azure/governance/policy/)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Advisor](/azure/advisor/)

Related solutions:

- [Optimization engine](../optimization-engine/overview.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
