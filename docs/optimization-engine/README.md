---
layout: default
title: Optimization Engine
has_children: true
nav_order: 40
description: 'The Azure Optimization Engine (AOE) is an extensible solution designed to generate optimization recommendations for your Azure environment.'
permalink: /optimization-engine
---

<span class="fs-9 d-block mb-4">Azure Optimization Engine</span>
An extensible solution designed to generate optimization recommendations for your Azure environment.
{: .fs-6 .fw-300 }

[Deploy](#-deployment-instructions){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Learn more](#️-why-an-optimization-engine){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🙋‍♀️ Why an Optimization Engine?](#️-why-an-optimization-engine)
- [🌟 Benefits](#-benefits)
- [📦 What's included](#-whats-included)
- [🔐 Requirements](#-requirements)
- [➕ Deployment instructions](#-deployment-instructions)
- [🛫 Get started with AOE](#-get-started-with-aoe)

</details>

---

The Azure Optimization Engine (AOE) is an extensible solution designed to generate optimization recommendations for your Azure environment. See it like a fully customizable Azure Advisor.

## 🙋‍♀️ Why an Optimization Engine?

The Azure Optimization Engine (AOE) was initially developed to augment Virtual Machine right-size recommendations coming from Azure Advisor with additional metrics and properties (see the whole blog series dedicated to this idea, starting [here](https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/augmenting-azure-advisor-cost-recommendations-for-automated/ba-p/1339298)) but quickly evolved to a generic framework for [Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/)-inspired optimizations of all
kinds, developed by the community. Besides the recommendations generated by Azure Advisor, AOE includes several custom recommendations, mostly from the Cost pillar, and allows for the rapid development of new ones. AOE complements Azure Advisor and other first party Azure services with additional optimization insights and allows for full customization.

## 🌟 Benefits

Besides collecting **all Azure Advisor recommendations**, AOE includes other custom recommendations that you can tailor to your needs, such as:

* 💰 Cost
    * Augmented Advisor Cost VM right-size recommendations, with fit score based on Virtual Machine guest OS metrics (collected by Log Analytics or Azure Monitor agents) and Azure properties
    * Underutilized VM Scale Sets, Premium SSD Disks, App Service Plans, and Azure SQL Databases (DTU-based SKUs only)
    * Orphaned Disks and Public IPs
    * Standard Load Balancers or Application Gateways without backend pool
    * VMs deallocated since a long time ago (forgotten VMs)
    * Storage Accounts without retention policy in place
    * App Service Plans without any application
    * Stopped (not deallocated) Virtual Machines
* ☔ High Availability
    * Virtual Machine high availability (availability zones count, availability set, managed disks, storage account distribution when using unmanaged disks)
    * VM Scale Set high availability (availability zones count, managed disks)
    * Availability Sets structure (fault/update domains count)
* 🎯 Performance
    * VM Scale Sets constrained by lack of compute resources
    * SQL Databases constrained by lack of resources (DTU-based SKUs only)
    * App Service Plans constrained by lack of compute resources
* 👮 Security
    * Service Principal credentials/certificates without expiration date
    * NSG rules referring to empty/inexisting subnets, orphan/removed NICs, and orphan/removed Public IPs
* 🏅 Operational Excellence
    * Basic Load Balancers without backend pool
    * Service Principal credentials/certificates expired or about to expire
    * Subscriptions and Management Groups close to the maximum limit of RBAC assignments
    * Subscriptions close to the maximum limit of resource groups
    * Empty subnets and subnets with low free IP space or with too much IP space wasted
    * Orphaned NICs

In addition to the custom recommendations generated every week, AOE includes a set of Azure Workbooks providing deep insights about Azure commitments (Reservations and Savings Plans), Azure Storage usage, Cost anomalies, Identity and RBAC Governance ([see blog post](https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/azure-identities-and-roles-governance-dashboard-at-your/ba-p/3068613)), and Azure Policy compliance.

## 📦 What's included

AOE includes the following resources:

- Storage account to hold all raw data exports
- Log Analytics workspace where data is ingested and processed to generate recommendations and insights
- Azure Automation instance to manage data ingestion and recommendations generation logic
- Azure SQL Database to hold up to 1 year of recommendations history, ingestion control data, and recommendations suppression records
- The following Azure Workbooks, sitting on top of the Log Analytics data:
    - Benefits Simulation
    - Benefits Usage
    - Block Blob Storage Usage
    - Costs Growing
    - Identities and Roles
    - Policy Compliance
    - Recommendations
    - Reservations Potential
    - Reservations Usage
    - Resources Inventory
    - Savings Plans Usage
- A Power BI report with the most recent recommendations

Once deployed and after all the initial ingestion and recommendations generation automation has finished (typically after 3 hours), you can report on the data with the
help of Azure Workbooks or Power BI.

## 🔐 Requirements

* A supported Azure subscription (see the [FAQ](./faq.md))
* A user account with Owner permissions over the chosen subscription, so that the Automation Managed Identity is granted the required privileges over the subscription (Reader) and deployment resource group (Contributor)
* Azure Powershell 6.6.0+
* (Optional, for Identity and RBAC governance) Microsoft.Graph.Authentication and Microsoft.Graph.Identity.DirectoryManagement PowerShell modules (version 2.4.0+)
* (Optional, for Identity and RBAC governance) A user account with at least Privileged Role Administrator permissions over the Microsoft Entra tenant, so that the Managed Identity is granted the required privileges over Microsoft Entra ID (Global Reader)
* (Optional, for Azure commitments insights) A user account with administrative privileges over the Enterprise Agreement (Enterprise Enrollment Administrator) or the Microsoft Customer Agreement (Billing Profile Owner), so that the Managed Identity is granted the required privileges over your consumption agreement

During deployment, you'll be asked several questions. You must plan for the following:

* Whether you're going to reuse an existing Log Analytics Workspace or a create a new one. **IMPORTANT**: you should ideally reuse a workspace where you have VMs already sending performance metrics (`Perf` table), otherwise you will not fully leverage the augmented right-size recommendations capability. If this is not possible/desired for some reason, you can still manage to use multiple workspaces (see [Configuring workspaces](./configuring-workspaces.md)).
* An Azure subscription to deploy the solution (if you're reusing a Log Analytics workspace, you must deploy into the same subscription the workspace is in).
* A unique name prefix for the Azure resources being created (if you have specific naming requirements, you can also choose resource names during deployment)
* Azure region
* (Optional, for Azure commitments insights) Enterprise Agreement Billing Account ID (EA/MCA customers) and the Billing Profile IDs (MCA customers) 

## ➕ Deployment instructions

The simplest, quickest and recommended method for installing AOE is by using the **Azure Cloud Shell** (PowerShell). You just have to follow these steps:

1. Open Azure Cloud Shell (PowerShell)
2. Run `git clone https://github.com/microsoft/finops-toolkit.git finops-toolkit`
3. Run `cd finops-toolkit/src/optimization-engine`
4. (optional) Run `Install-Module Microsoft.Graph.Authentication,Microsoft.Graph.Identity.DirectoryManagement` - this is required to grant the Global Reader role to the Automation Managed Identity in Microsoft Entra ID, used by Identity and RBAC governance features.
5. Run `./Deploy-AzureOptimizationEngine.ps1`
6. Input your deployment options and let the deployment finish (it will take less than 5 minutes)

If the deployment fails for some reason, you can simply repeat it, as it is idempotent. The same if you want to upgrade a previous deployment with the latest version of the repo. You just have to keep the same deployment options. _Cool feature_: the deployment script persists your previous deployment options and lets you reuse it! 

If you don't want to use Azure Cloud Shell and prefer instead to run the deployment from your workstation's file system, you must first install the Az Powershell module (instructions [here](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)) and also the Microsoft.Graph modules (instructions [here](https://docs.microsoft.com/en-us/graph/powershell/installation)).

Optionally, you can specify the set of tags you want to assign to your AOE resources, by using the `ResourceTags` input parameter. For example:

```powershell
$tags = @{"Service"="aoe";"Environment"="Demo"}
.\Deploy-AzureOptimizationEngine.ps1 -ResourceTags $tags
```

## 🛫 Get started with AOE

After deploying AOE, there are several ways for you to get started (you have to wait at least 3 hours before seeing data):

1. Explore the several available Azure Workbooks, starting with the `Recommendations` one. AOE Workbooks are available from within the Log Analytics workspace chosen during installation (check the `Workbooks` blade inside the workspace). See [Reports](./reports.md) for more details.

1. Open the built-in Power BI report to get deeper insights about recommendations and customize it to your needs. See [Reports](./reports.md) for more details.

1. Customize AOE by widening the scope of the engine or adjusting thresholds to your needs (this can be done right after deployment). For all the available customization details, check [Customizations](./customizing-aoe.md).

1. For richer virtual machine right-size recommendations, you can add your machines' performance logs to the scope of AOE. Check [Configuring workspaces](./configuring-workspaces.md).

Every week at the same time, AOE recommendations will be updated according to the current state of your environment.

<br>