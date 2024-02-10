---
layout: default
parent: Resources
title: Troubleshooting
nav_order: 999
description: 'Details and solutions for common issues you may experience.'
permalink: /resources/troubleshoot
---

<span class="fs-9 d-block mb-4">Troubleshooting common errors</span>
Sorry to hear you're having a problem. We're here to help!
{: .fs-6 .fw-300 }

---

<blockquote class="important" markdown="1">
  _Source code within the FinOps toolkit is provided as-is with no guarantees and is not officially covered by Microsoft Support. However, the underlying services **are** fully supported. If you encounter an issue, we generally recommend that you [create an issue](https://aka.ms/finops/toolkit/ideas) **and** file a support request. We will do our best to help you resolve any issues through GitHub issues and discussions but Microsoft Support will be better equipped to resolve issues in the underlying products and services. Microsoft Support may request code samples to help resolve the issue, which can be provided from the GitHub repository._
</blockquote>

Here are a few simple solutions to issues you may have faced:

- [Reports are empty (no data)](#reports-are-empty-no-data)
- [The \<name\> resource provider is not registered in subscription \<guid\>](#the-name-resource-provider-is-not-registered-in-subscription-guid)
- [Power BI: Exception of type 'Microsoft.Mashup.Engine.Interface.ResourceAccessForbiddenException' was thrown](#power-bi-exception-of-type-microsoftmashupengineinterfaceresourceaccessforbiddenexception-was-thrown)
- [Power BI: The remote name could not be resolved: '\<storage-account\>.dfs.core.windows.net'](#power-bi-the-remote-name-could-not-be-resolved-storage-accountdfscorewindowsnet)
- [Power BI: We cannot convert the value null to type Logical](#power-bi-we-cannot-convert-the-value-null-to-type-logical)
- [FinOps hubs: We cannot convert the value null to type Table](#finops-hubs-we-cannot-convert-the-value-null-to-type-table)
- [FinOps hubs: Deployment failed with RoleAssignmentUpdateNotPermitted error](#finops-hubs-deployment-failed-with-roleassignmentupdatenotpermitted-error)

Didn't find what you're looking for?

[Start a discussion](https://aka.ms/finops/toolkit/discuss){: .btn .btn-primary .mb-4 .mb-md-0 .mr-4 }
[Create an issue](https://aka.ms/finops/toolkit/ideas){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

---

## Reports are empty (no data)

If you don't see any data in your Power BI or other reports or tools, try the following based on your data source:

1. If using the Cost Management connector in Power BI, check the `Billing Account ID` and `Number of Months` parameters to ensure they're set correctly. Keep in mind old billing accounts may not have data in recent months.
2. If using FinOps hubs, check the storage account to ensure data is populated in the **ingestion** container. You should see either a **providers** or **subscriptions** folder. Use the sections below to troubleshoot further.

### FinOps hubs: Ingestion container is empty

If the **ingestion** container is empty, open the Data Factory instance in Data Factory Studio and select **Manage** > **Author** > **Triggers** and verify the **msexports** trigger is started. If not, start it.

If the trigger fails to start with a "resource provider is not registered" error, open the subscription in the Azure portal, then select **Settings** > **Resource providers**, select the **Microsoft.EventGrid** row, then select the **Register** command at the top of the page. Registration may take a few minutes.

After registration completes, start the **msexports** trigger again.

After the trigger is started, re-run all connected Cost Management exports. Data should be fully ingested within 10-20 minutes, depending on the size of the account.

If the issue persists, check if Cost Management exports are configured with File Partitioning enabled. If you find it disabled, turn it on and re-run the exports.

Confirm the **ingestion** container is populated and refresh your reports or other connected tools.

### FinOps hubs: Files available in the ingestion container

If the **ingestion** container is not empty, confirm whether you have **parquet** or **csv.gz** files by drilling into the folders.

Once you know, verify the **FileType** parameter is set to `.parquet` or `.gz` in the Power BI report. See [Setup a FinOps hub report](../finops-hub/reports/README.md#setup-a-finops-hub-report) for details.

If you're using another tool, ensure it supports the file type you're using.

---

## The \<name> resource provider is not registered in subscription \<guid>

Open the subscription in the Azure portal, then select **Settings** > **Resource providers**, select the resource provider row (e.g., Microsoft.EventGrid), then select the **Register** command at the top of the page. Registration may take a few minutes.

---

## Power BI: Exception of type 'Microsoft.Mashup.Engine.Interface.ResourceAccessForbiddenException' was thrown

Indicates that the account loading data in Power BI does not have the [Storage Blob Data Reader role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader). Grant this role to the account loading data in Power BI.

---

## Power BI: The remote name could not be resolved: '\<storage-account>.dfs.core.windows.net'

Indicates that the storage account name is incorrect. If using FinOps hubs, verify the **StorageUrl** parameter from the deployment. See [Setup a FinOps hub report](../finops-hub/README.md#-create-a-new-hub) for details.

---

## Power BI: We cannot convert the value null to type Logical

Indicates that the **Billing Account ID** parameter is empty. If using FinOps hubs, set the value to the desired billing account ID. If you do not have access to the billing account or do not want to include commitment purchases and refunds, set the value to `0` and open the **CostDetails** query in the advanced editor and change the `2` to a `1`. This will inform the report to not load actual/billed cost data from the Cost Management connector. See [How to setup Power BI](../power-bi/setup.md#-setup-your-first-report) for details.

Applicable versions: **0.1 - 0.1.1** (fixed in **0.1.2**)

---

## FinOps hubs: We cannot convert the value null to type Table

This error typically indicates that data was not ingested into the **ingestion** container. See [Reports are empty (no data)](#reports-are-empty-no-data) for details.

---

## FinOps hubs: Deployment failed with RoleAssignmentUpdateNotPermitted error

If you've deleted FinOps Hubs and are attempting to redeploy it with the same values, including the Managed Identity name, you might encounter the following known issue:

```json
"code": "RoleAssignmentUpdateNotPermitted",
"message": "Tenant ID, application ID, principal ID, and scope are not allowed to be updated."
```
To fix that issue you will have to remove the stale identity:
   - Navigate to "Storage Account >> Access Control IAM" >> "Role assignments."
   - Identify a role assignment with an "unknown" identity and delete it.



---

<br>
