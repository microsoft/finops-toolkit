---
layout: default
parent: Governance workbook
title: Details
nav_order: 2
description: "Details about what's included in the governance workbook."
permalink: /governance-workbook/details
---

<span class="fs-9 d-block mb-4">Governance workbook details</span>
Learn about the resource details and metrics covered by the governance workbook.
{: .fs-6 .fw-300 }

[Deploy](./README.md#-deploy-the-workbook){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Learn more](#ℹ️-overview){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
  <summary class="fs-2 text-uppercase">On this page</summary>

- [ℹ️ Overview](#ℹ️-overview)
- [🖥️ Virtual machine](#️-virtual-machine)
- [🗃️ Storage + backup](#️-storage--backup)
- [🛜 Network](#-network)
- [🎛️ PaaS](#️-paas)
- [🔐 Security](#-security)
- [🔍 Monitoring](#-monitoring)
- [🪦 Service retirement](#-service-retirement)
- [🔢 Resource age](#-resource-age)
- [🏷️ Tag explorer](#️-tag-explorer)
- [💹 Cost Management](#-cost-management)
- [📊 Usage + limits](#-usage--limits)
- [📋 Compliance](#-compliance)
- [🎚️ Governance](#️-governance)

</details>

---

The Azure governance workbook enables you to easily identify and track Azure resources deployed into your environment. This page details the tabs and information you'll find within the workbook.

<blockquote class="tip" markdown="1">
  _Azure Resource Graph queries are limited to 10,000 results. If you receive an error for too many rows, try selecting a smaller management group or reducing the number of subscriptions._
</blockquote>

<br>

## ℹ️ Overview

The **overview** tab provides general information about your environment, including:

- Number of resources
- Resource count by subscription (top 10)
- Resource Number by type (top 10)
- Resource count by Azure region

<br>

## 🖥️ Virtual machine

The **Virtual machine** tab is focused on Compute resources to get more information about the resource count and configuration:

- Virtual machine count by OS type
- Virtual machines by type/size (e.g., D2ms, D2v3)
- Virtual machine scale set capacity and size
- Compute disks (OS & data disk attached, OS & data disk size, OS disk SKU)
- Compute networking (NIC, private IP, public IP attached)
- Managed disk utilization
- Compute optimization
  - Underused assets (identified by Azure Advisor)
  - Orphaned disks
  - Orphaned NICs
  - Current VM status (Creating, Starting, Running, Stopping, Stopped, Deallocating, Deallocated)
    <blockquote class="note" markdown="1">
      _For more information about each power state, please refer to [Azure VM states and billing status](https://learn.microsoft.com/azure/virtual-machines/states-billing)._
    </blockquote>
  - Virtual machine list filtered by power state

<br>

## 🗃️ Storage + backup

The **Storage + backup** tab is focused on storage and backup resources:

- Number of resource types
- Resource details
- Storage accounts details
  - Overview
  - Capacity
- Backup details
  <blockquote class="important" markdown="1">
    _Vault diagnostic setting needs configured in Log Analytics Workspaces in order to see backup details._
  </blockquote>

<br>

## 🛜 Network

The **Network** tab is focusing on network resource configuration:

- Number of network resources by resource type
- **NSGs** shows all or orphaned network security groups
- **NSG rules** shows network security group rules for the selected NSG from the pervious list
- **Public IPs** shows all or orphaned public IPs
- **Application gateways** shows all or orphaned application gateways with or without any backend IP and backend addresses
- **Load balancers** shows all or orphaned load balancers with or without empty backend pools

<br>

## 🎛️ PaaS

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

## 🔐 Security

The **Security** tab is focusing on the security score for your subscriptions and controls

- Security scores by subscription
- Security scores by control
- Top 5 attacked resources (with high severity)
- Top alert types
- New alerts in last 24 hours
- MITRE ATT&CK tactics
- Active alerts

<br>

## 🔍 Monitoring

The **Monitoring** tab shows Service Health information and main events impacting selected subscriptions:

- All Service Health active incident
- All changes performed on your resources for the past one day
- All deleted resources for the past 14 days

<br>

## 🪦 Service retirement

The **Services retirement** tab shows Azure services that are being phased out in order to mitigate affected resources.

<br>

## 🔢 Resource age

The **Resource age** tab shows information about the creation and last change dates for resources in the selected subscription to help you identify old resources and perform sanitization.

<br>

## 🏷️ Tag explorer

The **Tag explorer** tab helps you to filter/sort your resources by tag. You can list and identify resources with or without a specified tag name and with or without a value. Each result can be filtered by resource type.

You can also get general information on subscriptions and resource groups.

<br>

## 💹 Cost Management

The **Cost Management** tab shows high level information about your cost and can be filtered by tag.

<br>

## 📊 Usage + limits

Many Azure services have quotas, which are the assigned number of resources for your Azure subscription. Each quota represents a specific countable resource, such as the number of virtual machines you can create, the number of storage accounts you can use concurrently, the number of networking resources you can consume, or the number of API calls to a particular service you can make.

The **Usage & limits** tab shows resource this information about your subscriptions. To learn more about quotas, see [Quotas overview](https://learn.microsoft.com/azure/quotas/quotas-overview).

<br>

## 📋 Compliance

The **Compliance** tab helps you monitor policy compliance, the number of failures by resource, operation, and category.

<br>

## 🎚️ Governance

Microsoft Defender for Cloud continuously assesses your hybrid and multi-cloud workloads and provides you with recommendations to harden your assets and enhance your security posture.

Central security teams often experience challenges when driving the personnel within their organizations to implement recommendations. The organizations' security posture can suffer as a result.

We're introducing a brand-new, built-in governance experience to set ownership and expected remediation timeframes to resolve recommendations.

Pre-requisite: To use this governance report, you need to create security governance rules.

To learn more, refer to [Driving your organization to remediate security issues with recommendation governance in Microsoft Defender for Cloud](https://learn.microsoft.com/azure/defender-for-cloud/governance-rules).

<br>
