---
layout: default
parent: Compute
title: Virtual machines
nav_order: 0
description: 'Create Linux and Windows virtual machines (VMs) in seconds and reduce costs.'
permalink: /services/compute/virtual-machines
---

<span class="fs-9 d-block mb-4">{service}</span>
Create Linux and Windows virtual machines (VMs) in seconds and reduce costs.
{: .fs-6 .fw-300 }

<!--
[Primary CTA](#){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Secondary CTA](#){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
-->

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Understand cloud usage and cost](#understand-cloud-usage-and-cost)
- [Optimize cloud usage and cost](#optimize-cloud-usage-and-cost)
- [Quantify business value](#quantify-business-value)
- [Manage the FinOps practice](#manage-the-finops-practice)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---

Azure virtual machines are one of several types of [on-demand, scalable computing resources that Azure offers](https://learn.microsoft.com/azure/architecture/guide/technology-choices/compute-decision-tree). Typically, you choose a virtual machine when you need more control over the computing environment than the other choices offer.

An Azure virtual machine gives you the flexibility of virtualization without having to buy and maintain the physical hardware that runs it. However, you still need to maintain the virtual machine by performing tasks, such as configuring, patching, and installing the software that runs on it.

[About](https://azure.microsoft.com/products/virtual-machines){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Pricing](https://azure.microsoft.com/pricing/details/virtual-machines){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Documentation](https://learn.microsoft.com/azure/virtual-machines){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<br>

## Understand cloud usage and cost


### Data ingestion

**Understanding and Managing Costs for Virtual Machines**

Azure virtual machines (VMs) are a fundamental component of your cloud infrastructure, providing on-demand computing resources tailored to your specific needs. To effectively manage costs associated with VMs, it's crucial to understand the various factors that contribute to their pricing, as well as costs related to associated services.

## Virtual machines:

- **Hourly billing:** VMs are billed based on the number of hours they are provisioned. The longer a VM runs, the higher the associated cost.
  <blockquote class="important" markdown="1">
     _A "Stopped" VM is still "provisioned" in the cloud and will incur charges. Make sure you "deallocate" your VMs to stop incurring compute charges. Other charges, like storage, are still applicable even in a deallocated state._
  </blockquote>

- **VM Size:** The pricing of VMs varies based on the chosen size or configuration. Larger and more powerful VMs generally incur higher costs.

- **Regional Pricing:** The cost of a VM is influenced by the region where it is deployed. Different regions may have varying pricing structures, impacting the overall cost of VM usage.

- **VM States:** As VM instances transition through different states (running, stopped, deallocated), they may incur different billing rates. Ensure efficient VM management to minimize unnecessary costs during idle periods.

## Storage:

- **Disk Size:** Storage costs are determined by the size of disks attached to VMs, measured in gigabytes (GB). Larger disk sizes contribute to higher storage costs.

- **Transactions:** Transaction-based costs apply to storage and are influenced by the number of transactions per hour. Refer to the [storage billing documentation](https://docs.microsoft.com/azure/storage/blobs/storage-blobs-billing) for detailed information on transaction costs.

## Virtual Network and Bandwidth:

- **Virtual Network Data Transfer:** Costs are associated with the amount of data transferred across virtual networks, measured in gigabytes (GB). Be mindful of data transfer volumes to optimize costs.

- **Bandwidth:** Similar to virtual network data transfer, bandwidth costs are based on the amount of data transferred. Efficient network management helps control bandwidth-related expenses.

## Associated Services:

- **Azure Monitor:** Costs for Azure Monitor are based on the volume of data ingested. Monitor and optimize the data ingested to manage associated expenses effectively.

- **Azure Bastion:** Billing for Azure Bastion is determined by the volume of data transferred. Monitor and control data transfer to regulate costs.

- **Azure DNS:** Charges for Azure DNS depend on the number of DNS zones hosted and the quantity of DNS queries received. Manage DNS resources efficiently to control costs.

- **Load Balancer:** If load balancers are utilized, costs are determined by the number of rulesets, hours used, and the amount of data processed. Optimize load balancer configurations for cost-effectiveness.

- **Backup:** Backup costs are associated with the chosen backup replication policy and frequency. Regularly assess and adjust backup strategies to align with cost-effectiveness and data recovery needs.

### Allocation

Efficient cost allocation is crucial for managing Azure Virtual Machine (VM) expenses. A highly effective method for grouping and allocating costs is through the tag inheritance feature in Cost Management. Enabled tag inheritance applies billing, resource group, and subscription tags to child resource usage records.

Once tag inheritance is enabled, tags from billing profiles, invoice sections, subscriptions, and resource groups are automatically applied to child resource usage records for the current month within 24 hours. For detailed instructions, refer to the [Cost allocation guidance](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/enable-tag-inheritance).

#### Tagging Best Practices:

- **Consistent Tagging:** Establish a consistent tagging strategy across VMs using the [Cloud Adoption Framework (CAF) guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging).

- **Automated Tagging with Azure Policy:** Simplify and standardize tagging by utilizing Azure Policy to automatically apply tags to VMs. This streamlines the allocation process, ensuring adherence to tagging standards.

Implementing tag inheritance and following these tagging best practices enhances your ability to efficiently allocate and manage VM costs.

### Reporting + analytics

Effectively managing and optimizing costs associated with your Virtual Machines (VMs) in Azure requires a strategic approach to reporting and analytics. Services such as Cost Management and Azure Monitor play a crucial role in analyzing VM usage and expenditures.

To report on VM costs comprehensively, consider all the services mentioned in the Data Ingestion capability, including but not limited to:

- **Virtual Machines:** Understand the hourly billing, VM size, regional pricing, and states (running, stopped, deallocated).
- **Storage:** Factor in storage costs based on disk size and transactions per hour.
- **Virtual Network and Bandwidth:** Include costs related to data transfer and bandwidth usage.
- **Associated Services:** Consider costs associated with Azure Monitor, Azure Bastion, Azure DNS, and Load Balancer if used.

## Validating VM Usage:

Once you've identified all the costs associated with a VM, the next crucial step is to validate the VM usage to ensure it is properly sized. This involves:

- **Right-sizing VMs:** Review the VM size to ensure it aligns with the actual workload requirements. Consider scaling up or down based on usage patterns.
- **Efficient Resource Management:** Leverage Azure services such as Cost Management and Azure Monitor to gain insights into VM performance metrics, allowing you to identify areas for optimization.


### Anomalies
Anomaly detection helps pinpoint unexpected spikes or irregularities in VM spending, enabling timely intervention to optimize costs. IIdentifying irregularities helps in optimizing resource allocation, ensuring resources are used efficiently.


1. **Utilize Azure Monitor:**
   - Leverage Azure Monitor to access detailed insights into VM performance metrics. Set up alerts for key metrics such as CPU usage, memory utilization, and disk activity.

2. **Cost Management Tools:**
   - Leverage the cost management tools, such as Azure Cost Management and Power BI, to analyze spending patterns and detect unusual spikes in VM costs.

3. **Performance Metrics:**
   - Correlate cost anomalies with performance metrics. Anomalies in resource utilization may directly impact costs.

4. **Resource Configuration:**
   - Evaluate the configuration of VM resources. Anomalies could be linked to improper resource allocation or sudden changes in demand.

<br>

## Optimize cloud usage and cost

### Unit economics


### Estimation + forecasting

Before creating a VM, leverage the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) to simulate costs. This tool allows you to estimate expenses based on your selected VM configurations, helping you make informed decisions and plan budgets effectively.

Understanding and proactively managing the costs associated with virtual machines and related services are key components of a successful cloud financial management strategy. Regularly review and optimize your resource usage to ensure cost-effectiveness and alignment with your business goals.

### Budgeting
Effectively budgeting for Virtual Machines (VMs) in Azure involves considersing different factors, including VM sizes, usage patterns, and potential discounts.

## Understanding VM Sizes (SKUs):

- **Evaluate Performance Needs:** Choose VM sizes based on the specific performance requirements of your workloads. Consider factors such as CPU, memory, and storage capabilities.

## Usage Patterns:

- **Continuous vs. Scheduled Usage:**
   - Determine if VMs need to run continuously or if there are periods when they can be powered off. Schedule VMs to align with actual workload demands, optimizing costs during idle periods.

## Existing Commitment-Based Discounts:

- **Reserved Instances (RIs):**
   - Leverage Reserved Instances for VMs to benefit from significant cost savings. Commit to a one or three-year term for VMs that require ongoing, predictable usage.

- **Hybrid Benefit:**
   - If you have on-premises Windows Server licenses with Software Assurance, consider utilizing Azure Hybrid Benefit for additional cost savings on VMs.

## Underlying Services:

- **Networking Costs:**
   - Factor in networking costs associated with data transfer and bandwidth. Optimize network configurations to minimize unnecessary expenses.

- **Backup Services:**
   - Assess backup requirements for VMs. Utilize Azure Backup to efficiently manage and optimize backup costs based on retention policies and storage needs.

- **Monitoring and Alerts:**
   - Leverage Azure Monitor for VMs to gain insights into performance metrics and set up alerts. Proactively monitor VMs to identify potential issues and optimize resource usage.


### Benchmarking

<br>

## Quantify business value

### Architecting for cloud

### Utilization efficiency

Optimizing the utilization efficiency of Virtual Machines (VMs) in Azure is essential for achieving cost savings and maximizing resource efficiency. 


1. **Commitment-Based Discounts:**
   - Evaluate workloads for suitability with Reserved Instances or Spot Instances. Leverage commitment-based discounts to optimize costs for consistent and variable workloads.

2. **Regular Right-Sizing Reviews:**
   - Conduct regular reviews of VM sizes based on performance assessments and Azure Advisor recommendations. Right-size VMs to align with actual usage patterns.

3. **Scheduled Shutdowns:**
   - Identify and schedule automated VM shutdowns during idle periods. Implement Azure Automation runbooks for efficient management of startup and shutdown routines.

4. **Continuous Monitoring and Alerts:**
   - Implement continuous monitoring using Azure Monitor and set up


### Workload management


1. **Regular Performance Reviews:**
   - Conduct regular reviews of VM performance metrics. Adjust VM SKU based on changing workload patterns.

2. **Automation Implementation:**
   - Implement automation for routine workload management tasks. This includes auto stop and start VMs based on schedule.

3. **Continuous Monitoring:**
   - Establish a continuous monitoring process using Azure Monitor and Log Analytics. Proactively address performance issues to maintain optimal workload management.


### Licensing + SaaS

### Commitment discounts

Commitment-based discounts, such as Reserved Instances (RIs) and Azure Savings Plans, offer significant cost savings for organizations utilizing Virtual Machines (VMs) in Azure.

1. **Evaluate Workload Stability:**
   - Assess VM workloads to understand stability and usage patterns. Stable workloads with predictable usage are prime candidates for Reserved Instances.

2. **Long-Term Commitments:**
   - If your organization can commit to long-term usage, consider Reserved Instances. Evaluate the one or three-year commitment options based on budgetary considerations.

3. **Flexibility and Usage Variation:**
   - For workloads with varying usage or the need for flexibility, explore Azure Savings Plans. Savings Plans provide discounts while accommodating changes in VM size, family, or region.

4. **Cost Analysis:**
   - Utilize tools like Azure Pricing Calculator and Azure Cost Management to perform cost analysis. Compare the potential savings of RIs and Savings Plans against pay-as-you-go pricing.

5. **Regular Review:**
   - Periodically review VM workloads and commitments. Adjust Reserved Instances or Savings Plans as needed to align with evolving usage patterns.


### Cloud sustainability

<br>

## Manage the FinOps practice

### FinOps practice operations

### FinOps education + enablement

### FinOps assessment

### Cloud policy + governance

### FinOps tools + services

### Chargeback + invoicing

### Intersecting disciplines

<br>

## 🙋‍♀️ Looking for more?

Did we miss anything? Would you like to see something added? We'd love to hear about any questions, problems, or solutions you'd like to see covered here. Create a new issue with the details that you'd like to see either included here.

[Share feedback](https://github.com/microsoft/finops-toolkit/issues/new/choose){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" pbi="1" opt="1" gov="1" ps="0" bicep="0" data="0" %}

<br>
