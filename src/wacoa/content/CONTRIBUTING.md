---
title: Azure Cost Optimizarion Recommendation Library (ACORL)
---


# Contributing
Thank you for your interest in contributing to ACORL! Below is a detailed guide to help you understand the folder structure and the steps required to add new recommendations.

---

## Directory Structure

The project's directory is organized as follows:

### Folder Structure


docs/
├── content/
│   ├── azure-resources/
│   │   ├── compute/
│   │   │   ├── managedClusters/
│   │   │   │   ├── kql/
│   │   │   │   │   ├── [unique-query-id].kql
│   │   │   │   ├── recommedation.yaml (optional)
│   │   │   ├── disks/
│   │   │   │   ├── kql/
│   │   │   │   │   ├── [unique-query-id].kql
│   │   │   │   ├── recommedation.yaml (optional)
│   │   │   ├── virtualMachines/
│   │   │   │   ├── kql/
│   │   │   │   ├── recommedation.yaml (optional)


### Directory Structure

1. **ResourceType Folder**: Each recommendation will have its own folder named after the `recommendationResourceType`. For example, `Microsoft.sql/servers/elasticpools/`.

2. **Required Files**:
   - **KQL File**: Contains the KQL query for the recommendation. It should be named with a GUID for unique identification (e.g., `3ecbf770-9404-4504-a450-cc198e8b2a7d.kql`).
   - **recommendation.yaml**: This file contains manual recommendations. It is not mandatory and only applicable when there are recommendations that cannot be automated (e.g., `recommendation.yaml`). This YAML file should respect [proper encoding and fields](#yaml-bp).


Each new recommendation must include at least least one KQL or one YAML file to ensure proper functionality and documentation.

---

## Adding a New Recommendation

### 1. [**Add the KQL File**](#yaml-bp)
KQL File: The KQL query that supports the recommendation.

- **Location:** `docs/content/azure-resources/<ResourceType>/<Resource>/kql/`
- **Purpose:** This file contains the KQL query associated with your recommendation.
- **File Naming:** Use a UUID for the file name (e.g., `ab703887-fa23-4915-abdc-3defbea89f7a.kql`). You can use [Guid Generator](https://guidgenerator.com/) to create a unique UUID.

### 2. **Add the Recommendation YAML**
Recommendations YAML File: Contains metadata for the recommendation.

- **Location:** `docs/content/azure-resources/<ResourceType>/<Resource>/`
- **Purpose:** This YAML file provides metadata for the recommendation, including its description, impact, and control.
- **File Naming:** Name the file `recommendations.yaml`.
- **Structure Example:**
{{< highlight yaml >}}
- description: SQL Database elastic pool has no associated databases
  acorlGuid: '50987aae-a46d-49ae-bd41-a670a4dd18bd'
  recommendationTypeId: null
  recommendationControl: UsageOptimization/OrphanedResources
  recommendationImpact: High
  recommendationResourceType: Microsoft.sql/servers/elasticpools
  recommendationMetadataState: Active
  remediationAction: |
    Review and remove this resource if not needed
  potentialBenefits: Remove idle resources
  pgVerified: true
  publishedToLearn: false
  automationAvailable: true
  tags: null
  learnMoreLink:
    - name: xx
      url: "https://aka.ms/finops/toolkit"
{{< /highlight >}}

| **Field**                     | **Description**                                                                                         | **Required** | **Example**                                                  |
|-------------------------------|---------------------------------------------------------------------------------------------------------|--------------|--------------------------------------------------------------|
| `description`                 | A concise description of the recommendation.                                                           | Yes          | `SQL Database elastic pool has no associated databases`      |
| `acorlGuid`                   | Unique identifier for the recommendation.                                                              | Yes          | `50987aae-a46d-49ae-bd41-a670a4dd18bd`                      |
| `recommendationTypeId`        | Type identifier for the recommendation. Use `null` if not applicable.                                  | No           | `null`                                                       |
| `recommendationControl`       | Categorization of the recommendation (e.g., Optimization/Resource Management).                         | Yes          | `UsageOptimization/OrphanedResources`                       |
| `recommendationImpact`        | Impact level of the recommendation (e.g., High, Medium, Low).                                          | Yes          | `High`                                                      |
| `recommendationResourceType`  | Resource type the recommendation applies to.                                                           | Yes          | `Microsoft.sql/servers/elasticpools`                        |
| `recommendationMetadataState` | Metadata status of the recommendation (e.g., Active, Deprecated).                                      | Yes          | `Active`                                                    |
| `remediationAction`           | Suggested action to resolve or mitigate the issue.                                                     | Yes          | `Review and remove this resource if not needed`             |
| `potentialBenefits`           | Key benefits of implementing the recommendation.                                                       | Yes          | `Remove idle resources`                                     |
| `pgVerified`                  | Indicates if the recommendation is verified by Product Group (`true`/`false`).                        | No          | `true`                                                      |
| `publishedToLearn`            | Whether the recommendation is published to Learn documentation (`true`/`false`).                      | No           | `false`                                                     |
| `automationAvailable`         | Indicates if automation is available for this recommendation (`true`/`false`).                        | No          | `true`                                                      |
| `tags`                        | Tags for additional categorization. Use `null` if not applicable.                                      | No           | `null`                                                      |
| `learnMoreLink`               | Links to additional resources. Includes a `name` and `url`. Multiple links can be added as a list.     | No           | `- name: xx`<br>`  url: https://aka.ms/finops/toolkit`      |


---

## What If the ResourceType/Resource Doesn't Exist?

If the directory for your `<ResourceType>` or `<Resource>` does not exist, you can create it:

1. Add a folder under `docs/content/azure-resources/` for the `<ResourceType>`.
2. Inside this folder, create a subfolder for the `<Resource>`.
3. Ensure either a `kql/` folder or `recommendations.yaml` are added under the `<Resource>` directory.




# Closing Notes

Thank you for your interest in contributing to this project! We greatly appreciate your time and effort to help improve and expand our resources. 
