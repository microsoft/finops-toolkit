---
layout: default
parent: Governance workbook
title: Details
nav_order: 2
description: "Details about what's included in the FinOps hub template."
permalink: /governance-workbook/details
---

<span class="fs-9 d-block mb-4">Governance workbook details</span>
Learn about the resource details and metrics covered by the governance workbook.
{: .fs-6 .fw-300 }

[Deploy](./README.md#-create-a-new-hub){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
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

The **overview** tab give you general information about your environment like:

- Count of All Resources
- Resource count per Subscription (Top 10)\*
- Resource Number by Type (Top 10)\*
- Resource count per Azure Region

<br>

## 🖥️ Virtual machine

The **Virtual machine** tab is focused on Compute resources to get more information about the resource count and configuration:

- Virtual Machine Count per OS Type
- VM by VM Type/Size (D2ms, D2v3…)
- Virtual machine scale set capacity and size
- Compute Disks (OS & Data Disk attached, OS & Data Disk size, OS Disk SKU)
- Compute Networking (NIC, Private IP, Public IP attached)
- Compute optimization
  - Underused assets (identified by Azure Advisor)
  - Orphaned disks
  - Orphaned NICs
  - Current VM Status (Creating, Starting, Running, Stopping, Stopped, Deallocating, Deallocated). To get more information about each power state, please refer to the following link : [States and billing status - Azure Virtual Machines | Microsoft Learn](https://learn.microsoft.com/en-us/azure/virtual-machines/states-billing)
  - Virtual Machine List filtered by Power state

<br>

## 🗃️ Storage + backup

The **Storage + backup** tab is focused on storage and backup resources:

- Count of all resource types
- Resource details
- Storage accounts details
  - Overview
  - Capacity
- Backup details (Pre-requisite: Vault diagnostic setting needs configured with Log Analytics Workspaces)

<br>

## 🛜 Network

The **Network** tab is focusing on Network resources configuration:

- Count of all network resources by resource type
- **NSGs** is listing orphan Network Security Groups
- **NSG Rules** (if a NSG is selected above this list) is listing all Network Security Groups rules
- **Public Ips** is listing Public IPs (could be filtered if orphan or not)
- **Application Gateways** is listing Application Gateways with or without any backend IP and backend Addresses (depend on the “Orphan filter parameter”)
- **Load Balancers** is listing Load Balancers with or without empty backend pools (depend on the “Orphan filter parameter”)

<br>

## 🎛️ PaaS

The **PaaS** tab is focusing PaaS resources configuration:

- Automation is listing Automation Accounts, LogicApp Connectors, LogicApp API, Connectors, Logic Apps, Automation Runbooks, Automation Configurations.
- App Services is listing App Service Plans, Azure Functions, API Apps, App Services, App Gateways, Front Door, API Management, App Certificates, App Config Stores
- Data is listing CosmosDB, SQL DBs, MySQL Servers, SQL Servers, PostgreSQL Servers, PostgreSQL Flexi Servers, MariaDB Servers.
- Storage is listing Azure File Sync, Azure Backup, Storage Accounts, Key Vaults

<br>

## 🔐 Security

The **Security** tab is focusing on the security score for your subscriptions and controls

- Security Scores by Subscription
- Security Scores by Control
- Top 5 attacked resources (with High Severity)
- Top alert types
- New Alerts (Since last 24hrs)
- MITRE ATT&CK tactics
- Active Alerts

<br>

## 🔍 Monitoring

The **Monitoring** tab is providing Service Health information and main events that are happening into one selected subscription:

- All Service Health active Incident
- All changes performed on your resources for the past one day
- All deleted resources for the past 14 days

<br>

## 🪦 Service retirement

The **Services retirement** tab shows Azure services that are being phased out so that you can mitigate affected resources

<br>

## 🔢 Resource age

The **Resource age** tab is giving you more information about the resource “Creation Date” and the “Last Change Date” in the selected Subscription to help you to identify old resources and perform sanitization.

<br>

## 🏷️ Tag explorer

The **Tag explorer** tab help you to filter/sort your resources by Tag. You can list and identify resources with or without a specified tag name and with or without a value. Each result can be filtered by resource type.

You can also get general information on subscriptions and resource groups.

<br>

## 💹 Cost Management

The **Cost management** tab is providing you high level information about your cost and can be filtered by tag.

<br>

## 📊 Usage + limits

Many Azure services have quotas, which are the assigned number of resources for your Azure subscription. Each quota represents a specific countable resource, such as the number of virtual machines you can create, the number of storage accounts you can use concurrently, the number of networking resources you can consume, or the number of API calls to a particular service you can make.

The **Usage & limits** tab provides this information about your subscriptions. To learn more about quotas, see [Quotas overview](https://learn.microsoft.com/en-us/azure/quotas/quotas-overview).

<br>

## 📋 Compliance

The **Compliance** tab allow you to monitore your policy compliance, the number of failures by resources, by operations and by category.

<br>

## 🎚️ Governance

Microsoft Defender for Cloud continuously assesses your hybrid and multi-cloud workloads and provides you with recommendations to harden your assets and enhance your security posture.

Central security teams often experience challenges when driving the personnel within their organizations to implement recommendations. The organizations' security posture can suffer as a result.

We're introducing a brand-new, built-in governance experience to set ownership and expected remediation timeframes to resolve recommendations.

Pre-requisite: To use this governance report, you need to create security governance rules.

To know more about this product, please use the following link : [Driving your organization to remediate security issues with recommendation governance in Microsoft Defender for Cloud | Microsoft Learn](https://learn.microsoft.com/en-us/azure/defender-for-cloud/governance-rules)

<br>
