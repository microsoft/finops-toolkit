---
title: Architecting for cloud
description: This article helps you understand the architecting for cloud capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 07/14/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the architecting for cloud capability so that I can implement that in the Microsoft cloud.
---

<!-- markdownlint-disable-next-line MD025 -->
# Architecting for cloud

This article helps you understand the architecting for cloud capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Architecting for the cloud involves designing and implementing cloud infrastructure and applications in a manner that optimizes cost, performance, scalability, and reliability while aligning with business objectives.**

This capability encompasses the architectural decisions and best practices aimed at maximizing the value derived from cloud investments while minimizing unnecessary expenditure.

<br>

## Before you begin

Integrating the [Cloud Adoption Framework (CAF)](https://learn.microsoft.com/azure/cloud-adoption-framework) and the [Well-Architected Framework (WAF)](https://learn.microsoft.com/azure/well-architected/pillars) with the FinOps approach is crucial for a comprehensive and effective cloud governance strategy, especially when leveraging Microsoft Azure. Here's a refined list of prerequisites considering these frameworks:

- **Microsoft Azure fundamentals:** Gain familiarity with Azure services and features, including compute, storage, networking, databases, and security, aligning with the CAF's guidelines for Azure adoption.
- **Architectural principles and WAF pillars:** Familiarize yourself with architectural best practices outlined in the Well-Architected Framework's pillars: operational excellence, security, reliability, performance efficiency, and cost optimization.
- **Azure Resource Management and CAF Landing Zones:** Learn how to manage Azure resources using Azure Resource Manager (ARM) templates or Infrastructure as Code (IaC) tools like Azure Bicep or Terraform. Understand the concept of CAF landing zones for implementing Azure environments aligned with best practices.

<br>

## Getting started

Starting with the "Architecting for Cloud" capability within the FinOps Framework, especially for customers at lower maturity levels, involves a step-by-step approach to gradually build foundational knowledge, establish processes, and implement best practices for designing cloud architectures that optimize cost, performance, and reliability. 

- **Educate stakeholders:** Conduct training sessions or workshops to educate stakeholders about the benefits and principles of cloud architecture, emphasizing cost optimization, scalability, and resilience.

- **Implement architectural principles:** Establish architectural principles and design guidelines based on [WAF pillars](https://learn.microsoft.com/azure/well-architected/workloads): operational excellence, security, reliability, performance efficiency, and cost optimization.

- **Utilize Azure Well-Architected Review:** Conduct Azure [Well-Architected Reviews](https://learn.microsoft.com/assessments/azure-architecture-review/) for workloads deployed in Azure. Evaluate workloads against the five pillars of WAF to identify areas for improvement.

- **Implement cost management practices:** Review and incorporate CAF's [cost management practices](https://learn.microsoft.com/azure/cloud-adoption-framework/get-started/manage-costs) into architectural designs, such as right-sizing resources, [leveraging reserved instances](docs/_docs/framework/capabilities/optimize/rates.md), and implementing cost allocation mechanisms. Use Azure Cost Management + Billing to monitor and optimize costs.

- **Establish governance and compliance:** Establish [governance mechanisms](https://learn.microsoft.com/azure/cloud-adoption-framework/govern/monitor-cloud-governance) and compliance controls to ensure adherence to organizational policies, regulatory requirements, and industry standards. Use Azure Governance and Azure Blueprints for policy enforcement and compliance automation.

<br>

## Building on the basics

At this point, you should have a clear architectural guidance. As you move beyond the basics, consider the following points:

- **Advanced Architectural Patterns:** Review and explore the [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/browse/) for advanced architectural patterns and design principles specific to Azure, such as microservices, serverless computing, event-driven architectures, and distributed systems.
- **Cloud-native Technologies:** Leverage managed services to simplify architecture, improve scalability, and reduce operational overhead. Embrace cloud-native technologies and services offered by Azure, such as [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/well-architected/service-guides/azure-kubernetes-service), [Azure Functions](https://learn.microsoft.com/azure/well-architected/service-guides/azure-functions-security), Azure Logic Apps, and Azure Event Grid. 
- **Multi-Cloud and Hybrid Architectures:** Extend cloud architectures to embrace multi-cloud and hybrid cloud scenarios, leveraging [Azure Arc](https://learn.microsoft.com/azure/azure-arc/overview) for managing resources across on-premises, multi-cloud, and edge environments. Implement cloud bursting and disaster recovery strategies for resilience and flexibility.
- **Security and Compliance Automation:** Automate security and compliance practices using Azure Policy, Azure Security Center, and Azure Sentinel for threat detection, incident response, and compliance reporting. Implement DevSecOps practices to embed security throughout the development lifecycle.
- **Data Management and Analytics:** Enhance data management and analytics capabilities by leveraging Azure Data Services, such as Azure Synapse Analytics, Azure Databricks, and Azure Data Lake Storage. Implement advanced analytics, machine learning, and AI solutions for data-driven insights.
- **DevOps and CI/CD Automation:** Improve DevOps practices by automating CI/CD pipelines, infrastructure provisioning, and testing using Azure DevOps, GitHub Actions, or Azure Automation. Implement Infrastructure as Code (IaC) with Azure Resource Manager (ARM) templates or Azure Bicep for consistency and repeatability.
- **Advanced Monitoring and Observability:** Implement advanced monitoring and observability solutions using tools such as the [Azure Monitor Baseline Alerts (AMBA)](https://azure.github.io/azure-monitor-baseline-alerts/welcome/).
- **Azure Verified Modules:** Take advantage of [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) to accelerate cloud architecture design and implementation. These verified modules provide pre-validated configurations and best practices, according to Microsoft guidance (WAF), for deploying infrastructure, applications, and services on Azure.
- **Continuous Learning and Improvement:** Invest in ongoing training and certification programs for teams to stay updated with the latest Azure technologies and best practices. Encourage knowledge sharing, cross-functional collaboration, and participation in community forums and events.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Architecting for cloud](https://www.finops.org/framework/capabilities/architecting-for-cloud/) article in the FinOps Framework documentation.

<br>

## Related content

Related FinOps capabilities:

- [Workload optimization](./workloads.md)
- [Rate optimization](./rates.md)

Other resources:

- [Cloud Adoption Framework](/azure/cloud-adoption-framework/)
- [Well-Architected Framework](/azure/well-architected/)

<br>
