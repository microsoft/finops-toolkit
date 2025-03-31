---
title: managedClusters
geekdocCollapseSection: true
geekdocHidden: false
---
# Managed Clusters Recommendations

{{< yamltotable2 resourceType="compute" resource="managedClusters" >}}


## AKS cluster agent pool scale set is not utilizing Spot VMs {#aks-cluster-spot-vm}

{{< kqltomd file="c26abcc2-d5e6-4654-be4a-7d338e5c1e5f" >}}


<!----


{{< dynamicmarkdown resourceType="compute" resource="managedClusters" >}}


{{< highlight yaml >}}
- description: AKS cluster agent pool scale set is not utilizing Spot VMs
  acorlGuid: c26abcc2-d5e6-4654-be4a-7d338e5c1e5f
  recommendationTypeId: null
  recommendationControl: UsageOptimization/OptimizeResources
  recommendationImpact: Medium
  recommendationResourceType: Microsoft.containerservice/managedclusters
  recommendationMetadataState: Active
  remediationAction: |
    Consider enabling Spot VMs for this AKS cluster to optimize costs, as Spot VMs offer significantly lower pricing compared to regular VMs
  potentialBenefits: Optimize existing resources
  pgVerified: true
  publishedToLearn: false
  automationAvailable: true
  tags: null
  learnMoreLink:
    - name: xx
      url: "https://aka.ms/finops/toolkit"
{{< /highlight >}}


{{< yamltotable file="azure-resources/xx/yy/recommendations" >}}

 -->

<!-- TO DO

{{< kqltomd file="content\azure-resources\compute\managedClusters\kql\c26abcc2-d5e6-4654-be4a-7d338e5c1e5f.kql" >}}

Work on the tables.html shortcut to make it dinamic. 

{{< table file="recommendations\azure-resources\compute\disks\recommendations" >}}
 -->

