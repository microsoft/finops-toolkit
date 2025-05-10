# Azure Cost Optimization Best Practices

This document provides detailed best practices for optimizing costs in Microsoft Azure, organized by service category and optimization opportunity.

## Compute Optimization

### Virtual Machines

1. **Right-sizing VMs**
   - Use Azure Advisor right-sizing recommendations
   - Analyze CPU and memory utilization over time
   - Consider moving from general-purpose to burstable VMs (B-series) for dev/test workloads
   - Implement automatic VM size recommendations with Azure Advisor

2. **Shutdown Management**
   - Use Azure Automation to schedule shutdowns for non-production VMs
   - Implement auto-shutdown settings through the Azure portal
   - Create DevTest Labs for developer environments with automatic shutdown policies

3. **Commitment Discounts**
   - Use Reserved VM Instances for predictable workloads
   - Consider Azure Savings Plans for more flexible commitment discounts
   - Implement Azure Hybrid Benefit for Windows Server and SQL Server VMs

4. **Image Optimization**
   - Use shared image galleries to maintain optimized images
   - Remove unnecessary services and features from VM images
   - Implement disk optimization in base images

### Azure Kubernetes Service (AKS)

1. **Cluster Optimization**
   - Use Virtual Node to scale application pods temporarily
   - Implement cluster autoscaler to adjust node counts based on demand
   - Use pod disruption budgets to manage availability during scale-down

2. **Resource Management**
   - Set appropriate resource requests and limits for pods
   - Implement horizontal pod autoscalers based on custom metrics
   - Consider AKS spot node pools for fault-tolerant workloads

3. **Cost Allocation**
   - Use namespaces for workload segregation
   - Implement Kubernetes labels for cost attribution
   - Monitor pod-level resource consumption

## Storage Optimization

### Blob Storage

1. **Tiering Strategies**
   - Use lifecycle management policies to automatically tier data:
     ```json
     {
       "rules": [
         {
           "name": "moveToCool",
           "enabled": true,
           "type": "Lifecycle",
           "definition": {
             "filters": {
               "blobTypes": [ "blockBlob" ],
               "prefixMatch": [ "logs/" ]
             },
             "actions": {
               "baseBlob": {
                 "tierToCool": { "daysAfterModificationGreaterThan": 30 },
                 "tierToArchive": { "daysAfterModificationGreaterThan": 90 },
                 "delete": { "daysAfterModificationGreaterThan": 365 }
               }
             }
           }
         }
       ]
     }
     ```
   - Implement hot, cool, and archive tiers based on access patterns
   - Use blob index tags for more granular lifecycle management

2. **Data Redundancy Selection**
   - Choose appropriate redundancy options based on criticality:
     - LRS (Locally redundant storage) for non-critical, replaceable data
     - ZRS (Zone-redundant storage) for zone resiliency requirements
     - GRS/RA-GRS only for critical business data

3. **Capacity Optimization**
   - Implement blob compression where applicable
   - Use soft delete and versioning judiciously
   - Regularly audit and delete unnecessary data

### Managed Disks

1. **Size Optimization**
   - Right-size disks based on actual usage
   - Use disk bursting for handling unexpected spikes
   - Implement shared disks for clustered applications

2. **Performance Tier Selection**
   - Use Standard HDD for low I/O workloads
   - Implement Premium SSD only where performance requirements justify cost
   - Consider Ultra Disks only for the most I/O-intensive workloads

3. **Snapshot Management**
   - Implement an automated snapshot cleanup policy
   - Use incremental snapshots
   - Delete snapshots when they're no longer needed

## Database Optimization

### Azure SQL Database

1. **Service Tier Selection**
   - Choose the appropriate service tier based on workload requirements:
     - Basic for dev/test
     - Standard for production workloads with moderate demands
     - Premium for mission-critical applications
     - Hyperscale for large databases with unpredictable scaling needs

2. **Scaling Optimization**
   - Implement automatic scaling or elastic pools for variable workloads
   - Schedule scaling operations to match usage patterns
   - Use serverless compute tier for intermittent usage patterns

3. **Query Performance**
   - Optimize queries and indexes to reduce compute requirements
   - Implement query store to identify performance issues
   - Use automatic tuning features

### Cosmos DB

1. **Request Unit Optimization**
   - Design for efficient RU consumption with proper partition keys
   - Implement SDK-level retry policies with backoff
   - Use bulk operations for large data modifications

2. **Multi-region Strategy**
   - Deploy to multiple regions only when necessary for latency or availability
   - Use single-region writes when possible
   - Implement regional failover testing to validate configurations

