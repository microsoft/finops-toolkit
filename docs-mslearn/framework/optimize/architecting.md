---
title: Architecting for cloud
description: This article helps you understand the architecting for cloud capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
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

Integrating the [Cloud Adoption Framework (CAF)](/azure/cloud-adoption-framework) and the [Well-Architected Framework (WAF)](/azure/well-architected/pillars) with the FinOps approach is crucial for a comprehensive and effective cloud governance strategy, especially when using Microsoft Azure. Here's a refined list of prerequisites considering these frameworks:

- **Microsoft Azure fundamentals:** Gain familiarity with Azure services and features, including compute, storage, networking, databases, and security, aligning with the CAF's guidelines for Azure adoption.
- **Architectural principles and WAF pillars:** Familiarize yourself with architectural best practices outlined in the Well-Architected Framework's pillars: operational excellence, security, reliability, performance efficiency, and cost optimization.
- **Azure Resource Management and CAF Landing Zones:** Learn how to manage Azure resources using Azure Resource Manager (ARM) templates or Infrastructure as Code (IaC) tools like Azure Bicep or Terraform. Understand the concept of CAF landing zones for implementing Azure environments aligned with best practices.

<br>

## Getting started

The "Architecting for Cloud" capability within the FinOps Framework helps customers, especially people at lower maturity levels, build foundational knowledge, establish processes, and implement best practices for designing cloud architectures that optimize cost, performance, and reliability.

- **Educate stakeholders:** Conduct training sessions or workshops to educate stakeholders about the benefits and principles of cloud architecture, emphasizing cost optimization, scalability, and resilience.
- **Implement architectural principles:** Establish architectural principles and design guidelines based on [WAF pillars](/azure/well-architected/workloads): operational excellence, security, reliability, performance efficiency, and cost optimization.
- **Leverage Enterprise App Patterns for Web Apps:** Get started with the [Reliable Web App pattern](/azure/architecture/web-apps/guides/enterprise-app-patterns/overview). Enterprise App Patterns are built on top of the principles laid out in the WAF and provide implementation techniques to optimize your .NET or Java web app's move to the cloud.
- **Utilize Azure Well-Architected Review:** Conduct Azure [Well-Architected Reviews](/assessments/azure-architecture-review/) for workloads deployed in Azure. To identify areas for improvement, evaluate workloads against the five pillars of WAF.
- **Implement cost management practices:** Incorporate the Cloud Adoption Framework's [cost management practices](/azure/cloud-adoption-framework/get-started/manage-costs) into your architectural designs. This effort includes right-sizing resources, using [commitment discounts](./rates.md), and implementing [cost allocation mechanisms](../understand/allocation.md).
- **Establish governance and compliance:** Establish [governance mechanisms](/azure/cloud-adoption-framework/govern/monitor-cloud-governance) and compliance controls to ensure adherence to organizational policies, regulatory requirements, and industry standards. Use Azure Governance and Azure Blueprints for policy enforcement and compliance automation.

<br>

## Building on the basics

At this point, you should have a clear architectural guidance. As you move beyond the basics, consider the following points:

- **Advanced Architectural Patterns:** Review and explore the [Azure Architecture Center](/azure/architecture/browse/) for advanced architectural patterns and design principles specific to Azure. They include microservices, serverless computing, event-driven architectures, and distributed systems.
- **Cloud-native Technologies:** Use managed services to simplify architecture, improve scalability, and reduce operational overhead. Embrace cloud-native technologies and services offered by Azure, such as [Azure Kubernetes Service (AKS)](/azure/well-architected/service-guides/azure-kubernetes-service), [Azure Functions](/azure/well-architected/service-guides/azure-functions-security), Azure Logic Apps, and Azure Event Grid. 
- **Multi-Cloud and Hybrid Architectures:** Extend cloud architectures to embrace multicloud and hybrid cloud scenarios, using [Azure Arc](/azure/azure-arc/overview) for managing resources across on-premises, multicloud, and edge environments. Implement cloud bursting and disaster recovery strategies for resilience and flexibility.
- **Security and Compliance Automation:**  Use Azure Policy, Azure Security Center, and Microsoft Sentinel to automate security and compliance practices, including threat detection, incident response, and compliance reporting. Implement DevSecOps practices to embed security throughout the development lifecycle.
- **Data Management and Analytics:** Enhance data management and analytics capabilities by using Azure Data Services, such as Azure Synapse Analytics, Azure Databricks, and Azure Data Lake Storage. Implement advanced analytics, machine learning, and AI solutions for data-driven insights.
- **DevOps and CI/CD Automation:** Improve DevOps practices by automating CI/CD pipelines, infrastructure provisioning, and testing using Azure DevOps services, GitHub Actions, or Azure Automation. Implement Infrastructure as Code (IaC) with Azure Resource Manager (ARM) templates or Azure Bicep for consistency and repeatability.
- **Advanced Monitoring and Observability:** Implement advanced monitoring and observability solutions using tools such as the [Azure Monitor Baseline Alerts (AMBA)](https://azure.github.io/azure-monitor-baseline-alerts/welcome/).
- **Azure Verified Modules:** Take advantage of [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) to accelerate cloud architecture design and implementation. These verified modules provide prevalidated configurations and best practices, according to Microsoft guidance (WAF), for deploying infrastructure, applications, and services on Azure.
- **Continuous Learning and Improvement:** Invest in ongoing training and certification programs for teams to stay updated with the latest Azure technologies and best practices. Encourage knowledge sharing, cross-functional collaboration, and participation in community forums and events.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Architecting for cloud](https://www.finops.org/framework/capabilities/architecting-for-cloud/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/zMonuvmZE1g?list=PLUSCToibAswm62kf2eILBPaRHobvxNy35]

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.11/bladeName/Guide.Framework/featureName/Capabilities.Optimize.Architecting)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Workload optimization](./workloads.md)
- [Rate optimization](./rates.md)

Other resources:

- [Cloud Adoption Framework](/azure/cloud-adoption-framework/)
- [Well-Architected Framework](/azure/well-architected/)

<br>
