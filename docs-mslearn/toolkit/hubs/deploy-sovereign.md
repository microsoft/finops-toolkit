---
title: How to deploy FinOps hubs to sovereign clouds
description: This article explains how to deploy FinOps hubs to sovereign Azure clouds, including US Government and China, and other sovereign environments.
author: msbrett
ms.author: brettwil
ms.date: 03/27/2026
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner deploying to a sovereign cloud, I want to understand what additional steps are needed so I can successfully deploy FinOps hubs.
---

<!-- markdownlint-disable heading-increment MD024 -->

# How to deploy FinOps hubs to sovereign clouds

This article explains how to deploy FinOps hubs to sovereign Azure clouds, including Azure US Government, Azure China (21Vianet), and other sovereign environments. Bicep's `environment()` function compiles to an ARM runtime expression that resolves in the target cloud, so templates built on any workstation deploy correctly to any cloud. No cross-compilation is needed. This article helps you:

<!-- prettier-ignore-start -->
> [!div class="checklist"]
> - Verify prerequisites for sovereign cloud deployments. <!-- markdownlint-disable-line MD032 -->
> - Build the FinOps hub template for your target cloud.
> - Prepare open data for environments without internet access.
> - Deploy the template to your sovereign cloud.
> - Configure dashboards for your environment.
<!-- prettier-ignore-end -->

<br>

## Prerequisites

Before you deploy FinOps hubs to a sovereign cloud, you need the following:

