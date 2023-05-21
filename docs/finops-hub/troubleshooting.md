# 🛠️ Troubleshooting FinOps hubs

Sorry to hear you're having a problem. This page includes common issues and solutions. If you run into a problem that isn't covered here, [start a discussion](https://aka.ms/finops/toolkit/discuss) or [open an issue](https://aka.ms/finops/toolkit/ideas).

<br>

On this page:

- [Reports are empty (no data)](#reports-are-empty-no-data)
- [The Microsoft.EventGrid resource provider is not registered in subscription \<guid\>](#the-microsofteventgrid-resource-provider-is-not-registered-in-subscription-guid)
- [Exception of type 'Microsoft.Mashup.Engine.Interface.ResourceAccessForbiddenException' was thrown](#exception-of-type-microsoftmashupengineinterfaceresourceaccessforbiddenexception-was-thrown)
- [The remote name could not be resolved: '\<storage-account\>.dfs.core.windows.net'](#the-remote-name-could-not-be-resolved-storage-accountdfscorewindowsnet)

---

## Reports are empty (no data)

If you don't see any data in your Power BI or other reports or tools, check the storage account to ensure data is populated in the **ingestion** container. You should see either a **providers** or **subscriptions** folder.

### Ingestion container is empty

If the **ingestion** container is empty, open the Data Factory instance in Data Factory Studio and select **Manage** > **Author** > **Triggers** and verify the **msexports** trigger is started. If not, start it.

If the trigger fails to start with a "resource provider is not registered" error, open the subscription in the Azure portal, then select **Settings** > **Resource providers**, select the **Microsoft.EventGrid** row, then select the **Register** command at the top of the page. Registration may take a few minutes.

After registration completes, start the **msexports** trigger again.

After the trigger is started, re-run all connected Cost Management exports. Data should be fully ingested within 10-20 minutes, depending on the size of the account.

Confirm the **ingestion** container is populated and refresh your reports or other connected tools.

### Files available in the ingestion container

If the **ingestion** container is not empty, confirm whether you have **parquet** or **csv.gz** files by drilling into the folders.

Once you know, verify the **FileType** parameter is set to `.parquet` or `.gz` in the Power BI report. See [Setup a FinOps hub report](reports/README.md#setup-a-finops-hub-report) for details.

If you're using another tool, ensure it supports the file type you're using.

<br>

## The Microsoft.EventGrid resource provider is not registered in subscription \<guid>

Open the subscription in the Azure portal, then select **Settings** > **Resource providers**, select the **Microsoft.EventGrid** row, then select the **Register** command at the top of the page. Registration may take a few minutes.

<br>

## Exception of type 'Microsoft.Mashup.Engine.Interface.ResourceAccessForbiddenException' was thrown

Indicates that the account loading data in Power BI does not have the [Storage Blob Data Reader role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader). Grant this role to the account loading data in Power BI.

<br>

## The remote name could not be resolved: '\<storage-account>.dfs.core.windows.net'

Indicates that the storage account name is incorrect. Verify the **StorageUrl** parameter. See [Setup a FinOps hub report](#setup-a-finops-hub-report) for details.

<br>
