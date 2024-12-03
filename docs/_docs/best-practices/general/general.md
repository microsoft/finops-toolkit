---
layout: default
parent: Best practices
permalink: /best-practices/General
title: General
nav_order: 0
author: arclares
ms.date: 08/16/2024
ms.service: finops
description: 'Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.'

---

<span class="fs-9 d-block mb-4">General best practices</span>
Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.
{: .fs-6 .fw-300 }

[Share feedback](#️-looking-for-more){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Resource inventory summary](#resource-inventory-summary)
- [Carbon Optimization](#carbon-optimization)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---

## Resource inventory summary

### Query: Count of all resources

This Azure Resource Graph (ARG) query counts all resources within the specified scope.

<h4>Category</h4>

Inventory

<h4>Query</h4>

```kql
Resources
| summarize count()
```

<br>

### Query: Count of all resources per subscription

This Azure Resource Graph (ARG) query counts all resources within the specified scope per subscription.

<h4>Category</h4>

Inventory

<h4>Query</h4>

```kql
resources
| summarize Count=count(id) by subscriptionId
| order by Count desc
```

<br>

### Query: Count of all resources per type

This Azure Resource Graph (ARG) query counts all resources within the specified scope per type.

<h4>Category</h4>

Inventory

<h4>Query</h4>

```kql
Resources 
| extend type = case(
type contains 'microsoft.netapp/netappaccounts', 'NetApp Accounts',
type contains "microsoft.compute", "Azure Compute",
type contains "microsoft.logic", "LogicApps",
type contains 'microsoft.keyvault/vaults', "Key Vaults",
type contains 'microsoft.storage/storageaccounts', "Storage Accounts",
type contains 'microsoft.compute/availabilitysets', 'Availability Sets',
type contains 'microsoft.operationalinsights/workspaces', 'Azure Monitor Resources',
type contains 'microsoft.operationsmanagement', 'Operations Management Resources',
type contains 'microsoft.insights', 'Azure Monitor Resources',
type contains 'microsoft.desktopvirtualization/applicationgroups', 'WVD Application Groups',
type contains 'microsoft.desktopvirtualization/workspaces', 'WVD Workspaces',
type contains 'microsoft.desktopvirtualization/hostpools', 'WVD Hostpools',
type contains 'microsoft.recoveryservices/vaults', 'Backup Vaults',
type contains 'microsoft.web', 'App Services',
type contains 'microsoft.managedidentity/userassignedidentities','Managed Identities',
type contains 'microsoft.storagesync/storagesyncservices', 'Azure File Sync',
type contains 'microsoft.hybridcompute/machines', 'ARC Machines',
type contains 'Microsoft.EventHub', 'Event Hub',
type contains 'Microsoft.EventGrid', 'Event Grid',
type contains 'Microsoft.Sql', 'SQL Resources',
type contains 'Microsoft.HDInsight/clusters', 'HDInsight Clusters',
type contains 'microsoft.devtestlab', 'DevTest Labs Resources',
type contains 'microsoft.containerinstance', 'Container Instances Resources',
type contains 'microsoft.portal/dashboards', 'Azure Dashboards',
type contains 'microsoft.containerregistry/registries', 'Container Registry',
type contains 'microsoft.automation', 'Automation Resources',
type contains 'sendgrid.email/accounts', 'SendGrid Accounts',
type contains 'microsoft.datafactory/factories', 'Data Factory',
type contains 'microsoft.databricks/workspaces', 'Databricks Workspaces',
type contains 'microsoft.machinelearningservices/workspaces', 'Machine Learnings Workspaces',
type contains 'microsoft.alertsmanagement/smartdetectoralertrules', 'Azure Monitor Resources',
type contains 'microsoft.apimanagement/service', 'API Management Services',
type contains 'microsoft.dbforpostgresql', 'PostgreSQL Resources',
type contains 'microsoft.scheduler/jobcollections', 'Scheduler Job Collections',
type contains 'microsoft.visualstudio/account', 'Azure DevOps Organization',
type contains 'microsoft.network/', 'Network Resources',
type contains 'microsoft.migrate/' or type contains 'microsoft.offazure', 'Azure Migrate Resources',
type contains 'microsoft.servicebus/namespaces', 'Service Bus Namespaces',
type contains 'microsoft.classic', 'ASM Obsolete Resources',
type contains 'microsoft.resources/templatespecs', 'Template Spec Resources',
type contains 'microsoft.virtualmachineimages', 'VM Image Templates',
type contains 'microsoft.documentdb', 'CosmosDB DB Resources',
type contains 'microsoft.alertsmanagement/actionrules', 'Azure Monitor Resources',
type contains 'microsoft.kubernetes/connectedclusters', 'ARC Kubernetes Clusters',
type contains 'microsoft.purview', 'Purview Resources',
type contains 'microsoft.security', 'Security Resources',
type contains 'microsoft.cdn', 'CDN Resources',
type contains 'microsoft.devices','IoT Resources',
type contains 'microsoft.datamigration', 'Data Migraiton Services',
type contains 'microsoft.cognitiveservices', 'Congitive Services',
type contains 'microsoft.customproviders', 'Custom Providers',
type contains 'microsoft.appconfiguration', 'App Services',
type contains 'microsoft.search', 'Search Services',
type contains 'microsoft.maps', 'Maps',
type contains 'microsoft.containerservice/managedclusters', 'AKS',
type contains 'microsoft.signalrservice', 'SignalR',
type contains 'microsoft.resourcegraph/queries', 'Resource Graph Queries',
type contains 'microsoft.batch', 'MS Batch',
type contains 'microsoft.analysisservices', 'Analysis Services',
type contains 'microsoft.synapse/workspaces', 'Synapse Workspaces',
type contains 'microsoft.synapse/workspaces/sqlpools', 'Synapse SQL Pools',
type contains 'microsoft.kusto/clusters', 'ADX Clusters',
type contains 'microsoft.resources/deploymentscripts', 'Deployment Scripts',
type contains 'microsoft.aad/domainservices', 'AD Domain Services',
type contains 'microsoft.labservices/labaccounts', 'Lab Accounts',
type contains 'microsoft.automanage/accounts', 'Automanage Accounts',
type contains 'microsoft.relay/namespaces', 'Azure Relay',
type contains 'microsoft.notificationhubs/namespaces', 'Notification Hubs',
type contains 'microsoft.digitaltwins/digitaltwinsinstances', 'Digital Twins',
type contains 'microsoft.monitor/accounts', 'Monitor Accounts',
type contains 'microsoft.dashboard/grafana', 'Grafana',
type contains 'microsoft.scom/managedinstances', 'SCOM Managed instances',
type contains 'microsoft.datareplication/replicationvaults', 'Replication Vaults',
type contains 'microsoft.avs/privateclouds', 'Azure VMWare Solution',
type contains 'microsoft.machinelearningservices/registries', 'Machine learning registries',
type contains 'microsoft.dbformysql/flexibleservers', 'MySQL flexible servers',
type contains 'microsoft.dataprotection/backupvaults', 'Backup vaults',
strcat("Not Translated: ", type))
| summarize count() by type
| order by count_ desc
```

<br>

### Query: Count of all resources per region

This Azure Resource Graph (ARG) query counts all resources within the specified scope per region.

<h4>Category</h4>

Inventory

<h4>Query</h4>

```kql
resources
| summarize count() by location
```

<br>

## Carbon Optimization

### Query: Carbon emissions

This Azure Resource Graph (ARG) query identifies resources within your Azure environment that have recommendations for reducing carbon emissions, based on Azure Advisor recommendations.

<h4>Description</h4>

This query surfaces Azure resources with recommendations from Azure Advisor for optimizing carbon emissions. It highlights potential carbon savings and provides insights into how these recommendations can be implemented to reduce the carbon footprint of your cloud infrastructure.

<h4>Category</h4>

Sustainability

<h4>Query</h4>

```kql
advisorresources
| where tolower(type) == "microsoft.advisor/recommendations"
| extend RecommendationTypeId = tostring(properties.recommendationTypeId)
| where RecommendationTypeId in ("94aea435-ef39-493f-a547-8408092c22a7", "e10b1381-5f0a-47ff-8c7b-37bd13d7c974")
| extend properties = parse_json(properties)
| project
    subscriptionId,
    resourceGroup,
    ResourceId = properties.resourceMetadata.resourceId,
    ResourceType = tostring(properties.impactedField),
    shortDescription = properties.shortDescription.problem,
    recommendationType = properties.extendedProperties.recommendationType,
    recommendationMessage = properties.extendedProperties.recommendationMessage,
    PotentialMonthlyCarbonEmissions = properties.extendedProperties.PotentialMonthlyCarbonEmissions,
    PotentialMonthlyCarbonSavings = toreal(properties.extendedProperties.PotentialMonthlyCarbonSavings),
    properties
```

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any datasets you're looking for. Create a new issue with the details that you'd like to see either included in existing or new best practices.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="0" opt="1" pbi="0" ps="0" %}

<br>