- All prerequisites from the [standard deployment tutorial](deploy.md#prerequisites), including:
  - [Contributor](/azure/role-based-access-control/built-in-roles#contributor) to deploy resources.
  - [Role Based Access Control Administrator](/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator) to configure managed identity.
  - For least-privileged access, see [template details](template.md#prerequisites).
- Bicep CLI pre-installed on the deployment workstation ([installation guide](/azure/azure-resource-manager/bicep/install)).

> [!IMPORTANT]
> Azure CLI normally downloads the Bicep CLI on first use, but this requires internet access. For sovereign environments without internet access, manually install the Bicep binary before deploying. See [Install Bicep tools](/azure/azure-resource-manager/bicep/install).

<br>

## Supported clouds

FinOps hubs support deployment to all standard Azure clouds and can be configured for other sovereign environments with parameter overrides.

| Cloud | Environment name | Portal URL | Status |
|-------|-----------------|------------|--------|
| Azure Commercial | `AzureCloud` | `portal.azure.com` | ✅ Fully supported |
| Azure US Government | `AzureUSGovernment` | `portal.azure.us` | ✅ Fully supported |
| Azure China (21Vianet) | `AzureChinaCloud` | `portal.azure.cn` | ✅ Fully supported |
| Other sovereign clouds | *(verify with your environment)* | *(verify with your environment)* | ⚠️ Supported with parameter overrides |

> [!NOTE]
> Some sovereign cloud environment names, DNS suffixes, and portal URLs are not published in public Microsoft documentation. Verify all endpoints against your target environment before deploying.

<br>

## Step 1: Build the template

FinOps hubs include a build script that compiles the Bicep template and configures the dashboard. The `-PortalUrl` parameter sets the portal URL used in the 27 feedback links in `dashboard.json`. Build output lands in the `release/finops-hub/` folder.

### [PowerShell](#tab/powershell)

Run once on any workstation with the Bicep CLI installed:

```powershell
# Azure Commercial (default)
./src/scripts/Build-Toolkit -Template finops-hub

# Azure US Government
./src/scripts/Build-Toolkit -Template finops-hub -PortalUrl "https://portal.azure.us"

# Azure China (21Vianet)
./src/scripts/Build-Toolkit -Template finops-hub -PortalUrl "https://portal.azure.cn"

# Other sovereign clouds
./src/scripts/Build-Toolkit -Template finops-hub -PortalUrl "https://<your-portal-url>"
```

### [Manual](#tab/manual)

If you don't have a build environment, you can deploy the templates directly from the source repository. The dashboard feedback links default to the Azure Commercial portal URL. To update feedback links for your cloud, edit the `clusterUri` and portal URLs in `dashboard.json` after importing it into Azure Data Explorer.

---

<br>

## Step 2: Prepare open data

> [!NOTE]
> Skip this step if your environment has internet access to github.com.

FinOps hubs use open-data CSV files for pricing units, regions, resource types, and services. By default, these files are fetched from GitHub at Azure Data Explorer query time. In sovereign environments without internet access, you need to pre-load these files into a storage account.

Upload the following files from the `src/open-data/` folder to a container accessible by the Azure Data Explorer cluster (for example, `https://<storage>.blob.<suffix>/open-data/`):

| File | Size |
|------|------|
| `CommitmentDiscountEligibility.csv` | 5.1 MB |
| `PricingUnits.csv` | 12 KB |
| `Regions.csv` | 18 KB |
| `ResourceTypes.csv` | 718 KB |
| `Services.csv` | 54 KB |

When the `openDataBaseUrl` parameter points to your storage account, the Data Factory GitHub linked service and dataset are automatically skipped during deployment.

<br>

## Step 3: Deploy the template

### [Azure portal](#tab/azure-portal)

Deploy to Azure buttons are available for Azure US Government and Azure China. For other sovereign clouds, deploy directly from the Azure portal in your cloud environment.

1. Open the appropriate template in the Azure portal:
   - [Deploy to Azure Gov](https://aka.ms/finops/hubs/deploy/gov)
   - [Deploy to Azure China](https://aka.ms/finops/hubs/deploy/china) (MCA only)
   - For other sovereign clouds, open the Azure portal for your environment and create a deployment using the compiled template from the `release/finops-hub/` folder.
2. Follow the deployment steps in the [standard deployment tutorial](deploy.md#deploy-the-finops-hub-template).
3. If you pre-loaded open data in the previous step, specify the `openDataBaseUrl` parameter with your storage account URL (for example, `https://<storage>.blob.<suffix>/open-data`).
4. For restricted environments, set `enablePublicAccess` to **Disabled**. For more information, see [Configure private networking](private-networking.md).

### [PowerShell](#tab/powershell)

The following command is part of the FinOps toolkit PowerShell module. To install the module, see [Install the FinOps toolkit PowerShell module](../powershell/powershell-commands.md#install-the-module).

> [!IMPORTANT]
> PowerShell deployment requires Bicep CLI to be installed and available in PATH. See [Install Azure Bicep](/azure/azure-resource-manager/bicep/install) for installation instructions.

```powershell
# Deploy with open data hosted locally (environments without internet access)
Deploy-FinOpsHub `
    -Name MyHub `
    -ResourceGroupName MyNewResourceGroup `
    -Location <your-region> `
    -DataExplorerName MyFinOpsHubCluster `
    -OpenDataBaseUrl 'https://<storage>.blob.<your-storage-suffix>/open-data' `
    -EnablePublicAccess $false

# Deploy with default open data (environments with internet access)
Deploy-FinOpsHub `
    -Name MyHub `
    -ResourceGroupName MyNewResourceGroup `
    -Location <your-region> `
    -DataExplorerName MyFinOpsHubCluster
```

For other parameters, see [Deploy-FinOpsHub](../powershell/hubs/Deploy-FinOpsHub.md).

### [Azure CLI](#tab/azure-cli)

```bash
# Deploy with open data hosted locally (environments without internet access)
az deployment group create \
  --resource-group my-finops-rg \
  --template-file release/finops-hub/main.bicep \
  --parameters \
    hubName=my-hub \
    openDataBaseUrl='https://<storage>.blob.<your-storage-suffix>/open-data' \
    enablePublicAccess=false

# Deploy with default open data (environments with internet access)
az deployment group create \
  --resource-group my-finops-rg \
  --template-file release/finops-hub/main.bicep \
  --parameters \
    hubName=my-hub
```

---

<br>

## Step 4: Configure the dashboard

Import the Data Explorer dashboard for your FinOps hub:

1. [Download the dashboard template](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-dashboard.json).
   - If you built the template with the `-PortalUrl` parameter, use the `dashboard.json` file from the `release/finops-hub/` folder instead. This version has feedback links configured for your cloud.
2. Grant any users **Viewer** (or greater) access to the **Hub** and **Ingestion** databases. [Learn more](/kusto/management/manage-database-security-roles#database-level-security-roles).
3. Go to the [Azure Data Explorer dashboards](https://dataexplorer.azure.com/dashboards) page for your cloud.
4. Import a new dashboard from the file in step 1.
5. Edit the dashboard and change the data source to your FinOps hub cluster.
   - The `clusterUri` field is empty by default &ndash; set it to your cluster URI after import.

For more information, see [Configure Data Explorer dashboards](configure-dashboards.md).

> [!TIP]
> Build the template with the correct `-PortalUrl` for your cloud so dashboard feedback links point to the right portal. If you deployed without building, manually update the portal URLs in the dashboard JSON after import.

<br>

## DNS suffix handling

Most DNS suffixes are derived from `environment()` at deployment time and resolve correctly in any cloud with no overrides. Two services require workarounds because ARM does not expose their suffixes directly.

### Kusto (Azure Data Explorer) DNS suffix

No `environment().suffixes.dataExplorer` property exists in ARM. The template uses a lookup map for known clouds with a fallback heuristic for unknown environments:

```bicep
var dataExplorerDnsSuffixLookup = {
  AzureCloud: 'kusto.windows.net'
  AzureUSGovernment: 'kusto.usgovcloudapi.net'
  AzureChinaCloud: 'kusto.windows.cn'
}
var dataExplorerDnsSuffix = dataExplorerDnsSuffixLookup[?environment().name] ?? replace(environment().suffixes.storage, 'core', 'kusto')
```

A lookup map is required because the Kusto suffix does not follow the same naming pattern as storage across all clouds &ndash; China is the notable exception. Unknown environments fall back to a `replace('core', 'kusto')` heuristic based on the storage suffix.

[Bicep #12482](https://github.com/Azure/bicep/issues/12482) tracks the broader gap in `environment().suffixes` coverage across many Azure services.

### Key Vault private DNS zone

The private DNS zone name for Key Vault uses `vaultcore` instead of `vault`:

```bicep
name: 'privatelink${replace(environment().suffixes.keyvaultDns, 'vault', 'vaultcore')}'
```

The `vault` → `vaultcore` pattern for private DNS zones is documented by Microsoft and verified across all standard clouds.

<br>

## Troubleshooting

If you experience a specific error, check the [list of common errors](../help/errors.md) for mitigation steps. If you aren't experiencing a specific error code or run into any other issues, refer to the [Troubleshooting guide](../help/troubleshooting.md).

If your issue isn't resolved with the troubleshooting guide, see [Get support for FinOps toolkit issues](../help/support.md) for additional help.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK/bladeName/Hubs/featureName/Deploy)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps hubs content:

- [Create and update FinOps hubs](deploy.md)
- [FinOps hub template details](template.md)
- [Configure private networking](private-networking.md)
- [Configure remote hubs](configure-remote-hubs.md)

Related FinOps capabilities:

- [Data ingestion](../../framework/understand/ingestion.md)
- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Advisor](/azure/advisor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