3. **Throughput Management**
   - Use autoscale provisioned throughput for variable workloads
   - Schedule throughput scaling for predictable patterns
   - Consider serverless capacity mode for development environments

## Networking Optimization

### Data Transfer

1. **Traffic Routing Optimization**
   - Use Azure CDN to cache content closer to users
   - Implement Front Door for global load balancing
   - Consider Express Route for high-volume private connections

2. **VPN and ExpressRoute**
   - Right-size ExpressRoute circuits based on actual bandwidth needs
   - Use VPN for non-critical or low-volume connections
   - Implement traffic shaping to prioritize critical data transfers

3. **Data Transfer Planning**
   - Schedule large data transfers during off-peak hours
   - Use Azure Data Box for large initial data migrations
   - Compress data before transfer when possible

### Network Services

1. **Load Balancer Configuration**
   - Use Basic SKU for non-production workloads
   - Implement proper health probes to prevent routing to unhealthy instances
   - Consider Application Gateway for HTTP/HTTPS traffic

2. **NAT Gateway Optimization**
   - Share NAT gateways across multiple subnets
   - Size NAT gateway based on actual connection requirements
   - Monitor SNAT port utilization and adjust as needed

## Platform Services Optimization

### Azure Functions

1. **Consumption Plan Optimization**
   - Design functions to minimize execution time
   - Avoid cold starts by implementing premium plan for critical functions
   - Use durable functions for complex orchestrations

2. **Resource Efficiency**
   - Implement proper memory allocation
   - Optimize dependencies and package sizes
   - Use connection pooling for database and HTTP connections

### App Service

1. **App Service Plan Selection**
   - Consolidate low-usage apps onto shared App Service Plans
   - Use PremiumV3 or PremiumV2 for production workloads requiring scalability
   - Consider Isolated SKUs only when security requirements demand it

2. **Auto-scaling Configuration**
   - Implement rule-based auto-scaling with appropriate metrics
   - Consider predictive scaling for workloads with predictable patterns
   - Set appropriate minimum and maximum instance counts

## Specialized Best Practices

### Dev/Test Environments

1. **Environment Management**
   - Implement automated shutdown schedules for all dev/test resources
   - Use DevTest Labs to enforce policies and quotas
   - Create ephemeral environments that are destroyed after use

2. **Cost Controls**
   - Set spending limits on dev/test subscriptions
   - Use budget alerts to notify when approaching thresholds
   - Implement approval processes for high-cost resources

### AI and Machine Learning

1. **Compute Optimization**
   - Use low-priority VMs for training jobs
   - Implement automatic shutdown of training clusters
   - Schedule batch inference during off-peak hours

2. **Model Deployment**
   - Use the appropriate deployment target based on throughput needs
   - Implement autoscaling for inference endpoints
   - Consider serverless inference for irregular usage patterns

## Implementation Strategies

### Automated Cost Optimization

1. **Azure Automation Runbooks**
   - Implement regular right-sizing scripts
   - Create automated cleanup processes for unused resources
   - Schedule scaling operations to match usage patterns

2. **Infrastructure as Code**
   - Use ARM templates or Bicep with cost-optimized configurations
   - Implement policy as code to enforce cost constraints
   - Create reusable modules with cost-efficient defaults

3. **Monitoring and Remediation**
   - Create Azure Monitor alerts for cost anomalies
   - Implement Azure Functions to automatically remediate inefficiencies
   - Use Logic Apps for approval workflows before optimization actions

## Tools and Resources

1. **Native Azure Tools**
   - [Azure Advisor](https://learn.microsoft.com/en-us/azure/advisor/)
   - [Azure Cost Management](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/)
   - [Azure Monitor Cost Analysis](https://learn.microsoft.com/en-us/azure/azure-monitor/costs/analyze-cost)

2. **Microsoft Cost Optimization Resources**
   - [Azure Well-Architected Framework - Cost Optimization](https://learn.microsoft.com/en-us/azure/architecture/framework/cost/overview)
   - [Cloud Adoption Framework - Cost Management discipline](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/govern/cost-management/)
   - [Azure Architecture Center - Cost optimization](https://learn.microsoft.com/en-us/azure/architecture/framework/cost/overview)

3. **FinOps Toolkit Components**
   - [FinOps Workbooks](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/workbooks/finops-workbooks-overview)
   - [Power BI Cost Reports](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/power-bi/reports)
   - [Azure Optimization Engine](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/optimization-engine/overview)

---

_Last updated: May 9, 2025_
