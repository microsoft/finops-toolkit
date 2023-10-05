# 📊 Governance workbook

![Version 0.0.1](https://img.shields.io/badge/version-0.0.1-darkgreen)
&nbsp;
[![Go to issue](https://img.shields.io/github/issues/detail/title/microsoft/cloud-hubs/104?label=roadmap)](https://github.com/microsoft/cloud-hubs/issues/104)

The governance workbook is an Azure Monitor workbook that provides a customizable single pane of glass for governance.

## Workbook Overview
Take advantage of the Azure governance workbook to easily navigate through the resource of your subscription. The purpose of this tool is to help you to identify the resources deployed into your environment and keep track on them.
The following section will help you to understand the metrics displayed in this workbook to ease your cloud usage and administration.
This tool is contain 14 sections:
-	Overview
-	Virtual Machine
-	Storage + backup
-	Network
-	PaaS
-	Security
-	Monitoring
-	Services retirement
-	Resource age
-	Tag Explorer
-	Cost management
-	Usage + limits
-	Compliance
-	Governance

:warning: If the number of result for a query is >10000, please reduce the scope (subscription number) of the analysis

## Prerequisites
This workbook requires the following least-privileged (minimum) roles:
- **Reader** : allows you to import the workbook without saving it and view all of the workbook tabs except the Cost management tab.
- **Cost Management Reader**: allows you to view the costs in the Cost management tab
- **Workbook Contributor** : allows you to import and save the workbook

## Workbook tab description
### Overview
The **overview** tab give you general information about your environment like:
-	Count of All Resources
-	Resource count per Subscription (Top 10)*
-	Resource Number by Type (Top 10)*
-	Resource count per Azure Region

## Virtual machine
The **Virtual machine** tab is focused on Compute resources to get more information about the resource count and configuration:
-	Virtual Machine Count per OS Type
-	VM by VM Type/Size (D2ms, D2v3…)
-	Virtual machine scale set capacity and size
-	Compute Disks (OS & Data Disk attached, OS & Data Disk size, OS Disk SKU)
-	Compute Networking (NIC, Private IP, Public IP attached)
-	Compute optimization
    -	Underused assets (identified by Azure Advisor)
    -	Orphaned disks
    -	Orphaned NICs
    -	Current VM Status (Creating, Starting, Running, Stopping, Stopped, Deallocating, Deallocated). To get more information about each power state, please refer to the following link : [States and billing status - Azure Virtual Machines | Microsoft Learn](https://learn.microsoft.com/en-us/azure/virtual-machines/states-billing)
    -	Virtual Machine List filtered by Power state

## Storage + backup
The **Storage + backup** tab is focused on storage and backup resources:
- Count of all resource types
- Resource details
- Storage accounts details
  - Overview
  - Capacity
- Backup details (Pre-requisite: Vault diagnostic setting needs configured with Log Analytics Workspaces)

## Network
The **Network** tab is focusing on Network resources configuration:
- Count of all network resources by resource type
-	**NSGs** is listing orphan Network Security Groups
-	**NSG Rules** (if a NSG is selected above this list) is listing all Network Security Groups rules
-	**Public Ips** is listing Public IPs (could be filtered if orphan or not)
-	**Application Gateways** is listing Application Gateways with or without any backend IP and backend Addresses (depend on the “Orphan filter parameter”)
-	**Load Balancers** is listing Load Balancers with or without empty backend pools  (depend on the “Orphan filter parameter”)

## PaaS
The **PaaS** tab is focusing PaaS resources configuration:
-	Automation is listing Automation Accounts, LogicApp Connectors, LogicApp API, Connectors, Logic Apps, Automation Runbooks, Automation Configurations.
-	App Services is listing App Service Plans, Azure Functions, API Apps, App Services, App Gateways, Front Door, API Management, App Certificates, App Config Stores
-	Data is listing CosmosDB, SQL DBs, MySQL Servers, SQL Servers, PostgreSQL Servers, PostgreSQL Flexi Servers, MariaDB Servers.
-	Storage is listing Azure File Sync, Azure Backup, Storage Accounts, Key Vaults

## Security
The **Security** tab is focusing on the security score for your subscriptions and controls
- Security Scores by Subscription
- Security Scores by Control
- Top 5 attacked resources (with High Severity)
- Top alert types
- New Alerts (Since last 24hrs)
- MITRE ATT&CK tactics
- Active Alerts

## Monitoring
The **Monitoring** tab is providing Service Health information and main events that are happening into one selected subscription:
-	All Service Health active Incident
-	All changes performed on your resources for the past one day
-	All deleted resources for the past 14 days

## Service retirement
The **Services retirement** tab shows Azure services that are being phased out so that you can mitigate affected resources

## Resource age
The **Resource age** tab is giving you more information about the resource “Creation Date” and the “Last Change Date” in the selected Subscription to help you to identify old resources and perform sanitization.

## Tag explorer
The **Tag explorer** tab help you to filter/sort your resources by Tag. You can list and identify resources with or without a specified tag name and with or without a value. Each result can be filtered by resource type.
You can also get general information on Subscription and Resource Groups.

## Cost management
The **Cost management** tab is providing you high level information about your cost and can be filtered by tag.

## Usage + limits
Many Azure services have quotas, which are the assigned number of resources for your Azure subscription. Each quota represents a specific countable resource, such as the number of virtual machines you can create, the number of storage accounts you can use concurrently, the number of networking resources you can consume, or the number of API calls to a particular service you can make.
The **Usage & limits** tab is providing this information about your subscriptions. If you need more information about quotas, see [Quotas overview](https://learn.microsoft.com/en-us/azure/quotas/quotas-overview).

## Compliance
The **Compliance** tab allow you to monitore your policy compliance, the number of failures by resources, by operations and by category.

## Governance
Microsoft Defender for Cloud continuously assesses your hybrid and multi-cloud workloads and provides you with recommendations to harden your assets and enhance your security posture.
Central security teams often experience challenges when driving the personnel within their organizations to implement recommendations. The organizations' security posture can suffer as a result.
We're introducing a brand-new, built-in governance experience to set ownership and expected remediation timeframes to resolve recommendations.
Pre-requisite: To use this governance report, you need to create security governance rules. 
To know more about this product, please use the following link : [Driving your organization to remediate security issues with recommendation governance in Microsoft Defender for Cloud | Microsoft Learn](https://learn.microsoft.com/en-us/azure/defender-for-cloud/governance-rules)



![Screenshot of the Governance workbook.](https://github.com/microsoft/finops-toolkit/assets/399533/20813257-51ba-486c-ac28-d279bb8af3ac)

<!--
On this page:

- [ℹ️ Summary](#ℹ️-summary)
- [➕ Deploy the workbook](#-deploy-the-workbook)

---

## ℹ️ Summary

<br>
-->

## ➕ Deploy the workbook

1. Confirm you have the following least-privileged roles to deploy and use the workbook:
   - **Workbook Contributor** allows you to deploy the workbook.
   - **Reader** view all of the workbook tabs.
2. [Deploy the **governance-workbook** template](../deploy/README.md).
   > [![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.costmanagement%2Fgovernance-workbook%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.costmanagement%2Fgovernance-workbook%2FcreateUiDefinition.json) &nbsp; [![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.costmanagement%2Fgovernance-workbook%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.costmanagement%2Fgovernance-workbook%2FcreateUiDefinition.json)
