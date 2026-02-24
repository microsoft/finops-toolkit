# Health check for FinOps hubs

## Step 1: Check the latest released FinOps hub version

Get the content from this file to determine the latest stable version of FinOps hubs: `https://raw.githubusercontent.com/microsoft/finops-toolkit/refs/heads/main/src/templates/finops-hub/modules/ftkver.txt`.

Get the content from this file to determine the latest development version of FinOps hubs: `https://raw.githubusercontent.com/microsoft/finops-toolkit/refs/heads/dev/src/templates/finops-hub/modules/ftkver.txt`.

FinOps hubs use semantic versioning (SemVer) format for version numbers, which is `major.minor`, `major.minor.patch`, or `major.minor-prerelease`. If the version number has `-dev` at the end of it, that means it's a development version.

Compare the version of the current FinOps hub instance with the latest stable version of FinOps hubs. If it's the same version as stable, tell the user they are using the latest released version and skip to the next step.

If the FinOps hub version is the same as the development version, tell the user they are using the development version and they should monitor the repository to ensure it's updated with the latest changes, then skip to the next step.

If the FinOps hub version is older than the development version and matches or is older than the latest stable version, tell the user they are using an older development version and should update to the latest stable release or development version. Mention their version number and the latest stable and development version numbers. Give them this link to deploy the latest stable version depending on their Azure cloud environment:

- For the Azure public, commercial cloud, use https://aka.ms/finops/hubs/deploy
- For the Azure Government cloud, use https://aka.ms/finops/hubs/deploy/gov
- For the Azure China cloud, use https://aka.ms/finops/hubs/deploy/china

## Step 2: Check the latest data refresh/update date

If the last data refresh/update date less than 24 hours ago, skip this step.

If the last data refresh/update date is more than 24 hours ago, inform the user that the data may be stale and they should check the Microsoft Cost Management exports and Azure Data Factory data ingestion pipelines to ensure they are running without errors.

Give them a link to Microsoft Cost Management to check the exports: https://portal.azure.com/#view/Microsoft_Azure_CostManagement/Menu/~/exports

Give them a link to the Azure Data Factory portal to check data ingestion pipelines: https://adf.azure.com/monitoring/pipelineruns

Tell the user you can help them troubleshoot any issues with [common errors](https://learn.microsoft.com/cloud-computing/finops/toolkit/help/errors) and the [troubleshooting guide](https://learn.microsoft.com/cloud-computing/finops/toolkit/help/troubleshooting).
